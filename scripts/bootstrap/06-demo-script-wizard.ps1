<#
.SYNOPSIS
    Generates a scenario-aware demo script from the outputs of 05-start-wizard.ps1.

.DESCRIPTION
    Reads `answers.md`, `spec.md`, `plan.md`, and `tasks.md` from
    `specs/<scenario-slug>/`, suggests a scenario-derived demo flow, asks a
    small set of demo-specific questions, and writes two scenario-based
    artifacts back to the same folder:
    - `demo-walkthrough.md` (engineer/operator walkthrough)
    - `demo-talk-track.md` (presenter script)

    For compatibility, it also writes `demo-script.md` as a copy of the
    talk track.

    The script is intentionally generic. It works with any scenario created by
    the first wizard by reusing the scenario's problem statement, target users,
    entities, artifacts, success criteria, and environment details.

.PARAMETER ScenarioSlug
    Existing scenario folder under `specs/`.

.PARAMETER Force
    Overwrite demo artifacts without prompting.

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

function Get-ChecklistItems {
    param([string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return @()
    }

    $matches = [regex]::Matches($Content, '(?m)^- \[[ xX]\]\s+(.+)$')
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($m in $matches) {
        $items.Add($m.Groups[1].Value.Trim())
    }
    return @($items)
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
        [int]$DurationMinutes,
        [string]$TalkTrackStyle = "verbose"
    )

    $artifactSummary = if ($Artifacts.Count -gt 0) { $Artifacts -join ", " } else { "the scenario artifacts" }
    $secondaryEntity = if ($Entities.Count -gt 1) { $Entities[1] } elseif ($Entities.Count -gt 0) { $Entities[0] } else { $HeroRecord }
    $normalizedStyle = ($TalkTrackStyle ?? "verbose").Trim().ToLowerInvariant()
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

    if ($normalizedStyle -eq "short") {
        foreach ($step in $steps) {
            if ($step.Actions.Count -gt 2) {
                $step.Actions = @($step.Actions | Select-Object -First 2)
            }
            if ($step.KeyPoints.Count -gt 2) {
                $step.KeyPoints = @($step.KeyPoints | Select-Object -First 2)
            }
        }
    }

    return $steps
}

function Get-TalkTrackStyle {
    param([string]$Value)

    $normalized = ($Value ?? "").Trim().ToLowerInvariant()
    switch ($normalized) {
        "short" { return "short" }
        "verbose" { return "verbose" }
        default { throw "Talk track style must be 'short' or 'verbose'." }
    }
}

function Get-TalkTrackOpening {
    param(
        [string]$Style,
        [string]$ScenarioName,
        [string]$AudiencePersona,
        [string]$ProblemStatement,
        [string]$SuccessCriteria,
        [string]$HeroRecord
    )

    if ($Style -eq "short") {
        return @(
            '"Today I am showing how ' + $ScenarioName + ' helps ' + $AudiencePersona + ' handle ' + $ProblemStatement + '."',
            '"Watch for this result: ' + $SuccessCriteria + '."'
        )
    }

    return @(
        '"Today I am showing how ' + $ScenarioName + ' helps ' + $AudiencePersona + ' solve this problem: ' + $ProblemStatement + '."',
        '"The success signal is: ' + $SuccessCriteria + '."',
        '"I will anchor the walkthrough on ' + $HeroRecord + ' and show how the scenario flows from intake to outcome."'
    )
}

function Get-TalkTrackClosing {
    param(
        [string]$Style,
        [string]$CompactWorkflow,
        [string]$SuccessCriteria
    )

    if ($Style -eq "short") {
        return @(
            '"We demonstrated ' + $CompactWorkflow + ' and proved ' + $SuccessCriteria + '."'
        )
    }

    return @(
        '"To recap, we demonstrated ' + $CompactWorkflow + ' and confirmed the expected outcome: ' + $SuccessCriteria + '."',
        '"Next, we can review edits for pacing, audience emphasis, or depth."'
    )
}

function Get-TalkTrackPhrases {
    param(
        [string]$Style,
        [string]$TalkingPoints
    )

    $phrases = New-Object System.Collections.Generic.List[string]
    $phrases.Add('"' + $TalkingPoints + '"')
    $phrases.Add('"We can trace this outcome directly to the scenario requirements and mapping."')
    if ($Style -eq "short") {
        $phrases.Add('"This is the exact result the business asked to see."')
    }
    else {
        $phrases.Add('"What you are seeing aligns to the defined success measure."')
        $phrases.Add('"The implementation stays aligned to the scenario files and explicit mapping."')
    }

    return @($phrases)
}

