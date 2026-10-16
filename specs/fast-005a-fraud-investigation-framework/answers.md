# Discovery Answers

## Contract
- Contract: docs/wizard-contract-v1.md
- Profile: wizard.profile.json
- Wizard mode: framework-acceptance

## Scenario
- Name: FAST 005A Fraud Investigation Framework Acceptance
- Slug: fast-005a-fraud-investigation-framework

## Application Profile
- Profile: standalone-model-driven
- Table Strategy: custom-only
- Form Strategy: create-new-forms
- Entry Point Table: fva_investigation
- Landing View: Active Investigations
- Entry Point Validation: approved
- Landing View Plan: adopt-generated-active
- Power Apps Grid (table-level, all views): yes
- Power Apps Grid Inline Editing: yes
- Review App Mode: create-or-update
- Required App Artifacts: all planned tables, forms, views, assignment and approval workflows, fraud-scoring integration, reports, and acceptance evidence

## Framework Acceptance Controls
- Environment authorized: yes
- Isolated solution name: Fast005AFraudFramework20261015
- Publisher prefix: fva
- Hero record labels: Investigation FRAUD-005A | complete acceptance case
- Rerun evidence: A second run with unchanged inputs produces byte-identical accelerator analysis and decision artifacts
- Retention policy: retain
- Destructive cleanup separately approved: no
- Evidence plan: Capture intake answers, requirement coverage, component deltas, dependency manifest, readiness evidence, all architecture options, approved decision, unchanged rerun hashes, rejected decision change, and explicitly approved decision change

## App Module
- Enabled: yes
- App Name: FAST 005A Fraud Investigation Framework Acceptance Review App
- Unique Name: fva_fast_005a_fraud_investigation_framework_app
- Navigation Group: Investigations

## Required Question Set (11)
1. Type of demo/app: Fraud investigation management acceptance application
2. Platform area: Power Apps
3. Target audience: Fraud investigators, supervisors, evidence custodians, compliance reviewers, and framework maintainers
4. Business problem: Manage investigation intake, investigator assignment, evidence custody, interviews, external fraud-scoring integration, supervisor approval, and operational and management reporting with deterministic acceptance evidence
5. Users: Fraud investigators, supervisors, evidence custodians, compliance reviewers
6. Data entities: Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report
7. Needed artifacts: Intake and assignment forms, active investigation and custody views, interview timeline, external fraud-scoring integration, supervisor approval workflow, operational dashboard, management reports, and acceptance evidence
8. Success definition: A synthetic fraud case proves intake, assignment, custody, interviews, fraud-score auditability, approval, reporting, stable reruns, and an unchanged approved architecture decision
9. Build environment: Authorized GCC development environment https://powerplatformvscodestarter.crm9.dynamics.com
10. Demo data needed: No
11. Solution output type: Unmanaged

## Extension Blocks
- business-process-flow: enabled=no ; primary= ; name=
- table-strategy: custom-only
- solution-identity: solution=new -- Fast005AFraudFramework20261015; prefix=new -- fva
- reporting: no
- source-control: branch=feature/fast-005a-fraud-investigation-framework; commits=checkpoints; pull-request=no
- retrofit: disabled

## Source Control Plan
- Standards: requirements/GithubInstructions_General.md
- Scenario branch: feature/fast-005a-fraud-investigation-framework
- Related work: specs/fast-005a-fraud-investigation-framework
- Commit strategy: checkpoints
- Required validation/CI: FAST and wizard regression tests plus deterministic artifact comparison
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

## User Task Plan
- Task definitions: Investigator | triage intake and assign investigator | per intake | fva_investigation/Active Investigations | owner and priority are recorded; Evidence custodian | record each custody transfer | per transfer | fva_evidence/Active Evidence | complete chain of custody is traceable; Investigator | document interview | per interview | fva_interview/Recent Interviews | statement and participants are recorded; Supervisor | review scored investigation | per submission | fva_investigation/Pending Approval | decision and rationale are recorded; Manager | review investigation reporting | daily | fva_report/Operational Reports | workload and outcomes are visible
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
- Analysis ID: sha256:a37fde2aacd06f2154aefe865e67d141aefd5822cbac5ee90dfdd7c3f6ca6a6c
- Catalog snapshot: sha256:777873ba1d2beedcb9fb5de2fe85d17c0f5bb20c6fafe5ce674d0de654be8348
- Recommended architecture: hybrid
- User-selected architecture: hybrid
- Explicit approval: True
- Selected packages: microsoft-fast:module:core 1.2.1.0 [f813e8500b97db1fd74f938da28f22ba53c1c4593f6374b34e8a0f7d52e895b3]; microsoft-fast:module:investigations 1.2.1.0 [131be1ade134e838e3d824777b6655331a7149eaf80ae14bc26583a4f1bb8391]
- Environment readiness: action-required
- FAST-dependent execution allowed: False
- Decision artifact: accelerator/accelerator-decision.json
