# Wizard Contract v1

Status: Active
Version: 1.10.0

## Purpose

Define one canonical workflow contract across discovery, planning, and execution.
All wizard entry points must follow this contract:
- Terminal wizard script
- Chat prompt wizard
- Onboarding documentation
- Requirements guidance

## Optional workload and reviewed-source input

`05-start-wizard.ps1 -ApplicationProfile new-dynamics-365-app` explicitly plans
a separate model-driven app, not an existing-app extension or first-party
Dynamics installation. Confirm module dependencies/licensing before building.
Without the argument, Demo Builder's existing inference is unchanged. Detailed
modes include this value in A0; supplying the argument bypasses A0 only.

`-RequirementsMaterialsFile <review.json>` consumes source-specific notes
validated by [the review schema](../schemas/requirements-materials.schema.json).
Use `decision: none` with an empty materials array, or `provided` with source,
kind, reviewStatus, summary, planningImpact and openQuestions for each material.
Only `reviewed` entries may have a nonempty summary; pending/inaccessible entries
retain empty summaries and unfinished review tasks. No file means
`not-collected`, not an implicit no-materials or approved decision.

The terminal does not read source documents/images or fetch URLs; import only
authorized, redacted human/chat review notes. All fields remain blockquoted in
answers/spec/plan/tasks to prevent source text from injecting contract headings.
Resolve or explicitly defer source questions before planning approval. Source
notes never override accepted architecture, native identities or semantic gates.
Use existing discovery/confirmation in chat; add no mandatory materials or
workload question to Demo Builder.

## Canonical Flow

1. Wizard mode selection (`demo-builder` by default)
2. Mode-specific discovery and technical-design confirmation
3. Optional extension blocks (selected by profile)
4. Source-control plan for the app or demo being created
5. Spec Kit planning gate (`spec.md`, `plan.md`, `tasks.md`)
6. Optional demo script generation
7. Core bootstrap execution modules with approved commit checkpoints
8. Solution inventory and sync
9. Publish and usability validation
10. Optional execution modules
11. Validation, push verification, pull request preparation, and handoff

## Wizard Mode Contract

Every entry point supports exactly three modes. Mode selection changes discovery depth, not planning artifacts or execution modules.

### Demo Builder (default)

- Uses six core business questions plus two delivery questions and one consolidated recommendation confirmation.
- Asks about the idea/outcome, primary user/task, data, experience/lifecycle, demo success/sample data, and target environment/output.
- Infers the application profile, table/form strategy, entry point, landing view, review app, navigation, relationships/reports, solution name, and publisher prefix.
- Shows those technical recommendations together for approval before writing planning artifacts.
- Must not ask about disposable environments, destructive cleanup, retention policy, rerun-proof engineering, or acceptance-run source tags.

### Advanced Builder (explicit)

- Exposes the complete core discovery, architecture intent, entity mapping, user-task, relationship, report, demo-data, solution identity, and source-control controls.
- Must not ask about disposable environments, destructive cleanup, retention policy, or framework rerun-proof evidence.
- Use with `pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Mode advanced-builder`.

### Framework Acceptance (explicit only)

- Includes Advanced Builder controls plus authorized-environment confirmation, isolated timestamped naming, acceptance source tags and hero labels, deterministic rerun evidence, retention policy, separately approved destructive cleanup, and an evidence plan.
- Never select this mode implicitly from an app idea or environment name.
- Use with `pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Mode framework-acceptance`.

All modes emit compatible `answers.md`, `spec.md`, `plan.md`, `tasks.md`, and `report-mappings.md` artifacts and use the shared execution contract below.

Build verification is independently selected with `90-run-build.ps1
-VerificationProfile Legacy|Demo|Acceptance`; `Legacy` remains the default.
`Demo` skips optional second-pass checks/export unless `-VerifyIdempotency` or
`-ExportSolution` is explicitly selected. Existing payload prerequisites and
final membership/security gates remain; `Acceptance` retains the legacy
payload-dependent coverage, not a new exhaustive verifier. Profile selection
never grants Apply authorization or follows automatically from discovery mode/
delivery goal. Resume binds execution mode and effective verification policy.
See [release operating modes](release-consolidation.md).

## Delivery target, timeframe and optional automation

Every mode, including retrofit, first captures (or reuses) two plain-language answers:

