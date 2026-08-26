# Onboarding Guide

> **This is the authoritative bootstrap sequence for this repository.** All agents, chat prompts, and documentation defer to the step order defined here. If another document shows a different order, this file takes precedence.

Use this document when setting up this repo for the first time in VS Code.

Prefer a visual format? Open the full walkthrough page: [docs/wizard-walkthrough.html](wizard-walkthrough.html).

This is the beginner-safe, step-by-step path for building standalone model-driven Power Apps and Dynamics 365 extensions from VS Code.

Important process rule:

- Complete Spec Kit planning (`spec.md`, `plan.md`, `tasks.md`) before building artifacts.

---

## Fastest Start: Let Copilot Guide Setup

Use this path when Git, VS Code, and Copilot Chat are already available. After cloning and opening the repository in VS Code, open Copilot Chat and enter:

```text
/power-platform-wizard-init
```

Natural-language fallback:

```text
Start the Power Platform wizard in this repository.
```

The first response must explain the initial setup before asking any discovery question. It will confirm the repository, inspect it without modifying tracked project files, run `00-prereq-check.ps1`, explain the results, ask whether this is a greenfield build or retrofit, and then ask you to choose chat or terminal.

The prerequisite script writes local progress telemetry under `.wizard-metrics/` unless `WIZARD_METRICS_OPTOUT=1`. Initial setup does not authenticate, create Dataverse resources, run build scripts, commit, or push.

If Git, VS Code, or Copilot Chat is not available, follow the manual sequence below. The guided skill orchestrates the same prerequisite and planning order; do not run the same prerequisite step again unless setup changed or the earlier check failed.

---

## Before You Start: Beginner Concepts

- PAC CLI (`pac`): command-line tool for Power Platform operations.
- Dataverse: data platform used by model-driven apps.
- Solution: a package of app components (tables, forms, views, flows).
- Unpack/pack: convert solution zip to source files and back.
- Spec Kit: planning method that defines requirements before implementation.

Why this matters:

- Following this order prevents rework and makes handoff/demo prep repeatable.

---

## Step 0: Clone the Repo and Open in VS Code

If this is your first time with the repository:

```powershell
git clone https://github.com/bradlaw76/power-platform-vscode-starter
cd power-platform-vscode-starter
code .
```

Validation checkpoint:

- The folder opens in VS Code.
- You can see `README.md`, `docs/`, `requirements/`, and `scripts/` in Explorer.

---

## Step 0A: Install Claude Code Skills (Run Once Per Machine)

If you are using Claude Code (the VS Code CLI or extension), install the wizard skill so it is available in every Claude session on this machine:

```powershell
pwsh ./scripts/bootstrap/01-install-skills.ps1
```

What this does:

- Copies skill folders from `.claude/skills/` in this repo to `~/.claude/skills/`.
- Makes the skill available in Claude Code sessions on this machine.

Validation checkpoint:

- Script prints `INSTALLED power-platform-vscode-wizard`.
- You only need to run this once per machine. Re-running is safe (it overwrites with the latest version).
- Repo-shared Copilot Chat skill is available at `.github/skills/power-platform-wizard-init` and can be invoked with `/power-platform-wizard-init`.

---

## Step 1: Accept Extension Recommendations

When VS Code opens this folder you will see a notification:

> "Do you want to install the recommended extensions for this repository?"

Click **Install All**. If you missed it, open the Extensions panel (Ctrl+Shift+X), search `@recommended`, and install each one.

Required extensions installed by this repo:

- GitHub Copilot: AI assistant.
- GitHub Copilot Chat: in-editor chat experience for the prompt-based wizard.
- Power Platform Tools: Maker and CLI integration.
- PowerShell: terminal language support.
- JSON: schema validation for payloads.
- Markdown lint: documentation quality checks.
- YAML: process definition files.

Validation checkpoint:

- Open Extensions (`Ctrl+Shift+X`) and confirm the above extensions are installed.

---

## Step 2: Open an Integrated Terminal

