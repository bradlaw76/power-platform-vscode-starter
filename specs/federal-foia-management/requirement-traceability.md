# Federal FOIA Management Requirement Traceability

**Design version:** `FOIA-DD-1.0`
**Governing catalog:** `Federal-FOIA-Solution-Requirements.md` version 1.0
**Demo implementation profile:** `requirements-baseline.md` version 1.0
**Scope:** Reusable, agency-neutral, credential-free demonstration design; no live-access, production-readiness, or deployment authorization

## Traceability Rules

- `FOIA-REQ-001` through `FOIA-REQ-300` are authoritative and retain their original identifiers.
- Every one of the 84 demo profile IDs appears exactly once in the detailed matrix below.
- The catalog scope register connects every catalog ID range to one or more profile families and assigns its current demo disposition.
- A profile mapping is not proof of implementation. Artifact, test, and environment evidence determine whether a catalog requirement is implemented.
- “Planned artifact” identifies the implementation contract, not a claim that the
  component exists.
- Evidence must use synthetic data and redact environment, tenant, user, and
  document identifiers before it is committed.
- `AZ-*` feature flags are false for the mandatory Azure-independent test run.
- Live IDs and execution evidence belong in an instantiated deployment manifest,
  outside this credential-free template.

## Catalog Scope Register

| Catalog IDs | Requirement area | Demo disposition | Primary implementation profile |
| --- | --- | --- | --- |
| FOIA-REQ-001..019 | Intake, validation, referrals, and consultations | Core demo scope | FOIA-INT, FOIA-CAS, FOIA-INTG |
| FOIA-REQ-020..026 | Fees, waivers, expedited processing, and tracks | Core demo scope with configurable policy | FOIA-INT, FOIA-CAS, FOIA-CLK |
| FOIA-REQ-027..040 | Dynamics 365 case management and relationships | Core demo scope | FOIA-DAT, FOIA-CAS |
| FOIA-REQ-041..051 | Statutory clocks, risk, notification, and escalation | Core demo scope | FOIA-CLK, FOIA-CAS, FOIA-RPT |
| FOIA-REQ-052..060 | Search tasking, preservation, and holds | Core demo scope; legal-hold policy validation required | FOIA-COL, FOIA-CAS, FOIA-SEC |
| FOIA-REQ-061..080 | Collection, ingestion, processing, and provenance | Core metadata and contract demo; source integrations contract-only | FOIA-COL, FOIA-INTG, FOIA-TST |
| FOIA-REQ-081..087 | Search, OCR, retrieval, and isolation | Keyword/metadata and authorization demo; semantic search optional | FOIA-COL, FOIA-SEC, FOIA-AI |
| FOIA-REQ-088..104 | Responsiveness, exemption, segregability, and review | Core demo scope | FOIA-REV, FOIA-SEC |
| FOIA-REQ-105..116 | Redaction and quality control | Decision and approval demo; irreversible rendering tool contract-only | FOIA-REV, FOIA-SEC |
| FOIA-REQ-117..122 | Approval and separation of duties | Core demo scope | FOIA-REV, FOIA-SEC |
| FOIA-REQ-123..132 | Versioned release packages and delivery | Core demo scope; tenant delivery integration validation required | FOIA-REV, FOIA-INTG |
| FOIA-REQ-133..140 | Appeals, litigation indicators, and preservation | Representative appeal demo; litigation policy validation required | FOIA-REV, FOIA-CLK, FOIA-SEC |
| FOIA-REQ-141..148 | Correspondence, accessibility, and status inquiry | Template and evidence demo; portal messaging contract-only | FOIA-INT, FOIA-REV, FOIA-TST |
| FOIA-REQ-149..160 | Operational and annual reporting | Core demo scope using synthetic data | FOIA-RPT, FOIA-SEC |
| FOIA-REQ-161..173 | Platform architecture, ALM, preview, and deployment control | Core reusable design and credential-free validation scope | FOIA-ARC, FOIA-ALM, FOIA-INTG |
| FOIA-REQ-174..189 | Optional Azure services | Contract-only and disabled by default; separate optional demo approval required | FOIA-ARC, FOIA-AI, FOIA-INTG, FOIA-TST |
| FOIA-REQ-190..210 | AI and automation guardrails | Guardrails and disabled adapter contracts; optional synthetic AI demo | FOIA-AI, FOIA-SEC, FOIA-TST |
| FOIA-REQ-211..230 | Identity, security, audit, privacy, and DevSecOps | Core design and synthetic security tests; tenant controls validation required | FOIA-SEC, FOIA-ALM |
| FOIA-REQ-231..245 | Synthetic data, protection, privacy, and records management | Core synthetic-data controls; agency schedules and classified processing validation required | FOIA-SEC, FOIA-DAT, FOIA-ALM |
| FOIA-REQ-246..250 | Section 508 accessibility | Core release-acceptance scope | FOIA-TST |
| FOIA-REQ-251..258 | Reliability, performance, recovery, and operations | Bounded demo testing; production objectives validation required | FOIA-INTG, FOIA-TST, FOIA-ALM |
| FOIA-REQ-259..271 | ALM, testing, traceability, contracts, and bulk exchange | Core repository and validation scope; tenant exchange mappings contract-only | FOIA-ALM, FOIA-TST, FOIA-INTG |
| FOIA-REQ-272..277 | Legacy migration | Deferred and contract-only for the initial demo | FOIA-DAT, FOIA-INTG, FOIA-TST |
| FOIA-REQ-278..283 | Documentation and operational readiness | Core documentation scope; production runbooks validation required | FOIA-ALM, FOIA-TST |
| FOIA-REQ-284..290 | Reusability and agency neutrality | Core reusable-design scope | FOIA-ARC, FOIA-DAT, FOIA-ALM |
| FOIA-REQ-291..300 | Acceptance and validation scenarios | Core non-Azure demo plus separately approved optional-service scenario | FOIA-TST, FOIA-SEC, FOIA-RPT, FOIA-ALM |

