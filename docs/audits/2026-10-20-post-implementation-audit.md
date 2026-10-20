# Power Platform VS Code Wizard — Post-Implementation Audit

## Update Log

### LATEST — 2026-10-20 11:56 UTC

**Status: BLOCKED — recovery restore verification failed; implementation has not started.**

- Created `/tmp/power-platform-vscode-starter-remediation-82227ed90c01920d.bundle`
  for feature-branch HEAD `82227ed90c01920d6cdfed70701e6b2e547eb32c`.
- `git bundle verify` succeeded. SHA-256:
  `17f8f9a4610753c622c060a2d41ed42c4d6edac2ce11941757b00a1672c664bc`.
- Disposable clone verification failed because shallow history is missing
  ancestor `7cef4f68404156cba52fb8fb72e64bbbc90480a1`.
- The bundle, checksum file, and failed verification clone remain under `/tmp`.
  Per the approved stop condition, no alternate backup method was attempted and
  no implementation edits were made.

### Previous Update — 2026-10-20 11:11 UTC

**Status: Audit completed; remediation assessed as not ready (maturity 4/10).**

The original read-only audit below found that target Git identity was not
validated before generation, maintenance authorization did not enforce actual
operations, and the remediation branch lacked its own CI run. Its Git-state
details and conclusions are preserved as a historical snapshot; they are not a
claim about the later recovery-checkpoint attempt.

---

**Audit date:** 2026-10-20  
**Historical audit mode:** Read-only; no repository files were changed and no
tests or workflows were executed during that audit.
**Baseline:** `1bb72aacc6bc6abb9eb6aaaf3f492737fc115d95`

## A. Executive Summary

**Overall status: not ready to treat the framework as a reliably read-only
dependency.** The remediation adds substantial path validation and target-root
routing. However, a separate clone of the framework can be accepted as the
application target and receive generated files before Git identity checks run.
Framework maintenance authorization is also a voluntary checker, not an
enforced filesystem or Git-operation boundary.

The remediation is committed and pushed on a feature branch, not `main`; it has
no associated pull request or branch-specific Wizard Quality run. The audit
rates overall maturity **4/10**. This is an audit judgment, not a certification.

## B. Current Git State

Read-only commands and relevant results:

```text
git rev-parse --show-toplevel
/home/runner/work/power-platform-vscode-starter/power-platform-vscode-starter

git remote -v
origin http://localhost:26831/bradlaw76/power-platform-vscode-starter (fetch)
origin http://localhost:26831/bradlaw76/power-platform-vscode-starter (push)

git branch --show-current
copilot/extend-use-case-isolation-remediation

git rev-parse HEAD
bbe117a9bb98ce595be4438ca0f035bc37b58bdb

git status -sb
## copilot/extend-use-case-isolation-remediation...origin/copilot/extend-use-case-isolation-remediation

git rev-list --left-right --count @{upstream}...HEAD
0 0
```

`git status --short --ignored`, `git diff --cached --name-status`,
`git diff --name-status`, and `git stash list` were empty. The worktree was
clean: no staged, unstaged, untracked, ignored, stashed, or unpushed changes.
The shallow local clone contained only the remediation branch and its
remote-tracking ref. Direct comparison with the baseline succeeded, but the
shallow history did not provide a merge base.

GitHub reported these relevant branches:

| Branch | SHA | Protected |
|---|---|---|
| `main` | `1bb72aacc6bc6abb9eb6aaaf3f492737fc115d95` | No |
| `copilot/extend-use-case-isolation-remediation` | `bbe117a9bb98ce595be4438ca0f035bc37b58bdb` | No |
| `backup/pre-fast-20261015` | `17bebe3fb2322c2ad07c05dec8ef0c64dba6df28` | No |
| `feature/dataverse-form-formatter-v1` | `17bebe3fb2322c2ad07c05dec8ef0c64dba6df28` | No |
| `feature/fast-accelerator-catalog` | `0d1812b9acea61afa750883422d88807f48b4f1d` | No |
| `feature/federal-foia-demo-security` | `1fd8eeb0a12ba461e49507a66e75fc82ee32fd3b` | No |
| `feature/federal-foia-management` | `5a2a8e57520675c22d8d38a5ae92cab08084de9a` | No |
| `copilot/add-dynamics-365-app-option` | `991e911c7d18dfbe437ce5a5e984b5a0ba3bd74` | No |

