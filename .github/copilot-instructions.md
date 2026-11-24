# Project guidelines

## One execution policy

Load [authorization and execution](../docs/policies/authorization-and-execution.md),
the canonical policy for framework and wizard-managed execution. Routine
authorized nonproduction corrections are development-first: reuse accepted
requirements, implement and validate within scope, then reconcile affected notes.
Do not replay discovery or impose a new planning package. New/material features,
semantic design, security, production and protected functionality retain their
applicable pre-change gates. Historical handoffs are reference, not restrictions.
Project-specific requirements and stricter security policies remain binding.

For explicitly autonomous multi-change work, use
[queued delivery](../docs/QUEUED_AUTONOMOUS_DELIVERY.md) and
https://code.visualstudio.com/docs/agents/overview. Load the policy's authority,
backup, writer/recovery, publication and native-acceptance rules rather than
duplicating them here. Instructions do not install an executor.

## Functional planning and beginner guidance

This is a reusable Power Platform/Dynamics wizard, not a consumer application.
Begin new/material scenarios with discovery; retain accepted answers and actual
current state for retrofits. Use scenario-level `spec.md`, `plan.md`, `tasks.md`;
do not duplicate them at root. Minor maintenance uses focused checks without
regenerating the full matrix; preserve native field/security proof before live
binding. Follow [scenario impact](../docs/scenario-change-impact-gate.md).

Use `demo-builder` by default, `advanced-builder` only for requested technical
control, and `framework-acceptance` only after explicit selection.
Load applicable questions/contracts from [wizard contract](../docs/wizard-contract-v1.md),
`wizard.profile.json` and [onboarding](../docs/onboarding.md), the sole bootstrap
sequence authority. Do not maintain a competing step list here.

Ask one missing business question at a time. Explain PAC CLI, Dataverse, solution
and managed/unmanaged when first used. Reuse setup, delivery goal and deadline.
Guided work needs no WSL; unattended execution requires actual capability and
explicit opt-in. Reporting, data scope, relationships, entry/landing view and
review-app decisions stay in existing consolidated confirmation.

## Shared update lifecycle and reporting consent

Use the confirmed runtime's `04-check-wizard-update.ps1 -Action Status` for
offline identity, then shared Review changes / Update wizard / Skip for now.
Never implement another pull/copy updater. Official Apply remains fail-closed;
profile/contract versions and copied skills are not verified releases.
See [wizard updates](../docs/wizard-updates.md).

Recheck [H010 reporting consent](../docs/wizard-contract-v1.md#reporting-consent-h010)
before new or resumed orchestration. Completed stages and leftover payloads are
not consent; native/HTML decisions remain independent.

## Load affected contracts, not historical collections

- Schema/type changes: [semantic fields](../docs/semantic-field-type-standard.md)
  and approved scenario decisions; never delete/recreate String columns to hide drift.
- Forms, views, navigation, inventory and solution sync: applicable onboarding/
  payload contracts; preserve business labels, idempotence, scoped publication,
  membership/export checks and unrelated standard components.
- Optional FAST, styling, grid, formatting and reporting: selected contracts and
  approval/verification gates only. FAST stays default-off; readiness is not authority.
- Continuation/status: [framework handoff](../docs/framework-handoff.md);
  task/lease/dependency projection is not dispatch or live proof.
- Installation/migration: [skill distribution](../docs/skill-distribution.md);
  preserve custom instructions and project-specific security.

## SpeckKit and maintenance

Use `SYSTEM_MANIFEST.json.md`, `SPEC.md` and `BINDING_CERTIFICATION.md` for repository
governance; scenario artifacts remain authoritative for individual builds.
Registry: https://github.com/bradlaw76/SpeckKit-Project-Development.
Apply existing component headers to new component files; ask before loading
SpeckKit UI references. Prefer repository-local functional contracts on overlap.

For runtime enhancements, update the README registry/checklist and affected
profile, generated guidance, skill families, tests and existing review handoff.
Record evidence once; never bypass repository protection to write it.
