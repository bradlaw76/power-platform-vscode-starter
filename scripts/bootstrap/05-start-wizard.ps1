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

    This script does not authenticate or create Dataverse artifacts. It is the
    planning step that should happen before `10-auth-connect.ps1` and scripts
    `20`-`60` when starting a new idea.

.PARAMETER Force
    Overwrite existing generated files without prompting.

.EXAMPLE
    pwsh ./scripts/bootstrap/05-start-wizard.ps1

.EXAMPLE
    pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Force
#>

param(
    [switch]$Force
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
Write-Host "This wizard captures discovery answers and scaffolds Spec Kit starter files." 
Write-Host "Run this before authentication or build scripts when starting a new idea."
Write-Host ""

$scenarioName = Read-RequiredValue "Scenario or app name"
$scenarioSlugDefault = ConvertTo-Slug $scenarioName
$scenarioSlug = Read-RequiredValue "Scenario folder slug" $scenarioSlugDefault

$answers = [ordered]@{}
$answers["ScenarioName"] = $scenarioName
$answers["ScenarioSlug"] = $scenarioSlug
$answers["AppType"] = Read-RequiredValue "1. What type of demo or app are you building?"
$answers["PlatformArea"] = Read-RequiredValue "2. Is it for Dynamics 365 Sales, Customer Service, Field Service, Contact Center, Power Apps, Power Pages, Copilot Studio, or Dataverse?"
$answers["TargetAudience"] = Read-RequiredValue "3. Who is the target audience?"
$answers["BusinessProblem"] = Read-RequiredValue "4. What business problem does it solve?"
$answers["Users"] = Read-RequiredValue "5. Who are the users?"
$answers["DataEntities"] = Read-RequiredValue "6. What data tables or entities are needed?"
$answers["ArtifactsNeeded"] = Read-RequiredValue "7. What screens, forms, views, pages, flows, or copilots are needed?"
$answers["SuccessLooksLike"] = Read-RequiredValue "8. What does a successful demo look like?"
$answers["BuildEnvironment"] = Read-RequiredValue "9. What environment should it be built in?"
$answers["NeedsDemoData"] = Read-RequiredValue "10. Does it need demo data?" "Yes"
$answers["SolutionType"] = Read-RequiredValue "11. Should the output be a managed or unmanaged solution?" "Unmanaged"

$scenarioFolder = Join-Path $repoRoot (Join-Path "specs" $scenarioSlug)
New-Item -ItemType Directory -Path $scenarioFolder -Force | Out-Null

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
7. Needed artifacts: $($answers["ArtifactsNeeded"])
8. Success definition: $($answers["SuccessLooksLike"])
9. Build environment: $($answers["BuildEnvironment"])
10. Demo data needed: $($answers["NeedsDemoData"])
11. Solution output type: $($answers["SolutionType"])
"@

$specContent = @"
# spec.md

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

## Acceptance Criteria
- The scenario is clear and approved.
- Required entities and artifacts are identified.
- Success measures are specific enough to validate.
- The environment and solution type are agreed before implementation.
"@

$planContent = @"
# plan.md

## Build Approach
- Platform area: $($answers["PlatformArea"])
- Environment: $($answers["BuildEnvironment"])
- Solution type: $($answers["SolutionType"])

## Proposed Workstreams
1. Discovery review and approval
2. Dataverse schema design
3. Forms/views/pages/app experience design
4. Flow/copilot automation design
5. Demo data planning
6. Solution export/unpack/git workflow
7. Validation and handoff

## Risks to Resolve
- Confirm environment availability and permissions.
- Confirm entity scope and artifact count.
- Confirm whether demo data must be scripted or manual.

## Validation Plan
- Verify artifacts in Maker portal.
- Verify solution export/unpack succeeds.
- Verify git changes are reviewable.
- Verify import into target environment succeeds.
"@

$tasksContent = @"
# tasks.md

## Ordered Tasks
- [ ] Review `answers.md` with stakeholder
- [ ] Finalize `spec.md`
- [ ] Finalize `plan.md`
- [ ] Approve build environment and permissions
- [ ] Define Dataverse tables and columns for: $($answers["DataEntities"])
- [ ] Define required app artifacts for: $($answers["ArtifactsNeeded"])
- [ ] Decide demo data approach: $($answers["NeedsDemoData"])
- [ ] Run `pwsh ./scripts/bootstrap/00-prereq-check.ps1`
- [ ] Run `pwsh ./scripts/bootstrap/10-auth-connect.ps1`
- [ ] Build tables with `20-build-tables.ps1`
- [ ] Build columns with `30-build-columns.ps1`
- [ ] Build relationships with `40-build-relationships.ps1`
- [ ] Add components to solution with `50-add-to-solution.ps1`
- [ ] Build starter forms/views with `60-build-forms-views.ps1`
- [ ] Export and unpack solution
- [ ] Commit changes to git
- [ ] Pack and import solution
- [ ] Update `docs/build-log.md`
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
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review and refine the generated files."
Write-Host "  2. Get approval on scope and success criteria."
Write-Host "  3. Then run: pwsh ./scripts/bootstrap/00-prereq-check.ps1"