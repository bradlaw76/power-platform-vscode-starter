# FAST-007 Implementation and Validation Evidence

**Date:** 2026-10-19

**Branch:** `feature/fast-accelerator-catalog`

**Verified starting commit:** `8ec29edc23e136354ea31ace6dc88a5b0b359a32`

**Boundary:** Local files only; no Dataverse or PAC invocation, package install,
solution import, build execution, approval issuance or authorization issuance.

## Implemented architecture

- [Readiness engine](../../../scripts/accelerators/execution-readiness.ps1):
  checks canonical architecture and FAST-006 plan identities, exact file
  SHA-256, every pinned planning input, bidirectional requirement/task/acceptance
  coverage, component and package dependency graphs, ownership/customization
  restrictions, and per-operation permission evidence.
- [Explicit CLI](../../../scripts/accelerators/invoke-execution-readiness.ps1):
  default-off, deterministic with an explicit evaluation clock, writes only
  the schema-validated readiness artifact.
- [Orchestrator](../../../scripts/bootstrap/90-run-build.ps1):
  `-ExecutionReadinessOnly` returns before runtime helpers, payload checks,
  run-state initialization or stages. Apply rejects FAST-dependent decisions
  **or plans**, including a plan whose decision file is missing. Ordinary
  Fully Custom and legacy builds retain their existing behavior.
- [Evidence schema](../../../schemas/accelerators/execution-evidence.schema.json),
  [readiness schema](../../../schemas/accelerators/execution-readiness.schema.json)
  and [future authorization schema](../../../schemas/accelerators/build-authorization.schema.json):
  version 1.0. The last is a contract only, with no issuer or consumer.
- [ADR 0010](../../fast-solution-accelerator-discovery/adrs/0010-local-execution-readiness.md)
  records the review-only boundary. FAST-006 is not reimplemented.

The primary blocking status has deterministic precedence: decision change,
evidence, compatibility, security, prerequisites. All findings remain visible,
even when a higher-precedence status determines the report's primary status.
Every operation is blocked when any prerequisite fails. `READY_FOR_APPROVAL`
sets human-review eligibility only; execution remains false and authorized
operation categories remain empty.

Missing or malformed primary artifacts generate blocked reports. A missing
file has a null file digest, not a fabricated content hash. Invalid paths or
unreadable secondary evidence fail explicitly; they never become ready.

## New execution-readiness results

Command:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\ci\test-execution-readiness.ps1 `
  -SampleOutputFolder .\specs\fast-007-execution-readiness\evidence\samples
```

**129 assertions passed.** Four unrelated applications, 26 negative scenarios,
plus verified separate extensions, transitive package metadata/minimum versions,
dependency ordering, exact-byte plan binding, the precise 24-hour evidence
lifetime boundary, unavailable/malformed artifacts, clock expiry, default-off
behavior, a ready orchestrator hook, and missing-decision Apply rejection.

All 11 persisted samples were regenerated with **zero byte changes**. Samples
use synthetic identities, local fixtures, an explicit historical clock and
reserved example hosts. They are not live environment-readiness evidence.
Test fixtures describe approved architecture solely to exercise the planner;
they never generate deployment approval or build authorization records.

| Synthetic application or condition | Result | Sample |
| --- | --- | --- |
| Equipment maintenance, Fully Custom | READY_FOR_APPROVAL | [Report](samples/equipment-maintenance/execution-readiness.json) |
| Event registration, Fully Custom | READY_FOR_APPROVAL | [Report](samples/event-registration/execution-readiness.json) |
| Employee onboarding, Fully Custom | READY_FOR_APPROVAL | [Report](samples/employee-onboarding/execution-readiness.json) |
| Library circulation, Hybrid | READY_FOR_APPROVAL | [Report](samples/library-circulation-hybrid/execution-readiness.json) |
| Missing managed solution | BLOCKED_PREREQUISITES | [Report](samples/missing-prerequisites/execution-readiness.json) |
| Expired evidence | BLOCKED_EVIDENCE | [Report](samples/stale-evidence/execution-readiness.json) |
| Conflicting existing component | BLOCKED_COMPATIBILITY | [Report](samples/conflicting-components/execution-readiness.json) |
| Managed extension not customizable | BLOCKED_COMPATIBILITY | [Report](samples/managed-restricted/execution-readiness.json) |
| Missing customization permissions | BLOCKED_SECURITY | [Report](samples/missing-permissions/execution-readiness.json) |
| Unapproved architecture decision | BLOCKED_DECISION_CHANGE | [Report](samples/unauthorized-decision/execution-readiness.json) |
| Package SHA-256 changed | BLOCKED_DECISION_CHANGE | [Report](samples/changed-package/execution-readiness.json) |

