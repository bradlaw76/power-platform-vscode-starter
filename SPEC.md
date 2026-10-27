# Power Platform VS Code Starter - Specification

**Status:** DRAFT
**Version:** 0.1.0
**Created:** 2026-07-19

---

## Purpose

Define the repo-level contract for this starter kit: how a user moves from discovery to planning to scripted Power Platform build steps inside VS Code.

## Scope

In scope:

- The beginner-safe onboarding flow for Power Platform and Dynamics 365 builders.
- The mandatory planning gate using `spec.md`, `plan.md`, and `tasks.md` before implementation scripts run.
- Scripted bootstrap phases for tables, columns, relationships, forms, views, app modules, reporting shells, validation, export, and documentation.
- Repo-level documentation, prompts, skills, and tests that enforce the workflow contract.

Out of scope:

- Duplicating scenario-specific planning artifacts already maintained under `specs/<scenario-slug>/`.
- Replacing scenario requirements with a single root planning document.
- Manual portal-first build guidance that bypasses the scripted workflow.

## Governance Model

- This root specification governs the repository itself.
- Scenario-level planning artifacts under `specs/<scenario-slug>/` remain the authoritative source for individual demos, apps, and build requests.
- `docs/onboarding.md` is the authoritative bootstrap sequence when workflow documentation overlaps.

## Requirements

1. The repo must require completion of scenario planning artifacts before recommending or running build scripts.
2. The repo must support a guided discovery flow through terminal wizard, chat prompt, or installed skill.
3. The repo must keep build steps source-controlled, repeatable, and practical for first-time builders.
4. The repo must explain Power Platform concepts in beginner-safe language when they first appear.
5. The repo must provide validation checkpoints and tests for workflow and contract changes.

## Framework Maintenance Handoff and Approvals

This section is the canonical framework-maintenance policy for Copilot, Claude,
and other contributors. The authoritative status record is
`docs/audits/chatgpt-review-handoff.md`.

### Required updates and completion gate

Append a dated handoff update for every change, significant milestone, successful
or partial completion, failure or exception, blocker, pause, interruption, or
handoff to another agent. Include tests that fail, are skipped, or cannot run,
and Git operations that fail or are rejected by a protection gate.
Preserve historical entries; clearly distinguish historical evidence from
freshly verified results. Do not duplicate completed implementation.

Before reporting COMPLETE, PARTIAL, FAILED, or BLOCKED, either update the local
handoff and report its publication status or provide the complete response-only
fallback below. Never describe blocked or partial work as complete.

Every update must record:

1. Date, task, outcome, and exact operation attempted.
2. Error message or failure evidence, or an explicit statement that none occurred.
3. Repository identity, branch, and full HEAD SHA.
4. Files modified, including changes made before a failure.
5. Validation results: tests completed, failed, skipped, or not run, with reasons.
6. Working-tree status and whether uncommitted changes remain.
7. Work successfully completed.
8. Unresolved issues and work remaining.
9. Recovery actions attempted and their outcomes, or none.
10. Exact next actions for ChatGPT and the owner.
11. Publication status: local, committed, pushed, and merged separately, with
    verified SHAs or evidence where available. Unknown is not success.

### Separate authorization boundaries

Modification, commit, push, and merge each require explicit, separate approval
for that operation and its scope. Approval for one never authorizes another.
Do not infer authorization from a prior task, an ambiguous acknowledgement,
or a successful preflight. Clarify only the approval that remains ambiguous;
do not repeatedly request an explicit approval already granted for the same scope.
Task-specific exceptions are not permanent waivers.

Before any write, verify repository identity, the approved branch and starting
HEAD, and applicable protection gates. Preserve unrelated work. Do not switch,
reset, merge, or overwrite branches merely to locate a handoff. If absent
locally, retrieve the existing approved-branch handoff read-only; copying it
onto another branch requires explicit authorization and must be labeled a copy.

Select tools according to their actual side effects. A progress/reporting tool
that also commits or pushes requires those separate approvals before invocation;
its name does not make it safe for local-only reporting. Report progress in the
response instead when the tool's publication effects are not authorized.

### Safe response-only fallback

Never bypass a failed preflight or repository protection check to update the
handoff. If branch restrictions, filesystem failures, permissions, tooling, or
missing approval prevent a safe write, stop prohibited operations and return
**HANDOFF NOT WRITTEN — BLOCKED** in the response.

Include the exact intended document path, the reason it could not be updated,
and complete transferable Markdown containing all eleven record fields above.
Never claim the file was updated when it was not. Do not automatically commit
or push the handoff; report whether it is local-only, committed, pushed, or merged.

Instructions and static regression checks guide and validate the checked-in
contract; they cannot guarantee agent compliance in every conversation or
replace runtime protections and human approvals.

## Success Criteria

- A new user can follow the documented onboarding flow and understand the build order without reading source code first.
- A scenario can be planned under `specs/<scenario-slug>/` and then built through the scripted sequence without bypassing the planning gate.
- Repo changes that affect workflow contracts can be validated with the existing CI or script-based checks.
