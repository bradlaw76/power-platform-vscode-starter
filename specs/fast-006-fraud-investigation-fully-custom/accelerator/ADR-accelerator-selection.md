# ADR: Accelerator Architecture Selection

**Status:** Proposed - explicit user decision required
**Analysis ID:** `sha256:638bf67049dddfb506455c6c5eb9102135fea5bc4f7ca95aa969ae8858b538c1`
**Catalog snapshot:** `sha256:5a59214ec84f70e0bc8f1da052458233ed2eab0f8c7963e6c92b66142e45bd69`

## Recommendation

Recommended planning option: **hybrid**.

This recommendation does not authorize accelerator installation,
Dataverse mutation, or FAST-dependent execution.

## Options

### 1. hybrid

- Status: planning-only-dependency-blocked
- Architecture suitable: True
- Execution gate open: False
- Rationale: Accelerator candidates cover 4 requirement(s), while 4 extension, 3 build, and 0 verification result(s) require explicit delta work.

### 2. fully-custom

- Status: available
- Architecture suitable: True
- Execution gate open: True
- Rationale: Uses the existing wizard generation path without FAST package or environment prerequisites.

### 3. fast-based

- Status: not-recommended
- Architecture suitable: False
- Execution gate open: False
- Rationale: Verified reuse requirements: 0; extension requirements: 4; custom-build requirements: 3; verification requirements: 0.

## Decision gate

The user must select an option before any later wizard integration may
translate this planning evidence into executable work.
