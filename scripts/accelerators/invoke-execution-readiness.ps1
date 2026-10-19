<#
=============================================================================
COMPONENT:    Nonexecuting Execution Readiness Command
FILE:         scripts/accelerators/invoke-execution-readiness.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Local artifacts
-----------------------------------------------------------------------------
OVERVIEW
Writes a deterministic, schema-validated readiness report for human review.
NON-NEGOTIABLES
Default off. Never issues approval or authorization; never runs build stages.
=============================================================================
#>
[CmdletBinding()]
param(
    [switch]$EnableExecutionReadiness,
    [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')] [string]$ScenarioSlug,
    [Parameter(Mandatory)] [string]$EvidencePath,
    [Parameter(Mandatory)] [string]$EnvironmentUrl,
    [Parameter(Mandatory)] [guid]$EnvironmentId,
    [Parameter(Mandatory)] [guid]$TenantId,
    [string]$WorkspaceRoot = '',
    [string]$OutputFolder = '',
    [DateTimeOffset]$EvaluationTimeUtc = [DateTimeOffset]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $EnableExecutionReadiness) { throw 'Execution readiness is disabled by default. Pass -EnableExecutionReadiness for local validation only.' }
. (Join-Path $PSScriptRoot 'execution-readiness.ps1')
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { $WorkspaceRoot = $adapterRoot }
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
if ([string]::IsNullOrWhiteSpace($OutputFolder)) { $OutputFolder = "specs\$ScenarioSlug\accelerator\readiness" }
$reportPath = Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path (Join-Path $OutputFolder 'execution-readiness.json')
$report = Get-ExecutionReadiness -WorkspaceRoot $WorkspaceRoot -ScenarioSlug $ScenarioSlug -EvidencePath $EvidencePath `
    -EnvironmentUrl $EnvironmentUrl -EnvironmentId $EnvironmentId -TenantId $TenantId -EvaluationTimeUtc $EvaluationTimeUtc
foreach ($inputPath in @($EvidencePath, "specs\$ScenarioSlug\accelerator\accelerator-decision.json",
    "specs\$ScenarioSlug\accelerator\build-plan\build-plan-manifest.json")) {
    if ($reportPath -ieq (Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $inputPath)) {
        throw 'Readiness output cannot overwrite an input artifact.'
    }
}
$evidenceArtifact = Read-ExecutionArtifact -Path (Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $EvidencePath)
if ($evidenceArtifact.valid -and (Test-ExecutionSchema -Value $evidenceArtifact.value -SchemaName 'execution-evidence')) {
    foreach ($input in $evidenceArtifact.value.inputArtifacts) {
        if ($reportPath -ieq (Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $input.path)) {
            throw 'Readiness output cannot overwrite a pinned planning input.'
        }
    }
}
New-Item -ItemType Directory -Path (Split-Path $reportPath -Parent) -Force | Out-Null
Set-Content -LiteralPath $reportPath -Value ($report | ConvertTo-Json -Depth 100) -Encoding utf8NoBOM
Write-Host "Execution readiness: $($report.status). Human review only; execution remains unauthorized. Report: $reportPath"
return $report
