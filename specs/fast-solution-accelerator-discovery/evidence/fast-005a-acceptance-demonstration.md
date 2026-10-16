# FAST-005A Acceptance Demonstration

## Result

Executed on 2026-10-15 from `feature/fast-accelerator-catalog` at
`db7b44222bac098826c744c7c02bf90a7742abb7`.

The real Demo Builder, Advanced Builder, and Framework Acceptance modes
completed with accelerator recommendations explicitly enabled. The runs used:

- catalog snapshot
  `sha256:777873ba1d2beedcb9fb5de2fe85d17c0f5bb20c6fafe5ce674d0de654be8348`;
- 32 catalog items, including 21 modules;
- verified Core, Investigations, and Training and Certification package
  indexes;
- the existing GCC environment report for
  `https://powerplatformvscodestarter.crm9.dynamics.com`.

No live Dataverse request, solution import, build stage, or environment
mutation was performed.

## Demo Builder interaction

| # | Actual question | Scripted acceptance answer |
|---|---|---|
| 1 | Describe the app idea and business outcome | FAST 005A Fraud Investigation Demo |
| 2 | Who is the primary user, and what is their top task? | Fraud investigator; triage intake, assign investigators, and manage cases through supervisor approval |
| 3 | What business records or data should the app track? | Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report |
| 4 | What should users see or do, including any lifecycle stages? | Capture intake, assign an investigator, maintain evidence chain of custody, document interviews, call an external fraud-scoring service, route the case for supervisor approval, and present reporting |
| 5 | What makes the demo successful, and should it include synthetic sample data? | A complete synthetic fraud case proves custody, interviews, fraud-score auditability, approval, and reporting |
| 6 | What Environment URL and solution output do you expect? | GCC development URL; unmanaged solution |
| 7 | Select and approve the consolidated architecture | Hybrid |

The actual concise recommendation was:

- recommended option: `hybrid`;
- environment readiness: `action-required`;
- FAST-dependent execution gate: closed;
- Hybrid: planning-only, FAST portions blocked;
- Fully Custom: available;
- FAST-based: not recommended.

Generated evidence:

- `../../fast-005a-fraud-investigation-demo/answers.md`
- `../../fast-005a-fraud-investigation-demo/spec.md`
- `../../fast-005a-fraud-investigation-demo/plan.md`
- `../../fast-005a-fraud-investigation-demo/tasks.md`
- `../../fast-005a-fraud-investigation-demo/accelerator/`

## Advanced Builder interaction

The Advanced Builder captured the same fraud workflow with explicit:

- application, table, form, entry-point, view, grid, app, and source-control
  choices;
- actors and user tasks;
- investigation, assignment, evidence, custody, interview, score, approval,
  and reporting entities;
- external fraud-scoring integration;
- relationship cardinality, requiredness, cascade, ownership, and done
  definitions.

The actual detailed output classified:

| Requirement | Primary candidate | Version | Dispositions | Evidence |
|---|---|---:|---|---|
| `REQ-BUSINESS-001` | Investigations | 1.2.1.0 | EXTEND, INTEGRATE | package-verified |
| `REQ-EXPERIENCE-001` | Core | 1.2.1.0 | EXTEND, INTEGRATE | package-verified |

Generated evidence:

- `../../fast-005a-fraud-investigation-advanced/answers.md`
- `../../fast-005a-fraud-investigation-advanced/spec.md`
- `../../fast-005a-fraud-investigation-advanced/plan.md`
- `../../fast-005a-fraud-investigation-advanced/tasks.md`
- `../../fast-005a-fraud-investigation-advanced/accelerator/`

## Framework Acceptance interaction

Framework Acceptance additionally captured authorized-environment intent,
isolated naming, retention, no destructive cleanup approval, and the required
rerun and decision evidence.

The first decision explicitly selected Hybrid:

- decision ID:
  `sha256:9fb26ce8a4f0f173ed8e249fb3adbe9c38c34ca0703750476a60544b8b257118`;
- decision file SHA-256:
  `5973eee3939cfd1eb66b2e4b3962bab47964fdc89820bf3bdb48779c580d2ae2`.

