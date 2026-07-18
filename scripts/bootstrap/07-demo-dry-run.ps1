<#
.SYNOPSIS
    Runs a lightweight dry run for a generated demo script.

.DESCRIPTION
    Reads `demo-script.md` for a scenario, walks the presenter through each
    step, and records rehearsal notes in `demo-dry-run.md`.

.PARAMETER ScenarioSlug
    Existing scenario folder under `specs/`.

.PARAMETER Force
    Overwrite `demo-dry-run.md` without prompting.

.EXAMPLE
    pwsh ./scripts/bootstrap/07-demo-dry-run.ps1 -ScenarioSlug contoso-case-tracker
#>

param(
    [string]$ScenarioSlug,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-RequiredValue {
    param([string]$Prompt)

    while ($true) {
        $value = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        Write-Host "A value is required." -ForegroundColor Yellow
    }
}

function Confirm-Overwrite {
    param([string]$Path)

    $answer = Read-Host "'$Path' already exists. Overwrite it? (y/N)"
    return $answer -match '^(y|yes)$'
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "07-demo-dry-run.ps1"
}

$specsRoot = Join-Path $repoRoot "specs"

if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    $scenarioFolders = @(Get-ChildItem -Path $specsRoot -Directory | Sort-Object Name)
    if ($scenarioFolders.Count -eq 0) {
        throw "No scenario folders were found under '$specsRoot'. Run 05-start-wizard.ps1 first."
    }

    Write-Host "Available scenarios:" -ForegroundColor Cyan
    $scenarioFolders | ForEach-Object { Write-Host "  - $($_.Name)" }
    $ScenarioSlug = Read-RequiredValue "Scenario folder slug"
}

$scenarioFolder = Join-Path $specsRoot $ScenarioSlug
$demoScriptPath = Join-Path $scenarioFolder "demo-script.md"
$dryRunPath = Join-Path $scenarioFolder "demo-dry-run.md"

if (-not (Test-Path $demoScriptPath)) {
    throw "Missing demo script: $demoScriptPath. Run 06-demo-script-wizard.ps1 first."
}

if ((Test-Path $dryRunPath) -and -not $Force) {
    if (-not (Confirm-Overwrite -Path $dryRunPath)) {
        Write-Host "No files were changed." -ForegroundColor Yellow
        if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
            Complete-WizardStepTelemetry -Message "Dry run cancelled by user."
        }
        exit 0
    }
}

$stepLines = @(Get-Content -Path $demoScriptPath -Encoding UTF8 | Where-Object {
    $_ -match '^### Step\s+\d+:\s+(.+)\s+\((\d+)\s+min\)$'
})
if ($stepLines.Count -eq 0) {
    throw "No demo steps were found in $demoScriptPath."
}

$notes = New-Object System.Collections.Generic.List[string]
$notes.Add("# Demo Dry Run: $ScenarioSlug")
$notes.Add("")
$notes.Add("## Rehearsal Summary")

Write-Host ""
Write-Host "=== Demo Dry Run ===" -ForegroundColor Cyan
Write-Host "Scenario: $ScenarioSlug"
Write-Host ""

foreach ($stepLine in $stepLines) {
    $null = $stepLine -match '^### Step\s+\d+:\s+(.+)\s+\((\d+)\s+min\)$'
    $stepTitle = $matches[1].Trim()
    $stepMinutes = $matches[2].Trim()

    Write-Host "Step: $stepTitle ($stepMinutes min)" -ForegroundColor Cyan
    $status = Read-RequiredValue "Status after rehearsal (pass/fix/skip)"
    $observation = Read-RequiredValue "Observation or edit needed"
    Write-Host ""

    $notes.Add("- Step: $stepTitle")
    $notes.Add("  Status: $status")
    $notes.Add("  Note: $observation")
}

$overall = Read-RequiredValue "Overall rehearsal result"
$nextEdit = Read-RequiredValue "Primary edit to request before the live demo"

$notes.Add("")
$notes.Add("## Overall Result")
$notes.Add("- Outcome: $overall")
$notes.Add("- Requested edit: $nextEdit")

Set-Content -Path $dryRunPath -Value ($notes -join [Environment]::NewLine) -Encoding UTF8

Write-Host "Dry-run notes written to: $dryRunPath" -ForegroundColor Green
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Dry-run notes captured."
}
