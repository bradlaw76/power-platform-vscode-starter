<!--
Component: Semantic Field Type Decision Standard
Purpose: Prevent business semantics from being lost through incorrect Dataverse column-type selection.
Owner: Power Platform VS Code Wizard
Version: 1.0.0
Status: Mandatory for every Dataverse use case
-->

# Semantic Field Type Decision Standard

## Scope

This standard applies to every Dataverse solution handled by the wizard:

- Any industry, department, process, or application domain
- Greenfield and retrofit projects
- Demonstrations, proofs of concept, and production-oriented builds
- Standard-table extensions, custom tables, and hybrid designs
- Model-driven apps and other solutions that generate Dataverse column metadata

The wizard must select column types from business meaning, validation needs,
reporting behavior, automation behavior, and ownership of the allowed values.
It must not infer a text column merely because requirements or sample records
represent values as words.

## Required Classification

Classify every planned field before generating a column payload:

| Classification | Use when |
|---|---|
| Single-line or multiline text | The value is genuinely open-ended prose. |
| Identifier or code | The value identifies a record or external object and is not a controlled business vocabulary. |
| Number, currency, or decimal | Numeric comparison, aggregation, or calculation is required. |
| Date/time | Date or time semantics, ordering, or calculations are required. |
| Yes/No | Exactly two stable logical states exist. |
| Choice | A bounded list of stable business values exists. |
| Multi-select Choice | Multiple values from a bounded vocabulary may apply simultaneously and a relationship is not required. |
| Lookup | Allowed values are governed records with their own attributes, ownership, lifecycle, or relationships. |
| File or image | The field stores document or image content supported by Dataverse. |

## Categorical Candidate Signals

Treat a field as a categorical candidate when its business meaning describes a
bounded vocabulary. Names commonly include, end with, or imply:

- Status, state, stage, phase, or lifecycle
- Type, kind, category, class, or classification
- Disposition, outcome, result, decision, or resolution
- Channel, method, mode, source, destination, or repository
- Reason, priority, severity, risk, tier, or level
- Access, approval, review, validation, verification, or eligibility
- Frequency, cadence, format, region, segment, or business unit classification

This list is a detection aid, not a naming requirement. A field with an
unrelated name is still categorical when its allowed values are bounded.

## Type Selection Rules

1. Use Choice when a stable bounded vocabulary controls validation, filtering,
   reporting, automation, or user selection.
2. Use Yes/No only when the meaning is truly binary. Do not use it when
   Unknown, Not Applicable, Pending, or another state is required.
3. Use a lookup when each allowed value needs independent metadata, ownership,
   lifecycle, relationships, security, or administrator-managed records.
4. Use multi-select Choice only when simultaneous values are valid and the
   limitations of multi-select filtering, automation, and reporting are
   acceptable.
5. Use text for open-ended content or identifiers, not as a shortcut for
   controlled values.
6. Use a global Choice when multiple fields share the same semantic vocabulary.
   Use a local Choice when the vocabulary is specific to one field.
7. Define stable numeric option values. Do not renumber existing options merely
   to change display order.
8. Define labels, descriptions, defaults if any, localization needs, and
   deterministic sample-data mappings during planning.
9. A categorical-looking field may remain text only when `spec.md` and
   `plan.md` record the rationale, consequences, and explicit user approval.
10. Unresolved field types block column-payload generation and stage 30.

## Required Planning Artifact

Add a field-type decision table to `spec.md`, `plan.md`, or a referenced
scenario design artifact:

| Table | Field | Business meaning | Bounded values? | Selected Dataverse type | Scope or target | Rationale |
|---|---|---|---|---|---|---|
| Work Item | Processing Status | Current operational state | Yes | Choice | Global `processing_status` | Shared workflow and reporting vocabulary |
| Work Item | Priority | Relative processing urgency | Yes | Choice | Global `priority_level` | Stable values used for sorting and automation |
| Work Item | Is Escalated | Whether escalation is active | Yes, binary | Yes/No | Not applicable | Exactly two logical states |
| Work Item | Owning Department | Department responsible for the item | Governed records | Lookup | Department table | Departments have names, owners, and lifecycle |
| Work Item | External Reference | Identifier assigned by another system | No business vocabulary | Single-line text | Maximum length and alternate-key decision | Identifier rather than category |
| Work Item | Description | User-entered details | No | Multiline text | Plain text | Open-ended content |

For each Choice, also record:

| Choice | Scope | Numeric value | Label | Meaning | Default? |
|---|---|---:|---|---|---|
| `processing_status` | Global | 100000000 | New | Work has not started | Yes |
| `processing_status` | Global | 100000001 | In progress | Work is actively being processed | No |
| `processing_status` | Global | 100000002 | Completed | Processing is complete | No |

## Pre-Build Gate

Before stage 30:

- Every planned field appears in the decision table.
- Every categorical candidate has a resolved Choice, Yes/No, lookup, or
  explicitly approved text decision.
- Choice scope, numeric values, labels, defaults, and sample-data mappings are
  complete.
- Forms, views, charts, business process flows, automation, integrations, and
  reports use the same vocabulary definitions.
- Column payload metadata matches the approved decisions.

## Post-Build Validation

After stage 30:

- Query live Dataverse attribute metadata.
- Verify the actual attribute type for every planned Choice, multi-select
  Choice, Yes/No, lookup, number, currency, date/time, file, and image field.
- Verify global Choices bind to the intended option set.
- Verify option values and labels match the approved design.
- Verify forms render an appropriate control and views, charts, automation, and
  reports can use the field as intended.

Displayed labels or controls are not sufficient proof of the underlying
Dataverse metadata type.

## Retrofit Rule

Dataverse cannot change an existing String attribute to Choice in place. A
retrofit requires:

1. Read-only value and dependency inventory
2. Deterministic old-value-to-option-value mapping
3. Foreign or unmapped value blocking
4. Fresh unmanaged backup
5. Dependency removal and restoration plan
6. Separate destructive approval
7. Snapshot and rollback capability
8. Same-name deletion and recreation when approved
9. Data restoration, scoped publication, and metadata verification
10. Form, view, chart, process, automation, reporting, membership, idempotency,
    and export validation
