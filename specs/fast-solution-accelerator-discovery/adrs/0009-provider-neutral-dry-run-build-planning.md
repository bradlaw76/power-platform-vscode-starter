# ADR 0009: Provider-Neutral Dry-Run Build Planning

**Status:** Accepted for FAST-006
**Date:** 2026-10-16

## Context

An approved accelerator recommendation is architecture evidence, not an
executable Dataverse build instruction. A planner must translate approved
FAST-based, Hybrid, and Fully Custom decisions into component-level work while
preserving managed-solution ownership and the existing custom generation path.
The reusable implementation must not contain industry-specific defaults.

## Decision

Add a default-off provider-neutral planning adapter with the dispositions
`REUSE`, `EXTEND`, `CREATE`, `INTEGRATE`, and `DEFER`.

The adapter:

- consumes the approved scenario-local decision and hash-verified analysis
  artifacts rather than accepting an architecture override;
- treats managed accelerator components as immutable inputs and never permits
  direct managed-layer modification or duplicate creation;
- models extensions as separately owned customizations and defers them when
  customization support is not proven by fresh environment evidence;
- requires matching snapshot, package version, SHA-256, dependency, and target
  environment evidence for accelerator-dependent readiness;
- leaves Fully Custom independent of accelerator packages and environments;
- emits deterministic, schema-validated plans with requirement, task, evidence,
  dependency, acceptance, authorization, and rollback traceability;
- always sets `dryRun` to true and `executionAuthorized` to false.

The adapter is not registered with bootstrap stages or Dataverse transports.

## Consequences

- The current GCC Hybrid plan is blocked because Core and Investigations are
  absent and the evidence is stale.
- The same approved requirements can produce an independent Fully Custom plan.
- New industries require only requirements and scenario mappings, not adapter
  source changes.
- FAST-007 may consume these plans only after a separate execution-gate design,
  approval, and contract change.
