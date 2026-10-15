# FAST Solution Accelerator Discovery Plan

**Status:** Proposed for architectural review  
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

- Provider contracts and registry.
- FAST source adapter.
- Automatic official module-page release-link discovery.
- Catalog JSON schemas.
- Fixture-based parsing.
- Cross-source reconciliation for documentation, releases, source, and
  package-inspected metadata.
- Candidate snapshot, validation, diff, and promotion.
- No wizard UX and no Dataverse access.

### FAST-003 - Dependency and physical metadata

- Core and specialty dependency graph.
- Package inventory and safe offline package inspection.
- Evidence-tier promotion.
- Compatibility matrix contract.
- No automatic import.

### FAST-004 - Matching and delta planning

- Requirement normalization.
- Deterministic retrieval and optional local semantic index.
- Per-requirement classification.
- Architecture alternatives and ADR generation.
- Golden matching fixtures.

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

Deferred to an approved development or sandbox environment. It is not part of
FAST-001 and requires separate authorization.

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

## Stop condition

Stop after review handoff. Do not implement provider interfaces, crawlers,
schemas, scheduling, matching logic, wizard prompts, or Dataverse behavior
until FAST-002 is explicitly approved.
