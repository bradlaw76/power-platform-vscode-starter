---
name: power-platform-wizard-init
description: 'Use when: starting the Power Platform VS Code wizard, kicking off discovery/planning, choosing chat or terminal start path, or monitoring wizard run progress from telemetry. Supports greenfield and retrofit flows without changing core bootstrap scripts.'
argument-hint: 'Optional: mode=demo-builder|advanced-builder|framework-acceptance path=chat|terminal type=greenfield|retrofit scenario=<slug>'
---

# Power Platform Wizard Init

## Overview

This skill starts the repository wizard safely through either chat or terminal, enforces planning gates, and reports progress using existing telemetry artifacts.

This skill does not modify core wizard scripts.

## Runtime Compatibility Preflight

Skill availability is not runtime installation. A copied `SKILL.md` does not provide the PowerShell scripts, helpers, schemas, profile, or canonical docs it references.

Before intake, inspect the target repository without modifying it. Report present, missing, and incompatible runtime files, including `wizard.profile.json`, `docs/onboarding.md`, `docs/wizard-contract-v1.md`, payload schemas, and every script named by the profile. If runtime files are missing, stop and offer a reviewed bootstrap plan. Never overwrite existing instructions, skills, scripts, specs, or payloads without explicit review and approval. Use [skill-distribution.md](../../../docs/skill-distribution.md) for installation and provenance checks.

## Repository update advisor

After repository confirmation, run
`pwsh .\scripts\bootstrap\check-repository-updates.ps1` once for local cached
advice; terminal intake performs this automatically, so do not duplicate it.
Network requires explicit `-Fetch` (terminal `-FetchRepositoryUpdates`);
`-SkipRepositoryUpdateCheck` skips terminal checking. An unavailable check warns,
not a setup blocker. Cached up-to-date does not prove remote freshness.
Optional `repo-update-context.json` selections filter capability relevance;
unknown remains review-needed. Never infer approval or enable modules from advice.
Stage 90 records `repositoryBaseline` with UTC/full SHA/dirty fingerprint;
only Apply archives immutable run provenance. Resume preserves original source
identity. Never auto-pull, merge, tag, push or adopt updates. Follow
`docs/repository-updates.md`; add no discovery question or build stage.

## Universal semantic field gate

Apply `docs/semantic-field-type-standard.md` to every Dataverse use case,
industry, mode, greenfield/retrofit and standard/custom/hybrid design,
independently of FAST. Business meaning selects types, never sample strings.
Before column generation, complete and explicitly approve
`specs/<slug>/field-type-decisions.json`, mirror every decision row/ID in
spec/plan, and run `14-validate-semantic-fields.ps1` Planning. Run Payload
before builds and Metadata after relationships and before export. Resolve
categorical candidates as Yes/No, Choice, multi-select Choice, Lookup or a
separately approved text exception; define stable options, labels, meanings,
defaults, deterministic mappings and dependent surfaces. Stage 30 blocks
missing decisions and existing wrong-type fields. Never auto-approve legacy
plans, conceal drift or implicitly delete/recreate String fields.
Functional surface validation remains required. In Demo Builder, include the
inferred design in the existing consolidated confirmation, not a new questionnaire.

## What This Produces

- A selected start path (chat or terminal)
- A selected wizard mode and its completed discovery/confirmation contract
- Planning gate status for `spec.md`, `plan.md`, and `tasks.md`
- A progress snapshot (current step, last completed step, failure if present)
- The exact next safe action

## When to Use

- "start wizard"
- "start the Power Platform wizard in this repository"
- "kick off planning"
- "run the wizard in terminal"
- "start with chat prompt"
- "where did my wizard run stop"
- "monitor wizard progress"
- "retrofit existing implementation into spec kit"

## First Response Contract

Before asking discovery questions or listing build commands, give the user a short startup preview with these exact headings:

- `Initial setup`: preview that, after confirmation, you will inspect the target repository without modifying tracked project files and run the non-destructive prerequisite check.
- `Before discovery`: explain that the user will identify the application type first, then identify a new build or retrofit, and then choose chat or terminal.
- `What will change`: state that initial setup writes local progress telemetry under `.wizard-metrics/` unless `WIZARD_METRICS_OPTOUT=1`, but does not authenticate, create Dataverse resources, run build scripts, commit, or push. Planning files are created only after intake begins and the user approves the path.
- `First decision`: ask the user to confirm the target repository. Ask only this one question in the first response.

Keep this preview beginner-safe. Expand `PAC CLI`, `Dataverse`, and `Spec Kit` the first time each term appears. If the user arrived from the GitHub URL and has not cloned the repository, do not assume a folder location or project name. Ask the user two things first: (1) where they want to keep their Power Platform projects (a parent folder path), and (2) what to name this project (used as the clone's folder name). Only after they answer, give the exact clone/open commands built from their answers, then tell them to enter `/power-platform-wizard-init` in Copilot Chat. Also accept the natural-language fallback: `Start the Power Platform wizard in this repository.`

After repository confirmation, do not ask for confirmation again. Perform the repository preflight and run:

```powershell
pwsh ./scripts/bootstrap/00-prereq-check.ps1
```

Summarize pass/fail results in plain language. Resolve missing setup requirements before beginning discovery. Treat the check as non-destructive rather than read-only because local telemetry files may be updated.

## Procedure

1. Confirm target repo
- Verify the user wants to run in the current workspace repository.
- If repository confirmation is already present in the conversation, reuse it and do not ask again.
- Apply `requirements/GithubInstructions_General.md` to the app or demo being created.
- Run a read-only preflight for repository root, remote, current/default branch, working-tree state, recent history, existing tooling, and applicable validation commands.
- Do not create a branch, stage files, commit, or push during intake.

2. Select scenario type and wizard mode before the start path
- Select the application type before asking model-driven-specific discovery questions:
  - Model-driven Power App or Dynamics 365 extension: continue with this wizard.
  - Canvas app: do not start the model-driven intake; direct the user to the Canvas App workflow.
  - Existing model-driven app reporting: direct the user to the Dataverse Report Wizard.
  - Any other workload: ask the user to identify the appropriate Power Platform workflow before continuing.
- Never infer that the user wants a model-driven app from the repository, a Dataverse requirement, or the phrase "Power App".
- When asking for the build target, label it **Environment URL** and request the Dataverse/Power Platform URL (for example, `https://your-org.crm.dynamics.com`), not a friendly environment name.
- Greenfield: define scope, mappings, and target solution identity.
- Retrofit: inventory what already exists first, then define only remaining work.
- Default to `demo-builder`. Use `advanced-builder` or `framework-acceptance` only after explicit selection.

3. Select the start path
- Chat path: continue the intake in the current conversation. Do not invoke `/power-platform-demo-wizard` and restart setup.
- Demo Builder terminal path: `pwsh ./scripts/bootstrap/05-start-wizard.ps1`
- Advanced Builder terminal path: `pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Mode advanced-builder`
- Framework Acceptance terminal path: `pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Mode framework-acceptance`
- Retrofit terminal path: `pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Mode advanced-builder -Retrofit`

4. Run the selected mode's intake (do not mix modes)
- Demo Builder asks six business questions plus one consolidated technical recommendation confirmation. Infer application profile, table/form strategy, entry point, landing view, review app, navigation, relationships/reports, and solution identity. Do not ask about disposable environments, destructive cleanup, retention, acceptance source tags, or rerun-proof engineering.
- Advanced Builder asks the 11 core questions and exposes architecture controls directly. Do not ask framework-acceptance or cleanup questions.
- Framework Acceptance includes Advanced Builder plus explicit environment authorization, isolated timestamped names, acceptance source tags/hero labels, deterministic rerun evidence, retention, separately approved cleanup, and evidence capture.
- All three modes emit compatible planning artifacts for the same shared build pipeline.
- Accelerator recommendations remain disabled by default. With explicit
  `FAST_ENABLED=true` or terminal
  `-EnableAcceleratorRecommendations`, offer an optional preliminary preference
  after mode selection: Evaluate accelerators, Fully Custom, or Prefer FAST
  reuse. Persist it separately from final architecture approval. Fully Custom
  bypasses matching; the other preferences evaluate normalized requirements
  after discovery and before architecture finalization without adding a module
  selection screen or mandatory FAST business question. Demo Builder uses its existing
  consolidated approval; Advanced Builder and Framework Acceptance expose
  coverage, evidence, schema deltas, dependencies, risks, and readiness. Fully
  Custom remains independent. After approval, the separate FAST-006 planner may
  emit a provider-neutral dry-run plan with REUSE, EXTEND, CREATE, INTEGRATE,
  and DEFER dispositions. It must read the approved artifact, preserve managed
  ownership, and remain disconnected from Dataverse and build stages.
  Fully Custom always remains selectable. Persist the approved decision under
  `specs/<slug>/accelerator/`; never invoke Dataverse generation or import from
  this planning integration.
- FAST-007 readiness is local-only and default-off in all modes. Explicitly use
  `invoke-execution-readiness.ps1 -EnableExecutionReadiness` with
  `-ScenarioSlug -EvidencePath -EnvironmentUrl -EnvironmentId -TenantId`;
  optional `-WorkspaceRoot`, `-OutputFolder`, and `-EvaluationTimeUtc` control
  workspace, output, and the deterministic clock. Validate approved
  decision/build-plan
  manifest, file SHA-256, canonical IDs, input fingerprints, and external
  evidence schema. Match URL/environment ID/tenant ID exactly (URL normalized)
  and enforce a hard 24-hour evidence lifetime maximum. `READY_FOR_APPROVAL`
  is human review only and never authorizes execution; `executionAuthorized`
  is always false. Blocking statuses are `BLOCKED_PREREQUISITES`,
  `BLOCKED_EVIDENCE`, `BLOCKED_COMPATIBILITY`, `BLOCKED_SECURITY`, and
  `BLOCKED_DECISION_CHANGE`. Scope SHA-256
  binds decision/plan/evidence/inputs/target. No approval/authorization records
  are generated or consumed; `build-authorization.schema.json` is future-only.
  Orchestrator `-ExecutionReadinessOnly -ExecutionEvidencePath` also requires
  `-ReadinessEnvironmentId -ReadinessTenantId`, with optional
  `-ReadinessEvaluationTimeUtc`, and returns before helpers/stages/payload
  requirements. Never combine preflight with Apply. Normal Apply rejects
  approved `fast-based`/`hybrid` decisions regardless of readiness;
  legacy/Fully Custom builds remain unchanged. No
  Dataverse/PAC/network/authentication/install/import/build execution or live
  collection occurs in readiness itself. See
  `docs/fast-integration/execution-readiness.md`.
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
  See `docs/fast-integration/trusted-environment-verification.md`.
  Future controlled execution, independent deployment approvals/signatures,
  scoped authorization/revalidation and a separately approved executor remain
  proposed and unauthorized; FAST-dependent Apply stays disabled globally.
- Architecture intent captured directly or confirmed from Demo Builder recommendations includes:
  - OOB extension only, custom tables only, or hybrid?
  - If OOB extension: update forms in place or clone new business forms?
  - Required primary entry-point table?
  - Default landing view for that table?
  - Which artifacts must the required auto-created or updated model-driven review app surface?
- After explicit table mapping, resolve the entry-point logical name against reused standard tables, planned custom tables, or current retrofit inventory. For a uniquely planned new custom table, record `adopt-generated-active` when the requested name exactly equals `Active {plural table display name}` and `create-custom` for a distinct business view. Record `explicit-decision-required` for standard, hybrid-standard, shared, preexisting, retrofit, or ambiguous tables instead of guessing. Treat this as planning intent only; step 60 must still prove current-run creation and exact generated Active/default-view metadata. Do not proceed to app assembly until explicit decisions and Dataverse resolution are complete.
- Artifact provenance is isolated under `.wizard-metrics/artifacts/manifest/<normalized-scenario-slug>/`. Every stage validates scenario, solution, and publisher identity before manifest access. Never infer provenance from another scenario or silently consume the legacy global manifest. Preview must not create or alter manifest provenance; legacy migration requires the explicit validated helper documented in `docs/wizard-hardening-runbook.md`.

5. Capture task, relationship, report, and demo-data planning at the selected mode's depth
- At reporting scoping, explain and ask about native dashboards (standard Dataverse charts/dashboard components), custom HTML reports, both, or neither. Demo Builder includes the choice in its existing consolidated confirmation, not an extra business question. Persist separate native/HTML decisions in `Reporting Selection`. Both need complementary purposes.
- Explain each report's audience, business decision, metrics/calculations, record scope, placement, limitations, and overlap. Derive HTML content from the user's scenario documentation, top tasks, lifecycle, tables, and success criteria. Frontline/agent, supervisor, and leadership are Dynamics-styled patterns, not a mandatory set of three.
- Before HTML generation, author and explicitly approve scenario `html-reports.json` against `html-reports.schema.json`, exact requirement excerpts in current `spec.md`/`plan.md`, and matching table/title/placement rows in `report-mappings.md`. Generate only defined metrics; no guessed priority, owner, or queue fields. Follow `docs/live-report-web-resources-runbook.md` for query limitations and placement handoff. Never auto-approve legacy HTML or build native payloads after opt-out. The focused Report Wizard remains native-only.
- Record top user tasks as persona, task, frequency, entry table/view, expected outcome, owner, and done definition.
- For each relationship, capture cardinality, requiredness, existing/new status, cascade behavior, and supporting task/surface.
- Generate `report-mappings.md` for every run. If reports are enabled, capture critical/high-frequency tables and one mapping per report with table logical name, surface, form/dashboard/view type, placement, required fields, supported decision, owner, and validation checklist. Block progression when a critical table has no mapping. If reports are disabled, record that explicit decision.
- If demo data is enabled, choose all scenario-created custom tables or selected tables, confirm the resolved tables, and capture per-table counts, scenarios/states, hero records and their demo purpose, relationship distribution, method, and privacy constraints. Rerun-proof evidence, acceptance source tagging, retention, and cleanup approval belong only to Framework Acceptance.
- If Dataverse Task activities are requested, capture eligible parent tables, latest/all/selected scope, source-record limit (default 10 for latest), ordering field, and tasks per selected record. Do not plan tasks for every record unless the user explicitly selects all.
- Generate `demo-data-plan.json` when enabled. This stage plans data only and must not create Dataverse rows.

6. Capture the source-control extension block when enabled
- Scenario branch (default: `feature/<scenario-slug>`)
- Related issue, spec, or work item
- Checkpoint or final-only commit strategy
- Validation and CI commands discovered from the target repository
- Pull request handoff and merge strategy
- Persist these decisions in `answers.md`, `plan.md`, and `tasks.md`.

7. Enforce hard gates before build scripts
- Planning artifacts must be complete and aligned before any mutation scripts:
  - `spec.md`
  - `plan.md`
  - `tasks.md`
  - `report-mappings.md`
- Do not recommend scripts `20+` before the planning gate passes.
- Prefer the orchestrated preview and apply entry point: `pwsh ./scripts/bootstrap/90-run-build.ps1 -ScenarioSlug <scenario-slug> -Mode <Preview|Apply>`.
- A planned BPF uses `55-build-business-process-flows.ps1` to validate payloads and generate a designer handoff. Initial definition authoring occurs through Power Apps; apply mode validates, activates, adds, and links the existing category-4 process.
- The required review app is assembled and validated by `62-build-app-module.ps1`.
- When `choice-presentations-*.json` exists, optional `35-style-choice-options.ps1` runs after column creation. It applies allowlisted pastel colors and optional inline Unicode prefixes such as `▲`, `◆`, `⚠`, and `ℹ` to existing options on wizard-owned unmanaged local Choice columns. The icon is part of the Choice label, not separate icon metadata. Preview emits a SHA-256 hash; orchestrated Apply requires `-ApprovedChoicePresentationPlanHash <sha256>`.
- When `specs/<scenario-slug>/form-layouts.json` exists, optional `63-format-forms.ps1` runs after app assembly. Its schema-validated Preview emits artifacts and a SHA-256 hash; Apply requires the approved hash. Version 1 targets only active, customizable, wizard-owned custom Main forms and existing baseline controls/fields, with tabs, sections, one- to three-column layouts, Boolean Toggle components, and Choice OptionSet Wrapper components. Components are type-checked and configured for web, tablet, and phone. OOB forms and other components are deferred.
- Capture whether the modern Power Apps grid is desired at table level for all
  all views and whether inline editing is enabled. Demo Builder infers this inside
  its consolidated recommendation without adding a business question;
  Advanced and Framework Acceptance ask explicitly. When enabled, generate
  `grid-controls.json` and route it to
  `61-configure-power-apps-grid.ps1` after forms/views and before
  reporting/app assembly. Preview is a classic solution explorer maker handoff;
  Apply verifies `Microsoft.PowerApps.PowerAppsOneGrid` in exported metadata.
  This is separate from form layout and subgrids; subgrid support is deferred.
- Credential-free orchestrator Preview lists the formatting target. Orchestrated Apply requires `-ApprovedFormFormattingPlanHash <sha256>`.
- Anthropic's `frontend-design` skill is optional advice only and is not installed by this repository.
- Native `reporting-*.json` charts/dashboard are built by `64-build-charts-dashboard.ps1` before app assembly.
- Stable-key, source-tagged `data-*.json` records are built by `66-seed-synthetic-data.ps1`.
- Framework Acceptance captures and verifies a controlled second pass with `85-verify-idempotency.ps1`.
- After app/report assembly, require `50-add-to-solution.ps1 -InventoryOnly -EnforceExportGate`. Do not recommend export while required membership fails.
- `95-export-unmanaged-solution.ps1` performs unmanaged export and local unpack/inspection only. Never import that acceptance package.

8. Monitor progress using existing telemetry (no script changes)
- Primary signal: `.wizard-metrics/events.jsonl`
- Event statuses: `Started`, `Completed`, `Failed`
- Optional summaries:
  - `pwsh ./scripts/bootstrap/81-build-progress-matrix.ps1`
  - `pwsh ./scripts/bootstrap/82-build-progress-report.ps1`
- If telemetry is opted out (`WIZARD_METRICS_OPTOUT=1`), use artifact-based checks instead.

9. End every run with a deterministic output contract
- Selected path
- Current gate status
- Current or failed step
- Exact next safe command

## Safety Rules

- Follow the authoritative sequence in `docs/onboarding.md`.
- Keep chat and terminal paths equivalent in gate enforcement.
- Treat unresolved intake, missing solution identity, failed prereqs, or failed auth as hard stops.
- Never bypass planning to jump straight to build scripts.
- Keep unrelated working-tree changes untouched.
- Require explicit approval before commit and separate approval before push.
- After push, verify that the remote branch contains the local commit before reporting success.

## Progress Commands

Use these when the user asks for status:

```powershell
pwsh ./scripts/bootstrap/81-build-progress-matrix.ps1
pwsh ./scripts/bootstrap/82-build-progress-report.ps1
```

## Troubleshooting (Init Stage)

- `pac` missing:
  - Install CLI and rerun prereq check.
- Wrong terminal context:
  - Ensure PowerShell 7 and repo root.
- Auth/profile not ready:
  - Run `pwsh ./scripts/bootstrap/10-auth-connect.ps1`.
- Telemetry unavailable:
  - Check `WIZARD_METRICS_OPTOUT` and fall back to artifact checks.

## References

- [Onboarding sequence](../../../docs/onboarding.md)
- [Wizard contract](../../../docs/wizard-contract-v1.md)
- [Wizard profile](../../../wizard.profile.json)
- [GitHub engineering standards](../../../requirements/GithubInstructions_General.md)
- [Start wizard script](../../../scripts/bootstrap/05-start-wizard.ps1)
- [Telemetry helper](../../../scripts/bootstrap/helpers/wizard-telemetry.ps1)
- [Progress matrix](../../../scripts/bootstrap/81-build-progress-matrix.ps1)
- [Progress report](../../../scripts/bootstrap/82-build-progress-report.ps1)
- [Detailed monitoring reference](./references/progress-monitoring.md)
