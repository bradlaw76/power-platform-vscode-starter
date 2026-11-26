# Contributing

## Before changing code

Load the [canonical execution policy](docs/policies/authorization-and-execution.md)
and only the functional contracts affected by the change. For wizard/application
changes, use [onboarding](docs/onboarding.md) and the
[wizard contract](docs/wizard-contract-v1.md). Keep scenario work under
`specs/<scenario-slug>/` and `payloads/scenarios/<scenario-slug>/`; do not recreate
scenario planning at the repository root.

For new or changed application behavior, align affected `spec.md`, `plan.md`, and `tasks.md` before implementation under the [proportional scenario-impact gate](docs/scenario-change-impact-gate.md). Minor maintenance that restores accepted behavior retains accepted planning and runs focused checks; do not restart the full planning cycle. Preserve payloads as the source of truth, idempotent behavior, 401 token refresh, 429 backoff, publishing, complete solution inventory, and the export gate.

The canonical policy owns authority, writer/recovery, publication and
documentation rules; this contributor guide does not add another approval cycle.
For explicitly autonomous multi-change work, use
[dependency-aware queues](docs/QUEUED_AUTONOMOUS_DELIVERY.md).

## Development workflow

1. Start from a clean clone or reviewed working tree.
2. Run the prerequisites needed by the affected workflow. Wizard/environment
   work uses `00-prereq-check.ps1`; routine source maintenance uses its existing
   focused validation, not a repeated environment setup cycle.
3. Make focused changes without modifying unrelated user work.
4. Add credential-free tests, including rerun behavior when metadata mutation changes.
5. Run the repository CI commands documented in [docs/onboarding.md](docs/onboarding.md).
6. Review staged files for secrets, generated artifacts, customer data, and local workspace files.
7. Commit and push each require explicit permission. Reuse valid scoped
   permission already provided; ask only for missing scope, following
   [authorization and execution](docs/policies/authorization-and-execution.md).

Never run Dataverse integration tests against production. Use only an authorized disposable development environment and the manually triggered workflow confirmation.

## Pull requests

Describe the requirement, implementation, tests, Dataverse behavior that remains unverified, security impact, and documentation changes. Keep generated reports and raw solution exports out of the pull request unless they are sanitized, stable fixtures intentionally required by a test.

## Licensing

No repository license has been selected. Contributors and owners must not infer redistribution rights. Choosing and adding a license is an explicit repository-owner decision.
