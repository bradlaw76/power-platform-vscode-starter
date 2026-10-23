---
name: dataverse-solution-architect
description: 'Use when planning or reviewing Dataverse solution architecture, standard versus custom tables, semantic field types, relationships, forms, views, or solution boundaries. Planning only; no deployment.'
---

<!--
=============================================================================
COMPONENT:    Dataverse Solution Architect Skill
FILE:         .claude/skills/dataverse-solution-architect/SKILL.md
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-23
ENVIRONMENT:  Copilot | Claude | Dataverse planning
OVERVIEW:     Translate approved business requirements into reviewable design.
ARCHITECTURE: Read verified framework guidance; write only approved target specs.
TEST CASES:   scripts/ci/test-planning-skills.ps1 checks parity and boundaries.
NON-NEGOTIABLES: Planning only; preserve source protection and wizard modes.
=============================================================================
-->

# Dataverse Solution Architect

## Scope and preflight

Design or review architecture; do not implement, authenticate, deploy, run build
scripts, change Dataverse metadata, install a runtime, commit, push, or merge.
Do not begin Skill 3 or any implementation skill without separate approval.
Skill availability is not runtime installation.

Resolve the verified read-only `FrameworkRoot` and separate writable
`TargetProjectRoot` before any application write. Apply
`docs/wizard-contract-v1.md`, including root/remote/source protection and
scenario isolation. Framework Administration Mode means Framework Maintenance
Mode, not an application wizard mode; framework edits require the exact
repository/branch/SHA preflight in `docs/framework-maintenance-preflight.md`
and distinct modification, commit, push, and merge approvals.

Read the framework's `docs/onboarding.md` (authoritative bootstrap sequence),
`README.md`, `docs/build-log.md`, both model-driven wizard/build requirements
guides in `requirements/`, and `docs/semantic-field-type-standard.md`. Inspect
compatible schemas and the actual runtime before claiming support. If required
guidance is absent or incompatible, stop with a reviewed compatibility plan;
never copy or overwrite framework/runtime/application files implicitly.

## Intake and mode preservation

Reuse approved discovery and `specs/<scenario-slug>/` artifacts; never restart
intake just because this skill was selected. Ask only one unresolved question
at a time, explaining Dataverse (the data platform), solution (component
package), and standard/out-of-box (OOB) versus custom when first used.

- `demo-builder` remains the default: six business questions plus one
  consolidated technical recommendation confirmation. Infer architecture from
  the answers; do not add a technical questionnaire.
- `advanced-builder` is explicit: capture technical controls directly.
- `framework-acceptance` is explicit: retain environment authorization,
  isolated naming, rerun evidence, retention, and separately approved cleanup.
- Never ask acceptance, disposable-environment, retention, rerun-proof,
  source-tag, or cleanup questions in Demo Builder or Advanced Builder.

For retrofit work, inventory current tables, columns, forms, views, flows,
relationships, solution identity and publisher first. Label evidence as
verified, operator-provided, or unverified. Do not assume a greenfield build,
change existing types, or invent live metadata from names.

## Architecture decisions

1. Link the approved business outcomes, user tasks, and stable requirement IDs
   from `power-platform-requirements-analyst` or existing specs. Missing
   requirements return to analysis; do not invent business approval.
2. Select the supported application profile and OOB-only/custom-only/hybrid
   strategy. Prefer reuse when fit is demonstrated; document gaps and rationale.
   Capture solution unique name, publisher/prefix, ownership/security model,
   dependencies, environment constraints, and ALM boundaries.
3. Apply the **Semantic Field Type Standard** in
   `docs/semantic-field-type-standard.md` to every field. Produce a field catalog
   with requirement IDs, semantic intent, native type/format/date-time behavior,
   requiredness/default, limits/precision/options/targets, privacy, rationale,
   payload mapping, and verification. Never default emails, phones, URLs,
   financial amounts, dates, categories, or record references to generic text.
   Unsupported runtime mappings are blocked decisions, not text fallbacks.
4. For every relationship, record referencing/referenced tables, cardinality,
   requiredness, existing/new status, cascade behavior, and the supporting user
   task or app surface. Record lookup targets and deletion/assignment effects.
5. Confirm form strategy (update selected existing forms or create new business
   forms), primary entry-point logical table, landing view, review app and
   sitemap. Preserve generated Information forms and the existing view
   dispositions: `adopt-generated-active`, `create-custom`, or
   `explicit-decision-required`. Planning never proves adoption provenance;
   step 60 must still prove it before mutation.
6. Preserve explicit report/no-report decisions in `report-mappings.md`.
   Reports require critical/high-frequency table coverage, supported decision,
   placement, required fields, owner and validation. Route focused existing-app
   reporting to `dataverse-report-wizard`; do not replace its simulate/approval
   gates. Demo data remains opt-in and standard reused tables are never seeded
   implicitly. Task activities require eligible parents, latest/all/selected
   scope, bounded source count, ordering field, and tasks per selected record.
7. Record risks, assumptions, unresolved decisions, capability gaps and
   alternatives with owners. Present one consolidated architecture
   recommendation for confirmation at the selected mode's depth.

## Outputs and approval gate

Only after the target path and planning writes are approved, update the
application's `specs/<scenario-slug>/spec.md`, `plan.md`, `tasks.md`, and
`answers.md` in place. Keep `spec.md` faithful to current state and approved
scope; `plan.md` and `tasks.md` describe remaining work only for retrofit.
Add `architecture.md` and `field-catalog.md` in that same scenario folder, and
update `requirements-traceability.md` with requirement-to-design-to-task-to-test
links. Record architecture approval, open decisions and evidence explicitly.
Never recreate scenario plans at the framework root or overwrite other scenarios.

Payload files remain the source of truth for executable schema, labels, and
field ordering. This skill records mappings, not deployable payload changes.
Before handing back to the existing wizard, require aligned and approved
`spec.md`, `plan.md`, `tasks.md`, architecture intent, complete field/relationship
decisions, report/data scope and traceability. Unresolved blocking decisions
must stop progression, not be represented as completed work.

Return a concise design summary, proposed/modified planning paths, approval
state, blockers, and next safe planning action. No solution inventory, sync,
publish, validation, export, or deployment is claimed to have run. Subsequent
approved execution uses the same existing bootstrap pipeline, inventory/sync,
membership gates, scoped publish, usability checks, reporting and evidence.
