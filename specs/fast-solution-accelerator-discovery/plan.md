# FAST Solution Accelerator Discovery Plan

**Status:** FAST-007 local execution readiness implemented and validated; execution remains out of scope
**Baseline:** `17bebe3fb2322c2ad07c05dec8ef0c64dba6df28`

## Approach

Add a provider-neutral accelerator evaluation boundary between normalized
requirements discovery and final architecture confirmation. FAST will be an
optional provider backed by immutable, reviewed snapshots. Existing planning,
payload, Dataverse runtime, orchestration, provenance, and export stages remain
unchanged until later approved milestones explicitly integrate them.

## Architecture

### 1. Provider registry

Define an `AcceleratorProvider` contract with:

- provider identity and schema versions;
- enabled/disabled state;
- health and source-maintenance state;
- candidate synchronization;
- snapshot validation and promotion;
- catalog query;
- requirements evaluation;
- provenance lookup.

Consumers resolve providers through a registry. They do not import FAST types.
An empty registry is valid and means custom-only operation.

### 2. FAST source adapter

Use repository collections as the primary breadth source because the rendered
site indexes are incomplete for machine enumeration. The adapter will:

1. read the docs repository configuration and collection tree;
2. parse module, use-case, persona, agent, and portal front matter;
3. discover official release links from every module page and front-matter
   record, preserving encoded tag paths;
4. inventory module source directories and generated statistics;
5. enumerate releases/tags and assets with explicit pagination;
6. reconcile documentation links, release assets, source artifacts, and
   package-inspected physical metadata per module and version;
7. retrieve rendered narrative pages only for evidence sections that need them;
8. canonicalize URLs and stable identities;
9. report disagreements rather than selecting one source silently.

Both backing repositories are archived, so scheduled checks detect source
state and content changes but must not imply ongoing Microsoft maintenance.

### 3. Candidate and promoted snapshots

```text
source fetch
  -> raw source records
  -> normalized candidate
  -> schema and provenance validation
  -> coverage reconciliation
  -> dependency validation
  -> catalog diff
  -> human/policy approval
  -> immutable promoted snapshot
```

Matching reads only promoted snapshots. A scenario records the selected
snapshot ID. Candidate and promotion records are separate from the wizard's
generated Dataverse artifact manifest.

### 4. Evidence model

Keep every claim linked to its source and evidence tier. Documentation metadata
can identify candidate tables or capabilities but cannot generate exact
Dataverse payloads. Package inspection can verify physical schema. Authorized
environment inspection can verify installed version and compatibility.

Evidence is additive: stronger verification adds a record; it does not erase
the original claim or its source.

### 5. Core dependency resolver

Build a DAG from documented requirements and verified package dependencies.
Store dependency edges with evidence and version constraints. Topological
ordering is available only when the graph is complete and acyclic.

Core `1.2.1.0` is now package-verified: its managed ZIP downloaded successfully,
matched the GitHub API SHA-256 digest, and exposed exact physical metadata.
The package also declares four external dependencies. This evidence permits
package indexing for that release but does not establish environment
compatibility or make `1.2.1.0` a permanent requirement. Selected-version and
environment dependency resolution remain mandatory before deployment planning.

### 6. Requirements evaluator

1. Normalize scenario requirements to stable IDs.
2. Retrieve candidates using deterministic metadata filters and optional local
   semantic indexing.
3. Resolve dependencies and source freshness.
4. Score functional fit separately from deployability.
5. Build the per-requirement decision matrix.
6. Produce FAST foundation, hybrid, and custom alternatives.
7. Ask at most one material clarification.
8. Persist the approved ADR and machine-readable decision.

No customer requirements are sent to FAST sources. Any semantic index must be
local or use a separately approved service and data-handling contract.

## Storage design

Planned logical stores:

- `RawSourceRecord`: bounded source response plus provenance/hash.
- `CatalogSnapshot`: immutable normalized catalog and coverage report.
- `CatalogItem`: module, use case, persona, agent, portal, or shared data model.
- `CapabilityEvidence`: claim, source anchor, tier, confidence, and validation.
- `PackageRelease`: release/tag/assets/hashes and verification state.
- `DependencyEdge`: source, target, constraint, evidence, and resolution state.
- `CatalogDiff`: added, changed, renamed, removed, or incompatible.
- `AcceleratorDecision`: scenario requirements, alternatives, selection, and
  snapshot pin.

Exact schemas are defined in
[`catalog-contracts.md`](catalog-contracts.md).

## Integration sequence

### FAST-002 - Catalog foundation

