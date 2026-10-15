# ADR 0004: Environment Preflight Before FAST-Dependent Generation

**Status:** Accepted for FAST-002
**Date:** 2026-10-15

## Context

Package inspection proves the contents and declared dependencies of a specific
solution archive. It does not prove that a target Dataverse environment has the
required solutions, components, versions, permissions, policies, or current
service conditions.

## Decision

Use three evidence levels:

1. credential-free catalog compatibility;
2. read-only environment preflight;
3. approved installation verification.

Requirements analysis may run with Level 1 evidence. FAST-dependent Dataverse
generation requires fresh `ready` Level 2 or Level 3 evidence matching the
catalog snapshot, selected environment, and selected package IDs and hashes.
Any mismatch or expiry requires revalidation. Fully custom architecture bypasses
this FAST-specific gate.

FAST-002 implements Level 1 and a transport-neutral, mockable Level 2
evaluator. It defines Level 3 as an unauthorized, unimplemented workflow plan.

## Consequences

- Package availability is never reported as environment compatibility.
- Environment changes and stale evidence fail closed.
- Users may decline or remain offline and continue requirements analysis.
- Future installation work must verify Core before specialty modules.
- Existing wizard modes and runtime stages remain unchanged until separately
  authorized integration.

## Rejected alternatives

- **Assume package metadata predicts import success:** ignores environment
  state and undisclosed runtime conditions.
- **Connect during normal discovery:** adds mandatory FAST friction and
  violates custom-only independence.
- **Allow stale evidence:** risks building against a changed environment or
  package set.
