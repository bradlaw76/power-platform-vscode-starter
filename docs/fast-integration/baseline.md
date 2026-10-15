# FAST-000 Baseline and Recovery Evidence

**Instruction:** FAST-IMPLEMENTATION-001  
**Status:** Complete  
**Evidence date:** 2026-10-15  
**Repository:** `bradlaw76/power-platform-vscode-starter`

## Baseline identity

| Item | Evidence |
| --- | --- |
| Default branch | `main` |
| Source branch before preservation | `feature/dataverse-form-formatter-v1` |
| FAST feature branch | `feature/fast-accelerator-catalog` |
| Baseline commit | `17bebe3fb2322c2ad07c05dec8ef0c64dba6df28` |
| Preservation commit | `Checkpoint worktree before FAST implementation` |
| Remote backup branch | `backup/pre-fast-20261015` |
| Annotated rollback tag | `pre-fast-20261015` |
| Remote repository | `https://github.com/bradlaw76/power-platform-vscode-starter` |

The source branch contained tracked and untracked work for form formatting,
Choice presentation, Power Apps grid support, and FAST instruction
registration. The operator explicitly approved preserving every current change
in one commit before FAST planning began. No files were discarded, reset, or
overwritten.

## GitHub verification

GitHub returned the following refs:

```text
refs/heads/backup/pre-fast-20261015
  17bebe3fb2322c2ad07c05dec8ef0c64dba6df28

refs/heads/feature/fast-accelerator-catalog
  17bebe3fb2322c2ad07c05dec8ef0c64dba6df28

refs/tags/pre-fast-20261015
  annotated tag object 7f4e66d83de55431cd90cf3fac0d212d63da2979
  target commit 17bebe3fb2322c2ad07c05dec8ef0c64dba6df28
```

The original source branch,
`feature/dataverse-form-formatter-v1`, was also pushed at the baseline SHA.

## Tool evidence

| Tool | Version |
| --- | --- |
| PowerShell | 7.6.7 |
| Git | 2.55.0.windows.5 |
| GitHub CLI | 2.88.1 |
| Azure CLI | 2.84.0 |
| Power Platform CLI | 2.12.2 |
| Node.js | 22.23.2 |
| npm | 10.9.8 |

No Dataverse environment was accessed or modified during FAST-000 or FAST-001.

## Baseline validation

The aggregate command was attempted first:

```powershell
pwsh -NoProfile -NonInteractive -File .\run-quality.ps1
```

It exited with code `1` after 4.07 seconds because the baseline file does not
parse at line 78:

```text
Variable reference is not valid. ':' was not followed by a valid variable name
character. Consider using ${} to delimit the name.
```

The failing expression is the existing `$_:` interpolation in the standalone
result summary. This pre-existing defect was recorded without changing the
baseline. The same stages were then run independently.

| Stage | Result | Evidence |
| --- | --- | --- |
| Markdown lint | PASS | 78 files, 0 errors |
| PowerShell parsing | FAIL | 68 files; only `run-quality.ps1:78` failed |
| PSScriptAnalyzer 1.24.0 | PASS | 0 findings |
| JSON/schema validation | PASS | 40 JSON documents parsed; 18 payloads matched schemas |
| Contract integrity | PASS | Existing profile and contract checks passed |
| Standalone CI scripts | PARTIAL | 22 passed, 1 failed |
| Pester 5.7.1 | PASS | 103 passed, 0 failed, 0 skipped |

The one standalone failure was:

```text
scripts/ci/test-script-smoke.ps1:24
Demo script wizard duration intake appears incomplete:
missing How long should the demo be, in minutes?.
```

The following required baseline behaviors passed:

- `test-wizard-modes.ps1`: Demo Builder, Advanced Builder, and Framework
  Acceptance all passed their shared artifact and mode-contract checks.
- `test-idempotency-and-export-stages.ps1`: baseline capture, stable IDs,
  unmanaged export/unpack, missing-component rejection, unrelated-component
  rejection, and no-import enforcement all passed.
- The working tree was clean after the independent test run.

These two failures are baseline defects and are not caused by FAST planning:

1. `run-quality.ps1` cannot parse at line 78.
2. `test-script-smoke.ps1` expects a demo-duration prompt that the current
   implementation does not contain.

## Restore rehearsal

A detached worktree was created from `pre-fast-20261015` outside the
repository. The rehearsal set `FAST_ENABLED=false` and invalid local HTTP/HTTPS
proxy endpoints to represent FAST-disabled and source-unreachable operation.

The restored worktree resolved to the exact baseline SHA and was clean. These
credential-free checks passed:

```powershell
pwsh -NoProfile -NonInteractive -File .\scripts\ci\test-wizard-modes.ps1
pwsh -NoProfile -NonInteractive -File .\scripts\ci\test-idempotency-and-export-stages.ps1
```

The temporary worktree was removed after the successful rehearsal. No managed
solution was uninstalled, no environment recovery was attempted, and no
Dataverse operation occurred.

## FAST-000 gate

- [x] Existing committed and uncommitted work preserved.
- [x] Exact baseline SHA recorded.
- [x] Remote backup branch verified through GitHub.
- [x] Annotated rollback tag verified through GitHub.
- [x] Isolated FAST feature branch created and pushed.
- [x] Baseline tests attempted and independently enumerated.
- [x] Pre-existing failures explicitly recorded.
- [x] Nonproduction restore rehearsal passed.
- [x] FAST disable and rollback strategy documented.

