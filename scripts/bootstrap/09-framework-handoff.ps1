<#
=============================================================================
COMPONENT:    Installed Framework Handoff
FILE:         scripts/bootstrap/09-framework-handoff.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
ENVIRONMENT:  PowerShell 7 | Python 3.11+ | Local consumer workspace
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ProjectRoot,
    [Parameter(Mandatory)] [string]$RuntimeWorkspace,
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [ValidateSet('start', 'preview', 'sync', 'enable', 'disable', 'rehearse', 'status', 'worker')]
    [string]$Action = 'start',
    [string]$ContractPath,
    [string]$RecipePath,
    [string]$SnapshotPath,
    [string]$AdoptionPath,
    [string]$DeliveryContextPath,
    [string]$WorkerConfigPath,
    [string]$PythonExecutable = 'python',
    [string]$BuildDocument = 'BUILD.md',
    [switch]$EnableSpecKitSync
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$arguments = @(
    (Join-Path $PSScriptRoot 'helpers/framework-handoff.py'),
    '--project', $ProjectRoot, '--runtime', $RuntimeWorkspace,
    '--scenario', $ScenarioSlug, '--action', $Action.ToLowerInvariant(), '--build', $BuildDocument
)
foreach ($entry in @(
    @('--contract', $ContractPath), @('--recipe', $RecipePath),
    @('--snapshot', $SnapshotPath), @('--adoption', $AdoptionPath),
    @('--delivery', $DeliveryContextPath), @('--worker-config', $WorkerConfigPath)
)) {
    if (-not [string]::IsNullOrWhiteSpace($entry[1])) { $arguments += $entry }
}
if ($EnableSpecKitSync) { $arguments += '--enable-sync' }
& $PythonExecutable @arguments
exit $LASTEXITCODE
