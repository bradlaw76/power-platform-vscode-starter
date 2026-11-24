# Queued autonomous delivery and web-resource-first iteration

Status: **operating guidance / proposed integration contract**. This page does not create a background process, scheduler, Copilot API, browser driver, Dataverse authorization, or new deployed capability.

## Default user experience

When a user asks for a multi-step build or change, the assistant should **offer a complete copy/pasteable execution bundle by default**, rather than requiring a new prompt after every task. Provide (1) a primary instruction that discovers the current executor and its queue, (2) an ordered, dependency-aware backlog, (3) self-correction/recovery instructions, and (4) a clear summary of work that needs the owner. Single focused edits do not need artificial queues.

For **explicitly autonomous multi-change work**, recommend a dependency-aware
queue, not repeated one-task approval loops. Reuse accepted requirements and
standing scoped nonproduction authorization under the canonical
[authorization and execution policy](policies/authorization-and-execution.md).
Queueing is coordination, not authorization. Recoverable registration, H
numbering and narrative documentation must not delay independently authorized
implementation unless required for real authority, enforced policy or conflicting
writers; reconcile them before closure. H IDs track outcomes, not permanent
component ownership; preserve historical IDs and request allocator review rather
than inventing or reusing one.

Use **queue** for the concept in documentation; describe **cue/queue** when assisting a user who calls the feature “cues.” A Copilot chat prompt is not itself a durable queue or a guarantee of unattended execution. Verify the actual worker/extension and its persistence first. If no suitable executor exists, provide sequential prompts and explain that continuing requires the user to run them, or implement/test the required executor as a separate approved change.

### User instructions for VS Code

1. Open the intended repository or workspace in VS Code and confirm the selected GitHub account and branch. Open GitHub Copilot Chat in **Agent** mode if the installed extension supports it.
2. Check for existing tasks, branches, PRs, locks and an active worker. **Attach to/resume** the existing owner if possible; otherwise wait on its conflicting work. Do not create duplicate agents or assign new H-numbers independently. An H-number comes from the project's authorized allocator.
3. Paste the instruction bundle below. If a supported persistent queue/task runner has been installed, translate the work items to its documented queue interface and verify that the items are actually persisted. If no runner is installed, Copilot can complete sequential steps in the current session, but cannot be assumed to run after the session ends.
4. Keep the editor/worker host available if execution is local. Check the queue/task store and its timestamped status; restarting VS Code alone does not prove automatic recovery. Checkpoint and recovery must be demonstrated by tests.
5. Review the final evidence: commit/PR, tests, live deployment receipts if applicable, what changed, remaining blockers, and rollback reference.

### Native VS Code message queue — required link in every multi-item response

Official agent overview: https://code.visualstudio.com/docs/agents/overview

Message queue instructions: https://code.visualstudio.com/docs/chat/chat-overview#_send-messages-while-a-request-is-running

For each generated multi-item queue, include the agent overview URL, message queue link and the following short instructions immediately before the separately copyable task prompts. Verify feature availability in the selected installed harness/session rather than assuming every agent supports the same controls:

1. Start the first task in VS Code Copilot Chat using the intended agent/session.
2. While it runs, paste the next task into the same chat. Open the Send dropdown and select **Add to Queue**. Repeat for each remaining task in dependency order.
3. Drag pending messages to reorder them if needed. Avoid **Steer with Message** or **Stop and Send** for routine follow-up tasks because they interrupt the current request.
4. To make queueing the default, open Settings (Ctrl+, on Windows), search for `chat.requestQueuing.defaultAction`, and select `queue`. Alternatively set `"chat.requestQueuing.defaultAction": "queue"` in user settings JSON. Settings reference: https://code.visualstudio.com/docs/agents/reference/ai-settings
5. Check that each message appears in the pending queue. Native queueing automatically submits follow-ups after the current response ends; it does not guarantee task success, reboot recovery, persistent worker execution or unattended permission approval.

Each queued prompt must independently check predecessor completion and current ownership, resume from evidence, self-correct bounded failures, and skip or wait on unmet dependencies. If the queue control is unavailable, verify the installed VS Code/Copilot version and session support; use the documented sequential fallback. Never imply that a native message queue is equivalent to a durable automation worker.

**Required response format:** official URL + short how-to + primary prompt + individually copyable Q01, Q02, ... prompts + dependencies and expected outcome. Queue numbers are local ordering labels, not new H-number allocations.

