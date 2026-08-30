# Framework Acceptance Execution Plan

## Current Stop Point

Dataverse access is stopped after the successful GET-only provenance reconstruction. The remaining live build requires one consolidated authorization covering forms/views, charts/dashboard, app/sitemap, tagged synthetic records, publishing, functional verification, second-run idempotency, and unmanaged export/package inspection.

## Operation Classification

| Operation | Classification | Current authorization | Notes |
| --- | --- | --- | --- |
| Read local specs, payloads, schemas, scripts, and Git state | Read-only | Authorized | No service access |
| Parse JSON and PowerShell; run JSON Schema, lint, analyzer, unit, and contract tests | Read-only local validation | Authorized | May write ignored local test telemetry only when a test explicitly does so |
| Generate or edit scenario planning files and payload drafts | Planning-only local write | Authorized | No Dataverse effect |
| Run `15-dry-validate.ps1` against local payloads | Read-only local validation | Authorized | Use explicit prefix override `ppvs` |
| Run `90-run-build.ps1 -Mode Preview` | Preview-only orchestration | Authorized | Use sentinel connection values; live resolution disabled |
| Run `10-auth-connect.ps1` | Authentication and live validation | Not authorized | May query environment/solution/publisher; requires separate approval |
| Query Dataverse metadata or solution membership | Live read-only | Completed for provenance; future reads included only in consolidated build | GET-only reconstruction passed |
| Publisher `PowerPlatformVSCodeStarter` with prefix `ppvs` | Existing prerequisite | Verified | Permanent framework publisher; never a cleanup target |
| Unmanaged solution `LabEquipmentCheckoutAcceptance20260826` | Existing prerequisite | Verified | Exact publisher identity confirmed |
| Existing schema: scripts 20, 30, and 40 | Completed before reconstruction | Proven | 2 tables, 15 columns, and 1 relationship reconstructed into scoped provenance |
| Run forms/views, charts/dashboard, app/sitemap, sync, and required publish operations | Mutating | Not authorized | Covered by one consolidated completion request |
| Seed synthetic records | Mutating | Not authorized | Must use source tag `ppvs-acceptance-20260826` on every row |
| Publish customizations | Mutating | Not authorized | Component-scoped `PublishXml` only for scenario tables and exact app module; `PublishAllXml` prohibited |
| Export/unpack and inspect unmanaged solution | Live read plus local write | Not authorized | Unmanaged export only; local inspection only; no import; blocked until membership passes |
| Reset or delete environment | Destructive | Prohibited | Environment is permanent |
| Delete components or synthetic records | Destructive cleanup | Prohibited | Requires separate explicit future approval; no approval exists |

## Completion Flow

1. Revalidate identity, scoped provenance, and inventory.
2. Execute the remaining build as one authorized flow with validation checkpoints, stopping on any hard-gate failure.
3. Generate and validate the BPF designer handoff; do not fabricate workflow internals.
4. Publish only scoped components, verify function, rerun for zero duplicates, enforce membership, then export/unpack/inspect locally without import.
5. Never infer cleanup, environment deletion, PAC profile changes, or source-control approval from build approval.

## Supported BPF Designer Handoff

- Script 55 does not create or patch BPF workflow definitions.
- First create `Lab Equipment Checkout Lifecycle` in the Power Apps BPF designer.
- Use unique name `ppvs_lab_equipment_checkout_lifecycle` and primary table `ppvs_checkoutrequest`.
- Add Review, Approve, Issue, and Return stages using the mappings in the process payload and designer handoff.
- Add the process to `LabEquipmentCheckoutAcceptance20260826`, activate it, and publish through the supported maker path.
- Acceptance requires only generation and validation of this supported designer handoff.
- Do not synthesize `clientdata`, `uidata`, or `xaml`, and do not require an active BPF component for this acceptance run.

## Permanent Environment Constraints

- Environment: Power Platform VS Code Starter - GCC.
- The environment is permanent.
- Do not reset or delete it.
- Do not modify or remove existing isolated Contoso components.
- Retain acceptance artifacts after verification.
- Do not perform automatic or implicit cleanup.
- Never delete or include publisher `PowerPlatformVSCodeStarter` in cleanup scope.
- Any future targeted cleanup must use source tag `ppvs-acceptance-20260826` and requires separate explicit approval.

## Evidence Required Before Completion

- Payload schema and strict dry-validation reports.
- Prefix, solution identity, source-tag, and hero-label audit results.
- Preview output reviewed before apply authorization.
- Created/updated/skipped/failed counts by component category.
- Final inventory and solution membership report.
- Generated and validated BPF designer handoff; active-state, membership, and app linkage are not required for this acceptance scenario.
- Functional evidence for landing view, navigation, relationship requiredness, restrict delete, lifecycle, availability, dashboard drill-through, and deterministic rerun.
- Unmanaged export, successful unpack, and package-content inspection evidence.
- Collision checks prove exactly one matching form, view, chart, dashboard, app, sitemap, and natural-key record; mismatched ownership, solution membership, or metadata stops before mutation.
