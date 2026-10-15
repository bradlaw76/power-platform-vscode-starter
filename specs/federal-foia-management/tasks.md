# Federal FOIA Management Tasks

## Planning And Approval

- [x] Select `advanced-builder`.
- [x] Verify wizard runtime, prerequisites, contract integrity, documentation consistency, and skill parity.
- [x] Inspect repository documentation and record that no existing FOIA implementation or FOIA live-access authorization is present.
- [x] Preserve the reusable catalog as `Federal-FOIA-Solution-Requirements.md` with stable `FOIA-REQ-001` through `FOIA-REQ-300` IDs.
- [x] Retain the categorized `FOIA-*` IDs as the condensed demo implementation profile.
- [x] Approve the hybrid Customer Service architecture, new FOIA forms, FOIA Request entry point, Request-to-Case relationship, lifecycle, SharePoint storage, clock architecture, reports, synthetic data, and Azure-disabled initial release.
- [x] Create and align `Federal-FOIA-Solution-Requirements.md`, `answers.md`, `requirements-baseline.md`, `spec.md`, `plan.md`, `tasks.md`, `requirement-traceability.md`, and `report-mappings.md`.
- [x] Generate and review the scenario-derived presenter demo script and engineer walkthrough.
- [x] Complete the narrative dry run and defer app-dependent rehearsal steps until deployment and synthetic-data verification.
- [x] Review and approve the complete planning package.
- [x] Create and switch to `feature/federal-foia-management` only after approval.

## Traceability And Detailed Design

- [x] Create the requirement-to-artifact-to-test-to-evidence matrix for FOIA-ARC-001 through FOIA-ALM-008.
- [x] Add a complete catalog-range scope register covering FOIA-REQ-001 through FOIA-REQ-300.
- [x] Review, deterministically validate, and approve the revised two-layer catalog/profile traceability before further build execution or environment mutation.
- [x] Define controlled choice values, status transitions, business rules, ownership, field security, audit settings, and retention classifications.
- [x] Finalize annual and quarterly measure formulas and version identifiers.
- [x] Define environment-variable, connection-reference, feature-flag, and secret contracts.
- [x] Define the deployment manifest schema and rollback checklist.
- [x] Validate that every design remains functional with all optional Azure flags disabled.

## Payload Design And Credential-Free Validation

- [x] Create table payloads for all 11 custom tables with prefix `foia`.
- [x] Create column payloads for custom tables and approved Case/Contact extensions.
- [x] Create relationship payloads for every relationship in `spec.md`, including 20 1:N relationships and the Release Package-to-Responsive Record N:N relationship.
- [x] Create schema-bound view definitions with explicit dispositions, columns, filters, and sorts and no guessed standard-table view adoption.
- [x] Create primary and appeal process payloads/designer handoffs with entry/exit criteria and required fields; use BPF chevrons as the interactive stage authority and retain lifecycle/stage columns only for reporting and status projection.
- [x] Create reporting payloads for eight native charts and five native dashboards.
- [x] Create `demo-data-plan.json` with explicit bounded standard-table choices before any data payload.
- [x] Create 41 deterministic synthetic records covering the seven approved journeys, including explicitly bounded synthetic Contact and Case records and no Task activities.
- [x] Run JSON parsing, checked-in JSON Schema validation, strict dry validation, prefix audit, requirement-ID audit, preview nonmutation tests, and FOIA-specific orchestrated Preview.
- [x] Stop for review before authentication or live environment access.

## Credential-Free Runtime Blockers

- [x] Add supported N:N relationship handling for Release Package-to-Responsive Record membership without fabricating a 1:N relationship.
- [x] Add supported alternate-key mutation for tracking, task, decision, package, appeal, and event identifiers.
- [x] Add a scenario view-contract payload and backward-compatible multiple-dashboard support.
- [x] Update stage `55` to deterministically validate and report every process payload, including separate primary-request and Appeal handoffs.

## Environment And Solution Gate

