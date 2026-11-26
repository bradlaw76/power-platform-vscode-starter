"""Component: starter H008 handoff verification, version 0.1.0.

File: scripts/ci/test_framework_handoff.py
Environment: Python 3.11+; optional installed framework 0.2.1 and generic fixture.
"""
import argparse
from contextlib import nullcontext
from copy import deepcopy
import errno
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from types import ModuleType
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("starter_handoff", ROOT / "scripts" / "bootstrap" / "helpers" / "framework-handoff.py")
handoff = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handoff)
FIXTURE = os.environ.get("STARTER_FRAMEWORK_FIXTURE")
AVAILABLE = importlib.util.find_spec("demo_builder") is not None and FIXTURE is not None


class HandoffBoundaries(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.project, self.runtime = self.root / "project", self.root / "runtime"
        self.args = argparse.Namespace(project=str(self.project), runtime=str(self.runtime),
            scenario="connected-journey", action="start", build="BUILD.md", contract=None,
            recipe=None, snapshot=None, adoption=None, delivery=None, worker_config=None,
            enable_sync=False)

    def docs(self):
        folder = self.project / "specs" / self.args.scenario
        folder.mkdir(parents=True)
        for name in ("spec.md", "plan.md", "tasks.md"):
            (folder / name).write_bytes(b"# Human text\r\n\r\nPreserve spacing.  \r\n")
        (self.project / "BUILD.md").write_bytes(b"# Human build record\r\n")

    def framework_boundary(self):
        """Isolate delegation tests; InstalledHandoff retains the real runtime."""
        def write_json(path, state):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(state), encoding="utf-8")

        package = ModuleType("demo_builder")
        modules = {"demo_builder": package}
        capabilities = {
            "workspace": {"assert_external_output": Mock(return_value=None),
                          "locked_workspace": Mock(side_effect=lambda path: nullcontext()),
                          "write_json": write_json},
            "errors": {"BuildError": type("BuildError", (Exception,), {})},
            "browser": {"validate_config": Mock(side_effect=lambda value: value)},
            "delivery": {"Delivery": Mock(side_effect=AssertionError("Use the CLI boundary"))},
            "forms": {"guid": Mock(side_effect=lambda value: value)},
            "discovery": {"continue_wizard": Mock(side_effect=AssertionError("Use the CLI boundary"))},
            "agent_testing": {"run_tests": Mock(side_effect=AssertionError("Use the CLI boundary"))},
            "replay": {"scenario": Mock(side_effect=AssertionError("Use the CLI boundary"))},
            "git_inventory": {"inspect_integration": Mock(side_effect=AssertionError("Use the CLI boundary"))},
            "functional": {"COVERAGE_VERSION": "1.0",
                           "load_requirements_coverage": lambda path, *, task_ids=None: {}},
        }
        for name, members in capabilities.items():
            module = ModuleType(f"demo_builder.{name}")
            vars(module).update(members)
            setattr(package, name, module)
            modules[module.__name__] = module
        return patch.dict(sys.modules, modules)

    def test_absent_spec_kit_is_noop_without_install_or_workspace(self):
        value, code = handoff.execute(self.args)
        self.assertEqual(code, 0)
        self.assertEqual(value["status"], "not-applicable")
        self.assertFalse(self.project.exists())
        self.assertFalse(self.runtime.exists())

    def test_supported_versions_still_require_coverage_api_before_status(self):
        self.docs()
        self.args.action = "status"
        for version in ("0.2.1", "0.2.2rc1"):
            with self.subTest(version=version), self.framework_boundary(), \
                    patch.object(handoff.importlib.metadata, "version", return_value=version), \
                    patch.object(handoff, "canonical_task_status", return_value={"status": "unavailable"}):
                result, code = handoff.execute(self.args)
                self.assertEqual(code, 0)
                self.assertEqual(result["status"], "not-started")
                self.assertFalse(result["scheduler_started"])
                with patch("demo_builder.functional.load_requirements_coverage", lambda unrelated: {}):
                    with self.assertRaisesRegex(ValueError, "coverage API 1.0"):
                        handoff.execute(self.args)
                with patch("demo_builder.functional.COVERAGE_VERSION", "future"):
                    with self.assertRaisesRegex(ValueError, "coverage API 1.0"):
                        handoff.execute(self.args)
        self.assertFalse(self.runtime.exists())

    def test_partial_planning_and_protected_roots_fail_before_mutation(self):
        self.project.mkdir()
        (self.project / "specs" / self.args.scenario).mkdir(parents=True)
        (self.project / "specs" / self.args.scenario / "spec.md").write_text("Incomplete")
        with self.assertRaisesRegex(ValueError, "Partial"):
            handoff.execute(self.args)
        self.assertFalse(self.runtime.exists())
        with self.assertRaisesRegex(ValueError, "starter source"):
            handoff.roots(str(ROOT / "specs"), str(self.runtime))
        with self.assertRaisesRegex(ValueError, "non-overlapping"):
            handoff.roots(str(self.project), str(self.project / "runtime"))
        with self.assertRaisesRegex(ValueError, "relative"):
            handoff.selected_path(self.project, "../outside.md")
        clone = self.root / "another-starter"
        clone.mkdir()
        (clone / "wizard.profile.json").write_text("{}")
        (clone / "SYSTEM_MANIFEST.json.md").write_text("Source marker")
        with self.assertRaisesRegex(ValueError, "starter source"):
            handoff.roots(str(clone / "consumer"), str(self.runtime))

    def test_duplicate_json_and_unknown_version_are_not_silently_adopted(self):
        path = self.root / "duplicate.json"
        path.write_text('{"accepted":true,"accepted":false}')
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            handoff.load_json(path)
        self.docs()
        with patch.object(handoff.importlib.metadata, "version", return_value="9.0.0"):
            with self.assertRaisesRegex(ValueError, "compatibility"):
                handoff.execute(self.args)
        self.assertFalse(self.runtime.exists())

    def test_browser_action_uses_existing_runtime_and_never_reuses_cached_diagnostics(self):
        self.docs()
        self.runtime.mkdir()
        (self.runtime / ".demo-workspace.json").write_text('{"owner":"demo-builder"}')
        config = self.root / "browser.json"
        config.write_text('{"schema_version":"1.0"}')
        self.args.action, self.args.browser_config = "browser", str(config)
        succeeded = subprocess.CompletedProcess(["browser"], 0, '{"status":"passed","fixture":true}', "")
        with self.framework_boundary(), \
                patch.object(handoff.importlib.metadata, "version", return_value="0.2.1"), \
                patch("demo_builder.browser.validate_config", return_value={}), \
                patch.object(handoff, "launch", return_value=(succeeded, 1)) as launch:
            first, code = handoff.execute(self.args)
            self.assertEqual(code, 0)
            second, code = handoff.execute(self.args)
        self.assertEqual(code, 0)
        self.assertEqual(launch.call_count, 2)
        self.assertEqual(launch.call_args.args[0][:2], ["browser", "diagnose"])
        self.assertNotIn("--install", launch.call_args.args[0])
        self.assertNotIn("replayed", second)

    def worker_boundary(self):
        self.docs()
        self.runtime.mkdir()
        (self.runtime / ".demo-workspace.json").write_text('{"owner":"demo-builder"}')
        self.source = self.project / "source.py"
        self.verifier = self.project / "verifier.py"
        self.source.write_text("source version one")
        self.verifier.write_text("verifier version one")
        config = self.root / "worker.json"
        config.write_text(json.dumps({"command": [sys.executable, str(self.source)],
                                     "verify_command": [sys.executable, str(self.verifier)]}))
        self.args.action, self.args.worker_config = "worker", str(config)
        functional = ModuleType("demo_builder.functional")
        functional.COVERAGE_VERSION = "1.0"
        functional.load_requirements_coverage = lambda path, *, task_ids=None: {}
        windows = ModuleType("demo_builder.windows_process")
        windows.WINDOWS_SUPERVISION_VERSION = "1.0"
        windows.OwnedJob, windows.identity_alive = Mock(), Mock()
        return patch.dict(sys.modules, {functional.__name__: functional, windows.__name__: windows})

    def test_reconciliation_rechecks_current_source_and_verifier_after_cached_results(self):
        with self.worker_boundary(), self.framework_boundary(), \
                patch.object(handoff.importlib.metadata, "version", return_value="0.2.1"), \
                patch.object(handoff, "launch", side_effect=[
                    (subprocess.CompletedProcess(["worker"], 0, "accepted original source", ""), 1),
                    (subprocess.CompletedProcess(["worker"], 2, "", "source fingerprint changed"), 1),
                    (subprocess.CompletedProcess(["worker"], 3, "", "verifier fingerprint changed"), 1),
                ]) as launch:
            self.args.reconcile_only = True
            handoff.execute(self.args)
            self.source.write_text("source version two")
            changed_source, code = handoff.execute(self.args)
            self.assertEqual(2, code, changed_source)
            self.assertNotIn("replayed", changed_source)
            self.verifier.write_text("verifier version two")
            changed_verifier, code = handoff.execute(self.args)
            self.assertEqual(3, code, changed_verifier)
            self.assertNotIn("replayed", changed_verifier)
        self.assertEqual(3, launch.call_count)
        self.assertTrue(all("--reconcile-only" in call.args[0] for call in launch.call_args_list))

    def test_worker_task_selection_is_forwarded_and_changes_cached_intent_without_releasing_holds(self):
        with self.worker_boundary(), self.framework_boundary(), \
                patch.object(handoff.importlib.metadata, "version", return_value="0.2.1"), \
                patch.object(handoff, "launch", return_value=(
                    subprocess.CompletedProcess(["worker"], 0, "delegated", ""), 1)) as launch:
            canonical = self.runtime / "tasks.json"
            canonical.write_text(json.dumps({"tasks": [
                {"id": "SOURCE-BLOCKED", "status": "blocked"},
                {"id": "OWNER-HOLD", "status": "blocked", "reason": "protected owner hold"},
            ]}))
            original = canonical.read_bytes()
            self.args.task_id = ["SOURCE-BLOCKED", "OWNER-HOLD"]
            handoff.execute(self.args)
            command = launch.call_args.args[0]
            self.assertEqual(command[-4:], ["--task-id", "SOURCE-BLOCKED", "--task-id", "OWNER-HOLD"])
            self.assertNotIn("--force", command)
            self.args.task_id = ["SOURCE-BLOCKED"]
            result, code = handoff.execute(self.args)
            self.assertEqual(0, code, result)
            self.assertNotIn("replayed", result)
            self.assertEqual(2, launch.call_count)
            self.assertEqual(canonical.read_bytes(), original)
            replayed, code = handoff.execute(self.args)
            self.assertEqual(0, code, replayed)
            self.assertTrue(replayed["replayed"])
            self.assertEqual(2, launch.call_count)
            self.args.task_id = ["UNKNOWN-EXISTING-ID"]
            launch.return_value = (subprocess.CompletedProcess(["worker"], 2, "", "unknown task ID"), 1)
            result, code = handoff.execute(self.args)
            self.assertEqual(2, code, result)
            self.assertEqual(launch.call_args.args[0][-2:], ["--task-id", "UNKNOWN-EXISTING-ID"])
            self.assertEqual(canonical.read_bytes(), original)
            self.args.reconcile_only, self.args.task_id = True, ["SOURCE-BLOCKED", "OWNER-HOLD"]
            handoff.execute(self.args)
            self.assertIn("--reconcile-only", launch.call_args.args[0])
            self.assertEqual(launch.call_args.args[0][-4:], ["--task-id", "SOURCE-BLOCKED", "--task-id", "OWNER-HOLD"])
            self.assertEqual(canonical.read_bytes(), original)

    def test_python_entrypoint_accepts_repeated_existing_task_ids(self):
        argv = ["handoff", "--project", str(self.project), "--runtime", str(self.runtime),
                "--scenario", self.args.scenario, "--action", "worker", "--reconcile-only",
                "--task-id", "SOURCE-BLOCKED", "--task-id", "OWNER-HOLD"]
        with patch.object(sys, "argv", argv), patch.object(handoff, "execute", return_value=({}, 0)) as execute:
            self.assertEqual(0, handoff.main())
        self.assertEqual(execute.call_args.args[0].task_id, ["SOURCE-BLOCKED", "OWNER-HOLD"])
        self.assertTrue(execute.call_args.args[0].reconcile_only)

    @unittest.skipUnless(shutil.which("pwsh"), "PowerShell is needed for wrapper forwarding")
    def test_powershell_entrypoint_forwards_explicit_existing_task_ids(self):
        scripts = self.root / "wrapper"
        (scripts / "helpers").mkdir(parents=True)
        shutil.copyfile(ROOT / "scripts" / "bootstrap" / "09-framework-handoff.ps1", scripts / "09-framework-handoff.ps1")
        (scripts / "12-check-wizard-capabilities.ps1").write_text("$global:LASTEXITCODE = 0\n")
        (scripts / "helpers" / "framework-handoff.py").write_text("import json,sys\nprint(json.dumps(sys.argv[1:]))\n")
        result = subprocess.run(["pwsh", "-NoProfile", "-File", str(scripts / "09-framework-handoff.ps1"),
            "-ProjectRoot", str(self.project), "-RuntimeWorkspace", str(self.runtime),
            "-ScenarioSlug", self.args.scenario, "-Action", "worker", "-ReconcileOnly",
            "-TaskIds", "SOURCE-BLOCKED", "-PythonExecutable", sys.executable],
            capture_output=True, text=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        command = json.loads(result.stdout)
        self.assertIn("--reconcile-only", command)
        self.assertEqual(command[-2:], ["--task-id", "SOURCE-BLOCKED"])
        quote = lambda value: "'" + str(value).replace("'", "''") + "'"
        expression = (f"& {quote(scripts / '09-framework-handoff.ps1')} "
            f"-ProjectRoot {quote(self.project)} -RuntimeWorkspace {quote(self.runtime)} "
            f"-ScenarioSlug {quote(self.args.scenario)} -Action worker -ReconcileOnly "
            f"-TaskIds @('SOURCE-BLOCKED','OWNER-HOLD') -PythonExecutable {quote(sys.executable)}")
        result = subprocess.run(["pwsh", "-NoProfile", "-Command", expression],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout)[-4:], ["--task-id", "SOURCE-BLOCKED", "--task-id", "OWNER-HOLD"])

    def test_discovery_works_before_spec_kit_and_feedback_forwards_without_cached_success(self):
        self.project.mkdir()
        contract = self.root / "selected.json"
        contract.write_text('{"schema_version":"1.0"}')
        self.args.action, self.args.contract = "discover", str(contract)
        self.args.entry_path, self.args.fidelity = "repair", "single-operator-demonstration"
        succeeded = subprocess.CompletedProcess(["wizard"], 0, '{"status":"discovered","ui_verified":false}', "")
        with self.framework_boundary(), \
                patch.object(handoff.importlib.metadata, "version", return_value="0.2.1"), \
                patch.object(handoff, "launch", return_value=(succeeded, 1)) as launch:
            handoff.execute(self.args)
            value, code = handoff.execute(self.args)
        self.assertEqual(0, code)
        self.assertEqual(2, launch.call_count)
        command = launch.call_args.args[0]
        self.assertEqual(["wizard", "discover"], command[:2])
        self.assertEqual("repair", command[command.index("--entry-path") + 1])
        self.assertNotIn("replayed", value)
        self.assertFalse((self.project / "specs").exists())
        (self.runtime / ".demo-workspace.json").write_text('{"owner":"demo-builder"}')
        feedback = self.root / "feedback.json"
        feedback.write_text('{"schema_version":"1.0"}')
        self.args.action, self.args.feedback = "feedback", str(feedback)
        with self.framework_boundary(), \
                patch.object(handoff.importlib.metadata, "version", return_value="0.2.1"), \
                patch.object(handoff, "launch", return_value=(succeeded, 1)) as launch:
            handoff.execute(self.args)
        self.assertEqual(["wizard", "feedback"], launch.call_args.args[0][:2])
        self.assertEqual(str(feedback), launch.call_args.args[0][launch.call_args.args[0].index("--input") + 1])

    def test_transient_launch_retries_are_bounded_and_permission_is_not_retried(self):
        transient = OSError(errno.EBUSY, "controlled busy launch")
        with patch.object(handoff.subprocess, "run", side_effect=transient) as runner:
            with patch.object(handoff.time, "sleep") as sleeper:
                with self.assertRaises(OSError):
                    handoff.launch(["run"])
        self.assertEqual(runner.call_count, 3)
        self.assertEqual(sleeper.call_count, 2)
        with patch.object(handoff.subprocess, "run", side_effect=PermissionError("denied")) as runner:
            with self.assertRaises(PermissionError):
                handoff.launch(["run"])
        self.assertEqual(runner.call_count, 1)

    def test_agent_behavior_uses_existing_runtime_without_planning_generation_or_publish_flags(self):
        self.project.mkdir()
        suite = self.root / "agent-suite.json"
        config = self.root / "agent-config.json"
        suite.write_text('{"schema_version":"1.0"}')
        config.write_text('{"schema_version":"1.0"}')
        self.args.action = "agent-test"
        self.args.agent_suite, self.args.agent_config = str(suite), str(config)
        self.args.repair_agent_fixture = True
        succeeded = subprocess.CompletedProcess(["agent-test"], 0, '{"status":"passed","fixture":true}', "")
        with self.framework_boundary(), \
                patch.object(handoff.importlib.metadata, "version", return_value="0.2.1"), \
                patch.object(handoff, "launch", return_value=(succeeded, 1)) as launch:
            handoff.execute(self.args)
            value, code = handoff.execute(self.args)
        self.assertEqual(0, code)
        self.assertEqual(2, launch.call_count)
        command = launch.call_args.args[0]
        self.assertEqual("agent-test", command[0])
        self.assertEqual(str(self.runtime / "agent-tests"), command[command.index("--workspace") + 1])
        self.assertIn("--repair", command)
        self.assertNotIn("--publish", command)
        self.assertFalse((self.project / "specs").exists())
        self.assertNotIn("replayed", value)

    def test_deploy_requires_explicit_delivery_authority_and_always_rechecks_the_live_target(self):
        self.docs()
        self.runtime.mkdir()
        (self.runtime / ".demo-workspace.json").write_text('{"owner":"demo-builder"}')
        self.args.action = "deploy"
        with self.framework_boundary(), \
                patch.object(handoff.importlib.metadata, "version", return_value="0.2.1"):
            with self.assertRaisesRegex(ValueError, "exact authorization"):
                handoff.execute(self.args)
        tenant = "00000000-0000-0000-0000-000000000001"
        config = self.root / "browser.json"
        config.write_text(json.dumps({"target": {"tenant_id": tenant}}))
        authority = self.root / "authority.json"
        authority.write_text(json.dumps({"development_profile": {"delivery": {"browser_config": str(config)}}}))
        self.args.authorization, self.args.tenant = str(authority), tenant
        succeeded = subprocess.CompletedProcess(["apply"], 0, '{"status":"completed","ui_verified":false}', "")
        with self.framework_boundary(), \
                patch.object(handoff.importlib.metadata, "version", return_value="0.2.1"), \
                patch("demo_builder.browser.validate_config", side_effect=lambda value: value), \
                patch.object(handoff, "launch", return_value=(succeeded, 1)) as launch:
            handoff.execute(self.args)
            second, code = handoff.execute(self.args)
        self.assertEqual(0, code)
        self.assertEqual(2, launch.call_count)
        command = launch.call_args.args[0]
        self.assertEqual("apply", command[0])
        self.assertIn("--development", command)
        self.assertEqual(str(authority), command[command.index("--authorization") + 1])
        self.assertEqual(tenant, command[command.index("--tenant") + 1])
        self.assertNotIn("replayed", second)
        self.assertEqual(handoff.classify(subprocess.TimeoutExpired("run", 1)), "uncertain")

    def test_quality_replay_and_git_review_forward_fresh_without_planning_or_implicit_reset(self):
        self.project.mkdir()
        manifest = self.root / "git-review.json"
        manifest.write_text('{"schema_version":"1.0"}')
        self.args.action, self.args.git_review_manifest = "git-review", str(manifest)
        succeeded = subprocess.CompletedProcess(["git-review"], 0, '{"status":"observed"}', "")
        with self.framework_boundary(), \
                patch.object(handoff.importlib.metadata, "version", return_value="0.2.1"), \
                patch.object(handoff, "launch", return_value=(succeeded, 1)) as launch:
            handoff.execute(self.args)
            handoff.execute(self.args)
            self.assertEqual(2, launch.call_count)
            command = launch.call_args.args[0]
            self.assertEqual("git-review", command[0])
            self.assertEqual(str(self.project), command[command.index("--root") + 1])
            self.assertNotIn("--accepted", command)
            (self.runtime / ".demo-workspace.json").write_text('{"owner":"demo-builder"}')
            self.args.action = "scenario"
            handoff.execute(self.args)
            self.assertEqual(["scenario", "replay"], launch.call_args.args[0][:2])
            self.args.scenario_operation, self.args.accept_scenario = "capture", True
            handoff.execute(self.args)
            self.assertEqual(["scenario", "capture"], launch.call_args.args[0][:2])
            self.assertIn("--accepted", launch.call_args.args[0])
            self.args.scenario_operation, self.args.accept_scenario = "reset", False
            self.args.authorization = str(manifest)
            handoff.execute(self.args)
            command = launch.call_args.args[0]
            self.assertEqual(["scenario", "reset"], command[:2])
            self.assertEqual(str(manifest), command[command.index("--authorization") + 1])
        self.assertFalse((self.project / "specs").exists())


