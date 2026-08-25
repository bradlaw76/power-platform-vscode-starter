# Wizard Hardening Runbook

## Preflight Validation

- Run `pwsh ./scripts/bootstrap/15-dry-validate.ps1` before mutation steps.
- Review `.wizard-metrics/artifacts/validation/build-contract-validation.md` for the human summary.
- Review `.wizard-metrics/artifacts/validation/build-contract-validation.json` for machine-readable consumers.
- In strict mode, any contract error stops the run before table, column, relationship, or solution mutations begin.

## Contamination Scan Handling

- Run `pwsh ./scripts/bootstrap/50-add-to-solution.ps1` with contamination scanning enabled.
- Review `.wizard-metrics/artifacts/solution/contamination-scan.md` and `.json`.
- `clean` means the solution contains only expected scenario artifacts.
- `warning` means only wizard-looking artifacts from another scenario were detected.
- `contaminated` means manual or legacy foreign artifacts were detected.
- In strict mode, `contaminated` stops the run unless `-AllowContaminatedSolution:$true` is supplied intentionally.

## Manifest Usage

- Every run updates `.wizard-metrics/artifacts/manifest/generated-artifact-manifest.json`.
- Use the manifest to see which tables, columns, relationships, forms, views, BPFs, app components, and app modules were `created`, `updated`, `skipped`, or `failed`.
- The markdown companion file is `.wizard-metrics/artifacts/manifest/generated-artifact-manifest.md`.

## Form And View Quality Troubleshooting

- Review `.wizard-metrics/artifacts/forms/form-population-report.json`.
- Review `.wizard-metrics/artifacts/views/view-population-report.json`.
- Raise `MinBusinessFieldsPerForm` or `MinBusinessColumnsPerView` only when the scenario genuinely needs denser layouts.
- If under-population failures are expected temporarily, rerun with `-FailIfUnderpopulatedForms:$false` or `-FailIfUnderpopulatedViews:$false` while you complete payloads.
- When views are preserved as manual, the script will not overwrite them; rename or remove the manual view if you want the wizard-managed view regenerated.

## App Module Wiring And Verification

- Add an `## App Module` block to `answers.md` when the scenario should produce a model-driven app shell.
- Run `pwsh ./scripts/bootstrap/62-build-app-module.ps1 -ScenarioSlug <slug>` after forms/views.
- Review `.wizard-metrics/artifacts/app-module/app-module-summary.json`.
- Review `.wizard-metrics/artifacts/app-module/navigation-summary.json`.
- Review `.wizard-metrics/artifacts/app-module/app-module-validation.json`.
- Re-running is safe: the script updates the existing app by unique name and re-attaches intended components.