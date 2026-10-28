# Build Log

Record each build run here. One row per execution.

Use this to document what was planned, built, validated, and promoted.

## Wizard Behavior Versions

Record wizard version changes here so you can trace which behavior applied to each build.

| Date | Version | Change Summary |
| ---- | ------- | -------------- |
| 2026-10-27 | Contract v2.2.0 | Local-first repository update advisor, explicit fetch, capability relevance and immutable Apply run source baselines. No automatic update adoption or deployment. |
| 2026-10-23 | Contract v2.1.0 | Independent native/HTML/both/neither reporting choice; requirement-backed approved HTML definitions replace the fixed report trio and inferred metrics. No live deployment claimed. |
| 2026-10-19 | Contract v2.0.0 | Mandatory, use-case-neutral semantic field inventory; pre-generation/build gates, live stage-30 type verification and post-relationship/pre-export metadata validation, including direct stage 95. Existing scenarios require explicit planning upgrades; no automatic destructive migration. |
| 2026-07-13 | v1.2 | Added Q6b (standard vs custom tables), Q12 (new/existing solution), Q13 (new/existing prefix). Total: 14 discovery questions. |
| 2026-07-13 | v1.3 | Added `06-demo-script-wizard.ps1` (post-scenario demo script generator) and `07-demo-dry-run.ps1` (rehearsal helper). |
| 2026-07-15 | v1.4 | Added mid-project retrofit support: wizard can reverse-engineer spec from partial builds. `docs/onboarding.md` designated authoritative bootstrap sequence. |
| 2026-07-16 | v2.0.0 | Contract-driven wizard baseline: `wizard-contract-v1.md`, `wizard.profile.json`, optional module entrypoint `70-build-web-resources.ps1`, payload path standardization, and CI consistency checks. |
| 2026-07-17 | v2.0.1 | Made `80-post-build-analysis.ps1` generic and parameterized (`SpecPath`, `PlanPath`, `TasksPath`, `PayloadFolder`, `ReadmePath`) with marker-safe README updates, preview mode, and branch-aware push confirmation. |
| 2026-07-17 | v2.0.2 | Added disclosed local wizard telemetry (`.wizard-metrics/events.jsonl`) plus `81-build-progress-matrix.ps1` to summarize step completion/drop-off across runs. |
| 2026-09-30 | Form formatter v1 | Added optional, hash-approved form-layout Preview/Apply for active, customizable, wizard-owned custom Main forms after app assembly. |
| 2026-10-15 | Contract v1.13.0 | Added default-off, planning-only accelerator recommendations after discovery and before architecture finalization. |
| 2026-10-16 | Contract v1.14.0 | Added separate accelerator startup preference, granular requirement traceability, validated package manifest input, schema-rendering correction, and generator-level Markdown cleanup. |
| 2026-10-16 | Contract v1.15.0 | Added default-off provider-neutral FAST-006 dry-run build planning with approved-artifact, managed-ownership, readiness, rollback, and traceability gates. |
| 2026-10-19 | FAST-007 | Added local-only execution-readiness reporting and an early-return orchestrator preflight; readiness never authorizes execution and FAST-dependent Apply stays blocked. See the operational guide; this entry claims no live readiness or test result. |
| 2026-10-19 | FAST-008A / Contract v1.16.0 | Documented GET-only verification, RS256 envelopes and independent X509 trust; Authenticated default with explicit RecordedTest/LocalPlanning diagnostics. Mock-only milestone; no live GCC access, test pass, deployment approval or execution claim. See [trusted verification](fast-integration/trusted-environment-verification.md); actual validation outcomes must be recorded below. |

## Release Process

### Repository update advisor maintainer validation - 2026-10-27

- Contract 2.2.0; update advisor passed 56 local Git fixture assertions, including
  startup controls, isolated fetch, history states, scenario relevance, source
  fingerprints and immutable scenario/solution/publisher/run-bound records.
- Contract integrity, JSON/schema, docs consistency, script order, script smoke,
  wizard modes and accelerator integration passed.
- Final run-state persistence, Preview non-mutation and semantic-field
  regressions passed (85 semantic checks). FAST-007 readiness passed 129
  assertions and skill parity passed 98 Pester tests.
- Touched-script parsing, PSScriptAnalyzer 1.24.0, Markdown lint 0.18.1
  (17 changed Markdown files) and whitespace checks passed.
- Working-copy check used cached metadata only; reported diverged history and
  locally modified source. No public upstream fetch or Dataverse deployment.
  The full aggregate was not run at this initial implementation checkpoint. See
  [the implementation tasks](../specs/repository-update-advisor/tasks.md).

### Complete integration publication validation - 2026-10-27

- The complete `run-quality.ps1` passed with exit code 0 on a 434-file,
  SHA-256-verified local source snapshot outside OneDrive. It included all
  approved current integration work plus the repository update advisor.
