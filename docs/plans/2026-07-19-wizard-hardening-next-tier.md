# 2026-07-19 Wizard Hardening Next Tier

## Scope

- Build contract validator
- Full contamination scan
- Generated artifact manifest
- Form/view quality gates
- App module wiring

## Delivery Notes

- Shared logic lives in `scripts/bootstrap/helpers/wizard-hardening.ps1`.
- Preflight validation integrates into `15-dry-validate.ps1`.
- Contamination scan integrates into `50-add-to-solution.ps1`.
- Artifact manifest is updated by mutation steps so later cleanup and handoff do not need to infer results.
- App assembly now has a dedicated step after forms/views: `62-build-app-module.ps1`.

## Operator Sequence

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
11. Optional `70-build-web-resources.ps1`
12. `80-post-build-analysis.ps1`