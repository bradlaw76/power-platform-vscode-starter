# Demo Walkthrough: Federal FOIA Management

## Purpose
This walkthrough is for the engineer/operator running the demo. It is derived from scenario files and should stay aligned to the implemented solution.

## Current Presentation Boundary - 2026-11-04

Use the reviewed `demo-script.md` / `demo-talk-track.md` and the current checklist
in `demo-dry-run.md` for a seven-minute, read-only prototype demonstration.
Deployment/export evidence remains dated 2026-10-22. A separately approved
2026-11-04 read-only UI check verified the core screens with presentation gaps:
the normal request's process bar is at Intake while its lifecycle field is
Review, a compatibility banner appears, and runtime console issues remain
undiagnosed. See `demo-dry-run.md`; timed narration is still pending. Do not rerun
build, seed, export, or generator scripts to prepare this walkthrough.

Show the normal request, related work, selected seeded lifecycle states, and the
operations dashboard. Do not edit records, advance stages, send correspondence,
approve/release packages, or open external document links. Requirement statements
and data-integrity rules below describe the target solution, not proof that its
server enforcement, role assignments, document security, or delivery is complete.

## Scenario Source
- Derived from: answers.md, spec.md, plan.md, and tasks.md in specs/federal-foia-management/
- Scenario name: Federal FOIA Management
- Platform area: Dynamics 365 Customer Service / Power Apps model-driven app
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
Use the current read-only click and timing checklist in `demo-dry-run.md`.
Production acceptance remains separate under the milestone plan in `plan.md`.

## Engineer Runbook
### Pre-demo Setup
- Obtain separate read-only DEV/browser authorization before checking app load in `https://usfedfoia.crm9.dynamics.com`.
- Validate demo data availability mode: inspect existing deterministic synthetic data without editing or saving.
- Open the hero record area for: FOIA Request
- Confirm the request form/view, Choice labels, related work, and dashboard charts are usable; seeded clock/approval/package values do not prove production controls.

### Current Walkthrough Checklist
- [x] Confirm the bounded read-only approval and existing authenticated DEV access.
- [x] Complete the current app/record/related-work/Choices/chart checks in `demo-dry-run.md`, retaining the documented presentation gaps.
- [ ] Rehearse the presenter script and record actual elapsed time and blockers.
- [x] Keep historical data/metadata proof separate from current UI observations.
- [ ] Present only after the current checklist passes; otherwise report the blocker.

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
