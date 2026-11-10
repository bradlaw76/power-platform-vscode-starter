# Implementation plan

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
