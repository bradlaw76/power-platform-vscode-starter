# How to Build Dynamics Model-Driven Apps in VS Code with Copilot

Created: 2026-05-28
Scope: Generic guide (not project-specific)
Audience: Builders using Dynamics 365, Dataverse, VS Code, and Copilot

Companion wizard:

- Use `how-to-build-dynamics-model-driven-apps-wizard.md` when you want a
  guided, question-by-question process that walks users from principles and
  Spec Kit setup through design, build, validation, and handoff.

### Reporting selection

At report scoping, ask whether to include native dashboards (standard Dataverse
chart/dashboard components), custom HTML reports, both, or neither. Demo Builder
includes the choice in its existing consolidated confirmation, not another
mandatory business question. Explain audience, decision, metrics, record scope,
placement, limitations, and overlap; use both only for complementary tasks.
HTML reports must follow the end user's scenario spec/plan and report mappings,
not a fixed set of generic KPIs. Review and explicitly approve
`html-reports.json` with current requirement excerpts before generation.
Frontline/agent, supervisor, and leadership are selectable layout patterns;
generate only approved reports. See
[the reporting runbook](../docs/live-report-web-resources-runbook.md) for
supported queries, approval, legacy migration, and placement verification.

## 0. How to Use This Guide

### Repository updates and traceability

After repository confirmation, use `check-repository-updates.ps1` for cached
local update advice; only explicit `-Fetch` permits network. Terminal startup
does the local check automatically, with `-FetchRepositoryUpdates` and
`-SkipRepositoryUpdateCheck` controls. Review changed-path categories and preserve
unknown relevance. Optional `repo-update-context.json` selections filter advice,
not approvals or module activation. Stage 90 records timestamp/full-commit/
dirty-fingerprint baselines; only Apply archives immutable run provenance.
Resume preserves the original identity. Never auto-pull, tag, adopt updates
or bypass planning/deployment gates. See [repository updates](../docs/repository-updates.md);
the authoritative onboarding build order is unchanged.

- Use Sections 1-6 for initial architecture and app setup.
- Use Sections 7-11 for implementation, security, ALM, and testing.
- Use Sections 12-14 as release gates and handoff criteria.
- Treat this as a baseline playbook and add domain-specific requirements in separate docs.

For this repository, the primary wizard entry is `/power-platform-wizard-init` in Copilot Chat. It guides the choice between chat and terminal intake, preserves the required planning gates, and supports telemetry-based progress monitoring. The direct chat prompt and terminal wizard remain valid alternatives. Use `docs/wizard-walkthrough.html` for the visual end-to-end guide.

Required process gate:

- Spec Kit planning is mandatory before implementation.
- Complete `spec.md`, `plan.md`, and `tasks.md` before running build scripts.
- The [Semantic Field Type Standard](../docs/semantic-field-type-standard.md)
  applies to every Dataverse use case, industry, mode, retrofit and table strategy,
  independently of FAST. Complete/approve `field-type-decisions.json` and matching
  spec/plan rows before columns; select types by meaning, not sample strings.
  Resolve Choice/Lookup, stable options/mappings and separately approved
  categorical text exceptions. Run `14-validate-semantic-fields.ps1` Planning
  before generation, Payload before build and Metadata after relationships and
  before export. Drift stops execution; no legacy bypass, inferred approval or
  implicit destructive migration. Functional surface tests remain required.

### 0A. Beginner first-run flow (clone to demo)

Use this exact sequence for predictable onboarding:

1. Clone repo and open in VS Code.
2. Install required tools and extensions.
3. Validate Power Platform CLI and prerequisites.
4. Authenticate to Azure and Power Platform.
5. Choose/create a Power Platform environment.
6. Answer discovery questions.
7. Create Spec Kit artifacts (`spec.md`, `plan.md`, `tasks.md`).
8. Convert requirements to implementation tasks.
9. Build metadata artifacts (tables, columns, relationships, forms, views).
10. Export and unpack solution.
11. Commit changes to Git.
12. Pack and import solution.
13. Validate imported result.
14. Document final demo and handoff.

Validation checkpoints:

- Stop if any step fails; fix before continuing.
- Do not skip planning artifacts.

### 0B. Wizard discovery modes

Use `demo-builder` by default: ask six business questions plus one consolidated technical recommendation confirmation. Use `advanced-builder` explicitly for the following 11 core questions and technical extension blocks. Use `framework-acceptance` explicitly for authorized-environment, isolation, deterministic-rerun, retention, cleanup-approval, and evidence controls.

