# Standalone Model-Driven App Support Plan

## Approach

1. Extend the existing markdown planning contract instead of creating a second wizard.
2. Parse profile and architecture intent through `wizard-hardening.ps1` so all build steps share one source.
3. Generate forms and views from declared table and column payload targets, not only custom table-creation payloads.
4. Apply form strategy explicitly and preserve non-wizard forms by default.
5. Resolve the app entry table and landing view during app assembly and validate the selected view.
6. Keep report generation profile-neutral for standalone apps.
7. Update operator documentation and CI acceptance coverage.

## Compatibility

- Scenario files without the new profile section use legacy defaults.
- Existing custom-only payload behavior remains unchanged.
- No installed Dynamics table is assumed to exist merely because it appears in a static catalog.

## Validation

- `pwsh ./scripts/ci/test-wizard-hardening.ps1`
- `pwsh ./scripts/ci/test-form-population.ps1`
- `pwsh ./scripts/ci/test-script-smoke.ps1`
- `pwsh ./scripts/ci/test-docs-consistency.ps1`
- Broader CI after focused checks pass.

## Sitemap Boundary

App assembly will validate and attach the requested entry table and landing view. Direct sitemap authoring will only use a repository-verified supported API or SDK contract; otherwise the build must report sitemap configuration as an explicit remaining action rather than claiming it was applied.
