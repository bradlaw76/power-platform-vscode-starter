# FAST-008A Implementation Plan

1. Extend the shared FAST inspector with a bounded, redirect-rejecting GET
   transport and provider-neutral empty-package inspection. Preserve legacy
   FAST-003 behavior unless the stricter verification path is requested.
2. Collect current organization/environment/tenant, WhoAmI, installed solutions
   and publishers, package dependencies and concrete planned metadata.
   Unsupported descriptive component identities remain explicitly unverified.
3. Query effective privileges by name at organization scope where needed.
   Read access never implies customization permission. Future component
   ownership is labelled prospective/inferred, not observed.
4. Add a signed verification envelope containing normalized FAST-007 evidence,
   observation classifications and exact planning/artifact bindings.
   Use RSA/SHA-256 with an externally supplied signing certificate and an
   independently provisioned trust anchor. No production key is generated.
5. Integrate provenance verification into FAST-007. Authenticated is the
   default trust policy; explicit LocalPlanning and RecordedTest policies
   support diagnostics/tests but never claim live verified eligibility.
6. Add an explicit verification CLI with no environment-file fallback.
   Live requires target confirmation and existing credentials; tests inject
   transport only in Mock mode. No live calls during implementation.
7. Correct quality-runner parsing/result propagation and align the smoke
   assertion with the existing timer prompt. Add focused regressions.
8. Update versioned contracts, ADR, README enhancement surfaces, canonical
   guidance and skills. Run offline suites, commit/push only the feature branch,
   and verify its exact remote SHA.

## Trust boundary

Signatures prove integrity and provenance from the configured collection
authority, not deployment authorization. The signing authority and TLS endpoint
remain trusted infrastructure; a compromised signer is outside this local
artifact validator's protection. Mock signatures are test-only.

## Implemented surfaces

- [Collector](../../scripts/accelerators/trusted-environment-verification.ps1)
  and [explicit command](../../scripts/accelerators/invoke-trusted-environment-verification.ps1).
- [Reused inspector](../../scripts/accelerators/dataverse-environment-inspector.ps1)
  and its shared redirect-rejecting GET/retry transport.
- [Provenance and required observation scope](../../scripts/accelerators/verification-provenance.ps1).
- [Readiness integration](../../scripts/accelerators/execution-readiness.ps1),
  signed-envelope schema, default-off profile registration and nonexecuting
  orchestrator parameter forwarding.
- [Acceptance tests](../../scripts/ci/test-trusted-environment-verification.ps1)
  and [recorded outcomes](validation-evidence.md).
