<#
COMPONENT: Accepted outcome gate | VERSION: 1.0
ARCHITECTURE: Existing scenario artifacts; no new stage or discovery workflow.
SECURITY: Credential-free; does not approve native fields/reports or execution.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ScenarioFolder,
    [string]$CoverageInputPath,
    [switch]$RequireCoverage
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers\requirements-coverage.ps1')
if ($CoverageInputPath) {
    Write-WizardRequirementsCoverage -InputPath $CoverageInputPath -ScenarioFolder $ScenarioFolder | ConvertTo-Json -Depth 20
} else {
    Test-WizardRequirementsCoverage -ScenarioFolder $ScenarioFolder -RequireCoverage:$RequireCoverage | ConvertTo-Json -Depth 20
}
