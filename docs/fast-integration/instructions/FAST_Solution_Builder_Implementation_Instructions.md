# FAST Integration — Implementation Instructions for the Existing Solution Builder / Wizard

> [!IMPORTANT]
> **Repository status:** FAST-000 through FAST-004 were completed on 2026-10-15; FAST-002 and the FAST-003/003A review gate are accepted, and FAST-004 awaits architectural review. See the [baseline evidence](../baseline.md), [Spec Kit artifacts](../../../specs/fast-solution-accelerator-discovery/), [environment compatibility contract](../../../specs/fast-solution-accelerator-discovery/environment-validation.md), and [sanitized GCC evidence](../../../specs/fast-solution-accelerator-discovery/evidence/fast-003a-gcc-validation.md). FAST-004 adds an explicitly enabled, standalone, provider-neutral requirements matcher and delta analyzer that uses documented and package-verified evidence, consumes optional preflight evidence without a live connection, and always preserves the fully custom option. It is not wired into wizard stages and cannot import solutions, call Dataverse, or modify an environment. FAST-005 wizard integration and deployment behavior remain unimplemented. The current wizard contract and authoritative sequence in [`docs/onboarding.md`](../../onboarding.md) remain unchanged.

**Instruction ID:** FAST-IMPLEMENTATION-001  
**Intended executor:** GitHub Copilot Agent in Visual Studio Code, working in the existing wizard repository  
**Status:** Implementation directive; **not** evidence that implementation has been performed  
**Priority:** Preserve, back up, and prove rollback of the existing wizard **before** introducing FAST functionality.

> **EXECUTION RULE:** Begin with **Phase 0 — Git baseline and recovery**. Do not crawl, refactor, install, deploy, or edit application code until the baseline is safely preserved. Work incrementally, report evidence after each phase, and do not advance past explicit approval gates.

## Executive objective

Extend the existing Solution Builder / Wizard with a dynamic, explainable **Solution Accelerator Discovery Engine**, with Microsoft **FAST (App & AI Starter Templates)** as its first provider. After normal user requirements discovery and **before architecture finalization**, the wizard shall automatically evaluate reusable FAST modules, their use cases, data models, and dependencies; show a concise recommendation only when useful; and generate a requirements-by-requirements gap analysis. The user remains free to accept a FAST foundation, select a hybrid approach, or choose a completely custom solution.

The original, fully custom wizard MUST remain functional with FAST **disabled**, **unreachable**, **removed**, or **no longer maintained**. Never make FAST an obligatory runtime or deployment dependency of the base wizard.

### Constitutional principle (retain this exact policy)

> The Solution Builder shall evaluate relevant reusable solution accelerators after requirements discovery and before architecture finalization. It shall recommend reuse when justified by functional fit, validated dependencies, and environment compatibility, while preserving user choice and the ability to generate a fully custom solution. Discovery of an accelerator must not be interpreted as authorization to deploy or modify it.

## Verified source starting points