There is no pull request for the remediation branch. Open PR #3 is unrelated:
[Add new Dynamics 365 app workload and requirements-material intake](https://github.com/bradlaw76/power-platform-vscode-starter/pull/3).
PRs #1 and #2 are closed and unmerged.

Remediation commits:

- [`2cc5e6e`](https://github.com/bradlaw76/power-platform-vscode-starter/commit/2cc5e6ee1bc4d64db0bbcf071b4a0f0c215e8317) — initial boundary/helper
- [`6d654ec`](https://github.com/bradlaw76/power-platform-vscode-starter/commit/6d654ecf570bc1d181098139c2b0e21a79ae4b10) — audit plan, migration guidance, root routing
- [`b828470`](https://github.com/bradlaw76/power-platform-vscode-starter/commit/b828470fe3ed65afce7c353b43460c89e8d32f08) — CI fixture separation
- [`7cef4f6`](https://github.com/bradlaw76/power-platform-vscode-starter/commit/7cef4f68404156cba52fb8fb72e64bbbc90480a1) — maintenance authorization and fixtures
- [`bbe117a`](https://github.com/bradlaw76/power-platform-vscode-starter/commit/bbe117a9bb98ce595be4438ca0f035bc37b58bdb) — maintenance-path tightening and tests

## C. Complete Changed-File Inventory

The baseline-to-HEAD comparison found **59 changed files: 4 added, 55
modified, none deleted or relocated**. All are committed and pushed on the
remediation branch; none were uncommitted during the audit. No clearly
unintended changes were identified.

### Added

| File | Classification and purpose |
|---|---|
| `docs/plans/2026-10-19-framework-source-protection-phase-1.md` | Planning documentation: audit and remediation plan |
| `scripts/bootstrap/framework-maintenance.ps1` | Framework authorization checker |
| `scripts/bootstrap/helpers/wizard-source-protection.ps1` | Framework/target path and Git identity helpers |
| `scripts/ci/test-framework-source-protection.ps1` | Source-protection tests |

### Modified guidance and configuration (12)

`.claude/skills/dataverse-report-wizard/SKILL.md`;  
`.claude/skills/power-platform-vscode-wizard/SKILL.md`;  
`.github/prompts/power-platform-demo-wizard.prompt.md`;  
`.github/skills/dataverse-report-wizard/SKILL.md`;  
`.github/skills/power-platform-wizard-init/SKILL.md`;  
`MIGRATION.md`; `README.md`; `docs/dataverse-report-wizard.md`;
`docs/onboarding.md`; `docs/wizard-contract-v1.md`;
`requirements/GithubInstructions_General.md`; `wizard.profile.json`.

These files document or configure application/framework separation, migration,
wizard intake, reporting, and installation behavior. `docs/wizard-contract-v1.md`
is the authoritative contract.

### Modified framework scripts and helpers (28)

`00-prereq-check.ps1`; `01-install-skills.ps1`; `05-start-wizard.ps1`;
`06-demo-script-wizard.ps1`; `07-demo-dry-run.ps1`; `08-report-wizard.ps1`;
`10-auth-connect.ps1`; `15-dry-validate.ps1`; `20-build-tables.ps1`;
`30-build-columns.ps1`; `40-build-relationships.ps1`;
`50-add-to-solution.ps1`; `55-build-business-process-flows.ps1`;
`57-prune-foreign-tables.ps1`; `60-build-forms-views.ps1`;
`62-build-app-module.ps1`; `64-build-charts-dashboard.ps1`;
`65-build-web-resources.ps1`; `66-seed-synthetic-data.ps1`;
`68-build-security-roles.ps1`; `80-post-build-analysis.ps1`;
`81-build-progress-matrix.ps1`; `82-build-progress-report.ps1`;
`83-submit-feedback.ps1`; `85-verify-idempotency.ps1`; `90-run-build.ps1`;
`95-export-unmanaged-solution.ps1`; `helpers/reporting-wizard.ps1`;
`helpers/wizard-telemetry.ps1` under `scripts/bootstrap/`.

These changes route application artifacts through the target root and add
boundary checks across wizard/build/report stages.

### Modified tests (15)

`scripts/ci/RelationshipPayload.Tests.ps1`;
`test-app-module-rerun.ps1`; `test-docs-consistency.ps1`;
`test-form-population.ps1`; `test-idempotency-and-export-stages.ps1`;
`test-live-report-generation.ps1`; `test-post-build-analysis.ps1`;
`test-preview-nonmutation.ps1`; `test-report-wizard.ps1`;
`test-reporting-and-data-stages.ps1`; `test-run-state-persistence.ps1`;
`test-security-role-stage.ps1`; `test-wizard-modes.ps1`;
`test-wizard-source-control-acceptance.ps1`; all under `scripts/ci/`.

## D. Framework Source Protection

Implementation evidence is primarily in
`scripts/bootstrap/helpers/wizard-source-protection.ps1` and
`scripts/bootstrap/framework-maintenance.ps1`.

| Control | Assessment | Evidence and limitation |
|---|---|---|
| Distinct framework and target roots; explicit target | **Implemented and tested** | `wizard-source-protection.ps1:48–83` resolves both roots, requires an existing explicit target, and rejects identical/nested roots. |
| Path traversal, symlinks, nested repositories | **Implemented and tested, with coverage limits** | `:3–29`, `:84–97`, `:104–132` resolve physical paths and guard selected trees. Fixtures test representative cases, not every filesystem/platform edge. |
| Generated artifacts directed to target | **Implemented; not exhaustively verified** | Main wizard/build/report stages initialize context and guard paths; examples include `05-start-wizard.ps1` and `90-run-build.ps1`. Not every writer was executed in this audit. |
| Reject framework repository before file generation | **Missing** | Initialization at `:74–101` validates roots but does not compare Git identities. Identity checks are separate at `:158–179`; a distinct clone can pass the root check and receive generated artifacts before later Git checks. |
| Reject framework repository before Git operations | **Implemented for guarded operations; incomplete** | `:158–179` compares physical repository roots and normalized remotes. `80-post-build-analysis.ps1:1025–1056` guards its README Git flow. The audit search found no other production caller of this Git-operation guard. |
| Owner/admin cannot bypass source protection | **Partially implemented; not enforced at OS level** | Guarded writes are caller-independent, but direct filesystem operations remain possible. The “repository owner” test invokes the same helper and does not exercise OS permissions or bypass behavior. |
| Framework Maintenance Mode | **Authorization checker implemented; operation enforcement missing** | `framework-maintenance.ps1:48–119` checks a dedicated branch, separate approval switches, and exact paths, then returns an object. It does not mediate subsequent writes, commits, or pushes. |
| Read-only filesystem or packaged framework | **Missing** | No read-only installation/package enforcement was found. Distribution guidance is documentation, not a filesystem boundary. |
| All generated output confined to target | **Mostly implemented; not exhaustively tested** | Planning, reports, telemetry, and build artifacts are routed/guarded in inspected paths. Not every generation path was executed. |

The source-protection test verifies shared-remote rejection when the Git
operation guard is called (`test-framework-source-protection.ps1:88–94`).
It does not test same-framework-repository rejection before generation.

## E. Scenario Isolation

Examples remain in scenario-scoped directories such as
`specs/federal-foia-management/` and
`payloads/scenarios/federal-foia-management/`; Contoso content is similarly
scenario-scoped. The remediation diff did not modify example assets.

Positive evidence: `scripts/ci/test-wizard-modes.ps1:50–59, 152–171` creates a
fresh target workspace with empty `payloads`, copies only contract files, and
generates an unrelated equipment-checkout scenario.

Residual coupling:

- `scripts/bootstrap/62-build-app-module.ps1` contains a runtime rewrite for
  dashboard titles beginning with `Federal FOIA`.
- `scripts/bootstrap/65-build-web-resources.ps1` includes `cct_priority` as one
  candidate in a priority-field fallback.
- `.github/skills/dataverse-report-wizard/SKILL.md:166–170` uses
  `contoso_customer_service` in a sample configuration. It is not a runtime
  default, but could be copied as-is.
- `scripts/bootstrap/helpers/wizard-hardening.ps1:107–112` auto-selects the
  only scenario in a project when no slug is supplied. This is useful for an
  existing project but means a single example scenario is not strictly opt-in.
- Other matches include harmless usage examples such as Contoso names.

**Assessment:** the tested clean-target intake does not copy example payloads,
but there is no dedicated test proving every unrelated build path remains
contamination-free or that examples are never implicitly selected.

## F. GitHub Security

Verified GitHub metadata:

- Repository is **public**, with default branch `main`.
- Collaborator listing returned only `bradlaw76` with `admin` role.
- All listed branches were reported `protected: false`.
- `.github/workflows/wizard-quality.yml:3–4` grants `contents: read`; checkout
  at `:21–24` uses `persist-credentials: false`.
- No releases were listed.
- Tag `pre-fast-20261015` points to commit
  `17bebe3fb2322c2ad07c05dec8ef0c64dba6df28`; GitHub marks it unsigned and
  unverified.
- `.github/workflows/dataverse-integration.yml:3–15, 22–39` is manually
  triggered and gated by exact disposable-environment confirmation; it does
  not declare repository write permissions.

**Unable to verify:** rulesets and bypass rules, deploy keys, installed GitHub
Apps, automation-token permissions, and code-/secret-scanning settings. The
available scanning API requests returned 403. Unavailable controls are not
assumed to be configured.

Because branches are reported unprotected, required pull-request reviews,
required checks, force-push restrictions, branch-deletion restrictions, and
administrator bypass limits are not demonstrated.

## G. Backup and Recovery

- Baseline `main` remains at `1bb72aacc6bc6abb9eb6aaaf3f492737fc115d95`.
- Remote branch `backup/pre-fast-20261015` and tag `pre-fast-20261015` point to
  `17bebe3fb2322c2ad07c05dec8ef0c64dba6df28`. The tag message says
  “Verified wizard baseline before FAST integration,” but it predates the
  requested baseline and is unsigned.
- No Git bundle, checksum manifest, or disposable restore evidence was found.
- No recovery operation was attempted during this read-only audit.
- The audit worktree and stash were empty.

**Conclusion:** Git history and remote refs provide recovery points, but a
restoration was not demonstrated. This is an untested-recovery gap, not proof
that no checkpoint exists.

## H. Test Results

No tests were executed during this read-only audit. The following results come
from the prior implementation-validation record and were not independently
reproduced in this audit:

| Test or command | Reported result | Does it exercise the claimed control? |
|---|---|---|
| 25 standalone `scripts/ci/test-*.ps1` checks | 25 passed, 0 failed | Broad regression coverage, including source protection and scenario tests |
| Pester suites | 90 passed, 0 failed | Regression coverage; not OS-level immutability or early same-repository rejection |
| `scripts/ci/test-framework-source-protection.ps1` | Passed | Representative paths, symlink, nested repo, shared remote when Git guard is called, maintenance checks; does not test pre-generation clone rejection or bypass |
| `scripts/ci/test-wizard-modes.ps1` | Passed | Demonstrates generic intake in a clean target; not every build-stage contamination path |
| PowerShell parser checks | Passed | Syntax validation |
| Markdown lint | Passed | Documentation style |
| JSON/schema and contract checks | Passed | Schema and contract integrity, not runtime source enforcement |
| PSScriptAnalyzer local run | Not completed; PSGallery unavailable | No local result for remediation branch |
| CodeQL/review validation | No CodeQL-analyzable language reported; review could not initialize | Not a substantive security pass |

The latest visible GitHub Wizard Quality run was [run #43](https://github.com/bradlaw76/power-platform-vscode-starter/actions/runs/38810031493),
completed successfully on 2026-10-15 at the **baseline `main` SHA**, not the
remediation SHA. Its job reported markdown lint, pinned PSScriptAnalyzer,
PowerShell parsing, JSON, contract, standalone CI, and Pester steps succeeded.
GitHub reported zero Wizard Quality runs for the remediation branch. No live
Dataverse or recovery tests were performed during this audit.

## I. Prioritized Findings

Priority scale: Critical 9–10; Moderate 5–8; Low 1–4.

### Critical

#### 1. Target Git identity is not validated before generation — 10/10

- **Evidence:** `wizard-source-protection.ps1:74–101` initializes roots without
  Git identity checks. Identity checks are separate at `:158–179`, and are
  invoked later in `80-post-build-analysis.ps1:1025–1056`.
- **Risk:** A separate clone of the framework can pass physical-root checks
  and receive application artifacts before any later Git operation is checked.
- **Status:** Confirmed missing control.
- **Remediation:** Validate canonical target repository identity during
  application-context initialization, before any writer runs.
- **Verification:** Test same-framework remote clones, alternate URL forms,
  missing remotes, worktrees, and a target that is not the repository root.

#### 2. Source protection and maintenance are bypassable — 9/10

- **Evidence:** `framework-maintenance.ps1:48–119` returns an authorization
  object and does not mediate operations. Path protection applies only to
  callers that invoke its helpers. No read-only filesystem boundary was found.
- **Risk:** An owner can directly edit framework files or run Git operations
  without invoking the authorization helper.
- **Status:** Confirmed enforcement gap; helper-level checks exist.
- **Remediation:** Use a read-only/package installation for application
  authoring and make maintenance an operation-enforcing, separately authorized
  workflow.
- **Verification:** Test direct owner-level file writes and stage/commit/push
  attempts, as well as approved maintenance operations, in an isolated fixture.

### Moderate

#### 3. No branch protection is reported — 8/10

- **Evidence:** GitHub reports all listed branches `protected: false`; the
  repository is public. Rulesets were unavailable to inspect.
- **Risk:** Review, CI, force-push, deletion, and bypass controls are not
  demonstrated.
- **Status:** Branch status verified; ruleset details unable to verify.
- **Remediation:** Configure and independently verify required reviews/checks,
  force-push/deletion restrictions, and administrator bypass policy.
- **Verification:** Inspect effective GitHub branch/ruleset settings.

#### 4. Remediation has no PR or Wizard Quality run — 7/10

- **Evidence:** No PR is associated with the remediation branch and GitHub
  reported zero Wizard Quality runs there. The latest successful run is on
  baseline `main`.
- **Risk:** The remediation has not received GitHub CI validation at its
  current SHA.
- **Status:** Verified.
- **Remediation:** Run quality CI against the exact remediation commit and
  complete reviewed integration before merge.
- **Verification:** Confirm successful checks tied to the remediation SHA.

#### 5. Dataverse integration workflow omits target-root setup — 6/10

- **Evidence:** `.github/workflows/dataverse-integration.yml:97–123` invokes
  scripts without setting or passing `TargetProjectRoot`.
- **Risk:** The workflow is likely incompatible with the explicit-root
  requirement and may use the framework checkout as its workspace.
- **Status:** Strongly indicated by source contract; not dynamically verified.
- **Remediation:** Create and pass an isolated application workspace.
- **Verification:** Add a non-mutating workflow preflight; do not run live
  Dataverse integration until corrected and reviewed.

#### 6. Recovery restoration is untested — 6/10

- **Evidence:** Remote baseline/backup refs exist, but no disposable restore,
  bundle, or checksum verification was found.
- **Risk:** Recovery may be possible from Git but has not been proven operational.
- **Status:** Checkpoints exist; restoration untested.
- **Remediation:** Document recovery and verify it in a disposable clone.
- **Verification:** Record a successful restore and compare expected refs/files.

### Low

#### 7. Scenario-specific references remain in reusable code/examples — 4/10

- **Evidence:** FOIA dashboard-title rewrite in
  `scripts/bootstrap/62-build-app-module.ps1`; `cct_priority` fallback in
  `scripts/bootstrap/65-build-web-resources.ps1`; Contoso sample app in
  `.github/skills/dataverse-report-wizard/SKILL.md:166–170`.
- **Risk:** Limited runtime coupling or copied-example selection.
- **Status:** References confirmed; impact appears bounded.
- **Remediation:** Move scenario-specific values into scenario configuration
  and use neutral placeholders in reusable samples.
- **Verification:** Build an unrelated scenario in a clean target and assert no
  sample identifiers or assets are selected.

## J. Scores and Limitations

| Area | Score / 10 | Basis |
|---|---:|---|
| Framework architecture | 7 | Explicit roots and central helper, but identity validation is late |
| Application/framework isolation | 4 | Useful path checks; no early repository identity check or read-only boundary |
| Scenario neutrality | 7 | Scenario-scoped examples and generic intake test; residual references |
| Repository protection | 3 | Guarded Git calls do not prevent direct bypass |
| GitHub configuration | 2 | Public repo; branches reported unprotected; other controls unavailable |
| Backup and recoverability | 4 | Remote checkpoints exist; restore is untested |
| Automated testing | 7 | Broad reported pass, but critical security cases and branch CI are missing |
| Release/distribution readiness | 3 | Provenance guidance exists; no release/package or read-only distribution |

**Overall maturity: 4/10.** Limitations include the shallow local clone, lack of
remediation-branch CI, inaccessible GitHub settings/scanning APIs, and absence
of a restore test.

## K. Recommended Next Actions

1. Validate target repository identity before any generated file is written.
2. Enforce read-only framework access during application authoring; make
   maintenance authorization enforce actual operations.
3. Configure and verify GitHub branch/ruleset protections.
4. Give the Dataverse integration workflow an isolated target workspace and
   add a non-mutating preflight.
5. Add security tests for same-repository clones, direct owner bypass, and
   unrelated-scenario builds.
6. Test recovery in a disposable clone and record the result.
7. Externalize remaining scenario-specific code and examples; establish
   versioned distribution with provenance and checksums.

## Copyable Review Package

**Summary:** The remediation adds useful target-root and path checks but is not
yet a reliably read-only framework dependency. Target Git identity is not
checked before generation, and maintenance authorization is a voluntary
checker. Overall maturity: **4/10**.

**Git state:** Branch `copilot/extend-use-case-isolation-remediation`;
HEAD/remote HEAD `bbe117a9bb98ce595be4438ca0f035bc37b58bdb`; baseline/main
`1bb72aacc6bc6abb9eb6aaaf3f492737fc115d95`. Worktree clean; upstream divergence
`0 0`; no stash or uncommitted/ignored files. No remediation PR. All branches
were reported unprotected.

**Changed files:** 59 total (4 added, 55 modified; none deleted/relocated), all
committed and pushed: added
`docs/plans/2026-10-19-framework-source-protection-phase-1.md`,
`scripts/bootstrap/framework-maintenance.ps1`,
`scripts/bootstrap/helpers/wizard-source-protection.ps1`, and
`scripts/ci/test-framework-source-protection.ps1`; modified guidance/config
files `.claude/skills/dataverse-report-wizard/SKILL.md`,
`.claude/skills/power-platform-vscode-wizard/SKILL.md`,
`.github/prompts/power-platform-demo-wizard.prompt.md`,
`.github/skills/dataverse-report-wizard/SKILL.md`,
`.github/skills/power-platform-wizard-init/SKILL.md`, `MIGRATION.md`,
`README.md`, `docs/dataverse-report-wizard.md`, `docs/onboarding.md`,
`docs/wizard-contract-v1.md`, `requirements/GithubInstructions_General.md`,
`wizard.profile.json`; bootstrap files
`scripts/bootstrap/00-prereq-check.ps1`, `01-install-skills.ps1`,
`05-start-wizard.ps1`, `06-demo-script-wizard.ps1`, `07-demo-dry-run.ps1`,
`08-report-wizard.ps1`, `10-auth-connect.ps1`, `15-dry-validate.ps1`,
`20-build-tables.ps1`, `30-build-columns.ps1`, `40-build-relationships.ps1`,
`50-add-to-solution.ps1`, `55-build-business-process-flows.ps1`,
`57-prune-foreign-tables.ps1`, `60-build-forms-views.ps1`,
`62-build-app-module.ps1`, `64-build-charts-dashboard.ps1`,
`65-build-web-resources.ps1`, `66-seed-synthetic-data.ps1`,
`68-build-security-roles.ps1`, `80-post-build-analysis.ps1`,
`81-build-progress-matrix.ps1`, `82-build-progress-report.ps1`,
`83-submit-feedback.ps1`, `85-verify-idempotency.ps1`, `90-run-build.ps1`,
`95-export-unmanaged-solution.ps1`, and helpers
`scripts/bootstrap/helpers/reporting-wizard.ps1` and
`scripts/bootstrap/helpers/wizard-telemetry.ps1`; tests
`scripts/ci/RelationshipPayload.Tests.ps1`, `test-app-module-rerun.ps1`,
`test-docs-consistency.ps1`, `test-form-population.ps1`,
`test-idempotency-and-export-stages.ps1`, `test-live-report-generation.ps1`,
`test-post-build-analysis.ps1`, `test-preview-nonmutation.ps1`,
`test-report-wizard.ps1`, `test-reporting-and-data-stages.ps1`,
`test-run-state-persistence.ps1`, `test-security-role-stage.ps1`,
`test-wizard-modes.ps1`, and `test-wizard-source-control-acceptance.ps1`.

**Critical findings:** (1) Priority 10: no Git identity validation before
generation; separate framework clones can pass the physical-root check.
Validate identity before any writer and test same-repository clones. (2)
Priority 9: the maintenance script returns authorization rather than enforcing
file/Git operations; owners can bypass helper calls. Use a read-only framework
distribution and enforce maintenance operations.

**Moderate findings:** (1) Priority 8: branches reported unprotected; configure
and verify branch/ruleset controls. (2) Priority 7: no PR or Wizard Quality run
for remediation; validate exact SHA. (3) Priority 6: integration workflow
omits target-root setup; isolate target and add preflight. (4) Priority 6:
recovery refs exist but no disposable restore has been tested.

**Test results:** No tests were executed during the audit. Prior validation
records report 25 standalone CI checks and 90 Pester tests passing, plus parser,
schema/contract, and Markdown checks. Source-protection tests do not cover
pre-generation same-repository rejection or OS-level/direct-operation bypass.
The latest visible GitHub run #43 passed on baseline `main`, not the remediation
branch. No live Dataverse or recovery test was run.

**Recovery:** `main` baseline `1bb72aacc6bc6abb9eb6aaaf3f492737fc115d95`;
remote `backup/pre-fast-20261015` and tag `pre-fast-20261015` at
`17bebe3fb2322c2ad07c05dec8ef0c64dba6df28` (tag unsigned). No restoration
attempted or verified.

**Next actions:** Validate repository identity before writes; enforce read-only
framework use and operation-enforced maintenance; configure GitHub protections;
fix integration target-root setup; add bypass and contamination tests; verify
recovery in a disposable clone; externalize scenario-specific references and
publish a versioned, provenance-checked distribution.
