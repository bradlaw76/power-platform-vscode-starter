# FAST Solution Accelerator Discovery

**Feature ID:** FAST-ACCELERATOR-DISCOVERY  
**Instruction:** FAST-IMPLEMENTATION-001  
**Status:** FAST-002 implemented; architectural review required
**Phase boundary:** Stop after FAST-002

## Problem statement

The wizard can design custom model-driven Power Apps and Dynamics 365
extensions, but it does not evaluate reusable solution accelerators. Makers may
duplicate relevant FAST reference implementations or, conversely, assume a
documented module is deployable without verifying its package, dependencies,
maintenance state, or environment compatibility.

The wizard needs an optional, explainable accelerator-evaluation capability
after business requirements are understood and before architecture is finalized.
FAST is the first provider, not a mandatory platform dependency.

## Constitutional principle

> The Solution Builder shall evaluate relevant reusable solution accelerators
> after requirements discovery and before architecture finalization. It shall
> recommend reuse when justified by functional fit, validated dependencies, and
> environment compatibility, while preserving user choice and the ability to
> generate a fully custom solution. Discovery of an accelerator must not be
> interpreted as authorization to deploy or modify it.

This principle is proposed for review. FAST-001 does not silently amend the
repository-level specification or active wizard contract.

## Goals

1. Discover FAST content without hardcoded module or use-case lists.
2. Normalize modules, use cases, personas, dependencies, data-model evidence,
   and releases into immutable catalog snapshots.
3. Distinguish documentation claims from package-verified and
   environment-verified metadata.
4. Match normalized requirements to accelerators with per-requirement evidence
   and gaps.
5. Offer FAST foundation, hybrid, or fully custom architecture choices without
   changing the three wizard modes.
6. Preserve custom-only behavior when FAST is disabled, absent, unavailable,
   retired, or rejected.
7. Prevent catalog discovery from authorizing Dataverse changes or package
   installation.

## Non-goals

- Implementing the crawler, catalog store, matching engine, UI, or generator in
  FAST-001.
- Installing FAST Core or any specialty module.
- Connecting to or modifying a Dataverse environment.
- Treating reference implementations as supported production products.
- Inferring exact Dataverse schema from prose, screenshots, or ERDs.
- Adding a fourth wizard mode.
- Changing the active build order, profile contract, or script stages.
- Automatically committing live external content or release packages.

## Users and outcomes

| User | Need | Expected outcome |
| --- | --- | --- |
| Demo maker | Know whether FAST can accelerate a scenario | Concise, cited recommendation without extra questions when FAST is irrelevant |
| Solution architect | Compare reuse, extension, integration, and custom work | Requirement-level matrix, dependency graph, evidence tiers, gaps, and risks |
| Framework maintainer | Prove provider isolation and deterministic behavior | Fixture-driven sync/matching tests and disabled/offline parity |
| Environment owner | Avoid unauthorized installation or mutation | Separate compatibility/installation plan and explicit approval gate |
| Reviewer | Reproduce why a recommendation was made | Pinned snapshot, source hashes, citations, confidence, and ADR |

## Functional requirements

### FR-001 Provider isolation

The base wizard shall depend on provider-neutral accelerator contracts. FAST
shall be registered through an optional provider assembly. Missing or failed
FAST loading shall not prevent normal wizard startup or custom-only planning.

### FR-002 Capability flag

`FAST_ENABLED` shall default to disabled until the runtime capability is
approved. Disabled mode shall bypass provider loading, synchronization, FAST
network calls, matching, recommendation UX, scheduling, and FAST-dependent
generation.

### FR-003 Dynamic source discovery

The FAST provider shall enumerate current source collections dynamically from
authoritative repository structure and configuration. It shall not rely on
hardcoded module names, use-case names, counts, or per-module URLs.

The initial source policy shall distinguish:

- GitHub source collections for breadth and front matter;
- official release links discovered from every module page and front-matter
  record, including URL-encoded tags containing `/`;
- module source directories and generated statistics for structural evidence;
- GitHub Releases and tags for package availability;
- rendered Microsoft documentation for narrative guidance;
- diagrams and ERDs as conceptual evidence unless a stronger source verifies
  exact schema.

### FR-004 Snapshot lifecycle

Synchronization shall create a candidate snapshot and never mutate the
promoted snapshot in place. A candidate must pass source coverage, schema,
dependency, provenance, and completeness validation before promotion.

Every snapshot shall record:

- provider and schema version;
- snapshot ID and content hash;
- source repository archival/maintenance state;
- source URLs, commit SHAs or ETags, retrieval timestamps, and content hashes;
- collection coverage and exceptions;
- package/release verification results;
- documented release links and their reconciliation with release API assets,
  source artifacts, and inspected package metadata;
- validation and promotion status;
- previous promoted snapshot.

### FR-005 Failure-safe synchronization

A partial crawl, timeout, malformed source, rate limit, broken link, or schema
failure shall not replace the last known-good snapshot. Removed items shall be
tombstoned for review rather than silently deleted.

### FR-006 Evidence tiers

Every capability and data-model claim shall carry one of these levels:

1. `conceptual`: supported by documentation, prose, or diagrams;
2. `package-verified`: proven from an identified solution package;
3. `environment-verified`: proven from an expressly authorized target
   environment at execution time.

Missing evidence shall be `unverified`, not `absent`.

### FR-007 Core and module dependencies

Module dependencies shall form a directed acyclic graph. Core-first
requirements shall be derived from authoritative metadata and validated
package dependencies. Cycles, missing required modules, incompatible versions,
and unavailable packages shall block FAST-dependent deployment planning.

