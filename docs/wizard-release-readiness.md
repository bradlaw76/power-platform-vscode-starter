# H009 release trust, distribution and final acceptance

## Status and scope

This is the H009 implementation-aligned trust decision record and Q18 handoff,
preserving the H009-09 through H009-12 reconciliation. It records
reconciliation for issue #14 and existing implementation PR #16. It supplements,
but does not alter, design PR #15 at
`5098769d2786fbf366b8e2e8ecb7fd8912bd84ce`.
The original implementation is `480ba1563e54613350879a6c3efd441dfaa209ed`;
the preserved Q15 path correction is
`8673681b231d0e275354aa98fe1d2f53a06bf97b`.
Q17's Windows CRLF correction is
`c3536cd7e6940512d9d010d3c5cbc1d0488bc395`; its frozen candidate is
`e8eb06fa576a2dc26693a233f6ff0f2ea2687f95`.

**Candidate only. Official Apply, consumer-copy Apply and installed-skill Apply
remain disabled.** Neither this record nor the inventory grants publisher,
release, merge, installation or deployment authority. Distribution is not a
Dataverse operation. No release version, tag or signing key has been registered.

Final source IDs and exact-head CI evidence are appended to issue #14 and PR #16.
Earlier Q14/Q15 test evidence proves only those frozen source versions, not this
expanded package. Canonical **HANDOFF NOT WRITTEN - BLOCKED** is preserved; this
requested technical report is not a replacement for protected audit authority.

## Release-security decision record

### Identity, channels and immutable source

Proposed publisher namespace is `bradlaw76/power-platform-vscode-starter` on
`https://github.com`, observed repository ID `1263044026` and node ID
`R_kgDOS0iFug`. These observed IDs identify the source, not a person authorized
to publish. A separately approved policy must bind the publisher, repository
IDs, exact release workflow identity/digest and approved policy version.
Repository transfers, renames or resurrection require reapproval, not automatic
URL substitution.

- **Stable:** default and only currently implemented discovery channel.
  Future release version must be stable SemVer, with tag `v<version>` pointing
  to the exact reviewed full commit. Never infer a version from main, dates,
  profile, contract or component headers.
- **Development:** committed descriptor remains nullable. Startup accurately
  reports unknown distribution; local descriptors and Git tags are not proof.
- **Preview:** intentionally deferred. Future preview selection must be explicit,
  isolated from stable, SemVer-aware and independently attested. No current
  switch silently opts users into prereleases.
- Recommend immutable GitHub releases, after separate owner authorization for
  configuration and publication. A normal mutable tag is insufficient.
  Release notes and the GitHub latest/prerelease flags can remain mutable even
  for immutable releases; trust the attested identity, not those flags.

### Preferred provenance mechanism

Use supported GitHub immutable-release attestations plus GitHub Actions artifact
attestations, not a custom publisher RSA protocol. The existing RSA verifier is
for operator-controlled synthetic fixtures only.

The future verifier must fail closed unless **all** predicates hold:

1. The independently supplied approved policy matches repository numeric IDs,
   host, signer workflow path/digest, expected OIDC issuer and policy version.
2. The release attestation validates the selected immutable tag, exact commit
   and asset digest. There is no moving `latest` reference in an approval plan.
3. Artifact attestation validates the exact archive and inventory bytes, signer
   identity, source commit/ref and approved workflow digest. Prefer hosted
   builders; deny self-hosted builders unless separately approved.
4. The manifest validates structurally and semantically: stable version/tag,
   exact source identity, supported schema/policy versions, unique portable
   relative paths, regular files, bounded sizes, SHA-256 per file, Git modes,
   compatibility ranges, migration requirements and notes bound to the same
   attested bytes. Reject unknown fields and incomplete manifests.
5. Archive entries exactly equal the approved ownership inventory. Reject
   traversal, absolute paths, ADS, symlinks, junctions, hardlink entries,
   submodules, case aliases, extra files and unbounded extraction.
6. Revocation data is authenticated, current and independently trusted; neither
   release nor signer/policy is revoked. Recheck immediately before mutation.
7. Installed identity and ownership are independently verified, contract/profile
   are compatible, version strictly increases, and required migrations are
   separately approved. Same exact completed transaction is a read-only no-op;
   downgrade, incompatible and ambiguous installations are blocked.
