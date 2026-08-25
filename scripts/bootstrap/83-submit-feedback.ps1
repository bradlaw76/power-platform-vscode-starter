#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Submit bug reports or enhancement requests to the GitHub repo as Issues.

.DESCRIPTION
    This script prompts wizard operators to submit feedback about their build experience
    as GitHub Issues. It auto-populates build context (scenario, tables, columns, forms, etc.)
    and tries to use the GitHub CLI (gh) with --web flag for browser-based submission.
    Falls back to opening a pre-filled GitHub Issue URL if gh is not available or not authenticated.

    All submission paths require human review before issue creation — no silent/auto-submit.

.PARAMETER ScenarioSlug
    The scenario slug (e.g., 'contoso-case-tracker'). If not provided, attempts to read
    from wizard.profile.json in the repo root. Interactive prompt if neither is available.

.PARAMETER FeedbackType
    The type of feedback: 'Bug' or 'Enhancement'. If not provided, prompts the user.
    Accepts 'B', 'E', or 'S' (skip) as shortcuts.

.PARAMETER SkipContextCollection
    If set, skips reading build-mind-map.json and events.jsonl. Useful for testing.

.EXAMPLE
    # Prompt for scenario and feedback type
    pwsh ./scripts/bootstrap/83-submit-feedback.ps1

    # Submit a bug for a specific scenario
    pwsh ./scripts/bootstrap/83-submit-feedback.ps1 -ScenarioSlug contoso-case-tracker -FeedbackType Bug

    # Skip context collection (fast path)
    pwsh ./scripts/bootstrap/83-submit-feedback.ps1 -ScenarioSlug contoso-case-tracker -SkipContextCollection

.NOTES
    Author: Power Platform Wizard
    Requires: PowerShell 5.0+, git, optional: GitHub CLI (gh)

    GitHub CLI (gh) is preferred but not required. If available and authenticated,
    opens GitHub Issue form in browser (--web) for review. Falls back to direct URL
    if gh is not available.

    Build context (tables, columns, forms, etc.) is auto-populated from:
    - .wizard-metrics/artifacts/analysis/build-mind-map.json
    - .wizard-metrics/events.jsonl (last run ID and final step)
    - wizard.profile.json (scenario, environment)
#>

param(
    [string]$ScenarioSlug,
    [ValidateSet('Bug', 'Enhancement', 'bug', 'enhancement', 'B', 'E', 'S', 'Skip')]
    [string]$FeedbackType,
    [switch]$SkipContextCollection
)

# Constants
$RepoRoot = (git rev-parse --show-toplevel 2>$null) -or (pwd).Path
$MetricsDir = Join-Path $RepoRoot ".wizard-metrics"
$AnalysisDir = Join-Path $MetricsDir "artifacts/analysis"
$BuildMindMapPath = Join-Path $AnalysisDir "build-mind-map.json"
$EventsPath = Join-Path $MetricsDir "events.jsonl"
$ProfilePath = Join-Path $RepoRoot "wizard.profile.json"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Power Platform Wizard — Feedback Submission" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# === Step 1: Determine Scenario Slug ===
if (-not $ScenarioSlug) {
    if (Test-Path $ProfilePath) {
        try {
            $profile = Get-Content $ProfilePath -Raw | ConvertFrom-Json -ErrorAction Stop
            $ScenarioSlug = $profile.scenarioSlug
            Write-Host "✓ Read scenario from wizard.profile.json: $ScenarioSlug" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Could not read scenario from wizard.profile.json" -ForegroundColor Yellow
        }
    }

    if (-not $ScenarioSlug) {
        Write-Host "Enter the scenario slug (e.g., 'contoso-case-tracker', or press Enter to skip feedback):" -ForegroundColor White
        $ScenarioSlug = Read-Host "Scenario"
        if (-not $ScenarioSlug) {
            Write-Host "Feedback submission skipped." -ForegroundColor Gray
            exit 0
        }
    }
}

# === Step 2: Determine Feedback Type ===
if (-not $FeedbackType) {
    Write-Host ""
    Write-Host "What type of feedback would you like to submit?" -ForegroundColor White
    Write-Host "  [B] Bug report" -ForegroundColor White
    Write-Host "  [E] Enhancement request" -ForegroundColor White
    Write-Host "  [S] Skip (I'll do this later)" -ForegroundColor White
    Write-Host ""

    $response = Read-Host "Enter your choice"
    $FeedbackType = switch ($response.ToUpper()) {
        'B' { 'Bug' }
        'E' { 'Enhancement' }
        'S' { 'Skip' }
        default {
            if ($response -match '^(Bug|Enhancement)$') { $response }
            else { 'Skip' }
        }
    }
}

# Normalize
$FeedbackType = $FeedbackType -replace '^b$', 'Bug' -replace '^e$', 'Enhancement' -replace '^s$', 'Skip' -replace '^bug$', 'Bug' -replace '^enhancement$', 'Enhancement'

