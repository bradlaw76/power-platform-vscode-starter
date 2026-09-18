# START HERE

Welcome! This is the fastest path to get going with `power-platform-vscode-starter`.

> The full, authoritative bootstrap sequence lives in [docs/onboarding.md](docs/onboarding.md). This file is a quick-start summary — if anything here ever conflicts with `docs/onboarding.md`, that file wins.

## 0. Starting from the VS Code Welcome page

If you just opened VS Code and see the **Welcome** tab (no folder open yet),
you have two options:

- **Use a terminal (recommended — matches the commands below):** go to
  **Terminal > New Terminal** in the menu bar. A terminal opens at some
  default location; `cd` to wherever you want your projects to live, then
  continue with step 1 below.
- **Use the Welcome page directly:** click **Clone Git Repository...** under
  **Start**, paste
  `https://github.com/bradlaw76/power-platform-vscode-starter.git`, and pick
  a **new, empty folder** for your project when prompted (do not pick a
  folder that already has another clone in it). VS Code will open it
  automatically — skip to step 2.

Ignore the **Recent** list for a new project; only reopen an entry there if
you are returning to a project you already created.

## 1. Create a separate project folder from the starter

Two ways to do this — pick whichever fits how you like to work:

- **Ask Copilot to walk you through it (recommended for new users):** open
  Copilot Chat and say `Start the Power Platform wizard in this repository.`
  or type `/power-platform-wizard-init` (if the repo is already open). Before
  giving you any commands, Copilot will ask **where you want to keep your
  projects** (a parent folder path) and **what to name this project**, then
  give you exact commands built from your answers.
- **Do it yourself in a terminal:** decide those same two things yourself —
  a parent folder (for example `C:\Users\<you>\Projects`, `D:\Repos`, or
  `~/dev`) and a project name (for example `contoso-case-tracker`) — then
  adapt the commands below. There is no required directory structure; the
  only rule is that the project folder is not nested inside another clone
  of this repo (see step 2).

`C:\path\to\Power Platform Projects` and `contoso-case-tracker` below are
placeholders — replace both with your own answers to the two questions above.

Before you clone, confirm you are **not** already inside another Git repository
(this is how nested-repo mix-ups happen):

```powershell
cd "C:\path\to\Power Platform Projects"
git rev-parse --is-inside-work-tree 2>$null
```

If that prints `true`, you are inside an existing repo — `cd ..` up to a plain
folder (like `Power Platform Projects` above) before continuing.

Now clone into a new, dedicated project folder:

```powershell
mkdir "C:\path\to\Power Platform Projects" -Force
cd "C:\path\to\Power Platform Projects"
git clone https://github.com/bradlaw76/power-platform-vscode-starter.git ".\contoso-case-tracker"
code --new-window ".\contoso-case-tracker"
```

Replace `C:\path\to\Power Platform Projects` with your own parent folder and
`contoso-case-tracker` with your project name.

> **Checkpoint:** VS Code should open with your project folder (not its
> parent folder) as the workspace root. Run `git remote -v` in the VS Code
> terminal — it should point at `power-platform-vscode-starter` and the
> folder should contain `README.md`, `docs/`, and `scripts/` directly (not
> one level deeper).
>
> If `code` isn't recognized, VS Code's command-line tools aren't on PATH yet.
> Open VS Code manually, run **View > Command Palette > Shell Command: Install
> 'code' command in PATH**, restart the terminal, and re-run the command above.

## 2. Keep the starter separate from your project

Each clone from step 1 is its own project repository. Do not create a person's
folder, customer documents, or another scenario folder inside that clone — and
never clone a project into a folder that already contains another clone.

Example layout (your parent folder and project name will differ):

```text
Power Platform Projects\              # your own parent folder — any name/location
├── power-platform-vscode-starter\   # optional: clean copy of the starter for reference
└── contoso-case-tracker\            # your project and its documents (from step 1)
```

