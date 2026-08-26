<#
=============================================================================
COMPONENT:    Build Tables
FILE:         scripts/bootstrap/20-build-tables.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Creates the custom Dataverse tables required by the approved scenario mapping
while avoiding standard out-of-box entities.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          approved table payloads and explicit entity mapping
- Outputs:         created custom tables and build artifacts
- Dependencies:    Dataverse Web API, table-detection helper, planning files
- Side Effects:    creates Dataverse metadata and local telemetry/artifacts

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Explicit entity mapping must be complete in spec.md and plan.md.
2. Environment authentication must already be valid.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Custom tables are created from payloads successfully.
✔ Standard reused tables are excluded from create operations.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never attempt to create standard Dataverse tables.
- Keep reruns safe for already-created metadata where supported.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Creates Dataverse tables from JSON payload files.
    Safe to rerun — skips tables that already exist.

.DESCRIPTION
    Loads all table-*.json files from the payloads/ folder adjacent to this script's
    parent directory. Calls the Dataverse EntityDefinitions API for each table.

    Reads environment config from .env.ps1 (written by 10-auth-connect.ps1).
    Values can also be passed directly as parameters.

.PARAMETER EnvironmentUrl
    Dataverse environment URL. Defaults to $env:DV_ENVIRONMENT_URL.

.PARAMETER AccessToken
    Bearer token. Defaults to $env:DV_TOKEN.

.PARAMETER PayloadsFolder
    Path to the folder containing table-*.json files. Defaults to ../../payloads.

.EXAMPLE
    pwsh ./scripts/bootstrap/20-build-tables.ps1
    pwsh ./scripts/bootstrap/20-build-tables.ps1 -EnvironmentUrl "https://org.crm.dynamics.com" -AccessToken $token
#>

param(
    [string]$EnvironmentUrl  = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken     = $env:DV_TOKEN,
    [string]$PayloadsFolder  = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "20-build-tables.ps1"
}

$hardeningHelper = Join-Path $PSScriptRoot "helpers\wizard-hardening.ps1"
if (Test-Path $hardeningHelper) {
    . $hardeningHelper
}

# ── Load session env if not already set ───────────────────────────────────
$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    $AccessToken    = $global:DV_TOKEN
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
    Write-Host "Environment URL and token are required." -ForegroundColor Red
    Write-Host "Run 10-auth-connect.ps1 first, or pass -EnvironmentUrl and -AccessToken."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path $repoRoot "payloads"
}

if (-not (Test-Path $PayloadsFolder)) {
    Write-Host "Payload folder not found: $PayloadsFolder" -ForegroundColor Red
    Write-Host "Expected payload location is the repo root 'payloads/' folder." -ForegroundColor Yellow
    exit 1
}

$tableDetectionHelper = Join-Path $PSScriptRoot "helpers\table-detection.ps1"
if (Test-Path $tableDetectionHelper) {
    . $tableDetectionHelper
}