1. **Delivery goal:** `prototype`, `presentation-demo`, `connected-demo`, `pilot`, or `production`.
2. **User timeframe:** a date or duration, or `no fixed deadline`.

Demo Builder therefore uses **eight business/delivery questions plus its existing one consolidated design confirmation**. Advanced Builder and Framework Acceptance add the same two shared questions without changing their technical depth. Older scripted `-AnswersFile` fixtures keep their answer order; use `-DeliveryGoal` and `-DeliveryTimeframe` to supply these values explicitly. Otherwise, scripted delivery intent remains `unconfirmed` and must be settled before release.

Generate delivery context into `answers.md`, `spec.md`, `plan.md` and `tasks.md` without inventing a completion estimate. Choose proportional testing based on delivery risk, but do not skip required validation or production gates due to an urgent deadline. Automation starts **off** and is considered only when measurable time saved exceeds setup, verification and recovery overhead and the user opts in. Detect optional tools without installing them; WSL is not a general prerequisite. See [delivery pacing and tooling](delivery-pacing-and-tooling.md).

## Architecture Intent Contract

Demo Builder reuses recognized standard Dataverse tables inside its consolidated
recommendation; availability and view disposition still require verification.
`-AcceptedContractPath` preserves exact accepted table/relationship identities
and records source hashes rather than converting standard Account into a custom
table. Detailed intake rejects contradictions instead of overriding decisions.
Accepted table selection must be complete and unique. Relationships require
accepted endpoints, business meaning and owner evidence; native many-to-many
has no child lookup, while one-to-many requires that lookup.
Optional `-FrameworkRuntimeWorkspace` connects approved planning to the installed
framework; synchronization remains a separate explicit opt-in. See
[handoff and supported hosts](framework-handoff.md).
Read-only Status `task_summary` projects canonical counts,
IDs, dependencies, owner/lease holds, timestamps and next actions without
dispatch or stored lease mutation. Coordinator eligibility is not worker
authorization, and missing/corrupt records never become zero-count success.
Unchanged synchronization conflict holds retain exit 3 without document,
journal or history writes; changed inputs resume and other incomplete steps retry.

Explicit canonical delivery updates also apply to existing adoptions without
re-enabling disabled synchronization. The installed CLI protocol is UTF-8 on
Windows and POSIX; do not strip Unicode from accepted requirements or paths.

First select one supported application profile:

- `standalone-model-driven`
- `dynamics-sales-extension`
- `dynamics-customer-service-extension`
- `dynamics-field-service-extension`
- `generic-dataverse-solution`

Before any build recommendation, either confirm all five architecture intent questions directly in Advanced Builder or Framework Acceptance, or approve the consolidated inferred recommendation in Demo Builder:

1. Is the implementation **OOB extension only**, **custom tables only**, or **hybrid**?
2. If OOB extension: should forms be **updated in place** or **cloned as new business forms**?
3. What is the **required primary entry-point table** (first screen)?
4. What is the **default landing view** for that entry-point table?
5. Which artifacts must the required auto-created or updated **model-driven review app** surface?

Do not proceed to build until architecture intent is captured in the planning artifacts and approved.

After explicit table mapping, the entry-point logical name must resolve to a reused standard table, a planned custom table, or an existing retrofit inventory table. Every planned view must declare a disposition in `views.json`. For a uniquely identified new custom table, the generator emits `adopt-generated-active` when the requested name exactly equals `Active {plural table display name}` and emits `create-custom` for a distinct business view name. Standard, hybrid-standard, shared, preexisting, retrofit, or ambiguously classified tables emit `explicit-decision-required` rather than a guessed disposition. App assembly remains blocked until every explicit decision is resolved and each named saved query resolves in Dataverse.

### View Disposition Contract

`adopt-generated-active` is allowed only when all of the following are proven before mutation:

- The table has a custom-table payload and the current run manifest records it as created by `20-build-tables.ps1` for the same scenario.
- The target is the table's unmanaged, active, public, default Dataverse-generated Active view.
- Its table identity, query type, generated baseline columns, active-record filter, and sort match the generated dependency expected for that table.
- It has not already been marked as owned by another wizard scenario, and no unrelated or preexisting business view is selected by name.

The generated disposition is planning intent only. It does not establish live provenance or authorize mutation; step 60 must still prove every condition above at apply time.

