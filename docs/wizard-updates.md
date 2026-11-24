# H009 - Wizard version and safe updates

For candidate file ownership, proposed GitHub attestation policy, topology
boundaries and the requirement-by-requirement reconciliation, see
[release readiness](wizard-release-readiness.md). Candidate inventories never
expand the fixture updater's allowlist or enable official Apply.

Implements [issue #14](https://github.com/bradlaw76/power-platform-vscode-starter/issues/14)
from [existing design PR #15](https://github.com/bradlaw76/power-platform-vscode-starter/pull/15)
at `5098769d2786fbf366b8e2e8ecb7fd8912bd84ce`, reconciled against merged
main `57f54fbf6b2c88e391100c001ba0b3f8834e190b`. PR15 remains an intact
design proposal; the linked implementation PR is a separate source lane as
requested by issue14, not a replacement design or new H-number.

At the Q18 handoff this remains an **unmerged source candidate**, not an official
release or an update already installed from main. See the
[final review and owner actions](wizard-release-readiness.md#q18-final-review-and-handoff).

## What is installed

Run from the **confirmed runtime clone**, not an application project:

```powershell
pwsh .\scripts\bootstrap\05-start-wizard.ps1 -VersionOnly
pwsh .\scripts\bootstrap\04-check-wizard-update.ps1 -Action Status
pwsh .\scripts\bootstrap\04-check-wizard-update.ps1 -Action Status -AsJson
```

Explicit relative `-RuntimeRoot` paths resolve from the current PowerShell
location, even when its process directory differs. An absolute script path can
also be invoked from a different caller directory: default runtime identity
comes from the script installation, not that caller. A copied runtime without
its own Git repository reports no source revision rather than borrowing one.
These path rules do not install missing runtime files or authorize updates.

Read-only update checks preserve Git's installed `core.autocrlf`, `core.eol`
and `core.safecrlf` scalar settings when inspecting checkout changes. A normal
Windows CRLF checkout is not a local customization. Repository-local overrides
still take precedence, and real content edits remain locally modified. The
checker reads only these validated conversion values through Git's configuration
builtin; ordinary Git inspection continues to exclude system/global executable
configuration and disables filesystem monitors. Invalid conversion settings are
reported as inspection failures rather than clean status.

Ordinary terminal startup prints the same banner before intake. It does not
add a discovery question, require Python/WSL, authenticate or access the network.
`-VersionOnly` returns without intake or telemetry. Expected development output:

```text
Installed wizard: release unknown - development checkout
Source: <full inspected revision> | Contract: 1.10.0 | Profile: 1.6
Update check: offline-unknown - No network check; official publisher policy unavailable.
Choices: Review changes | Update wizard | Skip for now (continue unchanged)
```

ASCII hyphen renders the requested "release unknown - development checkout"
message consistently in native terminals. A missing/malformed profile/descriptor
reports explicit diagnostics, not invented release data or blocked discovery.
`wizard.release.json` is the authoritative nullable distribution descriptor,
validated against `schemas/wizard-release.schema.json`. Profile, contract,
script and automation package versions are **not distribution versions**.
A descriptor alone, a Git tag, a checksum from the same feed or moving main
cannot verify an installed release.

## Shared choices for terminal, Copilot and Claude

Both shipped wizard skills and the prompt invoke
`scripts/bootstrap/04-check-wizard-update.ps1` in the confirmed runtime.
They must not implement independent pull/copy logic.

- **Review changes:** request the shared read-only exact file preview.
- **Update wizard:** request the same plan, review its digest, then explicitly
  approve that exact plan. An unavailable trust/ownership gate is a stop, not
  permission to invoke the old installer or manually copy over a conflict.
- **Skip for now:** `-Action Skip`; continue existing discovery unchanged.
  Skip is session-only, needs no Python and writes no preference or task record.

Missing helper/runtime in a copied Copilot or installed Claude skill means
**unavailable runtime**, not version zero or an installed distribution. Preserve
all human instruction edits. H009 reports application/skill/mixed topologies;
consumer and skill-only Apply are not enabled without approved original bundle
ownership. Existing `01-install-skills.ps1` remains a separate explicit installer,
not the transactional updater and not a way around conflicts.

For a returning user, confirm the runtime folder, read VersionOnly/Status, then
choose whether to inspect updates or continue unchanged:

```powershell
pwsh .\scripts\bootstrap\04-check-wizard-update.ps1 -Action Check -Offline -AsJson
pwsh .\scripts\bootstrap\04-check-wizard-update.ps1 -Action Skip -AsJson
```

Check needs Python; Skip does not. Review does not authorize Update, and choosing
Update is not approval for Git integration or release. At present no verified
official candidate can pass the live Apply gate: unknown/unverified metadata is
not an available official version. The complete Apply example below is only for
an independently prepared isolated fixture, never an existing installation.

## Local instruction inheritance and migration

This is an explicit **instruction-only local source adoption** through the
existing H009 transaction engine, not an official runtime/release update.
Official Apply, publisher trust and H010 consent are unchanged. Choose a
reviewed local runtime source; no network, executable upgrade, tenant operation,
Git commit/staging or project authorization is implied.

New terminal workspaces automatically receive the actual local AGENTS, Copilot,
canonical policy, shipped skills/prompt and queue guidance. Chat intake invokes:

```powershell
pwsh D:\ReviewedRuntime\scripts\bootstrap\05-start-wizard.ps1 `
  -WorkspaceRoot D:\CedarCivic -InitializeInstructionsOnly
```

Initialization needs no Python. Create-new writes cannot replace an existing
file. Existing or partial instructions, CLAUDE.md and custom instruction folders
are retained, not silently completed. Interrupted initial copying may leave a
partial bundle: use migration, never delete/reset it. Guidance is not installed
runtime compatibility or proof an agent loaded the policy. Missing referenced
runtime dependencies still require their separate compatibility review.

For an existing independent Git project on an identifiable branch, use the
same executing runtime's explicit instruction mode. Optional
`-PreviousInstructionRoot` must be a separately retained, reviewed *generic*
previous instruction source, not a copy of custom project instructions used to
force recognition. Review every diff, including stricter requirements. Unknown,
edited or ambiguous managed bodies are held; migrate those through a separately
reviewed customization reconciliation, not fabricated old-body evidence.

```powershell
$update = 'D:\ReviewedRuntime\scripts\bootstrap\04-check-wizard-update.ps1'
& $update -Action Review -RuntimeRoot D:\CedarCivic -InstructionMigration `
  -PreviousInstructionRoot D:\PreviousRuntime -PlanPath D:\Evidence\instructions.json -AsJson
# Reuse the saved plan's exact planSha256 after reviewing the proposed changes.
& $update -Action Update -RuntimeRoot D:\CedarCivic -InstructionMigration `
  -PreviousInstructionRoot D:\PreviousRuntime -PlanPath D:\Evidence\instructions.json `
  -ApprovedPlanSha256 '<reviewed planSha256>' -AsJson
```

Omit the previous-source option for missing or already current instruction
files. Preview records body/version classifications, source/previous hashes,
target metadata, diffs and an immutable sibling `.instructions` payload.
Surrounding customized bytes, accepted specifications, stricter local rules
and unrelated files are retained. Apply revalidates the entire target snapshot,
Git identity and payload; changed inputs or active/unreconciled writers block
the affected migration, not unrelated authorized work. Whole-workspace
snapshotting is deliberately conservative, not component-parallel migration.

Existing `.wizard-update` locks, staged bytes, backups and journal provide
recovery; no second updater or lease-expiration shortcut is introduced.
Use the returned transaction path:

```powershell
& $update -Action Recover -RuntimeRoot D:\CedarCivic -InstructionMigration `
  -TransactionPath '<transaction path>' -AsJson
# Optional compensation of newly created, still-identical instruction files:
& $update -Action Recover -RuntimeRoot D:\CedarCivic -InstructionMigration `
  -TransactionPath '<transaction path>' -RemoveCreatedInstructions `
  -ApprovedPlanSha256 '<original reviewed planSha256>' -AsJson
```

Recovery preserves later human edits; conflicts return `recovery-blocked`,
which is **not success**, even with exit zero. Compensation is guarded and
file-by-file, not an atomic filesystem/power-loss rollback. Default recovery
does not delete new files. After recovery, unchanged original inputs/plan can
resume without a new investigation. `instructionCompatibilityVerified` means
managed instruction integrity only; `runtimeUpdated` and `releaseVerified`
remain false. No mocked or synthetic case establishes tenant/native acceptance.
Filesystem evidence covers the existing engine's recorded metadata and
read-only guards, not full NTFS ACL/owner portability. Protected/custom filesystem
permissions require separate verification; do not infer it from byte integrity.

## Discovery and trust

Startup and default Check are offline. On-demand online discovery requires
explicit selection, uses a bounded request to the fixed official GitHub release
endpoint and never transmits source files, scenario names, tenant IDs, credentials
or requirements. Stable-only is the default; no preview channel or moving main
is used as update authority.

Outcomes distinguish offline/unknown, unverified metadata, locally modified,
incompatible, current, older and newer-compatible. Verified current/newer outcomes
in the test campaign use independently pinned **synthetic** metadata, not a
claim that an official release exists. The observed official release list is
empty. An unreachable/rate-limited host is unknown; an untrusted release cannot
be advertised as an available official update.

Offline fixture trust uses a separately supplied exact envelope SHA-256 pin
or an independently supplied RSA public key, detached signature and explicit
local OpenSSL executable. Optional RSA verification is operator-key verification,
**not official publisher policy** or embedded-key trust. No OpenSSL installation
is performed. Release/fixture mutation is restricted to isolated synthetic targets. Successful
fixture checks demonstrate integrity/transaction behavior only; they cannot
authorize a remote release or an update to an actual user installation.

**Official publisher policy is unavailable. Actual live Apply fails closed.**
Source implementation and fixture acceptance do not enable official distribution
or silently trust GitHub, a user-supplied checksum or a manifest's embedded key.
Before enabling that path, the release owner must separately establish publisher
identity, immutable source/tag and artifact attestation/signature verification,
distributable ownership inventory and release/version/publication authority.
No release version, tag or trust root is selected by this implementation.

The committed descriptor contains no containing-commit SHA. A generated external
source envelope/file index binds final immutable source and payload hashes and
must exclude itself/signature from the payload set to avoid self-reference.
No release-supplied validation/install hook is executed.

## Exact plan and recovery contract

The default release/fixture ownership allowlist remains **synthetic only**:
`scripts/bootstrap/helpers/update-fixture-*.py` and `update-fixture-*.json`.
No official runtime/skill bundle is inferred or silently enabled. Fixture mutation
requires an explicit matching root marker in an independent initial Git commit,
no remotes, an isolated `fixture/` or `update/` branch and no framework/consumer
identity markers. Actual framework clones, application repositories, user homes
and copied skills cannot opt into mutation by passing a fixture flag alone.

An actual fixture preview contains exact entries such as:

```json
{
  "path": "scripts/bootstrap/helpers/update-fixture-alpha.py",
  "class": "runtime-helper",
  "scope": "framework",
  "size": 24,
  "baselineSha256": "3fc9f0d1cd7fba5941162190b694ebe57f2f73de7c21551344cb41bef0ecfcc4",
  "sha256": "a16b77babaa3b0a9c02fce970ccb19b407213da3b81424b7ede39c6ef740f0b4"
}
```

For an independently prepared synthetic fixture only:

```powershell
$fixtureInputs = @{
    RuntimeRoot = '<isolated fixture root>'
    FixtureRoot = '<same isolated fixture root>'
    EnvelopePath = '<external exact envelope.json>'
    TrustedEnvelopeSha256 = '<independent SHA256 pin>'
    SourcePath = '<separate exact payload directory>'
    AsJson = $true
}
$command = '.\scripts\bootstrap\04-check-wizard-update.ps1'
& $command -Action Check @fixtureInputs
$plan = & $command -Action Review -PlanPath '<external plan.json>' @fixtureInputs |
    ConvertFrom-Json
& $command -Action Update -PlanPath '<external plan.json>' `
    -ApprovedPlanSha256 $plan.planSha256 @fixtureInputs
& $command -Action Recover -RuntimeRoot '<isolated fixture root>' `
    -FixtureRoot '<same isolated fixture root>' `
    -TransactionPath '<exact transaction returned by Update>' -AsJson
```

Review creates a plan file only when the explicit external `PlanPath` is given.
Default Review does not write a plan or mutate the target. An alternative to the
fixture pin is the complete `SignaturePath`, `TrustKeyPath`, `OpenSslPath` set;
OpenSSL must be an explicit absolute existing executable path. Operator RSA
verification still does not establish an approved official publisher policy.
`Check -Online` is the only network-capable command; supplying Online with
another action is rejected by the engine.

The shared engine separates read-only discovery/preview from opt-in mutation.
Plans enumerate exact changed paths and hashes; no Git pull/reset/force-push,
automatic branch switching, commit, push or Dataverse call occurs.

Apply requires exact approved plan identity and revalidates the target baseline,
source bytes and ownership under an exclusive lock. It preserves backups and a
durable per-file journal, stages only selected bytes, verifies final hashes and
reports blocked/partial states honestly. Plans never authorize extra paths or
removal. Protected application, Spec Kit, credential and instruction paths stay
outside the update set. Windows path aliases/reparse points and Linux symlinks
are tested separately, not inferred from each other.
Temporary payload staging is not Git staging: Apply neither stages nor commits
the reported `selectiveStagingPaths` in Git.

Recovery is a guarded compensation operation, **not an atomic filesystem
transaction**. It must compare current content to the updater's own recorded
bytes before restoring. Later human writes are held for manual reconciliation;
never delete the journal/lock to manufacture success or overwrite the user.
Keep the checkpoint and reported repair list. No automatic deletion of newly
added files is authorized; removal requires separate explicit human handling.

### Recovery results and rollback limits

| Result | Exit/status meaning | Required handling |
| --- | --- | --- |
| Missing exact Update approval | Nonzero PowerShell error | Review a fresh exact plan; never invent an approval digest |
| Validation or integrity failure | Engine exit2, status blocked | Preserve error, transaction, lock and original backups |
| Recovery conflict or manual removal needed | Exit0 can contain status recovery-blocked | Not restored; preserve later edits and reconcile only explicitly approved paths |
| Recovery complete | Exit0, status recovered | Verify reported conflicts/removals are empty and retain backups/evidence |
| Repeated completed fixture Update | Exit0, status already-applied | Exact unchanged replay; not another release or deployment |

Automation must check the JSON status, not exit0 alone. For an explicitly
authorized existing synthetic checkpoint:

```powershell
$recovery = & $command -Action Recover -RuntimeRoot '<isolated fixture root>' `
    -FixtureRoot '<same isolated fixture root>' `
    -TransactionPath '<exact existing transaction>' -AsJson | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $recovery.status -ne 'recovered') {
    throw 'Recovery incomplete. Preserve the checkpoint, lock, backups and later edits.'
}
```

Q17's actual post-replacement corruption probe returned exit2/blocked with an
interrupted journal. Recover held the unknown bytes; only after deliberate
fixture-operator reconciliation did Recover restore original bytes/metadata,
unchanged clean Git branch/HEAD and two verified backups, releasing the lock.
This tests post-write validation failure separately from the real exit86 process
interruption tests. Neither demonstrates reboot/power-loss durability.

Checkpoint compensation is not a trusted official-version downgrade. An
authenticated anti-rollback ledger, downgrade policy and production verifier
remain unimplemented owner gates. Never delete locks, rewrite receipts or run
the skill installer to make recovery appear complete.

For framework source updates, use an isolated reviewed feature branch/PR and
the exact path inventory, not `git add .` or an updater mutation of main.
Local preparation, verified local application, commit, push, merge and distributed
release are separate states. Staged/unstaged/untracked shadow files, nested repos,
branch mismatch, changed metadata or ambiguous topology block writes.

## Source release notes and adoption

H009 is an additive source feature, not a numbered distributed release.
No existing app table, architecture decision, native task ID, discovery answer
or build stage changes. The startup banner is new; tools parsing terminal text
should use the shared Status JSON instead. `-VersionOnly` is a new non-mutating
entry point. Existing discovery defaults and mandatory planning remain unchanged.

Adopt through the reviewed source PR and your normal non-force clone workflow;
never use a fixture envelope as an official release or copy the whole repository
over an application. Keep local instruction and skill edits for manual review.
Python 3.10+ enables optional on-demand engine actions; PowerShell 7 suffices for
startup/Status/Skip. No dependency package, service or scheduler is installed.
Consumers with copied runtime/skills need original ownership inventory before
Apply, not blanket permission inferred from a familiar filename.

## Supported host and verification matrix

Declared requirements are PowerShell 7 for the shared command and Python 3.10+
plus Git for on-demand engine actions. Requirements are not a claim that every
minor version or platform has been certified. The pinned Q17 runtime baseline is
`e8eb06fa576a2dc26693a233f6ff0f2ea2687f95`, with
[exact-head CI45300515892](https://github.com/bradlaw76/power-platform-vscode-starter/actions/runs/45300515892).
Q18 only changes documentation/inventory; final submitted-head checks are linked
from issue14/PR16.

| Host or installation | Actual verification | Supported boundary |
| --- | --- | --- |
| Native Windows hosted runner | Windows Server 2025, PowerShell 7.6.10, Python 3.12.10; updater 23 passed/one POSIX skip, inventory 5 passed, entry Pester 8/0/0 | Windows path/CRLF/junction and fixture recovery evidence, not Linux-derived proof |
| Hosted Linux | Ubuntu 26.04.1 LTS, PowerShell 7.6.10, Python 3.14.4; updater 23 passed/one Windows skip, inventory 5 passed, full Pester 112/0/0 | Real Linux command/metadata/symlink and shared-wrapper evidence |
| Local native Windows | Q17 real clone, dirty/no-Git copies and post-write failure/recovery; four gap cases plus one expanded copied-entry case passed | Actual persisted synthetic state; separate from official installation acceptance |
| Local Q18 tool inventory/smoke | PowerShell 7.7.0, Python 3.14.10, Git 2.56.1; VersionOnly and offline Check passed | Current smoke/tool versions, not retroactively assigned to earlier full test runs |
| WSL | Earlier source-specific engine run on a native Linux filesystem; optional | No fresh Q17/Q18 WSL wrapper certification; Windows absolute worktree metadata must not be shared with Linux Git |
| Full copied runtime without Git | Actual copied VersionOnly/Status plus offline Check/Skip passed; no invented source revision | Read-only discovery; no Git creation and no production Apply |
| Copilot/Claude skill-only installation | Routing/parity and real shared commands tested | Missing runtime explicit; no independent two-client interactive UI certification or installed-skill Apply |
| macOS, Windows PowerShell 5.1, declared Python minimum 3.10 | No fresh campaign for these combinations | No macOS/5.1 certification or Python 3.10 certification inferred from a declared minimum |

Startup/Status/Skip do not require Python, WSL or a new Git repository. Missing
Python blocks the selected engine action explicitly, not ordinary discovery.
Git-less runtime copies remain read-only. Source support is not live Dataverse,
official package/distribution, unattended scheduler or power-loss acceptance.

## Verification commands

```powershell
pwsh .\scripts\ci\test-wizard-update.ps1
Invoke-Pester .\scripts\ci\WizardUpdateEntryPoints.Tests.ps1 -Output Detailed
```

Python 3.10+ is required for Check/Review/Update/Recover; these on-demand features
are optional. Startup/Status/Skip need only the compatible PowerShell runtime.
No package install is performed. Tests use isolated synthetic fixtures, no real
application, user skill folder, credentials or Dataverse environment. Required CI
runs the H009 engine on native Windows and Linux; Linux also runs the full existing
quality suite and real PowerShell entry-point tests. WSL is an additional actual
Linux engine check, not native-Windows path-security evidence.

See the linked implementation PR and issue #14 for exact tested commits,
U01-U19 mapping, demonstrations and remaining trust/release decisions.
