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

### Q9 definitive legacy dispositions - 2026-11-23

Fresh ancestry is against Q8 candidate
`7a3e15669ebc957d54ba66bb71053377854f90f7` and main
`632d00cbe38bbee753f4c4e7f4b5d1fb8d4afc8a`, not a cached PR comparison base.
All six original heads are unchanged. Full source/file/ownership evidence and
final publication identifiers remain in the one external report/ledger.

| PR / exact head | Definitive disposition and remaining action |
| --- | --- |
| #3 `c95e02bb750bb84cb5da14217efd9513b3d7795f` | **BLOCKED; generic subset incorporated.** Workload/review-note adaptation is retained, and the requirements-material schema matches. Do not restore old intake/runner/payloads. Separate application ownership and approved Choice migration; cutover-before-schema and absent stage 32 remain unresolved. The approving review was for earlier `8aa1fad640caaea820d7bc2efe9538f37f735dd0`, not authority for a new merge. |
| #4 `8d35b723852dbc0a218a29cebd877d6bc1cc128a` | **INCORPORATED ELSEWHERE in #5 history, not release/main.** A draft targets `copilot/extend-use-case-isolation-remediation`, with three approvals at its head. Its independently reusable semantic planning reference is adapted here; full skills/preflight adoption remains gated. Owner selects whether to retain this historical review vehicle or later close it in favor of repaired #5. |
| #5 `241983d60983df52dc5101310e3037e63e72d5ca` | **BLOCKED; independent subsets adapted.** Explicit-slug guard and semantic planning guidance only. Skills/installer/source protection remain valuable but coupled; retain actual target/no-Git compatibility review and exact repair context. Fix ZIP hidden entries and all-outgoing-history path validation before adoption/release. |
| #6 `e226f0857a8304fafa726db7c60ce846299a0249` | **BLOCKED.** Nine proposed additions are unadopted; mechanically clean does not authorize canonical audit restoration, hooks or CODEOWNERS. Use Q8's exact owner decisions and repair staged/outgoing validation before activation. |
| #7 `d1c96edc1ddb8ab9b6022f62a25e0b7c1f52f7de` | **INCORPORATED ELSEWHERE in candidate, not main.** Exact ancestry, original audit and profile test blobs are retained; current runner extends the same profile policy. Original PR is a draft. No second merge; closure is only proposed after authorized #13 integration and owner disposition. |
| #11 `3b1bafd748a51bf980f73af912d6fbad497a6721` | **INCORPORATED ELSEWHERE in candidate, not main.** Exact ancestry and sustained-execution section remain; later authorization/hand-off guidance supersedes whole-file replacement. No second merge or implicit closure. |

Fresh mechanical merge analysis found ten conflicting paths for #3 and eight
each for #4/#5 against the Q8 candidate; #6 had none. No branch, commit or
worktree merge was created. A divergent blob is not proof of missing behavior,
and an ancestor is not proof of main integration.

The [semantic planning reference](semantic-field-type-standard.md) is the
independently eligible documentation adaptation; it deliberately preserves the
current decision-artifact policy rather than reviving the old field catalog.
It does not install missing semantic validation runtime, add four skills,
activate a protection package or fix application migration.

Order: preserve the tested #13 candidate/#7/#11 history; obtain exact-head
merge authority separately; approve and repair H003/#6; reconcile repaired
PR #5/#4 against current source, no-Git and audit authority; scope #3's residual
application/migration independently. Unblocked planning-reference work need
not wait for these gates. Original PR closure, retargeting, ready-for-review,
merge and protection activation are prepared decisions, not executed actions.

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
| Existing app/solution | Inventory current tables/forms/views/relationships, exact solution and publisher first. For technical retrofit control explicitly select `-Mode advanced-builder -Retrofit`; inspect actual generated identity/current-state fields before build. A flag or inferred recommendation is not metadata proof. Keep current state in spec and remaining work in plan; review `-AdoptionPath` without changing native identifiers. Source evidence is not live existence. |
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

