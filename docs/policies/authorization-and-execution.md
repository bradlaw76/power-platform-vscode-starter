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

## Proportional planning and verification

Use the [scenario change impact gate](../scenario-change-impact-gate.md) to classify the actual delta. Minor maintenance retains accepted planning and uses focused checks without regenerating the full matrix. Scenario changes update affected contracts and dependent surfaces; new or cross-cutting scenarios review the applicable end-to-end chain. Mandatory CI, production, signed-approval, environment and live field/security gates are never waived.

Reuse accepted requirements, architecture decisions, bindings and evidence while
they remain applicable. Ask only for a missing material decision, not a replay of
discovery. A new component or changed requirement still needs its affected
planning contracts before implementation; an existing-component repair that
restores accepted behavior does not need a new planning dossier.

Reuse accepted delivery answers and valid explicit automation opt-in only while its scope remains unchanged. A deadline is a target, not permission; guided execution remains available without WSL and no unattended work starts implicitly. This policy preserves configured safeguards; it does not install features absent from the current baseline or grant execution authority.

## Mandatory controls and recoverable administration

Production authorization, security/access boundaries, secret handling, signing,
platform confirmations and enforced repository controls are mandatory. Never
disable a protection, manufacture approval or reinterpret an explicit owner
restriction as administrative inconvenience. Preserve semantic-field and
report-definition approvals, hash/signature gates, FAST restrictions, solution
membership and required validation even for urgent nonproduction repairs.

Project registration, H numbering, task bookkeeping and documentation are
recoverable project administration unless they establish real authority, satisfy
an enforced policy or resolve conflicting writers. Administrative registration,
H-number allocation and documentation must not block independently authorized
implementation when none of those exceptions applies. Record the missing
administration and reconcile it in the existing task/PR before closure; do not
silently waive it or create a competing approval ledger. An explicit read-only
allocation restriction still binds until its authorized owner supersedes it.

H IDs track outcomes, not permanent component ownership. Preserve historical
H008/H009/H010 and all accepted identifiers; never invent, rename or reuse an H
ID. Use the existing temporary work identifier while authorized allocation is
pending. Where ChatGPT is the designated allocator, submit separate STARTER and
AUTO outcome mappings for review; a proposal is not an allocation or permission.
Component writer ownership is established by current resource/process evidence,
not inferred from an old H label.

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

### Standing scoped nonproduction authorization

An owner may explicitly authorize a standing scope for routine development,
repair, testing and, only if specified, nonproduction publish/deployment.
Record or reference it in existing planning/task/PR evidence: owner, permitted
operations/effects, exact repository/branch or environment/tenant/solution,
components, exclusions, validity/revocation conditions and required verification.
Nonproduction status and credentials alone never constitute authorization.

Reuse that authority without repeated confirmation while all scope checks above
still pass. A scope change, expiration, revocation, production target, destructive
effect or newly required gate stops only the affected operation for a decision.
Standing permission cannot approve a semantic/report definition or sign an
artifact hash by implication; satisfy those separate gates through their
established mechanisms. It does not activate a scheduler, expand privileges or
authorize commit, push, merge or release unless explicitly included.

### Routine repairs and retrospective documentation

For a routine authorized nonproduction existing-component repair, first verify
the target, accepted behavior, writer, bounded effect, applicable gates and
recoverable before-state/rollback. Keep a minimum change contract in the existing
task/PR/checkpoint: defect, intended correction, protected behavior and focused
checks. Then implement, run targeted regression/readback checks and, only when
already authorized, publish and verify the actual target.

Full narrative documentation and administrative registration may follow the
repair rather than delay it. Reconcile exact accepted source, hashes, tests,
authorization reference, rollback and remaining limitations in existing records
before closure. Retrospective documentation is not retrospective permission,
semantic/report approval, hash approval or security review. New requirements,
schema/type changes, report meaning, security boundaries and protected/OOB
components retain their applicable pre-change planning and approval gates.

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

Before releasing or taking over a writer, inspect active process/session state,
latest durable checkpoint/journal, current branch/PR and actual resource state
and in-flight writes. Lease expiry alone is insufficient evidence of release.
Attach to or recover the existing owner first; do not start a duplicate writer.
Use the executor's supported fencing/recovery protocol where available. If
ownership or an uncertain write cannot be reconciled, hold only that resource
and its dependents, record the missing evidence and continue independent work.
Do not delete locks or reset state merely to force a restart. Repair within the
bounded budget above; a fresh session does not reset that budget.

For explicitly autonomous multi-change work, recommend a dependency-aware queue
with ready items, owner/resource scope, checkpoints and blocked reasons. Follow
[queued delivery](../QUEUED_AUTONOMOUS_DELIVERY.md), including ready-to-paste VS
Code instructions. Verify the installed executor's actual capabilities; native
message queueing is not proof of durable recovery or unattended permission.

## Completion and evidence

### Native application safety and browser acceptance

