"""Component: H009 candidate inventory acceptance, version 0.1.0.

File: scripts/ci/test_wizard_distribution.py
Environment: Python 3.10+ and Git; isolated offline repositories only.
Verifies Git blob integrity and excluded ownership, not publisher authority.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "bootstrap" / "helpers"))
import wizard_distribution as distribution


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="h009-inventory-")
        self.root = Path(self.temporary.name)
        self.policy_path = self.root / "distribution" / "ownership-policy.json"
        self.policy_path.parent.mkdir()
        self.name = "scripts/bootstrap/helpers/example.py"
        path = self.root.joinpath(*self.name.split("/"))
        path.parent.mkdir(parents=True)
        path.write_bytes(b"VALUE = 'original'\n")
        self.policy = {
            "schemaVersion": 1, "inventoryVersion": "1.0.0",
            "repository": distribution.REPOSITORY, "status": "candidate", "automaticApply": False,
            "groups": [{"category": "helper", "consumerAction": "explicit-review", "paths": [self.name]}],
        }
        self.save_policy()
        self.git("init", "--quiet", "-b", "fixture/distribution")
        self.git("config", "user.name", "H009 fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "core.autocrlf", "false")
        self.git("config", "core.hooksPath", str(self.root / "no-hooks"))
        (self.root / ".env").write_text("synthetic-excluded")
        (self.root / "application.py").write_text("synthetic_excluded = True")
        self.git("add", "--", self.name, "distribution/ownership-policy.json", ".env", "application.py")
        self.git("commit", "--quiet", "-m", "Synthetic inventory")
        self.commit = self.git("rev-parse", "HEAD").decode().strip()

    def tearDown(self):
        def writable_remove(function, path, exception):
            os.chmod(path, 0o700)
            function(path)
        shutil.rmtree(self.root, onerror=writable_remove)
        self.temporary.cleanup()

    def git(self, *args):
        environment = {key: value for key, value in os.environ.items()
                       if not key.upper().startswith("GIT_")}
        environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
                           GIT_TERMINAL_PROMPT="0")
        result = subprocess.run(["git", "--no-pager", "-C", str(self.root), *args],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                timeout=15, check=False, env=environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def save_policy(self):
        self.policy_path.write_text(json.dumps(self.policy), encoding="utf-8")

    def test_exact_blob_hashes_ignore_dirty_files_and_exclude_application_and_secrets(self):
        self.root.joinpath(*self.name.split("/")).write_bytes(b"VALUE = 'local edit'\r\n")
        result = distribution.inventory(self.root, self.commit, self.policy_path)
        self.assertEqual([entry["path"] for entry in result["files"]], [self.name])
        self.assertEqual(result["files"][0]["sha256"], hashlib.sha256(b"VALUE = 'original'\n").hexdigest())
        self.assertFalse(result["publisherVerified"])
        self.assertFalse(result["automaticApply"])
        self.assertEqual(result, distribution.inventory(self.root, self.commit, self.policy_path))
        with self.assertRaises(distribution.UpdateError):
            distribution.inventory(self.root, "HEAD", self.policy_path)

    def test_policy_drift_and_missing_or_symlink_blob_fail_closed(self):
        self.policy["groups"][0]["paths"].append("scripts/bootstrap/helpers/missing.py")
        self.save_policy()
        with self.assertRaises(distribution.UpdateError):
            distribution.inventory(self.root, self.commit, self.policy_path)
        self.git("add", "--", "distribution/ownership-policy.json")
        self.git("commit", "--quiet", "-m", "Missing inventory member")
        with self.assertRaises(distribution.UpdateError):
            distribution.inventory(self.root, self.git("rev-parse", "HEAD").decode().strip(), self.policy_path)
        self.policy["groups"][0]["paths"].pop()
        self.save_policy()
        self.git("add", "--", "distribution/ownership-policy.json")
        object_id = self.git("hash-object", "-w", "--", str(self.policy_path)).decode().strip()
        self.git("update-index", "--add", "--cacheinfo", "120000," + object_id + "," + self.name)
        self.git("commit", "--quiet", "-m", "Synthetic Git symlink entry")
        with self.assertRaises(distribution.UpdateError):
            distribution.inventory(self.root, self.git("rev-parse", "HEAD").decode().strip(), self.policy_path)

    def test_protected_paths_case_aliases_and_wrong_categories_are_rejected(self):
        original = deepcopy(self.policy)
        for name in ("../escape.py", ".env", ".git/config", "specs/project/spec.md",
                     "payloads/customer.json", "docs/build-log.md", ".github/workflows/release.yml",
                     "AGENTS.md", r"C:\outside.py", "scripts/bootstrap/helpers/CON.py"):
            self.policy = deepcopy(original)
            self.policy["groups"][0]["paths"] = [name]
            self.save_policy()
            with self.subTest(path=name), self.assertRaises(distribution.UpdateError):
                distribution.load_policy(self.policy_path)
        self.policy = deepcopy(original)
        self.policy["groups"][0]["paths"].append("scripts/bootstrap/helpers/Example.py")
        self.save_policy()
        with self.assertRaises(distribution.UpdateError):
            distribution.load_policy(self.policy_path)
        self.policy = deepcopy(original)
        self.policy["automaticApply"] = True
        self.save_policy()
        with self.assertRaises(distribution.UpdateError):
            distribution.load_policy(self.policy_path)

    def test_real_policy_accepts_framework_schemas_but_never_consumer_payloads(self):
        _, entries = distribution.load_policy(ROOT / "distribution" / "ownership-policy.json")
        self.assertIn("schemas/payloads/table.schema.json", {entry["path"] for entry in entries})
        with self.assertRaises(distribution.UpdateError):
            distribution.eligible("payloads/scenarios/customer/table.json", "schema-profile")

    def test_cli_verifies_exact_inventory_and_rejects_tampering_without_overwrite(self):
        output = self.root / "candidate.json"
        command = [sys.executable, "-B", str(ROOT / "scripts/bootstrap/helpers/wizard_distribution.py"),
                   "--root", str(self.root), "--commit", self.commit, "--policy", str(self.policy_path)]
        for option, expected in (("--output", 0), ("--output", 2), ("--verify", 0)):
            result = subprocess.run([*command, option, str(output)], capture_output=True, timeout=30)
            self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        data = json.loads(output.read_bytes())
        data["automaticApply"] = 0
        output.write_text(json.dumps(data))
        result = subprocess.run([*command, "--verify", str(output)], capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        data["automaticApply"] = False
        data["files"][0]["sha256"] = "0" * 64
        output.write_text(json.dumps(data))
        result = subprocess.run([*command, "--verify", str(output)], capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("differs", json.loads(result.stdout)["error"])


if __name__ == "__main__":
    unittest.main()
