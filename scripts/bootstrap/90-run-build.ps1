<#
=============================================================================
COMPONENT:    Orchestrated Wizard Build
FILE:         scripts/bootstrap/90-run-build.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-24
ENVIRONMENT:  PowerShell 7 | Power Platform Bootstrap Runtime

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Plans or runs a scenario build in contract order with fail-fast gates, resume
state, and machine-readable plus human-readable summaries.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            top-level bootstrap orchestrator
- Inputs:          scenario planning, payloads, environment context
- Outputs:         run state and summary artifacts
- Dependencies:    individual bootstrap stage scripts
- Side Effects:    none in Preview mode; Dataverse mutations in Apply mode

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Preview is the default and invokes no mutating stage.
✔ Apply mode stops at the first failed stage and records resumable state.
✔ Resume skips previously completed stages for the same scenario and scope.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never select an environment, solution, or scenario silently.
- Never commit, push, or mutate Git.
- Optional stages run only when scenario artifacts explicitly enable them.
=============================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')]
    [string]$ScenarioSlug,
    [ValidateSet('Preview', 'Apply')]
    [string]$Mode = 'Preview',
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
    [string]$PayloadsFolder = '',
    [switch]$Resume,
    [switch]$StrictSolutionIsolation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')

$paths = Resolve-WizardScenarioPaths -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder
foreach ($requiredPath in @($paths.ScenarioFolder, $paths.PayloadFolder)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Container)) {
        throw "Required scenario path not found: $requiredPath"
    }
}
foreach ($planningFile in @('spec.md', 'plan.md', 'tasks.md')) {
    $planningPath = Join-Path $paths.ScenarioFolder $planningFile
    if (-not (Test-Path -LiteralPath $planningPath -PathType Leaf)) {
        throw "Planning gate failed. Missing scenario artifact: $planningPath"
    }
}

$answersPath = Join-Path $paths.ScenarioFolder 'answers.md'
$planningText = @(Get-ChildItem -LiteralPath $paths.ScenarioFolder -File | Where-Object Name -in @('answers.md', 'spec.md', 'plan.md', 'tasks.md') | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
$hasBpfPayload = @(Get-ChildItem -LiteralPath $paths.PayloadFolder -Filter 'process-*.json' -File -ErrorAction SilentlyContinue).Count -gt 0
$reportsEnabled = $planningText -match '(?im)^.*(?:reports?|web resources?).*\b(?:yes|enabled|true)\b'

$runRoot = Join-Path $repoRoot ".wizard-metrics/runs/$ScenarioSlug"
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$statePath = Join-Path $runRoot 'current-run.json'
$summaryJsonPath = Join-Path $runRoot 'run-summary.json'
$summaryMarkdownPath = Join-Path $runRoot 'run-summary.md'

$scope = [ordered]@{
    scenarioSlug = $ScenarioSlug
    payloadFolder = [IO.Path]::GetRelativePath($repoRoot, $paths.PayloadFolder).Replace('\', '/')
    environmentUrl = if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) { '[not configured]' } else { $EnvironmentUrl }
    solutionUniqueName = if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { '[not configured]' } else { $SolutionUniqueName }
    publisherPrefix = if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) { '[not configured]' } else { $PublisherPrefix.ToLowerInvariant() }
}
$scopeHashSource = "$($scope.scenarioSlug)|$($scope.payloadFolder)|$($scope.environmentUrl)|$($scope.solutionUniqueName)|$($scope.publisherPrefix)"
$scopeHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($scopeHashSource))).ToLowerInvariant()