- Markdown lint 0.18.1 passed 151 files; all PowerShell parsed and
  PSScriptAnalyzer 1.24.0 reported no findings.
- JSON validation parsed 164 documents and matched 24 payloads plus 48
  accelerator documents to schemas. Contract integrity passed.
- All 35 remaining standalone suites passed, including advisor, reporting,
  semantic-field, FAST, formatter, Preview, run-state and source-control checks.
- Pester 5.7.1 passed all 128 tests, with zero failed, skipped or not run.
- Final documentation-only review/handoff evidence additions are checked
  separately with the pinned Markdown linter and documentation/contract checks.
  Both visual guides' 39 local links/assets were verified.
- Publication scope: all current integration and documentation work on
  `review/fast-reporting-integration-20261023`; commit and origin push explicitly
  approved. This does not authorize a default-branch merge or Dataverse work.
- No live Dataverse authentication, collection, deployment, import or destructive
  cleanup was performed. Synthetic tests do not establish live app usability.

### Release tagging

Use semantic versioning for wizard behavior:

- Major: contract changes
- Minor: new optional modules
- Patch: bug fixes only

For every release tag, publish notes with:

- What changed
- What consumers must update
- Quick validation checklist after upgrade

## Semantic field standard maintainer validation - 2026-10-19

- Contract: 2.0.0; synthetic, credential-free fixtures only.
- Semantic regression: 83 checks passed, including partial-create recovery,
  wrong-type rejection, transport failures, direct-export blocking, Preview,
  reruns and scoped publication.
- Pester: 113 tests passed across runtime and skill-parity suites.
- Focused compatibility checks passed: Preview non-mutation, run-state persistence,
  contract integrity, documentation consistency, script order, JSON/schema,
  script smoke, Choice presentation, idempotency/export, FAST-disabled compatibility,
  execution readiness (129 assertions), and mocked live-environment preflight.
- Form formatter assertions and cleanup passed in a temporary copy outside
  OneDrive. In-repository assertions passed, but OneDrive blocked their cleanup.
- Changed-script parsing and pinned PSScriptAnalyzer passed; pinned Markdown
  lint and whitespace checks passed.
- No live Dataverse authentication, metadata reads, mutations, export, import or
  destructive migration occurred. Mock transport/PAC results do not prove live
  endpoint compatibility or functional app surfaces.

## Reporting choice maintainer validation - 2026-10-23

- Credential-free intake checks passed for native/HTML/both/neither choices.
- HTML regression checks passed for current requirement references, explicit
  report counts, a custom checkout lifecycle field/table, empty-data behavior,
  reruns, stale/unapproved definitions, mapping failures, and missing metadata.
- Native reporting opt-out, focused report wizard, app rerun, orchestrated
  reporting gates, Preview non-mutation, run-state persistence, and detailed
  source-control intake compatibility checks passed.
- Skill parity: 96 Pester tests passed. JSON/schema, documentation consistency,
  contract integrity, script order, changed-script parsing/PSScriptAnalyzer,
  Markdown lint, and whitespace checks passed.
- No live Dataverse authentication or deployment was performed. Mock/preview
  checks do not establish live report rendering, permissions, or app placement.

## Integrated review release validation - 2026-10-23

- Verified timestamped GitHub backup branches for `main` and the FAST-007 feature
  baseline before preparing `review/fast-reporting-integration-20261023`.
- A fresh full `run-quality.ps1` passed with exit code 0 against a hash-verified
  421-file source snapshot outside OneDrive: Markdown lint (149 files), parsing,
  PSScriptAnalyzer, JSON/schema, contract integrity, all 34 remaining standalone
  suites, and all 126 Pester tests passed. Formatter assertions and cleanup passed.
- FAST-008A passed 103 assertions, FAST-007 readiness passed 129, and the universal
  semantic-field suite passed 83 checks. JSON validation parsed 158 documents and
  matched 22 payloads plus 48 accelerator documents to schemas.
- The initial aggregate exposed a historical-date certificate in the CLI test.
  Fixed only the test fixture to use a separate ephemeral certificate valid at
  actual invocation time; added an observed-clock assertion. Production
  certificate validity, provenance, and authorization restrictions are unchanged.
- No live Dataverse authentication, access, deployment, export, import, or
  default-branch merge was performed. Publication and review handoff are separate
  from deployment approval. See the [review guide](fast-reporting-review-guide.md)
  for baseline references, change map, remaining boundaries, and a ChatGPT prompt.

## Run summary template

For reporting runs, record native-dashboard and HTML decisions separately,
definition approval, spec/plan requirement references, mapping/metadata
validation, created/updated/skipped/failed counts, solution membership, and
actual app/form placement verification. Report generation is not placement
verification and is not evidence of a live-data or app-usability pass.

Copy this block for each run:

