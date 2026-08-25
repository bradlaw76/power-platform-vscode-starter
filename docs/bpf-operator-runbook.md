# Business Process Flow Operator Runbook

Use the BPF feature only when the scenario has a real staged lifecycle such as intake -> review -> decision -> escalation or closure. If the scenario is only CRUD-oriented, leave BPF disabled and let script `55-build-business-process-flows.ps1` skip it.

These reliability rules are mandatory quality gates for every designer-authored BPF validated by the wizard.

## When to enable BPF

- Enable BPF when the business process has named stages with a clear order.
- Enable BPF only when the process root entity is unambiguous.
- Enable BPF only when every stage can name the fields that must be present before users advance.
- Enable BPF only when any cross-table stage is backed by an explicit relationship payload.

## Required planning inputs

- Discovery answers from `05-start-wizard.ps1` with the optional business-process-flow block completed.
- `spec.md`, `plan.md`, and `tasks.md` must all reflect the same process root and stage progression.
- A `process-*.json` payload must exist under `payloads/scenarios/<scenario-slug>/`.
- Stage names and sequence must be explicit.
- Branch predicates must be explicit, including expected Yes and No paths.
- Human decision checkpoints must be explicit.
- Completion behavior must be explicit, including what Finish means for users and data state.
- If branch logic is ambiguous, stop and clarify before implementation.
- The process payload must include:
  - `Enabled`
  - `BusinessProcessFlowName`
  - `PrimaryProcessEntity`
  - `FailIfBpfDefinitionIncomplete`
  - `PreferUpdateExistingBpf`
  - `FormIntegration.TargetFormName`
  - `StageDefinitions[]` with `Order`, `StageName`, `EntityLogicalName`, `RequiredFields`, `EntryCriteria`, `ExitCriteria`, and `RelationshipLogicalName` when cross-table progression is used

## Reliability guardrails (must follow)

- Do not declare success because workflow state is Active only.
- Do not declare success because workflow is present in solution only.
- Do not leave cloned template fields or labels in production BPF steps.
- Do not fabricate or patch `clientdata`, `uidata`, or `xaml` workflow definitions through the wizard.
- Do not bind BPF steps to fields that are missing from primary-table metadata.
- Do not rely on brittle UI automation as the only implementation path.

## Two-phase build model (required)

1. Create and activate a base BPF in the designer.
2. Run deterministic validation, activation, solution membership, and app-linkage checks.

If designer authoring is unavailable or unstable, stop and preserve the handoff. Do not switch to unsupported workflow-definition payload construction.

## Deterministic validator requirements

Validator status must be PASS before completion can be declared.

Validate at minimum:

- Active state.
- Solution membership.
- Model-driven app linkage.
- Stage count threshold.
- Condition count threshold.
- Step count sanity.
- Field existence in Dataverse metadata before applying step bindings.

Operator requirements:

- Keep step-to-field mapping deterministic and replayable from plan artifacts.
- Apply field bindings and label text in the Power Apps designer.
- Publish the designer-authored process before rerunning script `55`.
- Verify app linkage for workflow component type `29`.

Threshold guidance:

- Record thresholds directly in the BPF build report for each run.
- If a threshold decision changes (for example 6 vs 7 stages), document the reason in build-log evidence.

## Build order dependency

Run the bootstrap scripts in this order:

```powershell
pwsh ./scripts/bootstrap/20-build-tables.ps1
pwsh ./scripts/bootstrap/30-build-columns.ps1
pwsh ./scripts/bootstrap/40-build-relationships.ps1
pwsh ./scripts/bootstrap/50-add-to-solution.ps1
pwsh ./scripts/bootstrap/55-build-business-process-flows.ps1 -ScenarioSlug <scenario-slug>
pwsh ./scripts/bootstrap/60-build-forms-views.ps1
```

Why script `55` sits here:

- Tables, columns, and relationships must already exist so BPF validation can bind only to real repo-backed metadata.
- The process is added to the selected solution inside script `55` after validation passes.
- Script `60` follows immediately so the relevant Main form exists or is refreshed for the intended user experience.

## Failure modes and remediation

- Missing primary entity: fix `PrimaryProcessEntity` in `process-*.json` and align it with the explicit table mapping in `spec.md` and `plan.md`.
- Missing stage field mappings: add the field to `columns-*.json` for custom fields or to the standard field mapping section in planning artifacts for standard fields.
- Missing cross-table relationship: add or correct the `relationships-*.json` payload, then rerun scripts `40`, `50`, and `55`.
- Ambiguous or CRUD-only scenario: disable BPF in discovery or delete the `process-*.json` draft so script `55` skips cleanly.
- Expected BPF is missing: open the generated designer handoff, create the category-4 process in Power Apps with the exact expected unique name, add it to the target solution, publish, and rerun script `55`.
- Existing process has the wrong category or unique name: correct or replace it through the supported designer/solution path; the script will not rewrite its definition.
- Dataverse customization lock or contention: retry with exponential backoff instead of hard-failing the run.

## Completion criteria (must all pass)

- Validator status is PASS with documented thresholds.
- BPF is Active.
- BPF is present in the intended solution.
- BPF is linked to the intended model-driven app.
- Stage, condition, and step summary is recorded in build-log evidence.
- Threshold decisions are explicitly documented.
- Residual risks and follow-up actions are captured.

## Required output per BPF run

- Final stage map with field bindings by stage.
- Final branch predicate summary.
- Validation results with thresholds used.
- App linkage evidence.
- Notes on retries, lock handling, and automatic remediation performed.

## Output artifacts

- Build report: `specs/<scenario-slug>/reports/business-process-flow-report.json`
- Designer handoff: `specs/<scenario-slug>/reports/business-process-flow-designer-handoff.md`
- Process payload input: `payloads/scenarios/<scenario-slug>/process-*.json`
- Build-log evidence: `docs/build-log.md`

The report records the process name, target entity, stages, validation checks, and Dataverse add-to-solution result so reruns are reviewable.
