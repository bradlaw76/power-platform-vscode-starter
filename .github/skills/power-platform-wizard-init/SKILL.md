---
name: power-platform-wizard-init
description: 'Use when: starting the Power Platform VS Code wizard, kicking off discovery/planning, choosing chat or terminal start path, or monitoring wizard run progress from telemetry. Supports greenfield and retrofit flows without changing core bootstrap scripts.'
argument-hint: 'Optional: path=chat|terminal mode=quick|full scenario=<slug>'
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
- "kick off planning"
- "run the wizard in terminal"
- "start with chat prompt"
- "where did my wizard run stop"
- "monitor wizard progress"
- "retrofit existing implementation into spec kit"

## Procedure

1. Confirm target repo
- Verify the user wants to run in the current workspace repository.
- Apply `requirements/GithubInstructions_General.md` to the app or demo being created.
- Run a read-only preflight for repository root, remote, current/default branch, working-tree state, recent history, existing tooling, and applicable validation commands.
- Do not create a branch, stage files, commit, or push during intake.

2. Select the start path first
- Chat path: `/power-platform-demo-wizard`
- Terminal path: `pwsh ./scripts/bootstrap/05-start-wizard.ps1`

3. Select mode
- Quick mode: capture mandatory discovery + architecture intent, then stop at planning handoff.
- Full mode: continue through optional modules and readiness handoff.

4. Run intake in sequence (do not skip)
- Required discovery questions (11) from the repo onboarding contract.
- Architecture intent questions (5):
  - OOB extension only, custom tables only, or hybrid?
  - If OOB extension: update forms in place or clone new business forms?
  - Required primary entry-point table?
  - Default landing view for that table?
  - Auto-create or auto-update a model-driven review app?

5. Branch by scenario type
- Greenfield: define scope, mappings, and target solution identity.
- Retrofit: inventory what already exists first, then define only remaining work.

6. Capture task, relationship, and demo-data planning
- Record top user tasks as persona, task, frequency, entry table/view, expected outcome, owner, and done definition.
- For each relationship, capture cardinality, requiredness, existing/new status, cascade behavior, and supporting task/surface.
- If demo data is enabled, choose all scenario-created custom tables or selected tables, confirm the resolved tables, and capture per-table counts, scenarios/states, hero records and their demo purpose, relationship distribution, method, rerun behavior, source tag, privacy constraints, and cleanup/reset decision.
- If Dataverse Task activities are requested, capture eligible parent tables, latest/all/selected scope, source-record limit (default 10 for latest), ordering field, and tasks per selected record. Do not plan tasks for every record unless the user explicitly selects all.
- Generate `demo-data-plan.json` when enabled. This stage plans data only and must not create Dataverse rows.

7. Capture the source-control extension block when enabled
- Scenario branch (default: `feature/<scenario-slug>`)
- Related issue, spec, or work item
- Checkpoint or final-only commit strategy
- Validation and CI commands discovered from the target repository
- Pull request handoff and merge strategy
- Persist these decisions in `answers.md`, `plan.md`, and `tasks.md`.

8. Enforce hard gates before build scripts
- Planning artifacts must be complete and aligned before any mutation scripts:
  - `spec.md`
  - `plan.md`
  - `tasks.md`
- Do not recommend scripts `20+` before the planning gate passes.

9. Monitor progress using existing telemetry (no script changes)
- Primary signal: `.wizard-metrics/events.jsonl`
- Event statuses: `Started`, `Completed`, `Failed`
- Optional summaries:
  - `pwsh ./scripts/bootstrap/81-build-progress-matrix.ps1`
  - `pwsh ./scripts/bootstrap/82-build-progress-report.ps1`
- If telemetry is opted out (`WIZARD_METRICS_OPTOUT=1`), use artifact-based checks instead.

10. End every run with a deterministic output contract
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
