# Standalone Model-Driven App Support

## Problem Statement

The wizard describes generic Power Platform support, but its generated planning contract and experience builders still assume Dynamics-oriented defaults. A maker must be able to plan and build a standalone model-driven Power Apps application without installing a Dynamics 365 workload.

## Application Profiles

- `standalone-model-driven`: standalone Power Apps app, normally custom-table-first.
- `dynamics-sales-extension`: extension of installed Dynamics 365 Sales metadata.
- `dynamics-customer-service-extension`: extension of installed Customer Service metadata.
- `dynamics-field-service-extension`: extension of installed Field Service metadata.
- `generic-dataverse-solution`: Dataverse solution that may not create an app shell.

## Architecture Intent

Every scenario must capture:

- Application profile.
- Table strategy: `oob-only`, `custom-only`, or `hybrid`.
- Form strategy: `update-in-place` or `create-new-forms` when existing tables are used.
- Primary entry-point table logical name.
- Default landing view.
- Whether to create or update the review app.

## Experience Requirements

- Forms and views can target any table declared by table or column payloads, including installed standard tables.
- `create-new-forms` must not patch an existing non-wizard Main form.
- `update-in-place` may update only the explicitly selected target form.
- App configuration must retain the entry table and landing view and validate both against expected artifacts.
- Standalone scenarios use neutral report names and visual defaults.
- Legacy scenario files without an Application Profile section remain readable.

## Acceptance Criteria

- The terminal wizard asks architecture-intent questions before general discovery.
- Generated `answers.md`, `spec.md`, `plan.md`, and `tasks.md` contain the approved profile and app intent.
- Custom-only and mixed-table form/view tests pass.
- App-module configuration identifies the requested landing view rather than assuming `Active Records`.
- Invalid or missing profile fields fail build-contract validation for newly generated scenarios.
- Existing CI scripts pass.
