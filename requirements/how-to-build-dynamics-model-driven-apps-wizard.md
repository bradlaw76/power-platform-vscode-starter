# Dynamics Model-Driven App Wizard (VS Code + Copilot)

Created: 2026-05-29
Scope: Generic wizard playbook (not project-specific)
Audience: Teams that want a guided, question-first process from idea to release

## 0. How This Wizard Works

This document is designed as a facilitation wizard.

- Ask each question block in order.
- Capture answers directly in the response template under each step.
- Do not move to the next step until the exit criteria are met.
- Use Copilot prompts in each step to generate draft artifacts.
- Validate generated output before accepting it.

Wizard outcome:
- A complete, traceable blueprint and implementation path for a model-driven Dynamics app built from VS Code.
- A beginner-usable onboarding path that works in any repository.

Mandatory rule:
- Spec Kit comes first. Do not build tables, forms, views, flows, or solution artifacts until `spec.md`, `plan.md`, and `tasks.md` are complete.

### 0A. End-to-end flow this wizard supports

Use this sequence from first clone to final handoff:

1. Clone repo.
2. Open repo in VS Code.
3. Install required tools and extensions.
4. Validate PAC CLI and prerequisites.
5. Authenticate to Power Platform.
6. Choose/create environment.
7. Answer discovery questions.
8. Generate Spec Kit specification.
9. Create implementation plan.
10. Create task list.
11. Build or modify artifacts.
12. Export and unpack solution.
13. Commit to Git.
14. Pack and import solution.
15. Document finished demo.

Validation checkpoint:
- Pause at each step until validation passes. Do not continue on failed checks.

### 0B. Required discovery questionnaire

Ask and capture these answers before Step 1:

1. What type of demo or app are you building?
2. Is it for Dynamics 365 Sales, Customer Service, Field Service, Contact Center, Power Apps, Power Pages, Copilot Studio, or Dataverse?
3. Who is the target audience?
4. What business problem does it solve?
5. Who are the users?
6. What data tables or entities are needed?
6b. Use standard Dataverse tables (Contact, Account, Case, etc.) or create custom tables? (standard/custom/both)
7. What screens, forms, views, pages, flows, or copilots are needed?
8. What does a successful demo look like?
9. What environment should it be built in?
10. Does it need demo data?
11. Should the output be a managed or unmanaged solution?
12. New solution or use an existing one? (new/existing)
13. New publisher prefix or use an existing one? (new/existing)

Exit criteria:
- All 14 questions answered (1-11 + 6b + 12 + 13).
- Stakeholder confirms the answers are complete enough to draft `spec.md`.
- For Q6b, standard tables have been identified using `docs/standard-dataverse-tables.md` as reference.
- For Q12/Q13, solution name and publisher prefix are validated (script 10-auth-connect.ps1 will verify these exist or guide creation).

Before Step 1:
- Ensure the repo includes a standard bootstrap contract (`scripts/bootstrap/*`, `payloads/*`, `docs/onboarding.md`, `.vscode/extensions.json`).
- Run the new-hire setup path from `how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md` Section 15.

## 1. Wizard Kickoff: Principles and Build Contract

Goal: Establish decision principles before any tables, forms, or flows are created.

Ask the user:
1. What business outcome must this app achieve in one sentence?
2. Who are the primary personas and what decisions do they make?
3. Is this a demo build, production build, or phased demo-to-production?
4. What constraints are mandatory (compliance, security, time, budget)?
5. What quality bar defines success (accuracy, cycle time, adoption)?

Define principle set:
- Principle 1: Business task clarity over technical complexity.
- Principle 2: Dataverse schema first, UI second.
- Principle 3: Least privilege by default.
- Principle 4: Environment-safe configuration (no hard-coded endpoints).
- Principle 5: Traceability from requirement to artifact.

Exit criteria:
- One-page principle charter approved.
- In-scope and out-of-scope boundaries written.

Copilot prompt:
"Create a one-page model-driven app principle charter with scope, non-scope, constraints, and measurable success criteria."

