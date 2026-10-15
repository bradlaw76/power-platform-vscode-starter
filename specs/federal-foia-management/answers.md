# Federal FOIA Management Advanced Builder Answers

## Scenario

- Name: Federal FOIA Management
- Slug: `federal-foia-management`
- Wizard mode: `advanced-builder`
- Build posture: new scenario planning package; no FOIA components are currently documented in this repository
- Initial target: FedCiv GCC/GCC High
- Selected environment classification: FedCiv GCC
- Deployment ring: Development
- Portability target: DoD IL5
- Environment URL: `https://usfedfoia.crm9.dynamics.com`
- Environment selection: approved for authentication planning on 2026-10-06
- Authentication method: interactive browser sign-in
- Live access: authentication and GET-only verification authorized and completed on 2026-10-06
- Mutation access: limited authorization granted on 2026-10-07 to create only the `foia` publisher and unmanaged `FederalFOIAManagement` solution; completed and independently verified
- Environment readiness: Case and Contact are available; the `foia` publisher and unmanaged `FederalFOIAManagement` solution exist with the expected binding
- Capability readiness: SharePoint Online and Power Automate/Office 365 connector licensing and usability were operator-confirmed on 2026-10-08; related Dataverse metadata is available
- Capability evidence boundary: automated connector inventory could not complete because the Power Platform API tool generated an invalid environment endpoint, so no connection identifiers are recorded
- Remaining mutation boundary: data, flow, security, export, commit, and push operations remain unauthorized
- Table mutation authorization: stage 20 creation of the 11 planned custom tables was authorized and completed on 2026-10-08
- Table implementation status: all 11 planned custom tables were created and independently verified on 2026-10-08; live IDs are recorded in the sanitized deployment manifest, and stage 50 later verified publication and selected-solution membership
- Column and key mutation authorization: stage 30 creation of the reviewed 134 columns and 11 alternate keys was authorized on 2026-10-08; relationships, data, app, flow, publish, export, commit, and push remain unauthorized
- Column and key implementation status: all 134 columns and 11 alternate keys were created and independently verified on 2026-10-08; all key indexes are Active, all key solution memberships are verified, and stage 50 later completed table/column synchronization and scoped publication
- Relationship mutation authorization: stage 40 creation of the reviewed 20 one-to-many and one many-to-many relationships was authorized on 2026-10-11; solution synchronization, publishing, data, app, flow, export, commit, and push remain unauthorized
- Relationship implementation status: all 21 relationships were created and independently verified on 2026-10-11; requiredness, identity, restrictive delete behavior, and the N:N intersect match the payload contract, with the Dataverse-required Contact merge cascade documented as a platform exception
- Solution synchronization authorization: stage 50 explicit membership synchronization for the approved 11 tables, 134 columns, 21 relationships, and 11 alternate keys, followed by scoped publication of the 13 payload-referenced entities, was authorized on 2026-10-11; data, app, flow, export, commit, and push remain unauthorized
- Solution synchronization status: stage 50 completed on 2026-10-11 with a clean contamination verdict, 155 explicit column/relationship additions, all declared schema and deterministic Dataverse dependencies verified in `FederalFOIAManagement`, and 13 entities published; export remains blocked by later experience, reporting, app, and process stages
- Business process status: both supported designer-authored category-4 processes are Active and stage 55 completed with zero failures on 2026-10-12; workflow IDs, component-type 29 membership in `FederalFOIAManagement`, and the named Request/Appeal target forms are verified, while app linkage remains pending stage 62
- Business process field rule: BPF chevrons are authoritative for interactive process position; `foia_lifecyclestage` and `foia_stage` remain reporting/view/sample-data/status-projection columns and are not repeated as BPF steps. Repeated Due Date, Disposition, or Outcome references expose the same underlying record value rather than duplicate data.
- Forms and views status: stage 60 completed on 2026-10-12 with 13 wizard-owned main forms and 13 explicit public views created or adopted, scoped publication across all 13 tables, zero under-populated surfaces, and a stable rerun of 13 form skips and 13 view skips. Request and Appeal use `FOIA Request Main` and `FOIA Appeal Main`; the remaining tables retain `Starter Main Form`.
- Native reporting status: stage 64 passed on 2026-10-13. Eight chart records and five dashboards have verified `FederalFOIAManagement` membership, complete native dashboard controls, exact native per-type presentation templates, unaliased category nodes, and successful aggregate FetchXML execution. After stage 66 populated all six source tables, the operator confirmed that the charts render in the published app. A stable rerun skips all eight charts and five dashboards.
- Review app status: stage 62 completed on 2026-10-13. The published `Federal FOIA Management` app (`foia_federal_foia_management`) and its sitemap have stable IDs, component types 80 and 62 in `FederalFOIAManagement`, 13 custom/reused table navigation entries, a generated five-link Dashboards group, `foia_foiarequest` as the entry point, `Active FOIA Requests` as the landing view, both BPFs, all eight charts, and all five dashboards. Platform validation, operator dashboard validation, and the idempotent rerun passed.
- Deployment: never automatic

