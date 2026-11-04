# Federal FOIA Management Implementation Plan

## Build Approach

- Wizard mode: `advanced-builder`
- Application profile: `dynamics-customer-service-extension`
- Initial environment family: FedCiv GCC/GCC High
- Portability requirement: DoD IL5
- Environment URL: `https://usfedfoia.crm9.dynamics.com`
- Environment selection: approved for authentication planning on 2026-10-06
- Authentication method: interactive browser sign-in
- Live authorization: authentication and GET-only readiness verification completed as an explicitly authorized exception on 2026-10-06
- Mutation authorization: prior bounded demo operations are recorded in the deployment manifest; no new live operations are authorized by the 2026-11-04 planning request
- Solution unique name: `FederalFOIAManagement`
- Solution display name: Federal FOIA Management
- Publisher prefix: `foia`
- Solution output: unmanaged development solution; managed release artifact later
- Original source branch: `feature/federal-foia-management`; current local branch: `feature/federal-foia-choice-normalization`
- Current gate: review and preserve the uncommitted demo increments, approve the production-hardening design and unresolved policy decisions below, then obtain separate operation-specific live authorization. Earlier implementation sections retain historical sequencing and do not authorize replay of completed mutations.

## Production-Hardening Increment - 2026-11-04

**Status:** Proposed; planning updates requested, implementation and release not
approved. No delivery estimate is committed before the remaining decisions and
dependencies are resolved.

### Readiness Review

This is a local readiness review of status, scenario evidence, and pending runtime
integration changes, not a complete line-by-line audit or a fresh live test.

| Area | Finding | Required disposition |
| --- | --- | --- |
| Recorded development build | Latest live evidence is 2026-10-22: 263 memberships, 706 stable identities, 53/53 export roots, 41 synthetic rows; no production import or managed release | Preserve evidence; revalidate only after separate authorization |
| Pending source work | Choice migration, global-Choice styling, native grid verification, schema/seed overlays, inventory/export gates, resilience fixes, tests, and planning changes remain modified or untracked | Review explicit file groups, run isolated credential-free regression, and obtain checkpoint commit approval; do not stage everything |
| Clean-clone reproducibility | Stages 30 and 66 enable the approved Choice overlay when matching local Apply evidence exists; original String/label payloads remain the rollback source | Block fresh-target promotion until an approved versioned effective schema/data contract is reproducible without another environment's local Apply evidence; retain rollback sources |
| State documentation | Older plan headings described the pre-build gate; some checkboxes combine completed role metadata verification with unperformed access tests | Treat dated evidence as historical, distinguish metadata proof from behavior, and retain outstanding functional tests |
| Business behavior | Clock, identifier allocation, controlled approval/release, immutable guards, flows, queues/SLAs, and SharePoint work remain open | Implement and test in dependency order; BPF activation and populated sample fields do not prove enforcement |
| Production authorization | Current manifest targets DEV, managed release/import is not approved, and demo roles have no assignments | Require separate test/prod boundary, security, ALM, and operational approvals; do not reuse historical demo approval |

The table above records the initial review findings before the approved local
fix. It is not a claim that the old evidence-dependent selection remains the
current implementation; see the implementation results below.

### PH-00 Local Verification Results - 2026-11-04

Created an isolated source snapshot containing 273 tracked/untracked project
files, excluding credentials, runtime evidence, Git history, and local test
output. Its separate Git root has an inert non-framework remote; no remote
requests, staging, or commits were performed. Tests that write scenario evidence
ran only in that copy. SHA-256 comparison confirmed all 286 original
`.wizard-metrics` files remained unchanged.

| Validation | Result and boundary |
| --- | --- |
| Choice migration Preview, Apply/rollback, dependency preparation, exact verification, presentation | Five credential-free suites passed with mocked transports; no live migration performed |
| Grid views and exported grid-control verification | Both suites passed, including rerun and existing-view preservation fixtures |
| Solution isolation, wizard hardening, idempotency/export, form population | Four suites passed in the isolated copy; no real export or live metadata operation |
| JSON, contract integrity, documentation consistency, FOIA traceability | Four suites passed; 89 JSON documents parsed, 61 payload schema matches, 300 catalog and 84 profile IDs validated |
| Request runtime | Pester 5.7.1: 19 passed, zero failed/skipped; includes 401 refresh, 429/native Retry-After, transient transport errors, scoped publishing, and collision checks |
| Fresh-source reproducibility probe | Blocker reproduced: no credentials/Apply evidence, automatic overlay absent, 29 rollback String bindings; explicit contract resolution yields 26 global Choices and 29 Picklists without network calls |

This is 15 selected standalone suites plus 19 runtime tests, not the complete
repository CI, a full review of every untracked implementation, or live
functional/security validation. The explicit converter probe does not prove a
fresh target can provision global Choices, create/bind columns, seed numeric
values, or pass inventory/export gates end to end.

Pending files were grouped without staging: 18 framework runtime/schema/profile,
12 validation, 17 scenario payload/spec/evidence, 11 guidance, and one local
`testResults.xml` output. This grouping is a review manifest, not an instruction
to commit whole groups. Keep generated test output out of source checkpoints;
review framework/scenario dependencies together and request explicit commit
approval only after the reproducibility fix and applicable regression pass.

The recommended next design decision is a checked-in, versioned declaration of
the current effective Choice schema/data contract, independent of migration
execution evidence. Preserve the existing String/label rollback sources and
destructive migration approvals. Normal schema/seed/inventory/export consumers
must agree on that declaration, validate supported global-Choice creation and
bindings, and reject incompatible existing metadata rather than deleting or
converting it automatically. Pre-migration backup must remain possible through
an explicit reviewed path. Local implementation requires approval; none has been
performed at this checkpoint.

The operator subsequently approved local implementation on 2026-11-04. Add a
versioned `CurrentSchema` identity declaration to the existing Choice contract,
with scenario, solution, and publisher binding. Normal stages 30/50/66/95 must
select it without requiring Apply evidence; existing migration evidence remains
validated when present and never becomes portable authorization. Stage 30 must
preflight existing field types/bindings, create only missing compatible global
Choices, and never convert existing text columns. Stage 66 must preflight types
and map values before writes. Strict inventory/export must use the same contract.
Provide explicit `PreMigrationBackup` selection for reviewed legacy backup while
retaining mandatory checks when successful Apply evidence or Choice membership
exists. Preserve destructive stage-36 approvals and original rollback payloads.
All verification uses credential-free isolated fixtures, not a live target.

### PH-00 Effective-Contract Implementation Results - 2026-11-04

