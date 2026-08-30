# Business Process Flow Designer Handoff

This validated handoff is the Framework Acceptance deliverable for the planned BPF. The acceptance run does not create or modify BPF definition metadata. A future separately authorized maker may use this document to create the process with the Power Apps Business Process Flow designer.

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

## Handoff Validation

1. Confirm the handoff identifies the exact target solution, primary table, form, unique name, and four ordered stages.
2. Confirm every referenced field exists in the approved scenario payloads and live reconstructed schema.
3. Confirm each stage has entry, exit, and human-checkpoint or completion guidance.
4. Confirm the handoff requires the supported Power Apps designer and forbids direct workflow-definition payload construction.
5. Record the handoff as validated without requiring an active process, solution membership, or app linkage.

## Unsupported Operations

- Do not fabricate or patch `clientdata`, `uidata`, or `xaml`.
- Do not use direct workflow-definition payload construction.
- Do not represent the handoff as an active BPF component.
