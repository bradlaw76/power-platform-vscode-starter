# START HERE

Welcome! This is the fastest path to get going with `power-platform-vscode-starter`.

> **Never used VS Code, Git, or GitHub before?** That's fine — every step below explains what to click or type, and nothing here requires prior experience. If a term is unfamiliar (like "terminal" or "clone"), it's explained the first time it's used.

> The full, authoritative bootstrap sequence lives in [docs/onboarding.md](docs/onboarding.md). This file is a quick-start summary — if anything here ever conflicts with `docs/onboarding.md`, that file wins.

## 0. Before you begin: install VS Code, Git, and Copilot Chat

You need VS Code, Git, and GitHub Copilot Chat before Step 1 will work.
If you're not sure whether you already have VS Code or Git, open a terminal
(Windows: search "PowerShell" in the Start menu and open it) and type each
command below one at a time.

1. **VS Code** — the editor you'll do everything in.
   - Check: `code --version`
   - If you see an error instead of a version number, download and install it from [code.visualstudio.com](https://code.visualstudio.com), then close and reopen any terminal windows.
2. **Git** — the tool that downloads ("clones") repositories and tracks
   changes. Both Step 1 paths need Git installed.
   - Check: `git --version`
   - If you see an error instead of a version number, download and install it from [git-scm.com/downloads](https://git-scm.com/downloads) (accept the default options), then close and reopen any terminal windows.

Once both commands print a version number, continue to Step 1.

> **If VS Code was already open when you installed Git**, closing and reopening a terminal isn't enough — VS Code's own Git features (like "Clone Git Repository...") only detect Git when VS Code itself starts, not while it's already running. Fully close **every** VS Code window, then open VS Code again, before continuing to Step 1. If you're not sure whether you had VS Code open during install, close it and reopen it anyway — it only takes a few seconds.

3. **GitHub Copilot Chat** — Copilot will run the clone command in Step 1
   after showing you what it plans to do.
   - In VS Code, open **Extensions** with `Ctrl+Shift+X`, search for
     `GitHub Copilot`, and install both **GitHub Copilot** and
     **GitHub Copilot Chat**.
   - Sign in to GitHub when prompted. A browser tab opens for the sign-in.
   - Open the Copilot Chat panel with `Ctrl+Alt+I`. If it opens, this step is
     complete.

## 1. Create an authoring workspace

Choose **one** path below:

- **Path A — Create the authoring workspace folder first, then let Copilot
  clone into it.** This is the guided option: you choose the folder name and
  open the empty folder before Copilot runs the clone command.
- **Path B — Clone directly from a terminal.** This is the faster option if
  you are comfortable pasting commands: Git creates the named workspace folder
  for you.

Do not do both paths for the same build. Both produce the same result: one
authoring workspace containing the full wizard files directly, with no nested
clone.

First, decide two things (write them down or just keep them in mind):

1. **Where** you want to keep your authoring workspaces on your computer — for
   example a `Power Platform Projects` folder inside your Documents, like
   `C:\Users\<you>\Documents\Power Platform Projects`. It doesn't need to
   exist yet.
2. **What to name this authoring workspace** — a short name with no spaces,
   for example `my-first-app-authoring` or `contoso-case-tracker-authoring`.
   This becomes the folder name for the full local wizard copy.

### Path A — Create the authoring workspace folder first, then ask Copilot to clone

1. In VS Code, choose **File > Open Folder...**.
2. In the Windows folder picker, browse to your authoring-workspaces location.
   Click **New folder**, give it your chosen authoring workspace name, then
   open that new folder and click **Select Folder**.
3. If VS Code shows **"Do you trust the authors of the files in this
   folder?"**, click **Trust Folder & Continue**. You created this empty
   folder yourself.
4. Open Copilot Chat (`Ctrl+Alt+I`) and paste this request:

   ```text
   Clone https://github.com/bradlaw76/power-platform-vscode-starter.git
   into the current empty authoring workspace. First verify that the folder
   is empty and is not already a Git repository. Do not create a nested
   folder. Show me the exact command before running it.
   ```

5. Review Copilot's command. It should use `git clone` with `.` as the final
   destination, which means "this current empty folder." Approve the command
   only if it does not create another folder inside your authoring workspace.
6. When it finishes, the Explorer should refresh to show `README.md`, `docs`,
   and `scripts` directly inside your authoring workspace. If it does not
   refresh, choose **Developer: Reload Window** from the Command Palette
   (`Ctrl+Shift+P`).

> **Checkpoint:** In the Explorer on the left, your authoring workspace name
> (for example `my-first-app-authoring`) should appear as the top-level folder.
> Expand it to confirm that the full copied wizard folders and files—such as
> `.github`, `docs`, `payloads`, `requirements`, `scripts`, `README.md`, and
> `START HERE.md`—are directly inside it, not inside another folder.

### Path B — Clone directly from a terminal

```powershell
mkdir "C:\path\to\Power Platform Projects" -Force
cd "C:\path\to\Power Platform Projects"
git clone https://github.com/bradlaw76/power-platform-vscode-starter.git ".\contoso-case-tracker-authoring"
code --new-window ".\contoso-case-tracker-authoring"
```

Replace both placeholders with your authoring-workspaces location and
authoring workspace name. This creates the folder and clones the full wizard
into it in one step; do not create or open that folder first.

> **Checkpoint:** In the Explorer on the left, your authoring workspace folder
> (not its parent folder) is the top-level folder. Expand it to confirm that
> the full copied wizard folders and files—such as `.github`, `docs`,
> `payloads`, `requirements`, `scripts`, `README.md`, and `START HERE.md`—are
> directly inside it, not one level deeper.

## 2. Know what this clone is—and is not

The folder you just created is an **authoring workspace**: a local copy of the
full reusable wizard. It is where you currently run the guided planning and
build process.

It is **not** yet a clean, finished project repository. If you push this clone
to GitHub, it includes the wizard's generic scripts, skills, prompts, and
template documentation as well as any project-specific files you add.

The intended end state for every build is a separate, clean target project
repository that persists only its project-specific artifacts, such as:

- approved requirements and planning files;
- scenario payloads and build definitions;
- project documentation and build evidence; and
- exported and unpacked solution source.

The target project repository should not retain generic wizard scripts,
generic skills/prompts, template-only documentation, or local wizard telemetry.

> **Current limitation:** the starter does not yet automate writing
> project-specific artifacts directly to a separate target project repository.
> Until that capability is added, use this authoring workspace for the guided
> build process. Do not treat this full clone as the clean project repository
> you intend to publish.

Example current local layout (your folder names will differ):

```text
Power Platform Projects\              # your own parent folder — any name/location
└── contoso-case-tracker-authoring\  # full local wizard copy used while building
```

When the separate target-project capability is available, the durable layout
will become:

```text
Power Platform Projects\
├── power-platform-vscode-starter\   # reusable local wizard/tooling
└── contoso-case-tracker\            # clean project repository to publish
```

## 3. Install the remaining recommended extensions

When VS Code opens the cloned repository, it may prompt you to install
recommended extensions. Click **Install All**. If you miss the prompt, open
Extensions (`Ctrl+Shift+X`), search `@recommended`, and install everything
listed.

You already installed GitHub Copilot and GitHub Copilot Chat in Step 0, so VS
Code will skip them if they appear in the recommendations. Power Platform Tools
and PowerShell let VS Code run the build scripts Copilot will call on your
behalf. The other recommendations (JSON, Markdown lint, YAML) make the
generated files easier to read and edit. See [README.md](README.md) for the
full list of what this starter includes.

**New to Copilot?** You signed in and opened Copilot Chat in Step 0. Use that
same panel for the commands in the next steps.

## 4. Choose the app type before continuing

Do not assume that the app is model-driven. First identify what you are
building, then use the matching entry point:

| If you are building... | Next step |
| --- | --- |
| A model-driven Power App or Dynamics 365 extension (new or retrofit) | `/power-platform-wizard-init` |
| Reports (charts, dashboards, FetchXML) for a model-driven app that already exists | `/dataverse-report-wizard` |
| A Canvas app | Stop here and use the Canvas App workflow in Power Apps Studio or the Canvas App tooling; do not use the model-driven wizard. |
| Something else | Describe the app type and desired outcome in Copilot Chat before selecting a workflow. |

This matters because each app type uses a different wizard, different
questions, and different scripts — picking the wrong one wastes time or
builds the wrong thing. See [README.md](README.md) for the full list of
supported workloads if you're not sure which row fits.

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

1. **Confirm it's working in the repository you intended** — so it doesn't
   accidentally read or write files in the wrong project.
2. **Inspect the repo without modifying tracked files** — a read-only look
   to understand what's already here before touching anything.
3. **Run the non-destructive prerequisite check** (`00-prereq-check.ps1`) for
   VS Code, PowerShell 7, Azure CLI, PAC CLI, and Git — catching missing
   tools now, rather than mid-build later.
4. **Explain and help resolve anything missing** — so you're not left
   guessing what to install.
5. **Confirm the app type and workload** — restating what you chose in Step 4
   before it asks any app-specific questions.
6. **For a model-driven workflow, ask whether this is a new build or a
   retrofit** of existing work, then whether to continue in chat or the
   terminal — so the questions that follow match your actual situation.

This step does **not** sign in to Power Platform, create/change Dataverse
resources, run build scripts, commit, or push — it only inspects your machine
and this repository. It writes local progress telemetry under
`.wizard-metrics/` (opt out with `WIZARD_METRICS_OPTOUT=1`). See
[README.md](README.md) for the complete list of what each script in this
repository does.

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

**Why this gate exists:** these files capture what you're building, why, and
in what order, so build scripts create the right tables, forms, and
relationships instead of guessing. **Do not run build scripts before these
planning files are complete.** This is a hard gate — see
[SPEC.md](SPEC.md) and [docs/onboarding.md](docs/onboarding.md) for details,
or [README.md](README.md) for how planning fits into the overall workflow.

## Stuck installing Git, VS Code, or Copilot Chat?

See Step 0 above for installing Git and VS Code, and Step 3 for Copilot Chat.
For a more detailed, full step-by-step machine setup sequence, see
[docs/onboarding.md](docs/onboarding.md). If you'd rather not install Git at
all, you can download the repo as a ZIP from GitHub (**Code > Download ZIP**)
and open the extracted folder in VS Code — note this won't let you pull
future updates or use source control until you initialize Git yourself.

## Where to go next

- [README.md](README.md) — full overview, supported workloads, and script reference.
- [docs/onboarding.md](docs/onboarding.md) — the authoritative, detailed bootstrap sequence.
- [docs/build-log.md](docs/build-log.md) — where build run outcomes get recorded.
- [requirements/](requirements) — detailed how-to guides for building model-driven apps with this wizard.
- [docs/live-report-web-resources-runbook.md](docs/live-report-web-resources-runbook.md) — after `/dataverse-report-wizard`, use this when you need live, zero-data, or design-summary report modes.
