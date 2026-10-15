<!--
=============================================================================
COMPONENT:    Federal FOIA Management Evidence Index
FILE:         specs/federal-foia-management/evidence-index.md
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-14
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
| Strict solution membership | Export allowed; 232 already in solution; 0 failed; 0 missing; 0 unauthorized | `.wizard-metrics/artifacts/contamination/federal-foia-management/solution-membership-report.json` |
| Strict membership summary | Human-readable companion to the JSON report | `.wizard-metrics/artifacts/contamination/federal-foia-management/solution-membership-report.md` |
| Idempotency baseline | 673 identities captured before the controlled second pass | `.wizard-metrics/artifacts/idempotency/federal-foia-management/baseline.json` |
| Idempotency verification | Stable IDs true; duplicate count 0; failure count 0 | `.wizard-metrics/artifacts/idempotency/federal-foia-management/verification.json` |
| Reporting second pass | 13 native reporting surfaces skipped with stable identities | `.wizard-metrics/artifacts/reporting/federal-foia-management.json` |
| Synthetic-data second pass | 41 existing records updated; no duplicate candidates | `.wizard-metrics/artifacts/data/federal-foia-management.json` |
| App-module validation | Published review-app identity, component linkage, and platform validation | `.wizard-metrics/artifacts/app-module/app-module-validation.json` |
| Navigation validation | FOIA Request entry point, landing view, five dashboard links, and table navigation | `.wizard-metrics/artifacts/app-module/navigation-summary.json` |
| Export inspection | 24 expected root components matched; 0 missing; 0 unrelated; import not permitted | `.wizard-metrics/artifacts/export/federal-foia-management.json` |
| Unmanaged package | Exported development package; not approved for import | `.wizard-metrics/exports/federal-foia-management/FederalFOIAManagement.zip` |
| Unpacked package | 214 locally inspected files | `.wizard-metrics/exports/federal-foia-management/unpacked/` |

Runtime artifacts under `.wizard-metrics/` are local execution evidence and are
not required to be committed. The deployment manifest preserves the durable,
sanitized summary.

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
