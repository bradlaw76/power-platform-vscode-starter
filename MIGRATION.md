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
