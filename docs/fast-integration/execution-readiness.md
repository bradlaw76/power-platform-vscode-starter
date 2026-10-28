# FAST-007 / FAST-008A: Execution Readiness

## Purpose and safety boundary

FAST-007 is separately authorized local-only readiness evaluation, not a
FAST-006 continuation into execution. Readiness checks whether an approved
architecture decision, pinned dry-run plan, and supplied evidence are suitable
for human review. It does not approve or execute the plan.

**`READY_FOR_APPROVAL` means human review only. `executionAuthorized` is always
false for every status.** A ready report cannot unlock FAST-dependent Apply.
FAST remains disabled by default in Demo Builder, Advanced Builder, and
Framework Acceptance. The authoritative bootstrap sequence remains
[`../onboarding.md`](../onboarding.md); readiness is an optional local branch,
not a new platform build stage.

There are no Dataverse, PAC CLI, network, authentication, installation, import,
or build operations in readiness. Evidence is supplied externally as local
files. The engine does not authenticate to an environment itself. FAST-008A validates
signed collector provenance using an independently supplied trusted certificate;
hash integrity alone is not evidence-source authenticity. See
[trusted environment verification](trusted-environment-verification.md).

## Inputs and integrity checks

Complete and align the scenario's `spec.md`, `plan.md`, and `tasks.md`, approve
its architecture decision, and generate the FAST-006 dry-run plan before using
readiness. Do not create a replacement decision or edit a plan merely to make
a readiness result pass.

The engine reads:

- `specs/<scenario-slug>/accelerator/accelerator-decision.json`: the approved
  architecture decision, not a CLI architecture override.
- `specs/<scenario-slug>/accelerator/build-plan/build-plan-manifest.json`: the
  pinned plan manifest and its referenced local artifacts.
- The evidence selected by `-EvidencePath`: by default a signed
  `trusted-environment-verification.json` envelope, containing normalized
  [`execution-evidence.schema.json`](../../schemas/accelerators/execution-evidence.schema.json)
  v1 evidence. Raw FAST-007 evidence requires explicit `LocalPlanning` opt-in.
- The referenced local inputs needed to verify SHA-256 file integrity,
  canonical decision/plan IDs, and input fingerprints.

Supply the intended environment URL, environment ID, and tenant ID
independently of the evidence. The full evidence target must match this
triple exactly after URL normalization. A manifest cannot define its own
acceptable target merely by asserting an identity. These comparisons bind the
requested target locally; they are not a live identity lookup.

Evidence has a hard maximum lifetime of **24 hours**. An evidence producer
cannot extend that limit. Evaluate timestamps and freshness against the
evaluation clock, and resolve missing, invalid, expired, or inconsistent
evidence rather than changing the clock to hide a blocker.

## Evidence trust policy

`-EvidenceTrustPolicy Authenticated` is the default. Only complete, fresh,
matching signed Live evidence with an independently provisioned trusted X509
certificate can produce `verifiedForHumanReview: true`. Pass the public
certificate using `-TrustedCertificatePath`; never trust an embedded key.
Certificates must be valid at collection and evaluation.

Explicit `RecordedTest` permits signed Mock evidence to reach
`READY_FOR_APPROVAL`, but `verifiedForHumanReview` is always false.
Explicit `LocalPlanning` preserves raw FAST-007 local diagnostics, also with
`verifiedForHumanReview: false`. Neither opt-in permits writes.
Every policy preserves `executionAuthorized: false`. Collection signatures
prove collector authority, not truth against a compromised signer or deployment
approval. FAST-008A implementation uses mocks only; no live GCC access is claimed.

## Standalone local command

From the repository root:

```powershell
pwsh .\scripts\accelerators\invoke-execution-readiness.ps1 `
  -EnableExecutionReadiness `
  -ScenarioSlug <scenario-slug> `
  -EvidencePath <trusted-environment-verification.json> `
  -EvidenceTrustPolicy Authenticated `
  -TrustedCertificatePath <independently-provisioned-public.cer> `
  -EnvironmentUrl <approved-target-url> `
  -EnvironmentId <environment-guid> `
  -TenantId <tenant-guid> `
  -WorkspaceRoot <repository-root>
