"""Component: H009 candidate distribution inventory, version 0.1.0.

File: scripts/bootstrap/helpers/wizard_distribution.py
Environment: Python 3.10+ standard library and Git; offline, read-only source.
Inventories exact Git blob bytes, never the working tree or a moving ref.
Candidate metadata is not publisher trust, an install bundle or Apply permission.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

from wizard_update import (OFFICIAL, RESERVED, UpdateError, canonical, check_chain,
                           fail, git, parse_json, read_json, write_exclusive)


REPOSITORY = "bradlaw76/power-platform-vscode-starter"
CATEGORIES = {"core-runtime", "helper", "schema-profile", "copilot-asset",
              "claude-asset", "shared-doc", "validation"}
DENIED_PARTS = {".git", ".env", ".vscode", ".wizard-metrics", "specs",
                "solutions", "node_modules", "__pycache__", "out", "backup"}
DENIED_DOCS = {"build-log.md", "release-consolidation.md", "security-public-review.md"}


def safe_name(name: str) -> str:
    if (not isinstance(name, str) or len(name) > 240
            or not re.fullmatch(r"[A-Za-z0-9._ /-]+", name)):
        fail("Invalid inventory path")
    if name.split("/")[0].casefold() == "payloads":
        fail("Consumer payloads are not distributable")
    for part in name.split("/"):
        if (part in {"", ".", ".."} or part.endswith((".", " "))
                or part.casefold() in DENIED_PARTS or part.casefold().startswith(".env")
                or RESERVED.match(part)):
            fail("Protected inventory path")
    return name


def eligible(name: str, category: str) -> bool:
    safe_name(name)
    if category == "core-runtime":
        return bool(re.fullmatch(r"scripts/bootstrap/[a-zA-Z0-9-]+\.ps1", name))
    if category == "helper":
        return bool(re.fullmatch(r"scripts/bootstrap/helpers/[a-zA-Z0-9_-]+\.(ps1|py)", name))
    if category == "schema-profile":
        return (name in {"wizard.profile.json", "wizard.release.json", "distribution/ownership-policy.json"}
                or bool(re.fullmatch(r"schemas/(?:payloads/|examples/)?[a-zA-Z0-9.-]+\.json", name)))
    if category == "copilot-asset":
        return (name in {"AGENTS.md", ".github/copilot-instructions.md"}
                or bool(re.fullmatch(r"\.github/(?:skills|prompts)/[A-Za-z0-9._/-]+\.md", name)))
    if category == "claude-asset":
        return bool(re.fullmatch(r"\.claude/skills/[A-Za-z0-9._/-]+\.md", name))
    if category == "shared-doc":
        return (name in {"README.md", "START HERE.md", "MIGRATION.md", "SECURITY.md", "CONTRIBUTING.md",
                         "docs/QUEUED_AUTONOMOUS_DELIVERY.md",
                         "requirements/GithubInstructions_General.md",
                         "requirements/how-to-build-dynamics-model-driven-apps-wizard.md",
                         "requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md"}
                or bool(re.fullmatch(r"docs/(?:policies/)?[a-zA-Z0-9-]+\.md", name))
                and Path(name).name not in DENIED_DOCS)
    if category == "validation":
        return (name in {"run-quality.ps1", "PSScriptAnalyzerSettings.psd1", ".markdownlint-cli2.jsonc"}
                or bool(re.fullmatch(r"scripts/ci/(?:fixtures/)?[A-Za-z0-9_.-]+\.(ps1|py|json)", name))
                and not any(word in name.casefold() for word in ("foia", "gcc")))
    return False


def load_policy(path: Path) -> tuple[dict, list[dict]]:
    policy = read_json(path)
    if (not isinstance(policy, dict)
            or set(policy) != {"schemaVersion", "inventoryVersion", "repository", "status",
                              "automaticApply", "groups"}
            or policy["schemaVersion"] != 1 or type(policy["schemaVersion"]) is not int
            or policy["inventoryVersion"] != "1.0.0" or policy["repository"] != REPOSITORY
            or policy["status"] != "candidate" or policy["automaticApply"] is not False
            or not isinstance(policy["groups"], list) or not policy["groups"]):
        fail("Unsupported candidate ownership policy")
    entries = []
    seen = set()
    spellings = {}
    categories = set()
    for group in policy["groups"]:
        if (not isinstance(group, dict) or set(group) != {"category", "consumerAction", "paths"}
                or group["category"] not in CATEGORIES or group["category"] in categories
                or group["consumerAction"] != "explicit-review"
                or not isinstance(group["paths"], list) or not group["paths"]):
            fail("Invalid ownership group")
        categories.add(group["category"])
        for name in group["paths"]:
            if not isinstance(name, str) or not eligible(name, group["category"]):
                fail("Path is not eligible for this framework category")
            if name.casefold() in seen:
                fail("Duplicate inventory path")
            seen.add(name.casefold())
            parts = name.split("/")
            for index in range(1, len(parts) + 1):
                prefix = "/".join(parts[:index])
                previous = spellings.setdefault(prefix.casefold(), prefix)
                if previous != prefix:
                    fail("Case-colliding inventory path component")
            entries.append({"path": name, "category": group["category"],
                            "consumerAction": group["consumerAction"]})
    if len(entries) > 512:
        fail("Inventory exceeds file budget")
    return policy, sorted(entries, key=lambda item: item["path"])


def inventory(root: Path, commit: str, policy_path: Path) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        fail("Exact full source commit required; branches and tags are not inventory authority")
    root = check_chain(root).resolve()
    if git(root, "rev-parse", "--verify", commit + "^{commit}").decode().strip() != commit:
        fail("Source identity mismatch")
    top = Path(git(root, "rev-parse", "--show-toplevel").decode().strip()).resolve()
    if top != root:
        fail("Exact source repository root required")
    policy, entries = load_policy(policy_path)
    tree = {}
    for record in git(root, "ls-tree", "-r", "-z", commit).split(b"\0"):
        if not record:
            continue
        info, name = record.split(b"\t", 1)
        mode, kind, object_id = info.decode("ascii").split()
        tree[name.decode("utf-8")] = (mode, kind, object_id)
    policy_entry = tree.get("distribution/ownership-policy.json")
    if (policy_entry is None or policy_entry[:2] != ("100644", "blob")
            or parse_json(git(root, "cat-file", "blob", policy_entry[2])) != policy):
        fail("Ownership policy must match the exact source commit")
    total = 0
    files = []
    for entry in entries:
        name = entry["path"]
        if name not in tree:
            fail("Policy names a missing source file: " + name)
        mode, kind, object_id = tree[name]
        if mode not in {"100644", "100755"} or kind != "blob":
            fail("Only regular Git blobs are distributable")
        data = git(root, "cat-file", "blob", object_id)
        total += len(data)
        if len(data) > 2 * 1024 * 1024 or total > 32 * 1024 * 1024:
            fail("Distribution exceeds byte budget")
        files.append({**entry, "gitMode": mode, "size": len(data),
                      "sha256": hashlib.sha256(data).hexdigest()})
    return {"schemaVersion": 1, "kind": "candidate-framework-distribution",
            "inventoryVersion": policy["inventoryVersion"], "repository": REPOSITORY,
            "repositoryUrl": OFFICIAL, "sourceCommit": commit,
            "policySha256": hashlib.sha256(canonical(policy)).hexdigest(),
            "publisherVerified": False, "automaticApply": False,
            "fileCount": len(files), "totalBytes": total, "files": files}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--policy", required=True, type=Path)
    output = parser.add_mutually_exclusive_group(required=True)
    output.add_argument("--output", type=Path)
    output.add_argument("--verify", type=Path)
    args = parser.parse_args(argv)
    try:
        result = inventory(args.root, args.commit, args.policy)
        if args.verify:
            if canonical(read_json(args.verify)) != canonical(result):
                fail("Candidate inventory differs from exact source or policy")
            status = "verified-candidate"
        else:
            write_exclusive(check_chain(args.output), (json.dumps(result, indent=2) + "\n").encode())
            status = "generated-candidate"
        print(json.dumps({"status": status, "sourceCommit": args.commit,
                          "fileCount": result["fileCount"], "totalBytes": result["totalBytes"],
                          "publisherVerified": False, "automaticApply": False}))
        return 0
    except (UpdateError, OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({"status": "blocked", "error": str(exc)}))
        return 2


if __name__ == "__main__":
    sys.exit(main())
