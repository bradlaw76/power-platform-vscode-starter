# FAST-008A Trusted Environment Verification

**Baseline:** `0d1812b9acea61afa750883422d88807f48b4f1d`

## Outcome and boundaries

Obtain authenticated, GET-only Dataverse verification and bind it to the
approved architecture, immutable plan, selected packages, catalog snapshot,
dependency manifest, actual environment and authenticated principal.
Readiness remains human review only. No executor, installation, import,
permission grant, deployment approval or authorization issuer is permitted.

## Requirements

- Reuse FAST-003 inspection, FAST-006 planning and FAST-007 validation.
- Independently verify environment ID and tenant using
  `RetrieveCurrentOrganization`; do not confuse organization ID with environment
  ID or accept caller-supplied tenant as server evidence.
- Record verified, missing, inaccessible, unsupported and inferred information
  distinctly. Incomplete inspection cannot produce verified review eligibility.
- Verify installed solutions/versions, transitive dependencies, concrete
  component names, managed restrictions, solution/publisher membership and
  relevant effective privileges where supported.
- Sign evidence with an operator-provided certificate; validate using a
  separately trusted certificate, never a key embedded in the evidence.
- Bind all material input hashes and expiration; persist no credentials.
- Mock/recorded evidence must never masquerade as live authenticated evidence.
- Require explicit target and read-only scope opt-in before live collection.
  Do not use stored GCC evidence or environment files to choose a target.
- Preserve all wizard modes, default-off FAST and the ordinary Fully Custom
  build pipeline. Keep FAST-dependent Apply disabled.
- Correct the two isolated historical quality defects with focused regression
  checks. Document OneDrive cleanup contention separately.

## Acceptance

Mock unrelated Fully Custom and accelerator applications, installed/missing/
wrong-version solutions, stale or tampered evidence, environment mismatches,
missing permissions, managed restrictions, unavailable credentials and incomplete
dependencies. Run existing offline regression/security suites. No live GCC query
is authorized by this milestone.
