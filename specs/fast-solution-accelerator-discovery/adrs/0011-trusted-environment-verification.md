# ADR 0011: Trusted Environment Verification Without Execution Authority

**Status:** Accepted for FAST-008A read-only, mock-validated scope
**Date:** 2026-10-19

## Context

FAST-007 validates local integrity, not evidence-source authenticity.
Caller-authored raw evidence cannot establish authenticated review eligibility.
The historical FAST-008 proposed-only collection boundary needs a bounded
supersession without creating an executor or changing ordinary Fully Custom
build behavior.

## Decision

Reuse `dataverse-environment-inspector.ps1` and shared `dataverse-runtime`.
Add `trusted-environment-verification.ps1`, its explicit `invoke-` CLI and
`verification-provenance.ps1`. Collect GET-only observations; no installation,
import, permission grant, deployment approval or authorization issuer.
`trustedEnvironmentVerification` defaults false in contract v1.16.0.

Actual EnvironmentId/TenantId come from RetrieveCurrentOrganization;
OrganizationId/UserId come from WhoAmI and are not substitutes. FAST-003's
historical environmentId organization-ID semantics remain legacy-only.
Reuse selected-package/dependency inspection, concrete table/column metadata,
managed properties, publishers/solution membership and effective privileges by
name. Unsupported descriptive FAST-006 component identities remain unverified/
blocked; never guess forms/apps/integration IDs. Prospective ownership of future
CREATE components is inferred, distinct from observed metadata.

Sign `trusted-environment-verification.json` with RSA/SHA-256 (RS256) using an
operator-provided external X509 certificate. Bind normalized execution-evidence
v1, exact decision bytes, plan ID/SHA, catalog snapshot, dependency/input/package
metadata hashes, classified checks, collection mode, actual identity and
collection/expiry times. Persist no tokens, credentials or private keys.

Validate with an independently provisioned trusted X509 certificate:
`TrustedCertificate` in the engine, `-TrustedCertificatePath` in the readiness
CLI. Never accept an embedded key as authority. Require certificate validity at
collection and evaluation. Signatures prove collector authority and integrity,
not truth against a compromised signer or deployment authorization.

Collection defaults Mock and requires injected RequestInvoker for tests.
Live rejects injected transport and requires explicit feature opt-in,
read-only confirmation, target URL/environment/tenant/solution, existing
TokenProvider or reused Azure CLI session, and external signing certificate.
There is no `.env` fallback or stored target selection. This milestone uses
mocks only and authorizes no live GCC access.

Readiness `EvidenceTrustPolicy` is Authenticated by default: only complete,
fresh, matching signed Live evidence can set `verifiedForHumanReview: true`.
Explicit RecordedTest permits signed Mock evidence to reach READY_FOR_APPROVAL
with verifiedForHumanReview false. Explicit LocalPlanning preserves raw
FAST-007 diagnostics, also false. Every policy retains executionAuthorized
false. Forward `-ReadinessEvidenceTrustPolicy` and
`-ReadinessTrustedCertificatePath` through the existing early-return
`-ExecutionReadinessOnly` branch; never combine it with Apply.

## Consequences and supersession

This ADR supersedes ADR 0010 and historical FAST-008 proposed-only wording
**only** for GET-only collection and signed provenance validation. It does not
supersede their no-execution boundary. FAST-dependent Apply remains disabled
globally; ordinary Fully Custom builds and default-off modes remain unchanged.
Raw evidence requires explicit diagnostic opt-in and cannot claim authenticated
review eligibility. Operational guidance lives in
[trusted verification](../../../docs/fast-integration/trusted-environment-verification.md).

Actual mock/regression outcomes belong to the FAST-008A milestone evidence;
this ADR claims no test pass or live readiness. Isolated quality-runner parser/
stage-result propagation and timer-prompt assertion corrections are tightly
scoped; OneDrive cleanup contention remains a separate limitation.

Future controlled execution remains proposed and unauthorized. Independent
deployment approvals/signatures, scoped authorization consumption, scope
checks/revalidation and a separately approved executor need separate approval.
