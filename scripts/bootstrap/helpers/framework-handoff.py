"""Component: installed framework handoff, version 0.1.2.

File: scripts/bootstrap/helpers/framework-handoff.py
Environment: Python 3.11+; canonical power-platform-demo-builder 0.2.1.
The status receipt is a derived view, not a task store or scheduler.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
from datetime import datetime
import errno
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

SOURCE = Path(__file__).resolve().parents[3]
MAX_BYTES = 1024 * 1024
MAX_LAUNCH_ATTEMPTS = 3
FRESH_ACTIONS = {"browser", "deploy", "discover", "deliver", "feedback", "agent-test", "scenario", "git-review"}


def hash_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict:
    if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_BYTES:
        raise ValueError(f"Select a regular bounded JSON input: {path.name}")
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise ValueError(f"Duplicate JSON field in {path.name}: {key}")
            value[key] = item
        return value
    value = json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=unique)
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path.name}")
    return value


def selected_path(root: Path, name: str) -> Path:
    relative = Path(name)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("Selected document paths must be relative and remain inside the project.")
    path = root / relative
    if path.resolve() != path.absolute():
        raise ValueError("Symlink document paths are not supported.")
    return path


def roots(project: str, runtime: str) -> tuple[Path, Path]:
    values = []
    for location in (project, runtime):
        path = Path(location).expanduser().absolute()
        if path.resolve() != path:
            raise ValueError("Symlink workspace paths are not supported.")
        if path == SOURCE or path.is_relative_to(SOURCE) or any(
                (parent / "wizard.profile.json").is_file()
                and (parent / "SYSTEM_MANIFEST.json.md").is_file()
                for parent in (path, *path.parents)):
            raise ValueError("Consumer output cannot be inside starter source.")
        values.append(path)
    project_path, runtime_path = values
    if (project_path == runtime_path or project_path.is_relative_to(runtime_path)
            or runtime_path.is_relative_to(project_path)):
        raise ValueError("Keep project and canonical runtime in separate non-overlapping folders.")
    return project_path, runtime_path


def classify(exc: BaseException) -> str:
    if isinstance(exc, PermissionError):
        return "authorization"
    if isinstance(exc, subprocess.TimeoutExpired):
        return "uncertain"
    if isinstance(exc, OSError) and exc.errno in {errno.EAGAIN, errno.EBUSY, errno.ETXTBSY}:
        return "transient"
    return "deterministic"


def browser_budget(config):
    quality = config.get("quality", {})
    checks = len(config["scenarios"]) + len(quality.get("viewports", [])) * (len(quality.get("surfaces", [])) + 3)
    return config.get("authentication_seconds", 180) + (checks + 5) * (config.get("timeout_seconds", 30) + 40)


def launch(arguments: list[str]) -> tuple[subprocess.CompletedProcess, int]:
    environment = {**os.environ, "PYTHONIOENCODING": "utf-8", "PYTHONUTF8": "1"}
    timeout = 180
    if arguments[0] == "agent-test":
        from demo_builder.agent_testing import validate_config, validate_suite
        config = validate_config(load_json(Path(arguments[arguments.index("--config") + 1])))
        suite = validate_suite(load_json(Path(arguments[arguments.index("--suite") + 1])))
        timeout = 120 + 2 * sum(len(item["turns"]) for item in suite["scenarios"]) * (
            config.get("turn_timeout_seconds", 60) + 40)
    if arguments[:2] == ["browser", "diagnose"]:
        from demo_builder.browser import validate_config
        from demo_builder.errors import BuildError
        try:
            config = validate_config(load_json(Path(arguments[arguments.index("--config") + 1])))
        except BuildError as exc:
            raise ValueError(str(exc)) from exc
        timeout = browser_budget(config) + 60
    if arguments[0] == "scenario" and "--browser-config" in arguments:
        timeout += browser_budget(load_json(Path(arguments[arguments.index("--browser-config") + 1])))
    if arguments[0] == "apply" and "--development" in arguments:
        authority = load_json(Path(arguments[arguments.index("--authorization") + 1]))
        config = load_json(Path(authority["development_profile"]["delivery"]["browser_config"]))
        plan = load_json(Path(arguments[arguments.index("--workspace") + 1]) / "build-plan.json")
        timeout = 300 + len(plan["operations"]) * 180 + (config.get("max_repairs", 1) + 1) * browser_budget(config)
    if arguments[:2] == ["wizard", "deliver"]:
        timeout = 300
        if "--worker-config" in arguments:
            config = load_json(Path(arguments[arguments.index("--worker-config") + 1]))
            timeout += config.get("run_timeout_seconds", 1800) + config.get("verify_timeout_seconds", 120)
        if "--recipe" in arguments:
            recipe = load_json(Path(arguments[arguments.index("--recipe") + 1]))
            timeout += 180 * (10 + 5 * sum(len(value) for value in recipe.values() if isinstance(value, list)))
        configs = []
        if "--browser-config" in arguments:
            configs.append(load_json(Path(arguments[arguments.index("--browser-config") + 1])))
        if "--authorization" in arguments:
            authority = load_json(Path(arguments[arguments.index("--authorization") + 1]))
            delivery = authority.get("development_profile", {}).get("delivery")
            if delivery:
                configs.append(load_json(Path(delivery["browser_config"])))
        for config in configs:
            timeout += (config.get("max_repairs", 1) + 1) * browser_budget(config)
    for attempt in range(1, MAX_LAUNCH_ATTEMPTS + 1):
        try:
            return subprocess.run([sys.executable, "-m", "demo_builder", *arguments],
                                  capture_output=True, text=True, encoding="utf-8",
                                  timeout=timeout, check=False, env=environment), attempt
        except OSError as exc:
            if classify(exc) != "transient" or attempt == MAX_LAUNCH_ATTEMPTS:
                raise
            time.sleep(0.1 * 2 ** (attempt - 1))
    raise AssertionError("Unreachable retry state")


def clock() -> str:
    try:
        zone = ZoneInfo("America/New_York")
    except ZoneInfoNotFoundError:
        # Windows can lack IANA data; an explicit UTC timestamp is preferable to
        # mislabelling the machine's local zone as New York.
        from datetime import timezone
        return datetime.now(timezone.utc).isoformat()
    return datetime.now(zone).isoformat()


def snapshot(paths: list[Path]) -> dict[str, str | None]:
    if any(path.is_symlink() for path in paths):
        raise ValueError("Refusing symlinks in observed inputs or canonical records.")
    return {str(path): hash_file(path) if path.is_file() else None for path in paths}


def observed_snapshot(paths: list[Path], runtime: Path) -> dict[str, str | None]:
    records = [path for path in runtime.rglob("*.json")
               if path.name != "starter-handoff-status.json"]
    return snapshot(paths + records)


def persist(runtime: Path, path: Path, state: dict) -> None:
    from demo_builder.workspace import locked_workspace, write_json
    from demo_builder.errors import BuildError
    try:
        with locked_workspace(runtime):
            write_json(path, state)
    except BuildError as exc:
        raise ValueError(str(exc)) from exc


def source_head() -> dict:
    if not (SOURCE / ".git").exists():
        return {"status": "unversioned-source", "sha": None}
    try:
        result = subprocess.run(["git", "--no-pager", "-C", str(SOURCE), "rev-parse", "HEAD"],
                                capture_output=True, text=True, timeout=5, check=True)
        return {"status": "observed", "sha": result.stdout.strip()}
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"Source revision unavailable: {type(exc).__name__}", file=sys.stderr)
        return {"status": "unavailable", "sha": None, "diagnostic": type(exc).__name__}


def canonical_task_status(runtime: Path) -> dict:
    from demo_builder import tasks
    from demo_builder.errors import BuildError
    from demo_builder.workspace import child, digest, read_json
    try:
        path = child(runtime, "tasks.json")
        if not path.exists():
            return {"status": "unavailable", "observed_at": clock(), "counts": None,
                    "projection_only": True, "diagnostic": "Canonical tasks.json is absent.",
                    "next_action": "Reconcile interrupted initialization in the original canonical workspace."}
        stored = read_json(path)
        state = deepcopy(stored)
        eligible = [task["id"] for task in tasks.ready_tasks(state)]
    except (BuildError, KeyError, TypeError) as exc:
        raise ValueError(f"Cannot report canonical tasks: {exc}") from exc
    by_id = {task["id"]: task for task in state["tasks"]}
    original = {task["id"]: task for task in stored["tasks"]}
    events = state.get("history", [])
    if any(not isinstance(event, dict) or (
            event.get("task") is not None and not isinstance(event["task"], str)) for event in events):
        raise ValueError("Cannot report malformed canonical task history.")
    last_events = {event.get("task"): event.get("at") for event in events}
    counts = dict(completed=0, running=0, blocked=0, pending=0, eligible=len(eligible))
    records = []
    for task in state["tasks"]:
        status = task.get("status")
        if not isinstance(status, str) or status not in {"completed", "running", "blocked", "ready"}:
            raise ValueError(f"Unsupported canonical status for task {task['id']}; reconcile its task record.")
        counts["pending" if status == "ready" else status] += 1
        waiting = [{"task_id": dependency, "status": by_id[dependency]["status"]}
                   for dependency in task.get("depends_on", [])
                   if by_id[dependency]["status"] != "completed"]
        if task["id"] in eligible:
            action = "Use the canonical coordinator with an explicitly authorized worker scope."
        elif status == "running":
            action = "Preserve the owner; verify the current lease before any write."
        elif status == "completed":
            action = "Review evidence separately; coordination completion is not live acceptance."
        elif status == "blocked":
            action = "Resolve the recorded blocker without resetting canonical state."
        elif waiting:
            action = "Resolve the listed prerequisites; independent eligible tasks can continue."
        else:
            action = "Inspect canonical resource and external ownership holds before claiming."
        records.append({"id": task["id"], "status": status,
                        "stored_status": original[task["id"]].get("status"),
                        "owner": task.get("owner"), "lease_until": task.get("lease_until"),
                        "last_event_at": last_events.get(task["id"]),
                        "blocked_reason": task.get("blocked_reason"),
                        "waiting_for": waiting,
                        "lease_reconciliation_required": (
                            original[task["id"]].get("status") == "running"
                            and (status != "running" or task.get("last_result_code") == "lease_expired")),
                        "next_action": action})
    return {"status": "observed", "observed_at": clock(), "updated_at": stored.get("updated_at"),
            "task_state_digest": digest(stored), "projection_only": True,
            "eligibility_scope": "coordinator-only-not-worker-authorization",
            "counts": counts, "eligible_task_ids": eligible, "tasks": records,
            "next_action": ("Continue independent eligible tasks through the configured canonical coordinator."
                            if eligible else "Inspect owners, blockers and dependencies; do not dispatch outside scope.")}


def execute(args: argparse.Namespace) -> tuple[dict, int]:
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", args.scenario):
        raise ValueError("Use a normalized scenario slug, not a path.")
    project, runtime = roots(args.project, args.runtime)
    selected = {key: f"specs/{args.scenario}/{key}.md" for key in ("spec", "plan", "tasks")}
    selected["build"] = args.build
    documents = [selected_path(project, name) for name in selected.values()]
    existing = [path.is_file() for path in documents[:3]]
    if not any(existing) and args.action not in {"discover", "feedback", "agent-test", "scenario", "git-review"}:
        return {"status": "not-applicable", "reason": "Spec Kit absent", "source_changed": False,
                "scheduler_started": False, "next_action": "Complete accepted planning before handoff."}, 0
    if not all(existing) and args.action not in {"discover", "feedback", "agent-test", "scenario", "git-review"}:
        raise ValueError("Partial Spec Kit planning: complete all selected documents before handoff.")
    for path in documents:
        if path.exists() and (not path.is_file() or path.stat().st_size > MAX_BYTES):
            raise ValueError("Selected Markdown documents must be regular and bounded to 1 MiB.")
    try:
        version = importlib.metadata.version("power-platform-demo-builder")
    except importlib.metadata.PackageNotFoundError:
        raise ValueError("Installed framework missing; select its Python environment. No automatic installation.") from None
    if version != "0.2.1":
        raise ValueError("Review compatibility before using a framework version other than 0.2.1.")
    from demo_builder.workspace import assert_external_output
    from demo_builder.errors import BuildError
    try:
        assert_external_output(project)
        assert_external_output(runtime)
    except BuildError as exc:
        raise ValueError(str(exc)) from exc
    marker = runtime / ".demo-workspace.json"
    if marker.exists() and load_json(marker).get("owner") != "demo-builder":
        raise ValueError("Preserve another tool's workspace; select the canonical runtime.")
    status_path = runtime / "starter-handoff-status.json"
    previous = load_json(status_path) if status_path.exists() else None
    if previous is not None and previous.get("schema_version") != "1.0":
        raise ValueError("Unsupported handoff status version; preserve and review it.")
    if previous is not None and (not isinstance(previous.get("intent"), dict)
                     or previous["intent"].get("project") != str(project)):
        raise ValueError("Existing handoff belongs to another project; preserve its canonical workspace.")
    sources = [Path(value).expanduser().absolute() for value in
               (args.contract, args.recipe, args.snapshot, args.adoption, args.delivery, args.worker_config,
                getattr(args, "browser_config", None), getattr(args, "authorization", None),
                getattr(args, "feedback", None), getattr(args, "agent_suite", None),
                getattr(args, "agent_config", None), getattr(args, "agent_baseline", None),
                getattr(args, "git_review_manifest", None)) if value]
    for path in sources:
        load_json(path)
    if (args.action == "worker" or (args.action == "deliver" and args.worker_config)) and sys.platform == "win32":
        raise ValueError("Native Windows worker supervision is unsupported; use an explicitly selected POSIX host.")
    if args.action == "status":
        if previous is None:
            return {"status": "not-started", "next_action": "Run start with the accepted contract.",
                    "task_summary": canonical_task_status(runtime), "scheduler_started": False}, 0
        value = previous.copy()
        value["recorded_status"] = value["status"]
        value["recorded_exit_code"] = value["exit_code"]
        value["current_inputs_match"] = (
            value.get("observed_hashes") == observed_snapshot(
                [Path(name) for name in value.get("observed_hashes", {})], runtime)
            and value["intent"]["starter_source_head"] == source_head())
        if value["recorded_status"] == "completed" and not value["current_inputs_match"]:
            value["status"] = "stale"
            value["next_action"] = "Resume with the accepted inputs; recorded completion is not current evidence."
        value["canonical_tasks"] = str(runtime / "tasks.json")
        value["scheduler_started"] = False
        value["task_summary"] = canonical_task_status(runtime)
        if value["task_summary"]["status"] == "unavailable":
            value.update(status="blocked", exit_code=2, next_action=value["task_summary"]["next_action"])
            return value, 2
        return value, int(value["exit_code"])
    observed = sources + documents + [runtime / name for name in (
        "contract.json", "tasks.json", "identity-map.json", "spec-kit.json",
        "spec-kit-state.json", "memory-environment.json", "execution-summary.json")]
    observed += [Path(__file__), SOURCE / "scripts" / "bootstrap" / "09-framework-handoff.ps1"]
    intent = {"project": str(project), "selection": selected, "action": args.action,
              "enable_sync": args.enable_sync, "framework_version": version,
              "starter_source_head": source_head()}
    if (runtime / "spec-kit.json").exists():
        config = load_json(runtime / "spec-kit.json")
        if config["project"] != str(project) or config["files"] != selected:
            raise ValueError("Resume the original document selection; do not reclaim another adoption.")
    if (args.action not in FRESH_ACTIONS and previous and previous["status"] == "completed" and previous["intent"] == intent
            and previous["observed_hashes"] == observed_snapshot(observed, runtime)):
        return {**previous, "replayed": True, "source_changed": False}, 0
    if (args.action not in FRESH_ACTIONS and previous and previous["status"] == "blocked" and previous["intent"] == intent
            and (previous.get("category") == "deterministic"
                 or (previous.get("category") == "conflict-or-incomplete"
                     and previous.get("current_command") == ["spec-kit", "sync"]
                     and previous.get("exit_code") == 3))
            and previous.get("observed_hashes") == observed_snapshot(observed, runtime)):
        return {**previous, "replayed": True, "source_changed": False}, int(previous["exit_code"])
    commands: list[list[str]] = []
    if args.action in {"scenario", "git-review"}:
        if args.enable_sync:
            raise ValueError("Quality, replay and Git inspection never enable document synchronization.")
        if args.action == "scenario":
            try:
                from demo_builder.replay import scenario
            except ImportError:
                raise ValueError("Selected installed framework lacks Q33 scenario reuse.") from None
            command = ["scenario", getattr(args, "scenario_operation", "replay"), "--workspace", str(runtime)]
            for name in ("authorization", "browser_config"):
                if getattr(args, name, None):
                    command += ["--" + name.replace("_", "-"), getattr(args, name)]
            if getattr(args, "accept_scenario", False):
                command.append("--accepted")
        else:
            try:
                from demo_builder.git_inventory import inspect_integration
            except ImportError:
                raise ValueError("Selected installed framework lacks Q33 Git inspection.") from None
            if not getattr(args, "git_review_manifest", None):
                raise ValueError("Read-only Git review requires selected PR snapshots and canonical writer workspace scope.")
            command = ["git-review", "--root", str(project), "--manifest", args.git_review_manifest]
        commands.append(command)
    elif args.action == "agent-test":
        try:
            from demo_builder.agent_testing import run_tests
        except ImportError:
            raise ValueError("Selected installed framework lacks Q32 behavioral testing; no silent installation.") from None
        if args.enable_sync or not getattr(args, "agent_suite", None) or not getattr(args, "agent_config", None):
            raise ValueError("Agent testing requires selected suite/config and never enables document synchronization.")
        command = ["agent-test", "--workspace", str(runtime / "agent-tests"),
                   "--suite", args.agent_suite, "--config", args.agent_config]
        for field in ("authorization", "agent_baseline"):
            if getattr(args, field, None):
                command += ["--baseline" if field == "agent_baseline" else "--authorization", getattr(args, field)]
        if getattr(args, "repair_agent_fixture", False):
            command.append("--repair")
        commands.append(command)
    elif args.action in {"discover", "deliver", "feedback"}:
        try:
            from demo_builder.discovery import continue_wizard
        except ImportError:
            raise ValueError("Selected installed framework lacks Q31 discovery; review/install its candidate first.") from None
        if args.enable_sync:
            raise ValueError("Select document synchronization separately; discovery never enables or regenerates planning.")
        command = ["wizard", args.action, "--workspace", str(runtime)]
        fields = {"discover": ("contract", "snapshot", "entry_path", "fidelity"),
                  "deliver": ("recipe", "snapshot", "worker_config", "browser_config", "authorization", "tenant", "requirement"),
                  "feedback": ("feedback",)}[args.action]
        for name in fields:
            value = getattr(args, name, None)
            if value:
                command += ["--input" if name == "feedback" else "--" + name.replace("_", "-"), value]
        if args.action == "deliver" and getattr(args, "rehearse_slice", False):
            command.append("--rehearse")
        commands.append(command)
    elif args.action == "start":
        if not args.contract:
            raise ValueError("Start requires an explicitly selected accepted framework contract.")
        contract = load_json(Path(args.contract))
        from demo_builder.contract import validate_contract
        diagnostics = validate_contract(contract)
        if any(item["severity"] == "error" for item in diagnostics):
            raise ValueError("Accepted contract invalid: " + json.dumps(diagnostics))
        commands.append(["run", "--contract", args.contract, "--workspace", str(runtime)])
        if args.adoption:
            commands.append(["adopt", "--workspace", str(runtime), "--input", args.adoption])
        if args.enable_sync and not (runtime / "spec-kit.json").exists():
            if not documents[3].is_file():
                raise ValueError("Opt-in requires an existing selected BUILD document; it is never scaffolded implicitly.")
            adoption = ["spec-kit", "adopt", "--workspace", str(runtime), "--project", str(project),
                        "--owner", "starter-handoff", "--enable"]
            for name, location in selected.items():
                adoption += ["--" + name, location]
            if args.delivery:
                adoption += ["--delivery-context", args.delivery]
            commands += [adoption, ["spec-kit", "preview", "--workspace", str(runtime)],
                         ["spec-kit", "sync", "--workspace", str(runtime)]]
        elif (runtime / "spec-kit.json").exists():
            config = load_json(runtime / "spec-kit.json")
            if config["project"] != str(project) or config["files"] != selected:
                raise ValueError("Resume the original document selection; do not reclaim another adoption.")
            if args.delivery and config.get("delivery") != load_json(Path(args.delivery)):
                commands.append(["spec-kit", "delivery", "--workspace", str(runtime),
                                 "--delivery-context", args.delivery])
            # A start replay never re-enables a disabled existing adoption.
            commands.append(["spec-kit", "sync", "--workspace", str(runtime)])
        if args.recipe:
            commands.append(["compile", "--workspace", str(runtime), "--recipe", args.recipe])
    elif args.action in {"preview", "sync", "enable", "disable"}:
        commands.append(["spec-kit", args.action, "--workspace", str(runtime)])
    elif args.action == "rehearse":
        if args.recipe:
            if load_json(Path(args.recipe)).get("fixture") is not True:
                raise ValueError("Only explicitly synthetic recipes are permitted.")
            commands.append(["compile", "--workspace", str(runtime), "--recipe", args.recipe])
        rehearsal = ["rehearse", "--workspace", str(runtime)]
        if args.snapshot:
            rehearsal += ["--snapshot", args.snapshot]
        commands.append(rehearsal)
    elif args.action == "worker":
        if not args.worker_config:
            raise ValueError("Worker requires an explicitly selected existing worker configuration.")
        commands.append(["worker", "--workspace", str(runtime), "--config", args.worker_config])
    elif args.action == "browser":
        if not getattr(args, "browser_config", None):
            raise ValueError("Browser diagnostics requires an explicitly selected browser configuration.")
        try:
            from demo_builder.browser import validate_config
        except ImportError:
            raise ValueError("Selected installed framework lacks Q29 browser support; review/install its candidate first.") from None
        try:
            validate_config(load_json(Path(args.browser_config)))
        except BuildError as exc:
            raise ValueError(str(exc)) from exc
        output = runtime / "browser-diagnostics" / hashlib.sha256(Path(args.browser_config).read_bytes()).hexdigest()[:24]
        commands.append(["browser", "diagnose", "--workspace", str(output), "--config", args.browser_config])
    elif args.action == "deploy":
        if not getattr(args, "authorization", None) or not getattr(args, "tenant", None):
            raise ValueError("Deployment requires existing exact authorization and tenant; credentials alone grant no scope.")
        try:
            from demo_builder.delivery import Delivery
            from demo_builder.browser import validate_config
            from demo_builder.forms import guid
        except ImportError:
            raise ValueError("Selected installed framework lacks Q30 targeted delivery; review/install its candidate first.") from None
        authority = load_json(Path(args.authorization))
        profile = authority.get("development_profile", {})
        if not isinstance(profile, dict) or not isinstance(profile.get("delivery"), dict):
            raise ValueError("Deployment requires the explicitly authorized Q30 nonproduction delivery profile.")
        try:
            config = validate_config(load_json(Path(profile["delivery"]["browser_config"])))
            if guid(args.tenant) != guid(config["target"]["tenant_id"]):
                raise ValueError("Deployment tenant differs from the authorized rendered target.")
        except (BuildError, KeyError) as exc:
            raise ValueError(str(exc)) from exc
        commands.append(["apply", "--workspace", str(runtime), "--development", "--authorization",
                         args.authorization, "--credential", "azure-cli", "--tenant", args.tenant])
    if args.action not in {"start", "discover", "agent-test", "git-review"} and not (runtime / ".demo-workspace.json").is_file():
        raise ValueError("Start or adopt the canonical runtime before continuing.")
    history = previous.get("history", []) if previous else []
    if len(history) + len(commands) > 200:
        raise ValueError("Handoff history limit reached; review archival without erasing canonical records.")
    state = {"schema_version": "1.0", "intent": intent, "status": "running",
             "started_at": clock(), "current_command": None, "history": history,
             "exit_code": 3, "next_action": args.action, "scheduler_started": False}
    for index, command in enumerate(commands):
        state["current_command"] = command[0:2]
        state["remaining_commands"] = len(commands) - index
        persist(runtime, status_path, state)
        try:
            result, attempts = launch(command)
        except (OSError, subprocess.TimeoutExpired) as exc:
            category = classify(exc)
            state["history"].append({
                "command": command,
                "attempts": MAX_LAUNCH_ATTEMPTS if category == "transient" else 1,
                "exit_code": 2, "timestamp": clock(),
                "category": category, "diagnostic": str(exc)})
            state.update(status="blocked", exit_code=2, category=classify(exc),
                         diagnostic=str(exc), observed_hashes=observed_snapshot(observed, runtime),
                         next_action="Reconcile canonical records and resume the same workspace.")
            persist(runtime, status_path, state)
            return state, 2
        record = {"command": command, "attempts": attempts, "exit_code": result.returncode,
                  "timestamp": clock(), "stdout": result.stdout[-32768:], "stderr": result.stderr[-8192:]}
        state["history"].append(record)
        if result.returncode:
            state.update(status="blocked", exit_code=result.returncode,
                         category="conflict-or-incomplete" if result.returncode == 3 else "deterministic",
                         observed_hashes=observed_snapshot(observed, runtime),
                         next_action="Resolve reported blockers; continue independent canonical tasks, then resume.")
            persist(runtime, status_path, state)
            return state, result.returncode
    state.update(status="completed", exit_code=0, current_command=None, remaining_commands=0,
                 completed_at=clock(), observed_hashes=observed_snapshot(observed, runtime),
                 next_action="Review canonical tasks and separate source, synthetic, deployment and UI evidence.")
    persist(runtime, status_path, state)
    return state, 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("project", "runtime", "scenario"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--action", default="start",
                        choices=("start", "preview", "sync", "enable", "disable", "rehearse", "status", "worker", "browser", "deploy", "discover", "deliver", "feedback", "agent-test", "scenario", "git-review"))
    for name in ("contract", "recipe", "snapshot", "adoption", "delivery", "worker-config", "browser-config", "authorization", "tenant", "requirement", "feedback", "agent-suite", "agent-config", "agent-baseline", "git-review-manifest"):
        parser.add_argument("--" + name)
    parser.add_argument("--entry-path", choices=("build", "enhance", "repair"))
    parser.add_argument("--fidelity", choices=("single-operator-demonstration", "multi-persona-demonstration", "production-oriented"))
    parser.add_argument("--rehearse-slice", action="store_true")
    parser.add_argument("--repair-agent-fixture", action="store_true")
    parser.add_argument("--scenario-operation", choices=("capture", "replay", "reset"), default="replay")
    parser.add_argument("--accept-scenario", action="store_true")
    parser.add_argument("--build", default="BUILD.md")
    parser.add_argument("--enable-sync", action="store_true")
    args = parser.parse_args()
    try:
        value, code = execute(args)
    except (ValueError, OSError) as exc:
        value, code = {"status": "blocked", "category": classify(exc), "diagnostic": str(exc),
                       "source_changed": False, "scheduler_started": False}, 2
    print(json.dumps(value, indent=2))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