An unchanged rerun reproduced all 13 accelerator files byte-for-byte.

Changing Hybrid to Fully Custom without
`-ApproveAcceleratorDecisionChange` failed with:

> The approved accelerator architecture decision changed. Rerun with
> -ApproveAcceleratorDecisionChange only after explicit review.

The rejected run preserved the decision SHA-256. Repeating the change with the
explicit approval flag succeeded:

- final decision:
  `sha256:77abf4abaa66c1d87de462e97e01b730d4b97cff19f3f0a7c88b972fb13484e1`;
- final decision file SHA-256:
  `5bcfcf11907ff27012332b89660e1066fa8a1c58a4fb8357f2839fb3f45e81c4`;
- selected option: `fully-custom`;
- Fully Custom execution allowed: `true`;
- FAST-dependent execution allowed: `false`.

Generated evidence:

- `../../fast-005a-fraud-investigation-framework/answers.md`
- `../../fast-005a-fraud-investigation-framework/spec.md`
- `../../fast-005a-fraud-investigation-framework/plan.md`
- `../../fast-005a-fraud-investigation-framework/tasks.md`
- `../../fast-005a-fraud-investigation-framework/accelerator/`

## Actual architecture comparison

| Option | Rank | Suitability | Execution | Actual rationale |
|---|---:|---|---|---|
| Hybrid | 1 | Suitable | Blocked for FAST portions | Two requirements have accelerator foundations, but both require extension or integration |
| Fully Custom | 2 | Suitable | Available | Uses the existing wizard path without FAST package or environment prerequisites |
| FAST-based | 3 | Not recommended | Blocked | No requirement was proven as complete REUSE; both matched requirements require extension |

Evidence references are preserved in the coverage matrix. The primary sources
were the Microsoft FAST Investigations and Core module documents plus the
verified package indexes:

- Investigations source content hash:
  `1d145d87ace685c4d6cb954406ab7887bdf3c2cac4f7ab7fa9857c8fe9ab5672`;
- Investigations package SHA-256:
  `131be1ade134e838e3d824777b6655331a7149eaf80ae14bc26583a4f1bb8391`;
- Core source content hash:
  `924de286202f9dd67cd3b5d6afbb7145be830aa49b5b7cea4be95a9340f97da6`;
- Core package SHA-256:
  `f813e8500b97db1fd74f938da28f22ba53c1c4593f6374b34e8a0f7d52e895b3`.

## Component and dependency evidence

The generated delta identified package-verified Investigations components,
including the Investigations model-driven application and evidence access and
custody attributes. It did not claim that these components fully implement the
requested fraud process.

The dependency manifest recorded:

- selected modules: Core and Investigations;
- foundation module: Core;
- specialty module: Investigations;
- module dependency edges: 1;
- deduplicated component dependencies: 33;
- unresolved dependencies: 0;
- dependency cycles: 0.

The external fraud-scoring connector, its security and error handling,
supervisor-specific approval behavior, and solution-specific reporting remain
extension or integration work.

## GCC readiness

The supplied environment evidence matched the catalog and package identities,
but it was stale and remained `action-required`.

- Core assessment: `missing-prerequisites-potentially-available`;
- installed FAST modules in the referenced report: none;
- FAST execution gate: closed;
- automatic Core installation: not attempted;
- Fully Custom path: available.

## Artifacts inspected

The 13 Framework Acceptance accelerator files were inspected and included:

- `accelerator-evaluation.json`;
- `requirements-coverage-matrix.json`;
- `component-delta-analysis.json`;
- `schema-reuse-extension-plan.json`;
- `dependency-manifest.json`;
- `environment-readiness-reference.json`;
- `architecture-recommendation.json`;
- `acceptance-traceability.json`;
- `requirements-to-accelerator-matrix.md`;
- `ADR-accelerator-selection.md`;
- `accelerator-analysis-manifest.json`;
- `accelerator-decision.json`;
- `accelerator-decision.md`.

## Acceptance findings

1. The real catalog and package evidence produced the expected conservative
   Hybrid recommendation and correctly blocked FAST execution in GCC.
