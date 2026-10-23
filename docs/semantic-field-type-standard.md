# Semantic Field Type Standard

Status: Active for architecture planning. This standard does not migrate
existing columns or change payload schemas or execution behavior.

## Core rule

Select the Dataverse type from the business meaning, not the sample value,
label alone, or convenience of text storage. Reuse a compatible standard or
existing column first. Record semantic intent, native type and format,
constraints, and rationale for every field. Unknown intent is an open decision,
not permission to default to text. Use business display labels, with separate
publisher-prefixed schema and logical names for custom metadata.

| Business meaning | Native Dataverse representation | Required planning decisions |
| --- | --- | --- |
| Short free text, names, external identifiers | StringAttributeMetadata, Text format | MaxLength, Unicode/localization needs, uniqueness; identifiers/postal codes keep leading zeros |
| Email address | StringAttributeMetadata, Email format | MaxLength, validation and whether multiple addresses need related rows |
| Telephone number | StringAttributeMetadata, Phone format | International formatting/extension; never numeric |
| Web address | StringAttributeMetadata, Url format | Allowed schemes and validation; not generic text |
| Long narrative | MemoAttributeMetadata | MaxLength, plain/rich text intent and supported rendering |
| Whole-number count | IntegerAttributeMetadata | MinValue, MaxValue, negative values and units |
| Exact fractional measurement/rate | DecimalAttributeMetadata | Precision, MinValue, MaxValue, units; percentage scale (0-1 or 0-100) |
| Approximate scientific value | DoubleAttributeMetadata | Precision/range and explicit reason approximation is acceptable |
| Financial amount | MoneyAttributeMetadata | Precision/PrecisionSource, currency behavior and transactioncurrency relationship; not Decimal or text by default |
| Two-state business fact | BooleanAttributeMetadata | Explicit true/false labels, default, and unknown/not-applicable handling |
| One finite category | PicklistAttributeMetadata (Choice) | Local/global choice, stable option values, localized labels and defaults |
| Multiple independent categories | MultiSelectPicklistAttributeMetadata | Approved need for multiple values; reporting/filtering limits; consider related rows instead |
| Reference to a record | LookupAttributeMetadata through a relationship payload | Referenced table, cardinality, requiredness, cascade behavior; never a record name stored as text |
| Calendar date (birthday, statutory date) | DateTimeAttributeMetadata, DateOnly format and DateOnly behavior | No time-zone conversion; date semantics and any deadline rule |
| Real-world instant (submitted at) | DateTimeAttributeMetadata, DateAndTime format, UserLocal behavior | Input time zone, UTC persistence and user-local display |
| Wall-clock date/time independent of viewer zone | DateTimeAttributeMetadata, DateAndTime format, TimeZoneIndependent behavior | Why identical displayed time is required across zones |
| Duration | IntegerAttributeMetadata, Duration format | Minutes and bounds; distinguish elapsed time from calendar arithmetic |
| File/image content | FileAttributeMetadata / ImageAttributeMetadata | Supported API/runtime path, size, access, retention; never base64 in a text column |
| Platform status, owner, customer, autonumber, calculated/rollup value | Compatible platform metadata or explicit supported design | Existing semantics, allowed transitions/targets, runtime capability and dependencies; never invent a payload type |

`DateOnly` format alone is not sufficient: explicitly plan date/time behavior.
Choice labels are not stored option values. Boolean is not a substitute for
multi-state status. A lookup is not just a String column. Formats provide
platform semantics but do not replace business validation or privacy controls.
Do not use floating point for exact financial arithmetic.

## Field catalog contract

Under the approved application's `specs/<scenario-slug>/field-catalog.md`,
use one row per reused or planned field:

| Field ID | Requirement IDs | Table | Business label | Schema/logical name | Existing/new | Semantic intent | Native type/format/behavior | Requiredness/default | Constraints/options/targets | Privacy/security | Rationale/evidence | Payload path | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| FLD-001 | REQ-001 | example_request | Contact Email | example_contactemail | new | One contact email address | StringAttributeMetadata / Email | optional / none | MaxLength 254 | personal data; approved access | Business contact requirement | payloads/scenarios/example/columns-request.json | Read back type and Email format; validate valid/invalid input |

Examples are illustrative, not approved deployment payloads or a real scenario.
Record confidence and provenance for existing metadata: distinguish verified
metadata from operator-provided inventory and unverified assumptions. Existing
type mismatches require an explicit migration/compatibility decision; never
silently alter or recreate a column or claim live verification offline.

## Payload compatibility and review gate

Payloads remain the source of truth for executable schema, labels, and order.
Map approved catalog decisions to the existing
`schemas/payloads/columns.schema.json` and relationship payload contracts; use
proper `@odata.type`, `DisplayName.LocalizedLabels`, and `RequiredLevel.Value`.
For example, an Email field uses this column object inside the existing
`TableLogicalName` / `Columns` envelope:

```json
{
  "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
  "SchemaName": "example_contactemail",
  "DisplayName": {
    "LocalizedLabels": [{ "Label": "Contact Email", "LanguageCode": 1033 }]
  },
  "RequiredLevel": { "Value": "None" },
  "MaxLength": 254,
  "FormatName": { "Value": "Email" }
}
```

The permissive JSON schema does not prove native-type support or semantics.
Check the actual stage, Dataverse metadata API, target capabilities, and
preview output. Mark unsupported or unverified types/configurations **blocked**
with the required reviewed implementation or manual handoff; never substitute
text or promise the current scripts support every type above.

Before architecture approval, verify every field has a requirement and semantic
decision, relationships have explicit targets/cascade behavior, date/time and
money semantics are unambiguous, choices have stable values, and payload intent
matches the catalog. Track exceptions with rationale, owner, approval and
verification. After a separately approved build, compare live metadata with
these decisions; that validation is not performed by the planning skills.