Accelerator recommendations remain disabled by default. With explicit
`FAST_ENABLED=true` or `-EnableAcceleratorRecommendations`, offer a preliminary
Evaluate accelerators, Fully Custom, or Prefer FAST reuse preference after mode
selection. It is separate from final approval and does not authorize
deployment. Fully Custom bypasses matching; otherwise reuse the
provider-neutral matcher after normal discovery and before architecture
finalization. Do not ask a FAST-specific business question. Present FAST-based, Hybrid,
and Fully Custom options, require an explicit selection, and record the pinned
snapshot, package hashes, coverage, deltas, readiness, and rationale under
`specs/<slug>/accelerator/`. Do not connect this planning decision to
Dataverse generation or solution import.

Advanced Builder questions:

1. What type of demo or app are you building?
2. Is it for Dynamics 365 Sales, Customer Service, Field Service, Contact Center, Power Apps, Power Pages, Copilot Studio, or Dataverse?
3. Who is the target audience?
4. What business problem does it solve?
5. Who are the users?
6. What data tables or entities are needed?
**6b. Use standard Dataverse tables (Contact, Account, Case, etc.) or create custom tables? (standard/custom/both)**
7. What screens, forms, views, pages, flows, or copilots are needed?
8. What does a successful demo look like?
9. What environment should it be built in?
10. Does it need demo data?
11. Should the output be a managed or unmanaged solution?

Optional extension blocks (profile-driven):
- table-strategy (standard/custom and mapping)
- solution-identity (new/existing solution and publisher prefix)
- reporting (optional web resources)
- retrofit (current-state and remaining-work intake)
- source-control (target-repository preflight, scenario branch, traceability, checkpoint commits, discovered validation/CI, PR handoff, and merge strategy)
- user-tasks (persona, task, frequency, entry table/view, expected outcome, owner, and done definition)
- demo-data (conditional table scope, per-table counts, scenarios/states, hero records, relationship distribution, bounded Task activity generation, method, and privacy constraints; rerun/source-tag/retention/cleanup controls are Framework Acceptance only)

The source-control block applies throughout whatever app or demo the end user is creating. Use `requirements/GithubInstructions_General.md` as the engineering standard. Inspect the target repository before implementation, record the plan in scenario artifacts, commit only coherent validated checkpoints, and reserve approved push/PR verification for handoff.

Why this matters:

- These answers become the source for `spec.md`, then `plan.md`, then `tasks.md`.
- The table-strategy extension ensures you reuse existing standard tables (Contact, Case, Product, etc.) instead of recreating them.
- The solution-identity extension prevents accidental cross-project contamination by requiring explicit solution names and prefixes.
- User-task intake drives task-oriented forms, views, navigation, automation, and validation rather than producing a generic build checklist.
- Relationship intake records cardinality, requiredness, existing/new status, cascade behavior, and the task or surface each relationship supports.
- When demo data is enabled, `demo-data-plan.json` records the approved target tables, counts, hero records and their demo purpose, and bounded Task activity choices. Standard reused tables require an explicit create/reuse decision and are never seeded implicitly. Task activities default to the latest 10 eligible parent records and only target every record when `all` is explicitly approved.
- Demo-data discovery produces a validated `data-*.json` contract. `66-seed-synthetic-data.ps1` executes only approved source-tagged records through stable natural keys and exact lookup resolution.

- Native chart/dashboard definitions use `reporting-*.json` and `64-build-charts-dashboard.ps1`; HTML report web resources remain a separate optional capability.
- Framework Acceptance uses `85-verify-idempotency.ps1` around a controlled second pass and `95-export-unmanaged-solution.ps1` for gated unmanaged export/unpack/inspection. The acceptance package is never imported.
- Reference `docs/standard-dataverse-tables.md` to identify which tables are out-of-box vs. custom.

## 1. What You Are Building

A model-driven app is a Dataverse-first application where:

- Data model drives UI behavior.
- Forms, views, business rules, and processes are generated from schema.
- Security and environment strategy determine operational readiness.

Use this guide for a repeatable build process in VS Code with Copilot support.

## 2. Prerequisites

- Microsoft Power Platform environment with Dataverse enabled.
- Permissions for solution customization and table/app creation.
- VS Code installed.
- Git repository initialized for source control.
- Power Platform CLI installed and authenticated.
- Copilot available in VS Code.

Minimum tooling baseline:

- Power Platform CLI (`pac`) authenticated to target tenant.
- Environment URL and publisher prefix agreed before metadata creation.
- One service account or managed identity strategy documented for automation.

Recommended VS Code extensions:

