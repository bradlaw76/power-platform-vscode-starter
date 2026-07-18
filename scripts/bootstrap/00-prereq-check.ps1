<#
.SYNOPSIS
    Verifies all required tools are installed and accessible before starting a build.
    Safe to run at any time. Makes no changes to any environment.

.DESCRIPTION
    Checks for: VS Code, PowerShell 7+, Azure CLI, Power Platform CLI, Git.
    Prints version info and a PASS/FAIL summary line for each tool.

.EXAMPLE
    pwsh ./scripts/bootstrap/00-prereq-check.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "00-prereq-check.ps1"
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Test-Tool {
    param(
        [string]$Name,
        [string]$Command,
        [string]$Args = "--version"
    )
    try {
        $output = & $Command $Args 2>&1 | Select-Object -First 1
        $results.Add([PSCustomObject]@{ Tool = $Name; Status = "PASS"; Version = "$output" })
    }
    catch {
        $results.Add([PSCustomObject]@{ Tool = $Name; Status = "FAIL"; Version = "Not found or error: $_" })
    }
}

Write-Host ""
Write-Host "=== Prerequisite Check ===" -ForegroundColor Cyan

Test-Tool -Name "VS Code"           -Command "code"
Test-Tool -Name "PowerShell 7+"     -Command "pwsh"
Test-Tool -Name "Azure CLI"         -Command "az"
Test-Tool -Name "Power Platform CLI"-Command "pac"
Test-Tool -Name "Git"               -Command "git"

Write-Host ""
$results | Format-Table -AutoSize

$failed = @($results | Where-Object { $_.Status -eq "FAIL" })
if ($failed.Count -gt 0) {
    Write-Host "FAILED tools: $($failed.Count). Install missing tools before continuing." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install commands (Windows):" -ForegroundColor Yellow
    Write-Host "  VS Code:              https://code.visualstudio.com"
    Write-Host "  PowerShell 7+:        winget install Microsoft.PowerShell"
    Write-Host "  Azure CLI:            winget install Microsoft.AzureCLI"
    Write-Host "  Power Platform CLI:   winget install Microsoft.PowerPlatformCLI"
    Write-Host "  Git:                  winget install Git.Git"
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Missing required tools."
    }
    exit 1
}

Write-Host "All prerequisites passed." -ForegroundColor Green
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Prerequisite check passed."
}
