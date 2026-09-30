# Dataverse Form Formatting Skill Feasibility and Plan

**Status:** Feasibility review only; no implementation authorized  
**Date:** 2026-09-30  
**Target:** Model-driven Power Apps and Dynamics 365 forms built by this wizard

## Executive decision

Turning form formatting into a separate skill is feasible and is a good fit for
the wizard's architecture, with one important boundary:

- The wizard should remain responsible for producing a valid, populated,
  usable baseline app and form.
- A second-pass form-formatting skill should improve information hierarchy,
  tabs, sections, columns, labels, and component placement.
- Claude may propose the design, but a deterministic repository runtime should
  validate and apply the approved layout. Claude should not write arbitrary
  `FormXml` directly to Dataverse.

Recommended feasibility rating:

| Area | Rating | Assessment |
|---|---|---|
| Separate skill workflow | High | The repository already distributes Claude skills and has a clear post-build orchestration model. |
| Deterministic form restructuring | High | `SystemForm.FormXml` exposes tabs, sections, columns, rows, cells, controls, and labels. |
| Reusing the official Claude `frontend-design` skill | Medium as an advisor | Useful for design critique and hierarchy, but designed for free-form web UI rather than constrained model-driven forms. |
| Fully autonomous visual styling | Low | Model-driven forms don't provide arbitrary CSS, font, palette, or component styling. |
| Safe updates to wizard-owned forms | High | Existing scenario ownership markers provide a safe default boundary. |
| Safe updates to existing OOB forms | Medium | Possible only with explicit selection, backup, preservation rules, and stronger validation. |

## What exists today

### Wizard baseline

The current `60-build-forms-views.ps1` stage:

- Resolves the approved form strategy.
- Creates or updates a named Main form.
- Uses a scenario-specific ownership marker in the form description.
- Places the primary field and eligible business fields.
- Creates a basic `General` tab with `General` and optional `Details` sections.
- Places fields in two cells per row.
- Preserves existing controls and adds only missing controls.
- Publishes scoped table customizations.
- Produces population reports and fails under-populated forms when configured.

This is a strong baseline builder, but it isn't yet a business-aware formatter.
Its layout logic is intentionally generic: the first six fields go to General,
remaining fields go to Details, and section labels are fixed.

The existing scenario `forms.json` contract only identifies:

- Target table logical name.
- Target form name.

It doesn't describe tabs, sections, column widths, field grouping, headers,
subgrids, quick views, component placement, or responsive priorities.

### Existing contract direction

The repository contract already calls for post-update optimization:

- Enforce section labels.
- Enforce business labels.
- Remove legacy sections from prior runs.
- Validate form XML after update.

A dedicated formatter would make this requirement explicit and testable instead
of expanding the baseline population script into a design engine.

### Available Claude UI skill

Anthropic's public skills repository currently includes an official
`frontend-design` skill. It emphasizes:

- A design brief before implementation.
- Deliberate information hierarchy and layout.
- Self-critique rather than generic generated UI.
- A two-pass plan, review, and build workflow.

It is not installed in the current local `~/.claude/skills` inventory, and it is
not part of this repository's installer. More importantly, its design vocabulary
includes typography, color, motion, and arbitrary page layout that model-driven
forms don't expose.

Recommendation:

1. Do not make the official `frontend-design` skill a required runtime
   dependency.
2. Optionally use it as a design-advisory pre-pass when it is installed and its
   license/provenance has been reviewed.
3. Create a purpose-built `dataverse-form-formatter` Claude skill whose output
   is constrained to supported model-driven form capabilities.
4. Keep the same deterministic behavior whether the optional advisory skill is
   available or not.

### Tagged presenter HTML

The reviewed presenter HTML demonstrates a successful generated web-artifact
pattern: design tokens, responsive layout, clear sections, interaction states,
and theme support. Those techniques are useful for a form-layout preview or
review report, but the HTML itself can't be translated directly into a
model-driven form. Dataverse form metadata, not HTML/CSS, remains the source of
truth.

## Proposed user experience

The default wizard build remains unchanged:

1. Complete Spec Kit planning.
2. Build tables, columns, relationships, forms, views, reporting, and app shell.
3. Publish and validate the usable baseline app.
4. Offer an optional second pass: **Format model-driven forms**.

The formatting pass:

1. Discovers forms created or explicitly selected by the scenario.
2. Reads current `FormXml`, table metadata, labels, field types, relationships,
   user tasks, and approved form strategy.
3. Generates a business-oriented layout proposal and a before/after preview.
4. Validates the proposal without mutation.
5. Requires approval.
6. Applies the approved transformation through a deterministic script.
7. Publishes only affected tables.
8. Re-reads and validates deployed metadata.
9. Runs app usability and solution-membership checks again.

The baseline build must still succeed when formatting is skipped, unavailable,
or rejected.

## Recommended architecture

### 1. Claude skill: `dataverse-form-formatter`

Proposed locations:

- `.claude/skills/dataverse-form-formatter/`
- Later parity option: `.github/skills/dataverse-form-formatter/`

Responsibilities:

- Confirm the target scenario and environment.
- Confirm that the base wizard run completed successfully.
- Explain model-driven form constraints to the user.
- Gather or infer a form design brief from approved planning artifacts.
- Produce a layout proposal using only supported capabilities.
- Request approval before mutation.
- Call deterministic preview, apply, and verify commands.
- Report created, updated, unchanged, blocked, and failed forms.

The skill must not:

- Write directly to Dataverse.
- Invent table or column logical names.
- Patch non-selected OOB forms.
- remove controls, event handlers, business rules, components, or hidden
  dependencies merely because they aren't visible in the design brief.
- claim arbitrary web-style branding is possible on a native model-driven form.

### 2. Layout contract

Add a scenario-scoped contract rather than overloading the existing minimal
`forms.json`. Recommended file:

`specs/<scenario-slug>/form-layouts.json`

Illustrative shape:

```json
{
  "version": "1.0",
  "forms": [
    {
      "tableLogicalName": "ppvs_checkoutrequest",
      "formName": "Checkout Request Main",
      "ownership": "wizard-owned-only",
      "intent": "Fast request intake and approval tracking",
      "primaryPersona": "Lab coordinator",
      "tabs": [
        {
          "key": "summary",
          "label": "Request",
          "layout": "two-column",
          "sections": [
            {
              "key": "request-details",
              "label": "Request details",
              "columns": 2,
              "fields": [
                "ppvs_name",
                "ppvs_requester",
                "ppvs_asset",
                "ppvs_needby"
              ]
            }
          ]
        }
      ],
      "preserve": {
        "unlistedControls": true,
        "eventHandlers": true,
        "formLibraries": true,
        "headersAndFooters": true
      }
    }
  ]
}
```

The production schema should also support, when verified:

- One-, two-, and three-column tab or section layouts.
- Field span and placement.
- Collapsed tabs and section visibility defaults.
- Header and business-process context.
- Subgrids, quick-view forms, timelines, notes, and supported components.
- Read-only, hidden, and required presentation properties where they don't
  conflict with column metadata or business rules.
- Form-factor priority and responsive ordering.
- Localized labels.
- Explicit preservation and removal policies.

### 3. Deterministic runtime

Proposed future script:

`scripts/bootstrap/63-format-forms.ps1`

Although the wizard's numeric filenames aren't the execution authority, stage
63 communicates that this is an experience pass after form creation and app
assembly. The orchestrator should explicitly place it after `app-module` and
before final solution-membership, final publish verification, idempotency
verification, and export.

Suggested modes:

```powershell
pwsh ./scripts/bootstrap/63-format-forms.ps1 `
  -ScenarioSlug <scenario-slug> `
  -Mode Preview

pwsh ./scripts/bootstrap/63-format-forms.ps1 `
  -ScenarioSlug <scenario-slug> `
  -Mode Apply `
  -ApprovedPlanHash <sha256>
