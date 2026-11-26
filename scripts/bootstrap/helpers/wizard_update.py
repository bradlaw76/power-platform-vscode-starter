"""Component: H009 bounded wizard update engine, version 0.1.0.

File: scripts/bootstrap/helpers/wizard_update.py
Environment: Python 3.10+ standard library; optional local OpenSSL for RSA verification.
Official release policy is not yet published: production mutation is disabled.
Fixture transactions are deliberately restricted to remote-free, marked test repositories.

The fixture marker is .wizard-update-fixture.json with kind
"wizard-update-isolated-fixture", version 1, exact absolute root and 32-hex nonce.
The marker and wizard.release.json must belong to an independent single initial
Git commit on fixture/* or update/* with no remotes. Only synthetic
scripts/bootstrap/helpers/update-fixture-*.py|json files are eligible.
An independent SHA-256 pin supplies fixture integrity, never publisher trust.
Preview writes a plan only when an explicit, outside-target --plan is supplied;
apply repeats the envelope/source/trust arguments and requires that plan's hash.
No release code, Git hook, commit, checkout, staging or push is executed.
Default recovery reports new payload files for manual removal. Explicit local
instruction-only adoption reuses these transactions; approved recovery can
remove only unchanged newly created instructions. It is not a runtime release.
"""
from __future__ import annotations

import argparse
import ast
from contextlib import contextmanager
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import threading
import time
import uuid


MAX_JSON = 1024 * 1024
MAX_FILE = 2 * 1024 * 1024
MAX_TOTAL = 16 * 1024 * 1024
MAX_FILES = 128
STATE = ".wizard-update"
MARKER = ".wizard-update-fixture.json"
OFFICIAL = "https://github.com/bradlaw76/power-platform-vscode-starter"
RELEASES = "https://api.github.com/repos/bradlaw76/power-platform-vscode-starter/releases?per_page=10"
ENGINE_ROOT = Path(__file__).resolve().parents[3]
HEX = re.compile(r"[0-9a-f]{64}\Z")
SEMVER = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\Z")
RESERVED = re.compile(r"(con|prn|aux|nul|conin\$|conout\$|com[0-9¹²³]|lpt[0-9¹²³])(?:\.|$)", re.I)
PROTECTED = {
    ".git", ".env", "specs", "payloads", "solutions", ".wizard-metrics",
    ".github", ".claude", ".copilot", "agents.md", "claude.md", "gemini.md",
    "spec.md", "binding_certification.md", "system_manifest.json.md", STATE,
}
INSTRUCTION_PATHS = (
    "AGENTS.md", ".github/copilot-instructions.md",
    "docs/policies/authorization-and-execution.md",
    ".github/prompts/power-platform-demo-wizard.prompt.md",
    ".github/skills/power-platform-wizard-init/SKILL.md",
    ".github/skills/power-platform-wizard-init/references/progress-monitoring.md",
    ".github/skills/dataverse-report-wizard/SKILL.md",
    ".claude/skills/power-platform-vscode-wizard/SKILL.md",
    ".claude/skills/dataverse-report-wizard/SKILL.md",
    "docs/QUEUED_AUTONOMOUS_DELIVERY.md",
)


class UpdateError(Exception):
    pass


def fail(message):
    raise UpdateError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            fail("Duplicate JSON member")
        result[key] = value
    return result


def parse_json(data):
    try:
        return json.loads(data.decode("utf-8"), object_pairs_hook=no_duplicates,
                          parse_constant=lambda value: fail("Non-finite JSON number"))
    except (UnicodeError, ValueError, RecursionError) as exc:
        raise UpdateError("Invalid UTF-8 JSON") from exc


def check_chain(path):
    path = Path(os.path.abspath(path))
    for item in (path, *path.parents):
        try:
            info = item.lstat()
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
            fail("Symlink, junction or reparse point rejected")
    return path


def read_bytes(path, limit=MAX_FILE):
    path = check_chain(path)
    if not path.is_file():
        fail("Expected regular file")
    with path.open("rb") as stream:
        data = stream.read(limit + 1)
    if len(data) > limit:
        fail("File exceeds byte budget")
    return data


def read_json(path):
    return parse_json(read_bytes(path, MAX_JSON))


def version(value):
    if not isinstance(value, str) or not SEMVER.fullmatch(value):
        fail("Stable SemVer required")
    return tuple(int(part) for part in value.split("."))


def relative_name(value, instructions=False):
    if instructions and value in INSTRUCTION_PATHS:
        return value
    if not isinstance(value, str) or not value or len(value) > 240:
        fail("Invalid ownership path")
    if "\\" in value or ":" in value or value.startswith("/") or "\x00" in value:
        fail("Absolute, Windows or alternate-stream path rejected")
    parts = value.split("/")
    for part in parts:
        if (part in {"", ".", ".."} or part.endswith((".", " "))
                or any(ord(char) < 32 or char in '<>"|?*' for char in part)
                or RESERVED.match(part) or part.casefold() in PROTECTED
                or part.casefold().startswith(".env")):
            fail("Protected or unsafe ownership path")
    # No published ownership policy exists. Fixtures exercise only synthetic helpers.
    if (len(parts) != 4 or parts[:3] != ["scripts", "bootstrap", "helpers"]
            or not re.fullmatch(r"update-fixture-[a-z0-9_-]+\.(py|json)", parts[-1])):
        fail("Path is outside the approved synthetic ownership allowlist")
    return value


def owned_path(root, name, instructions=False):
    relative_name(name, instructions)
    cursor = root
    for part in name.split("/"):
        if cursor.is_dir():
            for index, child in enumerate(cursor.iterdir()):
                if index >= 4096:
                    fail("Ownership directory exceeds traversal budget")
                if child.name.casefold() == part.casefold() and child.name != part:
                    fail("Case-colliding target path rejected")
        cursor = cursor / part
    result = check_chain(root.joinpath(*name.split("/")))
    for parent in result.parents:
        if parent == root:
            break
        if (parent / ".git").exists():
            fail("Nested Git repository rejected")
    return result


def execute(argv, cwd=None, limit=4 * MAX_JSON, read_git_configuration=False):
    environment = {key: value for key, value in os.environ.items()
                   if not key.upper().startswith("GIT_")}
    environment.update(GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0")
    if not read_git_configuration:
        environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
    try:
        with subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, env=environment) as process:
            output = [bytearray(), bytearray()]
            exceeded = threading.Event()

            def drain(stream, index):
                while True:
                    chunk = stream.read(8192)
                    if not chunk:
                        return
                    if len(output[index]) + len(chunk) > limit:
                        exceeded.set()
                        process.kill()
                        return
                    output[index].extend(chunk)

            readers = [threading.Thread(target=drain, args=(stream, index), daemon=True)
                       for index, stream in enumerate((process.stdout, process.stderr))]
            for reader in readers:
                reader.start()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise
            finally:
                for reader in readers:
                    reader.join(timeout=2)
            if exceeded.is_set() or sum(map(len, output)) > limit:
                fail("Subprocess output exceeds budget")
            if process.returncode:
                fail("Local verification command failed")
            return bytes(output[0])
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise UpdateError("Bounded local subprocess unavailable") from exc


