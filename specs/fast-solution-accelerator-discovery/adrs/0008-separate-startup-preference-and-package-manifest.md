# ADR 0008: Separate Startup Preference and Package Manifest

**Status:** Accepted for FAST-005B
**Date:** 2026-10-15

## Context

FAST-005A proved the default-off planning seam but exposed four acceptance
gaps: users could not express an early strategy preference, detailed workflow
answers collapsed into aggregate requirements, custom schema mappings rendered
as `None`, and nested `pwsh -File` calls bound only the first package path.
Generated planning Markdown also needed manual trailing-whitespace cleanup.

## Decision

When accelerator recommendations are already explicitly enabled, offer a
preliminary preference after mode selection and before business discovery:
Evaluate accelerators, Fully Custom, or Prefer FAST reuse.

The preference is stored separately from the final architecture decision. It
cannot enable the feature, select an architecture, authorize deployment, or
open the environment-readiness gate. Fully Custom bypasses matching. Prefer
FAST reuse preserves Hybrid and Fully Custom and uses the same evidence rules.

Split only explicitly delimited workflow clauses into deterministic
requirements. Preserve aggregate fallback when discovery does not provide
enough detail, and correlate criteria, entities, and integrations by evidence
terms rather than inventing requirements.

Rename formatter parameters that collide with PowerShell's automatic `$input`
variable and sanitize trailing whitespace before writing generated Markdown.

Use a validated package manifest as the preferred multi-package command-line
contract. Each entry pins the package metadata path, module and package IDs,
version, and SHA-256. Direct arrays remain supported for in-process callers,
but mixed inputs and identity mismatches fail explicitly.

## Consequences

- Normal runs remain baseline-equivalent because FAST and the selector remain
  disabled by default.
- Demo Builder retains six business questions and one consolidated final
  approval.
- Explicit fraud workflow clauses become independently traceable requirements.
- Schema mappings remain visible in all planning documents.
- Core and multiple specialty packages can be passed reliably through one
  nested PowerShell argument.
- No PAC, HTTP, Dataverse, import, generation, or build-stage authority is
  added.
- FAST-006 remains a separate approval boundary.

## Rejected alternatives

- **Let preference activate FAST:** bypasses repository feature governance.
- **Select a FAST module at startup:** requires premature technical knowledge.
- **Treat Prefer FAST as final approval:** removes evidence and user-choice
  gates.
- **Always split prose sentences:** risks manufacturing requirements not
  supplied through discovery.
- **Rely on repeated array arguments through `pwsh -File`:** is ambiguous
  across host invocation patterns.