## Architecture And Platform

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-ARC-001 | `foia_foiarequest`, FOIA Case form on `incident`, request-to-case relationship, review app | Integration; E2E | Metadata inventory plus synthetic request/case journey proving Dataverse authority |
| FOIA-ARC-002 | Environment classification gate and portability constraints in configuration/deployment contracts | Configuration; Security | GCC High capability review and IL5 portability checklist with no unsupported dependency |
| FOIA-ARC-003 | Disabled Azure adapters and complete Dataverse/SharePoint/Power Automate core path | Azure independence; E2E | Full core-suite result with no Azure endpoint, connection, or resource configured |
| FOIA-ARC-004 | Replaceable adapter interfaces and `AZ_*_ENABLED` environment flags | Unit; Configuration | Contract tests for disabled, unavailable, failed, and enabled-provider boundaries |
| FOIA-ARC-005 | FedCiv-first environment profile with portability decision record | Architecture review; Configuration | Signed compatibility matrix showing no FedCiv-only assumption in core components |
| FOIA-ARC-006 | Environment-variable and connection-reference contracts; secret-free manifests | Static; Security | Secret scan, hard-coded-value scan, and reviewed resolved-configuration inventory |

## Intake

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-INT-001 | Intake adapter contract and channel choice set for portal, email, mail room, staff, FOIA.gov, and API | Unit; Integration | Synthetic contract fixtures for each channel and normalized intake records |
| FOIA-INT-002 | Intake validation service, validation status/reason fields, correction queue | Unit; E2E | Required-field positive/negative cases and correction-routing screenshots/logs |
| FOIA-INT-003 | Attachment policy, malware-state gate, size/type rules, approved SharePoint destination | Unit; Security; Integration | Rejected type/size/scan fixtures and accepted synthetic upload audit trail |
| FOIA-INT-004 | Server-side tracking-number allocator and alternate key | Unit; Concurrency; Integration | Deterministic-format tests, uniqueness constraint proof, and concurrent allocation result |
| FOIA-INT-005 | Acknowledgment flow, correspondence metadata, and audit event | Integration; E2E | Synthetic accepted request with one idempotent acknowledgment and delivery status |
| FOIA-INT-006 | Duplicate-candidate service and human-review disposition fields | Unit; E2E | Similar synthetic requests flagged without automatic merge, closure, or scope change |

