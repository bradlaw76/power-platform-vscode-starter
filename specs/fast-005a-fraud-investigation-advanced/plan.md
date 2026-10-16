# plan.md

## Build Approach
- Wizard mode: advanced-builder
- Application profile: standalone-model-driven
- Platform area: Power Apps
- Environment: Authorized GCC development environment https://powerplatformvscodestarter.crm9.dynamics.com
- Solution type: Unmanaged
- Solution unique name: Fast005AFraudAdvanced (new)
- Publisher prefix: fiv (new)

## Accelerator Preference Plan
- Preserve the preliminary preference prefer-fast in accelerator/accelerator-preference.json.
- Run matching only after requirements normalization and only when matching was requested.
- Keep the final architecture decision separate from this preference.
## Accelerator Architecture Plan
- Reproduce from accelerator/accelerator-evaluation.json and accelerator/accelerator-decision.json.
- Preserve selected architecture $(@{schemaVersion=1.0; decisionId=sha256:b2168d8eb950d6da6bd9c4dbcfadcd67219f23e72c4cd12c72e4192c1a5df124; scenarioSlug=fast-005a-fraud-investigation-advanced; wizardMode=advanced-builder; evaluationStatus=evaluated; analysisId=sha256:dd261832bb9f2a9ab2192fb99c1195cedcfd9f7dc3436daa8eb3902eb5e159f6; catalogSnapshotId=sha256:777873ba1d2beedcb9fb5de2fe85d17c0f5bb20c6fafe5ce674d0de654be8348; recommendedOption=hybrid; selectedOption=hybrid; explicitApproval=True; rationale=Prefer verified reuse but retain custom scoring, approval, and reporting work.; selectedPackages=System.Object[]; environmentReadiness=; fastDependentExecutionAllowed=False; fullyCustomExecutionAllowed=False; recordedAtUtc=2026-10-15T21:00:00.0000000Z}.selectedOption) unless an explicitly approved decision change is recorded.
- Revalidate environment readiness before any future FAST-dependent execution.
- Keep fully custom work independent from FAST package prerequisites.
- Do not import packages or mutate Dataverse during planning.

## Model-Driven App Plan
- Review app mode: create-or-update
- App name: FAST 005A Fraud Investigation Advanced Review App
- App unique name: fiv_fast_005a_fraud_investigation_advanced_app
- Navigation group: Investigations
- Entry-point table: fiv_investigation
- Default landing view: Active Investigations
- Entry-point validation: approved
- Landing-view action: adopt-generated-active
- Form strategy: create-new-forms
- Power Apps grid decision: enabled=no; table-level scope=all-views; inline-editing=no
- Grid implementation: generate grid-controls.json, complete the classic solution explorer handoff, then verify exported metadata at stage 61 before app assembly.
- Required artifacts: all planned tables, forms, views, assignment and approval workflows, fraud-scoring integration, and reports

## Proposed Workstreams
1. Discovery review and approval
2. Source-control preflight and scenario branch confirmation
3. Dataverse schema design
4. Forms/views/pages/app experience design
5. Flow/copilot automation design
6. Demo data planning
7. Solution export/unpack and Git checkpoint workflow
8. Optional report web resource design and generation
9. Validation, pull request preparation, and handoff

## User Task Implementation Plan
- Task definitions: Investigator | triage intake and assign investigator | per intake | fiv_investigation/Active Investigations | owner and priority are recorded; Evidence custodian | record each custody transfer | per transfer | fiv_evidence/Active Evidence | complete chain of custody is traceable; Investigator | document interview | per interview | fiv_interview/Recent Interviews | statement and participants are recorded; Supervisor | review scored investigation | per submission | fiv_investigation/Pending Approval | decision and rationale are recorded; Manager | review investigation reporting | daily | fiv_report/Operational Reports | workload and outcomes are visible
- Owners and done definitions: triage intake and assign investigator | Investigation supervisor | owner and priority are recorded; record each custody transfer | Evidence custodian | immutable custody event is linked to evidence; document interview | Assigned investigator | interview date, participants, and notes are complete; review scored investigation | Supervisor | approval decision and rationale are complete; review investigation reporting | Program manager | required metrics reconcile to investigation records

## Report Implementation Plan
- Scoping status: approved-no-reports
- Critical or high-frequency tables: none
- Mapping artifact: report-mappings.md
- Gate: validate every mapped table, field, and target placement before creating report payloads or HTML sources.

## Demo Data Implementation Plan
- Scope: none
- Target tables: none
- Standard reused table strategy: none
- Counts: none
- Scenarios and states: none
- Hero records: none
- Parent/child distribution: none
- Create Task activities: no
- Task parent tables: none
- Task scope and source-record limit: none -- 0
- Task ordering and count: none -- 0 per selected record
- Method: none
- Rerun behavior: none
- Source tag: none
- Privacy constraints: none
- Cleanup/reset instructions: no
- Gate: data creation cannot begin until table counts, hero records, relationship distribution, bounded Task activity scope, and synthetic-data constraints are approved.

## Source Control Plan
- Standards: requirements/GithubInstructions_General.md
- Scenario branch: feature/fast-005a-fraud-investigation-advanced
- Related work: specs/fast-005a-fraud-investigation-advanced
- Commit strategy: checkpoints
- Required validation/CI: FAST and wizard regression tests
- Pull request handoff: no
- Merge strategy: squash
- Keep remote operations human-approved and verify the remote commit after push.

## Risks to Resolve
- Confirm environment availability and permissions.
- Confirm entity scope and artifact count.
- Confirm whether demo data must be scripted or manual.
- Confirm which entities are standard (out-of-box) and which are custom (to be created).

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

### Payload Readiness Rule
- Payload generation is blocked until this mapping is complete and approved.

## Optional Business Process Flow Plan
- Enabled: no
- Build order dependency: run 55-build-business-process-flows.ps1 after 50-add-to-solution.ps1 and before 60-build-forms-views.ps1.
- Process definition payload: payloads/scenarios/fast-005a-fraud-investigation-advanced/process-fast-005a-fraud-investigation-advanced.json
- Primary entity:
- Target Main form:
- Cross-table progression: no

### Planned stages
- None

### BPF failure rules
- Fail if the primary entity is ambiguous or missing.
- Fail if any required stage field is missing from payload or explicit field mapping artifacts.
- Fail if any cross-table step is unsupported by a relationship payload.
- Skip BPF if the scenario does not define a real business progression.

## Validation Plan
- Verify artifacts in Maker portal.
- Verify solution export/unpack succeeds.
- Verify git changes are reviewable.
- Verify import into target environment succeeds.
- If reports are enabled, verify three HTML web resources are created and visible in solution.
- If BPF is enabled, verify the BPF build report matches the created Dataverse process metadata and the process is added only to the selected solution.