Response template:
- Outcome statement:
- Personas:
- Build type:
- Constraints:
- Success metrics:
- Approved principles:

## 2. Spec Kit Start (Speck Kit) and System Design Intake

Goal: Start the Spec Kit workflow with enough detail to design the system correctly.

Ask the user:
1. What problem statement should seed the feature spec?
2. What business process stages must be represented?
3. What are the required data entities and ownership boundaries?
4. What external systems must integrate and who is source of truth per field?
5. What risks must be designed around from day one?

Required artifacts to create in this step:
- spec.md (feature specification)
- plan.md (implementation and architecture plan)
- tasks.md (ordered execution tasks)

System design outputs:
- Context diagram (actors, systems, boundaries)
- Data model draft (tables, keys, relationships)
- Lifecycle state model (status and transition rules)
- Integration contract map (inputs, outputs, error handling)

Exit criteria:
- spec.md, plan.md, and tasks.md exist and are internally consistent.
- High-risk assumptions are called out explicitly.

Copilot prompts:
"Generate a spec.md for a generic Dynamics model-driven app with personas, workflow stages, constraints, and acceptance criteria."
"Generate a plan.md with architecture, data model, integration approach, security model, and release gates."
"Generate a dependency-ordered tasks.md grouped by schema, app layer, automation, security, and validation."

Response template:
- Spec seed statement:
- Workflow stages:
- Core entities:
- Integrations:
- Critical risks:
- Artifact status (spec/plan/tasks):

## 3. Data Architecture Wizard (Dataverse First)

Goal: Lock schema decisions before UI and automation work.

Ask the user:
1. Which tables are system-of-record entities vs reference entities?
2. What columns are required at creation time?
3. What lifecycle states need status and status reason?
4. Which relationships are required and what cascade behavior is expected?
5. What audit and retention fields are mandatory?
6. Which shared source-tagging field (for example `demo_datacustomerapplication`) must be present on every app table and demo seed row?

Build decisions:
- Naming convention (publisher prefix, schema style, relationship naming).
- Parent-before-child creation order.
- Required vs optional field policy.
- Data classification per table.

Exit criteria:
- Table catalog with required columns completed.
- Relationship map approved.
- State transition table defined.

Copilot prompt:
"Create a Dataverse schema checklist with table definitions, required columns, relationships, status model, validation rules, and audit metadata."

Response template:
- Table catalog:
- Required columns:
- Relationship map:
- Status model:
- Data classification:

## 4. App Experience Wizard (Model-Driven Layer)

Goal: Convert approved schema into task-oriented app navigation and record experiences.

Ask the user:
1. What are the top 3 user tasks by frequency?
2. Which records need quick create versus full form?
3. What views represent work queues and approvals?
4. What dashboard metrics are needed for daily operations?
5. What accessibility requirements must be enforced?

Build decisions:
- Sitemap areas aligned to business workflow.
- Form density and sectioning strategy.
- View filters for triage behavior.
- Chart/dashboard baseline KPIs.
- Starter form source strategy: payload-driven fields from `columns-*.json` plus primary name field first.
- Label strategy: payload `DisplayName.LocalizedLabels` first; friendly logical-name fallback if labels are missing.
- Rerun behavior: patch Starter Main Form, preserve non-starter Main forms.

Exit criteria:
- Sitemap draft approved.
- Forms/views matrix complete.
- Dashboard metric list signed off.
- Form label behavior documented for create and rerun scenarios.

Copilot prompt:
"Draft a model-driven app sitemap and forms/views matrix aligned to task-centric workflows, including accessibility checkpoints."

Response template:
- Top tasks:
- Sitemap sections:
- Forms matrix:
- Views matrix:
- Dashboard KPIs:

## 5. Automation and Integration Wizard

Goal: Place logic in the correct layer and define safe integration behavior.

Ask the user:
1. Which rules are simple UI/data validation versus orchestration?
2. Which flows are synchronous and which are asynchronous?
3. What retry policy and idempotency key strategy is required?
4. How should failures be surfaced to users and operators?
5. What correlation ID strategy will be used across systems?

