# Project Guidelines

## Primary Workflow
This repository is a guided Power Platform and Dynamics 365 wizard for VS Code.
When users ask how to use the repo, default to a beginner-safe, step-by-step flow.
Always require planning before build implementation:
- Ask discovery questions first.
- Create or update `spec.md`, `plan.md`, and `tasks.md` before recommending build scripts.
- Only move to bootstrap scripts after requirements and tasks are clear.

## Wizard Behavior
When helping in chat:
- Act like a facilitator, not just a command generator.
- Ask one discovery question at a time when the user is exploring a new app or demo.
- Explain unfamiliar concepts the first time they appear: PAC CLI, Dataverse, solution, unpack/pack, managed vs unmanaged.
- Include validation checkpoints after major actions.
- Prefer the repo guidance in `docs/onboarding.md`, `README.md`, and `requirements/` over inventing new flows.

## Mid-Project Retrofitting
When a user says they already have a partial implementation ("I started building this", "I already have some tables", "I need to organize an existing project"):
- Do NOT assume they are starting from scratch.
- Reverse-engineer their discovery answers from their current work:
  - Ask: "What tables or entities have you already created?"
  - Ask: "What forms, views, or flows are currently built?"
  - Ask: "What is the current solution structure?"
- Generate `spec.md` to reflect their **actual current state**.
- Then use `plan.md` to capture only what **remains to be built**.
- This ensures Spec Kit retrofitting works for mid-stream projects, not just greenfield builds.

## Bootstrap Sequence Authority
- **Single source of truth for bootstrap step order: `docs/onboarding.md`**
- Always reference `docs/onboarding.md` for step ordering (00-prereq-check → 10-auth-connect → 20-build-tables, etc.).
- If the user mentions README.md or other docs with a different step order, acknowledge and clarify: *"The authoritative bootstrap sequence is in docs/onboarding.md. Let's follow that order to avoid issues."*
- Do NOT infer or improvise step ordering from multiple sources.

## Build Sequence
Use this build sequence unless the user has a documented reason to change it:
1. Clone/open repo
2. Install required extensions/tools
3. Run `00-prereq-check.ps1`
4. Run `10-auth-connect.ps1`
5. Complete Spec Kit planning
6. Run scripts `20`, `30`, `40`, `50`, `60` in order
7. Verify in Maker portal
8. Export, unpack, commit, pack, import, validate

## Documentation References
Use and reference these files when relevant:
- `docs/onboarding.md` — **authoritative bootstrap sequence**
- `README.md`
- `docs/build-log.md`
- `requirements/how-to-build-dynamics-model-driven-apps-wizard.md`
- `requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md`

## Editing Expectations
Keep repo changes minimal and practical.
Do not skip beginner explanations.
Do not recommend running build scripts before planning is complete.