- Implemented the approved `CurrentSchema` version `1.0.0` identity declaration
  and shared contract selection for stages 30/50/66/95. Ordinary current-schema
  operation no longer requires local Apply evidence; present evidence is still
  validated, and legacy payload selection retains its previous evidence gate.
- Stage 30 preflights existing categorical metadata before mutations, validates
  existing global Choices, creates only missing compatible Choices/columns,
  binds by metadata GUID, records metadata IDs, and publishes the selected
  entities/Choices. It never deletes or converts an existing text column.
- Stage 50 explicitly adds/rechecks missing global-Choice membership and records
  IDs. Stage 66 resolves every input label/numeric value before transport and
  validates live types/bindings/options before writes. Strict inventory/export
  checks use the same selected contract.
- `PreMigrationBackup` explicitly selects the legacy backup path. Stage 50
  restricts it to read-only inventory; required Choice checks, successful Apply
  evidence, and exported global-Choice memberships cannot be bypassed.
  Original String/label payloads and stage-36 destructive authorization remain.
- Fresh-source isolated mocks passed: 26 global Choices and 29 GUID-bound
  Picklists created; schema rerun issued no metadata writes other than scoped
  publication; all 97 populated values were numeric; all 41 seeded row IDs
  remained stable. Preview, wrong identity, incompatible field type, unmapped
  seed, and backup non-bypass gates passed without fabricated Apply evidence.
- All 20 selected standalone suites passed, including legacy migration/rollback,
  reporting/data, alternate keys, preview nonmutation, forms/grids, inventory,
  package gates, and docs/contracts/traceability. Runtime Pester: 19 passed,
  zero failures/skips. PowerShell syntax and pinned ScriptAnalyzer 1.24.0 passed
  for eight implementation/test files. JSON: 89 documents, 61 schema matches.
  All 286 original runtime-evidence file hashes remained unchanged.

These are local implementation and mocked validation results, not current live
metadata verification, a full source review/full CI result, production-readiness
certification, or clean-target deployment evidence. Source checkpoint approval,
remaining implementation review, and all later policy/live/release gates remain
open. No authentication, live writes, real export/import, commit, or push.

### PH-00 Full Local CI And Review Blockers - 2026-11-04

The full credential-free Windows CI equivalent passed in a separate source
copy: 81 PowerShell files parsed without errors; ScriptAnalyzer 1.24.0 reported
zero findings under the repository's configured rules; all 32 standalone suites
and all 91 Pester tests passed, with no failed/skipped/not-run tests. Pinned
markdownlint-cli2 0.18.1 checked all 93 Markdown files with zero errors.
This is not hosted Linux CI, live Dataverse validation, or a security audit.
SHA-256 and count checks confirmed all 286 original runtime-evidence files
remained unchanged.

The broader pending-source review is blocked, not signed off. Two additional
isolated transport probes reproduced defects in the existing destructive
migration path that the passing suites do not cover:

| Blocker | Source and reproduction | Required correction before checkpoint approval |
| --- | --- | --- |
| Stale snapshot overwrites current values | Stage 36 checks live ownership/mappings, but does not compare current rows/values with the snapshot before deleting columns. A valid post-Snapshot edit was overwritten: expected `100000000`, restored stale `100000003`; the mocked Apply issued 237 mutations and reported success | Compare complete binding/row/value cohorts before any mutation; reject stale, missing, added, or changed data and require a refreshed snapshot. Document an approved write-quiescence boundary because a preflight alone does not close concurrent-write races |
| Pagination omits data and ownership checks | Stage 36 `Get-ChoiceRows` reads only `.value`. Snapshot reported success while ignoring all 29 advertised next pages in the probe | Follow and validate all next links for Snapshot and Apply preflight; reject out-of-scope/unmapped rows on any page; add multi-page and late-page failure tests |

These are local mock reproductions, not evidence that the historical DEV
migration lost data. No repository implementation was changed during this
review, no live request was made, and no files were staged or committed.
Obtain approval for the additional local migration-safety fixes, rerun affected
regressions, then resume the remaining pending-source review. PH-00, checkpoint
approval, PH-01 execution design, and every live/release gate remain open.

Proposed checkpoint boundaries remain explicit: separate framework
runtime/schema/tests/guidance from scenario payload/planning/evidence changes,
while keeping dependent changes aligned. Exclude credentials, runtime metrics,
generated packages/raw output, and the pre-existing local `testResults.xml`.
Do not stage all pending files or request a release checkpoint on the basis of
the green test suite alone.

### PH-00 Approved Migration-Safety Corrections - 2026-11-04

The operator subsequently approved local fixes and regression tests for both
review blockers, without authorizing live access, destructive execution,
staging, commits, push, or deployment.

- Stage 36 now reuses the paged collection reader with checks for page shape,
  repeated pages, target environment, and exact collection. Snapshot and Apply
  validate ownership and mappings across every page, including empty cohorts.
- Before any mutating request, Apply requires complete snapshot bindings and
  compares exact populated row IDs/text values, numeric mappings, attribute
  metadata IDs, entity-set/primary-ID identities, and rollback definitions.
  Stale, incomplete, duplicate, or inconsistent data fails closed and requires
  a refreshed Snapshot.
- Stateful regression coverage uses one-row pages and verifies all 97 values.
  It rejects first/late-page edits, cleared/deleted/added/duplicate rows,
  replaced attributes, malformed/incomplete snapshot bindings, altered restore
  mappings/definitions, late-page foreign/unmapped rows, malformed pages,
  cross-environment/collection links, and paging cycles without mutations.
  Healthy Apply/Verify, rerun, empty Snapshot, and rollback remain covered.
- Onboarding now requires an independently established write freeze from
  Snapshot through Apply and Verify. The script does not implement a lock or
  transaction; preflight alone does not protect against concurrent writers.

The complete CI baseline above predates these corrections. Post-correction
validation runs the eight affected standalone suites, syntax and pinned
repository ScriptAnalyzer for the three affected PowerShell files, documentation
consistency, and Markdown lint for the edited guidance/planning files. Record
their final outcome in the build log; do not describe the earlier full run as
a new full-suite or live run. Resume remaining pending-source review before
checkpoint commit approval; PH-00 and production release remain open.

### PH-00 Final Grouped Source Review - 2026-11-04

Completed the remaining checkpoint-oriented source review across 59 pending
paths: 18 framework runtime/schema/profile files, 13 validation files, 17
scenario payload/planning/evidence files, and 11 guidance files. Historical
manifest/report evidence remains dated October 22; production, managed-package,
commit, and push authorizations remain false. All 26 Choices appear in the
design, the reporting filter uses the approved numeric value, and presenter
guidance distinguishes seeded demo surfaces from unimplemented enforcement.
This is not a full business/security audit, hosted Linux run, or live validation.

