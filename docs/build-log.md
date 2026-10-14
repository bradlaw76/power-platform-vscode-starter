# Build Log

Record each build run here. One row per execution.

Use this to document what was planned, built, validated, and promoted.

## Federal FOIA Management - 2026-10-14

| Field | Result |
| --- | --- |
| Runner | Human operator with Copilot SDK in VS Code |
| Environment | FedCiv GCC Development; DoD IL5 portability target |
| Build type | Reusable synthetic-data demonstration |
| Scenario | `federal-foia-management` |
| Solution | `FederalFOIAManagement` (unmanaged) |
| Publisher | `FederalFOIA`; prefix `foia` |
| Scripts completed | `15`, `20`, `30`, `40`, `50`, `55`, `60`, `64`, `62`, `66`, `85`, `95` |
| Tables | 11 custom tables plus reused Contact and Case |
| Columns and keys | 134 columns; 11 active alternate keys |
| Relationships | 20 one-to-many; 1 many-to-many |
| Forms and views | 13 main forms; 13 public views |
| Business Process Flows | 2 active, solution-owned, and app-linked |
| Native reporting | 8 charts and 5 dashboards; second pass skipped all 13 stable surfaces |
| Model-driven app | Published; platform validation passed; FOIA Request landing experience and five-dashboard navigation verified |
| Synthetic data | 41 approved records across 13 tables; second pass updated the same 41 records |
| Final membership | Strict gate passed: 232 already in solution, 0 failed, 0 missing, 0 unauthorized |
| Idempotency | 673 identities stable; 0 failures; 0 duplicate candidates |
| Export | Unmanaged export and local unpack completed |
| Package inspection | 24/24 expected root components matched; 0 missing; 0 unrelated; 214 unpacked files |
| Import | No import performed or authorized |
| Source control | `49cc130`, `3e2c430`, `bbef403`; no push performed |
| Evidence | `specs/federal-foia-management/evidence-index.md` |
| Remaining release gates | Security roles/access tests, flows/integrations, accessibility, performance, complete E2E journeys, documentation sign-off, push/PR approval, and any managed-release approval |

## Wizard Behavior Versions

Record wizard version changes here so you can trace which behavior applied to each build.

| Date | Version | Change Summary |
| ---- | ------- | -------------- |
| 2026-07-13 | v1.2 | Added Q6b (standard vs custom tables), Q12 (new/existing solution), Q13 (new/existing prefix). Total: 14 discovery questions. |
| 2026-07-13 | v1.3 | Added `06-demo-script-wizard.ps1` (post-scenario demo script generator) and `07-demo-dry-run.ps1` (rehearsal helper). |
| 2026-07-15 | v1.4 | Added mid-project retrofit support: wizard can reverse-engineer spec from partial builds. `docs/onboarding.md` designated authoritative bootstrap sequence. |
| 2026-07-16 | v2.0.0 | Contract-driven wizard baseline: `wizard-contract-v1.md`, `wizard.profile.json`, optional module entrypoint `70-build-web-resources.ps1`, payload path standardization, and CI consistency checks. |
| 2026-07-17 | v2.0.1 | Made `80-post-build-analysis.ps1` generic and parameterized (`SpecPath`, `PlanPath`, `TasksPath`, `PayloadFolder`, `ReadmePath`) with marker-safe README updates, preview mode, and branch-aware push confirmation. |
| 2026-07-17 | v2.0.2 | Added disclosed local wizard telemetry (`.wizard-metrics/events.jsonl`) plus `81-build-progress-matrix.ps1` to summarize step completion/drop-off across runs. |

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
Demo Data Planned (yes/no):
Demo Data Target Tables / Counts:
Demo Data Hero Records / Purpose:
Demo Data Task Activity Scope / Parent Limit / Ordering:
Demo Data Method / Rerun Behavior:
Demo Data Source Tag / Privacy Rule:
Demo Data Created (yes/no/not implemented):
Demo Data Cleanup Verified (yes/no/not applicable):
Forms (created/updated/skipped/failed):
Views (created/skipped/failed):
Starter Main Form patched on rerun (yes/no):
Non-starter Main forms preserved (yes/no):
Business labels visible on starter form (yes/no):
Solution Exported (yes/no):
Native Reporting Stage (created/updated/skipped/failed):
Synthetic Data Stage (created/updated/skipped/failed):
Second-Run Stable IDs (yes/no/not applicable):
Second-Run Duplicate Count:
Unmanaged Package Unpacked and Inspected (yes/no):
Acceptance Package Imported (must be no):
Solution Unpacked (yes/no):
Solution Packed (yes/no):
Solution Imported (yes/no):
BPF Report Present (yes/no):
BPF Status (pass/fail/skipped):
BPF Active Verified (yes/no):
BPF In Solution Verified (yes/no):
BPF App Linked (yes/no/pending):
BPF Stage Count / Threshold:
BPF Condition Count / Threshold:
BPF Step Count / Threshold:
BPF Branch Predicate Summary Recorded (yes/no):
BPF Retry or Lock Handling Notes:
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
- README generated build summary reviewed/updated: yes/no
- Post-build analysis preview run completed (`80-post-build-analysis.ps1 -PreviewOnly`): yes/no
