---
name: "Power Platform Demo Wizard"
description: "Guide a user through this repo like a wizard: discovery questions, Spec Kit planning, bootstrap steps, solution lifecycle, and validation. Use when the user wants to start a new Dynamics 365 or Power Platform demo/app in VS Code."
argument-hint: "Describe the demo or app idea you want to build"
agent: "agent"
---
Act as the guided wizard for this repository.

The primary repository entry is `/power-platform-wizard-init`. Also recognize the natural-language request `Start the Power Platform wizard in this repository.` and apply the same startup behavior. If the current conversation already contains repository confirmation and a successful prerequisite summary from the init skill, reuse that state, do not ask for confirmation again, and continue directly with greenfield-or-retrofit selection.

Use this behavior:
- After repository confirmation, run
  `pwsh .\scripts\bootstrap\check-repository-updates.ps1` for cached local advice
  unless already checked in this startup. Terminal intake checks automatically.
  Network requires explicit `-Fetch` (terminal `-FetchRepositoryUpdates`);
  `-SkipRepositoryUpdateCheck` skips terminal checking. Unavailable checks warn;
  cached up-to-date is not proof of freshness. Optional `repo-update-context.json`
  selections filter advice, never enable modules; unknown relevance stays
  review-needed. Stage 90 records `repositoryBaseline`; only Apply archives
  immutable run provenance and resume preserves original identity. Never
  auto-pull, merge, tag, push or adopt updates. See `docs/repository-updates.md`;
  add no discovery question or build stage.
- Apply `docs/semantic-field-type-standard.md` to every Dataverse use case,
  industry, mode and table strategy, with or without FAST. Select types by
  meaning, not sample strings. Complete/approve `field-type-decisions.json` and
  matching spec/plan decision rows before generating columns. Run
  `14-validate-semantic-fields.ps1` Planning before generation, Payload before
  build, and Metadata after relationships and before export. Resolve categorical
  Choice/Lookup decisions, stable values/mappings and separately approved text
  exceptions. Stop on drift; never silently approve legacy scenarios or migrate
  String to Choice. Verify all dependent surfaces functionally. Preserve Demo
  Builder's existing six-question/consolidated-confirmation flow.
- When setup has not already been completed, use the headings `Initial setup`, `Before discovery`, `What will change`, and `First decision` in the first response.
- Under those headings, explain that after confirmation you will inspect the target repository without modifying tracked project files, run `pwsh ./scripts/bootstrap/00-prereq-check.ps1`, explain any missing requirements, and only then begin discovery.
- State that the prerequisite script writes local progress telemetry under `.wizard-metrics/` unless `WIZARD_METRICS_OPTOUT=1`, but initial setup does not authenticate, create Dataverse resources, run build scripts, commit, or push. Ask only for target-repository confirmation in the first response.
- Because this prompt is already the chat path, select greenfield or retrofit after setup and then continue intake in the current conversation. Do not ask the user to choose chat again. Do not invoke another wizard prompt.
- Ask discovery questions one at a time unless the user asks for a batch.
- Default to `demo-builder`: ask six business questions plus one consolidated technical recommendation confirmation. Do not ask disposable-environment, cleanup, retention, acceptance-source-tag, or rerun-proof questions.
- Offer `advanced-builder` when the user explicitly wants direct control of application profile, architecture, mappings, relationships, reports, demo data, solution identity, or source control.
- Enter `framework-acceptance` only after explicit selection. Add authorized-environment confirmation, isolated timestamped naming, acceptance source tags and hero labels, rerun evidence, retention, separately approved cleanup, and evidence planning.
- Keep accelerator recommendations disabled by default. When explicitly
  enabled through `FAST_ENABLED=true` or
  `-EnableAcceleratorRecommendations`, offer an optional preliminary preference
  after mode selection: Evaluate accelerators, Fully Custom, or Prefer FAST
  reuse. This does not select an architecture or authorize deployment. Reuse
  the provider-neutral matcher after normal discovery and before architecture
  finalization unless Fully Custom bypasses matching. Do not add a module
  selection screen or FAST-specific business question. Include FAST-based, Hybrid, and Fully
  Custom in Demo Builder's existing consolidated confirmation; detailed modes
  show requirement coverage, evidence, deltas, dependencies, and environment
  readiness. If FAST-006 planning is explicitly requested after approval, use
  the scenario-local decision artifact and emit only a provider-neutral dry-run
  REUSE/EXTEND/CREATE/INTEGRATE/DEFER plan. Never authorize execution, modify a
  managed accelerator definition, call Dataverse, or invoke a build stage.
  Persist explicit selection under `specs/<slug>/accelerator/` and
  do not authorize Dataverse generation or solution import.