8. The approved plan binds all input hashes, policy/revocation versions,
   installation topology, full target identity and original bytes/metadata.
   Revalidate under a lock, retain checkpoint/journal, verify scoped writes and
   preserve later human edits. Never execute release-provided validation hooks.

Supported verification commands were checked with the installed GitHub CLI.
The following is a **future operator template, not an implemented updater or
authority to fetch, publish or apply a release**:

```powershell
gh release verify <approved-tag> --repo bradlaw76/power-platform-vscode-starter --format json
gh release verify-asset <approved-tag> <archive> --repo bradlaw76/power-platform-vscode-starter --format json
gh attestation verify <archive> --repo bradlaw76/power-platform-vscode-starter `
  --signer-workflow <approved-workflow> --signer-digest <approved-workflow-commit> `
  --source-digest <approved-source-commit> --source-ref refs/tags/<approved-tag> `
  --deny-self-hosted-runners --format json
```

Independent semantic checks must inspect returned claims; exit zero alone does
not implement ownership, compatibility, revocation or target approval.
`gh release verify-asset` does not authenticate GitHub's automatically generated
source ZIP/tarballs; publish a separately built and attested archive instead.
Treat workflow-produced predicates as untrusted until constrained by the
verified certificate, verified timestamps, pinned repository IDs and exact
source/signer workflow identities. A persistent Verified commit badge does
not establish current release trust after key expiry/revocation.
Offline bundles cannot establish the repository's current name/ownership or
revocation freshness by themselves. Offline startup/Skip continues safely;
official Apply stays blocked when fresh policy/provenance cannot be verified.
No new workflow permissions, security settings or publisher credentials are
enabled in this package.

References:
[GitHub immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases),
[artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations),
[gh attestation verify](https://cli.github.com/manual/gh_attestation_verify),
[gh release verify](https://cli.github.com/manual/gh_release_verify).

### Authority registration, rotation and compromise

Recommend keyless GitHub OIDC/Sigstore verification with supported trusted roots,
not a committed long-lived private key. Publisher registration requires an
independently reviewed policy artifact, owner identity and authorized workflow;
the release cannot register itself. Owner must designate who can approve that
policy and its distribution.

Rotation changes policy version and approved workflow/root identities in a
separately reviewed change. Do not trust a new key merely because it signs its
own registration. If a custom key is later required, require independently
verified fingerprint, validity window, algorithm, purpose and explicit rotation
approval; never promote synthetic fixture keys.
For short-lived Sigstore certificates, verify validity at the authenticated
signing timestamp using the supported verifier. Expired now is not equivalent
to invalid at signing. Policy/revocation freshness remains a separate current
check; a historically valid certificate cannot bypass it.

Recommend authenticated revocation records listing policy/key/workflow/release
digests, issued/expiry times, reason and incident reference. Refresh within a
proposed maximum 24-hour validity window before Apply; stale/unavailable means
blocked Apply, not blocked startup. Owner must approve this freshness/SLA
policy before activation. Revocation stops new installs and raises an explicit
warning for affected installations. It never silently downgrades or removes
files; remediation is another reviewed forward update or guarded recovery.
Revocation distribution, policy pinning and the production verifier are
**design complete, implementation pending**, not working controls.

## Candidate distribution ownership

[ownership-policy.json](../distribution/ownership-policy.json) is an explicit,
versioned file allowlist. It is not a directory wildcard. Every entry requires
`explicit-review`; `automaticApply` and `publisherVerified` stay false.
The generated [candidate inventory](../distribution/candidate-inventory.json)
binds its source commit, canonical policy digest, exact paths, categories, Git
modes, byte counts and per-file SHA-256.

The generator reads **Git blobs at a full commit**, not working-tree bytes,
line-ending-converted checkout files, branch tips or installed user folders.
It requires the policy to match the committed source policy. Verification
recomputes the entire inventory, including totals and membership; JSON Schema
alone is insufficient. New files are excluded until explicitly added to policy.

| Category | Eligible source | Consumer disposition |
| --- | --- | --- |
| Core runtime | Explicit generic bootstrap scripts | Review identity/dependencies; never execute on distribution |
| Helpers | Explicit PowerShell/Python helpers | Review original ownership and hashes |
| Schemas/profiles | Explicit schemas, descriptors and policy | Review compatibility; no scenario payloads |
| Copilot assets | Two skills, references, prompt and instruction template | Human instruction edits always require explicit comparison |
| Claude assets | Two checked-in skill sources | User-installed path requires separate verified bundle receipt |
| Shared docs | Named guides and two generic requirement guides | Templates only; never replace a customer's README/instructions |
| Validation | Named tests, generic fixture metadata, lint config | Source tooling only; not a standalone dependency-complete package |

Excluded: all scenario `specs/` and `payloads/`, customer app/solution code,
credentials, `.env*`, tenant/environment settings, `.vscode/`, Git metadata,
workflows, workspaces, backups, telemetry, audit/operational records, build logs,
historical plans, binary assets, and unlisted files. Consumer-specific FOIA/GCC
traceability runners are not proposed distributable tests. Existing samples
remain untouched in the repository; exclusion is not deletion.

This is a **redistribution review inventory**, not a working install archive.
Some guides/tests link to intentionally excluded historical/scenario material.
Before real packaging, resolve dependency closure using generic templates or
explicitly documented optional source-checkout-only tests. Do not silently add
consumer samples or operational evidence to make a package complete.

The inventory and acceptance evidence cannot include themselves in their own
source-bound hash cycle. The committed inventory references a prior exact code/
policy commit; final acceptance also generates and verifies an external inventory
at the final implementation SHA. Neither is an official release.

### Installation topology matrix

| Topology | Current behavior | Future eligible updates | Never automatic |
| --- | --- | --- | --- |
| Full framework clone | Offline identity/Check; official Apply blocked | Verified owned runtime on reviewed branch; exact plan | Dirty paths, divergent branches, hooks/settings, scenario/application files |
| Existing consumer repo | Read-only classification; Apply blocked | Only original verified bundle receipt and approved subset | App code, specs/payloads, project README/instructions, credentials |
| Repo-shared Copilot skill | Classified separately; missing runtime explicit | Skill-source paths with verified receipt and manual instruction review | Other skills, `.github` settings/workflows, project instructions |
| User-installed Claude skill | Classified separately; runtime not inferred | Exact approved installed folder and generated policy-copy mapping | Home tree, unrelated skills, credentials or modified references |
| Partial/incompatible installation | Missing-runtime diagnostics; discovery/Skip continues | Reviewed bootstrap or migration, not an automatic repair | Invented installed version, missing dependency installation |
| Customized/local modifications | Locally modified/stale plan blocks fixture writes | Individually reconciled owned files and fresh exact approval | Discarding edits, forcing Git, automatic merges/removals |

Claude's installer-generated `references/authorization-and-execution.md` is
derived from the canonical policy. Its source hash is in this inventory, but
the installed destination needs its own receipt. Existing installer reruns are
not transactional H009 updates and cannot bypass that requirement.

### Reproducible inventory commands

Run after committing the source/policy. Use a new output filename; existing
files are never overwritten.

```powershell
$source = git rev-parse HEAD
python -B .\scripts\bootstrap\helpers\wizard_distribution.py `
  --root . --commit $source --policy .\distribution\ownership-policy.json `
  --output <new-candidate-inventory.json>
