<#
=============================================================================
COMPONENT:    Preview-first Choice Migration Stage
FILE:         scripts/bootstrap/32-migrate-choices.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-20
ENVIRONMENT:  PowerShell 7 | Dataverse Web API
OVERVIEW:     Explicit operator stage; defaults to read-only metadata preview.
NON-NEGOTIABLES: No environment-file loading, deletes, legacy writes or row logs.
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PayloadsFolder,
    [Parameter(Mandatory)][string]$ScenarioSlug,
    [Parameter(Mandatory)][string]$SolutionUniqueName,
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [Parameter(Mandatory)][string]$AccessToken,
    [ValidateSet('Metadata','Backfill','Validate')][string]$Mode = 'Metadata',
    [switch]$Apply, [switch]$ApproveBackfill, [switch]$AcknowledgeWriteFreeze,
    [ValidateRange(1,100000)][int]$MaxRows = 10000,
    [ValidateRange(1,5000)][int]$PageSize = 250,
    [scriptblock]$RequestInvoker, [scriptblock]$TokenProvider, [scriptblock]$SleepAction
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')
. (Join-Path $PSScriptRoot 'helpers/choice-migration.ps1')
$result = Invoke-WizardChoiceMigration @PSBoundParameters
if ($Apply -and $Mode -eq 'Metadata') {
    $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $evidence = Join-Path $root ".wizard-metrics/artifacts/choices/$ScenarioSlug.json"
    New-Item -ItemType Directory -Path (Split-Path $evidence -Parent) -Force | Out-Null
    @{ ScenarioSlug=$ScenarioSlug; SolutionUniqueName=$SolutionUniqueName; Inventory=$result.Inventory } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $evidence -Encoding UTF8
}
$result