Reports contain blocked operations, deterministic component/package ordering,
planned and observed component ownership, managed properties, security
requirements and acceptance traceability. Rejected operations include
duplicates, cycles, unresolved dependencies, unsupported actions, deferred
work, managed overwrites and CREATE against existing components.

## Regression results

All 34 existing/new standalone CI scripts were executed independently using
`pwsh -NoProfile -NonInteractive -File`, continuing after failures to obtain
complete results rather than stopping at the first historical failure.

| Check | Result |
| --- | --- |
| Standalone CI scripts | 33 passing after isolated formatter rerun; 1 historical smoke failure |
| Existing FAST catalog, matching, package indexing, environment, integration and build-planning suites | PASS |
| All three wizard modes and source-control acceptance | PASS |
| Schema, contract, docs, script order and Preview non-mutation | PASS |
| Idempotency/export, app rerun, solution/publish isolation and run-state security | PASS |
| Pester 5.7.1 runtime/security and skill parity | 107 passed, 0 failed, 0 skipped |
| PSScriptAnalyzer 1.24.0, full repository | 0 findings |
| Markdown lint, full repository | 0 errors |
| Scoped whitespace validation | PASS |
| PowerShell parsing | Only the historical aggregate-runner failure below |

The formatter's assertions passed in the OneDrive workspace, but its final
temporary-directory cleanup failed twice due to file locking. The identical
script, helpers, profile and schemas were copied to an isolated local temporary
workspace outside OneDrive: assertions and cleanup both passed, exit 0. That
workspace was removed. No formatter code was changed.

### Historical quality failure 1: aggregate runner parser

`run-quality.ps1:78` still fails PowerShell parsing because `$_:` is an invalid
variable reference. The aggregate runner cannot execute. Its quality stages
were run independently. This is the documented pre-FAST baseline defect,
not a FAST-007 failure.

### Historical quality failure 2: script smoke expectation

`test-script-smoke.ps1:24` still expects the absent text
`How long should the demo be, in minutes?`. This is the documented pre-FAST
baseline defect. It was not suppressed, modified or counted as passing.

## Authorization and managed-component safety findings

- Readiness never authorizes execution or generates a valid authorization.
- The future contract binds decision ID and exact bytes, plan ID and SHA-256,
  target environment/tenant/URL, operation categories, exact task scope,
  approver identity/evidence reference, approval time, expiry and prerequisite
  evidence/input hashes.
- The scope SHA-256 changes with architecture, plan bytes, environment,
  planning inputs, dependency metadata, package identities or evidence changes.
  Previous-scope authorization cannot be reused by a conforming future consumer.
- Freshness is recomputed against the evaluation clock, not trusted from a
  cached boolean. Evidence lifetime is capped at 24 hours.
- Managed definitions cannot be recreated or directly modified. EXTEND is
  reviewable only with existence, ownership, explicit allowed-action and
  customization evidence and without direct managed modification.
- No production decision or package metadata was changed. Existing GCC
  prerequisites were not provisioned, and no live readiness claim was made.

## Limitations and proposed FAST-008

Local evidence is externally supplied assertion data, not authenticated
Dataverse provenance. SHA-256 provides identity and change detection, not a
digital signature or proof that the assertions are true. Semantic permission
categories require a future collector to map them to actual scoped Dataverse
privileges. This milestone does not collect live evidence or verify an
approver's authority.

The future authorization schema alone does not enforce signatures, time
ordering, expiration, operation-subset relationships or current scope matching.
There is intentionally no authorization consumer. A ready sample therefore
cannot unlock Apply. Previously generated plans with incomplete requirement
mappings, unresolved component dependencies or deferred operations remain
blocked rather than being silently repaired.

Proposed FAST-008: separately approve trusted read-only evidence collection,
organization-specific permission mapping, independent approver/signature
verification, authorization expiry/scope validation at time of use, and an
explicitly reviewed executor design with scoped safety gates. Installation,
imports and Dataverse writes remain outside FAST-007.