- GitHub Copilot (`GitHub.copilot`)
- Power Platform Tools (`microsoft-IsvExpTools.powerplatform-vscode`)
- PowerShell (`ms-vscode.powershell`)
- JSON (`ms-vscode.vscode-json`)
- Markdown lint (`DavidAnson.vscode-markdownlint`)

## 2A. First-Time Builder Setup (Day 0)

Use this section for people who are completely new to VS Code and Dynamics app
building.

### Install required tools

Install each tool before running any build scripts.

| Tool | Install command or link |
| --- | --- |
| VS Code | <https://code.visualstudio.com> |
| PowerShell 7+ | `winget install Microsoft.PowerShell` |
| Azure CLI | `winget install Microsoft.AzureCLI` |
| Power Platform CLI | `winget install Microsoft.PowerPlatformCLI` |
| Git | `winget install Git.Git` |

After install, open a new terminal and verify:

```powershell
code --version
az --version
pac --version
pwsh --version
git --version
```

### Sign in to Azure and Dataverse

Run these commands in VS Code's integrated terminal (Ctrl+` to open).

```powershell
# Step 1: Sign in to Azure with your work or school account.
# A browser window will open. Complete sign-in there.
az login --allow-no-subscriptions

# Step 2: Confirm your account is active
az account show

# Step 3: Create a Power Platform auth profile for your target environment.
# Replace the URL with your actual Dataverse environment URL.
pac auth create --url "https://<your-org>.crm.dynamics.com"

# Step 4: Confirm the profile is active (look for the asterisk)
pac auth list

# Step 5: Get a bearer token to use with API scripts.
# The --resource value must EXACTLY match the environment URL (no trailing slash).
$envUrl = "https://<your-org>.crm.dynamics.com"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
```

### Authentication lessons learned

These are real issues encountered during builds. Read before starting.

#### Token URL mismatch (most common error)

- The `--resource` URL passed to `az account get-access-token` must match the
  Dataverse environment URL exactly.
- A trailing slash or wrong subdomain produces a valid-looking token that
  returns 401 on every API call.
- Fix: always copy the URL from Power Platform admin center and strip trailing
  `/`.

#### Two separate auth mechanisms

- `az login` and `pac auth create` are independent. You need both.
- `az login` produces the bearer token used in API scripts.
- `pac auth create` is used by `pac` CLI commands (solution pack, publish,
  etc).
- Confusion here is the number-one onboarding blocker.

#### Token expiry during long runs

- Azure tokens expire after approximately 60-90 minutes.
- If scripts fail mid-run with 401, re-run the token command and re-export
  `$token`.
- Add token refresh at the top of any long-running script.

#### Browser vs device code flow

- `az login` launches a browser by default. On headless servers use:

```powershell
az login --use-device-code
```

- A code is printed. Visit <https://microsoft.com/devicelogin> and enter it.

#### Multiple tenants

- If you have multiple Azure tenants, login may resolve to the wrong one.
- Force a specific tenant:

```powershell
az login --tenant "TENANT_ID_OR_DOMAIN"
```

- Verify you are in the right tenant:

```powershell
az account show --query tenantId -o tsv
```

#### PAC profile points to wrong environment

- Running `pac auth list` shows all profiles. The active one has an asterisk.
- Switch with:

```powershell
pac auth select --index <number>
```

#### MFA / Conditional Access blocking terminal login

- Some tenants block non-interactive auth entirely.
- Workaround: use an application registration with client credentials
  (client ID + secret) for CI scenarios:

```powershell
az login --service-principal -u "<client-id>" -p "<client-secret>" --tenant "<tenant-id>"
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
```

- Never commit client secrets to source control. Use environment variables or a
  secrets manager.

### First environment decisions to record before build

Capture these values in your `docs/onboarding.md` before creating any metadata:

| Decision | Value |
| --- | --- |
| Dataverse environment URL | `https://<your-org>.crm.dynamics.com` |
| Publisher name | e.g. `Contoso` |
| Publisher prefix | e.g. `cto` (3-8 chars, lowercase, no spaces) |
| Solution unique name | e.g. `ContosoHRApp` |
| Solution display name | e.g. `Contoso HR Application` |
| Build mode | Demo / Production / Phased |
| Table naming standard | `<prefix>_<entity>` e.g. `cto_employee` |

Minimum success criteria before continuing:

- You can sign in and retrieve a token without errors.
- `pac auth list` shows your environment with an asterisk.
- `az account show` shows the correct tenant and user.
- You can describe the create order: tables -> columns -> relationships ->
  solution -> forms/views.

## 3. Workspace and Source Strategy

1. Create one repository folder for your model-driven app artifacts.
2. Keep app work in a dedicated solution folder.
3. Separate these document types:
   - Build steps and execution logs
   - Governance and standards
   - Generic reference guides (this file type)
