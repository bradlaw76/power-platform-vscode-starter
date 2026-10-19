# FAST-007 Implementation Plan

## Architecture

1. Add strict version-1 local evidence, readiness report and future authorization
   JSON schemas under `schemas/accelerators/`.
2. Reuse the FAST-006 canonical hashing, decision validation and graph helpers.
   Independently verify the FAST-006 identity basis and exact file SHA-256.
3. Consume scenario-local approved decision, plan, pinned planning inputs and
   externally supplied environment/dependency/ownership/security evidence.
   Evidence is an assertion, not independently authenticated platform proof.
4. Validate fail-closed with all actionable findings and one primary status,
   ordered decision change, evidence, compatibility, security, prerequisites.
5. Bind decision bytes, plan bytes, evidence bytes, target environment and all
   pinned input hashes into a deterministic authorization scope digest.
6. Return reports only. Add an explicit preflight-only branch before orchestrator
   initialization; permanently block FAST-dependent Apply in this milestone.
7. Add deterministic cross-domain samples and negative tests, then update the
   README enhancement checklist surfaces, skills, contracts and evidence.
8. Run credential-free regressions, review scoped changes, commit and push only
   `feature/fast-accelerator-catalog`, and verify the remote commit.

## Boundaries

No build stage, package installation, Dataverse call, approval issuer,
authorization issuer, signature trust service or executor is introduced.
Fully Custom readiness still requires target and permission evidence, but never
inherits FAST packages or accelerator environment prerequisites.
