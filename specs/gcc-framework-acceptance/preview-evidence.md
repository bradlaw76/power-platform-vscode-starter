# Credential-Free Preview Evidence

## Scope And Result

- Date: 2026-08-26
- Scenario: `gcc-framework-acceptance`
- Mode: Preview
- Result: `preview-complete`
- Solution contract: `LabEquipmentCheckoutAcceptance20260826`
- Publisher contract: permanent `PowerPlatformVSCodeStarter` with prefix `ppvs`
- Publisher prefix: `ppvs`
- Connection input: non-routable sentinel values; no GCC URL or credential was used
- Dataverse authentication, discovery, queries, and mutations: not attempted
- Apply, publish, export, seed, delete, reset, cleanup, commit, and push: not run

## Apply-Order Stage Evidence

| Order | Stage | Script | Preview result |
| ---: | --- | --- | --- |
| 0 | Permanent publisher prerequisite | Supported maker/PAC path after authorization | Planned; create `PowerPlatformVSCodeStarter` with prefix `ppvs`; mutation suppressed |
| 1 | Unmanaged solution prerequisite | Supported maker/PAC path after authorization | Planned; create under permanent publisher; mutation suppressed |
| 2 | Validate | `15-dry-validate.ps1` | Completed: 16 passes, 0 warnings, 0 errors |
| 3 | Tables | `20-build-tables.ps1` | Planned; mutation suppressed |
| 4 | Columns | `30-build-columns.ps1` | Planned; mutation suppressed |
| 5 | Relationships | `40-build-relationships.ps1` | Planned; mutation suppressed |
| 6 | Initial solution sync | `50-add-to-solution.ps1` | Planned; mutation suppressed |
| 7 | Business process flow | `55-build-business-process-flows.ps1` | Planned as designer handoff validation; mutation suppressed |
| 8 | Forms and views | `60-build-forms-views.ps1` | Planned; mutation suppressed |
| 9 | App module | `62-build-app-module.ps1` | Completed as local contract preview; live reads: none |
| 10 | HTML web resources | `65-build-web-resources.ps1` | Skipped because HTML reports are disabled |
| 11 | Final membership gate | `50-add-to-solution.ps1` | Planned in inventory-only/export-gate mode; live check suppressed |
| 12 | Post-build analysis | `80-post-build-analysis.ps1` | Completed locally |

## Proposed Inventory Confirmation

The solution inventory has 27 required component rows plus one validated BPF designer-handoff artifact that is not a solution component. The exact plan also includes one permanent publisher, one unmanaged solution, and eight synthetic rows. Publisher, solution, and schema creation are now completed historical work with reconstructed provenance.

- Tables: `ppvs_labasset`, `ppvs_checkoutrequest`
- Lab Asset columns: `ppvs_name`, `ppvs_assettag`, `ppvs_category`, `ppvs_availabilitystatus`, `ppvs_acceptancesourcetag`
- Checkout Request columns: `ppvs_name`, `ppvs_requestnumber`, `ppvs_requestername`, `ppvs_requestedon`, `ppvs_expectedreturndate`, `ppvs_actualreturndate`, `ppvs_lifecyclestage`, `ppvs_approvaldecision`, `ppvs_acceptancesourcetag`
- Lookup: `ppvs_checkoutrequest.ppvs_labassetid`
- Relationship: `ppvs_labasset_ppvs_checkoutrequest`
- Forms: Lab Asset Main (`ppvs_labasset|main`), Checkout Request Main (`ppvs_checkoutrequest|main`)
- Views: Available Lab Assets (`ppvs_labasset|active`, `create-custom`), Active Checkout Requests (`ppvs_checkoutrequest|active`, `adopt-generated-active`)
- Preview reports the declared dispositions without mutation; live generated-view provenance must still be proven at the apply gate.
- BPF handoff artifact: `ppvs_lab_equipment_checkout_lifecycle` (validated design only; not a required BPF component)
- Charts: Requests by Lifecycle Stage; Assets by Availability
- Dashboard: Lab Equipment Lifecycle and Availability
- App: `ppvs_lab_equipment_checkout_acceptance_20260826`
- Sitemap: `ppvs_lab_equipment_checkout_acceptance_20260826_sitemap`

Local app/navigation validation confirmed one entry point, the named landing view, two ordered tables, two forms, two views, one navigation group, and the deterministic sitemap identity. The BPF reference is a validated handoff only. Chart and dashboard display names resolve uniquely in the planning contract; they remain supported maker-authored components without locally generated metadata IDs.

## Identity And Data Evidence

- Custom identity audit: 23 references checked; all use `ppvs`
- Synthetic records: 8 total; all use `ppvs-acceptance-20260826`
- Hero records: exactly one `LECA-20260826-001 — Full Review-to-Return Journey`
- BPF stages: Review, Approve, Issue, Return
- BPF boundary: Power Apps designer handoff only; no `clientdata`, `uidata`, or `xaml` definition was generated or patched

## Non-Mutation Proof

The snapshot was captured immediately before and after the orchestrated preview.

- Git HEAD unchanged: true (`3b13f000acf4acd77d14b06292c1a4a43c72fbf3`)
- Branch unchanged: true
- Git refs unchanged: true (`f740c838674bd3c1da396bb44b3deab96c9e59e4c5de02995e8ea3c7a5ee2276`)
- Index tree unchanged: true (`f15097a81a2b5a5751977a01d03e96942e0766d6`)
- Staged file set unchanged: true
- Git status unchanged: true
- Aggregate SHA-256 of all tracked-file paths and contents unchanged: true (`d4c602b8a4d9a6474a2266956bfb7180e760a4412f65591799cd3a3e74ce0b51`)
- Process environment and token values restored: true

The preview wrote only ignored local evidence under `.wizard-metrics/`. This document and the completed gate updates were written after the snapshot comparison and are evidence-recording changes, not preview side effects.

## Historical Live-Read Separation

After an earlier credential-free preview, authentication and GET-only Dataverse activity occurred outside that preview authorization boundary. That activity caused no mutation and has stopped. It previously observed:

- Publisher with prefix `ppvs`: absent
- Solution `LabEquipmentCheckoutAcceptance20260826`: absent
- All component identities planned at that historical point: absent

Those historical observations are not evidence produced by this fresh credential-free preview and were not rechecked. No current live query is authorized.

## Credential-Free Preview Stop Point

At the end of the original preview, publisher creation, solution creation, all component/data mutations, authentication, live query, export, commit, push, and cleanup were blocked. This historical stop was superseded by the separately authorized schema gate and GET-only provenance reconstruction below. The permanent publisher remains excluded from cleanup categorically.

## Read-Only Provenance Reconstruction: 2026-08-28

- The scenario-scoped manifest correction passed local tests and GitHub Actions before reconstruction.
- GET-only checks verified the approved URL binding, active-token tenant binding, exact unmanaged solution, permanent publisher, two custom table descriptions, table and column creation timestamps, all 15 planned columns, and exact relationship shape.
- The live timestamps correlate to the recorded successful schema gate at 2026-08-28 02:01-02:10 UTC.
- The GCC manifest was reconstructed with 2 table, 15 column, and 1 relationship `created` entries, each marked as reconstructed evidence. The legacy Contoso manifest remained separate.
- Step 60 then passed in `PreviewOnly` mode with `MinBusinessColumnsPerView 3`: two forms were planned, `Active Checkout Requests` reported `adoption-planned`, and `Available Lab Assets` reported custom creation. No form, view, publish, or provenance mutation occurred.
- GCC access stopped after this gate. The remaining completion build requires the single consolidated authorization in `revised-apply-plan.md`.
