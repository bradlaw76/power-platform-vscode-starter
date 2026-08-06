<#
=============================================================================
COMPONENT:    Install Claude Code Skills
FILE:         scripts/bootstrap/01-install-skills.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | VS Code | Claude Code Skills

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Copies repo-hosted Claude Code skills into the local user skills directory so
future sessions can invoke the Power Platform wizard skill without manual file
copying.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          repo .claude/skills folder and local HOME directory
- Outputs:         installed skill folders under ~/.claude/skills
- Dependencies:    helpers/wizard-telemetry.ps1, Copy-Item, New-Item
- Side Effects:    writes to the local user skills directory

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Run from a cloned copy of this repository.
2. Local file system write access to ~/.claude/skills.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Missing source skills folder exits cleanly without failure.
✔ Existing destination folders are overwritten safely on rerun.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Do not require Dataverse authentication for local skill installation.
- Preserve rerunnable behavior when copying skill folders.
- Keep the script safe to run on any machine with this repository.
=============================================================================
#>

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
Write-Host ""
Write-Host "VS Code Copilot Chat users:" -ForegroundColor Cyan
Write-Host "  This repo also includes a shared skill at .github/skills/power-platform-wizard-init"
Write-Host "  Invoke it in Copilot Chat with:"
Write-Host "  /power-platform-wizard-init"
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Skills installed."
}
