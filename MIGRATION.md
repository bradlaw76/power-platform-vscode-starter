# Migration Guide

## Scope

This guide covers migration to the contract-driven wizard baseline introduced in v1.0.0.

## Breaking Changes

- Discovery is now defined as 11 required questions plus optional extension blocks.
- Payload folder is standardized to `payloads/` at repository root.
- `docs/onboarding.md` is the authoritative step-order document.

## New Optional Modules

- `65-build-web-resources.ps1` (web resources)
- `06-demo-script-wizard.ps1` (demo script generation)
- `07-demo-dry-run.ps1` (rehearsal)

## Required Config Additions

Add `wizard.profile.json` with:
- required question count
- optional question module flags
- core and optional module sequence
- folder conventions
- validation gates

## Before/After

### Before

- Discovery count varied across docs/prompt/script.
- Script payload defaults were inconsistent with repository layout.
- Optional modules mixed into core flow without explicit profile gating.

### After

- One contract in `docs/wizard-contract-v1.md`.
- One profile in `wizard.profile.json`.
- Core vs optional modules clearly separated.
- Folder and docs consistency checks available in CI.

## Compatibility Matrix

| Wizard Version | Contract | Supported Template Baseline |
| --- | --- | --- |
| 1.x | v1 | Current `power-platform-vscode-starter` baseline |

## Upgrade Validation Checklist

- `wizard.profile.json` exists and has required keys.
- `docs/onboarding.md` sequence matches profile core module order.
- Discovery model matches contract in README, onboarding, and prompt.
- Payload path resolves to root `payloads/` in scripts 20/30/40/50/60.
- Optional web resources module only appears when selected.

## Framework Source Protection Migration (Contract 1.11.0)

Application authoring now requires a separate, existing `TargetProjectRoot`; the
wizard checkout is the read-only `FrameworkRoot`. `05-start-wizard.ps1` and
artifact-generating entry points reject a missing or overlapping target. The
legacy `-WorkspaceRoot` name remains an explicit alias for
`-TargetProjectRoot`, but omission no longer defaults writes to the framework
checkout.

Existing `specs/`, `payloads/`, `.wizard-metrics/`, exports, and scenario files
are not automatically reinterpreted or relocated. To move an existing scenario:

1. Inventory the scenario's planning files, payloads, generated evidence, and
   local configuration without changing the source.
2. Choose or create a separate application repository and review path conflicts.
3. Obtain explicit approval for a one-time copy; preserve the original source
   until the copied scenario passes the repository's validation checks.
4. Set `TargetProjectRoot` to the application repository and use that root for
   all future planning and builds.
5. Record the migration result and any files intentionally excluded.

Do not copy secrets from `.env.ps1` into source control. A mismatch, conflict, or
uncertain path is a stop condition; do not overwrite, delete, or move files
automatically. Framework maintenance remains a distinct, branch- and
operation-approved workflow defined in `docs/wizard-contract-v1.md`.
