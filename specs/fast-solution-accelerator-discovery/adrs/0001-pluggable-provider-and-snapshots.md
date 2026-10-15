# ADR 0001: Pluggable Accelerator Providers and Immutable Snapshots

**Status:** Proposed  
**Date:** 2026-10-15

## Context

The wizard needs accelerator evaluation without making FAST a mandatory
dependency. FAST sources can be incomplete, unavailable, archived, or
internally inconsistent. Existing and resumed scenarios must remain
reproducible.

## Decision

Introduce a provider-neutral accelerator registry. FAST is an optional provider
assembly registered only when enabled. Providers synchronize into candidate
snapshots. Only immutable, validated, promoted snapshots can be queried by
matching. Scenario decisions pin a snapshot ID and source hashes.

The generated Dataverse artifact manifest remains separate from catalog
provenance.

## Consequences

- The base wizard operates with an empty provider registry.
- FAST can be removed without changing consumer code.
- Failed or partial sync cannot corrupt the active catalog.
- Resumed runs do not silently adopt a newer catalog.
- Storage, promotion, retention, and migration policies are required.
- Live-source freshness is visible but does not override reproducibility.

## Rejected alternatives

- **Direct live-site matching:** not reproducible and fails during source
  outages.
- **Hardcoded module list:** cannot discover additions or reconcile source
  differences.
- **FAST types in the core wizard:** prevents clean provider removal.
- **Catalog content in the Dataverse artifact manifest:** conflates external
  evidence with wizard-owned environment artifacts.

