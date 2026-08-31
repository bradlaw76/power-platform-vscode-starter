# Lab Equipment Checkout Framework Acceptance Tasks

## Planning And Review

- [x] Persist explicit Framework Acceptance mode selection.
- [x] Record the permanent authorized environment and no-reset/no-delete constraints.
- [x] Confirm solution `LabEquipmentCheckoutAcceptance20260826`.
- [x] Correct the live assumption: publisher prefix `ppvs` does not currently exist.
- [x] Plan permanent publisher `PowerPlatformVSCodeStarter` with prefix `ppvs`.
- [x] Exclude the permanent publisher from all cleanup.
- [x] Confirm source tag `ppvs-acceptance-20260826`.
- [x] Confirm hero record `LECA-20260826-001 — Full Review-to-Return Journey`.
- [x] Complete explicit entity, relationship, task, report, and demo-data mappings.
- [x] Generate schema-bound scenario payloads.
- [x] Document proposed inventory and solution membership.
- [x] Document the separate BPF designer handoff.
- [x] Review and approve all generated planning artifacts.
- [x] Commit and push planning artifacts only after explicit approval.

## Credential-Free Validation

- [x] Validate all JSON documents and payload schemas.
- [x] Run strict dry validation with scenario slug and publisher prefix `ppvs`.
- [x] Audit every custom component for prefix `ppvs`.
- [x] Audit solution identity, source tags, and hero label.
- [x] Run PowerShell parser, PSScriptAnalyzer, standalone CI, Pester, and Markdown lint.
- [x] Confirm the worktree contains only the expected planning package and credential-free validation support changes.
- [x] Stop for review before authentication or preview.

## Preview Gate

- [x] Obtain explicit preview authorization.
- [x] Run `pwsh ./scripts/bootstrap/90-run-build.ps1 -ScenarioSlug gcc-framework-acceptance -Mode Preview` only after approval.
- [x] Review the preview plan and verify that no apply step ran.
- [x] Stop again before authentication, live queries, or mutation.

## Authorization Boundary Correction

- [x] Record that live-read activity exceeded the credential-free preview authorization.
- [x] Record that the activity caused no Dataverse mutation.
- [x] Stop all further Dataverse access.
- [x] Rerun the complete credential-free local preview without authentication or Dataverse queries.

## Scenario Provenance Reconstruction

- [x] Deploy and validate scenario-scoped manifest architecture.
- [x] Correlate the recorded successful schema gate with exact live table descriptions and creation timestamps.
- [x] Verify all 15 planned columns and the exact relationship shape with GET-only metadata calls.
- [x] Verify unmanaged solution and publisher identity without changing PAC profiles.
- [x] Reconstruct 2 table, 15 column, and 1 relationship creation entries in the GCC scenario manifest.
- [x] Prove the legacy Contoso manifest remains separate.
- [x] Run step 60 in GET-only preview mode and prove generated Active-view adoption, both planned forms, the custom asset view, and preview provenance nonmutation.

## Consolidated Remaining Live Build (Not Authorized)

The reusable checked-in stages and credential-free tests are implemented. The tasks below remain live GCC execution tasks and require separate authorization.

- [ ] Obtain one consolidated completion authorization.
- [x] Verify permanent publisher `PowerPlatformVSCodeStarter`, unmanaged solution `LabEquipmentCheckoutAcceptance20260826`, and completed schema.
- [x] Generate and validate the supported Power Apps designer handoff; do not fabricate BPF workflow metadata.
- [ ] Create the separate Lab Asset Main and Checkout Request Main forms without modifying generated Information forms.
- [ ] Create Available Lab Assets using its `create-custom` contract.
- [ ] Adopt only the verified generated Active Checkout Requests view using its `adopt-generated-active` contract.
- [ ] Run `64-build-charts-dashboard.ps1` for the two payload-defined charts and dashboard.
- [ ] Create/update review app and sitemap with Checkout Request first.
- [ ] Collect complete artifact inventory and sync all required components to the solution.
- [ ] Publish only the two scenario tables and exact app module through scoped `PublishXml`; stop on `PublishAllXml`.
- [ ] Run `66-seed-synthetic-data.ps1` for exactly 3 assets and 5 requests using the approved source tag.
- [ ] Functionally verify navigation, forms, views, relationship behavior, charts, dashboard drill-through, and hero journey.
- [ ] Execute the orchestrated second pass and run `85-verify-idempotency.ps1 -Phase Verify` to prove stable IDs and zero duplicates.
- [ ] Verify final solution membership.
- [ ] Run `95-export-unmanaged-solution.ps1` to export, unpack, and inspect the unmanaged package locally without importing it anywhere.
- [ ] Retain acceptance artifacts after verification.
- [ ] Do not reset/delete the environment, clean up components, change unrelated PAC profiles, fabricate a BPF, or make Git changes during live execution.