### Copy/paste starter prompt

```text
Load the actual project-local AGENTS and canonical execution policy before acting.
Preserve stricter project requirements; missing instructions require the shared
wizard inheritance/migration path, not a remote link or copy-over.
Inspect this repository's current instructions, authorized scope, working tree, open PRs,
existing task queue/worker and dependency locks. Reuse the existing execution owner.
Read https://code.visualstudio.com/docs/agents/overview and verify the selected
agent/session's actual queue and recovery support before making capability claims.
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
Reuse accepted requirements and valid standing scoped nonproduction permission.
Do not block independently authorized repairs for registration, numbering or
narrative documentation alone; reconcile those before closure. Preserve all
semantic/report/hash/FAST/security gates and enforced repository controls.
H IDs track outcomes, not permanent component ownership. Check active process,
checkpoint and actual resource evidence before writer release. Lease expiry alone
is insufficient; recover before restart, never spawn a conflicting writer.

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

### Individually copyable queue example

Adapt these local ordering labels to the accepted scope; they allocate no H IDs.
Paste the primary prompt first, then queue these messages using the controls
above. Dependencies are evidence checks, not an instruction to start new writers.

**Q01 — Inspect/recover. Depends on: existing authorization. Outcome: known owner,
accepted requirements, affected contracts and ready/blocked items.**

```text
Q01: Inspect accepted requirements, current scope and existing process/session,
checkpoint, branch/PR and actual resource evidence. Attach/recover before restart;
lease expiry alone cannot release a writer. Preserve all original worktrees.
Report dependency-ready work and exact resource holds. Do not allocate an H ID,
enable an executor or expand authority.
```

**Q02 — Implement/verify. Depends on: Q01 evidence for the affected resource.
Outcome: bounded authorized changes and focused test/readback evidence.**

```text
Q02: Recheck Q01 evidence, authority and current ownership. Implement only
dependency-ready changes under accepted requirements and the canonical policy.
Keep minimum repair/rollback evidence; preserve semantic/report/hash/FAST/security
gates. Apply bounded material repairs and targeted regressions. Reconcile uncertain
writes before retry. Continue independent work; hold conflicting resources.
Do not treat registration or narrative documentation alone as an implementation
blocker absent real authority, enforced policy or a conflicting writer.
```

**Q03 — Reconcile/handoff. Depends on: Q02 results. Outcome: exact source/evidence,
administrative reconciliation and truthful completion report.**

```text
Q03: Verify Q02 results from current source and target evidence, not chat status.
Reconcile accepted source/hashes, tests, rollback, registration and narrative
documentation before closure. Prepare separate STARTER/AUTO outcome mappings only
when requested; do not allocate H IDs. Report source, tests, deployment and live
verification separately. Commit/push/PR/merge/release each retain their actual
authorization. If no durable executor ran, say so; never claim live acceptance
from local tests or prepared prompts.
```

## Executor contract and self-correction

- **Queue state:** stable task IDs (allocated by authorized project mechanism), dependency graph, priorities, owner/lock, scope/permissions, attempt count, checkpoint, target repository/environment, and evidence links.
- **Scheduling:** use one writer for a shared component/environment; safe read-only or independent tasks may run in parallel. Do not overwrite other branches or accepted user edits. Wait and recheck locks.
- **Recovery:** persist state outside ephemeral chat context; on restart inspect latest authoritative branch, task store, lease and tenant snapshot before resuming. Identify stale locks by the runner's proven fencing protocol, not age alone.
- **Writer release:** require active process/session, durable checkpoint and actual resource/in-flight-write evidence before release or takeover. Lease expiry alone is insufficient. Attach/recover before restart; if evidence is missing, hold the conflicting resource and dependents while advancing independent authorized items. Never delete locks to force progress.
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

Apply the canonical policy's
[native application safety and browser acceptance](policies/authorization-and-execution.md#native-application-safety-and-browser-acceptance)
before this path: observe the actual browser principal (not declared session or
API-admin identity), stop on mismatch, validate publication blast radius while
preserving unrelated drafts, retain unexpected native record change evidence
without blind rollback, classify restrictions without bypass, and verify
intended app/user form eligibility rather than direct URL access alone. Recover
the independent browser process/session from current checkpoint/resource evidence
and repeat principal preflight. Missing native support stays partial/unverified;
this guide does not supply Automation runtime or claim a native pilot.

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
