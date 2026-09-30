<#
=============================================================================
COMPONENT:    Demo Presenter Contract Test
FILE:         scripts/ci/test-demo-presenter.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-09-22
ENVIRONMENT:  PowerShell 7 | Credential-free CI

OVERVIEW
Validates the static contract between the demo wizard and its standalone HTML
presenter template without creating scenario artifacts.

NON-NEGOTIABLES
- Remain credential-free and environment-independent.
- Validate the timer prompt, Dynamics blue default, and theme toggle.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$wizardPath = Join-Path $repoRoot "scripts\bootstrap\06-demo-script-wizard.ps1"
$templatePath = Join-Path $repoRoot "scripts\bootstrap\templates\demo-presenter.template.html"

function Assert-Contains {
    param(
        [string]$Content,
        [string]$Expected,
        [string]$Description
    )

    if (-not $Content.Contains($Expected)) {
        throw "Demo presenter contract failed: $Description"
    }
}

if (-not (Test-Path $wizardPath)) {
    throw "Demo wizard not found: $wizardPath"
}
if (-not (Test-Path $templatePath)) {
    throw "Demo presenter template not found: $templatePath"
}

$wizard = Get-Content -Path $wizardPath -Raw -Encoding UTF8
$template = Get-Content -Path $templatePath -Raw -Encoding UTF8

Assert-Contains -Content $wizard -Expected 'How long should the demo timer run, in minutes?' -Description "the wizard must ask for timer duration"
Assert-Contains -Content $wizard -Expected '$ScenarioSlug-demo-presenter.html' -Description "the wizard must declare the presenter output"
Assert-Contains -Content $wizard -Expected 'ConvertTo-Json -Depth 8 -Compress' -Description "presenter data must be serialized rather than interpolated into markup"
Assert-Contains -Content $template -Expected 'const data = __DEMO_DATA_JSON__;' -Description "the template must expose exactly one data placeholder"
Assert-Contains -Content $template -Expected '--accent: #0078d4;' -Description "the default theme must use Dynamics blue"
Assert-Contains -Content $template -Expected 'id="theme-toggle"' -Description "the presenter must include a theme toggle"
Assert-Contains -Content $template -Expected 'id="timer-toggle"' -Description "the presenter must include timer controls"
Assert-Contains -Content $template -Expected 'spokenHeading.textContent = "What to say"' -Description "the presenter must render spoken content on the left"
Assert-Contains -Content $template -Expected 'actions.innerHTML = "<h3>On screen</h3>"' -Description "the presenter must render on-screen actions on the right"
Assert-Contains -Content $template -Expected 'keyLine.className = "key-line"' -Description "the presenter must render a standard key line"
Assert-Contains -Content $template -Expected 'transition.className = "transition"' -Description "the presenter must render a standard transition"
Assert-Contains -Content $wizard -Expected 'if ($DurationMinutes -gt 25)' -Description "long demos must add duration-specific detail"
Assert-Contains -Content $wizard -Expected 'sayLines = @($step.SayLines)' -Description "presenter data must include derived spoken lines"
Assert-Contains -Content $wizard -Expected 'transition = $step.Transition' -Description "presenter data must include a derived transition"
Assert-Contains -Content $wizard -Expected '"Today I am showing how $ScenarioName helps $Audience address this business problem: $problemSummary"' -Description "What to say must contain project-derived speaker prose"
Assert-Contains -Content $wizard -Expected '"What you are seeing is a configured demonstration baseline based on the current project plan' -Description "long demos must include speaker-ready governance language"
Assert-Contains -Content $wizard -Expected '$stepLines.Add("**What to Say**")' -Description "the Markdown talk track must use the same speaker-ready contract"

$placeholderCount = ([regex]::Matches($template, [regex]::Escape("__DEMO_DATA_JSON__"))).Count
if ($placeholderCount -ne 1) {
    throw "Demo presenter contract failed: expected one data placeholder, found $placeholderCount."
}

Write-Host "Demo presenter contract checks passed." -ForegroundColor Green