4. Use branch-per-feature naming for clean review and rollback.

Recommended generic structure:

```text
repo-root/
  docs/
    standards/
    runbooks/
  solutions/
    <solution-name>/
      metadata/
      apps/
      flows/
  scripts/
    bootstrap/
    validation/
  requirements/
    generic-guides/
```

## 3A. Cross-Repo Onboarding Contract (Recommended)

To make this process work in any repository, standardize these files and folders in every repo:

```text
repo-root/
  .vscode/
    extensions.json
    settings.json
  scripts/
    bootstrap/
      00-prereq-check.ps1
      10-auth-connect.ps1
      20-build-tables.ps1
      30-build-columns.ps1
      35-style-choice-options.ps1
      40-build-relationships.ps1
      50-add-to-solution.ps1
      60-build-forms-views.ps1
      61-configure-power-apps-grid.ps1
      62-build-app-module.ps1
      63-format-forms.ps1
  schemas/
    payloads/
      choice-presentations.schema.json
      grid-controls.schema.json
      form-layouts.schema.json
  payloads/
    table-*.json
    columns-*.json
    choice-presentations-*.json
    relationships-*.json
  specs/
    <scenario-slug>/
      grid-controls.json
      form-layouts.json
  docs/
    onboarding.md
    build-log.md
```

Why this works across repos:

- New users always find setup scripts in the same location.
- Build order is explicit from script naming.
- Payload-driven metadata keeps app design portable.
- Build logs provide reproducibility and troubleshooting evidence.

Suggested `.vscode/extensions.json` recommendations:

```json
{
  "recommendations": [
    "GitHub.copilot",
    "microsoft-IsvExpTools.powerplatform-vscode",
    "ms-vscode.powershell",
    "ms-vscode.vscode-json",
    "DavidAnson.vscode-markdownlint"
  ]
}
```

## 4. Define the App Blueprint First

Before creating tables, define:

- Business capability scope
- Core user roles
- Data entities and relationships
- Business process stages
- Reporting and audit requirements

Use Copilot to draft:

- Entity list with primary keys and required fields
- State/status model
- Security role matrix outline
- Initial acceptance criteria

Also define non-functional requirements early:

- Data retention and auditing obligations
- Performance targets (for example, form load expectations)
- Accessibility and localization needs
- Recovery and rollback expectations

## 5. Build the Dataverse Data Model

1. Create core tables in dependency order (parent before child).
2. Add columns with clear naming, types, and required constraints.
3. Define relationships (1:N, N:1, N:N) intentionally.
4. Add status and reason fields for operational state tracking.
5. Add audit-friendly columns where needed (owner, created on, modified on, source).

Copilot prompt pattern:

- Ask Copilot to generate a table definition checklist including:
  - Column names
  - Data types
  - Required/optional
  - Validation rules
  - Relationship targets

Naming standard baseline (generic):

- Publisher prefix on all custom tables/columns.
- Singular table names and explicit relationship names.
- Separate display label from schema name decisions.
- Reserve state/status choices for lifecycle transitions only.

## 5A. Reusable API-First Bootstrap (VS Code)

Use this when you want a repeatable, scriptable bootstrap before opening Maker UI:

1. Store table payloads as JSON files.
2. Store column payloads as JSON files.
3. Run scripts from VS Code terminal with environment URL + access token.
4. Keep scripts idempotent (skip existing metadata) so reruns are safe.

Reusable command pattern:

```powershell
$envUrl = "https://yourorg.crm.dynamics.com"
az login --allow-no-subscriptions
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv

# Example script calls
pwsh ./scripts/start-dataverse-build.ps1 -EnvironmentUrl $envUrl -AccessToken $token
pwsh ./scripts/add-dataverse-columns.ps1 -EnvironmentUrl $envUrl -AccessToken $token
```

Recommended payload split:

- `table-*.json` for entity metadata
- `columns-*.json` for attribute metadata
- `relationships-*.json` for relationship definitions

Validation additions:

- Lint payloads before execution.
- Record every create/update response in a build log.
- Fail fast when required metadata dependencies are missing.

## 5B. First Build Runbook (Tables, Columns, Forms, Views)

Use this copy/paste flow for first-time builders after setup is complete.

