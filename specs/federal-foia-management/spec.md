# Federal FOIA Management Specification

## Scenario Summary

Federal FOIA Management is a reusable Dynamics 365 Customer Service extension for secure, auditable request processing from intake through closure and appeal. Dataverse is the authoritative system of record. SharePoint provides separately secured document storage. Optional Azure capabilities remain behind disabled adapters so all core operations work in FedCiv GCC/GCC High and DoD IL5 without Azure dependencies.

The authoritative reusable requirement catalog is [Federal-FOIA-Solution-Requirements.md](Federal-FOIA-Solution-Requirements.md). The condensed [requirements-baseline.md](requirements-baseline.md) is the implementation profile for this demonstration. All acceptance evidence must retain the applicable catalog and profile IDs.

## Scope

### In Scope

- Multi-channel request intake, validation, tracking, acknowledgments, and duplicate suggestions.
- FOIA Request orchestration over one or more Dynamics 365 Cases.
- Search, collection, responsive-record tracking, review, exemptions, redactions, release packages, appeals, statutory clocks, and operational audit.
- Customer Service queues, routing, SLAs, Business Process Flows, dashboards, reports, roles, and auditing.
- SharePoint document locations with explicit document permissions.
- Dataverse plug-ins for clock calculation and Power Automate for notifications.
- Disabled adapter contracts and feature flags for optional Azure enhancements.
- Synthetic end-to-end data and the required test/evidence framework.
- Agency-neutral configuration that supports reuse without solution forks.
- Bounded demonstration evidence that labels capabilities as demonstrated, contract-only, deferred, unsupported, or validation-required.

### Out Of Scope For The Initial Release

- Deployment of Azure Functions, Azure Document Intelligence, Azure AI Search, Azure OpenAI, or Azure Storage.
- Autonomous AI decisions or modifications to controlled FOIA outcomes.
- Production data migration.
- Production accreditation, authorization, capacity, retention, recovery, and tenant-specific policy decisions.
- Automatic deployment.
- Final tenant-specific portal, FOIA.gov, mission-system, or legacy-system connector implementation before each interface contract and authorization is approved.
- Destructive cleanup of any environment or unrelated solution.

### Demonstration Constraints

- Use only deterministic synthetic data with bounded source-record counts.
- Demonstrate the core intake-through-release journey without Azure dependencies.
- Treat optional services as disabled adapters or contract fixtures unless a separate optional demonstration is explicitly approved.
- Do not present sample configuration as legal advice, agency policy, or production readiness.
- Preserve reusable labels and behavior; agency-specific terminology and policy enter through configuration.

## Users And Top Tasks

| Persona | Task | Frequency | Entry table/view | Expected outcome | Owner | Done definition |
| --- | --- | --- | --- | --- | --- | --- |
| Intake Specialist | Validate and perfect a new request | Daily | `foia_foiarequest` / New and Unperfected Requests | Request is valid, linked to a requester, assigned a tracking number, acknowledged, and either perfected or routed for clarification | FOIA Intake Lead | Required validation passes, acknowledgment is recorded, and status/clock state is correct |
| FOIA Processor | Coordinate an active request | Daily | `foia_foiarequest` / Active FOIA Requests | Cases, tasks, dates, fees, correspondence, and current stage are coherent | FOIA Operations Manager | Required work is assigned and the request has no unexplained overdue action |
| Search Coordinator | Assign and monitor collection | Daily | `foia_searchtask` / Open Search Tasks | Every approved search scope has an owner, source, due date, and collection result | Records Search Lead | Search evidence and result counts are recorded and submitted |
| Custodian | Complete assigned collection work | As assigned | `foia_searchtask` / My Search Tasks | Responsive material or a defensible no-records result is returned securely | Search Coordinator | Task is completed with evidence and document references |
| Reviewer | Review responsiveness and segregability | Daily | `foia_reviewtask` / My Open Reviews | Each assigned record receives a documented disposition | Review Lead | Review status, rationale, and follow-up work are recorded |
| Legal Reviewer | Decide exemptions and review proposed redactions | Daily | `foia_exemptiondecision` / Pending Legal Decisions | Legal basis and scope are documented for supervisory action | Office of General Counsel FOIA Lead | Decision has authority, rationale, affected records, and reviewer identity |
| Supervisory Approver | Approve controlled decisions | Daily | Approval dashboard / Pending Approvals | Exemption and redaction decisions are approved, rejected, or returned | FOIA Program Manager | Independent approval and date are recorded; proposer cannot self-approve |
| Release Officer | Assemble and release an approved package | Daily | `foia_releasepackage` / Ready for Release | The correct approved version and response are issued through the authorized channel | Disclosure Office Lead | Final approval, package hash/version, release method, recipient, and timestamp are recorded |
| Auditor | Reproduce activity, clock, and reporting outcomes | Monthly and on demand | Audit and Compliance dashboard | A decision or metric can be reconstructed from immutable evidence | Records and Compliance Officer | Source events reconcile to the displayed outcome with no unexplained gap |
| Administrator | Maintain configuration and integrations | As needed | Administration area | Configuration changes are controlled, tested, and traceable | Platform Product Owner | Change has requirement linkage, tests, deployment manifest, rollback plan, and evidence |

