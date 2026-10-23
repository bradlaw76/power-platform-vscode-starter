# Repository Instructions for Claude

Read `.github/copilot-instructions.md` for the shared repository workflow and
SpeckKit governance. `docs/onboarding.md` is the authoritative bootstrap
sequence; `docs/wizard-contract-v1.md` governs modes, source protection,
application isolation, planning, reporting and execution.

Before any framework edits, follow `docs/framework-maintenance-preflight.md`:
verify the canonical repository, exact approved maintenance branch and full
approved HEAD SHA with `scripts/bootstrap/framework-context-preflight.ps1`.
Framework Administration Mode is Framework Maintenance Mode, not a fourth
wizard mode. Stop on mismatch; never switch branches or rewrite history to
pass. Preserve dirty changes. Use the maintenance operation gate with
`-ExpectedHead` and separate modification, commit, push and merge approvals.
Honor recorded task-specific backup exceptions without requesting them again.

Application Authoring Mode requires a verified read-only `FrameworkRoot` and
separate writable `TargetProjectRoot`; framework source checkouts are never
application targets. Keep scenario artifacts under the application's
`specs/<scenario-slug>/`, never at the framework root.

Planning skills are available in `.claude/skills/`:

- `power-platform-requirements-analyst`: requirements, traceability and Spec Kit.
- `dataverse-solution-architect`: architecture and Semantic Field Type Standard.

They reuse existing discovery and approvals, preserve `demo-builder` as the
default with six business questions and one consolidated recommendation, and
use `advanced-builder` and `framework-acceptance` only explicitly. Planning
does not authorize builds, deployment or starting Skill 3. Existing wizard and
report skills remain the execution entry points after their own gates.
Ask before loading SpeckKit UI reference context.