```powershell
$envUrl = "https://<your-org>.crm.dynamics.com"
$solutionUniqueName = "<YourSolutionUniqueName>"

az login --allow-no-subscriptions
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv

# 1) Create tables
pwsh ./scripts/bootstrap/20-build-tables.ps1 -EnvironmentUrl $envUrl -AccessToken $token

# 2) Create columns
pwsh ./scripts/bootstrap/30-build-columns.ps1 -EnvironmentUrl $envUrl -AccessToken $token

# Optional: preview pastel colors and inline Choice-label icons, then apply the approved hash
pwsh ./scripts/bootstrap/35-style-choice-options.ps1 -ScenarioSlug <scenario-slug> -PreviewOnly
# pwsh ./scripts/bootstrap/35-style-choice-options.ps1 -ScenarioSlug <scenario-slug> -ApprovedPlanHash <sha256>

# 3) Create relationships
pwsh ./scripts/bootstrap/40-build-relationships.ps1 -EnvironmentUrl $envUrl -AccessToken $token

# 4) Add metadata to solution
pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -EnvironmentUrl $envUrl -AccessToken $token -SolutionUniqueName $solutionUniqueName

# 5) Build forms and views
pwsh ./scripts/bootstrap/60-build-forms-views.ps1 -EnvironmentUrl $envUrl -AccessToken $token

# Optional modern table grid contract: handoff first, verify after maker publish
pwsh ./scripts/bootstrap/61-configure-power-apps-grid.ps1 -ScenarioSlug <scenario-slug> -Mode Preview
pwsh ./scripts/bootstrap/61-configure-power-apps-grid.ps1 -ScenarioSlug <scenario-slug> -Mode Verify

# 6) Assemble or update the model-driven app
pwsh ./scripts/bootstrap/62-build-app-module.ps1 -ScenarioSlug <scenario-slug>

# 7) After app assembly, optionally preview a scenario form layout
pwsh ./scripts/bootstrap/63-format-forms.ps1 -ScenarioSlug <scenario-slug> -Mode Preview
# Apply only after approving the emitted SHA-256 hash:
# pwsh ./scripts/bootstrap/63-format-forms.ps1 -ScenarioSlug <scenario-slug> -Mode Apply -ApprovedPlanHash <sha256>
```

Expected output per step:

- Created count, skipped count, failed count
- List of affected tables/forms/views
- Clear non-zero exit code on failure
- Build-log entry in `docs/build-log.md`

Script 60 behavior baseline:

- Build Starter Main Forms from `columns-*.json` payloads for payload-defined custom entities.
- Place the primary name field first, then payload-defined fields in payload order.
- Use field labels from payload `DisplayName.LocalizedLabels` (1033 first, then first available).
- If payload labels are missing, derive friendly labels from logical names (remove prefix, replace underscores, title case).
- Patch existing Starter Main Form XML on rerun when payload labels/fields change.
- Do not overwrite non-starter Main forms.
- Publish customizations after create/update.
- Report script 60 counts as: forms created, forms updated, forms skipped, views created, failures.

Optional form formatting Version 1 reads
`specs/<scenario-slug>/form-layouts.json`, validates it against
`schemas/payloads/form-layouts.schema.json`, and runs only after app assembly.
It supports tabs, sections, one- to three-column layouts, and existing
baseline controls/fields on active, customizable, wizard-owned custom Main
forms. Preview emits artifacts and a SHA-256 plan hash; Apply requires that
exact hash. `90-run-build.ps1` enables the stage when the contract exists,
lists the target in credential-free Preview, and requires
`-ApprovedFormFormattingPlanHash` for Apply. Boolean Toggle components and
Choice OptionSet Wrapper components are type-checked and configured for web,
tablet, and phone. Other components and OOB forms are deferred. Anthropic's official `frontend-design` skill is optional advice
only and is not installed.

If your repo already has differently named scripts:

- Keep the same execution order.
- Add wrappers in `scripts/bootstrap/` so beginners always run a consistent command set.

## 6. Create the Model-Driven App Layer

1. Create or open your solution.
2. Create a model-driven app shell.
3. Add sitemap/navigation areas by business workflow.
4. Attach forms and views to each table.
5. Configure quick create forms for high-frequency records.
6. Add charts/dashboards for operational visibility.

Design guidance:

- Keep top-level navigation aligned to business tasks.
- Prefer task-centric forms over field-dense forms.
- Use views for queue/triage behavior.
- Keep command bar customization minimal until core flows are stable.

## 7. Add Business Logic

Implement logic in this order:

1. Column-level validation
2. Business rules
3. Business process flows
4. Power Automate flows
5. Optional plug-ins/custom code

Keep logic placement consistent:

- Simple deterministic UI/data rules in Business Rules.
- Multi-step orchestration and integration in Power Automate.
- Advanced transactional logic in plug-ins when required.

Automation quality baseline:

- Define retry policy and idempotency keys for integration flows.
- Separate synchronous user-facing logic from asynchronous background processing.
- Track flow ownership and alert targets.

## 7A. Integration Design (Generic)

When integrating with external systems:

1. Define source-of-truth per business field.
2. Standardize request/response contracts and error codes.
3. Add dead-letter or retry queues for non-transient failures.
4. Log correlation IDs across systems for diagnostics.
5. Document data mapping and transformation rules.

## 8. Security and Access Model

1. Define app personas (for example: Operator, Reviewer, Admin).
2. Map required table privileges per persona.
3. Assign app access and role-based visibility.
4. Validate least-privilege behavior with test users.

For demo builds:

- Use simplified roles.
- Document deferred production hardening items explicitly.

## 8A. Compliance and Governance Baseline

- Define data classification for each table (public, internal, sensitive).
- Configure DLP policy alignment for Power Platform connectors.
- Enable auditing for critical create/update/delete operations.
- Document PII handling, masking, and retention decisions.
- Validate environment-level security settings before release.

## 9. Environment and ALM Workflow

1. Build in a dedicated dev environment.
2. Export/import as managed or unmanaged based on stage.
3. Promote through test and production environments.
4. Track solution versioning and release notes.
5. Store configuration differences by environment.

Recommended pipeline quality gates:

- Solution unpack/pack validation.
- Static checks (including solution checker where applicable).
- Environment variable and connection reference validation.
- Import smoke test in a clean validation environment.

Minimum ALM checkpoints:

- Solution version increment
- Schema migration impact check
- Security regression check
- Integration endpoint validation

## 10. Copilot-Driven Working Pattern in VS Code

Use Copilot for:

- Schema draft generation
- Validation checklist creation
- Documentation synthesis
- Test scenario writing
- Refactoring long markdown and config files

Best prompt pattern:

1. State the exact artifact to create.
2. Give constraints (demo vs production, required sections).
3. Require explicit acceptance criteria.
4. Ask for output in reusable checklist/table format.

Quality guardrails:

- Never accept generated output without source validation.
- Keep one requirement-to-artifact trace path.
- Record rationale for architectural choices.

Prompt templates that scale:

1. "Generate a Dataverse table definition checklist for [domain], include
  required fields, relationships, and lifecycle states."
2. "Create validation scenarios for [feature] covering happy path, permission
  denial, and integration failure."
3. "Draft a release checklist for model-driven app changes with rollback criteria and owner per gate."

## 10A. Reusable KB Article + PDF Workflow (For Future Repos)

Use this pattern when you need to consolidate source material (including
extracted PDF content) into one shareable knowledge-base article.

Recommended structure:

```text
repo-root/
  Knowledge/
    _extracted/
      combined.txt
  docs/
    <topic>-knowledge-base-<year>.html
    <topic>-knowledge-base-<year>.pdf
```

Execution sequence:

1. Consolidate source inputs.

- Gather extracted text from PDFs and any supplemental source notes.
- Normalize into one canonical file, for example `Knowledge/_extracted/combined.txt`.

1. Draft or generate the KB article.

- Create a human-readable article in `docs/` as HTML or Markdown.
- Prefer a stable naming pattern such as `<topic>-knowledge-base-<year>.html`.

1. Export a shareable PDF.

- Use a headless browser export to avoid LaTeX dependencies.
- Keep output next to the article source for easy handoff.

Reusable PowerShell command pattern:

```powershell
$html = "./docs/<topic>-knowledge-base-<year>.html"
$pdf = "./docs/<topic>-knowledge-base-<year>.pdf"
$edge = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
$uri = (New-Object System.Uri((Resolve-Path $html).Path)).AbsoluteUri

& $edge --headless --disable-gpu --print-to-pdf="$pdf" "$uri"
```

1. Verify output and publish reference links.

- Confirm file exists, size is non-zero, and timestamp is current.
- Add links to both HTML and PDF artifacts in the repo's primary README or
  docs index.

Verification snippet:

```powershell
Get-Item "./docs/<topic>-knowledge-base-<year>.pdf" |
  Select-Object FullName, Length, LastWriteTime
```

Quality guardrails:

- Keep a single canonical combined source file to reduce drift.
- Regenerate PDF after each substantive KB content update.
- Treat HTML as source-of-truth and PDF as distribution artifact.
- Use consistent naming and storage paths across repos to simplify automation.

## 11. Testing and Validation

Run validation in layers:

1. Data model integrity (required fields, relationships, status transitions)
2. Form/view usability (task completion time, error clarity)
3. Security behavior (access boundaries)
4. Process automation outcomes
5. Integration reliability

