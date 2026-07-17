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
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX
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