# ── Helpers ────────────────────────────────────────────────────────────────
function Invoke-Dv {
    param([string]$Method, [string]$Path, [string]$Body = "")
    $headers = @{
        "Authorization"    = "Bearer $AccessToken"
        "Content-Type"     = "application/json"
        "OData-Version"    = "4.0"
        "OData-MaxVersion" = "4.0"
        "Accept"           = "application/json"
    }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

function Test-TableExists([string]$LogicalName) {
    try {
        $resp = Invoke-Dv "Get" "EntityDefinitions(LogicalName='$LogicalName')?`$select=LogicalName"
        return (-not [string]::IsNullOrWhiteSpace($resp.LogicalName))
    } catch { return $false }
}

function ConvertTo-DataverseEntityMetadata {
    param([Parameter(Mandatory)] [object]$Payload)

    $entityDefinition = $Payload.EntityDefinition ?? $Payload
    $schemaName = [string]$entityDefinition.SchemaName
    $prefix = if ($schemaName.Contains('_')) { $schemaName.Split('_', 2)[0] } else { $schemaName }
    $metadata = [ordered]@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.EntityMetadata'
        SchemaName = $schemaName
        DisplayName = $entityDefinition.DisplayName
        DisplayCollectionName = $entityDefinition.DisplayCollectionName
        Description = $entityDefinition.Description
        OwnershipType = $entityDefinition.OwnershipType
        IsActivity = [bool]$entityDefinition.IsActivity
        HasActivities = $false
        HasNotes = $false
        Attributes = @(
            [ordered]@{
                '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
                SchemaName = "${prefix}_name"
                DisplayName = @{ LocalizedLabels = @(@{ Label = 'Name'; LanguageCode = 1033 }) }
                Description = @{ LocalizedLabels = @(@{ Label = "Primary name for $schemaName"; LanguageCode = 1033 }) }
                AttributeType = 'String'
                AttributeTypeName = @{ Value = 'StringType' }
                FormatName = @{ Value = 'Text' }
                IsPrimaryName = $true
                MaxLength = 100
                RequiredLevel = @{ Value = 'ApplicationRequired'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
            }
        )
    }
    return $metadata
}

# ── Main ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Build Tables ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Payloads:    $PayloadsFolder"
Write-Host ""

$payloads = @(Get-ChildItem -Path $PayloadsFolder -Filter "table-*.json" -ErrorAction SilentlyContinue)
if ($payloads.Count -eq 0) {
    Write-Host "No table-*.json files found in: $PayloadsFolder" -ForegroundColor Yellow
    Write-Host "Create at least one table payload file and rerun."
    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message "No table payloads found."
    }
    exit 0
}

$created = 0; $skipped = 0; $failed = 0

foreach ($file in $payloads) {
    $payload = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $name    = $payload.EntityDefinition.SchemaName ?? $payload.SchemaName
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Host "  SKIP  $($file.Name) — could not determine SchemaName" -ForegroundColor Yellow
        if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'table' -Name $file.Name -Status 'skipped' -Step '20-build-tables.ps1' -Details @{ reason = 'missing schema name'; payload = $file.Name } | Out-Null
        }
        $skipped++; continue
    }

    $logical = $name.ToLower()
    Write-Host "  $name " -NoNewline

    if (Get-Command Test-IsStandardTable -ErrorAction SilentlyContinue) {
        if (Test-IsStandardTable $logical) {
            Write-Host "(standard table in payload — skipped)" -ForegroundColor Yellow
            if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'table' -Name $logical -Status 'skipped' -Step '20-build-tables.ps1' -Details @{ reason = 'standard table payload'; payload = $file.Name } | Out-Null
            }
            $skipped++; continue
        }
    }

    if (Test-TableExists $logical) {
        Write-Host "(exists — skipped)" -ForegroundColor DarkGray
        if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'table' -Name $logical -Status 'skipped' -Step '20-build-tables.ps1' -Details @{ reason = 'already exists'; payload = $file.Name } | Out-Null
        }
        $skipped++; continue
    }

    try {
        $metadata = ConvertTo-DataverseEntityMetadata -Payload $payload
        Invoke-Dv "Post" "EntityDefinitions" ($metadata | ConvertTo-Json -Depth 12 -Compress) | Out-Null
        Write-Host "(created)" -ForegroundColor Green
        if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'table' -Name $logical -Status 'created' -Step '20-build-tables.ps1' -Details @{ payload = $file.Name } | Out-Null
        }
        $created++
    } catch {
        Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
        if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'table' -Name $logical -Status 'failed' -Step '20-build-tables.ps1' -Details @{ payload = $file.Name; error = $_.Exception.Message } | Out-Null
        }
        $failed++
    }
}

Write-Host ""
Write-Host "Tables — created: $created  skipped: $skipped  failed: $failed"
if ($failed -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Table build failed for one or more payloads."
    }
    exit 1
}
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/30-build-columns.ps1"
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Table build completed."
}

