# Installed framework handoff (H008)

This is starter integration under issue #12, reusing Automation Framework H008
(issue #24, merged PR #26). It is not a second controller or implementation.
Spec Kit remains required before build. This optional continuation adds no
mandatory discovery question, build stage, installation or deployment.

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
| `worker` | Explicit existing configuration on a supported POSIX host only |

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
persisted state. Status never claims tasks, renews/expires stored leases,
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
Windows supervised workers and Windows restart recovery are not verified;
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
in the consumer project nor WSL. Native Windows worker supervision is rejected.
Linux/macOS/explicit WSL can use the framework's existing worker interface;
host availability alone does not prove the package is installed. Never start
an unattended scheduler merely because worker support exists.

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
checks and installed-runtime integration checks. Select the installed framework
interpreter and set `STARTER_FRAMEWORK_FIXTURE` to an independent generic
connected-journey fixture to run integration. Without both, integration is
explicitly skipped, not claimed as verified by hosted CI.

Native wizard tests cover custom mappings, standard reuse, accepted identities
and relationship rejection before writes. Installed integration checks cover
new/existing/no-Git projects, opt-out, disabled replay, conflict preservation,
interruption, ownership locks and separate stale-evidence stages.
