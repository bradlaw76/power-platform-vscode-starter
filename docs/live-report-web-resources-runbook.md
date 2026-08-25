# Live Report Web Resources Runbook

Use this runbook when generating scenario-specific HTML report web resources that read live Dataverse data.

## Live report mode

Run:

```powershell
pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <scenario-slug> -ReportMode live
```

Behavior:
- Validates scenario-derived entities and fields against Dataverse.
- Generates HTML web resources plus local config, query preview, and validation artifacts.
- Fails the step if required report entities or fields are missing.

## Zero-data mode

Run:

```powershell
pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <scenario-slug> -ReportMode live-with-design-fallback
```

Behavior:
- Queries live Dataverse data at runtime when the report opens.
- If no operational records exist yet, renders zero-state KPI cards and keeps the layout intact.
- Does not fabricate business KPIs when the environment is empty.

## Design-summary fallback mode

Run:

```powershell
pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <scenario-slug> -ReportMode static -EnableLiveDataverseReports:$false
```

Behavior:
- Generates the same scenario-specific report shell.
- Skips live Dataverse runtime queries.
- Shows only clearly labeled design metadata.

## Query preview mode

Run:

```powershell
pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <scenario-slug> -PreviewReportQueriesOnly
```

Behavior:
- Writes HTML and JSON artifacts locally.
- Skips Dataverse upload.
- Emits intended query definitions to `specs/<scenario-slug>/report-artifacts/query-preview.json`.

## Troubleshooting missing entity or field validation

If generation fails:
- Open `specs/<scenario-slug>/report-artifacts/report-validation.json`.
- Review `MissingEntities` and `MissingFields` for the failing report.
- Confirm the scenario mapping in `specs/<scenario-slug>/spec.md` matches the intended Dataverse logical names.
- Confirm the environment actually contains those entities and fields.
- If you only want to inspect generated queries before resolving metadata gaps, rerun with `-PreviewReportQueriesOnly`.
