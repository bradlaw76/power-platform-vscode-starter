# Federal FOIA Management Security Model

**Security model ID:** `FOIA-SEC-MODEL-1.0`
**Authorization status:** Full model is design only. The bounded three-role demo
increment was separately approved and applied on 2026-10-15. Role assignment and
all broader production-security work remain unauthorized.

## Current Demo Implementation Boundary

The production-oriented model in this document remains authoritative for future
hardening. The current demo implements only:

- `FOIA Demo Processor`
- `FOIA Demo Approver`
- `FOIA Demo Release Officer`

The demo increment creates role definitions only. It does not create tenant
identities, assign roles, create teams or business units, configure queues, create
field-security profiles, provision SharePoint, or automate SharePoint permissions.
Existing approved test accounts may be assigned later through a separate operator
step.

Dataverse automatically attaches four Global SharePoint integration metadata
privileges to newly created roles: `Create/Read/Write SharePointData` and
`Read SharePointDocument`. Stage 68 reports but does not manage this platform
baseline. These privileges do not provision SharePoint or grant access to
SharePoint sites, libraries, folders, or documents.

The three roles demonstrate coarse table and action boundaries. They do not, by
themselves, enforce proposer/approver identity separation, controlled status
transitions, immutable Clock/Audit Events, or document access. Those controls
remain deferred to server-side commands and plug-ins plus independent SharePoint
authorization. Synthetic data is mandatory, and this increment must not be
represented as production security readiness.

## Security Principles

- Deny by default and grant only the privileges needed for a named task.
- Separate request ownership, work routing, controlled proposal, approval, and
  release authority.
- Treat Dataverse and SharePoint as independent authorization boundaries.
- Use immutable IDs and server-side enforcement for security-significant actions.
- Never place production data, credentials, access tokens, tenant identifiers, or
  sensitive evidence in source control.
- Keep the core control set available in GCC High and portable to IL5 without
  optional Azure services.

## Organizational Boundary

- Business units represent approved FOIA program-office boundaries.
- Owner teams own program-office Requests, Search Tasks, Review Tasks, and Appeals.
- User-owned work may be assigned within the owning business unit.
- Access teams grant documented, time-bounded collaboration on a specific request.
- Queues route work; queue membership alone does not grant record or document access.
- Cross-business-unit sharing requires purpose, expiration, approver, and an Audit
  Event. Broad organization-level read is limited to approved oversight roles.

## Role And Privilege Matrix

Privilege codes are `C` create, `R` read, `W` write, `A` assign, `S` share,
`P` append/append-to, and `X` controlled action. Scope is `U` user, `BU`
business unit, `PC` parent-child business unit, or `O` organization. A dash means
no direct privilege. All roles receive only the minimum supporting reference-table
read privileges required by the model-driven app.

| Role | Request/Case | Search/Record | Review | Decisions | Package | Appeal | Clock/Audit | Controlled actions |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Intake Specialist | CRWAP-S BU | R BU | - | - | - | - | R BU | Accept intake; request clarification |
| FOIA Processor | RWAP-S BU | CRWAP-S BU | CRWAP BU | R BU | R BU | R BU | R BU | Coordinate request; no final approval/release |
| Search Coordinator | R BU | CRWAP-S BU | R BU | - | - | - | R BU | Assign/submit search |
| Custodian | R U/shared | RW U/shared | - | - | - | - | R U/shared | Complete assigned collection only |
| Reviewer | R U/shared | R U/shared | CRWAP U/shared | C/R U/shared | R U/shared | - | R U/shared | Propose review/decision; no approval |
| Legal Reviewer | R BU | R BU | RW BU | CRWAP BU | R BU | RW BU | R BU | Propose/approve legal decision subject to separation rules |
| Supervisory Approver | R PC | R PC | R PC | RW-X PC | RW-X PC | R PC | R PC | Independent approve/reject/return |
| Release Officer | R PC | R PC | R PC | R PC | CRW-X PC | R PC | R PC | Assemble and release independently approved package |
| Auditor | R O | R metadata O | R O | R O | R O | R O | R O | Read/reconcile/export through audited action; no operational write |
| Administrator | Metadata/config O | Metadata/config O | Metadata/config O | Metadata/config O | Metadata/config O | Metadata/config O | R O | Configure; cannot approve/release merely by administrator role |

