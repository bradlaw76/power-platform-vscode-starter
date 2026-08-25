<#
=============================================================================
COMPONENT:    Build Columns
FILE:         scripts/bootstrap/30-build-columns.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Creates approved Dataverse columns on standard or custom tables according to
the scenario mapping and payload definitions.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          column payloads and approved entity mapping
- Outputs:         created columns and build artifacts
- Dependencies:    Dataverse Web API, planning files, repo helpers
- Side Effects:    creates Dataverse metadata and local telemetry/artifacts

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Table mapping and payload readiness rules must already be satisfied.
2. Required tables must exist or be reusable in the target environment.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Approved custom fields are created on the intended tables.
✔ Reused standard fields are not recreated as custom metadata.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Respect the standard-vs-custom mapping from planning.
- Avoid duplicate custom field creation on rerun where supported.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Adds columns to existing Dataverse tables from columns-*.json payload files.
    Safe to rerun — skips columns that already exist on the table.

.PARAMETER EnvironmentUrl  Defaults to $env:DV_ENVIRONMENT_URL (set by 10-auth-connect.ps1).
.PARAMETER AccessToken     Defaults to $env:DV_TOKEN.
.PARAMETER PayloadsFolder  Folder containing columns-*.json. Defaults to ../../payloads.

.EXAMPLE
    pwsh ./scripts/bootstrap/30-build-columns.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken    = $env:DV_TOKEN,
    [string]$PayloadsFolder = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "30-build-columns.ps1"
}

$hardeningHelper = Join-Path $PSScriptRoot "helpers\wizard-hardening.ps1"
if (Test-Path $hardeningHelper) {
    . $hardeningHelper
}

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile; $EnvironmentUrl = $global:DV_ENVIRONMENT_URL; $AccessToken = $global:DV_TOKEN
}
$scenarioContext = if (Get-Command Get-WizardScenarioContext -ErrorAction SilentlyContinue) {
    Get-WizardScenarioContext -RepoRoot $repoRoot -ScenarioSlug '' -PayloadsFolder $PayloadsFolder
} else { $null }
$solutionName = if (Get-Variable global:DV_SOLUTION_NAME -ErrorAction SilentlyContinue) { $global:DV_SOLUTION_NAME } else { '' }
$publisherPrefix = if (Get-Variable global:DV_PUBLISHER_PREFIX -ErrorAction SilentlyContinue) { $global:DV_PUBLISHER_PREFIX } else { '' }
if (Get-Command Initialize-WizardArtifactManifest -ErrorAction SilentlyContinue) {
    Initialize-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix | Out-Null
}
if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "Run 10-auth-connect.ps1 first." -ForegroundColor Red; exit 1
}
if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path $repoRoot "payloads"
}

if (-not (Test-Path $PayloadsFolder)) {
    Write-Host "Payload folder not found: $PayloadsFolder" -ForegroundColor Red
    Write-Host "Expected payload location is the repo root 'payloads/' folder." -ForegroundColor Yellow
    exit 1
}

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "") {
    $h = @{ "Authorization"="Bearer $AccessToken"; "Content-Type"="application/json";
            "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Accept"="application/json" }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
}

function Test-ColumnExists([string]$Table, [string]$Column) {
    try { Invoke-Dv "Get" "EntityDefinitions(LogicalName='$Table')/Attributes(LogicalName='$Column')?`$select=LogicalName" | Out-Null; return $true }
    catch { return $false }
}

Write-Host ""
Write-Host "=== Build Columns ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host ""

$payloads = @(Get-ChildItem -Path $PayloadsFolder -Filter "columns-*.json" -ErrorAction SilentlyContinue)
if ($payloads.Count -eq 0) {
    Write-Host "No columns-*.json found in: $PayloadsFolder" -ForegroundColor Yellow
    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message "No column payloads found."
    }
    exit 0
}

$created = 0; $skipped = 0; $failed = 0

foreach ($file in $payloads) {
    $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $tableName = $doc.TableLogicalName
    if ([string]::IsNullOrWhiteSpace($tableName)) {
        Write-Host "  SKIP $($file.Name) — missing TableLogicalName property" -ForegroundColor Yellow
        if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'column' -Name $file.Name -Status 'skipped' -Step '30-build-columns.ps1' -Details @{ reason = 'missing table logical name'; payload = $file.Name } | Out-Null
        }
        $skipped++; continue
    }
    $tableName = $tableName.Trim()

    Write-Host "  Table: $tableName" -ForegroundColor Cyan
    foreach ($col in $doc.Columns) {
        $schema  = $col.SchemaName
        $logical = $col.LogicalName
        if ([string]::IsNullOrWhiteSpace($logical) -and -not [string]::IsNullOrWhiteSpace($schema)) {
            $logical = $schema
        }

        if ([string]::IsNullOrWhiteSpace($logical)) {
            Write-Host "    SKIP (missing SchemaName/LogicalName)" -ForegroundColor Yellow
            if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'column' -Name "$tableName.[unknown]" -Status 'skipped' -Step '30-build-columns.ps1' -Details @{ reason = 'missing logical name'; payload = $file.Name } | Out-Null
            }
            $skipped++
            continue
        }

            $logical = $logical.Trim()
        Write-Host "    $logical " -NoNewline

        if (Test-ColumnExists $tableName $logical) {
            Write-Host "(exists — skipped)" -ForegroundColor DarkGray
            if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'column' -Name "$tableName.$logical" -Status 'skipped' -Step '30-build-columns.ps1' -Details @{ reason = 'already exists'; payload = $file.Name } | Out-Null
            }
            $skipped++; continue
        }

        try {
            if ([string]::IsNullOrWhiteSpace($col.LogicalName)) {
                $col.LogicalName = $logical
            }
            $body = $col | ConvertTo-Json -Depth 20 -Compress
            Invoke-Dv "Post" "EntityDefinitions(LogicalName='$tableName')/Attributes" $body | Out-Null
            Write-Host "(created)" -ForegroundColor Green
            if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'column' -Name "$tableName.$logical" -Status 'created' -Step '30-build-columns.ps1' -Details @{ payload = $file.Name } | Out-Null
            }
            $created++
        } catch {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
            if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'column' -Name "$tableName.$logical" -Status 'failed' -Step '30-build-columns.ps1' -Details @{ payload = $file.Name; error = $_.Exception.Message } | Out-Null
            }
            $failed++
        }
    }
}

Write-Host ""
Write-Host "Columns — created: $created  skipped: $skipped  failed: $failed"
if ($failed -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Column build failed for one or more payloads."
    }
    exit 1
}
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/40-build-relationships.ps1"
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Column build completed."
}