- Provider contracts and default-off registry.
- Dynamic FAST source and release adapter.
- Automatic official module-page release-link discovery.
- Catalog, package, registry, and environment evidence JSON schemas.
- Fixture-based discovery and encoded-tag parsing.
- Offline package indexing for Core and two specialty modules.
- Candidate snapshot, deterministic hash, diff, immutable write, and promotion
  pointer.
- Level 1 catalog compatibility and mockable Level 2 read-only preflight.
- Level 3 installation verification plan only.
- No wizard UX, Dataverse transport, environment mutation, or import.

### FAST-003 - Dependency intelligence and approved integration preparation

- Authenticated read-only Dataverse inspector.
- Exact installed Core and specialty version/publisher checks.
- Batched table and grouped component dependency inspection.
- Versioned compatibility report and metadata fingerprint.
- Environment/snapshot/package/dependency-bound evidence cache.
- Reusable readiness gate without wizard-stage registration.
- No automatic import or Dataverse mutation.

### FAST-004 - Matching and delta planning

- Natural-language and structured requirement normalization with stable IDs.
- Deterministic, evidence-grounded catalog retrieval without remote semantic
  services or arbitrary numeric confidence scores.
- Independent package-component correlation after documented functional
  relevance is established.
- REUSE, EXTEND, BUILD, INTEGRATE, and VERIFY dispositions with component-level
  gaps, schema deltas, risks, acceptance criteria, and task references.
- Transitive dependency resolution, physical-edge deduplication, cycle
  detection, and fail-closed version handling.
- FAST-based, Hybrid, and Fully Custom alternatives with environment readiness
  evaluated separately from architectural suitability.
- Schema-valid machine-readable artifacts plus Markdown matrix and ADR
  projection.
- Golden matching fixtures covering new modules, unavailable sources,
  documented-only capabilities, ambiguity, GCC Core absence, and deterministic
  reruns.

### FAST-005 - Wizard integration

- Capability flag and optional provider assembly.
- Post-discovery/pre-finalization integration.
- Mode-specific presentation.
- Pinned decision artifacts.
- No change to custom-only outputs when disabled.

### FAST-006 - Provider-neutral build planning

- Consume only explicitly approved architecture and hash-verified analysis
  artifacts.
- Generate deterministic REUSE, EXTEND, CREATE, INTEGRATE, and DEFER tasks.
- Enforce managed ownership, collision prevention, and evidence-based
  environment readiness.
- Emit aggregate and projection schemas without invoking Dataverse or build
  stages.
- Prove industry neutrality with unrelated data-only acceptance fixtures.
- Preserve an independent Fully Custom plan.

### FAST-007 - Local execution readiness (completed)

- Evaluate approved decisions and pinned plans with external local evidence,
  not a handoff to execution stages.
- Bind decision/plan/evidence/inputs/target with SHA-256; validate canonical IDs,
  fingerprints, the full independently supplied target identity, and the hard
  maximum 24-hour evidence lifetime using an explicit evaluation clock.
- Emit six fail-closed statuses with `executionAuthorized: false` always.
- Add an early-return readiness-only orchestrator branch and independently
  block FAST-dependent Apply; preserve legacy/Fully Custom normal builds.
- Keep approval/authorization records and execution out of scope; see ADR 0010.

## Testing strategy

### Credential-free

- source fixtures and front-matter parsing;
- pagination and coverage reconciliation;
- content-hash stability;
- schema validation;
- candidate rejection and promotion;
- rename/removal tombstones;
- dependency cycle/missing dependency/version conflict;
- strong/partial/zero/ambiguous matching;
- three-mode parity with FAST disabled;
- no-network startup and custom-only planning;
- prompt-injection strings treated as inert source data.

### Network integration

- Explicitly invoked source discovery against approved hosts;
- measured coverage and source-state evidence;
- no promotion without review;
- safe handling of rate limits, archive state, and unavailable sources.

### Package verification

- Offline inspection of explicitly obtained assets;
- hash and provenance recording;
- no execution or import;
- malformed/untrusted archive boundaries.

### Environment verification

FAST-003 implements live Level 2 inspection under the three-level contract in
[`environment-validation.md`](environment-validation.md). Level 2 uses
the shared authenticated Dataverse request conventions and an injectable
transport for credential-free tests. Real-environment execution is optional,
explicit, and read-only. Level 3 remains a separately authorized future
workflow, not an importer.

## Compatibility

