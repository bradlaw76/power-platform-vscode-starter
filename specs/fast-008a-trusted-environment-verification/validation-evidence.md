# FAST-008A Validation Evidence

## Scope and baseline

- Branch: `feature/fast-accelerator-catalog`.
- Baseline: `0d1812b9acea61afa750883422d88807f48b4f1d` (FAST-007).
- All collection responses were synthetic and transported in process. No live
  GCC or other Dataverse environment was contacted. No existing stored target
  was selected automatically.
- Test certificates were ephemeral RSA keys held in memory; the CLI integration
  test wrote only a public certificate into its individually named temporary
  fixture, removed during test cleanup. No production key was provisioned.

## New verification acceptance

The acceptance script is
[`test-trusted-environment-verification.ps1`](../../scripts/ci/test-trusted-environment-verification.ps1).
Its examples are stored under [`samples/`](samples/).

| Application or condition | Expected result |
| --- | --- |
| Equipment maintenance, Fully Custom | `READY_FOR_APPROVAL`, recorded test only |
| Event registration, Fully Custom | `READY_FOR_APPROVAL`, recorded test only |
| Employee onboarding, Fully Custom | `READY_FOR_APPROVAL`, recorded test only |
| Library circulation, Hybrid with installed compatible module | `READY_FOR_APPROVAL`, recorded test only |
| Missing accelerator with an unresolved observed component owner | Blocked compatibility, plus missing-prerequisite findings |
| Incorrect installed version | Blocked decision change and compatibility findings |
| Stale evidence or expired certificate | Blocked evidence |
| Environment or tenant mismatch | Blocked decision change |
| Missing Global privileges, including Basic/RecordFilter depth | Blocked security |
| Inaccessible privilege metadata | Blocked evidence |
| Restricted managed customization | Blocked compatibility |
| Unknown managed properties or incomplete dependency graph | Blocked evidence |
| Expired/unavailable credentials | Blocked; explicit unavailable checks, no compatibility inference |
| Signature tampering, untrusted certificate, omitted/downgraded mandatory checks | Blocked evidence |
| Authenticated principal changes during collection | Blocked security |
| Column parent disallows customization or does not expose restrictions | Blocked compatibility or evidence |
| Unapproved architecture | Rejected before issuing any request |
| Cross-origin/query-changing/cyclic/over-limit pagination | Rejected; incomplete evidence cannot pass |
| Unselected package in the manifest | Not remotely queried or added as a prerequisite |
| Mock collection under default Authenticated policy | Blocked evidence; never live verified |

The suite additionally checks deterministic output for identical inputs,
collection time, responses and signing key; complete same-query pagination;
shared bounded throttling retries; read-only transport; no persisted tokens;
explicit CLI collection/readiness integration; and absence of authorization
records. Every report has `executionAuthorized: false`.

The final focused run passed **102 assertions**, or **104** with the two additional
persisted-output count checks enabled. Seven report/envelope pairs are included
in the review change set; this evidence does not establish publication status.
This includes a complete pinned
transitive dependency example, dependency-first ordering, and explicit rejection
when a signed envelope omits its required package-table or package-component
observations. The inherited FAST-007 readiness suite also passed its unchanged
**129 assertions** under explicitly labelled LocalPlanning diagnostics.

Sample signatures identify a disposable test signing authority. No matching
trust certificate is committed or provisioned. These are illustrative records,
not independently enrolled evidence and not approval records. Regenerating the
samples uses a new ephemeral certificate. Mock positives have
`evidenceTrust: recorded-test` and `verifiedForHumanReview: false`.

## Historical quality corrections

1. `run-quality.ps1`: delimit `${_}` in its summary interpolation; preserve the
   native Markdown-lint exit status; show actual status and caught JSON/contract
   errors; return failure if any stage fails. Pester aggregate `Result`, rather
   than only failed test count, also catches discovery/container failures.
   Focused subprocess tests isolate success and every failure category.
2. `test-script-smoke.ps1`: require the actual existing demo-timer prompt from
   stage 06. No production prompt, timer behavior or wizard intake changed.
   The focused Pester test and existing presenter/smoke suites cover the text.
3. Integrated review on 2026-10-23 exposed a time-dependent CLI test fixture:
   its certificate was valid only around the fixed 2026-10-19 simulation clock,
   but CLI collection correctly uses the current clock. CLI integration now
   creates a separate ephemeral certificate around its actual invocation time
   and checks the observed timestamp. Deterministic engine tests retain their
   fixed clock and historical certificate. Production expiry and trust checks
   are unchanged; a new integrated result is recorded in the review guide.

The OneDrive test-cleanup limitation is separate: synchronized temporary
directories may intermittently remain locked after assertions finish. This is
not an evidence-trust failure, parser defect or timer-contract failure. No broad
cleanup retry/refactoring was introduced.

## Regression results

| Gate | Result |
| --- | --- |
| New trusted verification acceptance | 102 assertions passed; 104 with persisted sample-count checks |
| Existing FAST-007 readiness | 129 assertions passed |
| Pester 5.7.1 | 121 passed, zero failed |
| Focused quality-runner regressions | 11 passed, including each stage and Pester container failures |
| Markdown lint | Zero errors |
| All PowerShell parsing | Passed |
| PSScriptAnalyzer 1.24.0 | Zero findings |
| JSON/schema checks after sample generation | 155 documents parsed; 20 payloads and 48 accelerator documents matched schemas |
| Contract integrity, docs and skill parity | Passed |
| Standalone coverage | All 35 checks exercised: JSON/contract plus 33 remaining suites |
| Final aggregate process | Exit 1 solely for the known OneDrive formatter cleanup lock |
| Hash-identical isolated formatter repeat | Passed, including cleanup; isolated copy removed |

