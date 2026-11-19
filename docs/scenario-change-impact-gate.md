# Scenario Change Impact Gate for the VS Code Wizard

**Status:** authoring guidance for greenfield, existing-app retrofit and later scenario extensions. This file improves the Wizard's **planning instructions**; it does not implement a new PowerShell stage or authorize running deployment scripts. `docs/onboarding.md` remains the bootstrap sequence authority, and scenario `spec.md`, `plan.md`, `tasks.md` and `report-mappings.md` remain the build-specific planning sources.

## When the Wizard must run this review

Trigger it not only when a new project begins, but when a user adds a **new scenario, journey, branch, persona, tab, field, form, view, portal/HTML experience, report, Case episode, related record or synthetic dataset** to an already running project. Run a **delta against accepted requirements, current source, and observed tenant metadata** before giving instructions to implement UI. A prepared demo screen can still be created independently while its live data dependencies remain unresolved, provided it is labeled prepared and cannot write to Dataverse.

The Wizard must not ask the owner to re-answer accepted questions, restart prior completed work or assume a blocked component stops every independent package. Inspect the current repository, Spec Kit, open PRs/branches, dirty worktrees, active writers and locks; keep current H/workload numbers. In projects where ChatGPT allocates H numbers, Copilot must not select, rename or reuse them. The owner can authorize **multiple compatible H-numbered packages in one batch**; preserve one writer per conflicting resource and per-environment write authority.

## Step 1 — Inventory and compare the actual existing build

Ask read-only technical questions only for missing material decisions. Prefer discovery from repository manifests, payloads and existing approved metadata, then show a consolidated confirmation:

| Scope | Inventory to verify | Preserve by default |
|---|---|---|
| Base model | Standard Dataverse tables, exact existing columns/types, lookups, relationship cardinality/cascade, custom table solutions | Do not create a duplicate of `incident`, `contact`, `account` or another suitable standard table |
| User experience | Current form IDs/roles/order, app roots/sitemap, views, charts, dashboards, native Timeline, portals and web resources | Existing/shared/managed/other-solution forms, views and fallback; choose a new dedicated copy on standard table when requested |
| Business scenario | Requirement IDs, personas, actions, actual/simulated episodes, source facts and unresolved business decisions | Original requirements and accepted answers; no invented conditions, weights, medical rationale or dates |
| Data/security | Identity, Contact/Case linkage, actual actor, table/column/record roles, portal Web API permissions, documents and fixture IDs | Existing records, keys and unrelated demo data; no global role grant or copy by matching display name |
| Work and evidence | Git state, PRs, H/work IDs, writer ownership, task status, tests and release receipts | No second writer, blind cherry-pick, publish-all, unapproved reset or deployment |

## Step 2 — Complete the scenario impact matrix *before* HTML, forms or field payloads

Create or update a **scenario-owned** `scenario-impact-register.md` (or agreed maintained equivalent). Every changed requirement/persona/checkpoint gets a row tracing **the whole chain**:

`requirement/checkpoint → role and signed-in actor → exact standard/custom table → existing or candidate field/relationship → type/requiredness/source → dedicated form and tab/control → view/subgrid/chart → app/sitemap → Power Pages/HTML DTO and permissions → synthetic data and chronology → actual Save/reopen and negative tests → solution membership → implementation owner and state`.

Use explicit states `EXISTING VERIFIED`, `REUSE CANDIDATE`, `NEW PROPOSED`, `PREPARED ONLY`, `UNRESOLVED`, `IMPLEMENTED SOURCE`, `PUBLISHED`, `INTENDED-USER VERIFIED`. Never convert a label or a mock into a verified logical name. Every candidate addition must be compared to suitable **native/standard** columns, relationships, activities, notes, attachments and existing tables before creating it.

Produce/update five companion contracts as part of the *same planning batch*:

1. **Field/relationship dictionary:** host table, existing name vs candidate, data type, optional/required, length/choices/default, cardinality/cascade, human writer, visibility, audit, source, test and DDS/other solution ownership. Avoid duplicate fields and globally shared option label changes.
2. **New native forms and tabs:** exact business title with the owner's project prefix; explicitly **new form ID** when copying approved standard/OOB form; sections, native controls, subgrids, view/filter, role and app inclusion. Keep original forms and fallback/roles/order intact. A verified inaccessible form/dependency is a scoped blocker, not permission to remove it.
3. **App, views and reporting:** entry table, named landing views, per-persona queues, selected charts, roots/sitemap, metrics and their exact source/formula, published/draft component inclusion if platform requires it. Reuse existing scoped views by identity rather than duplicating.
4. **Portal/HTML and source binding:** one canonical authenticated record context, exact accepted field mapping, safe DTO, customer/worker separation, prepared vs live indicator, rejected foreign-Case and unauthorized medical access. Do not build a live save handler before its field and security contract exist.
5. **Demo data and acceptance:** versioned synthetic record IDs, related Cases/episodes, source provenance/unknown values, approved sample documents and version/page citations, idempotent seed/receipt, permitted test identity/import target, native lifecycle/readback, denial and regression cases. Never seed reused standard tables implicitly or fabricate professional decisions.

Update the existing scenario `spec.md`, `plan.md`, `tasks.md`, `answers.md` and `report-mappings.md` **in the same change** so Copilot does not have to rediscover the schema or find mismatched new tabs later. Link new reference files rather than rewriting immutable historical stories, implementation evidence or unrelated consumer documents. Keep a small document-coverage register showing touched/unchanged files and why.

## Step 3 — Dependency-ordered authoring and safe continuation

| Order | Can proceed after | Do not infer |
|---|---|---|
| A. Source/requirement delta and read-only inventory | Current source access | All business details accepted or tenant schema available |
| B. Reuse-first field/relationship/permission design | A, accepted business semantics | A candidate column exists or a custom table is necessary |
| C. Native dedicated forms, tabs, views/app membership | B, compatible supported form template and authorized native writer | A designer preview equals published/intended-user app access |
| D. Connected portal/HTML and report bindings | B/C, exact authenticated Case/Contact, accepted safe permission scope | A prepared role switch equals a real login or a failed Save succeeded |
| E. Versioned fixture and authorized bounded seed | Approved target, source facts, identity and data/security | Same name means same person; prepared document is signed/received |
| F. Integration and ALM verification | Real metadata and actor, native lifecycle, current published/draft app composition | Local tests replace hosted checks, negative access or applied import |

If B/C/E are blocked, continue independent approved documentation, stable source previews and focused tests without crossing the blocked dependency. State the exact missing owner action and resume condition. A global `BLOCKED` label for a whole project is inaccurate if other workstreams are ready.

## Step 4 — Required Wizard output to user

- A concise matrix: **what already exists** / **new proposals** / **needs business choice** / **blocked native operations** / **ready independent work**.
- A named DDS/FOIA/other-app-specific list of **new forms, tabs, views and fields** with all logical names clearly existing or candidate.
- One dependency-ordered **multi-work-package batch** using only the owner's existing or explicitly assigned H/workload IDs. If none were assigned, ask the authorized allocator; never manufacture an H number.
- Paths to the updated scenario Spec Kit, field dictionary, form/view map, portal binding contract and fixture/tests so the next builder consumes them directly.
- Separate planned/source-prepared/published/intended-user-tested/isolated-import evidence and an exact stop/resume condition for anything requiring new tenant authority.

**Read this gate as mandatory *planning* guidance, not as permission to create, import, publish, grant access, modify shared assets, spend money or turn on an automated controller.** An executable impact analyzer is a future framework candidate and requires its own implementation/testing evidence.
