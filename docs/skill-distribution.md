# Skill Distribution

The repository ships three aligned skill families:

- GitHub Copilot shared skill: `.github/skills/power-platform-wizard-init/`
- Claude Code skill: `.claude/skills/power-platform-vscode-wizard/`
- GitHub Copilot reporting skill: `.github/skills/dataverse-report-wizard/`
- Claude Code reporting skill: `.claude/skills/dataverse-report-wizard/`
- GitHub Copilot form-formatting skill: `.github/skills/dataverse-form-formatter/`
- Claude Code form-formatting skill: `.claude/skills/dataverse-form-formatter/`

A Markdown skill is instructions, not the wizard runtime. Copying `SKILL.md` alone does not install the PowerShell scripts, helpers, schemas, profile, or scenario contract it invokes.

## Install options

For this repository, use the checked-in Copilot skill in place. Claude Code users can install the complete skill folder with:

```powershell
pwsh ./scripts/bootstrap/01-install-skills.ps1
```

For another compatible repository, copy the complete Copilot skill folder only after a non-mutating compatibility review. At minimum, the target must also provide compatible versions of:

- `wizard.profile.json`
- `docs/onboarding.md` and `docs/wizard-contract-v1.md`
- `scripts/bootstrap/00-prereq-check.ps1`, `05-start-wizard.ps1`, `15-dry-validate.ps1`, and `90-run-build.ps1`
- every stage and helper named by the profile
- `schemas/payloads/`
- scenario-scoped `specs/` and `payloads/scenarios/` conventions

The optional accelerator recommendation integration additionally requires
compatible versions of:

- `accelerator.providers.json`
- `scripts/accelerators/requirements-matching.ps1`
- `scripts/accelerators/wizard-accelerator-integration.ps1`
- `schemas/accelerators/requirements-analysis.schema.json`
- `schemas/accelerators/architecture-decision.schema.json`
- `scripts/ci/test-accelerator-requirements-matching.ps1`
- `scripts/ci/test-wizard-accelerator-integration.ps1`

It remains disabled by default and is planning-only. A copied skill must not
assume that accelerator runtime files are installed, enable the feature, or
connect it to executing build stages.

The optional FAST-007 local execution-readiness route also requires:

- `scripts/accelerators/execution-readiness.ps1`
- `scripts/accelerators/invoke-execution-readiness.ps1`
- `schemas/accelerators/execution-evidence.schema.json`
- `schemas/accelerators/execution-readiness.schema.json`
- `schemas/accelerators/build-authorization.schema.json`
- `scripts/ci/test-execution-readiness.ps1`
- the compatible `90-run-build.ps1 -ExecutionReadinessOnly` early-return hook

This route remains default-off and requires independent environment and tenant
identifiers plus local prerequisite evidence. It emits human-review readiness,
not approval or authorization. The authorization schema has no issuer or
consumer. FAST-dependent Apply remains disabled, including after a ready result.

The reporting skill additionally requires compatible versions of:

- `scripts/bootstrap/08-report-wizard.ps1`
- `scripts/bootstrap/64-build-charts-dashboard.ps1`
- `scripts/bootstrap/helpers/reporting-wizard.ps1`
- `schemas/payloads/reporting.schema.json`
- `scripts/ci/test-report-wizard.ps1`

The form-formatting skill additionally requires compatible versions of:

- `scripts/bootstrap/60-build-forms-views.ps1`
- `scripts/bootstrap/35-style-choice-options.ps1`
- `scripts/bootstrap/61-configure-power-apps-grid.ps1`
- `scripts/bootstrap/62-build-app-module.ps1`
- `scripts/bootstrap/63-format-forms.ps1`
- `scripts/bootstrap/90-run-build.ps1`
- `schemas/payloads/form-layouts.schema.json`
- `schemas/payloads/choice-presentations.schema.json`
- `schemas/payloads/grid-controls.schema.json`
- `schemas/examples/form-layouts.example.json`
- `schemas/examples/choice-presentations.example.json`
- `schemas/examples/grid-controls.example.json`
- `scripts/ci/test-form-formatting.ps1`
- `scripts/ci/test-choice-presentations.ps1`
- `scripts/ci/test-power-apps-grid.ps1`

