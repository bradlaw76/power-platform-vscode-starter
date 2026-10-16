# ADR: Accelerator Architecture Selection

**Status:** Proposed - explicit user decision required
**Analysis ID:** `sha256:a37fde2aacd06f2154aefe865e67d141aefd5822cbac5ee90dfdd7c3f6ca6a6c`
**Catalog snapshot:** `sha256:777873ba1d2beedcb9fb5de2fe85d17c0f5bb20c6fafe5ce674d0de654be8348`

## Recommendation

Recommended planning option: **hybrid**.

This recommendation does not authorize accelerator installation,
Dataverse mutation, or FAST-dependent execution.

## Options

### 1. hybrid

- Status: planning-only-dependency-blocked
- Architecture suitable: True
- Execution gate open: False
- Rationale: Accelerator candidates cover 2 requirement(s), while 2 extension, 4 build, and 1 verification result(s) require explicit delta work.

### 2. fully-custom

- Status: available
- Architecture suitable: True
- Execution gate open: True
- Rationale: Uses the existing wizard generation path without FAST package or environment prerequisites.

### 3. fast-based

- Status: not-recommended
- Architecture suitable: False
- Execution gate open: False
- Rationale: Verified reuse requirements: 0; extension requirements: 2; custom-build requirements: 4; verification requirements: 1.

## Decision gate

The user must select an option before any later wizard integration may
translate this planning evidence into executable work.
