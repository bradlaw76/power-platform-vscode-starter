# FAST-004 Requirements Analysis Evidence

**Validation date:** 2026-10-15
**Scope:** Credential-free synthetic requirements against documented FAST
capability fixtures and the verified Core, Investigations, and Training and
Certification package indexes.

Synthetic requirements below are test inputs. They are not represented as
Microsoft product claims. Catalog descriptions and source URLs retain their
documented provenance.

## Representative coverage matrix

| Requirement | Candidate | Disposition | Evidence | Specific delta |
| --- | --- | --- | --- | --- |
| REQ-FRAUD-001: investigation intake through resolution, evidence custody, interviews, and corrective actions | Investigations 1.2.1.0 | REUSE | Documented capability plus package-verified components | Environment execution remains blocked because GCC Core is absent |
| REQ-TRAIN-001: learning delivery, credentialing, qualifications, and mobile renewal alerts | Training and Certification 1.2.1.0 | EXTEND | Documented capability plus package-verified components | Mobile renewal alerts are not established by the indexed evidence |
| REQ-HYBRID-001: investigation intake plus external fraud scoring and predictive referrals | Investigations 1.2.1.0 | EXTEND, INTEGRATE | Documented and package-verified investigation foundation | Add the external API integration and design the unsupported predictive referral workflow |
| REQ-CUSTOM-001: cafeteria menus and ingredient quantities | None | BUILD | No evidence-grounded FAST candidate | Design new Menu, Ingredient, and Lunch Day components |
| REQ-DOCS-001: asset accountability and lifecycle management | Asset Management documented version | VERIFY | Documented capability only | Obtain package metadata before proposing physical reuse |
| REQ-AMBIGUOUS-001: TBD investigations or training workflow | None selected | VERIFY | Requirement uncertainty | Clarify workflow, actor, outcome, and acceptance criteria |

## Dependency and environment evidence

- Investigations and Training and Certification each resolve a grouped module
  dependency on Core while retaining uniquely identified physical dependency
  evidence.
- Duplicate display names do not inflate component counts.
- Version differences remain unverified without an explicit compatibility
  policy.
- Synthetic cyclic module fixtures close the FAST-dependent execution gate.
- The accepted GCC preflight reports Core and specialty modules absent with
  readiness `action-required`. Matching and all three architecture alternatives
  remain available, while FAST-based execution remains closed.

## Architecture outcome

The mixed representative scenario recommends **Hybrid** because verified
accelerator foundations coexist with extension, integration, custom-build, and
verification deltas. A fraud-only scenario recommends **FAST-based** for
architectural suitability while retaining the closed environment gate. An
unrelated cafeteria scenario recommends **Fully Custom**.

All analyses preserve Fully Custom as selectable and require a final user
choice.

## Safety and reproducibility

- No PAC, HTTP, Dataverse, or environment call is used by the matcher.
- No solution is imported and no Dataverse mutation is possible.
- FAST remains disabled in the provider registry.
- Repeated execution with identical normalized requirements and snapshot
  produces the same analysis identity and coverage matrix.
- A newly discovered synthetic module participates without matcher code
  changes.
- Unavailable source, documented-only metadata, stale or missing environment
  evidence, and FAST-disabled paths fail closed.
