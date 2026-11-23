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
| #13 | H008 repairs and tested source; merge requires owner authorization/review and exact-head CI |
| #11 | Sustained execution guidance incorporated into the owned candidate; does not grant operations |
| #7 | Explicit verification profiles incorporated into the owned candidate; local history integration is not a GitHub/main merge |
| #6 | Owner review of protection/CODEOWNERS/hooks; no activation or security-setting change in H008 |
| #5 | Resolve source conflicts and strict Git identity versus no-Git guided planning before adopting coupled protection/install/skills changes |
| #4 | Contained in #5; historical approvals do not approve a different combined head; owner decides supersession |
| #3 | Separate generic intake from application artifacts; new workload/materials prompts conflict with current inferred Demo Builder budget and need contract reconciliation |

Normal main integration order is owner-approved #13 with candidate #11/#7,
then owner-reviewed protection #6, reconciled #5/#4 and separately scoped #3.
Do not auto-close another owner's PR, remove application history or infer
authorization from mergeability, credentials, a deadline or absent rulesets.

## Audit provenance

The historical canonical path is identifiable, but unmerged #5 and #6 contain
different maintenance records. The
[additive audit proposal](audits/h008-release-consolidation-proposal.md)
records immutable provenance and the required owner selection without inventing
or combining historical approvals/results. No canonical audit restoration or
protection bypass is claimed.
