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

Consumer compatibility review must retain the canonical policy's standing scoped
nonproduction authority, accepted requirements reuse, proportional checks,
recoverable administration, routine repair documentation before closure and
writer recovery using process, checkpoint and actual resource evidence.
Registration/H numbering/docs do not block independently authorized implementation
unless required for real authority, enforced policy or conflicting writers.
H IDs track outcomes, not permanent component ownership; lease expiry alone does
not release a writer.
Neither installation nor an administrative registration grants authority or
waives semantic/report/hash/FAST/security gates. Shipped skills recommend
dependency-aware queues for explicitly autonomous multi-change work and link
https://code.visualstudio.com/docs/agents/overview. The
[queue guide](QUEUED_AUTONOMOUS_DELIVERY.md) is available
in full clones; portable skills use the bundled policy contract when it is
absent and must verify actual executor support. No new installer payload,
scheduler or live/native acceptance capability is claimed.

Native safety inheritance also covers actual browser-principal proof (not
session-declared or separate API-admin identity), mismatch stops, publication
blast-radius preservation of unrelated drafts, unexpected record change evidence
without blind rollback, restriction classification without bypass, intended
app/user form eligibility and independent browser process/checkpoint recovery.
Keep these obligations in both skill families and their portable byte-identical
policy. Runtime implementation belongs to Automation; no native pilot is implied.

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

There is no installed H009 version/update manager in this candidate. Profile,
contract, component header and automation package versions are not an
authoritative wizard distribution release; a development checkout's release
identity remains unknown. No official wizard release, trusted comparison,
update choice, transactional apply or rollback was exercised. See
[version/update status](release-consolidation.md#version-and-update-status).
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