- The three current modes remain unchanged.
- Existing scenarios without accelerator artifacts remain valid.
- Existing payload and build stages do not read catalog data.
- The provider flag defaults off until rollout approval.
- Custom-only behavior is the reference baseline.
- Existing scenario-scoped generated-artifact manifests remain authoritative
  for wizard-owned Dataverse artifacts.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Archived sources imply stale or unsupported content | Surface archive state, freshness, disclaimer, and last verification in every recommendation |
| Documentation and packages disagree | Reconcile sources and preserve separate evidence; package availability controls deployability |
| A package is available but target dependencies are unresolved | Record package-verified metadata while blocking environment compatibility claims and deployment |
| External content contains malicious instructions | Parse as data, use strict schemas, and never execute source text |
| Catalog silently changes resumed runs | Pin snapshot ID and source hashes per decision |
| FAST becomes coupled to the wizard | Provider registry, default-off flag, absent-provider tests, and no FAST imports in base consumers |
| Live crawl is partial | Candidate isolation, coverage thresholds, resumability, and last-known-good promotion |
| Licensing or retention uncertainty | Store metadata/extracts conservatively and require policy approval before committing snapshots/packages |

## FAST-001 deliverables

- [x] Remote baseline and restore evidence.
- [x] Disable, retirement, and rollback strategy.
- [x] Current architecture assessment.
- [x] Official-source research with explicit gaps.
- [x] Feature specification and acceptance criteria.
- [x] Implementation plan and milestones.
- [x] Ordered task list.
- [x] Catalog and decision contracts.
- [x] Provider, evidence/Core, and isolation ADRs.
- [ ] Architectural review approval.

## FAST-002 deliverables

- [x] Default-off provider registry and provider-neutral catalog functions.
- [x] Dynamic documentation and release discovery without module registration.
- [x] Encoded slash-tag and future-module fixtures.
- [x] Immutable, reproducible content-addressed snapshots and promotion pointer.
- [x] Offline package parser and normalized Core plus two specialty indexes.
- [x] Core four-dependency handling.
- [x] Level 1 compatibility and mockable Level 2 preflight.
- [x] Level 3 installation-verification plan with execution disabled.
- [x] Mandatory FAST-dependent build gate.
- [x] FAST-disabled runtime isolation regression test.
- [x] Architectural review approval.

## FAST-003 deliverables

- [x] Explicit, default-off live preflight entry point.
- [x] Reuse authenticated environment/token refresh conventions.
- [x] Identity, organization version, solution, publisher, and table evidence.
- [x] Core and specialty dependency-component verification.
- [x] Core installed/missing/incompatible/inaccessible classifications.
- [x] Versioned schema-valid report with recommended next action.
- [x] Bounded timeouts, retry/backoff, grouped reads, and local evidence cache.
- [x] Cache invalidation for environment, catalog, package, dependency, and TTL.
- [x] Mocked authentication, permission, throttling, timeout, and nonmutation
  tests.
- [x] Architectural review approval.

## FAST-003A validation deliverables

- [x] Discover GCC targets from existing PAC `UsGov` profiles.
- [x] Require explicit confirmation before Dataverse Web API access.
- [x] Validate the selected `crm9.dynamics.com` environment with a
  resource-scoped token.
- [x] Execute and measure forced-refresh and cache-hit paths.
- [x] Correct live API discrepancies and add mocked regression coverage.
- [x] Record a sanitized readiness report with no tenant, user, or token
  identifiers.
- [x] Keep the FAST build gate closed because Core is missing.
- [x] Architectural review approval.

## FAST-004 deliverables

- [x] Provider-neutral local requirements-analysis service.
- [x] Explicit standalone entry point with opt-in enable switch.
- [x] Stable natural-language and structured requirement normalization.
- [x] Evidence-grounded documented matching and package component correlation.
- [x] REUSE, EXTEND, BUILD, INTEGRATE, and VERIFY delta decisions.
- [x] Transitive dependency grouping, deduplication, cycle detection, and
  fail-closed unresolved/version handling.
- [x] Optional FAST-003 evidence consumption without a live connection.
- [x] FAST-based, Hybrid, and Fully Custom recommendations.
- [x] Versioned schema plus structured Spec Kit artifact projections.
- [x] Representative offline acceptance scenarios and deterministic reruns.
- [x] FAST-disabled, no-network, no-Dataverse, and wizard-isolation proof.
- [x] Architectural review approval before FAST-005.

## FAST-005 deliverables

- [x] Default-off profile contract and `FAST_ENABLED`/explicit-switch opt-in.
- [x] Common post-discovery/pre-finalization integration for all three modes.
- [x] Demo Builder six-question budget plus one consolidated architecture
  approval.