Four additional issues were reproduced without live access:

| Priority | Finding | Reproduction and required disposition |
| --- | --- | --- |
| P1 | Existing global Choice definitions are not checked before destructive Apply | A mocked existing Choice with a wrong English label was reused; Apply converted all 29 fields, made 211 mutating mock requests, and reported success. Only subsequent Verify rejected it. Preflight every existing definition and metadata identity before creating components or deleting columns; reject value/label/color/type drift without writes |
| P2 | Exported FOIA view filter verification checks presence, not mandatory scope | Both exported views passed with an OR filter allowing rows without the FOIA marker. Require the marker condition in a mandatory primary-table conjunction and add broadened/aliased-filter rejection tests; this is not evidence of a live access-control breach |
| P2 | Dependency-preparation test assumes `TEMP` exists | An isolated process with `TEMP` unset exited 1 before tests ran. Use the existing cross-platform `[IO.Path]::GetTempPath()` pattern and verify the unset-variable case; no hosted Linux failure is claimed |
| P3 | New wizard skill has six broken repository-relative links | All six `../../` links resolve under `.github`, not repository root. Correct the relative depth and verify every local Markdown link resolves |

Checkpoint sign-off is blocked on these corrections and their regression
evidence. The previous stale-snapshot/pagination fixes remain intact; the
passing suites did not cover these additional cases. Request one consolidated
approval for local corrections/tests only. No commit, push, live migration,
role assignment, deployment, or import is authorized.

Candidate checkpoint scope is the explicit 59-path review manifest, not all
workspace files. Preserve framework/scenario dependencies together. Exclude
the pre-existing local `testResults.xml`, credentials, runtime metrics, raw
exports/unpacked output, and session-only probe artifacts. A limited structured
credential-key check found no nonempty credential fields in pending JSON;
that check is not a comprehensive secret scan or redistribution approval.

### PH-00 Approved Final Corrections - 2026-11-04

The operator approved all four local corrections and validation, without
authorizing live access, destructive execution, staging, commit, push, or
deployment. Implemented:

- Stage 36 preflights every existing global Choice's exact metadata, options,
  rendered English labels/colors, and metadata identity before any mutation.
  Missing Choices are created only afterward and read back before column
  replacement. Existing compatible definitions are reused, not overwritten.
- Exported FOIA views must place the primary-table marker in a mandatory AND
  condition; OR-only, nested-OR-only, or related-alias guards are rejected.
  Legitimate mandatory primary-table conjunctions remain supported.
- Dependency preparation uses the cross-platform temporary-path helper.
- All six new skill links resolve to the repository root; the existing
  documentation suite now checks those relative targets.

Targeted tests passed: migration Apply/Verify/rerun/rollback with seven new
existing-definition drift gates; grid verification with fourteen negative
gates and a valid explicit-AND case; documentation with the old broken links
rejected and corrected links accepted; dependency preparation with `TEMP`
explicitly unset. The earlier stale-snapshot/pagination tests remain included.
Fresh full Windows checkpoint validation passed against the isolated current
source: 81 PowerShell files parsed, zero findings under the repository's pinned
ScriptAnalyzer settings, all 32 standalone suites, all 91 Pester tests (zero
failed/skipped/not run), and Markdown lint over all 88 current source Markdown
files. A result-capture redirection initially omitted Pester counters from the
summary; a rerun asserted the actual result object and confirmed 91/91 passing.
This is not hosted Linux CI, a comprehensive security audit, or live validation.

All 286 historical runtime-evidence files retain their original SHA-256 hashes.
The exact pending-source manifest matches the 60 paths below and whitespace
checks pass. No changes were staged or committed. The four review blockers are
resolved locally. The operator subsequently approved staging the exact reviewed
60 paths and creating one local checkpoint commit. Push/PR approval remains
separate; PH-01 policy/design decisions and every live production-release gate
remain open.

The proposed coherent checkpoint now contains 60 paths: 18 framework
runtime/schema/profile, 14 validation, 17 scenario payload/planning/evidence,
and 11 guidance. The additional path is the existing documentation test updated
for link coverage. Keep the framework/scenario dependencies together; exclude
credentials, runtime metrics, local test XML, raw packages/unpacked output,
and session-only probes. A source checkpoint is not a production release.

### Proposed Slice And Boundaries

Start with staff-assisted intake of one synthetic normal request through
validation/perfection, deterministic tracking and clock calculation, a related
Case/search/review, independent approval, and an authorized release of a versioned
synthetic SharePoint document. Use existing tables/forms/views where sufficient;
preserve the FOIA Request landing view and all original shared-table forms/views.
No new schema or relationship is approved here. Any required additions must first
update field-type and relationship decisions, payloads, and traceability.

Expedited, tolling/correction, overdue, fee, exemption/redaction, appeal, and
no-records paths remain mandatory later coverage, not implied by the normal path.
Tenant intake/collection/delivery connectors remain contract-only until approved.
Release requires real independent document authorization and verified delivery
evidence; a mock connector or success-shaped fallback cannot pass live acceptance.

### Milestones And Dependency Gates

Owner names below are existing persona/accountability roles, not assigned people.
Named owners and approvers must be confirmed before execution.

