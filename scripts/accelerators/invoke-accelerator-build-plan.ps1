<#
=============================================================================
COMPONENT:    Invoke Provider-Neutral Accelerator Build Plan
FILE:         scripts/accelerators/invoke-accelerator-build-plan.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-16
ENVIRONMENT:  PowerShell 7 | JSON | Spec Kit

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Generates schema-valid, scenario-local dry-run build planning artifacts from
an explicitly approved architecture decision.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Requires explicit dry-run enablement.
- Reads local artifacts only.
- Does not call PAC, Dataverse, HTTP, imports, or build stages.
- Does not accept architecture selection as a command-line override.
=============================================================================
#>

[CmdletBinding()]
param(
    [switch]$EnableDryRunBuildPlanning,
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [string]$WorkspaceRoot,
    [string]$PackageManifestPath = '',
    [string]$ExpectedEnvironmentUrl = '',
    [string]$OutputFolder = '',
    [switch]$ApproveBuildPlanDecisionChange
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $EnableDryRunBuildPlanning) {
    throw 'Build planning is disabled by default. Pass -EnableDryRunBuildPlanning for an explicit local dry-run.'
}

$implementationRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$repoRoot = if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $implementationRoot
} else {
    [IO.Path]::GetFullPath($WorkspaceRoot)
}
. (Join-Path $PSScriptRoot 'build-planning-adapter.ps1')

function Resolve-BuildPlanPath {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [switch]$RequireFile
    )
    $resolved = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $repoRoot $Path }
    $resolved = [IO.Path]::GetFullPath($resolved)
    if ($RequireFile -and -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Build-planning file not found: $resolved"
    }
    return $resolved
}

function Get-VerifiedBuildPlanPackages {
    param([string]$ManifestPath)

    if ([string]::IsNullOrWhiteSpace($ManifestPath)) { return @() }
    $manifestFile = Resolve-BuildPlanPath -Path $ManifestPath -RequireFile
    $manifestSchema = Join-Path $repoRoot 'schemas\accelerators\package-input-manifest.schema.json'
    $packageSchema = Join-Path $repoRoot 'schemas\accelerators\package-metadata.schema.json'
    $manifestText = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8
    if (-not (Test-Json -Json $manifestText -SchemaFile $manifestSchema -ErrorAction Stop)) {
        throw 'Package input manifest failed schema validation.'
    }
    $manifest = $manifestText | ConvertFrom-Json
    $manifestFolder = Split-Path $manifestFile -Parent
    $packages = @(
        foreach ($entry in @($manifest.packages)) {
            $packagePath = if ([IO.Path]::IsPathRooted("$($entry.path)")) {
                "$($entry.path)"
            } else {
                Join-Path $manifestFolder "$($entry.path)"
            }
            if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
                throw "Package metadata file not found: $packagePath"
            }
            $packageText = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8
            if (-not (Test-Json -Json $packageText -SchemaFile $packageSchema -ErrorAction Stop)) {
                throw "Package metadata failed schema validation: $packagePath"
            }
            $package = $packageText | ConvertFrom-Json
            if ("$($package.moduleId)" -cne "$($entry.moduleId)" -or
                "$($package.packageId)" -cne "$($entry.packageId)" -or
                "$($package.solution.version)" -cne "$($entry.version)" -or
                "$($package.sha256)" -cne "$($entry.sha256)") {
                throw "Package manifest identity mismatch for '$($entry.moduleId)'."
            }
            $package
        }
    )
    $duplicates = @($packages | Group-Object moduleId | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) {
        throw "Package manifest contains duplicate module '$($duplicates[0].Name)'."
    }
    return $packages
}

$scenarioFolder = Resolve-BuildPlanPath -Path (Join-Path 'specs' $ScenarioSlug)
if (-not (Test-Path -LiteralPath $scenarioFolder -PathType Container)) {
    throw "Scenario folder not found: $scenarioFolder"
}
$acceleratorFolder = Join-Path $scenarioFolder 'accelerator'
$paths = [ordered]@{
    decision = Join-Path $acceleratorFolder 'accelerator-decision.json'
    analysisManifest = Join-Path $acceleratorFolder 'accelerator-analysis-manifest.json'
    coverage = Join-Path $acceleratorFolder 'requirements-coverage-matrix.json'
    componentDelta = Join-Path $acceleratorFolder 'component-delta-analysis.json'
    schemaPlan = Join-Path $acceleratorFolder 'schema-reuse-extension-plan.json'
    dependencies = Join-Path $acceleratorFolder 'dependency-manifest.json'
    environment = Join-Path $acceleratorFolder 'environment-readiness-reference.json'
    traceability = Join-Path $acceleratorFolder 'acceptance-traceability.json'
    spec = Join-Path $scenarioFolder 'spec.md'
}
foreach ($inputPath in $paths.Values) {
    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
        throw "Required scenario-local build-planning artifact not found: $inputPath"
    }
}

