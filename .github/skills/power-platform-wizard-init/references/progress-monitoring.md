# Progress Monitoring Reference

Use this reference when the user asks to monitor wizard run status without changing bootstrap scripts.

## Primary Data Source

- `.wizard-metrics/events.jsonl`

Each wizard step writes lifecycle events through the telemetry helper with:

- `RunId`
- `StepCode`
- `StepKey`
- `Status` (`Started`, `Completed`, `Failed`)
- `TimestampUtc`
- `Message` (optional)

## Quick Commands

```powershell
pwsh ./scripts/bootstrap/81-build-progress-matrix.ps1
pwsh ./scripts/bootstrap/81-build-progress-matrix.ps1 -Format Json
pwsh ./scripts/bootstrap/82-build-progress-report.ps1
```

## Minimal Status Summary Pattern

When asked "where did my run stop":

1. Find the latest run ID in `.wizard-metrics/events.jsonl`.

2. For that run, identify:

- Highest completed step
- Latest event step/status
- Any failed step message

1. Return:

- Current state
- Blocking issue (if failed)
- Exact next safe command

## If Telemetry Is Disabled

When `WIZARD_METRICS_OPTOUT=1` is set:

- Do not infer step events.
- Use artifact-based checks instead:

  - Planning artifacts present and aligned
  - Recent script outputs
  - Current recommended next gate

## Guardrail

Monitoring is read-only. Do not modify wizard bootstrap scripts to add extra telemetry unless the user explicitly requests script changes.
