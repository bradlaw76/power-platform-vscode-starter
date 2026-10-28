# Repository update advisor implementation plan

## Approved design

1. Add `repository-updates.json` with the stable GitHub repository identity,
   default remote `origin`, branch `main`, and capability path rules. Consumers
   of forks may explicitly override the remote/branch. Never guess a target
   from the current branch.
2. Add JSON Schemas for catalog, optional scenario `repo-update-context.json`,
   baseline and update report. Context contains explicit enabled/disabled
   capability IDs; omitted capabilities remain unknown.
3. Implement a shared Git helper plus `check-repository-updates.ps1`. Local
   checks prefer the last advisor fetch ref, falling back to
   `refs/remotes/<remote>/<branch>`; opt-in fetch uses the isolated
   `refs/wizard-update-check/<remote>/<branch>` ref without tags or FETCH_HEAD.
   Reports include resolved SHAs and fetch/cached freshness, not just status.
4. Wire automatic local checks into terminal intake, with opt-in fetch and a
   skip switch. Chat instructions invoke the same standalone check. Checks
   print results without persisting files unless an output folder is requested.
5. Add baseline capture to orchestrator state/summary. Apply archives one
   immutable JSON record per run beneath the existing scenario manifest root.
   Preview writes no manifest records. Resume checks source identity before
   skipping work; legacy resumes without baseline require a fresh run. Git-less
   workspaces may resume with an explicit unverified-source warning, preserving
   existing non-Git workflows without claiming reproducibility.
6. Increment the runtime contract to 2.2.0; register the advisor as a pre-intake
   service, not a Dataverse build stage. Update all applicable maintenance
   checklist surfaces without altering build ordering or approval gates.

## Source identity boundaries

Local fingerprints hash Git binary diff against HEAD, status and hashes of
nonignored untracked files. Only hashes, never source contents or remote URLs,
are serialized. Ignored build outputs do not change source identity. These are
diagnostic provenance, not signed attestations or deployment authorization.
Missing Git/profile metadata is explicitly unverified rather than fabricated.
Historical immutable records remain local ignored artifacts unless a user
separately chooses to share them.

## Validation strategy

Use temporary repositories outside OneDrive with local remotes and configured
fixture authors. Assert HEAD/index/worktree do not change, no network by default,
fetch failure is explicit, unknown capability IDs fail, context conflicts fail,
and per-run records reject replacement. Run focused existing regression suites,
PowerShell parsing/analyzer, Markdown lint and whitespace validation.
