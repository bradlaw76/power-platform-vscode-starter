# START HERE

Welcome! This is the fastest path to get going with `power-platform-vscode-starter`.

> **Never used VS Code, Git, or GitHub before?** That's fine — every step below explains what to click or type, and nothing here requires prior experience. If a term is unfamiliar (like "terminal" or "clone"), it's explained the first time it's used.

> The full, authoritative bootstrap sequence lives in [docs/onboarding.md](docs/onboarding.md). This file is a quick-start summary — if anything here ever conflicts with `docs/onboarding.md`, that file wins.

## 1. Get the repository onto your computer

**Copilot can't help with this very first step.** Copilot Chat only becomes available once this repository is open in VS Code with its extensions installed — so this one step is manual, click-by-click. Every step after this one, Copilot guides you.

First, decide two things (write them down or just keep them in mind):

1. **Where** you want to keep your projects on your computer — for example a `Projects` folder inside your Documents, like `C:\Users\<you>\Documents\Projects`. It doesn't need to exist yet.
2. **What to name this project** — a short name with no spaces, for example `my-first-app` or `contoso-case-tracker`. This becomes the folder name for your project.

Pick **one** of the two options below.

### Option A — Point and click (recommended if you're new to VS Code)

1. Open VS Code. If you don't have it yet, download it from [code.visualstudio.com](https://code.visualstudio.com) and install it first.
2. You'll land on VS Code's **Welcome** tab, with a **Start** list on the left.
3. Click **Clone Git Repository...**
4. Paste this URL and press Enter:

   ```text
   https://github.com/bradlaw76/power-platform-vscode-starter.git
   ```

5. VS Code opens a folder picker — the same kind of "Save As" window you've used before in other programs. Browse to (or create) the projects folder you decided on above, then use the picker's **New Folder** button to create a folder named after your project (for example `my-first-app`), and select that new folder as the destination.
6. VS Code will ask if you want to open the cloned repository — click **Open**.

> **Checkpoint:** The title bar and the left-hand Explorer panel (click the top icon that looks like two overlapping pages, or press `Ctrl+Shift+E`) should show your project name (for example `my-first-app`) as the top-level folder, containing `README.md`, `docs`, and `scripts` directly — not nested one level deeper inside another folder of the same name.

### Option B — Use a terminal (if you're comfortable typing commands)

A **terminal** is a text window for typing commands instead of clicking. In VS Code: menu bar → **Terminal > New Terminal**.

Before you clone, confirm you are **not** already inside another Git repository (this is how nested-repo mix-ups happen):

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

`C:\path\to\Power Platform Projects` and `contoso-case-tracker` are
placeholders — replace both with your own answers to the two questions above.

> **Checkpoint:** VS Code should open with your project folder (not its
> parent folder) as the workspace root. Run `git remote -v` in the VS Code
> terminal — it should point at `power-platform-vscode-starter` and the
> folder should contain `README.md`, `docs/`, and `scripts/` directly (not
> one level deeper).
>
> If `code` isn't recognized, VS Code's command-line tools aren't on PATH yet.
> Open VS Code manually, run **View > Command Palette > Shell Command: Install
> 'code' command in PATH**, restart the terminal, and re-run the command above.

Once this repository is open and you complete step 3 below (installing
extensions, including Copilot Chat), you can ask Copilot for help with
**future** projects the same way: say `Start the Power Platform wizard in
this repository.` in Copilot Chat, and it will ask you the same two
questions (where and what to name it) before giving you commands.

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

**New to Copilot?** After installing, sign in when prompted (a browser tab opens for GitHub login). Once signed in, open the Copilot Chat panel using the icon in the top-right of the VS Code window (it looks like a chat bubble), or press `Ctrl+Alt+I`. This is where you'll type the commands in the next steps.

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