## Case Management And Workflow

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-CAS-001 | Request lifecycle reporting/status-projection choice, primary BPF, related appeal process; BPF chevrons are the interactive stage authority | E2E; Regression | Synthetic journeys covering every lifecycle state and appeal relationship without repeated lifecycle/stage BPF steps |
| FOIA-CAS-002 | Eight-stage primary BPF and six-stage appeal BPF with contextual reuse of Due Date, Disposition, and Outcome values | Metadata; E2E | Active-state and solution-membership evidence, BPF stage/step/condition report, deferred app linkage, and transition test log |
| FOIA-CAS-003 | Required request lookup on FOIA Case form and 1:N request-to-`incident` relationship | Integration; E2E | One synthetic request coordinating multiple routed Cases |
| FOIA-CAS-004 | Queues, routing, SLAs, BPFs, dashboards, roles, and audit configuration | Integration; Security | Component inventory plus task-routing, SLA, dashboard, role, and audit checks |
| FOIA-CAS-005 | Controlled approval state machines and synchronous separation-of-duties plug-in | Unit; Security; E2E | Bypass and self-approval attempts denied; independent approvals recorded |
| FOIA-CAS-006 | Review app sitemap with `foia_foiarequest` and Active FOIA Requests landing view | Metadata; Accessibility; E2E | App usability evidence proving first table/view and authorized navigation |

## Records Collection And Documents

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-COL-001 | Source connector/manual-transfer contracts and collection-source choice | Contract; Integration | One synthetic fixture per source class, including documented manual transfer |
| FOIA-COL-002 | Media-type allowlist and document metadata fields | Unit; Integration | Accepted synthetic fixture for every listed format and denied unsupported format |
| FOIA-COL-003 | `foia_searchtask` schema, forms, views, and completion business rules | Unit; E2E | Search task with scope, source, owner, dates, terms, counts, and evidence |
| FOIA-COL-004 | `foia_responsiverecord` metadata and SharePoint reference contract | Integration; Security | Record resolves authorized SharePoint item without any Azure Storage dependency |
| FOIA-COL-005 | SharePoint library/location template and explicit permission manifest | Integration; Security | Request/case-scoped synthetic location with verified positive and negative access |
| FOIA-COL-006 | Independent Dataverse and SharePoint authorization checks | Security | Matrix proving Dataverse read does not imply SharePoint document read |
| FOIA-COL-007 | Audit Event types for view/download/export/package/release actions | Security; Audit | Correlated synthetic action ledger with actor, purpose, scope, time, and result |

## Review, Decisions, And Release

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-REV-001 | Review-type choice and `foia_reviewtask` workflow | Unit; E2E | Synthetic responsive, segregability, legal, supervisory, and final-release reviews |
| FOIA-REV-002 | Review Task schema, assignment rules, form, and My Open Reviews view | Integration; E2E | Completed task showing type, status, disposition, dates, and reviewer notes |
| FOIA-REV-003 | Exemption Decision schema and proposal/approval state machine | Unit; Security; E2E | Approved synthetic decision with authority, rationale, scope, actors, and dates |
| FOIA-REV-004 | Redaction Decision schema, location contract, and independent approval | Unit; Security; E2E | Synthetic redaction preserving record/location/basis/proposer/approver/final state |
| FOIA-REV-005 | Versioned Release Package, inclusion relationship, manifest, and correspondence reference | Integration; E2E | Approved package manifest with included records, version, hash, release method/date |
| FOIA-REV-006 | Appeal schema, process, clock type, queues, and reporting fields | Integration; E2E | Synthetic appeal from receipt through outcome with challenged determination |
| FOIA-REV-007 | Released-package lock and correction-as-new-version plug-in | Unit; Security; E2E | Ordinary update denied and controlled correction creates a new linked version |

## Dataverse Data Model

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-DAT-001 | FOIA-specific Case form/columns on reused `incident`; no table-creation payload | Metadata; Regression | Inventory proves reuse and unchanged OOB forms |
| FOIA-DAT-002 | FOIA-specific Contact form/minimum requester columns on reused `contact` | Metadata; Security | Inventory proves reuse, field protection, and unchanged OOB forms |
| FOIA-DAT-003 | Eleven `foia_*` custom table definitions listed in `detailed-design.md` | Schema; Integration | Table inventory with logical names, ownership, auditing, and primary keys |
| FOIA-DAT-004 | Prefix validation rule for schema/component unique names | Static; Schema | Prefix audit reports zero non-`foia` custom names |
| FOIA-DAT-005 | Separate FOIA Case and Contact main forms | Metadata; Regression | Form IDs and XML comparison proving OOB forms were not modified |
| FOIA-DAT-006 | Versioned payload catalog for schema, UX, process, report, and synthetic data | Static; Schema | JSON Schema validation and payload-hash inventory |
| FOIA-DAT-007 | Relationship catalog in `spec.md` and restrictive cascade contract | Schema; Integration | Metadata comparison for cardinality, requiredness, state, cascade, and surface |
| FOIA-DAT-008 | Alternate keys and protected server-generated identifier fields | Unit; Concurrency; Integration | Duplicate insert failures and stable synthetic natural-key rerun results |