```

Runtime responsibilities:

- Validate `form-layouts.json` against a checked-in JSON schema.
- Resolve every table, form, field, relationship, and component from live
  metadata.
- Require scenario ownership by default.
- Export or persist a redacted pre-change snapshot for rollback.
- Transform XML using named nodes and stable identifiers.
- Preserve nodes outside the approved ownership boundary.
- Validate resulting XML before sending a PATCH.
- Produce a canonical semantic diff rather than relying on raw XML ordering.
- Apply only a previously previewed plan hash.
- publish only affected tables.
- Re-query deployed forms and compare semantic state with the approved plan.
- Record IDs and outcomes in the scenario artifact manifest.
- Be idempotent: the second apply should produce zero mutations.

### 4. Optional design advisor

If the official Claude `frontend-design` skill is available:

- Use it only to critique hierarchy, grouping, density, and scanability.
- Translate its advice into the constrained `form-layouts.json` vocabulary.
- Discard advice about unsupported typography, CSS, palette, animation, or
  unconstrained responsive layout.
- Record that the advisor was used, including its source version or commit.

If unavailable:

- The purpose-built formatter applies a native model-driven form design rubric.
- No capability should be lost from the deterministic preview/apply path.

## Native form design rubric

The formatter should optimize for task completion rather than decorative
styling:

1. Put the primary task and decision-critical fields first.
2. Group fields by user intent, not by schema or creation order.
3. Keep high-frequency fields above lower-frequency details.
4. Use concise business labels and section names.
5. Separate intake, work, decision, and audit information when the lifecycle
   supports those distinctions.
6. Keep related lookups and dates together.
7. Avoid empty sections and excessive tabs.
8. Preserve required and dependency controls.
9. Keep the form usable at narrower widths.
10. Prefer native components before embedded custom pages.

## Safety model

### Default boundary

Only format forms that:

- Are named in the scenario contract.
- Carry the exact wizard ownership marker for that scenario.
- Belong to tables in the scenario inventory.
- Are customizable and active.

### OOB or preexisting forms

Formatting an OOB or preexisting form requires all of:

- An approved `update-in-place` strategy.
- Exact form ID selection, not name-only matching.
- A captured pre-change snapshot.
- A semantic diff that lists moved, relabeled, added, preserved, and removed
  nodes.
- Separate approval for any destructive operation.
- Validation of form libraries, event handlers, business rules, header/footer
  controls, quick views, subgrids, and other embedded components.

### Owned-node markers

The formatter should mark tabs and sections it creates with deterministic,
scenario-scoped names. It may replace or remove only nodes carrying those
markers unless a destructive change is separately approved.

### Failure behavior

- Invalid or unparseable existing XML: stop; don't rebuild from a blank form.
- Missing field or component: fail preview for that form.
- Ambiguous form match: stop and require exact selection.
- Unsupported component: preserve it and report the limitation.
- Post-apply mismatch: fail the stage and present rollback instructions.
- Partial multi-form failure: report each form and stop final export.

## Preview and approval artifacts

Recommended generated artifacts under the scenario's metrics/artifact area:

- `form-formatting-plan.json` - normalized resolved plan.
- `form-formatting-diff.md` - human-readable semantic changes.
- `form-formatting-preview.html` - optional accessible wireframe, clearly
  labeled as an approximation rather than a live Power Apps render.
- `form-formatting-before/` - pre-change snapshots keyed by form ID.
- `form-formatting-report.json` - apply and verification results.

The HTML preview can reuse the presenter's tokenized, responsive review pattern,
but should render native concepts such as tabs, sections, columns, fields,
subgrids, and headers instead of presenting an unconstrained web mockup.

## Validation requirements

### Contract validation

- Valid JSON schema and supported contract version.
- All form, table, field, and component references resolve.
- No field is placed more than once unless the platform explicitly permits and
  the contract opts in.
- Required fields remain reachable.
- Section and tab names are unique and deterministic.

### Metadata validation

- Resulting `FormXml` parses successfully.
- Target form remains a Main form and remains active.
- Existing libraries, handlers, and preserved components are unchanged.
- Labels match approved business labels.
- Every planned field appears in the intended section.
- No wizard-owned duplicate tabs or sections remain.

### Functional validation

- App opens successfully.
- Entry table and landing view remain unchanged.
- A user can open, create, edit, save, and reopen a representative record.
- Required fields and supported controls render.
- Target forms are included in the app and available to intended roles.
- Narrow-width usability is manually or automatically checked where practical.

### Idempotency and ALM validation

- Reapplying the same approved plan makes zero changes.
- Solution inventory contains every changed form.
- Final solution-membership gate passes.
- Exported unmanaged solution contains the expected form definitions.
- No environment-wide default form or view changes occur unless explicitly
  planned and approved.

## Testing strategy

Add focused tests when implementation is authorized:

1. Contract schema acceptance and rejection.
2. New wizard-owned form restructuring.
3. Existing wizard-owned form idempotent update.
4. OOB form blocked without explicit update-in-place approval.
5. Ambiguous name blocked until exact form ID is supplied.
6. Preservation of unknown controls, libraries, handlers, headers, and footer.
7. Stable IDs and no duplicate tabs, sections, rows, cells, or controls.
8. Legacy formatter-owned section removal without removing user-owned sections.
9. Missing metadata fails in preview.
10. Invalid XML blocks apply.
11. Apply requires the exact preview hash.
12. Post-apply re-read matches the semantic plan.
13. Scoped publish only.
14. Full orchestrator skip behavior when formatting isn't enabled.

Tests should use a representative exported `FormXml` fixture in addition to the
current minimal mock forms. An authenticated acceptance test should use an
isolated custom table and form before OOB update-in-place is considered ready.

## Delivery phases

### Phase 0 - Specification and examples

- Create a dedicated scenario `spec.md`, `plan.md`, and `tasks.md`.
- Define the native design rubric.
- Collect sanitized FormXML fixtures covering simple and complex forms.
- Decide which components are supported in version 1.
- Decide whether the official `frontend-design` skill is permitted as an
  optional dependency after license and provenance review.

Exit criteria:

- Approved scope, ownership rules, rollback policy, and version 1 contract.

### Phase 1 - Preview-only formatter

- Add the layout schema and sample contract.
- Implement discovery, resolution, normalization, semantic diff, and HTML
  preview.
- Make no Dataverse mutations.

Exit criteria:

- Preview is deterministic and correctly blocks unsafe targets.

### Phase 2 - Wizard-owned apply

- Apply only to scenario-owned custom forms.
- Add scoped publish, post-apply readback, inventory, and idempotency.
- Integrate as an optional post-build stage.

Exit criteria:

- Isolated acceptance run proves stable IDs, zero duplicates, successful app
  use, and successful unmanaged export.

### Phase 3 - Advanced native components

- Add approved support for headers, subgrids, timelines, quick views, and other
  native components.
- Expand semantic validation and fixtures.

Exit criteria:

- Each component type has preview, apply, preservation, and rollback coverage.

### Phase 4 - Controlled OOB updates

- Enable exact-ID updates to explicitly selected OOB or preexisting forms.
- Add stronger snapshots, destructive approvals, and role/form-order checks.

Exit criteria:

- OOB acceptance tests prove no unrelated form behavior or metadata changed.

### Phase 5 - Optional Claude design advisor

- Integrate the official `frontend-design` skill as an optional advisory pass.
- Pin or record source provenance.
- Ensure advice is translated through the native layout contract.

Exit criteria:

- Identical deterministic apply behavior with or without the optional advisor.

## Open decisions before implementation

1. Should version 1 support only wizard-owned custom forms, as recommended, or
   also permit selected OOB forms?
2. Which native components belong in version 1: fields only, or fields plus
   headers, subgrids, timeline, and quick views?
3. Should `form-layouts.json` be fully user-authored, Claude-proposed and
   approved, or a hybrid of defaults plus overrides?
4. Should HTML preview be mandatory or optional?
5. Should the formatter run automatically when a layout contract exists, or
   only through an explicit skill invocation?
6. Is importing or depending on Anthropic's `frontend-design` skill acceptable
   after license review, or should this repository use only original,
   model-driven-specific guidance?

## Recommendation

Proceed with a dedicated skill, but implement it in stages. Start with a
preview-only contract and wizard-owned forms. Keep Claude in the design and
review loop while keeping metadata resolution, XML transformation, publishing,
and verification deterministic.

Do not fold this capability directly into the current baseline form builder.
The baseline must remain predictable and rerunnable; formatting should remain an
optional second pass that can be reviewed, rejected, rerun, or omitted without
blocking a valid app build.

## References

- Anthropic, `frontend-design` skill:
  <https://github.com/anthropics/skills/tree/main/skills/frontend-design>
- Claude Code skills:
  <https://code.claude.com/docs/en/skills>
- Microsoft Learn, Customize forms in model-driven apps:
  <https://learn.microsoft.com/power-apps/developer/model-driven-apps/customize-entity-forms>
- Microsoft Learn, Create and customize a model-driven app form:
  <https://learn.microsoft.com/power-apps/maker/model-driven-apps/create-and-edit-a-model-driven-form>