if ($FeedbackType -eq 'Skip') {
    Write-Host "Feedback submission skipped." -ForegroundColor Gray
    exit 0
}

Write-Host ""
Write-Host "Preparing $FeedbackType feedback for scenario: $ScenarioSlug" -ForegroundColor Green

# === Step 3: Collect Build Context ===
$buildContext = @{
    scenario = $ScenarioSlug
    tableCount = 0
    tableNames = @()
    columnCount = 0
    relationshipCount = 0
    formCount = 0
    viewCount = 0
    webResourceCount = 0
    lastStep = "Unknown"
    runDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")
    environmentUrl = ""
    psVersion = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor).$($PSVersionTable.PSVersion.Patch)"
    pacVersion = ""
}

if (-not $SkipContextCollection) {
    # Load build-mind-map.json
    if (Test-Path $BuildMindMapPath) {
        try {
            $mindMap = Get-Content $BuildMindMapPath -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($mindMap.metadata) {
                $meta = $mindMap.metadata
                $buildContext.tableCount = @($meta.tables).Count
                $buildContext.tableNames = @($meta.tables).ForEach({ $_.name })
                $buildContext.columnCount = @($meta.columns).Count
                $buildContext.relationshipCount = @($meta.relationships).Count
                $buildContext.formCount = @($meta.forms).Count
                $buildContext.viewCount = @($meta.views).Count
                $buildContext.webResourceCount = @($meta.webResources).Count
            }
            Write-Host "✓ Loaded build context from build-mind-map.json" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Could not parse build-mind-map.json: $_" -ForegroundColor Yellow
        }
    }

    # Load environment URL from wizard.profile.json
    if (Test-Path $ProfilePath) {
        try {
            $profile = Get-Content $ProfilePath -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($profile.environmentUrl) {
                # Mask the URL (keep scheme and domain, mask trailing ID)
                $url = $profile.environmentUrl
                if ($url -match '(^https?://[^/]+/)(.{0,30})(.{6,})$') {
                    $buildContext.environmentUrl = "$($matches[1])$($matches[2])[...]"
                } else {
                    $buildContext.environmentUrl = $url
                }
            }
        } catch {}
    }

    # Load last step from events.jsonl
    if (Test-Path $EventsPath) {
        try {
            $events = @(Get-Content $EventsPath | ConvertFrom-Json -ErrorAction SilentlyContinue)
            if ($events) {
                $lastEvent = $events[-1]
                if ($lastEvent.step) {
                    $buildContext.lastStep = $lastEvent.step
                }
                if ($lastEvent.timestamp) {
                    $buildContext.runDate = $lastEvent.timestamp
                }
            }
            Write-Host "✓ Loaded run telemetry from events.jsonl" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Could not read events.jsonl: $_" -ForegroundColor Yellow
        }
    }
}

# Get PAC CLI version
try {
    $pacOutput = & pac --version 2>&1
    $buildContext.pacVersion = $pacOutput -join " "
} catch {
    $buildContext.pacVersion = "unknown"
}

# === Step 4: Build Issue Title and Body ===
$issueTitlePrefix = if ($FeedbackType -eq 'Bug') { '[BUG]' } else { '[ENHANCEMENT]' }

$issueTitle = "$issueTitlePrefix [$ScenarioSlug] "
Write-Host ""
Write-Host "Issue title prefix (you will edit this in the browser):" -ForegroundColor White
Write-Host "  $issueTitle<Your title here>" -ForegroundColor Gray

# Build context block for issue body
$contextBlock = @"
## 🛠 Build Context (auto-generated)
*Pre-populated by feedback script. Edit or remove if not relevant.*

- **Scenario**: $($buildContext.scenario)
- **Tables**: $($buildContext.tableCount) — $($buildContext.tableNames -join ', ')
- **Columns**: $($buildContext.columnCount) | **Relationships**: $($buildContext.relationshipCount)
- **Forms**: $($buildContext.formCount) | **Views**: $($buildContext.viewCount)
- **Last Step Completed**: $($buildContext.lastStep)
- **Run Date**: $($buildContext.runDate)
- **Environment URL**: $($buildContext.environmentUrl)
- **PowerShell Version**: $($buildContext.psVersion)
- **PAC CLI Version**: $($buildContext.pacVersion)

---
"@

