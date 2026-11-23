# Implementation plan

Reuse framework 0.2.1 from its installed Python environment and invoke its CLI.
Do not copy its task coordinator, Spec Kit journal, deployment executor or lessons.

Add a PowerShell entry point with a small Python adapter. Select consumer paths
explicitly; forbid starter source destinations, symlink escapes and overlapping
runtime/project roots. Use canonical workspace locks and atomic JSON for a
derived status receipt, never another executable backlog. Replays verify exact
input/output hashes before skipping completed commands; uncertain writes resume
through the canonical journals.

Use an optional accepted table-decision input for wizard recommendations;
standard Dataverse identities are reused, unresolved relationship intent remains
unresolved. Synchronization requires a separately selected accepted framework
contract, not inferred Markdown approval. Update shipped guidance and focused
tests, then run affected regression/lint checks and publish a review PR.

## Authorized follow-on reliability cycle

Continue issue #12 and PR #13, without another H-number/controller. Evaluate the
ten requested phases: PR gates, remaining PR dependencies, new/existing intake,
architecture, Spec Kit lifecycle, canonical recovery, host compatibility,
isolated synthetic benefits workflow, quality/security and release readiness.
Repair the outstanding accepted-table coverage finding first. Preserve other
PR ownership; merge, security-policy changes and live execution require their
actual applicable gates. Keep scenario data and the single maintainer ledger
in the existing external pilot root.
