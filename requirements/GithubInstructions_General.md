# GitHub Repository Engineering Standards

## Purpose

These rules define the source-control, repository, CI/CD, branch, commit, pull-request, release, security, and agent-development standards for this repository.

They are intentionally technology-neutral.

The repository is the authoritative engineering record for the project.

---

# 1. Repository as Source of Truth

Anything required to understand, build, test, deploy, troubleshoot, reproduce, or extend the project should be represented in source control where appropriate.

Do not leave essential engineering information only in:

* local workstations;
* IDE chat history;
* AI-agent conversations;
* temporary files;
* manually configured environments;
* personal notes.

Repository contents should allow another qualified engineer to understand and reproduce the project.

---

# 2. Inspect Before Changing

Before making significant changes, inspect the repository.

At minimum determine:

```text
Current branch
Working-tree status
Recent commits
Configured remotes
Repository structure
Build system
Package manager
Lockfiles
Existing CI/CD
Tests
Linting
Formatting
Contribution instructions
Agent instructions
```

Never assume these values.

Use the repository as evidence.

---

# 3. Preserve Existing Standards

Before introducing new tooling, determine whether the repository already defines:

* package-management conventions;
* formatting;
* linting;
* testing;
* build commands;
* directory structure;
* naming;
* release processes;
* CI workflows.

Prefer existing conventions unless there is a documented reason to change them.

Do not create parallel tooling unnecessarily.

---

# 4. Main Branch

The default branch represents the latest stable integrated state.

Commonly:

```text
main
```

or:

```text
master
```

Determine the actual default branch rather than assuming its name.

Do not use the default branch as a scratch workspace.

---

# 5. Branch-Based Development

For meaningful changes, prefer:

```text
Default Branch
      ↑
Pull Request
      ↑
Feature Branch
```

Branches isolate work and provide a reviewable integration boundary.

---

# 6. Branch Naming

Use predictable branch names.

Recommended:

```text
feature/<description>
fix/<description>
docs/<description>
refactor/<description>
test/<description>
chore/<description>
ci/<description>
release/<version>
```

Examples:

```text
feature/add-search-api
fix/session-timeout
docs/update-deployment-guide
refactor/extract-auth-service
test/add-contract-tests
ci/add-build-validation
```

Avoid meaningless names such as:

```text
stuff
test2
new
final
final2
temp
changes
```

---

# 7. One Branch, One Goal

A branch should represent one coherent objective.

Avoid combining unrelated:

* features;
* bug fixes;
* architecture changes;
* formatting changes;
* infrastructure changes;
* documentation rewrites;

unless they genuinely belong to the same work item.

---

# 8. Commit Format

Use concise, meaningful commit messages.

Recommended structure:

```text
<type>: <imperative summary>
```

Recommended types:

```text
feat:
fix:
docs:
refactor:
test:
chore:
ci:
build:
perf:
security:
```

Examples:

```text
feat: add account search endpoint
fix: prevent duplicate event processing
docs: document local development setup
test: add authentication integration tests
ci: add pull request validation
security: remove plaintext credential handling
```

---

# 9. Bad Commit Messages

Avoid:

```text
updates
changes
stuff
work
more work
fix
fixed
final
wip
oops
```

Commit history is engineering documentation.

Someone should be able to understand the project's evolution by reading it.

---

# 10. Commit Scope

Each commit should represent a coherent change.

Prefer:

```text
feat: add customer model

feat: add customer repository

test: add customer repository tests
```

over:

```text
feat: build customer system and other updates
```

Do not make commits artificially tiny, but avoid enormous unrelated commits.

---

# 11. Commit Only Intentional Files

Before committing, inspect:

```bash
git status
git diff
git diff --staged
```

Verify that the commit does not accidentally include:

* generated files;
* temporary files;
* logs;
* secrets;
* local databases;
* editor state;
* unrelated modifications.

---

# 12. Local Validation Before Commit

Run the repository's existing applicable validation before committing meaningful implementation work.

Examples may include:

```text
build
tests
lint
typecheck
format check
static analysis
contract tests
```

Do not invent commands.

Determine them from the repository.

---

# 13. Pull Requests

Use pull requests for meaningful integration work.

A PR should explain:

## Summary

What changed?

## Reason

Why was the change needed?

## Validation

What tests/checks were run?

## Impact

Does it affect:

* architecture;
* APIs;
* persistence;
* security;
* deployment;
* compatibility;
* dependencies;
* user experience?

## Related Work

Reference relevant:

* issue;
* specification;
* task;
* ADR;
* design document.

---

# 14. Focused Pull Requests

Prefer PRs that can be understood and reviewed without reconstructing weeks of unrelated development.

Break very large initiatives into logical phases.

---

# 15. CI Is Required Validation

The repository should have automated CI appropriate to its technology stack.

CI should use commands already supported by the repository.

Common checks include:

```text
dependency installation
build
tests
lint
typecheck
format validation
static analysis
contract validation
```

Do not invent build or test commands solely for CI.

---

# 16. CI Trigger Standard

General CI should normally run on:

```text
pull_request → default branch
push → default branch
```

Additional workflows may run on:

```text
tags
releases
scheduled checks
manual dispatch
specific paths
```

when appropriate.

---

# 17. CI Must Be Reproducible

CI should run in a clean environment.

This validates that the project does not secretly depend on:

* local machine state;
* undeclared packages;
* IDE configuration;
* developer-specific files;
* uncommitted artifacts.

---

# 18. Dependency Installation

Use the repository's existing package manager and lockfile.

Examples:

```text
package-lock.json → npm ci
pnpm-lock.yaml → pnpm
yarn.lock → yarn
poetry.lock → Poetry
uv.lock → uv
Pipfile.lock → Pipenv
packages.lock.json → NuGet
go.sum → Go modules
Cargo.lock → Cargo
```

Do not arbitrarily switch package managers.

---

# 19. CI Caching

Use dependency caching where it improves performance without compromising correctness.

Cache dependencies/package-manager state rather than arbitrary build outputs unless there is a documented reason.

---

# 20. CI Permissions

GitHub Actions should use least privilege.

Prefer:

```yaml
permissions:
  contents: read
```

unless additional permissions are actually required.

Do not grant broad write permissions by default.

---

# 21. Workflow Simplicity

Keep workflows understandable.

Prefer several purpose-specific workflows over one enormous workflow when responsibilities are genuinely distinct.

Examples:

```text
ci.yml
contracts.yml
security.yml
release.yml
deploy.yml
```

Do not split workflows merely for cosmetic reasons.

---

# 22. Default Branch Protection

For important repositories, protect the default branch.

Recommended protections:

* require pull requests;
* require applicable CI checks;
* prevent force pushes;
* prevent branch deletion;
* require branch to be current when appropriate;
* require reviews when team structure warrants them.

Solo development may use lighter review rules while still requiring CI.

---

# 23. Force Push Policy

Never force-push the default branch.

Do not rewrite released history.

Feature branches may be rebased when doing so will not disrupt collaborators.

---

# 24. Merge Strategy

Use a deliberate merge strategy.

### Squash Merge

Useful when feature branches contain noisy intermediate commits.

### Merge Commit

Useful when individual commits contain meaningful engineering history.

### Rebase Merge

Useful when a linear history is intentionally maintained.

Choose a repository standard and apply it consistently.

---

# 25. Tags

Use annotated, immutable tags for meaningful stable states.

Example:

```text
v1.0.0
v1.1.0
v2.0.0
```

Project-specific milestone tags may also be appropriate.

Never silently move a published tag.

---

# 26. Releases

Use GitHub Releases for meaningful distributable versions.

Release notes should describe:

* capabilities;
* important changes;
* compatibility;
* deployment notes;
* migrations;
* known limitations;
* security considerations where relevant.

---

# 27. Version Alignment

Where applicable, align:

```text
Git tag
GitHub release
Application/package version
Deployment artifact version
```

This improves traceability.

---

# 28. Semantic Versioning

Where appropriate, use:

```text
MAJOR.MINOR.PATCH
```

Conceptually:

```text
MAJOR = breaking compatibility
MINOR = backward-compatible functionality
PATCH = backward-compatible fix
```

Projects with different established versioning standards should preserve those standards.

---

# 29. .gitignore

Maintain a repository-appropriate `.gitignore`.

Exclude things such as:

```text
dependency directories
build outputs
coverage
test results
IDE state
temporary files
local databases
local environment files
logs
generated caches
```

Determine exact entries from the project's technology.

---

# 30. Secrets

Never commit:

* passwords;
* access tokens;
* API keys;
* client secrets;
* private keys;
* credential-bearing connection strings;
* production credentials.

