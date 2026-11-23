<!--
Component: H008 Release Consolidation Audit Proposal
Purpose: Preserve recovered provenance and current outcomes without inventing history.
Owner: Power Platform VS Code Starter
Version: 1.0.0
-->

# H008 additive audit proposal

Status: **ADDITIVE PROPOSAL**, not canonical restoration, branch adoption,
historical approval or permission to bypass a maintenance preflight.

## Recovered destination and divergent provenance

The canonical destination is `docs/audits/chatgpt-review-handoff.md`.
It is absent on verified main `632d00cbe38bbee753f4c4e7f4b5d1fb8d4afc8a`
and the accepted H008 baseline
`bc4f7c85ccb9a57df77da3b70fe02f27273c3cbb`.
It exists in branch history, not in an approved merged release:

- [Original canonical maintenance handoff](https://github.com/bradlaw76/power-platform-vscode-starter/commit/c37d9d79a40fb27df772be0ddf0b0bb4e69ae57f)
  contains preserved Skills 1-2 records and explicitly authorized historical
  branch-specific copies. Their publication/validation statements retain their
  original time and scope.
- [PR #5 handoff snapshot](https://github.com/bradlaw76/power-platform-vscode-starter/blob/241983d60983df52dc5101310e3037e63e72d5ca/docs/audits/chatgpt-review-handoff.md)
  belongs to the unmerged maintenance/protection proposal.
- [PR #6 H003 companion snapshot](https://github.com/bradlaw76/power-platform-vscode-starter/blob/e226f0857a8304fafa726db7c60ce846299a0249/docs/audits/chatgpt-review-handoff.md)
  is a different additive ownership record, with CODEOWNERS naming
  `@bradlaw76`, and expressly leaves merging/protection decisions to the owner.

These are not interchangeable historical bases. No snapshot was copied over
another owner's work, no historical section was fabricated, and no pending
protection/approval policy was activated merely to write this proposal.

## Owner decision and recovery plan

1. Select the approved historical base during ordinary PR reconciliation.
2. Preserve its existing sections verbatim, including obsolete-but-historical
   status; link other branch records rather than silently claiming one linear
   verified history.
3. Append current H008 outcomes with their actual source/test provenance.
4. Run the adopted maintenance preflight/ownership gates on the selected
   authorized branch and paths before restoring or updating the canonical file.
5. Validate links, documentation and exact-head CI; record remote publication
   separately from merge.

Until that selection/authorization is established:
**HANDOFF NOT WRITTEN - BLOCKED** for the canonical destination.
This newly requested additive proposal does not substitute for canonical
restoration or change the stronger protection boundary.

## Current transferable outcome

- Existing H008 issue #12/PR #13 and canonical framework ownership are retained.
- PR #13's accepted-table review finding was reproduced/fixed in its existing
  work, and the addressed review thread was resolved during consolidation.
  No approving review or scoped merge authorization was recorded.
- #11 and #7 were incorporated only into the owned H008 candidate branch;
  owner branches and main were not changed. Profile tests passed 154 assertions
  on that candidate, with synthetic stage bodies, not tenant validation.
- Fresh native new/partial-project verification at
  `d5a36e2876157ed6d5329d11b3aa76279600c68d` passed 34 assertions and
  34 synthetic operations, 16 installed handoff tests, 16 actual POSIX worker
  tests, 25 standalone suites and 104 Pester tests. Actual scoped Spec Kit
  projections/dependencies and zero-write replay were verified.
- Native Windows guided execution, accepted architecture, opt-in Spec Kit,
  recovery and stale-evidence boundaries remain unchanged. Candidate profiles
  keep Legacy default and required membership/security gates.
- #6 protection adoption, #5/#4 ownership/no-Git reconciliation and #3's mixed
  application/intake contract remain independent owner-gated lanes.
- The full final release report, fresh scenario logs, exact subsequent commits/
  CI and the single durable status record stay in the existing external pilot.
  Final publication receipts are recorded on issue #12/PR #13 rather than
  fabricating a self-referential commit hash in this document.

No live deployment, public release, scheduler, billing/security change or
application repository modification is authorized or performed by this proposal.

## Q3 evidence-based governance baseline - 2026-11-23

This is an authorized additive update to this proposal, not restoration of
the missing canonical handoff or adoption of another branch's policy.
The preceding proposal is retained unchanged. Historical audit sources remain
in their original commits with their original attribution, dates and bytes.

### Immutable audit map and authority

| Source | Canonical handoff Git blob | Meaning |
| --- | --- | --- |
| Verified main `632d00cbe38bbee753f4c4e7f4b5d1fb8d4afc8a` | Absent | No current canonical audit file to append |
| Q2 candidate `487b56a939807b7409c474f255fa31c5d1faa2ec` | Absent | Existing additive proposal only |
| Skills #4 `8d35b723852dbc0a218a29cebd877d6bc1cc128a` | `d1431d0955d140186a45e31d031f214195d20bf3` | Historical Skills 1-2 record |
| Canonical-policy record `c37d9d79a40fb27df772be0ddf0b0bb4e69ae57f` | `d6659180ccd38ff6766f36194f143f8a00fe6dd3` | Historical copy and later policy/status entries |
| Maintenance #5 `241983d60983df52dc5101310e3037e63e72d5ca` | `5fe10453cbd4b509336b8fd4017d7cb914865f73` | Different unmerged maintenance snapshot |
| Ownership #6 `e226f0857a8304fafa726db7c60ce846299a0249` | `efb8afb304eaed4a4bff4d0506bcec7df69e7eb4` | Separately authored H003 companion, not a replacement history |

The historical
[SPEC policy](https://github.com/bradlaw76/power-platform-vscode-starter/blob/c37d9d79a40fb27df772be0ddf0b0bb4e69ae57f/SPEC.md)
names `docs/audits/chatgpt-review-handoff.md` and requires eleven all-outcomes
fields, separate operation permission, historical preservation and a blocked
response-only fallback. A historical document's claim of an authorized copy
is evidence about that operation, not a new grant for this branch.
Main's [authorization policy](../policies/authorization-and-execution.md)
preserves handoff/protection requirements but grants no permission itself.
No inspected current owner record selects #5, #6 or the historical policy
snapshot as the approved restoration base for this candidate.

Owner choices remain:

1. Authorize an exact historical base and append current evidence without
   rewriting its obsolete-but-historical statements; link other immutable
   records instead of fabricating one linear history.
2. Alternatively, explicitly authorize a fresh dated canonical index linking
   these immutable records, with no claim that their approvals/results apply
   to the new branch. Specify its role relative to this proposal and the
   current authorization policy.

Either choice must name the repository/branch/current full SHA, canonical
path and applicable operation scope. Never relabel or switch to a maintenance
branch to manufacture a successful preflight. No choice has been made here.
Canonical result: **HANDOFF NOT WRITTEN - BLOCKED**.

### Verified and unavailable protection layers

| Layer | Actual evidence / limitation |
| --- | --- |
| Current H008 handoff | Five fresh installed tests passed: protected/overlapping roots and traversal, active runtime lock/stale plan, owner-preserving crash resume, human conflict isolation and zero-write replay |
| Proposed #6 guard | Direct hooks invoked only in a separate synthetic Git fixture: valid baseline plus six real rejections for new application paths, neutral application content, frozen worktree changes and wrong push destinations/remotes |
| Proposed #6 gaps | A forbidden staged blob with restored worktree passed pre-commit; an outgoing violating branch while main was checked out passed pre-push. Both are REPRODUCED UNFIXED, not passing protections |
| Proposed #5 preflight/maintenance | Read-only source review confirms exact root/secure remotes/branch/full HEAD and scoped path checks; not installed or adopted here. Its outgoing-history and archive review findings remain unresolved |
| This clone | No configured `core.hooksPath` and no non-sample Git hooks found; direct fixture invocation is not activation |
| Main/server | No main protection/effective rules/CODEOWNERS; passing PR CI is not mandatory server enforcement |
| Isolation | Separate folders, URL checks and naming rules are not an OS sandbox or proof of authenticated repository identity |

The proposed hook probe used the exact #6 script/baseline blobs, 71 original
historical files and synthetic local commits. It installed no hooks and
performed no network push. Its configured origin is test metadata, not an
authenticated ownership claim. Full fixture data/logs remain in the external
pilot. These new reproductions corroborate Q2's unresolved findings; original
review threads and owner branches remain unchanged.

### H-number, writer and recovery boundaries

- Starter #12/PR #13 reuse canonical Automation Framework
  [H008 issue #24](https://github.com/bradlaw76/Power-Platform-vs-code-starter-automation-pipeline/issues/24)
  and merged
  [PR #26](https://github.com/bradlaw76/Power-Platform-vs-code-starter-automation-pipeline/pull/26),
  merge `a23096ec27de9bc1035b690dc9d49268a408d059`.
- Existing H009 issue #14/design PR #15 remain a separate owner lane; none was
  allocated, renamed or modified by Q3. The #6 H003 companion explicitly does
  not establish a new global allocation sequence.
- Follow the existing [one-writer/H-number gate](../scenario-change-impact-gate.md).
  Git lock absence is a point-in-time observation, not proof that no IDE or
  remote writer exists. Actual runtime lease rejection was tested; no global
  cross-repository writer registry or enforced H-number allocator was found.
- Use an explicitly selected non-OneDrive checkout and separate external
  project/runtime directories; inspect branch, full SHA, remotes, dirty state,
  concurrent owners and relevant locks before consequential operations.
  Do not move, stash or overwrite another operator's work.
- All five original generic-fixture SHA-256 values still match. Known main,
  Q1 and Q2 commits remain available for read-only comparison and reviewed
  rollback. [Git engineering standards](../../requirements/GithubInstructions_General.md#49-branches-are-not-backups)
  distinguish recovery commits from misleading backup branches.
- The historical Skills 1-2 durable-backup exception was task-specific. It
  is not a Q3 waiver. No backup repository or filesystem backup was changed,
  no full disaster restore was exercised, and commits do not back up dirty
  files, secrets or live tenant data.
- Before rollback, preserve evidence/dirty work, inspect the exact diff and
  obtain the applicable owner scope for a selected-file repair or revert and
  its commit/push. Never automatically reset, abort Git operations, restore a
  whole workspace, import a package or infer live rollback authorization.

### Transferable all-outcomes handoff

1. **Date/task/outcome:** 2026-11-23, Q3 governance reconciliation; additive
   proposal/source evidence prepared, canonical restoration blocked.
2. **Errors/failure evidence:** no current boundary test failed; two proposed
   hook protections accepted controlled violations and remain unfixed.
3. **Context:** `bradlaw76/power-platform-vscode-starter`,
   `feature/h008-starter-integration`, starting full HEAD
   `487b56a939807b7409c474f255fa31c5d1faa2ec`.
4. **Changed files:** this proposal, release guide, build log and existing
   scenario plan/tasks. External probe/log/report/ledger updates are not
   application artifacts or new controllers.
5. **Validation:** five installed tests, nine isolated proposed-hook probes,
   original fixture hashes and immutable audit blob identities verified.
   Full source CI/publication is recorded separately in #12/#13. No live
   deployment, backup restore or server enforcement test was performed.
6. **Worktree:** scoped documentation changes were pending at authoring;
   final clean/committed/pushed state is read back in the publication receipt.
7. **Completed:** audit/policy/ownership lineage, actual protection inventory,
   supported boundary tests and controlled gap reproductions.
8. **Remaining:** canonical base/index authority, #6 staged/outgoing repairs
   before hook adoption, #5 scoped package repairs/adoption, server rules and
   verified backup/disaster-recovery requirements.
9. **Recovery:** no security bypass or competing source writer was used.
   Corrected a local task-section placement before publication. An initial
   raw worktree-byte preservation assertion failed because the existing
   `core.autocrlf=true` checkout uses CRLF while Git stores LF; comparison of
   the actual Git-cleaned blob then proved the complete original prefix was
   preserved byte-for-byte. No content rewrite, Git setting change, product
   runtime correction or original owner branch rewrite was needed.
10. **Next actions:** owner chooses base versus fresh canonical index and
    operation scope, authorizes owned protection repair/adoption contexts and
    separately decides server enforcement. Q4 can proceed independently once
    its scope is supplied; Q3 does not authorize tenant mutation.
11. **Publication:** proposal only, not canonical restoration or main merge.
    Exact resulting source SHA, CI and remote receipts are recorded on
    existing #12/#13 and in the single external ledger/report; no self-hash or
    fictional approval record is embedded here.
