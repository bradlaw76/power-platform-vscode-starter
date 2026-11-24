# Contributing

## Before changing code

Read [docs/onboarding.md](docs/onboarding.md), [docs/wizard-contract-v1.md](docs/wizard-contract-v1.md), and the repository instructions. Keep scenario work under `specs/<scenario-slug>/` and `payloads/scenarios/<scenario-slug>/`; do not recreate scenario planning at the repository root.

For new or changed application behavior, align affected `spec.md`, `plan.md`, and `tasks.md` before implementation under the [proportional scenario-impact gate](docs/scenario-change-impact-gate.md). Minor maintenance that restores accepted behavior retains accepted planning and runs focused checks; do not restart the full planning cycle. Preserve payloads as the source of truth, idempotent behavior, 401 token refresh, 429 backoff, publishing, complete solution inventory, and the export gate.

Reuse accepted requirements and valid standing scoped nonproduction authority
under the canonical authorization policy. Recoverable registration, H numbering
and narrative documentation do not block independently authorized implementation
unless needed for real authority, enforced policy or conflicting writers. Complete
routine repair documentation before closure; never defer semantic/report/hash/
FAST/security gates. H IDs track outcomes, not permanent component ownership.
Recover before restart using process, checkpoint and actual resource evidence;
lease expiry alone does not release a writer. For explicitly autonomous
multi-change work, recommend [dependency-aware queues](docs/QUEUED_AUTONOMOUS_DELIVERY.md).

## Development workflow

1. Start from a clean clone or reviewed working tree.
2. Run `pwsh ./scripts/bootstrap/00-prereq-check.ps1`.
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
