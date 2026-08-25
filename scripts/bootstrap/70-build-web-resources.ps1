<#
=============================================================================
COMPONENT:    Build Web Resources Entry Point
FILE:         scripts/bootstrap/70-build-web-resources.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web Resources | Scenario Reporting

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Acts as the optional reporting entry point that orchestrates scenario web
resource generation and solution packaging flow.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          scenario slug, reporting decisions, and repo context
- Outputs:         generated report artifacts and run guidance
- Dependencies:    65-build-web-resources.ps1 and scenario planning files
- Side Effects:    writes report artifacts and may update solution context

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Reporting must be enabled for the selected scenario.
2. Base metadata steps should already be complete.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Reporting-enabled scenarios dispatch to the report generator successfully.
✔ Scenarios without reporting configuration skip safely.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Keep this script as an optional reporting entry point.
- Preserve safe skip behavior when reporting is out of scope.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Compatibility wrapper for web resource generation.

.DESCRIPTION
    Calls 65-build-web-resources.ps1 so teams can use script 70 in generalized
    step ordering while preserving existing behavior.
#>

param(
    [string]$ScenarioSlug = "",
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
    [ValidateSet("live", "live-with-design-fallback", "static")]
    [string]$ReportMode = "live-with-design-fallback",
    [bool]$EnableLiveDataverseReports = $true,
    [bool]$FailIfReportEntitiesMissing = $true,
    [bool]$FailIfReportFieldsMissing = $true,
    [bool]$IncludeDesignSummaryWhenNoData = $true,
    [switch]$PreviewReportQueriesOnly,
    [string]$MetadataSnapshotPath = ""
)

$target = Join-Path $PSScriptRoot "65-build-web-resources.ps1"
if (-not (Test-Path $target)) {
    Write-Host "Missing target script: $target" -ForegroundColor Red
    exit 1
}

$splat = @{
    ScenarioSlug       = $ScenarioSlug
    EnvironmentUrl     = $EnvironmentUrl
    AccessToken        = $AccessToken
    SolutionUniqueName = $SolutionUniqueName
    PublisherPrefix    = $PublisherPrefix
    ReportMode         = $ReportMode
    EnableLiveDataverseReports = $EnableLiveDataverseReports
    FailIfReportEntitiesMissing = $FailIfReportEntitiesMissing
    FailIfReportFieldsMissing = $FailIfReportFieldsMissing
    IncludeDesignSummaryWhenNoData = $IncludeDesignSummaryWhenNoData
    PreviewReportQueriesOnly = $PreviewReportQueriesOnly
    MetadataSnapshotPath = $MetadataSnapshotPath
}
& $target @splat

$webResourcesExitCode = $LASTEXITCODE
if ($webResourcesExitCode -ne 0) {
    exit $webResourcesExitCode
}

$postBuildScript = Join-Path $PSScriptRoot "80-post-build-analysis.ps1"
if (-not (Test-Path $postBuildScript)) {
    Write-Host "Warning: post-build analysis script not found: $postBuildScript" -ForegroundColor Yellow
    exit 0
}

try {
    & $postBuildScript -ScenarioSlug $ScenarioSlug
    $postBuildExitCode = $LASTEXITCODE
    if ($postBuildExitCode -ne 0) {
        Write-Host "Warning: 80-post-build-analysis.ps1 failed with exit code $postBuildExitCode. Prior build steps completed successfully." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Warning: 80-post-build-analysis.ps1 failed: $($_.Exception.Message). Prior build steps completed successfully." -ForegroundColor Yellow
}

exit 0
