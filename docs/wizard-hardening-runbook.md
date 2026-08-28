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

- Each apply run updates only `.wizard-metrics/artifacts/manifest/<normalized-scenario-slug>/generated-artifact-manifest.json`.
- Use the manifest to see which tables, columns, relationships, forms, views, BPFs, app components, and app modules were `created`, `updated`, `skipped`, or `failed`.
- The markdown companion file is in the same scenario-specific folder.
- Every manifest open validates the normalized scenario slug, solution unique name, and publisher prefix against the active stage. Any mismatch is a hard stop.
- Preview may write disposable reports and run summaries, but it must not create or alter manifest provenance.

### Explicit Legacy Migration

The former global manifest at `.wizard-metrics/artifacts/manifest/generated-artifact-manifest.json` is never read automatically. To migrate it, first inspect it without exposing credentials or identifiers, then explicitly invoke the validated migration helper:

```powershell
. ./scripts/bootstrap/helpers/wizard-hardening.ps1
Move-WizardLegacyArtifactManifest -RepoRoot $PWD -ScenarioSlug '<scenario-slug>' -SolutionName '<solution-unique-name>' -PublisherPrefix '<prefix>'
```

Migration copies the legacy manifest only when all three identities match and no scenario-specific manifest exists. A mismatch or existing target stops migration.

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