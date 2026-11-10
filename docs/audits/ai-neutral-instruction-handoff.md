# AI-neutral instruction and implementation handoff

## Review snapshot: 2026-11-10 UTC

This document is for a person or any AI helping generate instructions, implement
changes, or review the Power Platform VS Code starter. It follows the existing
review-handoff model: exact context, authorization, implementation inventory,
evidence, limitations, findings, and next decisions. It does not depend on a
particular chat product, model, IDE assistant, or access to an earlier conversation.

Start with the current repository and this document, not assumptions from its
filename. Reverify branch heads and links before acting. A handoff conveys context;
it does not grant new permissions or make a proposed capability implemented.

- Repository: `bradlaw76/power-platform-vscode-starter`.
- Baseline: `4c9d2bfac675812a8fbe100b94c05ebe4c4bed1e` (`main`).
- Isolated branch: `test/ai-neutral-handoff-20261110`.
- Purpose: test a streamlined, explicit demo delivery verification profile and
  prepare reusable instruction-generation guidance for owner review.
- Excluded: merge, release, deployment, authentication, live tenant changes,
  application development, existing PR edits, history cleanup, and SSA changes.
- This repository is public. Keep tenant identities, customer data, secrets,
  private application requirements, and access-bearing URLs out of this handoff.

## Executive assessment

The starter already has substantial API-driven construction, solution isolation,
scoped publishing, payload validation, reporting/data/role stages, retry helpers,
run state, idempotency evidence, and unmanaged export inspection. Reuse these
instead of designing another pipeline or making every demo a framework audit.

At the reviewed baseline, discovery modes change intake depth, not execution.
The build runner independently uses `Preview` or `Apply`. Reporting, data, or
security-role payloads enable a second pass; unmanaged export is always enabled.
Consequently, selecting Demo Builder at intake does not make delivery lightweight.
This update introduces an explicit verification policy without changing the
meaning of either intake mode or mutation mode.

## Implemented isolated update

Changed `scripts/bootstrap/90-run-build.ps1` and added
`scripts/ci/test-verification-profiles.ps1` plus this document. Existing workflow
auto-discovers `test-*.ps1`; no new CI workflow or live integration trigger is added.

### Three independent decisions

1. Intake: existing `demo-builder`, `advanced-builder`, or `framework-acceptance`.
2. Execution: existing `Preview` (default) or explicitly authorized `Apply`.
3. Delivery verification: new `Legacy` (default), `Demo`, or `Acceptance`.

`Legacy` and `Acceptance` retain existing payload-dependent second-pass checks
and export. Acceptance is not a new exhaustive testing engine. Its existing
second pass still requires reporting, data, or role payloads; it does not rerun
every stage or prove every component type is idempotent.

`Demo` retains validation, first-pass construction, optional components selected
by the scenario, security-role construction, final membership enforcement and
post-build analysis. It skips the optional second-pass group and unmanaged
export unless separately selected:

```powershell
# Safe preview; no tenant authentication is needed for this command.
pwsh ./scripts/bootstrap/90-run-build.ps1 -ScenarioSlug contoso-case-tracker -Mode Preview -VerificationProfile Demo

# Independently request both additional deliverables, still in preview.
pwsh ./scripts/bootstrap/90-run-build.ps1 -ScenarioSlug contoso-case-tracker -Mode Preview -VerificationProfile Demo -VerifyIdempotency -ExportSolution
```

`-VerifyIdempotency` retains the existing supported-payload prerequisite. It does
not invent baseline coverage for scenarios without reporting/data/roles.
`-ExportSolution` does not bypass the final membership gate, package inspection,
or existing export restrictions. Neither switch authorizes a live operation.
Changing to Apply requires the existing explicit environment, solution, publisher,
and authentication context plus the owner's actual authorization.

The effective profile, rerun/export decisions, and execution mode now participate
in resume identity. Cross-policy or Preview-to-Apply resume is rejected. Older
saved state must start fresh without `-Resume`; do not delete evidence to force a
match. Same-policy resume remains available. Payload content hashes and freshness
checks are not added by this change.

### Deliberately not claimed

- No automatic mapping from intake Demo Builder to runtime Demo. Callers must
  select the new profile explicitly. Entrypoint mapping is a later integration.
