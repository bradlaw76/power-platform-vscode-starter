# Federal FOIA Management Detailed Design

**Design ID:** `FOIA-DD-1.0`
**Status:** Approved architecture elaboration; publisher, unmanaged solution, 11 custom tables, 134 columns, 11 Active alternate keys, 21 relationships, two Active Business Process Flows, 13 wizard-owned main forms, 13 public views, eight rendering native charts, five dashboards, 41 deterministic synthetic records, and the published Federal FOIA Management review app and sitemap are created and independently verified under limited authorization; automation, security, export, and source-control stages remain incomplete or unauthorized
**Portability:** FedCiv GCC/GCC High first, DoD IL5 compatible
**Core dependency rule:** Azure is optional and disabled by default

## Design Boundaries

Dataverse is the authoritative transactional system. SharePoint is the
authoritative content repository and has an independent permission boundary.
Power Automate may notify and orchestrate but may not create controlled
approvals, rewrite clock history, or release content. Synchronous Dataverse
plug-ins enforce identifiers, state transitions, clock commands, immutable
events, separation of duties, and release-package version protection.

No tenant URL, environment ID, connection ID, user ID, credential, endpoint, or
secret is part of this design. All examples are synthetic.

## Stable Choice Contract

All choices are global unless a table-specific status reason is required.
Published numeric values are immutable: labels may be localized, but values
must never be reused. New values append above the current maximum.

### Shared Choices

| Choice | Stable value | Label |
| --- | ---: | --- |
| `foia_intakechannel` | 100000000 | Public portal |
|  | 100000001 | Agency portal |
|  | 100000002 | Email |
|  | 100000003 | Mail room |
|  | 100000004 | Staff assisted |
|  | 100000005 | FOIA.gov |
|  | 100000006 | API |
| `foia_validationstate` | 100000000 | Pending |
|  | 100000001 | Valid |
|  | 100000002 | Correction required |
|  | 100000003 | Rejected |
| `foia_requestlifecycle` | 100000000 | Intake |
|  | 100000001 | Clarification |
|  | 100000002 | Search |
|  | 100000003 | Review |
|  | 100000004 | Redaction |
|  | 100000005 | Approval |
|  | 100000006 | Release |
|  | 100000007 | Closure |
| `foia_taskstate` | 100000000 | Draft |
|  | 100000001 | Ready |
|  | 100000002 | Assigned |
|  | 100000003 | In progress |
|  | 100000004 | Blocked |
|  | 100000005 | Submitted |
|  | 100000006 | Completed |
|  | 100000007 | Cancelled |
| `foia_approvalstate` | 100000000 | Draft |
|  | 100000001 | Proposed |
|  | 100000002 | Pending independent approval |
|  | 100000003 | Approved |
|  | 100000004 | Rejected |
|  | 100000005 | Returned |
|  | 100000006 | Superseded |
| `foia_reviewtype` | 100000000 | Responsiveness |
|  | 100000001 | Segregability |
|  | 100000002 | Legal |
|  | 100000003 | Supervisory |
|  | 100000004 | Final release |
| `foia_disposition` | 100000000 | Full grant |
|  | 100000001 | Partial grant |
|  | 100000002 | Full denial |
|  | 100000003 | No records |
|  | 100000004 | Withdrawn |
|  | 100000005 | Duplicate |
|  | 100000006 | Other closure |
| `foia_feecategory` | 100000000 | Commercial |
|  | 100000001 | Educational or scientific |
|  | 100000002 | News media |
|  | 100000003 | Other |
| `foia_clockeventtype` | 100000000 | Received |
|  | 100000001 | Perfected |
|  | 100000002 | Toll started |
|  | 100000003 | Toll ended |
|  | 100000004 | Extension applied |
|  | 100000005 | Due date recalculated |
|  | 100000006 | Appeal received |
|  | 100000007 | Appeal due date calculated |
|  | 100000008 | Closed |
|  | 100000009 | Correction |
| `foia_auditaction` | 100000000 | View sensitive content |
|  | 100000001 | Download |
|  | 100000002 | Export |
|  | 100000003 | Package inclusion |
|  | 100000004 | Approval |
|  | 100000005 | Release |
|  | 100000006 | Permission change |
|  | 100000007 | Configuration change |
| `foia_adapterstatus` | 100000000 | Disabled |
|  | 100000001 | Ready |
|  | 100000002 | Running |
|  | 100000003 | Succeeded |
|  | 100000004 | Unavailable |
|  | 100000005 | Failed |
| `foia_aidisposition` | 100000000 | Pending human review |
|  | 100000001 | Accepted |
|  | 100000002 | Rejected |
|  | 100000003 | Superseded |

