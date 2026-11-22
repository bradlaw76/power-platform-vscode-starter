"""Component: starter H008 handoff verification, version 0.1.0.

File: scripts/ci/test_framework_handoff.py
Environment: Python 3.11+; optional installed framework 0.2.1 and generic fixture.
"""
import argparse
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
import unittest
from unittest.mock import patch

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

    def test_absent_spec_kit_is_noop_without_install_or_workspace(self):
        value, code = handoff.execute(self.args)
        self.assertEqual(code, 0)
        self.assertEqual(value["status"], "not-applicable")
        self.assertFalse(self.project.exists())
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
        self.assertEqual(handoff.classify(subprocess.TimeoutExpired("run", 1)), "uncertain")


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
