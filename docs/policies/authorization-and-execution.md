# Authorization and execution

## Scope and precedence

This operational contract is mandatory for framework maintenance and every
wizard-generated or wizard-managed project, across all workloads, industries
and modes. It is not limited to any particular application or Power Pages.
It guides execution; it does not grant permission or introduce an approval
system. Higher-priority instructions, repository protections, platform
confirmations, signed approvals and environment security controls still apply.
When rules conflict, retain the stronger safety boundary and report the conflict.

Use the target project's existing policy, planning and evidence mechanisms.
In this framework, [onboarding](../onboarding.md) remains the bootstrap sequence
authority; scenario `spec.md`, `plan.md` and `tasks.md` precede app implementation.
Preserve semantic-field and report-definition approvals, Choice/form plan-hash
approvals, solution membership/export gates and existing overwrite confirmations.
FAST stays default-off: readiness is not execution permission,
`executionAuthorized: false` remains mandatory, and FAST-dependent Apply remains
blocked. No conversational permission overrides those restrictions.

## Reuse valid authorization

Before each consequential operation, match existing explicit permission to:

- The task and operation (local edits, commit, push, PR, deployment or cleanup).
- The repository/branch or environment/tenant, solution/site and components.
- The approved inputs, intended effects and any time or other constraints.
- The permission's continuing validity: not expired, revoked or superseded.

Use the conversation and existing approved planning/run artifacts; do not create
a new approval ledger. Never infer permission from credentials, access, a prior
unrelated task, an architecture decision, a readiness result or urgency.
If scope is unclear, stop that operation and request only the missing decision.
Revalidate after a target, artifact hash, effect, ownership or authority changes.

Reuse valid, explicitly scoped authorization throughout the authorized task.
Never create redundant owner-approval gates when authorization is already valid.
Commit and push each require explicit permission; a single request explicitly
covering both satisfies both requirements. Commit permission alone does not
permit push; push/PR permission does not permit merge, release or deployment.
A deployment request is usable only when its target and effects are explicit.
Required platform prompts and signed approvals must still be satisfied through
their established mechanisms; never simulate or auto-sign human approval.

## Discover and reuse deployment patterns

Inspect the target repository, instructions, runbooks, scripts, manifests,
lockfiles, prior successful run evidence and current target state before
introducing alternatives. Reuse a verified deployment pattern only after checking
that its platform, target, tool version, inputs and ownership match this task.
Prior success is evidence for a method, not permission for another deployment.

Prefer supported Dataverse APIs through the shared resilient runtime and the
authoritative bootstrap sequence. For Power Pages projects, use their established
PAC CLI deployment procedures and site-specific validation when appropriate;
do not invent Power Pages infrastructure in unrelated wizard workloads.
If no suitable pattern exists, explain the gap and choose a supported method
within scope. Material architecture or authorization changes need a decision.

## Fix technical failures within scope

Fix technical errors autonomously within scope: missing dependencies,
configuration, approved fields and deployment scripts. Use existing package
managers and lockfiles; install/restore only after manifest changes or a verified
missing-dependency failure. Diagnose first, make a material correction, run
focused checks, then resume the authorized operation.

An unplanned field or type migration is not a technical shortcut: update and
approve the semantic design before generation. Never bypass validation, weaken
security, change a target, expand privileges or replace a managed/production
component merely to make deployment pass.

## Bound retries and reconcile writes

Use the existing runtime's bounded retry budget, 401 token refresh and 429
exponential backoff/Retry-After handling. If a tool defines no budget, use at most
three total attempts per operation for transient failures. Record attempts and
sanitized errors in existing run evidence.

After a timeout or ambiguous write, read back by stable component identity,
operation ID or idempotency key before any retry. Reconcile uncertain writes:
continue if the intended state is confirmed, retry only when absence is proven
and the write is safe, otherwise mark that operation BLOCKED. Never blindly
repeat a create, import or deployment that might already have succeeded.

Stop repeating unsuccessful operations without a material change. An unchanged
deterministic error gets no retry; after the bounded transient budget, diagnose
or block. A new attempt requires a recorded change relevant to the cause, not
merely a new session or invocation. Never hide failure with a success fallback.

## Preserve components and concurrent work