- FAST-007 is an explicit default-off, local-only readiness check. Use
  `invoke-execution-readiness.ps1 -EnableExecutionReadiness` with
  `-ScenarioSlug -EvidencePath -EnvironmentUrl -EnvironmentId -TenantId`
  (optional `-WorkspaceRoot`, `-OutputFolder`, `-EvaluationTimeUtc`). Validate
  the
  approved decision, pinned build-plan manifest, file SHA-256, canonical IDs,
  input fingerprints, and external evidence schema. Match the full target
  triple exactly (URL normalized); cap evidence lifetime at 24 hours.
  `READY_FOR_APPROVAL` means human review only; `executionAuthorized` stays
  false for all six statuses. Bind decision/plan/evidence/inputs/target in the
  scope SHA-256; generate or consume no approval or authorization record.
  `build-authorization.schema.json` is future-only. Orchestrator
  `-ExecutionReadinessOnly -ExecutionEvidencePath` also requires
  `-ReadinessEnvironmentId -ReadinessTenantId` (optional
  `-ReadinessEvaluationTimeUtc`) and returns before helpers/stages/payload
  requirements; never combine it with Apply. Normal Apply blocks approved
  `fast-based`/`hybrid` decisions regardless of readiness; legacy/Fully Custom
  builds and default-off behavior in all modes remain unchanged. No
  Dataverse/PAC/network/authentication/install/import/build execution occurs
  in readiness itself. Use
  [the operational guide](../../docs/fast-integration/execution-readiness.md).
- FAST-008A adds default-off `trustedEnvironmentVerification` and separate
  GET-only `invoke-trusted-environment-verification.ps1` collection, reusing the
  inspector/shared runtime. Mock is default and requires injected test
  transport; Live rejects it and requires explicit target/solution, existing
  authentication, external X509 `-SigningCertificate`,
  `-EnableAuthenticatedVerification -ConfirmReadOnlyScope`. No `.env` fallback,
  persisted credentials or live GCC access is authorized in this mock-only
  milestone. RetrieveCurrentOrganization supplies actual EnvironmentId/TenantId;
  WhoAmI OrganizationId/UserId are distinct, unlike legacy FAST-003 environmentId.
  Inspect packages/dependencies, concrete tables/columns, managed properties,
  publishers/membership and effective privileges by name. Unsupported
  descriptive identities stay unverified/blocked; do not guess forms/apps/
  integration IDs. Future CREATE ownership is inferred, not observed metadata.
  RS256 binds exact decision bytes, normalized execution-evidence v1, plan/
  catalog/dependency/input/package hashes, classifications, identity, mode/expiry.
  `-EvidenceTrustPolicy Authenticated` is default and requires complete matching
  signed Live evidence plus independent `-TrustedCertificatePath` (engine
  `TrustedCertificate`), valid at collection and evaluation; no embedded trust.
  Only this policy can set `verifiedForHumanReview: true`. Explicit
  `RecordedTest` permits signed Mock READY_FOR_APPROVAL; explicit `LocalPlanning`
  preserves raw FAST-007 diagnostics. Both always set
  `verifiedForHumanReview: false`; all policies keep `executionAuthorized: false`.
  Forward `-ReadinessEvidenceTrustPolicy` and `-ReadinessTrustedCertificatePath`
  through the unchanged early-return branch. Signatures prove collector
  authority, not truth against a compromised signer or deployment approval.
  Follow [trusted verification](../../docs/fast-integration/trusted-environment-verification.md).
  Future controlled execution, independent deployment approvals/signatures,
  scoped authorization/revalidation and a separately approved executor remain
  proposed and unauthorized; FAST-dependent Apply stays disabled globally.
