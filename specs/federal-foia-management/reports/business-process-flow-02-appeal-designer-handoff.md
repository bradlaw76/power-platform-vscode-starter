# Business Process Flow Designer Handoff

This repository does not create BPF definition metadata through direct Dataverse Web API workflow payloads.
Create the process with the Power Apps Business Process Flow designer, add it to the target solution, publish it, then rerun step 55.

- Display name: Federal FOIA Appeal Lifecycle
- Expected unique name: foia_federal_foia_appeal_lifecycle
- Primary table: foia_appeal
- Target solution: FederalFOIAManagement

## Stages

### 1. Appeal Intake
- Table: foia_appeal
- Required fields: foia_appealnumber, foia_receiveddate, foia_challengeddetermination
- Entry criteria: Appeal received and linked; FOIA-REV-006.
- Exit criteria: Identity, receipt, and challenged determination recorded; FOIA-REV-006.

### 2. Validation
- Table: foia_appeal
- Required fields: foia_duedate
- Entry criteria: Appeal intake is recorded.
- Exit criteria: Timeliness, scope, and appeal due date validated; FOIA-CLK-001..006.

### 3. Reconsideration and Legal Review
- Table: foia_appeal
- Required fields: foia_challengeddetermination
- Entry criteria: Appeal validation passes.
- Exit criteria: Decision evidence is reconsidered; FOIA-REV-001..006.

### 4. Appeal Decision
- Table: foia_appeal
- Required fields: foia_decision, foia_outcome
- Entry criteria: Legal review is complete.
- Exit criteria: Authorized decision and outcome recorded; FOIA-REV-006.

### 5. Response
- Table: foia_appeal
- Required fields: foia_outcome
- Entry criteria: Appeal decision has final approval.
- Exit criteria: Approved response issuance recorded; FOIA-CAS-005.

### 6. Closure
- Table: foia_appeal
- Required fields: foia_outcome, foia_closeddate
- Entry criteria: Response issued or controlled final outcome applies.
- Exit criteria: Closure reconciles to Appeal Clock Events; FOIA-RPT-003.

## Verification
1. Activate the process in the designer.
2. Confirm the process is present in the target unmanaged solution.
3. Rerun step 55 in apply mode; it validates and links the existing process.
