# Framework Source Protection — Phase 1 Audit and Remediation Plan

## Audit status

Read-only inventory found no existing Phase 1 source-protection audit or
file-level remediation plan. This document records that audit and the approved
remediation scope; it does not authorize unlisted migrations or deployments.

## Architectural requirement

During application authoring, the wizard is a read-only dependency. `FrameworkRoot`
contains wizard scripts, schemas, skills, instructions, CI, templates, and
configuration. The user must explicitly resolve a separate `TargetProjectRoot`
before any generated writes. Application artifacts, including specifications,
payloads, logs, manifests, exports, deployment manifests, and evidence, belong
only beneath the approved target.

Application Authoring Mode must reject identical/overlapping roots, traversal,
symlink redirection outside the target, nested repositories in output trees,
and framework-repository staging, commits, pushes, or PR operations. These are
Critical failures regardless of repository owner or administrator permissions.
Framework Maintenance Mode remains separate and requires a dedicated
`framework-maintenance/<task>` branch plus independent approvals for
modifications, commits, and pushes.

## Read-only audit findings

| Priority | Existing surface | Finding and remediation |
| --- | --- | --- |
| Critical | `scripts/bootstrap/05-start-wizard.ps1` | Previously defaulted `WorkspaceRoot` to the framework checkout and wrote specs, payloads, `.env.ps1`, and telemetry there. Require an explicit target and split framework resource reads from target writes. |
| Critical | `scripts/bootstrap/06-demo-script-wizard.ps1`, `07-demo-dry-run.ps1`, `08-report-wizard.ps1`, `helpers/reporting-wizard.ps1` | Generated demo/rehearsal/report files from the script-derived framework root. Resolve scenario inputs and outputs under the target and read schemas from the framework. |
| Critical | Build stages `00`, `10`, `15`, `20`, `30`, `40`, `50`, `55`, `57`, `60`, `62`, `64`, `65`, `66`, `68`, `80`, `81`, `82`, `83`, `85`, `90`, and `95` | Many derive logs, manifests, reports, evidence, or exports from the framework checkout. Require the resolved target context, propagate it through orchestration, and guard explicit output paths. |
| Critical | `scripts/bootstrap/80-post-build-analysis.ps1` | README staging/commit/push used prompts, but repository mismatch was only a warning. Reject framework identity and verify the target before each Git mutation. |
| High | `scripts/bootstrap/helpers/wizard-telemetry.ps1`, `wizard-hardening.ps1`, `solution-isolation.ps1`, `wizard-run-state.ps1` | Shared writers generate telemetry, validation reports, contamination reports, manifests, and run state; guard each generated destination. |
| High | `docs/wizard-contract-v1.md`, `docs/onboarding.md`, `README.md`, wizard skills/prompts, `requirements/GithubInstructions_General.md` | Existing guidance treated the active checkout as the target. Make the contract authoritative and align entry-point guidance without duplicating policy. |
| High | `scripts/ci/test-wizard-source-control-acceptance.ps1`, `scripts/ci/test-report-wizard.ps1`, CI workflow | Existing tests did not cover framework-as-target rejection, physical path escapes, nested repositories, or separate maintenance approvals. Extend CI security and compatibility coverage. |

## File-level remediation sequence

1. Define the FrameworkRoot/TargetProjectRoot boundary and explicit migration
   policy in `docs/wizard-contract-v1.md`; update the profile contract version.
2. Add a source-level path and repository identity helper. Resolve physical
   paths and fail closed on overlap, traversal, symlink escapes, nested repos,
   and framework Git identity.
3. Refactor authoring, report, demo, build, telemetry, evidence, and export
   writers so framework resources are read-only and generated outputs are
   target-only. Require an explicit target in orchestration.
4. Guard staging, commit, push, and PR operations. Define separate maintenance
   mode approvals and a dedicated branch; do not use app-build authorization
   for framework maintenance.
5. Align the existing onboarding, skills, prompts, and Git standards to the
   contract; add an opt-in migration procedure and do not silently relocate
   existing scenarios.
6. Add mandatory tests for ordinary and owner-level authoring, framework-as-
   target rejection, Git identity, path traversal, symlinks, nested repos,
   maintenance approval boundaries, and existing external project scenarios.
7. Run the existing quality suite, review all changed paths, and scan changed
   files for secrets before any commit or push.

## Approval and compatibility controls

The full plan was explicitly approved before implementation. No scenario is
automatically copied, moved, deleted, or rewritten. Existing scenario files
remain untouched unless the operator separately approves a migration after
reviewing the inventory and destination conflicts. Use
`MIGRATION.md` for the explicit transition procedure.
