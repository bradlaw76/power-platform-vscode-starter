# FAST-008A: Trusted Environment Verification

## Scope and operator boundary

FAST-008A adds authenticated, GET-only evidence collection and signed provenance
to FAST-007 human-review readiness. It does not add an executor, deployment
approval, installation, import, permission grant, or authorization issuer.
FAST and `trustedEnvironmentVerification` remain default-off in every wizard
mode. Normal Fully Custom builds are unchanged; FAST-dependent Apply remains
disabled globally, even after `READY_FOR_APPROVAL`.

This milestone is implemented and evaluated with mocks only. No live GCC
access is authorized or claimed. The following describes the operator contract,
not a request to run live collection. Complete and approve scenario planning,
architecture and the immutable FAST-006 plan first. Follow
[onboarding](../onboarding.md), the authoritative bootstrap sequence.

## Explicit collection contract

`scripts/accelerators/invoke-trusted-environment-verification.ps1` invokes
`trusted-environment-verification.ps1`, reusing
`dataverse-environment-inspector.ps1` and the shared `dataverse-runtime`.
The collector accepts:

| Parameter | Contract |
| --- | --- |
| `-EnableAuthenticatedVerification` | Explicit feature opt-in |
| `-ScenarioSlug` | Approved scenario and pinned decision/plan |
| `-EnvironmentUrl`, `-EnvironmentId`, `-TenantId` | Explicit independently supplied intended target; no `.env` fallback or stored URL selection |
| `-SolutionUniqueName` | Explicit target solution |
| `-SigningCertificate` | Operator-provided external X509 certificate object with RSA private key; never a generated production key |
| `-ConfirmReadOnlyScope` | Required explicit confirmation before Live collection |
| `-CollectionMode` | `Mock` (default) or `Live`; Mock requires an injected `RequestInvoker` for tests, Live rejects injected transport |
| `-PackageManifestPath` | Optional selected package/dependency manifest |
| `-WorkspaceRoot`, `-OutputFolder` | Workspace and local evidence destination |
| `-EvidenceTimeToLiveSeconds` | Optional collection lifetime of 1-3600 seconds (default 900); readiness maximum remains 24 hours |

Live collection also requires an existing authenticated `TokenProvider` or a
reused Azure CLI existing session. It must fail closed without credentials,
explicit target, confirmation or signing certificate. There is no interactive
deployment sign-in, write transport, or implicit environment discovery.
Do not persist access tokens, credentials, private keys, or authentication
headers in evidence or logs.

## Observations, not assumptions

- `RetrieveCurrentOrganization` supplies actual **EnvironmentId** and TenantId;
  `WhoAmI` supplies OrganizationId and UserId. OrganizationId is not
  EnvironmentId. FAST-003's historical `environmentId` organization-ID meaning
  remains legacy-only; new verification enforces `actualEnvironmentId`.
- Reuse selected-package and transitive-dependency inspection. Check installed
  solutions/versions, concrete metadata existence, managed properties,
  publishers, solution membership and effective privileges **by name**.
  Read access does not prove customization privileges.
- Initial concrete component support covers tables and columns. Unsupported
  or descriptive FAST-006 identities remain unverified/blocked. Never guess
  IDs for forms, apps, integrations or other unsupported components.
- Distinguish verified, missing, inaccessible, unsupported and inferred
  information. Prospective ownership of future CREATE components is inferred,
  not observed metadata. Incomplete checks cannot establish verified review
  eligibility.

## Signed envelope and independently pinned trust

The output `trusted-environment-verification.json` conforms to
`schemas/accelerators/trusted-environment-verification.schema.json`.
It includes normalized execution-evidence v1, exact decision bytes, plan ID
and SHA-256, catalog snapshot ID, dependency hash, input and package metadata
hashes, classified checks, collection mode, actual authenticated identity,
collection time and expiry. `verification-provenance.ps1` signs the envelope
with RSA/SHA-256 (RS256).

Readiness must receive an **independently provisioned trusted X509 certificate**,
not trust an embedded certificate/public key from evidence. The standalone
readiness CLI accepts `-TrustedCertificatePath` (public certificate); its engine
accepts a `TrustedCertificate` object. The certificate must be valid both at
collection and evaluation. A valid signature proves integrity and the configured
collector authority, not truth against a compromised signer, nor deployment
authorization. Protect the signing authority and provision its public trust
anchor through a separate trusted channel.

## Readiness policies

| `-EvidenceTrustPolicy` | Accepted purpose | `verifiedForHumanReview` |
| --- | --- | --- |
| `Authenticated` (default) | Complete, fresh, matching, signed **Live** envelope with independently trusted certificate | Can be true only after all required checks pass |
| `RecordedTest` (explicit) | Signed Mock evidence for deterministic offline tests; may report `READY_FOR_APPROVAL` | Always false |
| `LocalPlanning` (explicit) | Raw FAST-007 local evidence for planning diagnostics only | Always false |

Raw evidence no longer establishes authenticated review eligibility. Explicit
LocalPlanning opt-in preserves diagnostics, not writes or live verification.
Every policy and every status has `executionAuthorized: false`.

For a previously collected Live envelope, the standalone review shape is:

```powershell
pwsh .\scripts\accelerators\invoke-execution-readiness.ps1 `
  -EnableExecutionReadiness -ScenarioSlug <scenario-slug> `
  -EvidencePath <trusted-environment-verification.json> `
  -EvidenceTrustPolicy Authenticated `
  -TrustedCertificatePath <independently-provisioned-public.cer> `
  -EnvironmentUrl <approved-target-url> `
  -EnvironmentId <actual-environment-guid> -TenantId <tenant-guid>
```

The orchestrator forwards `-ReadinessEvidenceTrustPolicy` and
`-ReadinessTrustedCertificatePath` through `-ExecutionReadinessOnly`, preserving
its early return before helper loading, payload requirements and build stages.
Never combine this branch with `-Mode Apply`. See
[execution readiness](execution-readiness.md) for statuses and local integrity
checks.

## Handoff and remaining authorization

Record source/mode, independent certificate provenance, identity, bindings,
expiry, unsupported checks and actual validation outcomes in
[the build log](../build-log.md). No test pass or live readiness is claimed here.
The isolated quality corrections cover the `run-quality.ps1` `${_}:` parser
form and real stage exit/result propagation, plus the smoke assertion matching
`How long should the demo timer run, in minutes?`. OneDrive cleanup contention
is a separate limitation, not grounds for unrelated refactoring.

FAST-008A supersedes earlier proposed-only trusted-collection wording only
within this read-only signed-evidence scope. A future controlled execution
phase remains proposed and unauthorized: independent deployment approvals and
signatures, scoped authorization consumption, scope checks, revalidation and a
separately approved executor require separate work. See
[ADR 0011](../../specs/fast-solution-accelerator-discovery/adrs/0011-trusted-environment-verification.md).
