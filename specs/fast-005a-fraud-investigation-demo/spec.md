# spec.md

## Scenario Summary
FAST 005A Fraud Investigation Demo is a FAST 005A Fraud Investigation Demo for Power Apps model-driven app on Dataverse.

## Application Architecture
- Wizard mode: demo-builder
- Profile: standalone-model-driven
- Table strategy: custom-only
- Form strategy: create-new-forms
- Entry point: fasta_investigation
- Landing view: Active Investigations
- Entry-point validation: approved
- Landing-view action: adopt-generated-active
- Review app: create-or-update
- Required app artifacts: all run-created tables, forms, views, processes, and approved reports
- Power Apps grid: enabled=yes; scope=all-views; inline-editing=yes
- Grid contract: generate and review grid-controls.json when enabled; stage 61 is a maker handoff plus exported-solution verification gate, not metadata mutation.

## Problem Statement
FAST 005A Fraud Investigation Demo

## Target Audience
Fraud investigator | triage intake, assign investigators, and manage cases through supervisor approval

## Users
Fraud investigator | triage intake, assign investigators, and manage cases through supervisor approval

## Required Data Entities
Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report

### Table Strategy
- **Approach**: custom-only
- **Guidance**: See 'docs/standard-dataverse-tables.md' for out-of-box vs custom tables.

## Explicit Entity Mapping (Required)

### Standard reused tables (display -> logical)
- None

### Custom tables to create (input -> generated logical)
- Investigation -> fasta_investigation
- Investigator Assignment -> fasta_investigatorassignment
- Evidence -> fasta_evidence
- Evidence Custody Event -> fasta_evidencecustodyevent
- Interview -> fasta_interview
- Fraud Score -> fasta_fraudscore
- Supervisor Approval -> fasta_supervisorapproval
- Report -> fasta_report

### Standard fields reused
- None

### Custom fields to add
- to be refined during planning

### Relationships to create
- to be recommended and confirmed during planning

### Relationship decisions
recommendation pending stakeholder confirmation

### Payload Generation Gate
- Do not generate payloads until this mapping is complete and stakeholder-approved.
- Do not include standard tables in table-creation payloads.
- Reuse out-of-box fields unless a true custom field is required.

## Optional Report Web Resources
- Enabled: no
- Report set: Operational workspace; Team workload; Management KPI
- Visual style: Power Apps neutral tokens with icon-backed KPI cards.
- Integration scope: Create HTML web resources and add them to solution (no automatic form-tab insertion).
- Report scoping status: approved-no-reports
- Critical or high-frequency tables: none
- Approved mapping: See report-mappings.md.

## User Tasks
- Task definitions: Fraud investigator | triage intake, assign investigators, and manage cases through supervisor approval | Capture intake, assign an investigator, maintain evidence chain of custody, document interviews, call an external fraud-scoring service, route the case for supervisor approval, and present operational and management reporting | primary workflow | fasta_investigation/Active Investigations | A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting
- Ownership and done definitions: Capture intake, assign an investigator, maintain evidence chain of custody, document interviews, call an external fraud-scoring service, route the case for supervisor approval, and present operational and management reporting | app owner | A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting

## Demo Data Requirements
- Enabled: Yes
- Scope and target tables: all-created -- Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report
- Standard reused table strategy: none
- Record counts: small synthetic set; counts to be confirmed during planning
- Required scenarios/states: A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting
- Hero records: none
- Relationship distribution: none
- Task activity generation: no -- none 0 records per table, ordered by none
- Synthetic-data/privacy rule: synthetic data only; no personal or production data

## Optional Business Process Flow
- Enabled: no
- Process name:
- Primary entity:
- Target Main form:
- Cross-table progression: no
- Fail if definition incomplete: yes
- Prefer update existing: yes

### BPF Stage Definitions
- None

### BPF Generation Gate
- Build a BPF only when the scenario has a real staged lifecycle and the repo contains a matching process-*.json definition.
- Every stage must declare required fields, entry criteria, and exit criteria.
- Every cross-table stage must name the supporting relationship payload that justifies the transition.
- If the scenario is CRUD-only, leave BPF disabled and skip generation.

## Required Experience and Artifacts
Capture intake, assign an investigator, maintain evidence chain of custody, document interviews, call an external fraud-scoring service, route the case for supervisor approval, and present operational and management reporting

## Success Criteria
A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting

## Environment
https://powerplatformvscodestarter.crm9.dynamics.com; unmanaged solution

## Demo Data Requirement
Yes

## Solution Packaging Decision
Unmanaged

## Solution and Publisher
- Solution: Fast005AFraudInvestigationDemo (new)
- Publisher prefix: fasta (new)

## Accelerator Startup Preference
- Preliminary preference: evaluate
- Matching requested: True
- This preference is separate from final architecture approval and does not authorize deployment.
## Accelerator Evaluation
- Recommended architecture: hybrid
- Approved architecture: hybrid
- Catalog snapshot: sha256:777873ba1d2beedcb9fb5de2fe85d17c0f5bb20c6fafe5ce674d0de654be8348
- Selected packages: microsoft-fast:module:core 1.2.1.0 [f813e8500b97db1fd74f938da28f22ba53c1c4593f6374b34e8a0f7d52e895b3]; microsoft-fast:module:investigations 1.2.1.0 [131be1ade134e838e3d824777b6655331a7149eaf80ae14bc26583a4f1bb8391]
- Environment readiness: action-required
- FAST-dependent generation gate: False

### Requirement coverage
- REQ-ASSIGNMENT-INVESTIGATOR-001: BUILD | candidate= | evidence=unverified
- REQ-EVIDENCE-CHAIN-CUSTODY-001: EXTEND | candidate=microsoft-fast:module:investigations | evidence=package-verified
- REQ-EXTERNAL-FRAUD-SCORING-SERVICE-001: VERIFY | candidate=microsoft-fast:module:programs-and-services | evidence=conceptual
- REQ-INTAKE-001: BUILD | candidate= | evidence=unverified
- REQ-INTERVIEW-001: EXTEND | candidate=microsoft-fast:module:investigations | evidence=package-verified
- REQ-OPERATIONAL-AND-MANAGEMENT-REPORTING-001: BUILD | candidate= | evidence=unverified
- REQ-THE-CASE-FOR-SUPERVISOR-001: BUILD | candidate= | evidence=unverified

## Acceptance Criteria
- The scenario is clear and approved.
- Required entities and artifacts are identified.
- Success measures are specific enough to validate.
- The environment and solution type are agreed before implementation.
