# Migration Guide

## Scope

### Contract 2.2.0: repository update advisor

Distribute the aligned catalog, schemas, helper, command and startup/orchestrator
hooks described in [repository updates](docs/repository-updates.md).
Existing scenarios need no update context unless they want relevance filtering.
No automatic pull or migration occurs. Existing run states without a source
baseline cannot be resumed; start a fresh run after review. Git-less runs remain
explicitly unverified. Preview never creates manifest provenance, and Apply
records are immutable. Contract 2.1.0 reporting and 2.0.0 semantic-field gates
remain unchanged.

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
- Core payload paths resolve to root `payloads/`; optional Choice presentation
  payloads run at stage 35, while grid and form-layout contracts resolve from
  `specs/<scenario-slug>/` for stages 61 and 63.
- The README enhancement registry, `docs/onboarding.md`, profile/contract
  versions, paired skills, requirements guides, and related CI checks are
  synchronized for every runtime enhancement.
- Optional web resources module only appears when selected.