`S` is shown only where sharing is part of the role. Share commands are still
server validated and audited. Administrator does not receive document content,
final-approval, or release authority by implication; break-glass access is a
separate governed process.

## Separation Of Duties

| Controlled action | Proposer | Required final actor | Prohibited combinations |
| --- | --- | --- | --- |
| Exemption determination | Reviewer or Legal Reviewer | Different Legal Reviewer or Supervisory Approver per agency policy | Same immutable user ID proposes and finally approves |
| Redaction | Reviewer or Legal Reviewer | Different Supervisory Approver | Same user proposes and approves |
| Response issuance | FOIA Processor prepares | Release Officer | Preparer issues without release authority |
| Package approval | Release Officer or Processor assembles | Supervisory Approver | Assembler gives final approval |
| Package release | Approved Release Officer | Release Officer different from final controlled-decision proposer where required | Flow/application identity or ordinary processor releases |
| Reopen/correction | Processor requests | Records Officer/Supervisory Approver | Original record or event overwritten |

Team membership does not satisfy independence: checks compare immutable user IDs.
Application users, flows, and service principals cannot act as the human approver.
Delegation is time bounded, pre-approved, and recorded. Emergency break-glass
requires two-person approval, expires automatically, and creates an Audit Event.

## Field Security Profiles

Fields not listed use table privileges and record access. Profiles never replace
SharePoint permission checks.

| Profile | Protected field groups | Read | Update |
| --- | --- | --- | --- |
| Requester Sensitive Data | personal contact details, identity-verification attributes, preferred private channel | Intake, assigned Processor, authorized Auditor | Intake; assigned Processor before release lock |
| Legal Analysis | legal notes, privileged rationale, draft exemption analysis | Legal Reviewer, Supervisory Approver, authorized Auditor | Legal Reviewer before final approval |
| Exemption Decision Control | authority, scope, proposed rationale, proposer, final state, approver/time | Reviewer (own proposal), Legal, Supervisor, Release Officer read, Auditor | Proposal fields by proposer; final fields only through approval command |
| Redaction Control | precise location, basis, proposer, approver, final state | Assigned Reviewer, Legal, Supervisor, Release Officer, Auditor | Proposal fields by assigned reviewer; final fields through approval command |
| Release Control | package hash, manifest state, approval, release recipient classification, release actor/time | Supervisor, Release Officer, Auditor | Server/controlled actions only after pending approval |
| Audit And Clock Provenance | actor, source, correlation, prior/resulting due dates, evidence location | Assigned operational roles as needed; Auditor; Administrator metadata only | Create plug-in only; no post-create update |
| AI Assistance Content | source references, prompt/operation class, provider/version, output, confidence, disposition | Assigned Reviewer, Legal where applicable, Auditor | Adapter creates provenance; authorized human sets disposition |

Sensitive free text is minimized. Forms hide secured controls for unauthorized
users, views exclude secured columns, quick find does not index privileged legal
or identity fields, and exports honor field security.

## Table Audit Policy

Dataverse organization and table auditing must be enabled before user acceptance.
Audit configuration is inventoried and tested after import.

| Audit tier | Tables | Audited changes |
| --- | --- | --- |
| A - complete | FOIA Request, Exemption Decision, Redaction Decision, Release Package, Appeal | owner, status, dates, scope, decisions, approvals, disposition, fees, package/release metadata, sharing |
| B - operational | Search Task, Responsive Record, Review Task, FOIA extensions on Case/Contact | assignment, status, source, evidence/counts, repository metadata, classification, review disposition |
| C - immutable ledger | Clock Event, Audit Event | create and access controls; post-create update/delete is denied |
| D - AI provenance | AI Assistance Record | create, provider/version, source references, output hash, disposition, reviewer |

