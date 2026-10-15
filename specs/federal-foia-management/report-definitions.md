# Federal FOIA Management Report Definitions

**Annual definition ID:** `FOIA-ANNUAL-1.0.0`
**Quarterly definition ID:** `FOIA-QUARTERLY-1.0.0`
**Metric library ID:** `FOIA-METRICS-1.0.0`
**Status:** Design baseline; not a certified agency submission

## Purpose And Authority

These definitions make annual and quarterly values reproducible from Dataverse
records and immutable Clock/Audit Events. They define the planned calculation
contract; they do not replace agency reporting policy, Department of Justice
guidance, or an approved records schedule. A policy change produces a new semantic
version and never rewrites evidence from a prior certified run.

All examples and fixtures are synthetic.

## Versioning

- Major: inclusion, exclusion, boundary, status, or formula semantics change.
- Minor: additive measure or dimension with unchanged existing semantics.
- Patch: clarification or defect correction that does not alter certified values.
- A certified run records all three IDs, source solution version, calendar version,
  query/package hashes, parameters, actor, UTC run time, row counts, totals, and
  evidence references.
- Recalculation under a new definition creates a new run linked to the prior run.

## Common Terms

Let:

- `B` be the report boundary in configured report time zone.
- `S` be the snapshot instant, stored in UTC.
- `FY(Y)` be `[Y-10-01 00:00:00, (Y+1)-10-01 00:00:00)`.
- `Q1`, `Q2`, `Q3`, `Q4` be consecutive fiscal-quarter half-open intervals
  beginning October 1, January 1, April 1, and July 1.
- `Received(r)` be the accepted request received date.
- `Perfected(r)` be the effective date of its first non-superseded Perfected Clock
  Event, adjusted only by later linked Correction Events.
- `Closed(r)` be the effective date of its authoritative Closed Clock Event.
- `OpenAt(r,S)` mean `Perfected(r) <= S` and no authoritative closure effective at
  or before `S`.
- `ClosedIn(r,B)` mean `Closed(r)` is within boundary `B`.
- `AppealOpenAt(a,S)` and `AppealClosedIn(a,B)` use the analogous Appeal Clock Events.
- `CalendarDays(a,b)` be the date difference without excluding weekends, holidays,
  extensions, or tolling.
- `ProcessingDays(a,b,c)` be business days under immutable calendar version `c`,
  excluding only intervals between valid Toll Started and Toll Ended event pairs.
- `FinalPackage(r)` be the latest Released package version effective by `S`.
- `FinalDecision(d,S)` be an Approved, non-superseded decision effective by `S`.

Intervals are start-inclusive and end-exclusive. Instants are converted from UTC
to `foia_ReportTimeZoneId` before date membership is evaluated. Date-only statutory
values remain date-only. Null, invalid, or contradictory dates enter the Data
Quality Exceptions measure and do not receive fabricated defaults.

## Population Rules

### Included Requests

A request is included when it has an accepted tracking number and is not a clearly
synthetic operational test record in a live certified run. Source-tag exclusion is
parameterized and recorded. The committed test suite includes only synthetic data.

### Duplicate, Withdrawn, And Reopened Requests

- A request closed as Duplicate or Withdrawn remains a received/closed request and
  is classified by that disposition; it is not counted as backlog after closure.
- Duplicate candidates that remain active are not excluded.
- A reopened request preserves its original receipt/perfection/closure history.
  For backlog, it is open from the effective Reopen correction/command until the
  next closure. For processing time, the definition reports both original-cycle
  and reopened-cycle values; it never erases the original certified cycle.

### Corrections

An authorized Correction Clock Event may supersede a derived date but not the
original event. The resolver follows explicit `supersedesEventId` links, rejects
cycles/multiple active successors, and records all exception IDs. Corrections
effective after `S` do not affect that snapshot.

### Security And Drill-Through

Aggregates run under a designated reporting identity with approved read access.
Interactive drill-through re-evaluates the viewer's Dataverse row/field security
and SharePoint permission. Aggregate visibility never grants underlying access.

## Shared Metric Formulas

