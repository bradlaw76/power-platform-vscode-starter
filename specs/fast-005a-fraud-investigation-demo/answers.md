# Discovery Answers

## Contract
- Contract: docs/wizard-contract-v1.md
- Profile: wizard.profile.json
- Wizard mode: demo-builder

## Scenario
- Name: FAST 005A Fraud Investigation Demo
- Slug: fast-005a-fraud-investigation-demo

## Application Profile
- Profile: standalone-model-driven
- Table Strategy: custom-only
- Form Strategy: create-new-forms
- Entry Point Table: fasta_investigation
- Landing View: Active Investigations
- Entry Point Validation: approved
- Landing View Plan: adopt-generated-active
- Power Apps Grid (table-level, all views): yes
- Power Apps Grid Inline Editing: yes
- Review App Mode: create-or-update
- Required App Artifacts: all run-created tables, forms, views, processes, and approved reports

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
- App Name: FAST 005A Fraud Investigation Demo Review App
- Unique Name: fasta_fast_005a_fraud_investigation_demo_app
- Navigation Group: Operations

## Required Question Set (11)
1. Type of demo/app: FAST 005A Fraud Investigation Demo
2. Platform area: Power Apps model-driven app on Dataverse
3. Target audience: Fraud investigator | triage intake, assign investigators, and manage cases through supervisor approval
4. Business problem: FAST 005A Fraud Investigation Demo
5. Users: Fraud investigator | triage intake, assign investigators, and manage cases through supervisor approval
6. Data entities: Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report
7. Needed artifacts: Capture intake, assign an investigator, maintain evidence chain of custody, document interviews, call an external fraud-scoring service, route the case for supervisor approval, and present operational and management reporting
8. Success definition: A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting
9. Build environment: https://powerplatformvscodestarter.crm9.dynamics.com; unmanaged solution
10. Demo data needed: Yes
11. Solution output type: Unmanaged

## Extension Blocks
- business-process-flow: enabled=no ; primary= ; name=
- table-strategy: custom-only
- solution-identity: solution=new -- Fast005AFraudInvestigationDemo; prefix=new -- fasta
- reporting: no
- source-control: branch=feature/fast-005a-fraud-investigation-demo; commits=checkpoints; pull-request=yes
- retrofit: disabled

## Source Control Plan
- Standards: requirements/GithubInstructions_General.md
- Scenario branch: feature/fast-005a-fraud-investigation-demo
- Related work: specs/fast-005a-fraud-investigation-demo
- Commit strategy: checkpoints
- Required validation/CI: applicable repo CI tests
- Pull request handoff: yes
- Merge strategy: team-default
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

## User Task Plan
- Task definitions: Fraud investigator | triage intake, assign investigators, and manage cases through supervisor approval | Capture intake, assign an investigator, maintain evidence chain of custody, document interviews, call an external fraud-scoring service, route the case for supervisor approval, and present operational and management reporting | primary workflow | fasta_investigation/Active Investigations | A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting
- Ownership and done definitions: Capture intake, assign an investigator, maintain evidence chain of custody, document interviews, call an external fraud-scoring service, route the case for supervisor approval, and present operational and management reporting | app owner | A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting

## Demo Data Plan
- Enabled: Yes
- Scope: all-created
- Tables: Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report
- Standard reused table strategy: none
- Record counts: small synthetic set; counts to be confirmed during planning
- Scenarios and lifecycle states: A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting
- Hero records: none
- Related-record distribution: none
- Create Task activities: no
- Task parent tables: none
- Task scope and source-record limit: none -- 0
- Task ordering: none
- Tasks per selected record: 0
- Creation method: scripted
- Rerun behavior: upsert
- Source tag: fast-005a-fraud-investigation-demo
- Privacy constraints: synthetic data only; no personal or production data
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
- Analysis ID: sha256:f35e1312ea83c8815689803b5768d0567c74e471ff848e6e50d913fae937dc10
- Catalog snapshot: sha256:777873ba1d2beedcb9fb5de2fe85d17c0f5bb20c6fafe5ce674d0de654be8348
- Recommended architecture: hybrid
- User-selected architecture: hybrid
- Explicit approval: True
- Selected packages: microsoft-fast:module:core 1.2.1.0 [f813e8500b97db1fd74f938da28f22ba53c1c4593f6374b34e8a0f7d52e895b3]; microsoft-fast:module:investigations 1.2.1.0 [131be1ade134e838e3d824777b6655331a7149eaf80ae14bc26583a4f1bb8391]
- Environment readiness: action-required
- FAST-dependent execution allowed: False
- Decision artifact: accelerator/accelerator-decision.json
