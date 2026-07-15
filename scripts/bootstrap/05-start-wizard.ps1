<#
.SYNOPSIS
    Runs an interactive repository wizard for a new Power Platform or Dynamics
    365 demo/app idea and scaffolds Spec Kit starter files.

.DESCRIPTION
    Prompts the user with discovery questions, captures answers, and writes
    starter `spec.md`, `plan.md`, `tasks.md`, and `answers.md` files to a
    scenario folder under `specs/<scenario-slug>/`.

    If generated files already exist for the chosen scenario, the script prompts
    before overwriting unless -Force is used.

    Use -Retrofit when the user already has a partial implementation. The script
    will ask for current state (what is already built) and use that as the basis
    for `spec.md`, with `plan.md` capturing only the remaining work.

    This script does not authenticate or create Dataverse artifacts. It is the
    planning step that should happen before `10-auth-connect.ps1` and scripts
    `20`-`60` when starting a new idea.

.PARAMETER Force
    Overwrite existing generated files without prompting.

.PARAMETER Retrofit
    Use mid-project retrofit mode. Asks for current state instead of greenfield
    discovery, and generates spec.md reflecting what exists plus plan.md for
    remaining work.

.EXAMPLE
    pwsh ./scripts/bootstrap/05-start-wizard.ps1

.EXAMPLE
    pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Force

.EXAMPLE
    pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Retrofit
#>

param(
    [switch]$Force,
    [switch]$Retrofit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-RequiredValue {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    while ($true) {
        $value = if ([string]::IsNullOrWhiteSpace($Default)) {
            Read-Host $Prompt
        }
        else {
            Read-Host "$Prompt [$Default]"
        }

        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = $Default
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        Write-Host "A value is required." -ForegroundColor Yellow
    }
}

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = [regex]::Replace($slug, "[^a-z0-9]+", "-")
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "new-scenario"
    }
    return $slug
}

function Resolve-StandardLogicalName {
    param([string]$Name)

    $key = ($Name ?? "").Trim().ToLower()
    $map = @{
        "account"     = "account"
        "activity"    = "activitypointer"
        "case"        = "incident"
        "contact"     = "contact"
        "incident"    = "incident"
        "lead"        = "lead"
        "opportunity" = "opportunity"
        "product"     = "product"
        "task"        = "task"
    }

    if ($map.ContainsKey($key)) { return $map[$key] }
    return $key
}

function Convert-ToCustomLogicalName {
    param(
        [string]$Name,
        [string]$Prefix
    )

    $normalizedPrefix = ($Prefix ?? "").Trim().ToLower()
    $candidate = ($Name ?? "").Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($candidate)) { return "" }

    if ($candidate.Contains("_")) { return $candidate }
    $candidate = [regex]::Replace($candidate, "[^a-z0-9]+", "")
    if ([string]::IsNullOrWhiteSpace($candidate)) { return "" }

    if ([string]::IsNullOrWhiteSpace($normalizedPrefix)) { return $candidate }
    return "$normalizedPrefix`_$candidate"
}

