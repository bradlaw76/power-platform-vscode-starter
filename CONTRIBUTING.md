# Contributing

## Before changing code

Read [docs/onboarding.md](docs/onboarding.md), [docs/wizard-contract-v1.md](docs/wizard-contract-v1.md), and the repository instructions. Keep scenario work under `specs/<scenario-slug>/` and `payloads/scenarios/<scenario-slug>/`; do not recreate scenario planning at the repository root.

For behavior changes, update `spec.md`, `plan.md`, and `tasks.md` before implementation. Preserve payloads as the source of truth, idempotent behavior, 401 token refresh, 429 backoff, publishing, complete solution inventory, and the export gate.

## Development workflow

1. Start from a clean clone or reviewed working tree.
2. Run `pwsh ./scripts/bootstrap/00-prereq-check.ps1`.
3. Make focused changes without modifying unrelated user work.
4. Add credential-free tests, including rerun behavior when metadata mutation changes.
5. Run the repository CI commands documented in [docs/onboarding.md](docs/onboarding.md).
6. Review staged files for secrets, generated artifacts, customer data, and local workspace files.
7. Request explicit approval before committing and separate approval before pushing.

Never run Dataverse integration tests against production. Use only an authorized disposable development environment and the manually triggered workflow confirmation.

## Pull requests

### Maintain update advice and source traceability

When adding or changing a wizard capability, update
[`repository-updates.json`](repository-updates.json) with matching path rules
and review guidance. Use the existing categories; do not label path changes as
verified fixes or guaranteed breaking changes. Keep unknown relevance visible
and preserve explicit scenario opt-outs.

Follow the [enhancement maintenance checklist](README.md#required-checklist-for-future-enhancements)
and [update advisor guide](docs/repository-updates.md). Keep startup local-only,
require explicit fetch, and never automatically pull or enable a capability.
Apply run source records are immutable and scenario/solution/publisher/run-bound;
Preview must not write manifest provenance. Preserve these boundaries when
changing orchestration or resume.

Run `pwsh .\scripts\ci\test-repository-updates.ps1` for advisor changes and the
existing related contract/parity/Preview tests. Use the complete
`pwsh .\run-quality.ps1` before publishing a combined integration bundle.
Keep local update reports, baseline archives, credentials and generated build
outputs out of commits unless sanitized fixtures are intentionally approved.

### Describe the change

Describe the requirement, implementation, tests, Dataverse behavior that remains unverified, security impact, and documentation changes. Keep generated reports and raw solution exports out of the pull request unless they are sanitized, stable fixtures intentionally required by a test.

## Licensing

No repository license has been selected. Contributors and owners must not infer redistribution rights. Choosing and adding a license is an explicit repository-owner decision.