python -B .\scripts\bootstrap\helpers\wizard_distribution.py `
  --root . --commit $source --policy .\distribution\ownership-policy.json `
  --verify <new-candidate-inventory.json>
pwsh .\scripts\ci\test-wizard-distribution.ps1
```

Exit 0 means candidate generated/verified; exit 2 means blocked. No network,
install, Git write, release operation or Apply path is invoked. Hashes prove
byte identity, not absence of malicious code or publisher approval.

## Security and ownership review

Direct source review covers the PR16 engine, wrappers, fixture tests, candidate
generator and original design. The requested delegated security review was
interrupted without a report; it is **not** claimed as an independent audit.
No confirmed exploitable production-update vulnerability was identified in
this bounded direct review. Official mutation remains unreachable by design.

| # | Severity | File | Lines | Vulnerability | Confidence |
|---|----------|------|-------|---------------|------------|
| - | - | - | - | No confirmed exploitable finding in the reviewed disabled-production scope | - |

Important limitations are not passed-off as implemented security guarantees:

- GitHub metadata and local descriptor claims are unverified. Online failure is
  exposed by `remoteMetadata.availability`; a top-level `unverified` value is
  not successful release verification.
- Fixture trust checks exact bytes with an independent pin or synthetic RSA
  key. They do not prove official repository/commit/package provenance.
- Mutation is limited to remote-free, single-commit, marked synthetic repos,
  on isolated fixture/update branches and synthetic helper filenames.
  Candidate inventory metadata does **not** expand this engine allowlist.
- Locks serialize cooperating updater/recovery processes. Revalidation detects
  tested later edits, but check-then-replace is not an OS-level atomic
  compare-and-swap against an adversarial same-user writer. Production support
  needs an approved exclusive-workspace/concurrency contract and OS validation.
- Backups/journals are local recovery evidence, not tamper-proof against an
  attacker already controlling the same account. Windows ACL/ADS preservation,
  hostile filesystem races and crash consistency under power loss are not
  established by the fixture campaign. No transactional guarantee is claimed.
- Recovery preserves bytes, tested mode/owner/group/mtime boundaries and later
  edits. New payload files require manual removal; recovery can remain blocked.
  Stale locks must not be deleted to manufacture success.

## Requirement-by-requirement reconciliation

Classifications below deliberately separate synthetic acceptance from a real
official release. Tests are named in `test_wizard_update.py`,
`WizardUpdateEntryPoints.Tests.ps1` and `test_wizard_distribution.py`.

| Requirement from issue/design/01-08 | Classification | Evidence or exact remaining work |
| --- | --- | --- |
| 01 distribution authority distinct from component/profile/contract | Implemented and verified | Nullable descriptor/schema; version entry-point tests |
| 01 stable channel, immutable source, trust architecture | Design complete, implementation pending | This decision record; production attestation adapter not implemented |
| 01 ownership, conflicts, backup/recovery, CLI/agent contract | Implemented and verified | Synthetic allowlist, U07-U19, shared wrapper; real bundle activation separate |
| 02 authoritative numbered distribution version | Blocked by release authorization | Owner must select first stable version; null is intentional |
| 02 validated descriptor and compatibility | Implemented and verified | JSON schema, U03/U04/U08; descriptor never asserts trust |
| 02 complete distribution inventory and hashes | Implemented and verified | Explicit candidate policy, Git-blob generator, inventory negative tests |
| 02 official repository/commit/files provenance | Design complete, implementation pending | Candidate hashes are not attestation verification |
| 02 immutable reviewed tag/publication | Blocked by release authorization | No official tag/release created |
| 02 release notes and migration renderer | Intentionally deferred | Synthetic envelope notes exist; no official history/migration renderer |
| 03 early version/status without interrupting project | Implemented and verified | Real VersionOnly/Status, missing-helper and Q15 relative-path tests |
| 03 verified installed/current/outdated identity | Design complete, implementation pending | Unknown/unverified real state; installed fixture receipt is synthetic only |
| 04 on-demand bounded official GitHub query | Implemented and verified | U05 fixed endpoint, no redirects/proxy/source transmission |
| 04 verified newer/current/incompatible comparison | Implemented and verified | U04 synthetic versions only; official release recognition pending |
| 04 offline/failure/rate limit safety | Implemented and verified | Startup offline; bounded child/request failure diagnostics, U01/U05 |
| 04 avoid repeated calls/cache | Intentionally deferred | No startup network; each explicit online Check performs one call, no persisted cache |
| 05 Review/Update/Skip parity and returning users | Implemented and verified | Same wrapper, entry-point tests and signed lifecycle |
| 05 independent interactive Copilot/Claude conversation acceptance | Implemented but not independently verified | Instruction parity/shared command tested; no actual two-client interactive run claimed |
| 05 exact user update consent, no application/Git/deployment authority | Implemented and verified | Plan digest required; fixture Apply no Git writes, U10/U11/U13 |
| 06 clone/downstream/copied/installed topology | Implemented and verified | U02, missing-runtime tests; conservative write policy for all real installs |
| 06 actual consumer-copy and installed-skill Apply | Intentionally deferred | Requires original ownership receipt, approved package and production verifier |
| 06 dirty tree, branch changes, nested Git, cooperating writers | Implemented and verified | U10/U13/U14/U18/U19; no real divergent-branch synchronization implemented |
| 06 exact file impact/backup/revalidation | Implemented and verified | U09-U11/U17; signed shared-command plan |
| 06 traversal, case aliases, ADS names, junction/symlink guard | Implemented and verified | U07/U18 native platform tests, inventory negative tests |
| 06 selective verified writes and guarded compensation | Implemented and verified | U11/U12/U15-U17; byte/metadata verification, no deletion |
| 06 adversarial filesystem writer/ACL/ADS/power-loss guarantee | Intentionally deferred | Not promised; production contract and native hardening required |
| 07 current/newer/incompatible/offline/untrusted/dirty | Implemented and verified | U01/U03-U10/U19 |
| 07 protected app/instruction files and nested repos | Implemented and verified | U07/U13/U18; inventory excludes scenarios, settings and evidence |
| 07 concurrent attempts, crash, recovery failure/later edits | Implemented and verified | U14-U17, actual process exit86 and retained checkpoints |
| 07 replay/idempotence and post-update installed state | Implemented and verified | Exact replay test, signed lifecycle current/already-applied and unchanged fingerprint |
| 07 missing runtime, Skip, Copilot/Claude parity | Implemented and verified | Real wrapper/Pester and signed lifecycle; no runtime installation |
| 07 Windows and Linux/regression acceptance | Implemented and verified | Earlier exact-head CI retained; expanded final exact-head run linked in PR16 |
| 07 no external environment mutation | Implemented and verified | Offline isolated fixtures; no tenant/PAC/deploy API invoked by updater |
| 08 documentation/commands/limitations/PR | Implemented and verified | Existing PR16, updated operations/migration/readiness docs; design15 intact |
| 08 independent security/merge/release acceptance | Blocked by release authorization | PR review and owner decisions still required; no release readiness inferred |

## Acceptance and final owner checklist

The signed lifecycle test invokes the **actual PowerShell command used by both
skills**, with a fresh synthetic RSA keypair outside the source tree. It records
`H009-LIFECYCLE` JSON lines in test output:

1. Status reports unknown independently verified release; Check reads synthetic
   installed descriptor 1.0.0 and finds compatible synthetic 1.1.0.
2. Detached signature validates; exact Review lists two helper paths and hashes.
3. Update uses the exact explicitly approved plan digest and verifies payloads.
4. Check reports current with a fixture-only receipt; same Update reports
   already-applied with the complete byte/path/mtime fingerprint unchanged.
5. Recover restores the checkpoint, retaining backups and no automatic removals.
6. Another Update is deliberately interrupted after replacement (exit86);
   explicit Recover restores originals. Altered signed envelope blocks; Skip
   returns `continueDiscovery:true,writes:0`.

This is real terminal/shared-entry execution, not a mock of the wrapper, but
still synthetic trust and synthetic files. It does not update a real consumer
or prove a native interactive agent UI. Existing U01-U19 continue testing stale
plans, modified targets, incompatible manifests and cross-repository rejection.

Reproduce:

```powershell
pwsh .\scripts\ci\test-wizard-update.ps1
pwsh .\scripts\ci\test-wizard-distribution.ps1
Invoke-Pester .\scripts\ci\WizardUpdateEntryPoints.Tests.ps1 -Output Detailed
```

Final exact-commit output, generated inventory digest/category counts and hosted
Windows/Linux full quality outcomes belong in issue #14 / PR #16 closeout.
The workflow runs the new standalone inventory runner on Linux and Windows.
Unavailable external verification must be marked unverified, never passed.

Before any real stable release:

- Owner approves publisher authority, repository/workflow identities and a
  reviewed independent trust-policy distribution/rotation/revocation procedure.
- Implement and independently test production attestation, policy/revocation
  and installed-identity verification; do not activate by removing fixture guards.
- Approve inventory and packaging dependency closure, licensing and generic
  templates; approve topology-specific receipts/migration and local edit policy.
- Complete native filesystem/concurrency/ACL/ADS/power-loss risk disposition.
- Select stable SemVer, compatibility/migrations and immutable source/tag; obtain
  separate release/configuration authorization and actual attestation evidence.
- Complete independent PR/security review and fresh exact-head CI. Merge is a
  separate owner action; passing source CI never authorizes release/deployment.

Recommendation: **review this PR as disabled-production candidate functionality,
not an official self-updater or release-ready distribution.** Eventual merge
requires independent review and required CI; real Apply remains a later gated
implementation, even after source merge.

## Q18 final review and handoff

### Delivered and verified

- One nullable distribution descriptor, early offline VersionOnly/Status and
  source/contract/profile identity; development release remains unknown.
- One shared terminal/Copilot/Claude command for Check, Review, Update, Skip and
  Recover. Explicit bounded stable-only online metadata is unverified until
  approved publisher policy and production verification exist.
- Exact preview, independent fixture pin or detached RSA verification,
  explicit plan-digest consent, strict synthetic ownership and guarded
  checkpoint/journal compensation. Actual installations cannot become writable
  merely by using a fixture flag or candidate inventory.
- Q15 preserves PowerShell-relative runtime paths; Q17 preserves normal Windows
  checkout conversion without trusting executable Git configuration.
- Q17's [source-specific acceptance](https://github.com/bradlaw76/power-platform-vscode-starter/pull/16#issuecomment-7118622588)
  records all twelve bounded lifecycle scenarios. Actual post-write validation
  failure, recovery conflict hold, explicit reconciliation, original bytes/
  metadata/Git identity and two retained verified backups were checked separately
  from process-interruption recovery and zero-write completed replay.

The [version/update operations guide](wizard-updates.md) owns commands and the
[supported-host matrix](wizard-updates.md#supported-host-and-verification-matrix).
[Installation guidance](skill-distribution.md#reviewed-candidate-installation)
distinguishes source evaluation, skill instructions and a complete runtime;
the existing force-copy installer is not transactional Update/Recover.

Runtime baseline `e8eb06fa576a2dc26693a233f6ff0f2ea2687f95` has successful
[Windows/Linux CI45300515892](https://github.com/bradlaw76/power-platform-vscode-starter/actions/runs/45300515892):
updater 23 passed/one platform skip and inventory 5 passed per OS, Windows entry
Pester 8/0/0 and Linux full Pester 112/0/0. Sixteen optional installed-framework
handoff skips and a non-failing checkout-action runtime deprecation annotation
remain explicit. Q18 changes documentation and its pinned candidate inventory,
not the runtime, schema, profile, skills or test implementation. Final exact-head
CI and source identifiers are recorded in the existing issue/PR closeout.

### Review disposition and one progress ledger

| Record | Q18 disposition |
| --- | --- |
| Implementation PR16 | Sole consolidated source implementation; open for independent exact-head review; do not merge in this assignment |
| Design PR15 | Separate draft design at `5098769d2786fbf366b8e2e8ecb7fd8912bd84ce`; preserve until owner approves disposition |
| Main | `57f54fbf6b2c88e391100c001ba0b3f8834e190b` at reconciliation; no merge or automatic synchronization |
| Existing external H009_IMPLEMENTATION_REPORT.md | Single durable campaign progress ledger, current summary plus preserved source-specific Q14-Q18 history |
| Q16/Q17 external reports and logs | Immutable evidence inputs linked by that ledger, not competing current-status ledgers |
| Issue14/PR16 comments | Sanitized final publication/evidence pointers; full project-shaped fixtures remain external |

No submitted PR review or inline review comment was present at Q18
reconciliation. Green CI is not reviewer approval. Earlier direct source review
is not an independent security audit; the interrupted delegated audit never
produced one. Canonical **HANDOFF NOT WRITTEN - BLOCKED** remains unchanged.

### Outstanding decisions and exact next actions

| Owner | Next action | Gate that remains closed |
| --- | --- | --- |
| Repository reviewer/maintainer | Review the final PR16 SHA, CI and requirement reconciliation; record findings and separately approve PR15 disposition | No merge is performed by Q18; no old review is promoted to current approval |
| Publisher/release authority | Record D01-D07 decisions: approved publisher/numeric source identity, proof profile, workflow/issuer/root policy, first SemVer/package, time/revocation freshness and channels | No invented key, version, authenticated publisher, release/tag or official available update |
| Distribution/architecture owner | Approve D08 dependency-complete package, licensing, per-topology ownership receipts, compatibility and migration ranges | Candidate source inventory is not an install bundle or overwrite permission |
| Authorized implementer and independent reviewer | Implement/test production provenance, installed identity, temporal/revocation verification, D09 anti-rollback state and native concurrency/filesystem risk handling | Do not activate production by removing fixture guards; synthetic signatures are not sufficient |
| Release/audit authority | Resolve D10 independent review/audit destination and obtain separate source-integration, packaging, release and activation approvals with fresh exact-head evidence | Source merge, official distribution, live deployment and unattended execution remain separate permissions |

An official downgrade policy is not the same as recovery of a known local
fixture checkpoint. Windows ACL/ADS preservation, hostile filesystem races,
power-loss/reboot durability and interactive multi-client acceptance remain
unverified. Unavailable evidence stays unavailable, not passed.

**Stop here when only these owner decisions remain.** No release/tag, official
update activation, persistent service or Dataverse operation is part of Q18.
