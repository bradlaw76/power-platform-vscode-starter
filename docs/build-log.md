# Build Log

Record each build run here. One row per execution.

Use this to document what was planned, built, validated, and promoted.

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
| 2026-09-30 | Form formatter v1 | Added optional, hash-approved form-layout Preview/Apply for active, customizable, wizard-owned custom Main forms after app assembly. |
| 2026-10-15 | Contract v1.13.0 | Added default-off, planning-only accelerator recommendations after discovery and before architecture finalization. |

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
Accelerator Recommendations Enabled (yes/no):
Accelerator Analysis ID / Catalog Snapshot:
Accelerator Recommended / Selected Architecture:
Accelerator Selected Packages (version/hash):
Accelerator Environment Readiness / Evidence Expiry:
FAST-Dependent Execution Gate (open/closed/not applicable):
Accelerator Decision Change Approval (yes/no/not applicable):
Scripts Run (15,20,30,optional 35,40,50,55,60,optional 61,64,62,optional 63,65,66,80,85,95):
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
Form Formatting Contract (`specs/<slug>/form-layouts.json`) Present (yes/no):
Form Field Components Applied (Toggle/OptionSet Wrapper/none):
Choice Presentation Payloads (files/none):
Choice Presentation Plan Hash:
Choice Pastel Colors and Inline Label Icons Verified (yes/no):
Form Formatting Schema Valid (yes/no/not applicable):
Form Formatting Planned Target:
Form Formatting Preview Artifacts Reviewed (yes/no/not applicable):
Form Formatting Approved SHA-256:
Form Formatting Apply (updated/unchanged/blocked/failed/not applied):
Form Formatting Readback / Scoped Publish Verified (yes/no/not applicable):
Form Formatting Boundary Verified (wizard-owned custom active customizable Main form; yes/no/not applicable):
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
### Power Apps grid gate

- Contract: `specs/<scenario-slug>/grid-controls.json` / not requested
- Stage 61 Preview handoff reviewed:
- Classic solution explorer all-views configuration published:
- Inline editing configured explicitly:
- Exported metadata verification: PASS / FAIL / N/A
- Runtime control: `Microsoft.PowerApps.PowerAppsOneGrid`
- Verification report:
- Note: view creation alone does not guarantee OneGrid; subgrid support is deferred.