- [x] Advanced and Framework requirement-level evidence presentation.
- [x] Explicit FAST-based, Hybrid, or Fully Custom selection.
- [x] Stable schema-valid architecture decision with package versions/hashes.
- [x] Scenario-scoped analysis, coverage, delta, dependency, readiness,
  recommendation, ADR, decision, and traceability artifacts.
- [x] Decision-change approval gate and deterministic rerun behavior.
- [x] Catalog-unavailable fallback to the existing Fully Custom workflow.
- [x] Missing/stale GCC evidence blocks FAST execution without blocking
  planning.
- [x] No Dataverse transport, import, build-stage registration, or fourth mode.
- [ ] Architectural review approval before FAST-006.

## FAST-005B implementation plan

1. Add a schema-valid preliminary preference record and expose it after mode
   selection only for explicitly enabled controlled runs.
2. Split explicitly listed workflow needs into stable requirement records
   without inferring requirements absent from discovery.
3. Correct the PowerShell renderer collision with the automatic `$input`
   variable and validate schema values across all generated planning files.
4. Replace ambiguous nested command-line package arrays with a validated
   package manifest while retaining direct arrays for in-process callers.
5. Sanitize generated Markdown at the source before writing.
6. Repeat Demo Builder, Advanced Builder, and Framework Acceptance fraud
   scenarios; prove stable artifacts, decision-change approval, missing-Core
   blocking, and no Dataverse transport.
7. Update the profile, contract, Spec Kit, canonical docs, distributed skills,
   and regression suites before committing and pushing.

The preference artifact remains separate from the analysis manifest because it
records user intent before analysis rather than evidence produced by analysis.
The final decision continues to pin the analysis and package identities.

## Stop condition

Historical FAST-005B/FAST-006 stop conditions are superseded only by the
authorized FAST-007 local readiness scope below. Package installation,
Dataverse mutation, and execution rollout remain unauthorized.

## FAST-007 completion and current stop condition

Implemented and validated local-only readiness through
`execution-readiness.ps1`, `invoke-execution-readiness.ps1`, and the
orchestrator's `-ExecutionReadinessOnly` early return. The implementation
requires independent environment URL, environment ID, and tenant ID,
schema-valid externally supplied evidence,
approved decision/plan/input integrity, and deterministic evaluation. No live
authentication or platform-provenance verification is included. The
`build-authorization.schema.json` contract is future-only; neither approvals
nor authorization records are generated or consumed.

Follow [ADR 0010](adrs/0010-local-execution-readiness.md) and
[the operational guide](../../docs/fast-integration/execution-readiness.md).
Implementation planning and synthetic evidence belong to
`specs/fast-007-execution-readiness/`. The authoritative
[validation evidence](../fast-007-execution-readiness/evidence/fast-007-validation.md)
records completed readiness and regression validation, including the
historical smoke-test and aggregate-runner parser failures and the isolated
formatter rerun. Runtime readiness integration is complete, not pending.
Completion does not establish live readiness or approval to execute.

Stop after FAST-007 review handoff. FAST-008 is proposed only: trusted evidence
collection, independent approver/signature verification, authorization
consumption/revalidation, and a separately approved executor design require
further authorization.

## Milestone supersession: FAST-008A (2026-10-19)

The earlier proposed-only trusted-collection plan is superseded within the
bounded [FAST-008A plan](../fast-008a-trusted-environment-verification/plan.md).
Reuse the inspector/shared Dataverse runtime and FAST-006/007 planning/readiness
contracts; add GET-only collection, external X509 RS256 signing and independent
public-certificate validation. Bind exact decision bytes, plan ID/SHA,
catalog/dependency/input/package hashes, actual authenticated identity,
classified observations, collection mode and expiry. Require certificate
validity at collection and evaluation; never trust an embedded key.

Collection defaults Mock with injected test transport. Live rejects injected
transport and requires explicit target/read-only scope, existing credentials
and an operator-provided signing certificate, with no `.env` fallback or
persisted credentials. Authenticated is the default readiness policy; explicit
RecordedTest and LocalPlanning retain diagnostics without verified review
eligibility or writes. Preserve early-return preflight, global FAST-dependent
Apply block, normal Fully Custom behavior and default-off settings in all modes.
See [ADR 0011](adrs/0011-trusted-environment-verification.md) and
[trusted verification operations](../../docs/fast-integration/trusted-environment-verification.md).
Validation is mock-only; parent milestone evidence records actual results.
Future controlled execution, deployment approvals/signatures, scope checks
and revalidation require separate authorization; stop at human review.