| Metric ID | Name | Formula |
| --- | --- | --- |
| `M-REQ-RECEIVED` | Requests received | `count(distinct r) where Received(r) in B` |
| `M-REQ-PERFECTED` | Requests perfected | `count(distinct r) where Perfected(r) in B` |
| `M-REQ-PROCESSED` | Requests processed | `count(distinct r) where ClosedIn(r,B)` |
| `M-REQ-BACKLOG` | Perfected request backlog | `count(distinct r) where OpenAt(r,S)` |
| `M-REQ-BACKLOG-AGE` | Backlog calendar age | For each backlog request: `CalendarDays(Perfected(r), snapshotDate)` |
| `M-REQ-OLDEST` | Oldest requests | Backlog ordered by `Perfected(r) ASC`, then tracking number; return configured top N |
| `M-REQ-PROC-DAYS` | Processing days | For each closed request: `ProcessingDays(Perfected(r), Closed(r), calendarVersion)` |
| `M-REQ-DUE-RISK` | Due-date risk | Open requests grouped by `currentDueDate <, =, or > snapshotDate`; current due date must replay from Clock Events |
| `M-EXP-REQUESTED` | Expedited processing requested | Distinct requests with expedited-requested time in `B` |
| `M-EXP-DECIDED` | Expedited decisions | Distinct requests with authoritative expedited decision time in `B`, grouped by decision |
| `M-EXP-BACKLOG` | Open expedited requests | `OpenAt(r,S)` and final expedited state by `S` is Approved |
| `M-APL-RECEIVED` | Appeals received | Distinct appeals with accepted received date in `B` |
| `M-APL-CLOSED` | Appeals closed | Distinct appeals with authoritative closure in `B`, grouped by outcome |
| `M-APL-BACKLOG` | Appeal backlog | Distinct appeals where `AppealOpenAt(a,S)` |
| `M-APL-AGE` | Appeal age | For each open appeal: `CalendarDays(appealReceived, snapshotDate)` |
| `M-EXM-APPLIED` | Exemptions applied | Count distinct requests per authority with at least one `FinalDecision(d,S)` included in `FinalPackage(r)` released in `B` |
| `M-FEE-ASSESSED` | Fees assessed | Sum immutable assessed-fee transactions effective in `B` |
| `M-FEE-WAIVED` | Fees waived | Sum approved waiver transactions effective in `B`; report as positive magnitude |
| `M-FEE-COLLECTED` | Fees collected | Sum settled collection transactions effective in `B`, net of reversals in `B` |
| `M-CLK-TOLL` | Toll activity | Count Toll Started events effective in `B`; separately count completed toll intervals and duration |
| `M-CLK-EXT` | Extension activity | Count valid Extension Applied events effective in `B`, grouped by reason and days |
| `M-DQ-EXCEPTION` | Data quality exceptions | Count and classify records rejected by boundary, state, event-chain, currency, or required-field validation |

Distinct-request exemption counts are non-additive across authorities because one
request may use several authorities. The report provides both per-authority
distinct requests and a grand distinct-request total rather than summing groups.

Fee values use the transaction currency's base-currency value at posting. Every
run records base currency. Assessed, waived, collected, refunded/reversed, and
outstanding are separate facts; no amount is inferred from a request status.

## Annual Report Definition `FOIA-ANNUAL-1.0.0`

### Annual Parameters

| Parameter | Rule |
| --- | --- |
| `fiscalYear` | Required four-digit start year |
| `snapshotInstantUtc` | Required; normally the instant immediately after fiscal-year close |
| `reportTimeZoneId` | Must equal approved configuration |
| `calendarVersion` | Required immutable approved version |
| `sourceClassification` | Required inclusion/exclusion rule |
| `topOldestCount` | Required integer, default 10, range 1-100 |
| `definitionIds` | Must exactly match the IDs at the top of this document |

`B = FY(fiscalYear)` and the normal snapshot is the exclusive end of `B`. A late
certification may use a later run time, but the snapshot remains fixed and
post-boundary events are excluded unless a correction definition explicitly says
the event corrects a fact effective within `B`.

### Annual Measures

The annual report emits:

1. Requests received, perfected, and processed during `B`.
2. Request disposition counts from the authoritative closure disposition.
3. Request backlog at `S`, with age bands `0-20`, `21-40`, `41-60`, `61-100`,
   `101-200`, `201-400`, and `401+` calendar days.
4. Oldest open requests using `M-REQ-OLDEST`.
5. Processing-day count distribution: count, minimum, maximum, arithmetic mean,
   median, and percentiles P75/P90/P95. Percentiles use nearest-rank over sorted
   integer processing-day values.
