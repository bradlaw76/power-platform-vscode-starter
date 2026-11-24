# Authorization and execution

This is the single active execution policy for framework and wizard-managed
projects. It guides work, not permission. Preserve actual security/access and
environment security controls,
production, signing, platform confirmations and enforced repository protections.
Current explicit owner scope supersedes historical procedural restrictions,
never actual protections or protected functionality.
Protection lookup HTTP403 means unverified configuration, not absent protection
or evidence that an attempted write was denied. Actual protection/preflight
rejection stops the affected operation; never bypass it.

## Development first, within authority

For authorized nonproduction corrections:

1. Identify the accepted outcome and affected components.
2. Perform minimal risk-based preflight and verify applicable recoverable backup.
3. Implement; run targeted safety/predeployment tests.
4. Deploy/publish only within existing explicit scope; verify actual functionality.
5. Correct bounded defects, retest and continue independent authorized tasks.
6. Reconcile source, affected specifications and documentation after validation.

Reuse accepted requirements and evidence whose inputs/applicability are unchanged.
Routine UI/web-resource repairs do not need new discovery or a complete planning
package. Significant features, architecture, semantic/business meaning, security
or material scope changes retain relevant requirements, design and acceptance
before implementation. [Scenario impact](../scenario-change-impact-gate.md)
identifies the affected contracts; do not regenerate an unchanged matrix.
[Onboarding](../onboarding.md) remains the sole bootstrap sequence authority.

Preserve semantic-field and report-definition approvals, Choice/form plan-hash
approvals, solution membership/export gates and protected/OOB component scope.
FAST stays default-off: `executionAuthorized: false`; FAST-dependent Apply remains
blocked. Readiness, urgency, credentials and a policy edit never approve execution.

## Reuse valid authorization

Before consequential operations, match continuing explicit permission to task,
operation, repository/branch or environment/tenant/solution, components, approved
inputs/effects, exclusions and validity/revocation conditions. A scope change,
expiration, revocation, production target, destructive effect or required gate
stops only the affected operation. If scope is unclear, stop that operation.

Reuse standing scoped nonproduction permission without repeated confirmation.
Never create redundant owner-approval gates when authorization is already valid.
Commit and push each require applicable scope; one instruction may cover both.
Commit permission alone does not permit push; push does not permit merge/release/
deployment. Nonproduction status and credentials alone never constitute authorization.
Standing permission cannot approve a semantic/report definition or sign an artifact
hash by implication. Satisfy signed approvals and required platform prompts through
their real mechanisms; never fabricate or auto-sign acceptance.

## Proportional documentation and tracking

| Change | Minimum relevant record |
| --- | --- |
| Routine correction | Brief defect/accepted outcome; scoped backup receipt where applicable; implementation reference; targeted result; incremental task/changelog update |
| New feature/material architecture | Relevant requirements/design; functional acceptance; implementation/deployment evidence |
| Security-sensitive/destructive | Explicit authority; security/impact assessment; verified recovery; applicable approvals before mutation |

Use existing task/issue/PR/checkpoint records, not competing approval ledgers.
Retrospective documentation is not retrospective permission.
Project registration, H numbering and narrative documentation are recoverable
administration unless they establish real authority, satisfy an enforced policy
or resolve conflicting writers. Recover them independently of authorized development.
H IDs track outcomes, not permanent component ownership; preserve historical/
suffixed assignments and the designated allocator. Retries/recovery do not create
new work IDs. An explicit read-only restriction still binds unless its owner
supersedes it; a historical allocation restriction is not current authority.

## Recovery, blockers and testing

Inspect only affected state and reuse the verified deployment pattern after
compatibility checks. Prior success is evidence for a method, not permission.
Fix technical errors autonomously within scope; reuse package managers/lockfiles
and restore dependencies only after manifest changes or missing-dependency failure.
Use targeted regression; broaden only for a concrete risk/failure or mandatory CI,
security, production, signature, environment or live-acceptance gate.

Use existing retry budgets, 401 refresh and 429 backoff/Retry-After. If none is
defined, use at most three total attempts per operation for transient failures.
An unchanged deterministic error gets no retry. After ambiguous mutation, read
back by stable component identity/operation ID/idempotency key before retry.
Confirm intended state, prove absence before safe replay, or hold the operation.
Never hide errors or blindly repeat uncertain creation, import or deployment.

