<!--
Component: Framework Ownership Review Handoff
Purpose: Record the additive H003 ownership proposal without application changes.
Owner: Power Platform VS Code Starter
Version: 1.0.0
-->

# ChatGPT Review Handoff

## H003 Companion - 2026-11-06 - Repository Ownership

### Numbering And Scope

This is the framework companion to "H003 - FOIA Repository Finalization and
Branch Consolidation" in the dedicated private application repository.
This path was absent on public main; this record does not claim a new global
HXXX sequence or replace handoffs on other framework maintenance branches.
Application finalization details belong in
[bradlaw76/FOIA#1](https://github.com/bradlaw76/FOIA/pull/1).

### Source And Additive Proposal

- Base: public main `4c9d2bfac675812a8fbe100b94c05ebe4c4bed1e`.
- Review branch: `framework-maintenance/h003-repository-ownership`.
- A separate clone was used. The existing FOIA-source checkout, its untracked
  test output, and its Git configuration were not switched or modified.
- Adds framework ownership instructions, CODEOWNERS, documentation, a frozen
  71-file historical application baseline, auto-discovered CI check, and local
  commit/push hooks. No existing application or shared framework file is removed.
- Actual historical files: 42 payloads, 28 scenario files, one traceability test.
  The preliminary 74-entry audit incorrectly counted three directories as files;
  BLOB counts were corrected before policy generation.
- Existing generic components, other scenarios, and published history remain.
  The ownership guard rejects new FOIA-named artifacts/application definitions,
  changes to frozen historical files, and incorrect fetch/push destinations.

### Validation And Publication Boundary

- `00-prereq-check.ps1` passed in the separate maintenance clone.
- Framework ownership and installed wrong-destination pre-push checks passed.
- Full local CI-equivalent validation passed: 25 standalone suites, 90 Pester
  tests, 66 PowerShell parser checks, repository analyzer, Markdown, and whitespace.
  Synthetic new FOIA paths and neutral-named FOIA definitions were rejected in
  integration tests; both temporary fixtures were removed afterward.
- Resolve the proposal commit with `git log -1 --format=%H` on the review branch.
  A commit cannot embed its own SHA.
- A separate review PR is required. No merge or repository-setting change is
  authorized by creating this proposal. Its check is not yet enforced on main.

### Outstanding Decisions

Owner approval is required for merging either repository's PR and for choosing
server-enforced main protections after reviewing existing framework PRs.
CODEOWNERS requests review but does not itself enforce approval or CI.
Hooks require installation in each clone and can be disabled by an operator.

Public application file cleanup, branch deletion, visibility changes, and
history rewriting need separate approval. Ordinary removal must first adapt
generic tests and references; it does not erase public history or caches.
No Azure, Dynamics, or Dataverse deployment occurred.
