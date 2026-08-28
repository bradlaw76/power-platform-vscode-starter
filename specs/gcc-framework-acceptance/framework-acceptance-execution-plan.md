# Framework Acceptance Execution Plan

## Current Stop Point

Dataverse access is stopped. A revised credential-free local preview is authorized; authentication, Dataverse queries, apply, export, seeding, publishing, retention changes, reset, deletion, and cleanup must not run.

## Operation Classification

| Operation | Classification | Current authorization | Notes |
| --- | --- | --- | --- |
| Read local specs, payloads, schemas, scripts, and Git state | Read-only | Authorized | No service access |
| Parse JSON and PowerShell; run JSON Schema, lint, analyzer, unit, and contract tests | Read-only local validation | Authorized | May write ignored local test telemetry only when a test explicitly does so |
| Generate or edit scenario planning files and payload drafts | Planning-only local write | Authorized | No Dataverse effect |
| Run `15-dry-validate.ps1` against local payloads | Read-only local validation | Authorized | Use explicit prefix override `ppvs` |
| Run `90-run-build.ps1 -Mode Preview` | Preview-only orchestration | Authorized | Use sentinel connection values; live resolution disabled |
| Run `10-auth-connect.ps1` | Authentication and live validation | Not authorized | May query environment/solution/publisher; requires separate approval |
| Query Dataverse metadata or solution membership | Live read-only | Not authorized | Requires separate approval after planning review |
| Create publisher `PowerPlatformVSCodeStarter` with prefix `ppvs` | Mutating prerequisite | Not authorized | Permanent framework publisher; never a cleanup target |
| Create unmanaged solution `LabEquipmentCheckoutAcceptance20260826` | Mutating prerequisite | Not authorized | Must use the permanent publisher |
| Run scripts 20, 30, 40, 50, 55 apply path, 60, 62, or report authoring | Mutating | Not authorized | Creates/updates metadata, solution membership, forms/views/app/BPF linkage, or reports |
| Seed synthetic records | Mutating | Not authorized | Must use source tag `ppvs-acceptance-20260826` on every row |
| Publish customizations | Mutating | Not authorized | Required only after approved metadata changes |
| Export/unpack solution | Live read plus local write | Not authorized | Blocked until membership gate passes and export is approved |
| Reset or delete environment | Destructive | Prohibited | Environment is permanent |
| Delete components or synthetic records | Destructive cleanup | Prohibited | Requires separate explicit future approval; no approval exists |

## Preview-First Gates

1. Complete credential-free validation and review all generated contents.
2. Run only the authorized orchestrated Preview mode and review its output.
3. Stop before authentication, live query, or mutation.
4. Obtain separate mutation authorization.
5. Create the permanent publisher and unmanaged solution as separate bounded prerequisites.
6. Apply one bounded phase at a time with validation checkpoints.
7. Never infer cleanup approval from apply approval.

## Supported BPF Designer Handoff

- Script 55 does not create or patch BPF workflow definitions.
- First create `Lab Equipment Checkout Lifecycle` in the Power Apps BPF designer.
- Use unique name `ppvs_lab_equipment_checkout_lifecycle` and primary table `ppvs_checkoutrequest`.
- Add Review, Approve, Issue, and Return stages using the mappings in the process payload and designer handoff.
- Add the process to `LabEquipmentCheckoutAcceptance20260826`, activate it, and publish through the supported maker path.
- Only then may an approved script 55 apply run validate the existing category-4 process, verify fields and thresholds, add/confirm membership, activate if required, and link it to the review app.
- If designer authoring is unavailable, stop and preserve the handoff; do not synthesize `clientdata`, `uidata`, or `xaml`.

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
- BPF designer handoff, validation thresholds, active state, membership, and app-linkage evidence.
- Functional evidence for landing view, navigation, relationship requiredness, restrict delete, lifecycle, availability, dashboard drill-through, and deterministic rerun.
