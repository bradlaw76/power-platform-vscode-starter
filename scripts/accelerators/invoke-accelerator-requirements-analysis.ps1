<#
=============================================================================
COMPONENT:    Standalone Accelerator Requirements Analysis
FILE:         scripts/accelerators/invoke-accelerator-requirements-analysis.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | JSON | Markdown

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Explicitly runs provider-neutral requirements matching from local artifacts.
It is not registered in the wizard profile or build orchestrator.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Requires explicit enablement.
- Reads local planning/catalog/package evidence only.
- Does not connect to Dataverse or mutate wizard planning artifacts.
=============================================================================
#>

[CmdletBinding()]
param(
    [switch]$EnableAcceleratorAnalysis,
    [Parameter(Mandatory)] [string]$RequirementsPath,
    [Parameter(Mandatory)] [string]$CatalogSnapshotPath,
    [string[]]$PackageMetadataPaths = @(),
    [string]$EnvironmentValidationPath = '',
    [Parameter(Mandatory)] [string]$OutputFolder,
    [string]$ProviderId = '',
    [string]$ScenarioSlug = 'accelerator-analysis',
    [datetime]$EvaluationTimeUtc = [DateTime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $EnableAcceleratorAnalysis) {
    throw 'Accelerator analysis is disabled by default. Pass -EnableAcceleratorAnalysis for an explicit local planning run.'
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'requirements-matching.ps1')

function Resolve-AnalysisInputPath {
    param([Parameter(Mandatory)] [string]$Path)
    $resolved = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $repoRoot $Path }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Analysis input file not found: $resolved"
    }
    return [IO.Path]::GetFullPath($resolved)
}

$requirementsFile = Resolve-AnalysisInputPath -Path $RequirementsPath
$catalogFile = Resolve-AnalysisInputPath -Path $CatalogSnapshotPath
$catalog = Get-Content -LiteralPath $catalogFile -Raw -Encoding UTF8 | ConvertFrom-Json
$requirementsText = Get-Content -LiteralPath $requirementsFile -Raw -Encoding UTF8
$requirements = if ([IO.Path]::GetExtension($requirementsFile) -ieq '.json') {
    $document = $requirementsText | ConvertFrom-Json
    $requirementsProperty = $document.PSObject.Properties['requirements']
    if ($null -ne $requirementsProperty) { $requirementsProperty.Value } else { $document }
} else {
    $requirementsText
}
$packages = @($PackageMetadataPaths | ForEach-Object {
    $path = Resolve-AnalysisInputPath -Path $_
    Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
})
$environmentEvidence = if ([string]::IsNullOrWhiteSpace($EnvironmentValidationPath)) {
    $null
} else {
    $path = Resolve-AnalysisInputPath -Path $EnvironmentValidationPath
    Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json -DateKind String
}

$analysis = Invoke-AcceleratorRequirementsAnalysis `
    -Requirements $requirements `
    -CatalogSnapshot $catalog `
    -PackageMetadata $packages `
    -EnvironmentEvidence $environmentEvidence `
    -ProviderId $ProviderId `
    -ScenarioSlug $ScenarioSlug `
    -ProviderEnabled $true `
    -EvaluationTimeUtc $EvaluationTimeUtc

$schemaPath = Join-Path $repoRoot 'schemas/accelerators/requirements-analysis.schema.json'
if (-not (Test-Json -Json ($analysis | ConvertTo-Json -Depth 100) -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw 'Accelerator requirements analysis failed schema validation.'
}

$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputFolder)) {
    $OutputFolder
} else {
    Join-Path $repoRoot $OutputFolder
}
$writeResult = Write-AcceleratorRequirementsAnalysisArtifacts `
    -Analysis $analysis `
    -OutputFolder $resolvedOutput

[pscustomobject]@{
    Analysis = $analysis
    Artifacts = $writeResult
}