## Security, Privacy, And Audit

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-SEC-001 | Ten least-privilege roles in `security-model.md` | Security | Persona/table privilege matrix with positive and negative tests |
| FOIA-SEC-002 | Distinct proposer/approver privileges and plug-in enforcement | Unit; Security | Self-approval and privilege-escalation attempts denied and audited |
| FOIA-SEC-003 | User/owner teams, business units, queues, access teams, and controlled sharing | Security; Integration | Assigned/unassigned/cross-office record-access test matrix |
| FOIA-SEC-004 | Requester, legal, exemption, approval, and release field-security profiles | Security | Field read/update masking and denial tests by role |
| FOIA-SEC-005 | Table/column audit enablement catalog | Metadata; Audit | Audit-settings export and synthetic before/after audit records |
| FOIA-SEC-006 | Export command and immutable Audit Event contract | Security; Audit | Synthetic export event with actor, time, purpose, scope, request/package, result |
| FOIA-SEC-007 | Create/read-only Clock/Audit roles plus update/delete plug-in guards | Unit; Security | Update/delete attempts denied; compensating event accepted |
| FOIA-SEC-008 | Synthetic-only policy, repository secret/data scans, evidence sanitization | Static; Security | Scans report no production/PII/classified/controlled source data or secrets |
| FOIA-SEC-009 | Separate Dataverse and SharePoint authorization model | Security; E2E | Dual-boundary positive/negative access suite and reviewed permission manifest |

## Statutory Clock

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-CLK-001 | Request/appeal date fields and typed Clock Events | Unit; Integration | Synthetic receipt, perfection, due, extension, appeal, and closure timeline |
| FOIA-CLK-002 | Tolling/extension commands, SLA notifications, and escalations | Unit; Integration; E2E | Start/end toll, extension, warning, breach, and escalation cases |
| FOIA-CLK-003 | Append-only Clock Event schema with prior/resulting due dates and provenance | Unit; Security | Immutable event record completeness and mutation-denial evidence |
| FOIA-CLK-004 | Synchronous Dataverse clock plug-in and disabled external clock adapter | Unit; Azure independence | Calculator/plug-in suite passes with no Azure configuration |
| FOIA-CLK-005 | Read-only due-date notification/escalation flows | Integration; Regression | Flow run uses authoritative values and produces no Clock Event history rewrite |
| FOIA-CLK-006 | Calendar-versioned, time-zone-aware deterministic calculator | Unit; Property; Integration | Replay corpus across weekends, holidays, DST, tolling, and extensions |

## Reporting

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-RPT-001 | Five dashboards and versioned annual/quarterly definitions | Report; E2E | Surface inventory and certified synthetic annual/quarterly runs |
| FOIA-RPT-002 | Measures for backlog, oldest, appeals, exemptions, expedited, and fees | Unit; Report | Formula fixtures and reconciled expected totals for every measure |
| FOIA-RPT-003 | Event-aware calculation library and certified-run metadata | Unit; Audit; Report | Report replay matches source rows/events and records definition/parameter hashes |
| FOIA-RPT-004 | Security-trimmed drill-through views | Security; Accessibility; E2E | Authorized drill-through succeeds; unauthorized row/document access fails |
| FOIA-RPT-005 | `report-definitions.md` version IDs, formulas, filters, and boundaries | Static; Report | Definition checksum, review approval, boundary tests, and change history |

