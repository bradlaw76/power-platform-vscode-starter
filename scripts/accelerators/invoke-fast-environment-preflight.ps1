<#
=============================================================================
COMPONENT:    FAST Live Environment Preflight
FILE:         scripts/accelerators/invoke-fast-environment-preflight.ps1
VERSION:      0.2.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Runs an explicitly enabled, authenticated, read-only FAST Level 2 preflight.
It is standalone and is not registered in the wizard build pipeline.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            operator entry point for live read-only compatibility
- Inputs:          package indexes, snapshot ID, existing environment session
- Outputs:         versioned schema-validated preflight report
- Dependencies:    Dataverse inspector and compatibility evaluator
- Side Effects:    local cache/report writes only

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never run unless -EnableFast is supplied.
- Never issue non-GET Dataverse requests.
- Never print or persist credentials.
=============================================================================
#>

[CmdletBinding()]
param(
    [switch]$EnableFast,
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [Parameter(Mandatory)] [string]$CatalogSnapshotId,
    [Parameter(Mandatory)] [string[]]$SelectedPackagePaths,
    [string]$EnvironmentUrl = '',
    [string]$AccessToken = '',
    [string]$TenantId = '',
    [string]$EnvironmentFile = '.env.ps1',
    [string]$CacheRoot = '',
    [string]$OutputPath = '',
    [timespan]$EvidenceTimeToLive = ([TimeSpan]::FromMinutes(15)),
    [switch]$ForceRefresh,
    [ValidateRange(1, 300)] [int]$RequestTimeoutSec = 30,
    [ValidateRange(1, 10)] [int]$MaxAttempts = 4,
    [scriptblock]$TokenProvider,
    [scriptblock]$RequestInvoker,
    [scriptblock]$SleepAction,
    [datetime]$NowUtc = [DateTime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'dataverse-environment-inspector.ps1')

if (-not $EnableFast) {
    throw 'FAST environment preflight is disabled by default. Pass -EnableFast for an explicit read-only run.'
}
if ($CatalogSnapshotId -notmatch '^sha256:[a-f0-9]{64}$') {
    throw 'CatalogSnapshotId must be a content-addressed sha256 snapshot ID.'
}
if ($ScenarioSlug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
    throw "Invalid scenario slug '$ScenarioSlug'."
}

$packages = @($SelectedPackagePaths | ForEach-Object {
    $resolved = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $repoRoot $_ }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Selected FAST package index not found: $resolved"
    }
    Get-Content -LiteralPath $resolved -Raw -Encoding UTF8 | ConvertFrom-Json
})

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
    $environment = Import-WizardEnvironment -RepoRoot $repoRoot -EnvironmentFile $EnvironmentFile
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
        $EnvironmentUrl = $environment.EnvironmentUrl
    }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        $AccessToken = $environment.AccessToken
    }
}
if ([string]::IsNullOrWhiteSpace($CacheRoot)) {
    $CacheRoot = Join-Path $repoRoot '.wizard-metrics/accelerator-cache/environment-preflight'
}

$environmentEvidence = Invoke-FastDataverseEnvironmentInspection `
    -EnvironmentUrl $EnvironmentUrl `
    -AccessToken $AccessToken `
    -TenantId $TenantId `
    -CatalogSnapshotId $CatalogSnapshotId `
    -SelectedPackages $packages `
    -CacheRoot $CacheRoot `
    -CacheTimeToLive $EvidenceTimeToLive `
    -ForceRefresh:$ForceRefresh `
    -RequestTimeoutSec $RequestTimeoutSec `
    -MaxAttempts $MaxAttempts `
    -TokenProvider $TokenProvider `
    -RequestInvoker $RequestInvoker `
    -SleepAction $SleepAction `
    -NowUtc $NowUtc

$report = Test-FastEnvironmentPreflight `
    -ScenarioSlug $ScenarioSlug `
    -CatalogSnapshotId $CatalogSnapshotId `
    -SelectedPackages $packages `
    -EnvironmentEvidence $environmentEvidence `
    -EvidenceTimeToLive $EvidenceTimeToLive `
    -NowUtc $NowUtc

$reportJson = $report | ConvertTo-Json -Depth 100
$schemaPath = Join-Path $repoRoot 'schemas/accelerators/environment-validation.schema.json'
if (-not (Test-Json -Json $reportJson -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw 'Generated FAST environment preflight report failed schema validation.'
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $repoRoot $OutputPath }
    $outputFolder = Split-Path $resolvedOutput -Parent
    New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
    Set-Content -LiteralPath $resolvedOutput -Value $reportJson -Encoding utf8NoBOM
}

$report