@unittest.skipUnless(AVAILABLE, "Select installed framework and STARTER_FRAMEWORK_FIXTURE for real integration")
class InstalledHandoff(unittest.TestCase):
    def setUp(self):
        HandoffBoundaries.setUp(self)
        HandoffBoundaries.docs(self)
        self.inputs = self.root / "inputs"
        shutil.copytree(FIXTURE, self.inputs)
        self.args.contract = str(self.inputs / "contract.json")
        self.args.recipe = str(self.inputs / "recipe.json")
        self.args.enable_sync = True

    def start(self):
        result, code = handoff.execute(self.args)
        self.assertEqual(code, 0, result)
        return result

    def action(self, action):
        args = deepcopy(self.args)
        args.action = action
        return handoff.execute(args)

    def test_new_and_existing_synthetic_projects_and_windows_wrapper(self):
        from demo_builder.workspace import read_json
        self.start()
        self.args.action = "rehearse"
        self.args.snapshot = str(self.inputs / "environment.json")
        result, code = handoff.execute(self.args)
        self.assertEqual(code, 0, result)
        execution = read_json(self.runtime / "execution-summary.json")
        self.assertEqual(len(execution["operations"]), 25)
        self.assertTrue(execution["fixture"])
        self.assertFalse(execution["ui_verified"])
        state = read_json(self.runtime / "memory-environment.json")
        self.assertEqual(len(state["state"]["rows"]["account"]), 2)
        self.assertEqual(len(state["state"]["rows"]["ppd_workitem"]), 3)
        self.assertEqual(state["state"]["forms"]["33333333-3333-4333-8333-333333333333"],
                         read_json(self.inputs / "environment.json")["state"]["forms"]["33333333-3333-4333-8333-333333333333"])
        self.assertFalse((self.project / ".git").exists())
        # Existing-project adoption is an accepted mode change, not a new store.
        contract = read_json(self.inputs / "contract.json")
        contract["project"]["mode"] = "improve"
        (self.inputs / "contract.json").write_text(json.dumps(contract))
        self.args.action = "start"
        self.start()
        command = [shutil.which("pwsh"), "-NoProfile", "-File",
                   str(ROOT / "scripts" / "bootstrap" / "09-framework-handoff.ps1"),
                   "-ProjectRoot", str(self.project), "-RuntimeWorkspace", str(self.runtime),
                   "-ScenarioSlug", self.args.scenario, "-Action", "Status",
                   "-PythonExecutable", sys.executable]
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(json.loads(result.stdout)["scheduler_started"])

    def test_wizard_continues_to_installed_handoff_and_synthetic_rehearsal(self):
        project = self.root / "wizard-project"
        runtime = self.root / "wizard-runtime"
        (project / "docs").mkdir(parents=True)
        (project / "payloads").mkdir()
        shutil.copyfile(ROOT / "wizard.profile.json", project / "wizard.profile.json")
        for name in ("onboarding.md", "wizard-contract-v1.md"):
            shutil.copyfile(ROOT / "docs" / name, project / "docs" / name)
        (project / "BUILD.md").write_text("# Human build record\n")
        answers = self.root / "answers.json"
        answers.write_text(json.dumps([
            "Connected journey", "Coordinator | manage linked work",
            "Account, Work Item", "Save linked Work Items from an Account",
            "Synthetic two-parent separation", "Synthetic rehearsal only", "yes"]))
        process = subprocess.run([
            shutil.which("pwsh"), "-NoProfile", "-File",
            str(ROOT / "scripts" / "bootstrap" / "05-start-wizard.ps1"),
            "-WorkspaceRoot", str(project), "-AnswersFile", str(answers),
            "-DeliveryGoal", "connected-demo", "-DeliveryTimeframe", "no fixed deadline",
            "-AcceptedContractPath", self.args.contract,
            "-FrameworkRuntimeWorkspace", str(runtime),
            "-FrameworkPythonExecutable", sys.executable, "-EnableFrameworkSpecKitSync"],
            capture_output=True, text=True, timeout=60)
        self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
        self.assertTrue((runtime / "tasks.json").is_file())
        text = (project / "specs" / self.args.scenario / "spec.md").read_text()
        self.assertIn("Accepted Planning Source", text)
        self.assertIn("ppd_workitem", text)
        self.assertIn("- Publisher prefix: ppd", text)
        self.assertFalse((project / ".git").exists())
        args = deepcopy(self.args)
        args.project, args.runtime = str(project), str(runtime)
        args.action, args.snapshot = "rehearse", str(self.inputs / "environment.json")
        result, code = handoff.execute(args)
        self.assertEqual(code, 0, result)
        summary = json.loads((runtime / "execution-summary.json").read_text())
        self.assertEqual(len(summary["operations"]), 25)
        self.assertTrue(summary["fixture"])
        self.assertFalse(summary["ui_verified"])

    def test_unchanged_replay_preserves_every_runtime_file_and_manual_text(self):
        self.start()
        files = [p for p in self.runtime.rglob("*") if p.is_file()]
        before = {p: p.read_bytes() for p in files}
        result = self.start()
        self.assertTrue(result["replayed"])
        self.assertEqual(before, {p: p.read_bytes() for p in files})
        self.assertTrue((self.project / "specs" / self.args.scenario / "spec.md").read_bytes().startswith(
            b"# Human text\r\n\r\nPreserve spacing.  \r\n"))
        status_before = (self.runtime / "starter-handoff-status.json").read_bytes()
        status, code = self.action("status")
        self.assertEqual(code, 0)
        self.assertTrue(status["current_inputs_match"])
        contract = json.loads((self.inputs / "contract.json").read_text())
        contract["requirements"][0]["description"] += " Accepted status freshness change."
        (self.inputs / "contract.json").write_text(json.dumps(contract))
        status, code = self.action("status")
        self.assertEqual(status["status"], "stale")
        self.assertFalse(status["current_inputs_match"])
        self.assertEqual(status_before, (self.runtime / "starter-handoff-status.json").read_bytes())

    def test_optout_and_explicit_disable_survive_restart_until_enable(self):
        self.args.enable_sync = False
        self.start()
        self.assertFalse((self.runtime / "spec-kit.json").exists())
        self.args.enable_sync = True
        self.start()
        self.action("disable")
        path = self.project / "specs" / self.args.scenario / "spec.md"
        before = path.read_bytes()
        contract = json.loads((self.inputs / "contract.json").read_text())
        contract["requirements"][0]["description"] += " Accepted fixture clarification."
        (self.inputs / "contract.json").write_text(json.dumps(contract))
        self.start()
        self.assertEqual(before, path.read_bytes())
        self.action("enable")
        self.action("sync")
        self.assertIn(b"Accepted fixture clarification.", path.read_bytes())

    def test_utf8_projection_survives_legacy_windows_child_encoding(self):
        contract = json.loads((self.inputs / "contract.json").read_text())
        contract["requirements"][0]["description"] += " Accepted clarification \u03a9."
        (self.inputs / "contract.json").write_text(json.dumps(contract))
        with patch.dict(os.environ, {"PYTHONIOENCODING": "ascii", "PYTHONUTF8": "0"}):
            self.start()
        path = self.project / "specs" / self.args.scenario / "spec.md"
        self.assertIn("Accepted clarification \u03a9.".encode("utf-8"), path.read_bytes())

    def test_explicit_delivery_updates_existing_adoption_without_reenabling(self):
        self.start()
        self.action("disable")
        documents = {path: path.read_bytes() for path in self.project.rglob("*.md")}
        delivery = {"goal": "connected-demo", "deadline": None, "evidence_ids": ["EV-account-journey"]}
        path = self.inputs / "delivery.json"
        path.write_text(json.dumps(delivery))
        self.args.delivery = str(path)
        self.start()
        config = json.loads((self.runtime / "spec-kit.json").read_text())
        self.assertEqual(config["delivery"], delivery)
        self.assertFalse(config["enabled"])
        self.assertEqual(documents, {path: path.read_bytes() for path in self.project.rglob("*.md")})
        before = {path: path.read_bytes() for path in self.runtime.rglob("*.json")}
        self.assertTrue(self.start()["replayed"])
        self.assertEqual(before, {path: path.read_bytes() for path in self.runtime.rglob("*.json")})

    def test_conflict_hold_preserves_human_text_and_updates_independent_section(self):
        self.start()
        contract = json.loads((self.inputs / "contract.json").read_text())
        path = self.project / "specs" / self.args.scenario / "spec.md"
        path.write_bytes(path.read_bytes().replace(contract["requirements"][0]["description"].encode(), b"Human conflict"))
        contract["requirements"][0]["description"] += " Revised first outcome."
        contract["requirements"][1]["description"] += " Independent update."
        (self.inputs / "contract.json").write_text(json.dumps(contract))
        result, code = handoff.execute(self.args)
        self.assertEqual(code, 3, result)
        self.assertEqual(result["status"], "blocked")
        self.assertIn(b"Human conflict", path.read_bytes())
        self.assertIn(b"Independent update.", path.read_bytes())
        before = {file: file.read_bytes() for root in (self.project, self.runtime)
                  for file in root.rglob("*") if file.is_file()}
        replay, code = handoff.execute(self.args)
        self.assertEqual(code, 3, replay)
        self.assertTrue(replay.get("replayed"), replay)
        self.assertEqual(before, {file: file.read_bytes() for root in (self.project, self.runtime)
                                 for file in root.rglob("*") if file.is_file()})
        contract["requirements"][1]["description"] += " Further independent update."
        (self.inputs / "contract.json").write_text(json.dumps(contract))
        resumed, code = handoff.execute(self.args)
        self.assertEqual(code, 3, resumed)
        self.assertNotIn("replayed", resumed)
        self.assertIn(b"Human conflict", path.read_bytes())
        self.assertIn(b"Further independent update.", path.read_bytes())

    def test_incomplete_non_sync_step_remains_retryable(self):
        incomplete = subprocess.CompletedProcess(["run"], 3, "", "Controlled incomplete assessment.")
        with patch.object(handoff, "launch", return_value=(incomplete, 1)) as launch:
            first, code = handoff.execute(self.args)
            self.assertEqual(code, 3, first)
            retry, code = handoff.execute(self.args)
            self.assertEqual(code, 3, retry)
            self.assertNotIn("replayed", retry)
            self.assertEqual(launch.call_count, 2)

    def test_interrupted_journal_recovers_without_duplicating_tasks(self):
        self.start()
        task_bytes = (self.runtime / "tasks.json").read_bytes()
        contract = json.loads((self.runtime / "contract.json").read_text())
        contract["requirements"][0]["description"] += " Interrupted accepted clarification."
        (self.runtime / "contract.json").write_text(json.dumps(contract))
        code = (
            "import os,sys; from unittest.mock import patch; "
            "from pathlib import Path; from demo_builder.cli import main; "
            "from demo_builder.workspace import write_text\n"
            "def crash(path,text):\n"
            " write_text(path,text)\n"
            " if str(Path(path)).startswith(sys.argv[2]): os._exit(86)\n"
            "with patch('demo_builder.spec_kit.write_text',side_effect=crash): "
            " main(['spec-kit','sync','--workspace',sys.argv[1]])"
        )
        process = subprocess.run([sys.executable, "-c", code, str(self.runtime), str(self.project)], timeout=30)
        self.assertEqual(process.returncode, 86)
        result, code = self.action("sync")
        self.assertEqual(code, 0, result)
        self.assertEqual(json.loads((self.runtime / "spec-kit-state.json").read_text())["pending"], {})
        self.assertEqual(task_bytes, (self.runtime / "tasks.json").read_bytes())

    def test_adapter_crash_after_adoption_resumes_without_reclaim_or_duplicates(self):
        helper = ROOT / "scripts" / "bootstrap" / "helpers" / "framework-handoff.py"
        code = (
            "import argparse,importlib.util,json,os,sys\n"
            "spec=importlib.util.spec_from_file_location('handoff',sys.argv[1])\n"
            "module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)\n"
            "original=module.launch\n"
            "def crash(command):\n"
            " result=original(command)\n"
            " if command[:2]==['spec-kit','adopt'] and result[0].returncode==0: os._exit(87)\n"
            " return result\n"
            "module.launch=crash\n"
            "module.execute(argparse.Namespace(**json.loads(sys.argv[2])))\n"
        )
        process = subprocess.run(
            [sys.executable, "-c", code, str(helper), json.dumps(vars(self.args))],
            capture_output=True, text=True, timeout=60,
        )
        self.assertEqual(process.returncode, 87, process.stdout + process.stderr)
        receipt = json.loads((self.runtime / "starter-handoff-status.json").read_text())
        self.assertEqual(receipt["status"], "running")
        self.assertEqual(receipt["current_command"], ["spec-kit", "adopt"])
        task_ids = [task["id"] for task in json.loads((self.runtime / "tasks.json").read_text())["tasks"]]
        selection = (self.runtime / "spec-kit.json").read_bytes()
        owner = (self.project / ".spec-kit-owner.json").read_bytes()
        command = [
            sys.executable, str(helper), "--project", str(self.project),
            "--runtime", str(self.runtime), "--scenario", self.args.scenario,
            "--contract", self.args.contract, "--recipe", self.args.recipe,
            "--enable-sync",
        ]
        resumed = subprocess.run(command, capture_output=True, text=True, timeout=60)
        self.assertEqual(resumed.returncode, 0, resumed.stdout + resumed.stderr)
        self.assertEqual(selection, (self.runtime / "spec-kit.json").read_bytes())
        self.assertEqual(owner, (self.project / ".spec-kit-owner.json").read_bytes())
        self.assertEqual(task_ids, [
            task["id"] for task in json.loads((self.runtime / "tasks.json").read_text())["tasks"]
        ])
        before = {path: path.read_bytes() for path in self.runtime.rglob("*") if path.is_file()}
        documents = {path: path.read_bytes() for path in self.project.rglob("*.md")}
        replay = subprocess.run(command, capture_output=True, text=True, timeout=60)
        self.assertEqual(replay.returncode, 0, replay.stdout + replay.stderr)
        self.assertTrue(json.loads(replay.stdout)["replayed"])
        self.assertEqual(before, {path: path.read_bytes() for path in self.runtime.rglob("*") if path.is_file()})
        self.assertEqual(documents, {path: path.read_bytes() for path in self.project.rglob("*.md")})

    def test_active_runtime_lock_and_stale_plan_are_not_bypassed(self):
        from demo_builder.workspace import locked_workspace
        self.start()
        contract = json.loads((self.runtime / "contract.json").read_text())
        contract["requirements"][0]["description"] += " Source changed."
        (self.runtime / "contract.json").write_text(json.dumps(contract))
        status_before = (self.runtime / "starter-handoff-status.json").read_bytes()
        with locked_workspace(self.runtime):
            with self.assertRaises((ValueError, PermissionError)):
                self.action("sync")
        self.assertEqual(status_before, (self.runtime / "starter-handoff-status.json").read_bytes())
        args = deepcopy(self.args)
        args.action = "rehearse"
        args.recipe = None
        result, code = handoff.execute(args)
        self.assertEqual(code, 2, result)
        self.assertIn("contract changed", result["history"][-1]["stderr"])
        before = {p: p.read_bytes() for p in self.runtime.rglob("*") if p.is_file()}
        replay, code = handoff.execute(args)
        self.assertEqual(code, 2)
        self.assertTrue(replay["replayed"])
        self.assertEqual(before, {p: p.read_bytes() for p in self.runtime.rglob("*") if p.is_file()})

    def test_status_projects_native_dependencies_and_resource_holds_without_writes(self):
        from demo_builder import tasks
        from demo_builder.workspace import read_json, write_json
        self.start()
        planned = [
            {"id": "NATIVE-DONE", "status": "completed", "depends_on": [], "resources": []},
            {"id": "NATIVE-OWNER", "status": "ready", "depends_on": [], "resources": ["shared"]},
            {"id": "NATIVE-BLOCK", "status": "blocked", "blocked_reason": "Owner decision", "depends_on": [], "resources": []},
            {"id": "NATIVE-DEPENDENT", "status": "ready", "depends_on": ["NATIVE-BLOCK"], "resources": []},
            {"id": "NATIVE-RESOURCE", "status": "ready", "depends_on": [], "resources": ["shared"]},
            {"id": "NATIVE-INDEPENDENT", "status": "ready", "depends_on": [], "resources": []},
        ]
        state = tasks.reconcile({}, planned, read_json(self.runtime / "contract.json"), [])
        tasks.claim(state, "existing-owner", "NATIVE-OWNER")
        write_json(self.runtime / "tasks.json", state)
        before = {p: p.read_bytes() for p in self.runtime.rglob("*") if p.is_file()}
        with patch.object(handoff, "launch", side_effect=AssertionError("Status must not dispatch")):
            report, code = self.action("status")
        self.assertEqual(code, 0)
        summary = report["task_summary"]
        self.assertEqual(summary["counts"], {"completed": 1, "running": 1, "blocked": 1, "pending": 3, "eligible": 1})
        self.assertEqual(summary["eligible_task_ids"], ["NATIVE-INDEPENDENT"])
        by_id = {task["id"]: task for task in summary["tasks"]}
        self.assertEqual(by_id["NATIVE-DEPENDENT"]["waiting_for"], [{"task_id": "NATIVE-BLOCK", "status": "blocked"}])
        self.assertEqual(by_id["NATIVE-OWNER"]["owner"], "existing-owner")
        self.assertIsNotNone(by_id["NATIVE-OWNER"]["last_event_at"])
        self.assertTrue(summary["projection_only"])
        self.assertFalse(report["scheduler_started"])
        self.assertEqual(before, {p: p.read_bytes() for p in self.runtime.rglob("*") if p.is_file()})

    def test_status_lease_expiry_is_projection_only_and_corrupt_graph_is_explicit(self):
        from demo_builder import tasks
        from demo_builder.workspace import read_json, write_json
        self.start()
        state = tasks.reconcile({}, [{"id": "NATIVE-LEASE", "status": "ready", "depends_on": [], "resources": []}],
                                read_json(self.runtime / "contract.json"), [])
        tasks.claim(state, "existing-owner", "NATIVE-LEASE")
        state["tasks"][0]["lease_until"] = "2000-01-01T00:00:00+00:00"
        write_json(self.runtime / "tasks.json", state)
        before = (self.runtime / "tasks.json").read_bytes()
        report, code = self.action("status")
        self.assertEqual(code, 0)
        task = report["task_summary"]["tasks"][0]
        self.assertEqual((task["stored_status"], task["status"]), ("running", "running"))
        self.assertEqual(task["owner"], "existing-owner")
        self.assertEqual(report["task_summary"]["eligible_task_ids"], [])
        self.assertTrue(task["lease_reconciliation_required"])
        self.assertEqual(before, (self.runtime / "tasks.json").read_bytes())
        state["tasks"][0]["depends_on"] = ["unknown-native-id"]
        write_json(self.runtime / "tasks.json", state)
        with self.assertRaisesRegex(ValueError, "unknown dependency"):
            self.action("status")
        for field, value in (("status", []), ("depends_on", None)):
            with self.subTest(field=field):
                malformed = read_json(self.runtime / "tasks.json")
                malformed["tasks"][0]["depends_on"] = []
                malformed["tasks"][0][field] = value
                write_json(self.runtime / "tasks.json", malformed)
                with self.assertRaises(ValueError):
                    self.action("status")
        state["tasks"][0]["depends_on"] = []
        state["history"] = [{"task": ["invalid-native-id"], "at": "2000-01-01T00:00:00+00:00"}]
        write_json(self.runtime / "tasks.json", state)
        with self.assertRaisesRegex(ValueError, "history"):
            self.action("status")

    def test_status_missing_task_store_is_unavailable_not_zero_count_success(self):
        self.start()
        (self.runtime / "tasks.json").unlink()
        report, code = self.action("status")
        self.assertEqual(code, 2)
        self.assertEqual(report["status"], "blocked")
        self.assertEqual(report["exit_code"], code)
        self.assertEqual(report["recorded_exit_code"], 0)
        self.assertEqual(report["task_summary"]["status"], "unavailable")
        self.assertIsNone(report["task_summary"]["counts"])
        self.assertIn("reconcile", report["task_summary"]["next_action"].lower())

    def test_transient_block_clears_without_input_change_and_native_worker_is_rejected(self):
        self.start()
        original_run = handoff.subprocess.run
        def busy(command, **kwargs):
            if command[:3] == [sys.executable, "-m", "demo_builder"]:
                raise OSError(errno.EBUSY, "controlled temporary launch interruption")
            return original_run(command, **kwargs)
        with patch.object(handoff.subprocess, "run", side_effect=busy):
            blocked, code = self.action("sync")
        self.assertEqual(code, 2)
        self.assertEqual(blocked["category"], "transient")
        self.assertEqual(blocked["history"][-1]["attempts"], 3)
        recovered, code = self.action("sync")
        self.assertEqual(code, 0, recovered)
        self.assertNotIn("replayed", recovered)
        before = {p: p.read_bytes() for p in self.runtime.rglob("*") if p.is_file()}
        with patch.object(handoff.sys, "platform", "win32"):
            with self.assertRaisesRegex(ValueError, "Native Windows worker"):
                self.action("worker")
        self.assertEqual(before, {p: p.read_bytes() for p in self.runtime.rglob("*") if p.is_file()})

    def test_new_synthetic_solution_target_and_stale_stage_receipts(self):
        recipe = json.loads((self.inputs / "recipe.json").read_text())
        environment = json.loads((self.inputs / "environment.json").read_text())
        for document in (recipe, environment):
            document["target"]["solution_unique_name"] = "ConnectedJourneyNew"
        (self.inputs / "recipe.json").write_text(json.dumps(recipe))
        (self.inputs / "environment.json").write_text(json.dumps(environment))
        self.start()
        self.args.action = "rehearse"
        self.args.snapshot = str(self.inputs / "environment.json")
        result, code = handoff.execute(self.args)
        self.assertEqual(code, 0, result)
        self.assertEqual(json.loads((self.runtime / "execution-summary.json").read_text())["target"]["solution_unique_name"],
                         "ConnectedJourneyNew")
        tasks = json.loads((self.runtime / "tasks.json").read_text())
        task = next(t for t in tasks["tasks"] if t["kind"] == "prepare")
        manifest = {"schema_version": "1.0", "project_id": "connected-journey",
            "source": {"id": "existing-work", "revision": "S1", "supersedes": [],
                       "kind": "reviewed_export", "identity": "neutral-test-export", "access": "observed"},
            "records": [{"id": "source-test-receipt", "item_id": "NATIVE-01", "task_id": task["id"],
                "aliases": ["NATIVE-PLAN"], "input_fingerprint": task["fingerprint"],
                "status": "source_ready", "supersedes": [], "evidence": {
                    stage: {"reference": str(self.inputs / "contract.json"),
                            "sha256": handoff.hash_file(self.inputs / "contract.json"),
                            "observed_at": "2026-11-22T00:00:00+00:00"} for stage in ("source", "inspection")}}],
            "decisions": [], "ownership": []}
        path = self.inputs / "adoption.json"
        path.write_text(json.dumps(manifest))
        self.args.action = "start"
        self.args.adoption = str(path)
        self.start()
        contract = json.loads((self.inputs / "contract.json").read_text())
        contract["requirements"][0]["description"] += " New accepted test inputs."
        (self.inputs / "contract.json").write_text(json.dumps(contract))
        self.start()
        build = (self.project / "BUILD.md").read_text()
        self.assertIn("historical-stale", build)
        latest = json.loads((self.runtime / "tasks.json").read_text())
        self.assertIn("NATIVE-PLAN", json.dumps(latest["adoption"]))
        self.assertFalse(any(t["status"] == "completed" for t in latest["tasks"]))


if __name__ == "__main__":
    unittest.main()