def git(root, *args, read_git_configuration=False):
    executable = shutil.which("git")
    if not executable:
        fail("Git unavailable")
    return execute([executable, "--no-pager", "--no-optional-locks",
                    "-c", "core.fsmonitor=false", "-c", "core.untrackedCache=false",
                    "-c", "core.quotePath=false", "-C", str(root), *args], cwd=root,
                   read_git_configuration=read_git_configuration)


def git_state(root):
    top = Path(os.fsdecode(git(root, "rev-parse", "--show-toplevel")).strip()).resolve()
    if top != root:
        fail("Root must be exact Git worktree root")
    head = git(root, "rev-parse", "--verify", "HEAD").decode().strip()
    branch = git(root, "rev-parse", "--abbrev-ref", "HEAD").decode().strip()
    line_endings = []
    # Read only scalar conversion settings; status still excludes executable user configuration.
    for key, default, allowed in (
            ("core.autocrlf", "false", {"true", "false", "input"}),
            ("core.eol", "native", {"native", "lf", "crlf"}),
            ("core.safecrlf", "false", {"true", "false", "warn"})):
        raw = git(root, "config", "--type=bool-or-str", "--get", "--default", default, key,
                  read_git_configuration=True)
        try:
            value = raw.decode("ascii").strip().lower()
        except UnicodeError as exc:
            raise UpdateError("Invalid Git line-ending configuration: " + key) from exc
        if value not in allowed:
            fail("Invalid Git line-ending configuration: " + key)
        line_endings.extend(("-c", key + "=" + value))
    status_bytes = git(root, *line_endings, "status", "--porcelain=v1", "-z", "--untracked-files=all",
                       "--", ".", ":(exclude).wizard-update")
    return {"head": head, "branch": branch, "statusSha256": digest(status_bytes),
            "statusPorcelain": status_bytes.decode("utf-8", errors="replace").replace("\0", "\n"),
            "dirty": bool(status_bytes)}


def topology(root):
    root = check_chain(root)
    copied_skill = (root / "SKILL.md").is_file() and root.parent.name == "skills"
    github = ((root / ".github" / "skills").is_dir()
              or copied_skill and root.parent.parent.name == ".github")
    claude = ((root / ".claude" / "skills").is_dir()
              or copied_skill and root.parent.parent.name == ".claude")
    remotes = []
    state = None
    diagnostics = []
    try:
        state = git_state(root)
    except UpdateError as exc:
        diagnostics.append({"operation": "git-state", "message": str(exc)})
    if state is not None:
        try:
            remotes = git(root, "remote", "get-url", "--all", "origin").decode().splitlines()
        except UpdateError as exc:
            diagnostics.append({"operation": "origin",
                                "message": "Origin missing or inspection unavailable: " + str(exc)})
    normalized = [value.removesuffix(".git").rstrip("/") for value in remotes]
    framework_markers = all((root / name).is_file()
                            for name in ("README.md", "SYSTEM_MANIFEST.json.md"))
    if state is not None and framework_markers and normalized == [OFFICIAL]:
        kind = "framework-clone"
    elif github and claude:
        kind = "mixed"
    elif github:
        kind = "copilot-only"
    elif claude:
        kind = "claude-only"
    elif state is not None and framework_markers:
        kind = "downstream"
    else:
        kind = "unknown"
    return {"kind": kind, "git": state, "remote": remotes, "inspectionDiagnostics": diagnostics,
            "writePolicy": "disabled-pending-official-policy"}


def descriptor(root):
    path = root / "wizard.release.json"
    if not path.exists():
        return {"releaseVersion": None, "releaseIdentity": "unknown-development",
                "releaseVerified": False, "compatibility": {"contractVersion": None, "profileVersion": None}}
    value = read_json(path)
    if not isinstance(value, dict):
        fail("Invalid distribution descriptor")
    release = value.get("releaseVersion")
    if release is not None:
        version(release)
    compatibility = value.get("compatibility", {})
    if not isinstance(compatibility, dict):
        fail("Invalid descriptor compatibility")
    return {"releaseVersion": release, "releaseVerified": False,
            "releaseIdentity": "unverified-local-descriptor" if release else "unknown-development",
            "compatibility": {"contractVersion": compatibility.get("contractVersion"),
                              "profileVersion": compatibility.get("profileVersion")}}


def assert_fixture(args, root):
    if not args.fixture_root or check_chain(args.fixture_root).resolve() != root:
        fail("Official apply unavailable: no published release trust/ownership policy")
    if root == ENGINE_ROOT or root in ENGINE_ROOT.parents:
        fail("Fixture must be separate from the framework checkout")
    for name in ("SYSTEM_MANIFEST.json.md", "README.md", "SPEC.md", ".github", ".claude"):
        if (root / name).exists():
            fail("Framework/consumer checkout cannot be used as a fixture")
    marker = read_json(root / MARKER)
    if (not isinstance(marker, dict) or marker.get("kind") != "wizard-update-isolated-fixture"
            or marker.get("version") != 1 or marker.get("root") != str(root)
            or not re.fullmatch(r"[a-f0-9]{32}", str(marker.get("nonce", "")))):
        fail("Explicit private fixture marker required")
    state = git_state(root)
    if git(root, "remote").strip():
        fail("Fixture must have no Git remotes")
    if not state["branch"].startswith(("fixture/", "update/")):
        fail("Fixture must use an isolated feature branch")
    check_chain(root / ".git")
    if not (root / ".git").is_dir():
        fail("Fixture cannot be a linked worktree")
    if len(git(root, "rev-list", "--max-count=2", "HEAD").splitlines()) != 1:
        fail("Fixture must have independent single-commit test history")
    tracked = git(root, "ls-tree", "-r", "--name-only", "-z", "HEAD").decode("utf-8").split("\0")
    if MARKER not in tracked or "wizard.release.json" not in tracked:
        fail("Fixture identity and release descriptor must belong to its independent initial commit")
    for name in filter(None, tracked):
        if name not in {MARKER, "wizard.release.json"}:
            relative_name(name)
    return marker, state


