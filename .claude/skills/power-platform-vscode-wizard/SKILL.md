---
name: power-platform-vscode-wizard
description: Use when building Power Platform model-driven apps, Dynamics 365 demos, or Dataverse solutions from VS Code using PAC CLI and the power-platform-vscode-starter repo bootstrap scripts
---

# Power Platform VS Code Wizard

## Overview

A wizard-guided workflow for building Power Platform model-driven apps from VS Code using PAC CLI and Dataverse Web API scripts. **Spec Kit planning is a mandatory gate — never run build scripts without completed `spec.md`, `plan.md`, and `tasks.md`.**

## Mandatory Rule

> Do not build tables, forms, views, flows, or solution artifacts until Spec Kit is complete.

Spec Kit artifacts required before scripts 20–60:
- `spec.md` — what to build and why
- `plan.md` — how it will be built
- `tasks.md` — ordered implementation work

## Bootstrap Sequence Authority

> **Single source of truth: `docs/onboarding.md`**

Always follow the step order in `docs/onboarding.md`. If the user mentions README.md or another file with a different order, clarify: *"The authoritative bootstrap sequence is in docs/onboarding.md."*

## Mid-Project Retrofit

If a user already has a partial implementation ("I already built some tables", "I started this weeks ago"), do **not** restart from scratch.

Reverse-engineer the discovery answers:
1. Ask what tables or entities already exist.
2. Ask what forms, views, or flows are already built.
3. Ask for the current solution name and publisher prefix.
4. Generate `spec.md` to reflect the **current state**.
5. Use `plan.md` to capture only the **remaining work**.
6. Run `06-demo-script-wizard.ps1` once the spec is ready to generate the demo story.

This keeps Spec Kit relevant for brownfield projects, not just greenfield builds.

## Discovery Questions (Run First)

Ask and capture all base discovery questions, then complete explicit entity mapping before any build work:

1. What type of demo or app are you building?
2. Is it for Dynamics 365 Sales, Customer Service, Field Service, Contact Center, Power Apps, Power Pages, Copilot Studio, or Dataverse?
3. Who is the target audience?
4. What business problem does it solve?
5. Who are the users?
6. What data tables or entities are needed?
6b. Use standard Dataverse tables (Contact, Account, Case, etc.) or create custom tables? (standard/custom/both)
7. What screens, forms, views, pages, flows, or copilots are needed?
8. What does a successful demo look like?
9. What environment should it be built in?
10. Does it need demo data?
11. Should the output be a managed or unmanaged solution?
12. Should we create a new solution or use an existing one? If existing, what is the exact unique name?
13. Should we create a new publisher prefix or use an existing one? If existing, what is the prefix (e.g. vafe, contoso)?
14. Standard reused tables (display/logical names)
15. Custom tables to create
16. Standard fields to reuse
17. Custom fields to add
18. Relationships to create

## Ordered Build Flow

Follow this exact sequence — do not skip validation checkpoints:

| Step | Action | Validation |
|------|--------|------------|
| 0 | Clone repo, open in VS Code, install extensions | Extensions installed via `@recommended` |
| 1 | Start wizard: `pwsh ./scripts/bootstrap/05-start-wizard.ps1` | Discovery answers captured |
| 2 | **GATE: Complete Spec Kit** (`spec.md`, `plan.md`, `tasks.md`) | All three files exist and are consistent |
| 3 | Generate presenter script: `pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug <scenario-slug>` | `demo-script.md` exists and matches the scenario story |
| 4 | Optional rehearsal: `pwsh ./scripts/bootstrap/07-demo-dry-run.ps1 -ScenarioSlug <scenario-slug>` | `demo-dry-run.md` captures rehearsal notes |
| 5 | Check prerequisites: `pwsh ./scripts/bootstrap/00-prereq-check.ps1` | All tools show PASS |
| 6 | Authenticate: `pwsh ./scripts/bootstrap/10-auth-connect.ps1` | `az account show` + `pac auth list` both return profile |
| 6.5 | **Validate solution + prefix** (`10-auth-connect.ps1` does this automatically) | Existing solution confirmed via `solutions?$filter=uniquename eq '<name>'`; existing prefix confirmed via `publishers?$filter=customizationprefix eq '<prefix>'`. Stop and fix if either is missing before running scripts 20–60. |
| 7 | Add payloads (`payloads/table-*.json`, `columns-*.json`, `relationships-*.json`) | Files present |
| 8 | Build in order (scripts 20–60) | Each script exits with zero failed count |
| 9 | Verify in Maker portal | Tables, forms, views visible in target solution |
| 10 | Export + unpack → commit → pack → import | See Solution Lifecycle below |
| 11 | Document in `docs/build-log.md` | Teammate can rerun the process |

## Build Scripts (Run in Order)

```powershell
pwsh ./scripts/bootstrap/20-build-tables.ps1
pwsh ./scripts/bootstrap/30-build-columns.ps1
pwsh ./scripts/bootstrap/40-build-relationships.ps1
pwsh ./scripts/bootstrap/50-add-to-solution.ps1
pwsh ./scripts/bootstrap/60-build-forms-views.ps1
```

All scripts are idempotent — safe to rerun after fixing failures.

Form-building instruction for agents:

"Build starter forms from columns payloads, place the primary field plus payload fields, use display labels from payload metadata, patch existing Starter Main Form on reruns, skip non-starter Main forms, publish customizations, and print created/updated/skipped/failure counts."