## Business Process Stage And Field Contract

- The request and appeal BPF chevrons are authoritative for the interactive process position.
- After migration approval, `foia_lifecyclestagechoice` and `foia_stagechoice` are the reporting/view/sample-data projections; original String columns remain rollback data. Neither projection is repeated as a step in every BPF stage.
- Due Date, Disposition, and Outcome can appear in multiple stages as contextual references to one underlying value on the current record. Their reuse does not create duplicate columns or records.
- Search Tasks, Responsive Records, Review Tasks, Exemption Decisions, Redaction Decisions, Release Packages, Clock Events, and Audit Events retain the detailed operational evidence rather than duplicating it on the parent process record.
- The request process has 8 stages, 16 entry/exit criteria, and 13 steps. The appeal process has 6 stages, 12 entry/exit criteria, and 10 steps.
- Both category-4 processes are Active and verified as component type 29 members of `FederalFOIAManagement`. Their named Request and Appeal forms are verified; app linkage is deferred to stage 62.
- Stage 60 created a separate wizard-owned main form for each of the 13 payload-referenced tables and implemented all 13 explicit view contracts. Request and Appeal use `FOIA Request Main` and `FOIA Appeal Main`; the other tables retain `Starter Main Form`. Every form and view passed its minimum four-business-field/column gate, and the verification rerun skipped all 26 surfaces without metadata updates.
- Stage 64 created eight native Dataverse chart records and five dashboards from the approved reporting payload. Visual inspection first caught an incomplete dashboard-control contract; the dashboards were replaced with complete native controls containing `VisualizationId`, `ViewId`, `TargetEntityType`, and `ChartGridMode=Chart`. A second repair aligned each chart type to an exact working Dataverse presentation template, kept `groupby_column` and `aggregate_column` in FetchXML, and removed the invalid category alias. After stage 66 populated the source tables, the operator confirmed that all charts render in the published app. Structural membership remains valid—four charts are inherited through include-all table root components, four charts are explicit component-59 members, and all dashboards are explicit component-60 members.
- Stage 62 created and published the `Federal FOIA Management` review app with FOIA Request first, Active FOIA Requests as its landing view, all 13 custom/reused table navigation entries, a generated five-link Dashboards group, both BPFs, all eight charts, and all five dashboards. The app module and sitemap are explicit solution components, platform validation passes, and a rerun preserves both IDs.
- Stage 66 created 41 explicitly approved synthetic records across 13 tables, including seven Contacts and seven Cases. Every record carries the scenario source tag, Case records reference their synthetic Contact and FOIA Request, and the second pass updated the same 41 stable IDs without creating duplicates.

### Table Status Reasons

Dataverse state remains Active (`0`) or Inactive (`1`). Status reasons use these
stable values and must align with the shared business state:

| Table | Active status-reason values | Inactive status-reason values |
| --- | --- | --- |
| FOIA Request | `100000000` Intake; `001` Clarification; `002` Search; `003` Review; `004` Redaction; `005` Approval; `006` Release | `100000007` Closed; `008` Withdrawn; `009` Administratively closed |
| Search Task | `100000000` Draft; `001` Ready; `002` Assigned; `003` In progress; `004` Blocked; `005` Submitted | `100000006` Completed; `007` Cancelled |
| Responsive Record | `100000000` Collected; `001` Processing; `002` In review; `003` Approved for package | `100000004` Released; `005` Superseded; `006` Removed by controlled correction |
| Review Task | `100000000` Draft; `001` Assigned; `002` In progress; `003` Blocked; `004` Submitted | `100000005` Completed; `006` Cancelled |
| Exemption/Redaction Decision | `100000000` Draft; `001` Proposed; `002` Pending independent approval; `005` Returned | `100000003` Approved; `004` Rejected; `006` Superseded |
| Release Package | `100000000` Draft; `001` Assembling; `002` Pending approval; `003` Approved | `100000004` Released; `005` Superseded; `006` Cancelled |
| Appeal | `100000000` Intake; `001` Validation; `002` Reconsideration; `003` Decision; `004` Response | `100000005` Closed; `006` Withdrawn |
| Clock/Audit Event | `100000000` Recorded | No ordinary inactive transition |
| AI Assistance Record | `100000000` Pending human review | `100000001` Accepted; `002` Rejected; `003` Superseded |

