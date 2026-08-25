# Wizard Contract v1

Status: Active
Version: 1.4.0

## Purpose

Define one canonical workflow contract across discovery, planning, and execution.
All wizard entry points must follow this contract:
- Terminal wizard script
- Chat prompt wizard
- Onboarding documentation
- Requirements guidance

## Canonical Flow

1. Architecture intent (required, before any other step)
2. Discovery (required questions)
3. Optional extension blocks (selected by profile)
4. Source-control plan for the app or demo being created
5. Spec Kit planning gate (`spec.md`, `plan.md`, `tasks.md`)
6. Optional demo script generation
7. Core bootstrap execution modules with approved commit checkpoints
8. Solution inventory and sync
9. Publish and usability validation
10. Optional execution modules
11. Validation, push verification, pull request preparation, and handoff

## Architecture Intent Contract (Always First)

First select one supported application profile:

- `standalone-model-driven`
- `dynamics-sales-extension`
- `dynamics-customer-service-extension`
- `dynamics-field-service-extension`
- `generic-dataverse-solution`

Before any build recommendation, confirm all five architecture intent questions:

1. Is the implementation **OOB extension only**, **custom tables only**, or **hybrid**?
2. If OOB extension: should forms be **updated in place** or **cloned as new business forms**?
3. What is the **required primary entry-point table** (first screen)?
4. What is the **default landing view** for that entry-point table?
5. Which artifacts must the required auto-created or updated **model-driven review app** surface?

Do not proceed to discovery or build until all five are confirmed.

After explicit table mapping, the entry-point logical name must resolve to a reused standard table, a planned custom table, or an existing retrofit inventory table. The landing view must have an explicit action: create or update the named view for a planned custom table, or verify the existing saved query for reused/existing tables. App assembly remains blocked until the named saved query resolves in Dataverse.

## Discovery Contract

### Required Question Set (11 core + 7 architecture intake)

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
- `demo-data`: conditional table scope, per-table counts, scenarios/states, hero records, relationship distribution, bounded Task activity generation, method, rerun behavior, source tag, privacy constraints, and cleanup decision

Relationship planning must identify the referencing and referenced tables, cardinality, requiredness, existing/new status, cascade behavior, and the user task or app surface supported by each relationship.

When demo data is enabled, default scope may be all scenario-created custom tables, but the resolved table list must be shown and approved. Standard reused tables must explicitly choose create, reuse-existing, or both; they are never seeded implicitly. Hero records must identify their table, count, and demo scenario or purpose.

Dataverse Task activity generation is opt-in. When enabled, planning must identify eligible parent tables, latest/all/selected scope, a source-record limit, the ordering field used to determine latest records, and tasks per selected record. The recommended default is the latest 10 parent records per table ordered by `createdon desc`; every-record task creation requires the user to explicitly select `all`.

## Source Control Contract

Apply `requirements/GithubInstructions_General.md` throughout each end user's app or demo lifecycle.

1. Before implementation, inspect the target repository, remote, current/default branch, working tree, recent history, build/package tooling, lockfiles, CI, tests, linting, formatting, and repository instructions.
2. Record a scenario branch, related issue/spec/work item, commit strategy, applicable discovered validation, pull request preference, and merge strategy in scenario planning artifacts.
3. Do not guess validation commands, stage unrelated files, or use the default branch as a scratch workspace.
4. At coherent planning, implementation, validation, and final source checkpoints: inspect status and diff, run applicable validation, stage explicit intended files, and use a typed imperative commit message.
5. Require explicit approval before commit and separate approval before push.
6. After push, verify that the remote branch contains the local commit before reporting remote success.
7. Distinguish modified locally, committed locally, pushed, pull request opened, merged, released, and deployed.

## Planning Contract

Required artifacts:
- `spec.md`
- `plan.md`
- `tasks.md`
- `answers.md`
- `report-mappings.md`
- `demo-data-plan.json` when demo data is enabled

Required gate before execution:
- All 18 discovery questions answered
- Architecture intent confirmed
- Entry-point table resolved against the explicit table plan, with an approved landing-view create-or-verify action
- Selected extension blocks completed
- Source-control plan completed when the profile enables it
- User tasks include owners and done definitions when the profile enables them
- Relationship decisions are complete for every planned relationship
- Report scoping is approved. When reports are enabled, every critical or high-frequency table has a mapping with type, placement, required fields, supported decision, owner, and validation checklist. When reports are disabled, that no-report decision is explicit.
- When demo data is enabled, table scope, per-table counts, scenarios/states, hero records, relationship distribution, bounded Task activity generation, rerun behavior, source tag, privacy constraints, and cleanup decision are approved
- Spec Kit artifacts approved
- No conflict between generated guidance and these docs (resolve toward internal docs or report conflict):
  - `README.md`
  - `docs/onboarding.md`
  - `docs/build-log.md`
  - `requirements/how-to-build-dynamics-model-driven-apps-wizard.md`
  - `requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md`
  - `requirements/GithubInstructions_General.md`

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
10. `62-build-app-module.ps1`
11. Solution inventory collection and sync (inline, post-62)
12. Publish (inline, after sync)
13. `80-post-build-analysis.ps1`

### Optional Modules (profile-driven)

- `65-build-web-resources.ps1`
- `06-demo-script-wizard.ps1`
- `07-demo-dry-run.ps1`
- future execution modules: data seeding, AI summary, integration adapters

The current demo-data extension is planning-only. It must not create Dataverse rows. A future seeding module requires a separate approved contract and must be idempotent, relationship-aware, hero-record-aware, source-tagged, synthetic-data-safe, enforce approved Task activity bounds, and report created/skipped/failed counts.

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
