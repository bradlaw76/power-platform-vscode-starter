# Federal FOIA Management Demo Implementation Profile

**Version:** 1.0
**Baseline date:** 2026-10-02
**Governing catalog:** [Federal-FOIA-Solution-Requirements.md](Federal-FOIA-Solution-Requirements.md), Version 1.0
**Source:** Federal FOIA Management Solution - GitHub Copilot Build Specification, Version 1.0, October 2026
**Status:** Approved for planning

## Purpose

This profile condenses the governing 300-requirement catalog into stable implementation IDs for the reusable demonstration. Profile IDs must be preserved in specifications, plans, payloads, code, tests, deployment manifests, rollback instructions, and evidence.

The `FOIA-REQ-*` catalog IDs remain authoritative. The categorized IDs in this profile aggregate related catalog requirements for implementation planning and do not replace, narrow, or waive them. [requirement-traceability.md](requirement-traceability.md) records the catalog-range-to-profile crosswalk and demo disposition.

## Reusable Demo Boundary

- The implementation remains agency-neutral and configurable; it must not encode a specific agency, component, branch, bureau, or mission identity.
- Demonstrations use bounded, synthetic, deterministic, rerunnable records and do not use production, requester, classified, CUI, PII, or agency-export data.
- The core demo proves an Azure-independent intake-through-release path with representative clock, search, review, approval, release, reporting, security, and failure scenarios.
- Optional Azure, AI, OCR, semantic search, portal, and external-system capabilities are adapter-based and disabled by default. They may be shown only through approved contract fixtures, mocks, or a separately authorized optional demonstration.
- Production-only concerns such as tenant integrations, legacy migration, accreditation, exact retention, production capacity, and disaster-recovery objectives remain validation-required or deferred until an agency approves them.
- Demo evidence must label each capability as demonstrated, contract-only, deferred, unsupported, or validation-required.

## Architecture And Platform

| ID | Requirement |
| --- | --- |
| FOIA-ARC-001 | Dynamics 365 Customer Service and Dataverse shall be the authoritative FOIA case-management system of record. |
| FOIA-ARC-002 | The core solution shall support secure DoD IL5 and FedCiv GCC/GCC High environments. |
| FOIA-ARC-003 | The core solution shall remain fully functional without Azure Functions, Azure OpenAI, Azure AI Search, Azure Document Intelligence, or Azure Storage. |
| FOIA-ARC-004 | Optional Azure capabilities shall use replaceable adapters and environment-controlled feature flags. |
| FOIA-ARC-005 | The first implementation target shall be FedCiv GCC/GCC High without reducing DoD IL5 portability. |
| FOIA-ARC-006 | Core configuration shall not contain hard-coded tenant, environment, endpoint, connection, or secret values. |

## Intake

| ID | Requirement |
| --- | --- |
| FOIA-INT-001 | The architecture shall support intake from a public FOIA portal, agency portal, email, mail-room entry, staff-assisted entry, FOIA.gov, and APIs. |
| FOIA-INT-002 | Intake shall validate required request information and reject or route invalid submissions for correction. |
| FOIA-INT-003 | Intake shall validate attachment type, size, malware-scan state, and permitted storage destination before processing. |
| FOIA-INT-004 | The system shall assign a unique, reproducible tracking number to each accepted FOIA Request. |
| FOIA-INT-005 | The system shall generate and record an acknowledgment for each accepted request. |
| FOIA-INT-006 | The system shall identify potential duplicate requests for human review without automatically merging or closing them. |

## Case Management And Workflow

| ID | Requirement |
| --- | --- |
| FOIA-CAS-001 | The FOIA lifecycle shall support Intake, Clarification, Search, Review, Redaction, Approval, Release, Appeal, and Closure. |
| FOIA-CAS-002 | The primary FOIA Request process shall use Intake, Clarification, Search, Review, Redaction, Approval, Release, and Closure stages; Appeal shall use a related process. |
| FOIA-CAS-003 | One FOIA Request shall support one or more related Dynamics 365 Cases. |
| FOIA-CAS-004 | Customer Service queues, routing, SLAs, Business Process Flows, dashboards, reporting, security roles, and auditing shall support FOIA operations. |
| FOIA-CAS-005 | Human approval shall be mandatory before exemption determination, redaction approval, response issuance, or release-package release. |
| FOIA-CAS-006 | The model-driven review app shall open on FOIA Request and default to the Active FOIA Requests view. |

## Records Collection And Documents

