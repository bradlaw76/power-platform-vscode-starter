<#
.SYNOPSIS
    Generates a scenario-aware demo script from the outputs of 05-start-wizard.ps1.

.DESCRIPTION
    Reads `spec.md` and `answers.md` from `specs/<scenario-slug>/`, suggests a
    business demo flow, asks a small set of demo-specific questions, and writes
    `demo-script.md` plus `demo-script-answers.md` back to the same scenario
    folder.

    The script is intentionally generic. It works with any scenario created by
    the first wizard by reusing the scenario's problem statement, target users,
    entities, artifacts, success criteria, and environment details.

.PARAMETER ScenarioSlug
    Existing scenario folder under `specs/`.

.PARAMETER Force
    Overwrite `demo-script.md` and `demo-script-answers.md` without prompting.

.EXAMPLE
    pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug contoso-case-tracker
#>

param(
    [string]$ScenarioSlug,
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

function Read-MultilineValue {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    Write-Host $Prompt -ForegroundColor Cyan
    if (-not [string]::IsNullOrWhiteSpace($Default)) {
        Write-Host "Press Enter to accept the default or type a replacement." -ForegroundColor DarkGray
        Write-Host "Default: $Default" -ForegroundColor DarkGray
    }

    $value = Read-Host ">"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default.Trim()
    }

    return $value.Trim()
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

function Get-MarkdownSectionValue {
    param(
        [string]$Content,
        [string]$Heading
    )

    $pattern = "(?ms)^##\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim()
}

function Get-ListValue {
    param(
        [string]$Block,
        [string]$Label
    )

    $pattern = "(?m)^-\s+$([regex]::Escape($Label)):\s*(.+)$"
    $match = [regex]::Match($Block, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim()
}

function Split-Items {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return @($Value -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-DemoSteps {
    param(
        [string[]]$Entities,
        [string[]]$Artifacts,
        [string]$HeroRecord,
        [string]$Workflow,
        [string]$DataMode,
        [string]$Audience,
        [string]$SuccessCriteria,
        [string]$TalkingPoints,
        [int]$DurationMinutes
    )

    $artifactSummary = if ($Artifacts.Count -gt 0) { $Artifacts -join ", " } else { "the scenario artifacts" }
    $secondaryEntity = if ($Entities.Count -gt 1) { $Entities[1] } elseif ($Entities.Count -gt 0) { $Entities[0] } else { $HeroRecord }
    $pace = switch ($DurationMinutes) {
        { $_ -le 3 } { "Keep the clicks minimal and speak to outcomes quickly." }
        { $_ -le 5 } { "Keep the story tight and focus on the primary workflow." }
        { $_ -le 10 } { "Show the primary workflow and one supporting artifact." }
        default { "Show the primary workflow, supporting artifacts, and one exception path." }
    }

    $steps = @(
        [ordered]@{
            Title = "Open with the business problem"
            Narrative = "Explain why this scenario exists, who it helps, and what outcome the audience should watch for. $pace"
            Actions = @(
                "State the workflow being demoed: $Workflow",
                "Anchor the audience on the hero record: $HeroRecord",
                "Call out the target audience: $Audience"
            )
            KeyPoints = @(
                "Business value: $SuccessCriteria",
                "Primary assets in scope: $artifactSummary"
            )
        },
        [ordered]@{
            Title = "Start from the hero record"
            Narrative = "Show how a user begins work with $HeroRecord and why that record matters to the scenario."
            Actions = @(
                "Navigate to the app area or page where $HeroRecord is managed",
                "Open the relevant form, view, or page for $HeroRecord",
                "Explain which fields or data points matter most"
            )
            KeyPoints = @(
                "Hero record drives the rest of the workflow",
                "The design should reduce friction for $Audience"
            )
        },
        [ordered]@{
            Title = "Walk through the core workflow"
            Narrative = "Demonstrate the main business use case from start to finish using $HeroRecord and $secondaryEntity."
            Actions = @(
                "Create or update the record needed for the workflow",
                "Show how related data or artifacts support the process",
                "Narrate the expected business outcome at each point"
            )
            KeyPoints = @(
                "Workflow outcome: $Workflow",
                "Show evidence that the process is controlled and repeatable"
            )
        },
        [ordered]@{
            Title = "Show supporting experience"
            Narrative = "Use the scenario artifacts to prove that the workflow is operational, visible, and useful to the business."
            Actions = @(
                "Show the most important artifact from: $artifactSummary",
                "Explain how users monitor or act on the workflow",
                "Call out any automation, views, dashboards, or copilots involved"
            )
            KeyPoints = @(
                "Audience should see how the app supports day-to-day work",
                "Use the artifacts to reinforce the business problem being solved"
            )
        },
        [ordered]@{
            Title = "Close with success and next step"
            Narrative = "Tie the workflow back to the business problem and tell the audience what to review next."
            Actions = @(
                "Restate the measurable success outcome",
                "Summarize what changed for the user",
                "Ask the reviewer to confirm edits or additional demo goals"
            )
            KeyPoints = @(
                "Review request: confirm that the demo flow and talking points match the intended story",
                "Data approach during demo: $DataMode"
            )
        }
    )

    if (-not [string]::IsNullOrWhiteSpace($TalkingPoints)) {
        $steps[0].KeyPoints += "Special emphasis: $TalkingPoints"
    }

    return $steps
}

function Get-FlowSuggestions {
    param(
        [string]$ProblemStatement,
        [string[]]$Entities,
        [string[]]$Artifacts,
        [string]$SuccessCriteria
    )

    $primary = if ($Entities.Count -gt 0) { $Entities[0] } else { "record" }
    $secondary = if ($Entities.Count -gt 1) { $Entities[1] } else { $primary }
    $artifactFocus = if ($Artifacts.Count -gt 0) { $Artifacts[0] } else { "the primary app experience" }

    return @(
        "Create and complete a $primary workflow that resolves: $ProblemStatement",
        "Show how $primary and $secondary support the business outcome in $artifactFocus",
        "Walk through the fastest path to prove success: $SuccessCriteria"
    )
}

function Get-StepMinutes {
    param(
        [int]$DurationMinutes,
        [int]$StepIndex,
        [int]$StepCount
    )

    if ($StepCount -le 0) {
        return 1
    }

    $base = [math]::Floor($DurationMinutes / $StepCount)
    if ($base -lt 1) {
        $base = 1
    }

    $remainder = $DurationMinutes - ($base * $StepCount)
    if ($StepIndex -lt $remainder) {
        return ($base + 1)
    }

    return $base
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$specsRoot = Join-Path $repoRoot "specs"

if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    $scenarioFolders = @(Get-ChildItem -Path $specsRoot -Directory | Sort-Object Name)
    if ($scenarioFolders.Count -eq 0) {
        throw "No scenario folders were found under '$specsRoot'. Run 05-start-wizard.ps1 first."
    }

    Write-Host ""
    Write-Host "Available scenarios:" -ForegroundColor Cyan
    $scenarioFolders | ForEach-Object { Write-Host "  - $($_.Name)" }
    $ScenarioSlug = Read-RequiredValue "Scenario folder slug"
}

$scenarioFolder = Join-Path $specsRoot $ScenarioSlug
$specPath = Join-Path $scenarioFolder "spec.md"
$answersPath = Join-Path $scenarioFolder "answers.md"
$demoScriptPath = Join-Path $scenarioFolder "demo-script.md"
$demoAnswersPath = Join-Path $scenarioFolder "demo-script-answers.md"

if (-not (Test-Path $specPath)) {
    throw "Missing spec file: $specPath"
}

if (-not (Test-Path $answersPath)) {
    throw "Missing answers file: $answersPath"
}

$existingFiles = @($demoScriptPath, $demoAnswersPath | Where-Object { Test-Path $_ })
if ($existingFiles.Count -gt 0 -and -not $Force) {
    if (-not (Confirm-Overwrite -Paths $existingFiles)) {
        Write-Host ""
        Write-Host "No files were changed." -ForegroundColor Yellow
        exit 0
    }
}

$specContent = Get-Content -Path $specPath -Raw -Encoding UTF8
$answersContent = Get-Content -Path $answersPath -Raw -Encoding UTF8

$scenarioBlock = Get-MarkdownSectionValue -Content $answersContent -Heading "Scenario"
$wizardBlock = Get-MarkdownSectionValue -Content $answersContent -Heading "Wizard Answers"

$scenarioName = Get-ListValue -Block $scenarioBlock -Label "Name"
if ([string]::IsNullOrWhiteSpace($scenarioName)) {
    $scenarioName = $ScenarioSlug
}

$problemStatement = Get-MarkdownSectionValue -Content $specContent -Heading "Problem Statement"
$targetAudience = Get-MarkdownSectionValue -Content $specContent -Heading "Target Audience"
$users = Get-MarkdownSectionValue -Content $specContent -Heading "Users"
$requiredEntitiesText = Get-MarkdownSectionValue -Content $specContent -Heading "Required Data Entities"
$artifactsText = Get-MarkdownSectionValue -Content $specContent -Heading "Required Experience and Artifacts"
$successCriteria = Get-MarkdownSectionValue -Content $specContent -Heading "Success Criteria"
$environmentUrl = Get-MarkdownSectionValue -Content $specContent -Heading "Environment"
$demoDataRequirement = Get-MarkdownSectionValue -Content $specContent -Heading "Demo Data Requirement"

$entities = Split-Items -Value $requiredEntitiesText
if ($entities.Count -eq 0) {
    $entities = Split-Items -Value ([regex]::Match($wizardBlock, '(?m)^6\. Data entities:\s*(.+)$').Groups[1].Value)
}

$artifacts = Split-Items -Value $artifactsText
if ($artifacts.Count -eq 0) {
    $artifacts = Split-Items -Value ([regex]::Match($wizardBlock, '(?m)^7\. Needed artifacts:\s*(.+)$').Groups[1].Value)
}

$suggestedHero = if ($entities.Count -gt 0) { $entities[0] } else { "Primary record" }
$flowSuggestions = Get-FlowSuggestions -ProblemStatement $problemStatement -Entities $entities -Artifacts $artifacts -SuccessCriteria $successCriteria

Write-Host ""
Write-Host "=== Demo Script Wizard ===" -ForegroundColor Cyan
Write-Host "Scenario: $scenarioName"
Write-Host "Problem: $problemStatement"
Write-Host "Entities: $($entities -join ', ')"
Write-Host "Artifacts: $($artifacts -join ', ')"
Write-Host ""
Write-Host "Suggested demo flows:" -ForegroundColor Cyan
for ($index = 0; $index -lt $flowSuggestions.Count; $index++) {
    Write-Host "  $($index + 1). $($flowSuggestions[$index])"
}

$heroRecord = Read-RequiredValue "1. What is the hero record for the demo?" $suggestedHero
$workflow = Read-RequiredValue "2. Which business workflow should the demo follow?" $flowSuggestions[0]
$audiencePersona = Read-RequiredValue "3. Who is watching this demo?" $targetAudience
$demoScope = Read-RequiredValue "4. What should the demo include?" (($artifacts -join ', '))
$durationChoice = Read-RequiredValue "5. Target duration in minutes? (3/5/10/15)" "5"
[int]$durationMinutes = 5
if (-not [int]::TryParse($durationChoice, [ref]$durationMinutes)) {
    throw "Duration must be a whole number of minutes."
}

$dataModeDefault = if ($demoDataRequirement -match '^(yes|y)$') { "Use prepared sample data where helpful, but show at least one live change." } else { "Start with the current app state and explain what data would exist in production." }
$dataMode = Read-MultilineValue "6. How should the demo start with data?" $dataModeDefault

$talkingPointDefault = "Emphasize how $workflow resolves '$problemStatement' for $users and prove success through: $successCriteria"
$talkingPoints = Read-MultilineValue "7. What key talking points should be emphasized?" $talkingPointDefault

$preDemoDefault = "Verify access to $environmentUrl, open the app, and queue any sample records needed for the $heroRecord story."
$preDemoSetup = Read-MultilineValue "8. What should the presenter prepare before starting?" $preDemoDefault

$steps = Get-DemoSteps -Entities $entities -Artifacts $artifacts -HeroRecord $heroRecord -Workflow $workflow -DataMode $dataMode -Audience $audiencePersona -SuccessCriteria $successCriteria -TalkingPoints $talkingPoints -DurationMinutes $durationMinutes

$demoAnswersContent = @"
# Demo Script Answers

## Scenario
- Name: $scenarioName
- Slug: $ScenarioSlug

## Demo Wizard Answers
1. Hero record: $heroRecord
2. Workflow: $workflow
3. Audience persona: $audiencePersona
4. Demo scope: $demoScope
5. Duration minutes: $durationMinutes
6. Data start mode: $dataMode
7. Key talking points: $talkingPoints
8. Pre-demo setup: $preDemoSetup
"@

$stepLines = New-Object System.Collections.Generic.List[string]
for ($index = 0; $index -lt $steps.Count; $index++) {
    $minutes = Get-StepMinutes -DurationMinutes $durationMinutes -StepIndex $index -StepCount $steps.Count
    $step = $steps[$index]
    $stepLines.Add("### Step $($index + 1): $($step.Title) ($minutes min)")
    $stepLines.Add("**Narrative**")
    $stepLines.Add($step.Narrative)
    $stepLines.Add("")
    $stepLines.Add("**Actions**")
    foreach ($action in $step.Actions) {
        $stepLines.Add("- $action")
    }
    $stepLines.Add("")
    $stepLines.Add("**Key Points**")
    foreach ($point in $step.KeyPoints) {
        $stepLines.Add("- $point")
    }
    $stepLines.Add("")
}

$artifactDisplay = if ($artifacts.Count -gt 0) { $artifacts[0] } else { "primary artifact" }

$demoScriptContent = @"
# Demo Script: $scenarioName

## Demo Overview
- Title: $heroRecord demo for $workflow
- Target audience: $audiencePersona
- Duration: $durationMinutes minutes
- Hero record: $heroRecord
- Business problem: $problemStatement
- Success measure: $successCriteria
- Environment: $environmentUrl

## Presenter Start Point
$preDemoSetup

## Suggested Business Use Case
$workflow

## Review Request
Review this script and decide whether the story, steps, and talking points match the demo you want to deliver. Ask for edits if you want a different workflow, audience emphasis, or pacing.

## Pre-Demo Checklist
- [ ] Confirm environment access in $environmentUrl
- [ ] Open the app area for $heroRecord
- [ ] Verify the demo scope items are available: $demoScope
- [ ] Prepare data approach: $dataMode
- [ ] Confirm success measure to prove during the demo: $successCriteria

## Presenter Talking Points
- $talkingPoints
- Show how the workflow supports $users
- Reinforce the business problem: $problemStatement
- Tie the final state back to the success measure: $successCriteria

## Demo Flow
$($stepLines -join [Environment]::NewLine)
## Demo Success Indicators
- [ ] The hero record story is clear and easy to follow
- [ ] The workflow demonstrates: $workflow
- [ ] The audience sees the main artifact or experience: $artifactDisplay
- [ ] The measurable success outcome is proven: $successCriteria

## Fallback Path
- If the live data state is not ready, explain the intended state and continue from the closest prepared record.
- If an automation step is delayed, narrate the expected result and show the supporting artifact manually.
- If a screen or view is unavailable, switch to the most relevant form, record, or dashboard that still proves the use case.

## Optional Dry Run
To rehearse this script interactively, run:

```powershell
pwsh ./scripts/bootstrap/07-demo-dry-run.ps1 -ScenarioSlug $ScenarioSlug
```
"@

Set-Content -Path $demoAnswersPath -Value $demoAnswersContent -Encoding UTF8
Set-Content -Path $demoScriptPath -Value $demoScriptContent -Encoding UTF8

Write-Host ""
Write-Host "Demo script output created:" -ForegroundColor Green
Write-Host "  $demoAnswersPath"
Write-Host "  $demoScriptPath"
Write-Host ""
Write-Host "Next step:" -ForegroundColor Cyan
Write-Host "  Review demo-script.md and ask for edits if you want a different story, pacing, or emphasis."