The adoption operation may update only FetchXML, LayoutXML, and the wizard ownership description. It must preserve the saved-query ID, name, active state, public query type, and default status. Reruns may update that same ID only when its ownership marker matches the current scenario. A same-name non-generated view, metadata mismatch, missing creation provenance, standard/shared/preexisting table, or ownership mismatch is a hard stop.

Artifact provenance is scenario-scoped at `.wizard-metrics/artifacts/manifest/<normalized-scenario-slug>/`. Every stage must validate the manifest's scenario slug, solution unique name, and publisher prefix before reading or writing it. A legacy global manifest is untrusted until an operator explicitly runs the validated migration helper; it is never selected automatically. Preview must not create or alter manifest provenance.

`create-custom` always creates or idempotently updates a separate wizard-owned view from its declared columns, filter, and sort. Generated forms and views are never changed by this disposition. Main forms created by the wizard remain separate named forms; generated `Information` forms are never update targets.

## Discovery Contract

### Advanced Question Set (11 core + architecture intake)

Core questions (1–11):
1. What type of demo or app are you building?
2. Is it for Dynamics 365 Sales, Customer Service, Field Service, Contact Center, Power Apps, Power Pages, Copilot Studio, or Dataverse?
3. Who is the target audience?
4. What business problem does it solve?
5. Who are the users?
6. What data tables or entities are needed?
7. What screens, forms, views, pages, flows, or copilots are needed?
8. What does a successful demo look like?
9. What environment should it be built in?
10. Does it need demo data?
11. Should the output be a managed or unmanaged solution?

Architecture intake questions (12–18):
12. Should this build extend OOB tables, use custom tables, or both?
13. If OOB tables are used, should existing forms be updated or new forms be created?
14. What is the required primary entry-point table?
15. What is the default landing view for that entry point?
16. Should the wizard always create/update a model-driven review app with all run artifacts?
17. Which artifacts must be visible in the review app at the end of the run?
18. Which solution unique name is the target for all components?

### Extension Blocks (optional)

- `business-process-flow`: staged lifecycle intake, process root, stage definitions, and BPF execution preferences
- `table-strategy`: standard vs custom table strategy and explicit mapping
- `solution-identity`: new/existing solution and publisher prefix
- `reporting`: explicit report decision, critical/high-frequency table scope, report type and placement, required fields, supported business decision, owner, and validation checklist
- `retrofit`: current-state and remaining-work intake for in-progress projects
- `source-control`: target-repository preflight, scenario branch, work-item traceability, commit checkpoints, discovered validation/CI, pull request handoff, and merge strategy
- `user-tasks`: persona, task, frequency, entry table/view, expected outcome, owner, and done definition
- `demo-data`: conditional table scope, per-table counts, scenarios/states, hero records, relationship distribution, bounded Task activity generation, method, and privacy constraints; Framework Acceptance adds rerun evidence, source tags, retention, and cleanup approval

Relationship planning must identify the referencing and referenced tables, cardinality, requiredness, existing/new status, cascade behavior, and the user task or app surface supported by each relationship.

When demo data is enabled, default scope may be all scenario-created custom tables, but the resolved table list must be shown and approved. Standard reused tables must explicitly choose create, reuse-existing, or both; they are never seeded implicitly. Hero records must identify their table, count, and demo scenario or purpose.

Dataverse Task activity generation is opt-in. When enabled, planning must identify eligible parent tables, latest/all/selected scope, a source-record limit, the ordering field used to determine latest records, and tasks per selected record. The recommended default is the latest 10 parent records per table ordered by `createdon desc`; every-record task creation requires the user to explicitly select `all`.

## Source Control Contract

Apply `requirements/GithubInstructions_General.md` throughout each end user's app or demo lifecycle.

1. Before implementation, inspect the target repository, remote, current/default branch, working tree, recent history, build/package tooling, lockfiles, CI, tests, linting, formatting, and repository instructions.
2. Record a scenario branch, related issue/spec/work item, commit strategy, applicable discovered validation, pull request preference, and merge strategy in scenario planning artifacts.
3. Do not guess validation commands, stage unrelated files, or use the default branch as a scratch workspace.
4. At coherent planning, implementation, validation, and final source checkpoints: inspect status and diff, run applicable validation, stage explicit intended files, and use a typed imperative commit message.
5. Commit and push each require explicit permission; reuse valid scoped
   authorization under [authorization and execution](policies/authorization-and-execution.md).
   Ask only for missing scope; neither operation authorizes merge or deployment.
