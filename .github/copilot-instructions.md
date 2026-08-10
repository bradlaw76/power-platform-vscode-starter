# Project Guidelines

## SpeckKit Integration
This repository is registered with the SpeckKit registry using raw registry URLs so the repo can consume standards without duplicating the registry locally.

- Registry: https://github.com/bradlaw76/SpeckKit-Project-Development
- Project profile: `spec-governed`
- Repo manifest: `SYSTEM_MANIFEST.json.md`
- Repo-level governance: `SPEC.md` and `BINDING_CERTIFICATION.md`
- Scenario-level planning artifacts under `specs/<scenario-slug>/` remain the authoritative Spec Kit files for individual demos and builds; do not recreate those scenarios at repo root.

### SpeckKit Agent Defaults
- Apply the SpeckKit component header comment block when creating new component files unless the user explicitly asks to skip header comments.
- Ask before loading SpeckKit UI reference context.
- When SpeckKit guidance and repo-local workflow guidance overlap, prefer the repo-local process in `docs/onboarding.md`, `README.md`, and `requirements/`.

## Primary Workflow
This repository is a guided Power Platform and Dynamics 365 wizard for VS Code.
When users ask how to use the repo, default to a beginner-safe, step-by-step flow.
Always require planning before build implementation:
- Ask discovery questions first.
- Create or update `spec.md`, `plan.md`, and `tasks.md` before recommending build scripts.
- Only move to bootstrap scripts after requirements and tasks are clear.

## Architecture Intent (Always First)
Before recommending any build action, ask and confirm architecture intent:
1. Is the implementation **OOB extension only**, **custom tables only**, or **hybrid**?
2. If OOB extension: should forms be **updated in place** or **cloned as new business forms** on OOB tables?
3. What is the **required primary entry-point table** (first screen)?
4. What is the **default landing view** for that entry-point table?
5. Should the run **auto-create or auto-update a model-driven review app** that surfaces all built artifacts?

Do not proceed to build scripts until all five architecture questions are confirmed.

## Discovery Questions (Required Intake)
In addition to the core 11 discovery questions, always ask:
1. Should this build extend OOB tables, use custom tables, or both?
2. If OOB tables are used, should existing forms be updated or new forms be created?
3. What is the required primary entry-point table?
4. What is the default landing view for that entry point?
5. Should the wizard always create/update a model-driven review app with all run artifacts?
6. Which artifacts must be visible in the review app at the end of the run?
7. Which solution unique name selected during wizard setup is the target for all components?

When demo data is requested, also ask which tables receive records (all scenario-created custom tables or selected tables), the record count per table, required scenarios/lifecycle states, hero records and their demo purpose, parent-child distribution, creation method, rerun behavior, source tag, synthetic-data/privacy constraints, and cleanup/reset preference. Never seed standard reused tables implicitly. If Dataverse Task activities are requested, ask which parent tables qualify, whether tasks apply to the latest, all, or selected parent records, the maximum source-record count (default 10 for latest), the ordering field, and tasks per selected record; do not create tasks for every record unless the user explicitly selects all.

Capture the top user tasks with persona, frequency, entry table/view, expected outcome, owner, and done definition. For every planned relationship, capture cardinality, requiredness, existing/new status, cascade behavior, and the task or app surface it supports.

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

## Planning Gate (No Build Before This)
Require completed and aligned planning artifacts before any script execution:
- `README.md`
- `docs/onboarding.md`
- `docs/build-log.md`
- `requirements/how-to-build-dynamics-model-driven-apps-wizard.md`
- `requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md`

If generated guidance conflicts with any of these internal docs, either align to the internal docs or explicitly call out the conflict and propose a fix. Do not silently override internal docs.

## Build Behavior Requirements
1. Payload files (`payloads/`) are the source of truth for schema, labels, and field ordering.
2. Form labels must use business display labels, not schema names.
3. All scripts must be idempotent and rerun-safe.
4. All metadata and app updates must end with a publish call.
5. Scripts must include Dataverse resilience:
   - Refresh token on 401
   - Exponential backoff on 429
6. App component add/remove operations must be explicit, tracked, and rerunnable.

## Solution Inventory and Sync (Mandatory)
During every build run, collect and persist inventory for all created or updated artifacts:
- Tables, Columns, Relationships
- Forms, Views
- Model-driven apps, Sitemap updates
- Web resources
- Optional: Dashboards, Charts, Flows

Persist both logical names and IDs. Then:
1. Sync all inventory categories into the selected solution.
2. Re-check solution membership after sync.
3. Produce a final membership report: Added / Already in solution / Failed with reason / Missing after sync.
4. Do not proceed to export unless membership check passes, unless user explicitly overrides.

## Auto-Created Review App Standard (Mandatory)
Every run creates or updates a model-driven review app that includes:
- All app-addressable run artifacts
- Entry-point table and landing view explicitly implemented
- App navigation sitemap-aligned to selected workflow

After app creation/update:
- Publish the app
- Validate usability: user can open app, reach expected entities/forms/views, and entry-point opens as intended

## Form Strategy Standard
- If user selected **no modification of existing OOB forms**: create new forms on OOB tables and place fields there.
- If user selected **update in place**: update selected OOB forms only.
- Post-form-update optimization must: enforce section and business labels, remove legacy sections from prior runs to avoid duplicates, and validate form XML/metadata after update.

## Validation and Reporting Requirements
Run both component-inventory checks and functional metadata checks after each build:
1. Fields exist on target tables
2. Intended forms exist with correct labels
3. App navigation contains intended entry points
4. Target solution contains required components

Write a run summary with created/updated/skipped/failed counts by category. Update `docs/build-log.md` template fields for app/sitemap/inventory/sync status.

## Human Run Sequence (Operator Checklist)
1. Run wizard intake and answer all discovery questions (including architecture intent questions).
2. Confirm planning artifacts.
3. Execute schema build scripts (`20`, `30`, `40`).
4. Execute form/view generation or OOB form update/create strategy (`60`).
5. Execute app assembly and sitemap update (`62`).
6. Run solution inventory and sync (`50`).
7. Publish.
8. Run metadata and app usability validation (`80`).
9. Export/unpack only after membership check passes.
10. Record outcomes in `docs/build-log.md`.

## Build Sequence
Use this build sequence unless the user has a documented reason to change it:
1. Clone/open repo
2. Install required extensions/tools
3. Run `00-prereq-check.ps1`
4. Run `10-auth-connect.ps1`
5. Complete Spec Kit planning (architecture intent confirmed)
6. Run scripts `15`, `20`, `30`, `40`, `50`, `55`, `60`, `62` in order
7. Run solution inventory and sync; produce membership report
8. Publish; validate app usability
9. Export, unpack, commit, pack, import, validate

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