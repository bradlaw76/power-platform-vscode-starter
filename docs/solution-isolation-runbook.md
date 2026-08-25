# Solution Isolation Runbook

Use this runbook when building into a Dataverse solution with the wizard bootstrap scripts.

## Normal clean build path

1. Run `pwsh ./scripts/bootstrap/10-auth-connect.ps1`.
2. Leave the solution choice on the default `new` unless you intentionally need an existing solution.
3. If you choose `new` and the unique name already exists, stop and enter a different solution name.
4. Run the standard build flow through `pwsh ./scripts/bootstrap/50-add-to-solution.ps1`.
5. If the solution contains only payload-derived tables, the add-to-solution step continues normally.

## Contaminated solution detection path

1. Run `pwsh ./scripts/bootstrap/50-add-to-solution.ps1`.
2. If the target solution already contains tables outside the payload-derived expected set, the script fails before adding components.
3. Review the listed foreign tables in the terminal output.
4. Only bypass this guard when reuse is intentional:
   `pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -FailIfSolutionHasForeignTables:$false`

## Cleanup path

1. Review what would be removed:
   `pwsh ./scripts/bootstrap/57-prune-foreign-tables.ps1 -SolutionUniqueName "<solution-name>"`
2. Confirm the dry run output lists only unrelated tables.
3. Apply the cleanup:
   `pwsh ./scripts/bootstrap/57-prune-foreign-tables.ps1 -SolutionUniqueName "<solution-name>" -Mode Apply`
4. When prompted, type `REMOVE` to confirm.
5. Re-run `pwsh ./scripts/bootstrap/50-add-to-solution.ps1` after cleanup.