## Version and update status

H009 implements the existing
[PR #15](https://github.com/bradlaw76/power-platform-vscode-starter/pull/15) /
[issue #14](https://github.com/bradlaw76/power-platform-vscode-starter/issues/14).
design under Q14 source authorization. See [current H009 operations](wizard-updates.md)
for offline startup identity, shared explicit choices, trusted-fixture comparison,
ownership-aware preview and guarded recovery. Official publisher policy and
distributed release identity remain unavailable; live Apply fails closed.
Do not present the proposal's illustrative 1.11.0 as installed or available.

Historical pre-H008 main: profile 1.4, contract 1.10.0, intake component 0.7.0.
Merged H008 baseline: profile 1.6, contract 1.10.0, intake component 0.8.2;
H009 intake component 0.9.0. Separate automation package remains 0.2.1.
These versions do not establish wizard release identity.
The observed release listing was empty; historical snapshot/rollback tags and
a moving branch are not official update authority. Offline or unavailable
advice never proves remote freshness. The optional cached repository advisor
script/runbook is absent here; report unavailable rather than execute an
invented fallback. Manual skill review is not transactional synchronization.

Official Apply requires independently trusted provenance, explicit distributable
ownership/target inventory and exact-plan authorization. A committed descriptor
must not embed its own containing commit SHA; generated source-bound envelopes
and file indexes must avoid self-hash cycles. PR #15 remains a design reference,
not a trust root or release authority. Q7-Q12 entries below are historical
checkpoints, not the current H009 implementation state.

## Q7-Q12 finalization and next backlog

### Completed workstreams and delivered evidence

| Workstream | Outcome |
| --- | --- |
| Q7 activation | Tested candidate preserved; PR #13 not merged without exact operation/head/target/method authority |
| Q8 governance | Additive provenance/owner choices and isolated rejected-write recovery verified; canonical restoration and protection activation remain gated |
| Q9 reconciliation | Exact #7/#11 candidate ancestry and #4-in-#5 preserved; independent semantic planning reference adapted without missing runtime claims |
| Q10 H009 | Current design/version gaps and dependency/test handoff prepared in existing owner records; implementation remains gated |
| Q11 operational acceptance | Five fresh native cases, exact human/metadata preservation and four actual WSL recovery tests passed within synthetic scope |
| Q12 documentation | README, installation/adoption/version/recovery/release boundaries reconciled; one external final report/ledger and existing PR coordination retain exact final commit/CI |

Q11 recorded 59 distinct native assertions (65 retained checks), zero unexpected
failures and 47 commands. WSL ran four actual supervisor tests, zero failure/
error/skip, with synthetic local executors. New-app rehearsal performed 34 memory
operations. Retry exhaustion stayed blocked, a live orphan rejected duplicate
dispatch, and normal post-executor-stop resume used a new lease and zero-launch
replay. Process restart evidence does not establish boot persistence.

All four supplied human prefixes/CRLF and existing table/form/view/column/
relationship metadata survived. Publisher/solution IDs are not modeled by the
memory adapter. The no-Git case's native `feder` proposal and later separate
`ppd` contract require explicit pre-build alignment; that case verifies no-Git
adoption/reporting, not custom-schema compatibility. A completed command receipt
had zero completed native tasks; matching inputs did not clear a conflict hold,
and stale evidence remained stale. Status exit0 is not acceptance.

No new runtime API, stage, question or dependency was introduced by Q8-Q12
documentation. Compatibility limits remain: pinned relationship endpoint/kind
changes do not auto-migrate; partial planning/malformed inputs fail explicitly;
native Windows workers are unsupported; changed build verification/target policy
requires new reviewed state; H009 and real publisher/tenant/UI/reboot acceptance
are not delivered. Read historical conflict counts against their named baseline:
Q9's final semantic addition raised #4/#5 from eight to nine conflicts without
rewriting prior observations. Final-source conflict analysis must follow any
future source change, not assume this count forever.

### Release authority process - prepared, not activated

1. Select the exact source and review current owners/dirty state, reviews,
   threads, CI and applicable repository gates. Normal edit/commit/push permission
   does not grant main merge or publication.
2. Obtain an explicit merge operation bound to current PR/head/target/strategy.
   Use the existing head-SHA guard, no admin bypass/auto-merge/branch deletion.
3. Verify resulting main ancestry/tree and warranted post-merge checks. Keep
   source, installed package, synthetic, deployment and UI acceptance separate.
4. Before a tag/package, obtain release identity/version/channel/source and
   publish operation authority, independently reviewed provenance/trust and
   a distributable file inventory. Do not package every tracked historical/
   application file or assume H009's proposal is adopted.
5. Validate exact tagged source, inventory/digests, notes, compatibility and
   recovery expectations, then publish only through the explicitly approved
   process. No tag name, new version or publication command is selected here.
6. Read back immutable tag/artifact/source identities and record package and
   installation verification separately. Never invoke Dataverse from a framework
   release approval or silently overwrite an installed clone.

### Concise PR disposition and dependency matrix

| PR | Current disposition / next owner action |
| --- | --- |
| #13 | Open tested candidate; source/docs prepared, merge requires exact scoped authority |
| #7 / #11 | Exact history incorporated in candidate, not main; no second merge; closure only after owner-approved integration/disposition |
| #6 | Open H003 protection owner lane; staged/outgoing repairs and separate audit/adoption/activation decisions |
| #5 / #4 | Open coupled package / draft intermediate vehicle; #4 in #5, independent guidance adapted; repair ZIP/history and coordinate compatibility/ownership before adoption |
| #3 | Open, generic subset adapted; separate application/Choice-migration/old-runner scope; no whole-file transplant |
| #15 | Draft H009 design; approve/refine a bounded slice and designate owner/base before implementation |

Next backlog is **proposed work, not executable dispatch or allocated H-numbers**:

| Next task | Dependencies and responsible owner |
| --- | --- |
| Preserve/review exact candidate and later post-merge evidence | Existing PR #13 owner/release approver; exact merge grant first |
| Resolve canonical audit base versus fresh index | Repository owner selects authority; preserve all historical blobs |
| Repair index/outgoing checks, then review protection adoption | Existing H003/#6 owner context; activation separately authorized |
| Repair archive hidden entries/outgoing history and reconcile skills | Existing #5/#4 owner context; protection/compatibility and packaging choices |
| Implement approved read-only H009 foundation, then planner/recovery | Existing #15/#14 owner/slice; authoritative identity/binding; trust/ownership before Apply |
| Define typed solution/publisher alignment and evidence-aware fixtures | Proposed planning/runtime objective for existing governance/allocator review; no automatic reinterpretation of native decisions |
| Implement missing semantic enforcement and verify functional surfaces | Approved scenario/type/runtime scope; planning reference is not validator code |
| Run real target publisher/solution/app/UI acceptance | Environment/solution owner authorizes exact target/effects; source tests cannot substitute |

Read-only owner review, requirements refinement and explicit scope selection can
proceed independently; code/activation rows retain their actual dependencies.
No current safe implementation task is created by listing these proposals.
Do not allocate or infer another H-number. Exact commits, test counts/skips,
security availability and owners' remaining decisions live in the one external
report/ledger, not duplicated controllers or fabricated approval records.

Recommended next objectives for owner/ChatGPT scoping, without allocating a
number: controlled identity-safe relationship migration; repairs/adoption of
original protection packages; authorized canonical audit restoration; real
deployment/UI/managed-ownership acceptance; and persistent recovery through the
existing canonical controller with separate restart authorization. No competing
controller, automatic cleanup, credential change or public release is proposed.