| ID | Requirement |
| --- | --- |
| FOIA-COL-001 | Collection shall support Exchange, SharePoint, OneDrive, file shares, archives, mission systems, and legacy systems through source-specific connectors or documented manual transfer procedures. |
| FOIA-COL-002 | Collection shall support PST, MSG, EML, DOCX, XLSX, PPTX, PDF, HTML, TXT, CSV, TIFF, JPG, and PNG artifacts. |
| FOIA-COL-003 | Search Tasks shall record collection scope, custodian or source, assigned owner, status, dates, search terms, result counts, and evidence. |
| FOIA-COL-004 | Responsive Records shall record authoritative metadata and secure document references without requiring Azure Storage. |
| FOIA-COL-005 | Core document storage shall use SharePoint document libraries with request- or case-scoped locations and explicit document permissions. |
| FOIA-COL-006 | Dataverse privileges shall not be treated as sufficient protection for SharePoint documents. |
| FOIA-COL-007 | Document access, download, export, and release actions shall be auditable. |

## Review, Decisions, And Release

| ID | Requirement |
| --- | --- |
| FOIA-REV-001 | The solution shall support responsive, exemption, segregability, legal, supervisory, and final-release review. |
| FOIA-REV-002 | Review Tasks shall record assignment, review type, status, disposition, dates, and reviewer notes. |
| FOIA-REV-003 | Exemption Decisions shall record the cited authority, rationale, scope, decision maker, approval state, and dates. |
| FOIA-REV-004 | Redaction Decisions shall record the affected record and location, proposed basis, reviewer, approver, and final state. |
| FOIA-REV-005 | Release Packages shall record package version, included records, response correspondence, approval, release date, and release method. |
| FOIA-REV-006 | Appeals shall record the challenged determination, receipt and due dates, assignment, decision, and outcome. |
| FOIA-REV-007 | Released content shall be immutable by ordinary processors; corrections shall create a new controlled package version. |

## Dataverse Data Model

| ID | Requirement |
| --- | --- |
| FOIA-DAT-001 | The solution shall reuse and extend the standard Incident (`incident`) table for Customer Service Cases. |
| FOIA-DAT-002 | The solution shall reuse the standard Contact (`contact`) table for requester management. |
| FOIA-DAT-003 | The solution shall create custom FOIA Request, Search Task, Responsive Record, Review Task, Exemption Decision, Redaction Decision, Release Package, Appeal, Clock Event, Audit Event, and AI Assistance Record tables. |
| FOIA-DAT-004 | New custom schema names and component unique names shall use the `foia` publisher prefix. |
| FOIA-DAT-005 | New FOIA-specific business forms shall be created for reused out-of-box tables rather than modifying their existing forms. |
| FOIA-DAT-006 | Payload files shall be the source of truth for schema, labels, field ordering, views, processes, reports, and synthetic data. |
| FOIA-DAT-007 | All relationships shall document cardinality, requiredness, existing/new state, cascade behavior, and supported app task or surface. |
| FOIA-DAT-008 | Tracking numbers, package identifiers, and synthetic-data natural keys shall have enforced uniqueness appropriate to their scope. |

## Security, Privacy, And Audit

| ID | Requirement |
| --- | --- |
| FOIA-SEC-001 | The solution shall provide least-privilege roles for Intake Specialist, FOIA Processor, Search Coordinator, Custodian, Reviewer, Legal Reviewer, Supervisory Approver, Release Officer, Auditor, and Administrator. |
| FOIA-SEC-002 | Separation of duties shall prevent a single ordinary processor from proposing and finally approving controlled decisions or releases. |
| FOIA-SEC-003 | Record-level ownership, teams, queues, business units, and sharing shall restrict access to assigned work. |
| FOIA-SEC-004 | Field-level security shall protect sensitive requester, legal, exemption, and release-approval data. |
| FOIA-SEC-005 | Dataverse auditing shall be enabled for security-relevant tables and fields. |
| FOIA-SEC-006 | Exports shall record actor, time, purpose, scope, and related request or package. |
| FOIA-SEC-007 | Audit Events and Clock Events shall be append-only for ordinary users and immutable after creation. |
| FOIA-SEC-008 | No production, operational, classified, controlled, or personally identifiable source data shall be committed to the repository. |
| FOIA-SEC-009 | Security design and testing shall cover both Dataverse records and separately secured SharePoint documents. |

## Statutory Clock

| ID | Requirement |
| --- | --- |
| FOIA-CLK-001 | The system shall record receipt, perfected, due, extension, appeal, and closure dates. |
| FOIA-CLK-002 | The system shall support tolling, statutory extensions, escalations, and notifications. |
| FOIA-CLK-003 | Clock Events shall be immutable and shall preserve event type, effective date/time, reason, actor, prior due date, resulting due date, and provenance. |
| FOIA-CLK-004 | Authoritative clock calculations shall execute in Dataverse plug-ins and shall not depend on Azure services. |
| FOIA-CLK-005 | Power Automate may issue notifications and escalations but shall not independently rewrite authoritative clock history. |
| FOIA-CLK-006 | Clock calculations shall be deterministic, reproducible, time-zone aware, and testable against applicable calendar configuration. |

