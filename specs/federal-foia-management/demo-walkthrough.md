# Demo Walkthrough: Federal FOIA Management

## Purpose
This walkthrough is for the engineer/operator running the demo. It is derived from scenario files and should stay aligned to the implemented solution.

## Scenario Source
- Derived from: answers.md, spec.md, plan.md, and tasks.md in specs/federal-foia-management/
- Scenario name: Federal FOIA Management
- Platform area:
- Environment: `https://usfedfoia.crm9.dynamics.com`

## Scenario Requirements Snapshot
- Business problem: provide a reusable, secure, auditable Federal FOIA request-management solution from intake through release, appeal, and closure.
- Success criteria: staff can process representative requests end to end while statutory timing, decisions, documents, approvals, and report calculations remain traceable and reproducible.
- Required entities: FOIA Request, Search Task, Responsive Record, Review Task, Exemption Decision, Redaction Decision, Release Package, Appeal, Clock Event, Audit Event, and AI Assistance Record, Case (`incident`) and Contact (`contact`)
- Required artifacts: FOIA Request, Case, Contact, all downstream FOIA operational tables, forms, views, both BPF handoffs, charts, dashboards, and role-appropriate navigation

### Explicit Entity Mapping
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

All new relationships use `Restrict` delete and `NoCascade` for assign, share, unshare, reparent, and merge unless a later security design explicitly proves a safer supported behavior.

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

### Validation Plan
No validation plan block found.

## Engineer Runbook
### Pre-demo Setup
- Confirm environment access and app load in `https://usfedfoia.crm9.dynamics.com`.
- Validate demo data availability mode: Use deterministic synthetic data and update one hero request during the demonstration
- Open the hero record area for: FOIA Request
- Confirm demo scope artifacts are available: FOIA Request form and views, statutory clock, search and review tasks, approval controls, release package, audit trail, and dashboards

### Implementation Walkthrough Checklist
- [ ] Select 'advanced-builder'.
- [ ] Verify wizard runtime, prerequisites, contract integrity, documentation consistency, and skill parity.
- [ ] Inspect repository documentation and record that no existing FOIA implementation or FOIA live-access authorization is present.
- [ ] Preserve the reusable catalog as 'Federal-FOIA-Solution-Requirements.md' with stable 'FOIA-REQ-001' through 'FOIA-REQ-300' IDs.
- [ ] Retain the categorized 'FOIA-*' IDs as the condensed demo implementation profile.
- [ ] Approve the hybrid Customer Service architecture, new FOIA forms, FOIA Request entry point, Request-to-Case relationship, lifecycle, SharePoint storage, clock architecture, reports, synthetic data, and Azure-disabled initial release.
- [ ] Create and align 'Federal-FOIA-Solution-Requirements.md', 'answers.md', 'requirements-baseline.md', 'spec.md', 'plan.md', 'tasks.md', 'requirement-traceability.md', and 'report-mappings.md'.
- [ ] Generate and review the scenario-derived presenter demo script and engineer walkthrough.
- [ ] Complete the narrative dry run and defer app-dependent rehearsal steps until deployment and synthetic-data verification.
- [ ] Review and approve the complete planning package.

### What To Show (Implementation-Oriented)
- Show where the hero record (FOIA Request) is managed.
- Demonstrate how configured entities/artifacts support: Process a synthetic FOIA request from intake through search, review, human approval, release, and audit
- Show one verification signal tied to success criteria.

### Risk Mitigation During Demo
- If live data is missing, pivot to nearest prepared record and narrate expected outcome.
- If automation is delayed, show artifact evidence and explain eventual state.
- If a screen/view is unavailable, use the closest form/view that still proves the scenario.

## Review Gate
- [ ] Walkthrough reflects current spec/plan/tasks.
- [ ] Mapping section matches implemented standard/custom model.
- [ ] Success criteria can be demonstrated in under 7 minutes.
