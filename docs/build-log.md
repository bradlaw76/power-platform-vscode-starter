# Build Log

Record each build run here. One row per execution.

Use this to document what was planned, built, validated, and promoted.

## Wizard Behavior Versions

Record wizard version changes here so you can trace which behavior applied to each build.

| Date | Version | Change Summary |
|------|---------|----------------|
| 2026-07-13 | v1.2 | Added Q6b (standard vs custom tables), Q12 (new/existing solution), Q13 (new/existing prefix). Total: 14 discovery questions. |
| 2026-07-13 | v1.3 | Added `06-demo-script-wizard.ps1` (post-scenario demo script generator) and `07-demo-dry-run.ps1` (rehearsal helper). |
| 2026-07-15 | v1.4 | Added mid-project retrofit support: wizard can reverse-engineer spec from partial builds. `docs/onboarding.md` designated authoritative bootstrap sequence. |
| 2026-07-16 | v2.0.0 | Contract-driven wizard baseline: `wizard-contract-v1.md`, `wizard.profile.json`, optional module entrypoint `70-build-web-resources.ps1`, payload path standardization, and CI consistency checks. |

## Release Process

Use semantic versioning for wizard behavior:

- Major: contract changes
- Minor: new optional modules
- Patch: bug fixes only

For every release tag, publish notes with:

- What changed
- What consumers must update
- Quick validation checklist after upgrade

## Run summary template

Copy this block for each run:

```text
Date:
Runner:
Environment URL: https://<org>.crm.dynamics.com
Build Type (Demo/Prod):
Scripts Run (20,30,40,50,60):
Tables (created/skipped/failed):
Columns (created/skipped/failed):
Relationships (created/skipped/failed):
Forms (created/updated/skipped/failed):
Views (created/skipped/failed):
Starter Main Form patched on rerun (yes/no):
Non-starter Main forms preserved (yes/no):
Business labels visible on starter form (yes/no):
Solution Exported (yes/no):
Solution Unpacked (yes/no):
Solution Packed (yes/no):
Solution Imported (yes/no):
Git Branch:
Commit ID:
Notes:
```

## Planning checkpoint (Spec Kit)

Complete this before implementation:

- Spec file complete: yes/no
- Plan file complete: yes/no
- Tasks file complete: yes/no
- Discovery questions answered: yes/no
- Scenario owner sign-off: yes/no

## Validation checkpoint

- Maker portal verification complete: yes/no
- Required tasks from `tasks.md` complete: yes/no
- Known issues captured with owner/date: yes/no
