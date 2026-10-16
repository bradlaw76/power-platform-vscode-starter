# Discovery Answers

## Contract
- Contract: docs/wizard-contract-v1.md
- Profile: wizard.profile.json
- Wizard mode: advanced-builder

## Scenario
- Name: FAST 006 Fraud Investigation Fully Custom
- Slug: fast-006-fraud-investigation-fully-custom

## Application Profile
- Profile: standalone-model-driven
- Table Strategy: custom-only
- Form Strategy: create-new-forms
- Entry Point Table: fiv_investigation
- Landing View: Active Investigations
- Entry Point Validation: approved
- Landing View Plan: adopt-generated-active
- Power Apps Grid (table-level, all views): no
- Power Apps Grid Inline Editing: no
- Review App Mode: create-or-update
- Required App Artifacts: all planned tables, forms, views, assignment and approval workflows, fraud-scoring integration, and reports

## Framework Acceptance Controls
- Environment authorized: not applicable
- Isolated solution name: not applicable
- Publisher prefix: not applicable
- Hero record labels: not applicable
- Rerun evidence: not applicable
- Retention policy: not applicable
- Destructive cleanup separately approved: not applicable
- Evidence plan: not applicable

## App Module
- Enabled: yes
- App Name: FAST 006 Fraud Investigation Fully Custom Review App
- Unique Name: fiv_fast_006_fraud_investigation_fully_custom_app
- Navigation Group: Investigations

## Required Question Set (11)
1. Type of demo/app: Fraud investigation management application
2. Platform area: Power Apps
3. Target audience: Fraud investigators, supervisors, evidence custodians, and compliance reviewers
4. Business problem: Manage investigation intake, investigator assignment, evidence custody, interviews, external fraud-scoring integration, supervisor approval, and operational and management reporting
5. Users: Fraud investigators, supervisors, evidence custodians, compliance reviewers
6. Data entities: Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report
7. Needed artifacts: Intake and assignment forms, active investigation and custody views, interview timeline, external fraud-scoring integration, supervisor approval workflow, operational dashboard, and management reports
8. Success definition: An investigator completes a synthetic fraud case with traceable custody, interview history, an externally sourced fraud score and audit reference, supervisor approval, and accurate reporting
9. Build environment: Authorized GCC development environment https://powerplatformvscodestarter.crm9.dynamics.com
10. Demo data needed: No
11. Solution output type: Unmanaged

## Extension Blocks
- business-process-flow: enabled=no ; primary= ; name=
- table-strategy: custom-only
- solution-identity: solution=new -- Fast006FraudFullyCustom; prefix=new -- fiv
- reporting: no
- source-control: branch=feature/fast-accelerator-catalog; commits=checkpoints; pull-request=no
- retrofit: disabled

## Source Control Plan
- Standards: requirements/GithubInstructions_General.md
- Scenario branch: feature/fast-accelerator-catalog
- Related work: specs/fast-006-fraud-investigation-fully-custom
- Commit strategy: checkpoints
- Required validation/CI: FAST and wizard regression tests
- Pull request handoff: no
- Merge strategy: squash
- Safety: inspect status and diff, stage explicit files, validate before commit, and require approval before commit or push.

## Optional Report Web Resources
- Enabled: no
- Selected Reports: Operational workspace; Team workload; Management KPI
- Visual theme: Power Apps neutral
- Integration: Create HTML web resources and add them to the selected solution.
- Report scoping status: approved-no-reports
- Critical or high-frequency tables: none
- Mapping artifact: report-mappings.md

## Explicit Entity Mapping (Required Before Payloads)

### Standard reused tables (display -> logical)
- None

### Custom tables to create (input -> generated logical)
- Investigation -> fiv_investigation
- Investigator Assignment -> fiv_investigatorassignment
- Evidence -> fiv_evidence
- Evidence Custody Event -> fiv_evidencecustodyevent
- Interview -> fiv_interview
- Fraud Score -> fiv_fraudscore
- Supervisor Approval -> fiv_supervisorapproval
- Report -> fiv_report

### Standard fields reused
- None

### Custom fields to add
- Investigation.fiv_name
- Investigation.fiv_status
- Investigation.fiv_summary
- Evidence.fiv_name
- EvidenceCustodyEvent.fiv_action
- Interview.fiv_interviewdate
- FraudScore.fiv_score
- FraudScore.fiv_auditreference
- SupervisorApproval.fiv_decision
- Report.fiv_name

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

## User Task Plan
- Task definitions: Investigator | triage intake and assign investigator | per intake | fiv_investigation/Active Investigations | owner and priority are recorded; Evidence custodian | record each custody transfer | per transfer | fiv_evidence/Active Evidence | complete chain of custody is traceable; Investigator | document interview | per interview | fiv_interview/Recent Interviews | statement and participants are recorded; Supervisor | review scored investigation | per submission | fiv_investigation/Pending Approval | decision and rationale are recorded; Manager | review investigation reporting | daily | fiv_report/Operational Reports | workload and outcomes are visible
- Ownership and done definitions: triage intake and assign investigator | Investigation supervisor | owner and priority are recorded; record each custody transfer | Evidence custodian | immutable custody event is linked to evidence; document interview | Assigned investigator | interview date, participants, and notes are complete; review scored investigation | Supervisor | approval decision and rationale are complete; review investigation reporting | Program manager | required metrics reconcile to investigation records

## Demo Data Plan
- Enabled: No
- Scope: none
- Tables: none
- Standard reused table strategy: none
- Record counts: none
- Scenarios and lifecycle states: none
- Hero records: none
- Related-record distribution: none
- Create Task activities: no
- Task parent tables: none
- Task scope and source-record limit: none -- 0
- Task ordering: none
- Tasks per selected record: 0
- Creation method: none
- Rerun behavior: none
- Source tag: none
- Privacy constraints: none
- Cleanup/reset instructions: no

## Optional Business Process Flow
- Enabled: no
- Reason to skip: No staged lifecycle was captured during discovery.

## Accelerator Startup Preference
- Preference: evaluate
- Matching requested: True
- Final architecture selected at startup: no
- Deployment authorized at startup: no
- Preference artifact: accelerator/accelerator-preference.json
## Accelerator Architecture Decision
- Feature enabled: yes
- Evaluation status: evaluated
- Analysis ID: sha256:638bf67049dddfb506455c6c5eb9102135fea5bc4f7ca95aa969ae8858b538c1
- Catalog snapshot: sha256:5a59214ec84f70e0bc8f1da052458233ed2eab0f8c7963e6c92b66142e45bd69
- Recommended architecture: hybrid
- User-selected architecture: fully-custom
- Explicit approval: True
- Selected packages: none
- Environment readiness: not-provided
- FAST-dependent execution allowed: False
- Decision artifact: accelerator/accelerator-decision.json
