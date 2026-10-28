# Implementation plan

## Architecture

- Canonical policy: `docs/semantic-field-type-standard.md`.
- Scenario inventory: `specs/<slug>/field-type-decisions.json`, validated by a
  shared JSON schema and helper, with explicit references in scenario spec/plan.
- `14-validate-semantic-fields.ps1` provides credential-free Planning/Payload
  modes and GET-only Metadata mode. Planning precedes column payload generation;
  Payload checks exact coverage before build execution.
- Stage 30 validates existing metadata before mutations, creates missing columns
  only on 404, publishes only changed tables, and validates deployed columns.
- The orchestrator validates payloads before any build stage, validates all fields
  after stage 40 and before export, and does not resume-skip metadata gates.
- Direct stage 95 reruns the live semantic gate before PAC, including outside the
  orchestrator. HTTP classification does not confuse identifier digits with a
  response status.
- Inventory/planning/payload content participates in resume scope hashing.
- Terminal intake emits an unapproved draft, never inferred field approvals.

## Boundaries

Human approval asserts semantic correctness and cross-surface vocabulary review;
software verifies structure, payload conformance and live metadata. Visual and
functional forms/views/charts/BPF/automation/integration/report validation remains
an explicit operator task, not a claimed consequence of metadata checks.
No destructive retrofit executor is added. Existing scenarios without an approved
inventory intentionally stop; no automatic legacy bypass is provided.

## Validation

Use synthetic local fixtures, injectable transport, focused CI/Pester checks,
PowerShell parsing/analyzer, JSON schema validation, documentation consistency,
skill parity and whitespace checks. Do not authenticate or mutate Dataverse.
