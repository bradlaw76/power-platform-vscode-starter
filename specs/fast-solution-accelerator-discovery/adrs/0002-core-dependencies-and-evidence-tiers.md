# ADR 0002: Core Dependencies and Evidence Tiers

**Status:** Proposed  
**Date:** 2026-10-15

## Context

FAST documentation requires Core before specialty modules. The corrected source
review followed the official Core module-page link to `core/v1.2.1.0`, verified
the managed package digest, and extracted its physical metadata. The package
declares four external dependencies, while actual target environments remain
uninspected. Documentation, source, packages, and installed environments
therefore still provide different levels of evidence.

## Decision

Represent dependencies as evidence-carrying DAG edges. Represent component and
schema claims using three tiers:

1. conceptual;
2. package-verified;
3. environment-verified.

Core-first documentation creates a conceptual dependency. The inspected
`1.2.1.0` package adds package-verified solution, schema, component, and
dependency evidence for that release only. FAST-dependent deployment planning
remains blocked until the selected version and its dependencies are compatible
with an authorized target environment. Fully custom wizard solutions do not
require Core, and `1.2.1.0` is not a permanent version requirement.

## Consequences

- Matching can identify relevant FAST concepts even when deployment is blocked.
- Package metadata can be indexed offline without importing the solution.
- Exact logical names and types cannot be generated from prose or diagrams.
- Dependency resolution can explain whether a failure is functional,
  packaging-related, or environment-specific.
- Package inspection and environment inspection require later, separately
  approved phases.

## Rejected alternatives

- **Trust documentation as physical schema:** risks invalid or destructive
  payload generation.
- **Treat missing package as missing capability:** confuses unavailable evidence
  with absence.
- **Require Core for every wizard solution:** breaks custom-only independence.
- **Flatten dependencies to a list:** cannot detect cycles, ordering, or version
  conflicts.
