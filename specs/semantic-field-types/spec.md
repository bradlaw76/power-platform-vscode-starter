# Universal semantic field types

## Purpose

Select Dataverse types by business meaning, never the string representation of
sample values. Apply to every industry, use case, wizard mode, table strategy,
greenfield/retrofit project, and accelerator selection, including Fully Custom.

## Requirements

- Maintain the supplied Semantic Field Type Standard as shared normative guidance.
- Require a complete, explicitly approved scenario field inventory before column
  payload generation and stage 30. Never auto-approve existing scenarios.
- Check payload types, Choice inventories/mappings, categorical text exceptions,
  Lookup targets/relationships, and applicable type settings.
- Query live metadata for created and reused fields. Report drift and dependencies;
  block dependent execution without rewriting approved planning.
- Never migrate or delete an existing field as a side effect of normal builds.
- Preserve credential-free Preview and existing accelerator authorization boundaries.

## Acceptance criteria

- Unapproved, incomplete, duplicate, unmapped, or type-mismatched inventories fail.
- A source string cannot override an approved Choice, numeric, date, or binary type.
- Existing wrong-type fields fail rather than skip; non-404 read failures propagate.
- Scoped publication and metadata validation follow column creation.
- Lookup validation follows relationship creation; final metadata validation
  precedes export, including resumed runs.
- Synthetic tests cover unrelated use cases and all supported semantic categories.