Preserve production components outside the approved change set, dirty worktrees,
Portal drafts, unrelated published/unpublished changes and protected functionality.
Do not delete/recreate components, clear locks or blindly reset state.
Before writer release, reconcile active process/session state, latest durable
checkpoint/journal, actual resource state and in-flight writes.
Lease expiry alone is insufficient evidence of release.
Recover the existing generation and completed diagnosis; preserve retry counts,
uncertainty holds and newer edits. A fresh session does not reset that budget.
Continue independent authorized work only when it does not depend on the blocked
operation or change its target.

For explicitly autonomous multi-change work, recommend existing dependency-aware
queues: [queued delivery](../QUEUED_AUTONOMOUS_DELIVERY.md) and
https://code.visualstudio.com/docs/agents/overview. Verify installed capabilities;
native message queueing is not proof of durable recovery or unattended permission.

## Native publication and acceptance

- **Principal:** observe the selected browser's actual authenticated user and
  effective access before acceptance/writes; compare intended user/target and
  repeat after login/session/target changes. A session-declared identity, displayed
  persona switch or separate API administrator identity is not browser-principal
  proof. Missing/unverifiable evidence or identity mismatch blocks affected writes.
  Retain sanitized evidence, never credentials.
- **Publication:** inspect dependencies and current published/unpublished state.
  Broad table/app publication can promote unrelated pending changes.
  If scoped publication cannot be proven, stop that publication.
- **Records:** capture stable record identity/version, permitted before-state and
  exact expected effects; compare native readback, including expected platform
  changes. Unexpected modifications stop affected writes; retain sanitized
  before/after, diff, timing, operation and principal evidence.
  Do not blindly roll back, overwrite concurrent changes or delete records.
- **Restrictions:** distinguish application-created, security/access, platform and
  unknown restrictions using evidence. A business rule may protect data.
  Classification is diagnosis, never permission to bypass a control.
  Unknown restrictions block affected actions until understood.
- **Form eligibility:** verify published app membership, user/role eligibility,
  table/form type and actual selected form/user path.
  Mere direct URL access is not proof of form eligibility in the intended app/user context.
  Missing/direct-access-only proof remains partial/unverified.
- **Browser recovery:** use independent process/owner, target, observed principal
  and checkpoint evidence, separate from an API worker or its administrator session.
  Reconcile outstanding writes and resource state before restart; repeat principal
  preflight and read back uncertain effects. Never launch a conflicting writer.
  Prefer a supported dedicated browser adapter; do not replace native proof with
  fragile desktop interaction, API or mocked results.

These are safety obligations, not an installed browser driver or a performed pilot.
Starter supplies guidance and instruction/distribution contracts; actual runtime
capabilities belong to the selected executor.

## Evidence, context and inheritance

| Status | Evidence |
| --- | --- |
| SOURCE COMPLETE | Persistent source/configuration and exact identity |
| TESTED | Executed commands/results and scope; identify synthetic checks |
| DEPLOYED | Actual target and successful publish/deployment/readback receipt |
| LIVE VERIFIED | Actual intended-user journey and target evidence |
| BLOCKED | Affected operation, reason, attempts and next resolution |

TESTED does not imply DEPLOYED; deployment does not imply LIVE VERIFIED.
Verify remote SHAs for push claims; Git publication is not tenant deployment.
Report functional delivery, accepted journeys, recoveries, blockers and next
tasks concisely. Documentation improvement is not application functionality.

Active instructions are this policy and applicable project-specific safeguards.
Functional specifications describe accepted outcomes. Machine receipts,
checkpoints and results are operational evidence. Completed handoffs, older
policies and Git history are historical reference, not new restrictions.

Use existing issue/PR/build log for incremental reconciliation and handoff.
If protection blocks a required handoff, report **HANDOFF NOT WRITTEN - BLOCKED**
with transferable evidence; never bypass protection to write it.
Consumer projects include this policy or an explicitly reviewed equivalent
operational contract through [skill distribution](../skill-distribution.md);
do not silently replace existing instructions or stricter local security.
Installed skills resolve project-local policy first, then byte-identical bundled
`references/authorization-and-execution.md`. If neither exists, report BLOCKED for
mutating work until applicable constraints are known; independent read-only work
may continue. Guidance migration retires only verified framework-owned text,
preserves customizations and does not grant authority or install runtime code.
