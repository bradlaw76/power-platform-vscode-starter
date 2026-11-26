# Installed framework handoff (H008)

This is starter integration under issue #12, reusing Automation Framework H008
(issue #24, merged PR #26). It is not a second controller or implementation.
Spec Kit remains required before build. This optional continuation adds no
mandatory discovery question, build stage, installation or deployment.

## Accepted-outcome reliability

Reuse the existing consolidated confirmation and original accepted requirements;
do not add discovery questions or a separate approval ledger. Author
`requirements-coverage.json` against `schemas/requirements-coverage.schema.json`.
Its original confirmation source is scenario-relative (`provenance.sourcePath`,
exact `sourceSha256`); excerpts also match current spec/plan, whose hashes and
real task excerpts are bound. Select only applicable operations and criteria:
binding, CRUD (create/read/update/delete and related assignment/inspection),
lifecycle, chronology, metrics, cancellation and concurrency. Read-only/no-report
designs require only their accepted surfaces. A narrowed read-only task cannot
satisfy accepted mutations; mapping and source existence are not functional proof.
Fictional confirmation uses `kind: simulation`, never native approval.

Terminal intake accepts `-RequirementsCoveragePath` from that same confirmation.
For existing accepted artifacts, generate/validate without rediscovery:

```powershell
pwsh .\scripts\bootstrap\13-validate-requirements-coverage.ps1 -ScenarioFolder .\specs\example -CoverageInputPath .\confirmed-coverage.json
pwsh .\scripts\bootstrap\12-check-wizard-capabilities.ps1 -ScenarioFolder .\specs\example -RequireCoverage -RequireFrameworkRuntime -PythonExecutable python
```

The safe consolidated preflight checks source scripts/helpers/schema/profile and
the selected installed package version, origin and functional API. A skill copy
does not install runtime capabilities. Missing capabilities block affected work;
no install, authentication, worker, native write or deployment is attempted.
Intake runs that same preflight with `-PlanningWorkspaceRoot` to verify the actual
selected profile and required wizard/onboarding guides; missing external runtime
files cannot fall back silently to a copied skill. Instruction-only initialization
is still instruction-only, not runtime installation.
Handoff validates present coverage before any runtime operation. Legacy scenarios
without applicable accepted-outcome coverage retain legacy behavior; explicitly
covered deliveries must not omit it from independent runtime verification.
New intake marks `Accepted Outcome Coverage` in the generated planning files;
the validator refuses missing coverage for those files instead of silently
treating them as legacy. Author coverage from the existing confirmed outcome,
not another approval meeting. Explicit read-only outcomes still validate with
only read criteria.
Configure the existing worker's `requirements_coverage` input with the exact
artifact. Independent evidence binds criterion IDs, coverage/source/task hashes
and claim identity; synthetic evidence cannot become native acceptance.
For source-only reconciliation, the installed worker's `--reconcile-only` mode
uses accepted current task/decision provenance, `task_kinds: ["prepare"]`,
`scope.environment_writes: false`, separate `verify_command` and `verify_outputs`
including `functional-evidence.json`. It reuses canonical claim/finish and holds,
never imports fictional approval or runs an implicit application rebuild.
Reconciliation never replays the handoff's completion or blocked-result cache:
the worker must check current selected source and verifier fingerprints each time.
Use explicit existing `-TaskIds` to request source-rechecks of eligible blocked
tasks. Omission retains the worker's legacy selection, not blocked-task recovery.
The canonical worker still rejects unknown IDs and preserves business, adoption,
uncertainty and owner holds; selecting an ID does not release it.

```powershell
pwsh .\scripts\bootstrap\09-framework-handoff.ps1 -ProjectRoot <external-project> -RuntimeWorkspace <canonical-workspace> -ScenarioSlug <slug> -Action worker -WorkerConfigPath <selected-config.json> -ReconcileOnly -TaskIds <existing-task-id> -PythonExecutable <selected-python>
```

Inside PowerShell, call the script directly with `-TaskIds @('PREPARE-A',
'PREPARE-B')` for multiple existing IDs. The Python entrypoint uses repeated
`--task-id PREPARE-A --task-id PREPARE-B` alongside `--reconcile-only`; both
forward the exact selection to the existing worker. Changed task selections
are part of the handoff intent, never an implicit full-store dispatch.

Omit `-ReconcileOnly` for an accepted implementation/extension task through the
same worker/config. Keep accepted coverage and real independent assertions bound
to the new task fingerprint; do not reuse a source-only receipt as delivery.

Reusable credential-free fixture inputs:
`scripts/ci/fixtures/requirements-coverage.fixture.json` and
`requirements-confirmation.fixture.json` in that same folder. Copy confirmation
into the external scenario as `confirmed.json`; bind its real SHA-256 (the input
template's zero hash is intentionally invalid), use the exact outcome/task
excerpts in spec/tasks, and let the generator hash spec/plan/tasks.
`scripts/ci/test-requirements-coverage.ps1` executes this public CLI path. These
are generic synthetic examples, not field/report approval or a native pilot.

Native validator reuse is surgical, from
`review/fast-reporting-integration-20261023` commit
`378ebd0a90c609207b767a9bac81ab72f4c98f35`: semantic script/helper/schema/example/test,
HTML schema/example/runbook, semantic standard and resilient Dataverse helper.
Dependency inspection also required that commit's existing
`choice-presentation-tokens.ps1` and `reporting-plan.ps1`. No branch merge or
duplicate native validator was introduced. This lineage does not inherit that
branch's FAST, source-baseline or native runner integration.
`-RequireNativeBuild` reports BLOCKED until native executor integration is
independently reviewed; preflight approval fields are always false.
Run real `14-validate-semantic-fields.ps1` Planning/Payload/Metadata gates and
approved report definitions through their actual native mechanisms. Existing
semantic helper regression exercises planning, payload and injected metadata;
`-IncludeBranchIntegration` explicitly requires the full authoritative branch's
runner/source-baseline integration and is not this surgical adoption's acceptance.

## Before starting

Use the [release consolidation guide](release-consolidation.md) to distinguish
the selected installed source/package from an unmerged candidate. A copied
skill or repository link is not installation. Build verification profiles are
separate from this handoff's delivery JSON and do not grant synchronization,
worker, Apply or deployment authorization.

- Select an external consumer project and a separate external runtime folder.
  Neither may be inside either framework source tree or overlap the other.
- Complete the selected `specs/<slug>/spec.md`, `plan.md` and `tasks.md`.
  Preserve handwritten text and native task identifiers.
- Load the actual project-local execution policy and instruction entrypoint.
  Reuse accepted planning for routine corrections; reconcile affected notes
  incrementally. New project inheritance and existing instruction migration
  follow [the shared wizard lifecycle](wizard-updates.md#local-instruction-inheritance-and-migration),
  separately from runtime installation or synchronization authority.
- Select the already installed `power-platform-demo-builder` **0.2.1**
  Python environment (Python 3.11+). Missing/incompatible tooling is reported,
  never silently installed.
- Select the framework's canonical accepted requirements contract. Wizard
  answers are proposals, not automatically accepted contracts or live evidence.
- For synchronization, explicitly select the existing fourth document
  (`BUILD.md` by default) and opt in. Missing Spec Kit is read-only
  `not-applicable`; partial planning is an explicit error.

## Operator path

### Native quality, replay and Git inspection (Q33)

With the selected installed Q33 candidate, keep `-Action browser` and
`-BrowserConfigPath`. Optional `quality` config specifies bounded viewports,
selected DOM/iframe surfaces, scroll/dimension thresholds and exact native
table/record/form context. It detects clipping, overlap, redundant visible
headers, missing accessible names, excessive scrolling and responsive/resource
dimensions, with screenshots. These are scoped heuristics, not accessibility
certification. Existing metadata/form bindings remain required. `navigation`
scenarios verify actual same-origin anchor destinations/rendered native identity
with GET navigation, not arbitrary scripts or popup policy. Browser remains
read-only by default and no second driver is introduced.

Use `-Action scenario -ScenarioOperation capture -AcceptScenario` only after a
completed fictional rehearsal. `-ScenarioOperation replay` is the default:
compare accepted IDs/values without repeating persisted transactions, optionally
adding existing fixture browser checks. Drift, accepted-record changes and
duplicate seeding are blocked. `reset` is never implicit; `-AuthorizationPath`
must bind accepted synthetic-only selected-record values, exact receipt/current
snapshot digests and expiry. It backs up current state, preserves unselected
records/counters and cannot create/delete rows or reset live data.

`-Action git-review -GitReviewManifestPath <external-json>` forwards the existing
bounded local Git inspector. Manifest `schema_version:"1.0"` selects at most
ten `pull_requests:[{id,base,head,depends_on,supersedes,work_id}]` with full local
commit hashes and optional `task_workspaces:[]` canonical runtime roots.
It detects overlapping paths, missing exact ancestry, equivalent patches/work
identities, unique superseded/merge work, dirty/ahead state and writer conflicts.
Expired running leases/uncertain effects retain ownership. Recovery refs are
preserved; cached observations are not remote freshness or process absence.
No network, merge, close, push or document sync occurs. Git inspection can
precede Spec Kit; replay requires its existing completed runtime. Both invoke
fresh checks on reentry and add no mandatory planning or administrative stage.

Q37 optionally discovers hosted PR branch dependencies through the installed
Automation CLI's same `git-review` command with explicit
`--repository owner/repository --pull-request <number>` (repeat at most ten).
It reuses existing `gh` authentication and local Git inspection; no sign-in,
Git fetch, merge, close or supersession inference occurs. Matching selected
same-repository base/head observations supply structural dependencies, not work
allocation approval. Unselected/cross-repository prerequisites and missing local
objects remain unverified; partial evidence returns exit 3. The Starter
`GitReviewManifestPath` interface remains offline. See
[installation and capability boundaries](intelligent-wizard-getting-started.md).

### Agent behavioral testing (Q32)

With the selected installed Q32 candidate, use `-Action agent-test`,
`-AgentSuitePath` and `-AgentConfigPath` for external behavioral scenarios and
versioned instructions. This forwards Automation `agent-test`, not another
driver or instruction-syntax checker. Optional `-AgentBaselinePath` compares
results across versions. `-RepairAgentFixture` selects at most one explicitly
accepted hash-bound local fictional instruction correction and retests the suite.
It never edits or publishes an actual agent. Scenario prompts/data stay external.

Tests can precede Spec Kit because they do not build an application or generate
planning documents. Live conversations are not inherently read-only: tools may
execute. `-AuthorizationPath` must bind the exact suite/config, target, expiry
and approved nonproduction agent-side effects; actual security controls remain.
Missing tool/knowledge/escalation telemetry is unverified, never a passing
negative assertion. Use supported Direct Line or normalized enriched verifier
observations; no implicit authentication, token persistence or maker-portal
automation. Existing Q29 Playwright is a separate rendered diagnostic surface.

The same runtime retains `agent-tests` journals and versioned results. Handoff
reentry always invokes the runtime; completed run evidence is explicitly cached
there. Use a distinct external runtime for an intentionally fresh run, not to
evade an uncertain-effect hold. Tests never complete canonical native acceptance.

### Adaptive discovery (Q31)

When the selected installed runtime provides Q31, prefer `-Action discover`
before repeating intake. Use `-EntryPath build|enhance|repair` when intent is
not already known, and optional `-Fidelity single-operator-demonstration`,
`multi-persona-demonstration` or `production-oriented`. Default single-operator
fidelity does not add production persona tests or relax actual security.
Read-only discovery and accepted-requirement `feedback` can run before Spec Kit
exists, including partial local projects; neither writes application source or
Dataverse. They never generate planning documents or enable synchronization.

Use the existing accepted `-ContractPath` to initialize discovery, or resume the
canonical runtime. Selected read roots/scoped `-SnapshotPath` inventory supply
facts; absence/unknown and source/live evidence stay distinct. New unfinished
intake uses installed `init`/`wizard next`; discovery does not accept proposals.

After required affected planning, `-Action deliver` forwards one existing slice,
with optional `-RequirementId`. Select `-WorkerConfigPath` on POSIX or a compatible
installed Windows owned-Job runtime, or
`-RecipePath -RehearseSlice` for explicit fictional execution. Live recipes
instead require existing Q30 `-AuthorizationPath`/`-TenantId` and retain its
resource-only nonproduction limits. Optional `-BrowserConfigPath` provides
read-only rendered inspection. No command, recipe or fidelity grants authority.

Inspect the early slice, then `-Action feedback -FeedbackPath ...` supplies
accepted requirement/evidence arrays in schema `1.0`. It cannot change authority
or architecture, rewrite evidence, release writers or reset journals. Existing
task reconciliation retains unrelated completions and stable GUIDs. Resume the
same runtime; synchronize affected documentation separately afterward.
The legacy terminal questionnaire and bootstrap ordering are unchanged.

Run from the starter checkout, replacing these example consumer paths:

```powershell
pwsh .\scripts\bootstrap\09-framework-handoff.ps1 `
  -ProjectRoot C:\Pilot\project -RuntimeWorkspace C:\Pilot\runtime `
  -ScenarioSlug connected-journey -ContractPath C:\Pilot\inputs\contract.json `
  -PythonExecutable C:\Tools\framework\Scripts\python.exe `
  -Action start -EnableSpecKitSync
```

`start` assesses requirements with the installed framework. Optional
`-AdoptionPath` adopts existing work, `-DeliveryContextPath` selects pinned
lessons, and `-RecipePath` compiles the selected recipe. The framework remains
responsible for validation, aliases, canonical `tasks.json`, dependency
coordination and synchronization transactions.

On an existing adoption, an explicitly changed delivery JSON is validated and
applied through canonical `spec-kit delivery` before synchronization. Identical
delivery does not add a delivery write, and disabled synchronization stays
disabled. Wizard goal/timeframe text is not automatically converted into an
accepted ISO deadline or evidence assertion; supply the canonical JSON explicitly.

After planning, wizard intake can explicitly invoke the same entry point with
`-AcceptedContractPath`, `-FrameworkRuntimeWorkspace`,
`-FrameworkPythonExecutable` and optional `-EnableFrameworkSpecKitSync`.
It preserves accepted logical table names and relationship intent, recommends
standard-table reuse, and records accepted input hashes. It does not verify
live table availability, approve semantic field decisions or provision a
solution.

A single accepted custom-table namespace also guides the publisher-prefix
recommendation. This preserves `ppd_` identities rather than proposing a
different prefix; it does not prove that the publisher already exists.
Multiple namespaces and existing/new publisher selection require explicit
planning and environment verification.

When adopting an independent contract into already generated planning, compare
the actual solution unique name and publisher prefix in spec/plan with the
selected canonical table namespaces. Preserve conflicting human decisions and
resolve them explicitly before custom payloads/build; document synchronization
alone does not establish full architecture compatibility. The memory adapter
does not model publisher/solution metadata, so rehearsal cannot verify their
real IDs or solution membership. A generated recommendation accepted by the
operator is not the same as a name mentioned only in a free-text environment
answer. Source-only existing-work adoption does not prove tenant existence.

Detailed modes must match accepted table identities and use the exact compact
accepted relationship JSON in both relationship fields (`none` for an empty
selection). Free-text contradictions are rejected before planning writes,
not silently substituted for accepted dependency decisions.

Demo Builder must retain every accepted table exactly once. Subset or duplicate
selections fail before planning writes. Both relationship cardinalities require
accepted endpoints, explicit business meaning and accepted owner evidence.
One-to-many requires the child lookup; native many-to-many prohibits that lookup.
An explicit junction remains separate one-to-many relationships, not an inferred
change to accepted architecture.

Use the same project/runtime/scenario/interpreter parameters with `-Action`:

| Action | Meaning |
| --- | --- |
| `preview`, `sync` | Existing H008 projections and independent conflict holds |
| `disable`, `enable` | Explicit persistent synchronization selection |
| `rehearse` | Synthetic execution; optional explicitly fixture-marked recipe/snapshot |
| `status` | Read-only recorded status and current-input applicability |
| `worker` | Explicit existing configuration on POSIX or an installed compatible Windows owned-Job runtime; observed ownership is still required |
| `browser` | Optional installed Playwright diagnostics with `-BrowserConfigPath`; Windows/POSIX, fresh read-only observations |
| `deploy` | Explicit installed Q30 delivery profile with `-AuthorizationPath` and `-TenantId`; nonproduction exact-resource publication and rendered verification |

### Playwright diagnostics (Q29)

After accepted planning and runtime initialization, use the same arguments with
`-Action browser -BrowserConfigPath C:\Pilot\browser.json`. The existing handoff
calls installed `demo-builder browser diagnose`; it never installs dependencies
or reuses cached browser success. Evidence stays under the external runtime's
`browser-diagnostics/<config-hash>/`, not in Starter or a second queue.
Select the Automation candidate containing Q29 and its optional `browser` extra;
the version number alone does not establish that capability. Use its existing
`browser setup` / explicit `browser setup --install` when dependencies are absent.
The installed runtime's acceptance-context guide defines the exact target GUIDs,
record guards, application-owned paths and bounded read-only scenario format.
An approved loopback CDP session or explicit human Microsoft sign-in supplies
authentication; credentials/MFA are never automated or persisted.

Starter's action is diagnostics only. Separately authorized repairs use the
same runtime's `browser diagnose --repair-workspace ... --authorization ...
--tenant ...` and existing conditional development journal/publication gates.
Synthetic Chromium success is not intended-user tenant acceptance. Native
business writes still require the independent `accept` adapter and exact effects.
No discovery question or bootstrap stage is added.

### Targeted delivery (Q30)

After accepted planning, adoption and compilation of the smallest functional
slice, use the same project/runtime/scenario arguments with
`-Action deploy -AuthorizationPath C:\Pilot\authority.json -TenantId <tenant-guid>`.
This forwards to the installed Automation runtime's existing `apply
--development --credential azure-cli`; it does not generate authority, select
another target or reuse cached deployment success. An already authorized API
identity and the selected browser's independently observed user remain distinct.

The authority must explicitly select a nonproduction `development_profile`
with Q30 `delivery` settings. Its runtime acceptance-context guide defines
the exact browser form/resource bindings, protected IDs, verified backups,
foreign-draft ownership, published readback and source mappings.
Fresh diagnostics precedes guarded source/note reconciliation. Read-only success
does not claim native saves. Newer edits and conflicting writers are preserved.
No broad publication, production deployment, schema recreation, new planning
dossier or bootstrap stage is introduced. Unsupported form-only publication
remains in the existing separately authorized table-publication workflow.

### One read-only operational status

Use the same explicit project/runtime/scenario/interpreter arguments with
`-Action status`. `task_summary` reads the canonical `tasks.json` through
the installed coordinator and reports:

- Completed, running, blocked and pending active-task counts, plus coordinator
  eligible IDs. Pending includes ready tasks waiting on dependencies/resources.
- Native task IDs, owners/leases, latest retained event timestamps, unmet
  prerequisites, recorded blockers and each task's next action.
- Canonical task-state digest, stored update time and observation time.
  Missing retained event times are null, not invented.

Eligibility uses canonical `ready_tasks` on a copy, including external/retired
ownership and resource holds. It is not a second queue or worker selection
engine: configured task kinds, verifier capability, authority, process guards
and retry/run limits still determine whether a worker may launch.

`projection_only: true` means expired-lease normalization is view-only.
`stored_status` and `lease_reconciliation_required` distinguish it from
persisted state. With the current coordinator, an expired owner stays `running`
and ineligible, while `lease_reconciliation_required` is true. The flag also
supports older coordinators that project expiry as a status transition. Neither
case releases the stored owner or process/resource fences.
Status never claims tasks, renews/expires stored leases,
dispatches, re-enables synchronization or writes journals/receipts.

Handoff `recorded_status`/`recorded_exit_code` describe a prior command receipt,
not total project completion. Stale source/input evidence remains stale even
when the current task projection shows progress. A missing canonical store is
explicitly unavailable with null counts; an established receipt then reports
blocked/exit 2. Malformed records fail with a diagnostic, not empty success.

For recovery, preserve the original roots, IDs, owner and document selection.
Resolve an active/orphan executor before dispatch; inspect recorded blockers
and continue independent eligible tasks only through the existing scoped
coordinator/worker. Do not clear state or locks to make the report green.
Transient launches retry at most three times; deterministic unchanged errors
do not retry. Worker repairs use configured attempt/task/time budgets and
pass prior failure diagnostics to the next attempt.

There is no installed reboot/startup controller in this integration. Native
earlier Windows supervised-worker/restart acceptance was not performed;
no host restart, service or scheduler installation is part of Status.
POSIX subprocess recovery is separate from machine-reboot persistence.

An ordinary `start` replay does not re-enable disabled synchronization.
Completed, hash-unchanged replay writes neither documents nor a new receipt.
Changed inputs or canonical records invalidate cached completion. A
deterministic unchanged failure is retained; changed blockers permit resume.
An unchanged `spec-kit sync` document-conflict hold also returns its retained
exit 3 without rewriting documents, journals or adapter history. Changed inputs
resume synchronization and independent updates; other incomplete steps remain
retryable rather than being cached as document conflicts.
Interrupted work is reconciled by existing canonical tasks/journals, not copied
into a second executable backlog.

Apply the canonical [authorization and execution policy](policies/authorization-and-execution.md)
when deciding whether work can continue: H IDs track outcomes, not permanent
component ownership; registration and narrative documentation alone do not block
independently authorized work absent real authority, enforced policy or writer
conflicts. Preserve historical H008/H009/H010. Before writer release, inspect
active process/session, latest durable checkpoint and actual resource/in-flight
write evidence. Lease expiry alone is insufficient; recover before restart,
bound repairs and advance independent dependency-ready work. These are operator
obligations, not a claim that this adapter implements a new fencing or automatic
lease-reclamation mechanism. Runtime changes are separately reviewed.

If the adapter terminates after canonical adoption but before acknowledging the
command, resume the same accepted inputs/project/runtime. The existing document
selection and owner claim remain authoritative; replay does not reclaim them or
duplicate task identities. Resolve an active owner or uncertain native operation
before retrying. Interrupted Git operations belong to the selected repository's
normal recovery process, not automatic reset/abort by this adapter.

## Hosts, recovery and acceptance

Native Windows supports the PowerShell guided path and requires neither Git
in the consumer project nor WSL. Native Windows worker supervision requires
installed owned-Job v1.0 capability
and actual launch ownership/recovery evidence; capability discovery alone is
not process ownership. Missing/failed Job assignment blocks the affected worker.
Linux/macOS/explicit WSL can use the framework's existing worker interface;
host availability alone does not prove the package is installed. Never start
an unattended scheduler merely because worker support exists.
Use `12-check-wizard-capabilities.ps1 -RequireWindowsWorker` with the selected
Python interpreter before a Windows worker. Actual runtime launch must prove
owned Job assignment, direct process/child identity and prior checkpoint/resource
reconciliation. Lease expiry alone and a WSL interop child are not ownership
proof. Windows `guard_fds` batch coordination remains unsupported/POSIX-only.

The installed Python CLI subprocess uses explicit UTF-8 input/output settings,
including on Windows consoles configured for a legacy encoding. Unicode paths,
requirement text and previews must not be rewritten into ASCII to avoid failures.
The settings are child-process-local, not a system or console-policy change.

The tested POSIX worker runs bounded, explicitly configured subprocesses. It
provides checkpoints, lease checks and orphan exclusion; it is not an OS sandbox.
An explicit WSL worker is the practical supported option when native supervision
is unavailable. The adapter never installs WSL/PowerShell/packages or enables
startup services. Machine reboot and VS Code-close continuation are not proven
by process-restart tests; no persistent scheduler is supplied by this handoff.

`starter-handoff-status.json` is a derived receipt containing timestamps,
source revision, input hashes, command results, bounded retry counts and the
next action. Canonical tasks/journals remain authoritative. Receipts use New
York offsets where IANA timezone data exists, otherwise explicitly UTC rather
than an incorrectly labelled local time. Source revision unavailability is
reported, not treated as verified source.

Only transient process-launch failures retry (at most three attempts).
Authorization failures are not retried; uncertain timeouts require canonical
record reconciliation. Ownership locks and human edits are never bypassed.
Status marks stale completion rather than promoting old receipts to current
acceptance.

Synthetic rehearsal is not package, deployment, inspection or UI acceptance.
Live Dataverse, new-solution provisioning and production controls require
separate verified permissions/evidence; this handoff grants none.

Native/browser acceptance also requires the canonical policy's
[six safety obligations](policies/authorization-and-execution.md#native-application-safety-and-browser-acceptance).
The actual browser principal must be observed independently of API-admin or
session-declared identity. Validate publication blast radius, unrelated drafts,
record readback changes, restriction classification and intended app/user form
eligibility. Recover independent browser process/checkpoint/resource evidence
before resume and repeat principal preflight. This Starter adapter does not
implement those Automation runtime capabilities or install a browser driver;
missing native support is partial, not acceptance. No native pilot is claimed.

## Verification

`scripts/ci/test_framework_handoff.py` includes dependency-independent boundary
checks and installed-runtime integration checks. Delegation-only boundary cases
use explicit test doubles for optional runtime imports; they retain on-disk
handoff history and do not claim installed-runtime guards or live acceptance.
Select the installed framework
interpreter and set `STARTER_FRAMEWORK_FIXTURE` to an independent generic
connected-journey fixture to run integration. Without both, integration is
explicitly skipped, not claimed as verified by hosted CI.

Native wizard tests cover custom mappings, standard reuse, accepted identities
and relationship rejection before writes. Installed integration checks cover
new/existing/no-Git projects, opt-out, disabled replay, conflict preservation,
interruption, ownership locks and separate stale-evidence stages.
