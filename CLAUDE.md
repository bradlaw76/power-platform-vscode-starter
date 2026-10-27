# Claude Repository Instructions

Follow the repository workflow in `SPEC.md`, `docs/onboarding.md`, and
`.github/copilot-instructions.md`; onboarding remains authoritative for bootstrap
ordering. Do not start build scripts before the planning gate is satisfied.

## Framework Maintenance Governance

Before framework-maintenance work, follow the canonical
[Framework Maintenance Handoff and Approvals](SPEC.md#framework-maintenance-handoff-and-approvals)
policy. Append dated updates to `docs/audits/chatgpt-review-handoff.md` for every
change and outcome, preserving history. Modification, commit, push, and merge
require explicit, separate approvals; reporting tools with publication side
effects are not exempt. Before reporting COMPLETE, PARTIAL, FAILED, or BLOCKED,
update the local handoff and state its publication status, or return
**HANDOFF NOT WRITTEN — BLOCKED** with the complete transferable report required
by the policy. Never bypass repository protection to write the handoff.
