# spec.md

## Scenario Summary
FAST 005A Fraud Investigation Framework Acceptance is a Fraud investigation management acceptance application for Power Apps.

## Application Architecture
- Wizard mode: framework-acceptance
- Profile: standalone-model-driven
- Table strategy: custom-only
- Form strategy: create-new-forms
- Entry point: fva_investigation
- Landing view: Active Investigations
- Entry-point validation: approved
- Landing-view action: adopt-generated-active
- Review app: create-or-update
- Required app artifacts: all planned tables, forms, views, assignment and approval workflows, fraud-scoring integration, reports, and acceptance evidence
- Power Apps grid: enabled=yes; scope=all-views; inline-editing=yes
- Grid contract: generate and review grid-controls.json when enabled; stage 61 is a maker handoff plus exported-solution verification gate, not metadata mutation.

## Problem Statement
Manage investigation intake, investigator assignment, evidence custody, interviews, external fraud-scoring integration, supervisor approval, and operational and management reporting with deterministic acceptance evidence

## Target Audience
Fraud investigators, supervisors, evidence custodians, compliance reviewers, and framework maintainers

## Users
Fraud investigators, supervisors, evidence custodians, compliance reviewers

## Required Data Entities
Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report

### Table Strategy
- **Approach**: custom-only
- **Guidance**: See 'docs/standard-dataverse-tables.md' for out-of-box vs custom tables.

## Explicit Entity Mapping (Required)

### Standard reused tables (display -> logical)
- None

### Custom tables to create (input -> generated logical)
- Investigation -> fva_investigation
- Investigator Assignment -> fva_investigatorassignment
- Evidence -> fva_evidence
- Evidence Custody Event -> fva_evidencecustodyevent
- Interview -> fva_interview
- Fraud Score -> fva_fraudscore
- Supervisor Approval -> fva_supervisorapproval
- Report -> fva_report

### Standard fields reused
- None

### Custom fields to add
- Investigation.fva_name
- Investigation.fva_status
- Investigation.fva_summary
- Evidence.fva_name
- EvidenceCustodyEvent.fva_action
- Interview.fva_interviewdate
- FraudScore.fva_score
- FraudScore.fva_auditreference
- SupervisorApproval.fva_decision
- Report.fva_name

### Relationships to create
- Investigator Assignment -> Investigation
- Evidence -> Investigation
- Evidence Custody Event -> Evidence
- Interview -> Investigation
- Fraud Score -> Investigation
- Supervisor Approval -> Investigation
- Report -> Investigation

### Relationship decisions
Investigator Assignment -> Investigation | many-to-one | required | new | restrict delete | intake assignment; Evidence -> Investigation | many-to-one | required | new | restrict delete | evidence tracking; Evidence Custody Event -> Evidence | many-to-one | required | new | cascade assign | custody timeline; Interview -> Investigation | many-to-one | required | new | cascade assign | interview history; Fraud Score -> Investigation | many-to-one | required | new | restrict delete | external score audit; Supervisor Approval -> Investigation | many-to-one | required | new | restrict delete | approval gate; Report -> Investigation | many-to-one | optional | new | remove link | reporting

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
- Task definitions: Investigator | triage intake and assign investigator | per intake | fva_investigation/Active Investigations | owner and priority are recorded; Evidence custodian | record each custody transfer | per transfer | fva_evidence/Active Evidence | complete chain of custody is traceable; Investigator | document interview | per interview | fva_interview/Recent Interviews | statement and participants are recorded; Supervisor | review scored investigation | per submission | fva_investigation/Pending Approval | decision and rationale are recorded; Manager | review investigation reporting | daily | fva_report/Operational Reports | workload and outcomes are visible
- Ownership and done definitions: triage intake and assign investigator | Investigation supervisor | owner and priority are recorded; record each custody transfer | Evidence custodian | immutable custody event is linked to evidence; document interview | Assigned investigator | interview date, participants, and notes are complete; review scored investigation | Supervisor | approval decision and rationale are complete; review investigation reporting | Program manager | required metrics reconcile to investigation records

## Demo Data Requirements
- Enabled: No
- Scope and target tables: none -- none
- Standard reused table strategy: none
- Record counts: none
- Required scenarios/states: none
- Hero records: none
- Relationship distribution: none
- Task activity generation: no -- none 0 records per table, ordered by none
- Synthetic-data/privacy rule: none

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
Intake and assignment forms, active investigation and custody views, interview timeline, external fraud-scoring integration, supervisor approval workflow, operational dashboard, management reports, and acceptance evidence

## Success Criteria
A synthetic fraud case proves intake, assignment, custody, interviews, fraud-score auditability, approval, reporting, stable reruns, and an unchanged approved architecture decision

## Environment
Authorized GCC development environment https://powerplatformvscodestarter.crm9.dynamics.com

## Demo Data Requirement
No

## Solution Packaging Decision
Unmanaged

## Solution and Publisher
- Solution: Fast005AFraudFramework20261015 (new)
- Publisher prefix: fva (new)

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
- REQ-EVIDENCE-CUSTODY-001: EXTEND, INTEGRATE | candidate=microsoft-fast:module:investigations | evidence=package-verified
- REQ-EXTERNAL-FRAUD-SCORING-INTEGRATION-001: BUILD, INTEGRATE | candidate= | evidence=unverified
- REQ-INTERVIEW-001: INTEGRATE, VERIFY | candidate= | evidence=unverified
- REQ-INVESTIGATION-INTAKE-001: EXTEND, INTEGRATE | candidate=microsoft-fast:module:investigations | evidence=package-verified
- REQ-INVESTIGATOR-ASSIGNMENT-001: BUILD, INTEGRATE | candidate= | evidence=unverified
- REQ-OPERATIONAL-AND-MANAGEMENT-REPORTING-001: BUILD, INTEGRATE | candidate= | evidence=unverified
- REQ-SUPERVISOR-APPROVAL-001: BUILD, INTEGRATE | candidate= | evidence=unverified

## Acceptance Criteria
- The scenario is clear and approved.
- Required entities and artifacts are identified.
- Success measures are specific enough to validate.
- The environment and solution type are agreed before implementation.