| Gate | Prerequisite | Scope and requirement linkage | Accountable role | Exit evidence |
| --- | --- | --- | --- | --- |
| PH-00 Source and reproducibility baseline | None; live work remains blocked | Review/split pending scenario and framework changes; make migrated effective payloads reproducible while preserving rollback contracts; FOIA-DAT-006, FOIA-ALM | Platform Product Owner | Explicit file manifest and approved commit checkpoints; isolated tests with live evidence untouched; clean-clone credential-free proof of all 26 Choices/29 Picklists and numeric seed mappings without borrowed Apply evidence; no blind destructive replay |
| PH-01 Approved execution design | PH-00 and decision register resolved | Finalize first-slice commands, plug-in registrations, identity/privilege checks, calendars, flow contracts, SharePoint boundary, configuration, and test fixtures; FOIA-ARC, FOIA-INT, FOIA-CLK, FOIA-SEC, FOIA-INTG | Platform Product Owner with FOIA Program Manager | Reviewed contracts and requirement mappings, named owners, approved thresholds and role matrix; refreshed DEV capability/authorization evidence only if separately approved |
| PH-02 Server-enforced foundation | PH-01 | Tracking allocation/uniqueness, required-input validation, clock commands/replay, protected projections, append-only Clock/Audit Events; BR-001/002/003/007/010, FOIA-INT-002/004, FOIA-CLK | Platform Product Owner | Unit tests plus separately authorized DEV integration; exact approved calendar results, concurrent allocation uniqueness, safe duplicate command replay, denied ordinary history/projection writes |
| PH-03 Controlled journey and documents | PH-02 | Case/search/review, proposer/approver separation, frozen package/version/hash, release authorization, explicit SharePoint permissions, bounded queues/routing/SLAs; BR-005/006/008/009/011, FOIA-CAS, FOIA-COL, FOIA-REV, FOIA-SEC | FOIA Operations Manager, FOIA Program Manager, Disclosure Office Lead | Different approved test identities; direct-API bypass denial; Dataverse access alone cannot open documents; changed package cannot retain approval; immutable release evidence; queue/SLA behavior matches authoritative dates |
| PH-04 Observable automation and slice rehearsal | PH-03; notification contracts designed in PH-01 | Acknowledgment, assignments, due alerts, approval/release notices, explicit delivery status and correlation; FOIA-INT-005, FOIA-INTG, FOIA-TST | FOIA Operations Manager | Normal journey completes with synthetic documents and Azure disabled; duplicate triggers do not duplicate logical actions; transient/permanent failures are visible and recoverable without false delivery/release success |
| PH-05 Remaining functional and production controls | PH-04 | All remaining journey variants, full ten-role/field/record model, certified reports, accessibility/performance, portability, recovery and operations; FOIA-RPT, FOIA-SEC, FOIA-TST, FOIA-ALM | FOIA Program Manager and Records and Compliance Officer | Complete mapped suites, signed metric reconciliation, agreed workload/latency thresholds, accessibility findings disposition, restore exercise and support ownership; no unapproved gaps |
| PH-06 Release candidate and promotion | PH-05 and separate release approval | Versioned managed package, clean validation/test import, environment variables/connection references, solution checker, approved backout and production cutover; FOIA-ALM | Platform Product Owner and designated release approver | Strict membership, stable rerun proof, sanitized package/hash/test evidence, approved managed build/test import, UAT sign-off, rollback rehearsal and post-release monitoring; production deployment separately authorized |

SharePoint operations and test-user role assignments each need their own reviewed
scope and authorization. Plug-ins and flows are new application components, not
capabilities assumed to exist in the metadata bootstrap scripts. Inventory and
solution-sync them explicitly and publish scoped changes. Continue to follow
[the onboarding sequence](../../docs/onboarding.md) for enabled metadata stages;
this milestone order does not replace that sequence or authorize build scripts.

### Acceptance Tests For The First Slice

| Test | Required observable result |
| --- | --- |
| PH-T01 Accepted/invalid intake | Required input and attachment policy are enforced server-side; invalid input has an actionable failure and no accepted-state/acknowledgment side effect |
| PH-T02 Tracking concurrency and replay | Every distinct accepted request has one unique tracking number; approved retry/replay preserves its identity; no duplicate event or acknowledgment for the same command |
| PH-T03 Clock calculation | Exact approved expected dates match calendar/time-zone/version fixtures, including weekend/holiday and daylight-saving boundaries; no unapproved statutory defaults |
| PH-T04 Clock/event tampering | Ordinary UI, API, flow, and application identities cannot forge clock projections or change/delete protected history; corrections append linked events and replay deterministically |
| PH-T05 Approval bypass | Self-approval, unauthorized transition, and automation bypass are rejected using trusted actor identity; valid independent approval records actor, decision/version, time, and correlation |
| PH-T06 Package integrity | Inclusion/content/version/hash changes invalidate approval under the approved transition contract; unapproved release is denied and ordinary edits to released content are denied |
| PH-T07 Document boundary | A user with Dataverse access but no SharePoint permission cannot read/download the item; approved access succeeds and emits the required audit evidence |
| PH-T08 Notification failure/retry | Repeated triggers produce one logical notification; retryable failures follow bounded policy and permanent or uncertain delivery remains explicitly unresolved; no fabricated success |
| PH-T09 Full normal journey | Authorized actors complete intake through release using a verified synthetic document, approved queues/SLAs, and real integration evidence with all optional Azure endpoints absent |
| PH-T10 Regression and packaging | Existing records/component IDs and unrelated shared-table surfaces remain stable except explicitly approved additions; strict inventory, membership, rerun and package checks pass |

Each result must retain the applicable profile and governing catalog IDs from
[requirement-traceability.md](requirement-traceability.md), test inputs,
expected/actual outputs, actor role, configuration/calendar version, correlation
ID, timestamp, and pass/fail disposition. Protect raw environment/user/document
identifiers outside source control; commit only sanitized evidence summaries.

### Decisions Required Before Implementation

| Decision | Required confirmation | Gate owner |
| --- | --- | --- |
| First journey | Approve the proposed staff-assisted normal request and exact synthetic document/release method; confirm exclusions for this increment | FOIA Program Manager |
| Clock and tracking policy | Approved tracking format/uniqueness scope; calendar/jurisdiction/version, time zone, perfection/tolling/extension/appeal rules, and exact expected dates | FOIA Program Manager with authorized policy reviewer |
| Identity and enforcement | Named test personas, approved assignment scope, business-unit/team boundaries, protected fields, command permissions, impersonation/application identity handling | Platform Product Owner |
| Documents and delivery | Authorized non-production SharePoint target, inheritance/group mapping, scan/access checks, approved delivery connector/channel and failure semantics | Records and Compliance Officer |
| Development and ALM | Confirm DEV/test/prod boundaries, cloud capabilities/licensing/DLP, branch/PR checkpoint strategy, plug-in toolchain and supported deployment route | Platform Product Owner |
| Acceptance and operations | Named sign-off/support owners, measurable performance/concurrency targets, accessibility baseline, audit/retention/hold policy and recovery objectives | FOIA Program Manager and Records and Compliance Officer |

Unresolved choices block affected implementation and are not permission to invent
agency rules, seed more standard-table records, provision resources, or deploy.
Production retention/accreditation/data migration remains outside the demo's
authorization; it requires a separately approved tenant-specific scope.

## Requirement Traceability Strategy

1. Treat [Federal-FOIA-Solution-Requirements.md](Federal-FOIA-Solution-Requirements.md) and its `FOIA-REQ-001` through `FOIA-REQ-300` IDs as the governing reusable catalog.
2. Use the categorized IDs from [requirements-baseline.md](requirements-baseline.md) as the condensed implementation profile for payload descriptions, code work items, tests, deployment manifests, and evidence.
3. Preserve both applicable catalog IDs and profile IDs when implementation evidence is created.
4. Use [requirement-traceability.md](requirement-traceability.md) to classify every catalog range and connect it to the profile matrix.
5. Stop on conflicts rather than weakening a requirement or inventing a fallback.
6. Treat Azure-disabled tests as a mandatory release gate, not an optional test mode.
7. Keep the demo agency-neutral, synthetic, bounded, and reusable; tenant-specific integrations and production-readiness decisions require separate approval.