6. After push, verify that the remote branch contains the local commit before reporting remote success.
7. Distinguish modified locally, committed locally, pushed, pull request opened, merged, released, and deployed.

## Planning Contract

The canonical [authorization and execution policy](policies/authorization-and-execution.md)
also governs accepted requirements reuse, standing scoped nonproduction authority,
recoverable administration and routine repair documentation before closure.
Registration/H numbering/docs do not block independently authorized implementation
unless needed for real authority, enforced policy or conflicting writers.
H IDs track outcomes, not permanent component ownership. Inspect active process,
checkpoint and actual resource evidence before writer release; lease expiry alone
is insufficient. Recover before restart, bound repairs and continue independent
work. Use [dependency-aware queues](QUEUED_AUTONOMOUS_DELIVERY.md) for explicitly
autonomous multi-change work; no scheduler or live acceptance is implied.
Semantic/report/hash/FAST/security gates and enforced repository controls remain.

Required artifacts:
- `spec.md`
- `plan.md`
- `tasks.md`
- `answers.md`
- `report-mappings.md`
- `demo-data-plan.json` when demo data is enabled

Required gate before execution:
- The selected mode's discovery and confirmation contract is complete
- Architecture intent is directly confirmed or its consolidated Demo Builder recommendation is approved
- Entry-point table resolved against the explicit table plan, with an approved landing-view create-or-verify action
- Selected extension blocks completed
- Source-control plan completed when the profile enables it
- User tasks include owners and done definitions when the profile enables them
- Relationship decisions are complete for every planned relationship
- Report scoping is approved. When reports are enabled, every critical or high-frequency table has a mapping with type, placement, required fields, supported decision, owner, and validation checklist. When reports are disabled, that no-report decision is explicit.
- When demo data is enabled, table scope, per-table counts, scenarios/states, hero records, relationship distribution, bounded Task activity generation, and privacy constraints are approved. Acceptance-only rerun, retention, source-tag, and cleanup engineering is required only in Framework Acceptance mode.
- Spec Kit artifacts approved
- No conflict between generated guidance and these docs (resolve toward internal docs or report conflict):
  - `README.md`
  - `docs/onboarding.md`
  - `docs/build-log.md`
  - `requirements/how-to-build-dynamics-model-driven-apps-wizard.md`
  - `requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md`
  - `requirements/GithubInstructions_General.md`

Apply the proportional [scenario change impact planning contract](scenario-change-impact-gate.md) to new, expanded or inherited scenarios. Minor maintenance retains accepted planning and uses focused checks without regenerating the full matrix. Scenario deltas update only affected requirement/schema/binding/permission/fixture contracts and dependent surfaces; new or cross-cutting scenarios review the applicable end-to-end chain. Align affected planning files and link unchanged contracts. Native field/security proof before live binding and all mandatory release gates remain required; no new executable stage or tenant access is implied.

## Execution Contract

### Core Modules (always)

1. `00-prereq-check.ps1`
2. `10-auth-connect.ps1`
3. `15-dry-validate.ps1`
4. `20-build-tables.ps1`
5. `30-build-columns.ps1`
6. `40-build-relationships.ps1`
7. `50-add-to-solution.ps1`
8. `55-build-business-process-flows.ps1`
9. `60-build-forms-views.ps1`
10. Optional `64-build-charts-dashboard.ps1` from `reporting-*.json`
11. `62-build-app-module.ps1`, including declared chart/dashboard components
12. Optional profile-driven web resources
13. Optional `66-seed-synthetic-data.ps1` from `data-*.json`
14. Optional preview-first `68-build-security-roles.ps1` from `security-roles-*.json`
15. First `50-add-to-solution.ps1 -InventoryOnly -EnforceExportGate`
16. `85-verify-idempotency.ps1 -Phase CaptureBaseline`
17. Controlled second pass of forms/views, reporting, app/sitemap, synthetic data, and security roles
18. Final membership gate and `85-verify-idempotency.ps1 -Phase Verify`
19. `95-export-unmanaged-solution.ps1`
20. `80-post-build-analysis.ps1`