- Press **Ctrl+`** (backtick) or go to **Terminal > New Terminal**.
- Confirm the shell is PowerShell 7.

```powershell
$PSVersionTable.PSVersion
```

Major version must be 7 or higher.

Validation checkpoint:

- Terminal shell shows `pwsh`.
- Version major is `7` or higher.

---

## Step 3: Run the Prerequisite Check

```powershell
pwsh ./scripts/bootstrap/00-prereq-check.ps1
```

All tools should show PASS. Install any that show FAIL before continuing.

What this checks:

- VS Code
- PowerShell 7+
- Azure CLI
- Power Platform CLI
- Git

Validation checkpoint:

- Script exits successfully and prints `All prerequisites passed.`

---

## Step 4: Validate PAC CLI Directly

Run these commands to make sure the Power Platform CLI is usable in this terminal session:

```powershell
pac --version
pac help
```

Validation checkpoint:

- Version prints.
- Help text prints without errors.

Common mistake:

- `pac` works in one terminal but not another.
- Fix: close and reopen the VS Code terminal after CLI installation.

---

## Step 4A: Start a Direct Wizard Path

If you already started `/power-platform-wizard-init`, continue in that conversation and do not start another wizard command. For the manual sequence, start one direct path:

- VS Code chat prompt (direct wizard path): run `/power-platform-demo-wizard` in Copilot Chat.
- Terminal wizard: run `pwsh ./scripts/bootstrap/05-start-wizard.ps1`.
- Terminal retrofit wizard: run `pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Retrofit`.

What each option does:

- Chat prompt: asks discovery questions and helps draft planning files interactively.
- Terminal wizard: asks discovery questions in PowerShell and creates starter files under `specs/<scenario-slug>/`.
- Wizard now includes an optional yes/no decision to generate 3 HTML report web resources (agent, supervisor, executive KPI).
- Wizard now includes an optional Business Process Flow block for scenarios with a true staged lifecycle (for example: intake -> review -> decision -> closure).

Validation checkpoint:

- You have discovery answers captured before authentication or build scripts.
- You have starter planning files or a clear set of answers to create them.

---

## Step 4B: Generate the Demo Script

After the first wizard creates your scenario files, generate the demo artifacts for both engineer and presenter:

```powershell
pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug <scenario-slug>
```

What this step does:

- Reads `spec.md` and `answers.md` from `specs/<scenario-slug>/`.
- Suggests a generic business use case based on the scenario that was built.
- Asks for the hero record, audience emphasis, timing, and presenter setup.
- Generates `demo-walkthrough.md` (engineer runbook) and `demo-talk-track.md` (presenter script).
- Writes `demo-script.md` as a compatibility copy of the talk track for existing tooling.

Optional rehearsal step:

```powershell
pwsh ./scripts/bootstrap/07-demo-dry-run.ps1 -ScenarioSlug <scenario-slug>
```

Validation checkpoint:

- `demo-walkthrough.md` and `demo-talk-track.md` exist under `specs/<scenario-slug>/`.
- The story, hero record, and talking points reflect the business problem and success criteria.

---

## Step 5: Sign In and Configure

```powershell
pwsh ./scripts/bootstrap/10-auth-connect.ps1
```

The script will ask you for:

- Dataverse environment URL
- Azure tenant (optional)
- Publisher name and prefix
- Solution unique and display names

It saves your session to `.env.ps1` (local only, never committed).

What this step does:

- Signs in to Azure.
- Creates a PAC auth profile for your Dataverse environment.
- Gets a Dataverse access token.
- Stores local session values for other scripts.

Optional flags:

```powershell
# No browser available (remote machine or headless)
pwsh ./scripts/bootstrap/10-auth-connect.ps1 -UseDeviceCode