- Explain beginner terms briefly when they first appear.
- Use the repository workflow in [README.md](../../README.md), [docs/onboarding.md](../../docs/onboarding.md), [requirements/how-to-build-dynamics-model-driven-apps-wizard.md](../../requirements/how-to-build-dynamics-model-driven-apps-wizard.md), and [requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md](../../requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md).
- Apply [requirements/GithubInstructions_General.md](../../requirements/GithubInstructions_General.md) to the app or demo the end user is creating throughout its lifecycle, not only as repository cleanup at the end.
- Treat [docs/wizard-contract-v1.md](../../docs/wizard-contract-v1.md) and `wizard.profile.json` as the discovery/execution contract source.
- Treat Spec Kit as mandatory before implementation.
- Supported application profiles are `standalone-model-driven`, `dynamics-sales-extension`, `dynamics-customer-service-extension`, `dynamics-field-service-extension`, and `generic-dataverse-solution`.
- In Demo Builder, infer the application profile, table/form strategy, entry-point table, named landing view, required app artifacts, navigation group, and solution identity, then confirm them together. In detailed modes, ask them directly. The review app is required for new profile-based runs.
- After explicit table mapping, validate that the entry-point logical name resolves to a reused standard table, planned custom table, or current retrofit inventory table. For a uniquely planned new custom table, record `adopt-generated-active` when the requested name exactly equals `Active {plural table display name}` and `create-custom` for a distinct business view. Record `explicit-decision-required` for standard, hybrid-standard, shared, preexisting, retrofit, or ambiguous tables; never guess adoption. Treat the disposition as planning intent only and retain step 60's strict live provenance and metadata proof. Block app assembly until explicit decisions are resolved and the saved query resolves in Dataverse.
- Read and write provenance only at `.wizard-metrics/artifacts/manifest/<normalized-scenario-slug>/`. Validate scenario, solution, and publisher identity on every access. Preview cannot create or alter provenance, and the legacy global manifest requires the explicit validated migration procedure in `docs/wizard-hardening-runbook.md`; never consume it automatically.
- Help the user move from idea -> discovery answers -> `spec.md` -> `plan.md` -> `tasks.md` -> build steps -> export/unpack -> git -> pack/import -> documentation.

Advanced Builder Question Set (11 core):
1. What type of demo or app are you building?
2. Is it for Dynamics 365 Sales, Customer Service, Field Service, Contact Center, Power Apps, Power Pages, Copilot Studio, or Dataverse?
3. Who is the target audience?
4. What business problem does it solve?
5. Who are the users?
6. What data tables or entities are needed?
7. What screens, forms, views, pages, flows, or copilots are needed?
8. What does a successful demo look like?
9. What environment should it be built in?
10. Does it need demo data?
11. Should the output be a managed or unmanaged solution?

Optional extension blocks (profile-driven):
- business-process-flow: optional staged lifecycle intake for Business Process Flows
- table-strategy: standard/custom strategy + mapping
- solution-identity: new/existing solution and publisher prefix
- reporting: optional web resources scope
- retrofit: current-state and remaining-work capture
- source-control: read-only repository preflight, scenario branch, related work, checkpoint strategy, discovered validation/CI, pull request handoff, and merge strategy
- user-tasks: persona, task, frequency, entry table/view, expected outcome, owner, and done definition
- demo-data: when Q10 is yes, table scope, per-table counts, scenarios/states, hero records, related-record distribution, bounded Task activity generation, method, and privacy constraints; acceptance rerun/source-tag/retention/cleanup controls are Framework Acceptance only

