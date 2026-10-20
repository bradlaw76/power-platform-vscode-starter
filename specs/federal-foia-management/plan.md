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
- Mutation authorization: not granted
- Solution unique name: `FederalFOIAManagement`
- Solution display name: Federal FOIA Management
- Publisher prefix: `foia`
- Solution output: unmanaged development solution; managed release artifact later
- Planned source branch: `feature/federal-foia-management`
- Current gate: the 300-item catalog crosswalk and all four credential-free runtime enhancements were approved and validated on 2026-10-06; environment capability verification and explicit mutation authorization remain required before publisher, solution, schema, data, publish, or export operations

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

## Experience Work

1. Create separate FOIA-specific main forms for FOIA Request, Case, Contact, and each operational custom table.
2. Create task-oriented views for each persona; explicitly classify each view as `create-custom`, `adopt-generated-active`, or another supported disposition.
3. Use Active FOIA Requests as the landing view, adopting a generated view only if every provenance requirement in the wizard contract is proven at apply time.
4. Create the review app and navigation groups defined in [spec.md](spec.md).
5. Create queues and routing rules for Intake, Search, Review, Legal, Supervisory Approval, Release, and Appeals.
6. Configure SLAs against authoritative due-date fields while preserving the statutory Clock Event ledger.
7. Produce supported designer handoffs for the primary and appeal BPFs; do not fabricate unsupported workflow metadata.
8. Treat BPF chevrons as the authoritative interactive process-stage indicator. After the approved Choice migration, use `foia_lifecyclestagechoice` and `foia_stagechoice` as reporting/status projections; retain original text columns for rollback, not visible input.
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
# Choice migration preparation — 2026-10-20

Repository prepared, not deployed; all existing live evidence is historical.
Offline tests use injected transports only. Future operator approval must cover
the environment and solution before any metadata or row access.
Use stage 32 to preview metadata, apply additive metadata, preview bounded paged
backfill, then apply backfill with optimistic row concurrency. Review the complete
mapping contract first. Validate a fresh preview with zero pending rows before
cutting forms, views, BPFs, reports and synthetic data over. Default orchestration
must stop before cutover until this gate passes. Keep legacy fields for rollback;
never convert or delete them. Export requires membership and usability checks.

### Future operator sequence (not authorized or executed in this change)

Follow `docs/onboarding.md` for the underlying bootstrap order. This is an
additive migration exception before experience stages, not an in-place conversion:

1. Review the contract independently, approve the target environment and
   `FederalFOIAManagement` solution, freeze edits and capture a secure backup.
   Confirm source tag `federal-foia-synthetic-v1` ownership, existing String
   columns and table solution membership. For a fresh environment, complete
   the normal schema and first table-membership stages before this migration.
2. Invoke `32-migrate-choices.ps1` with explicit `-PayloadsFolder`,
   `-ScenarioSlug federal-foia-management`, `-SolutionUniqueName FederalFOIAManagement`,
   `-EnvironmentUrl` and `-AccessToken`. Do not save tokens in commands or Git;
   pass an approved in-memory token variable. Default `-Mode Metadata` is
   read-only; inspect planned counts and conflicts.
3. Separately approve and repeat with `-Mode Metadata -Apply`. This creates
   global Choices and side-by-side Picklists, explicitly syncs components 9
   and 2, verifies membership and publishes only selected entities/Choices.
   Metadata inventory (names, IDs and membership only) is saved under
   `.wizard-metrics/artifacts/choices/federal-foia-management.json`.
4. Invoke `-Mode Backfill` without `-Apply`, reviewing counts and resolving
   errors privately. `-MaxRows` defaults to 10,000 total selected rows across
   tables, `-PageSize` to 250. Reads select only IDs, source tag and mapped
   categorical columns and include every row with nonnull mapped data.
   Any such row owned by another scenario or lacking the approved tag blocks
   the run; do not expand ownership scope without separate review.
5. After approval, repeat the exact scope with
   `-Mode Backfill -Apply -ApproveBackfill -AcknowledgeWriteFreeze`. The explicit
   acknowledgement confirms an active maintenance window/write freeze, not a
   transactional guarantee. All pages, values, mappings,
   existing targets and ETags are validated before the first write. Each PATCH
   contains only new Choice fields and uses If-Match. A concurrency failure
   stops the run; some earlier rows may have succeeded. Preview again and rerun
   safely. There is no cross-row transaction or automatic rollback.
6. Run `-Mode Validate -AcknowledgeWriteFreeze` with the same bound and require
   zero pending rows while the freeze is still active. For the default orchestrator
   or direct experience/data stages, pass `-AcknowledgeWriteFreeze` only after
   confirming the maintenance window. This is human
   acknowledgement, not proof of migration completion or an alternative to live reads.
   The default orchestrator and direct stages 55/60/64/66 repeat fresh read-only
   validation before mutating surfaces/data; no stale local success flag bypasses it.
   Keep all writers stopped until all surfaces have been validated; independent
   read calls cannot guarantee a stable dataset if concurrent writers are active.
7. Update the existing designer-authored BPFs to the new payload field contract,
   publish those processes, then follow the authoritative experience sequence
   for forms/views, BPF/app linkage, charts/dashboards and optional seed rerun.
   Never claim the old process IDs imply the designer steps already changed.
8. Verify scoped publish, final inventory/membership, legacy-control absence,
   Choice labels, null open outcomes, app usability and report correctness before
   export. Preserve historical manifests and text data for controlled rollback.

Clock/Audit rows are excluded from automatic backfill and cutover row validation:
their original evidence text is immutable and retained unchanged. Additive Choice
metadata is still prepared there for newly created future synthetic rows.
The seed stage skips all updates to existing Clock/Audit records; it may create
new explicitly approved synthetic rows with integer Choice values. Historical
evidence is a deliberate UI exception: retain legacy Clock/Audit categorical
controls read-only and labeled `(Legacy evidence)` alongside new Choice controls.
Their views include both old evidence and new Choice columns. Other tables remove
legacy categorical controls normally. The Clock Events by Type chart retains
legacy evidence grouping and excludes null legacy categories; it is not a migrated
future-Choice or mixed historical series. Any future Choice-only clock chart
requires a separately reviewed reporting payload change.
There is no switch authorizing this helper to rewrite historical Clock/Audit rows.
Approved decisions may also be protected by deployed server enforcement; an
authorized maintenance role is required and this helper never bypasses enforcement.

The current cutover gate intentionally compares populated legacy text with
nonnull business Choices on nonhistorical tables. After cutover, a legitimate
Choice edit can therefore conflict with its retained legacy snapshot and block
a later migration/surface rerun. This is a conservative hard stop, not evidence
that the newer Choice is wrong. Do not overwrite Choices to satisfy the gate;
separately review reconciliation/retirement of this migration-only gate before
routine post-cutover reruns. There is no stale success flag or implicit override.
