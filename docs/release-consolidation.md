# Release consolidation and verified operating modes

This is H008 candidate integration, not a new controller or H-number. Source
proposal, tested candidate, merged main, installed package, deployment and UI
acceptance are separate outcomes. Exact commits/CI belong in the existing
build log, PR #13 and the requested external release report.

## Installation and adoption

1. Select the repository/workspace and inspect its current revision and dirty
   state. Preserve existing instructions, applications and owner branches.
2. Follow [onboarding](onboarding.md) for actual tooling and bootstrap order.
   Native PowerShell guided planning/handoff needs neither consumer Git nor WSL.
3. A copied skill is not runtime installation. Use the existing
   [distribution review](skill-distribution.md); do not activate unmerged
   installers, protection hooks or security settings implicitly.
4. H008 uses an explicitly selected installed framework 0.2.1 environment,
   accepted contract, separate external project/runtime roots and existing
   Spec Kit documents. Follow [the handoff guide](framework-handoff.md).
5. Opt in to synchronization separately. Preserve native aliases, manual text,
   owner claims, original source identity and disabled synchronization on resume.

No public package release, system install, hook activation or tenant deployment
is implied by this candidate.

## Three independent mode selections

Optional new-Dynamics workload and source-note inputs follow
[the wizard contract](wizard-contract-v1.md#optional-workload-and-reviewed-source-input).
They add no mandatory Demo Builder prompt or build stage and authorize no
first-party product installation, existing-app mutation or source fetching.

| Selection | Values | Meaning |
| --- | --- | --- |
| Discovery | Demo Builder, Advanced Builder, Framework Acceptance | Planning depth and existing confirmations |
| Execution | Preview (default), Apply | Preview or separately authorized mutation |
| Verification | Legacy (default), Demo, Acceptance | Optional second-pass/export deliverables |

`Legacy` and `Acceptance` preserve existing payload-dependent second passes and
unmanaged export. Acceptance does not add comprehensive coverage for every
component. `Demo` preserves first-pass stages, selected optional components,
security-role construction, final membership enforcement and post-build analysis.
It skips the optional second-pass group and export unless explicitly requested.

After accepted planning, safe preview examples:

```powershell
pwsh .\scripts\bootstrap\90-run-build.ps1 -ScenarioSlug sample -Mode Preview -VerificationProfile Demo
pwsh .\scripts\bootstrap\90-run-build.ps1 -ScenarioSlug sample -Mode Preview -VerificationProfile Demo -VerifyIdempotency -ExportSolution
```

`-VerifyIdempotency` still needs supported reporting/data/security payloads.
`-ExportSolution` never bypasses membership/export gates. Neither authorizes
Apply or changes a delivery goal into acceptance evidence. Do not automatically
map Demo Builder or connected-demo to Demo verification; reuse the existing
consolidated confirmation, not an extra questionnaire.

## Durable recovery and verification

Build resume binds scenario, target, payload folder, execution mode and effective
verification policy. A changed profile, Preview/Apply mode, rerun/export decision
or pre-policy state is rejected. Preserve the old evidence and start a separately
reviewed fresh run; never delete state merely to force a match. Same-policy
resume skips already completed stages.

H008 recovery separately uses canonical tasks/journals and input hashes. An
adapter crash does not permit reclaiming another owner or overwriting human
edits. Native Windows guided execution supports Unicode/spaced paths and
child-local UTF-8. POSIX/WSL workers are bounded, explicitly configured local
subprocesses with lease/checkpoint/orphan safeguards, not an OS sandbox or an
installed unattended service. Linux PowerShell was not installed in the tested
WSL environment; native PowerShell-specific tests run on Windows.

Source and synthetic tests cannot establish native lifecycle, permission,
connector, package deployment or intended-user UI proof. Use the existing
[authorization policy](policies/authorization-and-execution.md) and report
SOURCE COMPLETE, TESTED, DEPLOYED, LIVE VERIFIED and BLOCKED separately.

## Dependency-aware PR sequence

| Lane | Candidate outcome / prerequisite |
| --- | --- |
| #13 | H008 repairs and eligible Q2 adaptations; merge requires explicit scoped permission, applicable repository gates and exact-head CI; PR permission alone is insufficient |
| #11 | INCORPORATED ELSEWHERE: exact history is in candidate, not main; no additional integration or closure performed |
| #7 | INCORPORATED ELSEWHERE: exact history/profiles are in candidate, not main; no duplicate integration or closure |
| #6 | BLOCKED: protection adoption and approved maintenance context; unresolved pre-push outgoing-ref and staged-blob review findings must be fixed before activation |
| #5 | BLOCKED, partial guard adapted: coupled protection/install/skills, strict Git identity/no-Git reconciliation and unresolved ZIP/outgoing-history review findings remain |
| #4 | INCORPORATED ELSEWHERE in #5, not release/main: draft targets an intermediate branch; historical approvals do not approve #5; closure only proposed after owner disposition |
| #3 | INCORPORATED ELSEWHERE, generic subset only: optional workload/schema/notes adapted; full PR remains blocked by application scope, old runner and unresolved Choice-migration sequencing |

Normal main integration order is owner-approved #13 with candidate #11/#7,
then owner-reviewed protection #6, reconciled #5/#4 and separately scoped #3.
Q2's independent adaptations do not approve or supersede the original PRs.
The #3 full merge has ten conflicting paths and #5 has six at the recorded
Q1 candidate; do not resolve these by overwriting current runtime or policies.
Do not auto-close another owner's PR, remove application history or infer
authorization from mergeability, credentials, a deadline or absent rulesets.

## Audit provenance

The historical canonical path is identifiable, but unmerged #5 and #6 contain
different maintenance records. The
[additive audit proposal](audits/h008-release-consolidation-proposal.md)
records immutable provenance and the required owner selection without inventing
or combining historical approvals/results. No canonical audit restoration or
protection bypass is claimed.

Q3's [governance baseline](audits/h008-release-consolidation-proposal.md#q3-evidence-based-governance-baseline---2026-11-23)
records immutable audit blob IDs, historical versus current authority,
H-number/writer ownership and tested versus unavailable protections. Five
current installed boundary tests passed; direct uninstalled #6 hooks in a
synthetic repository demonstrated six rejections, but the staged-blob and
outgoing-ref gaps were reproduced unfixed. No hook or server protection was
enabled. Passing CI does not enforce an unprotected main branch.

Use an explicit non-OneDrive isolated checkout, inspect its exact branch/full
SHA/remotes/dirty state and preserve other writers. Keep project/runtime roots
separate from framework source. Retained source commits and original fixture
hashes are recovery evidence, not a backup of dirty files or tenant data.
Historical task-specific backup exceptions do not carry forward. Rollback
requires reviewed scope and applicable commit/push or deployment authorization;
no automatic reset, full-workspace restore or import is provided.