Values shown as `001` through `009` abbreviate the shared `100000` prefix in
that row. Payloads must contain the full integer.

## Controlled State Transitions

Only listed transitions are valid. Plug-ins validate current state, target
state, actor privileges, required fields, and optimistic-concurrency version.

### FOIA Request

`Intake -> Clarification|Search|Closure`
`Clarification -> Search|Closure`
`Search -> Review|Clarification|Closure`
`Review -> Redaction|Approval|Search|Closure`
`Redaction -> Approval|Review`
`Approval -> Release|Review|Redaction`
`Release -> Closure`
`Closure -> Intake` only through a Records Officer-approved reopen command that
creates an Audit Event and preserves the original closure/reporting facts.

Entry rules:

- Search requires a perfected date, current due date, requester, tracking number,
  scope statement, and at least one active Case.
- Redaction requires responsive records and completed responsiveness review.
- Approval requires all required reviews submitted and all proposed decisions
  independently actioned.
- Release requires an approved, fixed package manifest and a Release Officer
  different from controlled-decision proposers.
- Closure requires a disposition, closure date, final correspondence reference,
  and no unexplained open mandatory task.

### Tasks And Decisions

- Tasks: `Draft -> Ready -> Assigned -> In progress -> Submitted -> Completed`.
  `Assigned|In progress -> Blocked -> In progress`; cancellation requires reason.
- Decisions: `Draft -> Proposed -> Pending independent approval ->
  Approved|Rejected|Returned`; `Returned -> Draft`; approved decisions may only
  become `Superseded` by a new linked decision.
- AI: `Pending human review -> Accepted|Rejected|Superseded`; accepted output is
  copied only by an authorized human command that runs controlled-field guards.

### Release Packages

`Draft -> Assembling -> Pending approval -> Approved -> Released`.
`Pending approval -> Assembling` on return. `Approved -> Assembling` is forbidden;
a change creates the next version. `Released -> Superseded` only when a newer
released correction references it. Released content and its manifest are locked.

### Appeals

`Intake -> Validation -> Reconsideration -> Decision -> Response -> Closed`.
Validation may return to Intake. Decision may return to Reconsideration.
Withdrawal may occur before Closed and requires actor, reason, and correspondence.

## Business Rules And Server Enforcement

| Rule ID | Enforcement |
| --- | --- |
| BR-001 Identifier allocation | Pre-create synchronous plug-in allocates tracking/task/decision/appeal/event IDs; alternate key rejects duplicates. |
| BR-002 Request validation | Accepted intake requires channel, requester, received time, scope, attachment validation, and validation result. |
| BR-003 Perfection | Perfection command requires validated scope and creates a Clock Event; direct perfected/due-date edits are denied. |
| BR-004 Duplicate handling | Candidate match may create a review task; it cannot merge, close, or alter scope. |
| BR-005 Task completion | Required scope, evidence, result/disposition, completion time, and actor must be present. |
| BR-006 Independent approval | Proposer, reviewer, and final approver constraints are evaluated from immutable user IDs; bypass by flow/application identity is denied. |
| BR-007 Clock authority | Due dates are projections from ordered Clock Events and versioned calendar configuration; direct history changes are denied. |
| BR-008 Package integrity | Pending approval freezes inclusion rows and computes manifest hash; changed content invalidates approval and requires a new version. |
| BR-009 Release | Only Release Officer command may release; it records package hash, method, recipient classification, actor, and UTC time. |
| BR-010 Immutable events | Clock/Audit Events deny update, delete, deactivate, merge, assign, and ordinary import overwrite. Corrections append linked events. |
| BR-011 SharePoint boundary | A repository reference is usable only when access state is verified independently; Dataverse access never grants document access. |
| BR-012 Export | Export requires purpose and scope, emits an Audit Event, and omits protected fields unless the actor has explicit privilege. |
| BR-013 AI guard | Application/AI identities cannot write controlled decision, approval, scope, clock, package, or released-content fields. |
| BR-014 Azure independence | Optional adapter status `Disabled`, `Unavailable`, or `Failed` cannot block core intake, search tracking, review, release, appeal, clock, audit, or report operations. |

Client business rules may improve usability but are never the only enforcement
for security, approvals, identifiers, clocks, immutability, or release.

## Table Ownership And Keys

