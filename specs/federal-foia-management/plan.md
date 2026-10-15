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

1. Define SharePoint site/library/location naming without embedding tenant-specific values.
2. Define request/case folder or document-set provisioning and permission inheritance rules.
3. Map Dataverse roles/teams to explicit SharePoint access groups or approved access automation.
4. Record repository item IDs, versions, hashes, classifications, and access state in Responsive Record and Release Package metadata.
5. Test positive and negative access independently in Dataverse and SharePoint.
6. Track download, export, package inclusion, and release events.

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
| Integration | Dataverse metadata/data operations, SharePoint security boundary, flows, queues, routing, SLAs, and approved connectors |
| Security | Role/privilege matrix, field security, record access, separation of duties, export audit, immutable-event protection, and SharePoint negative tests |
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