## Reporting

| ID | Requirement |
| --- | --- |
| FOIA-RPT-001 | The solution shall provide annual FOIA reporting, quarterly reporting, and operational dashboards. |
| FOIA-RPT-002 | Reporting shall include backlog, oldest requests, appeals, exemptions, expedited requests, and fees. |
| FOIA-RPT-003 | Report calculations shall be reproducible and auditable from Dataverse records and immutable event history. |
| FOIA-RPT-004 | Report surfaces shall support drill-through to authorized underlying records. |
| FOIA-RPT-005 | Reporting definitions, filters, date boundaries, and aggregation rules shall be version controlled. |

## AI Guardrails And Optional Azure

| ID | Requirement |
| --- | --- |
| FOIA-AI-001 | AI shall be assistive only and may support summarization, classification, duplicate detection, search recommendations, OCR enhancement, relevance ranking, and draft generation. |
| FOIA-AI-002 | AI shall not autonomously modify case scope, responsiveness decisions, exemption decisions, redactions, approvals, release decisions, or released content. |
| FOIA-AI-003 | Every AI recommendation shall be stored as an AI Assistance Record with provider, model or service version, prompt or operation classification, source references, output, confidence when available, reviewer disposition, and timestamps. |
| FOIA-AI-004 | A human shall explicitly accept, reject, or supersede an AI recommendation before it affects operational records. |
| FOIA-AI-005 | The initial release shall provide disabled adapter contracts and feature flags only; it shall not deploy optional Azure services. |
| FOIA-AI-006 | Disabled, unavailable, or failed optional adapters shall produce explicit operational status and shall not silently change core behavior. |

## Integration And Resilience

| ID | Requirement |
| --- | --- |
| FOIA-INTG-001 | Integrations shall use documented contracts, authenticated connections, least privilege, retry boundaries, and idempotency keys where applicable. |
| FOIA-INTG-002 | Dataverse scripts and integrations shall refresh authentication on HTTP 401 and use exponential backoff for HTTP 429. |
| FOIA-INTG-003 | Long-running and asynchronous operations shall expose status, correlation identifiers, failure reasons, and safe retry behavior. |
| FOIA-INTG-004 | Core FOIA processing shall continue when optional Azure adapters are disabled or unavailable. |
| FOIA-INTG-005 | FOIA.gov and other API integrations shall be independently enableable and shall not bypass intake validation or audit requirements. |

## Testing, ALM, And Evidence

| ID | Requirement |
| --- | --- |
| FOIA-TST-001 | Every implementation change shall include appropriate unit tests. |
| FOIA-TST-002 | The solution shall include integration, security, accessibility, performance, and end-to-end test coverage. |
| FOIA-TST-003 | Tests and demonstrations shall use synthetic data only. |
| FOIA-TST-004 | Accessibility validation shall cover model-driven forms, views, dashboards, custom pages, and generated correspondence surfaces. |
| FOIA-TST-005 | Performance tests shall cover operational views, statutory-clock operations, document metadata, dashboards, and representative bulk workloads. |
| FOIA-ALM-001 | Implementation shall not begin until `Federal-FOIA-Solution-Requirements.md`, `requirements-baseline.md`, `spec.md`, `plan.md`, `tasks.md`, and `requirement-traceability.md` are complete and aligned. |
| FOIA-ALM-002 | No deployment shall occur automatically; preview, apply, export, and release actions require explicit operator decisions. |
| FOIA-ALM-003 | All scripts and component operations shall be idempotent, rerunnable, explicit, and tracked. |
| FOIA-ALM-004 | Every metadata or app update shall end with a scoped publish operation. |
| FOIA-ALM-005 | Every build shall inventory logical names and IDs, synchronize all required components into the selected solution, and verify membership before export. |
| FOIA-ALM-006 | Every backlog item shall link requirement IDs, passing tests, security and accessibility evidence, updated documentation, a deployment manifest, and a rollback path. |
| FOIA-ALM-007 | The development output shall be unmanaged; a managed release artifact may be produced only through a separately approved release workflow. |
| FOIA-ALM-008 | Source-control changes shall use coherent validated checkpoints, explicit file staging, approval before commit or push, and pull-request review. |

## Conflict And Change Control

- Stop implementation when requirements conflict or when a required approval is missing.
- Additive clarification may extend this profile without renumbering existing IDs, but it may not alter the governing catalog.
- Changed or retired requirements retain their IDs and receive an explicit status and rationale.
- Scenario planning files may refine acceptance criteria but may not weaken the governing catalog or this profile without stakeholder approval.