## Architecture Decisions

| Decision | Selection | Requirement drivers |
| --- | --- | --- |
| System of record | Dynamics 365 Customer Service and Dataverse | FOIA-ARC-001 |
| Data strategy | Hybrid: `incident`, `contact`, and 11 custom tables | FOIA-DAT-001..003 |
| OOB forms | New FOIA-specific forms | FOIA-DAT-005 |
| Entry point | `foia_foiarequest` / Active FOIA Requests | FOIA-CAS-006 |
| Request work segmentation | One FOIA Request to many Cases | FOIA-CAS-003 |
| Documents | SharePoint with independently enforced permissions | FOIA-COL-005..007, FOIA-SEC-009 |
| Clock engine | Dataverse plug-ins plus immutable events | FOIA-CLK-003..006 |
| Notifications | Power Automate over authoritative Dataverse values | FOIA-CLK-005 |
| Optional Azure | Disabled feature flags and adapter contracts initially | FOIA-ARC-003..004, FOIA-AI-005..006 |
| Reports | Native operational dashboards plus annual/quarterly reporting | FOIA-RPT-001..005 |

## Explicit Entity Mapping (Required Before Payloads)

### Standard reused tables (display -> logical)

- Case -> incident
- Contact -> contact

### Custom tables to create (input -> generated logical)

- FOIA Request -> foia_foiarequest
- Search Task -> foia_searchtask
- Responsive Record -> foia_responsiverecord
- Review Task -> foia_reviewtask
- Exemption Decision -> foia_exemptiondecision
- Redaction Decision -> foia_redactiondecision
- Release Package -> foia_releasepackage
- Appeal -> foia_appeal
- Clock Event -> foia_clockevent
- Audit Event -> foia_auditevent
- AI Assistance Record -> foia_aiassistancerecord

### Standard fields reused

- `incident.incidentid`, `incident.ticketnumber`, `incident.title`, `incident.ownerid`, `incident.statecode`, and Customer Service queue/SLA fields
- `contact.contactid`, `contact.fullname`, and approved requester communication fields

### Custom fields to add

- `incident.foia_foiarequestid` and approved FOIA case classification fields
- `contact.foia_requesterclassification` and approved minimum requester extensions
- `foia_foiarequest.foia_trackingnumber` plus intake, scope, status, clock, fee, acknowledgment, and disposition fields
- `foia_searchtask.foia_searchtasknumber` plus source, custodian, assignment, status, date, search-term, result-count, and evidence fields
- `foia_responsiverecord.foia_recordidentifier` plus repository, version, hash, media-type, size, classification, and review-state fields
- `foia_reviewtask.foia_reviewtasknumber` plus review-type, assignment, status, date, disposition, and notes fields
- `foia_exemptiondecision.foia_decisionnumber` plus authority, rationale, scope, proposer, approver, state, and date fields
- `foia_redactiondecision.foia_redactionnumber` plus record-location, basis, proposer, approver, state, and date fields
- `foia_releasepackage.foia_packagenumber` plus version, manifest, hash, response, approval, release-date, and release-method fields
- `foia_appeal.foia_appealnumber` plus challenged-determination, receipt, due, assignment, decision, and outcome fields
- `foia_clockevent.foia_eventid` plus type, effective-time, reason, actor, prior/resulting due-date, and provenance fields
- `foia_auditevent.foia_eventid` plus operation, actor, time, purpose, scope, target, correlation, and export fields
- `foia_aiassistancerecord.foia_assistanceid` plus provider, service-version, operation, sources, output, confidence, human-disposition, and date fields

### Relationships to create

- `foia_foiarequest` (referencing) -> `contact` (referenced)
- `incident` (referencing) -> `foia_foiarequest` (referenced)
- `foia_searchtask` (referencing) -> `foia_foiarequest` (referenced)
- `foia_searchtask` (referencing) -> `incident` (referenced)
- `foia_responsiverecord` (referencing) -> `foia_searchtask` (referenced)
- `foia_responsiverecord` (referencing) -> `foia_foiarequest` (referenced)
- `foia_reviewtask` (referencing) -> `foia_responsiverecord` (referenced)
- `foia_reviewtask` (referencing) -> `foia_foiarequest` (referenced)
- `foia_exemptiondecision` (referencing) -> `foia_reviewtask` (referenced)
- `foia_exemptiondecision` (referencing) -> `foia_responsiverecord` (referenced)
- `foia_redactiondecision` (referencing) -> `foia_responsiverecord` (referenced)
- `foia_redactiondecision` (referencing) -> `foia_exemptiondecision` (referenced)
- `foia_releasepackage` (referencing) -> `foia_foiarequest` (referenced)
- `foia_appeal` (referencing) -> `foia_foiarequest` (referenced)
- `foia_appeal` (referencing) -> `foia_releasepackage` (referenced)
- `foia_clockevent` (referencing) -> `foia_foiarequest` (referenced)
- `foia_clockevent` (referencing) -> `incident` (referenced)
- `foia_auditevent` (referencing) -> `foia_foiarequest` (referenced)
- `foia_aiassistancerecord` (referencing) -> `foia_foiarequest` (referenced)
- `foia_aiassistancerecord` (referencing) -> `foia_responsiverecord` (referenced)
- `foia_releasepackage` <-> `foia_responsiverecord` is a required N:N design relationship but is not represented by the current 1:N relationship payload runtime; it remains blocked for supported implementation rather than being fabricated.

## Planned Schema Work

1. Define table payloads for all 11 custom tables with ownership, auditing, primary columns, descriptions, and requirement IDs.
2. Define column payloads for:
   - intake identity, channel, validation, tracking, acknowledgment, requester, scope, status, expedited handling, fees, dates, and disposition;
   - task assignment, source/custodian, due dates, evidence, counts, and completion;
   - responsive-record repository metadata, media type, hash, size, source, classification, and review state;
   - review, exemption, redaction, approval, package, appeal, clock, audit, and AI provenance;
   - FOIA metadata extensions on `incident` and the minimum justified requester extensions on `contact`.
3. Define choices centrally where reuse is required and document stable values.
4. Define alternate keys for tracking and controlled identifiers.
5. Define every relationship listed in [spec.md](spec.md), preserving requiredness and restrictive cascade behavior, including the Dataverse-required merge cascade exception for the Contact parent.
6. Add no schema payload until its labels, ownership, security classification, reporting use, and lifecycle behavior are explicit.

### Choice-Column Normalization Retrofit

The retrofit uses 26 solution-owned global choices across 29 columns. Existing
shared choices are reused where their semantics match; categorical fields with
different business meaning receive separate option sets.

