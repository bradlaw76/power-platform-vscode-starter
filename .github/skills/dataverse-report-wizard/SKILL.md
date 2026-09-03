---
name: dataverse-report-wizard
description: 'Use when creating, previewing, simulating, or deploying native Dataverse reports for a Dynamics 365 or Power Apps model-driven app. Discovers apps, tables, and columns; generates FetchXML, charts, dashboards, and report mappings; and requires approval before deployment.'
argument-hint: 'Optional: scenario=<slug> mode=simulate|live action=preview|deploy'
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
approval. Use [skill-distribution.md](../../../docs/skill-distribution.md) for
installation and provenance checks.

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
is `specs/<scenario-slug>/report-mappings.md`. It must identify:

- target model-driven app;
- report audience and decision supported;
- selected tables and fields;
- chart and dashboard placement;
- filters;
- owner; and
- validation checklist.

The generated FetchXML preview must also be approved before deployment.

If the request adds or changes tables, columns, relationships, forms, views,
business process flows, navigation, or the app shell, route that portion to
`/power-platform-wizard-init`. The full `spec.md`, `plan.md`, and `tasks.md`
gate applies before those app or schema changes.

## Modes

### Simulate

Use for demonstrations, tests, and first runs. Run:

```powershell
pwsh ./scripts/ci/test-report-wizard.ps1
```

The test uses sanitized fixture metadata, simulates Dataverse transport,
validates deployment and app attachment, and cleans up temporary artifacts.
Summarize the simulated app, table, chart, filter, dashboard, and validation
result.

### Live preview

Use when the user wants to design a report against a real authorized
nonproduction environment without deploying it.

1. Run `pwsh ./scripts/bootstrap/00-prereq-check.ps1`.
2. Run the report wizard. It asks for the environment URL, authenticates
   immediately, and then uses live metadata for report design:

```powershell
pwsh ./scripts/bootstrap/08-report-wizard.ps1 -ScenarioSlug <scenario-slug>
```

3. Read and summarize:
   - `payloads/scenarios/<scenario-slug>/reporting-<scenario-slug>.json`
   - `specs/<scenario-slug>/report-artifacts/query-preview.json`
   - `specs/<scenario-slug>/report-mappings.md`
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

Ask only one question at a time unless the user requests a batch. Reuse answers
already present in the conversation.

Collect:

1. Simulation or live mode.
2. Scenario slug.
3. Dataverse environment URL for live mode.
4. Authenticate immediately so live metadata can guide later questions.
5. Ask, "What do you want to see in the report?" Capture the audience,
   business decision, measures, groupings, and filters in natural language.
6. Infer and display a proposed target app, table, category, measure,
   calculation, chart, and filters. Ask the user to confirm or correct it.
7. Target model-driven app.
8. Report audience and business decision.
9. One to three reporting tables.
10. Category/grouping column for each chart.
11. Calculation: `count`, `countcolumn`, `sum`, `avg`, `min`, or `max`.
12. Measure column.
13. Chart type: `column`, `bar`, `pie`, or `doughnut`.
14. Optional filters.
15. Dashboard name.
16. Report owner and validation checklist.

Use metadata display names in explanations and logical names in generated
configuration. Numeric calculations (`sum`, `avg`, `min`, `max`) require a
numeric Dataverse column.

## Noninteractive Configuration

For agent-driven or CI runs, create a temporary configuration outside tracked
repository paths and pass it with `-ConfigurationPath`. Do not leave temporary
configuration files behind.

```json
{
  "ReportRequest": "Show open cases grouped by priority for service managers.",
  "TargetAppUniqueName": "contoso_customer_service",
  "OutputTargets": [
    "fetchxml-preview",
    "native-chart-dashboard"
  ],
  "DashboardName": "Case Operations",
  "Charts": [
    {
      "Name": "Open Cases by Priority",
      "TableLogicalName": "incident",
      "CategoryField": "prioritycode",
      "AggregateField": "incidentid",
      "Aggregate": "count",
      "ChartType": "column",
      "Filters": [
        {
          "Field": "statecode",
          "Operator": "eq",
          "Value": "0"
        }
      ]
    }
  ]
}
```

Use `-MetadataSnapshotPath` only for sanitized offline metadata. Never use a
customer metadata export as a committed test fixture without review.

## Completion Contract

Report:

- mode used;
- environment and solution, or `offline simulation`;
- target app;
- generated artifact paths;
- tables, calculations, and filters;
- whether Dataverse was contacted;
- whether any mutation occurred;
- components created, updated, or attached;
- validation commands and results; and
- any capability that remains unverified in a real environment.

Never describe a simulated deployment as a live deployment.
