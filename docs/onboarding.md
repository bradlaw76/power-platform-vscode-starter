# Onboarding Guide

> **This is the authoritative bootstrap sequence for this repository.** All agents, chat prompts, and documentation defer to the step order defined here. If another document shows a different order, this file takes precedence.

Use this document when setting up this repo for the first time in VS Code.

This is the beginner-safe, step-by-step path for building Dynamics 365 and Power Platform demos/apps from VS Code.

Important process rule:

- Complete Spec Kit planning (`spec.md`, `plan.md`, `tasks.md`) before building artifacts.

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

## Step 4A: Start the Wizard in Chat or Terminal

You can start the repository wizard in either of these ways:

- VS Code chat prompt: run `/power-platform-demo-wizard` in Copilot Chat.
- Terminal wizard: run `pwsh ./scripts/bootstrap/05-start-wizard.ps1`.

What each option does:

- Chat prompt: asks discovery questions and helps draft planning files interactively.
- Terminal wizard: asks discovery questions in PowerShell and creates starter files under `specs/<scenario-slug>/`.
- Wizard now includes an optional yes/no decision to generate 3 HTML report web resources (agent, supervisor, executive KPI).

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

Before building anything, answer the **11 required** questions in writing. This becomes your requirement source.

Canonical contract sources:

- `docs/wizard-contract-v1.md`
- `wizard.profile.json`

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

Then complete optional extension blocks based on profile and project needs:

- `table-strategy` (standard/custom strategy)
- `solution-identity` (new/existing solution and publisher prefix)
- `reporting` (optional web resources)
- `retrofit` (current state + remaining work)

Validation checkpoint:

- All 11 required questions are answered and reviewed by the demo/app owner.
- Selected extension blocks are complete.
- For table-strategy, confirm which tables are standard (Contact, Case, Product, etc.) vs. custom — see `docs/standard-dataverse-tables.md` for reference.
- Add an explicit entity mapping block before payload work:
- Standard reused tables (display -> logical)
- Custom tables to create
- Standard fields reused
- Custom fields to add
- Relationships to create
- Do not generate payloads until this mapping block is complete and approved.

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

---

## Step 10: Build in Order

Run each script in sequence. Each one tells you the next step on completion.

```powershell
pwsh ./scripts/bootstrap/20-build-tables.ps1
pwsh ./scripts/bootstrap/30-build-columns.ps1
pwsh ./scripts/bootstrap/40-build-relationships.ps1
pwsh ./scripts/bootstrap/50-add-to-solution.ps1
pwsh ./scripts/bootstrap/60-build-forms-views.ps1
# Optional if report web resources were enabled by profile + planning
pwsh ./scripts/bootstrap/70-build-web-resources.ps1 -ScenarioSlug <scenario-slug>
# End-of-build summary analysis and optional README update/commit prompts
pwsh ./scripts/bootstrap/80-post-build-analysis.ps1 -ScenarioSlug <scenario-slug>
```

All scripts are idempotent and safe to rerun.

Payload rules for Step 10:

- `table-*.json` must include only true custom entities.
- Do not place standard entities (like `contact` or `incident`) in `table-*.json`.
- `columns-*.json` and `relationships-*.json` can reference both standard and custom entities.
- `60-build-forms-views.ps1` builds Starter Main Form controls from `columns-*.json` for payload-defined custom entities.
- Starter forms place the table primary name field first, then payload-defined fields in payload order.
- Form labels use payload `DisplayName.LocalizedLabels` (1033 first, then first available), with friendly logical-name fallback.
- Reruns patch existing Starter Main Form XML; non-starter Main forms are preserved.
- If optional reports are enabled, `70-build-web-resources.ps1` runs the reporting module and upserts 3 Dynamics-blue HTML report web resources into the selected solution.
- `80-post-build-analysis.ps1` provides an end-of-build preview summary and asks for explicit confirmation before updating README markers or running any git commit/push action.
- For preview only, run: `pwsh ./scripts/bootstrap/80-post-build-analysis.ps1 -ScenarioSlug <scenario-slug> -PreviewOnly`

Validation checkpoint after each script:

- Script exits without errors.
- Summary counts are printed.
- For script 60, verify: forms created, forms updated, forms skipped, views created, failures.
- If failed count is greater than zero, stop and fix before proceeding.

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
git checkout -b feature/<short-description>
git status
git add .
git commit -m "Add feature solution updates"
git push -u origin feature/<short-description>
```

Validation checkpoint:

- `git status` reports a clean working tree after commit.

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

- Root overview and quick start: `README.md`
- Full implementation playbook: `requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md`
- Guided wizard and discovery prompts: `requirements/how-to-build-dynamics-model-driven-apps-wizard.md`
- Build execution log template: `docs/build-log.md`
