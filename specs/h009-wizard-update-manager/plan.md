# H009 implementation plan

## Existing state

Merged H008 supplies planning and handoff, not distribution identity or updater.
Design PR #15 stays intact; issue #14 requests a separate implementation PR.
Historical design versions remain historical. Runtime profile 1.6, contract
1.10.0, intake 0.8.2 and automation package 0.2.1 are not release versions.

## Implementation decisions

1. Commit a nullable development distribution descriptor; a separately generated
   source envelope/file index avoids self-containing-SHA/hash cycles. Independent
   synthetic digest pins test integrity only; official signature/attestation and
   publisher policy remain required before enabling live Apply.
2. Pure PowerShell offline startup requires no Python/WSL/network. Shared
   on-demand command invokes the optional Python stdlib transaction engine.
3. Stable-only checks and session-only Skip. No trusted official publisher policy
   exists: live Apply must remain unavailable; no fabricated release identity.
4. Isolated synthetic trust/ownership permits transaction/recovery tests only.
   Consumer/skill-only Apply remains blocked pending approved bundle ownership.
5. Immutable plan digest binds source bytes, exact target and baseline; path,
   lock, backup, journal and recovery guards preserve later human edits.
6. Narrow new runtime/tests scope, both agent families and generated guidance
   aligned; final existing full CI plus Windows/Linux H009 acceptance.

## Verification and publication

U01-U19 map to runtime tests and entry-point tests. Preserve exact outcomes,
skips, source/CI evidence and release gates in issue #14 and final report.
Use non-force owned-branch pushes and linked implementation PR. Latest Q14
continuation explicitly prohibits merge; stop at tested source/PR publication.
Duplicate session `cc552cd7-ee1e-4521-bb49-4debcc14d42f` routed continuation
back to this sole owner without editing, committing, pushing or creating a lane.

## Release-readiness follow-up

Preserve Q15 `8673681b231d0e275354aa98fe1d2f53a06bf97b` and work in an isolated
follow-up worktree; serialize existing-branch publication after its owner
releases the branch. Add candidate inventory tooling, not an installer or
publisher verifier. Hash explicit allowlisted Git blobs at a full commit.
Final external inventory binds the final SHA without a self-containing commit
cycle. Use the existing tests/CI plus a signed shared-wrapper lifecycle and
focused inventory negatives. Reconcile production gaps honestly in
`docs/wizard-release-readiness.md`; official mutation stays blocked.