def signed_envelope(args):
    if not args.envelope:
        fail("--envelope is required")
    raw = read_bytes(args.envelope, MAX_JSON)
    envelope_hash = digest(raw)
    trust = {"envelopeSha256": envelope_hash, "signatureSha256": None,
             "trustKeySha256": None, "opensslSha256": None, "signed": False,
             "publisherVerified": False, "provenance": "none"}
    if args.trusted_envelope_sha256:
        if not HEX.fullmatch(args.trusted_envelope_sha256) or envelope_hash != args.trusted_envelope_sha256:
            fail("Independent envelope digest mismatch")
        trust["pinned"] = True
        trust["provenance"] = "independent-sha256-integrity-pin-not-publisher-trust"
    if args.signature or args.trust_key or args.openssl_path:
        if not all((args.signature, args.trust_key, args.openssl_path)):
            fail("Detached signature, independent public key and absolute OpenSSL path required")
        executable = Path(args.openssl_path)
        if not executable.is_absolute():
            fail("OpenSSL must be pinned by absolute local executable path")
        executable = check_chain(executable)
        binary_hash = digest(read_bytes(executable, 32 * MAX_JSON))
        key = read_bytes(args.trust_key, 16384)
        if b"-----BEGIN PUBLIC KEY-----" not in key or b"PRIVATE" in key:
            fail("Independent RSA SubjectPublicKeyInfo public key required")
        signature = read_bytes(args.signature, 16384)
        # OpenSSL pkey rejects non-RSA keys here; dgst verifies exact envelope bytes.
        public = execute([str(executable), "pkey", "-pubin", "-in", str(check_chain(args.trust_key)),
                          "-text", "-noout"], limit=65536)
        if not re.search(rb"Public-Key: \((2048|3072|4096) bit\)", public) or b"Modulus:" not in public:
            fail("RSA public key must have 2048, 3072 or 4096 bits")
        execute([str(executable), "dgst", "-sha256", "-verify", str(check_chain(args.trust_key)),
                 "-signature", str(check_chain(args.signature)), str(check_chain(args.envelope))])
        # Detect files changed during the verifier's independent reads.
        if (read_bytes(args.envelope, MAX_JSON) != raw
                or read_bytes(args.trust_key, 16384) != key
                or read_bytes(args.signature, 16384) != signature
                or digest(read_bytes(executable, 32 * MAX_JSON)) != binary_hash):
            fail("Verification inputs changed")
        trust.update(signatureSha256=digest(signature), trustKeySha256=digest(key),
                     opensslSha256=binary_hash, signed=True, provenance="operator-rsa-signature-not-publisher-policy")
    if not trust["signed"] and not args.trusted_envelope_sha256:
        fail("Independent signature trust or envelope SHA-256 pin required")
    envelope = parse_json(raw)
    validate_envelope(envelope)
    return envelope, trust


def validate_envelope(value):
    expected = {"schemaVersion", "sourceMode", "releaseVersion", "sourceCommit", "sourceTag",
                "compatibility", "files", "notes"}
    if (not isinstance(value, dict) or set(value) != expected
            or type(value["schemaVersion"]) is not int or value["schemaVersion"] != 1):
        fail("Unsupported envelope contract")
    if value["sourceMode"] not in {"official", "fixture"}:
        fail("Unsupported source mode")
    version(value["releaseVersion"])
    if (not isinstance(value["sourceCommit"], str)
            or not re.fullmatch(r"[0-9a-f]{40}", value["sourceCommit"])
            or value["sourceTag"] != "v" + value["releaseVersion"]):
        fail("Immutable commit and stable release tag required")
    compatibility = value["compatibility"]
    if (not isinstance(compatibility, dict)
            or set(compatibility) != {"minRelease", "maxReleaseExclusive", "contractVersion", "profileVersion"}
            or any(not isinstance(compatibility[key], str) or len(compatibility[key]) > 80
                   for key in ("contractVersion", "profileVersion"))):
        fail("Explicit compatibility contract required")
    if version(compatibility["minRelease"]) >= version(compatibility["maxReleaseExclusive"]):
        fail("Invalid compatibility range")
    if not isinstance(value["notes"], str) or len(value["notes"]) > 8192:
        fail("Release notes exceed budget")
    files = value["files"]
    if not isinstance(files, list) or not 1 <= len(files) <= MAX_FILES:
        fail("Invalid file count")
    seen = set()
    total = 0
    for item in files:
        if (not isinstance(item, dict)
                or set(item) != {"path", "sha256", "size", "baselineSha256", "class", "scope"}):
            fail("Explicit file ownership contract required")
        name = relative_name(item["path"])
        if name.casefold() in seen:
            fail("Duplicate or case-colliding ownership paths")
        seen.add(name.casefold())
        if not isinstance(item["sha256"], str) or not HEX.fullmatch(item["sha256"]):
            fail("Invalid source hash")
        if item["baselineSha256"] is not None and (
                not isinstance(item["baselineSha256"], str) or not HEX.fullmatch(item["baselineSha256"])):
            fail("Invalid baseline hash")
        if type(item["size"]) is not int or not 0 <= item["size"] <= MAX_FILE:
            fail("Invalid file size")
        if item["class"] != "runtime-helper" or item["scope"] != "framework":
            fail("Unsupported ownership class/scope")
        total += item["size"]
    if total > MAX_TOTAL:
        fail("Payload exceeds total byte budget")


def validate_content(name, data):
    try:
        text = data.decode("utf-8")
        if name.endswith(".py"):
            ast.parse(text, filename=name)
        elif name.endswith(".json"):
            parse_json(data)
    except (UnicodeError, SyntaxError, ValueError, RecursionError) as exc:
        raise UpdateError("Payload syntax validation failed") from exc


def source_inventory(source, files, instructions=False):
    expected = {item["path"]: item for item in files}
    found = set()
    total = 0
    count = 0
    for folder, dirs, names in os.walk(source, followlinks=False):
        for name in dirs + names:
            path = check_chain(Path(folder) / name)
            relative = path.relative_to(source).as_posix()
            if name.casefold() == ".git":
                fail("Source contains nested Git repository")
            count += 1
            if count > 512:
                fail("Source inventory exceeds traversal budget")
            if path.is_dir():
                if not any(item.startswith(relative + "/") for item in expected):
                    fail("Unexpected payload directory")
                continue
            relative_name(relative, instructions)
            if relative not in expected or relative.casefold() in found:
                fail("Unexpected or case-colliding payload file")
            data = read_bytes(path)
            total += len(data)
            item = expected[relative]
            if len(data) != item["size"] or digest(data) != item["sha256"]:
                fail("Payload bytes do not match signed inventory")
            validate_content(relative, data)
            found.add(relative.casefold())
    if found != {name.casefold() for name in expected} or total > MAX_TOTAL:
        fail("Payload inventory is incomplete")


def snapshot(root):
    state = git_state(root)
    files = {}
    total = 0
    count = 0
    for folder, dirs, names in os.walk(root, followlinks=False):
        parent = Path(folder)
        if parent == root:
            dirs[:] = [name for name in dirs if name not in {".git", STATE}]
        for name in dirs + names:
            count += 1
            if count > 8192:
                fail("Worktree exceeds traversal budget")
            path = check_chain(parent / name)
            if name.casefold() == ".git":
                fail("Nested Git repository rejected")
            if path.is_dir():
                continue
            if len(files) >= 4096:
                fail("Worktree exceeds snapshot file budget")
            data = read_bytes(path, 8 * MAX_JSON)
            total += len(data)
            if total > 128 * MAX_JSON:
                fail("Worktree exceeds snapshot byte budget")
            files[path.relative_to(root).as_posix()] = digest(data)
    return {"git": state, "files": files}


