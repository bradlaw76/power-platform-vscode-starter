# Build Log

Record each build run here. One row per execution.

Use this to document what was planned, built, validated, and promoted.

## Federal FOIA Management - 2026-10-14

| Field | Result |
| --- | --- |
| Runner | Human operator with Copilot SDK in VS Code |
| Environment | FedCiv GCC Development; DoD IL5 portability target |
| Build type | Reusable synthetic-data demonstration |
| Scenario | `federal-foia-management` |
| Solution | `FederalFOIAManagement` (unmanaged) |
| Publisher | `FederalFOIA`; prefix `foia` |
| Scripts completed | `15`, `20`, `30`, `40`, `50`, `55`, `60`, `64`, `62`, `66`, `85`, `95` |
| Tables | 11 custom tables plus reused Contact and Case |
| Columns and keys | 134 columns; 11 active alternate keys |
| Relationships | 20 one-to-many; 1 many-to-many |
| Forms and views | 13 main forms; 13 public views |
| Business Process Flows | 2 active, solution-owned, and app-linked |
| Native reporting | 8 charts and 5 dashboards; second pass skipped all 13 stable surfaces |
| Model-driven app | Published; platform validation passed; FOIA Request landing experience and five-dashboard navigation verified |
| Synthetic data | 41 approved records across 13 tables; second pass updated the same 41 records |
| Final membership | Strict gate passed: 235 already in solution, 0 failed, 0 missing, 0 unauthorized |
| Idempotency | 676 identities stable; 0 failures; 0 duplicate candidates |
| Export | Unmanaged export and local unpack completed |
| Package inspection | 27/27 expected root components matched, including 3 security roles; 0 missing; 0 unrelated; 217 unpacked files |
| Import | No import performed or authorized |
| Source control | `49cc130`, `3e2c430`, `bbef403`; no push performed |
| Evidence | `specs/federal-foia-management/evidence-index.md` |
| Remaining release gates | Security roles/access tests, flows/integrations, accessibility, performance, complete E2E journeys, documentation sign-off, push/PR approval, and any managed-release approval |

## Federal FOIA Choice Migration Readiness - 2026-10-21

- Local implementation and credential-free validation only; no authentication,
  live Dataverse requests, dependency removal, column deletion, import, commit,
  or push performed.
- Added exact post-Apply verification for 26 global Choices and 29 Picklist
  columns, including option values/English labels, global bindings, live
  metadata IDs, and explicit/include-all solution membership.
- Strict inventory now includes global Choices; unmanaged export checks their
  roots and full definitions plus migrated attribute types/bindings.
- Successful matching Apply evidence automatically enables these gates;
  operators can also require them with `-RequireChoiceMigration`. The
  pre-migration backup path remains available before Apply.
- Seven focused credential-free suites passed: Choice verification, migration
  Apply/rollback, migration Preview, dependency preparation, solution isolation,
  idempotency/export, and wizard hardening. Existing tests that write scenario
  evidence were run in an isolated copy so saved live evidence was preserved.
- Live status is unchanged: refresh preview/backup and snapshot, complete
  supported dependency removal (including both designer-owned BPFs), obtain
  separate destructive authorization, apply/restore/publish, then perform
  live validation, membership, idempotency, and export gates.

## Federal FOIA Choice Migration Checkpoint - 2026-10-22

- Operator selected surgical same-logical-name replacement of all 29 approved
  categorical text fields for the synthetic demonstration, including restoration
  of demo values and affected app references; unrelated components remain outside
  scope.
- Fresh live stage-35 Preview passed: 26 global Choices, 29 bindings, zero
  mutations. Stage-37 Preview passed with the same 60 dependency references
  across 37 components and zero mutations.
- Fresh stage-95 unmanaged export and local unpack inspection passed: 27 expected
  roots matched, 235 membership items, zero missing or unrelated roots.
  Backup ZIP SHA-256:
  `AE139A57D0A60279F522C0399770BD3461D57B6D318A6FE66A5FACA566BF2DCE`.
  Runtime export evidence records the short session-storage path.
- Stage-36 Snapshot captured all 29 bindings without mutation; runtime evidence:
  `.wizard-metrics/artifacts/choice-migration/federal-foia-management-snapshot.json`.
- PAC printed a NuGet service-index TLS warning, but export, unpack, and package
  inspection completed successfully.
- Initial checkpoint paused before mutation for Microsoft sign-in. After the
  operator signed in, the authorized replacement completed on 2026-10-22:
  **26 global Choices, 29 same-logical-name Picklist columns, and all 97 captured
  populated field values restored and verified**.