```

| Parameter | Meaning |
| --- | --- |
| `-EnableExecutionReadiness` | Explicit opt-in; FAST's normal default-off behavior is unchanged |
| `-ScenarioSlug` | Scenario containing the approved decision and build-plan manifest |
| `-EvidencePath` | Signed verification envelope by default; raw evidence only with LocalPlanning |
| `-EvidenceTrustPolicy` | Authenticated (default), RecordedTest, or LocalPlanning |
| `-TrustedCertificatePath` | Independently provisioned public trust certificate for signed evidence |
| `-EnvironmentUrl` | Independently supplied expected target URL |
| `-EnvironmentId` | Independently supplied expected environment GUID |
| `-TenantId` | Independently supplied expected tenant GUID |
| `-WorkspaceRoot` | Optional repository workspace containing the scenario and local inputs; defaults to the repository root |
| `-OutputFolder` | Optional local report destination |
| `-EvaluationTimeUtc` | Optional explicit UTC clock for deterministic evaluation |

The default report destination is
`specs/<scenario-slug>/accelerator/readiness/execution-readiness.json`.

For a reproducible review or synthetic check, pass an explicit
`-EvaluationTimeUtc <utc-time>` and retain it with the report. Repeating the
same pinned inputs and clock supports deterministic comparison. A historical
clock or synthetic evidence does not establish current live readiness.

`scripts/accelerators/execution-readiness.ps1` contains the local-only engine;
`invoke-execution-readiness.ps1` is its operator-facing CLI.

## Orchestrator preflight only

The orchestrator offers the same local assessment without loading helpers,
requiring payloads, or executing stages:

```powershell
pwsh .\scripts\bootstrap\90-run-build.ps1 `
  -ScenarioSlug <scenario-slug> `
  -ExecutionReadinessOnly `
  -ExecutionEvidencePath <trusted-environment-verification.json> `
  -ReadinessEvidenceTrustPolicy Authenticated `
  -ReadinessTrustedCertificatePath <independently-provisioned-public.cer> `
  -EnvironmentUrl <approved-target-url> `
  -ReadinessEnvironmentId <environment-guid> `
  -ReadinessTenantId <tenant-guid>
```

`-ReadinessEvaluationTimeUtc <utc-time>` is optional. This explicit branch
returns before normal helper loading, stage setup/execution, and payload
requirements. **Never combine readiness-only preflight with Apply
(`-Mode Apply`).** It is not a preview-to-Apply shortcut.

Normal Apply independently rejects an approved decision whose `selectedOption`
is `fast-based` or `hybrid`, even if a ready report exists. Do not delete or
rewrite that decision to bypass the guard. Legacy scenarios and approved Fully
Custom scenarios retain their normal build behavior; they do not acquire
mandatory readiness preflight or FAST package prerequisites.

## Report and six statuses

The local report is `execution-readiness.json`, validated against
[`execution-readiness.schema.json`](../../schemas/accelerators/execution-readiness.schema.json).
Inspect its reported blockers and bindings; do not use the status name alone
as permission to proceed.

| Status | Operator interpretation |
| --- | --- |
| `READY_FOR_APPROVAL` | Human review only; inspect trust policy and verifiedForHumanReview separately; no execution authorization |
| `BLOCKED_PREREQUISITES` | Required planning or prerequisite conditions are not satisfied |
| `BLOCKED_EVIDENCE` | Required evidence or its integrity/freshness/binding is not acceptable |
| `BLOCKED_COMPATIBILITY` | Compatibility requirements are not satisfied by the supplied evidence |
| `BLOCKED_SECURITY` | Required security conditions are not satisfied |
| `BLOCKED_DECISION_CHANGE` | The approved decision and bound plan/input state require review rather than silent reuse |

Use the actual report reasons to resolve blockers. Fresh evidence is not a
substitute for missing prerequisites, compatibility, security review, or an
approved decision change.

The scope SHA-256 binds **decision, plan, evidence, inputs, and target**.
Changes to any bound input require reevaluation; an older report must not be
reused as authorization. `executionAuthorized` remains false on every path.

[`build-authorization.schema.json`](../../schemas/accelerators/build-authorization.schema.json)
is a future contract only. FAST-007 generates and consumes **no approval or
authorization records**. Architecture approval is an existing planning input,
not a new execution grant.

## Review checklist and recording

1. Confirm the selected scenario, approved architecture, and pinned plan.
2. Independently supply and review URL/environment ID/tenant ID.
3. Validate the evidence manifest and inspect its source, hashes, input
   fingerprints, timestamps, and maximum 24-hour lifetime.
4. Retain the explicit evaluation clock when reproducibility is required.
5. Inspect every blocker, report status, and scope SHA-256.
6. Confirm `executionAuthorized: false`; stop at human review even when ready.
7. Record actual commands, outputs, failures/skips, evidence provenance
   limitations, and report references in [`../build-log.md`](../build-log.md).

Synthetic samples are maintained under
[`specs/fast-007-execution-readiness/evidence/`](../../specs/fast-007-execution-readiness/evidence/).
They demonstrate local behavior only. This guide claims no test passes,
successful live readiness, platform compatibility, or execution approval.

## Stop condition and FAST-008A supersession

The authorized FAST-007 local scope supersedes historical FAST-005B/FAST-006
stop conditions only for this readiness implementation. Stop after human-review handoff. [ADR 0010](../../specs/fast-solution-accelerator-discovery/adrs/0010-local-execution-readiness.md)
records the boundary.

FAST-008A now adds GET-only trusted collection and RS256 provenance validation
within the [trusted verification contract](trusted-environment-verification.md)
and [ADR 0011](../../specs/fast-solution-accelerator-discovery/adrs/0011-trusted-environment-verification.md).
This supersedes the earlier proposed-only collection boundary, not execution.
A future controlled execution phase remains proposed and unauthorized:
independent deployment approver/signature checks, scoped authorization
consumption and revalidation, and a separately approved executor require
separate authorization. Neither the future schema nor a ready report supplies
those capabilities.