# Template body based on feedback type
$templateBody = if ($FeedbackType -eq 'Bug') {
    @"
$contextBlock

## 📝 Description
*Describe the bug in detail. What were you trying to do when it happened?*



## 🔍 Where It Occurred
*Which script or build step failed or exhibited unexpected behavior?*
- Script:
- Step:

## ✅ Expected Behavior
*What should have happened?*



## ❌ Actual Behavior
*What actually happened?*



## 🔄 Steps to Reproduce
1.
2.
3.

## 📎 Error Messages or Logs
\`\`\`
[Paste error output here]
\`\`\`

## 📌 Additional Context
*Any other information that might be helpful?*
"@
} else {
    @"
$contextBlock

## 🎯 What Enhancement Would Be Helpful?
*Describe the feature or improvement you'd like to see.*



## 🔧 Which Script or Build Step Does It Relate To?
- Script:
- Step:

## 🤔 Proposed Behavior
*How would you like this to work?*



## 💡 Why Is This Important?
*What's the use case? How would this improve the wizard?*



## 📚 Additional Context
*Any related issues or examples?*
"@
}

# === Step 5: Detect GitHub Remote ===
$ghRemote = & git remote get-url origin 2>$null
if (-not $ghRemote) {
    Write-Host "❌ Could not detect GitHub remote. Are you in a Git repository?" -ForegroundColor Red
    exit 1
}

# Parse owner/repo from HTTPS or SSH URL
$owner = $null
$repo = $null

if ($ghRemote -match 'github\.com[:/]([^/]+)/([^/]+?)(\.git)?$') {
    $owner = $matches[1]
    $repo = $matches[2]
}

if (-not $owner -or -not $repo) {
    Write-Host "❌ Could not parse owner/repo from remote: $ghRemote" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Detected GitHub repo: $owner/$repo" -ForegroundColor Green

# === Step 6: Try GitHub CLI First ===
Write-Host ""
Write-Host "Opening feedback form..." -ForegroundColor Cyan

$ghInstalled = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
$ghAuthenticated = $false

if ($ghInstalled) {
    try {
        & gh auth status 2>&1 | Out-Null
        $ghAuthenticated = $?
    } catch {}
}

if ($ghInstalled -and $ghAuthenticated) {
    Write-Host "✓ Using GitHub CLI (gh) — will open browser for review" -ForegroundColor Green
    Write-Host ""

    # Prepare labels based on feedback type
    $labels = if ($FeedbackType -eq 'Bug') { "bug,wizard-feedback" } else { "enhancement,wizard-feedback" }

    # Prepare template name
    $template = if ($FeedbackType -eq 'Bug') { "bug_report" } else { "enhancement_request" }

    try {
        # gh issue create --web opens browser with pre-filled form
        # User can review and edit before submitting
        & gh issue create `
            --title "$issueTitle" `
            --body $templateBody `
            --label $labels `
            --repo "$owner/$repo" `
            --web

        $submitted = $?
    } catch {
        Write-Host "⚠ GitHub CLI failed: $_" -ForegroundColor Yellow
        $submitted = $false
    }
} else {
    $submitted = $false
    if ($ghInstalled -and -not $ghAuthenticated) {
        Write-Host "⚠ GitHub CLI is installed but not authenticated (run 'gh auth login')" -ForegroundColor Yellow
    } elseif (-not $ghInstalled) {
        Write-Host "ℹ GitHub CLI (gh) not found — using browser fallback" -ForegroundColor Gray
    }
}

# === Step 7: Browser URL Fallback ===
if (-not $submitted) {
    Write-Host "✓ Opening GitHub Issue form in browser — please fill in and submit" -ForegroundColor Green
    Write-Host ""

    # URL-encode title and body
    $encodedTitle = [System.Uri]::EscapeDataString($issueTitle)
    $encodedBody = [System.Uri]::EscapeDataString($templateBody)

    # Select template based on feedback type
    $templateParam = if ($FeedbackType -eq 'Bug') { "bug_report.md" } else { "enhancement_request.md" }

    $issueUrl = "https://github.com/$owner/$repo/issues/new?template=$templateParam&title=$encodedTitle&body=$encodedBody&labels=$([System.Uri]::EscapeDataString('wizard-feedback'))"

    # Open in browser
    try {
        if ($IsWindows -or $PSVersionTable.OS -like '*Windows*') {
            Start-Process $issueUrl
        } elseif ($IsMacOS) {
            & open $issueUrl
        } else {
            & xdg-open $issueUrl
        }
        Write-Host "✓ Browser opened — you can now fill in and submit your feedback" -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not open browser: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please open this URL manually:" -ForegroundColor White
        Write-Host "  $issueUrl" -ForegroundColor Gray
    }
}

# === Step 8: Write Telemetry Event ===
$telemetryEvent = @{
    step = "83-submit-feedback"
    feedbackType = $FeedbackType
    scenario = $ScenarioSlug
    timestamp = (Get-Date -Format "o")
    runId = [System.Guid]::NewGuid().ToString()
} | ConvertTo-Json

try {
    if (-not (Test-Path $MetricsDir)) {
        New-Item -ItemType Directory -Path $MetricsDir -Force > $null
    }
    Add-Content -Path $EventsPath -Value $telemetryEvent -ErrorAction Stop
    Write-Host ""
    Write-Host "✓ Feedback telemetry recorded" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not write telemetry: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Thank you for your feedback!" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
