# Power Platform VS Code Starter

A generic, repo-agnostic starter kit for building Power Platform model-driven apps from VS Code using the Power Platform CLI and Dataverse Web API.
Not tied to any specific project — clone or copy this repo into any new environment to get a repeatable build baseline.

## Who this is for

- First-time Dynamics builders who have never used VS Code for this purpose.
- Teams who want a repeatable, scripted alternative to clicking through the Maker portal.
- Repos that need a consistent onboarding contract so any new person can get started in under an hour.

## Contents

```
dynamics-vscode-starter/
  .vscode/
    extensions.json           — VS Code extension recommendations (installs on first open)
  .gitignore                  — Protects .env.ps1 (tokens/secrets) from accidental commits
  docs/
    onboarding.md             — Step-by-step setup guide for new builders
    build-log.md              — Log template for recording each build run
  requirements/
    how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md  — Full playbook
    how-to-build-dynamics-model-driven-apps-wizard.md                  — Guided wizard variant
  scripts/
    bootstrap/
      00-prereq-check.ps1     — Verify tools are installed (no changes made)
      10-auth-connect.ps1     — Interactive sign-in, token acquisition, config save
      20-build-tables.ps1     — Create tables from payloads/table-*.json
      30-build-columns.ps1    — Add columns from payloads/columns-*.json
      40-build-relationships.ps1 — Create lookups from payloads/relationships-*.json
      50-add-to-solution.ps1  — Add tables to target solution
      60-build-forms-views.ps1 — Create starter forms and views, publish all
  payloads/                   — Place your table-*.json, columns-*.json, relationships-*.json here
```

## Quick start

```powershell
# 1. Check tools
pwsh ./scripts/bootstrap/00-prereq-check.ps1

# 2. Sign in (prompts for all values — no hardcoded credentials)
pwsh ./scripts/bootstrap/10-auth-connect.ps1

# 3. Build in order
pwsh ./scripts/bootstrap/20-build-tables.ps1
pwsh ./scripts/bootstrap/30-build-columns.ps1
pwsh ./scripts/bootstrap/40-build-relationships.ps1
pwsh ./scripts/bootstrap/50-add-to-solution.ps1
pwsh ./scripts/bootstrap/60-build-forms-views.ps1
```

See [docs/onboarding.md](docs/onboarding.md) for the full walkthrough including common issues.

## How to use in a new repo

1. Clone or copy this repo: `git clone https://github.com/bradlaw76/power-platform-vscode-starter`
2. Add your `table-*.json`, `columns-*.json`, and `relationships-*.json` files to `payloads/`.
3. Open the folder in VS Code and accept extension recommendations.
4. Run `00-prereq-check.ps1` then `10-auth-connect.ps1` to set up your session.
5. Run scripts 20–60 in order.