| Table.column | Global choice |
| --- | --- |
| `contact.foia_requesterclassification` | `foia_feecategory` |
| `foia_aiassistancerecord.foia_operationalstatus` | `foia_adapterstatus` |
| `foia_aiassistancerecord.foia_operationclassification` | `foia_aioperation` |
| `foia_aiassistancerecord.foia_reviewerdisposition` | `foia_aidisposition` |
| `foia_appeal.foia_outcome` | `foia_appealoutcome` |
| `foia_appeal.foia_stage` | `foia_appealstage` |
| `foia_auditevent.foia_eventtype` | `foia_auditaction` |
| `foia_clockevent.foia_clocktype` | `foia_clocktype` |
| `foia_clockevent.foia_eventtype` | `foia_clockeventtype` |
| `foia_exemptiondecision.foia_approvalstate` | `foia_approvalstate` |
| `foia_foiarequest.foia_disposition` | `foia_disposition` |
| `foia_foiarequest.foia_expediteddecision` | `foia_expediteddecision` |
| `foia_foiarequest.foia_feecategory` | `foia_feecategory` |
| `foia_foiarequest.foia_intakechannel` | `foia_intakechannel` |
| `foia_foiarequest.foia_lifecyclestage` | `foia_requestlifecycle` |
| `foia_foiarequest.foia_validationstate` | `foia_validationstate` |
| `foia_redactiondecision.foia_finalstate` | `foia_redactionstate` |
| `foia_releasepackage.foia_approvalstate` | `foia_approvalstate` |
| `foia_releasepackage.foia_releasemethod` | `foia_releasemethod` |
| `foia_responsiverecord.foia_accessstate` | `foia_recordaccessstate` |
| `foia_responsiverecord.foia_classification` | `foia_recordclassification` |
| `foia_responsiverecord.foia_repository` | `foia_repositorytype` |
| `foia_responsiverecord.foia_reviewstate` | `foia_recordreviewstate` |
| `foia_reviewtask.foia_disposition` | `foia_reviewdisposition` |
| `foia_reviewtask.foia_reviewtype` | `foia_reviewtype` |
| `foia_reviewtask.foia_status` | `foia_taskstate` |
| `foia_searchtask.foia_collectionsourcesystem` | `foia_collectionsource` |
| `foia_searchtask.foia_status` | `foia_taskstate` |
| `incident.foia_caseworktype` | `foia_caseworktype` |

Migration sequencing:

1. Preview validates all 26 option sets, 29 bindings, label-to-value mappings,
   current String metadata, synthetic ownership, and every delete dependency.
2. Apply remains blocked until separately approved destructive authorization and
   a fresh stage-95 unmanaged backup are recorded.
3. Snapshot all 41 synthetic records and the current 29 text values by stable
   natural key; any foreign or unmapped value stops before mutation.
4. Remove the 29 attributes from scenario-owned forms, views, charts, BPF field
   references, payload-driven data, and other reported dependencies.
5. Delete only the exact scenario-owned text attributes, create the 26 global
   choices, and recreate the 29 attributes with the same logical names as
   `PicklistAttributeMetadata` using `GlobalOptionSet@odata.bind`.
6. Restore dependencies from payloads, convert synthetic labels to stable
   numeric values, reseed, publish scoped components, and validate field types,
   labels, values, forms, views, BPFs, charts, dashboards, and app usability.
7. Rerun strict membership, stage 85, and stage 95. Do not import the package.

The live read-only Preview completed with all 29 attributes confirmed as String,
97 populated synthetic field values mapped, no foreign populated values, and 60
delete-dependency references: 16 saved-view references across 13 views, 4
process references across 2 BPFs, 7 chart references across 7 charts, and 33
system-form references across 15 forms. The forms include two generated BPF
backing forms that must not be edited independently. Every binding has at least
one dependency, so Apply must remove and later restore all 60 references;
direct attribute deletion is not permitted. The exact component IDs, impacted
fields, supported methods, and operator stop conditions are recorded in
[reports/choice-migration-dependency-handoff.md](reports/choice-migration-dependency-handoff.md).

Stage `36-apply-choice-migration.ps1` implements guarded `Snapshot`, `Apply`,
and `Verify` phases. Apply requires an explicit destructive switch and
authorization reference, refuses mutation unless every dependency count is
zero, adds global choices to the selected solution, recreates the same 29
logical names, restores numeric synthetic values, publishes scoped tables, and
rolls back to the original String definitions and values if migration fails.
It does not fabricate or rewrite BPF definitions. The two BPFs and their
generated backing forms must be handled through the Power Apps designer
handoff, while the payload-driven view, chart, and form dependencies are
removed and restored through their supported builders.

Stage `37-prepare-choice-dependencies.ps1` is a GET-only preparation gate run
after stage 35 and before live dependency removal. It resolves all 60 references
to the 37 reviewed component IDs, verifies handoff coverage, and generates
original and temporary XML definitions for the 13 views, 13 ordinary forms,
and 7 charts. The two BPFs and their two generated backing forms are emitted as
designer-managed records with no fabricated temporary definition.

The live stage 37 Preview passed on 2026-10-19 with 60 references, 37
components, and zero mutations. The required pre-migration unmanaged stage-95
backup then exported and unpacked successfully at the short persistent session
path recorded in export evidence. Inspection matched all 27 expected roots,
235 membership items, and 217 unpacked files with zero missing or unrelated
components. The ZIP SHA-256 is
`26c724b7df4d3b6a7efde3b689acaa483609145beb304077f900a38d22cfaf09`;
import remains prohibited.

Post-Apply verification uses the shared read-only Choice verification helper.
Stage 36 Verify checks all 26 option definitions and 29 exact global bindings,
retains metadata IDs, verifies explicit or include-all table membership, and
compares restored values with the snapshot. Stage 50 strict InventoryOnly and
stage 95 export require `-RequireChoiceMigration` in the operator sequence;
the versioned current contract or matching successful Apply evidence also enables
the checks automatically.
Stage 50 treats global Choices as mandatory solution components and stage 95
checks their roots, exact option values/English labels, and actual exported
attribute types and bindings. For a declared current contract, pre-Apply
unmanaged backups use the explicitly reviewed `PreMigrationBackup` path on
read-only stage-50 inventory and stage 95. Credential-free tests must reject missing membership,
foreign Choices, wrong labels, incorrect types/bindings, and incomplete
packages without making Dataverse calls or overwriting live local evidence.

The approved retrofit completed on 2026-10-22. Both BPFs used supported
temporary designer field rebinding, followed by restoration, validation, and
activation; their generated backing forms were not patched independently.
All 33 ordinary dependent components retained their IDs. Global Choice creation
uses bounded visibility polling and binds columns by metadata GUID. All 29
recreated attribute IDs are explicitly synchronized to the solution.