6. Expedited requests, decisions, approved expedited backlog, and their age.
7. Appeals received, closed by outcome, backlog, age bands, and processing days.
8. Exemptions applied by stable authority value and distinct request.
9. Fees assessed, waived, collected, and reversed in base currency.
10. Tolling/extension activity and data-quality exceptions.

Annual backlog is a point-in-time stock and must not be added to quarterly backlog
snapshots. Annual received/processed/fee/event measures are period flows.

## Quarterly Report Definition `FOIA-QUARTERLY-1.0.0`

### Quarterly Parameters

The parameters are the annual parameters plus `fiscalQuarter` (`1` through `4`).
`B` is the selected fiscal-quarter interval and `S` is its exclusive end.

### Quarterly Measures

The quarterly report emits:

1. Received, perfected, processed, and disposition counts in `B`.
2. Backlog at quarter end, age bands, oldest N, and change from prior certified
   quarter-end snapshot.
3. Due-date risk at quarter end: overdue, due today, due in 1-5, 6-10, 11-20,
   and more than 20 calendar days.
4. Expedited requests/decisions in `B` and approved expedited backlog at `S`.
5. Appeals received/closed in `B`, outcome, backlog, and age at `S`.
6. Exemptions applied to packages released in `B`.
7. Fees assessed, waived, collected, and reversed in `B`.
8. Tolling and extensions effective in `B`.
9. Data-quality exceptions and reconciliation status.

Backlog change is:

`current certified quarter-end backlog - prior consecutive certified quarter-end backlog`.

If the prior certified snapshot is missing or uses an incompatible major
definition version, change is `Not comparable`, not zero.

## Operational Dashboard Boundaries

Operational dashboards use a displayed `asOfUtc` and the same event resolver:

- Active FOIA Requests: active state and not closed at `asOfUtc`.
- New and Unperfected: accepted but no effective Perfected event by `asOfUtc`.
- Overdue: open and current replayed due date before configured local current date.
- Ready for Release: package Approved, all included item versions/hashes unchanged,
  request in Release, and no blocking task/hold.
- Pending Decisions: Proposed, Pending independent approval, or Returned.

Operational dashboards are not certified annual/quarterly reports unless a
certified-run record references their exact metric definition and snapshot.

## Certified Run And Evidence Contract

Each run writes a non-editable certified-run record containing:

- run ID, prior run/correction link, definition IDs and hashes;
- fiscal year/quarter, boundary start/end, snapshot UTC, report time zone;
- calendar version, solution version, source-classification rule;
- initiated/completed UTC, actor/application identity, status, correlation ID;
- source row counts by table and immutable-event high-water marks;
- measure results, exception counts, reconciliation status;
- query/package hash, output hash, and approved evidence references;
- preparer, reviewer, certifier, and their independent approval times.

A failed or exception-bearing run remains retained. Certification requires zero
unresolved critical exceptions; approved noncritical exceptions require owner,
rationale, and corrective due date.

## Reconciliation

For every run:

1. Record source counts for Requests, Appeals, Decisions, Packages, fee
   transactions, Clock Events, and Audit Events.
2. Recalculate current due dates by event replay and compare to projected request
   values; mismatches are critical.
3. Reconcile processed requests to one authoritative closure and disposition.
4. Reconcile released packages to approved manifest/hash and release Audit Event.
5. Reconcile exemptions to approved decisions included in the released package.
6. Reconcile fee totals to immutable transactions and base currency.
7. Verify population partitions and list exception record IDs in protected
   evidence, not in source control.

## Synthetic Boundary Test Catalog

- Receipt at boundary start, one tick before end, and exactly at end.
- UTC instant crossing local midnight and daylight-saving transitions.
- Perfection before receipt (critical exception).
- Open, closed, reopened, and reclosed requests.
- Toll start/end spanning fiscal year and quarter boundaries.
- Extension followed by correction.
- Multiple exemption authorities on one request.
- Package approved in one period and released in the next.
- Appeal received at quarter end and closed in a later quarter.
- Fee assessment, waiver, collection, and reversal in different periods.
- Missing prior quarterly snapshot (`Not comparable`).
- Post-snapshot correction and recertification with original evidence retained.

## Change And Approval

Changes require FOIA Reporting Lead, Records and Compliance Officer, security
reviewer, and solution owner approval. Formula-changing revisions require
parallel calculation against synthetic fixtures and, when later authorized,
protected historical data. Prior definition packages and certified runs remain
immutable.
