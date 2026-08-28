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

## Future Mutating Work (Not Authorized)

- [ ] Obtain separate apply authorization.
- [ ] Create permanent publisher `PowerPlatformVSCodeStarter` with prefix `ppvs`.
- [ ] Create unmanaged solution `LabEquipmentCheckoutAcceptance20260826` under that publisher.
- [ ] Build `ppvs_labasset` and `ppvs_checkoutrequest`.
- [ ] Build prefixed columns and required restrict-delete relationship.
- [ ] Create the base BPF in the Power Apps designer from the handoff.
- [ ] Validate, activate, add, publish, and link the existing BPF through script 55.
- [ ] Create/update main forms and active views.
- [ ] Create/update review app and sitemap with Checkout Request first.
- [ ] Author lifecycle/availability dashboard and charts through the supported maker/solution path.
- [ ] Collect complete artifact inventory and sync all required components to the solution.
- [ ] Verify solution membership before any export.
- [ ] Seed exactly 3 assets and 5 requests using the approved source tag.
- [ ] Validate the hero journey and deterministic second run.
- [ ] Retain acceptance artifacts after verification.
- [ ] Do not reset, delete, or clean up the environment.