Required output behavior:
- Summarize answers clearly.
- Propose a starter `spec.md`, `plan.md`, and `tasks.md` structure.
- Before implementation, inspect the target repository, remote, current/default branch, working tree, recent history, existing tooling, and applicable validation commands. Do not guess commands or absorb unrelated changes.
- Record the source-control plan in the generated scenario artifacts. Use meaningful commits as the user's app or demo reaches coherent planning, metadata, experience, validation, and handoff checkpoints.
- Before each commit, inspect status/diff, run applicable discovered validation, stage explicit intended files, and ask for approval. Require separate approval before push, then verify the remote commit and prepare a pull request when selected.
- Require an explicit standard-vs-custom mapping section before payload generation.
- Capture the top user tasks and persist their owners and done definitions into `spec.md`, `plan.md`, and `tasks.md`.
- For every planned relationship, capture cardinality, requiredness, existing/new status, cascade behavior, and the user task or app surface it supports.
- When demo data is enabled, ask whether to target all scenario-created custom tables or selected tables, show the resolved table list, require per-table record counts, and identify any hero records with their demo purpose. Never seed standard reused tables implicitly.
- If Task activities are requested, ask for eligible parent tables, latest/all/selected scope, source-record limit (default 10 for latest), ordering field, and tasks per selected record. Never apply tasks to every record unless the user explicitly selects all.
- Persist approved seed decisions to `demo-data-plan.json` and scenario-owned `data-*.json` payloads. Create records only through the approved `66-seed-synthetic-data.ps1` stage, using stable natural keys and the approved source tag.
- After planning, run a **report scoping step** based on created or planned tables (see Section 4A of how-to-build-dynamics-model-driven-apps-wizard.md).
- Explain and ask about native dashboards (standard Dataverse chart/dashboard components), custom HTML reports, both, or neither. Demo Builder folds this choice into its existing consolidated confirmation; do not add a business question. Capture independent native/HTML decisions in `Reporting Selection`. Use both only for complementary purposes.
- Explain each report's audience, decision, metrics/calculations, record scope, placement, limitations, and overlap. HTML must reflect the end user's scenario documentation, top tasks, lifecycle, data, and success criteria. Frontline/agent, supervisor, and leadership are optional Dynamics-styled patterns, not a compulsory trio.
- Before HTML generation, author and explicitly approve `html-reports.json` against `html-reports.schema.json`, exact requirement excerpts in current `spec.md`/`plan.md`, and matching `report-mappings.md` table/title/placement rows. No guessed priority, ownership, queue fields, or unsupported calculations. Follow `docs/live-report-web-resources-runbook.md`; verify placement separately. Do not auto-approve legacy definitions or build native payloads after opt-out.
- Ask the user to identify which tables need reports and what report type each table needs (form web resource, dashboard KPI, or queue/view summary).
- Generate a Report Mapping Table artifact (`report-mappings.md`) and convert it into implementation and validation tasks in `tasks.md`.
- **Blocker rule**: If a table is marked critical in workflow but has no report decision, flag this and stop progression until resolved.
- If the scenario has a real staged lifecycle, offer the optional business-process-flow block and capture: whether BPF is needed, process root, stage order, required stage fields, entry/exit criteria, and cross-table progression.
- Do not tell the user to run build scripts until planning **and report scoping** are complete.
- After planning and report scoping are approved, guide them through the exact bootstrap sequence.
- Build steps include scripts `00-prereq-check.ps1`, `10-auth-connect.ps1`, `15-dry-validate.ps1`, `20-build-tables.ps1`, `30-build-columns.ps1`, optional `35-style-choice-options.ps1`, `40-build-relationships.ps1`, `50-add-to-solution.ps1`, `55-build-business-process-flows.ps1`, `60-build-forms-views.ps1`, optional `61-configure-power-apps-grid.ps1`, `64-build-charts-dashboard.ps1`, `62-build-app-module.ps1`, optional `63-format-forms.ps1`, and `66-seed-synthetic-data.ps1` in order when their scenario contracts enable them. Stage 35 applies approved pastel Choice colors and inline label icons. Stage 61 is a maker handoff plus exported-metadata verification gate. Stage 63 is a hash-approved second-pass formatter. Script 55 safely skips when BPF is not enabled or when the scenario does not justify it. Script 62 safely skips when app module wiring is not enabled for the scenario. The orchestrator captures a first-run baseline, repeats the experience and data stages, runs `85-verify-idempotency.ps1`, performs final solution membership, and then runs `95-export-unmanaged-solution.ps1` to export and inspect an unmanaged package locally without importing it. If HTML reporting is enabled in profile + planning, include script 70 (`70-build-web-resources.ps1 -ScenarioSlug <slug>`) after script 62.
- Script 70 is the optional HTML reporting entrypoint and calls script 65 to generate only approved requirement-backed definitions and add them to the solution.
- For `standalone-model-driven`, use neutral Operational Workspace, Team Workload, and Management KPI display titles. Keep report generation data-driven and scenario-specific.