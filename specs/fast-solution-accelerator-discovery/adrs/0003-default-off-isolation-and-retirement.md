# ADR 0003: Default-Off FAST Isolation and Source Retirement

**Status:** Proposed  
**Date:** 2026-10-15

## Context

Both current FAST backing repositories are archived. The wizard must remain
usable if sources disappear, are retired, or the FAST implementation is
reverted.

## Decision

Use `FAST_ENABLED` as a default-off provider-registration flag. Disabled mode
performs no FAST loading, network access, matching, scheduling, prompts, or
dependent generation. Source archive/retirement is a provider health state.
The last promoted snapshot may be used offline only under explicit policy and
with visible age. Otherwise the wizard continues custom-only.

Code rollback, catalog rollback, provider retirement, historic artifact
retention, and Dataverse managed-solution recovery are separate procedures.
Automated FAST rollback never uninstalls managed solutions.

## Consequences

- Existing behavior remains the release baseline.
- FAST can be retired without corrupting historic decisions.
- A restart/new invocation is initially required after changing the environment
  flag because the repository has no dynamic feature-configuration service.
- Offline use needs freshness policy and clear user messaging.
- Managed-solution lifecycle remains under environment change control.

## Rejected alternatives

- **Default-on FAST:** introduces network and maintenance dependencies into the
  baseline wizard.
- **Silent stale-cache use:** misrepresents current availability.
- **Delete historic decisions when retired:** breaks auditability and
  reproducibility.
- **Uninstall FAST solutions during code rollback:** unsafe, destructive, and
  outside source-code rollback authority.

