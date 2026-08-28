# Revised Apply Plan

## Current Gate

No apply step is authorized. Stop for explicit mutation authorization.

## Ordered Plan

1. Capture a pre-apply inventory and confirm the permanent-environment safety boundary.
2. Verify-or-create publisher unique name `PowerPlatformVSCodeStarter`, display name Power Platform VS Code Starter, prefix `ppvs`.
3. Mark the publisher permanent and exclude it from all cleanup instructions and tooling inputs.
4. Verify-or-create unmanaged solution `LabEquipmentCheckoutAcceptance20260826` under that exact publisher.
5. Re-run strict local validation against the approved payloads.
6. Run tables, columns, relationships, initial solution sync, forms/views, app module, and final membership checks in repository order.
7. Pause for the Power Apps designer handoff to author the initial BPF definition; do not generate workflow definition internals.
8. After the designer artifact exists and separate approval remains valid, validate, activate, add, publish, and link the BPF through supported paths.
9. Create the two charts and dashboard through supported maker/solution tooling.
10. Upsert exactly 3 Lab Asset and 5 Checkout Request records using `ppvs-acceptance-20260826`.
11. Verify all 28 proposed component rows are members of the target solution.
12. Validate app navigation, named landing view, forms, charts, dashboard drill-through, hero journey, and deterministic rerun.
13. Retain all acceptance artifacts. Do not run cleanup, export, commit, or push without their separate approvals.

## Idempotency And Stops

- Publisher and solution stages are verify-or-create by exact unique name and prefix; conflicts stop the run.
- Each metadata phase stops on identity mismatch, foreign-component contamination, or failed membership.
- Publisher creation and solution creation are separate mutations and require authorization before either begins.
- Export remains blocked until the final membership report passes.
- Cleanup remains unauthorized, and the permanent publisher is categorically excluded.
