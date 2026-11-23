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
edits. Unchanged synchronization conflict holds preserve exit 3 and all document,
journal and adapter bytes; changed inputs resume independent work. Incomplete
non-sync steps are not cached as conflicts. Native Windows guided execution supports Unicode/spaced paths and
child-local UTF-8. POSIX/WSL workers are bounded, explicitly configured local
subprocesses with lease/checkpoint/orphan safeguards, not an OS sandbox or an
installed unattended service. Linux PowerShell was not installed in the tested
WSL environment; native PowerShell-specific tests run on Windows.

Read-only [Status](framework-handoff.md#one-read-only-operational-status) now
projects native task counts, dependencies, resource/owner holds, lease expiry
and timestamped next actions through the existing coordinator. No task-state
write or dispatch occurs. Projected eligibility is not worker authorization;
receipt completion is not completion of every task. Reboot/startup persistence
remains unverified: no persistent Windows controller was established or enabled.

Source and synthetic tests cannot establish native lifecycle, permission,
connector, package deployment or intended-user UI proof. Use the existing
[authorization policy](policies/authorization-and-execution.md) and report
SOURCE COMPLETE, TESTED, DEPLOYED, LIVE VERIFIED and BLOCKED separately.

Q5's isolated new/partial/no-Git/evolving/recovery campaign exercised installed
commands and 34 synthetic memory operations. Its custom review table remained
planning-only. A pinned relationship endpoint change was correctly blocked by
the canonical immutable identity guard; a compatible relationship-intent change
revisited native dependencies. Automatic endpoint migration is not verified.
The new conflict-replay regression passed with changed-input continuation and
non-sync retry coverage; full project logs remain outside the framework source.

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

Q8's [ownership reconciliation](audits/h008-release-consolidation-proposal.md#q8-ownership-and-audit-reconciliation---2026-11-23)
adds exact owner decision paths and fresh rejection-to-retry evidence without
installing protections. The isolated full candidate passed the proposed #6
checker and preserved all 71 frozen historical blobs; its unresolved index and
outgoing-ref gaps still block adoption. Historical base restoration and a fresh
canonical index are alternative owner choices, not interchangeable approvals.
Bounded source/credential checks do not certify ignored files or live identity.

Use an explicit non-OneDrive isolated checkout, inspect its exact branch/full
SHA/remotes/dirty state and preserve other writers. Keep project/runtime roots
separate from framework source. Retained source commits and original fixture
hashes are recovery evidence, not a backup of dirty files or tenant data.
Historical task-specific backup exceptions do not carry forward. Rollback
requires reviewed scope and applicable commit/push or deployment authorization;
no automatic reset, full-workspace restore or import is provided.

## Release candidate notes - 2026-11-23

**Status:** reviewable H008 source/synthetic candidate in existing PR #13, not
merged main, a published package/tag, a deployed app or an unattended service.
Runtime baseline is `563aa7361cc3a1648827dd6d8bc765f5eb77bd10`; final documentation
commit/CI and the full acceptance matrix are recorded in the single external
consolidation report and maintainer ledger. No new H-number is allocated.

### User-facing changes

- Accepted standard/custom table selection and relationship meaning survive
  intake; existing components and source-only evidence are distinguished from
  missing work and live metadata.
- Native task IDs, manual documents and accepted decisions remain intact through
  explicit four-document Spec Kit adoption, proportional updates and local holds.
- UTF-8 Windows transport, explicit delivery updates and disabled-sync persistence
  remove avoidable correction/reapproval cycles without granting deployment.
- Durable receipts and canonical journals support interrupted-process resume;
  bounded retries and independent eligibility avoid global stalls.
- Read-only task/lease/dependency Status exposes concrete next actions without
  dispatch. Unchanged sync holds now preserve exit 3 and all bytes/history.
- Explicit `Legacy`/`Demo`/`Acceptance` verification and independent rerun/export
  switches preserve required security/membership gates. Optional workload/source
  notes and strict explicit slugs do not add mandatory business questions.

### Installation, onboarding and migration

Acquire the full authoring runtime at an owner-reviewed commit, not a lone skill
or an assumed latest `main`. Git is needed to acquire a clone, but consumer
projects using an already installed guided runtime need not initialize Git.
Use a non-OneDrive isolated checkout and separate consumer/runtime roots.
No automatic source upgrade, package install or protection-hook activation.

| Path | Required operator behavior |
| --- | --- |
| New project | Follow authoritative onboarding; confirm architecture and scenario planning before build. Explicitly opt in to the installed handoff/synchronization. Custom payloads still need approved semantic field decisions. |
| Existing app/solution | Use `05-start-wizard.ps1 -Retrofit`; inventory current tables/forms/views/relationships and solution first. Keep current state in spec and remaining work in plan. Review `-AdoptionPath` mappings without changing native identifiers. Source evidence is not live existence. |
| Existing project without Git | Guided planning/adoption/rehearsal/Status do not create a repository. Keep accepted source contracts and stable external folders; consumer source-control choices remain explicit. |
| Existing H008 adoption | Resume the same owner, files, IDs and roots. Keep synchronization disabled until explicit enable. Changed source invalidates old receipts; never rewrite them as current/live evidence. |
| Build-profile migration | Preserve scenario, target, payload and effective verification policy; a mismatch requires separately reviewed fresh state, not deleting checkpoints. |
| Relationship migration | Compatible intent changes revisit dependencies; pinned endpoint/kind changes remain protected. No automatic identity migration, deletion/recreation or managed-component rewrite. |

Requirements: PowerShell 7 for native guided commands; explicitly selected
`power-platform-demo-builder` 0.2.1 with Python 3.11+ for H008; full profile,
helpers, schemas and guides. The framework declares no third-party runtime
dependencies; `setuptools>=68` is a build-time dependency, not an auto-install
step. Wizard profile 1.6, contract 1.10.0 and package 0.2.1 are different versions.
PAC CLI/authentication and approved target/semantic contracts are needed for
actual Dataverse work, which was not performed in this campaign.

| Host | Evidence and limits |
| --- | --- |
| Native Windows | Guided new/partial/no-Git intake, handoff, UTF-8, sync, synthetic rehearsal and read-only status verified. Supervised native Windows workers unsupported. |
| WSL/POSIX | Existing bounded worker/orphan/timeout/fair-retry recovery and new conflict replay verified separately. Linux PowerShell was absent; Windows PowerShell tests do not prove Linux equivalents. |
| macOS | Listed as a worker host in the profile; not exercised by this campaign. |
| Machine reboot | No persistent startup controller established, host restart or service enabled; process recovery does not prove reboot persistence. |

### Acceptance and owner decisions

The five source acceptance statements in
[the existing H008 spec](../specs/starter-framework-handoff/spec.md) have
evidence-backed outcomes: **5/5 (100%) source-contract coverage**. This is not
development speed, canonical task completion, promotion authorization, live
application completeness or production readiness. Deployment/public release/
native Windows worker supervision were excluded by that spec, not silently
treated as passed.

Exact main merge authority, canonical audit base/index authority and original
protection repair/adoption decisions remain outstanding. Main is currently
unprotected; passing CI is not enforcement or approval. Do not claim the
uninstalled #6 staged/outgoing hooks or #5 coupled archives are fixed/enabled.
Repository metadata reports secret scanning and push protection enabled, but
alert contents were not inspected and no comprehensive CVE/OS audit was performed.
These existing controls do not enforce branch approvals or repair local hooks.
The manual Dataverse integration workflow was not executed or live-certified;
its confirmation/secrets gates do not replace current scoped deployment approval
and validation of every current scenario/semantic contract.

Recommended next objectives for owner/ChatGPT scoping, without allocating a
number: controlled identity-safe relationship migration; repairs/adoption of
original protection packages; authorized canonical audit restoration; real
deployment/UI/managed-ownership acceptance; and persistent recovery through the
existing canonical controller with separate restart authorization. No competing
controller, automatic cleanup, credential change or public release is proposed.
