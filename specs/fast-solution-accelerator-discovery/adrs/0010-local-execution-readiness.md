# ADR 0010: Local-Only Execution Readiness

**Status:** Accepted for authorized FAST-007 scope
**Date:** 2026-10-19

## Context

FAST-006 produces provider-neutral dry-run plans, not executable authorization.
Operators need a bounded, reproducible assessment of approved plans and
externally supplied evidence without connecting the planner to Dataverse
execution. Historical stop conditions must not be interpreted as either
forbidding the separately authorized local assessment or authorizing execution.

## Decision

Add `execution-readiness.ps1` and the explicit default-off CLI
`invoke-execution-readiness.ps1`. Require scenario, evidence path, independent
environment URL/environment ID/tenant ID. Allow optional workspace root,
output folder, and an explicit deterministic UTC evaluation time.

The engine:

- reads the approved scenario-local `accelerator/accelerator-decision.json`
  and `accelerator/build-plan/build-plan-manifest.json`;
- verifies file SHA-256, canonical decision/plan IDs, and input fingerprints;
- validates externally supplied local evidence against
  `execution-evidence.schema.json`, compares the full independently supplied
  target triple exactly (URL normalized), and enforces a hard maximum
  evidence lifetime of 24 hours;
- produces `execution-readiness.json` under
  `execution-readiness.schema.json` with `READY_FOR_APPROVAL`,
  `BLOCKED_PREREQUISITES`, `BLOCKED_EVIDENCE`, `BLOCKED_COMPATIBILITY`,
  `BLOCKED_SECURITY`, or `BLOCKED_DECISION_CHANGE`;
- always sets `executionAuthorized` to false, including when ready for human
  review;
- binds decision, plan, evidence, inputs, and target in a SHA-256 scope;
- never generates or consumes approval or authorization records;
  `build-authorization.schema.json` is a future contract only.

Add `90-run-build.ps1 -ExecutionReadinessOnly` with external evidence, explicit
readiness environment/tenant IDs, and optional readiness evaluation time. It
returns before helpers, stages, or payload requirements; Apply combined with
preflight is forbidden. Independently reject normal Apply for approved
`selectedOption` values `fast-based` and `hybrid`, regardless of readiness.
Preserve legacy/Fully Custom normal builds and FAST default-off in all modes.

No Dataverse, PAC, network, authentication, installation, import, or build
execution occurs in readiness. Local evidence is not live platform-provenance
verification.

## Consequences

- A ready report means human review only, never approval or permission to run.
- Hashes and fingerprints detect local changes; they do not establish the
  trustworthiness of an external evidence producer.
- An explicit evaluation clock supports deterministic synthetic checks, not
  claims of current live readiness.
- Historical FAST-005B/FAST-006 stop conditions are superseded only for this
  authorized FAST-007 scope. Stop after its review handoff.
- FAST-008 is proposed, not implemented: trusted evidence collection,
  independent approver/signature verification, authorization consumption and
  revalidation, and a separately approved executor design require separate
  authorization.

Operational details are in
[`docs/fast-integration/execution-readiness.md`](../../../docs/fast-integration/execution-readiness.md).
