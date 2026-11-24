# H009 - Wizard version and safe updates

Implements [issue #14](https://github.com/bradlaw76/power-platform-vscode-starter/issues/14)
from [existing design PR #15](https://github.com/bradlaw76/power-platform-vscode-starter/pull/15)
at `5098769d2786fbf366b8e2e8ecb7fd8912bd84ce`, reconciled against merged
main `57f54fbf6b2c88e391100c001ba0b3f8834e190b`. PR15 remains an intact
design proposal; the linked implementation PR is a separate source lane as
requested by issue14, not a replacement design or new H-number.

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
is performed. Mutation is restricted to isolated synthetic targets. Successful
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

The current executable ownership allowlist is intentionally **synthetic only**:
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

Recovery is a guarded compensation operation, **not an atomic filesystem
transaction**. It must compare current content to the updater's own recorded
bytes before restoring. Later human writes are held for manual reconciliation;
never delete the journal/lock to manufacture success or overwrite the user.
Keep the checkpoint and reported repair list. No automatic deletion of newly
added files is authorized; removal requires separate explicit human handling.

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

## Verification commands

```powershell
pwsh .\scripts\ci\test-wizard-update.ps1
Invoke-Pester .\scripts\ci\WizardUpdateEntryPoints.Tests.ps1 -Output Detailed
```

Python 3.10+ is optional for Check/Review/Update/Recover, not startup/Skip.
No package install is performed. Tests use isolated synthetic fixtures, no real
application, user skill folder, credentials or Dataverse environment. Required CI
runs the H009 engine on native Windows and Linux; Linux also runs the full existing
quality suite and real PowerShell entry-point tests. WSL is an additional actual
Linux engine check, not native-Windows path-security evidence.

See the linked implementation PR and issue #14 for exact tested commits,
U01-U19 mapping, demonstrations and remaining trust/release decisions.