### Optional Modules (profile-driven)

- `65-build-web-resources.ps1`
- `64-build-charts-dashboard.ps1`
- `66-seed-synthetic-data.ps1`
- `68-build-security-roles.ps1`
- `06-demo-script-wizard.ps1`
- `07-demo-dry-run.ps1`
- future execution modules: AI summary and integration adapters

Synthetic data is created only from a validated `data-*.json` payload. The stage requires a source tag and stable natural keys, resolves entity-set names from metadata, fails on duplicate or foreign same-key records, resolves lookups exactly once, and updates the same IDs on rerun.

Bounded demo security roles are created only from a validated `security-roles-*.json` payload. `68-build-security-roles.ps1` defaults to preview, requires explicit `-Mode Apply`, replaces only the exact payload-defined privilege set of scenario-owned roles, verifies component-type 20 solution membership, and never creates identities, assigns roles, creates field-security profiles, or provisions SharePoint. Verification separately permits only Dataverse's four Global, platform-managed SharePoint integration privileges (`Create/Read/Write SharePointData` and `Read SharePointDocument`) that are automatically attached to new roles; these do not provision SharePoint or replace SharePoint document permissions.

Native charts and dashboards are distinct from HTML web resources. `64-build-charts-dashboard.ps1` creates or updates only wizard-owned `savedqueryvisualization` and dashboard `systemform` identities declared in `reporting-*.json`, adds those exact components to the selected solution, and publishes only their scenario tables.

Framework Acceptance export is unmanaged export plus local unpack/inspection only. `95-export-unmanaged-solution.ps1` requires a passing final membership report and never packs or imports the exported solution.

## Reliability Rules

All execution scripts must:
- Fail fast when expected payload folders/files are missing
- Verify existence checks using returned data, not only HTTP status
- Preserve metadata casing where schema names are case-sensitive
- Avoid deriving primary id fields from display/name fields
- Remain idempotent and print created/skipped/failed counts
- Refresh token on 401 (do not fail silently)
- Apply exponential backoff on 429 (rate limit)
- Use payload files (`payloads/`) as the source of truth for schema, labels, and field ordering
- Use business display labels on all form fields (not schema names)
- End all metadata/app update operations with a publish call

## Solution Inventory Contract

Every build run must:
1. Collect inventory for all created or updated artifacts (tables, columns, relationships, forms, views, model-driven apps, sitemap updates, web resources, optional dashboards/charts/flows)
2. Persist both logical names and IDs
3. Sync all inventory categories into the selected solution
4. Re-check solution membership after sync
5. Produce final membership report: Added / Already in solution / Failed with reason / Missing after sync
6. Block export unless membership check passes (user may override explicitly)

## Review App Contract

Every run must create or update a model-driven review app that:
1. Includes all app-addressable run artifacts
2. Sets entry-point table and landing view explicitly
3. Aligns app navigation sitemap to selected workflow
4. Is published after creation/update
5. Is validated: user can open app, reach expected entities/forms/views, entry-point opens as intended

For profile-based runs, app assembly must create or update an app-aware sitemap with the entry table first, resolve and attach the requested named landing view, attach the sitemap to the app, and publish. Landing-view validation is app-scoped; the wizard must not change a reused table's environment-wide default view.

## Form Strategy Contract

- OOB tables + no modification: create new forms on OOB tables; do not touch existing forms
- OOB tables + update in place: update selected OOB forms only
- Post-update: enforce section labels and business labels; remove legacy sections from prior runs; validate form XML/metadata

## Validation Contract

Post-build checks (both component inventory and functional metadata):
1. Fields exist on target tables
2. Intended forms exist with correct labels
3. App navigation contains intended entry points
4. Target solution contains required components

Run summary must include created/updated/skipped/failed counts by category.
`docs/build-log.md` must be updated for app/sitemap/inventory/sync status.

## Folder Contract

- Payload folder: `payloads/` at repository root (source of truth for schema, labels, field ordering)
- Scenario artifacts: `specs/<scenario-slug>/`
- Bootstrap scripts: `scripts/bootstrap/`

## Source of Truth Order

1. This contract document
2. `wizard.profile.json` (project profile)
3. `docs/onboarding.md` (authoritative step order)

Any mismatch must be resolved by updating the lower-priority document(s).
