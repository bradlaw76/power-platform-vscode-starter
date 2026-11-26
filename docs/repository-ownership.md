<!--
Component: Framework Repository Ownership
Purpose: Separate reusable framework maintenance from application development.
Owner: Power Platform VS Code Starter
Version: 1.0.0
-->

# Repository Ownership

The public `bradlaw76/power-platform-vscode-starter` repository owns reusable
skills, framework code, templates, installers, generic tooling, and shared tests.
The private [bradlaw76/FOIA](https://github.com/bradlaw76/FOIA) repository exclusively
owns Federal FOIA application code, architecture, Dataverse configurations,
Azure integrations, application tests, and application documentation.

Do not repoint existing clones or copy an application's Git history into this
framework. Use separate working directories and review branches.

## Required Checks

Before committing or pushing, verify the Git root, branch, origin fetch/push
URLs, and intended repository. Run:

```powershell
git status --short --branch
git remote -v
git config --local core.hooksPath .githooks
git config --local push.default simple
git config --local remote.pushDefault origin
pwsh -NoProfile -File .\scripts\ci\test-framework-ownership.ps1
```

Install these hooks in every fresh clone. The pre-commit hook checks ownership;
the pre-push hook additionally validates the actual origin argument and push
destination. Hooks can be bypassed by an operator and do not replace CI/review.

The existing quality workflow automatically discovers this ownership check.
It validates the framework destination, freezes the 71 historical FOIA files
at public main commit `4c9d2bfac675812a8fbe100b94c05ebe4c4bed1e`, rejects new
FOIA-named application paths, and detects FOIA definitions in new payloads,
solution source, and application code. Generic documentation may refer to the
ownership boundary without importing application content.

The baseline is a containment mechanism, not permission to keep developing the
application here. Future approved cleanup must deliberately revise the policy
and affected dependency tests together. Never silently remove a baseline entry
to bypass a failed check.

## Maintainer Review

The proposed CODEOWNERS file names the repository owner. Review requests and
CI are not equivalent to server-enforced branch protection. After explicit owner
approval, configure a main-branch rule requiring pull requests, owner review,
passing quality checks, and prohibiting force pushes/deletion. Evaluate existing
open framework PRs before changing administrative rules.

Do not claim these settings are active merely because this document or a PR
exists. The H003 ownership changes must be reviewed and merged before main's
workflow includes their check. No automatic PR merge is authorized.

## Cleanup Is A Separate Operation

Historical FOIA files, branches, and commits remain untouched. Ordinary future
file removal must repair references and tests while preserving shared framework
dependencies. It leaves public history intact. Branch deletion and history
rewriting need separate approval and an exposure/retention assessment; neither
guarantees removal from forks, caches, or existing clones.

No Azure, Dynamics, or Dataverse deployment is part of repository maintenance.
