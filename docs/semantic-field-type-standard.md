# Semantic Field Type Standard

## Purpose and applicability

The wizard MUST select Dataverse column types from the **semantic meaning and
behavior of the data**, not how values appear in requirements, spreadsheets,
screenshots, sample records or source systems. Dataverse is the Power Platform
data service; a column's metadata determines its behavior, not its displayed label.

This is a mandatory planning and validation gate for **every Dataverse
implementation**: every industry, agency, department, process, application and
use case; greenfield and retrofit; demos, proofs of concept, accelerators and
production-oriented builds; standard-table extensions, custom tables and hybrid
designs. It applies to all three wizard modes and is independent of FAST or any
other provider. Fully Custom is not an exemption.

## 1. Required semantic classification

Before generating **any** `columns-*.json`, classify every planned field exactly
once: free text; identifier/code; whole number, decimal, floating point or
currency; date/time; Yes/No; Choice; multi-select Choice; Lookup; File; or Image.
Do not default a field to text because its source values are strings.

## 2. Type selection principles

Resolve business meaning, allowed-value ownership, validation, cardinality,
reporting/filtering, automation, integration, security/ownership, allowed-value
lifecycle and future extensibility for every field. The chosen type MUST support
intended business behavior rather than merely accept current sample data.

## 3. Deterministic selection rules

| Semantic category | Required design |
| --- | --- |
| Free text | String or Memo only for genuinely open-ended descriptions, comments, notes or titles. Never use text for a bounded business vocabulary without an approved exception. |
| Identifier or code | Text is appropriate for external IDs, tracking/policy/application numbers, employee codes and legacy keys, even when a finite set currently exists. Resolve maximum length, uniqueness, alternate keys, case sensitivity, formatting, leading zeros and source ownership. Numeric-looking identifiers normally remain text when arithmetic is meaningless. An identifier references something; it is not automatically a category. |
| Numeric or currency | Use Integer, Decimal, Double or Money when arithmetic, aggregation, numeric sorting, ranges or numeric validation matter, even if source values are strings. Resolve whole versus decimal, precision, minimum/maximum, rounding and units. For Money, resolve currency, base-currency behavior and precision source. |
| Date/time | Use DateTime for calendar dates and points in time. Resolve Date Only versus Date and Time, DateOnly/UserLocal/TimeZoneIndependent behavior, precision and integration timezone. Text requires an explicit interoperability justification and approved exception. |
| Yes/No | Boolean requires exactly two logical states. Unknown, Pending, Not Applicable, Not Evaluated and Undetermined are additional business states, not false. Use Choice or another model when these states matter. |
| Choice | Picklist is for stable, bounded, business-owned vocabularies such as status, priority, severity, type, category, outcome, disposition, review result, channel and processing method. Sample labels `New`, `Approved`, `Pending` and `Completed` MUST NOT produce String metadata. |
| Multi-select Choice | MultiSelectPicklist requires simultaneous multiple values, a bounded vocabulary, and explicit acceptance of Dataverse filtering, automation, integration and reporting characteristics. Evaluate related records, many-to-many and intersect-table alternatives first. |
| Lookup | Prefer governed records over labels when the concept has attributes, lifecycle, ownership/security, other relationships, effective dates, hierarchy, administrative management or extensibility. Departments, offices, programs, facilities, vendors, organizations, employees and contracts commonly qualify. A short list alone does not justify Choice. |
| File or Image | Use native File/Image metadata for binary content, never ordinary text containing file/image/document payloads. Resolve maximum size, image behavior and primary-image requirements, integrations and storage implications. |

## 4. Categorical candidate detection

Treat any business concept with bounded allowed values as a categorical candidate,
even when its name contains no common signal. Signals include Status, State,
Stage, Phase, Lifecycle, Type, Kind, Category, Class, Classification, Disposition,
Outcome, Result, Decision, Resolution, Channel, Method, Mode, Source, Destination,
Repository, Reason, Priority, Severity, Risk, Tier, Level, Access, Approval,
Review, Validation, Verification, Eligibility, Frequency, Cadence, Format,
Region, Segment and organizational classification.

This is a detection aid, not a naming rule. The planner explicitly records
`categoricalCandidate` and `boundedValues` from business meaning. Runtime also
flags common categorical text names/meanings; this heuristic cannot replace
semantic review. Finite identifier examples are not a bounded business vocabulary.
`boundedValues` means a business vocabulary, not a numeric/date validation range.

## 5. Choice versus Lookup decision

Explicitly resolve every categorical candidate to Yes/No, Choice, multi-select
Choice, Lookup or an approved text exception.

| Question | Choice signal | Lookup signal |
| --- | --- | --- |
| Just labels with stable meanings? | Yes | |
| Additional attributes? | | Yes |
| Independent lifecycle? | | Yes |
| Ownership or security? | | Yes |
| Reused common vocabulary? | Yes | Possibly |
| Administrators dynamically create records? | | Yes |
| Relationships to other records? | | Yes |
| Centrally governed, rarely changed vocabulary? | Yes | |
| Effective dates or hierarchy? | | Yes |

