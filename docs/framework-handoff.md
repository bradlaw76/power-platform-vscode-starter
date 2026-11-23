# Installed framework handoff (H008)

This is starter integration under issue #12, reusing Automation Framework H008
(issue #24, merged PR #26). It is not a second controller or implementation.
Spec Kit remains required before build. This optional continuation adds no
mandatory discovery question, build stage, installation or deployment.

## Before starting

- Select an external consumer project and a separate external runtime folder.
  Neither may be inside either framework source tree or overlap the other.
- Complete the selected `specs/<slug>/spec.md`, `plan.md` and `tasks.md`.
  Preserve handwritten text and native task identifiers.
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

An ordinary `start` replay does not re-enable disabled synchronization.
Completed, hash-unchanged replay writes neither documents nor a new receipt.
Changed inputs or canonical records invalidate cached completion. A
deterministic unchanged failure is retained; changed blockers permit resume.
Interrupted work is reconciled by existing canonical tasks/journals, not copied
into a second executable backlog.

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
