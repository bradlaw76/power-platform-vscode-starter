# SSA D365 OSB - Call Center Modernization Requirements

**NOTE:** This is a draft baseline and we may supplement this document once we have more details from SSA.

**Date:** October 30, 2026

## 1. Signal Inputs Used

- SSA D365 OSB - Call Center Modernization channel messages, including D365 roadmap references and updates credited to Jason Burns.
- SSA D365 Business Strategy Channel updates on 10/30/2026 including action items, open business questions, and working documents.
- Dynamics @ SSA references to prior fraud-team demo material in shared files.
- Historical Universal Customer Service RFI themes emphasizing centralized multi-channel queueing and assignment.

## 2. Demo Objective

- Demonstrate a modernized SSA contact center operating model using Dynamics 365.
- Centralize intake and routing across communication channels.
- Improve technician and caseworker utilization.
- Preserve human decision authority with transparent auditability.
- Align solution narrative to SSA modernization goals and current pursuit governance.

## 3. Scope

### 3.1 In Scope

- Omnichannel intake (phone, chat, email, web case).
- Unified queue with skills and priority-based routing.
- Case records with timeline, notes, and evidence handling.
- Supervisor controls for approvals, escalation, and SLA tracking.
- AI-assisted summarization and triage recommendations with human-in-the-loop review.
- Operational dashboards for volume, backlog, aging, SLA risk, and productivity.
- Role-based access and end-to-end auditing.

### 3.2 Out of Scope for Demo v1

- Production telephony migration completion.
- Enterprise-wide migration execution.
- Final pricing and deal-desk closure.

## 4. Personas

- Contact Center Agent / Technician
- Supervisor / Team Lead
- Operations Manager
- Program / Business Owner
- IT Administrator / Platform Operations

## 5. Functional Requirements

### 5.1 Intake and Case Creation

- **FR-INT-001:** The system shall create a case from phone, chat, email, and web interactions.
- **FR-INT-002:** The system shall detect likely duplicates and link interactions to existing cases where appropriate.
- **FR-INT-003:** The system shall capture source channel, reason code, priority, customer context, and timestamps.

### 5.2 Queueing and Assignment

- **FR-QUE-001:** The system shall provide a single prioritized queue across channels.
- **FR-QUE-002:** The system shall route by skills, workload, urgency, and configurable business rules.
- **FR-QUE-003:** Supervisors shall be able to override assignments with required reason capture.
- **FR-QUE-004:** The queue experience shall support personal, team, and mission-level views.

### 5.3 Case Work and Resolution

- **FR-CAS-001:** Agents shall progress case states using validated status transitions.
- **FR-CAS-002:** The system shall support tasks and checklists tied to case type.
- **FR-CAS-003:** The system shall support attachments, notes, and evidence references.
- **FR-CAS-004:** The system shall maintain complete case activity timeline and ownership history.

### 5.4 Supervisor Governance

- **FR-SUP-001:** Supervisors shall have SLA risk and backlog monitoring views.
- **FR-SUP-002:** Escalations shall be configurable by age, priority, and severity.
- **FR-SUP-003:** Approval gates shall require explicit human action and rationale.
- **FR-SUP-004:** The demo solution shall support assignment of roles and responsibilities (R&R) across pursuit workstreams.

### 5.5 AI Assist Boundaries

- **FR-AI-001:** AI may summarize interactions and propose triage/disposition recommendations.
- **FR-AI-002:** AI output shall be advisory only and shall not execute final decisions.
- **FR-AI-003:** Users shall be able to accept, edit, or reject AI suggestions.
- **FR-AI-004:** The system shall store provenance metadata for AI-generated suggestions and summaries.

### 5.6 Reporting

- **FR-REP-001:** Dashboards shall include volume by channel, backlog, aging, throughput, and SLA compliance.
- **FR-REP-002:** Dashboards shall include assignment effectiveness and reassignment metrics.
- **FR-REP-003:** Dashboards shall support executive and supervisory drill-downs.

## 6. Non-Functional Requirements

- **NFR-001 Security:** Enforce role-based access control aligned to persona responsibilities.
- **NFR-002 Auditability:** Preserve immutable audit history for assignments, approvals, escalations, and AI actions.
- **NFR-003 Performance:** Queue and case views shall meet operationally acceptable response times.
- **NFR-004 Reliability:** Interaction ingestion shall not lose records during normal operations.
- **NFR-005 Configurability:** Routing, SLA, and escalation policies shall be administratively configurable.
- **NFR-006 Compliance:** Retention and traceability shall align to SSA operational controls.

## 7. Data Model (Demo Minimum)

- Core entities: Contact, Interaction, Case, Queue Item, Assignment, Task, Escalation, Approval, Knowledge/Reference, Audit Event.
- Contact 1:N Interactions; Case 1:N Interactions; Case 1:N Tasks/Escalations/Approvals; Queue Item -> Case.
- Required metadata includes source channel, reason code, priority, SLA clock, and owner history.

## 8. Integration Requirements

- **IR-001:** Ingest interactions from selected channels (live or demo-stubbed).
- **IR-002:** Integrate identity and role mapping for access controls.
- **IR-003:** Provide export/report hooks for business review artifacts.
- **IR-004:** Define integration points for migration-era coexistence.

## 9. Demo Acceptance Criteria

- **AC-001:** End-to-end flow from intake to routing to case work to supervisor decision is demonstrated.
- **AC-002:** Multi-channel queue and assignment behavior is clearly shown.
- **AC-003:** SLA and escalation behavior is demonstrated.
- **AC-004:** AI-assisted triage/summarization is shown with explicit human override.
- **AC-005:** Operational dashboard KPIs are demonstrated.
- **AC-006:** A complete audit trace is demonstrated for at least one sample case.

## 10. Open Decisions and Dependencies

- Determine timing and trigger criteria for deal-desk engagement.
- Determine timing and trigger criteria for additional migration funding.
- Decide training model for users and developers (internal, T-Tec, or mixed).
- Finalize cross-team R&R assignments across ATU, STU, PG, and ISD for pursuit execution.
