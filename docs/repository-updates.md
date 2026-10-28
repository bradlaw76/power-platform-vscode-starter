# Repository updates and work baselines

The update advisor answers **what changed**, **which capabilities may matter**,
and **which exact starter source a run used**. It never installs updates or
changes your app. A baseline is a source snapshot identifier, not a Git tag.

## Check for updates

Terminal intake runs a local check automatically, before discovery. It does not
add a business question or change build ordering. Chat startup uses the same
command after repository confirmation:

```powershell
pwsh .\scripts\bootstrap\check-repository-updates.ps1
```

By default this compares HEAD with cached metadata for `origin/main`. Cached
means **not network verified**, even if the status says `up-to-date`.
To explicitly contact the configured remote:

```powershell
pwsh .\scripts\bootstrap\check-repository-updates.ps1 -Fetch
# Or opt in at terminal wizard startup:
pwsh .\scripts\bootstrap\05-start-wizard.ps1 -FetchRepositoryUpdates
```

Fetch updates the private `refs/wizard-update-check/<remote>/<branch>` ref.
It does not change HEAD, the index, working files, tags, FETCH_HEAD or ordinary
remote-tracking refs. Subsequent local checks prefer this private cache; use
another explicit fetch to refresh it. The fallback, before the first advisor
fetch, is `refs/remotes/<remote>/<branch>`. A fetch failure never becomes cached
success. Git subprocesses time out after 20 seconds and disable credential
prompts; configure normal Git authentication separately if required.

For forks or another branch, explicitly choose the configured Git remote and
branch. A remote name is required, not an arbitrary URL:

```powershell
pwsh .\scripts\bootstrap\check-repository-updates.ps1 -Remote upstream -Branch main
```

The maintained [catalog](../repository-updates.json) supplies defaults and the
stable starter repository identity. If distributing a separately maintained
starter, review that identity and target configuration; never silently relabel
historical baselines. Remote URLs and source contents are not serialized.

Skip the terminal check with `-SkipRepositoryUpdateCheck`. Startup failures
warn and allow discovery; standalone inability to check exits nonzero. There
is no automatic scheduled workflow in this release.

## Interpret results

| Status | Meaning |
| --- | --- |
| `up-to-date` | Compared commits are identical; freshness is reported separately |
| `updates-available` | The comparison baseline is an ancestor of upstream |
| `local-ahead` | Upstream is already an ancestor of the comparison baseline |
| `diverged` | Both sides have commits; review upstream-side changes without discarding local work |
| `unrelated-history` | No shared ancestor in complete history; no adoption recommendation |
| `unable-to-check` | Missing refs, shallow/incomplete history, unavailable Git, timeout or fetch failure |

Categories describe affected capabilities, not verified fixes or guaranteed
breaking changes. The catalog groups runtime, governance, compatibility review,
optional features, documentation, experimental features and validation. Unknown
paths remain visible as `unclassified` / `review-needed`.

The advisor reads the local reviewed catalog; it never downloads or executes
remote catalog code. Maintainers must add rules when introducing capabilities.
One file may affect several capabilities. A report shows matching paths and
guidance so users can review why each recommendation appears.

## Match recommendations to a scenario

Without explicit selections, optional capabilities remain `unknown` /
`review-needed`; file existence never becomes approval. When scenario choices
are confirmed, optionally copy and edit
[the context example](../schemas/examples/repo-update-context.example.json) to
`specs/<slug>/repo-update-context.json`. Keep it aligned with approved planning:

```json
{
  "schemaVersion": "1.0",
  "scenarioSlug": "contoso-case-tracker",
  "enabledCapabilities": ["html-reports", "grid-controls"],
  "disabledCapabilities": ["native-reports", "fast"]
}
```

IDs must exist in the catalog and cannot appear in both lists. Universal
capabilities cannot be disabled. These selections only filter advice; they do
not enable modules, change planning, register reports or authorize deployment.
There is deliberately no heuristic parsing of prose to infer approvals.

```powershell
pwsh .\scripts\bootstrap\check-repository-updates.ps1 `
  -ScenarioSlug contoso-case-tracker `
  -BaselineCommit <full-commit-from-an-earlier-run> `
  -OutputFolder .\.wizard-metrics\updates\contoso-case-tracker
```

The optional output is `repository-update-report.json`; without an output folder,
the check only prints results. It does not overwrite any historical run baseline.

## Trace work to its source

Orchestrated runs record:

- Stable repository identity and full Git commit SHA.
- UTC capture time and a human-readable ID such as
  `ppvs-20261027T1928020000000Z-a1b2c3d4e5f6`.
- Runtime contract version, dirty status and a SHA-256 local-change fingerprint.

The fingerprint covers tracked working changes, staged changes and nonignored
untracked file contents. Ignored build output is excluded. It is a diagnostic
fingerprint, **not a backup, signed attestation or proof of reproducibility**.
Commit or otherwise preserve local changes separately if they must be reproduced.
Capture assumes files are not concurrently edited.

Both Preview and Apply include `repositoryBaseline` in existing run state and
JSON/Markdown summaries. Only Apply archives immutable, scenario/solution/
publisher/run-bound records under:

```text
.wizard-metrics/artifacts/manifest/<slug>/runs/<run-id>/repository-baseline.json
```

These are local ignored records, not Git tags. They remain intact when a new
run replaces the current summary. Resume reuses the original record and rejects
changed verified source identity. Legacy state without a baseline requires a
new run. Git-less workspaces remain explicitly `unverified`; their existing
workflows may continue/resume with warnings, without a reproducibility claim.
Direct individual build stages do not create an orchestrated run baseline.

No update recommendation bypasses planning, metadata checks, required approvals,
solution membership gates or FAST-dependent Apply restrictions.

## Share the version-control handoff

Use the [build-log run template](build-log.md#run-summary-template) to retain the
repository identity, full commit, timestamped baseline ID, dirty fingerprint and
update-check freshness with the scenario handoff. Source records and advisor
reports remain ignored local artifacts; do not stage `.wizard-metrics/` or
credentials just to share a baseline.

An advisor result is not approval to commit or publish. Review the intended
files and applicable validation, obtain commit approval and separate push
approval, then verify the pushed branch's remote SHA. Publishing a review
branch does not merge it into the default branch. The baseline records the
source used by a run; a later commit or push must not rewrite that historical
record. See [contribution guidance](../CONTRIBUTING.md).

## Validation checkpoint

```powershell
pwsh .\scripts\ci\test-repository-updates.ps1
```

Tests use temporary repositories and local remotes only. They do not authenticate
to Dataverse or fetch the public upstream. Review the report, decide which
updates to adopt, and validate them separately before a future build.