## Solution Lifecycle

```powershell
# Export unmanaged
pac solution export --name "<SolutionName>" --path "./out/<SolutionName>_unmanaged.zip" --managed false

# Unpack to source files (Git-friendly)
pac solution unpack --zipfile "./out/<SolutionName>_unmanaged.zip" --folder "./solutions/<SolutionName>" --packagetype Unmanaged

# Pack back to zip
pac solution pack --zipfile "./out/<SolutionName>_unmanaged_new.zip" --folder "./solutions/<SolutionName>" --packagetype Unmanaged

# Import to target environment
pac solution import --path "./out/<SolutionName>_unmanaged_new.zip"
```

## VS Code Chat Entry Points

```
/power-platform-demo-wizard Create a Dynamics 365 Customer Service demo for case triage
Walk me through this repo like a beginner wizard
Ask me the discovery questions one at a time and help me write spec.md, plan.md, and tasks.md
```

Three modes:
- `.github/copilot-instructions.md` — repo-wide chat behavior
- `.github/prompts/power-platform-demo-wizard.prompt.md` — slash prompt
- `pwsh ./scripts/bootstrap/05-start-wizard.ps1` — terminal wizard

Post-wizard demo helpers:
- `pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug <scenario-slug>` — generate a single reviewable demo script
- `pwsh ./scripts/bootstrap/07-demo-dry-run.ps1 -ScenarioSlug <scenario-slug>` — rehearse the script and capture edits

Note:
- `01-install-skills.ps1` installs this skill to your local Claude skills folder.
- Skill availability depends on Claude session behavior and invocation context.

## Auth Flags

```powershell
# No browser / remote machine
pwsh ./scripts/bootstrap/10-auth-connect.ps1 -UseDeviceCode

# Service principal / CI
pwsh ./scripts/bootstrap/10-auth-connect.ps1 -ServicePrincipal
```

## Standard vs Custom Tables

**See**: `docs/standard-dataverse-tables.md` for full reference (70+ standard tables across all modules).

### Why separate them?

**Standard (out-of-box) tables** like Contact, Account, Case, Incident, Product, etc. exist in every environment:
- ✅ Reuse them—they're already there with standard fields
- ✅ Dynamics workflows expect them
- ✅ Activities, notes, and connections work automatically
- ❌ Can't delete or heavily modify in managed solutions

**Custom tables** are app-specific:
- ✅ Full control over schema
- ✅ Isolated from standard CRM data
- ✅ Packagable in managed solutions
- ❌ Require your publisher prefix

### Planning-driven standard/custom handling

1. **Question 6**: "What data tables or entities are needed?" — list all (e.g., "Contact, Case, Inspection")
2. **Question 6b**: "Use standard tables, custom tables, or both?" — choose strategy
3. **Explicit mapping block** in planning artifacts: standard reused tables, custom tables to create, standard fields reused, custom fields to add, relationships
4. **Payload gate**: do not generate payloads until the explicit mapping block is complete and approved
5. **Script 20** (`20-build-tables.ps1`): creates only entities present in table payloads; standard entities must not be in table payloads

**Example**: If you list "Contact, Case, Incident, Product, Inspection" and choose "both":
- ✅ Contact -> `contact` (reused, not in table payloads)
- ✅ Case/Incident -> `incident` (reused, not in table payloads)
- ✅ Product -> `product` (reused, not in table payloads)
- ✅ Inspection -> `<prefix>_inspection` (custom, included in table payloads)

## Common Mistakes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Build scripts run before Spec Kit | Skipped the gate | Complete `spec.md`, `plan.md`, `tasks.md` first |
| 401 on every API call | Token resource URL mismatch | Rerun `10-auth-connect.ps1` — no trailing slash on env URL |
| Token works then stops mid-run | Token expired (60–90 min) | Rerun `10-auth-connect.ps1` to refresh |
| `pac` not found | CLI not installed | `winget install Microsoft.PowerPlatformCLI`, restart terminal |
| Solution not found in script 50 | Solution doesn't exist yet | Create solution in Maker portal first, then rerun |
| Wrong tenant at login | Multiple tenants | Pass `-tenantId` or rerun auth with explicit tenant |
| Script fails midway | Any error | Scripts are idempotent — fix issue and rerun same script |
| `.env.ps1` accidentally committed | `.gitignore` bypassed | Keep `.gitignore` unchanged; verify with `git status` before commit |
| Script 50 fails: solution not found | Solution was never created or wrong name entered | Wizard now asks new-vs-existing at question 12; `10-auth-connect.ps1` validates via API before writing `.env.ps1` |
| Wrong or missing publisher prefix | Prefix not confirmed at setup; reused prefix from a different project | Wizard now asks new-vs-existing at question 13; `10-auth-connect.ps1` validates prefix via `publishers` API before saving `.env.ps1` |
| Script 20 tries to create Contact or Case | Misidentified tables; assumed custom when they're standard | Before running script 20, verify `tasks.md` lists which tables are standard (skip) vs custom (create); use `docs/standard-dataverse-tables.md` as reference |

## Required Tools

```powershell
winget install Microsoft.PowerShell
winget install Microsoft.AzureCLI
winget install Microsoft.PowerPlatformCLI
winget install Git.Git
# Verify all installed:
pwsh --version; az --version; pac --version; git --version; code --version
```
