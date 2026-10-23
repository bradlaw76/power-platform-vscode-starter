# Framework Skills 1-2 Implementation Handoff

Date: 2026-10-23

## Status and authorization

Implemented locally on the approved maintenance checkout. Commit, push and
merge have not been approved or performed. No deployment, environment sign-in,
live Dataverse mutation, release, or Skill 3 work was performed. Temporary CI
fixtures create local test commits only; they do not alter repository history.

The first task command verified:

| Context | Observed value |
| --- | --- |
| Repository identity | `github.com/bradlaw76/power-platform-vscode-starter` from origin fetch and push URLs |
| Exact branch | `framework-maintenance/skills-1-2` |
| Starting and current HEAD | `d9a32483ca4607078959b76908019a555f13ce59` |
| Initial worktree | Clean |
| Modification authorization | Explicit Framework Administration Mode and Skills 1-2 implementation request |
| Durable-backup exception | Already approved for this task; honored without asking again; not a permanent exemption |
| Histories and branches | Preserved; no checkout switch, reset, rebase, force push, or deletion |

Framework Administration Mode is documented as the operator-facing name for
existing Framework Maintenance Mode, not an additional application wizard mode.
Edits were prepared outside the repository and applied through the existing
`framework-maintenance.ps1 -Operation modify -ApproveModify` path with exact
file/content maps. The initial application used the baseline version of that
gate after explicit branch/SHA comparison; subsequent updates use its new
mandatory `-ExpectedHead` preflight.

## Implementation

The new read-only preflight verifies the explicit Git root, canonical fetch and
push identity, exact approved maintenance branch and full approved HEAD. It
rejects detached HEAD, another maintenance branch, default/application
branches, ambiguous or foreign remotes, a subdirectory as root, missing roots,
malformed input and stale baselines. It reports dirty changes without
discarding them. It does not infer a baseline, switch branches, fetch, write
telemetry, authenticate, or repair the checkout.

Every maintenance operation now runs that preflight before mutation and
requires `-ExpectedHead`. This is the sole intentional maintenance API change;
existing operation-specific approvals, exact path matching, ShouldProcess,
source protection, non-forced push and remote-head verification remain.
Commit, push and merge still require distinct approvals. Merge is not
implemented by the maintenance script.

Both new skills are discoverable in Copilot and Claude skill directories with
front matter and adapted SpeckKit component headers. Their instructions are
identical apart from each header's platform file path.

`dataverse-solution-architect` covers requirements-linked table strategy,
solution/publisher/security boundaries, semantic fields, relationships,
forms/views/entry point/review app, reports/data and design approval. The
Semantic Field Type Standard includes native email/phone/URL formats,
date/time behavior, money/currency, precision, choices/booleans, lookups,
identifiers, narratives, duration and file/image capability decisions.
Unsupported mappings are blockers, never text fallbacks or claims of support.

`power-platform-requirements-analyst` covers one-question facilitation,
current-state retrofit, stable requirement IDs, measurable success criteria,
source/owner/approval, bidirectional design/task/test traceability, planned
versus executed evidence, change control and scenario-level Spec Kit updates.
It does not introduce acceptance questions into Demo Builder/Advanced Builder.

Both skills are planning-only. They preserve the six-question Demo Builder
intake plus consolidated confirmation, explicit Advanced Builder and Framework
Acceptance selection, separate application roots, scenario isolation, source
protection, report decisions, bounded Task activities and existing build gates.
They reuse prior answers instead of restarting intake. Application payloads,
schemas, profiles, stage ordering, report runtime, inventory/sync, publication,
idempotency and export behavior were not changed.

## Changed files

