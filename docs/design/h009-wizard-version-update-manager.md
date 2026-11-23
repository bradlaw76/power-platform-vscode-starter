# H009 — Wizard Version & Update Manager: Technical Design

**Status:** Proposed design, not approved release or implemented runtime  
**Date:** 2026-11-23  
**Tracking:** [H009 / issue #14](https://github.com/bradlaw76/power-platform-vscode-starter/issues/14)  
**Scope:** Generic framework distribution, version discovery, safe opt-in update and compatibility verification  
**Boundary:** This design does not modify or deploy any SSA, FOIA, or consumer Dynamics/Dataverse application.

## 1. Design decision summary

1. Introduce **one canonical framework distribution version** using SemVer (e.g. `1.11.0`) in a machine-readable release manifest. Keep `profileVersion`, `contractVersion`, and script header versions independently meaningful; never present them as the release version.
2. Prefer **immutable, reviewed GitHub release tags** and a manifest tied to a pinned commit. A moving `main` branch is not a release channel.
3. Offer **non-blocking startup notification** and an explicit on-demand `check wizard updates` action in PowerShell and supported Copilot/Claude skill entry points. No silent downloads, merges or changes.
4. Treat a framework clone, a copied skill, and a consuming application repository as **distinct installation topologies**. Updates affect only verified framework-owned files in the correct scope.
5. Perform a **preview → user choice → guarded apply → verify → recover** transaction-like sequence. Do not claim atomic filesystem transactions; use checkpoint inventory, staged preparation, validation and documented compensation.
6. Keep all Git operations and filesystem writes outside the user's Dataverse deployment context. Never infer authorization for a production or tenant change from framework update approval.

## 2. Existing baseline and gap

As inspected on `main` 2026-11-23:

| Existing artifact | Current value / meaning |
| --- | --- |
| `docs/wizard-contract-v1.md` | Contract version `1.10.0` |
| `wizard.profile.json` | Profile `1.4`, contract `1.10.0` |
| `scripts/bootstrap/05-start-wizard.ps1` | Individual script version `0.7.0` |
| `MIGRATION.md` | Historical manual migration/compatibility guidance |
| `docs/skill-distribution.md` | Reviewed commit/tag provenance and manual compatibility/skill distribution guidance |
| `.github/skills/power-platform-wizard-init/` | Repo-local Copilot instructions |
| `.claude/skills/power-platform-vscode-wizard/` | Claude skill distribution |
| `scripts/bootstrap/01-install-skills.ps1` | Local Claude skill installation, not a full wizard updater |

The baseline establishes version metadata and manual checks, but not a verified end-to-end agent update UX. This design must be reconciled against other branches/PRs before coding to avoid duplicating work.

## 3. Architecture and module responsibilities

```text
Wizard launch / Agent invoked
  -> Local installation classifier (read-only)
  -> Installed release & compatibility inspector (read-only)
  -> Optional trusted release discovery (network; cache / timeout / offline)
  -> User status: installed / current / newer / incompatible / unknown
  -> [Continue] [Review changes] [Update wizard]
  -> Immutable release manifest + ownership-aware update planner
  -> Diff and risk preview
  -> Explicit user choice
  -> Revalidate baseline + lock / exclusive writer
  -> Preflight and local recovery snapshot
  -> Staged selective apply
  -> Parity / contract / security tests
  -> Commit/restore checkpoint and outcome report
```

**Suggested boundaries** (implementation may refine names after inspection):

- `wizard.release.json`: committed distribution identity and compatibility, generated/validated for release.
- `schemas/wizard-release.schema.json`: manifest shape and strict validation.
- `scripts/bootstrap/helpers/wizard-version.ps1`: deterministic installed-version resolution, topology classification, compatibility decision; credential-free.
- `scripts/bootstrap/04-check-wizard-update.ps1`: read-only local + upstream update discovery and friendly summary; optional `-Offline` / JSON output.
- `scripts/bootstrap/04-apply-wizard-update.ps1`: preview/plan/apply/verify with explicit authorization, path guards, backup and failure records. Default: Preview.
- `scripts/ci/WizardUpdate.Tests.ps1`: isolated tests with local mock Git remotes and fixtures, no real user home / tenant.
- Entry-point instructions: use the same helper/action contract, rather than reproducing separate update logic in every agent.

**No remote code execution:** Treat release data as untrusted input; downloaded scripts are never executed until pinned provenance, expected files, integrity and compatibility are verified. Never run arbitrary release-supplied install hooks.

## 4. Proposed release manifest

Example **illustrative** shape; the version below is not an existing release.

```json
{
  "schemaVersion": "1.0",
  "product": "power-platform-vscode-starter",
  "releaseVersion": "1.11.0",
  "channel": "stable",
  "source": {
    "repository": "bradlaw76/power-platform-vscode-starter",
    "tag": "wizard-v1.11.0",
    "commit": "<immutable-full-commit-sha>"
  },
  "compatibility": {
    "minSupportedInstalledRelease": "1.10.0",
    "contractVersion": "1.10.0",
    "profileVersion": "1.4",
    "requiresManualMigration": false
  },
  "fileManifest": "wizard.release.files.json",
  "notes": "CHANGELOG.md"
}
```

An accompanying file manifest should enumerate normalized POSIX-relative paths, SHA-256, size, ownership classification (`framework-runtime`, `skill-copilot`, `skill-claude`, `documentation`, `test`) and install scope (`framework-clone`, `consumer-copy`, `user-skill`). File ownership is explicit allowlist-based; missing classification fails closed. Archive hashes and tag signature/provenance policy must be validated by publisher CI, not trusted solely because the downloaded manifest says so.

**Release publishing gate:** Validate manifest against the source tree, exact tag/commit and release artifacts; fail publication for missing hashes or mismatched files; check compatibility and change notes. Establish trust root/pinned repository identity independently of the manifest. A tag by itself is not proof of integrity or authorization; specify branch protection/release provenance checks before enabling Apply.

## 5. Installation topology and state detection

| Topology | Read-only detection | Safe update target |
| --- | --- | --- |
| Original framework clone | Exact verified origin/identity and expected framework markers, with Git root/path and worktree verified | Framework repository, on appropriate owner-reviewed branch/worktree |
| Consuming application with copied runtime | Separate Git root and confirmed copy/manifest inventory | Only explicitly allowlisted framework-owned copies, preserving scenario and app-owned files |
| Copilot repo-shared skill only | Present under project `.github/skills/`, runtime may be missing | Skill only after runtime compatibility check; otherwise review/bootstrap plan |
| Claude user-installed skill | Present in user skill directory with provenance metadata | Skill folder only; no silent runtime/source update |
| Unknown/mixed/untracked | Insufficient origin/ownership or divergent local edits | Read-only report; no apply |

Prevent symlink/junction escapes, path traversal, case-collision, nested repository boundary crossings, reparse point and alternate path alias escapes. Inspect staged/unstaged/untracked/ignored files, branch/remote divergence, active locks and competing writers before presenting an executable plan; revalidate before each write boundary.

If GitHub is unavailable, cached release information may be displayed as **stale and unverified**, never as confirmation that the latest version is installed.

## 6. User interaction contract

**At startup** (not a blocking wizard question):

```text
Power Platform VS Code Wizard
Installed framework: 1.10.0  (release channel: stable)
Contract: 1.10.0 | Profile: 1.4
Update check: newer compatible version 1.11.0 available
Choices: [Review changes] [Update wizard] [Skip for now]
```

Illustration only; `1.11.0` is not a verified release.

Rules:

- If an installed distribution release cannot be established, show `release unknown (development checkout)`, plus inspected contract/profile, without inventing a version.
- Agent and terminal text must distinguish `update available`, `already current`, `offline/unverified`, `incompatible`, `local divergence`, and `update blocked`.
- Support no-network `-Offline` and explicit on-demand check. Short bounded network timeout; a failed check must not block discovery/intake.
- Release notes describe user-visible changes, breaking changes, migration steps and compatibility, without reading private project data or sending telemetry.
- `Skip` resumes normal wizard operation and does not rewrite local state beyond optional privacy-safe notification preferences.
- `Update wizard` authorizes only the **displayed plan and specific files**. Files introduced, baseline drift or different release require renewed review. Do not infer approval of Git pushes, source merges, Dataverse write operations, or change to an application.

## 7. Safe synchronization protocol

### Phase A — Detect and plan (strictly read-only)

1. Resolve current filesystem root, identity, install topology, release metadata, branch/ref and relevant Git state.
2. Fetch trusted release metadata via GitHub HTTPS with bounded retry/timeout; validate host/repository allowlist, pinned commit, manifest schema and checksums.
3. Compute exact file-level `add/replace/skip/conflict/remove` plan. **No automatic removals** in v1.
4. Mark locally modified or uncertain-ownership paths as conflicts, even if content appears generated.
5. Check required runtime/skill parity and compatibility matrix; show a change list and recommended validation.

### Phase B — Authorization and protected apply

1. Present plan digest: release tag+SHA, expected checkout/installed state, file inventory and recovery destination.
2. Require a real opt-in for this plan; don't interpret chat instruction to generally work on an app as permission to update wizard infrastructure.
3. Acquire exclusive update lock, bound to process/session and protected from stale-lock assumptions. Re-read HEAD, source/target digests, target existence and path ownership **after** acquiring lock.
4. Stage bytes under a separate temporary directory, verify all digests and file types, preserve backup of every exact target and metadata necessary for recovery. Do not write to another Git root or user home without explicit scope choice.
5. Apply only allowlisted, unchanged-since-preview paths. For a framework clone prefer a Git-aware branch/PR workflow over direct mutation of `main`; never `git reset --hard`, `pull --force`, force-push or blindly overwrite edits. No unreviewed auto-commit/push.
6. Run targeted parser/schema checks, skill parity, contract tests and update-specific tests; produce a file-by-file audit record.
7. If a failure occurs, restore prior bytes/metadata only when the target still matches this updater's write digest. If concurrent mutation prevents safe restore, **stop with a repair plan**, never overwrite new user work.
8. Release lock, retain backup and outcome record, and report whether change was `prepared`, `applied locally`, `tested`, `committed`, `pushed`, `merged`, or `released` separately. Never call local apply a published release.

Avoid claiming all-or-nothing atomicity. If rollback itself fails, keep checkpoint and list paths requiring manual reconciliation.

### Phase C — Verification and follow-up

Post-apply checks: installed-version resolution; exact hashes of approved update set; no mutation of app-specific paths or secrets; script parsing; profile/schema compatibility; agent skill parity; dry-run wizard start; repeat update check returns `already current` under mock release feed. Maintain structured local evidence under an ignored, scenario-independent diagnostics directory; redact usernames, tokens, tenant IDs, private paths when reporting externally.

## 8. Interaction with existing workflows

- **H008 Spec Kit reconciliation:** The updater must not touch consuming projects' `spec.md`, `plan.md`, `tasks.md`, `answers.md` or any generated scenario artifacts. A framework update may publish a *migration recommendation*, but scenario reconciliation remains a distinct, evidenced operation.
- **Project ownership boundary:** Do not store consuming-project files inside the generic starter; don't infer SSA/FOIA-specific schemas, forms or data.
- **Framework maintenance:** Reuse existing approved preflight/source-protection and authorization policy rather than introducing permissive bypasses. Check current head/PR work before implementation.
- **Skills installer:** Reuse the installer only for approved copy plans; do not equate skill refresh with full runtime replacement.
- **GitHub release governance:** Publishing and tagging are separately authorized; a merged document does not enable or constitute an official release.

## 9. Acceptance scenarios and test matrix

| ID | Scenario | Expected result |
| --- | --- | --- |
| U01 | Correct release and available network | Display `current`; zero writes |
| U02 | Newer compatible verified release | Display version/diff; no writes before choice |
| U03 | Offline / rate limited / DNS failure | Startup continues, status `unknown` |
| U04 | Pre-release or mismatched version/channel | No misleading `latest` claim |
| U05 | Incompatible contract or missing runtime | Block Apply, explain migration |
| U06 | Unsigned/untrusted metadata under release policy; SHA mismatch | Hard-stop before write |
| U07 | Dirty Git, modified target, untracked shadow file | Conflict, preserve all bytes |
| U08 | Nested application repo or unrelated remote | Never write beyond verified scope |
| U09 | Only skill installed, missing runtime | Skill/runtime distinction, non-mutating guidance |
| U10 | Path traversal / symlink or junction escape | Reject, no outside writes |
| U11 | Release metadata changes between preview and apply | Reject stale plan |
| U12 | Interruption during staged/apply/verify | Recover checkpoint; no unreported success |
| U13 | Repeat update against same verified release | Idempotent no-op |
| U14 | Competing writer, live file change during recovery | Do not overwrite subsequent edits |
| U15 | Unauthorized user/home/tenant access attempt | Block or avoid entirely |
| U16 | Agent entry point, terminal entry point | Same status and explicit opt-in semantics |
| U17 | User chooses Skip | Wizard continues; no update |
| U18 | Latest manifest has removals | Preview manual migration; never auto-delete |
| U19 | Version metadata absent in development checkout | Show unknown release plus contract/profile |

Run entirely with temporary Git fixtures and mock release sources; do not require cloud credentials or contact a real Dataverse environment. Provide negative tests that deliberately attempt forbidden writes. On supported Windows, verify path case/reparse behavior independently rather than inferring from Linux runs.

## 10. Proposed delivery slices for the coding agent

1. **Foundation:** Verify baseline/head and active owners; introduce manifest+schema and release-validation tests; document trust/provenance policy.
2. **Read-only discovery:** Resolve installed version/topology, query verified official releases, implement graceful offline behavior, JSON diagnostics and visible startup status.
3. **Update planner:** Allowlisted manifest/diffs, compatibility and conflict detection, preview API and plan digest, negative security tests.
4. **Apply/recovery:** Exact-scope explicit approval, lock and revalidation, snapshot, staged selective writes, verify and bounded repair; no destructive delete.
5. **Agent entry points:** Copilot/Claude integration, parity tests, scripted demos, onboarding and migration guide.
6. **End-to-end acceptance:** Windows/Linux isolated CI, simulated bad metadata, dirty trees and interruptions; draft PR with evidence and no live deployment.

Continue between independent slices in one substantial agent session; stop only for disputed ownership, release trust configuration, irrecoverable target conflicts or genuinely irreversible decisions. Respect current H008 writer locks.

## 11. Open design decisions (must resolve before enabling update Apply)

- **Authoritative release policy:** Are signed tags or GitHub artifact attestations mandatory, and who may publish official stable releases? Minimum: a protected owner-approved release at a pinned commit with verified file hashes; no unchecked release source.
- **Consumer-copy support:** Which files constitute the redistributable runtime bundle and what exact metadata identifies their original ownership? Do not infer from filename alone.
- **Preference storage:** Whether `Skip` is per session or per release; choose privacy-safe local-only persistence if implemented.
- **Removed files:** v1 leaves them in place and reports migration requirements; later explicitly reviewed cleanup is separate.
- **Stable vs preview channels:** Default stable only; preview opt-in can be future scope.

## 12. Definition of done

A user cloning or returning to the wizard can identify the installed framework release, compare to the authenticated latest stable release, inspect change impact and make a clear choice; an approved compatible update affects only the exact permitted framework files, verifies the result and supports guarded recovery. All critical negative tests and two agent entry points pass; no consumer scenario, credential or Dataverse asset changes. Implementation must provide traceable PR/CI evidence, and a separately approved release process must exist before declaring automatic update detection fully operational.
