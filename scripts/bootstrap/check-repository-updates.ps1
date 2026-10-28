<#
=============================================================================
COMPONENT:    Repository Update Check Command
FILE:         scripts/bootstrap/check-repository-updates.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-27
ENVIRONMENT:  PowerShell 7 | Git
OVERVIEW:     Local-first advisory comparison; Fetch is explicit network opt-in.
ARCHITECTURE: Shared catalog and helper; optional JSON report; no build stages.
TEST CASES:   Cached/fetched comparisons; explicit nonzero failure; no adoption.
NON-NEGOTIABLES: Never pull, merge, tag, push or change Dataverse.
=============================================================================
#>
[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$Remote = '',
    [string]$Branch = '',
    [string]$BaselineCommit = 'HEAD',
    [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')] [string]$ScenarioSlug,
    [switch]$Fetch,
    [string]$OutputFolder = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers\repository-updates.ps1')
$report = Get-WizardRepositoryUpdateReport -RepoRoot $WorkspaceRoot -Remote $Remote -Branch $Branch `
    -BaselineCommit $BaselineCommit -ScenarioSlug $ScenarioSlug -Fetch:$Fetch
Show-WizardRepositoryUpdateReport $report
if ($OutputFolder) {
    . (Join-Path $PSScriptRoot 'helpers\wizard-run-state.ps1')
    Write-WizardAtomicJson -Path (Join-Path $OutputFolder 'repository-update-report.json') -InputObject $report
}
if ($report.status -eq 'unable-to-check') { throw "Repository update check failed: $($report.reason)" }
