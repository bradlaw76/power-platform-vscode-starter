# FAST Solution Accelerator Discovery Tasks

## FAST-000 - Git baseline and recovery

- [x] Confirm repository root, default branch, active branch, remotes, recent
  history, conflicts, worktrees, submodules, GitHub authentication, and PR state.
- [x] Obtain approval to preserve all tracked and untracked work.
- [x] Create preservation commit
  `17bebe3fb2322c2ad07c05dec8ef0c64dba6df28`.
- [x] Push the source branch.
- [x] Create and push `backup/pre-fast-20261015`.
- [x] Create and push annotated tag `pre-fast-20261015`.
- [x] Create and push `feature/fast-accelerator-catalog`.
- [x] Verify branch and tag targets through GitHub.
- [x] Attempt the aggregate quality runner and record its parser failure.
- [x] Run the quality stages independently and record exact results.
- [x] Rehearse restore from the annotated tag with FAST disabled and network
  outage conditions.
- [x] Document feature disable and rollback procedures.

## FAST-001 - Architecture and Spec Kit

- [x] Read repository specification, binding status, manifest, workflow
  contract, profile, planning examples, and source-control standards.
- [x] Inspect discovery and three-mode planning behavior.
- [x] Inspect planning gates and shared contract parsing.
- [x] Inspect payload-driven generation and orchestrator boundaries.
- [x] Inspect Dataverse request resilience and scoped publishing.
- [x] Inspect scenario-scoped provenance, idempotency, export, and tests.
- [x] Verify official FAST documentation and backing repositories.
- [x] Inventory dynamic source collections and breadth discrepancies.
- [x] Verify repository archive and support-disclaimer state.
- [x] Assess Core-first requirements and package-verification gaps.
- [x] Correct the Core release assessment using the official module-page link.
- [x] Verify the Core managed ZIP, GitHub digest, solution manifest, physical
  schema metadata, components, and declared dependencies.
- [x] Reconcile the complete release inventory to 22 package-bearing module
  prefixes across 70 releases.
- [x] Define provider isolation and catalog snapshot lifecycle.
- [x] Define catalog, evidence, dependency, matching, and decision contracts.
- [x] Define feature-disable, outage, retirement, and rollback behavior.
- [x] Define mode-preserving integration and acceptance criteria.
- [x] Create architecture decision records.
- [ ] Obtain architectural review approval.

## FAST-002 - Catalog foundation (not authorized)

- [ ] Define reviewed JSON schemas for catalog items, snapshots, source records,
  diffs, dependencies, releases, and provider health.
- [ ] Implement provider-neutral interfaces and an empty valid registry.
- [ ] Implement FAST source allowlist and SSRF-safe HTTP boundary.
- [ ] Implement collection discovery from repository configuration/tree.
- [ ] Discover official release links from every module page and front-matter
  record without hardcoded module names or versions.
- [ ] Implement front-matter and structured-stat parsers.
- [ ] Implement release/tag pagination and asset inventory.
- [ ] Reconcile, per module and version, documentation links, GitHub release
  assets, source artifacts, and available package-inspected physical metadata.
- [ ] Assign independent availability states: documented, source-available,
  package-verified, and environment-verified.
- [ ] Index solution ZIP metadata offline without importing or deploying it.
- [ ] Implement candidate snapshot normalization and content hashing.
- [ ] Implement coverage reconciliation and explicit exceptions.
- [ ] Implement candidate validation, diff, tombstones, and promotion.
- [ ] Add fixtures for new, changed, renamed, removed, duplicate, malformed,
  timeout, rate-limit, and partial-source cases.
- [ ] Prove no wizard UI, build-stage, or Dataverse change in FAST-002.

## FAST-003 - Core and package intelligence (not authorized)

- [ ] Discover and evaluate newer or alternate Core releases dynamically rather
  than pinning `1.2.1.0`.
- [ ] Build the evidence-carrying dependency DAG.
- [ ] Add cycle, missing dependency, and version conflict validation.
- [ ] Implement safe offline package metadata inspection.
- [ ] Define package hash/signature verification policy.
- [ ] Build a Core component manifest from verified evidence.
- [ ] Keep environment verification behind separate authorization.

## FAST-004 - Matching and delta analysis (not authorized)

- [ ] Normalize requirements to stable IDs.
- [ ] Implement deterministic candidate filtering.
- [ ] Evaluate a local semantic retrieval option and privacy boundary.
- [ ] Implement per-requirement decision classification.
- [ ] Produce FAST foundation, hybrid, and custom alternatives.
- [ ] Generate machine-readable decisions and ADR projections.
- [ ] Add strong, partial, zero, ambiguous, overlap, stale, and custom-override
  golden fixtures.

## FAST-005 - Wizard integration (not authorized)

- [ ] Add default-off `FAST_ENABLED` provider registration.
- [ ] Integrate after requirements normalization and before final architecture.
- [ ] Preserve Demo Builder question budget and consolidated recommendation.
- [ ] Add Advanced Builder detail without changing existing core questions.
- [ ] Add Framework Acceptance FAST evidence scenarios.
- [ ] Pin selected snapshot and module versions in scenario artifacts.
- [ ] Prove disabled mode produces baseline-equivalent planning outputs.

## FAST-006 - Failure, rollback, and rollout (not authorized)

- [ ] Add absent-provider, outage, no-snapshot, retired-source, broken-candidate,
  catalog-rollback, and code-rollback tests.
- [ ] Run security review before promotion.
- [ ] Complete documentation, contract, skill, and CI parity updates.
- [ ] Use controlled nonproduction rollout and explicit deployment approvals.