## Application Architecture

- Profile: `dynamics-customer-service-extension`
- Strategy: hybrid reuse of `incident` and `contact` plus custom `foia_*` tables.
- Entry point: `foia_foiarequest`.
- Landing view: Active FOIA Requests.
- Review app navigation groups: Intake; Case Management; Search and Collection; Review and Disclosure; Appeals; Compliance and Audit; Reports; Administration.
- Existing out-of-box forms remain unchanged. New FOIA-specific forms are created for Case and Contact.
- Role-based app visibility and privileges hide surfaces not required by a persona.

## Explicit Entity Mapping (Required)

### Reused Standard Tables

| Display name | Logical name | Planned use |
| --- | --- | --- |
| Case | `incident` | Customer Service routing, queues, SLAs, activities, ownership, and work segmentation under a FOIA Request |
| Contact | `contact` | Requester identity and communication details |

### Custom Tables

| Display name | Planned logical name | Purpose | Primary business key |
| --- | --- | --- | --- |
| FOIA Request | `foia_foiarequest` | Request-level identity, intake, scope, lifecycle, requester, dates, fees, and disposition | Tracking number |
| Search Task | `foia_searchtask` | Collection assignment and evidence | Search task number |
| Responsive Record | `foia_responsiverecord` | Metadata and secure repository reference for a collected artifact | Record identifier |
| Review Task | `foia_reviewtask` | Assigned responsiveness, segregability, legal, supervisory, or final review | Review task number |
| Exemption Decision | `foia_exemptiondecision` | Proposed and approved exemption determination | Decision number |
| Redaction Decision | `foia_redactiondecision` | Proposed and approved redaction at a defined record location | Redaction number |
| Release Package | `foia_releasepackage` | Versioned releasable content and response issuance | Package number plus version |
| Appeal | `foia_appeal` | Challenge to an adverse determination | Appeal number |
| Clock Event | `foia_clockevent` | Immutable statutory timing event and due-date derivation | Event ID |
| Audit Event | `foia_auditevent` | Append-only operational event not fully represented by platform audit | Event ID |
| AI Assistance Record | `foia_aiassistancerecord` | AI recommendation, provenance, output, and human disposition | Assistance ID |

### Required Relationship Decisions

All new relationships use `Restrict` delete and `NoCascade` for assign, share, unshare, and reparent. Merge uses `NoCascade` except when Dataverse requires `Cascade` for a merge-enabled standard parent; the Contact-to-FOIA Request relationship records that platform-required exception.

| Parent -> child | Cardinality | Child requiredness | State | Supported task or surface |
| --- | --- | --- | --- | --- |
| `contact` -> `foia_foiarequest` | 1:N | Business required requester | New | Intake, requester history, correspondence |
| `foia_foiarequest` -> `incident` | 1:N | Business required on FOIA Case form | New | Routing, queues, SLA work segmentation |
| `foia_foiarequest` -> `foia_searchtask` | 1:N | Required | New | Search coordination |
| `incident` -> `foia_searchtask` | 1:N | Optional | New | Case-specific collection |
| `foia_searchtask` -> `foia_responsiverecord` | 1:N | Required | New | Collection provenance |
| `foia_foiarequest` -> `foia_responsiverecord` | 1:N | Required | New | Request record inventory and security |
| `foia_responsiverecord` -> `foia_reviewtask` | 1:N | Required | New | Responsive and segregability review |
| `foia_foiarequest` -> `foia_reviewtask` | 1:N | Required | New | Work queues and request progress |
| `foia_reviewtask` -> `foia_exemptiondecision` | 1:N | Required | New | Legal exemption review |
| `foia_responsiverecord` -> `foia_exemptiondecision` | 1:N | Required | New | Record-level decision traceability |
| `foia_responsiverecord` -> `foia_redactiondecision` | 1:N | Required | New | Redaction review |
| `foia_exemptiondecision` -> `foia_redactiondecision` | 1:N | Optional | New | Redaction legal basis |
| `foia_foiarequest` -> `foia_releasepackage` | 1:N | Required | New | Versioned package history |
| `foia_releasepackage` <-> `foia_responsiverecord` | N:N | Explicit inclusion | New | Package contents and release reconciliation |
| `foia_foiarequest` -> `foia_appeal` | 1:N | Required | New | Appeal history |
| `foia_releasepackage` -> `foia_appeal` | 1:N | Optional | New | Challenged release/adverse determination |
| `foia_foiarequest` -> `foia_clockevent` | 1:N | Required | New | Statutory clock ledger |
| `incident` -> `foia_clockevent` | 1:N | Optional | New | Case-specific SLA correlation |
| `foia_foiarequest` -> `foia_auditevent` | 1:N | Required | New | Operational audit timeline |
| `foia_foiarequest` -> `foia_aiassistancerecord` | 1:N | Required | New | AI provenance and human disposition |
| `foia_responsiverecord` -> `foia_aiassistancerecord` | 1:N | Optional | New | Record-specific assistance |