- Temporarily rebound BPF steps through the supported Power Apps designer,
  preserved their names/order/requiredness, and reached zero delete dependencies.
  Restored all 33 reviewed ordinary form/view/chart definitions with their
  original IDs, corrected Choice controls and numeric chart filters, and restored,
  validated, and activated both BPFs without fabricating workflow metadata.
- Stage-36 Verify passed exact live metadata, option labels/values, global
  bindings, solution membership, and snapshot-value checks. All 29 recreated
  attributes were explicitly added to the solution. Attribute IDs intentionally
  changed; the pre-migration baseline was archived before the new baseline.
- Controlled reporting/data rerun: 7 reporting surfaces updated, 6 skipped, and
  all 41 approved synthetic records updated with the same IDs. Stage 85 passed:
  stable IDs true, zero duplicates, zero failures. Final strict membership:
  261 already in solution; zero failed, missing, or unauthorized.
- Published-app inspection confirmed actual dropdowns on Synthetic Normal
  Request: Intake Channel = Agency portal, Validation State = Perfected, and
  Disposition = Open; all seven channel options were available and the record
  remained Saved. Unrelated platform feature/licensing/telemetry warnings remain;
  they did not block the dropdown interaction. Full journey rehearsal is separate.
- Final unmanaged export/unpack and exact Choice-package inspection passed:
  53/53 expected roots, 261 membership items, 243 files, zero missing or unrelated
  roots, and all 26 option definitions/29 Picklist bindings verified. ZIP SHA-256:
  `1E06A159EAABD8F2168F53C1BA8F754FFA91422A6F88194AEFD8ECBD009BE97C`.
  Runtime export evidence retains the package and unpack paths.
- Runtime corrections cover supported global-option-set collection queries,
  bounded metadata visibility polling, GUID-based global binding, native
  Retry-After headers, and PAC's case-varied entity names and `OptionSetName`
  references. Legacy String/data payloads remain the pre-migration source;
  matching successful Apply evidence activates the approved migration overlay
  for stage-30 metadata and stage-66 numeric seed values.
- No import, managed release, commit, push, or pull request was performed.
- Final isolated regression run passed all eight focused suites (including
  19/19 runtime Pester tests). JSON validation parsed 86 documents and matched
  61 payload schemas; changed PowerShell files parsed and whitespace checks
  passed. Local test fixtures did not overwrite live migration evidence.

## Federal FOIA Choice Icons And Pastels - 2026-10-22

- Located the original VS Code wizard in the sibling starter workspace and
  reused its eight exact pastel tokens and inline symbol vocabulary. Its
  local-Choice-only styling stage was not executed against FOIA's global sets;
  stage 38 uses the supported global `UpdateOptionValue` action instead.
- Operator approved the rendered 162-option / 26-global-Choice / 29-field preview:
  `5378829731c57f423e55925b470291b7436599457c5d50296939f0370de75e48`.
  Semantic labels, numeric values, bindings, record values, option order, and
  metadata identities remain unchanged. Only English display-label prefixes
  and native color metadata were changed; other language labels are merged.
- Preflight verified the complete scope before mutation and captured original
  metadata under `.wizard-metrics/artifacts/choice-presentations/federal-foia-management/`.
  The stage published only changed global Choices and read back all 162 exact
  labels/colors. An immediate rerun repeated one validation-state option update
  during propagation; the settled rerun verified all options with zero updates.
- Stage 36 Verify reconfirmed 29 Picklists, 26 global bindings, and all 97 restored
  values. Strict membership remained 261 with zero missing/failed/unauthorized;
  stage 85 retained stable identities and zero duplicates.
- Authenticated published-app smoke test after reload showed `Agency portal`,
  `Perfected`, `Review`, `Other`, and `Open` with their intended symbols.
  All seven channel options displayed symbols and the record remained Saved.
  Standard form dropdowns rendered transparent option backgrounds; the pastel
  colors are configured and verified in metadata/package, not forced onto
  unsupported controls. Color-capable grids need their option-set-color setting.
- Final unmanaged export passed 53/53 roots, all 26 exact option definitions,
  all 162 labels/colors, and all 29 bindings; 243 unpacked files. ZIP SHA-256:
  `4ACFC90A018C62D09F95A9C800DCBAE1B82058D6C3B96BD590BE2ADD57E3FD55`.