Use approved secret-management mechanisms.

Examples include:

```text
GitHub Secrets
environment variables
cloud secret stores
managed identity
deployment-time configuration
```

---

# 31. Accidentally Committed Secrets

If a real secret enters Git history:

1. assume it is compromised;
2. revoke or rotate it;
3. remove it from active source;
4. determine whether history remediation is necessary;
5. document the incident appropriately.

Simply deleting the secret in a later commit does not make the original secret safe.

---

# 32. Dependency Hygiene

Enable appropriate dependency monitoring.

Common ecosystems include:

* npm;
* NuGet;
* Maven;
* Gradle;
* pip;
* Poetry;
* Go modules;
* Cargo;
* GitHub Actions.

Automated dependency PRs must still pass CI and review.

---

# 33. Security Features

Where available and appropriate, enable:

* Dependabot alerts;
* dependency review;
* secret scanning;
* push protection;
* code scanning;
* security advisories.

Do not treat security alerts as notification noise.

---

# 34. Generated Artifacts

Do not commit generated build artifacts unless they are intentionally part of the repository's distribution strategy.

Examples normally excluded:

```text
compiled output
coverage reports
test reports
package caches
temporary deployment packages
```

Release artifacts are generally better attached to releases or generated by CI.

---

# 35. Documentation Structure

Keep documentation organized.

Typical structure:

```text
README.md
CONTRIBUTING.md
SECURITY.md

docs/
    architecture/
    adr/
    development/
    deployment/

specs/
```

Use only the structure appropriate to the project.

---

# 36. README Purpose

The README should orient someone to the project.

It should generally answer:

* What is this?
* What does it do?
* How do I run it?
* How do I test it?
* Where is detailed documentation?
* How is it deployed?
* How do I contribute?

Do not turn the README into an unstructured dumping ground for every design decision.

---

# 37. Architecture Decision Records

Use ADRs for significant architectural decisions when the project warrants them.

Example:

```text
docs/adr/
001-database-selection.md
002-event-delivery-model.md
003-authentication-strategy.md
```

An ADR should generally capture:

```text
Context
Decision
Alternatives
Consequences
```

---

# 38. Specifications and Plans

For spec-driven projects, maintain traceability between:

```text
Requirement
Specification
Plan
Task
Implementation
Test
Commit / PR
```

Do not silently change approved requirements while implementing them.

---

# 39. Issues

Use Issues for work that needs lifecycle tracking.

Good uses include:

* bugs;
* technical debt;
* future features;
* security work;
* known limitations;
* research/discovery.

Do not duplicate every low-level task into an Issue when another established planning system already manages those tasks.

---

# 40. Issue Titles

Use specific titles.

Good:

```text
API retries can create duplicate records
Add validation for clean deployment
Investigate intermittent authentication timeout
```

Bad:

```text
bug
problem
help
fix this
```

---

# 41. Labels

Keep labels useful and relatively small in number.

A general taxonomy might include:

```text
type:bug
type:feature
type:docs
type:security
type:tech-debt

priority:high
priority:medium
priority:low

status:blocked
status:discovery
```

Add area labels only when useful.

---

# 42. Pull Request Template

For substantial repositories, create:

```text
.github/pull_request_template.md
```

Recommended sections:

```text
Summary
Related issue/spec
Architecture impact
Testing
Security impact
Deployment impact
Screenshots/evidence where applicable
Checklist
```

---

# 43. CODEOWNERS

Use:

```text
.github/CODEOWNERS
```

when automatic review ownership provides genuine value.

Do not add it purely for ceremony.

---

# 44. CONTRIBUTING.md

For repositories with multiple contributors or complex workflows, provide:

```text
CONTRIBUTING.md
```

Document:

* setup;
* branch conventions;
* commit expectations;
* testing;
* PR expectations;
* release expectations.

---

# 45. SECURITY.md

For public, shared, or security-sensitive projects, consider:

```text
SECURITY.md
```

Document supported versions and how vulnerabilities should be reported.

Do not ask researchers to disclose vulnerabilities publicly through ordinary Issues.

---

# 46. Repository Structure

Maintain a predictable directory structure.

Example only:

```text
.github/
docs/
src/
tests/
scripts/
infra/
specs/
```

Do not introduce arbitrary top-level directories when an existing location is appropriate.

---

