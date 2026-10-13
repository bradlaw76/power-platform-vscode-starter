# Federal FOIA Management Report Mappings

## Approved Report Decision

- Reports enabled: yes
- Scope: operational dashboards plus annual and quarterly FOIA reporting
- Native model-driven views/charts/dashboards: preferred
- Optional HTML report web resources: disabled until a documented gap is approved
- Calculation authority: version-controlled definitions over Dataverse data and immutable Clock/Audit Events

| Table | Surface | Type | Placement | Required fields | Decision supported | Owner | Validation checklist |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `foia_foiarequest` | Active FOIA Requests | View (`adopt-generated-active` only with proven provenance) | Review app entry point | tracking number, requester, lifecycle stage, perfected date, current due date, assigned owner, expedited flag | What active work requires attention? | FOIA Operations Manager | Provenance passes; active filter is correct; sort prioritizes due date; drill-through opens FOIA Request Main |
| `foia_foiarequest` | New and Unperfected Requests | View (`create-custom`) | Intake area | tracking number, intake channel, received date, requester, validation state, clarification due date | Which requests require intake or clarification? | FOIA Intake Lead | Filters and aging reconcile; required fields are readable and sortable |
| `foia_searchtask` | Open Search Tasks | View (`create-custom`) | Search and Collection area | task number, request, case, source/custodian, owner, due date, status, result count | Which searches are unassigned, late, or incomplete? | Records Search Lead | Queue totals reconcile; overdue logic uses authoritative due date |
| `foia_reviewtask` | My Open Reviews | View (`create-custom`) | Review and Disclosure area | task number, request, responsive record, review type, due date, status, owner | What must each reviewer decide next? | Review Lead | User filter and security are correct; drill-through preserves context |
| `foia_exemptiondecision` | Pending Legal Decisions | View (`create-custom`) | Legal review area | decision number, request, record, authority, proposer, status, proposed date | Which proposed exemptions need legal action? | OGC FOIA Lead | Pending criteria and field security pass; proposer/approver are visible to authorized roles |
| `foia_redactiondecision` | Pending Redaction Approvals | View (`create-custom`) | Supervisory approval area | redaction number, record, location, basis, proposer, approver, status | Which redactions require independent approval? | FOIA Program Manager | Separation-of-duties cases are flagged; record link opens securely |
| `foia_releasepackage` | Ready for Release | View (`create-custom`) | Release area | package number, version, request, approval state, package hash, planned release date | Which approved packages can be issued? | Disclosure Office Lead | Only fully approved packages appear; version/hash display; unauthorized users cannot release |
| `foia_appeal` | Open Appeals | View (`create-custom`) | Appeals area | appeal number, request, challenged package, received date, due date, owner, stage | Which appeals require action? | Appeals Program Lead | Due dates reconcile to appeal Clock Events; drill-through works |
| `foia_foiarequest` | Backlog by Age | Chart | Statutory Clock and Backlog dashboard | perfected date, current due date, lifecycle status, closure date | How large and old is the perfected open backlog? | FOIA Program Manager | Age bands and fiscal/date boundaries are documented and reconcile |
| `foia_foiarequest` | Oldest Requests | View | Statutory Clock and Backlog dashboard | tracking number, perfected date, age, due date, tolling state, owner | Which requests are oldest and why? | FOIA Program Manager | Ordered oldest first; tolling does not erase calendar age; security trimming passes |
| `foia_foiarequest` | Expedited Requests | Chart and view | FOIA Operations dashboard | expedited requested/decision/status, received/perfected/due dates | What expedited demand and aging require attention? | FOIA Operations Manager | Counts reconcile to request records and decision audit |
| `foia_appeal` | Appeals by Outcome and Age | Chart | Appeals dashboard | received date, closed date, outcome, due date | What is the appeal workload and disposition? | Appeals Program Lead | Open/closed logic and outcomes reconcile |
| `foia_exemptiondecision` | Exemptions Applied | Chart | Review and Disclosure dashboard | authority, final state, decision date, request | Which exemptions are applied and how often? | OGC FOIA Lead | Only approved final decisions count; authority labels are stable |
| `foia_foiarequest` | Fees Assessed, Waived, and Collected | Chart | Annual and Quarterly Reporting dashboard | fee category, assessed, waived, collected, fiscal period | What fee activity must be reported? | FOIA Reporting Lead | Currency and waiver rules are documented; totals reconcile |
| `foia_clockevent` | Tolling and Extension Activity | Chart | Statutory Clock and Backlog dashboard | event type, effective date, prior/resulting due dates, reason | How are clocks changing and can changes be defended? | Records and Compliance Officer | Event ledger is immutable; calculator replay reaches the displayed due date |
| Cross-table | Annual FOIA Report | Versioned report definition | Annual and Quarterly Reporting area | request, appeal, fee, exemption, disposition, processing-time, backlog, expedited, and clock fields | What values satisfy the approved annual reporting definition? | FOIA Reporting Lead | Every measure has a formula, source fields, fiscal boundary, reconciliation query, and sign-off |
| Cross-table | Quarterly FOIA Report | Versioned report definition | Annual and Quarterly Reporting area | request, appeal, fee, exemption, backlog, oldest, expedited, and clock fields | What quarterly trend and operational values require action? | FOIA Reporting Lead | Quarter boundaries, snapshots, corrections, and reconciliation are documented |

## Dashboard Set

### FOIA Operations

- Active requests by lifecycle stage and owner.
- New/unperfected work.
- Expedited requests.
- Upcoming and breached due dates.

### Statutory Clock And Backlog

- Backlog by age.
- Oldest requests.
- Tolling and extension activity.
- Due-date risk.

### Review And Disclosure

- Open reviews.
- Pending legal decisions.
- Pending redaction approvals.
- Packages ready for release.

### Appeals

- Open appeals by stage and age.
- Appeals by outcome.
- Upcoming and breached appeal due dates.

### Annual And Quarterly Reporting

- Versioned statutory and operational measures.
- Drill-through to authorized source records.
- Reconciliation status and last certified run.

## Calculation Controls

- Each metric receives a definition ID and version before implementation.
- Fiscal year, quarter, inclusion/exclusion, reopened-request, tolling, correction, and snapshot rules must be explicit.
- Certified report runs record definition version, parameters, run time, actor, row counts, totals, and evidence location.
- Corrections create a new certified run; prior evidence is retained.