## 6. Choice design

Use global Choice only when the **same semantic vocabulary** is intentionally
shared across fields/tables. Use local Choice for a vocabulary exclusive to one
field. Similar labels on unrelated fields are not grounds for global reuse.

Every option MUST have a stable numeric value. Once deployed or referenced,
values MUST NOT be renumbered merely to change display order. Identity and display
order are different concerns.

Planning defines logical/schema name, scope, numeric values, labels, meanings,
default (or explicitly none), relevant display order, localization, deterministic
sample/integration mappings and existing-value mappings for retrofit. Array order
in the option inventory records approved display order. Unknown values MUST NOT
silently map to an arbitrary option. A global definition must exist and match the
approved vocabulary before a field is bound to it; stage 30 does not invent one.

## 7. Text exception rule

A categorical candidate may remain text only when `spec.md` and `plan.md`
document the same reason, considered Choice/Lookup alternative, and reporting,
filtering, automation, integration and data-quality consequences, and the user
**explicitly approves the exception**. General architecture approval is not a
substitute. Without separate documented approval, column generation is blocked.
Do not disguise dates, numbers or binary content as free text to evade review.
An approved date interoperability exception retains `semanticCategory: date-time`
and explicitly selects String/Memo with length, precision and integration
timezone decisions, rather than misclassifying the value as open-ended text.

## 8. Required planning gate and decision inventory

Scenario planning MUST contain a complete field-type decision table, covering
every planned field exactly once, including reused and primary fields.

| Decision | Table | Field | Business meaning | Semantic category | Bounded values? | Dataverse type | Scope or target | Rationale |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FIELD-processing | sample_workitem | sample_processing | Current operational processing state | choice | true | Picklist | local:sample_processing | Stable business-owned workflow vocabulary, not governed reference records. |

Maintain the machine-readable table in
`specs/<slug>/field-type-decisions.json` and matching human-readable decision rows
in both `spec.md` and `plan.md`. Each row uses a stable `FIELD-...` decision ID.
Both documents must reference the JSON inventory and every decision ID; `tasks.md`
must reference the inventory and include validation/remediation tasks.
Use the column order above, logical table/field names, schema category tokens,
`true`/`false`, the metadata class without `AttributeMetadata`, and
`local:<name>`/`global:<name>`, Lookup target logical name, or `-` for scope.
The gate compares each row against the approved inventory and rejects duplicates,
missing, extra or conflicting rows. Escape literal cell pipes as `\|`.
The [schema](../schemas/payloads/field-type-decisions.schema.json) and
[synthetic example](../schemas/examples/field-type-decisions.example.json) define
the executable shape. Example approvals are test data, not approval for a build.

The inventory records business meaning, category, bounded/categorical flags,
selected metadata, rationale, all ten selection factors, type-specific settings,
disposition, dependencies and explicit vocabulary decisions for forms, views,
charts, BPFs, automation, integrations and reports. Mark unused surfaces
`not-applicable` with a reason; never silently assume they do not apply.

`expectedMetadata` is approved design, not a second deployed source of truth:
generated payloads MUST match it. Payloads remain the source of truth for schema,
business labels and ordering during execution. Changes require aligned planning,
payloads and approval; never silently reconcile a mismatch.

## 9. Required Choice inventory and mappings

Each `choice` contains scope/name, options with numeric `value`, localized
`labels` and business `meaning`, `default` (null means none), localization and
sample/integration/retrofit mappings. Each mapping declares applicability,
reason and deterministic source-to-option entries; applicable empty, duplicate
or unknown mappings block execution. Multi-select Choice has no default.

For example, `NEW -> 100000000 (New)`, `IN_PROGRESS -> 100000001 (In Progress)`
and `DONE -> 100000002 (Completed)` are explicit mappings, not label guessing.
Convert approved source values before writing seed payloads. Seed payloads must
already contain approved numeric values (multi-select uses Dataverse's
comma-separated numeric representation); stage 66 does not guess mappings.

## 10. Stage 30 blocking gate and operator sequence

Stage 30 MUST NOT execute, and column payloads MUST NOT be generated, until every
field/category/type is resolved; categorical text exceptions are explicitly
approved; Lookup targets are known; Choice scope/values/labels/meanings/defaults
and deterministic sample/retrofit mappings are approved; and every applicable
form, view, chart, BPF, automation, integration and report uses the vocabulary.

Follow [onboarding](onboarding.md), the authoritative stage order:

```powershell
# After completing and approving spec/plan/tasks and the semantic inventory:
pwsh .\scripts\bootstrap\14-validate-semantic-fields.ps1 -ScenarioSlug <slug> -Mode Planning
# Only then generate columns/relationships from approved decisions:
pwsh .\scripts\bootstrap\14-validate-semantic-fields.ps1 -ScenarioSlug <slug> -Mode Payload
# Use the normal orchestrator; Preview validates local design, never authenticates:
pwsh .\scripts\bootstrap\90-run-build.ps1 -ScenarioSlug <slug> -Mode Preview
```

The orchestrator runs Payload validation **before any build stage**, even on
resume. Direct stage 30 requires `-ScenarioSlug` or an unambiguous scenario
payload path and applies the same gate. There is no legacy bypass. Terminal
intake produces a deliberately unapproved draft; planning is not complete until
it is resolved and approved. Do not auto-upgrade/approve historical scenarios.
The software checks complete decision-row consistency and structure; human review
must verify the inventory is semantically correct and covers the requirements.

## 11. Payload generation rules

Choice -> Picklist; multi-select -> MultiSelectPicklist; Yes/No -> Boolean;
Lookup -> relationship/Lookup; whole/decimal/floating -> Integer/Decimal/Double;
currency -> Money; date/time -> DateTime; File -> File; Image -> Image;
free text/identifiers -> appropriate String/Memo (identifiers normally String).
Never infer `StringAttributeMetadata` from textual categorical sample values.

Explicit Lookup metadata, target, schema, requiredness, cardinality and cascade
behavior must be planned. No relationship label/type inference is allowed by
this gate. Stage 20's generated primary-name fields also belong in the inventory
as `table-primary`; they are String, length 100, business label Name and
ApplicationRequired under the current table runtime.

## 12. Post-build validation

After stage 30, query live metadata for created/reused attributes, including
every non-text type. Stage 30 preflights all applicable existing fields before
creating any missing columns; only a genuine HTTP 404 permits creation.
Authentication, permissions and transport errors are not evidence of absence.
Use the shared 401-refresh/429-backoff runtime and scoped publication.

Verify actual type, required level and applicable length/precision/range,
date/time behavior and size settings. For Choices also verify global/local
scope, global binding, numeric options, labels and default. For Lookups verify
target, schema, relationship and cascade behavior. A correct-looking label or
form control is NOT proof. Live metadata is authoritative for deployment checks.
Approved stage-35 inline label decoration is presentation, not a new vocabulary.
Reused system State/Status fields retain their native State/Status metadata;
they are not recreated as custom Picklists. Reused Customer/Owner lookup
subtypes must explicitly declare their approved `AttributeTypeName` and targets.

New Lookups do not exist until stage 40: run the GET-only stage-14 Metadata gate
after relationships, and again before export. The orchestrator includes both
gates and does not skip them on resume; changed design/payload bytes invalidate
resume scope. Direct stage 95 also reruns live semantic validation after its
membership check and before invoking PAC; cached success is not sufficient.
For manual validation, invoke:

```powershell
pwsh .\scripts\bootstrap\14-validate-semantic-fields.ps1 -ScenarioSlug <slug> -Mode Metadata
```

Separately validate appropriate form controls, view filtering/sorting, chart
aggregation/grouping, BPF/process behavior, automation underlying values,
integration representations and report usability. Record evidence and
created/updated/skipped/failed counts in [build-log.md](build-log.md).
An approved surface design assertion is not evidence that functional tests ran.

## 13. Drift detection

Mismatch is configuration drift: report expected and actual type/settings,
identify affected dependencies, stop dependent workflows and require remediation
planning. Never rewrite approved intent to match an incorrect deployment.

## 14. Retrofit safety

Dataverse cannot convert an existing String attribute directly to Choice in
place. Normal column generation MUST NOT perform destructive retrofit operations.
Plan a separate reviewed migration, in this order:

1. Read-only value inventory and dependency inventory.
2. Identify every distinct existing value and define deterministic mappings.
3. Block on foreign, unknown, ambiguous or unmapped values.
4. Create/verify a fresh unmanaged solution backup. A solution is a deployment
   package; unmanaged retains editable components. Export is not a data backup.
5. Record dependencies to remove/restore and their restoration sequence.
6. Obtain separate explicit destructive approval.
7. Capture a pre-change snapshot sufficient for data and dependency rollback.
8. Remove blockers only after approval, then delete String only after all
   approved prerequisites pass.
9. Recreate the approved schema name as Choice only when technically supported
   by the reviewed procedure; otherwise stop and revise the migration plan.
10. Restore data deterministically, restore dependencies and publish only
    required changed components.
11. Validate live metadata, forms, views, charts, BPFs/processes, automation,
    integrations, reports, solution membership, idempotency and solution export.

This change adds no migration executor and no implicit delete/recreate path.

## 15. Failure-safe principle

Ambiguous semantic intent MUST stop for a design decision rather than create
technically valid but semantically incorrect metadata.

> Do not optimize for successful metadata creation. Optimize for correct semantic modeling.
