---
name: power-platform-demo-data-designer
description: 'Use to design optional, synthetic, relationship-aware and rerunnable Power Platform demo data plans for approved scenarios; no automatic generation, import, seeding or deletion.'
---

<!--
COMPONENT: Power Platform Demo Data Designer Skill
VERSION: 1.0.0
ENVIRONMENT: GitHub Copilot | Claude | Dataverse planning
OVERVIEW: Plan deterministic synthetic data consistent with scenario payload contracts.
NON-NEGOTIABLES: Opt-in and explicit approval for every data write/cleanup.
-->

# Power Platform Demo Data Designer (Skill 4)

## Activation and boundaries

Activate only when demo data was affirmatively requested or an existing approved demo-data plan needs review. `demo-builder` retains six business questions and one consolidated technical recommendation; `advanced-builder` adds explicit controls; `framework-acceptance` alone adds retention, source tags, rerun evidence and separately approved destructive cleanup. Never silently enable demo data or expand the questionnaire.

This is a **planning-only** skill: no authentication, data generation into live environments, imports, seeding, deletes, solution changes, script execution, commits, pushes or merges. A dataset preview is not proof of a successful import. The existing `66-seed-synthetic-data.ps1`, `data-*.json` schema and approval gate are authoritative, not replaced by this skill. Skill availability is not runtime installation.

Follow `docs/wizard-contract-v1.md`, `docs/onboarding.md`, `docs/semantic-field-type-standard.md`, `docs/requirements-traceability.md`, and the existing payload schemas. Use verified read-only `FrameworkRoot` and separate approved `TargetProjectRoot`; Framework Administration Mode requires `docs/framework-maintenance-preflight.md` and separate modification, commit, push and merge approvals. Do not use an application run to modify framework source.

## Inputs and plan

1. Reuse approved `specs/<scenario-slug>/answers.md`, `spec.md`, `plan.md`, `tasks.md`, `architecture.md`, `field-catalog.md`, `requirements-traceability.md` and `demo-data-plan.json` if enabled. Do not recreate the scenario or invent approval.
2. Confirm selected solution, environment purpose, table scope, schema/provenance, fields, allowed choices, relationship mapping, volume per table, required states and hero records. Show the resolved table list for approval; default scope, if supported, may be scenario-created custom tables only. Reused standard/OOB tables must explicitly choose `create`, `reuse-existing`, or `both` on a per-table basis; **never seed them implicitly**.
3. Use only **synthetic** names, identifiers, dates and narratives. Do not copy production PII, secrets, credentials, access tokens, customer records or actual protected case data. For federal scenarios, use obviously fictional data, not real benefit/account identifiers; document realism without asserting regulatory clearance.
4. For each column, map business meaning to native Dataverse type and format (Email/Phone/Url, Memo, Boolean, Choice/multi-choice option values, Decimal/Integer/Double/Money with currency/precision, DateOnly/UserLocal/TimeZoneIndependent, File/Image and lookups). Validate requiredness, lengths, limits, uniqueness and disabled/unsupported type paths. Never use generic text as a substitute for missing runtime support.
5. Define parent-first creation ordering and stable lookup targets using scenario-owned deterministic natural keys; enforce exact lookup resolution, uniqueness and missing-parent failures. Do not assume an OOB entity set name; resolve through the authorized runtime/metadata stage.
6. Design clear distributions and narrative records (states, ages, ownership, dates, anomalies and negative test cases) with explicit counts, bounds and intended demonstrations. Negative/invalid examples belong in non-applied test fixtures, never the approved seed payload.
7. Plan rerun identity by source tag, deterministic keys and existing-record behavior. The current seed stage rejects duplicate/foreign same-key records and updates owned IDs on rerun; never claim it can silently upsert foreign data. Define idempotency checks and stop conditions.
8. For Dataverse **Task** activities, explicitly identify eligible parent tables, `latest/all/selected` scope, bounded source-record limit, ordering field and tasks per selected record. Recommended default: latest 10 per parent ordered by `createdon desc`, subject to verified contract support; selecting `all` requires explicit approval. Never generate tasks for every record by assumption.
9. Record dependencies, risks, data-quality invariants and validation cases (counts, types, choices, relationship reachability, owner/source tags, duplicate avoidance and replay consistency). Cleanup must be separately approved, bounded to proven scenario-owned records, with dry-run inventory, impact report and explicit operator confirmation. Do not promise transaction rollback for data already written.

## Output and execution handoff

Produce an approved-scope **planning proposal** in `TargetProjectRoot/specs/<scenario-slug>/` using the existing `demo-data-plan.json` planning contract defined by `scripts/bootstrap/05-start-wizard.ps1`; no standalone JSON Schema currently exists for that planning document. `schemas/payloads/data.schema.json` validates executable `data-*.json` payloads, not the planning document. Do not invent new planning keys or bypass executable payload schema validation. When a required behavior is not supported by the planning contract, executable payload schema or current stage, mark it blocked and propose a reviewed extension rather than creating a competing import engine. Optional companion `demo-data-design.md` may explain distributions, dependencies, sample synthetic preview, requirement links, planned tests and explicit approvals.

Report per-table name, mode, count, synthetic scenario/state distribution, relationships and key rules, privacy constraints, optional Task configuration, payload compatibility, open decisions, and validation/cleanup handoff. Record planned versus executed evidence distinctly. Only a separately authorized existing wizard pipeline may create or modify data; preserve existing preflight, preview and source-protection gates.
