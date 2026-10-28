# Repository update advisor

## Approval and scope

Approved by the operator on 2026-10-27: local-first automatic startup checks,
explicit opt-in fetch, capability categorization, per-run source baselines,
schemas, tests and documentation. No scheduled workflow in this release.
This is a repository enhancement, not a Dataverse app or deployment approval.

## Requirements

- Check cached upstream metadata at terminal/chat startup without network by
  default. Explicit fetch may update only a private remote-tracking ref; never
  pull, merge, checkout, tag, commit, push or modify tracked files.
- Use a configured remote name and branch, not an arbitrary command or URL.
  Disable interactive Git credential prompts during checks.
- Distinguish up-to-date, updates-available, local-ahead, diverged,
  unrelated-history and unable-to-check. Local results disclose cached freshness;
  fetch failure must not report cached success.
- Compare an explicitly selected baseline commit, or HEAD by default, with the
  selected upstream tip. Missing/shallow history is not proof of no updates.
- Categorize actual changed paths using a maintained schema-validated catalog.
  Paths prove affected capabilities, not bug fixes or compatibility guarantees.
  Unmatched paths require review. Optional capability relevance is tri-state,
  based only on explicit scenario selections, never inferred approval.
- Record full commit, UTC capture time, contract version, stable repository
  identity, dirty status and a SHA-256 local-change fingerprint. A human-readable
  baseline ID includes timestamp and short SHA; the full identity is authoritative.
- Store immutable run baseline records under the existing scenario manifest
  namespace for Apply. Preview may include baseline diagnostics in its existing
  run outputs, but must not write manifest provenance. Resume must not relabel
  earlier work with a new baseline. Missing Git metadata is explicitly unverified.
- Advisor failure warns at startup without blocking discovery. Explicit standalone
  checks fail nonzero on inability to check. No Dataverse, PAC, telemetry upload,
  remote code execution, automatic adoption or change to FAST authorization.

## Acceptance

Offline local Git fixtures prove all history states, dirty tracked/untracked
fingerprints, immutable records, schema validation, relevance and opt-in fetch.
Existing wizard-mode, Preview, run-state, contract and skill-parity tests remain
passing. No live Dataverse or public upstream fetch is needed for validation.
