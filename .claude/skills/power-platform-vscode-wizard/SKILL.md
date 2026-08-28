---
name: power-platform-vscode-wizard
description: Use when building Power Platform model-driven apps, Dynamics 365 demos, or Dataverse solutions from VS Code using PAC CLI and the power-platform-vscode-starter repo bootstrap scripts
---

# Power Platform VS Code Wizard

## Overview

A wizard-guided workflow for building Power Platform model-driven apps from VS Code using PAC CLI and Dataverse Web API scripts. **Spec Kit planning is a mandatory gate — never run build scripts without completed `spec.md`, `plan.md`, and `tasks.md`.**

## Runtime Compatibility Preflight

Skill availability is not runtime installation. A copied `SKILL.md` does not provide the PowerShell scripts, helpers, schemas, profile, or canonical docs it references.

Before intake, inspect the target repository without modifying it. Report present, missing, and incompatible runtime files, including `wizard.profile.json`, `docs/onboarding.md`, `docs/wizard-contract-v1.md`, payload schemas, and every script named by the profile. If runtime files are missing, stop and offer a reviewed bootstrap plan. Never overwrite existing instructions, skills, scripts, specs, or payloads without explicit review and approval. Use `docs/skill-distribution.md` for installation and provenance checks.

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

## Wizard Modes (Select First)

- `demo-builder` is the default. Ask six business questions plus one consolidated recommendation confirmation. Infer technical design and do not ask disposable-environment, destructive-cleanup, retention, acceptance-source-tag, or rerun-proof questions.
- `advanced-builder` requires explicit selection. Expose application profile, table strategy, form strategy, entry point, landing view, entity mapping, user tasks, relationships, reporting, demo data, solution identity, and source-control controls. Do not ask framework-acceptance or cleanup questions.
- `framework-acceptance` requires explicit selection. Add authorized-environment confirmation, isolated timestamped naming, acceptance source tags and hero labels, deterministic rerun evidence, retention policy, separately approved cleanup, and an acceptance evidence plan.

All modes generate compatible `answers.md`, `spec.md`, `plan.md`, `tasks.md`, and `report-mappings.md` files for the same build pipeline.

## Advanced Discovery Questions

In Advanced Builder and Framework Acceptance, ask and capture all base discovery questions, then complete explicit entity mapping before any build work:

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
13. Should we create a new publisher prefix or use an existing one? If existing, what is the prefix (e.g. cct, fabrikam)?
14. Standard reused tables (display/logical names)
15. Custom tables to create
16. Standard fields to reuse
17. Custom fields to add
18. Relationships to create
19. Create optional HTML report web resources (agent performance, supervisor oversight, executive KPI)? (yes/no)

If question 19 is yes, capture critical/high-frequency table logical names and one report mapping per surface: table, surface name, form/dashboard/view type, target placement, required fields, business decision, owner, and validation checklist. Generate `report-mappings.md` and block planning completion if any critical table lacks a mapping. If question 19 is no, preserve that explicit no-report decision in `report-mappings.md`.

After entity mapping in the detailed modes, also capture:
- Validate the primary entry-point logical name against reused standard tables, planned custom tables, or current retrofit inventory. Give every planned view an explicit `views.json` disposition. For a uniquely planned new custom table, use `adopt-generated-active` when the requested name exactly equals `Active {plural table display name}` and `create-custom` for a distinct business view. Use `explicit-decision-required` for standard, hybrid-standard, shared, preexisting, retrofit, or ambiguous tables; never infer adoption for them. Planning intent does not replace step 60's current-run creation and exact generated metadata proof. Require explicit-decision resolution and authenticated saved-query resolution before app assembly.
- Top user tasks: persona, task, frequency, entry table/view, expected outcome, owner, and done definition.
- Relationship decisions: cardinality, requiredness, existing/new status, cascade behavior, and supporting task/surface.
- When demo data is enabled: all-created vs selected table scope, resolved tables, per-table counts, scenarios/states, hero records and their demo purpose, relationship distribution, method, and synthetic-data/privacy constraints. Capture rerun evidence, acceptance source tags, retention, and cleanup only in Framework Acceptance.
- If Dataverse Task activities are requested: eligible parent tables, latest/all/selected scope, source-record limit (default 10 for latest), ordering field, and tasks per selected record. Never target every record unless the user explicitly selects all.

Generate `demo-data-plan.json` for approved demo-data planning. This does not authorize or execute Dataverse row creation.

Generate `report-mappings.md` for every run. Report payload and HTML implementation must not begin until the mapping is approved and its table, field, and placement references are validated.

When the `source-control` module is enabled, also inspect the target repository read-only and capture the scenario branch, related issue/spec, checkpoint strategy, validation/CI discovered from that repository, pull request handoff, and merge strategy. Apply `requirements/GithubInstructions_General.md` throughout whatever app or demo the end user is creating. Do not stage, commit, or push during intake.

## Ordered Build Flow

Follow this exact sequence — do not skip validation checkpoints:

| Step | Action | Validation |
|------|--------|------------|
| 0 | Clone repo, open in VS Code, install extensions | Extensions installed via `@recommended` |
| 1 | Start with `/power-platform-wizard-init` in Copilot Chat (primary), then choose mode and chat or terminal intake; default terminal path: `pwsh ./scripts/bootstrap/05-start-wizard.ps1` | Mode-specific discovery and source-control plan captured |
| 2 | **GATE: Complete Spec Kit** (`spec.md`, `plan.md`, `tasks.md`) | All three files exist and are consistent |
| 3 | Generate presenter script: `pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug <scenario-slug>` | `demo-script.md` exists and matches the scenario story |
| 4 | Optional rehearsal: `pwsh ./scripts/bootstrap/07-demo-dry-run.ps1 -ScenarioSlug <scenario-slug>` | `demo-dry-run.md` captures rehearsal notes |
| 5 | Check prerequisites: `pwsh ./scripts/bootstrap/00-prereq-check.ps1` | All tools show PASS |
| 6 | Authenticate: `pwsh ./scripts/bootstrap/10-auth-connect.ps1` | `az account show` + `pac auth list` both return profile |
| 6.5 | **Validate solution + prefix** (`10-auth-connect.ps1` does this automatically) | Existing solution confirmed via `solutions?$filter=uniquename eq '<name>'`; existing prefix confirmed via `publishers?$filter=customizationprefix eq '<prefix>'`. Stop and fix if either is missing before running scripts 20–60. |
| 7 | Add payloads (`payloads/table-*.json`, `columns-*.json`, `relationships-*.json`) | Files present |
| 8 | Build in order (scripts 20–60, plus optional 65 if Q19=yes) | Each script exits with zero failed count |
| 9 | Verify in Maker portal | Tables, forms, views visible in target solution |
| 10 | Export + unpack → validated final commit → approved push/PR handoff → pack → import | See Solution Lifecycle below |
| 11 | Document in `docs/build-log.md` | Teammate can rerun the process |

## Build Scripts (Run in Order)

```powershell
pwsh ./scripts/bootstrap/20-build-tables.ps1
pwsh ./scripts/bootstrap/30-build-columns.ps1
pwsh ./scripts/bootstrap/40-build-relationships.ps1
pwsh ./scripts/bootstrap/50-add-to-solution.ps1
pwsh ./scripts/bootstrap/55-build-business-process-flows.ps1 -ScenarioSlug <scenario-slug>
pwsh ./scripts/bootstrap/60-build-forms-views.ps1
pwsh ./scripts/bootstrap/62-build-app-module.ps1 -ScenarioSlug <scenario-slug>
# Run only if Q19 answer was yes
pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <scenario-slug>
pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -ScenarioSlug <scenario-slug> -InventoryOnly -EnforceExportGate
```

All scripts are idempotent — safe to rerun after fixing failures.

Prefer `pwsh ./scripts/bootstrap/90-run-build.ps1 -ScenarioSlug <scenario-slug> -Mode <Preview|Apply>` for the complete ordered run. A planned BPF generates a designer handoff; author the initial definition through Power Apps. Script 55 validates, activates, adds, and links the existing category-4 process rather than fabricating workflow definition metadata. Do not export while the final solution membership gate fails.

Script 65 generates 3 Dynamics-blue HTML reports (agent performance, supervisor oversight, executive KPI) from scenario design files and adds them to the solution as web resources. It skips silently when reports are disabled.

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
/power-platform-wizard-init
/power-platform-demo-wizard Create a Dynamics 365 Customer Service demo for case triage
Walk me through this repo like a beginner wizard
Ask me the discovery questions one at a time and help me write spec.md, plan.md, and tasks.md
```

The shared Copilot skill is the primary entry point. It selects chat or terminal intake, enforces the planning gate, and can monitor progress from existing telemetry. Direct chat and terminal wizard paths remain supported.

Source control follows the generated scenario, not just maintenance of this starter repository. Use coherent planning, metadata, experience, validation, and final unpacked-solution checkpoints. Before each commit, inspect status/diff, run applicable discovered validation, stage explicit files, and obtain approval. Push requires separate approval and remote commit verification.

Available entry points:
- `.github/skills/power-platform-wizard-init/SKILL.md` — primary shared Copilot skill
- `.github/copilot-instructions.md` — repo-wide chat behavior
- `.github/prompts/power-platform-demo-wizard.prompt.md` — slash prompt
- `pwsh ./scripts/bootstrap/05-start-wizard.ps1` — terminal wizard
- `docs/wizard-walkthrough.html` — visual, end-to-end walkthrough

Post-wizard demo helpers:
- `pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug <scenario-slug>` — generate a single reviewable demo script
- `pwsh ./scripts/bootstrap/07-demo-dry-run.ps1 -ScenarioSlug <scenario-slug>` — rehearse the script and capture edits

Note:
- `01-install-skills.ps1` installs this skill to your local Claude skills folder.
- It does not install a missing wizard runtime into another repository.
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
