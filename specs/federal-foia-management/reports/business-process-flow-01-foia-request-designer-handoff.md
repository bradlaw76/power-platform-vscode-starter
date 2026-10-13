# Business Process Flow Designer Handoff

This repository does not create BPF definition metadata through direct Dataverse Web API workflow payloads.
Create the process with the Power Apps Business Process Flow designer, add it to the target solution, publish it, then rerun step 55.

- Display name: Federal FOIA Request Lifecycle
- Expected unique name: foia_federal_foia_request_lifecycle
- Primary table: foia_foiarequest
- Target solution: FederalFOIAManagement

## Stages

### 1. Intake
- Table: foia_foiarequest
- Required fields: foia_trackingnumber, foia_intakechannel, foia_receiveddate, foia_validationstate
- Entry criteria: Submission received through an approved channel; FOIA-INT-001.
- Exit criteria: Validation, tracking, and acknowledgment complete; FOIA-INT-002..005.

### 2. Clarification
- Table: foia_foiarequest
- Required fields: foia_validationstate, foia_clarificationduedate
- Entry criteria: Scope requires human-managed correction; FOIA-INT-002.
- Exit criteria: Scope is clarified and perfected or controlled disposition recorded; FOIA-CAS-001.

### 3. Search
- Table: foia_foiarequest
- Required fields: foia_currentduedate
- Entry criteria: Perfected request has approved search scope; FOIA-COL-003.
- Exit criteria: Every approved search has evidence and results; FOIA-COL-003.

### 4. Review
- Table: foia_foiarequest
- Required fields: foia_currentduedate
- Entry criteria: Collected record metadata is available; FOIA-REV-001.
- Exit criteria: Required review dispositions are documented; FOIA-REV-001..003.

### 5. Redaction
- Table: foia_foiarequest
- Required fields: foia_currentduedate
- Entry criteria: Review identifies controlled redaction work; FOIA-REV-004.
- Exit criteria: Every proposed redaction has independent approval state; FOIA-CAS-005.

### 6. Approval
- Table: foia_foiarequest
- Required fields: foia_disposition
- Entry criteria: Controlled decisions are ready for approval; FOIA-CAS-005.
- Exit criteria: Independent human approvals are recorded; FOIA-CAS-005; FOIA-SEC-002.

### 7. Release
- Table: foia_foiarequest
- Required fields: foia_disposition
- Entry criteria: Approved fixed package is ready; FOIA-REV-005..007.
- Exit criteria: Method, recipient, hash, and timestamp are recorded; FOIA-REV-005.

### 8. Closure
- Table: foia_foiarequest
- Required fields: foia_disposition, foia_closeddate
- Entry criteria: A controlled final disposition is complete; FOIA-CAS-001.
- Exit criteria: Closure reconciles to clock and audit history; FOIA-RPT-003.

## Verification
1. Activate the process in the designer.
2. Confirm the process is present in the target unmanaged solution.
3. Rerun step 55 in apply mode; it validates and links the existing process.
