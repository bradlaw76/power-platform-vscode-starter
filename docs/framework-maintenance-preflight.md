# Framework Repository Context and Maintenance Preflight

This is a read-only identity check, not authorization to modify or publish.
Framework Administration Mode is the operator-facing name for the existing
Framework Maintenance Mode; it is not a fourth wizard mode.

Before any framework task, inspect the current repository root, fetch and push
remotes, exact branch, HEAD, worktree status, recent history, repository
instructions, tooling, and applicable CI. Compare them with the operator's
approved repository, maintenance branch, and full starting SHA. Never infer the
branch or baseline from whichever checkout the agent happens to receive.

Run from the verified framework source checkout:

```powershell
pwsh ./scripts/bootstrap/framework-context-preflight.ps1 `
  -FrameworkRoot <absolute-framework-repository-root> `
  -ExpectedBranch framework-maintenance/<approved-task> `
  -ExpectedHead <approved-40-character-sha>
```

The check fails closed on wrong repository identity, ambiguous fetch/push
identities, a subdirectory supplied as root, detached HEAD, another branch
(including another maintenance branch), or any HEAD mismatch. It accepts
equivalent HTTPS/SSH remote spellings through the existing identity helper.
It performs no network calls, authentication, branch changes, writes, commits,
or pushes. Dirty status is reported, not discarded: inspect it, preserve
unrelated changes, and stop for clarification if they conflict with the task.

Every `framework-maintenance.ps1` operation also runs this check, with the exact
branch derived from the explicitly approved `-Task` and a mandatory
`-ExpectedHead`. This is an intentional maintenance API change: callers must
now pass the reviewed HEAD, not a value guessed from their current checkout.
The initial task preflight requires the exact starting SHA, not merely an
ancestor. After a separately approved commit, review and record the resulting
SHA before using it for another operation. Do not update the baseline silently.

## Approval boundaries

Use `framework-maintenance.ps1` for exact approved paths and text updates.
Modification, commit, and push each require their own approval and operation;
merge requires a further explicit human approval and is not implemented by
this script. Never bundle approvals. A successful preflight does not grant any
of them. Preserve existing branches and histories; never force-push or reset
to make a preflight pass. Stop and report the mismatch instead.

Follow the existing durable recovery policy in `docs/skill-distribution.md`.
A task-specific approved durable-backup exception applies only to that task:
record it in the implementation handoff without requesting it again or
promoting it to a permanent exemption.

## Application and skill boundaries

Application Authoring Mode still requires a verified read-only installation,
a separately resolved writable `TargetProjectRoot`, and the existing source
protection gates. This maintenance check does not replace or relax them.
Copied skills are not runtime installations.

The two planning-only skills are `dataverse-solution-architect` and
`power-platform-requirements-analyst`. They do not create a new execution path,
authenticate, deploy, or authorize starting any subsequent skill. The wizard
contract and `docs/onboarding.md` remain authoritative for all execution.

## Regression checks

Run `pwsh ./scripts/ci/test-framework-context-preflight.ps1` and
`pwsh ./scripts/ci/test-framework-source-protection.ps1`. Both use isolated
temporary repositories, never change the operator's branch or history, and
exercise failed checks before any framework write.