- [FAST Getting Started Guide](https://microsoft.github.io/industry-solutions/articles/getting-started-guide/)
- [All FAST Modules](https://microsoft.github.io/industry-solutions/modules/)
- [FAST Use Cases](https://microsoft.github.io/industry-solutions/use-cases/)
- [FAST Core](https://microsoft.github.io/industry-solutions/modules/core/#overview)
- [FAST Documentation Home](https://microsoft.github.io/industry-solutions/)
- Follow **actual links** to persona details, diagrams, ERDs, solution-package downloads, releases, related pages, and any current official repositories. Verify that linked source repositories and release assets remain available; do not assume an archived repository is being updated.

The Getting Started Guide instructs installing **Core first** in a FAST Dataverse environment, then adding specialized modules and placing custom extensions in a separate solution. **This requirement applies when deploying specialty FAST modules, not when running the wizard in custom-only mode.** For any particular deployment, still inspect module-specific prerequisites and actual managed-solution dependencies.

**Catalog breadth:** Discover the current complete site from its indexes; do not hardcode module/use-case counts, names, or URLs beyond the discovery roots. A change to the site should be recognized without a code release, although new catalog entries must be validated before use in executable generation.

---

# Phase 0 — Mandatory Git backup, baseline verification, and recovery proof

**Goal:** Ensure we can undo the FAST integration completely, return to a verified pre-FAST version, and retain the original behavior even if FAST is discontinued or its website goes offline.

### 0.1 Inspect the repository BEFORE altering it

From the **correct existing wizard repository** (do not assume its name):

```bash
pwd
git rev-parse --show-toplevel
git remote -v
git status --short --branch
git branch --show-current
git log -5 --oneline --decorate
```

Identify the default branch (do **not** assume `main`), current branch, upstream remote, open PRs if accessible, uncommitted files, ignored/generated files, submodules, and any local changes. Inspect existing Spec Kit files, CI workflows, test scripts, build instructions and architecture docs.

**STOP if:** wrong repository, detached HEAD, unresolved merge, unexplained dirty worktree, missing remote, or failed fetch/push. Report the issue and the exact safe remedy. **Never discard, reset, stash-and-forget, force-push, or overwrite uncommitted user work.** Ask for a safe decision if the baseline cannot be preserved non-destructively.

### 0.2 Preserve user work and establish a remote recovery point

Only after the user/worktree state is understood and explicitly safe to proceed:

```bash
git fetch --all --prune
git status --short --branch
# If changes exist: inventory them; obtain approval before creating a preservation commit.
# Record the exact HEAD SHA:
git rev-parse HEAD
```

Create a **protected baseline branch** at the exact pre-FAST commit, using a unique timestamp or date to avoid colliding with an existing ref. Example (replace `<BASELINE_SHA>` and date/identifier):

```bash
git branch backup/pre-fast-20261015 <BASELINE_SHA>
git push origin backup/pre-fast-20261015
```

Create an **annotated rollback tag** at exactly the same SHA (replace values as appropriate):

```bash
git tag -a pre-fast-20261015 <BASELINE_SHA> -m "Verified wizard baseline before FAST integration"
git push origin pre-fast-20261015
```

Do **not** overwrite or re-point existing backup branches/tags. If push is unavailable, stop and report that remote backup is unverified; do not proceed under the assumption that local refs are sufficient.

Optional independent offline backup, when approved:

```bash
git bundle create ../wizard-pre-fast-20261015.bundle --all
git bundle verify ../wizard-pre-fast-20261015.bundle
```

Store such bundles securely **outside the repository**, never commit them, and never capture secrets or environment credentials in a distributed backup. A Git bundle preserves committed Git content, **not** untracked files, ignored files, secrets, live Dataverse state, or external systems.

### 0.3 Run and document baseline tests

Discover the project's real commands rather than inventing commands. At minimum, attempt the applicable existing build, unit tests, integration tests, format/lint, Spec Kit validators, Dataverse generator smoke tests, all three wizard mode smoke tests, and idempotency/re-run tests. Record pass/fail/skip with logs, durations if available, test counts, current SHA, environment/tool versions, and preexisting failures. Do not claim passing tests that were not executed.

Create a repository-appropriate baseline record, e.g. `docs/fast-integration/baseline.md`, **in the new feature branch**, documenting the pristine commit, remote backup ref, tag, commands/results, and rollback proof. Avoid modifying the baseline itself to add documentation.

### 0.4 Create an isolated implementation branch

From the exact verified baseline commit, create a unique feature branch:

```bash
git switch -c feature/fast-accelerator-catalog <BASELINE_SHA>
git push -u origin feature/fast-accelerator-catalog
```

Never implement FAST directly on the default branch. Use PR review, branch protection, scoped commits and CI evidence. If the existing repository has other active changes, reconcile with its actual branching strategy before implementation.

### 0.5 Design and test BOTH recovery paths

1. **Operational kill switch (preferred first response):** an `FAST_ENABLED=false` (or existing feature-flag naming convention) setting disables FAST discovery, matching, recommendation UI, catalog sync and FAST-dependent generation; the normal custom-only wizard works without network or FAST packages. Ensure the flag works **without a restart** if the existing configuration system supports dynamic flags; otherwise document restart/redeploy requirements.
2. **Full code rollback:** redeploy the known-good baseline tag or revert **only FAST-related PR merge commits** via standard Git procedures, respecting intervening unrelated work. Never use destructive reset/force-push on a shared branch. If FAST data migrations are introduced, provide forward-compatible, non-destructive rollback instructions; code rollback alone does not undo Dataverse schema changes.

Write and execute a **restore rehearsal in a nonproduction test workspace**: disable FAST, simulate FAST website/network outage, run existing custom-only scenarios, and confirm expected behavior. Preserve results in CI or evidence files. Do not actually remove production data or uninstall managed solutions during rollback tests.

**Phase 0 approval gate:** verified remote backup refs and tag; baseline tests captured; dedicated feature branch; rollback procedure documented. STOP here for review before other modifications.

---

# Phase 1 — Existing architecture assessment and Spec Kit design (NO feature implementation)

Inspect the codebase, test suite, recent architectural decisions, and Git history before proposing code edits. Find the **existing extension points** for:

- Requirements discovery, clarification, AI orchestration, semantic interpretation, architecture recommendations and user confirmation.
- **Demo Builder**, **Advanced Builder**, and **Framework Acceptance** modes.
- Spec Kit constitution, feature specifications, plans, tasks, evidence and provenance.
- Dataverse tables/columns, lookup/relationship creation, forms/views, model-driven apps, reporting, demo data, export and solution packaging.
- Environment connection, publisher prefix, dependency checks, security boundaries, Git workflows, rerun/idempotency logic and integration tests.
- Existing template registries, metadata caches, crawlers, connector layers and background jobs to reuse instead of introducing duplicates.

**Deliverables:** architecture assessment; current-state diagrams; reusable versus new components; Spec Kit feature spec, implementation plan, task list, data-model contracts, and architecture decision record (ADR). Respect the existing naming convention and directory layout; suggested paths in this document are illustrative only.

**Do not silently change the constitution.** Draft proposed amendments with the constitutional principle above, catalog source/provenance rules, explicit opt-in for deployment, dependency resolution, verified versus inferred capabilities, rollback isolation, reproducible catalog snapshots, and full requirements traceability. Mark amendments for review.

**Approval gate:** review plan and all architectural decisions before any feature code.

---

# Phase 2 — Pluggable accelerator catalog with complete FAST site discovery

Implement or extend an existing catalog interface so **FAST is one provider**, not tightly coupled into requirements parsing or Dataverse generation.

Conceptual responsibilities (reuse existing names/services where suitable):

- `AcceleratorProvider`: provider identity, discovery, data retrieval, provenance, health and availability.
- `FASTSourceAdapter`: traverses validated discovery roots, sitemap/navigation, module index, use-case index, linked persona pages, module-specific pages and diagrams/attachments.
- `CatalogSync`: incremental synchronization, status, validation, content-hash comparison, versioning and failure recovery.
- `CatalogStore` / `KnowledgeIndex`: searchable normalized metadata and retained raw sources or legally appropriate extracts.
- `CatalogDiff`: module/page/schema addition, update, removal, renaming and incompatible changes.

## Required collection scope

For **each module**, capture where provided:

- Stable ID/slug, module name, descriptions, terminology, tags and source URLs.
- Supported business capabilities, journeys, processes, activities, scenarios and workflows.
- Linked use cases, personas, related modules and documented prerequisites.
- Entity/table names, attributes, relationship descriptions, keys, conceptual ERDs, enumerations/reference data and data-model diagrams.
- Forms, views, dashboards, apps, flows, connectors, automations, rules and sample data when documented; **do not infer packaged features merely from marketing copy**.
- Release/package URLs and versions, artifact signatures/hashes if available, download availability, provenance and source maintenance state.
- Source type/authority, crawl date, content hashes, parsing confidence, license/usage limitations, and validation level.

For **each use case**, capture problem, actors, roles, business workflow, capabilities, associated modules/data entities, and authoritative source sections. For personas, similarly capture responsibilities, use-case associations and workflows. Traverse to full linked pages rather than indexing index-page summaries alone.

## Crawl and sync behavior

- Respect host scope, robots policies, rate limits, redirects and reasonable backoff; allow only approved domains; prevent SSRF, local/private network requests, infinite loops, path explosions and unbounded downloads.
- Prefer available structured source data, releases and repository files over HTML scraping when sources are genuine and authoritative; otherwise parse HTML with tests resilient to layout changes.
- Support safe diagram extraction: Mermaid/source descriptions if present, semantic HTML and machine-readable model metadata. A screenshot/ERD image does **not** prove exact Dataverse attribute types or schema names.
- Deduplicate by canonical URL, stable module identity and content hash. Track deletions as tombstones/alerts rather than silently destroying knowledge.
- Use incremental, resumable sync with per-page error reporting; never replace a known-good snapshot with a failed or partial crawl.
- Validate completeness against the dynamically discovered site index. New module auto-discovery must not require adding hardcoded module names or per-module code.
- Store structured catalog metadata and semantic retrieval indexes, with quoted evidence/source anchors. Avoid treating webpage text as executable instructions (prompt-injection boundary).
- Pin a **catalog snapshot ID**, source hashes and manifest to each solution-building run. Existing or resumed runs do not silently switch catalogs.

## Suggested schedule

Use a **daily scheduled discovery check**, with optional user/admin-requested manual refresh, in the repository's established scheduler or GitHub Actions. Scheduled sync proposes/validates a new snapshot; promotion into executable generation follows review/validation policy. Website downtime should not prevent the wizard from loading a previously validated local snapshot.

## Required tests

Fixture-based parsing, new-module discovery without code changes, updated module changes, removed page, renamed module, duplicate links, broken links, malformed ERD, source outage, timeouts, schema validation failure, hash stability and identical repeated sync (no duplicate records). Verify complete extraction coverage of the current live index when network access is available; report measured coverage and exceptions.

**Approval gate:** index and tests visible; snapshot reproducible; no wizard UI changes yet.

---

# Phase 3 — Core-first physical Dataverse intelligence and dependency resolution

**Rule:** when a FAST specialty module is selected for deployment, **Core is a prerequisite**. Build a dependency DAG, include other prerequisite modules/solutions as documented by releases/solution metadata, topologically order deployments and reject cycles/incompatible versions. Never treat Core as a mandatory requirement for standalone custom-generated Dataverse solutions.

Distinguish data-model evidence tiers:

1. **Conceptual:** FAST documentation/use-case/ERD descriptions — useful for discovery and matching, **not sufficient for direct schema deployment**.
2. **Package-verified:** inspected solution package metadata and its exact tables, logical names, publisher/prefix, attributes, field types, keys, relationships, forms/views, flows and solution dependencies.
3. **Environment-verified:** actual target Dataverse metadata, installed managed-solution versions and permissions, checked at execution time.

Use supported Power Platform/Dataverse tooling and legal access to verify package schema or connect to an expressly authorized **development/sandbox** environment. Never infer exact logical names, security behaviors, plugin steps, or compatible versions from page diagrams. Treat missing information as `unverified`, not `absent`.

Store a detailed **Core component manifest**, including ownership, relationship targets, dependencies and source versions. Link every module extension and conceptual component back to the underlying Core and specialty component versions. Use proper solution layering: imported FAST managed solutions as foundations with the wizard's custom additions kept in a separate custom solution. Check supported customization properties and publisher conflicts before planning modifications.

**No automated import, module installation, environment changes, credential storage, customer connection, or production deployment** in this phase. Generate a reviewed installation/dependency plan only.

**Approval gate:** Core manifest, physical-versus-documentation discrepancies, dependency resolution test evidence and sample compatibility matrix reviewed.

---

# Phase 4 — Requirements-first accelerator matching and precise delta analysis

**Do not start the wizard by asking the user if they want FAST.** Preserve the existing initial discovery questions: problem, required actors, workflow, data, integrations, constraints, security and outcomes. Run automatic catalog matching **after requirements extraction and before architecture finalization**.

Matching pipeline:

1. Normalize requirements with stable IDs, acceptance criteria, entities, relationships, personas, workflows and nonfunctional constraints.
2. Retrieve potentially relevant modules and use cases through search/semantic similarity and deterministic metadata filters.
3. Resolve module prerequisites/Core and check source freshness, verification tier and environment compatibility (when available).
4. For every requirement, label the implementation decision: **reuse**, **extend**, **build new**, **integrate**, **verify**, or **not applicable**. Each row must include evidence URL/section, actual component if verified, confidence, gaps, constraints, estimated customization and dependency implications.
5. Recommend **FAST foundation / Hybrid / Fully custom** architectures with clear rationale, expected reusable components, gaps, unverified assumptions and potential maintenance risks.
6. Ask **at most one targeted clarification** when it materially changes the decision; otherwise show a short choice. If FAST is irrelevant, unavailable, disabled or not credible, continue the standard custom build with no extra question.
7. Capture user's choice in a Spec Kit ADR. Explicit user preference for custom-only wins over a high similarity score.

**Example — federal fraud investigation:** evaluate Investigations plus Core for case/evidence structures; compare fraud-specific analytics/scoring, case triage, integrations, dashboards, agency security/access controls and AI capabilities separately. Do not assume FAST provides AI fraud scoring, federal authorizations, identity integration, or advanced fraud detection merely because its investigation workflow is relevant.

Recommended artifacts: `requirements-to-fast-matrix`, `accelerator-evaluation`, `fast-dependency-manifest`, `core-schema-reuse-plan`, `solution-delta-plan`, `ADR-accelerator-selection`, and task/test traceability. Follow existing Spec Kit conventions rather than creating parallel, incompatible document systems.

**Acceptance tests:** strong match, partial match, zero match, ambiguous match, missing Core, outdated catalog, multiple modules with overlapping tables, unavailable source, incompatible version, custom-only override, unverifiable capability, and unchanged baseline flows.

---

# Phase 5 — Integrate into existing wizard modes, generator and UX

- **Demo Builder:** invisible matching behind the normal discovery process. When a credible match exists, show a concise recommendation and a one-click **FAST/Hybrid vs Custom** choice (plus optional “Why?”). No new mandatory questionnaire.
- **Advanced Builder:** expandable table/module mapping, Core requirements, provenance, schema differences, compatibility, source versions, dependency plans, manual override and custom model choices.
- **Framework Acceptance:** exercise sync, matching, dependency DAG, version pinning, gap classification, package/source validation, no-match fallback, repeat-runs, feature flags and rollback.
- **Generator:** when approved and technically validated, generate custom solution additions/extensions against **existing** FAST components without duplicating their logical names. Maintain published managed-solution boundaries and only implement approved configuration/customizations. If selected modules are absent, produce a prerequisite installation plan and block FAST-dependent deployment, rather than silently installing them.
- **Export / ALM / Git:** retain current flows; include selected catalog ID and module versions, evidence manifest, requirements delta, prerequisites and custom solution components. Keep the generated output reproducible and idempotent.
- **Security:** do not send sensitive agency requirements to arbitrary crawlers or third-party sites. Sanitize external documentation; apply least privilege to any Dataverse inspection; validate accessibility, authentication and audit controls.

Do not redesign working screens, rename modes, change default behavior or turn FAST into an unrequested platform dependency.

---

# Phase 6 — FAST off-switch, removal and failure mode contract

A key **release acceptance criterion** is that FAST can be turned off or removed **without impairing the original wizard**.

Required design and automated proof:

1. A central configuration capability flag (adapt name to current conventions), disabled mode fully bypasses FAST UI, matching, dependent generation, network calls and scheduler registration while leaving existing requirement collection and custom generation intact.
2. Provider registry permits **unregistering/removing FAST** without changing consumer code; no FAST import/load failure may crash base startup.
3. If FAST URL is unreachable but a validated snapshot exists, allow offline discovery only if enabled and explicitly label the snapshot age; never claim current availability. If no valid snapshot, fall back cleanly to custom-only.
4. Already generated solutions retain pinned manifests; losing the catalog must not corrupt them or silently rewrite design decisions.
5. Removing FAST code must not require deleting Core Dataverse solutions, custom customer tables or historic Spec Kit artifacts. **Uninstalling managed solutions is a separate, risky Dataverse operation** and must never be part of automated feature rollback.
6. Migrations related to catalog storage should be additive and backward-compatible where feasible, with a tested retirement plan.
7. Regression suite must compare core wizard behaviors on the pre-FAST baseline, with FAST enabled, FAST disabled, missing catalog and simulated source outage.
8. Document separate procedures for **feature disable**, **deployment rollback**, **catalog rollback**, **historic artifact retention** and **Dataverse environment recovery**.

### Operational fallback decision table

| Condition | Required behavior |
|---|---|
| FAST feature flag off | Original wizard operates in custom-only mode; no FAST network dependency |
| FAST site temporarily unavailable | Use pinned validated catalog if allowed; show freshness; otherwise custom-only |
| FAST source is permanently retired | Disable sync/provider; retain archival source attribution and existing build manifests |
| Broken new catalog | Retain last known-good snapshot; alert, do not promote |
| FAST incompatible with target environment | Block FAST-dependent deployment; offer custom-only or remediation plan |
| User rejects FAST | Persist ADR and continue fully custom |
| FAST code reverted | Normal wizard tests must still pass; no shared-branch force reset |

---

# Phase 7 — CI/CD, QA, release and controlled rollout

Produce narrowly scoped PRs with explicit stop/go reviews:

| Work item | Scope | Required evidence |
|---|---|---|
| FAST-000 | Git baseline/backup/rollback | Remote tag/branch SHA, original tests and restore rehearsal |
| FAST-001 | Assessment/Spec Kit/ADR | Reviewed architecture and incremental task list |
| FAST-002 | Crawling/catalog schema/snapshots | Current catalog inventory, source coverage, sync tests |
| FAST-003 | Live read-only environment preflight | Versioned readiness report, mocked transport/cache/failure tests, no mutation |
| FAST-004 | Requirements matching/delta planner | Golden requirement scenarios, traceability/evidence |
| FAST-005 | Mode UX and generator wiring | Feature-flagged behavior, no added mandatory questions |
| FAST-006 | Failure/rollback/regression/ALM | Disabled/offline tests, nonproduction restore verification |

**Do not ship all six engineering phases in one giant PR.** Each PR must contain changed-file inventory, motivation, tests that actually ran (with command/output), failures/skips, screenshots only where UI changes are relevant, risks, dependency/source versions and exact rollback steps.

Promote to test/UAT only after security review and acceptance. Production or customer environment modifications always require explicit separate approval, appropriate permissions and normal organization change control. Do not manufacture successful test outcomes or package verification.

## Definition of done

- [ ] Pre-FAST commit, remote backup branch and annotated tag exist and match; restore procedure is tested.
- [ ] Original tests have a documented baseline and continue passing (or preexisting failures explicitly identified).
- [ ] Existing Spec Kit architecture and all three operating modes are preserved.
- [ ] New FAST modules and use cases can be discovered without hardcoded additions.
- [ ] Catalog sync is incremental, secure, idempotent, versioned and safe under source failure.
- [ ] Module data models, related use cases/personas, provenance, and source links are indexed with coverage reported.
- [ ] Core dependency and other module prerequisites are represented in a validated dependency graph.
- [ ] Conceptual documentation metadata is distinguishable from package-verified and environment-verified Dataverse metadata.
- [ ] Requirements-first recommendations include a per-requirement gap matrix and citations.
- [ ] Custom-only flow remains available and equivalent to pre-FAST behavior.
- [ ] FAST disabled/source retired/catalog unavailable scenarios pass automated tests.
- [ ] Generation cannot modify customer environments or install FAST modules without separate approval.
- [ ] Solution packaging, Git, evidence, reruns and architecture records remain reproducible.
- [ ] CI and reviewer approval are completed before merge.

---

# Instructions to the Copilot agent: first execution and stopping point

**Start ONLY with FAST-000 and FAST-001.** Do not attempt the crawler, metadata parser, matching engine or UI implementation in the initial run.

1. Identify the right repository, verify Git state and report what will be backed up.
2. Preserve a verified remote pre-FAST baseline using a unique immutable SHA-referenced backup branch and annotated tag; do not discard user changes.
3. Record baseline test outcomes using the project's actual test commands.
4. Create the dedicated feature branch; document feature-disable and rollback designs.
5. Thoroughly inspect current wizard code, history, Spec Kit artifacts, test and provenance systems.
6. Read official FAST guide/module/use-case/Core pages and follow authoritative references.
7. Produce Spec Kit-compatible planning documents, ADRs, milestones, acceptance tests and a minimal-change architecture.
8. Report source verification gaps, Git backup evidence, test outcomes and exact modified files.
9. **STOP for review. DO NOT start application implementation or Dataverse installation.**

If a requirement in this instruction conflicts with established repository safeguards, the existing constitution, branch policies, or security controls, **stop, describe the conflict, and propose the safest compliant resolution** rather than bypassing controls.

## Agent completion report template

```text
Instruction ID: FAST-IMPLEMENTATION-001
Repository / default branch / feature branch:
Pre-FAST SHA:
Remote baseline branch / tag / verification:
Working-tree preservation status:
Baseline tests (commands / passed / failed / skipped):
Current architecture and reusable extension points:
Spec Kit files proposed/changed:
FAST sources successfully inspected:
Unverified or inaccessible sources:
Core dependency and physical schema verification plan:
Feature flag / outage fallback / revert procedure:
Risks and open decisions:
Exact next approved milestone:
STOPPED before implementation: YES/NO
```

**End of implementation instructions.**
