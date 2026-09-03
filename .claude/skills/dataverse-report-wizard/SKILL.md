---
name: dataverse-report-wizard
description: Use when creating, previewing, simulating, or deploying native Dataverse reports for a Dynamics 365 or Power Apps model-driven app. Discovers apps, tables, and columns; generates FetchXML, charts, dashboards, and report mappings; and requires approval before deployment.
---

# Dataverse Report Wizard

## Purpose

Create native Dataverse charts and dashboards for an existing or planned
model-driven app. Use the checked-in reporting runtime for metadata discovery,
validation, FetchXML generation, solution registration, app attachment, and
publication.

This is a report-only workflow. Do not restart the full app-building wizard
when the user only wants reporting against an existing app.

## Runtime Compatibility Preflight

Skill availability is not runtime installation. A copied `SKILL.md` does not
provide the scripts, helpers, schemas, or tests it invokes.

Before intake, inspect the target repository without modifying it. Require:

- `scripts/bootstrap/08-report-wizard.ps1`
- `scripts/bootstrap/64-build-charts-dashboard.ps1`
- `scripts/bootstrap/10-auth-connect.ps1`
- `scripts/bootstrap/helpers/reporting-wizard.ps1`
- `scripts/bootstrap/helpers/dataverse-runtime.ps1`
- `schemas/payloads/reporting.schema.json`
- `scripts/ci/test-report-wizard.ps1`

Report present, missing, and incompatible files. If runtime files are missing,
stop and offer a reviewed bootstrap plan. Never overwrite existing
instructions, skills, scripts, specs, or payloads without explicit review and
approval. Use `docs/skill-distribution.md` for installation and provenance
checks.

## Safety Contract

- Default to `simulate` when the user has not chosen a mode.
- Simulation and preview must not contact or mutate a live Dataverse
  environment.
- Never deploy to production during development or testing.
- For live work, confirm the environment URL before authentication. Select the
  target app after authentication so live metadata can guide the choice.
- Generate and review the payload, FetchXML preview, and report mapping before
  offering deployment.
- Never use `-Deploy` without explicit approval in the current conversation.
- Treat a deployment approval as valid only for the displayed environment,
  solution, app, scenario, charts, dashboard, and filters.
- Use `-Force` only after showing that the scenario payload already exists and
  obtaining approval to replace it.
- Never print, persist in generated artifacts, or commit access tokens.
- Do not stage, commit, push, export, import, or delete resources unless the
  user separately requests and approves that action.

## Planning Boundary

For report-only work against an existing app, the required planning artifact
is `specs/<scenario-slug>/report-mappings.md`. It must identify the target app,
audience, decision supported, tables, fields, placement, filters, owner, and
validation checklist. The generated FetchXML preview must also be approved
before deployment.

If the request adds or changes tables, columns, relationships, forms, views,
business process flows, navigation, or the app shell, route that portion to
`/power-platform-vscode-wizard`. The full `spec.md`, `plan.md`, and `tasks.md`
gate applies before those app or schema changes.

## Modes

### Simulate

Run:

```powershell
pwsh ./scripts/ci/test-report-wizard.ps1
```

The test uses sanitized fixture metadata, simulates Dataverse transport,
validates deployment and app attachment, and cleans up temporary artifacts.
Summarize the simulated app, table, chart, filter, dashboard, and validation
result.

### Live preview

1. Run `pwsh ./scripts/bootstrap/00-prereq-check.ps1`.
2. Run the report wizard. It asks for the environment URL, authenticates
   immediately, and then uses live metadata for report design:

```powershell
pwsh ./scripts/bootstrap/08-report-wizard.ps1 -ScenarioSlug <scenario-slug>
```

3. Review and summarize the reporting payload, FetchXML preview, and
   `report-mappings.md`.
4. Stop for explicit deployment approval.

### Live deploy

After preview approval, display the exact environment, solution, target app,
dashboard, charts, tables, calculations, and filters. Then run:

```powershell
pwsh ./scripts/bootstrap/08-report-wizard.ps1 `
  -ScenarioSlug <scenario-slug> `
  -Force `
  -Deploy
```

The runtime creates or updates scenario-owned native charts and the dashboard,
adds them to the selected solution, attaches them to the selected model-driven
app, and publishes that app.

## Intake

Ask one question at a time unless the user requests a batch. Reuse answers
already present in the conversation.

Collect simulation or live mode and scenario slug first. In live mode, ask for
the Dataverse environment URL and authenticate immediately so metadata guides
the remaining questions. Then ask what the user wants to see in natural
language, infer and display a proposed app, table, category, measure,
calculation, chart, and filters, and ask only the questions needed to confirm
or correct that proposal. Finally capture the dashboard name, owner, and
validation checklist.

Use metadata display names in explanations and logical names in generated
configuration. Numeric calculations (`sum`, `avg`, `min`, `max`) require a
numeric Dataverse column.

## Noninteractive Configuration

For agent-driven or CI runs, create a temporary configuration outside tracked
repository paths and pass it with `-ConfigurationPath`. Remove it afterward.
Use `-MetadataSnapshotPath` only for sanitized offline metadata. Never commit a
customer metadata export as a test fixture without review.

The configuration contract includes:

- `TargetAppUniqueName`
- `ReportRequest`
- `OutputTargets`
- `DashboardName`
- one to three `Charts`
- chart `Name`, `TableLogicalName`, `CategoryField`, `AggregateField`,
  `Aggregate`, `ChartType`, and optional `Filters`

## Completion Contract

Report the mode, environment and solution or offline simulation, target app,
artifact paths, tables, calculations, filters, live-contact status, mutation
status, created or updated components, app attachments, validation results,
and anything not yet verified in a real environment.

Never describe a simulated deployment as a live deployment.