The important part is not the exact names or drive — it's that each project
is its own sibling folder, not nested inside another clone. Keep source
documents, requirements, payloads, planning artifacts, and generated solution
files inside the project folder only. Do not put personal, customer, or
scenario-specific documents in the reusable starter repository unless they
are intentionally reusable starter assets — the starter should contain only
reusable wizard code and documentation.

## 3. Accept the recommended extensions

When prompted, click **Install All**. If you miss the prompt, open Extensions (`Ctrl+Shift+X`), search `@recommended`, and install everything listed (GitHub Copilot, GitHub Copilot Chat, Power Platform Tools, PowerShell, JSON, Markdown lint, YAML).

## 4. Choose the app type before continuing

Do not assume that the app is model-driven. First identify what you are
building, then use the matching entry point:

| If you are building... | Next step |
| --- | --- |
| A model-driven Power App or Dynamics 365 extension (new or retrofit) | `/power-platform-wizard-init` |
| Reports (charts, dashboards, FetchXML) for a model-driven app that already exists | `/dataverse-report-wizard` |
| A Canvas app | Stop here and use the Canvas App workflow in Power Apps Studio or the Canvas App tooling; do not use the model-driven wizard. |
| Something else | Describe the app type and desired outcome in Copilot Chat before selecting a workflow. |

Open Copilot Chat and type the slash command for your row above. If the slash
command doesn't show up, type this instead:

```text
Start the Power Platform wizard in this repository.
```

The wizard should ask you to confirm this app type before it asks model-driven
questions such as tables, forms, views, solutions, or Dynamics 365 modules.
If it starts with those questions without confirming the app type, stop and
reply:

```text
Before we continue, ask me what type of Power Platform app I am building.
Do not assume that I want a model-driven app.
```

## 5. Let Copilot guide setup

Before asking anything about your app, Copilot will:

1. Confirm it's working in the repository you intended.
2. Inspect the repo without modifying tracked files.
3. Run the non-destructive prerequisite check (`00-prereq-check.ps1`) for VS Code, PowerShell 7, Azure CLI, PAC CLI, and Git.
4. Explain and help resolve anything missing.
5. Confirm the app type and workload.
6. For a model-driven workflow, ask whether this is a **new build** or a **retrofit** of existing work, then whether to continue in **chat** or the **terminal**.

This step does **not** sign in to Power Platform, create/change Dataverse resources, run build scripts, commit, or push. It only writes local progress telemetry under `.wizard-metrics/` (opt out with `WIZARD_METRICS_OPTOUT=1`).

When the wizard asks where the build should run, provide the **Environment
URL**. For example:

```text
https://your-org.crm.dynamics.com
```

Use the URL for the Dataverse/Power Platform environment, not a friendly
environment name. You can confirm the exact URL in the Power Platform admin
center or Maker portal.

## 6. Complete planning before you build

Once setup passes, the wizard moves into discovery questions and prepares the required Spec Kit planning files:

- `spec.md`
- `plan.md`
- `tasks.md`

**Do not run build scripts before these planning files are complete.** This is a hard gate — see [SPEC.md](SPEC.md) and [docs/onboarding.md](docs/onboarding.md) for details.

## Don't have Git, VS Code, or Copilot Chat yet?

Follow the manual, first-time machine setup and full step-by-step sequence in [docs/onboarding.md](docs/onboarding.md). You can also download the repo as a ZIP from GitHub (**Code > Download ZIP**) and open the extracted folder in VS Code.

## Where to go next

- [README.md](README.md) — full overview, supported workloads, and script reference.
- [docs/onboarding.md](docs/onboarding.md) — the authoritative, detailed bootstrap sequence.
- [docs/build-log.md](docs/build-log.md) — where build run outcomes get recorded.
- [requirements/](requirements) — detailed how-to guides for building model-driven apps with this wizard.
- [docs/live-report-web-resources-runbook.md](docs/live-report-web-resources-runbook.md) — after `/dataverse-report-wizard`, use this when you need live, zero-data, or design-summary report modes.
