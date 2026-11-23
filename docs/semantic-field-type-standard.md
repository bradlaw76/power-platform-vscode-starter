<!--
Component: Semantic Field Planning Standard
Purpose: Select native field semantics without implying migration or runtime gates.
Owner: Power Platform VS Code Starter
Version: 1.0.0
-->

# Semantic Field Type Standard

Planning reference adapted independently from the
[PR #4 semantic standard](https://github.com/bradlaw76/power-platform-vscode-starter/blob/8d35b723852dbc0a218a29cebd877d6bc1cc128a/docs/semantic-field-type-standard.md).
This does not adopt its skills, preflight, installer or protection package.
It changes no payload schema, execution behavior or existing column.

## Business meaning determines type

Reuse a compatible standard or existing field first. Choose the native type
from business meaning, not a sample string, label or storage convenience.
Unknown intent is an open decision, never permission to default to text.
Use business display labels separately from schema/logical names.

| Meaning | Native Dataverse representation | Decisions to record |
| --- | --- | --- |
| Short narrative, external identifier | StringAttributeMetadata / Text | Length, localization, uniqueness; preserve leading zeros in identifiers |
| Email, telephone, web address | StringAttributeMetadata / Email, Phone, Url | Format, length and validation; telephone numbers are not numeric |
| Long narrative | MemoAttributeMetadata | Length, plain/rich text and rendering |
| Whole-number count | IntegerAttributeMetadata | Bounds, units and whether negatives are meaningful |
| Exact fraction or rate | DecimalAttributeMetadata | Precision, bounds, units and percentage scale |
| Approximate scientific measurement | DoubleAttributeMetadata | Precision/range and justification for approximation |
| Financial amount | MoneyAttributeMetadata | Currency relationship and precision behavior; not text or floating point |
| Two-state fact | BooleanAttributeMetadata | Explicit labels/default and unknown/not-applicable handling |
| One finite category | PicklistAttributeMetadata / Choice | Local/global ownership, stable numeric options, labels, meanings and default |
| Multiple independent categories | MultiSelectPicklistAttributeMetadata | Approved multi-value need and reporting limits; consider related rows |
| Reference to another record | LookupAttributeMetadata through a relationship | Target, cardinality, requiredness, cascade and supporting user task |
| Calendar date | DateTimeAttributeMetadata / DateOnly format and DateOnly behavior | No time-zone conversion; date/deadline meaning |
| Real-world instant | DateTimeAttributeMetadata / DateAndTime, UserLocal | Input time zone, UTC persistence and display |
| Viewer-independent wall-clock date/time | DateTimeAttributeMetadata / DateAndTime, TimeZoneIndependent | Justification for identical displayed time |
| Duration | IntegerAttributeMetadata / Duration | Minutes, bounds and calendar-versus-elapsed arithmetic |
| File or image | FileAttributeMetadata / ImageAttributeMetadata | Actual supported runtime/API, size, access and retention |
| Platform status, owner, customer, calculated value | Compatible platform metadata | Existing semantics, supported targets/transitions and dependencies |

DateOnly format alone does not establish DateOnly behavior. Choice labels are
not stored numeric options. Boolean is not a substitute for multi-state status,
and a record name stored as text is not a lookup.

## Approved decisions and dependent surfaces

Keep stable field/requirement identifiers and accepted decisions in the existing
scenario artifacts. Complete and explicitly approve the target's
`specs/<scenario-slug>/field-type-decisions.json` and aligned spec/plan before
column payload generation. Do not replace that contract with the historical
proposal's `field-catalog.md`, add a parallel approval store or auto-approve
legacy plans. If the target lacks its required decision schema or validation
runtime, report that gate unavailable and prepare a reviewed compatibility plan.

Record intent, existing/new status, native type/format/behavior, requiredness,
constraints, rationale, provenance and verification for every field.
Resolve categorical candidates as Yes/No, Choice, multi-select Choice, Lookup,
or an explicitly approved text exception. Include stable option values,
meanings, defaults, source mappings and dependent forms, views, processes,
reports and data. Preserve their IDs and exact relationship semantics.

Distinguish actual metadata from operator inventory and assumptions. A wrong
existing type requires separately approved compatibility/migration work; never
delete/recreate a String column, silently alter accepted intent or substitute
text to conceal unsupported native metadata.

## Runtime and evidence boundary

Payloads remain the executable source of truth for labels, schema and order.
Review the actual [column schema](../schemas/payloads/columns.schema.json),
[onboarding sequence](onboarding.md) and target runtime before promising type
support. A permissive JSON schema does not prove native semantics.

This candidate does **not** include `14-validate-semantic-fields.ps1` or the
field-type decision validation schema. Adding this document does not provide
Planning/Payload/Metadata enforcement or migration. Never claim those controls
are installed, skip a required gate or run an unapproved build because this
reference exists. Report unsupported types or missing mandatory checks as
BLOCKED rather than using success-shaped fallbacks.

After a separately authorized build, compare actual native metadata and test
the dependent user surfaces. Planning/source checks are not live verification.
Follow the existing [authorization policy](policies/authorization-and-execution.md);
this reference grants no column, migration, commit, merge or deployment approval.
