# Lab Equipment Checkout Framework Acceptance Plan

## Build Approach

- Wizard mode: `framework-acceptance`
- Environment: Power Platform VS Code Starter - GCC
- Environment URL: `[APPROVED_GCC_ENVIRONMENT_URL]`
- Solution type: Unmanaged
- Solution unique name: LabEquipmentCheckoutAcceptance20260826
- Solution display name: Lab Equipment Checkout Acceptance — 2026-08-26
- Publisher prefix: ppvs
- Publisher unique name: PowerPlatformVSCodeStarter
- Publisher display name: Power Platform VS Code Starter
- Publisher lifecycle: permanent; excluded from every cleanup plan
- Source tag: ppvs-acceptance-20260826
- Current phase: credential-free revised preview complete; stopped for explicit mutation authorization

## Explicit Entity Mapping (Required Before Payloads)

### Standard reused tables (display -> logical)

- None.

### Custom tables to create (input -> generated logical)

- Lab Asset -> ppvs_labasset
- Checkout Request -> ppvs_checkoutrequest

### Standard fields reused

- None.

### Custom fields to add

- `ppvs_labasset.ppvs_assettag`
- `ppvs_labasset.ppvs_category`
- `ppvs_labasset.ppvs_availabilitystatus`
- `ppvs_labasset.ppvs_acceptancesourcetag`
- `ppvs_checkoutrequest.ppvs_requestnumber`
- `ppvs_checkoutrequest.ppvs_requestername`
- `ppvs_checkoutrequest.ppvs_requestedon`
- `ppvs_checkoutrequest.ppvs_expectedreturndate`
- `ppvs_checkoutrequest.ppvs_actualreturndate`
- `ppvs_checkoutrequest.ppvs_lifecyclestage`
- `ppvs_checkoutrequest.ppvs_approvaldecision`
- `ppvs_checkoutrequest.ppvs_acceptancesourcetag`
- `ppvs_checkoutrequest.ppvs_labassetid`

### Relationships to create

- ppvs_checkoutrequest (referencing) -> ppvs_labasset (referenced)

Relationship decision: N:1, required, new, Restrict delete, supporting request history and availability drill-through.

## Workstreams

1. Review and approve planning artifacts and complete component inventory.
2. Validate JSON payloads, prefix usage, solution identity, source tag, and hero label without credentials.
3. Run the authorized credential-free preview and inspect its local plan without applying mutations.
4. Stop and request explicit mutation authorization.
5. After authorization, verify-or-create permanent publisher `PowerPlatformVSCodeStarter` with prefix `ppvs`.
6. Verify-or-create unmanaged solution `LabEquipmentCheckoutAcceptance20260826` under that publisher.
7. Build tables, columns, and relationship.
8. Use the Power Apps designer handoff to create the base BPF; do not automate its definition metadata.
9. Validate/activate/add/link the existing BPF through script 55 after designer publication.
10. Create forms, views, review app, navigation, and the approved report surface.
11. Inventory and synchronize all proposed components into the isolated solution, then verify membership.
12. Seed only the approved synthetic records with the approved source tag.
13. Run functional and deterministic-rerun validation; retain artifacts and stop without cleanup.

## Idempotency Plan

- Tables, columns, relationships, forms, views, app, sitemap, and BPF are resolved by stable logical or unique names.
- Synthetic records are upserted using scenario-defined natural keys scoped by `ppvs-acceptance-20260826`.
- The second approved run must report created/updated/skipped counts and show no uncontrolled duplicate records or components.
- Cleanup is not part of rerun behavior and remains prohibited without separate approval.
- The permanent `PowerPlatformVSCodeStarter` publisher is never a cleanup target, even if targeted cleanup is later approved.

## Report Plan

- Surface: Lab Equipment Lifecycle and Availability dashboard.
- Components: adopted generated Active Checkout Requests view, separate custom Available Lab Assets view, Requests by Lifecycle Stage chart, Assets by Availability chart, and dashboard drill-through.
- Critical tables: `ppvs_checkoutrequest`, `ppvs_labasset`.
- HTML report web resources: disabled.
- Dashboard/chart authoring must use the supported maker/solution path if no repository automation exists; it may not be represented as completed until inventory and membership checks pass.

## Validation Gates

- Payload schema validation passes.
- Build contract strict validation passes with prefix `ppvs`.
- Prefix audit finds no custom logical or unique names outside `ppvs`.
- Identity audit confirms only `LabEquipmentCheckoutAcceptance20260826`.
- Demo-data audit confirms every planned record has source tag `ppvs-acceptance-20260826`.
- Hero audit confirms `LECA-20260826-001 — Full Review-to-Return Journey`.
- Proposed component inventory and membership are reviewed before preview authorization is requested.
- Publisher and solution creation remain planned mutations and are not represented as completed.

## Safety Gates

- Do not authenticate, query, apply, export, seed, publish, or clean up at the current stop point.
- The environment is permanent and must not be reset or deleted.
- Credential-free preview is authorized and complete.
- Apply and all mutations, including publisher and solution creation, require separate explicit authorization.
- Cleanup requires separate explicit approval and is currently prohibited.
- Preserve existing isolated Contoso components.
