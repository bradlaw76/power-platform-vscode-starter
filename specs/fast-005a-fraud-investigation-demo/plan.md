# plan.md

## Build Approach
- Wizard mode: demo-builder
- Application profile: standalone-model-driven
- Platform area: Power Apps model-driven app on Dataverse
- Environment: https://powerplatformvscodestarter.crm9.dynamics.com; unmanaged solution
- Solution type: Unmanaged
- Solution unique name: Fast005AFraudInvestigationDemo (new)
- Publisher prefix: fasta (new)

## Accelerator Preference Plan
- Preserve the preliminary preference evaluate in accelerator/accelerator-preference.json.
- Run matching only after requirements normalization and only when matching was requested.
- Keep the final architecture decision separate from this preference.
## Accelerator Architecture Plan
- Reproduce from accelerator/accelerator-evaluation.json and accelerator/accelerator-decision.json.
- Preserve selected architecture $(@{schemaVersion=1.0; decisionId=sha256:2549f2be7d14a2fe86d118db485b80add4179378f7a7cf177e17b6e8adfdcbee; scenarioSlug=fast-005a-fraud-investigation-demo; wizardMode=demo-builder; evaluationStatus=evaluated; analysisId=sha256:f35e1312ea83c8815689803b5768d0567c74e471ff848e6e50d913fae937dc10; catalogSnapshotId=sha256:777873ba1d2beedcb9fb5de2fe85d17c0f5bb20c6fafe5ce674d0de654be8348; recommendedOption=hybrid; selectedOption=hybrid; explicitApproval=True; rationale=Reuse verified investigation foundations while extending external scoring, approvals, and reporting.; selectedPackages=System.Object[]; environmentReadiness=; fastDependentExecutionAllowed=False; fullyCustomExecutionAllowed=False; recordedAtUtc=2026-10-15T21:00:00.0000000Z}.selectedOption) unless an explicitly approved decision change is recorded.
- Revalidate environment readiness before any future FAST-dependent execution.
- Keep fully custom work independent from FAST package prerequisites.
- Do not import packages or mutate Dataverse during planning.

## Model-Driven App Plan
- Review app mode: create-or-update
- App name: FAST 005A Fraud Investigation Demo Review App
- App unique name: fasta_fast_005a_fraud_investigation_demo_app
- Navigation group: Operations
- Entry-point table: fasta_investigation
- Default landing view: Active Investigations
- Entry-point validation: approved
- Landing-view action: adopt-generated-active
- Form strategy: create-new-forms
- Power Apps grid decision: enabled=yes; table-level scope=all-views; inline-editing=yes
- Grid implementation: generate grid-controls.json, complete the classic solution explorer handoff, then verify exported metadata at stage 61 before app assembly.
- Required artifacts: all run-created tables, forms, views, processes, and approved reports

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
- Task definitions: Fraud investigator | triage intake, assign investigators, and manage cases through supervisor approval | Capture intake, assign an investigator, maintain evidence chain of custody, document interviews, call an external fraud-scoring service, route the case for supervisor approval, and present operational and management reporting | primary workflow | fasta_investigation/Active Investigations | A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting
- Owners and done definitions: Capture intake, assign an investigator, maintain evidence chain of custody, document interviews, call an external fraud-scoring service, route the case for supervisor approval, and present operational and management reporting | app owner | A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting

## Report Implementation Plan
- Scoping status: approved-no-reports
- Critical or high-frequency tables: none
- Mapping artifact: report-mappings.md
- Gate: validate every mapped table, field, and target placement before creating report payloads or HTML sources.

## Demo Data Implementation Plan
- Scope: all-created
- Target tables: Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report
- Standard reused table strategy: none
- Counts: small synthetic set; counts to be confirmed during planning
- Scenarios and states: A complete synthetic fraud case proves traceable custody, interview history, fraud-score audit reference, supervisor approval, and accurate reporting
- Hero records: none
- Parent/child distribution: none
- Create Task activities: no
- Task parent tables: none
- Task scope and source-record limit: none -- 0
- Task ordering and count: none -- 0 per selected record
- Method: scripted
- Rerun behavior: upsert
- Source tag: fast-005a-fraud-investigation-demo
- Privacy constraints: synthetic data only; no personal or production data
- Cleanup/reset instructions: no
- Gate: data creation cannot begin until table counts, hero records, relationship distribution, bounded Task activity scope, and synthetic-data constraints are approved.

## Source Control Plan
- Standards: requirements/GithubInstructions_General.md
- Scenario branch: feature/fast-005a-fraud-investigation-demo
- Related work: specs/fast-005a-fraud-investigation-demo
- Commit strategy: checkpoints
- Required validation/CI: applicable repo CI tests
- Pull request handoff: yes
- Merge strategy: team-default
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

### Payload Readiness Rule
- Payload generation is blocked until this mapping is complete and approved.

## Optional Business Process Flow Plan
- Enabled: no
- Build order dependency: run 55-build-business-process-flows.ps1 after 50-add-to-solution.ps1 and before 60-build-forms-views.ps1.
- Process definition payload: payloads/scenarios/fast-005a-fraud-investigation-demo/process-fast-005a-fraud-investigation-demo.json
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
