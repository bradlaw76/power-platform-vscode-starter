<#
=============================================================================
COMPONENT:    Demo Script Wizard
FILE:         scripts/bootstrap/06-demo-script-wizard.ps1
VERSION:      0.2.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | VS Code | Demo Walkthrough Generation

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Builds demo-script artifacts from approved planning files so a scenario can be
presented consistently after discovery and before or alongside implementation.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          scenario answers and planning artifacts
- Outputs:         demo script, talk track, walkthrough, and dry-run assets
- Dependencies:    scenario planning files and repo documentation conventions
- Side Effects:    writes presentation artifacts under specs/<scenario-slug>

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Scenario planning files must already exist.
2. Run within the repo workflow for a selected scenario slug.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Existing scenario planning files generate demo artifacts successfully.
✔ Output references the correct scenario folder and artifact names.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.2.0  2026-09-22  Added interactive HTML presenter with timer and theme toggle.
v0.1.1  2026-08-18  Made demo duration an explicit positive-minute intake question.
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Keep generated demo artifacts derived from approved planning inputs.
- Do not invent scenario content outside the available planning context.
- Update this header when the step contract materially changes.
=============================================================================
#>

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
    - `<scenario-slug>-demo-presenter.html` (interactive presenter companion)

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

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "06-demo-script-wizard.ps1"
}

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
        [string]$ScenarioName,
        [string]$ProblemStatement,
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

    $artifactSummary = if ($Artifacts.Count -gt 0) { Get-CompactText -Text ($Artifacts -join ", ") -MaximumLength 220 } else { "the scenario artifacts" }
    $successSummary = Get-CompactText -Text $SuccessCriteria -MaximumLength 180
    $problemSummary = Get-CompactText -Text $ProblemStatement -MaximumLength 180
    $entitySummary = if ($Entities.Count -gt 0) { $Entities -join ", " } else { "the connected business records" }
    $secondaryEntity = if ($Entities.Count -gt 1) { $Entities[1] } elseif ($Entities.Count -gt 0) { $Entities[0] } else { $HeroRecord }
    $normalizedStyle = ($TalkTrackStyle ?? "verbose").Trim().ToLowerInvariant()
    $pace = switch ($DurationMinutes) {
        { $_ -le 3 } { "Keep the clicks minimal and speak to outcomes quickly." }
        { $_ -le 5 } { "Keep the story tight and focus on the primary workflow." }
        { $_ -le 10 } { "Show the primary workflow and one supporting artifact." }
        default { "Show the primary workflow, supporting artifacts, and one exception path." }
    }

    $steps = New-Object System.Collections.Generic.List[object]
    $steps.Add([ordered]@{
        Title = "Opening and positioning"
        Narrative = "Frame the scenario around the business problem, the people affected, and the outcome the audience should watch for. $pace"
        Actions = @(
            "Keep the starting experience visible without opening a record",
            "Point out where the workflow begins",
            "Confirm the audience can see the primary app or page"
        )
        KeyPoints = @(
            "The demo proves a business outcome, not just a collection of features",
            "Target audience: $Audience",
            "Success signal: $successSummary"
        )
    })

    if ($DurationMinutes -gt 10) {
        $steps.Add([ordered]@{
            Title = "User and workload context"
            Narrative = "Explain how $Audience works with this workload, what creates urgency, and why a guided experience matters before showing individual features."
            Actions = @(
                "Show the landing page, work queue, or starting view",
                "Identify the volume, priority, owner, or status signals available to the user",
                "Explain how the user decides what to work next"
            )
            KeyPoints = @(
                "The experience should make the next best piece of work obvious",
                "The workflow begins with context rather than navigation"
            )
        })
    }

    if ($DurationMinutes -gt 25) {
        $steps.Add([ordered]@{
            Title = "Experience and data orientation"
            Narrative = "Orient the audience to the scenario structure before entering the transaction, using the planned entities and artifacts as the map for the story."
            Actions = @(
                "Identify the primary experience and its major regions",
                "Show where $HeroRecord, $secondaryEntity, and related information appear",
                "Connect the visible experience to the planned scenario artifacts"
            )
            KeyPoints = @(
                "The experience organizes connected business data around the user's task",
                "Scenario assets in scope: $artifactSummary"
            )
        })
    }

    $steps.Add([ordered]@{
        Title = "Hero record selection"
        Narrative = "Introduce $HeroRecord as the anchor for the story and explain why this record deserves attention now."
        Actions = @(
            "Navigate to the area where $HeroRecord is managed",
            "Select or open the prepared hero record",
            "Point out the fields or signals that establish priority and ownership"
        )
        KeyPoints = @(
            "$HeroRecord gives the audience a concrete thread to follow",
            "The design should reduce friction for $Audience"
        )
    })

    if ($DurationMinutes -gt 25) {
        $steps.Add([ordered]@{
            Title = "Related data and full context"
            Narrative = "Build confidence that the user has enough connected context to act without leaving the workflow or reconstructing the story manually."
            Actions = @(
                "Show the relationship between $HeroRecord and $secondaryEntity",
                "Review the related history, evidence, activity, or supporting information available",
                "Call out which information is authoritative for the next decision"
            )
            KeyPoints = @(
                "Connected context reduces searching and prevents avoidable handoffs",
                "The user can explain why the record is in its current state"
            )
        })
    }

    $steps.Add([ordered]@{
        Title = "Core workflow execution"
        Narrative = "Demonstrate the central business action using $HeroRecord and show how the experience guides the user from the current state toward the intended outcome."
        Actions = @(
            "Create or update the information required by the workflow",
            "Show validation, guidance, or required fields that shape the action",
            "Save the change and confirm the visible state reflects it"
        )
        KeyPoints = @(
            "Workflow outcome: $Workflow",
            "The process is controlled, repeatable, and visible"
        )
    })

    if ($DurationMinutes -gt 10) {
        $steps.Add([ordered]@{
            Title = "Evidence and decision support"
            Narrative = "Show how related information helps the user make a defensible decision, and distinguish supporting insight from the human decision itself."
            Actions = @(
                "Open the most relevant supporting record, artifact, or insight",
                "Connect that information to the decision being made",
                "Return to $HeroRecord and record or explain the resulting action"
            )
            KeyPoints = @(
                "Supporting information is useful when it is connected to a specific decision",
                "The user remains accountable for the business outcome"
            )
        })
    }

    if ($DurationMinutes -gt 25) {
        $steps.Add([ordered]@{
            Title = "Exception path and guardrails"
            Narrative = "Demonstrate how the experience responds when information is incomplete, an exception appears, or the normal path should not continue."
            Actions = @(
                "Identify an exception, missing value, or alternate state in the prepared data",
                "Show the visible warning, validation, or review path",
                "Explain who owns the decision and how the exception is resolved"
            )
            KeyPoints = @(
                "A credible workflow makes exceptions visible instead of hiding them",
                "Guardrails support judgment without replacing accountability"
            )
        })
    }

    $steps.Add([ordered]@{
        Title = "Supporting experience"
        Narrative = "Use the planned artifacts to prove that the workflow is operational, discoverable, and useful beyond the single record."
        Actions = @(
            "Show the most important supporting experience from the scenario",
            "Explain how users monitor, find, or act on work",
            "Connect the artifact back to the business problem"
        )
        KeyPoints = @(
            "Supporting experiences turn a transaction into an operating process",
            "Primary assets in scope: $artifactSummary"
        )
    })

    if ($DurationMinutes -gt 10) {
        $steps.Add([ordered]@{
            Title = "Oversight and measurable outcomes"
            Narrative = "Move from the individual record to the management view and show how leaders understand workload, progress, and outcomes."
            Actions = @(
                "Open the relevant view, chart, dashboard, or summary",
                "Connect the aggregate signal back to the hero record story",
                "Identify the measure that demonstrates success"
            )
            KeyPoints = @(
                "Operational visibility should lead to a clear management action",
                "Measured outcome: $successSummary"
            )
        })
    }

    if ($DurationMinutes -gt 25) {
        $steps.Add([ordered]@{
            Title = "Scale, configuration, and governance"
            Narrative = "Explain how the demonstrated pattern can be maintained and extended without claiming that every production decision is already complete."
            Actions = @(
                "Identify the configuration or administration surface relevant to the scenario",
                "Explain how ownership, security, or controlled changes would be managed",
                "Separate the demonstrated pattern from production rollout decisions"
            )
            KeyPoints = @(
                "The demo is a working pattern that can be governed and extended",
                "Production readiness requires validated security, data, ownership, and operating decisions"
            )
        })
    }

    $steps.Add([ordered]@{
        Title = "Success recap and close"
        Narrative = "Return to the original business problem, summarize what changed for the user, and close on the measurable result rather than the final screen."
        Actions = @(
            "Restate the problem and the completed workflow",
            "Show the final state or outcome for $HeroRecord",
            "Invite questions or confirm the next review decision"
        )
        KeyPoints = @(
            "Close on the result: $successSummary",
            "Data approach during the demo: $DataMode"
        )
    })

    if (-not [string]::IsNullOrWhiteSpace($TalkingPoints)) {
        $steps[0].KeyPoints += "Special emphasis: $TalkingPoints"
    }

    for ($index = 0; $index -lt $steps.Count; $index++) {
        $step = $steps[$index]
        $sayLines = switch ($step.Title) {
            "Opening and positioning" {
                @(
                    "Today I am showing how $ScenarioName helps $Audience address this business problem: $problemSummary",
                    "The story follows $HeroRecord through this workflow: $Workflow",
                    "This is a working demonstration pattern grounded in the approved scenario artifacts; production decisions still require the appropriate business, security, data, and operating reviews.",
                    "The outcome to watch for is: $successSummary"
                )
            }
            "User and workload context" {
                @(
                    "For $Audience, the challenge is not simply opening a record. It is knowing what needs attention, who owns it, and what should happen next.",
                    "The starting experience brings the active workload into one place so the user can begin with priority and context rather than navigation.",
                    "The prepared data lets us follow one concrete example while keeping the broader workload visible."
                )
            }
            "Experience and data orientation" {
                @(
                    "The experience connects $entitySummary around the work the user is trying to complete.",
                    "The planned experience includes $artifactSummary",
                    "These surfaces organize the same connected business data; they are not separate systems of record.",
                    "As we move through the demo, the $HeroRecord remains the anchor that connects context, action, and outcome."
                )
            }
            "Hero record selection" {
                @(
                    "This is the hero record for the walkthrough: $HeroRecord.",
                    "Its visible status, priority, ownership, and related context explain why it deserves attention now.",
                    "The record gives us one traceable story that we can follow from the initial review through the resulting business outcome."
                )
            }
            "Related data and full context" {
                @(
                    "The related $secondaryEntity information gives the user context without requiring a separate search or an offline reconstruction of the story.",
                    "History, activity, evidence, and other supporting records remain connected to $HeroRecord so the user can understand how the current state was reached.",
                    "The purpose of this context is not to add more screens; it is to support a faster and more defensible decision."
                )
            }
            "Core workflow execution" {
                @(
                    "Now I am carrying out the central workflow: $Workflow",
                    "The experience keeps the required information and guidance close to the action, so the user can complete the work without losing context.",
                    "When the record is saved, the visible state becomes part of the shared operational record rather than a private note or disconnected update.",
                    "The important point is that the process is controlled, repeatable, and visible to the people who depend on the outcome."
                )
            }
            "Evidence and decision support" {
                @(
                    "This supporting information helps the user understand the record and make a defensible decision.",
                    "The insight is connected to a specific action; it does not replace the underlying record or the user's accountability.",
                    "The user can verify the supporting detail, return to $HeroRecord, and record the resulting decision in the same workflow."
                )
            }
            "Exception path and guardrails" {
                @(
                    "A credible business process must make exceptions visible instead of forcing every record through the happy path.",
                    "When information is incomplete or a condition needs review, the experience exposes that issue and keeps ownership clear.",
                    "The guardrail supports human judgment; it does not silently make the business decision on the user's behalf."
                )
            }
            "Supporting experience" {
                @(
                    "The supporting experience extends the story beyond one record and helps users find, monitor, and act on the broader workload.",
                    "For this project, the planned supporting assets are: $artifactSummary",
                    "Each surface should lead back to the connected operational record when the user needs to investigate or take action."
                )
            }
            "Oversight and measurable outcomes" {
                @(
                    "This view moves from the individual record to the operational picture that supervisors and leaders need.",
                    "The aggregate signals show workload, ownership, progress, or outcomes while the underlying records remain available for review.",
                    "The management question is not only what the number is, but what action that signal should prompt.",
                    "The success measure for this scenario is: $successSummary"
                )
            }
            "Scale, configuration, and governance" {
                @(
                    "What you are seeing is a configured demonstration baseline based on the current project plan, not a claim that every production decision is complete.",
                    "The pattern can be extended through controlled configuration while security, ownership, data quality, and operating responsibilities remain explicit.",
                    "A production rollout would validate those decisions with the appropriate business and technical owners before broader use."
                )
            }
            "Success recap and close" {
                @(
                    "We started with this problem: $problemSummary",
                    "We followed $HeroRecord through $Workflow and kept its context, actions, and outcome connected.",
                    "The demonstrated result is: $successSummary",
                    "The next decision is whether this story, level of detail, and operating pattern match what the project should take forward."
                )
            }
            default {
                @(
                    "This section continues the $ScenarioName story using $HeroRecord as the anchor.",
                    "The visible experience connects the user's action to the intended business outcome."
                )
            }
        }

        if ($normalizedStyle -eq "short" -and $sayLines.Count -gt 2) {
            $sayLines = @($sayLines | Select-Object -First 2)
        }

        $step.SayLines = @($sayLines)
        $step.KeyLine = $step.KeyPoints[0]
        $step.Transition = if ($index -lt ($steps.Count - 1)) {
            $nextTitle = $steps[$index + 1].Title.ToLowerInvariant()
            "Next, shift to $nextTitle and keep the story anchored on $HeroRecord."
        }
        else {
            "Pause on the outcome, invite questions, and confirm the next decision or follow-up."
        }
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

    return $steps.ToArray()
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
            $stepLines.Add("**What to Say**")
            foreach ($line in $step.SayLines) {
                $stepLines.Add("> $line")
                $stepLines.Add("")
            }
            $stepLines.Add("**Key Line**")
            $stepLines.Add($step.KeyLine)
            $stepLines.Add("")
            $stepLines.Add("**On Screen**")
            foreach ($action in $step.Actions) {
                $stepLines.Add("- $action")
            }
            $stepLines.Add("")
            $stepLines.Add("**Transition**")
            $stepLines.Add($step.Transition)
        }
        else {
            $stepLines.Add("**What to Say**")
            foreach ($line in $step.SayLines) {
                $stepLines.Add("> $line")
                $stepLines.Add("")
            }
            $stepLines.Add("**Key Line**")
            $stepLines.Add($step.KeyLine)
            $stepLines.Add("")
            $stepLines.Add("**On Screen**")
            foreach ($action in $step.Actions) {
                $stepLines.Add("- $action")
            }
            $stepLines.Add("")
            $stepLines.Add("**Transition**")
            $stepLines.Add($step.Transition)
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

function Get-CompactText {
    param(
        [string]$Text,
        [int]$MaximumLength = 180
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "the expected business outcome"
    }

    $compact = ($Text -replace '\s+', ' ').Trim()
    if ($compact.Length -le $MaximumLength) {
        return $compact
    }

    return ($compact.Substring(0, $MaximumLength - 3).TrimEnd() + "...")
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
$demoPresenterPath = Join-Path $scenarioFolder "$ScenarioSlug-demo-presenter.html"
$demoPresenterTemplatePath = Join-Path $PSScriptRoot "templates\demo-presenter.template.html"

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

if (-not (Test-Path $demoPresenterTemplatePath)) {
    throw "Missing demo presenter template: $demoPresenterTemplatePath"
}

$existingFiles = @($demoScriptPath, $demoWalkthroughPath, $demoTalkTrackPath, $demoAnswersPath, $demoPresenterPath | Where-Object { Test-Path $_ })
if ($existingFiles.Count -gt 0 -and -not $Force) {
    if (-not (Confirm-Overwrite -Paths $existingFiles)) {
        Write-Host ""
        Write-Host "No files were changed." -ForegroundColor Yellow
        if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
            Complete-WizardStepTelemetry -Message "Demo script generation cancelled by user."
        }
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
$durationChoice = Read-RequiredValue "5. How long should the demo timer run, in minutes?" "5"
[int]$durationMinutes = 5
if (-not [int]::TryParse($durationChoice, [ref]$durationMinutes) -or $durationMinutes -lt 1) {
    throw "Duration must be a positive whole number of minutes."
}

$dataModeDefault = if ($demoDataRequirement -match '^(yes|y)$') { "Use prepared sample data where helpful, but show at least one live change." } else { "Start with the current app state and explain what data would exist in production." }
$dataMode = Read-MultilineValue "6. How should the demo start with data?" $dataModeDefault

$talkTrackStyle = Get-TalkTrackStyle -Value (Read-RequiredValue "7. Should the presenter talk track be short or verbose?" "verbose")

$talkingPointDefault = "Emphasize how $workflow resolves '$problemStatement' for $users and prove success through: $successCriteria"
$talkingPoints = Read-MultilineValue "8. What key talking points should be emphasized?" $talkingPointDefault

$preDemoDefault = "Verify access to $environmentUrl, open the app, and queue any sample records needed for the $heroRecord story."
$preDemoSetup = Read-MultilineValue "9. What should the presenter prepare before starting?" $preDemoDefault

$steps = Get-DemoSteps -ScenarioName $scenarioName -ProblemStatement $problemStatement -Entities $entities -Artifacts $artifacts -HeroRecord $heroRecord -Workflow $workflow -DataMode $dataMode -Audience $audiencePersona -SuccessCriteria $successCriteria -TalkingPoints $talkingPoints -DurationMinutes $durationMinutes -TalkTrackStyle $talkTrackStyle
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
10. Output artifacts: demo-walkthrough.md, demo-talk-track.md, and $ScenarioSlug-demo-presenter.html
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

$presenterSteps = for ($index = 0; $index -lt $steps.Count; $index++) {
    $step = $steps[$index]
    [ordered]@{
        title = $step.Title
        narrative = $step.Narrative
        sayLines = @($step.SayLines)
        actions = @($step.Actions)
        keyPoints = @($step.KeyPoints)
        keyLine = $step.KeyLine
        transition = $step.Transition
        minutes = Get-StepMinutes -DurationMinutes $durationMinutes -StepIndex $index -StepCount $steps.Count
    }
}
$presenterData = [ordered]@{
    scenarioName = $scenarioName
    scenarioSlug = $ScenarioSlug
    problemStatement = $problemStatement
    audience = $audiencePersona
    heroRecord = $heroRecord
    durationMinutes = $durationMinutes
    successCriteria = Get-CompactText -Text $successCriteria -MaximumLength 180
    preDemoSetup = $preDemoSetup
    steps = @($presenterSteps)
}
$presenterJson = $presenterData | ConvertTo-Json -Depth 8 -Compress
$presenterJson = $presenterJson.Replace("<", "\u003c").Replace(">", "\u003e").Replace("&", "\u0026")
$demoPresenterContent = Get-Content -Path $demoPresenterTemplatePath -Raw -Encoding UTF8
if (-not $demoPresenterContent.Contains("__DEMO_DATA_JSON__")) {
    throw "Demo presenter template is missing the __DEMO_DATA_JSON__ placeholder."
}
$demoPresenterContent = $demoPresenterContent.Replace("__DEMO_DATA_JSON__", $presenterJson)

Set-Content -Path $demoAnswersPath -Value $demoAnswersContent -Encoding UTF8
Set-Content -Path $demoWalkthroughPath -Value $demoWalkthroughContent -Encoding UTF8
Set-Content -Path $demoTalkTrackPath -Value $demoTalkTrackContent -Encoding UTF8
# Backward-compatible artifact used by existing dry-run tooling.
Set-Content -Path $demoScriptPath -Value $demoTalkTrackContent -Encoding UTF8
Set-Content -Path $demoPresenterPath -Value $demoPresenterContent -Encoding UTF8

Write-Host ""
Write-Host "Demo script output created:" -ForegroundColor Green
Write-Host "  $demoAnswersPath"
Write-Host "  $demoWalkthroughPath"
Write-Host "  $demoTalkTrackPath"
Write-Host "  $demoScriptPath (compatibility copy of talk track)"
Write-Host "  $demoPresenterPath (interactive presenter companion)"
Write-Host ""
Write-Host "Next step:" -ForegroundColor Cyan
Write-Host "  Open $ScenarioSlug-demo-presenter.html for the timed interactive presentation, and review the Markdown artifacts for edits."
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Demo script artifacts generated."
}
