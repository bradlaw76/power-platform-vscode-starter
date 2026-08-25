# Solution Isolation Runbook

Use this runbook when building into a Dataverse solution with the wizard bootstrap scripts. Use a scenario-specific unmanaged solution in a non-production environment.

## Normal clean build path

1. Run `pwsh ./scripts/bootstrap/10-auth-connect.ps1`.
2. Leave the solution choice on the default `new` unless you intentionally need an existing solution.
3. If you choose `new` and the unique name already exists, stop and enter a different solution name.
4. Complete and approve scenario planning.
5. Run `pwsh ./scripts/bootstrap/90-run-build.ps1 -ScenarioSlug <scenario-slug> -Mode Preview`.
6. Run the authenticated build with `pwsh ./scripts/bootstrap/90-run-build.ps1 -ScenarioSlug <scenario-slug> -Mode Apply -StrictSolutionIsolation`.
7. The orchestrator runs the first `50-add-to-solution.ps1` pass for payload tables, then runs it again with `-InventoryOnly -EnforceExportGate` after forms, views, app, sitemap, BPF, and report stages.

Inventory-only mode performs Dataverse reads and writes local reports. It does not call `AddSolutionComponent`, publish, create, update, or delete Dataverse metadata.

## Inventory contract

The final report always includes mandatory categories for tables, columns, relationships, forms, views, model-driven apps, sitemap updates, and web resources. Optional categories are dashboards, charts, and flows. Business Process Flows (BPFs) are reported under flows.

Each discovered item preserves its logical or unique name, Dataverse object ID, solution component ID, and numeric component type. Results use these states:

- `Added`: added during the current inventory-producing operation when that state is available.
- `Already in solution`: expected and present.
- `Failed`: the artifact manifest records a build failure.
- `Missing`: expected but absent from solution membership.
- `Unauthorized`: present but absent from the approved expected-artifact set.

Reports are written to:

- `.wizard-metrics/artifacts/solution/solution-membership-report.json`
- `.wizard-metrics/artifacts/solution/solution-membership-report.md`

Missing or failed mandatory artifacts always block export. Strict mode also blocks export when unauthorized components remain. Empty optional categories are recorded and do not fail the gate.

## Contaminated solution detection path

1. Run `pwsh ./scripts/bootstrap/50-add-to-solution.ps1`.
2. If the target solution already contains tables outside the payload-derived expected set, the script fails before adding components.
3. Review the listed foreign tables in the terminal output.
4. Only bypass this guard when reuse is intentional:
   `pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -FailIfSolutionHasForeignTables:$false`

An override permits the add pass; it does not falsify or bypass the final membership report. Resolve final blocking findings before export.

## Cleanup path

1. Review what would be removed:
   `pwsh ./scripts/bootstrap/57-prune-foreign-tables.ps1 -SolutionUniqueName "<solution-name>"`
2. Confirm the dry run output lists only unrelated tables.
3. Apply the cleanup:
   `pwsh ./scripts/bootstrap/57-prune-foreign-tables.ps1 -SolutionUniqueName "<solution-name>" -Mode Apply`
4. When prompted, type `REMOVE` to confirm.
5. Re-run `pwsh ./scripts/bootstrap/50-add-to-solution.ps1` after cleanup.

## Final membership and export

Run a standalone read-only membership refresh when needed:

```powershell
pwsh ./scripts/bootstrap/50-add-to-solution.ps1 `
   -ScenarioSlug <scenario-slug> `
   -PayloadsFolder ./payloads/scenarios/<scenario-slug> `
   -InventoryOnly `
   -EnforceExportGate
```

Review every blocking item in the Markdown report. Re-run the owning build stage, then rerun the same inventory command. Do not export until `Export allowed: True`.

For a planned BPF, first use the generated designer handoff under `specs/<scenario-slug>/reports/`. Author and publish the category-4 process in Power Apps with the expected unique name. The BPF stage validates, activates, adds, and links that existing process; it does not fabricate a workflow definition through unsupported Web API metadata.

## Rerun expectations

A second build must update or validate deterministic artifacts rather than create duplicates. Compare membership report object IDs between runs. The same expected name must retain one intended object ID and solution component membership. Stop if a rerun adds duplicate forms, views, apps, sitemaps, BPFs, or wizard-managed tables.

The manually triggered Dataverse integration workflow is the authoritative live rerun check, but it must target an explicitly approved disposable development environment. Credential-free mocked tests cover classification and export-gate behavior only.