2. Passing multiple package metadata paths through a nested
   `pwsh -File` invocation bound only the first path. The valid acceptance run
   invoked the wizard directly from PowerShell so the `string[]` parameter
   received all three package paths. Terminal guidance should make this
   invocation requirement explicit or provide a repeatable manifest input.
3. The wizard normalized the detailed workflow into only two aggregate
   requirements. The features are present in descriptions, integrations, and
   acceptance criteria, but intake, assignment, custody, interviews, scoring,
   approval, and reporting do not receive independent coverage rows.
4. Advanced and Framework generated `answers.md`, `spec.md`, and `plan.md`
   render the explicit custom-table, custom-field, and relationship lists as
   `None`, even though the relationship decision text and downstream tasks
   retain the supplied values. This is a planning-artifact rendering defect
   outside the FAST recommendation seam and must be corrected before these
   scenario plans can authorize payload generation.
5. The three generated `spec.md` and `plan.md` pairs initially contained 18
   trailing-space lint errors. Repository-standard Markdown auto-formatting
   corrected the generated acceptance copies; the generator should avoid
   emitting the whitespace on future runs.

FAST-005A is therefore executed with the recommendation, safety, rerun, and
approval gates demonstrated, with findings 2-5 retained for follow-up.

## FAST-005B correction rerun

FAST-005B repeated the fraud demonstration through Demo Builder, Advanced
Builder, and Framework Acceptance using the same promoted 32-item catalog,
saved GCC evidence, and a single validated package manifest. The manifest
loaded and verified Core, Investigations, and Training and Certification
metadata, including each module/package identity, version `1.2.1.0`, and
package SHA-256.

The startup interactions were:

- Demo Builder: `evaluate`;
- Advanced Builder: `prefer-fast`; and
- Framework Acceptance: `evaluate`.

Each selector appeared after mode selection and before business discovery.
The output stated that the preference was planning-only and did not select an
architecture or authorize deployment. Separate regression coverage proved
that `fully-custom` bypasses matching and that `prefer-fast` retains Hybrid and
Fully Custom options.

The corrected fraud coverage contains seven stable requirement records:

| Requirement | Disposition | Evidence/result |
| --- | --- | --- |
| `REQ-INVESTIGATION-INTAKE-001` | EXTEND, INTEGRATE | Investigations, package verified |
| `REQ-INVESTIGATOR-ASSIGNMENT-001` | EXTEND, INTEGRATE | Investigations, package verified |
| `REQ-EVIDENCE-CUSTODY-001` | EXTEND, INTEGRATE | Investigations, package verified |
| `REQ-INTERVIEW-001` | EXTEND, INTEGRATE | Investigations, package verified |
| `REQ-EXTERNAL-FRAUD-SCORING-INTEGRATION-001` | BUILD, INTEGRATE | No sufficient accelerator evidence |
| `REQ-SUPERVISOR-APPROVAL-001` | BUILD, INTEGRATE | No sufficient accelerator evidence |
| `REQ-OPERATIONAL-AND-MANAGEMENT-REPORTING-001` | BUILD, INTEGRATE | No sufficient accelerator evidence |

Framework Acceptance conservatively classified the one-word interview clause
as VERIFY because it lacked enough distinctive detail in that submitted
answer. This demonstrates that clause extraction does not invent functional
coverage from a label alone.

The generated Advanced and Framework planning files now retain all submitted
custom tables, custom fields, and relationships instead of rendering them as
`None`. Generated `spec.md` and `plan.md` files contain no trailing whitespace
without manual formatting.

The first corrected Demo and Advanced runs rejected the changed approved
decision until `-ApproveAcceleratorDecisionChange` was supplied. Explicitly
approved runs then succeeded. A second unchanged Framework run produced 14
byte-identical accelerator artifacts.

Hybrid remained ranked first, Fully Custom remained available, and FAST-based
remained not recommended. GCC readiness remained `action-required`; missing
Core and specialty modules kept FAST-dependent execution closed. No PAC
authentication, network request, Dataverse request, package import, build
stage, or mutation was invoked.
