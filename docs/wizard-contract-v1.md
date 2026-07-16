# Wizard Contract v1

Status: Active
Version: 1.0.0

## Purpose

Define one canonical workflow contract across discovery, planning, and execution.
All wizard entry points must follow this contract:
- Terminal wizard script
- Chat prompt wizard
- Onboarding documentation
- Requirements guidance

## Canonical Flow

1. Discovery (required questions)
2. Optional extension blocks (selected by profile)
3. Spec Kit planning gate (`spec.md`, `plan.md`, `tasks.md`)
4. Optional demo script generation
5. Core bootstrap execution modules
6. Optional execution modules
7. Validation and handoff

## Discovery Contract

### Required Question Set (11)

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

### Extension Blocks (optional)

- `table-strategy`: standard vs custom table strategy and explicit mapping
- `solution-identity`: new/existing solution and publisher prefix
- `reporting`: web resource report generation scope
- `retrofit`: current-state and remaining-work intake for in-progress projects

## Planning Contract

Required artifacts:
- `spec.md`
- `plan.md`
- `tasks.md`
- `answers.md`

Required gate before execution:
- All required discovery questions answered
- Selected extension blocks completed
- Spec Kit artifacts approved

## Execution Contract

### Core Modules (always)

1. `00-prereq-check.ps1`
2. `10-auth-connect.ps1`
3. `20-build-tables.ps1`
4. `30-build-columns.ps1`
5. `40-build-relationships.ps1`
6. `50-add-to-solution.ps1`
7. `60-build-forms-views.ps1`

### Optional Modules (profile-driven)

- `65-build-web-resources.ps1`
- `06-demo-script-wizard.ps1`
- `07-demo-dry-run.ps1`
- future: data seeding, AI summary, integration adapters

## Reliability Rules

All execution scripts must:
- Fail fast when expected payload folders/files are missing
- Verify existence checks using returned data, not only HTTP status
- Preserve metadata casing where schema names are case-sensitive
- Avoid deriving primary id fields from display/name fields
- Remain idempotent and print created/skipped/failed counts

## Folder Contract

- Payload folder: `payloads/` at repository root
- Scenario artifacts: `specs/<scenario-slug>/`
- Bootstrap scripts: `scripts/bootstrap/`

## Source of Truth Order

1. This contract document
2. `wizard.profile.json` (project profile)
3. `docs/onboarding.md` (authoritative step order)

Any mismatch must be resolved by updating the lower-priority document(s).