$decisionText = Get-Content -LiteralPath $paths.decision -Raw -Encoding UTF8
$decisionSchema = Join-Path $repoRoot 'schemas\accelerators\architecture-decision.schema.json'
if (-not (Test-Json -Json $decisionText -SchemaFile $decisionSchema -ErrorAction Stop)) {
    throw 'Architecture decision failed schema validation.'
}
$decision = $decisionText | ConvertFrom-Json -DateKind String
if ("$($decision.scenarioSlug)" -cne $ScenarioSlug) {
    throw "Architecture decision scenario '$($decision.scenarioSlug)' does not match '$ScenarioSlug'."
}
$analysisManifest = Read-BuildPlanningJson -Path $paths.analysisManifest
foreach ($artifact in @($analysisManifest.artifacts)) {
    $artifactPath = Join-Path $acceleratorFolder "$($artifact.file)"
    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw "Analysis manifest artifact is missing: $artifactPath"
    }
    if ((Get-BuildPlanningFileHash -Path $artifactPath) -cne "$($artifact.sha256)") {
        throw "Analysis artifact hash mismatch: $($artifact.file)"
    }
}

$coverage = @(Read-BuildPlanningJson -Path $paths.coverage)
$componentDelta = @(Read-BuildPlanningJson -Path $paths.componentDelta)
$schemaPlan = Read-BuildPlanningJson -Path $paths.schemaPlan
$dependencies = Read-BuildPlanningJson -Path $paths.dependencies
$environment = Read-BuildPlanningJson -Path $paths.environment
$traceability = @(Read-BuildPlanningJson -Path $paths.traceability)
$packages = @(Get-VerifiedBuildPlanPackages -ManifestPath $PackageManifestPath)
$specMarkdown = Get-Content -LiteralPath $paths.spec -Raw -Encoding UTF8
$publisherPrefix = (Get-BuildPlanningMarkdownValue -Markdown $specMarkdown -Label 'Publisher prefix' -DefaultValue '') -replace '\s.*$', ''
$mappings = ConvertTo-ScenarioComponentMappings -SpecPath $paths.spec -PublisherPrefix $publisherPrefix

$inputFingerprints = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $inputFingerprints[$entry.Key] = Get-BuildPlanningFileHash -Path $entry.Value
}
if (-not [string]::IsNullOrWhiteSpace($PackageManifestPath)) {
    $packageManifestFile = Resolve-BuildPlanPath -Path $PackageManifestPath -RequireFile
    $inputFingerprints.packageManifest = Get-BuildPlanningFileHash -Path $packageManifestFile
}

$plan = New-ProviderNeutralBuildPlan `
    -Decision $decision `
    -AnalysisManifest $analysisManifest `
    -CoverageMatrix $coverage `
    -ComponentDelta $componentDelta `
    -SchemaPlan $schemaPlan `
    -DependencyManifest $dependencies `
    -EnvironmentReadiness $environment `
    -AcceptanceTraceability $traceability `
    -ScenarioMappings $mappings `
    -PackageMetadata $packages `
    -ExpectedEnvironmentUrl $ExpectedEnvironmentUrl `
    -InputFingerprints $inputFingerprints

$resolvedOutput = if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
    Join-Path $acceleratorFolder 'build-plan'
} else {
    Resolve-BuildPlanPath -Path $OutputFolder
}
$writeResult = Write-ProviderNeutralBuildPlanArtifacts `
    -Plan $plan `
    -OutputFolder $resolvedOutput `
    -ApproveDecisionChange:$ApproveBuildPlanDecisionChange

[pscustomobject]@{
    Plan = $plan
    Artifacts = $writeResult
}
