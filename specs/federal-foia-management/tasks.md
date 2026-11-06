# Federal FOIA Management Tasks

## Next Production-Hardening Increment - 2026-11-04

This checklist is the next-work index for
[the proposed milestone plan](plan.md#production-hardening-increment---2026-11-04).
Earlier completed items remain historical evidence, not permission to rerun live
operations. User approval on 2026-11-04 covers local review/planning only.

- [x] Review local status, dated deployment/build evidence, pending runtime integration changes, and remaining behavior/release gaps without live access.
- [x] Update current-state specification and separate proposed hardening scope from demo completion and production readiness.
- [x] Record milestone prerequisites, accountable roles, acceptance tests PH-T01 through PH-T10, unresolved policy decisions, and operation-specific approval boundaries.
- [x] PH-00 verification: run 15 selected standalone regression suites and 19 runtime Pester tests in a credential-free isolated source copy; all passed; verify all 286 original runtime-evidence files unchanged.
- [x] PH-00 verification: reproduce the default-overlay gap without Apply evidence and prove explicit contract resolution for all 26 global Choices/29 Picklists; record pending file groups without staging.
- [x] PH-00 design approval: operator approved local implementation of a versioned checked-in effective contract for normal consumers, preserving rollback sources and separate destructive migration/backup gates; no live operations, commits, or deployment authorized.
- [x] PH-00: Complete grouped pending-source review across 59 files; record four additional reproduced findings and explicit checkpoint exclusions. Earlier full CI and post-fix targeted validation remain dated evidence, not coverage of these newly reproduced cases.
- [x] PH-00: Operator approved all four final review corrections locally; targeted migration, grid, documentation-link, and unset-TEMP regressions pass. No live or source-control mutation was authorized.
- [x] PH-00: Fresh full Windows checkpoint validation passed: 81 parsed files, zero configured analyzer findings, 32 standalone suites, 91 Pester tests, 88-file Markdown lint, exact 60-path source scope, whitespace checks, and 286 unchanged historical evidence hashes. Hosted Linux and live checks were not run.
- [x] PH-00: Obtain explicit checkpoint commit approval. Operator approved staging the exact 60 reviewed paths and one local checkpoint commit only.
- [ ] PH-00: Obtain separate push/PR approval; no push is authorized.
- [x] PH-00: Approve and locally implement the reproducible post-migration schema/data contract; isolated fresh-source mocks create all 26 global Choices and 29 Picklist bindings, seed 97 numeric values across 41 stable records, and verify strict inventory/export without borrowing Apply evidence; original rollback sources retained.
- [x] PH-00: Run 20 selected standalone regression suites, 19 runtime Pester tests, and syntax/ScriptAnalyzer checks for eight implementation/test files; all passed and all 286 original runtime-evidence hashes unchanged. This does not mark full CI or live deployment complete.
- [x] PH-00: Run the full isolated Windows CI equivalent: parse 81 PowerShell files, pinned repository ScriptAnalyzer, 32 standalone suites, 91 Pester tests, and pinned Markdown lint over 93 files; all passed; all 286 original runtime-evidence hashes unchanged. Hosted Linux and live validation remain separate.
- [x] PH-00 review: reproduce stale-snapshot overwrite and ignored pagination in stage 36 using isolated mocks; record both as checkpoint blockers, not historical live data-loss claims.
- [x] PH-00 corrective approval: operator approved additional local migration-safety changes and regression coverage; no live access or destructive execution is authorized by this approval.
- [x] PH-00 corrective implementation: read every data page, compare complete live/snapshot cohorts before any mutation, fail closed on drift or late-page ownership/mapping errors, and document the required write-quiescence boundary.
- [x] PH-00 corrective validation: eight affected suites passed, including final drift/malformed-ID regression; three-file syntax and pinned analyzer passed; all 286 original runtime-evidence hashes unchanged. Documentation consistency and lint are required after recording these results.
- [x] PH-00: Complete remaining grouped review after the approved migration-safety fixes; sign-off is blocked by the four final review findings, not by an unfinished review pass.
- [x] PH-00 final corrections: validate every existing global Choice before any Apply mutation; reject broadened/aliased exported FOIA filters; make the dependency-preparation fixture portable with `TEMP` unset; fix and validate the new skill's six relative links. Regression coverage adds one modified existing test file, bringing candidate scope to 60 paths.
- [ ] PH-01 (depends on PH-00): Resolve the plan's policy/configuration decision register, assign named owners, approve first-slice design/test expectations, and obtain separate DEV access/deployment/test-identity/SharePoint authorization where applicable.
- [ ] PH-02 (depends on PH-01): Implement and unit test server-side intake validation, tracking allocation, deterministic clocks, protected projections, and immutable events; run authorized DEV integration and PH-T01 through PH-T04.
- [ ] PH-03 (depends on PH-02): Implement and test controlled review/approval/release, package integrity, independent SharePoint access, and bounded queues/routing/SLAs; pass PH-T05 through PH-T07.
- [ ] PH-04 (depends on PH-03): Implement observable idempotent notifications/integration failures; complete the normal synthetic request journey with Azure disabled; pass PH-T08 and PH-T09.
- [ ] PH-02 through PH-04: Inventory new plug-in/flow/configuration components and exact IDs, sync to the selected solution, publish scoped changes, preserve existing identities/data/shared-table surfaces, and pass PH-T10 after each increment.
- [ ] PH-05 (depends on PH-04): Complete the remaining journeys, full production security model and access tests, reporting reconciliation, accessibility/performance/portability/recovery suites, and named operational sign-off.
- [ ] PH-06 (depends on PH-05 and separate release approval): Produce/test a managed candidate in an authorized validation environment, rehearse rollback, obtain UAT and release sign-off, and separately approve production cutover.

## Demo Presentation Readiness - 2026-11-04

- [x] Align the existing presenter script and its companion copy, answers, and operator walkthrough to a seven-minute, read-only prototype presentation without production-enforcement claims.
- [x] Preserve the historical rehearsal and add a separate unchecked current-readiness checklist.
- [x] Validate the local presentation documents before requesting fresh DEV access: presenter copies match; 390 narrative seconds plus 30 navigation seconds equals seven minutes; current rehearsal remains unchecked; docs consistency, FOIA traceability, eight-file Markdown lint, whitespace, and all 286 historical evidence hashes pass. No generators were rerun.
- [x] Obtain separate approval for read-only DEV/browser rehearsal; operator signed in manually. No record edits, role assignments, build/seed/export operations, or deployment were authorized.
- [x] Complete the bounded current app/hero/related-work/Choices/selected-dashboard UI check; record actual observations in demo-dry-run.md, including the process/lifecycle mismatch, compatibility banner, and undiagnosed console issues. Core screens loaded; this is not a clean run or full journey acceptance.
- [ ] Complete timed narration and disposition the recorded presentation gaps before declaring ready; any live polish requires separate approval.

## Bounded DEV Polish - 2026-11-05

- [x] Obtain explicit approval for read-only diagnosis and a local fix plan; no live changes or framework implementation authorized.
- [x] Confirm the selected app's client configuration and the exact normal request/process identities using scoped GETs; document actual Intake-only traversal versus the stored Review lifecycle.
- [x] Prepare independently approvable app conversion and one-record process-alignment previews, including preconditions, native gate behavior, verification, rollback limitations, and exclusions in plan.md.
- [ ] Obtain live approval for app-only Unified Interface conversion, snapshot/recheck the selected app and drafts, use supported properties, validate/publish only that app, and recheck UI/membership/banner/console.
- [ ] Separately approve one synthetic process-instance progression and any positional recovery; respect native gates, stop for missing data, and verify no unrelated field/record/definition changes.
- [ ] After confirmed designer readback, separately review the local builder/configuration fix and targeted regression tests; do not assume an unverified numeric client flag.
- [ ] Complete timed narration and record actual results; do not call the diagnosis or a target script duration a completed rehearsal.

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
- [x] Audit categorical schema drift: 15 implemented fields map to the approved 12-choice contract and 14 additional fields require explicit choices.
- [x] Approve normalization of all 29 categorical fields and same-logical-name reconstruction for this synthetic demo.
- [x] Define 26 global choices, stable numeric values, 29 field bindings, deterministic label mappings, and the preview-first migration sequence.
- [x] Implement credential-free schema, offline mapping, preview nonmutation, dependency-gate, and foreign/unmapped-value tests for the choice retrofit.
- [x] Implement credential-free guarded Snapshot/Apply/Verify, dependency-zero enforcement, same-name recreation, solution membership, idempotent rerun, and rollback restoration tests.
- [x] Produce the exact operator dependency-removal/restoration handoff for all 60 references across 13 views, 2 designer-authored BPFs, 7 charts, and 15 forms, including the two generated BPF backing forms.
- [x] Implement and credential-free test GET-only stage 37 preparation: all 60 references and 37 handoff IDs are required; temporary definitions cover 26 stage-60 components and 7 stage-64 charts; 4 BPF-owned records remain designer-managed.
- [x] Run live stage 37 Preview and review the generated temporary definitions: all 60 references, 37 component IDs, 33 script-managed definitions, and 4 BPF-owned records passed with zero mutations.
- [x] Create the fresh pre-migration unmanaged stage-95 backup at a Windows-safe short path; inspect 27/27 expected roots, 235 membership items, and 217 files with zero missing or unrelated components and record SHA-256 `26c724b7df4d3b6a7efde3b689acaa483609145beb304077f900a38d22cfaf09`.
- [x] Add post-Apply strict inventory and export assertions for all 26 global choices and 29 Picklist columns; verify exact bindings, numeric values, English labels, metadata IDs, and explicit/include-all solution membership with credential-free positive/negative tests.
- [x] Run the choice retrofit in live read-only Preview: 29 String fields, 97 populated synthetic values, 60 blocking dependencies, and zero mutations.
- [x] Obtain separate destructive approval before deleting or recreating any live column: operator authorized all 29 approved categorical fields for the demo.
- [x] Apply the approved migration, restore all dependencies, reseed only owned synthetic records, publish, and run strict field/form/view/BPF/chart/app validation: 97 populated values restored, 33 ordinary definitions restored, both BPFs active, and real Request dropdown interaction verified on 2026-10-22.
- [x] Rerun membership, stage `85`, and stage `95`: 29 Choice columns, 26 global choices, 261 solution items, 41 stable record IDs, zero duplicates, and 53/53 export roots with no missing or unrelated components.
- [ ] Run schema integration and security tests.

## Server Logic And Automation

### Choice Presentation Increment

- [x] Reuse original wizard pastel/icon tokens and classify all 162 FOIA options without changing semantic labels or values.
- [x] Add preview/hash approval, complete global-Choice preflight, backup, scoped update/publish, exact readback, and credential-free tests.
- [x] Apply approved preview `5378829731c57f423e55925b470291b7436599457c5d50296939f0370de75e48`; settled rerun made zero updates; 29 live bindings/97 populated values, 261 memberships, 53 export roots and all 162 exported labels/colors passed. Published Request UI shows prefixed labels; standard form dropdowns do not render pastel option backgrounds.

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

## Pastel Grid Increment

- [x] Record the 13-table read-only Web-grid contract and preserve a pre-grid export.
- [x] Configure Power Apps grid Choice colors through supported maker UI, preserving mobile settings.
- [x] Create FOIA Requester Choice Overview and FOIA Case Choice Overview; preserve all 45 original shared-table public views; add both views to solution/app and publish.
- [x] Verify all 13 selected Web controls and colors in exported metadata and actual Request/Contact/Case app cells; prove 263 strict memberships, 97 unchanged values, all original IDs stable, and the final 53-root/245-file unmanaged package.
- [x] Archive and compare the 702-identity pre-grid baseline; allow only the two new views' four identity entries; verify the 706-identity baseline after the bounded view rerun.
- [x] Run eight isolated credential-free regression suites, including exact grid-property and FOIA-view positive/negative gates.

## Review App And Security

- [x] Create or update the Federal FOIA Management review app with FOIA Request first and Active FOIA Requests as the landing view.
- [x] Add all required app-addressable artifacts and role-appropriate navigation for all 13 custom/reused tables, both BPFs, eight charts, and five dashboards.
- [x] Approve a bounded demo-security scope: three Dataverse role definitions, no user creation or assignment, no field-security profiles, and no SharePoint provisioning.
- [x] Define the exact Business Unit privilege matrix and validated payload for `FOIA Demo Processor`, `FOIA Demo Approver`, and `FOIA Demo Release Officer`.
- [x] Preview the three roles with zero Dataverse calls and retain the local preview evidence.
- [x] Create the three roles after separate apply approval; verify stable IDs, exact planned privileges plus the reported Dataverse-managed baseline, explicit solution membership, and a mutation-free second pass.
- [x] Validate idempotent role creation, exact role privilege metadata, and solution membership; the recorded second pass made zero mutations.
- [ ] Validate actual processing/approval/release access boundaries with separately approved test-user assignments; role metadata is not proof of runtime enforcement.
- [ ] Defer the full 10-role model, field-security profiles, ownership/team/share design, auditing/export controls, and user assignments to a separately approved production-hardening increment.
- [ ] Defer proposer/approver identity enforcement, controlled transitions, immutable-event guards, and unauthorized-release tests until server-side controlled actions are implemented.
- [x] Complete operator dashboard usability validation of the published scoped app; automated platform validation, publication, entry-point, landing-view, five-link dashboard group, sitemap, and solution-membership checks pass.

## Synthetic Data And End-To-End Validation

- [x] Seed only the 41 approved deterministic synthetic records across 13 tables, including seven explicit synthetic Contacts and Cases and no Dataverse Task activities.
- [ ] Execute normal, expedited, overdue, appealed, fee, exemption, and released journeys.
- [x] Validate all seven journey records and all 41 source-tagged records read-only in live Dataverse with zero missing, extra, duplicate, or mismatched key records.
- [ ] Complete the full authenticated operator click rehearsal; sign-in and the Request Choice-dropdown smoke test passed on 2026-10-22, but full UI journey execution remains pending.
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