Build decisions:
- Business Rules for deterministic local logic.
- Power Automate for orchestration and integration.
- Plug-ins only for advanced transactional behavior.

Exit criteria:
- Logic placement matrix approved.
- Flow catalog with trigger/action/error path completed.
- Integration error taxonomy documented.

Copilot prompt:
"Generate a logic placement matrix and Power Automate flow catalog with retries, idempotency, correlation IDs, and failure handling paths."

Response template:
- Logic placement matrix:
- Flow catalog:
- Retry/idempotency strategy:
- Error taxonomy:
- Monitoring signals:

## 6. Security, Compliance, and Governance Wizard

Goal: Ensure the app is safe and policy-aligned before release planning.

Ask the user:
1. Which personas need create/read/update/delete privileges by table?
2. What sensitive data exists and how is it protected?
3. Which DLP policies affect required connectors?
4. What audit events must be retained and for how long?
5. What production hardening items are deferred and why?

Build decisions:
- Persona-to-privilege matrix.
- Sensitive field handling (masking, restricted visibility).
- Auditing scope and retention.

Exit criteria:
- Role matrix approved with least-privilege checks.
- DLP and connector policy fit confirmed.
- Compliance exceptions documented with owner and due date.

Copilot prompt:
"Create a security and compliance checklist for a model-driven app with least-privilege role matrix, DLP checks, audit scope, and deferred hardening log."

Response template:
- Role matrix:
- Sensitive data controls:
- DLP decisions:
- Audit policy:
- Deferred hardening items:

## 7. ALM and Environment Wizard

Goal: Make deployment repeatable, reversible, and environment-safe.

Ask the user:
1. What are dev, test, and prod environment boundaries?
2. Managed versus unmanaged solution strategy by stage?
3. Which environment variables and connection references are required?
4. What validation gates must pass before promotion?
5. What rollback condition and backout procedure is required?

Build decisions:
- Versioning model.
- Promotion gates.
- Smoke test set.
- Rollback triggers.

Exit criteria:
- ALM workflow documented end to end.
- Pipeline quality gates listed.
- Rollback runbook approved.

Copilot prompt:
"Generate an ALM release checklist for Dynamics model-driven apps including versioning, gate checks, environment variables, connection references, smoke tests, and rollback criteria."

Response template:
- Environment strategy:
- Versioning model:
- Promotion gates:
- Variables and references:
- Rollback runbook summary:

## 8. Validation Wizard (Functional + Operational)

Goal: Confirm the solution works for users and operators under realistic conditions.

Ask the user:
1. What are must-pass end-to-end scenarios?
2. What negative-path and permission-denied tests are required?
3. What performance thresholds are required for forms and views?
4. Which operational alerts are required for flow/integration failures?
5. What evidence must be retained for release sign-off?

## 9. AI Next Best Action Wizard (Case Form)

Goal: Generate a reliable AI summary and next best action on the case form using existing Dataverse fields.

Ask the user:
1. Which exact existing fields will feed the prompt?
2. What output format is required (JSON strongly recommended)?
3. Which case field will store rendered output?
4. Should output be plain text, HTML, or both?
5. What backfill strategy is required for existing records?

Recommended minimal field set:
- `cfd_processstage`
- `cfd_dockettype`
- `cfd_nodtimelinessstatus`
- `cfd_evidencewindowenddate`
- `cfd_bvadecisionoutcome`

Build decisions:
- Use AI Builder custom prompt with JSON-only output.
- Parse output with `Parse JSON` before writing fields.
- Use trigger filter columns to prevent update loops.
- Render HTML in `cfd_recommendednextaction` and optionally present through an HTML web resource.

Exit criteria:
- Prompt returns valid JSON for positive and missing-data paths.
- Flow writes the parsed result to the target case field.
- Form renders output correctly via rich text field or web resource.
- Backfill run has completed for existing records.

Copilot prompt:
"Generate a Power Automate implementation checklist for AI Next Best Action on a Dataverse case table using five existing fields, JSON output parsing, and HTML rendering."