- No new browser journey, role impersonation, live smoke test or usability proof.
- No new universal dependency validator or stricter publishing failure policy.
- No changes to component matching, scoped publishing, security, duplicates,
  approval logic, API retry rules, or export implementation.
- No claim that a successful summary means all live behavior was demonstrated.
  The existing post-build invocation remains `PreviewOnly = $true`.
- No proof that unsupported component categories are covered by membership or
  export checks. Examine their actual inventory contracts.

## Validation and reproducibility

The new suite executes a copied, unmodified candidate runner and its real path
and state helpers in a unique temporary directory. Only stage bodies are replaced
with recording stubs. Synthetic values use an invalid network destination; no
stub performs network, authentication, PAC, or Dataverse calls. Cleanup removes
only that suite's temporary fixture and restores its token environment variable.

It checks Preview/Apply across all profiles, preserved first-pass/security gates,
independent opt-ins, summary metadata, incompatible resume rejection,
same-policy resume, and fail-fast export suppression on membership failure.
This is orchestration evidence, not proof of live stage correctness. Existing
stage-specific regressions remain required.

Run from the isolated checkout with PowerShell 7 and repository prerequisites:

```powershell
pwsh -NoProfile -File scripts/ci/test-verification-profiles.ps1
pwsh -NoProfile -File scripts/ci/test-idempotency-and-export-stages.ps1
pwsh -NoProfile -File scripts/ci/test-preview-nonmutation.ps1
pwsh -NoProfile -File scripts/ci/test-run-state-persistence.ps1
```

Run the complete `Wizard Quality` workflow before any approved merge: pinned
Markdown lint, PowerShell parsing, PSScriptAnalyzer, JSON/schema validation,
contract checks, every standalone script, and pinned Pester. Record actual
results against the final commit, distinguishing passed, failed, blocked,
skipped and never run. Do not reuse another branch's CI as candidate evidence.

### Actual local validation before publication

On Linux with PowerShell 7.4.6, the candidate passed:

- All 25 standalone suites, including JSON validation (84 documents, 60 schema
  matches), existing export/idempotency, preview and run-state suites.
- New profile suite: 154 assertions, including positional-call compatibility,
  absent-payload handling, preview opt-ins and old-format resume rejection.
- Pester 5.7.1: 90 passed, zero failed/skipped/inconclusive/not run.
- PSScriptAnalyzer 1.24.0: zero findings under repository settings.
- All 66 PowerShell files parsed; Markdown lint 0.18.1: 86 files, zero errors.
- `git diff --check`: passed. Independent code review's positional compatibility
  finding was fixed by appending parameters and adding a regression test.

Validated runtime SHA-256:
`7a8df978d70ebc8c8e44c7deb004d3cd828ad2f845d80e71660bd7ce8d39564e`.
Validated profile test SHA-256:
`8d81e215d7e910760c786528f31d686bc9357d49218e6c405daa258aae21bddb`.
The final documentation-only evidence addition was linted again before publishing.
See the draft PR for published commit and remote CI results; local results do
not establish remote CI completion. Windows execution and live Dataverse/app
journey validation were not run. No claim of production or merge readiness.

## Existing work and integration order

Reviewed open work before editing; all remains untouched:

- [PR #5](https://github.com/bradlaw76/power-platform-vscode-starter/pull/5):
  Skills 1–4 and framework safeguards. Its runner adds mandatory application
  root isolation. Reconcile the small profile patch onto that architecture;
  do not revert its root routing to this older main implementation.
- [PR #3](https://github.com/bradlaw76/power-platform-vscode-starter/pull/3):
  Dynamics workload and requirements intake. Coordinate intake-to-profile
  mapping after its scope and conflicts with #5 are resolved.
- [PR #4](https://github.com/bradlaw76/power-platform-vscode-starter/pull/4):
  earlier skills/preflight vehicle on an intermediate base. It is not a reason
  to duplicate or cherry-pick all predecessor changes again.
- [PR #6](https://github.com/bradlaw76/power-platform-vscode-starter/pull/6):
  repository ownership containment. Preserve historical artifacts and keep
  application work in its designated application repository.

No order here authorizes a merge. Prefer reviewing the tested safeguards in #5,
then reconciling the isolated profile change and intake work, while retaining #6
containment. Recheck all current heads, merge results, conflicts and effective
protections. Historical successful CI or expired artifacts are not current proof.

## Exhaustive lesson and improvement checklist for this review scope

This is exhaustive for the reviewed themes, not a certification of every file.
Each item separates observed baseline behavior from proposed future work.

### A. Scope and instruction quality

- [ ] Specify the outcome, user journey, audience, and definition of done first.
- [ ] Identify framework maintenance versus application work and the correct repo.
- [ ] Pin baseline, branch, expected HEAD, owner and approved paths before edits.
- [ ] Inspect AGENTS/skills and active PRs; preserve concurrent uncommitted work.
- [ ] Distinguish discovery depth, live mutation authorization and verification
  cost. Never infer Apply or tenant permission from the word "demo".
- [ ] List implemented, proposed, unsupported and externally blocked capabilities.
- [ ] Use actual schema fields and supported stage arguments, not plausible
  invented JSON keys, commands or UI controls.
- [ ] Preserve requirements-to-design-to-payload-to-test traceability without
  duplicating entire requirement sets into every handoff.
- [ ] Ask only material unanswered questions; propose reversible defaults for
  review and make consequential assumptions explicit.

### B. Mode-sensitive verification

- [x] Expose an explicit lightweight delivery profile, preserving legacy default.
- [x] Make demo reruns and export independent opt-ins while keeping gates.
- [x] Identify mode and policy in saved state and reject incompatible resume.
- [ ] Map confirmed intake choice to explicit runtime profile in each entrypoint,
  retaining advanced/framework acceptance semantics and caller compatibility.
- [ ] Add focused smoke plans for the intended demo journey: app opens, required
  navigation works, form saves, lookup resolves, view filters correctly, expected
  chart appears, and appropriate user role can perform the intended task.
- [ ] Record results per step, account/role class and environment without secrets;
  failure must stay failure, not disappear into a successful build summary.
- [ ] Keep full offline framework CI mandatory regardless of demo delivery cost.
- [ ] Broaden acceptance coverage only from measured gaps, not blanket repeated
  builds that cost time without testing a new risk.
- [ ] Bind resumed evidence to payload/design content hashes and relevant tool
  versions; invalidate changed stages and their downstream dependents.

### C. API-first authoring and actual usability

- [ ] Prefer supported Dataverse APIs and existing payload stages for repeatable
  authoring; reserve designer/UI work for unsupported semantics or visual review.
- [ ] Check actual API/schema support for forms, views, app navigation, charts,
  dashboards, processes, roles and web resources before promising automation.
- [ ] Preserve native semantic types, choice values, relationship targets,
  requiredness, formats, and alternate keys rather than text-only substitutes.
- [ ] Distinguish a created component from a component included in the intended
  solution, available to the app, published, authorized, and usable by a user.
- [ ] Test generated form population and view business columns, not merely IDs.
- [ ] Validate app dependency closure and expected navigation; explicitly report
  unsupported/unresolved dependencies instead of silently broadening scope.
- [ ] Keep scoped `PublishXml`; baseline forms/views uses scenario entity names.
  It currently warns on some publish failures. Evaluate a fail-closed readiness
  outcome so published usability is not inferred from construction success.
- [ ] Add direct links to approved app/component targets only after verification;
  avoid guessing organization URLs, IDs or access rights.

### D. Solution membership and export

- [x] Keep final `InventoryOnly` plus `EnforceExportGate` even without demo export.
- [ ] Preserve explicit and inherited membership distinctions; a table root can
  account for inherited components without every component having an explicit ID.
- [ ] Test missing, failed, unauthorized and unrelated components independently.
- [ ] Distinguish intended dependency components from accidental contamination.
- [ ] Require fresh membership evidence for the same scenario/solution/run.
- [ ] Retain exact unmanaged export/unpack and expected-root inspection; export
  is a deliverable decision, not evidence that an app journey works.
- [ ] Never import, deploy, delete foreign components, or publish everything as an
  incidental response to an export or membership failure.
- [ ] Keep package provenance and artifact retention guidance with evidence.

### E. Uncertain writes and safe recovery

Observed `helpers/dataverse-runtime.ps1` retries HTTP 429/5xx and selected
connection/timeout errors for requests, including mutations. General retries are
not a universal exactly-once guarantee. This update does not change that helper.

- [ ] Classify operations as reads, deterministic updates, idempotent upserts,
  non-idempotent creates, and long-running operations before choosing retries.
- [ ] If a write response is lost, first query by stable unique identity or
  operation ID. Distinguish absent, applied, mismatched and indeterminate state.
- [ ] Adopt only an exact expected result; do not overwrite a similar object.
- [ ] Retry a create only after absence is established, or use supported unique
  constraints/upsert semantics. Bound retries and honor throttling.
- [ ] Persist correlation IDs, intended stable identity and verification outcome
  without tokens. Keep uncertain operations visible and stop downstream writes.
- [ ] Poll asynchronous jobs with deadline/cancellation handling; accepted is not
  completed and completed is not yet inspected.
- [ ] Test lost response after successful create, stale reads, duplicate names,
  401 refresh, 429 backoff, 5xx, partial batches and rerun after interruption.
- [ ] Use operation-specific recovery; do not imply local atomic JSON writes make
  multiple Dataverse mutations transactional or provide automatic rollback.

### F. Scoped safety and ownership

- [ ] Preserve approval boundaries, exact environment/solution/publisher checks,
  synthetic-data opt-in, security least privilege, and duplicate prevention.
- [ ] Separate proposing a cleanup from executing it. Show affected identities,
  ownership evidence and consequences; require applicable approval.
- [ ] Do not treat a naming prefix alone as ownership or deletion permission.
- [ ] Preserve source-control/application isolation when integrating #5/#6.
- [ ] Keep framework distributions read-only and route application outputs only
  into the authorized application root after that architecture is integrated.
- [ ] Never copy production records to create realistic demo data. Generate
  synthetic, relationally coherent scenarios and bounded record counts.
- [ ] Validate access as the intended user, not just an administrator.
- [ ] Keep credentials out of traces, artifacts, docs, test fixtures and commits.

### G. Evidence and documentation efficiency

- [ ] Maintain one concise current status and a linked detailed evidence index.
- [ ] Append dated corrections without rewriting historical results as current.
- [ ] Separate static/source inspection, stubbed execution, offline stage tests,
  genuine platform tests and live user journeys in every report.
- [ ] Include exact command, tool version, implementation SHA, tested merge SHA,
  outcome, log/artifact link and retention limits when applicable.
- [ ] State skipped or blocked checks and the smallest next action; do not say
  "all tests passed" after running only the new focused suite.
- [ ] Avoid one document per tiny phase; use checklists and links to stable
  contracts rather than duplicating implementation prose.
- [ ] Keep AI-neutral language and full context so another person or assistant
  can continue without the originating conversation.

## Reusable instruction-generation packet

Copy and complete this packet for the next task. Replace placeholders rather
than assuming the next assistant can resolve conversational references.

```text
Outcome and audience:
Repository / application repository:
Baseline SHA / branch / expected HEAD:
Authorized files and operations:
Explicit exclusions and approval boundaries:
Known active PRs and coordination constraints:
Discovery mode / Preview or Apply / verification profile:
Confirmed environment, solution and publisher (no secrets):
Requirement and schema sources:
Implemented capabilities and known unsupported cases:
Proposed plan with per-step success evidence:
Uncertain-write recovery and stop conditions:
Required focused tests, full checks and live checks:
Evidence locations, version information and retention:
Deliverables and owner review questions:
Resume instructions and remaining work:
```

The implementing assistant should inspect first, make the smallest coherent
change, test the final candidate, report findings early, and return a handoff with
actual outcomes. The reviewing assistant should independently check changes,
permission boundaries, negative cases, compatibility and claims. Neither should
merge, deploy, expand access or retry uncertain external writes solely because
this template asks for a complete result.

## Proposed next implementation: persistent scenario handoffs and lean tasks

### Status and how to use this proposal

Added for owner review on 2026-11-10. **Everything in this section is a proposal,
not implemented by PR #7.** The current document is a manually supplied review
reference. It is not automatically loaded, maintained, or enforced by the wizard
or an AI entrypoint. Only the verification-profile runtime change and its tests
in the implementation section are operative.

Give this document to Copilot, another assistant, or a developer with this request:

> Read this handoff and inspect the current repository and open PRs. Produce a
> read-only implementation plan for the proposed persistent scenario handoff,
> conditional tasks, and optional outputs. Identify exact files, contracts,
> compatibility risks, approval boundaries and tests. Do not implement, merge,
> deploy or modify a live environment until the plan is approved.

The plan should reconcile PR #5's application-root isolation and PR #3's intake
changes before selecting an implementation base. The following paths refer to
this reviewed codebase; reverify them on that base. An application scenario's
`specs/<scenario>/handoff.md` must live under its authorized application root,
not in the distributed framework source after root isolation is integrated.

### 1. Automatically maintained scenario handoff

- Initialize `specs/<scenario>/handoff.md` from
  `scripts/bootstrap/05-start-wizard.ps1` alongside `answers.md`, `spec.md`,
  `plan.md`, and `tasks.md`. Show its location at the end of intake.
- Define a versioned handoff contract in `docs/wizard-contract-v1.md`. Include
  scenario identity, repository and current source revision, discovery mode,
  execution mode, verification profile, confirmed scope, latest run ID, completed
  and remaining stages, failed/uncertain operations, evidence links, limitations,
  approval references, next permitted action, and separately owned human notes.
- Treat `.wizard-metrics/runs/<scenario>/current-run.json` and `run-summary.json`
  as execution evidence sources, not Markdown checkboxes. Project their actual
  statuses into the handoff; never infer completion from a generated plan.
- Add a narrowly scoped projection helper, proposed location
  `scripts/bootstrap/helpers/wizard-scenario-handoff.ps1`. This helper does not
  exist yet. Invoke it from `90-run-build.ps1` after durable stage checkpoints,
  resume transitions, handled failures and final summary creation. Initialize
  from intake separately; refresh stale handoffs on the next controlled entry.
- Keep generated content in explicit owned sections and preserve all human notes
  and unrecognized content. Use version checks, atomic file replacement and a
  concurrent-edit check. If preservation cannot be guaranteed, report a conflict
  without overwriting. Never replace the whole document on every checkpoint.
- Do not mask the original build failure if handoff projection fails. Record
  projection failure separately; recover from authoritative run state later.
  A hard process termination cannot guarantee a final projection, so show source
  run ID/timestamp and detect stale content rather than promising perfect sync.
- Record approval provenance and scope without treating an old approval record
  as authority for new actions. Exclude secrets and private customer records.
- Update `.github/copilot-instructions.md`,
  `.github/prompts/power-platform-demo-wizard.prompt.md`,
  `.github/skills/power-platform-wizard-init/SKILL.md`, and
  `.claude/skills/power-platform-vscode-wizard/SKILL.md` to discover and read the
  selected scenario handoff before proposing continuation. Coordinate `CLAUDE.md`
  and planning skills supplied by #5. Do not imply every third-party AI will
  automatically obey repository guidance; manual users still supply the file.
- Add projection tests for initialization, successful and failed stages, resume,
  stale state, missing state, interrupted writes, concurrent edits, human-note
  preservation, output-root isolation and secret redaction. Extend
  `test-run-state-persistence.ps1` and add a dedicated handoff suite; verify
  entrypoint guidance/parity through existing mode/skill checks.

### 2. Generate only the tasks and approvals the scenario needs

The current `05-start-wizard.ps1` templates include unconditional export/unpack
and pack/import tasks, import validation, report reviews, and several separate
approval items. Some generated instructions also name `70-build-web-resources.ps1`
while the runner uses `65-build-web-resources.ps1`. Inspect and reconcile these
actual templates rather than making the new handoff another conflicting list.

- Generate `plan.md` workstreams, validation and `tasks.md` from confirmed
  capabilities, profile, requested outputs and authorization, using stable task
  identifiers and explicit dependencies. Keep these artifacts consistent with
  the runner and handoff; changing only the Markdown checklist is insufficient.
- Include export/unpack only when requested by policy or as a deliverable.
  Include pack/import only for a separately requested deployment workflow with
  an explicit target and approval. Export never implies permission to import.
- For Demo, omit unselected second-pass/acceptance chores from the active task
  list. Retain a short explanation of omitted optional work so a reader can see
  the coverage boundary. Do not remove required framework CI or security checks.
- Combine related approvals into a clear review checkpoint when policy allows,
  and reuse valid approval for unchanged scope instead of repeatedly asking.
  Retain separate approvals when target, data, cost, access, destructive impact
  or other consequential scope changes. Never interpret "lean" as no approval.
- Include data, roles, BPF, reporting and extended artifacts only when applicable;
  preserve required dependency validation and explicitly selected deliverables.
- Regenerate only owned task sections; preserve human tasks, annotations and
  completion evidence. Do not mark a task complete because an AI claims it ran.
- Extend `test-wizard-modes.ps1`, `test-docs-consistency.ps1` and
  `test-script-order.ps1` with mode/capability/output combinations, command-path
  accuracy, no implicit import and approval-boundary regressions.

### 3. Make mind maps and extended reports optional outputs

`80-post-build-analysis.ps1` currently generates mind-map artifacts tested by
`test-post-build-analysis.ps1`. The repository also contains
`81-build-progress-matrix.ps1`, `82-build-progress-report.ps1`,
`08-report-wizard.ps1`, and `helpers/reporting-wizard.ps1`. These have different
purposes; distinguish diagnostic outputs from application-facing report features.

- Propose explicit output choices for mind maps and extended diagnostic reports,
  separate from requested app charts, dashboards and report web resources.
- Preserve minimal run status, errors, scope, safety evidence and the scenario
  handoff even when decorative or extended outputs are disabled.
- Demo should not generate every optional artifact automatically; preserve
  legacy defaults for existing callers and document any deliberate migration.
- Pass choices through intake, plan, runner and post-build analysis without
  changing core validation. Add enabled/disabled output tests and ensure disabled
  artifacts cannot be mistaken for fresh output from the current run.
- Update `test-post-build-analysis.ps1`, reporting tests and contract/docs checks
  only alongside the approved implementation; do not weaken tests merely to
  remove inconvenient output requirements.

### 4. Connect the experience and deepen meaningful verification

- Map a confirmed Demo Builder choice in `05-start-wizard.ps1` and AI entrypoints
  to an explicit Demo verification recommendation/invocation. Keep Preview as
  default. Preserve a conscious Acceptance choice and legacy caller compatibility.
  Do not silently select Apply from intake answers.
- Keep API-first component authoring in existing stages (`20`, `30`, `40`, `50`,
  `60`, `62`, `64`, `65`, `66`, `68`) with capability-specific validation and
  membership evidence. Do not introduce a second competing authoring pipeline.
- Design operation-aware, bounded recovery in
  `helpers/dataverse-runtime.ps1` and affected component stages. Require exact
  identity reconciliation before retrying uncertain creates; extend
  `DataverseRuntime.Tests.ps1` and component rerun tests with lost-response cases.
- Add separately authorized real journey checks informed by
  `07-demo-dry-run.ps1`, app/form/view contracts and intended user roles. Verify
  actual app opening, navigation, record save, lookups and required outputs.
  A proposed new live-smoke harness needs its own contract and explicit failure
  semantics; no existing dry-run document proves those live interactions ran.
- Report focused live results in the scenario handoff separately from stubbed
  CI, static checks and planned steps. Never upgrade a demo to "ready" while
  required journey or publish checks are failed, unknown or unperformed.

### Suggested implementation order after approval

1. Reconcile the selected base with active PRs and define the handoff/task/output
   contracts, ownership, migration and acceptance criteria in a read-only plan.
2. Implement persistent handoff initialization/projection and preservation tests.
3. Align conditional task generation and AI discovery with that contract.
4. Connect confirmed intake to verification profile; add optional output controls
   while preserving minimal evidence and legacy compatibility.
5. Implement bounded recovery and real journey validation as separately reviewed
   changes with suitable non-production authorization.
6. Run focused and full framework CI on every final candidate and the actual
   combined tree. Perform authorized live checks separately; update the handoff
   with actual results. Merge/deployment remain separate decisions.

## Owner review decisions and next steps

1. Review whether Demo's explicit opt-ins and unchanged default match the desired
   workflow; decide how intake should expose the separate profile later.
2. Reconcile with PR #5 application-root routing before integration. Re-run all
   checks on the actual combined tree, including Windows path behavior.
3. Prioritize operation-aware uncertain-write recovery and real journey smoke
   as separate, bounded changes, with explicit non-production authorization.
4. Decide how publish warnings, stale evidence and incomplete live validation
   affect a future "demo ready" outcome. Avoid a new label until it is measured.
5. Require independent review and current full CI before any separately approved
   merge. No live execution or release follows automatically.
