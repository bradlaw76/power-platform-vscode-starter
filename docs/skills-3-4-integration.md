# Skills 3 and 4 — Integration and Execution Boundaries

These optional skills are available to both GitHub Copilot (`.github/skills/`) and Claude (`.claude/skills/`). They extend existing planning/review, not the executable wizard. **Skill 3** (`dataverse-solution-validator`) reviews traceability, Dataverse metadata intent and actual evidence levels; **Skill 4** (`power-platform-demo-data-designer`) designs strictly opt-in synthetic datasets for the existing seeding pipeline.

## Routing

- Requirements discovery and acceptance criteria: `power-platform-requirements-analyst`.
- Table, column and relationship architecture: `dataverse-solution-architect`.
- Independent solution quality/readiness review: `dataverse-solution-validator`. Static review never constitutes environment or deployment validation.
- Optional dataset design after affirmative opt-in: `power-platform-demo-data-designer`. Use the existing `demo-data-plan.json` planning contract defined by `scripts/bootstrap/05-start-wizard.ps1`; no standalone JSON Schema currently exists for that planning document. `schemas/payloads/data.schema.json` validates executable `data-*.json` payloads, not the planning document. Never create a parallel import engine.
- Existing Dataverse reporting: `dataverse-report-wizard` and its own approval gates.

## Constraints

Preserve the three wizard modes (default six-question `demo-builder`, explicit `advanced-builder`, explicit `framework-acceptance`), the separate `FrameworkRoot` and `TargetProjectRoot`, scenario-scoped artifacts, the step order in `docs/onboarding.md`, and the workflow contract in `docs/wizard-contract-v1.md`. The two new skills do not introduce runtime stages, data writes or independent approvals. All output paths require existing planning-write approval. Existing tests for Skills 1–2 remain unchanged.

## Validation

Run `pwsh scripts/ci/test-skills-3-4.ps1` in a complete repository checkout. This static parity/safety check is not a functional integration test or a Dataverse deployment test. Run the repository's existing CI, Pester, analyzer, lint and schema checks at the approved baseline before publishing.

## Pre-release tracked findings

The five earlier PR #4 findings (two Moderate, three Low) are **not** resolved by these skills. Do not merge or release combined framework work before they are independently verified and remediated.
