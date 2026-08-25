# View Population Runbook

This runbook covers the hardened behavior in `scripts/bootstrap/60-build-forms-views.ps1` for wizard-managed Dataverse views.

## Normal populated-view build

Run the standard step after tables, columns, relationships, and solution assembly are in place:

```powershell
pwsh ./scripts/bootstrap/60-build-forms-views.ps1
```

What the step now does for each custom table:

- Creates or updates the wizard-managed `Active Records` working view.
- Builds the column list from payload columns first, then scenario markdown under `specs/<scenario-slug>/`, then live Dataverse attributes as fallback.
- Places the primary name column first.
- Adds optional metadata tail columns like `statuscode` or `ownerid` only after business columns are selected.
- Emits per-table console output showing columns placed, skipped columns, missing expected columns, and pass/fail validation.

Artifacts written locally:

- `.wizard-metrics/artifacts/forms/form-population-report.json`
- `.wizard-metrics/artifacts/views/view-population-report.json`

## Under-populated failure handling

Default view quality gate:

- `MinBusinessColumnsPerView = 4`
- `FailIfUnderpopulatedViews = $true`

If a view ends up with fewer than the configured business columns, or only system/default columns, the step exits non-zero and reports the failing tables in both console output and `view-population-report.json`.

Recommended operator flow:

1. Open `.wizard-metrics/artifacts/views/view-population-report.json`.
2. Review `missingExpectedColumns` and `skippedColumns` for each failing table.
3. Add the missing business fields to payload column files or to the scenario planning artifacts under `specs/<scenario-slug>/`.
4. Re-run step `60-build-forms-views.ps1`.

## Rerun behavior

Wizard-managed views are identified by a description marker and updated in place with deterministic `layoutxml` and `fetchxml`.

- Re-runs do not create duplicate views.
- Re-runs do not create duplicate columns.
- Legacy wizard-created `Active Records` views that only contained the old default columns are upgraded in place.
- Non-wizard manual views with the same name are preserved and not destructively replaced.

If a preserved manual `Active Records` view is under-populated, the step reports that condition and fails when `FailIfUnderpopulatedViews` is enabled.

## Override parameters

Use these parameters when you need to adjust the default gate:

```powershell
pwsh ./scripts/bootstrap/60-build-forms-views.ps1 `
  -ScenarioSlug contoso-case-tracker `
  -MinBusinessColumnsPerView 5 `
  -FailIfUnderpopulatedViews $true `
  -IncludeOwnerInViews $true `
  -IncludeStatusInViews $true
```

Parameter guidance:

- `-ScenarioSlug`: use when multiple scenario folders exist under `specs/` and you want view prioritization tied to one scenario.
- `-MinBusinessColumnsPerView`: raise or lower the minimum business-column requirement.
- `-FailIfUnderpopulatedViews`: set to `$false` only when you need a preview run without blocking the pipeline.
- `-IncludeOwnerInViews`: append `ownerid` after business columns when ownership matters to operators.
- `-IncludeStatusInViews`: append `statuscode` after business columns when workflow state matters to operators.