def candidate_state(local, envelope, fixture=False):
    release = local["releaseVersion"]
    compatibility = envelope["compatibility"]
    if release is None or not fixture:
        return "offline-unknown"
    current = version(release)
    if (not version(compatibility["minRelease"]) <= current < version(compatibility["maxReleaseExclusive"])
            or any(local["compatibility"][key] != compatibility[key]
                   for key in ("contractVersion", "profileVersion"))):
        return "incompatible"
    offered = version(envelope["releaseVersion"])
    return "newer-compatible" if offered > current else "older-available" if offered < current else "current"


def installed_files(plan):
    files = dict(plan["snapshot"]["files"])
    files.update({item["path"]: item["sha256"] for item in plan["files"]})
    return files


def file_metadata(path):
    path = check_chain(path)
    if not path.exists():
        return None
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        fail("Metadata requires a regular file")
    mode = stat.S_IMODE(info.st_mode)
    if mode & ~0o777:
        fail("Special permission bits are outside the update policy")
    return {"mode": mode, "mtimeNs": info.st_mtime_ns, "uid": info.st_uid, "gid": info.st_gid,
            "readOnly": bool(getattr(info, "st_file_attributes", 0) & 1)}


def target_metadata(root, files, instructions=False):
    return {item["path"]: file_metadata(owned_path(root, item["path"], instructions)) for item in files}


def set_private_metadata(path, metadata):
    current = file_metadata(path)
    if any(current[key] != metadata[key] for key in ("uid", "gid")):
        fail("Replacement would change owner/group; no ownership changes are authorized")
    if os.name == "nt" and (metadata["readOnly"] or not metadata["mode"] & stat.S_IWRITE):
        fail("Read-only Windows targets cannot be replaced or restored")
    with check_chain(path).open("r+b") as stream:
        if os.name != "nt":
            os.fchmod(stream.fileno(), metadata["mode"])
        os.utime(check_chain(path), ns=(path.stat().st_atime_ns, metadata["mtimeNs"]))
        stream.flush()
        os.fsync(stream.fileno())
    if file_metadata(path) != metadata:
        fail("Replacement metadata cannot be preserved exactly")


def replacement_metadata_matches(baseline, replacement):
    if not isinstance(replacement, dict) or set(replacement) != {"mode", "mtimeNs", "uid", "gid", "readOnly"}:
        return False
    if (any(type(replacement[key]) is not int for key in ("mode", "mtimeNs", "uid", "gid"))
            or type(replacement["readOnly"]) is not bool or not 0 <= replacement["mode"] <= 0o777):
        return False
    return baseline is None or all(replacement[key] == baseline[key]
                                   for key in ("mode", "uid", "gid", "readOnly"))


def instruction_mode(args):
    return bool(getattr(args, "instruction_source", None))


def assert_target(args, root):
    if not instruction_mode(args):
        return assert_fixture(args, root)
    if check_chain(args.instruction_source).resolve() != ENGINE_ROOT:
        fail("Instruction source must be this executing local runtime, not a release payload")
    if root == ENGINE_ROOT or root in ENGINE_ROOT.parents or ENGINE_ROOT in root.parents:
        fail("Instruction target must be a separate project, not the executing runtime")
    if root == Path.home().resolve() or root.parent == root:
        fail("User home/filesystem root is not an instruction project")
    if args.online or any(getattr(args, key, None) for key in (
            "envelope", "signature", "trust_key", "trusted_envelope_sha256", "source")):
        fail("Local instruction adoption cannot be combined with release/network inputs")
    state = git_state(root)
    if state["branch"] == "HEAD":
        fail("Instruction adoption requires an identifiable project branch")
    lock_name = os.fsdecode(git(root, "rev-parse", "--git-path", "index.lock")).strip()
    lock = Path(lock_name)
    if not lock.is_absolute():
        lock = root / lock
    if check_chain(lock).exists():
        fail("Active Git index writer detected")
    return {"scope": "local-project-instructions", "root": str(root)}, state


def instruction_bodies(root):
    root = check_chain(root).resolve()
    bodies = {}
    for name in INSTRUCTION_PATHS:
        path = owned_path(root, name, True)
        if path.exists():
            bodies[name] = read_bytes(path)
    return bodies


def instruction_match(data, body):
    normalized = body.replace(b"\r\n", b"\n")
    variants = {body, normalized, normalized.replace(b"\n", b"\r\n")}
    matches = [(data.index(value), len(value)) for value in variants if data.count(value) == 1]
    if sum(data.count(value) for value in variants) != 1:
        return None
    return matches[0]


def make_instruction_plan(args, installed_plan=None):
    root = check_chain(args.root).resolve()
    marker, _ = assert_target(args, root)
    current = instruction_bodies(ENGINE_ROOT)
    if any(not current.get(name) for name in INSTRUCTION_PATHS):
        fail("Local runtime lacks the complete instruction bundle, including AGENTS, Copilot and policy")
    if b"authorization-and-execution.md" not in current["AGENTS.md"]:
        fail("Local AGENTS does not reference the actual canonical policy")
    previous_root = getattr(args, "previous_instructions", None)
    previous = {}
    if previous_root:
        previous_root = check_chain(previous_root).resolve()
        if previous_root == root or root in previous_root.parents or previous_root in root.parents:
            fail("Previous instruction source must be independent of the target")
        previous = instruction_bodies(previous_root)
    state = snapshot(root)
    source = None
    if args.plan:
        plan_path = check_chain(args.plan).resolve()
        for boundary in (root, ENGINE_ROOT, previous_root):
            if boundary and (plan_path == boundary or boundary in plan_path.parents):
                fail("Instruction plan/payload must be outside project and source roots")
        source = plan_path.with_name(plan_path.name + ".instructions")
        check_chain(source)
    files = []
    diagnostics = []
    diffs = {}
    payload = {}
    for name, new in current.items():
        target = owned_path(root, name, True)
        old = read_bytes(target) if target.exists() else None
        if installed_plan is not None:
            entry = next((item for item in installed_plan["files"] if item["path"] == name), None)
            if entry:
                if old is None or digest(old) != entry["sha256"] or old.count(new) != 1:
                    fail("Installed instruction drift detected")
                files.append(dict(entry))
                payload[name] = old
                continue
        if old is None:
            after, classification = new, "new"
        elif instruction_match(old, new):
            after, classification = old, "current-customized" if old != new else "current"
        else:
            baseline = previous.get(name)
            match = instruction_match(old, baseline) if baseline else None
            if not match:
                fail("Edited, ambiguous or unrecognized instruction body: " + name)
            offset, length = match
            after = old[:offset] + new + old[offset + length:]
            classification = "recognized-previous-customized" if old != baseline else "recognized-previous"
        diagnostics.append({"path": name, "classification": classification,
                            "customizationPreserved": True})
        if after != old:
            payload[name] = after
            diffs[name] = "".join(difflib.unified_diff(
                (old or b"").decode("utf-8").splitlines(keepends=True),
                after.decode("utf-8").splitlines(keepends=True),
                fromfile=name + " (before)", tofile=name + " (after)"))
            files.append({"path": name, "sha256": digest(after), "size": len(after),
                          "baselineSha256": digest(old) if old is not None else None,
                          "class": "project-instruction", "scope": "local-source-only"})
    if installed_plan is not None:
        if state["files"] != installed_files(installed_plan) or any(
                state["git"][key] != installed_plan["snapshot"]["git"][key] for key in ("head", "branch")):
            fail("Installed project or Git identity drift detected")
        state = installed_plan["snapshot"]
        diagnostics = installed_plan["instructionDiagnostics"]
        diffs = installed_plan["instructionDiffs"]
    metadata = (installed_plan["targetMetadata"] if installed_plan is not None
                else target_metadata(root, files, True))
    if source:
        ensure_directory(source)
        for name, data in payload.items():
            path = owned_path(source, name, True)
            if path.exists():
                if read_bytes(path) != data:
                    fail("Prepared instruction payload changed; retain original plan")
            else:
                ensure_directory(path.parent)
                write_exclusive(path, data)
        source_inventory(source, files, True)
    plan = {
        "schemaVersion": 1, "root": str(root), "source": str(source) if source else None,
        "sourceMode": "local-instructions", "instructionSourceRoot": str(ENGINE_ROOT),
        "previousInstructionRoot": str(previous_root) if previous_root else None,
        "trust": {"mode": "explicit-local-source",
                  "sourceFiles": {name: digest(data) for name, data in current.items()},
                  "previousFiles": {name: digest(data) for name, data in previous.items()}},
        "fixtureMarkerSha256": digest(canonical(marker)), "snapshot": state,
        "targetMetadata": metadata, "files": files,
        "instructionDiagnostics": diagnostics,
        "instructionDiffs": diffs,
        "instructionStandard": "development-first-1",
        "officialPolicyAvailable": False,
        "candidateStatus": "local-instruction-adoption",
        "runtimeUpdated": False, "releaseVerified": False,
        "selectiveStagingPaths": [item["path"] for item in files],
    }
    plan["planSha256"] = digest(canonical(plan))
    return plan


