# Demo Dry Run: federal-foia-management

## Read-Only DEV Polish Diagnosis - 2026-11-05

Operator approved diagnosis/local planning only. Scoped authenticated GETs
confirmed:

- The existing FOIA app reports `clienttype=2`, state 0, status 1.
  Microsoft's documented legacy-app warning matches the observed banner; the
  proposed fix is supported app-properties conversion, not hiding the warning.
- The normal request `2fd97e59-1ac7-f111-aaae-001dd80753e2` remains
  `SYN-FOIA-2026-001`, source-tagged `federal-foia-synthetic-v1`, with lifecycle
  `100000003` / Review and validation Perfected.
- Its active process instance `30d97e59-1ac7-f111-aaae-001dd80753e2` points to
  Intake; its persisted traversed path contains only Intake. Review exists
  after Clarification and Search in the current active path. This is a real
  persisted-state mismatch, not just cached text.
- Clarification due date is null. A future alignment must honor the native stage
  gates and stop rather than inventing a date or bypassing requiredness.

No mutation, stage navigation, app conversion, publication, export, or commit
was performed. Console causes remain undiagnosed; conversion is not promised to
remove unrelated errors. This was not a fresh full click-through or timed
narration. See the [bounded fix preview](plan.md#bounded-dev-polish-preview---2026-11-05)
for independent approvals, preconditions, verification, and recovery limits.
The 2026-11-04 UI observations below remain dated evidence.

## Current Readiness - 2026-11-04

Status: authorized read-only UI check completed with presentation gaps; the
timed narrated rehearsal is not run. This is not a clean-console pass, full
journey test, fresh deployment/export verification, or production acceptance.
The date is local; browser event timestamps are 2026-11-05 UTC.

- [x] Obtain explicit read-only DEV/browser authorization; operator completed Microsoft sign-in manually.
- [x] Open the published app and navigate `FOIA Operations` -> `FOIA Requests` -> `Active FOIA Requests`. The app initially resumed the operations dashboard; explicit request navigation worked. This does not certify fresh-session landing behavior.
- [x] Find `SYN-FOIA-2026-001` / `Synthetic Normal Request`; inspect tracking, lifecycle, validation, due date, acknowledgment reference, disposition, and Choice labels. Open the seven-option Intake Channel list and dismiss it without selecting; the record remains Saved.
- [x] Inspect related lists: `Synthetic FOIA Case 1`, `Synthetic Normal Search`, `Synthetic Normal PDF`, and `Synthetic Normal Review` each appeared under the normal request. The initially loading Responsive Records grid was rechecked after rendering and showed one row, not an empty-data failure.
- [x] Inspect expedited `SYN-FOIA-2026-002` (`Search`, `Granted`) and released `SYN-FOIA-2026-007` (`Closure`, `Full grant`), both with the synthetic source tag. The released request's related list shows `Synthetic Released Package v1`; no external document was opened.
- [x] Open `Federal FOIA Operations`; both selected charts rendered data. Lifecycle counts: Redaction 1, Approval 1, Review 2, Search 1; expedited Granted count: 1. Compatibility and console issues below remain unresolved.
- [ ] Run the seven-minute presenter script; record actual elapsed time and navigation blockers.
- [x] Review the script locally to distinguish stored examples and historical counts from enforced policies, access tests, immutable evidence, and verified delivery. Actual spoken delivery remains part of the pending timed rehearsal.

### Current Observations And Presentation Gaps

- Target: `https://usfedfoia.crm9.dynamics.com`, existing Federal FOIA Management
  app `7ab66f1e-0ec7-f111-aaae-001dd80753e2`. Scope was the approved synthetic
  records, their associated lists, Choices, and two operations charts.
- The normal request's Lifecycle Stage field is `Review`, while its active
  business-process bar remains at `Intake`. Do not present them as synchronized
  or demonstrate stage advancement. No stage or record was changed.
- A visible legacy-web-client/Unified Interface compatibility banner appears.
  It is a presentation issue, not a proven failure of the inspected screens.
- Console observations include `Result is not PredictAPI`, a 400 response with
  `Column level security masking feature is not ready`, a resource 401, and
  a fingerprint-configuration CORS failure. Causes and wider impact were not
  diagnosed; do not call the run error-free or assume all messages harmless.
- This was a diagnostic click-through, not an uninterrupted narrated rehearsal.
  Actual presenter duration remains unmeasured; seven minutes is the script
  target. Other journey records, all 41 records, all dashboards, and assigned-role
  authorization were not comprehensively revalidated.
- The browser is left on `Synthetic Normal Request`, with Saved status observed
  after rendering. No record-edit/save, stage-change, message, role-change,
  external-document, build/seed/export, or deployment action was issued.

Next: rehearse the bounded prototype with these limitations disclosed, or obtain
separate approval for a targeted DEV polish plan and any resulting live changes.
Do not silently correct data/configuration under read-only approval.

## Historical Rehearsal Summary (Not Refreshed)
- Step: Open with the business problem
  Status: pass
  Note: Business framing is concise, outcome-first, and explicit about synthetic data and human authority.
- Step: Start from the hero record
  Status: partial
  Note: Published app identity, FOIA Request entry point, Active FOIA Requests landing view, and the live `SYN-FOIA-2026-001` record are verified. Interactive browser navigation remains pending because the automation browser sign-in window was inaccessible.
- Step: Walk through the core workflow
  Status: pass
  Note: Read-only Dataverse validation found all seven planned journey requests at their expected stages and all 41 source-tagged records exactly once, with no missing, extra, duplicate, or mismatched key records.
- Step: Show supporting experience
  Status: partial
  Note: Five published dashboards, eight native charts, app navigation, role metadata, and export membership are verified. Interactive chart and dashboard click-through remains pending with browser authentication.
- Step: Close with success and next step
  Status: pass
  Note: Closing now distinguishes verified demo capabilities from deferred flows, SharePoint, full production security, and server-side enforcement.

## Historical Overall Result
- Outcome: Deployed metadata and read-only live-data rehearsal passed. Authenticated UI click rehearsal remains pending and is not represented as passed.
- Requested edit: Complete one operator-driven click rehearsal using the exact navigation in `demo-script.md` when an accessible authenticated browser session is available.
