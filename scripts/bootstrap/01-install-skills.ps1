<#
.SYNOPSIS
    Installs Claude Code skills from this repo into the local user skills directory.
    Safe to run at any time. Does not require authentication or Dataverse access.

.DESCRIPTION
    Copies skills from .claude/skills/ in this repo to ~/.claude/skills/ so they
    are available to Claude Code in any future session on this machine.

    Copies each full skill folder (not only SKILL.md) so future skill assets
    are included automatically.

    Skills installed:
    - power-platform-vscode-wizard: guided wizard for building Power Platform
      model-driven apps from VS Code using PAC CLI.

.EXAMPLE
    pwsh ./scripts/bootstrap/01-install-skills.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "01-install-skills.ps1"
}

$skillsSource = Join-Path $repoRoot ".claude\skills"
$skillsDest   = Join-Path $HOME ".claude\skills"

Write-Host ""
Write-Host "=== Install Claude Code Skills ===" -ForegroundColor Cyan
Write-Host "Source: $skillsSource"
Write-Host "Dest:   $skillsDest"
Write-Host ""

if (-not (Test-Path $skillsSource)) {
    Write-Host "No skills found in repo at $skillsSource. Nothing to install." -ForegroundColor Yellow
    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message "No skills folder found."
    }
    exit 0
}

$installed = 0
$skipped   = 0

Get-ChildItem -Path $skillsSource -Directory | ForEach-Object {
    $skillName   = $_.Name
    $sourceSkill = $_.FullName
    $destSkill   = Join-Path $skillsDest $skillName

    $sourceFile = Join-Path $sourceSkill "SKILL.md"
    if (-not (Test-Path $sourceFile)) {
        Write-Host "  SKIP $skillName — no SKILL.md found" -ForegroundColor Yellow
        $skipped++
        return
    }

    New-Item -ItemType Directory -Force $destSkill | Out-Null
    Copy-Item (Join-Path $sourceSkill "*") $destSkill -Recurse -Force
    Write-Host "  INSTALLED $skillName" -ForegroundColor Green
    $installed++
}

Write-Host ""
Write-Host "Done. Installed: $installed  Skipped: $skipped" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  Skills are now available in Claude Code on this machine."
Write-Host "  Start a new Claude Code session and run the wizard skill:"
Write-Host "  /power-platform-vscode-wizard"
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Skills installed."
}