In the final aggregate run, 32 of 33 remaining standalone suites passed.
Its verification suite passed the then-current 100 assertions; the final focused
repeat additionally covers inaccessible extension publisher metadata and checks
that all seven report/envelope pairs actually persist.
The formatter printed that all behavioral assertions passed, then its existing
cleanup at line 304 failed because another process held the generated artifact
directory. The unchanged test, runtime files, schema and profile were copied to
an individually named session directory outside OneDrive; SHA-256 equality of
each copy was checked before running. That repeat passed including cleanup.
The earlier full aggregate also passed formatter cleanup, demonstrating the
intermittent nature of the lock. Neither historical logical quality defect
remains. The aggregate now correctly reports a nonzero status for this actual
environmental cleanup failure rather than hiding it.

Existing FAST catalog/indexing/matching, environment preflight, disabled-mode,
build-planning, wizard modes/source control, schema/contract, preview
nonmutation, solution/publish isolation, grid, form, reporting/data and
idempotency/export regressions were included. Build-related tests use their
existing mocks; no real solution build stages were executed.

## Safety and remaining limits

- Signing proves provenance from the independently trusted collection authority,
  not that an arbitrary external signer is honest. Trust enrollment, signer
  custody, certificate revocation and signer compromise remain operator concerns.
- Dataverse solution/version/publisher metadata cannot prove the SHA-256 of the
  ZIP originally installed. The approved local package hash is bound but clearly
  classified as inferred server content provenance.
- Concrete table/column queries and effective Global customization privileges
  are supported. Descriptive form/view/app identities, external integration
  permissions and unresolved package/platform dependencies remain blocked, not
  guessed.
- No live environment has yet produced `verifiedForHumanReview: true`. That
  requires separately authorized collection against an explicit target, an
  enrolled independent trust certificate, complete fresh evidence and unchanged
  approved artifacts.
- The ordinary Fully Custom build behavior remains unchanged; this milestone
  strengthens only explicitly requested readiness evaluation. FAST-dependent
  Apply remains rejected, including with missing architecture artifacts.

## Integrated review validation

For the fresh integrated 2026-10-23 release check (103 verification assertions,
126 Pester tests and all aggregate gates passing), see the
[review guide](../../docs/fast-reporting-review-guide.md). The table above is
historical milestone evidence and retains its original counts and cleanup failure.

## Separate future controlled-execution phase

Require a new approved milestone before implementing any executor. Its scope
should include a separately issued, authenticated authorization bound to the
exact scope digest, plan hash, environment, principal, package identities,
operation categories and expiration; immediate authenticated re-verification;
managed-component restrictions; narrowly scoped writes; audit/inventory
reconciliation; revocation/replay protection; and operator-controlled recovery.
Neither a readiness result nor a signed verification record is that authorization.

## Local baseline revalidation: 2026-10-27

Revalidated the current working tree on
`review/fast-reporting-integration-20261023`, based on HEAD
`0d1812b9acea61afa750883422d88807f48b4f1d`. Existing staged implementation
and documentation changes were present; these results cover that working tree,
not the baseline commit alone. No implementation changes were required.

| Check | Observed result |
| --- | --- |
| `test-trusted-environment-verification.ps1` | Passed: 103 assertions; mocked GET-only collection |
| `test-execution-readiness.ps1` | Passed: 129 assertions; four applications and 26 negative scenarios |
| `test-fast-environment-preflight.ps1` | Passed: mocked environment compatibility |
| `test-fast-disabled-compatibility.ps1` | Passed: default-off compatibility |
| `test-accelerator-build-planning.ps1` | Passed: eight unrelated fixtures plus Hybrid and Fully Custom plans |
| `test-wizard-accelerator-integration.ps1` | Passed |
| `test-preview-nonmutation.ps1` | Passed |
| `test-json-schema.ps1` | Passed: 159 documents parsed; 22 payloads and 48 accelerator documents matched schemas |
| `test-contract-integrity.ps1` | Passed |
| `test-docs-consistency.ps1` | Passed |
| Pester 5.7.1: DataverseRuntime, QualityRunner, SkillParity | 126 passed; zero failed, skipped or not run |
| PowerShell parsing and PSScriptAnalyzer 1.24.0 | Ten relevant scripts passed; zero findings |

The parsing/analyzer scope was the environment inspector, readiness engine and
CLI, trusted verification collector and CLI, verification provenance, shared
Dataverse runtime, build orchestrator, and both focused acceptance scripts.
QualityRunner deliberately exercises failing child processes; its enclosing
Pester suite passed. These expected child failures are not baseline failures.

The focused suites exercised invalid/untrusted signatures, expired evidence and
certificates, target identity mismatches, omitted/downgraded required checks,
and nonexecuting readiness/build guards. No new readiness defect was observed
within this scope. All selected check processes exited zero, with no cleanup
lock reported. This was not a rerun of the full aggregate quality pipeline.

No sample artifacts were regenerated. No live Dataverse environment was
contacted, no production signing authority was enrolled, and no deployment,
branch promotion or commit was performed. Mock readiness remains unverified
for live human review, `executionAuthorized` remains false, and FAST-dependent
Apply remains disabled. The next gate is a separately approved live read-only
validation plan with an explicit target and independently provisioned trust;
this revalidation does not authorize that access or a future executor.