Inspect current state and ownership before mutation. Preserve existing
components, data, environments and concurrent work, including production
components outside the approved change set. Use scoped updates, stable IDs,
readback and concurrency checks where supported. Do not delete/recreate a
component to resolve drift or overwrite another operator's change.
Destructive cleanup, production changes and changes to existing OOB components
require their applicable explicit scope and safety gates. Framework integration
tests remain non-production only.

Preserve dirty worktrees and active branches; use a suitable isolated branch or
worktree without stashing, reverting or committing unrelated work. If one
operation is blocked, continue independent authorized work only when it does not
depend on that operation or change the blocked target. Record dependencies and
do not claim completion for downstream work that could not be verified.

## Completion and evidence

When deployment is requested and authorized, complete implementation, focused
testing, authorized deployment and live verification. Source changes alone are
not the requested deployment outcome. Verify the actual target identity,
published component state and representative user path with the intended access.
If credentials, platform controls or target access prevent verification, report
the precise boundary; do not substitute mocks or source inspection.

Report these evidence-backed statuses separately, per operation where needed:

| Status | Required evidence |
| --- | --- |
| SOURCE COMPLETE | Intended source/configuration changes persist; identify files and local/commit SHA. |
| TESTED | Name commands, results and test scope; distinguish mocks from live checks. |
| DEPLOYED | Target identity and successful deployment/publish or reconciled readback evidence. |
| LIVE VERIFIED | Actual target readback and representative user-path verification; not just upload success. |
| BLOCKED | Affected operation, cause, attempts, missing permission/access/input and next action; independent results remain visible. |

These are not interchangeable. In particular, TESTED does not imply DEPLOYED,
and DEPLOYED does not imply LIVE VERIFIED. Preserve separate Git states:
modified, committed, pushed, PR opened and merged. Verify the remote SHA before
reporting a successful push; never infer a deployment from a GitHub publication.

## Handoff and inheritance

Reuse the existing GitHub PR, build log and review handoff requirements; record
scope, changes, commands/results, evidence links, status and unresolved issues
there. Do not add a parallel report or approval system. When repository
protection prevents a required handoff, report
**HANDOFF NOT WRITTEN - BLOCKED** with a complete transferable report; never
bypass the protection to write documentation.

Full wizard clones inherit this policy through the checked-in Copilot
instructions, prompt and skills. For another generated/consumer project, include
this policy or an explicitly reviewed equivalent operational contract, and
reference it from that project's existing instruction entry point before
mutating work. Reuse the compatibility review in
[skill distribution](../skill-distribution.md); do not silently replace existing
instructions. Installing a skill is not installing the wizard runtime.

Installed Claude skills carry an installer-generated, byte-identical policy in
`references/authorization-and-execution.md`. Resolve project-local policy first;
use the bundled contract when project-local policy is absent. If neither exists,
report BLOCKED for mutating work and continue only independent read-only work.
Never treat a bundled policy as permission or overwrite a stricter local policy.

## Contract scenarios

These scenarios define expected decisions for instruction/distribution tests,
not a new runtime authorization engine or proof of autonomous agent compliance.

| Case | Situation | Required behavior |
| --- | --- | --- |
| AUTH-01 | Owner explicitly permitted commit and push for this task/branch; scope is unchanged. | Reuse valid authorization; do not ask again. |
| AUTH-02 | The task permits local fixes, but deployment targets another tenant. | BLOCKED for deployment; request the missing target scope. |
| AUTH-03 | Authorized deployment fails because a declared dependency is missing. | Correct the dependency, run focused checks and resume within scope. |
| AUTH-04 | A prior verified deployment script matches current target and inputs. | Reuse the verified pattern after compatibility checks. |
| AUTH-05 | Deployment encounters an existing production component outside scope. | Preserve it; block the conflicting operation, never delete/recreate it. |
| AUTH-06 | One operation is blocked but an authorized local test is independent. | Continue the independent test; report the blocked dependency separately. |
| AUTH-07 | Source and mock tests pass but there is no target verification. | Report SOURCE COMPLETE and TESTED, not DEPLOYED or LIVE VERIFIED. |
| AUTH-08 | A write times out or the same deterministic failure recurs. | Reconcile uncertain writes; no unchanged deterministic retries; bound transient attempts. |