These are generic safety obligations for authorized native application work,
not a browser driver, runtime installation or evidence that a pilot has run.
Automation runtime capabilities and their tests belong to the Automation
repository; Starter supplies guidance and instruction/distribution contracts.

1. **Actual browser principal preflight:** before browser acceptance or native
   writes, observe the actual authenticated browser principal using supported
   application/session evidence and compare it with the owner-selected intended
   user, target and access scope. A session-declared identity, displayed persona
   switch or separate API administrator identity is not browser-principal proof.
   Identity mismatch stops the affected operation before writes; missing or
   unverifiable principal evidence blocks it. Recheck after login, target or
   session changes. Retain sanitized principal/target evidence, never credentials.
2. **Publication blast radius:** inspect the supported publication mechanism,
   dependencies and current published/unpublished state before publishing.
   Validate that the actual publication scope preserves unrelated drafts, not
   merely that the edited component is authorized. Broad table/app publication
   can promote unrelated pending changes. If scoped publication cannot be proven,
   stop that publication and report the unsupported/uncertain boundary; do not
   widen scope or claim partial publication as complete.
3. **Unexpected native record modification:** capture permitted before-state,
   stable record identity/version and the expected write set; compare native
   readback after the operation. Distinguish authorized effects and explicitly
   expected platform changes from unexpected record/field modifications. On an
   unexpected change, stop further affected writes and retain sanitized before/
   after, diff, timing, operation and principal evidence for owner investigation.
   Do not blindly roll back, overwrite concurrent changes or delete records;
   recovery needs reconciled state and its applicable explicit authority.
4. **Restriction classification:** classify observed restrictions separately as
   application-created, security/access, platform-enforced or unknown, recording
   the supporting evidence. Application-created does not mean safe to bypass:
   a business rule may protect data or enforce an approved contract. Only an
   authorized scoped repair with applicable planning/security gates may change
   it. Security/platform restrictions retain their established controls; unknown
   restrictions block the affected action until understood. Classification is
   diagnosis, never permission to bypass a control.
5. **Form eligibility in app/user context:** verify the intended form's published
   app membership, user/role eligibility, table/form type and supported selection/
   fallback behavior in the intended app. Mere direct URL access is not proof of
   form eligibility in the intended app/user context. Retain evidence of the
   actual selected form and representative user path; report direct-access-only
   or missing native support as partial/unverified rather than accepted.
6. **Independent browser-session recovery:** maintain the owner-selected browser
   session's independent process/owner, target, observed principal and durable
   checkpoint evidence, separate from an API worker or its administrator session.
   Before recovery/restart, reconcile active browser processes, outstanding
   writes and actual resource state; lease expiry or a stale session declaration
   cannot release its writer. Reattach/recover through supported mechanisms,
   repeat browser-principal preflight and read back uncertain effects before
   continuing. If support/evidence is missing, hold that session/resource and
   continue only independent authorized work; never launch a conflicting writer.

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
| AUTH-09 | Standing owner permission covers this exact nonproduction repair and remains valid. | Reuse standing scope; verify target and effects, retain separate required approvals. |
| AUTH-10 | Independently authorized repair awaits H registration or narrative documentation, without an authority/policy/writer conflict. | Implement the bounded repair; reconcile administration and documentation before closure. |
| AUTH-11 | A routine repair would change a field type, report definition, signed hash or FAST gate. | Stop the affected operation for its required pre-change gate; retrospective documentation is not approval. |
| AUTH-12 | A writer lease expires while its process, checkpoint or target write state is uncertain. | Recover before restart; lease expiry alone does not release the writer. |
| AUTH-13 | A historical H outcome touched the component but no conflicting writer remains. | Check current ownership evidence; preserve the H ID, do not treat it as permanent ownership. |
| AUTH-14 | Explicitly autonomous multi-change work has one blocked dependency. | Queue dependency-ready authorized work; preserve the hold and verify actual executor support. |
| AUTH-15 | Browser identity is session-declared or belongs to a separate API administrator, not the observed intended browser user. | Block before writes; actual browser-principal preflight is required and identity mismatch stops the operation. |
| AUTH-16 | Publishing an authorized form through its table/app would promote unrelated drafts. | Stop broad publication; validate actual blast radius and preserve unrelated drafts. |
| AUTH-17 | Native readback shows an unexpected record/field modification. | Stop affected writes, retain before/after evidence and investigate; no blind rollback. |
| AUTH-18 | A restriction appears application-created but its purpose or authority is unresolved. | Classify separately from security/platform/unknown; diagnosis does not permit bypass. |
| AUTH-19 | A form opens by direct URL but intended app/user eligibility is unproven. | Report partial/unverified; verify app membership, eligibility and the actual selected form. |
| AUTH-20 | Browser acceptance resumes after its independent process/session was interrupted. | Reconcile process/checkpoint/resource evidence, repeat principal preflight and recover uncertain writes before continuing. |