Include one timed reviewer scenario for practical usability validation.

Add these test dimensions:

- Accessibility checks for forms and navigation.
- Performance checks for high-volume views.
- Regression checks for role-based visibility after schema changes.
- Negative-path tests for failed automation and retry behavior.

Evidence expectations:

- Keep test logs, screenshots, and defect disposition notes per release.

## 12. Common Pitfalls and How to Avoid Them

- Pitfall: Building UI before schema stabilizes.
  - Fix: Freeze core entity model first.

- Pitfall: Mixing demo shortcuts with production requirements.
  - Fix: Maintain explicit demo-vs-production sections.

- Pitfall: Overusing automation for simple rules.
  - Fix: Keep simple logic in business rules; orchestrations in flows.

- Pitfall: Weak naming conventions.
  - Fix: Enforce table/column/status naming standards early.

- Pitfall: Missing traceability.
  - Fix: Keep requirement-to-artifact mapping current every sprint.

- Pitfall: Hard-coding environment-specific values.
  - Fix: Use environment variables and connection references consistently.

- Pitfall: Weak rollback readiness.
  - Fix: Define backout criteria and rehearse import rollback steps.

## 13. Definition of Done (Generic)

A model-driven app increment is done when:

- Data model changes are applied and validated.
- Forms/views/navigation support target user tasks.
- Security is tested for in-scope personas.
- Automation behaves correctly for defined scenarios.
- Documentation and build steps are updated.
- Known gaps are logged with owner and target date.
- Telemetry/diagnostic signals are in place for key failures.
- Rollback path is documented and verified.

## 14. Reusable Build Checklist

- [ ] Discovery questions completed and approved
- [ ] Spec Kit artifacts complete (`spec.md`, `plan.md`, `tasks.md`)
- [ ] Scope and personas confirmed
- [ ] Core entities and relationships finalized
- [ ] App shell and sitemap configured
- [ ] Forms and views completed
- [ ] Business rules and flows implemented
- [ ] Security roles applied and tested
- [ ] Validation scenarios executed
- [ ] Solution exported and unpacked for source control
- [ ] Git branch/commit/push completed
- [ ] Solution packed and imported into target environment
- [ ] KB article generated from combined source and exported as PDF
- [ ] Build and release notes documented
- [ ] Demo vs production gaps documented
- [ ] Handoff artifacts completed
- [ ] Environment variables and connection references validated
- [ ] Compliance/DLP requirements confirmed
- [ ] Rollback plan documented
- [ ] Post-release monitoring owners assigned

## 15. New-Hire Quick Start (60-Minute Path)

Use this path to onboard someone with no VS Code or Dynamics build experience.

1. Install and validate tools

- Install VS Code, Power Platform Tools, and PowerShell extension.
- Confirm `az`, `pac`, and `pwsh` are available in terminal.

1. Clone repo and open in VS Code

- Open the repo root.
- Accept extension recommendations.
- Review `docs/onboarding.md` if present.

1. Authenticate once

- Run Azure sign-in and Power Platform auth profile creation.
- Validate target Dataverse environment URL.

1. Complete planning before implementation (required)

- Answer discovery questions for scenario, users, data, and success criteria.
- Create `spec.md`, `plan.md`, and `tasks.md`.

1. Run bootstrap in order

- `00-prereq-check.ps1`
- `10-auth-connect.ps1`
- `20-build-tables.ps1`
- `30-build-columns.ps1`
- Optional `35-style-choice-options.ps1` when `choice-presentations-*.json` exists
- `40-build-relationships.ps1`
- `50-add-to-solution.ps1`
- `60-build-forms-views.ps1`
- Optional `61-configure-power-apps-grid.ps1` when `grid-controls.json` exists
- `62-build-app-module.ps1`
- Optional `63-format-forms.ps1` when `form-layouts.json` exists

1. Validate in Maker experience

- Verify tables exist.
- Verify forms and views are attached.
- Verify model-driven app shell navigation renders expected tables.

1. Export/unpack and commit

- Export solution zip and unpack to source files.
- Commit unpacked changes to a feature branch and push.

1. Pack/import and validate

- Pack solution from source files.
- Import into target environment.
- Validate required scenarios.

1. Capture evidence

