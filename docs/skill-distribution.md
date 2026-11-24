# Skill Distribution

The repository ships two aligned skill families:

- GitHub Copilot shared skill: `.github/skills/power-platform-wizard-init/`
- Claude Code skill: `.claude/skills/power-platform-vscode-wizard/`
- GitHub Copilot reporting skill: `.github/skills/dataverse-report-wizard/`
- Claude Code reporting skill: `.claude/skills/dataverse-report-wizard/`

A Markdown skill is instructions, not the wizard runtime. Copying `SKILL.md` alone does not install the PowerShell scripts, helpers, schemas, profile, or scenario contract it invokes.

## Authorization policy inheritance

Every shipped skill follows [authorization and execution](policies/authorization-and-execution.md). Full clones inherit its instruction, prompt and skill references. During the existing consumer compatibility review, include this policy or an explicitly reviewed equivalent and reference it from the project's existing instruction entry point. Preserve stricter local policies and do not overwrite another project's instructions automatically.

`01-install-skills.ps1` bundles the canonical policy byte-for-byte into each installed Claude skill's `references/authorization-and-execution.md`. Reruns refresh the copy; a missing canonical policy blocks skill copying. Skills prefer project-local policy, then the bundled copy; if both are absent, mutating work is blocked. This installs no runtime, credentials, scheduler or project authorization.

This baseline ships two skill families (wizard and reporting), four instruction files total, not the formatter family from the older integration branch. Do not import absent families merely to satisfy an obsolete count. Run `AuthorizationExecution.Tests.ps1` for policy decisions and real temporary-home install/rerun/missing-policy checks; no operator home or consumer project is used.

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

The reporting skill additionally requires compatible versions of:

- `scripts/bootstrap/08-report-wizard.ps1`
- `scripts/bootstrap/64-build-charts-dashboard.ps1`
- `scripts/bootstrap/helpers/reporting-wizard.ps1`
- `schemas/payloads/reporting.schema.json`
- `scripts/ci/test-report-wizard.ps1`

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

H009 supplies [offline identity and safe update planning](wizard-updates.md).
Both skills invoke the runtime's `04-check-wizard-update.ps1`, not agent-specific
pull/copy logic. Profile, contract, component and automation package versions
are not a distribution release; development release identity remains unknown.
Official Apply remains blocked without approved independent publisher policy.
Copied Copilot and installed Claude skills are classified separately; consumer/
skill Apply remains read-only until exact bundle ownership is approved.
The existing installer is not H009 transactional Apply and must not be used to
bypass local-edit conflicts or trust gates.
The [candidate ownership inventory](../distribution/ownership-policy.json) lists
source assets only. Its [topology and trust policy](wizard-release-readiness.md)
requires explicit review of local instructions and verified installed-bundle
receipts; candidate membership never grants home-folder or consumer writes.
The cached repository advisor script/runbook is absent in this candidate:
unavailable advice does not mean up-to-date. Do not copy a newer branch, overwrite
local skill edits or install absent updater tooling automatically.

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

The Claude installer currently installs Claude skills only. Copilot uses the repository-shared `.github/skills` folder; neither path downloads a missing wizard runtime.
