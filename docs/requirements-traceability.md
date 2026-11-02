# Requirements Traceability and Spec Kit Integration

The Requirements Analyst captures **what and why**; the Solution Architect
defines **how the approved need maps to Dataverse**. Both are planning-only
skills for Copilot and Claude. They augment the existing wizard, not replace
its mode selection, approvals, reporting or execution.

## Authoritative artifacts

All application artifacts belong in the approved `TargetProjectRoot`, under
`specs/<scenario-slug>/`. The scenario's `spec.md`, `plan.md`, `tasks.md`,
`answers.md` and `report-mappings.md` remain the existing Spec Kit contract.
Add `requirements-traceability.md`, `architecture.md`, and `field-catalog.md`
as review aids; they do not replace required files or authorize build scripts.
When demo data is enabled, keep the existing `demo-data-plan.json` contract.
Payload files remain authoritative for executable schema, labels and ordering.

Reuse existing IDs and approved decisions. For retrofit, `spec.md` records
actual current state and scope, while the plan/tasks describe only remaining
work. Preserve completed work and evidence. Never silently migrate scenarios,
rewrite historical evidence, or recreate application scenarios at repo root.
Repository governance (`SPEC.md`, `SYSTEM_MANIFEST.json.md`,
`BINDING_CERTIFICATION.md`) remains separate. Consume the configured SpeckKit
registry references, not a local copy. Ask before loading UI reference context.

## Requirement record

Use stable `REQ-###` IDs (or preserve an existing stable scheme). Never renumber
or recycle deleted IDs. Each requirement records its business outcome,
source/evidence, category, priority, owner, persona/task, measurable success
criterion, dependencies, status and approval. Mark assumptions and conflicting
requirements explicitly. Record out-of-scope items and deferred decisions
rather than quietly omitting them.

Capture user tasks with persona, frequency, entry table/view, expected outcome,
owner and done definition. Derive testable success criteria from these tasks;
do not impose additional acceptance questions on Demo Builder or Advanced
Builder. Preserve the six-question Demo Builder intake and consolidated design
confirmation. Acceptance-run engineering belongs only to explicitly selected
Framework Acceptance.

## Traceability matrix

Use this shape in the scenario's `requirements-traceability.md`:

| Requirement ID | Source / outcome | User task | Success criterion | Design / field / relationship | Component / payload path | Implementation task ID | Verification case / method | Evidence path / actual result | Status / owner / approval |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| REQ-001 | Approved intake: contact a requester | TASK-USER-001: caseworker, daily, request view, contact recorded, service owner, valid address saved | A valid contact email can be saved; invalid format is rejected | FLD-001 in field-catalog.md; String / Email | Planned columns-request.json, exact target path pending architecture | TASK-001 | TEST-001: metadata and form validation | Not executed; no live evidence | draft / service owner / pending |

The example is not a real scenario or approved payload. Use links to exact
scenario sections and payload paths once known. `Not executed` is distinct
from passed, failed, blocked, or not applicable. Every not-applicable mapping
requires a rationale and approval. Never use a planned test as execution proof.

## Review gate and change control

Check both directions before approval:

1. Every in-scope requirement has an owner, measurable criterion, design
   disposition, implementation task and planned verification.
2. Every planned component/task has a requirement or approved technical
   dependency; flag unjustified scope and orphan tasks.
3. Every field follows the [Semantic Field Type Standard](semantic-field-type-standard.md);
   every relationship records cardinality, requiredness, existing/new status,
   cascade behavior and supporting task/surface.
4. Report mappings cover critical/high-frequency tables or explicitly say no
   reports. Data scope is opt-in; standard reused tables and bounded Task
   activities retain their explicit scope decisions.
5. Current-state evidence is distinguished from assumptions. Blocking unknowns,
   conflicts and unsupported runtime capabilities have owners and stop build
   progression.
6. Discovery, architecture intent, scope and aligned `spec.md`, `plan.md`,
   `tasks.md` are approved. Record who approved what and when from real
   evidence, never invented identities or dates.

For a changed requirement, preserve its ID and record the reason, approval and
impact on design, fields, relationships, reports, tasks, tests and evidence.
Reopen affected approvals rather than claiming obsolete evidence still proves
the revised criterion. Implementation completion is recorded only after the
separately approved existing pipeline and actual validation have run.
