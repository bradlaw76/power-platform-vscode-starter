# Implementation plan

The sequence below records the original PR #8 implementation, not a direction to merge its older baseline. The 2026-11-22 proposal projects only applicable policy/distribution changes onto main plus PRs #10/#9; it excludes missing formatter/update-advisor features. Current test evidence belongs to the integration proposal, not the historical counts.

1. Use a separate worktree based on integration commit
   `378ebd0a90c609207b767a9bac81ab72f4c98f35`; preserve the active branch and
   uncommitted README edits. Open a focused stacked PR targeting
   `review/fast-reporting-integration-20261023`, not the divergent default branch.
2. Author `docs/policies/authorization-and-execution.md`; retain existing
   onboarding order, semantic/report definitions, FAST default-off/readiness-only
   restrictions and form/Choice hash approvals.
3. Link rather than duplicate policy text in Copilot, the prompt and all skills.
   Clarify per-action commit/push permission in existing workflow documentation:
   one explicit request may authorize both, but one never implies the other.
4. Extend `01-install-skills.ps1` to copy the canonical policy into each installed
   skill's references folder. Require policy inheritance during reviewed consumer
   installation; never overwrite another project's instructions automatically.
5. Add Pester contract scenarios and real temporary-home installer/rerun checks.
   These test policy coverage and distribution, not probabilistic agent behavior
   or live deployment. Run focused tests and the existing full quality runner.
6. Record results in the build log and existing review guide, stage explicit
   files, scan staged changes for secrets, commit, push, verify SHA and open PR.

## 2026-11-24 Starter continuation plan

The original publication sequence above is historical. For the temporary
PROPOSED-DEVELOPMENT-EXECUTION-SIMPLIFICATION campaign:

1. Inspect only the isolated Starter worktree and applicable instructions.
2. Extend the canonical policy and scenario-impact/queue/recovery guidance.
3. Propagate concise policy summaries through existing instructions, skills,
   prompt, generated tasks and authoritative engineering/distribution docs.
4. Add focused decision/distribution cases to `AuthorizationExecution.Tests.ps1`
   and assert the emitted task contract in `test-wizard-modes.ps1`.
5. Run related Pester suites, generated wizard/template and contract checks,
   Markdown lint and changed-PowerShell parsing/analyzer checks. Use only
   credential-free local fixtures; no unrelated Python runtime changes.
6. Update the existing AI-neutral handoff/build log and separate STARTER/AUTO
   registration proposal, inspect explicit staged diff, then commit with the
   required co-author trailer. Do not push or change the PR body in this run.
