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

6. Enforce hard gates before build scripts
- Planning artifacts must be complete and aligned before any mutation scripts:
  - `spec.md`
  - `plan.md`
  - `tasks.md`
- Do not recommend scripts `20+` before the planning gate passes.

7. Monitor progress using existing telemetry (no script changes)
- Primary signal: `.wizard-metrics/events.jsonl`
- Event statuses: `Started`, `Completed`, `Failed`
- Optional summaries:
  - `pwsh ./scripts/bootstrap/81-build-progress-matrix.ps1`
  - `pwsh ./scripts/bootstrap/82-build-progress-report.ps1`
- If telemetry is opted out (`WIZARD_METRICS_OPTOUT=1`), use artifact-based checks instead.

8. End every run with a deterministic output contract
- Selected path
- Current gate status
- Current or failed step
- Exact next safe command

## Safety Rules

- Follow the authoritative sequence in `docs/onboarding.md`.
- Keep chat and terminal paths equivalent in gate enforcement.
- Treat unresolved intake, missing solution identity, failed prereqs, or failed auth as hard stops.
- Never bypass planning to jump straight to build scripts.

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
- [Start wizard script](../../../scripts/bootstrap/05-start-wizard.ps1)
- [Telemetry helper](../../../scripts/bootstrap/helpers/wizard-telemetry.ps1)
- [Progress matrix](../../../scripts/bootstrap/81-build-progress-matrix.ps1)
- [Progress report](../../../scripts/bootstrap/82-build-progress-report.ps1)
- [Detailed monitoring reference](./references/progress-monitoring.md)
