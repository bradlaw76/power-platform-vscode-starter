# How to Build Dynamics Model-Driven Apps in VS Code with Copilot

Created: 2026-05-28
Scope: Generic guide (not project-specific)
Audience: Builders using Dynamics 365, Dataverse, VS Code, and Copilot

Companion wizard:

- Use `how-to-build-dynamics-model-driven-apps-wizard.md` when you want a
  guided, question-by-question process that walks users from principles and
  Spec Kit setup through design, build, validation, and handoff.

## 0. How to Use This Guide

- Use Sections 1-6 for initial architecture and app setup.
- Use Sections 7-11 for implementation, security, ALM, and testing.
- Use Sections 12-14 as release gates and handoff criteria.
- Treat this as a baseline playbook and add domain-specific requirements in separate docs.

Required process gate:

- Spec Kit planning is mandatory before implementation.
- Complete `spec.md`, `plan.md`, and `tasks.md` before running build scripts.

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

### 0B. Wizard discovery questions (11 required + extension blocks)

Answer these before writing or changing metadata:

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

Why this matters:

- These answers become the source for `spec.md`, then `plan.md`, then `tasks.md`.
- The table-strategy extension ensures you reuse existing standard tables (Contact, Case, Product, etc.) instead of recreating them.
- The solution-identity extension prevents accidental cross-project contamination by requiring explicit solution names and prefixes.
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
      40-build-relationships.ps1
      50-add-to-solution.ps1
      60-build-forms-views.ps1
  payloads/
    table-*.json
    columns-*.json
    relationships-*.json
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

# 3) Create relationships
pwsh ./scripts/bootstrap/40-build-relationships.ps1 -EnvironmentUrl $envUrl -AccessToken $token

# 4) Add metadata to solution
pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -EnvironmentUrl $envUrl -AccessToken $token -SolutionUniqueName $solutionUniqueName

# 5) Build forms and views
pwsh ./scripts/bootstrap/60-build-forms-views.ps1 -EnvironmentUrl $envUrl -AccessToken $token
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
- `40-build-relationships.ps1`
- `50-add-to-solution.ps1`
- `60-build-forms-views.ps1`

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
