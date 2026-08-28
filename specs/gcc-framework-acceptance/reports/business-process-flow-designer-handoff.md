# Business Process Flow Designer Handoff

This repository does not create BPF definition metadata through direct Dataverse Web API workflow payloads. Create the base process with the Power Apps Business Process Flow designer, add it to the target solution, activate and publish it, then use script 55 only for supported validation, membership, activation, and app-linkage work after explicit apply authorization.

- Display name: Lab Equipment Checkout Lifecycle
- Expected unique name: `ppvs_lab_equipment_checkout_lifecycle`
- Primary table: `ppvs_checkoutrequest`
- Target solution: `LabEquipmentCheckoutAcceptance20260826`
- Target main form: Checkout Request Main
- Cross-table progression: no

## Stages

### 1. Review

- Table: `ppvs_checkoutrequest`
- Required fields: `ppvs_requestnumber`, `ppvs_requestedon`
- Entry criteria: A synthetic checkout request has been created and linked to a Lab Asset.
- Exit criteria: Request details and expected return date have been reviewed.

### 2. Approve

- Table: `ppvs_checkoutrequest`
- Required fields: `ppvs_approvaldecision`
- Entry criteria: Review is complete.
- Exit criteria: Approval Decision is Approved or Declined; only Approved requests proceed to Issue.
- Human checkpoint: Lab coordinator records the decision.

### 3. Issue

- Table: `ppvs_checkoutrequest`
- Required fields: `ppvs_lifecyclestage`
- Entry criteria: Approval Decision is Approved and the linked asset is available.
- Exit criteria: Lifecycle Stage is Issue and the asset availability is Issued.
- Human checkpoint: Lab coordinator confirms physical handoff.

### 4. Return

- Table: `ppvs_checkoutrequest`
- Required fields: `ppvs_actualreturndate`
- Entry criteria: The asset has been issued.
- Exit criteria: Actual Return Date is recorded, Lifecycle Stage is Return, and the asset is available.
- Completion behavior: Finish means the request lifecycle is complete and the asset can be issued again.

## Supported Verification

1. Confirm every field exists before binding it in the designer.
2. Activate and publish the process in Power Apps.
3. Confirm the process is present in `LabEquipmentCheckoutAcceptance20260826`.
4. After explicit apply authorization, rerun script 55 to validate the existing category-4 process.
5. Confirm active state, stage and step thresholds, solution membership, and review-app linkage.

## Unsupported Operations

- Do not fabricate or patch `clientdata`, `uidata`, or `xaml`.
- Do not use direct workflow-definition payload construction.
- Do not treat an Active state or solution membership alone as proof of a valid BPF.