## AI Guardrails And Optional Azure

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-AI-001 | Provider-neutral assistive-operation enum and adapter contracts | Unit; Security | Each allowed operation returns a recommendation only |
| FOIA-AI-002 | Controlled-field write denylist and human-decision plug-in guard | Unit; Security; E2E | AI identity cannot alter scope, decisions, redactions, approvals, or release |
| FOIA-AI-003 | `foia_aiassistancerecord` provenance and output schema | Schema; Integration | Synthetic recommendation records every required provider/version/source/output field |
| FOIA-AI-004 | Pending/accepted/rejected/superseded human disposition state machine | Unit; E2E | Recommendation has no effect before explicit authorized disposition |
| FOIA-AI-005 | Disabled adapters and all optional Azure flags defaulting false | Configuration; Azure independence | Initial manifest declares no Azure resources and core suite passes |
| FOIA-AI-006 | Explicit Disabled/Unavailable/Failed adapter results | Unit; Resilience | Fault tests return status/correlation/error and never success-shaped fallback |

## Integration And Resilience

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-INTG-001 | Connector contracts, connection references, least-privilege scopes, idempotency keys | Contract; Security; Integration | Contract tests and connection-reference inventory without credentials |
| FOIA-INTG-002 | Shared HTTP policy for one 401 refresh cycle and bounded 429 backoff | Unit; Resilience | Mock 401/429 traces showing refresh, server guidance, bounds, and terminal failure |
| FOIA-INTG-003 | Async-operation status/correlation/error/retry fields | Unit; Integration | Synthetic failed/retried operation with stable correlation and no duplicate effect |
| FOIA-INTG-004 | Core dependency graph excluding optional Azure adapters | Azure independence; E2E | Complete core journey during disabled and unavailable adapter states |
| FOIA-INTG-005 | Independent FOIA.gov/API flags and common intake validation/audit pipeline | Contract; Security; E2E | Disabled path has no side effect; enabled test fixture cannot bypass validation |

## Testing, ALM, And Evidence

| Requirement | Planned artifact | Test layer | Required evidence |
| --- | --- | --- | --- |
| FOIA-TST-001 | Unit-test work item and acceptance link for every implementation change | Unit; Static | Requirement-indexed unit results and coverage/rationale record |
| FOIA-TST-002 | Integration, security, accessibility, performance, and E2E suites | All named layers | Release evidence index with result, defect disposition, owner, and timestamp |
| FOIA-TST-003 | Deterministic synthetic-data plan and production-data prohibition | Static; All runtime layers | Fixture provenance and repository scan confirming synthetic-only inputs |
| FOIA-TST-004 | Accessibility plan for forms, views, dashboards, custom/correspondence surfaces | Accessibility | Keyboard, focus, name, error, contrast, zoom/reflow, and screen-reader results |
| FOIA-TST-005 | Performance plan for views, clock, metadata, dashboards, and bulk work | Performance | Approved workload profile, thresholds, timings, and bottleneck disposition |
| FOIA-ALM-001 | Approved baseline/spec/plan/tasks gate | Static; Governance | Alignment review showing all four artifacts complete before implementation |
| FOIA-ALM-002 | Separate preview/apply/export/release approval fields in deployment manifest | Governance; Negative | Attempt without each approval is blocked and logged |
| FOIA-ALM-003 | Stable-name/idempotency contract and second-pass verification | Integration; Idempotency | Created/updated/skipped/failed counts, stable IDs, and zero uncontrolled duplicates |
| FOIA-ALM-004 | Scoped publish record after every metadata/app update set | Integration; Governance | Publish scope, timestamp, result, and post-publish metadata verification |
| FOIA-ALM-005 | Component inventory, sync, and membership gates | Integration; Governance | Added/already/failed/missing report with IDs; export gate passes only at zero missing |
| FOIA-ALM-006 | Backlog trace link, tests, security/accessibility, docs, manifest, rollback fields | Static; Governance | Completed work-item definition-of-done record with evidence links |
| FOIA-ALM-007 | Unmanaged development output and separately approved managed-release stage | Package; Governance | Unmanaged package inspection; managed package field remains unapproved initially |
| FOIA-ALM-008 | Explicit staging and separate commit/push/PR approvals | Static; Governance | Sanitized status/diff/validation review and recorded approvals at each boundary |

## Completeness Check

The authoritative baseline contains 84 unique `FOIA-*` IDs. Validation must compare
that set with the first column above and fail on a missing, extra, or duplicate ID.