function Format-TalkTrackSteps {
    param(
        [object[]]$Steps,
        [int]$DurationMinutes,
        [string]$TalkTrackStyle
    )

    $stepLines = New-Object System.Collections.Generic.List[string]
    $normalizedStyle = ($TalkTrackStyle ?? "verbose").Trim().ToLowerInvariant()

    for ($index = 0; $index -lt $Steps.Count; $index++) {
        $minutes = Get-StepMinutes -DurationMinutes $DurationMinutes -StepIndex $index -StepCount $Steps.Count
        $step = $Steps[$index]
        $stepLines.Add("### Step $($index + 1): $($step.Title) ($minutes min)")

        if ($normalizedStyle -eq "short") {
            $stepLines.Add("**Say**")
            $stepLines.Add($step.Narrative)
            $stepLines.Add("")
            $stepLines.Add("**Show**")
            foreach ($action in $step.Actions) {
                $stepLines.Add("- $action")
            }
        }
        else {
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
        }

        $stepLines.Add("")
    }

    return @($stepLines)
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

function Get-CompactWorkflowText {
    param([string]$Workflow)

    if ([string]::IsNullOrWhiteSpace($Workflow)) { return "the core scenario workflow" }
    $trimmed = $Workflow.Trim()
    if ($trimmed.Length -le 160) { return $trimmed }
    return ($trimmed.Substring(0, 157) + "...")
}

function Normalize-MarkdownText {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return "" }
    # Prevent PowerShell escape expansion in interpolated markdown output.
    return $Text.Replace([string][char]96, "'")
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
$planPath = Join-Path $scenarioFolder "plan.md"
$tasksPath = Join-Path $scenarioFolder "tasks.md"
$demoScriptPath = Join-Path $scenarioFolder "demo-script.md"
$demoWalkthroughPath = Join-Path $scenarioFolder "demo-walkthrough.md"
$demoTalkTrackPath = Join-Path $scenarioFolder "demo-talk-track.md"
$demoAnswersPath = Join-Path $scenarioFolder "demo-script-answers.md"

if (-not (Test-Path $specPath)) {
    throw "Missing spec file: $specPath"
}

if (-not (Test-Path $answersPath)) {
    throw "Missing answers file: $answersPath"
}

if (-not (Test-Path $planPath)) {
    throw "Missing plan file: $planPath"
}

if (-not (Test-Path $tasksPath)) {
    throw "Missing tasks file: $tasksPath"
}

$existingFiles = @($demoScriptPath, $demoWalkthroughPath, $demoTalkTrackPath, $demoAnswersPath | Where-Object { Test-Path $_ })
if ($existingFiles.Count -gt 0 -and -not $Force) {
    if (-not (Confirm-Overwrite -Paths $existingFiles)) {
        Write-Host ""
        Write-Host "No files were changed." -ForegroundColor Yellow
        exit 0
    }
}

$specContent = Get-Content -Path $specPath -Raw -Encoding UTF8
$answersContent = Get-Content -Path $answersPath -Raw -Encoding UTF8
$planContent = Get-Content -Path $planPath -Raw -Encoding UTF8
$tasksContent = Get-Content -Path $tasksPath -Raw -Encoding UTF8

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
$specMapping = Get-MarkdownSectionValue -Content $specContent -Heading "Explicit Entity Mapping (Required)"
$planMapping = Get-MarkdownSectionValue -Content $planContent -Heading "Explicit Entity Mapping (Required Before Payloads)"
$validationPlan = Get-MarkdownSectionValue -Content $planContent -Heading "Validation Plan"
$taskItems = Get-ChecklistItems -Content $tasksContent

$mappingText = if (-not [string]::IsNullOrWhiteSpace($specMapping)) { $specMapping } else { $planMapping }

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
$scenarioDrivenFlow = "Run the end-to-end $($scenarioName) story from intake through closure, using $($entities -join ', ') and proving '$successCriteria'."
if (-not [string]::IsNullOrWhiteSpace($mappingText)) {
    $scenarioDrivenFlow += " Keep entity behavior aligned with the explicit standard/custom mapping in the scenario files."
}
$flowSuggestions = @($scenarioDrivenFlow) + @($flowSuggestions)

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

$talkTrackStyle = Get-TalkTrackStyle -Value (Read-RequiredValue "7. Should the presenter talk track be short or verbose?" "verbose")

$talkingPointDefault = "Emphasize how $workflow resolves '$problemStatement' for $users and prove success through: $successCriteria"
$talkingPoints = Read-MultilineValue "8. What key talking points should be emphasized?" $talkingPointDefault

$preDemoDefault = "Verify access to $environmentUrl, open the app, and queue any sample records needed for the $heroRecord story."
$preDemoSetup = Read-MultilineValue "9. What should the presenter prepare before starting?" $preDemoDefault

$steps = Get-DemoSteps -Entities $entities -Artifacts $artifacts -HeroRecord $heroRecord -Workflow $workflow -DataMode $dataMode -Audience $audiencePersona -SuccessCriteria $successCriteria -TalkingPoints $talkingPoints -DurationMinutes $durationMinutes -TalkTrackStyle $talkTrackStyle
$compactWorkflow = Get-CompactWorkflowText -Workflow $workflow
$stepLines = Format-TalkTrackSteps -Steps $steps -DurationMinutes $durationMinutes -TalkTrackStyle $talkTrackStyle
$openingLines = Get-TalkTrackOpening -Style $talkTrackStyle -ScenarioName $scenarioName -AudiencePersona $audiencePersona -ProblemStatement $problemStatement -SuccessCriteria $successCriteria -HeroRecord $heroRecord
$closingLines = Get-TalkTrackClosing -Style $talkTrackStyle -CompactWorkflow $compactWorkflow -SuccessCriteria $successCriteria
$keyPhrases = Get-TalkTrackPhrases -Style $talkTrackStyle -TalkingPoints $talkingPoints

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
7. Talk track style: $talkTrackStyle
8. Key talking points: $talkingPoints
9. Pre-demo setup: $preDemoSetup
10. Output artifacts: demo-walkthrough.md and demo-talk-track.md
"@

$artifactDisplay = if ($artifacts.Count -gt 0) { $artifacts[0] } else { "primary artifact" }
$topTasks = @($taskItems | Select-Object -First 10)
$topTasksText = if ($topTasks.Count -gt 0) { ($topTasks | ForEach-Object { "- [ ] $(Normalize-MarkdownText -Text $_)" }) -join [Environment]::NewLine } else { "- [ ] No task list items found." }
$mappingDisplay = if (-not [string]::IsNullOrWhiteSpace($mappingText)) { $mappingText } else { "No explicit entity mapping block found." }
$validationDisplay = if (-not [string]::IsNullOrWhiteSpace($validationPlan)) { $validationPlan } else { "No validation plan block found." }

$demoWalkthroughContent = @"
# Demo Walkthrough: $scenarioName

## Purpose
This walkthrough is for the engineer/operator running the demo. It is derived from scenario files and should stay aligned to the implemented solution.

## Scenario Source
- Derived from: answers.md, spec.md, plan.md, and tasks.md in specs/$ScenarioSlug/
- Scenario name: $scenarioName
- Platform area: $([regex]::Match($wizardBlock, '(?m)^2\. Platform area:\s*(.+)$').Groups[1].Value)
- Environment: $environmentUrl

## Scenario Requirements Snapshot
- Business problem: $problemStatement
- Success criteria: $successCriteria
- Required entities: $requiredEntitiesText
- Required artifacts: $artifactsText

### Explicit Entity Mapping
$mappingDisplay

### Validation Plan
$validationDisplay

## Engineer Runbook
### Pre-demo Setup
- Confirm environment access and app load in $environmentUrl.
- Validate demo data availability mode: $dataMode
- Open the hero record area for: $heroRecord
- Confirm demo scope artifacts are available: $demoScope

### Implementation Walkthrough Checklist
$topTasksText

### What To Show (Implementation-Oriented)
- Show where the hero record ($heroRecord) is managed.
- Demonstrate how configured entities/artifacts support: $compactWorkflow
- Show one verification signal tied to success criteria.

### Risk Mitigation During Demo
- If live data is missing, pivot to nearest prepared record and narrate expected outcome.
- If automation is delayed, show artifact evidence and explain eventual state.
- If a screen/view is unavailable, use the closest form/view that still proves the scenario.

## Review Gate
- [ ] Walkthrough reflects current spec/plan/tasks.
- [ ] Mapping section matches implemented standard/custom model.
- [ ] Success criteria can be demonstrated in under $durationMinutes minutes.
"@

$demoTalkTrackContent = @"
# Demo Talk Track: $scenarioName

## Presenter Brief
- Audience: $audiencePersona
- Duration: $durationMinutes minutes
- Style: $talkTrackStyle
- Story anchor: $heroRecord
- Core workflow: $compactWorkflow

## Opening (30-45 sec)
$($openingLines -join [Environment]::NewLine)

## Talk Track Steps
$($stepLines -join [Environment]::NewLine)

## Key Phrases To Use
$($keyPhrases | ForEach-Object { "- $_" } | Out-String)

## Closing (20-30 sec)
$($closingLines -join [Environment]::NewLine)

## Presenter Checklist
- [ ] Keep language outcome-first, not implementation-heavy.
- [ ] Call out the hero record and business impact clearly.
- [ ] End by restating measurable success criteria.
"@

Set-Content -Path $demoAnswersPath -Value $demoAnswersContent -Encoding UTF8
Set-Content -Path $demoWalkthroughPath -Value $demoWalkthroughContent -Encoding UTF8
Set-Content -Path $demoTalkTrackPath -Value $demoTalkTrackContent -Encoding UTF8
# Backward-compatible artifact used by existing dry-run tooling.
Set-Content -Path $demoScriptPath -Value $demoTalkTrackContent -Encoding UTF8

Write-Host ""
Write-Host "Demo script output created:" -ForegroundColor Green
Write-Host "  $demoAnswersPath"
Write-Host "  $demoWalkthroughPath"
Write-Host "  $demoTalkTrackPath"
Write-Host "  $demoScriptPath (compatibility copy of talk track)"
Write-Host ""
Write-Host "Next step:" -ForegroundColor Cyan
Write-Host "  Review demo-walkthrough.md (engineer) and demo-talk-track.md (presenter) and ask for edits if you want different story, pacing, or emphasis."