- [x] Obtain explicit authentication and GET-only authorization for the selected FedCiv environment as an exception to the 300-item reconciliation gate.
- [x] Run `10-auth-connect.ps1` without printing secrets or account/profile identifiers into tracked evidence.
- [x] Verify that Case and Contact are available and that the new `foia` publisher prefix is unused.
- [x] Create and independently verify the approved `foia` publisher identity after crosswalk review and limited mutation approval.
- [x] Verify that `FederalFOIAManagement` does not conflict.
- [x] Create and independently verify the unmanaged `FederalFOIAManagement` solution and expected publisher binding after crosswalk review and limited mutation approval.
- [x] Confirm usable SharePoint and Power Automate/Office 365 connectors and required licensing; operator confirmation and related Dataverse metadata availability are recorded without connection identifiers.
- [x] Record the FedCiv GCC Development classification, approved publisher/solution-only operations, capability status, and remaining authorization boundaries in `deployment-manifest.json`.

## Schema Implementation

- [x] Run stage `15`; all 17 contract checks passed with zero warnings and zero errors after preserving the obsolete pre-solution preview manifest and initializing correct scenario provenance.
- [x] Run stage `20` to create and independently verify all 11 user-owned custom tables; zero skipped and zero failed, with live IDs recorded in `deployment-manifest.json`.
- [x] Run stage `30` to create and independently verify all 134 columns and 11 alternate keys, including approved Case/Contact extensions; all key indexes are Active and key solution membership is verified.
- [x] Run stage `40` to create and independently verify 20 one-to-many relationships and one many-to-many relationship with requiredness and restrictive cascades; document the Dataverse-required Contact merge cascade exception.
- [x] Add all declared schema components and deterministic Dataverse dependencies to `FederalFOIAManagement`, publish the 13 scoped entities, inventory IDs, and verify zero missing, failed, or unauthorized schema membership.
- [ ] Run schema integration and security tests.

## Server Logic And Automation

- [ ] Implement and unit test tracking-number allocation.
- [ ] Implement and unit test deterministic statutory-clock calculation and immutable Clock Event creation.
- [ ] Implement and test approval, separation-of-duties, release-transition, package-version, and immutable-event guards.
- [ ] Implement acknowledgment, clarification, due-date, escalation, assignment, approval, release, and integration-status flows.
- [ ] Add correlation IDs, idempotency, explicit failure states, 401 refresh, and bounded 429 backoff where applicable.
- [ ] Run Dataverse and Power Automate integration tests.

## Forms, Views, Processes, And Customer Service

- [x] Create separate wizard-owned FOIA forms on Case and Contact without modifying OOB forms.
- [x] Create main forms for all custom tables with business labels and General/Details sections.
- [x] Create the 13 explicit operational views and adopt generated Active views only after provenance is proven.
- [ ] Configure Intake, Search, Review, Legal, Supervisory Approval, Release, and Appeals queues and routing.
- [ ] Configure SLAs against authoritative dates without replacing the Clock Event ledger.
- [x] Generate and validate separate primary and Appeal BPF designer handoffs with aggregate multi-process evidence; use supported tooling for later live implementation.
- [x] Author `foia_federal_foia_request_lifecycle` and `foia_federal_foia_appeal_lifecycle` through the Power Apps BPF designer, then rerun stage `55` to validate Active state and synchronize both processes into `FederalFOIAManagement`.
- [x] Remove repeated `foia_lifecyclestage` and `foia_stage` BPF steps while retaining those columns for reporting, views, sample data, and external status projection; confirm repeated Due Date, Disposition, and Outcome references reuse the same record values.
- [x] Complete BPF form integration during stage `60` with `FOIA Request Main` and `FOIA Appeal Main`.
- [x] Complete BPF app linkage during stage `62`.
- [ ] Validate form XML/metadata, field order, labels, stage fields, views, queues, routing, and SLAs.

## Document Management And Integration

- [ ] Define and provision approved SharePoint libraries and request/case locations.
- [ ] Implement explicit SharePoint permission mapping independently of Dataverse privileges.
- [ ] Implement document metadata, version, hash, classification, access-state, download/export, and release tracking.
- [ ] Define connector contracts for intake and collection sources.
- [ ] Implement approved initial non-Azure connectors without making unavailable systems a core dependency.
- [ ] Run positive and negative Dataverse/SharePoint security-boundary tests.

