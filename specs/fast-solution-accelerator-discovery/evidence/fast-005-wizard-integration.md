# FAST-005 Wizard Integration Evidence

**Validation date:** 2026-10-15
**Scope:** Credential-free local wizard fixtures; no Dataverse or package
installation.

## Integration point

`05-start-wizard.ps1` completes the existing mode-specific discovery, converts
those answers into normalized requirements, invokes the FAST-004 service, shows
mode-appropriate architecture options, requires explicit selection, and only
then renders Spec Kit artifacts.

No upfront accelerator screen or FAST-specific discovery question exists.

## Sample interactions

### Demo Builder

```text
Accelerator architecture recommendation:
  Recommended option: fast-based
  Environment readiness: action-required
  FAST-dependent execution gate: False
  1. fast-based: planning-only-environment-blocked
  2. hybrid: planning-only-fast-portions-blocked
  3. fully-custom: available
7. Select and approve the consolidated architecture [fast-based]
```

The six business questions are unchanged. Architecture selection replaces no
business question and Fully Custom remains available.

### Advanced Builder

```text
Requirement coverage:
  REQ-BUSINESS-001: EXTEND -> microsoft-fast:module:training-and-certification
    Evidence: package-verified; gaps: mobile renewal alerts are unverified
Modules: microsoft-fast:module:training-and-certification, microsoft-fast:module:core
Dependency risks: unresolved=0; cycles=0
A-accelerator. Select and approve the architecture [hybrid]
```

The detailed view exposes evidence, gaps, dependencies, schema deltas, risks,
readiness, and every architecture option.

## Generated artifacts

Enabled scenarios contain:

- the eleven FAST-004 analysis artifacts;
- `accelerator-decision.json`;
- `accelerator-decision.md`;
- accelerator sections in `answers.md`, `spec.md`, `plan.md`, and `tasks.md`.

The decision records the analysis ID, snapshot ID, selected package
versions/hashes, recommended and selected architecture, rationale, readiness,
and separate FAST/custom execution gates.

## Acceptance results

- Disabled Demo Builder emitted no accelerator artifact or planning section.
- Enabled Demo, Advanced, and Framework modes completed with no new discovery
  questions.
- Fraud, training, and hybrid investigation fixtures used the FAST-004 matcher.
- A user-selected Fully Custom option remained independent from FAST readiness.
- Missing/stale GCC Core evidence kept FAST execution closed.
- Catalog absence produced an explicit `catalog-unavailable` Fully Custom
  decision.
- An identical Framework rerun reproduced the decision byte-for-byte.
- A changed selection failed until separate decision-change approval.
- Static safety checks found no Dataverse transport, PAC solution, table build,
  or column build invocation.

The fixtures use synthetic requirements and do not claim undocumented
Microsoft FAST behavior.