The original String column definitions and label-shaped seed payloads remain
the pre-migration source for rollback and audit. The approved
`choice-migration-federal-foia-management.json` is the current override through
its versioned `CurrentSchema` declaration: stage 30 generates effective
Picklist metadata with GUID global bindings and stage 66 maps seed labels to
the approved numeric values without requiring execution evidence from another
environment. Unmapped values and incompatible live metadata fail rather than
silently defaulting or deleting columns. Preserve Apply evidence for audit, but
do not manufacture it for a new target or replay original String declarations
directly against converted columns.
Choice filters in reporting payloads use numeric values.

Final verification found all 97 captured values restored, all 41 synthetic
record IDs stable, zero duplicates, and 261 required solution items. The new
post-schema-change baseline intentionally replaces the archived String-attribute
baseline, not the original component or record identities. Final unmanaged
inspection matched 53/53 roots and all 26 Choice/29 Picklist definitions;
import remains outside this authorization.

## Experience Work

### Pastel Grid Increment

Configure Microsoft.PowerApps.PowerAppsOneGrid through classic solution explorer,
select it for Web, set Enable OptionSet colors = Yes and Enable editing = No,
and preserve other settings/defaults and existing mobile controls. Never PATCH
internal custom-control configuration or edit/import fabricated solution XML.
Persist a 13-table grid contract and original export backup, then verify the
actual selected Web control and both properties from a fresh unmanaged export.
Create two separately owned, rerun-safe FOIA Choice Overview public views through
supported savedquery APIs; include FOIA Choice columns and filter shared tables
to FOIA-related records. Add the new view IDs to the selected solution and app,
publish scoped components, verify membership and exported metadata, and inspect
actual pastel cells in the published app. Do not infer success from a handoff.

Completed on 2026-10-22 through supported maker UI and scoped publication.
Package inspection proves all 13 Web controls have editing off and colors on;
both new FOIA views have exact names, filters, and column order. Actual Request,
Contact, and Case grids display pastel badges. All 45 original shared-table
public views are byte-for-byte unchanged in their names, FetchXML, layout,
default flag, and managed flag. A maker-save side effect added Case image-column
solution membership; removed only that incidental membership, not the live
field, before the final strict gate. Final membership is 263 with no failures,
missing items, or unauthorized components. The archived 702-identity baseline
was compared before extension: all original IDs are stable, with only four
identity entries for the two approved views added. The 706-identity baseline
then passed the bounded view rerun and stage 85. Final unmanaged inspection
matched 53/53 roots, 245 files, all 162 option labels/colors, and all 29 bindings.
No import, record edits, form changes, or security changes were performed.

### Choice Presentation Increment

Reuse the original wizard's `choice-presentation-tokens.ps1` palette and symbols.
Its stage 35 is local-Choice-only, so add a bounded global-Choice presentation
stage for the already-approved migration inventory instead of importing the
local stage or the full newer wizard runtime. Keep semantic `Label` and numeric
`Value` unchanged; optional `Icon`/`ColorToken` determine the displayed label
and color. Extend exact live/export verification to check these properties,
and preserve stage-36 creation and stage-66 numeric mappings.
Require a hash-approved preview; preflight all 26 sets, managed-state,
membership, expected values, and all 29 bindings before the first update.
Back up original option metadata, update through `UpdateOptionValue` using
`OptionSetName`, publish only changed global sets, read back every option, and
prove a second Apply makes zero updates. Refresh strict membership and unmanaged
export evidence. No delete/recreate, data reseeding, or unrelated app changes.

Completed on 2026-10-22 with approved plan
`5378829731c57f423e55925b470291b7436599457c5d50296939f0370de75e48`.
All 162 rendered labels and colors passed live and exported-metadata verification;
29 bindings, 97 populated values, 261 solution items, and stable identities passed.
The settled live rerun made zero updates. The first immediate rerun repeated one
validation-state option update while metadata propagation settled; subsequent
readback and rerun were exact. A refreshed published Request displayed the symbols
and all seven channel labels without changing the saved record. Standard form
dropdown option backgrounds remained transparent; pastel fills require a
color-capable control (for example, a grid configured for option-set colors).
This increment sets the native color metadata and does not claim form fills or
introduce custom controls.

### Remaining Experience Work

1. Create separate FOIA-specific main forms for FOIA Request, Case, Contact, and each operational custom table.
2. Create task-oriented views for each persona; explicitly classify each view as `create-custom`, `adopt-generated-active`, or another supported disposition.
3. Use Active FOIA Requests as the landing view, adopting a generated view only if every provenance requirement in the wizard contract is proven at apply time.
4. Create the review app and navigation groups defined in [spec.md](spec.md).
5. Create queues and routing rules for Intake, Search, Review, Legal, Supervisory Approval, Release, and Appeals.
6. Configure SLAs against authoritative due-date fields while preserving the statutory Clock Event ledger.
7. Produce supported designer handoffs for the primary and appeal BPFs; do not fabricate unsupported workflow metadata.
8. Treat BPF chevrons as the authoritative interactive process-stage indicator. Keep `foia_lifecyclestage` and `foia_stage` as reporting/status-projection columns, but do not repeat them as steps in every stage.
9. Permit Due Date, Disposition, and Outcome in multiple stages only as contextual reuse of the same record values; store detailed search, review, redaction, decision, and release evidence in the related child tables.

## Plug-In And Flow Work

### Dataverse Plug-Ins

- Tracking-number allocation and uniqueness enforcement.
- Clock command validation, deterministic calculation, and append-only Clock Event creation.
- Controlled approval transition validation and separation-of-duties checks.
- Release transition validation, package version protection, and immutable release evidence.
- Guardrails preventing ordinary updates/deletes to Clock Event and Audit Event.

Each plug-in change receives isolated unit tests plus Dataverse integration tests.

### Power Automate

- Acknowledgment delivery after accepted intake.
- Clarification requests and reminders.
- Due-date notifications and escalations.
- Search/review assignment notifications.
- Approval and release notifications.
- Integration status and failure notifications.

Flows consume authoritative Dataverse state, use idempotency/correlation values, and cannot create controlled approvals.

## Document Security Work

The following work is deferred from the current demo-security increment. No
SharePoint mutation is authorized by the three-role demo plan.

1. Define SharePoint site/library/location naming without embedding tenant-specific values.
2. Define request/case folder or document-set provisioning and permission inheritance rules.
3. Map Dataverse roles/teams to explicit SharePoint access groups or approved access automation.
4. Record repository item IDs, versions, hashes, classifications, and access state in Responsive Record and Release Package metadata.
5. Test positive and negative access independently in Dataverse and SharePoint.
6. Track download, export, package inclusion, and release events.