| Files | Change |
| --- | --- |
| `.github/skills/dataverse-solution-architect/SKILL.md`, `.claude/skills/dataverse-solution-architect/SKILL.md` | New architecture skill pair |
| `.github/skills/power-platform-requirements-analyst/SKILL.md`, `.claude/skills/power-platform-requirements-analyst/SKILL.md` | New requirements skill pair |
| `.github/copilot-instructions.md`, `CLAUDE.md` | Permanent preflight and planning-skill routing |
| `.github/skills/power-platform-wizard-init/SKILL.md`, `.claude/skills/power-platform-vscode-wizard/SKILL.md` | Optional specialist routing without replacing existing workflow |
| `scripts/bootstrap/framework-context-preflight.ps1` | New executable read-only context check |
| `scripts/bootstrap/framework-maintenance.ps1` | Mandatory approved HEAD check per operation; verified SHA in output |
| `scripts/ci/test-framework-context-preflight.ps1` | Isolated executable positive/negative regression tests |
| `scripts/ci/test-planning-skills.ps1` | Skill parity, boundaries, type/traceability contracts and payload-example validation |
| `scripts/ci/test-framework-source-protection.ps1` | Existing maintenance fixtures updated to pass their reviewed fixture SHA |
| `docs/framework-maintenance-preflight.md` | Permanent context/approval policy and migration instructions |
| `docs/semantic-field-type-standard.md` | Semantic mapping rules, catalog shape, example and review gate |
| `docs/requirements-traceability.md` | Requirement record, matrix, Spec Kit integration and review gate |
| `docs/wizard-contract-v1.md`, `docs/skill-distribution.md`, `README.md` | Related contract/discovery/distribution documentation |
| `docs/audits/framework-skills-1-2-implementation-handoff.md`, `docs/audits/chatgpt-review-handoff.md` | Actual implementation/results handoff and review log |

The existing Claude installer already enumerates complete skill directories.
The existing quality workflow enumerates standalone `test-*.ps1` checks.
No installer or CI workflow modification is needed for discovery of these
skills/tests. No user-global skills were installed.

## Actual validation

PowerShell was initially missing (`pwsh: command not found`). Installed the
Microsoft Ubuntu package; validation used PowerShell 7.6.8. This was a local
environment prerequisite restoration, not a repository dependency change.

| Check / command | Actual result |
| --- | --- |
| Baseline `pwsh -NoProfile -NonInteractive -File scripts/ci/test-contract-integrity.ps1` | Passed before implementation |
| `pwsh -NoProfile -NonInteractive -File scripts/ci/test-framework-context-preflight.ps1` | 29 executable checks passed |
| `pwsh -NoProfile -NonInteractive -File scripts/ci/test-planning-skills.ps1` | 200 static contract checks passed; Email payload example validated against existing column schema and exact type/format/length |
| All `scripts/ci/test-*.ps1`, each in its own noninteractive PowerShell process | 29 scripts passed, 0 failed |
| Existing source protection, preview nonmutation, solution/publish isolation, reporting/data, mode, idempotency/export checks | Passed as part of the 29-script suite |
| Existing JSON validation | 84 JSON documents parsed; 60 payloads matched schemas |
| Parse every repository `.ps1` using `System.Management.Automation.Language.Parser.ParseFile` with CI exclusions | Passed, zero parse errors |
| `npx --yes markdownlint-cli2@0.18.1 "**/*.md"` | Passed, zero lint errors |
| `git diff --check` | Passed |
| Pester 5.7.1 suites and PSScriptAnalyzer 1.24.0 | Blocked: pinned modules unavailable locally; restore attempts failed (see below), so not reported as passed |

The new preflight regression tests exercise rejected writes and compare fixture
status/index/ref state. The existing source-protection tests also exercise
approved modify/commit and dry-run push in isolated fixtures. Initial new-test
failures were fixture expectations (PowerShell says "Cannot validate argument";
a traversal example was rejected by parameter validation before the explicit
traversal check). Those expectations were corrected and the final checks pass.

Static skill checks prove checked-in contracts and platform parity, not agent
compliance in every future conversation or live Dataverse compatibility.
No simulated report or mocked build is presented as a deployment.

## Blockers and review attention

Pinned Pester/analyzer validation remains outstanding. The PowerShellGet gallery
was unavailable; default registration did not produce a usable gallery.
Both `www.powershellgallery.com` and the official package CDN
`cdn.powershellgallery.com` failed DNS resolution. A final official-release
asset lookup found no Pester release assets and the analyzer lookup was denied
by the session token's organization SAML enforcement. This does not establish
anything about the operator's personal repository permissions.
No unpinned module or substitute test runner was used.

Before merge, rerun the existing CI Pester 5.7.1 and PSScriptAnalyzer 1.24.0
steps where their pinned dependencies are available. Review the intentional
maintenance API change: callers must supply a genuinely approved full HEAD
SHA; after an approved commit, review the new SHA before a later operation.

There are no known implementation failures in the executed checks. No live
environment validation was attempted or authorized. Commit, push and merge
remain separate pending approval boundaries, not completed operations.
