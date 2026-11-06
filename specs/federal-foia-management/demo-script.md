# Demo Talk Track: Federal FOIA Management

## Presenter Brief
- Audience: FOIA program leaders, processors, legal reviewers, release officers, and auditors
- Duration: 7 minutes
- Style: short
- Story anchor: FOIA Request
- Core workflow: Inspect a synthetic FOIA request, related work, seeded lifecycle examples, and native reporting

## Presentation Boundary
- This is a read-only DEV prototype walkthrough, not production acceptance.
- Deployment/export evidence remains dated 2026-10-22; the bounded 2026-11-04 UI check and unresolved presentation gaps are recorded in `demo-dry-run.md`. Timed narration remains pending.
- Do not save records, advance stages, send messages, approve/release packages, or open external document links.
- Dates, decisions, and release references are seeded examples, not proof of automated calculation, authorization, immutability, or delivery.

## Opening (30 sec)
"This working prototype brings a FOIA request, related work, and reporting into one staff experience. We will inspect synthetic examples; production enforcement and integrations are still planned."

## Talk Track Steps
### Step 1: Open with the business problem (30 sec)
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
- Point out tracking number `SYN-FOIA-2026-001`, lifecycle stage `Review`, disposition `Open`, seeded due date, and acknowledgment reference. Scroll the form's Details section for lower fields. These stored values do not demonstrate automatic numbering, deadline calculation, or message delivery.
- Show Intake Channel `Agency portal` and Validation State `Perfected`; open the channel list only to inspect its seven options, then dismiss with Escape without choosing or saving.
- Disclose that the process bar is still at `Intake` while the stored lifecycle field is `Review`; they are not demonstrated as synchronized. Do not advance the process.
- Use the form or related navigation to connect the request to its Case, Search Task, Responsive Record, and Review Task.

### Step 3: Compare seeded lifecycle examples (90 sec)
**Say**
The seven synthetic requests illustrate different lifecycle states. We are switching between stored examples, not executing transitions or proving complete journeys.

**Show**
- `SYN-FOIA-2026-002`: expedited request in `Search`, with expedited decision `Granted`.
- `SYN-FOIA-2026-007`: released request in `Closure`, with seeded release-package references; do not claim a document was authorized or delivered.
- Optional bookmarks if time allows (not rechecked during the current UI check):
- `SYN-FOIA-2026-003`: overdue request in `Review`, with due date `2025-11-03`.
- `SYN-FOIA-2026-004`: appealed request in `Closure`, with partial-grant disposition and an Appeal.
- `SYN-FOIA-2026-005`: fee request in `Approval`, with $120 assessed, $80 waived, and $40 collected.
- `SYN-FOIA-2026-006`: exemption request in `Redaction`, with Exemption and Redaction Decisions.
- Do not edit these records during the short demo; use them as stable checkpoints.

### Step 4: Show supporting experience (1 min)
**Say**
The same operational data rolls into native views, charts, and dashboards for workload, statutory reporting, appeals, review, and release readiness.

**Show**
- Open the `Dashboards` group and select `Federal FOIA Operations`.
- Show `Active Requests by Lifecycle Stage` and `Expedited Requests by Decision`.
- Point out the additional dashboard links: `Federal FOIA Statutory Reporting`, `Federal FOIA Appeals`, `Federal FOIA Review Workload`, and `Federal FOIA Release Readiness`.
- Explain that Processor, Approver, and Release Officer role definitions exist as unassigned demo metadata; assigned-user separation and access tests remain outstanding.

### Step 5: Close with success and next step (30 sec)
**Say**
The prototype demonstrates request-management screens, related synthetic work, categorical Choices, and native reporting. Production controls require separate implementation and testing.

**Show**
- If mentioning counts, say the historical read-only validation found seven journey requests and 41 synthetic records; do not describe that as a fresh count.
- Clarify that SharePoint provisioning, automated flows, full production security, and server-side enforcement are planned future increments rather than hidden demo claims.


## Key Phrases To Use
- "This is a working data and experience prototype using synthetic records."
- "These screens relate to the scenario requirements; visible values are not proof of enforced policy."
- "Next we implement and test server-enforced clocks, approval/release, document security, and integrations."


## Closing (30 sec)
"We inspected a request, its related work, representative lifecycle states, and reporting. That is the working foundation. Enforced deadlines, independent approval, secure document release, and delivery are the next production increments."

## Presenter Checklist
- [ ] Keep language outcome-first, not implementation-heavy.
- [ ] Call out the hero record and business impact clearly.
- [ ] End by restating measurable success criteria.
- [ ] Complete the current read-only browser checklist and timed rehearsal in `demo-dry-run.md`; keep approximately 30 seconds of the seven-minute slot for navigation.
