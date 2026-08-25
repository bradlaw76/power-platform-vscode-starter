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

Describe the requirement, implementation, tests, Dataverse behavior that remains unverified, security impact, and documentation changes. Keep generated reports and raw solution exports out of the pull request unless they are sanitized, stable fixtures intentionally required by a test.

## Licensing

No repository license has been selected. Contributors and owners must not infer redistribution rights. Choosing and adding a license is an explicit repository-owner decision.
