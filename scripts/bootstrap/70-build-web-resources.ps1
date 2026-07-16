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

& $target \
    -ScenarioSlug $ScenarioSlug \
    -EnvironmentUrl $EnvironmentUrl \
    -AccessToken $AccessToken \
    -SolutionUniqueName $SolutionUniqueName \
    -PublisherPrefix $PublisherPrefix
