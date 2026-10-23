# Skill Distribution

The repository ships aligned wizard, reporting and planning skill families:

- GitHub Copilot shared skill: `.github/skills/power-platform-wizard-init/`
- Claude Code skill: `.claude/skills/power-platform-vscode-wizard/`
- GitHub Copilot reporting skill: `.github/skills/dataverse-report-wizard/`
- Claude Code reporting skill: `.claude/skills/dataverse-report-wizard/`
- Copilot and Claude architecture skill: `dataverse-solution-architect` under each platform's skills folder.
- Copilot and Claude requirements skill: `power-platform-requirements-analyst` under each platform's skills folder.

The planning skills are instructions only. They use the installed framework's
`docs/requirements-traceability.md`, `docs/semantic-field-type-standard.md` and
existing wizard contract; copying their folders alone does not install those
dependencies. The Claude installer already discovers all skill directories, so
no installer or execution-stage changes are required. Review destination
content before running the existing installer, which copies with overwrite.
Copilot discovers the checked-in `.github/skills/` folders.

Use `/power-platform-requirements-analyst` to refine business requirements and
`/dataverse-solution-architect` to review architecture without starting a build.
They reuse the selected mode and scenario plans, then return to the existing
wizard. See [Requirements traceability](requirements-traceability.md).
Run `pwsh ./scripts/ci/test-planning-skills.ps1` to check their parity,
required contracts and semantic-field documentation.

Framework contributors must first complete the exact repository/branch/SHA
check in [Maintenance preflight](framework-maintenance-preflight.md).

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

Application Authoring Mode must use a separately installed, read-only framework package and a distinct writable application repository. Do not author an application in a framework source checkout. Framework source checkouts are for explicitly authorized maintenance only.

Published releases provide a versioned ZIP and a `.sha256` checksum. Obtain both from the same reviewed GitHub release, independently verify the tag commit, and install to the versioned protected system location. For example:

```powershell
$expected = '<64-character-sha256-from-release>'
$commit = '<40-character-release-commit>'
if ((Get-FileHash ./power-platform-vscode-starter-v1.2.3.zip -Algorithm SHA256).Hash -ine $expected) { throw 'Package checksum mismatch' }
Expand-Archive ./power-platform-vscode-starter-v1.2.3.zip ./verified-framework-package
pwsh ./verified-framework-package/scripts/bootstrap/install-framework.ps1 `
  -PackagePath ./power-platform-vscode-starter-v1.2.3.zip `
  -ExpectedSha256 $expected `
  -ExpectedCommit $commit `
  -DestinationRoot "$env:ProgramFiles/Power Platform Wizard/$commit"
```

On Linux the required destination is `/opt/power-platform-vscode-starter/<commit>`; on macOS it is `/Library/Application Support/Power Platform Wizard/<commit>`. Run the installer elevated so it can assign framework ownership to administrators/root and remove write access for application-authoring users. The installer refuses to overwrite an existing version and validates package checksum and embedded repository/commit identity before installation. Existing installations and application scenario files are not silently replaced, moved, or migrated. Retain the release ZIP and checksum in approved durable storage according to the organization's backup policy.

To update, install a new release side-by-side, compare the runtime contract, review changes, run `scripts/ci/SkillParity.Tests.ps1`, then explicitly select the new `FrameworkRoot`.

To uninstall a user-installed Claude skill, remove its folder under `~/.claude/skills/`. The repo-shared Copilot skill is removed through a reviewed repository change. Uninstalling either skill does not remove the wizard runtime or generated scenario files.

## Repository governance and recovery artifacts

The settings below are manual repository-administrator actions; this project does not change GitHub rulesets or repository permissions.

- Protect `main` with a branch ruleset requiring pull requests, at least one maintainer approval, dismissal of stale approvals, resolved review conversations, and successful `Wizard Quality` checks. Block force pushes and deletion. Do not grant bypass to administrators or application-authoring identities.
- Protect `framework-maintenance/*` with the same review and validation controls, block force pushes and deletion, and restrict updates to designated framework maintainers. Framework changes still require the separate per-operation approvals in `docs/wizard-contract-v1.md`.
- Protect release tags (for example, `v*`) from updates and deletion; restrict tag creation and release publication to designated maintainers.
- Set repository base permission to read. Grant write/admin only to named maintainers and required automation identities. Application authors must not receive write access to the framework repository. Keep Actions' default token permission read-only; grant `contents: write` only to the release-publishing workflow. Restrict secrets to the required environments/workflows and require environment approval for any deployment credentials.
- Verify the effective ruleset, bypass list, team/repository permissions, Actions token defaults, and environment-secret access in GitHub settings after configuration. This checklist is not evidence that those controls have been applied.

For recovery, store the verified Git bundle, its SHA-256 checksum file, and its ref/commit manifest together in organization-approved durable, access-controlled storage—not `/tmp`, a runner workspace, or a public artifact. Keep a versioned/immutable copy according to the organization's retention policy. After upload and periodically thereafter, retrieve the bundle, verify the checksum, restore into a new repository without network access, compare the documented refs and representative files, and run `git fsck --full`. A checksum alone does not establish restorability. The bundle contains repository source and history, so restrict access at least as carefully as access to the source repository.

## Clean acceptance test

1. Install a reviewed framework release read-only and create/open a separate application repository.
2. Run `pwsh <FrameworkRoot>/scripts/bootstrap/00-prereq-check.ps1 -TargetProjectRoot <TargetProjectRoot>`.
3. Invoke the shared skill and confirm it reports runtime compatibility before intake.
4. Create a new scenario slug in the target project, leaving the synthetic Contoso sample unchanged.
5. Complete planning and run `<FrameworkRoot>/scripts/bootstrap/90-run-build.ps1 -TargetProjectRoot <TargetProjectRoot> -Mode Preview` without Dataverse credentials.
6. Confirm no Git branch, index, commit, or remote changed.
7. Run `pwsh ./scripts/ci/SkillParity.Tests.ps1` and the repository credential-free test suite.

For the reporting skill, also run
`pwsh ./scripts/ci/test-report-wizard.ps1`. Confirm that it reports an offline
simulation, exercises app attachment, and cleans up its temporary scenario.

The Claude installer currently installs Claude skills only. Copilot uses the repository-shared `.github/skills` folder; neither path downloads a missing wizard runtime.