Platform auditing is supplemented by Audit Events for sensitive views, downloads,
exports, package inclusion, approvals, releases, permission changes, and
configuration changes. Audit Events contain event ID, UTC time, actor ID/type,
action, purpose, scope, request/package, correlation ID, result, and evidence
reference. They do not copy document content or credentials.

Audit retention uses class `FOIA-RC-AUDIT`; no automated purge is permitted until
an approved agency/NARA schedule mapping exists. Legal holds always override
disposition.

## Immutable Record Controls

- Operational roles have create/read only for Clock and Audit Events.
- Pre-operation plug-ins reject update, delete, deactivate, assign, merge, bulk
  edit, and ordinary import overwrite.
- Administrator privileges do not bypass plug-in guards.
- Corrections append a linked event with reason, authorizer, prior event ID, and
  corrected projection.
- Released packages, manifests, and correspondence hashes are locked. A correction
  creates the next package version and preserves the old version.
- Backup/restore, records disposition, and platform-administrator emergency actions
  are governed outside ordinary application roles and must be audited.

## SharePoint Security Boundary

1. Use approved site/library identifiers supplied at deployment, never source-held
   tenant URLs or credentials.
2. Provision a request- or case-scoped location with inheritance broken according
   to the approved permission manifest.
3. Map Dataverse owner/access teams to approved SharePoint groups or governed
   permission automation.
4. Verify SharePoint access directly before showing an actionable document link.
5. Record permission state/version and last verification time in Dataverse.
6. Revoke temporary access at task completion, sharing expiry, reassignment, or
   request closure when retention/legal hold does not require continued access.
7. Audit view/download/export/release separately from Dataverse row access.

Required negative tests include: Dataverse read without SharePoint read; SharePoint
URL knowledge without permission; removed team membership; cross-office request;
expired share; secured field export; and released-content write attempt.

## Integration And Application Identities

- Each connector uses a named connection reference and least-privilege application
  or delegated identity appropriate to the approved environment.
- Application identities cannot hold human approval or release roles.
- Flows use specific tables/actions, not system-administrator connections.
- Inbound integrations pass the common validation, malware, authorization, and
  audit pipeline.
- Outbound operations use idempotency keys and correlation IDs.
- Secrets remain in an approved environment secret store, connection object, or
  managed identity where supported. Dataverse environment variables contain only
  non-secret configuration.
- Optional Azure identities and permissions do not exist when Azure flags are false.

## Export And Reporting Controls

Exports require purpose, scope, related request/package, actor, UTC time, and
result. Bulk export is denied to ordinary roles. Authorized exports apply record
and field security, security-trim report drill-through, and create an Audit Event.
Certified report evidence uses aggregate values and synthetic fixtures in source
control; live row-level evidence remains in the approved evidence repository.

## Privacy And Data Handling

- Collect only information required for intake, communication, legal processing,
  audit, and reporting.
- Classify fields and documents at creation; do not infer a lower classification.
- Do not include raw personal data in telemetry, correlation IDs, file names,
  exception messages, source-controlled fixtures, or screenshots.
- Use only conspicuously synthetic identities and documents for tests and demos.
- Disable search indexing of protected free text unless separately approved.
- A subject-access, correction, or records-disposition action cannot alter immutable
  legal/audit records; use a linked compensating record when required.

## Security Acceptance Evidence

- Role/privilege export and positive/negative persona matrix.
- Field-security read/update/mask results.
- Assignment, owner-team, access-team, queue, share, expiry, and cross-office tests.
- Separation-of-duties and automation/application-user bypass tests.
- Clock/Audit Event mutation-denial and correction tests.
- SharePoint independent-access matrix.
- Export, package, release, and report drill-through audit events.
- Audit configuration inventory and retention/hold mapping.
- Secret and sensitive-data scans.
- Complete core journey with all optional Azure flags false.

Evidence is sanitized before source control and referenced by immutable evidence
ID and hash in an instantiated deployment manifest.
