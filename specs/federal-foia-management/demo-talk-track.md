# Demo Talk Track: Federal FOIA Management

## Presenter Brief
- Audience: FOIA program leaders, processors, legal reviewers, release officers, and auditors
- Duration: 7 minutes
- Style: short
- Story anchor: FOIA Request
- Core workflow: Process a synthetic FOIA request from intake through search, review, human approval, release, and audit

## Opening (30-45 sec)
"Today I am showing how Federal FOIA Management helps FOIA program leaders, processors, legal reviewers, release officers, and auditors address this need: provide a reusable, secure, auditable Federal FOIA request-management solution from intake through release, appeal, and closure." "Watch for this result: staff can process representative requests end to end while statutory timing, decisions, documents, approvals, and report calculations remain traceable and reproducible."

## Talk Track Steps
### Step 1: Open with the business problem (1 min)
**Say**
Federal FOIA work spans intake, statutory timing, collection, review, approval, release, appeal, and audit. This demo uses only deterministic synthetic data and keeps human decision authority visible.

**Show**
- Open the published `Federal FOIA Management` model-driven app.
- Confirm the app opens in `FOIA Operations` on `FOIA Requests` / `Active FOIA Requests`.

### Step 2: Start from the hero record (2 min)
**Say**
The FOIA Request is the operational anchor for requester identity, dates, fees, lifecycle, related work, decisions, release evidence, and audit history.

**Show**
- In `Active FOIA Requests`, search for `SYN-FOIA-2026-001`.
- Open `Synthetic Normal Request`.
- Point out tracking number `SYN-FOIA-2026-001`, lifecycle stage `Review`, disposition `Open`, current due date, requester, and acknowledgment reference.
- Use the form or related navigation to connect the request to its Case, Search Task, Responsive Record, and Review Task.

### Step 3: Walk through the core workflow (2 min)
**Say**
The seven synthetic requests are a compact journey switcher. Each record demonstrates a distinct point in the lifecycle without changing production or tenant data.

**Show**
- `SYN-FOIA-2026-002`: expedited request in `Search`, with expedited decision `Granted`.
- `SYN-FOIA-2026-003`: overdue request in `Review`, with due date `2025-11-03`.
- `SYN-FOIA-2026-004`: appealed request in `Closure`, with partial-grant disposition and an Appeal.
- `SYN-FOIA-2026-005`: fee request in `Approval`, with $120 assessed, $80 waived, and $40 collected.
- `SYN-FOIA-2026-006`: exemption request in `Redaction`, with Exemption and Redaction Decisions.
- `SYN-FOIA-2026-007`: released request in `Closure`, with release-package evidence.
- Do not edit these records during the short demo; use them as stable checkpoints.

### Step 4: Show supporting experience (1 min)
**Say**
The same operational data rolls into native views, charts, and dashboards for workload, statutory reporting, appeals, review, and release readiness.

**Show**
- Open the `Dashboards` group and select `Federal FOIA Operations`.
- Show `Active Requests by Lifecycle Stage` and `Expedited Requests by Decision`.
- Point out the additional dashboard links: `Federal FOIA Statutory Reporting`, `Federal FOIA Appeals`, `Federal FOIA Review Workload`, and `Federal FOIA Release Readiness`.
- Explain that Processor, Approver, and Release Officer roles separate coarse table actions; user assignment and production enforcement remain outside this demo increment.

### Step 5: Close with success and next step (1 min)
**Say**
The demo proves a reusable, agency-neutral FOIA data and experience foundation with traceable synthetic journeys, human decision surfaces, native reporting, and bounded demo roles.

**Show**
- Restate that all seven journey records and all 41 synthetic records reconcile exactly once.
- Clarify that SharePoint provisioning, automated flows, full production security, and server-side enforcement are planned future increments rather than hidden demo claims.


## Key Phrases To Use
- "Emphasize reusable agency-neutral configuration, Azure-independent core processing, statutory timing, human decision authority, immutable release evidence, and traceability"
- "We can trace this outcome directly to the scenario requirements and mapping."
- "This is the exact result the business asked to see."


## Closing (20-30 sec)
"We demonstrated Process a synthetic FOIA request from intake through search, review, human approval, release, and audit and proved staff can process representative requests end to end while statutory timing, decisions, documents, approvals, and report calculations remain traceable and reproducible."

## Presenter Checklist
- [ ] Keep language outcome-first, not implementation-heavy.
- [ ] Call out the hero record and business impact clearly.
- [ ] End by restating measurable success criteria.