Response template:
- Prompt name:
- Input fields:
- JSON schema:
- Flow name:
- Trigger filter columns:
- Target output field:
- Backfill plan:

Build decisions:
- Test scenario catalog by risk area.
- Evidence format (logs, screenshots, timestamps, defect notes).
- Sign-off owners and sequence.

Exit criteria:
- Validation evidence package complete.
- Defects triaged and dispositioned.
- Release sign-off recorded.

Copilot prompt:
"Generate a validation suite for a model-driven app that includes happy paths, negative paths, role boundary tests, integration failures, and release evidence requirements."

Response template:
- E2E scenarios:
- Negative tests:
- Performance checks:
- Operational alerts:
- Sign-off evidence:

## 9. Release and Handoff Wizard

Goal: Complete production-ready handoff with ownership clarity.

Ask the user:
1. Who owns post-release monitoring and support?
2. What known gaps remain and what are target dates?
3. What training or enablement is required for users/admins?
4. What metrics will be reviewed in week 1 and month 1?
5. What is the first improvement backlog after go-live?

Exit criteria:
- Release notes published.
- Ownership matrix published.
- Improvement backlog seeded.

Copilot prompt:
"Create release notes and handoff pack for a model-driven app including support ownership, known gaps, success metrics, and first-iteration improvement backlog."

Response template:
- Support owners:
- Known gaps and target dates:
- Training plan:
- Success metric review cadence:
- Improvement backlog:

## 10. End-to-End Wizard Checklist

- [ ] Principles and scope charter approved
- [ ] Spec Kit artifacts created (spec.md, plan.md, tasks.md)
- [ ] Dataverse schema and lifecycle model locked
- [ ] Sitemap/forms/views defined for core tasks
- [ ] Automation and integration contracts documented
- [ ] Security, DLP, and audit baseline approved
- [ ] ALM gates and rollback runbook finalized
- [ ] Validation evidence package complete
- [ ] Release and handoff artifacts published

## 11. Fast-Start Session Script (Facilitator Use)

Use this script to run a live wizard session in VS Code:

1. Start with Section 1 and collect principles before discussing implementation.
2. Complete Section 2 and create Spec Kit artifacts before metadata changes.
3. Lock Section 3 outputs before building forms or flows.
4. Complete Sections 4-7 to design app, logic, security, and ALM.
5. Use Section 8 to collect release evidence.
6. Close with Section 9 handoff and Section 10 checklist.

Session rule:
- If any exit criteria fails, pause progression and resolve gaps before advancing.

## 12. Git Install and Update (Workspace Setup Add-On)

Use this add-on when the team needs repeatable source-control setup in a new machine or repo clone.

### Install Git (Windows)

1. Install Git from https://git-scm.com/download/win.
2. Verify installation:

```powershell
git --version
```

### Initial Git Identity

Run once per machine:

```powershell
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### Connect Local Repo to Remote

Run from the repository root:

```powershell
git remote add origin <REMOTE_URL>
git branch -M main
git push -u origin main
```

If `origin` already exists, update it:

```powershell
git remote set-url origin <REMOTE_URL>
```

### Safe Update Flow (Pull Latest)

Use this sequence to avoid overwriting local work:

```powershell
git status -sb
git fetch origin
git pull --ff-only origin <BRANCH_NAME>
```

If local changes block pull, stash first:

```powershell
git stash push -u -m "temp before pull"
git pull --ff-only origin <BRANCH_NAME>
git stash pop
```

### Submodule/Nested Repo Check

If a nested folder is tracked as a separate git repo, update it explicitly:

```powershell
git -C <NESTED_REPO_PATH> status -sb
git -C <NESTED_REPO_PATH> fetch origin
git -C <NESTED_REPO_PATH> pull --ff-only origin <BRANCH_NAME>
```

Exit criteria:
- Git is installed and version check passes.
- Local repo has a valid `origin` remote.
- Pull completes with `--ff-only` on target branch.
- Any nested repo is updated independently when applicable.