- Add results to `docs/build-log.md`.
- Record blockers and remediation actions.
- Create handoff note with environment, branch, and artifact list.
The table-level Power Apps grid is a separate experience gate from form layout
and subgrids. Views do not automatically guarantee OneGrid. Stage 61 runs after
step 60 and before reporting/app assembly: Preview explains the supported
classic solution explorer all-views setup (including explicit editing), and
Verify checks exported metadata for
`Microsoft.PowerApps.PowerAppsOneGrid` and declared properties. It never
mutates internal metadata or import XML. Subgrid support is deferred. See
[Microsoft Learn](https://learn.microsoft.com/power-apps/maker/model-driven-apps/the-power-apps-grid-control).

### Approved accelerator build planning

An explicitly approved FAST-based, Hybrid, or Fully Custom decision can be
translated by the default-off FAST-006 standalone planner. Treat its output as
a reviewable dry run only: it cannot authorize execution or connect to
Dataverse/build stages. Preserve managed ownership and keep Fully Custom free
of accelerator dependencies.

### Execution readiness and trusted verification (FAST-007 / FAST-008A)

After approval and dry-run planning, explicitly opt in with
`scripts/accelerators/invoke-execution-readiness.ps1
-EnableExecutionReadiness -ScenarioSlug -EvidencePath -EnvironmentUrl
-EnvironmentId -TenantId`; optional `-WorkspaceRoot`, `-OutputFolder`, and
`-EvaluationTimeUtc` select workspace, output, and a deterministic clock.
Validate the
scenario's approved decision and build-plan manifest, file SHA-256, canonical
decision/plan IDs, and input fingerprints. Externally supplied local evidence
must satisfy `execution-evidence.schema.json`, match the complete independently
supplied target triple exactly (URL normalized), and have a hard maximum
lifetime of 24 hours. FAST-008A now requires signed
`trusted-environment-verification.schema.json` envelopes for default
`-EvidenceTrustPolicy Authenticated`, with normalized execution-evidence v1.
Supply `-TrustedCertificatePath` independently (public X509 certificate);
never trust an embedded key. The certificate must be valid at collection
and evaluation. Only complete matching signed Live evidence can establish
`verifiedForHumanReview: true`. Explicit `RecordedTest` permits signed Mock
evidence to reach READY_FOR_APPROVAL; explicit `LocalPlanning` preserves raw
FAST-007 diagnostics. Both always report `verifiedForHumanReview: false`;
all policies preserve `executionAuthorized: false`.

The schema-valid `execution-readiness.json` reports `READY_FOR_APPROVAL`,
`BLOCKED_PREREQUISITES`, `BLOCKED_EVIDENCE`, `BLOCKED_COMPATIBILITY`,
`BLOCKED_SECURITY`, or `BLOCKED_DECISION_CHANGE`. Ready means human review only:
`executionAuthorized` is always false. Scope SHA-256 binds decision, plan,
evidence, inputs, and target. `build-authorization.schema.json` is future-only;
never generate or consume approval or authorization records.

The orchestrator's `-ExecutionReadinessOnly -ExecutionEvidencePath` path
requires `-ReadinessEnvironmentId -ReadinessTenantId`, accepts optional
`-ReadinessEvaluationTimeUtc`, forwards `-ReadinessEvidenceTrustPolicy` and
`-ReadinessTrustedCertificatePath`, and returns before helpers/stages/payload
requirements. Combining it with Apply is forbidden. Approved
`fast-based`/`hybrid` decisions block normal Apply regardless of readiness;
legacy/Fully Custom normal builds and all modes' default-off behavior remain
unchanged. No Dataverse/PAC/network/authentication/install/import/build
execution occurs in readiness itself. See
[FAST-007 operations](../docs/fast-integration/execution-readiness.md).

FAST-008A's separately opted-in GET-only collector reuses the inspector/shared
Dataverse runtime. `trustedEnvironmentVerification` defaults false. Collection
defaults Mock with injected test transport; Live rejects injected transport and
requires explicit target/solution, read-only confirmation, existing credentials,
and an external X509 signing certificate. There is no `.env` target fallback or
credential persistence; no live GCC query is authorized by this mock-only
milestone. RetrieveCurrentOrganization supplies actual EnvironmentId/TenantId;
WhoAmI OrganizationId/UserId are distinct, unlike legacy FAST-003 environmentId.
Reuse package/dependency checks, managed properties, publisher/membership and
effective privileges by name. Initial concrete support is tables/columns;
unsupported descriptive identities remain unverified/blocked. Future CREATE
ownership is inferred, not observed. RS256 binds decision bytes, plan/catalog/
dependency/input/package hashes, actual identity, collection mode and expiry.
Signatures prove collector authority, not truth against a compromised signer
or deployment approval. See
[trusted verification](../docs/fast-integration/trusted-environment-verification.md).
Future controlled execution, independent deployment approver/signature checks,
scoped authorization consumption/revalidation and a separately approved
executor remain proposed and unauthorized.
