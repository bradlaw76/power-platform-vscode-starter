# FAST-006 Build Planning Acceptance

**Date:** 2026-10-16
**Branch:** `feature/fast-accelerator-catalog`
**Execution boundary:** Dry-run only; no Dataverse or PAC calls

## Architecture

The provider-neutral adapter consumes approved scenario-local architecture,
coverage, delta, schema, dependency, package, readiness, and acceptance
artifacts. It produces an aggregate build plan and eight projections under
`specs/<scenario>/accelerator/build-plan/`.

Every component uses `REUSE`, `EXTEND`, `CREATE`, `INTEGRATE`, or `DEFER`.
Managed definitions cannot be modified directly. Unverified extensions are
deferred. All outputs are deterministic and explicitly unauthorized for
execution.

## Hybrid fraud acceptance

The accepted Hybrid decision reuses the package-verified Investigation,
Investigation Interview, Evidence Item, and Evidence Custody Record tables.
Investigator Assignment, Fraud Score, Supervisor Approval, and Report remain
solution-owned creations. Custom columns, relationships, forms, and views that
would target managed tables are deferred until customization support is
verified. External scoring is represented as integration work.

The GCC readiness gate remains closed: required FAST solutions are absent and
the evidence is not fresh enough for execution. The plan is blocked and does
not install anything.

## Fully Custom comparison

The real Advanced Builder generated and approved a separate Fully Custom
decision for the same seven requirements. Its plan has no accelerator-managed
components, package prerequisites, or FAST environment gate. It is
`dry-run-ready`, but remains unauthorized for execution under FAST-006.

## Industry neutrality

The same adapter was exercised with equipment maintenance, employee onboarding,
event registration, customer service, external API, accelerator-relevant,
no-match, and custom-only fixtures. Each scenario changed only fixture data.
Production adapter source contains none of their industry terminology.

## Validation

- focused FAST-006 suite: passed;
- contract integrity: passed;
- aggregate and projection JSON schemas: passed;
- deterministic reruns: passed;
- managed direct-modification check: passed;
- unapproved decision rejection: passed;
- no live execution command in the adapter: passed.