Version 1 formats only active, customizable, wizard-owned custom Main forms
using existing baseline fields/controls, tabs, sections, and one-, two-, or
three-column layouts. Preview emits artifacts plus a SHA-256 hash; Apply is
hash-gated. Boolean Toggle and Choice OptionSet Wrapper components are
type-checked and supported for web, tablet, and phone. Other components and OOB
forms are deferred.

If runtime files are missing, stop and present a reviewed bootstrap plan. Never overwrite existing instructions, skills, scripts, specs, or payloads automatically.

## Compatibility preflight

1. Confirm the target repository and inspect it without changing tracked files.
2. Compare its runtime files and `contractVersion` with this repository.
3. List present, missing, and incompatible files.
4. Run its credential-free prerequisite and contract tests if available.
5. Obtain approval before copying runtime files or changing repository instructions.

“Skill installed” means the agent can read the workflow instructions. “Wizard runtime installed” means every referenced script, helper, schema, profile, and document is present and its tests pass. Report these states separately.

## Versioning and updates

Distribute skills from a tagged release or a reviewed commit. Record the source commit and verify provenance with `git rev-parse HEAD`; release publishers may also publish SHA-256 checksums for packaged archives. To update, compare the installed folder and runtime contract, review changes, run `scripts/ci/SkillParity.Tests.ps1`, then replace only approved files.

Every runtime enhancement must also follow the
[README enhancement registry and maintenance policy](../README.md#enhancement-registry-and-maintenance-policy).
In the same reviewed change:

1. Update `docs/onboarding.md` first because it owns build order.
2. Update the README registry, script reference, sequence, and repository tree.
3. Keep `wizard.profile.json` and `docs/wizard-contract-v1.md` contract versions
   aligned.
4. Update both Copilot and Claude skills/instructions and both requirements
   guides.
5. Update schemas, examples, build-log evidence fields, compatibility lists,
   and stage-specific tests.
6. Run schema, contract, docs, order, Preview non-mutation, parity, and relevant
   behavior/idempotency tests before distributing the updated skill.

To uninstall a user-installed Claude skill, remove its folder under `~/.claude/skills/`. The repo-shared Copilot skill is removed through a reviewed repository change. Uninstalling either skill does not remove the wizard runtime or generated scenario files.

## Clean acceptance test

1. Create a temporary clean clone at a reviewed commit.
2. Run `pwsh ./scripts/bootstrap/00-prereq-check.ps1`.
3. Invoke the shared skill and confirm it reports runtime compatibility before intake.
4. Create a new scenario slug, leaving the synthetic Contoso sample unchanged.
5. Complete planning and run `90-run-build.ps1 -Mode Preview` without Dataverse credentials.
6. Confirm no Git branch, index, commit, or remote changed.
7. Run `pwsh ./scripts/ci/SkillParity.Tests.ps1` and the repository credential-free test suite.

For the reporting skill, also run
`pwsh ./scripts/ci/test-report-wizard.ps1`. Confirm that it reports an offline
simulation, exercises app attachment, and cleans up its temporary scenario.

For the form-formatting skill, also run
`pwsh ./scripts/ci/test-form-formatting.ps1`. Confirm Preview is non-mutating,
emits a SHA-256 plan hash, and Apply rejects a missing or mismatched approval
hash.

Also run `pwsh ./scripts/ci/test-choice-presentations.ps1` and
`pwsh ./scripts/ci/test-power-apps-grid.ps1`. Confirm Choice icons remain inline
label prefixes, colors pass readback/idempotency, and grid configuration remains
a maker handoff plus exported-metadata verification gate.

The Claude installer currently installs Claude skills only. Copilot uses the repository-shared `.github/skills` folder; neither path downloads a missing wizard runtime.

The installer includes the Claude `dataverse-form-formatter` skill. Anthropic's
official `frontend-design` skill is not installed; it may be used only as
optional advice when separately installed and reviewed.