### Data Integrity Rules

- Tracking, task, decision, package, appeal, and event identifiers are server generated and protected from ordinary updates.
- Clock Event and Audit Event records are create/read only for operational roles.
- Approval fields identify a human approver distinct from the proposing user where separation of duties applies.
- A Release Package cannot become Released unless required reviews and approvals pass and its document manifest is fixed.
- Corrections create a new package version; they do not overwrite released content.
- AI output is never copied to a controlled decision without an explicit human disposition.

## Business Processes

### Primary FOIA Request BPF

1. Intake
2. Clarification
3. Search
4. Review
5. Redaction
6. Approval
7. Release
8. Closure

Each stage shall define entry criteria, required fields, exit criteria, allowed roles, and exception handling in the process payload and designer handoff.

The BPF stage chevrons are authoritative for the interactive process position. `foia_lifecyclestage` remains a reporting, view, sample-data, and external status-projection column, but it is not repeated as a required step in each BPF stage. Due Date and Disposition may appear in more than one stage as contextual access to the same FOIA Request value; this does not create duplicate storage. Search, review, redaction, approval, and release evidence remains in the related child tables.

### Appeal Process

1. Appeal Intake
2. Validation
3. Reconsideration and Legal Review
4. Appeal Decision
5. Response
6. Closure

Appeal dates use the same immutable clock-event mechanism but a distinct clock type and reporting classification.

The same rule applies to appeals: the BPF chevrons are authoritative for interactive stage position, while `foia_stage` (display label **Appeal Stage**) remains available for reporting, views, sample data, and external status projection without being repeated as a BPF step. Due Date and Outcome may be reused contextually across stages as references to the same Appeal record values.

## Statutory Clock Design

- Synchronous Dataverse plug-ins validate clock commands and append Clock Events.
- A deterministic calculator derives current due dates from ordered events and approved calendar configuration.
- Tolling start/end, extensions, perfection, appeal, and closure are explicit event types.
- Power Automate reads authoritative due dates for notifications and escalations; flows do not rewrite past events.
- Correction requires an authorized compensating event, never mutation of the original event.

## Document And Integration Boundaries

- SharePoint libraries and locations are provisioned and secured separately from Dataverse.
- Dataverse stores repository, site, library, item, version, hash, classification, and access-state metadata.
- Collection adapters normalize status and metadata while preserving the source system as authority for source content.
- Unsupported or unavailable integrations expose actionable failure status and correlation IDs.
- Intake and collection adapters cannot bypass validation, malware scanning, authorization, or audit gates.

## Security Model

- Ten least-privilege roles map to the personas in `FOIA-SEC-001`.
- Owner teams, queues, business units, record sharing, and access teams enforce assignment boundaries.
- Field security profiles protect sensitive requester details, legal analysis, exemptions, approvals, and release controls.
- Separate proposer and approver privileges enforce controlled decisions.
- SharePoint groups and item/folder permissions are mapped and tested independently.
- Platform auditing plus immutable Audit Events cover reads/exports where required, decision changes, approvals, package creation, and release.

## Reporting

Required native surfaces include:

- FOIA Operations dashboard.
- Statutory Clock and Backlog dashboard.
- Review and Disclosure dashboard.
- Appeals dashboard.
- Annual and Quarterly Reporting dashboard.

Detailed mappings are in [report-mappings.md](report-mappings.md).

## Synthetic Data

The implementation plan shall define deterministic synthetic data for normal, expedited, overdue, appealed, fee, exemption, and released journeys. Standard Contact and Case records are never seeded implicitly. No production-derived names, addresses, documents, identifiers, or content are permitted.

## Acceptance Criteria

1. Every `FOIA-*` requirement has an implementation task and evidence target.
2. Core intake-to-closure and appeal journeys operate with all Azure feature flags disabled.
3. Active FOIA Requests opens as the review app landing view.
4. A request can coordinate multiple routed Customer Service Cases.
5. Human approval gates cannot be bypassed by ordinary users or automation.
6. Clock and audit history cannot be modified by operational roles and can reproduce due dates and report values.
7. SharePoint access tests prove that Dataverse access alone does not grant document access.
8. Annual, quarterly, and operational values reconcile to source records and events.
9. Synthetic end-to-end journeys pass unit, integration, security, accessibility, performance, and end-to-end tests.
10. Inventory and solution membership pass before export.
11. An unmanaged development artifact and documented rollback path exist; managed release remains a separate approval.
12. No automatic deployment, unauthorized live access, or production data use occurs.