| Table | Ownership | Alternate/business key | Ordinary delete |
| --- | --- | --- | --- |
| FOIA Request | User/team | Tracking number | Denied after acceptance; close instead |
| Search Task | User/team | Search task number | Denied after submission |
| Responsive Record | User/team | Record identifier | Denied after review/package use |
| Review Task | User/team | Review task number | Denied after submission |
| Exemption Decision | Organization | Decision number | Denied after proposal |
| Redaction Decision | Organization | Redaction number | Denied after proposal |
| Release Package | Organization | Request + package number + version | Always denied after approval |
| Appeal | User/team | Appeal number | Denied after validation |
| Clock Event | Organization | Event ID | Always denied |
| Audit Event | Organization | Event ID | Always denied |
| AI Assistance Record | Organization | Assistance ID | Denied after disposition |

Case and Contact retain standard ownership. Owner teams represent program
offices; access teams grant temporary cross-office collaboration. Queues route
work but do not replace record ownership. Sharing is time-bounded, justified,
audited, and revoked when the task or appeal ends.

## Calendar And Time Contract

- Store event instants in UTC; retain source time-zone ID and submitted offset.
- Store statutory dates as date-only when the governing rule is date based.
- Calendar configuration has immutable ID/version, effective range, weekend
  pattern, holiday dates, jurisdiction, and approval metadata.
- Event replay orders by effective UTC, event sequence, then immutable event ID.
- A late-arriving correction appends a Correction event and triggers recalculation;
  it never edits earlier events.
- Report runs record the calendar version used.

## Document Contract

Dataverse stores repository kind, environment-neutral location key, library key,
item ID, item version, media type, byte size, SHA-256 hash, classification,
malware state, access-verification state/time, and source provenance. It does
not store SharePoint credentials or tenant URLs in source-controlled payloads.

Package manifests contain ordered record IDs, repository item versions, hashes,
decision versions, and correspondence hash. Manifest hashes use UTF-8 canonical
JSON with lexicographically sorted object keys and SHA-256.

## Retention And Legal Hold

Stable classes are:

| Class | Applies to | Default behavior before agency schedule mapping |
| --- | --- | --- |
| `FOIA-RC-CASE` | Request, Case extensions, tasks, decisions, appeal, correspondence metadata | Retain; no automated deletion |
| `FOIA-RC-RELEASE` | Released packages, manifests, released content references | Immutable; retain; corrections add versions |
| `FOIA-RC-CLOCK` | Clock Events and calendar versions | Immutable; retain |
| `FOIA-RC-AUDIT` | Audit Events, exports, approvals, permission/configuration changes | Append-only; retain |
| `FOIA-RC-SOURCE` | Responsive source/working records | Retain; disposition only by approved records schedule |
| `FOIA-RC-AI` | AI input classifications, source references, output, and disposition | Retain with related case unless a stricter approved schedule applies |
| `FOIA-RC-TEST` | Clearly synthetic fixtures and sanitized test evidence | Delete only under approved non-record test-data procedure |

Deployment is blocked until the Records Officer maps each class to an approved
agency/NARA disposition authority, cutoff trigger, duration, and action. A blank
mapping means indefinite retention, not permission to delete. Legal hold,
litigation hold, appeal, investigation, preservation notice, and pending records
transfer suspend disposition. Holds are additive; release requires authorized
Records Officer action and an Audit Event. No rollback deletes or shortens the
retention of legal/immutable records.

## Azure-Disabled Acceptance Path

With every `AZ_*_ENABLED=false` and no Azure connection or endpoint:

1. All intake channels normalize through local/manual or approved core adapters.
2. Dataverse performs validation, identifiers, workflow, clocks, approvals, and
   event recording.
3. SharePoint stores documents using its approved connection reference.
4. Power Automate sends core notifications through approved Microsoft 365
   connections.
5. Native views, charts, dashboards, and versioned report calculations run from
   Dataverse and immutable events.
6. AI/OCR/search adapters return explicit `Disabled`; no core step waits for them.

This path is the mandatory release gate for GCC High and IL5 portability.
# Choice migration preparation — 2026-10-20

NOT deployed. Historical deployment paragraphs above remain historical evidence.
The machine-readable `choices-federal-foia-management.json` contract defines
new side-by-side columns; original String metadata remains unchanged.
Stable shared Choice values below are preserved. Table-specific enums append
explicit contracts where no shared domain exists (especially review findings,
appeal outcomes, package state and redaction state).
Request `Open` and appeal `Open` explicitly mean null final outcome, not a grant.
`Responsive`, `Partial Exemption`, and `Approved for Release` are review findings,
never request disposition. `Educational` aliases Educational or scientific;
`Perfected` aliases Valid; clock event aliases retain their event semantics.
Free-text rationale, reason, detail, identifiers and user-defined classification
or source labels remain text unless an explicit controlled domain is declared.