```text
Date:
Runner:
Wizard Contract Version:
Repository Identity / Full Source Commit SHA:
Source Baseline ID / Captured At UTC:
Source Identity Status (verified/unverified) / Reason:
Working Tree Modified / Local Changes SHA-256:
Orchestrated Run ID / Immutable Apply Baseline Path (not written by Preview or direct stages):
Update Check Status / Compared Baseline SHA / Upstream SHA:
Update Check Freshness (cached-not-network-verified/fetched/fetch-failed):
Scenario Update Context / Relevant Capabilities / Review Decisions:
Environment URL: https://<org>.crm.dynamics.com
Build Type (Demo/Prod):
Accelerator Recommendations Enabled (yes/no):
Accelerator Analysis ID / Catalog Snapshot:
Accelerator Recommended / Selected Architecture:
Accelerator Selected Packages (version/hash):
Accelerator Environment Readiness / Evidence Expiry:
FAST-Dependent Execution Gate (closed/not applicable; FAST-007/008A cannot open it):
Execution Readiness Enabled / Report Path:
Execution Readiness Status / Blockers:
Execution Readiness Evaluation Time UTC / Evidence Expiry (maximum 24h lifetime):
Execution Readiness Target URL / Environment ID / Tenant ID:
Execution Readiness Decision ID / Plan ID / Evidence Hash / Input Fingerprints:
Execution Readiness Scope SHA-256:
Execution Readiness Evidence Source / Collection Mode (Live/Mock/raw local; never relabel mock as live):
Execution Readiness EvidenceTrustPolicy (Authenticated default/RecordedTest/LocalPlanning):
Execution Readiness verifiedForHumanReview (false for RecordedTest/LocalPlanning):
Trusted Verification Envelope Path / Signature / Independent Certificate Source:
Trusted Certificate Validity at Collection and Evaluation:
Actual Authenticated Environment ID / Tenant ID / Organization ID / User ID:
Verification Plan SHA / Catalog Snapshot / Dependency Hash / Input and Package Metadata Hashes:
Verification Checks (verified/missing/inaccessible/unsupported/inferred) / Blockers:
Verification Collection and Expiry UTC / Read-Only Scope Confirmation:
Execution Authorized (false for every policy/status, including READY_FOR_APPROVAL):
FAST-Dependent Apply Block Verified / Readiness-Only Early Return:
Execution Readiness Validation Commands / Actual Outcomes / Skips:
FAST-008A Mock-Only Validation Outcomes (no live GCC access; no inferred test passes):
Quality Runner Parser and Stage Result / Smoke Timer Prompt Regression Outcomes:
OneDrive Cleanup Contention (separate limitation; no unrelated refactor):
Accelerator Decision Change Approval (yes/no/not applicable):
Scripts Run (15,20,30,optional 35,40,50,55,60,optional 61,64,62,optional 63,65,66,80,85,95):
Tables (created/skipped/failed):
Columns (created/skipped/failed):
Semantic Inventory Path / Explicit Approval / Decision Count:
Semantic Planning and Payload Gate Outcomes:
Semantic Live Metadata Report / Expected versus Actual Types:
Semantic Drift / Affected Dependencies / Remediation Plan:
Choice Scope / Stable Values / Labels / Defaults / Mappings Verified:
Categorical Text Exception Approval References:
Lookup Targets / Relationships / Cascades Verified:
Functional Forms / Views / Charts / BPF / Automation / Integration / Report Evidence:
Semantic Final Metadata Gate before Export:
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
Form Formatting Contract (`specs/<slug>/form-layouts.json`) Present (yes/no):
Form Field Components Applied (Toggle/OptionSet Wrapper/none):
Choice Presentation Payloads (files/none):
Choice Presentation Plan Hash:
Choice Pastel Colors and Inline Label Icons Verified (yes/no):
Form Formatting Schema Valid (yes/no/not applicable):
Form Formatting Planned Target:
Form Formatting Preview Artifacts Reviewed (yes/no/not applicable):
Form Formatting Approved SHA-256:
Form Formatting Apply (updated/unchanged/blocked/failed/not applied):
Form Formatting Readback / Scoped Publish Verified (yes/no/not applicable):
Form Formatting Boundary Verified (wizard-owned custom active customizable Main form; yes/no/not applicable):
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
### Power Apps grid gate

- Contract: `specs/<scenario-slug>/grid-controls.json` / not requested
- Stage 61 Preview handoff reviewed:
- Classic solution explorer all-views configuration published:
- Inline editing configured explicitly:
- Exported metadata verification: PASS / FAIL / N/A
- Runtime control: `Microsoft.PowerApps.PowerAppsOneGrid`
- Verification report:
- Note: view creation alone does not guarantee OneGrid; subgrid support is deferred.
## Optional accelerator build-planning evidence

- Approved architecture decision ID:
- Build plan ID:
- Architecture: FAST-based / Hybrid / Fully Custom / not used
- Dry-run status:
- Environment gate status and evidence age:
- Managed direct modifications permitted: no
- Execution authorized: no
- Build-plan artifact folder:
- Blocked actions and remediation reviewed:
