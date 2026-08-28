# Framework Acceptance Answers

## Scenario

- Name: Lab Equipment Checkout
- Slug: gcc-framework-acceptance
- Wizard mode: framework-acceptance
- Environment: Power Platform VS Code Starter - GCC
- Environment URL: `[APPROVED_GCC_ENVIRONMENT_URL]`
- Environment authorization: authorized for this isolated Framework Acceptance run
- Environment lifecycle: permanent; do not reset or delete

## Application Profile

- Profile: standalone-model-driven
- Table Strategy: custom-only
- Form Strategy: create-new-forms
- Entry Point Table: ppvs_checkoutrequest
- Landing View: Active Checkout Requests
- Landing View Plan: adopt-generated-active after proving current-scenario table ownership and generated Active/default-view identity
- Review App Mode: create-or-update
- Required App Artifacts: Lab Asset and Checkout Request tables, main forms, active views, Lab Equipment Checkout Lifecycle BPF, lifecycle and availability report surface
- View Dispositions: Active Checkout Requests = adopt-generated-active; Available Lab Assets = create-custom

## App Module

- Enabled: yes
- App Name: Lab Equipment Checkout Acceptance — 2026-08-26
- Unique Name: ppvs_lab_equipment_checkout_acceptance_20260826
- Navigation Group: Checkout Operations

## Solution Identity

- Solution unique name: `LabEquipmentCheckoutAcceptance20260826`
- Solution display name: Lab Equipment Checkout Acceptance — 2026-08-26
- Solution type: unmanaged
- Solution strategy: create under the permanent `PowerPlatformVSCodeStarter` publisher after explicit mutation authorization
- Publisher prefix: `ppvs`
- Publisher unique name: `PowerPlatformVSCodeStarter`
- Publisher display name: Power Platform VS Code Starter
- Publisher strategy: create once as a permanent framework publisher; never include it in cleanup

## Optional Report Web Resources

- Enabled: no
- Selected Reports: none
- Decision: Use a model-driven lifecycle and availability dashboard with views and charts; do not generate an HTML web resource.

## Synthetic Acceptance Data

- Enabled: yes
- Source tag: `ppvs-acceptance-20260826`
- Source tag column: `ppvs_acceptancesourcetag` on every scenario table
- Lab Asset records: 3
- Checkout Request records: 5
- Hero record: `LECA-20260826-001 — Full Review-to-Return Journey`
- Privacy: synthetic data only; no personal, customer, or production data
- Rerun behavior: deterministic upsert by scenario-defined natural keys and source tag
- Retention: retain after verification
- Cleanup approval: no

## Acceptance Controls

- Preview authorization: granted and completed for credential-free local execution only
- Live-read scope note: later live-read activity was outside the credential-free preview authorization and must not be treated as preview evidence; it caused no Dataverse mutation
- Apply authorization: not granted
- Export authorization: not granted
- Cleanup authorization: not granted
- Reset or delete environment: prohibited
- Automatic cleanup: prohibited