function Format-StandardTableMapping {
    param([string]$Input)

    if ([string]::IsNullOrWhiteSpace($Input) -or $Input.Trim().ToLower() -eq "none") {
        return "- None"
    }

    $lines = @()
    $items = @($Input -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($item in $items) {
        $logical = Resolve-StandardLogicalName $item
        $lines += "- $item -> $logical"
    }

    if ($lines.Count -eq 0) { return "- None" }
    return ($lines -join "`n")
}

function Format-CustomTableMapping {
    param(
        [string]$Input,
        [string]$Prefix
    )

    if ([string]::IsNullOrWhiteSpace($Input) -or $Input.Trim().ToLower() -eq "none") {
        return "- None"
    }

    $lines = @()
    $items = @($Input -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($item in $items) {
        $logical = Convert-ToCustomLogicalName -Name $item -Prefix $Prefix
        if (-not [string]::IsNullOrWhiteSpace($logical)) {
            $lines += "- $item -> $logical"
        }
    }

    if ($lines.Count -eq 0) { return "- None" }
    return ($lines -join "`n")
}

function Confirm-Overwrite {
    param([string[]]$Paths)

    Write-Host "" 
    Write-Host "The following files already exist and would be overwritten:" -ForegroundColor Yellow
    $Paths | ForEach-Object { Write-Host "  $_" }
    Write-Host "" 
    $answer = Read-Host "Overwrite these files? (y/N)"
    return $answer -match '^(y|yes)$'
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

Write-Host "" 
Write-Host "=== Power Platform Demo Wizard ===" -ForegroundColor Cyan

if ($Retrofit) {
    Write-Host "RETROFIT MODE: Reverse-engineering spec from an existing/in-progress project." -ForegroundColor Yellow
    Write-Host "spec.md will capture current state. plan.md will capture remaining work."
} else {
    Write-Host "This wizard captures discovery answers and scaffolds Spec Kit starter files."
    Write-Host "Run this before authentication or build scripts when starting a new idea."
}

Write-Host ""

$scenarioName = Read-RequiredValue "Scenario or app name"
$scenarioSlugDefault = ConvertTo-Slug $scenarioName
$scenarioSlug = Read-RequiredValue "Scenario folder slug" $scenarioSlugDefault

$answers = [ordered]@{}
$answers["ScenarioName"] = $scenarioName
$answers["ScenarioSlug"] = $scenarioSlug

if ($Retrofit) {
    # --- Retrofit mode: ask for current state, not greenfield intent ---
    Write-Host ""
    Write-Host "Answer these questions based on what already exists, not what you plan to build." -ForegroundColor Cyan
    Write-Host ""

    $answers["AppType"] = Read-RequiredValue "1. What type of app or demo is this? (describe what already exists)"
    $answers["PlatformArea"] = Read-RequiredValue "2. What platform area is it built on? (D365 Sales, Customer Service, Power Apps, etc.)"
    $answers["TargetAudience"] = Read-RequiredValue "3. Who is the target audience?"
    $answers["BusinessProblem"] = Read-RequiredValue "4. What business problem is it solving? (based on current state)"
    $answers["Users"] = Read-RequiredValue "5. Who are the current users or user roles?"
    $answers["DataEntities"] = Read-RequiredValue "R1. What tables or entities have already been created? (comma-separated)"
    $answers["TableChoice"] = Read-RequiredValue "R2. Which of those are standard Dataverse tables vs custom? (standard/custom/both)" "both"
    $answers["ArtifactsNeeded"] = Read-RequiredValue "R3. What forms, views, flows, or copilots are currently built or in progress?"
    $answers["SuccessLooksLike"] = Read-RequiredValue "8. What does a successful demo of this app look like?"
    $answers["BuildEnvironment"] = Read-RequiredValue "9. What environment is it currently built in?"
    $answers["NeedsDemoData"] = Read-RequiredValue "10. Does it need demo data?" "Yes"
    $answers["SolutionType"] = Read-RequiredValue "11. Is the solution managed or unmanaged?" "Unmanaged"

    Write-Host ""
    Write-Host "Solution and publisher details (use existing values if already set up):" -ForegroundColor Cyan
    $answers["SolutionChoice"] = "existing"
    $answers["SolutionName"] = Read-RequiredValue "    Existing solution unique name"
    $answers["PrefixChoice"] = "existing"
    $answers["PublisherPrefix"] = Read-RequiredValue "    Existing publisher prefix (e.g. vafe, contoso)"

    Write-Host ""
    Write-Host "Remaining work (leave blank or enter 'none' if fully built):" -ForegroundColor Cyan
    Write-Host ""
    $answers["RemainingEntities"] = Read-RequiredValue "R4. Tables or entities still to create (enter 'none' if complete)" "none"
    $answers["RemainingArtifacts"] = Read-RequiredValue "R5. Forms, views, flows, or copilots still to build (enter 'none' if complete)" "none"
    $answers["RemainingWork"] = Read-RequiredValue "R6. Any other remaining work not covered above (enter 'none' if complete)" "none"
} else {
    # --- Standard greenfield mode ---
    $answers["AppType"] = Read-RequiredValue "1. What type of demo or app are you building?"
    $answers["PlatformArea"] = Read-RequiredValue "2. Is it for Dynamics 365 Sales, Customer Service, Field Service, Contact Center, Power Apps, Power Pages, Copilot Studio, or Dataverse?"
    $answers["TargetAudience"] = Read-RequiredValue "3. Who is the target audience?"
    $answers["BusinessProblem"] = Read-RequiredValue "4. What business problem does it solve?"
    $answers["Users"] = Read-RequiredValue "5. Who are the users?"
    $answers["DataEntities"] = Read-RequiredValue "6. What data tables or entities are needed?"
    $answers["TableChoice"] = Read-RequiredValue "6b. Use standard Dataverse tables (Contact, Account, Case, etc.) or create custom tables? (standard/custom/both)" "both"
    $answers["ArtifactsNeeded"] = Read-RequiredValue "7. What screens, forms, views, pages, flows, or copilots are needed?"
    $answers["SuccessLooksLike"] = Read-RequiredValue "8. What does a successful demo look like?"
    $answers["BuildEnvironment"] = Read-RequiredValue "9. What environment should it be built in?"
    $answers["NeedsDemoData"] = Read-RequiredValue "10. Does it need demo data?" "Yes"
    $answers["SolutionType"] = Read-RequiredValue "11. Should the output be a managed or unmanaged solution?" "Unmanaged"

    $solutionChoice = Read-RequiredValue "12. New solution or use an existing one? (new/existing)" "new"
    $answers["SolutionChoice"] = $solutionChoice
    if ($solutionChoice -ieq "existing") {
        $answers["SolutionName"] = Read-RequiredValue "    Existing solution unique name"
    } else {
        $answers["SolutionName"] = Read-RequiredValue "    New solution unique name (no spaces, letters/numbers only, e.g. ContosoHRApp)"
    }

    $prefixChoice = Read-RequiredValue "13. New publisher prefix or use an existing one? (new/existing)" "new"
    $answers["PrefixChoice"] = $prefixChoice
    if ($prefixChoice -ieq "existing") {
        $answers["PublisherPrefix"] = Read-RequiredValue "    Existing prefix (e.g. vafe, contoso)"
    } else {
        $answers["PublisherPrefix"] = Read-RequiredValue "    New prefix (3-8 lowercase letters, e.g. cto, demo)"
    }
}

if ($Retrofit) {
    Write-Host ""
    Write-Host "Entity mapping (based on what already exists):" -ForegroundColor Cyan
    Write-Host ""
    $answers["StandardTablesReused"] = Read-RequiredValue "R7. Standard tables already reused (comma-separated display or logical names; enter 'none' if none)" "none"
    $answers["CustomTablesToCreate"] = Read-RequiredValue "R8. Custom tables still to create (comma-separated; enter 'none' if all done)" "none"
    $answers["StandardFieldsReused"] = Read-RequiredValue "R9. Standard fields already reused (table.field list; enter 'none' if none)" "none"
    $answers["CustomFieldsToAdd"] = Read-RequiredValue "R10. Custom fields still to add (table.field list; enter 'none' if all done)" "none"
    $answers["RelationshipsToCreate"] = Read-RequiredValue "R11. Relationships still to create (referencing -> referenced; enter 'none' if all done)" "none"
    $answers["IncludeHtmlReports"] = Read-RequiredValue "R12. Create optional HTML report web resources (agent, supervisor, executive KPI)? (yes/no)" "no"
} else {
    $answers["StandardTablesReused"] = Read-RequiredValue "14. Explicit mapping - standard tables to reuse (comma-separated display names or logical names; enter 'none' if none)" "none"
    $answers["CustomTablesToCreate"] = Read-RequiredValue "15. Explicit mapping - custom tables to create (comma-separated; enter 'none' if none)" "none"
    $answers["StandardFieldsReused"] = Read-RequiredValue "16. Explicit mapping - standard fields to reuse (table.field list; enter 'none' if none)" "none"
    $answers["CustomFieldsToAdd"] = Read-RequiredValue "17. Explicit mapping - custom fields to add (table.field list; enter 'none' if none)" "none"
    $answers["RelationshipsToCreate"] = Read-RequiredValue "18. Explicit mapping - relationships to create (referencing -> referenced; enter 'none' if none)" "none"
    $answers["IncludeHtmlReports"] = Read-RequiredValue "19. Create optional HTML report web resources (agent, supervisor, executive KPI)? (yes/no)" "no"
}
$answers["ReportTheme"] = "Dynamics blue"
$answers["ReportSet"] = "Agent performance report; Supervisor oversight report; Executive summary KPI report"

$standardTableMapping = Format-StandardTableMapping -Input $answers["StandardTablesReused"]
$customTableMapping = Format-CustomTableMapping -Input $answers["CustomTablesToCreate"] -Prefix $answers["PublisherPrefix"]

$scenarioFolder = Join-Path $repoRoot (Join-Path "specs" $scenarioSlug)
New-Item -ItemType Directory -Path $scenarioFolder -Force | Out-Null

# Write planning values to .env.ps1 so 10-auth-connect.ps1 can use them as defaults.
# 10-auth-connect.ps1 will overwrite this file with full auth + config when it runs.
$envFilePath = Join-Path $repoRoot ".env.ps1"
$planEnvContent = @"
# Planning values set by 05-start-wizard.ps1 -- do not commit this file.
# Run 10-auth-connect.ps1 next to complete authentication and full configuration.
`$env:DV_SOLUTION_NAME       = "$($answers["SolutionName"])"
`$env:DV_PUBLISHER_PREFIX    = "$($answers["PublisherPrefix"])"
`$global:DV_SOLUTION_NAME    = "`$env:DV_SOLUTION_NAME"
`$global:DV_PUBLISHER_PREFIX = "`$env:DV_PUBLISHER_PREFIX"
"@
Set-Content -Path $envFilePath -Value $planEnvContent -Encoding UTF8

$answersPath = Join-Path $scenarioFolder "answers.md"
$specPath = Join-Path $scenarioFolder "spec.md"
$planPath = Join-Path $scenarioFolder "plan.md"
$tasksPath = Join-Path $scenarioFolder "tasks.md"

$targetFiles = @($answersPath, $specPath, $planPath, $tasksPath)
$existingFiles = @($targetFiles | Where-Object { Test-Path $_ })
if ($existingFiles.Count -gt 0 -and -not $Force) {
    if (-not (Confirm-Overwrite -Paths $existingFiles)) {
        Write-Host "" 
        Write-Host "No files were changed. Re-run with a new scenario slug or use -Force." -ForegroundColor Yellow
        exit 0
    }
}

$answersContent = @"
# Discovery Answers

## Scenario
- Name: $($answers["ScenarioName"])
- Slug: $($answers["ScenarioSlug"])

## Wizard Answers
1. Type of demo/app: $($answers["AppType"])
2. Platform area: $($answers["PlatformArea"])
3. Target audience: $($answers["TargetAudience"])
4. Business problem: $($answers["BusinessProblem"])
5. Users: $($answers["Users"])
6. Data entities: $($answers["DataEntities"])
6b. Standard vs custom tables: $($answers["TableChoice"])
7. Needed artifacts: $($answers["ArtifactsNeeded"])
8. Success definition: $($answers["SuccessLooksLike"])
9. Build environment: $($answers["BuildEnvironment"])
10. Demo data needed: $($answers["NeedsDemoData"])
11. Solution output type: $($answers["SolutionType"])
12. Solution (new/existing): $($answers["SolutionChoice"]) -- $($answers["SolutionName"])
13. Publisher prefix (new/existing): $($answers["PrefixChoice"]) -- $($answers["PublisherPrefix"])
19. Create optional HTML report web resources: $($answers["IncludeHtmlReports"])

## Optional Report Web Resources
- Enabled: $($answers["IncludeHtmlReports"])
- Report set: $($answers["ReportSet"])
- Visual theme: $($answers["ReportTheme"])
- Integration: Create HTML web resources and add them to the selected solution.

## Explicit Entity Mapping (Required Before Payloads)

### Standard reused tables (display -> logical)
$standardTableMapping

### Custom tables to create (input -> generated logical)
$customTableMapping

### Standard fields reused
- $($answers["StandardFieldsReused"])

### Custom fields to add
- $($answers["CustomFieldsToAdd"])

### Relationships to create
- $($answers["RelationshipsToCreate"])
"@

$retrofitLabel = if ($Retrofit) { " [RETROFIT — reflects current state]" } else { "" }
$retrofitPlanLabel = if ($Retrofit) { " [RETROFIT — captures remaining work only]" } else { "" }

$specContent = @"
# spec.md$retrofitLabel

## Scenario Summary
$($answers["ScenarioName"]) is a $($answers["AppType"]) for $($answers["PlatformArea"]).

## Problem Statement
$($answers["BusinessProblem"])

## Target Audience
$($answers["TargetAudience"])

## Users
$($answers["Users"])

## Required Data Entities
$($answers["DataEntities"])

### Table Strategy
- **Approach**: $($answers["TableChoice"])
- **Guidance**: See 'docs/standard-dataverse-tables.md' for out-of-box vs custom tables.

## Explicit Entity Mapping (Required)

### Standard reused tables (display -> logical)
$standardTableMapping

### Custom tables to create (input -> generated logical)
$customTableMapping

### Standard fields reused
- $($answers["StandardFieldsReused"])

### Custom fields to add
- $($answers["CustomFieldsToAdd"])

### Relationships to create
- $($answers["RelationshipsToCreate"])

### Payload Generation Gate
- Do not generate payloads until this mapping is complete and stakeholder-approved.
- Do not include standard tables in table-creation payloads.
- Reuse out-of-box fields unless a true custom field is required.

## Optional Report Web Resources
- Enabled: $($answers["IncludeHtmlReports"])
- Report set: $($answers["ReportSet"])
- Visual style: $($answers["ReportTheme"]) tokens with icon-backed KPI cards.
- Integration scope: Create HTML web resources and add them to solution (no automatic form-tab insertion).

## Required Experience and Artifacts
$($answers["ArtifactsNeeded"])

## Success Criteria
$($answers["SuccessLooksLike"])

## Environment
$($answers["BuildEnvironment"])

## Demo Data Requirement
$($answers["NeedsDemoData"])

## Solution Packaging Decision
$($answers["SolutionType"])

## Solution and Publisher
- Solution: $($answers["SolutionName"]) ($($answers["SolutionChoice"]))
- Publisher prefix: $($answers["PublisherPrefix"]) ($($answers["PrefixChoice"]))

## Acceptance Criteria
- The scenario is clear and approved.
- Required entities and artifacts are identified.
- Success measures are specific enough to validate.
- The environment and solution type are agreed before implementation.
"@

$planContent = @"
# plan.md$retrofitPlanLabel

## Build Approach
- Platform area: $($answers["PlatformArea"])
- Environment: $($answers["BuildEnvironment"])
- Solution type: $($answers["SolutionType"])
- Solution unique name: $($answers["SolutionName"]) ($($answers["SolutionChoice"]))
- Publisher prefix: $($answers["PublisherPrefix"]) ($($answers["PrefixChoice"]))
$(if ($Retrofit) { @"

## Current State (Already Built)
- Tables/entities already created: $($answers["DataEntities"])
- Artifacts already built: $($answers["ArtifactsNeeded"])

## Remaining Work
- Tables still to create: $($answers["RemainingEntities"])
- Artifacts still to build: $($answers["RemainingArtifacts"])
- Other: $($answers["RemainingWork"])
"@ })
## Proposed Workstreams
1. Discovery review and approval
2. Dataverse schema design
3. Forms/views/pages/app experience design
4. Flow/copilot automation design
5. Demo data planning
6. Solution export/unpack/git workflow
7. Optional report web resource design and generation
8. Validation and handoff

## Risks to Resolve
- Confirm environment availability and permissions.
- Confirm entity scope and artifact count.
- Confirm whether demo data must be scripted or manual.
- Confirm which entities are standard (out-of-box) and which are custom (to be created).

## Explicit Entity Mapping (Required Before Payloads)

### Standard reused tables (display -> logical)
$standardTableMapping

### Custom tables to create (input -> generated logical)
$customTableMapping

### Standard fields reused
- $($answers["StandardFieldsReused"])

### Custom fields to add
- $($answers["CustomFieldsToAdd"])

### Relationships to create
- $($answers["RelationshipsToCreate"])

### Payload Readiness Rule
- Payload generation is blocked until this mapping is complete and approved.

## Validation Plan
- Verify artifacts in Maker portal.
- Verify solution export/unpack succeeds.
- Verify git changes are reviewable.
- Verify import into target environment succeeds.
- If reports are enabled, verify three HTML web resources are created and visible in solution.
"@

$tasksContent = @"
# tasks.md

## Ordered Tasks

- [ ] Review 'answers.md' with stakeholder
- [ ] Finalize 'spec.md'
- [ ] Finalize 'plan.md'
- [ ] Approve build environment and permissions
- [ ] Review standard table reference: 'docs/standard-dataverse-tables.md'
- [ ] Complete explicit entity mapping in spec/plan (standard reused tables, custom tables to create, standard fields reused, custom fields to add, relationships)
- [ ] Map standard names to logical names (for example: Case -> incident, Contact -> contact) before payload design
- [ ] Confirm table payloads include only true custom tables
- [ ] Confirm out-of-box fields are reused unless custom fields are explicitly required
- [ ] Define custom table schemas and payloads
- [ ] Define Dataverse tables and columns for: $($answers["DataEntities"])
- [ ] Define required app artifacts for: $($answers["ArtifactsNeeded"])
- [ ] Decide demo data approach: $($answers["NeedsDemoData"])
- [ ] Confirm solution name '$($answers["SolutionName"])' and publisher prefix '$($answers["PublisherPrefix"])' with stakeholder
- [ ] Run 'pwsh ./scripts/bootstrap/00-prereq-check.ps1'
- [ ] Run 'pwsh ./scripts/bootstrap/10-auth-connect.ps1'  # validates solution + prefix via API
- [ ] Build tables with '20-build-tables.ps1'
- [ ] Build columns with '30-build-columns.ps1'
- [ ] Build relationships with '40-build-relationships.ps1'
- [ ] Add components to solution with '50-add-to-solution.ps1'
- [ ] Build starter forms/views with '60-build-forms-views.ps1'
- [ ] If reports are enabled, run '65-build-web-resources.ps1'
- [ ] Export and unpack solution
- [ ] Commit changes to git
- [ ] Pack and import solution
- [ ] Update 'docs/build-log.md'
"@

Set-Content -Path $answersPath -Value $answersContent -Encoding UTF8
Set-Content -Path $specPath -Value $specContent -Encoding UTF8
Set-Content -Path $planPath -Value $planContent -Encoding UTF8
Set-Content -Path $tasksPath -Value $tasksContent -Encoding UTF8

Write-Host ""
Write-Host "Wizard output created:" -ForegroundColor Green
Write-Host "  $answersPath"
Write-Host "  $specPath"
Write-Host "  $planPath"
Write-Host "  $tasksPath"
Write-Host "  $envFilePath  (planning values for 10-auth-connect.ps1)"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
if ($Retrofit) {
    Write-Host "  1. Review spec.md — confirm it reflects current state accurately."
    Write-Host "  2. Review plan.md — confirm remaining work is complete and correct."
    Write-Host "  3. Generate a demo script: pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug $scenarioSlug"
    Write-Host "  4. Get stakeholder approval on current state + remaining work."
    Write-Host "  5. Then run: pwsh ./scripts/bootstrap/00-prereq-check.ps1"
} else {
    Write-Host "  1. Review and refine the generated files."
    Write-Host "  2. Generate a demo script: pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug $scenarioSlug"
    Write-Host "  3. Get approval on scope, success criteria, and demo story."
    Write-Host "  4. Then run: pwsh ./scripts/bootstrap/00-prereq-check.ps1"
}