- Eight isolated credential-free regression suites passed, including no-write
  preview, wrong-hash/managed/drift/membership rejection, unchanged translations,
  zero-write rerun, numeric seed mappings, and wrong-color live/package gates.
- No record edits, field recreation, imports, commits, or pushes were performed.

## Federal FOIA Pastel Grids - 2026-10-22

- Operator approved enabling Choice colors for all 13 FOIA tables, including
  shared Contact and Case, provided new views contain FOIA in their names.
- Configured native Power Apps grid controls through supported classic maker
  UI, selected Web, enabled OptionSet colors, and kept editing off. Existing
  phone/tablet selections were retained, including Case's inherited OneGrid.
  Explicitly saved Case settings into the selected solution for portability.
- Created and published two separately owned public views, linked to both
  solution and app: FOIA Requester Choice Overview
  (`3285d88d-5f40-4cb3-8a74-baf08e711b7a`) and FOIA Case Choice Overview
  (`4807ed1b-2597-4682-abf9-969d911df4d6`). All 45 original Contact/Case public
  views retain exact names, FetchXML, layouts, and default/managed flags.
- Actual Request, Contact, and Case grids displayed the configured pastel
  symbol badges. Case showed seven FOIA work types; Contact showed seven
  FOIA-related records. Forms and record values were not changed.
- The strict gate detected incidental `incident.entityimage` solution
  membership added by maker Save. Removed only its solution membership through
  the supported removal action; did not delete or modify the live field.
  Final gate: 263 already in solution; zero failed, missing, or unauthorized.
- Stage 36 Verify reconfirmed all 29 Picklists, 26 global Choices, and 97
  restored values. Archived the 702-identity pre-grid baseline and proved all
  original IDs unchanged, allowing only four identity entries for the two new
  views. Their bounded rerun created no views; stage 85 passed 706 identities,
  stable IDs, zero duplicates, and zero failures.
- Final stage-95 unmanaged export passed 53/53 roots, exact labels/colors for
  all 162 options, 29 bindings, all 13 selected read-only/color-enabled Web
  controls, both new views, and 245 unpacked files. ZIP SHA-256:
  `0243CE764FA103462585648FFA0911CEAACFFA3117B6FCB2CA89E3426A07D5D1`.
- Eight isolated credential-free regression suites passed: grid package,
  new views, Choice verification/presentation, strict solution isolation,
  wizard hardening, idempotency/export, and JSON schemas (88 documents;
  61 schema matches). The grid gate tests actual property text rather than
  treating the `static=true` binding qualifier as a boolean setting.
- No imports, managed releases, commits, or pushes were performed.

## Federal FOIA Production-Hardening Planning Checkpoint - 2026-11-04

- Operator approved local review and scenario planning updates only. No
  authentication, live requests, schema/data mutation, assignments, SharePoint
  provisioning, import, managed release, staging, commit, or push was performed.
- Reviewed working-tree status, dated build/manifest/task evidence, and pending
  runtime integration changes. This was a readiness review, not a complete code
  audit or fresh validation of the live environment.
- Latest recorded live checkpoint remains 2026-10-22: 263 memberships, 706 stable
  identities, 41 synthetic rows, and 53 matching unmanaged package roots.
- Recorded outstanding source work and the clean-clone reproducibility gate:
  current stages 30/66 enable Choice overlays from matching local Apply evidence,
  while original String/label payloads remain the rollback source. Promotion must
  not depend on borrowing another environment's evidence.
- Updated the scenario specification, plan, and tasks with PH-00 through PH-06,
  explicit prerequisites/owners, ten first-slice acceptance tests, and unresolved
  policy/identity/document/environment/operational decisions. The proposal is not
  approved for implementation or production release.
- Separated completed demo-role metadata/idempotency checks from still-pending
  real-user access and server-side enforcement tests. No existing unchecked
  business-behavior or production-release gate was declared complete.
- Validation passed: existing FOIA traceability check (300 catalog IDs and 84
  profile IDs), documentation consistency check, whitespace checks for the four
  updated documents, and syntax parsing of all 28 pending PowerShell files.
  Full implementation regression and live functional tests were not run; they
  remain PH-00 and later milestone gates respectively.
