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

## Wizard Modes
Use `demo-builder` by default. Ask six business questions (idea/outcome, primary user/task, data, experience/lifecycle, success/sample data, environment/output), infer the technical design, then present one consolidated recommendation for confirmation. Do not ask acceptance, disposable-environment, retention, rerun-proof, source-tag, or cleanup questions in this mode.

Use `advanced-builder` only when the user explicitly requests technical control or retrofit detail. Ask the core discovery and architecture questions directly, including table/form strategy, entry point, landing view, review app, mapping, relationships, reports, demo data, solution identity, and source control. Do not ask acceptance, disposable-environment, retention, rerun-proof, or cleanup questions.

Use `framework-acceptance` only after explicit selection. Add authorized-environment confirmation, isolated timestamped naming, acceptance source tags and hero labels, deterministic rerun evidence, retention, separately approved destructive cleanup, and acceptance evidence planning.

Accelerator recommendations remain disabled by default. When the operator
explicitly enables them with `FAST_ENABLED=true` or the terminal wizard's
`-EnableAcceleratorRecommendations` switch, offer a preliminary accelerator
preference after mode selection: Evaluate accelerators, Fully Custom, or Prefer
FAST reuse. The preference is optional planning input, not architecture
approval or deployment authorization. Then evaluate the already collected
requirements after discovery and before architecture finalization. Do not add
a module-selection screen or mandatory FAST business question. Fully Custom
preference bypasses matching. Demo Builder includes
FAST-based, Hybrid, and Fully Custom selection in its existing consolidated
confirmation; detailed modes show requirement coverage, evidence, schema
deltas, dependencies, and readiness. Persist the explicit decision under the
scenario's `accelerator/` folder. Never treat this planning decision as
Dataverse build, import, or deployment authorization.

FAST-006 planning is a separate explicit, default-off dry run that
must consume the approved decision artifact, preserve managed ownership, keep
Fully Custom independent of FAST prerequisites, and never call Dataverse or
bootstrap build stages.

FAST-007 is authorized local-only execution readiness, not a continuation of
FAST-006 execution planning. Use `invoke-execution-readiness.ps1` only with
`-EnableExecutionReadiness -ScenarioSlug -EvidencePath -EnvironmentUrl
-EnvironmentId -TenantId` (optional `-WorkspaceRoot`, `-OutputFolder`,
`-EvaluationTimeUtc`). Require the approved scenario decision, pinned build-plan
manifest, SHA-256/canonical IDs/input fingerprints, schema-valid external
evidence, exact full target identity (URL normalized), and a maximum 24-hour
evidence lifetime. `READY_FOR_APPROVAL` is human review only;
`executionAuthorized` is always false. The SHA-256 scope binds decision, plan,
evidence, inputs, and target; never generate or consume approval/authorization
records. `build-authorization.schema.json` is future-only.

`90-run-build.ps1 -ExecutionReadinessOnly` uses `-ExecutionEvidencePath`,
`-ReadinessEnvironmentId`, `-ReadinessTenantId`, and optional
`-ReadinessEvaluationTimeUtc`, and returns before helpers/stages/payload
requirements. Never combine preflight with Apply. Approved `fast-based` and
`hybrid` decisions block normal Apply regardless of readiness; legacy/Fully
Custom builds are unchanged. FAST stays default-off in every mode. Readiness
never performs Dataverse/PAC/network/authentication/install/import/build work
or verifies live platform provenance. Follow
`docs/fast-integration/execution-readiness.md`; FAST-008 trusted evidence,
independent approver/signature verification, authorization
consumption/revalidation, and a separately approved executor are proposed,
not implemented.

All modes must capture or confirm architecture intent before build scripts, produce compatible scenario planning artifacts, and use the same bootstrap pipeline.

Optional UI enhancement stages are
`35-style-choice-options.ps1`, `61-configure-power-apps-grid.ps1`, and
`63-format-forms.ps1`. Run them only when their scenario contracts enable them,
with their documented approval or verification gates.

When demo data is requested, never seed standard reused tables implicitly. If Dataverse Task activities are requested, capture eligible parent tables, latest/all/selected scope, a bounded source-record count, ordering field, and tasks per selected record; do not create tasks for every record unless the user explicitly selects all.

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
3. Execute schema build scripts (`20`, `30`, optional Choice presentation `35`, `40`).
4. Execute form/view generation (`60`) and optional all-views grid handoff/verification (`61`).
5. Execute app assembly (`62`) and optional second-pass form formatting (`63`).
6. Run solution inventory and sync (`50`).
7. Publish only scoped changed components.
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
6. Run scripts `15`, `20`, `30`, optional `35`, `40`, `50`, `55`, `60`, optional `61`, `64`, `62`, optional `63`, `65`, and `66` when their scenario contracts enable them
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
- `README.md` — enhancement registry and future-change maintenance checklist

## Editing Expectations
Keep repo changes minimal and practical.
Do not skip beginner explanations.
Do not recommend running build scripts before planning is complete.
For every runtime enhancement, update the README enhancement registry and all
applicable surfaces in its required future-enhancement checklist.