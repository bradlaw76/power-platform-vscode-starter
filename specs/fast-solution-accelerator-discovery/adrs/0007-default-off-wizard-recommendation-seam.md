# ADR 0007: Default-Off Wizard Recommendation Seam

**Status:** Accepted for FAST-005
**Date:** 2026-10-15

## Context

FAST-004 can produce deterministic requirements coverage and architecture
options, but it was deliberately disconnected from the wizard. Integration
must occur only after the existing business requirements are collected and
before architecture is finalized, without changing the discovery contract or
authorizing Dataverse work.

## Decision

Add one provider-neutral integration seam to `05-start-wizard.ps1` after common
mode-specific discovery and before planning files are rendered.

The seam is disabled by default. Controlled runs use either
`-EnableAcceleratorRecommendations` or `FAST_ENABLED=true` and provide local
catalog, package, and optional environment-evidence paths.

Demo Builder retains six business questions and uses its existing seventh
consolidated approval to select FAST-based, Hybrid, or Fully Custom
architecture. Advanced Builder and Framework Acceptance retain their existing
questions and add an architecture decision only after discovery.

Enabled runs write the FAST-004 artifacts plus a schema-valid explicit decision
under `specs/<scenario>/accelerator/`. The decision pins analysis and snapshot
identities, package versions and hashes, readiness, recommendation, user
selection, rationale, and execution gates. A changed decision ID requires
`-ApproveAcceleratorDecisionChange`.

Catalog absence fails safely to Fully Custom. Environment evidence is consumed
locally and never refreshed automatically. FAST-based or Hybrid selection does
not open execution unless matching readiness evidence is fresh and ready.

## Consequences

- Disabled runs emit no accelerator section or artifact.
- Existing custom-only generation remains unchanged.
- No fourth mode or mandatory discovery question is introduced.
- The current missing-Core GCC environment supports analysis but not
  FAST-dependent execution.
- The planning seam has no PAC, HTTP, Dataverse, import, or build-stage call.
- Build integration, installation, and rollout remain deferred to FAST-006.

## Rejected alternatives

- **Upfront accelerator selection:** requires users to understand FAST before
  describing their problem.
- **New Demo Builder question:** violates the established question budget.
- **Automatic acceptance of the recommendation:** removes user control.
- **Registering with the build orchestrator:** exceeds planning-only FAST-005
  scope and could imply mutation authority.