def make_plan(args, installed_plan=None):
    if instruction_mode(args):
        return make_instruction_plan(args, installed_plan)
    root = check_chain(args.root).resolve()
    envelope, trust = signed_envelope(args)
    if not args.source:
        fail("--source is required for preview/apply")
    source = check_chain(args.source).resolve()
    if not source.is_dir() or source == root or root in source.parents or source in root.parents:
        fail("Payload source must be a separate directory")
    source_inventory(source, envelope["files"])
    local = descriptor(root)
    target_snapshot = snapshot(root)
    metadata = target_metadata(root, envelope["files"])
    if installed_plan is not None:
        if (target_snapshot["files"] != installed_files(installed_plan)
                or any(target_snapshot["git"][key] != installed_plan["snapshot"]["git"][key]
                       for key in ("head", "branch"))):
            fail("Installed target or Git identity differs from approved transaction")
        target_snapshot = installed_plan["snapshot"]
        metadata = installed_plan["targetMetadata"]
    files = []
    for item in envelope["files"]:
        path = owned_path(root, item["path"])
        current_hash = digest(read_bytes(path)) if path.exists() else None
        expected_hash = item["sha256"] if installed_plan is not None else item["baselineSha256"]
        if current_hash != expected_hash:
            fail("Locally modified file or mismatched release baseline")
        files.append(dict(item))
    fixture = None
    if args.fixture_root:
        marker, _ = assert_fixture(args, root)
        if envelope["sourceMode"] != "fixture":
            fail("Fixture requires a fixture envelope")
        fixture = digest(canonical(marker))
    plan = {"schemaVersion": 1, "root": str(root), "source": str(source),
            "sourceMode": envelope["sourceMode"], "trust": trust,
            "fixtureMarkerSha256": fixture, "snapshot": target_snapshot,
            "targetMetadata": metadata,
            "releaseVersion": envelope["releaseVersion"], "sourceCommit": envelope["sourceCommit"],
            "sourceTag": envelope["sourceTag"], "releaseNotes": envelope["notes"], "local": local,
            "candidateStatus": candidate_state(local, envelope, fixture is not None), "files": files,
            "officialPolicyAvailable": False, "selectiveStagingPaths": [item["path"] for item in files]}
    plan["planSha256"] = digest(canonical(plan))
    return plan


def sync_directory(path):
    if os.name != "nt":
        descriptor_fd = os.open(path, os.O_RDONLY)
        try:
            os.fsync(descriptor_fd)
        finally:
            os.close(descriptor_fd)