Core is not required for fully custom wizard solutions. A package-verified Core
release may support physical metadata indexing, but target deployment remains
blocked until the selected version, declared dependencies, and environment
compatibility are verified. No observed Core version is a permanent requirement
or upper limit.

### FR-008 Requirements matching

The evaluator shall normalize requirements to stable IDs with actors,
workflows, entities, relationships, acceptance criteria, integrations,
security, and nonfunctional constraints.

Each requirement shall receive one decision:

- `reuse`
- `extend`
- `build-new`
- `integrate`
- `verify`
- `not-applicable`

Every decision shall include the candidate module/component, source citation,
evidence tier, confidence, gaps, constraints, dependency implications, and
estimated customization class.

### FR-009 Architecture options

The evaluator shall produce FAST foundation, hybrid, and fully custom options
when evidence supports them. It shall state rationale, reusable components,
unverified assumptions, missing packages, maintenance risk, and residual custom
work. Explicit custom-only preference shall override a match score.

### FR-010 Mode behavior

- Demo Builder: matching is invisible until a credible result exists; at most
  one concise choice is shown.
- Advanced Builder: exposes detailed module, dependency, evidence, version,
  compatibility, and override information.
- Framework Acceptance: validates sync, promotion, matching, dependency,
  disabled/offline, repeat-run, and rollback behavior.

All modes shall continue producing compatible existing planning artifacts.

### FR-011 Decision persistence

The selected option, rejected alternatives, provider, snapshot ID, module
versions, evidence links, assumptions, and user rationale shall be persisted in
an ADR and a machine-readable accelerator decision contract.

### FR-012 No implicit deployment

Discovery, synchronization, matching, and recommendation shall be read-only.
Selecting FAST shall create a prerequisite and compatibility plan. It shall not
download packages, authenticate to Dataverse, import solutions, alter metadata,
or deploy.

### FR-013 Retirement and rollback

The system shall support provider disable, provider removal, source retirement,
catalog rollback, code rollback, and historic artifact retention independently.
Managed-solution uninstall is explicitly outside automated rollback.

### FR-014 Environment compatibility and build gate

Compatibility shall use three distinct levels:

1. credential-free catalog compatibility;
2. read-only environment preflight;
3. explicitly approved installation verification.

Requirements analysis may continue with an unverified environment.
FAST-dependent Dataverse generation shall remain blocked until fresh `ready`
Level 2 or Level 3 evidence matches the selected snapshot, environment, package
IDs, versions, and hashes. A fully custom architecture does not require FAST
evidence. The complete contract is in
[`environment-validation.md`](environment-validation.md).

## Security and compliance requirements

1. Restrict fetches to configured HTTPS hosts and approved repository owners.
2. Resolve and validate redirects; block loopback, private, link-local, and
   metadata-service destinations.
3. Apply timeouts, size limits, content-type allowlists, pagination limits,
   retry/backoff, and per-source error reporting.
4. Treat external text as untrusted data, never executable agent instructions.
5. Do not send customer requirements to FAST or arbitrary third-party services.
6. Keep packages outside automatic execution and verify hashes/signatures where
   available before inspection.
7. Record source license and retention policy for stored content.
8. Redact credentials and avoid storing authenticated URLs or tokens.

## Nonfunctional requirements

- Deterministic: identical inputs and snapshot produce identical decisions.
- Idempotent: repeated sync of unchanged sources produces no duplicate records.
- Explainable: every recommendation maps to requirement IDs and source evidence.
- Resumable: interrupted synchronization can continue without corrupting the
  promoted snapshot.
- Bounded: crawling and indexing enforce explicit resource limits.
- Testable offline: fixtures cover sync, validation, dependency, and matching.
- Backward compatible: disabling or removing FAST preserves baseline behavior.

## Acceptance criteria

### Catalog

- A new source module appears in a candidate snapshot without a code change.
- Unchanged repeated sync produces the same content hash and no duplicates.
- Missing, renamed, and removed pages generate reviewed diffs/tombstones.
- A partial or invalid crawl cannot replace the promoted snapshot.
- Snapshot coverage reports reconcile documentation, source, statistics, and
  release breadth rather than claiming false completeness.

### Dependencies and evidence

- Core-first metadata creates dependency edges but does not claim deployability
  without a verified package.
- Dependency cycles and unavailable required packages block FAST-dependent
  deployment planning.
- Conceptual fields cannot be emitted as executable Dataverse schema.
- Package and environment verification can strengthen evidence without
  overwriting the original conceptual provenance.

### Matching

- Strong, partial, zero, ambiguous, overlapping-module, outdated-snapshot, and
  unverifiable-capability fixtures produce expected decisions.
- Every matched requirement has evidence, confidence, gap, and dependency data.
- A zero match continues custom-only without an additional question.
- A user custom-only override is persisted and honored.

### Compatibility and rollback

- Demo Builder, Advanced Builder, and Framework Acceptance remain the only
  modes.
- FAST disabled, provider absent, source outage, source retired, and code
  rollback scenarios preserve custom-only behavior.
- Existing scenario runs stay pinned to their selected snapshot.
- No FAST test imports or uninstalls a Dataverse solution.
- Core and two specialty packages are indexed offline without deployment.
- Ready, missing-dependency, incompatible, stale, offline, and user-declined
  environment evidence produce explicit compatibility outcomes.
- Changing the environment, catalog snapshot, package version/hash, or evidence
  validity closes the FAST-dependent build gate.

## FAST-002 implementation boundary

FAST-002 provides an explicit, default-off catalog synchronization command,
offline package inspection, immutable snapshots, and transport-neutral
environment compatibility evaluation. It is not wired into wizard discovery,
planning, or build stages and has no Dataverse transport or import capability.
FAST-003 and runtime integration require separate authorization.
