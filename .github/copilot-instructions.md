# Project Guidelines

## Authorization and execution

Mandatory for framework work and all wizard-generated projects: load and follow
[authorization and execution](../docs/policies/authorization-and-execution.md).
Reuse valid scoped permission without redundant approval loops; preserve every
required platform, planning, signature and environment gate. Include the policy
or a reviewed equivalent in consumer projects through the existing distribution
review. Report source, test, deployment, live verification and blocked outcomes
separately.

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

H009 version/update status uses the confirmed runtime's
`scripts/bootstrap/04-check-wizard-update.ps1 -Action Status` (offline,
read-only). Both agent families and terminal share Review changes / Update
wizard / Skip for now; Skip continues unchanged. Do not equate copied skills,
profile/contract versions or main commits with a verified release. Never
implement agent-specific pull/copy updating. Official Apply is fail-closed
without independently verified publisher policy, immutable identity, integrity,
compatibility and file ownership. See `docs/wizard-updates.md`.

This repository is a guided Power Platform and Dynamics 365 wizard for VS Code.
When users ask how to use the repo, default to a beginner-safe, step-by-step flow.
Always require planning before build implementation:
- Ask discovery questions first.
- Create or update `spec.md`, `plan.md`, and `tasks.md` before recommending build scripts.
- Only move to bootstrap scripts after requirements and tasks are clear.

## Wizard Modes
Before recommending automation, inspect the actual environment and tool availability. Guided delivery must work without WSL; suggest automated workers only when their expected time savings exceed setup, verification and recovery costs and the owner opts in. Production keeps all applicable security, CI and deployment gates, regardless of a short deadline. Persist delivery intent in the scenario's Spec Kit files. See `docs/delivery-pacing-and-tooling.md`.
Use `demo-builder` by default. Ask six core business questions (idea/outcome, primary user/task, data, experience/lifecycle, success/sample data, environment/output) plus two short delivery questions (prototype/presentation-demo/connected-demo/pilot/production; user-specified deadline), then present one consolidated technical recommendation for confirmation. Reuse delivery answers already provided; do not ask twice. Do not ask acceptance, disposable-environment, retention, rerun-proof, source-tag, or cleanup questions in this mode.

Use `advanced-builder` only when the user explicitly requests technical control or retrofit detail. Ask the core discovery and architecture questions directly, including table/form strategy, entry point, landing view, review app, mapping, relationships, reports, demo data, solution identity, and source control. Do not ask acceptance, disposable-environment, retention, rerun-proof, or cleanup questions.

Use `framework-acceptance` only after explicit selection. Add authorized-environment confirmation, isolated timestamped naming, acceptance source tags and hero labels, deterministic rerun evidence, retention, separately approved destructive cleanup, and acceptance evidence planning.

All modes must capture or confirm architecture intent before build scripts, produce compatible scenario planning artifacts, and use the same bootstrap pipeline.

When demo data is requested, never seed standard reused tables implicitly. If Dataverse Task activities are requested, capture eligible parent tables, latest/all/selected scope, a bounded source-record count, ordering field, and tasks per selected record; do not create tasks for every record unless the user explicitly selects all.

Capture the top user tasks with persona, frequency, entry table/view, expected outcome, owner, and done definition. For every planned relationship, capture cardinality, requiredness, existing/new status, cascade behavior, and the task or app surface it supports.

## Wizard Behavior

For installed H008 progress, use the existing read-only Status action described
in `docs/framework-handoff.md`. Its `task_summary` preserves native IDs and
projects canonical counts, dependencies, owners/leases and timestamps without
dispatch, stored lease mutation or scheduler activation. Coordinator eligibility
does not replace worker scope/capability gates; missing/corrupt records are
explicit and stale source evidence remains stale.
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

## New or Extended Scenario Impact Gate (Mandatory Planning)

Apply the proportional [scenario change impact gate](../docs/scenario-change-impact-gate.md) to the actual delta. Minor maintenance retains accepted planning and uses focused checks; do not regenerate the full matrix or repeat discovery. Scenario changes review affected requirements, schema/bindings, forms/views, permissions, data and dependent surfaces before implementation, keeping affected Spec Kit files aligned and linking unchanged contracts. Mark existing vs candidate vs prepared vs deployed clearly; native field and security proof is mandatory before live binding. Preserve shared assets and active writers, continue independent ready work, and use only owner-assigned H/workload IDs without allocating new ones.

This is a pre-build documentation check, not authority to alter Dataverse, seed standard tables, add roles, publish, merge, skip accepted business decisions or start a second writer.

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
6. Run scripts `15`, `20`, `30`, `40`, `50`, `55`, `60`, `64`, `62`, `65`, and `66` when their scenario payloads enable them
7. Run first solution membership, capture idempotency baseline, rerun experience/data stages, and run final membership plus script `85`
8. Publish only scoped components and validate app usability
9. Run script `95` for unmanaged export and local unpack/inspection; Framework Acceptance must never import that package

## Documentation References
Use and reference these files when relevant:
- `docs/onboarding.md` — **authoritative bootstrap sequence**
- `README.md`
- `docs/build-log.md`
- `requirements/how-to-build-dynamics-model-driven-apps-wizard.md`
- `requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md`

## Sustained execution after planning and authorization

For explicit new-Dynamics intent or supplied source review notes, follow the
[optional workload/source-note contract](../docs/wizard-contract-v1.md#optional-workload-and-reviewed-source-input).
Keep Demo Builder's prompt budget; no first-party provisioning, automatic source
fetching or inferred material/architecture approval. Preserve quoted human notes
and pending review tasks.

The one-question-at-a-time **discovery** flow above still applies until the user has accepted the scenario plan and any required owner/environment decisions. After that, avoid repeated 2–5-minute implementation handoffs. Include the relevant downstream backlog, dependencies, accepted file/operation scope, tests, rollback, and stop conditions in one instruction.

- Execute a meaningful sequence of separately authorized READY tasks: validate the saved baseline, apply the scoped change, run the right checks, correct routine errors within the approved budget, and continue the next eligible task without requiring a new prompt for each milestone.
- Record an unchanged access/ownership/Dataverse blocker once with its exact decision-maker; mark that lane BLOCKED and proceed with other safe work. Do not repeatedly rerun completed tests or ask already-answered setup questions.
- Persist progress in the existing planning, build-log and task records; use checkpoint recovery rather than restarting the wizard or overwriting prior work. Make one consolidated delivery report with verified changes, outstanding decisions, and explicit live-vs-fixture evidence.
- Never infer approval to run build/publish scripts, commit/push/merge, create security roles, or write Dataverse from this cadence rule. Honor all planning gates, business requirements, actual permissions and required approval steps already defined above.
- After VS Code closes, claim automatic continuation only if a real persistent worker is installed, enabled, authorized, and has valid READY tasks. A timer, scheduled monitor, or written instruction is not a coding agent.

This reusable behavior is consistent with the proposed [Sustained Execution Standard](https://github.com/bradlaw76/Work-items-standards-/pull/5) and SpeckKit's [agent-default update](https://github.com/bradlaw76/SpeckKit-Project-Development/pull/1). Existing consumers must update and load reviewed guidance; links or open PRs do not change active jobs automatically.

## Editing Expectations
Keep repo changes minimal and practical.
Do not skip beginner explanations.
Do not recommend running build scripts before planning is complete.