Choice array position `i` defines the immutable integer `100000000 + i`.
Never reorder/remove entries; append new options only after semantic review.
Aliases explicitly bind legacy text to those integers, including explicit null
for open request/appeal outcomes. Trimming/case-insensitive label matching is
allowed; fuzzy matching, default-to-other, and guessed outcomes are forbidden.
Shared global values match the Stable Choice Contract; the new table-specific
domains in the JSON are prepared contracts requiring operator review, not proof
of deployed metadata. They are business Picklists, not replacements for native
`statecode`/`statuscode`; the separate status-reason table above is unchanged.

Scope is the 21 fields listed in the contract. User-defined case-work labels,
collection source/custodian labels, repository/media classifications, access and
record-review evidence labels, release methods, provider/version and AI-operation
labels have no approved global finite domain in this contract and remain text.
These are explicit exclusions, not implicit guessed enum conversions. Free-text
appeal decision summaries, exemption authority/scope/rationale, redaction basis,
clock reason, and audit purpose/details also remain text.

### Prepared table-specific business Choice decisions

These are proposed migration domains for independent operator review, not
claims that native status reasons or deployed metadata have changed. The
contract's integer rule applies to every position, including appended values.

| Business Choice | Prepared labels in numeric order starting at 100000000 |
| --- | --- |
| `foia_expediteddecision` | Pending; Granted; Denied |
| `foia_reviewfinding` | Responsive; Non-responsive; Partial exemption; Approved for release; Returned for review |
| `foia_packagestate` | Draft; Pending approval; Approved; Released; Rejected; Returned; Superseded; Assembling; Cancelled |
| `foia_redactionstate` | Proposed; Approved; Rejected; Applied |
| `foia_appealstage` | Intake; Validation; Reconsideration; Decision; Response; Closed |
| `foia_appealoutcome` | Affirmed; Reversed; Partially affirmed; Remanded; Withdrawn; Other closure |
| `foia_clocktype` | Request; Appeal |

In particular, Package State is a business Picklist projected from legacy
`foia_approvalstate`, not the complete native package status/status-reason
contract. Assembling (`100000007`) and Cancelled (`100000008`) are explicit
prepared business values; their numbers do not mirror the native status-reason
numbers above. Rejected and Returned remain distinct prepared business states.
No real value outside these explicit labels/aliases is inferred or defaulted.

### Independently checked Appeal BPF mapping

`process-02-appeal.json` and `spec.md` define the display stages below.
Detailed design's controlled-state transition names are the canonical business
Choice labels; explicit aliases reconcile the display labels without guessing:

| BPF display stage (order) | Canonical business Choice | Integer |
| --- | --- | ---: |
| 1. Appeal Intake | Intake | 100000000 |
| 2. Validation | Validation | 100000001 |
| 3. Reconsideration and Legal Review | Reconsideration | 100000002 |
| 4. Appeal Decision | Decision | 100000003 |
| 5. Response | Response | 100000004 |
| 6. Closure | Closed | 100000005 |

Stage fields remain: intake = Appeal Number/Received Date/Challenged
Determination; validation = Due Date; reconsideration = Challenged Determination;
decision = free-text Decision plus `foia_outcomechoice`; response =
`foia_outcomechoice`; closure = `foia_outcomechoice` plus Closed Date.
`foia_stagechoice` is a reporting projection, not a repeated BPF step.
`foia_outcomechoice` uses the separate appeal-outcome domain and explicitly
maps legacy Open to null; it never derives an outcome from the stage.
Existing Active designer processes still require operator reauthoring and
field/step validation; changing this payload is not evidence of a deployed change.

Clock/Audit rows are preserved historical evidence, excluded from automatic
backfill and cutover row comparisons. Existing seed records on those tables
must never be patched by the seed rerun; newly created synthetic rows can use
the prepared Choice fields. This exclusion is not a claim that historical
categorical reports have been migrated.
Clock/Audit main forms therefore retain legacy evidence controls, explicitly
disabled and labeled `(Legacy evidence)`, beside the future Choice controls.
Existing legacy controls are relabeled/disabled on rerun rather than removed.
Their views retain both fields. The historical clock chart still groups nonnull
legacy event types; new Choice-only rows are not presented as migrated history.
All other tables use the normal legacy-control removal strategy.
