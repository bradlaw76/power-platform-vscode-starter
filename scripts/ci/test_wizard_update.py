"""Component: H009 update functional/security verification, version 0.1.0.

File: scripts/ci/test_wizard_update.py
Environment: Python 3.10+ standard library, Git; optional installed OpenSSL.
Run: python -B scripts/ci/test_wizard_update.py -v
U01-U19 names map the functional, negative, concurrency and crash-recovery cases.
All generated fixtures live in a uniquely owned sibling workspace, outside the source checkout.
"""
from __future__ import annotations

from contextlib import redirect_stdout
from copy import deepcopy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time
import unittest
from unittest.mock import patch
import uuid

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "scripts" / "bootstrap" / "helpers" / "wizard_update.py"
SPEC = importlib.util.spec_from_file_location("wizard_update", ENGINE)
update = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(update)
ALPHA = "scripts/bootstrap/helpers/update-fixture-alpha.py"
BETA = "scripts/bootstrap/helpers/update-fixture-beta.py"
NEW = "scripts/bootstrap/helpers/update-fixture-new.json"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return json.dumps(value, sort_keys=True).encode()


def local_command(args, cwd=None):
    environment = {key: value for key, value in os.environ.items()
                   if not key.upper().startswith("GIT_")}
    environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
                       GIT_TERMINAL_PROMPT="0")
    result = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            timeout=20, check=False, env=environment)
    if result.returncode:
        raise AssertionError(result.stderr.decode(errors="replace"))
    return result.stdout


def remove_fixture_workspace(path):
    def writable_remove(function, name, exception):
        os.chmod(name, stat.S_IWRITE)
        function(name)
    shutil.rmtree(path, onerror=writable_remove)


class WizardUpdateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = ROOT.parent / (".h009-ut-" + uuid.uuid4().hex[:8])
        cls.work.mkdir()
        cls.openssl = shutil.which("openssl")
        if not cls.openssl:
            candidate = Path(r"C:\Program Files\Git\usr\bin\openssl.exe")
            cls.openssl = str(candidate) if candidate.is_file() else None
        if cls.openssl:
            cls.private_key = cls.work / "private.pem"
            cls.public_key = cls.work / "public.pem"
            local_command([cls.openssl, "genpkey", "-algorithm", "RSA", "-pkeyopt",
                           "rsa_keygen_bits:2048", "-out", str(cls.private_key)])
            local_command([cls.openssl, "pkey", "-in", str(cls.private_key),
                           "-pubout", "-out", str(cls.public_key)])

    @classmethod
    def tearDownClass(cls):
        remove_fixture_workspace(cls.work)

    def setUp(self):
        self.case = self.work / (self._testMethodName[5:8] + "-" + uuid.uuid4().hex[:8])
        self.root = self.case / "fixture Ω space"
        self.source = self.case / "source Ω space"
        self.root.mkdir(parents=True)
        self.source.mkdir()
        self.original = {ALPHA: b"VALUE = 'original alpha'\n", BETA: b"VALUE = 'original beta'\n"}
        self.offered = {ALPHA: b"VALUE = 'updated alpha'\n", BETA: b"VALUE = 'updated beta'\n"}
        self.marker = {"kind": "wizard-update-isolated-fixture", "version": 1,
                       "root": str(self.root.resolve()), "nonce": uuid.uuid4().hex}
        (self.root / update.MARKER).write_bytes(encoded(self.marker))
        self.release = {"schemaVersion": "1.0", "product": "power-platform-vscode-starter",
                        "releaseVersion": "1.0.0", "channel": "stable",
                        "compatibility": {"contractVersion": "1.10.0", "profileVersion": "1.6"}}
        (self.root / "wizard.release.json").write_bytes(encoded(self.release))
        for name, data in self.original.items():
            path = self.root.joinpath(*name.split("/"))
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.git("init", "--quiet", "-b", "fixture/h009")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "user.name", "H009 fixture")
        self.git("config", "core.autocrlf", "false")
        self.git("config", "core.hooksPath", str(self.case / "no-hooks"))
        self.git("add", "--", update.MARKER, "wizard.release.json", ALPHA, BETA)
        self.git("commit", "--quiet", "-m", "Independent H009 fixture")
        self.envelope = {
            "schemaVersion": 1, "sourceMode": "fixture", "releaseVersion": "1.1.0",
            "sourceCommit": self.git("rev-parse", "HEAD").decode().strip(), "sourceTag": "v1.1.0",
            "compatibility": {"minRelease": "1.0.0", "maxReleaseExclusive": "2.0.0",
                              "contractVersion": "1.10.0", "profileVersion": "1.6"},
            "files": [], "notes": "Synthetic helper update only; no publisher policy asserted.",
        }
        self.envelope_path = self.case / "envelope.json"
        self.plan_path = self.case / "plan.json"
        self.signature_path = self.case / "envelope.sig"
        self.refresh()

    def git(self, *args):
        return local_command(["git", "--no-pager", "-C", str(self.root), *args], cwd=self.root)

    def refresh(self):
        self.envelope["files"] = []
        for name, data in self.offered.items():
            path = self.source.joinpath(*name.split("/"))
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            self.envelope["files"].append({
                "path": name, "sha256": sha(data), "size": len(data),
                "baselineSha256": sha(self.original[name]) if name in self.original else None,
                "class": "runtime-helper", "scope": "framework",
            })
        self.save_envelope()

    def save_envelope(self):
        self.envelope_path.write_bytes(encoded(self.envelope))
        self.pin = sha(self.envelope_path.read_bytes())

    def arguments(self, command, fixture=True, **extra):
        args = [sys.executable, "-B", str(ENGINE), command, "--root", str(self.root)]
        if fixture:
            args += ["--fixture-root", str(self.root)]
        if command in {"check", "preview", "apply"}:
            args += ["--envelope", str(self.envelope_path), "--trusted-envelope-sha256", self.pin]
        if command in {"preview", "apply"}:
            args += ["--source", str(self.source)]
        for name, value in extra.items():
            if value is not None:
                args += ["--" + name.replace("_", "-")]
                if value is not True:
                    args += [str(value)]
        return args

    def run_cli(self, command, expected=0, env=None, fixture=True, **extra):
        result = subprocess.run(self.arguments(command, fixture=fixture, **extra),
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30,
                                env={**os.environ, **(env or {})})
        self.assertEqual(result.returncode, expected, result.stdout.decode(errors="replace")
                         + result.stderr.decode(errors="replace"))
        self.assertFalse(result.stderr, result.stderr.decode(errors="replace"))
        return json.loads(result.stdout)

    def preview(self):
        if self.plan_path.exists():
            self.plan_path.unlink()
        return self.run_cli("preview", plan=self.plan_path)

    def apply(self, plan=None, expected=0, env=None, fixture=True):
        plan = plan or self.preview()
        return self.run_cli("apply", expected=expected, env=env, fixture=fixture, plan=self.plan_path,
                            approved_plan_sha256=plan["planSha256"])

    def checkpoint(self):
        lock = json.loads((self.root / update.STATE / "lock.json").read_bytes())
        return self.root / update.STATE / "transactions" / lock["transaction"]

    def crash_apply(self, point):
        plan = self.preview()
        result = subprocess.run(
            self.arguments("apply", plan=self.plan_path, approved_plan_sha256=plan["planSha256"]),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30,
            env={**os.environ, "WIZARD_UPDATE_FIXTURE_CRASH": point})
        self.assertEqual(result.returncode, 86, result.stdout + result.stderr)
        return self.checkpoint()

    def assert_original(self):
        for name, data in self.original.items():
            self.assertEqual(self.root.joinpath(*name.split("/")).read_bytes(), data)

    def test_U01_status_is_read_only_and_never_uses_network(self):
        before = {str(path.relative_to(self.root)): sha(path.read_bytes())
                  for path in self.root.rglob("*") if path.is_file()}
        with patch.object(update, "online_metadata", side_effect=AssertionError("network startup")):
            output = io.StringIO()
            with redirect_stdout(output):
                result = update.main(["status", "--root", str(self.root)])
        self.assertEqual(result, 0)
        status = json.loads(output.getvalue())
        self.assertFalse(status["networkUsed"])
        self.assertFalse(status["distribution"]["releaseVerified"])
        self.assertEqual(status["topology"]["git"]["head"], self.git("rev-parse", "HEAD").decode().strip())
        after = {str(path.relative_to(self.root)): sha(path.read_bytes())
                 for path in self.root.rglob("*") if path.is_file()}
        self.assertEqual(before, after)
        self.assertFalse((self.root / update.STATE).exists())
        self.assertEqual(self.run_cli("status")["status"], "offline-unknown")

    def test_U02_topology_distinguishes_clone_consumers_and_downstream(self):
        initial = self.run_cli("status")["topology"]
        self.assertEqual(initial["kind"], "unknown")
        self.assertEqual(initial["inspectionDiagnostics"][0]["operation"], "origin")
        for folder, expected in ((".github", "copilot-only"), (".claude", "claude-only")):
            copied = self.case / folder / "skills" / "copied-wizard"
            copied.mkdir(parents=True)
            (copied / "SKILL.md").write_text("Synthetic copied skill\n", encoding="utf-8")
            result = self.run_cli("status", root=copied, fixture=False)
            self.assertEqual(result["topology"]["kind"], expected)
            self.assertEqual(result["topology"]["inspectionDiagnostics"][0]["operation"], "git-state")
            self.assertFalse((copied / update.STATE).exists())
        with patch.object(update, "git", side_effect=update.UpdateError("Git unavailable")):
            self.assertEqual(update.topology(self.root)["inspectionDiagnostics"],
                             [{"operation": "git-state", "message": "Git unavailable"}])
        for folder, expected in ((".github", "copilot-only"), (".claude", "mixed")):
            (self.root / folder / "skills").mkdir(parents=True)
            self.assertEqual(self.run_cli("status")["topology"]["kind"], expected)
        shutil.rmtree(self.root / ".github")
        self.assertEqual(self.run_cli("status")["topology"]["kind"], "claude-only")
        shutil.rmtree(self.root / ".claude")
        for name in ("README.md", "SYSTEM_MANIFEST.json.md"):
            (self.root / name).write_text("{}")
        self.git("remote", "add", "origin", update.OFFICIAL + ".git")
        self.assertEqual(self.run_cli("status")["topology"]["kind"], "framework-clone")
        self.git("remote", "set-url", "origin", update.OFFICIAL + "-imposter.git")
        self.assertEqual(self.run_cli("status")["topology"]["kind"], "downstream")

    def test_U03_descriptor_does_not_create_release_trust(self):
        for offered in (None, "9.0.0"):
            self.release["releaseVersion"] = offered
            (self.root / "wizard.release.json").write_bytes(encoded(self.release))
            status = self.run_cli("status")
            self.assertFalse(status["distribution"]["releaseVerified"])
            self.assertEqual(status["distribution"]["compatibility"], self.release["compatibility"])
            checked = self.run_cli("check", fixture=False)
            self.assertEqual(checked["status"], "locally-modified")
            self.assertEqual(checked["candidateStatus"], "offline-unknown")
        (self.root / "wizard.release.json").unlink()
        self.assertIsNone(self.run_cli("status")["distribution"]["releaseVersion"])

    def test_U04_check_reports_compatible_incompatible_older_current_and_dirty(self):
        for release, status in (("1.1.0", "newer-compatible"), ("1.0.0", "current"),
                                ("0.9.0", "older-available")):
            self.envelope.update(releaseVersion=release, sourceTag="v" + release)
            self.save_envelope()
            result = self.run_cli("check")
            self.assertEqual(result["status"], status)
            self.assertFalse(result["trust"]["publisherVerified"])
        self.envelope["compatibility"]["profileVersion"] = "incompatible"
        self.save_envelope()
        self.assertEqual(self.run_cli("check")["status"], "incompatible")
        self.root.joinpath(*ALPHA.split("/")).write_text("VALUE = 'local'\n")
        self.assertEqual(self.run_cli("check")["status"], "locally-modified")

    def test_checkout_line_endings_respect_safe_installation_config_without_running_monitor(self):
        home = self.case / "isolated Git home"
        home.mkdir()
        config = home / ".gitconfig"
        sentinel = self.case / "monitor-was-executed"
        monitor = self.case / "monitor.py"
        monitor.write_text("from pathlib import Path\n"
                           f"Path({str(sentinel)!r}).write_text('unexpected execution')\n")
        for key, value in {
            "core.autocrlf": "on", "core.eol": "crlf", "core.safecrlf": "warn",
            "core.fsmonitor": f'"{Path(sys.executable).as_posix()}" "{monitor.as_posix()}"',
        }.items():
            local_command(["git", "config", "--file", str(config), key, value])
        self.git("config", "--unset", "core.autocrlf")
        for name, data in self.original.items():
            self.root.joinpath(*name.split("/")).write_bytes(data.replace(b"\n", b"\r\n"))
        self.git("-c", "core.autocrlf=true", "add", "--", *self.original)
        with patch.dict(os.environ, {"HOME": str(home), "XDG_CONFIG_HOME": str(home / "xdg")}):
            self.assertFalse(update.git_state(self.root)["dirty"])
            self.assertFalse(sentinel.exists())
            self.git("config", "core.autocrlf", "false")
            # Conversion changes alone can retain Git's clean stat cache.
            path = self.root.joinpath(*ALPHA.split("/"))
            info = path.stat()
            os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns + 2_000_000_000))
            self.assertTrue(update.git_state(self.root)["dirty"])
            self.git("config", "core.autocrlf", "true")
            info = path.stat()
            os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns + 2_000_000_000))
            self.assertFalse(update.git_state(self.root)["dirty"])
            self.root.joinpath(*ALPHA.split("/")).write_bytes(b"VALUE = 'human change'\r\n")
            self.assertTrue(update.git_state(self.root)["dirty"])
            self.assertFalse(sentinel.exists())
            self.git("config", "core.eol", "unrecognized")
            with self.assertRaisesRegex(update.UpdateError, "Invalid Git line-ending configuration"):
                update.git_state(self.root)

    def test_U05_explicit_online_metadata_is_bounded_unsigned_and_stable_only(self):
        data = encoded([
            {"tag_name": "v1.2.0", "draft": False, "prerelease": False},
            {"tag_name": "v1.3.0-beta", "draft": False, "prerelease": True},
            {"tag_name": "v2.0.0", "draft": True},
        ])
        with patch.object(update, "execute", return_value=data) as fetch:
            output = io.StringIO()
            with redirect_stdout(output):
                self.assertEqual(update.main(["check", "--root", str(self.root), "--online"]), 0)
            checked = json.loads(output.getvalue())
            self.assertTrue(checked["networkUsed"])
            self.assertEqual(checked["status"], "unverified")
            self.assertEqual(checked["remoteMetadata"]["stableTags"], ["v1.2.0"])
            self.assertEqual(fetch.call_args.args[0][:4], [sys.executable, "-I", "-S", "-c"])
            self.assertEqual(fetch.call_args.kwargs["limit"], 256 * 1024)
            self.assertIn("timeout=5", fetch.call_args.args[0][-1])
            self.assertIn(update.RELEASES, fetch.call_args.args[0][-1])
            fetch.side_effect = update.UpdateError("Subprocess output exceeds budget")
            self.assertEqual(update.online_metadata()["availability"], "unavailable")
        result = self.run_cli("status", expected=2, online=True)
        self.assertIn("only", result["error"])

    def test_U06_independent_pin_and_optional_rsa_verify_exact_envelope_bytes(self):
        self.pin = "0" * 64
        self.assertIn("digest", self.run_cli("preview", expected=2)["error"])
        self.save_envelope()
        plan = self.preview()
        self.assertIn("not-publisher", plan["trust"]["provenance"])
        if self.openssl:
            local_command([self.openssl, "dgst", "-sha256", "-sign", str(self.private_key),
                           "-out", str(self.signature_path), str(self.envelope_path)])
            args = dict(signature=self.signature_path, trust_key=self.public_key, openssl_path=self.openssl)
            signed = self.run_cli("preview", **args)
            self.assertTrue(signed["trust"]["signed"])
            self.envelope_path.write_bytes(self.envelope_path.read_bytes() + b"\n")
            self.pin = sha(self.envelope_path.read_bytes())
            self.run_cli("preview", expected=2, **args)
            self.save_envelope()
            self.run_cli("preview", expected=2, signature=self.signature_path)
            self.run_cli("preview", expected=2, **{**args, "openssl_path": "openssl"})
        else:
            self.run_cli("preview", expected=2, signature=self.signature_path)

    def test_U07_ownership_rejects_traversal_ads_reserved_protected_and_collisions(self):
        baseline = deepcopy(self.envelope)
        invalid = ["../escape.py", "/root.py", r"C:\evil.py", r"scripts\bootstrap\helpers\evil.py",
                   "scripts/bootstrap/helpers/../evil.py", "scripts/bootstrap/helpers/update-fixture-a.py:ads",
                   "scripts/bootstrap/helpers/update-fixture-a.py.", "scripts/bootstrap/helpers/update-fixture-a.py ",
                   "scripts/bootstrap/helpers/CON.py", "scripts/bootstrap/helpers/LPT1.json",
                   "scripts//bootstrap/helpers/update-fixture-a.py", ".git/config", ".env",
                   "specs/a.py", "payloads/a.py", "solutions/a.py", ".wizard-metrics/a.py",
                   ".github/copilot-instructions.md", ".claude/skills/a.py", "AGENTS.md", "CLAUDE.md",
                   "scripts/bootstrap/helpers/wizard_update.py", "scripts/bootstrap/helpers/update-fixture-a.ps1",
                   "scripts/bootstrap/helpers/update-fixture-\x00.py"]
        for path in invalid:
            with self.subTest(path=repr(path)):
                self.envelope = deepcopy(baseline)
                self.envelope["files"][0]["path"] = path
                self.save_envelope()
                self.run_cli("preview", expected=2)
        self.envelope = deepcopy(baseline)
        self.envelope["files"].append(deepcopy(self.envelope["files"][0]))
        self.save_envelope()
        self.assertIn("Duplicate", self.run_cli("preview", expected=2)["error"])
        self.assert_original()

    def test_U08_envelope_requires_complete_stable_bounded_explicit_contract(self):
        original = deepcopy(self.envelope)
        variants = [
            {"releaseVersion": "1.1.0-rc.1"}, {"releaseVersion": "01.1.0"},
            {"schemaVersion": True},
            {"sourceCommit": "HEAD"}, {"sourceTag": "latest"}, {"hooks": ["anything"]},
            {"files": []}, {"notes": "x" * 8193},
            {"compatibility": {"profileVersion": "1.6"}},
        ]
        for changes in variants:
            with self.subTest(changes=list(changes)):
                self.envelope = {**deepcopy(original), **changes}
                self.save_envelope()
                self.run_cli("preview", expected=2)
        self.envelope_path.write_bytes(b'{"schemaVersion":1,"schemaVersion":1}')
        self.pin = sha(self.envelope_path.read_bytes())
        self.run_cli("preview", expected=2)
        self.envelope_path.write_bytes(b'{"schemaVersion":NaN}')
        self.pin = sha(self.envelope_path.read_bytes())
        self.run_cli("preview", expected=2)
        self.assert_original()

    def test_U09_source_inventory_hash_size_syntax_and_extra_files_are_enforced(self):
        target = self.source.joinpath(*ALPHA.split("/"))
        for replacement in (b"tamper", b"if syntax invalid\n"):
            target.write_bytes(replacement)
            self.run_cli("preview", expected=2)
        self.offered[ALPHA] = b"if syntax invalid\n"
        self.refresh()
        self.assertIn("syntax", self.run_cli("preview", expected=2)["error"])
        self.offered[ALPHA] = b"VALUE = 'valid'\n"
        self.refresh()
        extra = self.source / "unexpected.json"
        extra.write_text("{}")
        self.run_cli("preview", expected=2)
        extra.unlink()
        nested = self.source / ".git"
        nested.mkdir()
        self.run_cli("preview", expected=2)
        nested.rmdir()
        target.unlink()
        self.run_cli("preview", expected=2)
        self.assert_original()

    def test_U10_approved_plan_binds_exact_inputs_target_bytes_and_approval(self):
        plan = self.preview()
        self.run_cli("apply", expected=2, plan=self.plan_path, approved_plan_sha256="0" * 64)
        tampered = deepcopy(plan)
        tampered["sourceCommit"] = "b" * 40
        self.plan_path.write_bytes(encoded(tampered))
        self.apply(plan, expected=2)
        self.plan_path.write_bytes(encoded(plan))
        self.source.joinpath(*ALPHA.split("/")).write_bytes(b"VALUE = 'late source'\n")
        self.apply(plan, expected=2)
        self.refresh()
        self.envelope["notes"] += " changed exact signed bytes"
        self.save_envelope()
        self.apply(plan, expected=2)
        self.assert_original()

    def test_U11_successful_apply_preserves_git_branch_head_and_selective_manifest(self):
        before_head = self.git("rev-parse", "HEAD")
        before_branch = self.git("branch", "--show-current")
        plan = self.preview()
        result = self.apply(plan)
        self.assertEqual(result["status"], "applied")
        self.assertFalse(result["commitCreated"])
        self.assertFalse(result["stagingPerformed"])
        self.assertEqual(result["selectiveStagingPaths"], [ALPHA, BETA])
        for name, data in self.offered.items():
            self.assertEqual(self.root.joinpath(*name.split("/")).read_bytes(), data)
        self.assertEqual(before_head, self.git("rev-parse", "HEAD"))
        self.assertEqual(before_branch, self.git("branch", "--show-current"))
        self.assertFalse(self.git("diff", "--cached", "--name-only"))
        checkpoint = Path(result["transaction"])
        journal = json.loads((checkpoint / "journal.json").read_bytes())
        self.assertEqual(journal["phase"], "complete")
        self.assertEqual((checkpoint / "0.backup").read_bytes(), self.original[ALPHA])
        self.assertFalse((self.root / update.STATE / "lock.json").exists())
        self.assertFalse(result.get("publisherVerified", False))

    def test_U12_new_file_recovery_requires_manual_removal_and_retains_backups(self):
        self.offered[NEW] = b'{"value":"new"}\n'
        self.refresh()
        result = self.apply()
        transaction = Path(result["transaction"])
        first = self.run_cli("recover", transaction=transaction)
        self.assertEqual(first["status"], "recovery-blocked")
        self.assertEqual(first["manualRemovalRequired"], [NEW])
        self.assertTrue(self.root.joinpath(*NEW.split("/")).exists())
        self.assert_original()
        self.root.joinpath(*NEW.split("/")).unlink()
        second = self.run_cli("recover", transaction=transaction)
        self.assertEqual(second["status"], "recovered")
        self.assertTrue((transaction / "0.backup").is_file())
        self.assertEqual(self.run_cli("recover", transaction=transaction)["status"], "recovered")

    def test_completed_transaction_replay_is_read_only_and_rejects_input_or_target_drift(self):
        plan = self.preview()
        applied = self.apply(plan)

        def inventory():
            return {str(path.relative_to(self.root)): (
                path.is_dir(), path.stat().st_mtime_ns,
                None if path.is_dir() else sha(path.read_bytes()))
                for path in (self.root, *self.root.rglob("*"))}

        before = inventory()
        checked = self.run_cli("check")
        self.assertEqual(checked["status"], "current")
        self.assertEqual(checked["candidateStatus"], "current")
        self.assertEqual(checked["fixtureInstalledRelease"]["releaseVersion"], "1.1.0")
        self.assertFalse(checked["fixtureInstalledRelease"]["publisherVerified"])
        self.assertFalse(checked["fixtureInstalledRelease"]["releaseVerified"])
        self.assertFalse(checked["distribution"]["releaseVerified"])
        self.assertEqual(inventory(), before)
        replay = self.apply(plan)
        self.assertEqual(replay["status"], "already-applied")
        self.assertEqual(replay["transaction"], applied["transaction"])
        self.assertEqual(inventory(), before)
        source = self.source.joinpath(*ALPHA.split("/"))
        source.write_bytes(b"VALUE = 'changed source'\n")
        self.run_cli("check", expected=2, source=self.source)
        self.apply(plan, expected=2)
        self.assertEqual(inventory(), before)
        source.write_bytes(self.offered[ALPHA])
        descriptor = self.root / "wizard.release.json"
        descriptor_bytes = descriptor.read_bytes()
        descriptor.write_bytes(encoded({**self.release, "channel": "changed metadata"}))
        drifted = inventory()
        self.apply(plan, expected=2)
        self.assertEqual(inventory(), drifted)
        descriptor.write_bytes(descriptor_bytes)
        installed = self.root.joinpath(*ALPHA.split("/"))
        installed.write_bytes(b"VALUE = 'edited installed helper'\n")
        drifted = inventory()
        self.run_cli("check", expected=2)
        self.apply(plan, expected=2)
        self.assertEqual(inventory(), drifted)

    @unittest.skipUnless(os.name == "posix", "POSIX permission-bit preservation")
    def test_posix_executable_mode_and_original_mtime_survive_apply_and_recovery(self):
        target = self.root.joinpath(*ALPHA.split("/"))
        target.chmod(0o755)
        self.git("config", "core.filemode", "true")
        self.git("add", "--", ALPHA)
        self.git("commit", "--amend", "--quiet", "--no-edit")
        self.envelope["sourceCommit"] = self.git("rev-parse", "HEAD").decode().strip()
        self.save_envelope()
        os.utime(target, ns=(target.stat().st_atime_ns, 1600000000123456789))
        original_metadata = update.file_metadata(target)
        plan = self.preview()
        self.assertEqual(plan["targetMetadata"][ALPHA], original_metadata)
        applied = self.apply(plan)
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o755)
        transaction = Path(applied["transaction"])
        journal_path = transaction / "journal.json"
        journal = json.loads(journal_path.read_bytes())
        self.assertEqual(journal["baselineMetadata"], plan["targetMetadata"])
        self.assertEqual(journal["replacementMetadata"][ALPHA], update.file_metadata(target))
        tampered = deepcopy(journal)
        tampered["baselineMetadata"][ALPHA]["mode"] = 0o644
        journal_path.write_bytes(encoded(tampered))
        self.run_cli("recover", expected=2, transaction=transaction)
        self.assertEqual(target.read_bytes(), self.offered[ALPHA])
        journal_path.write_bytes(encoded(journal))
        self.assertEqual(self.run_cli("recover", transaction=transaction)["status"], "recovered")
        self.assertEqual(update.file_metadata(target), original_metadata)
        self.assertEqual(target.read_bytes(), self.original[ALPHA])

    @unittest.skipUnless(os.name == "nt", "Windows read-only attribute protection")
    def test_windows_read_only_target_is_never_made_writable_or_replaced(self):
        target = self.root.joinpath(*ALPHA.split("/"))
        target.chmod(stat.S_IREAD)
        try:
            original_metadata = update.file_metadata(target)
            plan = self.preview()
            self.apply(plan, expected=2)
            self.assertEqual(update.file_metadata(target), original_metadata)
            self.assertEqual(target.read_bytes(), self.original[ALPHA])
            self.assertFalse((self.root / update.STATE).exists())
        finally:
            target.chmod(stat.S_IREAD | stat.S_IWRITE)

    def test_U13_official_consumer_main_remote_and_framework_bypass_are_blocked(self):
        plan = self.preview()
        self.apply(plan, fixture=False, expected=2)
        self.git("remote", "add", "origin", update.OFFICIAL + ".git")
        self.apply(plan, expected=2)
        self.git("remote", "remove", "origin")
        self.git("branch", "-m", "main")
        self.apply(plan, expected=2)
        self.git("branch", "-m", "fixture/h009")
        for marker in ("README.md", "SYSTEM_MANIFEST.json.md", ".github", ".claude"):
            path = self.root / marker
            path.mkdir() if marker.startswith(".") else path.write_text("{}")
            self.apply(plan, expected=2)
            path.rmdir() if path.is_dir() else path.unlink()
        self.envelope["sourceMode"] = "official"
        self.save_envelope()
        self.run_cli("preview", expected=2)
        self.assert_original()

    def test_U14_exclusive_lock_preserves_stale_owner_and_rejects_concurrent_apply(self):
        plan = self.preview()
        state = self.root / update.STATE
        state.mkdir()
        lock = state / "lock.json"
        stale = b'{"pid":0,"transaction":"do-not-clear"}'
        lock.write_bytes(stale)
        self.apply(plan, expected=2)
        self.assertEqual(lock.read_bytes(), stale)
        self.assertEqual(self.run_cli("status")["updateLock"]["state"], "unverified")
        lock.unlink()
        args = self.arguments("apply", plan=self.plan_path, approved_plan_sha256=plan["planSha256"])
        process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   env={**os.environ, "WIZARD_UPDATE_FIXTURE_PAUSE": "after-lock"})
        try:
            deadline = time.monotonic() + 10
            while not lock.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(lock.exists())
            self.assertEqual(self.run_cli("status")["updateLock"]["state"], "owner-running-or-unverifiable")
            self.apply(plan, expected=2)
            self.run_cli("recover", expected=2, transaction=self.checkpoint())
            out, err = process.communicate(timeout=20)
            self.assertEqual(process.returncode, 0, out + err)
            self.assertEqual(json.loads(out)["status"], "applied")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)

    def test_U15_actual_process_crashes_recover_before_and_after_atomic_writes(self):
        for point in ("after-lock", "prepared", "before-replace-0", "after-replace-0", "after-replace-1"):
            with self.subTest(crash=point):
                transaction = self.crash_apply(point)
                self.assertEqual(self.run_cli("status")["updateLock"]["state"], "owner-not-running")
                recovered = self.run_cli("recover", transaction=transaction)
                self.assertEqual(recovered["status"], "recovered")
                self.assertTrue(recovered["backupsRetained"])
                self.assert_original()
                self.assertFalse((self.root / update.STATE / "lock.json").exists())

    def test_U16_recovery_preserves_concurrent_edits_and_releases_only_after_resolution(self):
        transaction = self.crash_apply("after-replace-0")
        path = self.root.joinpath(*ALPHA.split("/"))
        concurrent = b"VALUE = 'concurrent user edit'\n"
        path.write_bytes(concurrent)
        result = self.run_cli("recover", transaction=transaction)
        self.assertEqual(result["conflicts"], [ALPHA])
        self.assertEqual(path.read_bytes(), concurrent)
        self.assertTrue((self.root / update.STATE / "lock.json").exists())
        path.write_bytes(self.original[ALPHA])
        self.assertEqual(self.run_cli("recover", transaction=transaction)["conflicts"], [ALPHA])
        journal = json.loads((transaction / "journal.json").read_bytes())
        original_metadata = journal["baselineMetadata"][ALPHA]
        os.utime(path, ns=(path.stat().st_atime_ns, original_metadata["mtimeNs"]))
        self.assertEqual(self.run_cli("recover", transaction=transaction)["status"], "recovered")
        self.assert_original()

    def test_U17_recovery_guards_checkpoint_root_plan_and_backup_integrity(self):
        transaction = self.crash_apply("after-replace-0")
        self.run_cli("recover", expected=2, transaction=self.case)
        self.git("branch", "-m", "fixture/changed")
        self.run_cli("recover", expected=2, transaction=transaction)
        self.git("branch", "-m", "fixture/h009")
        backup = transaction / "0.backup"
        original_backup = backup.read_bytes()
        backup.write_bytes(b"malicious backup")
        self.run_cli("recover", expected=2, transaction=transaction)
        self.assertEqual(self.root.joinpath(*ALPHA.split("/")).read_bytes(), self.offered[ALPHA])
        backup.write_bytes(original_backup)
        journal_path = transaction / "journal.json"
        journal = json.loads(journal_path.read_bytes())
        changed = deepcopy(journal)
        changed["files"][0]["path"] = "../outside"
        journal_path.write_bytes(encoded(changed))
        self.run_cli("recover", expected=2, transaction=transaction)
        journal_path.write_bytes(encoded(journal))
        plan_path = transaction / "plan.json"
        saved = plan_path.read_bytes()
        changed_plan = json.loads(saved)
        changed_plan["root"] = str(self.case)
        plan_path.write_bytes(encoded(changed_plan))
        self.run_cli("recover", expected=2, transaction=transaction)
        plan_path.write_bytes(saved)
        self.assertEqual(self.run_cli("recover", transaction=transaction)["status"], "recovered")
        self.assert_original()

    def test_U18_symlink_junction_nested_git_and_case_collision_are_rejected(self):
        payload_parent = self.source / "scripts" / "bootstrap" / "helpers"
        nested = payload_parent / ".git"
        nested.mkdir()
        self.run_cli("preview", expected=2)
        nested.rmdir()
        saved = deepcopy(self.envelope)
        self.envelope["files"].append({**self.envelope["files"][0], "path": ALPHA.upper()})
        self.save_envelope()
        self.run_cli("preview", expected=2)
        self.envelope = saved
        self.save_envelope()
        alias = self.case / "source alias"
        if os.name == "nt":
            result = subprocess.run(["cmd.exe", "/c", "mklink", "/J", str(alias), str(self.source)],
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            alias.symlink_to(self.source, target_is_directory=True)
        try:
            self.run_cli("preview", expected=2, source=alias)
        finally:
            alias.rmdir() if os.name == "nt" else alias.unlink()
        destination_parent = self.root / "scripts" / "bootstrap" / "helpers"
        outsider = self.case / "outside helpers"
        destination_parent.rename(outsider)
        if os.name == "nt":
            local_command(["cmd.exe", "/c", "mklink", "/J", str(destination_parent), str(outsider)])
        else:
            destination_parent.symlink_to(outsider, target_is_directory=True)
        try:
            self.run_cli("preview", expected=2)
        finally:
            destination_parent.rmdir() if os.name == "nt" else destination_parent.unlink()
            outsider.rename(destination_parent)
        self.assert_original()
        self.offered[NEW] = b'{"value":"new"}\n'
        self.refresh()
        existing_case_alias = destination_parent / Path(NEW).name.upper()
        existing_case_alias.write_bytes(b'{"value":"existing case alias"}\n')
        self.run_cli("preview", expected=2)
        self.assertEqual(existing_case_alias.read_bytes(), b'{"value":"existing case alias"}\n')

    def test_U19_bounded_subprocesses_dirty_revalidation_and_nonfixture_crash_guard(self):
        with self.assertRaises(update.UpdateError):
            update.execute([sys.executable, "-c", "print('x' * 100000)"], limit=1024)
        plan = self.preview()
        self.root.joinpath(*BETA.split("/")).write_bytes(b"VALUE = 'local concurrent edit'\n")
        self.apply(plan, expected=2)
        self.assertEqual(self.root.joinpath(*ALPHA.split("/")).read_bytes(), self.original[ALPHA])
        self.root.joinpath(*BETA.split("/")).write_bytes(self.original[BETA])
        plan = self.preview()
        self.apply(plan, expected=2, fixture=False,
                   env={"WIZARD_UPDATE_FIXTURE_CRASH": "after-replace-0"})
        self.assert_original()
        self.assertFalse((self.root / update.STATE).exists())
        process = subprocess.Popen(
            self.arguments("apply", plan=self.plan_path, approved_plan_sha256=plan["planSha256"]),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            env={**os.environ, "WIZARD_UPDATE_FIXTURE_PAUSE": "after-lock"})
        try:
            lock = self.root / update.STATE / "lock.json"
            deadline = time.monotonic() + 10
            while not lock.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(lock.exists())
            concurrent = b"VALUE = 'changed after lock'\n"
            self.root.joinpath(*ALPHA.split("/")).write_bytes(concurrent)
            stdout, stderr = process.communicate(timeout=20)
            self.assertEqual(process.returncode, 2, stdout + stderr)
            self.assertEqual(self.root.joinpath(*ALPHA.split("/")).read_bytes(), concurrent)
            self.assertEqual(self.root.joinpath(*BETA.split("/")).read_bytes(), self.original[BETA])
            self.assertEqual(self.run_cli("recover", transaction=self.checkpoint())["status"], "recovered")
            self.assertEqual(self.root.joinpath(*ALPHA.split("/")).read_bytes(), concurrent)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)

    def test_signed_lifecycle_through_terminal_and_agent_shared_entry_point(self):
        pwsh = shutil.which("pwsh")
        if not pwsh or not self.openssl:
            self.skipTest("Actual shared-command lifecycle requires PowerShell and OpenSSL")
        wrapper = ROOT / "scripts" / "bootstrap" / "04-check-wizard-update.ps1"
        local_command([self.openssl, "dgst", "-sha256", "-sign", str(self.private_key),
                       "-out", str(self.signature_path), str(self.envelope_path)])

        def invoke(action, expected=0, crash=None, **options):
            command = [pwsh, "-NoProfile", "-NonInteractive", "-File", str(wrapper),
                       "-Action", action, "-RuntimeRoot", str(self.root),
                       "-PythonExecutable", sys.executable, "-FixtureRoot", str(self.root), "-AsJson"]
            if action in {"Check", "Review", "Update"}:
                options.update(EnvelopePath=self.envelope_path, SignaturePath=self.signature_path,
                               TrustKeyPath=self.public_key, OpenSslPath=self.openssl)
            for name, value in options.items():
                command += ["-" + name, str(value)]
            process = subprocess.run(
                command, capture_output=True, timeout=45,
                env={**os.environ, "WIZARD_UPDATE_FIXTURE_CRASH": crash or ""})
            self.assertEqual(process.returncode, expected, process.stdout + process.stderr)
            if expected == 86:
                print("H009-LIFECYCLE " + json.dumps({"action": action, "crashExit": 86}))
                return None
            result = json.loads(process.stdout.decode("utf-8-sig"))
            print("H009-LIFECYCLE " + json.dumps({"action": action, "output": result}, sort_keys=True))
            return result

        self.assertIsNone(invoke("Status")["installedRelease"])
        checked = invoke("Check")
        self.assertEqual(checked["distribution"]["releaseVersion"], "1.0.0")
        self.assertEqual(checked["status"], "newer-compatible")
        self.assertTrue(checked["trust"]["signed"])
        self.assertFalse(checked["trust"]["publisherVerified"])
        plan = invoke("Review", SourcePath=self.source, PlanPath=self.plan_path)
        self.assertEqual([item["path"] for item in plan["files"]], [ALPHA, BETA])
        approved = dict(SourcePath=self.source, PlanPath=self.plan_path,
                        ApprovedPlanSha256=plan["planSha256"])
        applied = invoke("Update", **approved)
        self.assertEqual(applied["status"], "applied")
        for name, data in self.offered.items():
            self.assertEqual(self.root.joinpath(*name.split("/")).read_bytes(), data)
        self.assertEqual(invoke("Check")["status"], "current")
        before = {str(path.relative_to(self.root)): (sha(path.read_bytes()), path.stat().st_mtime_ns)
                  for path in self.root.rglob("*") if path.is_file()}
        self.assertEqual(invoke("Update", **approved)["status"], "already-applied")
        after = {str(path.relative_to(self.root)): (sha(path.read_bytes()), path.stat().st_mtime_ns)
                 for path in self.root.rglob("*") if path.is_file()}
        self.assertEqual(before, after)
        self.assertEqual(invoke("Recover", TransactionPath=applied["transaction"])["status"], "recovered")
        self.assert_original()
        self.plan_path.unlink()
        plan = invoke("Review", SourcePath=self.source, PlanPath=self.plan_path)
        approved["ApprovedPlanSha256"] = plan["planSha256"]
        invoke("Update", expected=86, crash="after-replace-0", **approved)
        self.assertEqual(invoke("Recover", TransactionPath=self.checkpoint())["status"], "recovered")
        self.assert_original()
        self.envelope_path.write_bytes(self.envelope_path.read_bytes() + b"\n")
        self.assertEqual(invoke("Check", expected=2)["status"], "blocked")
        self.assertEqual(invoke("Skip")["status"], "skipped")
        self.assert_original()


class InstructionMigrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = ROOT.parent / (".instruction-ut-" + uuid.uuid4().hex[:8])
        cls.work.mkdir()
        cls.runtime = cls.work / "current runtime"
        cls.engine = cls.runtime / "scripts" / "bootstrap" / "helpers" / "wizard_update.py"
        cls.engine.parent.mkdir(parents=True)
        shutil.copy2(ENGINE, cls.engine)
        shutil.copy2(ROOT / "scripts/bootstrap/helpers/wizard-version.ps1", cls.engine.parent)
        shutil.copy2(ROOT / "scripts/bootstrap/04-check-wizard-update.ps1", cls.engine.parent.parent)
        shutil.copy2(ROOT / "scripts/bootstrap/05-start-wizard.ps1", cls.engine.parent.parent)
        (cls.runtime / "distribution").mkdir()
        shutil.copy2(ROOT / "distribution/ownership-policy.json", cls.runtime / "distribution")
        for name in update.INSTRUCTION_PATHS:
            source = ROOT.joinpath(*name.split("/"))
            if source.exists():
                target = cls.runtime.joinpath(*name.split("/"))
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read_bytes())

    @classmethod
    def tearDownClass(cls):
        remove_fixture_workspace(cls.work)

    def setUp(self):
        self.case = self.work / uuid.uuid4().hex
        self.root = self.case / "Cedar Civic project"
        self.previous = self.case / "previous runtime"
        self.root.mkdir(parents=True)
        self.previous.mkdir()
        self.plan_path = self.case / "review.json"
        self.accepted = b"# Cedar Civic Services\nAccepted fictional requirements; no new planning package.\n"
        (self.root / "accepted-spec.md").write_bytes(self.accepted)

    def initialize_git(self):
        local_command(["git", "init", "-q", "-b", "development/instructions"], self.root)
        for key, value in (("user.name", "Fictional fixture"), ("user.email", "fixture@example.invalid"),
                           ("core.autocrlf", "false")):
            local_command(["git", "config", key, value], self.root)
        local_command(["git", "add", "."], self.root)
        local_command(["git", "commit", "-qm", "Independent fictional project"], self.root)

    def legacy(self, customized=False):
        self.prefix = b"# Project security\r\nProduction publication is forbidden.\r\n"
        self.suffix = b"\r\n# Project requirements\r\nKeep the accepted service lifecycle.  \r\n"
        for name in update.INSTRUCTION_PATHS[:3]:
            body = ("# Recognized previous " + name + "\nRoutine source work required a full dossier.\n").encode()
            old = self.previous.joinpath(*name.split("/"))
            old.parent.mkdir(parents=True, exist_ok=True)
            old.write_bytes(body)
            target = self.root.joinpath(*name.split("/"))
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(self.prefix + body.replace(b"\n", b"\r\n") + self.suffix if customized else body)

    def command(self, action, *options, expected=0, crash=None):
        args = [sys.executable, "-B", str(self.engine), action, "--root", str(self.root),
                "--instruction-source", str(self.runtime), *map(str, options)]
        environment = dict(os.environ)
        if crash:
            environment["WIZARD_UPDATE_FIXTURE_CRASH"] = crash
            args += ["--fixture-root", str(self.root)]
        result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                env=environment, timeout=45, check=False)
        self.assertEqual(result.returncode, expected, result.stdout.decode(errors="replace") +
                         result.stderr.decode(errors="replace"))
        return json.loads(result.stdout) if expected != 86 else None

    def review(self, legacy=False):
        self.options = ["--plan", str(self.plan_path)]
        if legacy:
            self.options += ["--previous-instructions", str(self.previous)]
        self.plan = self.command("preview", *self.options)
        self.options += ["--approved-plan-sha256", self.plan["planSha256"]]
        return self.plan

    def checkpoint(self):
        return next((self.root / update.STATE / "transactions").iterdir())

    def test_clean_install_and_explicit_scoped_rollback(self):
        self.initialize_git()
        plan = self.review()
        self.assertIn("AGENTS.md", plan["instructionDiffs"])
        self.assertFalse((self.root / "AGENTS.md").exists())
        result = self.command("apply", *self.options)
        self.assertTrue(result["instructionCompatibilityVerified"])
        self.assertFalse(result["runtimeUpdated"])
        self.assertFalse(plan["releaseVerified"])
        self.assertEqual(self.command("apply", *self.options)["status"], "already-applied")
        status = self.command("check")
        self.assertEqual(status["status"], "current")
        installed = (self.root / "AGENTS.md").read_bytes()
        refused = self.command("recover", "--transaction", result["transaction"],
                               "--remove-created-instructions", "--approved-plan-sha256", "0" * 64, expected=2)
        self.assertEqual(refused["status"], "blocked")
        self.assertEqual((self.root / "AGENTS.md").read_bytes(), installed)
        held = self.command("recover", "--transaction", result["transaction"])
        self.assertEqual(held["status"], "recovery-blocked")
        restored = self.command("recover", "--transaction", result["transaction"],
                                "--remove-created-instructions", "--approved-plan-sha256", plan["planSha256"])
        self.assertEqual(restored["status"], "recovered")
        self.assertFalse((self.root / "AGENTS.md").exists())
        self.assertEqual((self.root / "accepted-spec.md").read_bytes(), self.accepted)

    def test_actual_new_project_initializer_is_current_in_shared_migration(self):
        if not shutil.which("pwsh"):
            self.skipTest("PowerShell initializer unavailable on this host")
        self.initialize_git()
        local_command(["pwsh", "-NoProfile", "-File",
                       str(self.runtime / "scripts/bootstrap/05-start-wizard.ps1"),
                       "-WorkspaceRoot", str(self.root), "-InitializeInstructionsOnly"])
        status = self.command("check")
        self.assertEqual(status["status"], "current")
        self.assertEqual(status["files"], [])
        self.assertEqual((self.root / "accepted-spec.md").read_bytes(), self.accepted)

    def test_existing_customizations_and_backup_restore(self):
        self.legacy(customized=True)
        self.initialize_git()
        before = {name: self.root.joinpath(*name.split("/")).read_bytes()
                  for name in update.INSTRUCTION_PATHS[:3]}
        plan = self.review(legacy=True)
        result = self.command("apply", *self.options)
        for name, original in before.items():
            after = self.root.joinpath(*name.split("/")).read_bytes()
            self.assertTrue(after.startswith(self.prefix))
            self.assertTrue(after.endswith(self.suffix))
            self.assertIn(self.runtime.joinpath(*name.split("/")).read_bytes(), after)
            index = next(i for i, item in enumerate(plan["files"]) if item["path"] == name)
            self.assertEqual((Path(result["transaction"]) / f"{index}.backup").read_bytes(), original)
        restored = self.command("recover", "--transaction", result["transaction"],
                                "--remove-created-instructions", "--approved-plan-sha256", plan["planSha256"])
        self.assertEqual(restored["status"], "recovered")
        for name, original in before.items():
            self.assertEqual(self.root.joinpath(*name.split("/")).read_bytes(), original)
        self.assertEqual((self.root / "accepted-spec.md").read_bytes(), self.accepted)

    def test_unknown_customized_body_is_not_overwritten(self):
        self.legacy()
        target = self.root / "AGENTS.md"
        target.write_bytes(b"Unrecognized stricter project instructions.\n")
        self.initialize_git()
        before = target.read_bytes()
        result = self.command("preview", "--previous-instructions", self.previous, expected=2)
        self.assertEqual(result["status"], "blocked")
        self.assertEqual(target.read_bytes(), before)
        self.assertFalse((self.root / update.STATE).exists())

    def test_changed_target_and_active_writer_are_held(self):
        self.legacy()
        self.initialize_git()
        self.review(legacy=True)
        state = self.root / update.STATE
        state.mkdir()
        lock = state / "lock.json"
        lock.write_bytes(encoded({"root": str(self.root), "transaction": uuid.uuid4().hex,
                                  "token": uuid.uuid4().hex, "pid": os.getpid()}))
        self.assertEqual(self.command("apply", *self.options, expected=2)["status"], "blocked")
        self.assertTrue(lock.exists())
        lock.unlink()
        target = self.root / "AGENTS.md"
        target.write_bytes(target.read_bytes() + b"Later project-specific instruction.\n")
        before = target.read_bytes()
        self.assertEqual(self.command("apply", *self.options, expected=2)["status"], "blocked")
        self.assertEqual(target.read_bytes(), before)

    def test_interrupted_shared_transaction_recovers_and_reuses_plan(self):
        self.initialize_git()
        plan = self.review()
        self.command("apply", *self.options, crash="after-replace-0", expected=86)
        transaction = self.checkpoint()
        journal = json.loads((transaction / "journal.json").read_bytes())
        self.assertEqual(journal["files"][0]["phase"], "writing")
        result = self.command("recover", "--transaction", transaction, "--remove-created-instructions",
                              "--approved-plan-sha256", plan["planSha256"])
        self.assertEqual(result["status"], "recovered")
        self.assertEqual(self.command("apply", *self.options)["status"], "applied")
        self.assertEqual((self.root / "accepted-spec.md").read_bytes(), self.accepted)

    def test_newer_human_edits_survive_rollback(self):
        self.initialize_git()
        plan = self.review()
        result = self.command("apply", *self.options)
        target = self.root / "AGENTS.md"
        target.write_bytes(target.read_bytes() + b"Human security correction.\n")
        newer = target.read_bytes()
        held = self.command("recover", "--transaction", result["transaction"], "--remove-created-instructions",
                            "--approved-plan-sha256", plan["planSha256"])
        self.assertEqual(held["status"], "recovery-blocked")
        self.assertIn("AGENTS.md", held["conflicts"])
        self.assertEqual(target.read_bytes(), newer)

    def test_shared_powershell_wrapper_and_release_scope_boundary(self):
        self.initialize_git()
        if not shutil.which("pwsh"):
            self.skipTest("PowerShell wrapper unavailable on this host")
        wrapper = self.runtime / "scripts/bootstrap/04-check-wizard-update.ps1"
        result = local_command(["pwsh", "-NoProfile", "-File", str(wrapper), "-Action", "Review",
                                "-RuntimeRoot", str(self.root), "-InstructionMigration",
                                "-PlanPath", str(self.plan_path), "-AsJson"])
        plan = json.loads(result)
        self.assertEqual(plan["sourceMode"], "local-instructions")
        applied = local_command(["pwsh", "-NoProfile", "-File", str(wrapper), "-Action", "Update",
                                 "-RuntimeRoot", str(self.root), "-InstructionMigration",
                                 "-PlanPath", str(self.plan_path), "-ApprovedPlanSha256",
                                 plan["planSha256"], "-AsJson"])
        self.assertEqual(json.loads(applied)["status"], "applied")
        self.assertEqual(self.command("check", "--online", expected=2)["status"], "blocked")
        # Merely selecting a familiar filename still cannot enable fixture/release ownership.
        with self.assertRaises(update.UpdateError):
            update.relative_name("AGENTS.md")


if __name__ == "__main__":
    unittest.main()
