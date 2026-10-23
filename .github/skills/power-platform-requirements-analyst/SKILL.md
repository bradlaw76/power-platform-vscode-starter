---
name: power-platform-requirements-analyst
description: 'Use when discovering, clarifying, or retrofitting Power Platform business requirements, user tasks, acceptance criteria, requirements traceability, and scenario Spec Kit plans. Planning only; no build or deployment.'
---

<!--
=============================================================================
COMPONENT:    Power Platform Requirements Analyst Skill
FILE:         .github/skills/power-platform-requirements-analyst/SKILL.md
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-23
ENVIRONMENT:  Copilot | Claude | Spec Kit planning
OVERVIEW:     Facilitate requirements and maintain end-to-end traceability.
ARCHITECTURE: Approved application scenario artifacts; no runtime mutation.
TEST CASES:   scripts/ci/test-planning-skills.ps1 checks parity and boundaries.
NON-NEGOTIABLES: Preserve wizard modes, source isolation and approval gates.
=============================================================================
-->

# Power Platform Requirements Analyst

## Scope and preflight

Discover and document requirements; do not implement, authenticate, deploy, run
build scripts, install a runtime, change Dataverse, commit, push, or merge.
Do not begin Skill 3 or any implementation skill without separate approval.
Skill availability is not runtime installation.

Before application writes, resolve verified read-only `FrameworkRoot` and a
separate writable `TargetProjectRoot`. Follow `docs/wizard-contract-v1.md` for
source protection, repository identity, scenario isolation and planning gates.
For explicitly authorized framework work, Framework Administration Mode means
Framework Maintenance Mode: apply `docs/framework-maintenance-preflight.md`
with the approved repository, exact maintenance branch and HEAD SHA. Modification,
commit, push and merge require separate approvals.

Read `README.md`, `docs/onboarding.md` (authoritative bootstrap sequence),
`docs/build-log.md`, the wizard and VS Code/Copilot model-driven requirements
guides under `requirements/`, and existing scenario plans before drafting.
Missing/incompatible guidance or runtime requires a reviewed compatibility
plan, not silent installation or overwritten files. Never load SpeckKit UI
reference context without asking.

## Facilitation

Reuse existing answers and approvals; do not repeat completed intake. Ask one
unresolved discovery question at a time and explain unfamiliar terms.
Dataverse is the data platform; a solution packages components; Spec Kit is the
specification, plan and task workflow that must precede a build.

- Default `demo-builder`: ask the existing six business questions (idea/outcome,
  primary user/task, data, experience/lifecycle, success/sample data,
  environment/output), infer technical design, then present one consolidated
  recommendation for confirmation.
- Explicit `advanced-builder`: retain detailed discovery and architecture
  controls, including mapping, relationships, reports, forms, entry point,
  landing view, review app, solution identity and source control.
- Explicit `framework-acceptance`: retain environment authorization,
  timestamped isolation, source tags/hero labels, rerun evidence, retention,
  separately approved cleanup and evidence planning.
- Do not ask acceptance, disposable-environment, retention, rerun-proof,
  source-tag, or cleanup questions in Demo Builder or Advanced Builder.
  Derive testable success criteria from the business answers; do not add an
  acceptance questionnaire or silently switch modes.

For a partial implementation, first establish existing tables/entities,
forms/views/flows and solution structure. Distinguish verified metadata,
operator-provided inventory and assumptions. Preserve completed work and
current-state evidence; do not present a retrofit as greenfield.

## Requirements and traceability

Follow `docs/requirements-traceability.md`:

1. Capture business outcomes, in/out-of-scope boundaries, stakeholders and top
   user tasks. Each task includes persona, frequency, entry table/view,
   expected outcome, owner and done definition.
2. Assign stable `REQ-###` IDs without renumbering existing requirements.
   Record source/evidence, functional or non-functional category, priority,
   owner, measurable success criterion, dependencies and approval status.
   Capture security/privacy, accessibility, performance, integration and
   environment constraints only as relevant; unknowns stay open.
3. Link each requirement to its user task, architecture decision or field,
   planned component/payload, implementation task and verification case.
   Distinguish planned verification from executed evidence. Check both
   directions for missing requirements and unjustified scope.
4. Preserve relationship cardinality, requiredness, existing/new status,
   cascade behavior and supporting task/surface. Preserve explicit
   report/no-report scope and `report-mappings.md`; reports need table,
   placement, fields, supported decision, owner and validation.
5. Demo data is opt-in. Never seed standard reused tables implicitly.
   Task activities require eligible parent tables, latest/all/selected scope,
   bounded source-record count, ordering field and tasks per selected record.
   Capture these within the existing mode, not a new framework questionnaire.
6. Resolve conflicts and assumptions openly. Assign blocker owners and
   decisions needed; do not invent answers, lower success thresholds, or mark
   unverified work complete. Record scope changes and their impact on design,
   tasks, tests and evidence with approval.

## Spec Kit integration and handoff

After approval of the target path and planning writes, create or update only
the application's `specs/<scenario-slug>/`:

- `answers.md`: mode, discovery, provenance and confirmations.
- `spec.md`: approved scope, current state, stable requirements and testable
  success criteria; in retrofit, faithfully reflect what already exists.
- `plan.md`: implementation approach, architecture intent, risks, source
  control and validation strategy; remaining work only for retrofit.
- `tasks.md`: dependency-ordered tasks linked to requirements and verification;
  existing completed tasks retain their evidence and status.
- `requirements-traceability.md`: requirement-to-design-to-task-to-test matrix
  with planned versus executed evidence and approval state.
- `report-mappings.md` always, and `demo-data-plan.json` only when enabled,
  following the existing wizard schemas rather than inventing payload fields.

Scenario plans are authoritative; do not duplicate them at the framework root
or replace them with repository governance (`SPEC.md`, `SYSTEM_MANIFEST.json.md`,
`BINDING_CERTIFICATION.md`). Follow the repo-local SpeckKit registry references
without duplicating that registry or pulling unrelated UI context.

Use `dataverse-solution-architect` for unresolved design and the Semantic Field
Type Standard in `docs/semantic-field-type-standard.md`. Preserve field and
relationship decisions and link them back to stable requirement IDs. In
Demo Builder, include inferred design in the same consolidated recommendation;
do not restart technical discovery.

Return a concise requirements summary, artifact paths, traceability gaps,
approval state and blockers. Block build recommendations until discovery,
architecture intent, reporting/data scope and aligned `spec.md`, `plan.md`,
`tasks.md` are approved. Then hand back to the existing wizard and its shared
bootstrap pipeline; planning approval never authorizes execution, publish,
export, commit, push, merge or deployment.
