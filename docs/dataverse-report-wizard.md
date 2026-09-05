# Dataverse Report Wizard

Create native Dataverse charts and dashboards for Dynamics 365 and Power Apps
model-driven apps from Visual Studio Code.

[Return to the Power Platform VS Code Starter overview](../README.md).

`power-platform-vscode-starter` is the canonical implementation of this
wizard. The reporting workload reuses the starter repository's authentication,
Dataverse runtime, solution, app-module, publishing, schema, and CI
capabilities rather than maintaining a separate runtime.

The repository provides:

- a conversational skill for GitHub Copilot and Claude Code;
- an interactive PowerShell wizard;
- live Dataverse metadata discovery;
- natural-language report recommendations;
- FetchXML preview before deployment;
- native Dataverse chart and dashboard generation;
- solution registration and model-driven app attachment; and
- credential-free simulation and automated tests.

## Contents

- [How it works](#how-it-works)
- [Full app-builder compatibility](#full-app-builder-compatibility)
- [Before you begin](#before-you-begin)
- [Clone and open the repository](#clone-and-open-the-repository)
- [Install prerequisites](#install-prerequisites)
- [Start with GitHub Copilot](#start-with-github-copilot)
- [Start with Claude Code](#start-with-claude-code)
- [Run the wizard directly](#run-the-wizard-directly)
- [Recommended first run: simulation](#recommended-first-run-simulation)
- [Create a live report preview](#create-a-live-report-preview)
- [Review generated artifacts](#review-generated-artifacts)
- [Deploy an approved report](#deploy-an-approved-report)
- [Wizard questions](#wizard-questions)
- [Natural-language recommendations](#natural-language-recommendations)
- [Supported report features](#supported-report-features)
- [Noninteractive and CI usage](#noninteractive-and-ci-usage)
- [Repository structure](#repository-structure)
- [Security and safety](#security-and-safety)
- [Troubleshooting](#troubleshooting)
- [Validation](#validation)
- [Current limitations](#current-limitations)
- [Contributing](#contributing)

## How it works

The skill and wizard have different responsibilities:

```text
GitHub Copilot or Claude skill
    Guides intake, preview, approval, and safe execution
                         |
                         v
PowerShell report wizard
    Authenticates, discovers metadata, validates, and generates artifacts
                         |
                         v
Reporting payload and FetchXML preview
    Reviewable and source-control-friendly report definition
                         |
             explicit approval required
                         |
                         v
Dataverse deployment runtime
    Creates or updates charts and dashboard, adds them to the solution,
    attaches them to the selected model-driven app, and publishes the app
```

The skill does not contain the Dataverse implementation. The PowerShell runtime
does not replace the conversational guidance and approval gates. They are
designed to be used together, but the wizard can also run directly.

## Full app-builder compatibility

This repository also retains the broader Power Platform app-building wizard.
Use `/power-platform-wizard-init`, or tell Copilot:

```text
Start the Power Platform wizard in this repository.
```

That workflow performs initial setup, runs `00-prereq-check.ps1`, and then
guides complete model-driven app planning and generation. Its supported modes
are:

- `demo-builder` for the streamlined default experience;
- `advanced-builder`, which covers 11 core discovery questions; and
- `framework-acceptance` for explicit framework validation.

The full wizard supports the `standalone-model-driven` and
`dynamics-customer-service-extension` application profiles. It also captures
the entry-point table and landing view before app assembly. Follow
[`onboarding.md`](onboarding.md) as the authoritative sequence for that
workflow.

Wizard telemetry is stored under `.wizard-metrics/`. The opt-out setting is
`WIZARD_METRICS_OPTOUT=1`; in PowerShell, set it for the current shell with:

```powershell
$env:WIZARD_METRICS_OPTOUT = '1'
```

The report wizard described in the rest of this guide is the focused path when
the app and tables already exist and only native reporting artifacts are
needed.

## Before you begin

For live preview or deployment, you need:

- access to a Microsoft Power Platform environment with Dataverse;
- permission to read Dataverse metadata;
- an existing model-driven app;
- an existing unmanaged solution for deployment;
- permission to create and update solution components;
- permission to update and publish the selected model-driven app; and
- an authorized nonproduction environment for initial testing.

Do not test deployment against production.

Simulation does not require a Dataverse environment or credentials.

## Clone and open the repository

```powershell
git clone https://github.com/bradlaw76/power-platform-vscode-starter.git
Set-Location .\power-platform-vscode-starter
code .
```

If the folder name differs, use the folder created by `git clone`.

## Install prerequisites

### Required tools

- [Visual Studio Code](https://code.visualstudio.com/)
- [PowerShell 7](https://learn.microsoft.com/powershell/)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Microsoft Power Platform CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction)
- [Git](https://git-scm.com/)

For the conversational experience, also install and sign in to GitHub Copilot
in VS Code. Claude Code users can use the included Claude skill instead.

### Windows installation

```powershell
winget install Microsoft.VisualStudioCode
winget install Microsoft.PowerShell
winget install Microsoft.AzureCLI
winget install Microsoft.PowerPlatformCLI
winget install Git.Git
```

Restart VS Code after installation so its integrated terminal receives the
updated `PATH`.

### Verify the repository and tools

From the repository root:

```powershell
pwsh .\scripts\bootstrap\00-prereq-check.ps1
```

Resolve failed prerequisite checks before live discovery or deployment.

## Start with GitHub Copilot

The repository includes the shared skill:

```text
.github/skills/dataverse-report-wizard/SKILL.md
```

1. Open the cloned repository in VS Code.
2. Open GitHub Copilot Chat.
3. Select **Agent** mode.
4. Enter:

```text
/dataverse-report-wizard
```

You can also start with natural language:

```text
Start the Dataverse report wizard in this repository.
```

The skill defaults to simulation when a mode has not been selected. For live
work, it guides environment intake, report design, preview review, and the
separate deployment approval.

If the skill does not appear immediately after cloning, reload the VS Code
window and reopen Copilot Chat from the repository workspace.

## Start with Claude Code

The repository includes:

```text
.claude/skills/dataverse-report-wizard/SKILL.md
```

Install all checked-in Claude skills:

```powershell
pwsh .\scripts\bootstrap\01-install-skills.ps1
```

Start a new Claude Code session and enter:

```text
/dataverse-report-wizard
```

The installer copies complete skill folders to `~/.claude/skills`. Installing
a skill does not copy this repository's PowerShell runtime into another
project. Run the skill from a compatible clone of this repository.

## Run the wizard directly

You can bypass the AI skill and run the PowerShell wizard:

```powershell
pwsh .\scripts\bootstrap\08-report-wizard.ps1
```

The interactive wizard asks for:

1. a scenario slug;
2. the Dataverse environment URL;
3. authentication when required;
4. what the user wants to see;
5. confirmation or correction of the recommended report design;
6. optional additional charts and filters; and
7. the dashboard name.

Running without `-Deploy` generates local review artifacts only.

## Recommended first run: simulation

Run the credential-free simulation before connecting to Dataverse:

```powershell
pwsh .\scripts\ci\test-report-wizard.ps1
```

The simulation:

- loads sanitized model-driven app, table, and column metadata;
- interprets a natural-language reporting request;
- generates a reporting payload and filtered aggregate FetchXML;
- validates overwrite protection;
- rejects incompatible aggregations;
- simulates chart and dashboard creation;
- simulates solution registration;
- simulates attaching the chart and dashboard to an app;
- simulates app publication; and
- removes temporary scenario artifacts.

The simulation does not contact or modify Dataverse.

## Create a live report preview

### Using the skill

In Copilot Chat or Claude Code:

```text
/dataverse-report-wizard
```

Choose live preview when prompted.

### Using the terminal

```powershell
pwsh .\scripts\bootstrap\08-report-wizard.ps1
```

The wizard asks for an HTTPS Dataverse environment URL such as:

```text
https://your-org.crm.dynamics.com
```

It then:

1. verifies Azure CLI and Power Platform CLI availability;
2. reuses the current Azure session or starts interactive sign-in;
3. acquires a token scoped to the specified Dataverse environment;
4. creates or selects a PAC CLI authentication profile;
5. reads model-driven apps from `appmodules`;
6. reads reportable tables from `EntityDefinitions`;
7. reads table attributes and their types;
8. asks what the user wants to see;
9. recommends a report design; and
10. creates local preview artifacts.

Live preview reads environment metadata but does not create charts or
dashboards.

## Review generated artifacts

For a scenario named `case-operations`, the wizard creates:

```text
payloads/scenarios/case-operations/reporting-case-operations.json
specs/case-operations/report-artifacts/query-preview.json
specs/case-operations/report-mappings.md
```

### Reporting payload

The reporting payload is the machine-readable source of truth. It contains:

- the original reporting request;
- target model-driven app unique name;
- output targets;
- chart definitions;
- Dataverse table and column logical names;
- aggregation types;
- chart types;
- filters; and
- dashboard composition.

It is validated against:

```text
schemas/payloads/reporting.schema.json
```

### FetchXML query preview

`query-preview.json` contains the exact aggregate FetchXML generated for every
chart. Review:

- table logical names;
- category and measure columns;
- aggregation type;
- filter operators and values; and
- whether the query represents the requested business question.

### Report mappings

`report-mappings.md` provides a human-readable summary of the request, app,
dashboard, charts, fields, aggregations, output targets, and filters.

Do not deploy until the payload, FetchXML, and mapping are approved.

## Deploy an approved report

Deployment requires explicit approval after preview.

Before deploying, confirm:

- environment URL;
- existing solution unique name;
- existing publisher prefix;
- target model-driven app;
- dashboard name;
- chart names;
- selected tables and fields;
- calculations; and
- filters.

Run:

```powershell
pwsh .\scripts\bootstrap\08-report-wizard.ps1 `
  -ScenarioSlug case-operations `
  -Force `
  -Deploy
```

The deployment runtime:

1. validates the reporting payload;
2. resolves the selected unmanaged solution;
3. creates or updates scenario-owned system charts;
4. creates or updates the scenario-owned dashboard;
5. adds charts and the dashboard to the solution;
6. publishes affected table customizations;
7. resolves the selected model-driven app;
8. attaches the generated components with `AddAppComponents`; and
9. publishes the selected app.

`-Force` permits replacement of an existing local scenario payload. It should
only be used after reviewing the existing file.

The runtime refuses to update same-name charts or dashboards that are not
marked as owned by the current scenario.

## Wizard questions

The live wizard follows this order.

### 1. Scenario

A stable lowercase identifier used for artifact folders and ownership markers:

```text
case-operations
```

Allowed characters are lowercase letters, numbers, and single hyphens.

### 2. Environment

The exact Dataverse environment URL:

```text
https://your-org.crm.dynamics.com
```

The wizard authenticates immediately so later questions can use live metadata.

### 3. Reporting request

The user describes the desired outcome in natural language:

```text
Show service managers open cases grouped by priority.
```

A useful request includes:

- intended audience;
- decision the report supports;
- records or business process involved;
- grouping or comparison;
- measure or KPI;
- time period; and
- filters such as open, active, closed, region, owner, or category.

### 4. Recommended design

The wizard proposes:

- model-driven app;
- Dataverse table;
- category column;
- measure column;
- aggregation;
- chart type; and
- recognized active/open or inactive/closed filters.

The user can accept the proposal or choose metadata values manually.

### 5. Additional charts

A dashboard supports one to three generated charts in the current version.

### 6. Dashboard

The user provides the display name for the generated dashboard.

### 7. Deployment details

Only when deployment is requested, the wizard asks for missing solution and
publisher details.

## Natural-language recommendations

The recommendation engine uses live Dataverse display names, logical names,
attribute types, and common reporting terms.

Examples:

| Request | Likely recommendation |
|---|---|
| Show open cases by priority | Count Case rows, grouped by Priority, filtered to active state |
| Show total estimated value by owner | Sum a numeric or money field, grouped by Owner |
| Show average amount by category as a pie chart | Average a numeric field, grouped by Category, pie visualization |
| Show inactive assets by status | Count assets, grouped by Status, filtered to inactive state |

Recommendations are drafts. They must be confirmed against live metadata and
the generated FetchXML.

## Supported report features

### Native artifacts

- Dataverse system charts (`savedqueryvisualization`)
- Dataverse dashboards (`systemform`)
- Model-driven app component attachment
- Solution component registration
- Scoped publication

### Aggregations

- `count`
- `countcolumn`
- `sum`
- `avg`
- `min`
- `max`

`sum`, `avg`, `min`, and `max` require a numeric Dataverse attribute such as
whole number, decimal, floating point, money, or big integer.

### Chart types

- column
- bar
- pie
- doughnut

### Filter operators

- equals: `eq`
- not equal: `ne`
- greater than: `gt`
- greater than or equal: `ge`
- less than: `lt`
- less than or equal: `le`
- null
- not null

All filters in a generated chart currently use logical `and`.

## Noninteractive and CI usage

Use `-ConfigurationPath` to bypass interactive report-design questions.
Configuration files should not contain credentials.

Example:

```json
{
  "ReportRequest": "Show open cases grouped by priority for service managers.",
  "TargetAppUniqueName": "contoso_customer_service",
  "OutputTargets": [
    "fetchxml-preview",
    "native-chart-dashboard"
  ],
  "DashboardName": "Case Operations",
  "Charts": [
    {
      "Name": "Open Cases by Priority",
      "TableLogicalName": "incident",
      "CategoryField": "prioritycode",
      "AggregateField": "incidentid",
      "Aggregate": "count",
      "ChartType": "column",
      "Filters": [
        {
          "Field": "statecode",
          "Operator": "eq",
          "Value": "0"
        }
      ]
    }
  ]
}
```

Run a preview using sanitized metadata:

```powershell
pwsh .\scripts\bootstrap\08-report-wizard.ps1 `
  -ScenarioSlug case-operations `
  -MetadataSnapshotPath .\scripts\ci\fixtures\report-wizard-metadata.json `
  -ConfigurationPath C:\Temp\case-report.json
```

Use `-MetadataSnapshotPath` only with sanitized metadata. Do not commit customer
metadata exports without review.

For live noninteractive execution, omit `-MetadataSnapshotPath` and supply an
authorized environment and authentication context.

## Repository structure

```text
.github/
  skills/
    dataverse-report-wizard/
      SKILL.md                    GitHub Copilot skill

.claude/
  skills/
    dataverse-report-wizard/
      SKILL.md                    Claude Code skill

schemas/
  payloads/
    reporting.schema.json         Reporting payload contract

scripts/
  bootstrap/
    00-prereq-check.ps1           Tool prerequisite validation
    01-install-skills.ps1         Claude skill installer
    08-report-wizard.ps1          Interactive report wizard
    10-auth-connect.ps1           Full app-builder authentication workflow
    64-build-charts-dashboard.ps1 Native report deployment stage
    helpers/
      dataverse-runtime.ps1       Web API retry and token runtime
      reporting-wizard.ps1        Discovery, recommendation, generation, app wiring
  ci/
    test-report-wizard.ps1        End-to-end credential-free simulation
    SkillParity.Tests.ps1         Copilot and Claude contract parity
    fixtures/
      report-wizard-metadata.json Sanitized metadata fixture

payloads/
  scenarios/
    <scenario>/                   Generated machine-readable report payloads

specs/
  <scenario>/
    report-artifacts/             Generated FetchXML previews
    report-mappings.md            Human-readable report plan
```

## Security and safety

### Credentials

- Access tokens must never be printed or committed.
- `.env.ps1` is local and git-ignored.
- Generated report configuration must not contain credentials.
- Use interactive user authentication for normal development.
- Use a dedicated service principal only through an approved CI design.

### Environment safety

- Start with simulation.
- Use a dedicated development or test environment.
- Confirm the exact environment before authentication.
- Preview before deployment.
- Treat deployment approval as specific to the displayed environment,
  solution, app, dashboard, charts, and filters.
- Do not reuse approval after changing the report definition.

### Dataverse ownership

Generated native artifacts include a scenario ownership marker. Reruns update
matching scenario-owned artifacts and refuse ambiguous or foreign same-name
components.

### Source control

Before committing:

```powershell
git status --short
git diff --check
git diff
```

Review generated artifacts for environment-specific identifiers, customer
information, and accidental credentials.

## Troubleshooting

### The skill does not appear in Copilot Chat

1. Confirm the repository contains:

   ```text
   .github/skills/dataverse-report-wizard/SKILL.md
   ```

2. Open the repository folder, not an individual file.
3. Reload the VS Code window.
4. Reopen Copilot Chat in Agent mode.
5. Try the natural-language fallback:

   ```text
   Start the Dataverse report wizard in this repository.
   ```

### `pwsh` is not recognized

Install PowerShell 7:

```powershell
winget install Microsoft.PowerShell
```

Restart VS Code.

### `az` or `pac` is not recognized

```powershell
winget install Microsoft.AzureCLI
winget install Microsoft.PowerPlatformCLI
```

Restart VS Code and rerun:

```powershell
pwsh .\scripts\bootstrap\00-prereq-check.ps1
```

### Azure authentication fails

Verify that the environment URL is correct and that your account is a member of
the environment's tenant. Then run:

```powershell
az login --allow-no-subscriptions
```

Restart the report wizard.

### The app or table is missing

- Confirm the correct environment URL.
- Confirm the application is a model-driven app.
- Confirm your account can read app and table metadata.
- Confirm the required Dynamics 365 application is installed.
- Check the logical name in Maker portal.

### A numeric calculation is rejected

`sum`, `avg`, `min`, and `max` require a numeric or money column. Use `count`
or `countcolumn` for text, choice, lookup, status, and identifier fields.

### The reporting payload already exists

The wizard protects existing local payloads. Review:

```text
payloads/scenarios/<scenario>/reporting-<scenario>.json
```

Use a different scenario slug, or use `-Force` only after approving
replacement.

### Chart or dashboard ownership collision

A same-name Dataverse component exists but is not marked as owned by the
scenario. Do not bypass the check. Rename the generated artifact or review the
existing component and solution ownership.

### Deployment succeeded but users cannot see data

Report deployment does not grant table privileges. Confirm that affected users
have:

- access to the model-driven app;
- an appropriate security role;
- read privilege for the underlying tables; and
- field-level access for selected columns.

## Validation

Run the focused simulation:

```powershell
pwsh .\scripts\ci\test-report-wizard.ps1
```

Run reporting regressions:

```powershell
pwsh .\scripts\ci\test-reporting-and-data-stages.ps1
```

Validate all JSON and reporting payloads:

```powershell
pwsh .\scripts\ci\test-json-schema.ps1
```

Validate PowerShell parsing and required runtime patterns:

```powershell
pwsh .\scripts\ci\test-script-smoke.ps1
```

Validate Copilot and Claude skill parity:

```powershell
pwsh -NoProfile -Command `
  '$result = Invoke-Pester -Path .\scripts\ci\SkillParity.Tests.ps1 -PassThru; if ($result.FailedCount -gt 0) { exit 1 }'
```

Run contract and documentation checks:

```powershell
pwsh .\scripts\ci\test-contract-integrity.ps1
pwsh .\scripts\ci\test-docs-consistency.ps1
```

Credential-free tests do not prove that a target tenant permits every live
Dataverse operation. Validate against an authorized nonproduction environment
before broader use.

## Current limitations

- One generated dashboard contains one to three generated charts.
- Filters are joined with logical `and`.
- Natural-language interpretation is heuristic and requires confirmation.
- Common open/active and closed/inactive state filters are inferred; arbitrary
  business vocabulary may require manual selection.
- Cross-table joins and linked-entity FetchXML are not yet generated.
- Date grouping and fiscal-period grouping are not yet exposed by the wizard.
- Dashboard layout is generated rather than visually designed.
- HTML web-resource reporting exists elsewhere in the starter runtime but is
  not yet integrated into this focused wizard.
- SSRS/RDL and Power BI report generation are outside the current scope.
- A live Dataverse deployment must still be validated in each tenant because
  permissions, installed applications, and metadata differ.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing runtime behavior.

For report-wizard changes:

1. preserve preview-before-deployment behavior;
2. keep live transport injectable for credential-free tests;
3. add or update simulation coverage;
4. preserve schema compatibility with existing reporting payloads;
5. keep Copilot and Claude skill contracts aligned;
6. run the validation commands above; and
7. never use production for integration testing.

No repository license has been selected. Do not infer redistribution rights;
choosing a license is an explicit repository-owner decision.
