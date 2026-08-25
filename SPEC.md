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

## Success Criteria

- A new user can follow the documented onboarding flow and understand the build order without reading source code first.
- A scenario can be planned under `specs/<scenario-slug>/` and then built through the scripted sequence without bypassing the planning gate.
- Repo changes that affect workflow contracts can be validated with the existing CI or script-based checks.
