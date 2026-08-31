# Revised Apply Plan

## Completion Goal

Prove that a coworker can use the default Demo Builder experience to produce a functioning, repeatable, exportable model-driven Lab Equipment Checkout demo safely.

## Current Gate

The scenario-scoped manifest correction and read-only GCC provenance reconstruction passed on 2026-08-28.

- Exact environment URL binding, active-token tenant binding, unmanaged solution identity, publisher identity, table descriptions, creation timestamps, columns, and relationship shape were verified with Dataverse GET requests only.
- The scenario manifest contains 2 table, 15 column, and 1 relationship creation records. The legacy Contoso manifest remains separate.
- Step 60 completed in `PreviewOnly` mode with two forms planned, generated `Active Checkout Requests` adoption proven, custom `Available Lab Assets` creation planned, and no under-population failures at the scenario's three-column view threshold.
- No Dataverse mutation or publishing occurred during reconstruction or preview.

The remaining live build is not authorized until the consolidated authorization below is approved.

The repository implementation is complete and credential-free tests cover native reporting, synthetic-data reruns, app/sitemap reruns, stable-ID verification, and unmanaged export/unpack inspection. This does not authorize GCC access.

## Consolidated Remaining Build

1. Revalidate the exact environment, unmanaged solution, publisher, scoped manifest, and current target-solution inventory.
2. Create or update only `ppvs_labasset / Lab Asset Main / type=2`, `ppvs_checkoutrequest / Checkout Request Main / type=2`, `ppvs_labasset / Available Lab Assets / create-custom`, and `ppvs_checkoutrequest / Active Checkout Requests / adopt-generated-active`. Run step 60 with `MinBusinessColumnsPerView 3`; preserve generated Information forms and all unrelated views.
3. Generate and validate the supported Power Apps designer handoff for `Lab Equipment Checkout Lifecycle`. Do not create, patch, activate, or link unsupported BPF workflow-definition metadata.
4. Run `64-build-charts-dashboard.ps1` to create only `ppvs_checkoutrequest / Requests by Lifecycle Stage`, `ppvs_labasset / Assets by Availability`, and `Lab Equipment Lifecycle and Availability / systemform type=0` from the validated reporting payload.
5. Create or update only app `ppvs_lab_equipment_checkout_acceptance_20260826` and sitemap `ppvs_lab_equipment_checkout_acceptance_20260826_sitemap`, with Checkout Request first and `Active Checkout Requests` as the landing view.
6. Sync all required scenario components into `LabEquipmentCheckoutAcceptance20260826` and publish only the two scenario tables and exact app module through scoped `PublishXml` requests.
7. Run `66-seed-synthetic-data.ps1` to upsert exactly the three asset keys `LECA-ASSET-001` through `LECA-ASSET-003` and five request keys `LECA-20260826-001` through `LECA-20260826-005`; every row must carry source tag `ppvs-acceptance-20260826`.
8. Functionally verify navigation, forms, views, required lookup, restrict-delete behavior, lifecycle and availability data, charts, dashboard drill-through, and the hero journey.
9. Let `90-run-build.ps1` capture the first-pass baseline, run its controlled second pass, and invoke `85-verify-idempotency.ps1` to prove exactly one of every listed component and record natural key, zero new components or rows, and stable IDs.
10. Enforce final solution membership and run `95-export-unmanaged-solution.ps1` to export only an unmanaged solution, unpack and inspect it locally, and never import it.

## Separately Excluded

- Environment reset or deletion
- Component or synthetic-record cleanup
- Changes to unrelated PAC profiles
- Unsupported BPF fabrication
- Git staging, commits, pushes, branch changes, or other source-control mutation during live execution
- Import into another environment

## Stops

- Stop on environment, tenant, solution, publisher, or scenario-manifest mismatch.
- Stop on foreign-component contamination or any same-name form, view, chart, dashboard, app, or sitemap whose identity, scenario ownership, target-solution membership, or metadata differs from this contract.
- Stop if any stage requests `PublishAllXml`; only component-scoped `PublishXml` is authorized.
- Stop before export unless every required component is confirmed in the unmanaged solution.
- Stop if the supported BPF designer handoff cannot be generated and validated; do not synthesize workflow internals.

## Estimate And Critical Path

Estimated remaining execution time: 75-110 minutes, assuming normal Dataverse propagation and maker-tool availability.

Critical path: identity/inventory recheck -> forms/views -> charts/dashboard -> app/sitemap -> solution sync and publish -> synthetic data -> functional verification -> second run -> membership gate -> unmanaged export/unpack/package inspection.