# Service principal / CI
pwsh ./scripts/bootstrap/10-auth-connect.ps1 -ServicePrincipal
```

Validation checkpoint:

- `az account show` returns your user and tenant.
- `pac auth list` shows a profile for your environment.
- `.env.ps1` exists in the repo root.
- Default the solution choice to `new` unless you intentionally need to reuse an existing solution.
- If the new solution name already exists, stop and enter a unique name rather than continuing with a reused solution.

---

## Step 6: Choose or Create Your Power Platform Environment

Choose where you will build:

- Personal developer environment: safest for experimentation.
- Team sandbox environment: use for shared demo builds.

If you do not have an environment:

- Create one in Power Platform admin center first, then rerun Step 5.

Validation checkpoint:

- You can open your target environment in [Power Apps Maker](https://make.powerapps.com).
- The URL exactly matches the environment URL used in Step 5.

---

## Step 7: Run Discovery Questions (Wizard Intake)

Before building anything, choose the discovery depth. The default is intentionally concise; all modes still capture or confirm architecture intent and create the same planning files.

Canonical contract sources:

- `docs/wizard-contract-v1.md`
- `wizard.profile.json`

Supported application profiles:

- `standalone-model-driven`
- `dynamics-sales-extension`
- `dynamics-customer-service-extension`
- `dynamics-field-service-extension`
- `generic-dataverse-solution`

### Demo Builder (default)

The `demo-builder` mode is selected when `-Mode` is omitted. Run `pwsh ./scripts/bootstrap/05-start-wizard.ps1`. It asks six business questions plus one consolidated recommendation confirmation. It infers the application profile, OOB/custom/hybrid table strategy, form strategy, primary entry-point table, named landing view, review-app artifacts, navigation, relationships/reports, solution name, and publisher prefix. Review those recommendations together before files are written.

Demo Builder does not ask about disposable environments, destructive cleanup, retention, acceptance source tags, or rerun-proof engineering.

### Advanced Builder (explicit)

Run `pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Mode advanced-builder` when you need direct technical control. The following 11 core questions and architecture/mapping extensions apply in this mode:

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

### Framework Acceptance (explicit only)

Run `pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Mode framework-acceptance` only for framework engineering. It adds authorized-environment confirmation, isolated timestamped naming, acceptance source tags and hero labels, deterministic rerun evidence, retention policy, separately approved cleanup, and an evidence plan. Never infer this mode from an app idea or environment name.

All modes write compatible `answers.md`, `spec.md`, `plan.md`, `tasks.md`, and `report-mappings.md` files for the same build pipeline. New profile-based runs always create or update the review app. The app sitemap puts the entry table first and attaches the requested view without changing an environment-wide default view.

Then complete optional extension blocks based on profile and project needs:

- `table-strategy` (standard/custom strategy)
- `solution-identity` (new/existing solution and publisher prefix)
- `reporting` (explicit no-report decision, or critical-table report mappings with type, placement, fields, decision, owner, and validation)
- `retrofit` (current state + remaining work)
- `business-process-flow` (when enabled, include stage sequence, branch predicates with explicit Yes/No outcomes, human decision checkpoints, and Finish behavior)
- `source-control` (repository preflight, scenario branch, related work, commit checkpoints, discovered validation/CI, pull request handoff, and merge strategy)
- `user-tasks` (persona, task, frequency, entry table/view, expected outcome, owner, and done definition)
- `demo-data` (when enabled: all-created or selected table scope, resolved tables, per-table counts, scenarios/states, hero records, relationship distribution, bounded Task activity generation, method, and privacy constraints; rerun/source-tag/retention/cleanup engineering is Framework Acceptance only)

Validation checkpoint:

- The selected mode's intake is complete and reviewed by the demo/app owner; Demo Builder stays within seven prompts, while Advanced Builder uses the 11 core questions and technical extensions.
- Selected extension blocks are complete.
- For table-strategy, confirm which tables are standard (Contact, Case, Product, etc.) vs. custom — see `docs/standard-dataverse-tables.md` for reference.
- Add an explicit entity mapping block before payload work:
- Standard reused tables (display -> logical)
- Custom tables to create
- Standard fields reused
- Custom fields to add
- Relationships to create
- Do not generate payloads until this mapping block is complete and approved.
- Confirm the entry-point logical name resolves to a reused standard table, planned custom table, or existing retrofit inventory table.
- Confirm the landing-view action is recorded as create/update for a planned custom table or verify-existing for a reused/existing table. Before script 62, the named saved query must resolve in Dataverse.
- For every planned relationship, record cardinality, requiredness, existing/new status, cascade behavior, and the user task or app surface it supports.
- Capture top user tasks with named owners and done definitions before designing forms, views, navigation, or automation.
- If demo data is enabled, show and approve the exact target tables, record count per table, and hero records with their demo purpose. Do not implicitly seed standard reused tables.
- If Task activities are enabled, approve parent tables, latest/all/selected scope, source-record limit (default 10 for latest), ordering field, and tasks per selected record. Do not target every record unless `all` is explicitly approved.
- Confirm `demo-data-plan.json` captures hero records, bounded Task generation, synthetic-data/privacy, and relationship distribution. In Framework Acceptance, also confirm idempotent rerun, source-tagging, retention, and cleanup decisions.
- Confirm `report-mappings.md` exists. If reports are enabled, every critical or high-frequency table must have an approved mapping; if reports are disabled, the artifact must record that explicit decision.
- Demo-data intake is planning-only; no Dataverse rows are created by `05-start-wizard.ps1`.
- Review `requirements/GithubInstructions_General.md` and record how source control will support the app or demo being created.
- Confirm the target repository, remote, current/default branch, existing working-tree changes, recent history, existing tooling, and applicable validation commands.
- Keep intake read-only: do not create a branch, stage files, commit, or push while discovery is in progress.

---

## Step 8: Create Spec Kit Artifacts (Required Gate)

Create these files before implementation:

- `spec.md`: scenario, requirements, acceptance criteria.
- `plan.md`: architecture, environment, security, and release approach.
- `tasks.md`: ordered implementation tasks.

Use the guided wizard in `requirements/how-to-build-dynamics-model-driven-apps-wizard.md`.
If you used the terminal wizard, review the generated files under `specs/<scenario-slug>/` and refine them before proceeding.

Validation checkpoint:

- `spec.md`, `plan.md`, and `tasks.md` are complete and consistent.
- `demo-data-plan.json` exists and is approved when demo data is enabled.
- No build scripts are run before this checkpoint.

---

## Step 9: Move from Requirements to Implementation Tasks

Use this conversion pattern:

- Requirement: "Track customer onboarding status"
- Implementation tasks:
- Create table and status columns.
- Create main form and active view.
- Add automation for status transitions.
- Add role-based visibility rules.

Validation checkpoint:

- Every requirement maps to one or more implementation tasks.
- Each task has an owner and a done definition.

### Source-control lifecycle for this scenario

Before implementation, create or switch to the approved scenario branch from the generated `plan.md`. Preserve unrelated local changes.

Use coherent checkpoints as the app or demo progresses, such as planning, Dataverse schema, forms/views/app assembly, validation, and final unpacked solution source. At each selected checkpoint:

1. Inspect `git status` and `git diff`.
2. Run the applicable validation commands discovered from this repository.
3. Stage explicit intended files rather than using `git add .`.
4. Review `git diff --staged` and confirm no secrets, local configuration, generated junk, or unrelated files are included.
5. Use a typed imperative commit message, for example `feat: add case triage metadata`.
6. Obtain explicit approval before committing.

Commit and push are distinct approvals. Push verification and pull request preparation happen during final handoff.

---

## Step 10: Build in Order

Run each script in sequence. Each one tells you the next step on completion.

```powershell
pwsh ./scripts/bootstrap/15-dry-validate.ps1
pwsh ./scripts/bootstrap/20-build-tables.ps1
pwsh ./scripts/bootstrap/30-build-columns.ps1
pwsh ./scripts/bootstrap/40-build-relationships.ps1
pwsh ./scripts/bootstrap/50-add-to-solution.ps1
pwsh ./scripts/bootstrap/55-build-business-process-flows.ps1 -ScenarioSlug <scenario-slug>
pwsh ./scripts/bootstrap/60-build-forms-views.ps1
pwsh ./scripts/bootstrap/62-build-app-module.ps1 -ScenarioSlug <scenario-slug>
# Optional if report web resources were enabled by profile + planning
pwsh ./scripts/bootstrap/70-build-web-resources.ps1 -ScenarioSlug <scenario-slug>
# Final read-only inventory and export gate
pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -ScenarioSlug <scenario-slug> -InventoryOnly -EnforceExportGate
# End-of-build summary analysis and optional README update/commit prompts
pwsh ./scripts/bootstrap/80-post-build-analysis.ps1 -ScenarioSlug <scenario-slug>
# Build a run matrix from disclosed step events
pwsh ./scripts/bootstrap/81-build-progress-matrix.ps1
# Build an HTML dashboard from telemetry analytics
pwsh ./scripts/bootstrap/82-build-progress-report.ps1
```

All scripts are idempotent and safe to rerun.

Payload rules for Step 10:

- `table-*.json` must include only true custom entities.
- Do not place standard entities (like `contact` or `incident`) in `table-*.json`.
- `columns-*.json` and `relationships-*.json` can reference both standard and custom entities.
- `50-add-to-solution.ps1` derives the expected table set from payload references and fails before adding components if the target solution already contains foreign tables.
- `50-add-to-solution.ps1` also produces a contamination scan artifact that classifies expected, wizard-managed foreign, and manual or legacy solution contents before more components are added.
- Override that guard only when reuse is intentional: `pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -FailIfSolutionHasForeignTables:$false`.
- To inspect or remove foreign tables from an unmanaged solution, run `pwsh ./scripts/bootstrap/57-prune-foreign-tables.ps1`.
- `55-build-business-process-flows.ps1` reads `process-*.json` only when explicitly planned, validates stage fields and relationships, and writes a designer handoff and BPF report. Create the initial process definition in Power Apps with the expected unique name; apply mode validates, activates, adds, and links that existing supported definition.
- BPF completion is not satisfied by Active state alone or solution membership alone; use the BPF runbook completion criteria (validation PASS with thresholds, app linkage, and stage/condition/step evidence).
- The wizard does not POST or PATCH fabricated `clientdata`, `uidata`, or `xaml` workflow definitions.
- If BPF branch logic is ambiguous, resolve it in planning and the designer handoff before authoring the process.
- `60-build-forms-views.ps1` builds Starter Main Form controls from `columns-*.json` for payload-defined custom entities.
- `60-build-forms-views.ps1` applies form and view quality gates and writes population artifacts for both surfaces.
- `62-build-app-module.ps1` creates or updates the scenario app shell, attaches intended components, and validates the resulting model-driven app configuration.
- Starter forms place the table primary name field first, then payload-defined fields in payload order.
- Form labels use payload `DisplayName.LocalizedLabels` (1033 first, then first available), with friendly logical-name fallback.
- Reruns patch existing Starter Main Form XML; non-starter Main forms are preserved.
- If optional reports are enabled, `70-build-web-resources.ps1` runs the reporting module and upserts 3 Dynamics-blue HTML report web resources into the selected solution.
- The final inventory-only pass writes `.wizard-metrics/artifacts/solution/solution-membership-report.{json,md}`. Do not export unless `ExportAllowed` is true.
- `80-post-build-analysis.ps1` provides an end-of-build preview summary and asks for explicit confirmation before updating README markers or running any git commit/push action.
- For preview only, run: `pwsh ./scripts/bootstrap/80-post-build-analysis.ps1 -ScenarioSlug <scenario-slug> -PreviewOnly`
- Optional overrides for generalized workflows: `-SpecPath`, `-PlanPath`, `-TasksPath`, `-PayloadFolder`, and `-ReadmePath`.
- If inputs are missing, the generated summary prints `Not available` sections instead of failing.
- Bootstrap scripts disclose local step-progress telemetry and write events to `.wizard-metrics/events.jsonl`.
- Events include run ID, step code, status, and timestamps only; they do not include user name, machine name, email, or access tokens.
- Set `WIZARD_METRICS_OPTOUT=1` before running a script if you want to disable local telemetry for that session.
- Use `pwsh ./scripts/bootstrap/81-build-progress-matrix.ps1` to summarize completion/drop-off by run.
- Use `pwsh ./scripts/bootstrap/82-build-progress-report.ps1` to generate an HTML dashboard in `.wizard-metrics/build-progress-report.html`.
- Re-run `82-build-progress-report.ps1` after new work to refresh the dashboard from the latest telemetry events.
- Open the generated dashboard at `.wizard-metrics/build-progress-report.html`.

Validation checkpoint after each script:

- Script exits without errors.
- Summary counts are printed.
- For script 60, verify: forms created, forms updated, forms skipped, views created, failures.
- If failed count is greater than zero, stop and fix before proceeding.
- If `50-add-to-solution.ps1` reports foreign tables, use the dry run first and follow [docs/solution-isolation-runbook.md](solution-isolation-runbook.md) before rerunning the build.

---

## Step 11: Verify in the Maker Portal

Open [Power Apps Maker](https://make.powerapps.com), select your environment, and confirm:

- Tables appear under **Dataverse > Tables**.
- Forms and views appear on each table.
- Tables appear inside the target solution.
- Starter Main Form labels display business-friendly names (not raw logical names) where payload labels exist.

Validation checkpoint:

- All required artifacts from `tasks.md` appear in the environment.

---

## Step 12: Export and Unpack Your Solution

Why this step matters:

- Unpacked solution files are the source-controlled representation of your app.

```powershell
pac solution export --name "SOLUTION_NAME" --path "./out/SOLUTION_NAME_unmanaged.zip" --managed false
pac solution unpack --zipfile "./out/SOLUTION_NAME_unmanaged.zip" --folder "./solutions/SOLUTION_NAME" --packagetype Unmanaged
```

Validation checkpoint:

- Export zip exists in `out/`.
- Unpacked files exist under `solutions/SOLUTION_NAME/`.

---

## Step 13: Commit Changes to Git

```powershell
git branch --show-current
git status --short
git diff
git add <explicit-file-or-folder> [...]
git diff --staged
pwsh ./scripts/ci/<applicable-test>.ps1
git commit -m "feat: add <scenario> solution updates"
git push -u origin feature/<scenario-slug>
git rev-parse HEAD
git rev-parse origin/feature/<scenario-slug>
```

Use commands already supported by the repository. The test command above is a placeholder to replace with the validation discovered during preflight; do not invent a command.

Before commit and again before push, obtain explicit approval. After push, the two commit IDs must match before reporting that the change is available remotely. Prepare a pull request with summary, reason, validation, impact, and the related scenario spec.

Validation checkpoint:

- `git status` reports a clean working tree after commit.
- The remote branch commit matches the local commit after push.
- The handoff clearly states whether work is local, committed, pushed, in a pull request, merged, released, or deployed.

Common mistakes:

- Committing environment files such as `.env.ps1`.
- Fix: keep `.gitignore` unchanged and verify with `git status` before commit.

---

## Step 14: Pack and Import to Target Environment

```powershell
pac solution pack --zipfile "./out/SOLUTION_NAME_unmanaged_new.zip" --folder "./solutions/SOLUTION_NAME" --packagetype Unmanaged
pac solution import --path "./out/SOLUTION_NAME_unmanaged_new.zip"
```

Validation checkpoint:

- Import succeeds without blocking errors.
- Target environment shows updated solution version/components.

---

## Step 15: Document the Finished Demo

Record what you built and validated:

- Problem statement and scenario.
- Environment used.
- Tables, forms, views, and flows added or changed.
- Demo data approach.
- Known limitations and next steps.

Also update `docs/build-log.md` for traceability.

Validation checkpoint:

- A teammate can understand the demo scope and rerun your process.

---

## Step 16: (Optional) Submit Feedback to GitHub

Help improve the wizard by reporting bugs or requesting enhancements.

```powershell
pwsh ./scripts/bootstrap/83-submit-feedback.ps1 -ScenarioSlug <scenario-slug>
```

What this does:

- Prompts you to choose feedback type: Bug report or Enhancement request.
- Auto-populates GitHub Issue with build context (scenario, tables, columns, forms, views, etc.).
- Tries the GitHub CLI (`gh`) first with browser preview (user reviews before submitting).
- Falls back to opening a pre-filled GitHub Issue URL if `gh` is not available.
- All submission paths require human review — no silent/automatic issue creation.
- Writes telemetry to `.wizard-metrics/events.jsonl` for tracking.

Examples:

```powershell
# Interactive — asks for scenario and feedback type
pwsh ./scripts/bootstrap/83-submit-feedback.ps1

