# ADR 0006: Evidence-Grounded Requirements Analysis

**Status:** Accepted for FAST-004
**Date:** 2026-10-15

## Context

The catalog and package indexes contain two different kinds of evidence:
documentation describes intended capabilities, while package inspection proves
that physical Dataverse components exist. Neither component-name similarity nor
package availability alone proves that a business process is supported.
Environment readiness is also distinct from architectural suitability.

## Decision

Implement a provider-neutral, deterministic requirements-analysis service that
runs independently from wizard UI and Dataverse execution.

The service normalizes natural-language and structured requirements to stable
IDs. It first requires documented functional relevance, then independently
correlates package-verified tables, attributes, relationships, Choices, forms,
views, and applications. Results use explainable ordinal evidence bands rather
than arbitrary numeric confidence scores.

Each requirement receives one or more REUSE, EXTEND, BUILD, INTEGRATE, or
VERIFY dispositions with evidence references, gaps, component-level deltas,
dependencies, effort assumptions, risks, acceptance criteria, and task
references. Package component names alone cannot establish functional coverage.

Dependencies are resolved transitively from package metadata, deduplicated by
source module and physical component identity, and grouped separately at module
level. Cycles, unresolved dependencies, and version differences without an
explicit compatibility policy close the FAST-dependent execution gate.

Optional FAST-003 evidence is referenced but never refreshed automatically.
Architectural matching continues when Core is missing; FAST-dependent execution
does not. FAST-based, Hybrid, and Fully Custom alternatives are emitted, the
fully custom option is always retained, and final selection remains a user
decision.

## Consequences

- New catalog modules participate without matcher registration.
- Documented-only or unavailable evidence fails closed to VERIFY.
- Missing GCC Core blocks execution but not requirements analysis.
- Identical inputs produce stable requirement and analysis identities.
- Generated analysis artifacts are planning evidence, not deployment
  authorization.
- The matcher adds no wizard stage, mandatory question, network dependency,
  Dataverse request, or mutation path.

## Rejected alternatives

- **Keyword counts or opaque confidence scores:** not sufficiently explainable
  and can overstate business-process coverage.
- **Treat package tables as capabilities:** confuses physical existence with
  functional behavior.
- **Require live preflight for matching:** makes architecture exploration
  unavailable offline and couples custom planning to FAST.
- **Automatically choose FAST when relevant:** removes required user control
  and ignores dependency and environment risk.
