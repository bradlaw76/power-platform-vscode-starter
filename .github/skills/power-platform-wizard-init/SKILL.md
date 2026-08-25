---
name: power-platform-wizard-init
description: 'Use when: starting the Power Platform VS Code wizard, kicking off discovery/planning, choosing chat or terminal start path, or monitoring wizard run progress from telemetry. Supports greenfield and retrofit flows without changing core bootstrap scripts.'
argument-hint: 'Optional: path=chat|terminal type=greenfield|retrofit scenario=<slug>'
---

# Power Platform Wizard Init

## Overview

This skill starts the repository wizard safely through either chat or terminal, enforces planning gates, and reports progress using existing telemetry artifacts.

This skill does not modify core wizard scripts.

## What This Produces

- A selected start path (chat or terminal)
- Completed discovery intake (including architecture intent)
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
- `Before discovery`: explain that the user will identify a new build or retrofit first, then choose chat or terminal.
- `What will change`: state that initial setup writes local progress telemetry under `.wizard-metrics/` unless `WIZARD_METRICS_OPTOUT=1`, but does not authenticate, create Dataverse resources, run build scripts, commit, or push. Planning files are created only after intake begins and the user approves the path.
- `First decision`: ask the user to confirm the target repository. Ask only this one question in the first response.

Keep this preview beginner-safe. Expand `PAC CLI`, `Dataverse`, and `Spec Kit` the first time each term appears. If the user arrived from the GitHub URL and has not cloned the repository, give only the clone/open commands first, then tell them to enter `/power-platform-wizard-init` in Copilot Chat. Also accept the natural-language fallback: `Start the Power Platform wizard in this repository.`

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

2. Select scenario type before the start path
- Greenfield: define scope, mappings, and target solution identity.
- Retrofit: inventory what already exists first, then define only remaining work.

3. Select the start path
- Chat path: continue the intake in the current conversation. Do not invoke `/power-platform-demo-wizard` and restart setup.
- Greenfield terminal path: `pwsh ./scripts/bootstrap/05-start-wizard.ps1`
- Retrofit terminal path: `pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Retrofit`

4. Run intake in sequence (do not skip)
- Select the application profile first: standalone model-driven, Dynamics Sales extension, Dynamics Customer Service extension, Dynamics Field Service extension, or generic Dataverse solution.
- Required discovery questions (11) from the repo onboarding contract.
- Architecture intent questions (5):
  - OOB extension only, custom tables only, or hybrid?
  - If OOB extension: update forms in place or clone new business forms?
  - Required primary entry-point table?
  - Default landing view for that table?
  - Which artifacts must the required auto-created or updated model-driven review app surface?
- After explicit table mapping, resolve the entry-point logical name against reused standard tables, planned custom tables, or current retrofit inventory. Record whether the named landing view must be created/updated or verified as an existing saved query. Do not proceed to app assembly until Dataverse resolves that view.

5. Capture task, relationship, report, and demo-data planning
- Record top user tasks as persona, task, frequency, entry table/view, expected outcome, owner, and done definition.
- For each relationship, capture cardinality, requiredness, existing/new status, cascade behavior, and supporting task/surface.
- Generate `report-mappings.md` for every run. If reports are enabled, capture critical/high-frequency tables and one mapping per report with table logical name, surface, form/dashboard/view type, placement, required fields, supported decision, owner, and validation checklist. Block progression when a critical table has no mapping. If reports are disabled, record that explicit decision.
- If demo data is enabled, choose all scenario-created custom tables or selected tables, confirm the resolved tables, and capture per-table counts, scenarios/states, hero records and their demo purpose, relationship distribution, method, rerun behavior, source tag, privacy constraints, and cleanup/reset decision.
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