## Optional Azure Adapter Boundary

- [ ] Define orchestration, OCR, search, and generative-AI adapter interfaces.
- [ ] Implement disabled adapters and environment feature flags.
- [ ] Ensure disabled or failed adapters return explicit status and never success-shaped fallback output.
- [ ] Implement AI Assistance Record provenance and human disposition behavior independent of provider.
- [ ] Run the complete core test suite with no Azure configuration present.

## Reporting

- [x] Complete the approved native reporting surfaces: operational views, eight rendering native charts, five dashboards, exact per-type chart XML, aggregate-query execution, stable IDs, solution membership, and in-app operator validation.
- [ ] Implement versioned annual and quarterly report definitions.
- [ ] Add certified-run metadata and reconciliation evidence.
- [ ] Validate drill-through and security trimming.
- [ ] Reconcile all synthetic-data totals to source records and Clock/Audit Events.

## Review App And Security

- [x] Create or update the Federal FOIA Management review app with FOIA Request first and Active FOIA Requests as the landing view.
- [x] Add all required app-addressable artifacts and role-appropriate navigation for all 13 custom/reused tables, both BPFs, eight charts, and five dashboards.
- [x] Approve a bounded demo-security scope: three Dataverse role definitions, no user creation or assignment, no field-security profiles, and no SharePoint provisioning.
- [x] Define the exact Business Unit privilege matrix and validated payload for `FOIA Demo Processor`, `FOIA Demo Approver`, and `FOIA Demo Release Officer`.
- [x] Preview the three roles with zero Dataverse calls and retain the local preview evidence.
- [x] Create the three roles after separate apply approval; verify stable IDs, exact planned privileges plus the reported Dataverse-managed baseline, explicit solution membership, and a mutation-free second pass.
- [ ] Validate idempotent role creation, solution membership, and coarse processing/approval/release table-privilege boundaries.
- [ ] Defer the full 10-role model, field-security profiles, ownership/team/share design, auditing/export controls, and user assignments to a separately approved production-hardening increment.
- [ ] Defer proposer/approver identity enforcement, controlled transitions, immutable-event guards, and unauthorized-release tests until server-side controlled actions are implemented.
- [x] Complete operator dashboard usability validation of the published scoped app; automated platform validation, publication, entry-point, landing-view, five-link dashboard group, sitemap, and solution-membership checks pass.

## Synthetic Data And End-To-End Validation

- [x] Seed only the 41 approved deterministic synthetic records across 13 tables, including seven explicit synthetic Contacts and Cases and no Dataverse Task activities.
- [ ] Execute normal, expedited, overdue, appealed, fee, exemption, and released journeys.
- [ ] Run unit, integration, security, accessibility, performance, end-to-end, and Azure-independence suites.
- [x] Verify the approved data plan and payload prohibit production-derived data and committed document content.
- [x] Capture stage-66 created/updated counts and prove a second pass preserves all 41 stable IDs without duplicates.

## Inventory, Rerun, Export, And Handoff

- [x] Collect all required and optional artifact categories with logical names and IDs.
- [x] Synchronize components into `FederalFOIAManagement` and report Added, Already in solution, Failed with reason, and Missing after sync.
- [x] Capture the 676-identity idempotency baseline, rerun approved experience/data/security-role stages, refresh strict membership, and complete stage `85`.
- [x] Prove stable IDs with zero failures and zero duplicate candidates; the second pass skipped all 13 reporting surfaces and updated the same 41 synthetic records.
- [x] Verify final membership with strict isolation: 235 already in solution, zero failed, zero missing, zero unauthorized, and export allowed.
- [x] Run stage `95` for the explicitly approved unmanaged export and local unpack/inspection; all 27 expected root components, including three security roles, matched with zero missing or unrelated components and no import permitted.
- [x] Update `docs/build-log.md`, requirement traceability, deployment manifest, rollback instructions, and evidence index with verified membership, export, and idempotency results.
- [ ] Obtain approval before explicit staging, commit, push, or pull-request creation.
- [ ] Produce a managed release artifact only through a separately approved release workflow.
- [ ] Never deploy automatically.
