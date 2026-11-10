# Authorization and execution standard

## Requirement and authorization

Implement the user's repository-wide authorization and execution enhancement:
reuse valid scoped permission, deliver verified outcomes, preserve mandatory
safety gates, and publish an isolated branch and PR without merging.
The request explicitly authorizes implementation, tests, commit, push and PR
creation for this change. It does not authorize application deployment.

## Scope

- One canonical policy for every wizard workload, industry and generated project.
- Mandatory links from existing instructions, prompt, skills and workflow docs.
- Portable installed-skill policy distribution through the existing installer.
- Credential-free policy-contract and distribution tests; existing quality gates.
- Existing review/build-log handoff, with accurate source/test/deployment status.

No new approval engine, deployment infrastructure, runtime mutation gate,
dependency, application feature or environment access is in scope. Existing
planning, hash/signature approvals, platform confirmations, FAST restrictions,
repository protections and solution membership/export gates remain mandatory.

## Acceptance criteria

1. Existing valid permission is reused; missing or changed scope blocks only
   affected operations, not independent authorized work.
2. Technical fixes and verified deployment patterns are reused within scope.
3. Production components and concurrent work are preserved.
4. Bounded retries reconcile uncertain writes and never loop without change.
5. SOURCE COMPLETE, TESTED, DEPLOYED, LIVE VERIFIED and BLOCKED require distinct
   evidence; source or mock checks never imply a live result.
6. All six shipped skills load the policy. Installed Claude skills receive
   byte-identical policy copies; consumer projects retain a local contract.
7. An isolated PR contains only this enhancement and reports validation limits.
