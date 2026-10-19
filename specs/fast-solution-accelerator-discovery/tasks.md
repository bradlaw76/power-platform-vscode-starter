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
- [x] Build the evidence-carrying dependency DAG.
- [x] Add cycle, missing dependency, and version conflict validation.
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
- [x] Obtain FAST-004 architectural review approval before FAST-005.

## FAST-005 - Wizard integration

- [x] Add default-off `FAST_ENABLED` and explicit-switch integration gates.
- [x] Integrate after requirements normalization and before final architecture.
- [x] Preserve Demo Builder question budget and consolidated recommendation.
- [x] Add Advanced Builder detail without changing existing core questions.
- [x] Add Framework Acceptance FAST evidence and deterministic rerun scenarios.
- [x] Pin selected snapshot, module versions, and package hashes in scenario
  artifacts.
- [x] Require explicit architecture selection and approval for decision changes.
- [x] Refuse FAST-dependent generation unless current Level 2 or Level 3
  evidence opens the mandatory build gate.
- [x] Preserve Fully Custom during catalog outage or user override.
- [x] Prove disabled mode produces baseline-equivalent planning outputs.
- [x] Prove no Dataverse mutation, solution import, or build-stage invocation.
- [x] Obtain FAST-005 architectural review approval before FAST-005A.

## FAST-005A - Acceptance demonstration

- [x] Execute the synthetic fraud scenario through all three existing modes.
- [x] Use promoted catalog, verified package metadata, and GCC readiness
  evidence.
- [x] Prove byte-stable reruns and explicit approval for decision changes.
- [x] Record missing-Core blocking and no Dataverse mutation.
- [x] Identify granular-requirement, schema-rendering, package-input, and
  generated-Markdown corrections.

## FAST-005B - Acceptance corrections

- [x] Add a default-off, post-mode preliminary accelerator preference.
- [x] Keep feature activation, preliminary preference, final architecture
  approval, and deployment authorization separate.
- [x] Add stable granular requirement extraction with aggregate fallback.
- [x] Fix custom schema rendering at the PowerShell formatter source.
- [x] Add a validated multi-package input manifest with identity/hash checks.
- [x] Remove trailing whitespace in the Markdown generator.
- [x] Add focused preference, granularity, schema, package, lint,
  reproducibility, and safety regression tests.
- [x] Repeat and preserve all three corrected acceptance demonstrations.
- [x] Run complete FAST and wizard regression validation.
- [x] Commit, push, and verify the remote feature branch and recovery refs.
- [x] Obtain FAST-005B architectural review approval before FAST-006.

## FAST-006 - Provider-neutral dry-run build planning

- [x] Add strict approved-decision and scenario-artifact validation.
- [x] Generate deterministic aggregate and projection build-plan artifacts.
- [x] Implement REUSE, EXTEND, CREATE, INTEGRATE, and DEFER tasks.
- [x] Enforce managed ownership, publisher naming, and collision prevention.
- [x] Keep accelerator-dependent plans behind fresh environment evidence.
- [x] Preserve an accelerator-independent Fully Custom plan.
- [x] Exercise eight unrelated application fixtures without source changes.
- [x] Demonstrate blocked GCC Hybrid and viable Fully Custom fraud plans.
- [x] Register schemas, profile contract, CI, documentation, and skills.
- [x] Prove no Dataverse, PAC, import, or bootstrap-stage integration.
- [ ] Obtain FAST-006 architectural review approval before FAST-007.

## FAST-007 - Historical execution-gate proposal (superseded)

The former execution-stage handoff proposal is not authorized. The authorized
FAST-007 scope is local-only execution readiness, defined below.

## FAST-007 - Completed local readiness status

This update supersedes earlier stop conditions only for the bounded local
readiness implementation; it does not mark historical architectural review
tasks complete or authorize execution. Detailed implementation tasks and
synthetic evidence are owned by `specs/fast-007-execution-readiness/`.
The authorized local-only implementation and readiness-only orchestrator
integration are complete and validated; no runtime readiness integration
remains pending.

- [x] Record the local-only boundary in ADR 0010 and the operational guide.
- [x] Require approved scenario decision/build-plan manifest integrity, canonical
  IDs, input fingerprints, schema-valid external evidence, independent full
  target identity, and a maximum 24-hour evidence lifetime.
- [x] Emit six statuses; `READY_FOR_APPROVAL` is human review only and
  `executionAuthorized` is always false.
- [x] Bind decision/plan/evidence/inputs/target with scope SHA-256; keep
  `build-authorization.schema.json` future-only, with no approval or
  authorization records generated or consumed.
- [x] Return from readiness-only orchestration before helpers/stages/payload
  requirements; forbid combining preflight with Apply and block FAST-dependent
  normal Apply regardless of readiness.
- [x] Preserve default-off behavior in all modes and legacy/Fully Custom normal
  builds; perform no Dataverse/PAC/network/authentication/install/import/build
  execution or live platform-provenance verification.
- [x] Persist authoritative
  [FAST-007 validation evidence](../fast-007-execution-readiness/evidence/fast-007-validation.md):
  129 readiness assertions, four cross-domain applications, 26 negative
  scenarios, 11 byte-identical regenerated samples, and 107 passing Pester
  tests. Standalone CI finished at 33/34 passing after the isolated formatter
  rerun; its assertions had passed before OneDrive cleanup locks. The sole
  standalone failure is the historical `test-script-smoke.ps1` expectation.
  The historical `run-quality.ps1` parser failure is recorded separately.
  PSScriptAnalyzer reported zero findings and Markdown lint zero errors.

Stop after FAST-007 review. FAST-008 trusted collection, independent
approver/signature verification, authorization consumption/revalidation, and a
separately approved executor remain proposed, not approved. These validation
results do not establish live readiness or authorize execution; no approval
or authorization records are generated or consumed.
