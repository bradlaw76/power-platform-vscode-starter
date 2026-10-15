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
- [x] Obtain architectural review approval.

## FAST-002 - Catalog foundation

- [x] Define reviewed JSON schemas for catalog items, snapshots, source records,
  diffs, dependencies, releases, and provider health.
- [x] Implement provider-neutral interfaces and a default-off registry.
- [x] Implement FAST source allowlist and HTTPS request boundary.
- [x] Implement collection discovery from repository configuration/tree.
- [x] Discover official release links from every module page and front-matter
  record without hardcoded module names or versions.
- [x] Implement front-matter and release parsers.
- [x] Implement release/tag pagination and asset inventory.
- [x] Reconcile, per module and version, documentation links, GitHub release
  assets, source artifacts, and available package-inspected physical metadata.
- [x] Assign independent availability states: documented, source-available,
  package-verified, and environment-verified.
- [x] Index solution ZIP metadata offline without importing or deploying it.
- [x] Demonstrate Core and two specialty-module package indexes.
- [x] Implement candidate snapshot normalization and content hashing.
- [x] Implement coverage reconciliation and explicit exceptions.
- [x] Implement candidate diff and external promotion pointer.
- [x] Add fixtures for new, changed, removed, unavailable, offline, and
  encoded-tag cases.
- [x] Implement Level 1 catalog compatibility.
- [x] Implement mockable Level 2 read-only environment preflight.
- [x] Define Level 3 approved installation verification without import.
- [x] Implement the FAST-dependent generation gate with stale-evidence checks.
- [x] Test ready, missing-dependency, incompatible, stale, offline, and
  user-declined environment outcomes.
- [x] Prove no wizard UI, build-stage, or Dataverse change in FAST-002.
- [x] Obtain FAST-002 architectural review approval.

## FAST-003 - Read-only environment preflight

- [x] Implement live read-only environment transport before enabling any
  FAST-dependent generation in the wizard.
- [x] Prove the selected environment identity, permissions, installed Core,
  specialty versions, required components, and dependency evidence.
- [x] Reuse existing authenticated environment and token refresh conventions.
- [x] Inspect organization version, exact solution versions, and publishers.
- [x] Validate all four Core declared dependencies using live metadata.
- [x] Inspect required package tables and specialty component dependencies.
- [x] Classify Core installed, incomplete, missing, blocked, and inaccessible.
- [x] Produce a schema-valid version `1.1` preflight report.
- [x] Cache non-secret evidence by environment, snapshot, package, and
  dependency identity with bounded TTL.
- [x] Test authentication, permissions, throttling, timeout, stale cache,
  catalog/package/dependency changes, environment switching, disabled mode,
  and nonmutation.
- [x] Preserve fully custom planning and the reusable readiness gate.
- [x] Obtain FAST-003 architectural review approval.

## FAST-003A - Authorized GCC validation

- [x] Discover authenticated GCC environments without assuming commercial,
  GCC High, or DoD endpoints.
- [x] Require explicit confirmation of a non-production target.
- [x] Verify the PAC `UsGov` profile, GCC authority, and `crm9.dynamics.com`
  environment URL.
- [x] Run a resource-scoped, GET-only forced-refresh preflight.
- [x] Verify environment identity, organization version, read permissions,
  installed solutions, Core, specialty modules, and dependencies.
- [x] Verify cache reuse and forced-refresh behavior.
- [x] Correct unsupported global Choice filtering, missing-parent
  classification, and duplicate dependency identities.
- [x] Record sanitized GCC evidence without tenant, user, or token identifiers.
- [x] Confirm Core is missing and the FAST build gate remains closed.
- [x] Obtain FAST-003A review approval before FAST-004.

## FAST-003 follow-up dependency intelligence (not authorized)

- [ ] Discover and evaluate newer or alternate Core releases dynamically rather
  than pinning `1.2.1.0`.
- [ ] Build the evidence-carrying dependency DAG.
- [ ] Add cycle, missing dependency, and version conflict validation.
- [x] Implement safe offline package metadata inspection.
- [ ] Define package hash/signature verification policy.
- [x] Build a Core component manifest from verified evidence.
- [x] Keep environment verification behind explicit standalone invocation.

## FAST-004 - Matching and delta analysis

- [x] Normalize natural-language and structured requirements to stable IDs.
- [x] Implement deterministic, evidence-grounded candidate filtering.
- [x] Keep retrieval local and document the privacy boundary; do not require a
  remote semantic service.
- [x] Correlate verified physical components without treating names as process
  coverage.
- [x] Implement REUSE, EXTEND, BUILD, INTEGRATE, and VERIFY dispositions.
- [x] Produce FAST-based, Hybrid, and Fully Custom alternatives.
- [x] Compute transitive dependencies, deduplicate physical edges, detect
  cycles, and leave unsupported version compatibility unverified.
- [x] Consume optional FAST-003 evidence without initiating live inspection.
- [x] Generate machine-readable decisions, coverage, delta, schema,
  dependency, readiness, task, acceptance, and ADR projections.
- [x] Add strong, partial, zero, ambiguous, overlap, unavailable, new-module,
  repeated-run, GCC Core-missing, and disabled-mode fixtures.
- [x] Prove no wizard registration, Dataverse mutation, or network dependency.
- [ ] Obtain FAST-004 architectural review approval before FAST-005.

## FAST-005 - Wizard integration (not authorized)

- [ ] Add default-off `FAST_ENABLED` provider registration.
- [ ] Integrate after requirements normalization and before final architecture.
- [ ] Preserve Demo Builder question budget and consolidated recommendation.
- [ ] Add Advanced Builder detail without changing existing core questions.
- [ ] Add Framework Acceptance FAST evidence scenarios.
- [ ] Pin selected snapshot and module versions in scenario artifacts.
- [ ] Refuse FAST-dependent generation unless current Level 2 or Level 3
  evidence opens the mandatory build gate.
- [ ] Prove disabled mode produces baseline-equivalent planning outputs.

## FAST-006 - Failure, rollback, and rollout (not authorized)

- [ ] Add absent-provider, outage, no-snapshot, retired-source, broken-candidate,
  catalog-rollback, and code-rollback tests.
- [ ] Run security review before promotion.
- [ ] Complete documentation, contract, skill, and CI parity updates.
- [ ] Use controlled nonproduction rollout and explicit deployment approvals.