def write_exclusive(path, data):
    check_chain(path)
    with path.open("xb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    sync_directory(path.parent)


def atomic_json(path, value):
    check_chain(path)
    staged = path.with_name(path.name + "." + uuid.uuid4().hex + ".pending")
    write_exclusive(staged, canonical(value))
    os.replace(staged, check_chain(path))
    sync_directory(path.parent)


def ensure_directory(path):
    check_chain(path)
    path.mkdir(parents=True, exist_ok=True)
    check_chain(path)


def alive(pid):
    if type(pid) is not int or pid <= 0:
        return True
    if os.name == "nt":
        import ctypes
        handle = ctypes.windll.kernel32.OpenProcess(0x1000, False, pid)
        if not handle:
            return ctypes.windll.kernel32.GetLastError() != 87
        try:
            code = ctypes.c_ulong()
            if not ctypes.windll.kernel32.GetExitCodeProcess(handle, ctypes.byref(code)):
                return True
            return code.value == 259
        finally:
            ctypes.windll.kernel32.CloseHandle(handle)
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def crash(args, point):
    if args.fixture_root and os.environ.get("WIZARD_UPDATE_FIXTURE_CRASH") == point:
        os._exit(86)
    if args.fixture_root and os.environ.get("WIZARD_UPDATE_FIXTURE_PAUSE") == point:
        time.sleep(2)


@contextmanager
def recovery_guard(state):
    path = check_chain(state / "recovery.lock")
    try:
        write_exclusive(path, canonical({"pid": os.getpid()}))
    except FileExistsError:
        fail("Recovery lock exists; never assume a stale lock is safe")
    try:
        yield
    finally:
        path.unlink()
        sync_directory(state)


def completed_replay(args, approved):
    root = check_chain(args.root).resolve()
    state = check_chain(root / STATE)
    transactions = check_chain(state / "transactions")
    if not transactions.exists():
        return None
    if (state / "lock.json").exists() or (state / "recovery.lock").exists():
        fail("Update/recovery lock exists; completed replay cannot bypass an owner")
    for index, transaction in enumerate(transactions.iterdir()):
        if index >= 128:
            fail("Transaction inventory exceeds replay budget")
        transaction = check_chain(transaction)
        if not transaction.is_dir() or not re.fullmatch(r"[a-f0-9]{32}", transaction.name):
            fail("Unrecognized transaction checkpoint")
        journal = read_json(transaction / "journal.json")
        if (not isinstance(journal, dict) or journal.get("phase") != "complete"
                or journal.get("planSha256") != approved["planSha256"]):
            continue
        if (journal.get("root") != str(root) or journal.get("transaction") != transaction.name
                or read_json(transaction / "plan.json") != approved
                or journal.get("files") != [{**item, "phase": "written"} for item in approved["files"]]
                or journal.get("fixtureMarkerSha256") != approved["fixtureMarkerSha256"]
                or journal.get("baselineMetadata") != approved["targetMetadata"]
                or journal.get("replacementMetadata") != target_metadata(root, approved["files"], instruction_mode(args))
                or any(not replacement_metadata_matches(approved["targetMetadata"][item["path"]],
                                                         journal["replacementMetadata"][item["path"]])
                       for item in approved["files"])
                or journal.get("installedSnapshot") != snapshot(root)
                or make_plan(args, installed_plan=approved) != approved):
            fail("Completed transaction replay rejected: immutable input or installed state drift")
        # Re-read lock state after verification; replay never acquires or writes one.
        if (state / "lock.json").exists() or (state / "recovery.lock").exists():
            fail("An update/recovery owner appeared during replay verification")
        return {"status": "already-applied", "transaction": str(transaction),
                "planSha256": approved["planSha256"], "commitCreated": False,
                "stagingPerformed": False, "selectiveStagingPaths": approved["selectiveStagingPaths"]}
    return None


def apply(args):
    root = check_chain(args.root).resolve()
    assert_target(args, root)
    if not args.plan or not args.approved_plan_sha256:
        fail("Explicit --plan and --approved-plan-sha256 required")
    approved = read_json(args.plan)
    expected = args.approved_plan_sha256
    if (not HEX.fullmatch(expected) or not isinstance(approved, dict)
            or approved.get("planSha256") != expected):
        fail("Approved plan digest mismatch")
    unsigned = {key: value for key, value in approved.items() if key != "planSha256"}
    if digest(canonical(unsigned)) != expected:
        fail("Plan content digest mismatch")
    replay = completed_replay(args, approved)
    if replay is not None:
        return replay
    if make_plan(args) != approved:
        fail("Plan is stale; preview and approve again")
    if not instruction_mode(args) and (not (approved["trust"]["signed"] or approved["trust"].get("pinned"))
            or approved["sourceMode"] != "fixture"
            or approved["candidateStatus"] != "newer-compatible"
            or approved["snapshot"]["git"]["dirty"]):
        fail("Apply requires independently pinned compatible fixture upgrade and a clean feature branch")
    if instruction_mode(args) and not approved["files"]:
        return {"status": "already-current", "writes": 0, "runtimeUpdated": False}
    if os.name == "nt" and any(metadata and (
            metadata["readOnly"] or not metadata["mode"] & stat.S_IWRITE)
            for metadata in approved["targetMetadata"].values()):
        fail("Read-only Windows targets are not updateable")
    state = root / STATE
    ensure_directory(state / "transactions")
    transaction_id = uuid.uuid4().hex
    transaction = state / "transactions" / transaction_id
    lock = state / "lock.json"
    token = uuid.uuid4().hex
    lock_value = {"root": str(root), "transaction": transaction_id, "token": token, "pid": os.getpid()}
    if (state / "recovery.lock").exists():
        fail("Recovery is active")
    try:
        write_exclusive(lock, canonical(lock_value))
    except FileExistsError:
        fail("Update lock exists; explicit guarded recovery required")
    journal = None
    try:
        ensure_directory(transaction)
        journal = {"schemaVersion": 1, **lock_value, "planSha256": expected,
                   "fixtureMarkerSha256": approved["fixtureMarkerSha256"],
                   "baselineMetadata": approved["targetMetadata"], "replacementMetadata": {},
                   "phase": "preparing", "files": []}
        atomic_json(transaction / "journal.json", journal)
        write_exclusive(transaction / "plan.json", canonical(approved))
        crash(args, "after-lock")
        if make_plan(args) != approved:
            fail("Plan changed after lock acquisition")
        for index, item in enumerate(approved["files"]):
            target = owned_path(root, item["path"], instruction_mode(args))
            before = read_bytes(target) if target.exists() else None
            if (digest(before) if before is not None else None) != item["baselineSha256"]:
                fail("Concurrent target edit detected")
            baseline_metadata = approved["targetMetadata"][item["path"]]
            if file_metadata(target) != baseline_metadata:
                fail("Concurrent target metadata drift detected")
            if before is not None:
                write_exclusive(transaction / f"{index}.backup", before)
            staged = read_bytes(Path(approved["source"]).joinpath(*item["path"].split("/")))
            if digest(staged) != item["sha256"] or len(staged) != item["size"]:
                fail("Payload changed while staging")
            write_exclusive(transaction / f"{index}.staged", staged)
            replacement = transaction / f"{index}.replacement"
            write_exclusive(replacement, staged)
            if baseline_metadata is not None:
                set_private_metadata(replacement, {**baseline_metadata,
                                                   "mtimeNs": file_metadata(replacement)["mtimeNs"]})
            journal["replacementMetadata"][item["path"]] = file_metadata(replacement)
            journal["files"].append({**item, "phase": "staged"})
        journal["phase"] = "prepared"
        atomic_json(transaction / "journal.json", journal)
        crash(args, "prepared")
        # All backups/staged bytes and the complete baseline are checked before the first write.
        if make_plan(args) != approved:
            fail("Plan changed before first mutation")
        for index, item in enumerate(journal["files"]):
            if (item["baselineSha256"] is not None
                    and digest(read_bytes(transaction / f"{index}.backup")) != item["baselineSha256"]):
                fail("Checkpoint backup integrity mismatch before mutation")
            staged = read_bytes(transaction / f"{index}.staged")
            if digest(staged) != item["sha256"] or len(staged) != item["size"]:
                fail("Checkpoint staging integrity mismatch before mutation")
        for index, item in enumerate(journal["files"]):
            _, current_git = assert_target(args, root)
            if any(current_git[key] != approved["snapshot"]["git"][key] for key in ("head", "branch")):
                fail("Git identity changed during apply")
            target = owned_path(root, item["path"], instruction_mode(args))
            current = digest(read_bytes(target)) if target.exists() else None
            if current != item["baselineSha256"]:
                fail("Concurrent edit detected; checkpoint retained")
            if file_metadata(target) != approved["targetMetadata"][item["path"]]:
                fail("Concurrent metadata edit detected; checkpoint retained")
            staged_path = check_chain(transaction / f"{index}.staged")
            if digest(read_bytes(staged_path)) != item["sha256"]:
                fail("Staged bytes changed")
            item["phase"] = "writing"
            journal["phase"] = "applying"
            atomic_json(transaction / "journal.json", journal)
            crash(args, f"before-replace-{index}")
            ensure_directory(target.parent)
            sibling = transaction / f"{index}.replacement"
            if (digest(read_bytes(sibling)) != item["sha256"]
                    or file_metadata(sibling) != journal["replacementMetadata"][item["path"]]):
                fail("Replacement bytes or metadata changed")
            if (digest(read_bytes(target)) if target.exists() else None) != item["baselineSha256"]:
                fail("Concurrent edit before atomic replace")
            if file_metadata(target) != approved["targetMetadata"][item["path"]]:
                fail("Concurrent metadata edit before atomic replace")
            os.replace(check_chain(sibling), owned_path(root, item["path"], instruction_mode(args)))
            sync_directory(target.parent)
            crash(args, f"after-replace-{index}")
            if digest(read_bytes(target)) != item["sha256"]:
                fail("Post-write hash validation failed")
            if file_metadata(target) != journal["replacementMetadata"][item["path"]]:
                fail("Post-write metadata validation failed")
            item["phase"] = "written"
            atomic_json(transaction / "journal.json", journal)
        journal["installedSnapshot"] = snapshot(root)
        if journal["installedSnapshot"]["files"] != installed_files(approved):
            fail("Post-apply target drift; checkpoint retained")
        if target_metadata(root, approved["files"], instruction_mode(args)) != journal["replacementMetadata"]:
            fail("Post-apply metadata drift; checkpoint retained")
        journal["phase"] = "complete"
        atomic_json(transaction / "journal.json", journal)
        if read_json(lock) != lock_value:
            fail("Lock identity changed")
        lock.unlink()
        sync_directory(state)
        return {"status": "applied", "transaction": str(transaction), "planSha256": expected,
                "commitCreated": False, "stagingPerformed": False,
                **({"instructionCompatibilityVerified": True, "runtimeUpdated": False}
                   if instruction_mode(args) else {}),
                "selectiveStagingPaths": approved["selectiveStagingPaths"]}
    except Exception:
        if journal is not None:
            journal["phase"] = "interrupted"
            atomic_json(transaction / "journal.json", journal)
        raise


def recover(args):
    root = check_chain(args.root).resolve()
    marker, current_git = assert_target(args, root)
    if not args.transaction:
        fail("Explicit --transaction required")
    transaction = check_chain(args.transaction).resolve()
    state = check_chain(root / STATE)
    if (transaction.parent != state / "transactions"
            or not re.fullmatch(r"[0-9a-f]{32}", transaction.name)):
        fail("Transaction must be an exact checkpoint owned by this root")
    with recovery_guard(state):
        journal = read_json(transaction / "journal.json")
        plan = read_json(transaction / "plan.json")
        if (not isinstance(journal, dict) or not isinstance(plan, dict)
                or (plan.get("sourceMode") == "local-instructions") != instruction_mode(args)
                or (instruction_mode(args) and plan.get("instructionSourceRoot") != str(ENGINE_ROOT))
                or journal.get("root") != str(root) or journal.get("transaction") != transaction.name
                or not re.fullmatch(r"[a-f0-9]{32}", str(journal.get("token", "")))
                or journal.get("fixtureMarkerSha256") != digest(canonical(marker))
                or journal.get("planSha256") != plan.get("planSha256")
                or plan.get("root") != str(root)
                or journal.get("baselineMetadata") != plan.get("targetMetadata")
                or any(current_git[key] != plan.get("snapshot", {}).get("git", {}).get(key)
                       for key in ("head", "branch"))
                or digest(canonical({key: value for key, value in plan.items() if key != "planSha256"}))
                != plan.get("planSha256")):
            fail("Checkpoint identity or plan binding mismatch")
        if (instruction_mode(args) and getattr(args, "remove_created_instructions", False)
                and args.approved_plan_sha256 != plan["planSha256"]):
            fail("Removing created instructions requires the exact approved transaction plan hash")
        entries = journal.get("files")
        if (not isinstance(entries, list) or not isinstance(plan.get("files"), list)
                or len(entries) > len(plan["files"]) or len(entries) > MAX_FILES
                or any(not isinstance(entry, dict)
                       or {key: value for key, value in entry.items() if key != "phase"} != plan["files"][index]
                       for index, entry in enumerate(entries))):
            fail("Checkpoint file inventory mismatch")
        if (not isinstance(plan.get("targetMetadata"), dict)
                or not isinstance(journal.get("replacementMetadata"), dict)
                or any(not replacement_metadata_matches(plan["targetMetadata"][item["path"]],
                                                         journal["replacementMetadata"].get(item["path"]))
                       for item in entries)):
            fail("Checkpoint metadata binding mismatch")
        lock = state / "lock.json"
        if lock.exists():
            owner = read_json(lock)
            if (not isinstance(owner, dict)
                    or any(owner.get(key) != journal.get(key) for key in ("root", "transaction", "token"))):
                fail("Another transaction owns the update lock")
            if alive(owner.get("pid")):
                fail("Update lock owner is still running")
        else:
            write_exclusive(lock, canonical({key: journal[key] for key in ("root", "transaction", "token", "pid")}))
        conflicts = []
        manual = []
        for index in reversed(range(len(entries))):
            item = entries[index]
            target = owned_path(root, item["path"], instruction_mode(args))
            current = digest(read_bytes(target)) if target.exists() else None
            baseline_metadata = plan["targetMetadata"][item["path"]]
            current_metadata = file_metadata(target)
            if current == item["baselineSha256"] and current_metadata == baseline_metadata:
                item["phase"] = "restored"
                continue
            if (current != item["sha256"]
                    or current_metadata != journal["replacementMetadata"][item["path"]]):
                conflicts.append(item["path"])
                continue
            if item["baselineSha256"] is None:
                if instruction_mode(args) and getattr(args, "remove_created_instructions", False):
                    if (digest(read_bytes(target)) != item["sha256"]
                            or file_metadata(target) != journal["replacementMetadata"][item["path"]]):
                        fail("Concurrent change before scoped instruction removal")
                    target.unlink()
                    sync_directory(target.parent)
                    item["phase"] = "restored"
                    atomic_json(transaction / "journal.json", journal)
                    continue
                manual.append(item["path"])
                continue
            backup = read_bytes(transaction / f"{index}.backup")
            if digest(backup) != item["baselineSha256"]:
                fail("Backup integrity mismatch")
            item["phase"] = "restoring"
            atomic_json(transaction / "journal.json", journal)
            sibling = transaction / f"{index}.restore"
            if sibling.exists():
                if read_bytes(sibling) != backup:
                    fail("Recovery staging integrity mismatch")
            else:
                write_exclusive(sibling, backup)
            set_private_metadata(sibling, baseline_metadata)
            if (digest(read_bytes(target)) != item["sha256"]
                    or file_metadata(target) != current_metadata):
                fail("Concurrent edit during recovery")
            os.replace(check_chain(sibling), owned_path(root, item["path"], instruction_mode(args)))
            sync_directory(target.parent)
            if (digest(read_bytes(target)) != item["baselineSha256"]
                    or file_metadata(target) != baseline_metadata):
                fail("Recovered file bytes or metadata validation failed")
            item["phase"] = "restored"
            atomic_json(transaction / "journal.json", journal)
        journal["phase"] = "recovery-blocked" if conflicts or manual else "recovered"
        atomic_json(transaction / "journal.json", journal)
        if not conflicts and not manual:
            owner = read_json(lock)
            if owner.get("token") != journal["token"]:
                fail("Lock changed during recovery")
            lock.unlink()
            sync_directory(state)
        return {"status": journal["phase"], "transaction": str(transaction),
                "conflicts": conflicts, "manualRemovalRequired": manual, "backupsRetained": True}


def online_metadata():
    # A killable isolated stdlib child bounds even slow-drip HTTP headers/bodies.
    worker = """
import sys, urllib.request
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        raise ValueError("Release API redirect rejected")
request = urllib.request.Request(URL, headers={
    "Accept": "application/vnd.github+json", "User-Agent": "wizard-update/0.1"})
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
with opener.open(request, timeout=5) as response:
    sys.stdout.buffer.write(response.read(256 * 1024 + 1))
"""
    try:
        data = execute([sys.executable, "-I", "-S", "-c", "URL = " + repr(RELEASES) + "\n" + worker],
                       limit=256 * 1024)
        releases = parse_json(data)
        if not isinstance(releases, list) or len(releases) > 10:
            fail("Invalid release metadata")
        candidates = [item["tag_name"] for item in releases if isinstance(item, dict)
                      and not item.get("draft") and not item.get("prerelease")
                      and isinstance(item.get("tag_name"), str)
                      and SEMVER.fullmatch(item["tag_name"].removeprefix("v"))]
        return {"availability": "unverified", "stableTags": candidates,
                "reason": "GitHub metadata is not signed official release policy"}
    except (OSError, ValueError, UpdateError) as exc:
        return {"availability": "unavailable", "reason": type(exc).__name__}


def fixture_installed_proof(args, trust):
    root = check_chain(args.root).resolve()
    transactions = check_chain(root / STATE / "transactions")
    if not transactions.exists():
        return None
    for index, transaction in enumerate(transactions.iterdir()):
        if index >= 128:
            fail("Transaction inventory exceeds installed-proof budget")
        transaction = check_chain(transaction)
        if not transaction.is_dir() or not re.fullmatch(r"[a-f0-9]{32}", transaction.name):
            fail("Unrecognized transaction checkpoint")
        journal = read_json(transaction / "journal.json")
        if not isinstance(journal, dict) or journal.get("phase") != "complete":
            continue
        plan = read_json(transaction / "plan.json")
        if not isinstance(plan, dict) or plan.get("trust") != trust:
            continue
        if (plan.get("root") != str(root)
                or not HEX.fullmatch(str(plan.get("planSha256", "")))
                or digest(canonical({key: value for key, value in plan.items() if key != "planSha256"}))
                != plan["planSha256"]):
            fail("Installed fixture proof has invalid root or approved-plan binding")
        proof_args = argparse.Namespace(**vars(args))
        # This is read-only revalidation of the originally approved source, never target selection.
        if proof_args.source is None:
            proof_args.source = Path(plan["source"])
        replay = completed_replay(proof_args, plan)
        if replay is not None:
            return {"releaseVersion": plan["releaseVersion"], "transaction": replay["transaction"],
                    "planSha256": plan["planSha256"], "source": "completed-isolated-fixture-transaction",
                    "releaseVerified": False, "publisherVerified": False}
    return None


def inspect(args):
    root = check_chain(args.root).resolve()
    if not root.is_dir():
        fail("Root directory does not exist")
    local = descriptor(root)
    detected = topology(root)
    status = "offline-unknown"
    result = {"schemaVersion": 1, "status": status, "root": str(root), "distribution": local,
              "topology": detected, "officialPolicyAvailable": False, "networkUsed": False}
    lock = root / STATE / "lock.json"
    result["updateLock"] = {"state": "absent"}
    if lock.exists():
        try:
            owner = read_json(lock)
            if (not isinstance(owner, dict) or owner.get("root") != str(root)
                    or not re.fullmatch(r"[a-f0-9]{32}", str(owner.get("transaction", "")))):
                fail("Unverified lock identity")
            result["updateLock"] = {
                "state": "owner-running-or-unverifiable" if alive(owner.get("pid")) else "owner-not-running",
                "transaction": str(root / STATE / "transactions" / owner["transaction"]),
                "explicitRecoveryRequired": True,
            }
        except (UpdateError, OSError):
            result["updateLock"] = {"state": "unverified", "explicitRecoveryRequired": True}
    if detected["git"] and detected["git"]["dirty"]:
        result["status"] = "locally-modified"
    if args.command == "check" and args.envelope:
        envelope, trust = signed_envelope(args)
        trusted_fixture = False
        if args.fixture_root:
            assert_fixture(args, root)
            trusted_fixture = envelope["sourceMode"] == "fixture" and (trust["signed"] or trust.get("pinned"))
        result.update(trust=trust, candidateStatus=candidate_state(local, envelope, trusted_fixture))
        result["status"] = result["candidateStatus"] if trusted_fixture else "unverified"
        if detected["git"] and detected["git"]["dirty"]:
            result["status"] = "locally-modified"
        if trusted_fixture:
            proof = fixture_installed_proof(args, trust)
            if proof is not None:
                result.update(status="current", candidateStatus="current", fixtureInstalledRelease=proof)
    if args.command == "check" and args.online:
        result["networkUsed"] = True
        result["remoteMetadata"] = online_metadata()
        if not args.envelope and result["status"] != "locally-modified":
            result["status"] = "unverified"
    return result


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("command", choices=("status", "check", "preview", "apply", "recover"))
    result.add_argument("--root", required=True, type=Path)
    network = result.add_mutually_exclusive_group()
    network.add_argument("--offline", action="store_true", help="Default; never fetch")
    network.add_argument("--online", action="store_true", help="Check official metadata only")
    for name in ("envelope", "signature", "trust-key", "openssl-path", "source", "plan",
                 "instruction-source", "previous-instructions",
                 "fixture-root", "transaction"):
        result.add_argument("--" + name, type=Path)
    result.add_argument("--trusted-envelope-sha256")
    result.add_argument("--approved-plan-sha256")
    result.add_argument("--remove-created-instructions", action="store_true")
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.online and args.command != "check":
            fail("--online is allowed only with explicit check")
        if args.remove_created_instructions and (args.command != "recover" or not instruction_mode(args)):
            fail("Created-instruction removal is available only for explicit local instruction recovery")
        if args.previous_instructions and not instruction_mode(args):
            fail("Previous instruction source requires explicit instruction adoption scope")
        if args.command in {"status", "check"} and instruction_mode(args):
            if args.plan:
                fail("Instruction status/check does not write plans or payloads")
            output = make_instruction_plan(args)
            output["status"] = "current" if not output["files"] else "instruction-review-required"
        elif args.command in {"status", "check"}:
            output = inspect(args)
        elif args.command == "preview":
            output = make_plan(args)
            if args.plan:
                path = check_chain(args.plan)
                root = check_chain(args.root).resolve()
                if path == root or root in path.parents:
                    fail("Preview plan must be outside the target worktree")
                write_exclusive(path, canonical(output))
        elif args.command == "apply":
            output = apply(args)
        else:
            output = recover(args)
        print(json.dumps(output, sort_keys=True))
        return 0
    except (UpdateError, OSError, ValueError, KeyError, TypeError, RecursionError) as exc:
        print(json.dumps({"status": "blocked", "error": str(exc), "errorType": type(exc).__name__}))
        return 2


if __name__ == "__main__":
    sys.exit(main())
