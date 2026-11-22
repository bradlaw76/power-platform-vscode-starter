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