# Submit a bug for a known scenario
pwsh ./scripts/bootstrap/83-submit-feedback.ps1 -ScenarioSlug contoso-case-tracker -FeedbackType Bug

# Submit an enhancement request
pwsh ./scripts/bootstrap/83-submit-feedback.ps1 -ScenarioSlug contoso-case-tracker -FeedbackType Enhancement
```

Validation checkpoint:

- Feedback form opens in browser or GitHub CLI.
- You can review and edit the pre-filled context before submitting.
- Issue is created in the GitHub repo after your review.

---

## Common Issues

| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| 401 on every API call | Token URL mismatch | Re-run `10-auth-connect.ps1` and ensure URL has no trailing slash. |
| Token works then stops mid-run | Token expired (60-90 min) | Re-run `10-auth-connect.ps1` to refresh. |
| PAC errors after `az login` | Two separate auth mechanisms | Run both `az login` and `pac auth create`. |
| Login opens wrong tenant | Multiple tenants on account | Pass `-tenantId` or re-run auth with specific tenant. |
| `pac` not found | CLI not installed | Run `winget install Microsoft.PowerPlatformCLI`. |
| Solution not found | Wrong or missing solution unique name | Create solution in Maker portal, then rerun `50-add-to-solution.ps1`. |
| `code` command not found | VS Code shell command not in PATH | Install the `code` command from VS Code and restart terminal. |
| `git push` rejected | Branch behind remote or no upstream | Run `git pull --ff-only`, then push with `-u origin <branch>`. |
| Unpack fails | Wrong zip path or invalid export | Re-run export, verify zip exists, rerun unpack. |
| Import fails due to dependencies | Missing components in target env | Import into correct base environment or include required dependencies. |

---

## Related Documents

- Visual walkthrough page: `docs/wizard-walkthrough.html`
- Root overview and quick start: `README.md`
- Full implementation playbook: `requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md`
- Guided wizard and discovery prompts: `requirements/how-to-build-dynamics-model-driven-apps-wizard.md`
- Build execution log template: `docs/build-log.md`
