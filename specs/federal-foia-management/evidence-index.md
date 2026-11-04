<!--
=============================================================================
COMPONENT:    Federal FOIA Management Evidence Index
FILE:         specs/federal-foia-management/evidence-index.md
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-22
ENVIRONMENT:  FedCiv GCC Development | Synthetic demonstration data
=============================================================================
-->

# Federal FOIA Management Evidence Index

**Evidence boundary:** Development-environment and synthetic-data evidence only.
This index does not authorize import, managed release, production deployment,
push, or pull-request creation.

## Verified Evidence

| Evidence | Result | Runtime artifact |
| --- | --- | --- |
| Deployment manifest | Stages 20 through 66, final membership, stage 85, and stage 95 results recorded | `deployment-manifest.json` |
| Strict solution membership | Export allowed; 263 already in solution; 0 failed; 0 missing; 0 unauthorized | `.wizard-metrics/artifacts/contamination/federal-foia-management/solution-membership-report.json` |
| Strict membership summary | Human-readable companion to the JSON report | `.wizard-metrics/artifacts/contamination/federal-foia-management/solution-membership-report.md` |
| Idempotency baseline | 706 identities; all 702 pre-grid identities unchanged; only two approved views added in manifest/membership | `.wizard-metrics/artifacts/idempotency/federal-foia-management/baseline.json` |
| Baseline transition | Original 702-identity baseline archived and compared before the bounded view rerun | `.wizard-metrics/artifacts/grid-controls/federal-foia-management/baseline-transition.json` |
| Idempotency verification | Stable IDs true; duplicate count 0; failure count 0 | `.wizard-metrics/artifacts/idempotency/federal-foia-management/verification.json` |
| Reporting second pass | 7 native reporting surfaces updated, 6 skipped; stable identities | `.wizard-metrics/artifacts/reporting/federal-foia-management.json` |
| Synthetic-data second pass | 41 existing records updated; no duplicate candidates | `.wizard-metrics/artifacts/data/federal-foia-management.json` |
| App-module validation | Published review-app identity, component linkage, and platform validation | `.wizard-metrics/artifacts/app-module/app-module-validation.json` |
| Navigation validation | FOIA Request entry point, landing view, five dashboard links, and table navigation | `.wizard-metrics/artifacts/app-module/navigation-summary.json` |
| Choice migration | 26 global Choices, 29 Picklists, all 97 captured populated values restored; exact live bindings/options/membership verified | `.wizard-metrics/artifacts/choice-migration/federal-foia-management-verification.json` |
| Migration authorization and Apply | All 29 approved categorical text fields replaced, dependencies restored, both BPFs validated and active | `.wizard-metrics/artifacts/choice-migration/federal-foia-management-apply.json` |
| Export inspection | 53 expected roots matched, including 26 global Choices and 3 security roles; all 29 Picklist bindings verified; 0 missing; 0 unrelated; import not permitted | `.wizard-metrics/artifacts/export/federal-foia-management.json` |
| Choice presentation | All 162 options use original-wizard symbols and pastels; exact live readback, 29 unchanged bindings, and settled zero-update rerun | `.wizard-metrics/artifacts/choice-presentations/federal-foia-management/verification.json` |
| Presentation backup/approval | Original option metadata, exact labels/colors preview, approved SHA-256 plan and run receipts | `.wizard-metrics/artifacts/choice-presentations/federal-foia-management/` |
| Grid package | All 13 selected Web grids use native OneGrid, editing off, colors on; both new FOIA views verified | `gridControls` in `.wizard-metrics/artifacts/export/federal-foia-management.json` |
| New FOIA views | Two exact, FOIA-filtered public views; stable IDs and rerun without creation | `.wizard-metrics/artifacts/grid-controls/federal-foia-management/choice-views.json` |
| Original views preserved | All 19 Contact and 26 Case public views retain exact names, FetchXML, layouts, default/managed flags; only one new view per table | `.wizard-metrics/artifacts/grid-controls/federal-foia-management/original-view-preservation.json` |
| Grid regression tests | Eight isolated suites passed; JSON validation parsed 88 documents and matched 61 payload schemas | `.wizard-metrics/artifacts/grid-controls/federal-foia-management/regression-tests.json` |
| Unmanaged package | Grid ZIP SHA-256 `0243CE764FA103462585648FFA0911CEAACFFA3117B6FCB2CA89E3426A07D5D1`; all 162 labels/colors inspected; not approved for import | Session-storage ZIP path recorded as `zip` in export evidence |
| Unpacked package | 245 locally inspected files | Session-storage folder recorded as `unpacked` in export evidence |

Runtime artifacts under `.wizard-metrics/` are local execution evidence and are
not required to be committed. The deployment manifest preserves the durable,
sanitized summary.

Authenticated grid smoke testing confirmed pastel-filled symbol labels in
Request, Contact, and Case views. The new Case view showed seven values,
including Appealed (peach), Overdue (rose), Normal (blue), Expedited (yellow),
Fee (apricot), Exemption (blue), and Released (mint). The Contact overview
showed seven FOIA-related records and classification badges. Grid editing
remains disabled; these checks did not change records.

Authenticated published-app smoke testing confirmed Request dropdowns and saved
values for Intake Channel, Validation State, and Disposition, including all seven
channel options. This is not evidence of full journey completion or authorization
testing. Platform feature/licensing/telemetry warnings observed during the smoke
test remain unrelated follow-up items.

After the presentation increment, the reloaded Request showed prefixed labels
and all seven channel symbols. The original record remained Saved. Standard form
dropdown backgrounds were transparent; pastel metadata is verified, but visible
pastel fills depend on the control's support/settings. No grid-control change
was performed.

## Source-Control Checkpoints

| Commit | Purpose |
| --- | --- |
| `49cc130` | Federal FOIA scenario implementation |
| `3e2c430` | Strict membership and unmanaged export-gate verification |
| `bbef403` | Formal stage-85 idempotency verification |

No push or pull request has been performed.

## Open Evidence

- Security roles, field-security profiles, team/queue ownership, separation of
  duties, and positive/negative authorization tests
- Power Automate flows and external connector contracts
- SharePoint libraries, permissions, version/hash behavior, and release tracking
- Accessibility testing for forms, views, dashboards, and correspondence surfaces
- Performance and bounded-load results
- Complete normal, expedited, overdue, appealed, fee, exemption, and release
  journeys
- Annual/quarterly certified reporting runs and reconciliation
- Production operations, backup/recovery, retention, and agency-specific approvals
- Managed package, target import, release, push, pull request, and merge evidence