## Demo Security Increment

1. Define only three Dataverse security roles:
   - `FOIA Demo Processor` for request and operational work without approval or
     release authority;
   - `FOIA Demo Approver` for scoped read and approval-oriented access without
     release authority;
   - `FOIA Demo Release Officer` for scoped release-package and release access
     without ordinary decision-proposal authority.
2. Keep role creation idempotent, solution-owned, inventoried, and rerun safe.
3. Do not create users, teams, business units, queues, role assignments, or
   field-security profiles in this increment.
4. Do not provision or mutate SharePoint.
5. Validate role metadata and table privilege boundaries without claiming that
   roles enforce same-user separation, status-transition guards, immutable-event
   behavior, or document permissions.
6. Record all deferred production controls and retain synthetic-only test data.
7. Require a separate apply approval before creating the three roles.

## Optional Adapter Work

Define interfaces and configuration records for:

- workflow orchestration;
- OCR and metadata extraction;
- full-text, semantic, and vector search;
- summarization, classification, relevance ranking, and draft generation.

The default implementation is a disabled adapter that reports `Disabled` explicitly. It must not return success-shaped synthetic results. No Azure resource is planned for the initial release.

## Report Plan

- Implement native views, charts, and dashboards from version-controlled reporting payloads where supported.
- Define annual and quarterly measures with explicit date boundary, status, backlog, fee, exemption, appeal, and expedited logic.
- Reconcile every aggregate to Dataverse records and immutable Clock/Audit Events.
- Keep HTML web resources disabled unless a later approved requirement shows a native surface cannot satisfy the need.
- Use [report-mappings.md](report-mappings.md) as the report contract.

## Synthetic Data Plan

- Create a future `demo-data-plan.json` before any data payload.
- Include deterministic journeys for normal, expedited, overdue, appealed, fee, exemption, and released requests.
- Use clearly synthetic contacts and documents.
- Explicitly choose and bound standard Contact, Case, and Task activity creation; never seed reused standard tables implicitly.
- Use stable natural keys and a non-production source classification suitable for reruns.
- Define expected relationship distribution and report totals so tests can reconcile outputs.

## Testing And Evidence Plan

| Test layer | Minimum evidence |
| --- | --- |
| Unit | Plug-in services, clock calculator, validators, adapters, report calculations, and client logic |
| Integration | Current demo: Dataverse role metadata and table-privilege inspection. Deferred production scope: SharePoint security boundary, flows, queues, routing, SLAs, and approved connectors |
| Security | Current demo: three-role privilege matrix and coarse processing/approval/release boundaries. Deferred production scope: field security, user assignment, record-level access, same-user separation, export audit, immutable-event protection, and SharePoint negative tests |
| Accessibility | Keyboard, focus, labels, errors, contrast, zoom/reflow, screen-reader names, and model-driven/custom surface checks |
| Performance | Active work views, clock writes/calculation, bulk metadata, dashboards, package assembly, and representative concurrent workload |
| End to end | Intake-to-closure, clarification, expedited, overdue, no-records, exemption/redaction, release, fee, and appeal journeys |
| Azure independence | Complete core suite with every optional feature flag disabled and no Azure endpoint configured |

Evidence is stored outside source control when it contains environment identifiers or sensitive output. Committed evidence must be sanitized.

## Deployment Manifest

Before apply, create a scenario deployment manifest containing:

- scenario slug, solution unique name, publisher identity/prefix, and target environment classification;
- requirement IDs and exact payload versions;
- tables, columns, relationships, choices, keys, forms, views, BPF handoffs, queues, routing, SLAs, plug-ins, flows, roles, field-security profiles, apps, sitemap, reports, SharePoint configuration, and feature flags;
- logical/unique names and live IDs after creation;
- dependency order, publish scope, inventory state, membership state, test evidence, package hashes, and operator approvals.

Do not export until mandatory solution membership passes.

## Rollback Plan

- Schema changes are additive by default; destructive rollback is not automated.
- Disable new app modules, flows, plug-in steps, routing, SLAs, and feature flags before removing dependencies.
- Restore the previous managed solution version only through the approved release pipeline.
- Preserve Clock Events, Audit Events, released packages, and required retention data; never roll them back by deletion.
- Reverse SharePoint access changes through separately reviewed permission manifests.
- Use compensating configuration/data changes where deletion would break audit or legal retention.
- Document any irreversible change before deployment and require explicit approval.

## Idempotency And Resilience

- Resolve metadata by stable logical/unique names and records by approved alternate keys.
- Record created/updated/skipped/failed results for every category.
- Refresh tokens after 401 and apply bounded exponential backoff with server guidance for 429.
- Expose correlation IDs and errors; do not hide failures behind defaults.
- Re-run payload and experience/data stages and prove stable IDs and zero uncontrolled duplicates before release.

## Authoritative Build Sequence

Follow [docs/onboarding.md](../../docs/onboarding.md):

1. Complete and approve scenario planning.
2. Run `00-prereq-check.ps1` only if setup changed or the previous pass is stale.
3. Obtain explicit authorization, then run `10-auth-connect.ps1`.
4. Create and validate scenario payloads.
5. Run stages `15`, `20`, `30`, `40`, `50`, `55`, `60`, `64`, `62`, `65`, and `66` only when enabled by approved payloads.
6. Capture first membership and idempotency baseline; rerun approved experience/data stages; execute final membership and stage `85`.
7. Publish only scoped components and validate usability.
8. Run stage `95` for approved unmanaged export and local unpack/inspection.
9. Produce a managed release artifact only in a separately approved ALM workflow.
10. Update [docs/build-log.md](../../docs/build-log.md) with inventory, sync, app, sitemap, tests, and evidence outcomes.

## Planning Exit Criteria

- [x] Source requirements have stable IDs.
- [x] Advanced Builder architecture is approved.
- [x] Current repository state and authorization boundary are recorded.
- [x] Reused and custom tables are identified.
- [x] Top user tasks and relationship decisions are documented.
- [x] Reporting, synthetic-data, security, clock, document, Azure, test, deployment, and rollback approaches are documented.
- [x] Stakeholder approved the generated planning package by directing the wizard to proceed.
- [x] Scenario payloads are designed and schema validated within the current runtime contract.
- [x] Environment selection plus authentication and GET-only verification are explicitly authorized and complete as an exception to the reconciliation gate.
- [x] The 300-item catalog crosswalk is reviewed, deterministically validated, and approved.
- [ ] Dataverse mutation, publishing, data seeding, export, and release authorization are explicitly granted at their applicable gates.
