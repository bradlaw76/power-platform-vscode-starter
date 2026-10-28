# FAST, Semantic Fields, Reporting, and Repository Updates Review Guide

## Purpose and release boundary

This is the review entry point for four connected wizard updates: FAST-008A
trusted environment verification, universal semantic-field gates, and
requirements-backed reporting choices, plus the local-first repository update
advisor and timestamped run baselines. Shared runtime, profile, instructions,
documentation, and tests make them one integrated review set.

Review the exact commit containing this document, not the default branch by
assumption. Publication requires separate commit and push approval; a local
checkout alone is not publication. The remote commit and pull request, when
available, are the authoritative publication records.

No default-branch merge, live Dataverse access, deployment, import, or FAST
executor is authorized by this release.

## Verified GitHub backups

The following backup branches were created and their remote SHAs verified on
2026-10-23 before preparing the integrated release:

| Source | Backup branch | Exact commit |
| --- | --- | --- |
| `main` | [`backup/main-before-fast-reporting-20261023-194814`](https://github.com/bradlaw76/power-platform-vscode-starter/tree/backup/main-before-fast-reporting-20261023-194814) | `1bb72aacc6bc6abb9eb6aaaf3f492737fc115d95` |
| `feature/fast-accelerator-catalog` | [`backup/fast-before-reporting-20261023-194814`](https://github.com/bradlaw76/power-platform-vscode-starter/tree/backup/fast-before-reporting-20261023-194814) | `0d1812b9acea61afa750883422d88807f48b4f1d` |

These preserve the existing Git histories on GitHub. They are not an independent
off-site archive, a backup of issues/settings, or a snapshot of uncommitted work.
Neither source branch was moved or rewritten when creating these backups.

The focused implementation baseline is the FAST-007 commit
`0d1812b9acea61afa750883422d88807f48b4f1d`. Compare against that SHA to isolate
these updates. A comparison against `main` also includes earlier FAST work.
The review branch is `review/fast-reporting-integration-20261023`.
The intended draft pull request targets `feature/fast-accelerator-catalog`,
not `main`, so its diff isolates this integrated update. Neither branch will
be merged as part of publication.
After approved publication, use the
[focused comparison](https://github.com/bradlaw76/power-platform-vscode-starter/compare/0d1812b9acea61afa750883422d88807f48b4f1d...review/fast-reporting-integration-20261023).

## Review map

### 1. FAST-008A: trusted evidence, not deployment

Start with the [specification](../specs/fast-008a-trusted-environment-verification/spec.md),
[plan](../specs/fast-008a-trusted-environment-verification/plan.md),
[tasks](../specs/fast-008a-trusted-environment-verification/tasks.md), and
[operator contract](fast-integration/trusted-environment-verification.md).

Key implementation surfaces:

- [Collector entry point](../scripts/accelerators/invoke-trusted-environment-verification.ps1)
  and [collection engine](../scripts/accelerators/trusted-environment-verification.ps1).
- [Signature and provenance validation](../scripts/accelerators/verification-provenance.ps1),
  [environment inspector](../scripts/accelerators/dataverse-environment-inspector.ps1),
  and [readiness engine](../scripts/accelerators/execution-readiness.ps1).
- [Envelope schema](../schemas/accelerators/trusted-environment-verification.schema.json)
  and [acceptance tests](../scripts/ci/test-trusted-environment-verification.ps1).

Check independently supplied certificate trust, actual environment/tenant
identity, exact artifact bindings, certificate validity, expiry, mandatory
observations, read-only transport, and fail-closed unsupported cases.
Authenticated is the default policy. RecordedTest and LocalPlanning are explicit
diagnostics, never authenticated live verification. FAST remains default-off;
FAST-dependent Apply remains blocked and `executionAuthorized` is always false.
All evidence recorded for this milestone is synthetic, not a live-environment
certification. Historical evidence is in the
[FAST-008A validation record](../specs/fast-008a-trusted-environment-verification/validation-evidence.md).

### 2. Semantic-field gates: independent of FAST

Read the [semantic field standard](semantic-field-type-standard.md) and
[scenario plan](../specs/semantic-field-types/plan.md).

- [Decision schema](../schemas/payloads/field-type-decisions.schema.json) and
  [unapproved example](../schemas/examples/field-type-decisions.example.json).
- [Planning/Payload/Metadata validator](../scripts/bootstrap/14-validate-semantic-fields.ps1)
  and [shared implementation](../scripts/bootstrap/helpers/semantic-fields.ps1).
- [Column generation](../scripts/bootstrap/30-build-columns.ps1),
  [orchestrator](../scripts/bootstrap/90-run-build.ps1),
  [export gate](../scripts/bootstrap/95-export-unmanaged-solution.ps1), and
  [semantic regression tests](../scripts/ci/test-semantic-fields.ps1).

Check that business meaning determines type, every field has an approved
decision, categorical text needs an explicitly approved exception, and actual
metadata drift blocks dependent work. Legacy scenarios are not auto-approved.
There is no implicit delete/recreate migration for an incorrectly typed field.
These gates apply to Fully Custom, standard, hybrid, greenfield, and retrofit
workflows, not only accelerator scenarios.

### 3. Reporting: native, HTML, both, or neither

Read the [reporting runbook](live-report-web-resources-runbook.md), then inspect:

- [Intake and consolidated confirmation](../scripts/bootstrap/05-start-wizard.ps1).
- [Reporting selection and approved-plan validation](../scripts/bootstrap/helpers/reporting-plan.ps1).
- [HTML contract](../schemas/payloads/html-reports.schema.json) and
  [unapproved example](../schemas/examples/html-reports.example.json).
- [Native generation](../scripts/bootstrap/64-build-charts-dashboard.ps1),
  [app assembly](../scripts/bootstrap/62-build-app-module.ps1),
  [HTML generation](../scripts/bootstrap/65-build-web-resources.ps1), and
  [orchestrator preflight/resume](../scripts/bootstrap/90-run-build.ps1).
- [HTML regression tests](../scripts/ci/test-live-report-generation.ps1),
  [intake tests](../scripts/ci/test-wizard-modes.ps1), and
  [orchestration tests](../scripts/ci/test-run-state-persistence.ps1).

Native dashboards mean standard Dataverse charts/dashboard components, not an
automatic requirement to use preinstalled dashboards. Demo Builder retains six
business questions plus its consolidated confirmation. Detailed modes ask the
reporting choice directly. Accelerator-enabled confirmation can combine the
choices, for example `fully-custom+html`, without adding a mandatory question.

HTML definitions must cite exact current scenario spec/plan excerpts, mapped
tables and fields, audience, purpose, and matching placement rows. Frontline,
supervisor, and leadership are reusable patterns, not a compulsory trio.
Review the generated queries, not just the labels: version 1 supports total
counts, grouped counts, and recent-record lists. It does not implement filtered
"open/mine/team" totals, joins, currency sums, trends, or custom calculations.
Do not interpret a requirement excerpt as proof of semantic correctness.

Adding HTML resources to a solution does not automatically put them on a form
or sitemap. Placement remains a separately verified handoff. Removing a
definition does not delete an older deployed resource. The focused existing-app
Report Wizard remains native-only. Legacy HTML scenarios need explicitly
approved definitions before regeneration. Both reporting types should be chosen
only when they serve complementary business decisions.

### 4. Repository update advice and source baselines

Read the [approved enhancement spec](../specs/repository-update-advisor/spec.md),
[implementation plan](../specs/repository-update-advisor/plan.md),
[validation tasks](../specs/repository-update-advisor/tasks.md) and
[operator guide](repository-updates.md).

- [Capability catalog](../repository-updates.json) and
  [schemas](../schemas/repository-updates/).
- [Standalone check](../scripts/bootstrap/check-repository-updates.ps1) and
  [shared Git/baseline helper](../scripts/bootstrap/helpers/repository-updates.ps1).
- [Offline regression fixtures](../scripts/ci/test-repository-updates.ps1).

Check that startup uses cached metadata without network by default; fetch is
explicit, isolated and never a pull/merge/tag/push. Changed-path categories
are evidence of affected capabilities, not verified fixes or approvals.
Unknown relevance stays review-needed; explicit selections only filter advice.
Stage 90 records full-commit/UTC/dirty fingerprints and only Apply archives
immutable, scenario/solution/publisher/run-bound records. Preview creates no
manifest provenance, and resume preserves original source identity. Direct
report-only/stage runs do not acquire a stage-90 baseline automatically.

### 5. Shared compatibility and documentation

Inspect the [profile](../wizard.profile.json), [contract](wizard-contract-v1.md),
[README enhancement registry](../README.md#enhancement-registry-and-maintenance-policy),
[authoritative onboarding sequence](onboarding.md), and [build log](build-log.md).
The local contract version is 2.2.0. Instructions, prompt, shared kickoff skill,
Claude skill, requirements guides, and distribution guidance must describe the
same gates. The [quality runner](../run-quality.ps1) now propagates actual lint,
standalone, JSON/contract, and Pester outcomes instead of masking failures.

## Historical integrated validation - 2026-10-23

The complete configured `run-quality.ps1` passed with exit code 0 on 2026-10-23.
It ran against a local 421-file source snapshot outside OneDrive; SHA-256
equality was checked for every copied file before execution.

| Gate | Fresh integrated result |
| --- | --- |
| Markdown lint 0.18.1 | 149 files; zero errors |
| PowerShell parsing | Passed |
| PSScriptAnalyzer 1.24.0 | Zero findings |
| JSON/schema | 158 documents parsed; 22 payloads and 48 accelerator documents matched schemas |
| Contract integrity | Passed |
| Remaining standalone suites | 34 of 34 passed, including formatter assertions and cleanup |
| Pester 5.7.1 | 126 passed; zero failed, skipped, or not run |
| FAST-008A | 103 assertions; synthetic collection only |
| FAST-007 readiness | 129 assertions |
| Semantic-field validation | 83 checks |

The initial integrated run returned exit code 1 because the CLI verification
test reused a certificate valid only around its fixed October 19 simulation
clock. Its CLI invocation correctly used the current clock. A test-only fix
creates a separate current-time ephemeral certificate and asserts the observed
timestamp; fixed-clock engine tests and production trust checks are unchanged.
The focused repeat and the subsequent complete aggregate both passed.
Final documentation-only evidence edits are checked separately with the pinned
Markdown linter and documentation/contract consistency checks.

Validation uses synthetic fixtures only. It does not establish live Dataverse
compatibility or replace functional app-surface testing. Historical OneDrive
formatter cleanup failures are distinct from this fresh, fully passing isolated
aggregate. The original failure and its fix remain part of the release evidence,
not a reason to describe the initial run as successful.

## Current integrated validation - 2026-10-27

The complete `run-quality.ps1` passed with exit code 0 on an isolated,
hash-verified 434-file source snapshot that included the repository update
advisor and approved existing integration changes: 151 Markdown files,
PowerShell parsing, zero PSScriptAnalyzer findings, JSON/schema and contract
validation, all 35 remaining standalone suites, and all 128 Pester tests.
There were zero failed, skipped or not-run Pester tests.

Final documentation-only review/handoff evidence additions are checked
separately with the pinned Markdown linter and documentation/contract checks.
See the [build log](build-log.md#complete-integration-publication-validation---2026-10-27)
for exact counts and scope. No live Dataverse work or default-branch merge is
part of this publication. Commit and origin push of all current work on the
review branch were explicitly approved; creating or merging a pull request is
not part of that approval.

## Ready-to-use ChatGPT review prompt

> Review the branch/commit containing `docs/fast-reporting-review-guide.md` in
> `bradlaw76/power-platform-vscode-starter`. First confirm you can read that
> exact revision. Compare it with baseline
> `0d1812b9acea61afa750883422d88807f48b4f1d`, including new files.
> Review FAST-008A, semantic-field gates, reporting intake/generation, repository
> update advice and immutable run source baselines, and their
> shared orchestration/profile/documentation surfaces. Trace approval and error
> paths; verify default-off FAST behavior, no execution authorization, no
> unapproved schema changes, accurate query scope, and preserved rerun behavior.
> Verify local-first checks, explicit fetch isolation, unknown capability
> relevance, immutable Apply records and Preview non-mutation.
> Distinguish implementation defects from documented limitations and future
> work. Do not assume native and HTML reports are interchangeable or that HTML
> placement is automatic. Do not run live collection, deployment, import, or
> cleanup. Report actionable findings with severity, exact file/line, evidence,
> user impact, and a minimal fix. Separate tests actually run from static
> inspection, and identify any inaccessible files or unverified claims.

If ChatGPT cannot access the intended revision, supply that branch/commit or a
sanitized source archive. Default-branch visibility alone is not sufficient.
