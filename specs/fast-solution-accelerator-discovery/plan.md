# FAST Solution Accelerator Discovery Plan

**Status:** FAST-005 implemented; architectural review required
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

### FAST-006 - Failure, rollback, and release

- Disabled, absent-provider, outage, retirement, and rollback matrices.
- Repeated-run and snapshot pinning.
- Security review.
- Controlled rollout and documentation parity.

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

## Stop condition

Stop after FAST-005 review handoff. Do not begin FAST-006 build integration,
package installation, Dataverse mutation, or rollout without further
authorization.