$stageDefinitions = @(
    [pscustomobject]@{ Name = 'validate'; Script = '15-dry-validate.ps1'; Optional = $false; Enabled = $true; Arguments = @{ ScenarioSlug = $ScenarioSlug; PayloadsFolder = $paths.PayloadFolder; PublisherPrefixOverride = $PublisherPrefix; PreviewOnly = $true } }
    [pscustomobject]@{ Name = 'tables'; Script = '20-build-tables.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder } }
    [pscustomobject]@{ Name = 'columns'; Script = '30-build-columns.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder } }
    [pscustomobject]@{ Name = 'relationships'; Script = '40-build-relationships.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder } }
    [pscustomobject]@{ Name = 'solution'; Script = '50-add-to-solution.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; FailIfSolutionHasForeignTables = [bool]$StrictSolutionIsolation } }
    [pscustomobject]@{ Name = 'business-process-flow'; Script = '55-build-business-process-flows.ps1'; Optional = $true; Enabled = $hasBpfPayload; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug } }
    [pscustomobject]@{ Name = 'forms-views'; Script = '60-build-forms-views.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug } }
    [pscustomobject]@{ Name = 'app-module'; Script = '62-build-app-module.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug } }
    [pscustomobject]@{ Name = 'web-resources'; Script = '65-build-web-resources.ps1'; Optional = $true; Enabled = $reportsEnabled; Arguments = @{ ScenarioSlug = $ScenarioSlug } }
    [pscustomobject]@{ Name = 'post-build'; Script = '80-post-build-analysis.ps1'; Optional = $false; Enabled = $true; Arguments = @{ ScenarioSlug = $ScenarioSlug; PayloadFolder = $paths.PayloadFolder; PreviewOnly = $true } }
)

$runState = $null
if ($Resume -and (Test-Path -LiteralPath $statePath)) {
    $runState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($runState.scopeHash -ne $scopeHash) {
        throw 'Resume state belongs to a different scenario, environment, solution, publisher, or payload folder.'
    }
}
if ($null -eq $runState) {
    $runState = [pscustomobject]@{
        runId = [guid]::NewGuid().ToString()
        scopeHash = $scopeHash
        mode = $Mode
        startedAtUtc = [DateTime]::UtcNow.ToString('o')
        stages = @()
    }
}

Write-Host ''
Write-Host '=== Power Platform Wizard Build ===' -ForegroundColor Cyan
Write-Host "  Mode:        $Mode"
Write-Host "  Scenario:    $ScenarioSlug"
Write-Host "  Environment: $($scope.environmentUrl)"
Write-Host "  Solution:    $($scope.solutionUniqueName)"
Write-Host "  Publisher:   $($scope.publisherPrefix)"
Write-Host "  Payloads:    $($scope.payloadFolder)"
Write-Host ''

if ($Mode -eq 'Apply') {
    foreach ($requiredValue in @($EnvironmentUrl, $SolutionUniqueName, $PublisherPrefix, $env:DV_TOKEN)) {
        if ([string]::IsNullOrWhiteSpace($requiredValue)) {
            throw 'Apply mode requires an explicit authenticated environment, solution, publisher prefix, and DV_TOKEN. Run 10-auth-connect.ps1 first.'
        }
    }
}

$results = [System.Collections.Generic.List[object]]::new()
foreach ($stage in $stageDefinitions) {
    $existing = @($runState.stages | Where-Object { $_.name -eq $stage.Name -and $_.status -eq 'completed' })
    if ($Resume -and $existing.Count -gt 0) {
        $results.Add($existing[0]) | Out-Null
        Write-Host "RESUME: $($stage.Name) already completed." -ForegroundColor DarkGray
        continue
    }

    if (-not $stage.Enabled) {
        $result = [pscustomobject]@{ name = $stage.Name; script = $stage.Script; status = 'skipped'; reason = 'explicitly not enabled by scenario'; durationSeconds = 0 }
        $results.Add($result) | Out-Null
        Write-Host "SKIP: $($stage.Name)" -ForegroundColor DarkGray
        continue
    }

    if ($Mode -eq 'Preview' -and $stage.Name -notin @('validate', 'app-module', 'post-build')) {
        $result = [pscustomobject]@{ name = $stage.Name; script = $stage.Script; status = 'planned'; reason = 'mutation suppressed in preview mode'; durationSeconds = 0 }
        $results.Add($result) | Out-Null
        Write-Host "PLAN: $($stage.Script)" -ForegroundColor Cyan
        continue
    }

    $scriptPath = Join-Path $PSScriptRoot $stage.Script
    $arguments = @{} + $stage.Arguments
    if ($Mode -eq 'Preview' -and $stage.Name -eq 'app-module') { $arguments.PreviewOnly = $true }
    $started = [DateTime]::UtcNow
    Write-Host "RUN:  $($stage.Script)" -ForegroundColor Yellow
    try {
        & $scriptPath @arguments
        if ($LASTEXITCODE -ne 0) { throw "$($stage.Script) exited with code $LASTEXITCODE." }
        $status = 'completed'
        $reason = ''
    } catch {
        $status = 'failed'
        $reason = $_.Exception.Message
    }
    $result = [pscustomobject]@{
        name = $stage.Name
        script = $stage.Script
        status = $status
        reason = $reason
        durationSeconds = [Math]::Round(([DateTime]::UtcNow - $started).TotalSeconds, 3)
    }
    $results.Add($result) | Out-Null
    $runState.stages = @($results.ToArray())
    $runState | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $statePath -Encoding UTF8
    if ($status -eq 'failed') { break }
}

$failed = @($results | Where-Object status -eq 'failed')
$summary = [ordered]@{
    runId = $runState.runId
    mode = $Mode
    status = if ($failed.Count -eq 0) { if ($Mode -eq 'Preview') { 'preview-complete' } else { 'completed' } } else { 'failed' }
    startedAtUtc = $runState.startedAtUtc
    completedAtUtc = [DateTime]::UtcNow.ToString('o')
    scope = $scope
    stages = @($results.ToArray())
}
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryJsonPath -Encoding UTF8

$markdown = @(
    '# Wizard Build Summary',
    '',
    "- Run ID: $($summary.runId)",
    "- Mode: $Mode",
    "- Status: $($summary.status)",
    "- Scenario: $ScenarioSlug",
    "- Solution: $($scope.solutionUniqueName)",
    '',
    '| Stage | Script | Status | Duration (s) |',
    '| --- | --- | --- | ---: |'
)
foreach ($result in $results) {
    $markdown += "| $($result.name) | $($result.script) | $($result.status) | $($result.durationSeconds) |"
}
$markdown | Set-Content -LiteralPath $summaryMarkdownPath -Encoding UTF8

Write-Host ''
Write-Host "Run summary: $summaryMarkdownPath" -ForegroundColor Green
if ($failed.Count -gt 0) {
    throw "Build stopped at '$($failed[0].name)': $($failed[0].reason)"
}