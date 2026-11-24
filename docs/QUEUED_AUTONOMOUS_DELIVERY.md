# Queued autonomous delivery and web-resource-first iteration

Status: **operating guidance / proposed integration contract**. This page does not create a background process, scheduler, Copilot API, browser driver, Dataverse authorization, or new deployed capability.

## Default user experience

When a user asks for a multi-step build or change, the assistant should **offer a complete copy/pasteable execution bundle by default**, rather than requiring a new prompt after every task. Provide (1) a primary instruction that discovers the current executor and its queue, (2) an ordered, dependency-aware backlog, (3) self-correction/recovery instructions, and (4) a clear summary of work that needs the owner. Single focused edits do not need artificial queues.

Use **queue** for the concept in documentation; describe **cue/queue** when assisting a user who calls the feature “cues.” A Copilot chat prompt is not itself a durable queue or a guarantee of unattended execution. Verify the actual worker/extension and its persistence first. If no suitable executor exists, provide sequential prompts and explain that continuing requires the user to run them, or implement/test the required executor as a separate approved change.

### User instructions for VS Code

1. Open the intended repository or workspace in VS Code and confirm the selected GitHub account and branch. Open GitHub Copilot Chat in **Agent** mode if the installed extension supports it.
2. Check for existing tasks, branches, PRs, locks and an active worker. **Attach to/resume** the existing owner if possible; otherwise wait on its conflicting work. Do not create duplicate agents or assign new H-numbers independently. An H-number comes from the project's authorized allocator.
3. Paste the instruction bundle below. If a supported persistent queue/task runner has been installed, translate the work items to its documented queue interface and verify that the items are actually persisted. If no runner is installed, Copilot can complete sequential steps in the current session, but cannot be assumed to run after the session ends.
4. Keep the editor/worker host available if execution is local. Check the queue/task store and its timestamped status; restarting VS Code alone does not prove automatic recovery. Checkpoint and recovery must be demonstrated by tests.
5. Review the final evidence: commit/PR, tests, live deployment receipts if applicable, what changed, remaining blockers, and rollback reference.

### Copy/paste starter prompt

```text
Inspect this repository's current instructions, authorized scope, working tree, open PRs,
existing task queue/worker and dependency locks. Reuse the existing execution owner.
Build a dependency-ordered backlog for my request. Provide the entire ordered queue
up front; do not stop after each routine task for another prompt.

Within the authorized scope, proceed across safe independent tasks and checkpoint
after meaningful steps. On a failure, classify the failure; try a bounded fix;
rerun targeted checks; retry transient problems with backoff and a limit;
then continue unblocked tasks. Do not spin in an infinite retry loop.

Never bypass ownership, permission, protected-source, secret handling, security,
destructive-action, or deployment gates. Do not manufacture an approval or report
simulation as live verification. Re-read actual state after a conflict/restart.
Keep existing H-number assignment and PR ownership rules.

For Dataverse HTML/JavaScript web-resource UI work, use the web-resource-first
workflow in this repository: verify backup and target, retain a minimum change
contract, implement in a safe editable source, publish only when authorized,
test the live UI, repeat until accepted, then reconcile/export exact source and
update documentation. Protect explicitly frozen handlers/verification logic.

Report concise timestamped checkpoints with completed, queued, blocked and
live-verified status, actual evidence links, and a recovery/rollback path.
If no durable executor is configured, state this explicitly and perform the
available work in this session rather than claiming unattended operation.
```

## Executor contract and self-correction

- **Queue state:** stable task IDs (allocated by authorized project mechanism), dependency graph, priorities, owner/lock, scope/permissions, attempt count, checkpoint, target repository/environment, and evidence links.
- **Scheduling:** use one writer for a shared component/environment; safe read-only or independent tasks may run in parallel. Do not overwrite other branches or accepted user edits. Wait and recheck locks.
- **Recovery:** persist state outside ephemeral chat context; on restart inspect latest authoritative branch, task store, lease and tenant snapshot before resuming. Identify stale locks by the runner's proven fencing protocol, not age alone.
- **Repair:** classify transient infrastructure failures vs. code/test defects vs. access/security/design blockers. Apply bounded idempotent repairs, relevant tests and exponential backoff. If attempts exhaust, record the blocker and advance other independent work.
- **Acceptance:** verify each task against explicit requirements; distinguish prepared/source-only, validated in tests, deployed, and user-visible live verified. Never label a queued prompt as executed.
- **Safety:** no credential leakage, automatic merging of protected PRs, or tenant writes without scope-specific permission; retain backup/rollback and evidence of who authorized a change.
- **Implementation gap:** integrate these behaviors with the repository's *existing supported* task/worker interfaces; add missing CLI/UI/testing only via a separately tracked implementation with acceptance coverage. This document alone is not runtime functionality.

## Web-resource-first path: less paperwork, faster feedback

**Default for UI web resource work:** minimum viable contract → controlled source/resource change → targeted publish → live test → fix → source reconciliation → concise final documentation.

### New build

Before any write, establish intended user journey, required schema/security, environment/solution/publisher, app membership, dependencies, critical acceptance criteria, and rollback. Honor the starter's required Spec Kit files where applicable: `spec.md`, `plan.md`, `tasks.md`. They can be **concise and scoped**: not a lengthy design dossier. A new component must be added to the correct solution and published in dependency order; do not deploy a web resource before tables, fields or forms that it depends on are ready.

After minimum gates, implement the smallest demonstrable vertical slice; test visually and functionally as soon as it can run. Iterate on the live experience instead of writing exhaustive documentation before first feedback.

### Existing Dataverse web resource / contact UI repair

1. Capture exact organization/environment, solution, app/form selection, record test fixture, resource name/id, published/unpublished versions, references and hashes; export a verified rollback copy. Confirm active writer ownership and protected features.
2. Record a **short change contract**: current behavior, desired behavior, protected interfaces/handlers, tests and rollback. Identify Contact field/record effects separately from HTML edits. A web resource rewrite is not authorization to rewrite Contact data.
3. Edit the source (or, when explicitly approved, the target resource directly with captured before-state). Use supported concurrency checks, publish only the selected authorized scope, reload the right form and verify the actual runtime content/version.
4. Test in browser against intended Contact/Case records, roles and app. Validate existing behavior plus requested UX changes. On a defect, make a bounded correction and repeat. Halt/rollback on protected behavior regression.
5. Once accepted, immediately **export/reconcile the exact tenant-accepted HTML/JS** into Git, check hashes/diff to avoid tenant/source drift, update affected tests and minimal README/runbook, and attach deployment and rollback evidence. Treat documentation reconciliation as a mandatory completion step, not optional indefinite debt.

### Protected functionality and examples

Project-specific restrictions override generic convenience: for SSA Direct Deposit, **TED may change; Super Six verification functionality may not change** without explicit reversal. A visual cleanup is not permission to alter Super Six handlers or verification contract. Preserve source, behavior and testing evidence accordingly.

## Default report format

```text
Time / repo / branch / existing worker
Completed: task IDs + commit/PR + tests
Deployed and live verified: exact environment, resource, record, verification evidence (or "not verified")
Queued: dependency order + owner + next safe action
Self-repairs: problem, bounded fix, re-test result
Blocked / owner decisions: only genuine permission, security, architecture or destructive changes
Rollback: verified backup/export and restore procedure
Documentation/source reconciliation: complete / pending (pending prevents closure)
```
