---
name: dataverse-solution-validator
description: 'Use for evidence-based Dataverse solution design and implementation validation, field typing, solution membership, traceability, security and deployment-readiness reviews; read-only and no deployment.'
---

<!--
COMPONENT: Dataverse Solution Validator Skill
VERSION: 1.0.0
ENVIRONMENT: GitHub Copilot | Claude | Power Platform
OVERVIEW: Independent static and evidence-backed solution validation.
NON-NEGOTIABLES: Fail closed on unknowns; no mutation or invented evidence.
-->

# Dataverse Solution Validator (Skill 3)

## Activation and boundaries

Invoke after approved requirements and architecture planning, or to review an existing solution/retrofit. Reuse the current `specs/<scenario-slug>/` artifacts and approvals; never restart intake. This skill **does not** implement, authenticate, install, alter metadata, publish, import/export, deploy, commit, push, merge, or mark a live validation as passed. Do not invoke live endpoints as a side effect of review. A separately authorized execution/verification workflow may supply evidence to review.

Follow `docs/wizard-contract-v1.md`, `docs/onboarding.md`, `docs/requirements-traceability.md`, and `docs/semantic-field-type-standard.md`. Confirm `FrameworkRoot` is read-only in Application Authoring Mode and `TargetProjectRoot` is separate, explicitly resolved, and writable only with planning approval. Framework Administration Mode uses `docs/framework-maintenance-preflight.md` and separate modification, commit, push and merge approvals; never change checkout or loosen source protection to proceed. Skill availability is not runtime installation.

Preserve `demo-builder` (six business questions and consolidated recommendation), `advanced-builder`, and `framework-acceptance` without adding acceptance-mode questions to other modes. Existing `dataverse-report-wizard` gates, FAST integrations, Spec Kit, and bootstrap scripts remain authoritative.

## Inputs and provenance

1. Resolve scenario, existing/retrofit state, selected profile, solution unique name, publisher prefix, component inventory, solution membership report, app entry point, landing view, sitemap and report/no-report decision.
2. Read approved `spec.md`, `plan.md`, `tasks.md`, `answers.md`, `architecture.md`, `field-catalog.md`, `requirements-traceability.md`, and `report-mappings.md` when present. Treat missing required artifacts as findings, not presumed approval. `demo-data-plan.json` is conditional on opt-in.
3. Review actual payloads and their schemas, including `columns-*.json`, relationships, forms/views, solution/app/report definitions, and generated inventory where available. Payload files remain authoritative for executable schema and ordering; documentation does not prove runtime support.
4. Label each fact **verified artifact**, **operator-supplied**, **live evidence**, or **unverified assumption**. Record artifact path, exact field/record where feasible, evidence date, environment identity and freshness. Do not imply locally inspected source is live Dataverse state.

## Validation matrix

Check each relevant area and report PASS, FAIL, BLOCKED, NOT VERIFIED or NOT APPLICABLE (with explanation):

- **Scope and traceability:** stable `REQ-###` IDs, linked user task, acceptance criterion, architecture decision, implementation task and test. Trace both directions; identify orphan components and uncovered requirements. Distinguish planned from executed tests.
- **Solution identity/dependencies:** publisher, prefix, unique name, managed/unmanaged intent, component types, dependencies, environment profile and upstream packages; do not infer membership from local payloads.
- **Tables and metadata:** reuse versus custom rationale, logical/schema names, ownership, primary name and id conventions, requiredness, defaults, constraints and supported formats. Compare field catalog with actual `@odata.type`, `FormatName`, DateOnly/UserLocal/TimeZoneIndependent behavior, money/currency, numeric precision, Boolean/Choice/multiselect values, File/Image, and Lookup targets. Never silently substitute generic text.
- **Relationships:** referenced and referencing tables, cardinality, requiredness, cascade behavior, lookup resolution, permission and deletion impacts; validate parent-child dependencies and existing/new ownership.
- **Experience:** existing/generated form strategy; business display labels; expected forms, views, `adopt-generated-active` provenance versus `create-custom`, entry-point table, landing view, sitemap and model-driven review app. A name match never proves generated-view ownership.
- **Security and privacy:** actual versus assumed security roles/privileges, table ownership, least privilege, field sensitivity, role membership and evidence limitations. Do not claim real-user access without observed verification.
- **Reporting/data:** explicit report/no-report and `report-mappings.md`; scope of critical/high-frequency tables; optional demo-data opt-in; reused standard tables never seeded by default; Task activities bounded to eligible parent tables with latest/all/selected scope, source-record limit, ordering field and tasks per selected record.
- **Build quality:** schema validation, planned versus observed execution, first/final solution membership, idempotency, scenario provenance, source-control isolation, logged errors, publish evidence, app navigation and usability; identify missing or stale observations.

## Evidence levels and readiness decision

**STATIC:** validates artifact internal consistency only. **ENVIRONMENT:** requires approved, dated live metadata and environment-specific membership/security evidence. **DEPLOYMENT/USABILITY:** requires recorded authorized execution, publish, opening the app as an intended user, navigation/form checks, export gates and actual test results. No evidence tier upgrades implicitly. Never use static PASS to claim deployment readiness, or treat an unrun test as passed.

Severity: **Critical** for unauthorized writes/identity or source-root escapes; **High** for blocking requirements, incompatible metadata, unsupported types or proven security exposure; **Moderate** for material incomplete mappings or readiness gaps; **Low** for nonblocking documentation/observability gaps. State when severity is provisional because evidence is missing. Failed or unknown required gates imply **NOT READY / BLOCKED**, never a guessed score of 100%.

## Output contract

Return a reproducible review with scenario and environment identity, evaluated evidence level, source list and timestamps, a finding table (`ID`, area, requirement, severity, status, evidence path, observed versus expected, owner, remediation, retest), validation matrix, explicit unexecuted checks, and readiness decision. Add a traceability coverage summary with actual numerator/denominator only when computable. Keep recommendations separate from fixes.

Write only an approved review under `TargetProjectRoot/specs/<scenario-slug>/` (for example `solution-validation.md`); never rewrite payloads or scenario approvals automatically. Hand corrective implementation tasks back to the existing approved wizard, and require separate authorization for any live verification, source change, publish, or deployment.