# 47. Repository Root

Keep the root clean.

Root files should generally be important entry-point configuration or documentation.

Avoid accumulating:

```text
notes2.txt
temp.json
test-output.txt
old-config.xml
final-copy.md
```

---

# 48. Stale Branches

Delete merged branches when they no longer provide value.

Git history preserves merged work.

Do not accumulate stale branches indefinitely.

---

# 49. Branches Are Not Backups

Do not create branches named:

```text
backup
old-main
before-change
backup-final
```

Use commits, tags, and releases for intentional recovery points.

---

# 50. Recovery Strategy

Known-good states should be recoverable through:

```text
commits
tags
releases
deployment artifacts
```

Do not depend on a particular developer workstation.

---

# 51. Agent Preflight

Before an AI coding agent performs significant work, it must determine:

```text
Repository
Remote
Current branch
Working-tree state
Recent history
Relevant instructions
Relevant specification/task
Build commands
Test commands
Lint/typecheck commands
```

The agent must not guess.

---

# 52. Agent Scope

Agents should modify only files relevant to the requested task.

Do not perform opportunistic unrelated refactoring unless explicitly requested or required for correctness.

If unrelated problems are discovered, report or track them separately.

---

# 53. Agent Git Safety

Agents must not silently:

* force-push;
* rewrite the default branch;
* delete tags;
* remove unrelated branches;
* alter releases;
* commit secrets;
* overwrite another active workstream.

Potentially destructive Git operations require explicit justification and appropriate approval.

---

# 54. Agent Commit Behavior

Before committing, the agent should know:

```text
What changed?
Why?
Which files?
Which requirement/task?
Which validation passed?
What limitations remain?
```

The resulting commit message must accurately represent that scope.

---

# 55. Agent Push Verification

After pushing, verify that the remote actually contains the commit.

Conceptually:

```bash
git rev-parse HEAD
git rev-parse origin/<branch>
```

Do not report:

```text
pushed
updated in GitHub
available remotely
```

until remote state has been verified.

---

# 56. Local vs Remote State

Always distinguish:

```text
Modified locally
Committed locally
Pushed to remote branch
Merged to default branch
Released
Deployed
```

These are different states.

Never use them interchangeably.

---

# 57. CI Failure Handling

When CI fails:

1. identify the failing job;
2. inspect the actual error;
3. reproduce locally when practical;
4. fix the underlying issue;
5. rerun validation;
6. push the correction.

Do not weaken or remove a valid CI check simply to make the workflow green.

---

# 58. Flaky Tests

Do not normalize flaky tests.

Track and correct them.

Retries may be appropriate for genuinely nondeterministic external dependencies, but retries must not conceal defective tests.

---

# 59. Clean Clone Test

Periodically validate the project from a fresh clone.

A qualified developer or CI runner should be able to:

```text
clone
install dependencies
build
test
run
```

using documented commands.

This is one of the strongest repository-quality checks.

---

# 60. Release Hygiene Review

Before a significant release verify:

* default branch passes CI;
* repository is clean;
* required docs are current;
* version numbers align;
* release notes are prepared;
* dependencies are understood;
* secrets are absent;
* migration/deployment instructions are current;
* known limitations are documented;
* release artifacts are reproducible.

---

# 61. GitHub Notifications

Maintainers should normally monitor:

* CI/workflow failures;
* pull-request activity;
* requested reviews;
* security alerts;
* dependency alerts;
* release/deployment failures.

Avoid excessive notifications that make important failures easy to miss.

---

# 62. Definition of Repository Cleanliness

A repository is considered healthy when:

> The default branch is reproducible and passing validation; meaningful changes are traceable through commits and pull requests; releases have stable recovery points; dependencies and security are monitored; generated junk and secrets are excluded; documentation reflects the implementation; and another qualified engineer can clone the repository and understand how to build, test, operate, and extend it without depending on undocumented local state.

---

# 63. Definition of Done for Repository Changes

A meaningful repository change is not complete until, where applicable:

1. implementation is complete;
2. tests pass;
3. build passes;
4. lint/typecheck/format checks pass;
5. documentation is updated;
6. architecture decisions are recorded;
7. commit history is coherent;
8. remote push is verified;
9. CI passes;
10. PR requirements are satisfied;
11. release/version information is updated when required.

Repository hygiene is part of engineering quality, not post-development cleanup.
