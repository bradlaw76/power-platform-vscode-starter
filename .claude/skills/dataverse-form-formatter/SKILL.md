---
name: dataverse-form-formatter
description: Use after the Power Platform wizard has built a model-driven app to preview and apply a business-oriented second-pass layout to wizard-owned custom Main forms.
---

# Dataverse Form Formatter

## Purpose

Improve the information hierarchy of model-driven app forms after the wizard
has produced a valid baseline app. Version 1 supports fields, tabs, sections,
and one-, two-, or three-column layouts on wizard-owned custom Main forms.

This skill orchestrates the checked-in deterministic runtime. It does not write
FormXML directly.

## Runtime compatibility preflight

Skill availability is not runtime installation. A copied `SKILL.md` does not
provide the scripts, schema, helpers, or wizard contract it references.

Before intake, inspect the target repository without modifying it. Require:

- `wizard.profile.json` contract version `1.10.0` or a compatible later version
- `docs/onboarding.md`
- `docs/wizard-contract-v1.md`
- `scripts/bootstrap/60-build-forms-views.ps1`
- `scripts/bootstrap/63-format-forms.ps1`
- `scripts/bootstrap/90-run-build.ps1`
- `scripts/bootstrap/helpers/dataverse-runtime.ps1`
- `scripts/bootstrap/helpers/wizard-hardening.ps1`
- `schemas/payloads/form-layouts.schema.json`
- `scripts/ci/test-form-formatting.ps1`

If runtime files are missing or incompatible, stop and offer a reviewed
bootstrap plan. Never overwrite existing instructions, skills, scripts, specs,
or payloads without explicit review and approval.

## Mandatory gates

Do not preview or apply formatting unless:

1. `specs/<scenario-slug>/spec.md`, `plan.md`, and `tasks.md` exist.
2. The baseline wizard build completed step 60 and app assembly.
3. Each target is a custom Main form with the exact step 60 scenario ownership
   marker.
4. `specs/<scenario-slug>/form-layouts.json` validates against the checked-in
   schema.
5. Dataverse authentication is active.

Formatting is optional. A valid baseline app must remain usable when this pass
is skipped or rejected.

## Version 1 boundaries

Supported:

- Existing baseline fields
- Business labels
- Tabs and sections
- One-, two-, and three-column layouts
- Preview artifacts and semantic diff
- Apply by approved plan hash
- Scoped publish, readback verification, and idempotent rerun

Not supported:

- OOB, managed, inactive, noncustomizable, or preexisting non-wizard forms
- Adding fields that aren't already on the baseline form
- Headers, subgrids, timelines, quick views, or arbitrary custom components
- CSS, fonts, color themes, animation, or arbitrary web layout
- Destructive removal of unowned content

## Grid-control boundary

Table-level view grid configuration is not form formatting and must not be
encoded in `form-layouts.json` or FormXML. Route an all-views Power Apps grid
request to `specs/<scenario-slug>/grid-controls.json` and stage 61, which
creates a classic solution explorer maker handoff and verifies
`Microsoft.PowerApps.PowerAppsOneGrid` from an exported unmanaged solution.
Do not mutate internal custom-control metadata. Form subgrids remain deferred.

## Choice-presentation boundary

Pastel Choice colors and inline icon prefixes such as `▲ Label` belong to
`choice-presentations-*.json` and stage 35, not `form-layouts.json` or FormXML.
The icon is part of the Choice label. The formatter may select the OptionSet
Wrapper component but must preserve the option label and color metadata.

## Optional Claude UI advice

Anthropic's public `frontend-design` skill may be used as optional advice for
hierarchy, grouping, density, and scanability when it is already installed and
its provenance is acceptable. It is not required, isn't installed by this
repository, and must not generate or apply FormXML.

Translate any advice into the native `form-layouts.json` vocabulary. Discard
advice about unsupported typography, CSS, palette, animation, or free-form
responsive layout.

## Procedure

### 1. Confirm the scenario

- Resolve the scenario slug explicitly.
- Read its planning artifacts, `forms.json`, and current artifact manifest.
- Confirm the base form name, table logical name, persona, task, and business
  outcome.
- Never invent logical names.

### 2. Create or review the layout contract

Use `specs/<scenario-slug>/form-layouts.json`.

For every form, capture:

- `tableLogicalName`
- `formName`
- optional exact `formId`
- `ownership: wizard-owned-only`
- intent and primary persona
- ordered tabs
- tab column count/layout
- ordered sections
- section column count
- ordered existing fields and optional business labels
- optional `component: toggle` for Boolean fields or
  `component: option-set-wrapper` for Picklist fields
- preservation settings, all set to `true`

Group fields by user task rather than schema or creation order. Keep frequent
and decision-critical fields first. Avoid empty sections and excessive tabs.
Component requests are type-checked and configured for web, tablet, and phone.
Fields without `component` preserve their existing controls.

### 3. Validate the contract

Run:

```powershell
pwsh ./scripts/ci/test-json-schema.ps1
```

Resolve any schema or duplicate-field errors before contacting Dataverse.

### 4. Preview without mutation

Run:

```powershell
pwsh ./scripts/bootstrap/63-format-forms.ps1 `
  -ScenarioSlug <scenario-slug> `
  -Mode Preview
```

Review:

- normalized plan
- semantic diff
- approximate HTML wireframe
- report
- emitted SHA-256 plan hash

Preview must issue no PATCH, POST, DELETE, or publish request.

### 5. Obtain explicit approval

Show the semantic changes and the exact plan hash. Do not apply merely because
the user requested formatting earlier. Obtain approval for this preview.

### 6. Apply the approved plan

Run:

```powershell
pwsh ./scripts/bootstrap/63-format-forms.ps1 `
  -ScenarioSlug <scenario-slug> `
  -Mode Apply `
  -ApprovedPlanHash <sha256>
```

Apply must stop if metadata changed and the recomputed hash differs.

### 7. Verify

Require:

- Original FormXML snapshot
- Only selected forms patched
- Entity-scoped `PublishXml`
- Successful metadata readback
- Semantic equality with the approved plan
- Scenario manifest entry with form ID
- Second apply reports no changes
- Final solution membership and app usability checks pass

Report created, updated, unchanged, blocked, and failed counts. Surface every
failure explicitly.

## Orchestrated build

When `form-layouts.json` exists, `90-run-build.ps1` includes the optional
formatting stage after app assembly. Credential-free orchestrator Preview lists
the planned target. Apply requires:

```powershell
pwsh ./scripts/bootstrap/90-run-build.ps1 `
  -ScenarioSlug <scenario-slug> `
  -Mode Apply `
  -ApprovedFormFormattingPlanHash <sha256>
```

The authoritative overall bootstrap sequence remains `docs/onboarding.md`.