- Planning and next-work details:
  [Federal FOIA implementation plan](../specs/federal-foia-management/plan.md#production-hardening-increment---2026-11-04)
  and [tasks](../specs/federal-foia-management/tasks.md).

## Federal FOIA PH-00 Isolated Source Verification - 2026-11-04

- Continued local source-baseline verification only; no authentication, live
  requests, schema/data mutation, assignments, provisioning, real export/import,
  staging, commit, push, or deployment.
- Copied 273 source files into an isolated repository without credentials or
  runtime evidence. Tests used mocks and their own evidence paths. Verified
  SHA-256 hashes and file counts: all 286 original runtime-evidence files remain
  unchanged.
- All 15 selected standalone suites passed: Choice migration Preview,
  Apply/rollback, dependency preparation, exact Choice verification, global
  presentation, grid views, grid package verification, solution isolation,
  wizard hardening, idempotency/export, forms, JSON schemas, contract integrity,
  docs consistency, and FOIA traceability.
- Pester 5.7.1 request-runtime suite: 19 passed, zero failed/skipped. JSON:
  89 documents parsed and 61 payload schema matches. Traceability: 300 catalog
  IDs and 84 profile IDs validated.
- Reproduced the fresh-source blocker without network access: default contract
  selection returns no overlay without local Apply evidence, leaving 29
  rollback String definitions. Explicit contract resolution can produce all
  26 Choices/29 Picklists; this is not end-to-end provisioning proof.
- Grouped pending files for review without staging: 18 framework, 12 validation,
  17 scenario, 11 guidance, and one local test-output file. Full implementation
  review, full CI, source checkpoint approval, and clean-target reproducibility
  remain open.
- Updated the scenario plan/tasks with results and a proposed versioned
  source-controlled effective-contract decision. Runtime/payload implementation
  awaits approval; destructive migration protections must remain independent.

## Federal FOIA PH-00 Reproducible Choice Contract - 2026-11-04

- Operator separately approved local implementation of a versioned checked-in
  effective Choice contract. No live operations, commits, push, or deployment
  were authorized or performed.
- Added `CurrentSchema` version `1.0.0` with scenario/solution/publisher binding
  to the existing approved migration payload and schema. Normal stages
  30/50/66/95 share its selection without local Apply evidence. Present execution
  evidence remains validated; original String/label rollback payloads remain.
- Schema stage preflights types/bindings and existing options before mutations,
  creates missing Choices with bounded visibility polling, binds Picklists by
  GUID, records IDs, and publishes scoped metadata. Incompatible text fields
  stop rather than being skipped/deleted. Global Choice creation reuses the
  migration stage's extracted metadata-body builder.
- Stage 50 explicitly syncs/rechecks global Choice membership. Seed stage
  prevalidates all numeric/label mappings and live types/bindings/options.
  Inventory/export enforce exact current metadata and package definitions.
  Explicit `PreMigrationBackup` retains the legacy backup route without
  bypassing mandatory Choice checks or destructive migration approvals.
- Fresh-source isolated transport tests passed: 26 Choices, 29 GUID-bound
  Picklists, 97 numeric field values, 41 stable seeded record IDs, safe reruns,
  no Preview mutations, no fabricated Apply evidence, and negative gates for
  identity, incompatible type, unmapped input, and backup bypass.
- All 20 selected standalone suites and 19 runtime Pester tests passed.
  PowerShell syntax and ScriptAnalyzer 1.24.0 passed for eight changed
  implementation/test files. JSON: 89 documents and 61 schema matches.
  All 286 original runtime-evidence hashes remain unchanged.
- Updated scenario spec/plan/tasks and onboarding. Remaining gates include full
  pending-source review, applicable full CI and checkpoint commit approval,
  separately authorized live clean-target proof, policy/design decisions, and
  the later functional/security/release milestones. Mocked success is not a
  claim of production readiness or live deployment.

## Federal FOIA PH-00 Full Local CI And Blocked Review - 2026-11-04

- Full credential-free CI equivalent passed in an isolated Windows source copy:
  81 PowerShell files parsed, zero errors; ScriptAnalyzer 1.24.0 had zero findings
  under repository settings; all 32 standalone suites and all 91 Pester tests
  passed, with zero failed/skipped/not-run tests. markdownlint-cli2 0.18.1
  checked 93 Markdown files with zero errors. Hosted Linux CI and live tests
  were not run; this is not a security certification.
- Original evidence integrity passed: all 286 runtime-evidence files retained
  their SHA-256 hashes and count.
- Source review found two migration-safety blockers despite the green suites.
  An isolated mock proved stage 36 overwrites a valid post-Snapshot edit with
  stale saved data (expected `100000000`, actual `100000003`; 237 mocked
  mutations). A separate pagination probe proved Snapshot succeeds while
  ignoring 29 advertised next pages, omitting later ownership/mapping checks.
- These are additional mock probes, not failures of the existing CI suite and
  not claims of historical DEV data loss. No repository runtime implementation
  was changed in this review. No live access, export/import, staging, commit,
  push, or deployment occurred; pre-existing local test output was untouched.
- Checkpoint review remains blocked. Request approval for local fixes/tests,
  including complete pagination, live/snapshot cohort comparison, and a
  documented write-quiescence boundary; then resume the remaining source
  review. The green suite alone does not satisfy PH-00 or production readiness.
- Detailed findings and checkpoint exclusions:
  [PH-00 full CI and review blockers](../specs/federal-foia-management/plan.md#ph-00-full-local-ci-and-review-blockers---2026-11-04).

## Federal FOIA PH-00 Approved Migration-Safety Fixes - 2026-11-04

- Operator approved local code/test/documentation fixes for both review
  blockers. No live access, destructive execution, staging, commit, push, or
  deployment was authorized or performed.
- Stage 36 now reuses the paged collection reader with page-shape, cycle,
  environment, and collection checks. Every returned data page is included in
  ownership/mapping validation and Snapshot capture.
- Before any mutating request, Apply compares the full binding/row/value cohort,
  exact numeric mappings, attribute metadata identities, entity-set/primary-ID
  identities, and rollback definitions against the saved snapshot. Drift or
  malformed/incomplete evidence stops Apply and requires a refreshed Snapshot.
- Expanded stateful tests use one-row pages and capture all 97 values.
  First/late-page edits, cleared/deleted/added/duplicate rows, replaced metadata,
  malformed bindings/restore values/definitions, late-page foreign/unmapped
  rows, missing page values, cross-environment/collection next links, and
  paging cycles are rejected without mutations. Empty Snapshot, healthy
  Apply/Verify, rerun, and rollback paths pass.
- Eight affected suites passed: migration Apply, exact migration verification,
  current-contract reproducibility, migration Preview, dependency preparation,
  Choice presentation, solution isolation, and idempotency/export. One initial
  runner-path typo exited 64 before a test ran; the correctly named
  idempotency/export suite passed. Final migration regression passed again
  after adding explicit malformed metadata-ID rejection.
- Syntax and pinned ScriptAnalyzer 1.24.0 passed for the three affected
  PowerShell files. Original evidence integrity passed: 286 unchanged files
  and SHA-256 hashes. The earlier complete 32-suite/91-Pester/full-lint run
  predates these fixes; post-fix checks are targeted, not a second full CI run.
- Onboarding explicitly requires an independently established write freeze
  from Snapshot through Apply and Verify. Preflight is not a transaction,
  concurrency lock, or authorization to migrate an active production workload.
- Remaining gate: complete pending-source review and obtain checkpoint commit
  approval, then resolve PH-01 policy/design decisions. All live deployment,
  access/security testing, and production-release gates remain open.

## Federal FOIA PH-00 Final Grouped Review Findings - 2026-11-04

- Completed the remaining checkpoint-oriented review across 59 pending paths:
  18 runtime/schema/profile, 13 validation, 17 scenario payload/planning/evidence,
  and 11 guidance. The pre-existing local test XML remains excluded.
- Reproduced an existing-global-Choice preflight gap: a wrong English label
  did not stop Apply. It converted all 29 fields, issued 211 mock mutations,
  and reported success; only Verify rejected the incompatible definition.
- Reproduced an export verification gap: both FOIA views passed with OR filters
  admitting rows without their FOIA marker. This proves a package-gate defect,
  not a live data exposure or bypass of table permissions.
- Reproduced a portability defect: the dependency-preparation suite exits 1
  before tests execute when `TEMP` is unset. Hosted Linux CI was not run.
- Resolved the new wizard skill's relative paths read-only: all six `../../`
  links are broken because the skill is one directory deeper than the prompt
  from which it was copied.
- Confirmed historical evidence remains dated October 22, future managed
  release/commit/push authorizations are false, all 26 Choices are represented
  in the design, and the reporting filter uses the approved numeric value.
  A limited credential-key check found zero nonempty matches in pending JSON;
  it is not a comprehensive secret scan.
- No repository runtime implementation changed during this review pass.
  All defect probes used an isolated credential-free copy or process.
  No live access, staging, commit, push, export/import, or deployment occurred.
- Checkpoint sign-off is blocked by the four reproduced findings. Obtain one
  consolidated local-fix/test approval, then complete applicable validation
  before requesting commit approval. See
  [final grouped source review](../specs/federal-foia-management/plan.md#ph-00-final-grouped-source-review---2026-11-04).

## Federal FOIA PH-00 Final Corrections And Checkpoint Validation - 2026-11-04

- Operator approved all four local corrections and validation. Stage 36 now
  validates every existing global Choice before any mutation, including exact
  labels, values, colors, global/type flags, and consistent metadata identity.
  Compatible definitions are reused; newly created definitions are read back
  before replacing columns.
- Export verification now requires a mandatory primary-table FOIA conjunction,
  rejecting OR-only, nested-OR-only, and alias-qualified marker conditions.
  Dependency preparation supports unset `TEMP`; all six skill links now resolve.
  Onboarding documents the guards and a write freeze covering both data and
  customization writers. Preflight still is not a transaction or concurrency lock.
- Targeted regressions pass: seven existing-Choice drift cases stop with zero
  mutations; healthy reuse passes; grid checks include fourteen negative gates
  and a positive explicit-AND case; the old broken links fail the new docs guard,
  fixed links pass; dependency preparation passes with `TEMP` explicitly unset.
- Fresh full credential-free Windows validation passed in a separate isolated
  source copy: 81 PowerShell files parsed, zero findings under pinned
  ScriptAnalyzer 1.24.0/repository settings, all 32 standalone suites, all 91
  Pester 5.7.1 tests (zero failed/skipped/not run), and pinned Markdown lint over
  all 88 current source Markdown files. A runner redirection initially omitted
  Pester counters from the summary; the rerun asserted the actual result object
  and confirmed all 91 passed. Hosted Linux CI and live validation were not run.
- SHA-256 integrity check confirms all 286 original runtime-evidence files
  unchanged. Exact checkpoint scope is 60 source paths: 18 runtime/schema/profile,
  14 validation, 17 scenario payload/planning/evidence, and 11 guidance.
  Whitespace checks pass. Credentials, runtime metrics, pre-existing local test
  XML, packages/unpacked output, and session probes remain outside the checkpoint.
- The four final review blockers are resolved locally. After validation, the
  operator explicitly approved staging the exact 60 reviewed source paths and
  creating one local checkpoint commit only. No push, live request,
  export/import, or deployment is authorized by that approval. Historical
  October evidence remains historical.
- The initial staged whitespace check also covered newly added files and caught
  trailing EOF blank lines in two Markdown files. Removed only those blank lines;
  the commit remains gated on a successful staged recheck, without bypasses.
  PH-01 policy/design decisions and server-enforced behavior, access tests,
  end-to-end journeys, operations, and production-release gates remain open.

## Federal FOIA Demo Presentation Preparation - 2026-11-04

- Operator requested the next step toward showing the existing prototype.
  Prepared the existing seven-minute script and companion copy, presenter
  answers, and operator walkthrough locally. The source checkpoint remains
  `1e4fb7b`; this presentation update is not staged or committed.
- Focus is normal request -> related work -> seeded expedited/released examples
  -> operations dashboard. Other journey records are optional bookmarks.
  Removed unsupported claims that the demonstration proves complete journeys,
  automated clocks, assigned-role separation, immutable release evidence,
  document authorization, or delivery.
- Added a separate, unchecked current-readiness checklist. Historical rehearsal
  results remain preserved and explicitly labeled historical; no new live result
  is claimed. No generator, build, seed, export, or deployment script was run.
- Local validation passed: identical presenter copies; 390 narrative seconds
  plus 30 navigation seconds equals seven minutes; current rehearsal remains
  unchecked; documentation consistency, FOIA traceability, eight-file Markdown
  lint, whitespace, and all 286 historical runtime-evidence hashes pass.
  Read-only DEV/browser
  authorization and the actual click-through/timed rehearsal remain pending.
  Do not declare the presentation ready until observed checks pass. No record
  changes, stage advancement, messages, external document access, role changes,
  live access, commit, or push were performed during preparation.

## Federal FOIA Approved Read-Only Demo UI Check - 2026-11-04

- Operator explicitly approved the bounded DEV/browser check and completed
  Microsoft sign-in manually. Inspected only the existing FOIA app and synthetic
  demonstration surfaces; no business record-edit/save, stage advancement,
  message, role change, external document access, build/seed/export, deployment,
  commit, or push action was issued.
- App navigation and Active FOIA Requests worked. The normal request showed
  expected tracking/lifecycle/validation fields, acknowledgment reference,
  seeded due date, and Open disposition. Intake Channel exposed all seven
  options; the list was dismissed without selecting and Saved status remained.
  Associated lists showed Synthetic FOIA Case 1, Synthetic Normal Search,
  Synthetic Normal PDF, and Synthetic Normal Review.
- Expedited request showed Search/Granted; released request showed Closure/Full
  grant and a related Synthetic Released Package v1. Synthetic source tags were
  observed. This did not verify actual document authorization or delivery.
- Operations charts rendered: Redaction 1, Approval 1, Review 2, Search 1;
  expedited Granted 1. Other dashboards and all 41 records were not revalidated.
- Presentation gaps: the normal request's process bar remains at Intake while
  the Lifecycle Stage field is Review; a visible legacy-web-client/Unified
  Interface banner appears. Console observations include PredictAPI, masking
  feature/400, resource 401, and fingerprint-configuration CORS issues. Checked
  screens loaded, but causes and wider impact remain undiagnosed; no error-free
  or production-readiness claim is made.
- Browser is left on Synthetic Normal Request with Saved status observed after
  rendering. The diagnostic click-through is not a timed narrated rehearsal.
  Presenter copies now disclose the mismatch and current evidence boundary.
  Full observations and remaining checks are in the scenario's existing
  `demo-dry-run.md`; live polish needs separate approval.
- Final local checks passed after recording observations: presenter-copy parity,
  seven-minute script budget, truthful unchecked timed-rehearsal status, docs
  consistency, FOIA traceability, nine-file Markdown lint, and whitespace.
  All 286 historical runtime-evidence hashes remain unchanged; nothing is staged.

## Federal FOIA Read-Only DEV Polish Diagnosis - 2026-11-05

- Operator approved read-only app/process diagnosis and a local fix plan.
  Scoped same-origin GETs confirmed the selected app's `clienttype=2` and the
  normal request's Review lifecycle versus an active Intake-only process path.
  Verified exact app, workflow, request, parent, and process-instance identities.
- Microsoft's guidance matches the legacy-app banner and recommends supported
  app-properties conversion to Unified Interface. The local builder omits an
  explicit client type, but that omission is not proven to cause the current
  value; Microsoft's creation example also omits it. The preview does not
  prescribe an unverified numeric flag or hide warnings.
- Prepared independent previews for selected-app conversion/publication and
  one synthetic instance's native sequential progression to Review. Included
  identity/draft/drift checks, before-state capture, native stage gates,
  scoped verification, recovery limitations, and explicit exclusions.
  Clarification due date is blank; do not fabricate one to bypass a gate.
- No live setting/record/stage/process-definition change, publication, build,
  export/import, framework implementation, commit, or push was performed.
  Console causes and timed narration remain open. No production-readiness
  claim or new deployment/export baseline is made.
- Local preview validation passed: documentation consistency, FOIA requirements
  traceability, five-file Markdown lint, and whitespace. All 286 historical
  runtime-evidence hashes remain unchanged; nothing is staged.

## Federal FOIA Repository Synchronization - 2026-11-06

- Operator authorized review, validation, commit/push, and a ChatGPT handoff
  only; no Azure, Dataverse, or Dynamics 365 deployment or live action.
- Verified repository `bradlaw76/power-platform-vscode-starter`, HTTPS origin,
  branch `feature/federal-foia-choice-normalization`, and starting commit
  `1e4fb7bd57fcab40242b6a26b4f75bd51e52169b`. The feature branch initially had
  no upstream and no matching remote branch. No branch switch was performed.
- Fetched origin. Relative to `origin/main`, HEAD had one local-only checkpoint
  and two remote-only commits. Those remote commits add then remove an unrelated
  document: their net tree equals the checkpoint's parent `1bb72aa`.
  Preserve feature history and publish the current feature branch without
  rebasing, merging unrelated work, or force-pushing.
- Reviewed all nine modified documentation files. Retain the existing
  60-file Choice-contract checkpoint and FOIA solution summaries. Keep
  `.env.ps1`, `.wizard-metrics/`, and untracked `testResults.xml` local.
  Credential-pattern checks on all 62 changed tracked paths found no candidates;
  this is not a guarantee or a substitute for a comprehensive security review.
- Credential-free isolated Windows validation passed: all 32 standalone CI
  suites; all 91 Pester 5.7.1 tests (zero failures/skips); all 81 PowerShell
  files parsed; PSScriptAnalyzer 1.24.0 reported zero findings; Markdown lint
  0.18.1 passed all 88 documents; whitespace checks passed.
  No dependency installation, live build, export, import, or deployment ran.
- Publication and final SHA verification are pending at this source checkpoint.
  Record the verified source SHA and remaining work in the canonical ChatGPT
  handoff after the first push. The handoff is absent on this FOIA branch;
  unrelated framework status histories remain preserved on their remote branches.

## Wizard Behavior Versions

Record wizard version changes here so you can trace which behavior applied to each build.

| Date | Version | Change Summary |
| ---- | ------- | -------------- |
| 2026-07-13 | v1.2 | Added Q6b (standard vs custom tables), Q12 (new/existing solution), Q13 (new/existing prefix). Total: 14 discovery questions. |
| 2026-07-13 | v1.3 | Added `06-demo-script-wizard.ps1` (post-scenario demo script generator) and `07-demo-dry-run.ps1` (rehearsal helper). |
| 2026-07-15 | v1.4 | Added mid-project retrofit support: wizard can reverse-engineer spec from partial builds. `docs/onboarding.md` designated authoritative bootstrap sequence. |
| 2026-07-16 | v2.0.0 | Contract-driven wizard baseline: `wizard-contract-v1.md`, `wizard.profile.json`, optional module entrypoint `70-build-web-resources.ps1`, payload path standardization, and CI consistency checks. |
| 2026-07-17 | v2.0.1 | Made `80-post-build-analysis.ps1` generic and parameterized (`SpecPath`, `PlanPath`, `TasksPath`, `PayloadFolder`, `ReadmePath`) with marker-safe README updates, preview mode, and branch-aware push confirmation. |
| 2026-07-17 | v2.0.2 | Added disclosed local wizard telemetry (`.wizard-metrics/events.jsonl`) plus `81-build-progress-matrix.ps1` to summarize step completion/drop-off across runs. |

## Release Process

Use semantic versioning for wizard behavior:

- Major: contract changes
- Minor: new optional modules
- Patch: bug fixes only

For every release tag, publish notes with:

- What changed
- What consumers must update
- Quick validation checklist after upgrade

## Run summary template

Copy this block for each run:

```text
Date:
Runner:
Environment URL: https://<org>.crm.dynamics.com
Build Type (Demo/Prod):
Scripts Run (20,30,40,50,60):
Tables (created/skipped/failed):
Columns (created/skipped/failed):
Relationships (created/skipped/failed):
Demo Data Planned (yes/no):
Demo Data Target Tables / Counts:
Demo Data Hero Records / Purpose:
Demo Data Task Activity Scope / Parent Limit / Ordering:
Demo Data Method / Rerun Behavior:
Demo Data Source Tag / Privacy Rule:
Demo Data Created (yes/no/not implemented):
Demo Data Cleanup Verified (yes/no/not applicable):
Forms (created/updated/skipped/failed):
Views (created/skipped/failed):
Starter Main Form patched on rerun (yes/no):
Non-starter Main forms preserved (yes/no):
Business labels visible on starter form (yes/no):
Solution Exported (yes/no):
Native Reporting Stage (created/updated/skipped/failed):
Synthetic Data Stage (created/updated/skipped/failed):
Second-Run Stable IDs (yes/no/not applicable):
Second-Run Duplicate Count:
Unmanaged Package Unpacked and Inspected (yes/no):
Acceptance Package Imported (must be no):
Solution Unpacked (yes/no):
Solution Packed (yes/no):
Solution Imported (yes/no):
BPF Report Present (yes/no):
BPF Status (pass/fail/skipped):
BPF Active Verified (yes/no):
BPF In Solution Verified (yes/no):
BPF App Linked (yes/no/pending):
BPF Stage Count / Threshold:
BPF Condition Count / Threshold:
BPF Step Count / Threshold:
BPF Branch Predicate Summary Recorded (yes/no):
BPF Retry or Lock Handling Notes:
Git Branch:
Commit ID:
Notes:
```

## Planning checkpoint (Spec Kit)

Complete this before implementation:

- Spec file complete: yes/no
- Plan file complete: yes/no
- Tasks file complete: yes/no
- Discovery questions answered: yes/no
- Scenario owner sign-off: yes/no

## Validation checkpoint

- Maker portal verification complete: yes/no
- Required tasks from `tasks.md` complete: yes/no
- Known issues captured with owner/date: yes/no
- README generated build summary reviewed/updated: yes/no
- Post-build analysis preview run completed (`80-post-build-analysis.ps1 -PreviewOnly`): yes/no