## Business Outcome And Audience

- Outcome: provide a reusable, secure, auditable Federal FOIA request-management solution from intake through release, appeal, and closure.
- Platform: Dynamics 365 Customer Service, Microsoft Power Platform, Microsoft 365, and optional Azure adapters.
- Audience: FOIA program offices, records custodians, legal reviewers, supervisors, release officers, auditors, and administrators.
- Primary success measure: staff can process representative requests end to end while statutory timing, decisions, documents, approvals, and report calculations remain traceable and reproducible.

## Application And Data Architecture

- Application profile: `dynamics-customer-service-extension`
- Table strategy: `hybrid`
- Reused tables: Case (`incident`) and Contact (`contact`)
- Custom tables: FOIA Request, Search Task, Responsive Record, Review Task, Exemption Decision, Redaction Decision, Release Package, Appeal, Clock Event, Audit Event, and AI Assistance Record
- OOB form strategy: create new FOIA-specific business forms; do not modify existing out-of-box forms
- Primary entry-point table: `foia_foiarequest`
- Default landing view: Active FOIA Requests
- Landing-view disposition: `adopt-generated-active` only after live provenance proves the current scenario created the table and the target is its untouched generated Active/default public view
- Request-to-Case relationship: one FOIA Request to many Cases
- Review app: create or update on every run
- Required app surfaces: FOIA Request, Case, Contact, all 10 downstream custom tables (including Clock Event, Audit Event, and AI Assistance Record), queues, BPFs, dashboards, and reports, subject to role-based visibility

## Application Profile

- Profile: dynamics-customer-service-extension
- Table Strategy: hybrid
- Form Strategy: create-new-forms
- Entry Point Table: foia_foiarequest
- Landing View: Active FOIA Requests
- Review App Mode: create-or-update
- Required App Artifacts: FOIA Request, Case, Contact, all downstream FOIA operational tables, forms, views, both BPF handoffs, charts, dashboards, and role-appropriate navigation

## App Module

- Enabled: yes
- App Name: Federal FOIA Management
- Unique Name: foia_federal_foia_management
- Navigation Group: FOIA Operations

## Optional Report Web Resources

- Enabled: no
- Selected Reports: none
- Decision: use native model-driven views, charts, and dashboards; do not generate HTML report web resources

## Lifecycle And Automation

- Primary BPF: Intake -> Clarification -> Search -> Review -> Redaction -> Approval -> Release -> Closure
- Appeal: separate related process
- Human approvals: mandatory for exemption decisions, redactions, response issuance, and package release
- Statutory clock: Dataverse plug-ins own authoritative calculations and immutable event creation
- Notifications and escalations: Power Automate, driven by authoritative Dataverse values
- Optional Azure: adapter contracts and disabled feature flags only in the initial release

## Documents And Integrations

- Core document store: SharePoint document libraries
- Organization: request- or case-scoped document locations
- Security: explicit SharePoint permissions; Dataverse privileges are not assumed to protect documents
- Collection sources: Exchange, SharePoint, OneDrive, file shares, archives, mission systems, and legacy systems
- Intake channels: public portal, agency portal, email, mail-room entry, staff-assisted entry, FOIA.gov, and API

## Reporting And Data

- Reports: operational dashboards plus annual and quarterly FOIA reporting
- Required metrics: backlog, oldest requests, appeals, exemptions, expedited requests, and fees
- Demo data: representative synthetic end-to-end records covering normal, expedited, overdue, appealed, fee, exemption, and released scenarios
- Synthetic-data status: stage 66 created or updated 41 deterministic records across 13 tables with source tag `federal-foia-synthetic-v1`; the second pass preserved all 41 IDs and created no duplicates.
- Standard-table seeding: seven synthetic Contacts and seven synthetic Cases were explicitly approved and created; each Case is bound to its corresponding Contact and FOIA Request. No Dataverse Task activities were created.
- Production data: prohibited from source control

## Solution And Source Control

- Solution strategy: create new
- Solution unique name: `FederalFOIAManagement`
- Solution display name: Federal FOIA Management
- Publisher prefix: `foia`
- Publisher identity: to be selected or created during an explicitly authorized authentication step
- Development output: unmanaged
- Release output: managed artifact later through a separately approved release process
- Planned branch: `feature/federal-foia-management`
- Commit and push: require explicit approval after validation

## Current-State Retrofit Finding

- No FOIA scenario, FOIA payloads, unpacked FOIA solution, or FOIA component inventory was found in the repository.
- No `requirements-baseline.md` existed before this intake.
- The existing GCC Framework Acceptance materials concern an unrelated lab-equipment scenario and do not grant FOIA environment access or mutation authority.
- This planning package must preserve all unrelated scenarios and components.

## Approved Recommendation

The user approved the complete architecture on 2026-10-02 and approved the two-layer catalog crosswalk on 2026-10-06. Authentication and GET-only readiness verification are complete. Environment mutation, deployment, export, commit, and push remain unauthorized.
