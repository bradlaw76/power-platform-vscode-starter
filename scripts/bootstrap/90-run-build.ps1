<#
=============================================================================
COMPONENT:    Orchestrated Wizard Build
FILE:         scripts/bootstrap/90-run-build.ps1
VERSION:      0.3.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-11-26
ENVIRONMENT:  PowerShell 7 | Power Platform Bootstrap Runtime

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Plans or runs a scenario build in contract order with fail-fast gates, resume
state, explicit verification profiles, and machine-readable plus human-readable
summaries. Legacy remains the default; Demo options never authorize Apply.

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
✔ Resume revalidates native gates without losing completed later-stage evidence.
✔ Current reporting consent is checked before resuming or dispatching stages.

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
    [switch]$StrictSolutionIsolation,
    [scriptblock]$RequestInvoker,
    [ValidateSet('Legacy', 'Demo', 'Acceptance')]
    [string]$VerificationProfile = 'Legacy',
    [switch]$VerifyIdempotency,
    [switch]$ExportSolution
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$architectureDecisionPath = Join-Path $repoRoot "specs\$ScenarioSlug\accelerator\accelerator-decision.json"
$acceleratorBuildPlanPath = Join-Path $repoRoot "specs\$ScenarioSlug\accelerator\build-plan\build-plan-manifest.json"
if ($Mode -eq 'Apply' -and (Test-Path -LiteralPath $acceleratorBuildPlanPath -PathType Leaf)) {
    $acceleratorBuildPlan = Get-Content -LiteralPath $acceleratorBuildPlanPath -Raw | ConvertFrom-Json
    if ($acceleratorBuildPlan.architecture -cne 'fully-custom') {
        throw 'FAST-dependent or unresolved build execution is disabled. Readiness never authorizes build stages.'
    }
}
if ($Mode -eq 'Apply' -and (Test-Path -LiteralPath $architectureDecisionPath -PathType Leaf)) {
    $architectureDecision = Get-Content -LiteralPath $architectureDecisionPath -Raw | ConvertFrom-Json
    if ($architectureDecision.selectedOption -cne 'fully-custom') {
        throw 'FAST-dependent or unresolved build execution is disabled. Readiness never authorizes build stages.'
    }
}
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')
. (Join-Path $PSScriptRoot 'helpers/wizard-run-state.ps1')
. (Join-Path $PSScriptRoot 'helpers/wizard-hardening.ps1')
. (Join-Path $PSScriptRoot 'helpers\reporting-plan.ps1')

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

& (Join-Path $PSScriptRoot '14-validate-semantic-fields.ps1') -ScenarioSlug $ScenarioSlug -Mode Payload -PayloadsFolder $paths.PayloadFolder

$answersPath = Join-Path $paths.ScenarioFolder 'answers.md'
$answersText = if (Test-Path -LiteralPath $answersPath -PathType Leaf) { Get-Content -LiteralPath $answersPath -Raw } else { '' }
$reportingConfig = Get-WizardFeatureConfig -AnswersText $answersText
$reportingError = Get-WizardReportingReadinessError -FeatureConfig $reportingConfig
if ($reportingError) { throw $reportingError }
$planningText = @(Get-ChildItem -LiteralPath $paths.ScenarioFolder -File | Where-Object Name -in @('answers.md', 'spec.md', 'plan.md', 'tasks.md') | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
$hasBpfPayload = @(Get-ChildItem -LiteralPath $paths.PayloadFolder -Filter 'process-*.json' -File -ErrorAction SilentlyContinue).Count -gt 0
$hasReportingPayload = @(Get-ChildItem -LiteralPath $paths.PayloadFolder -Filter 'reporting-*.json' -File -ErrorAction SilentlyContinue).Count -eq 1
$reportingSelection = Assert-WizardNativeReportingChoice -ScenarioFolder $paths.ScenarioFolder -HasPayload $hasReportingPayload
$reportsEnabled = $reportingSelection.HtmlEnabled
if ($reportingSelection.Explicit -and ($reportingSelection.NativeEnabled -or $reportsEnabled)) {
    $mappingsPath = Join-Path $paths.ScenarioFolder 'report-mappings.md'
    if (-not (Test-Path -LiteralPath $mappingsPath) -or (Get-Content -LiteralPath $mappingsPath -Raw) -match '(?im)^- Status:\s*pending-review\s*$') {
        throw 'Reporting mappings require review before building. Complete report-mappings.md against the approved scenario requirements.'
    }
}
if ($reportingSelection.Explicit -and $reportingSelection.NativeEnabled -and -not $hasReportingPayload) {
    throw 'Native dashboards were selected, but an approved reporting-*.json payload is missing. Complete reporting planning before building.'
}
if ($reportsEnabled) {
    Read-WizardHtmlReportPlan -RepoRoot $repoRoot -ScenarioFolder $paths.ScenarioFolder | Out-Null
}
$hasDataPayload = @(Get-ChildItem -LiteralPath $paths.PayloadFolder -Filter 'data-*.json' -File -ErrorAction SilentlyContinue).Count -eq 1
$hasSecurityRolesPayload = @(Get-ChildItem -LiteralPath $paths.PayloadFolder -Filter 'security-roles-*.json' -File -ErrorAction SilentlyContinue).Count -eq 1
# Intake discovery mode and delivery verification are deliberately independent.
# Legacy and Acceptance preserve the existing payload-dependent rerun policy.
$idempotencyEnabled = ($hasReportingPayload -or $hasDataPayload -or $hasSecurityRolesPayload) -and ($VerificationProfile -ne 'Demo' -or $VerifyIdempotency)
$exportEnabled = $VerificationProfile -ne 'Demo' -or $ExportSolution

$runRoot = Join-Path $repoRoot ".wizard-metrics/runs/$ScenarioSlug"
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$statePath = Join-Path $runRoot 'current-run.json'
$summaryJsonPath = Join-Path $runRoot 'run-summary.json'
$summaryMarkdownPath = Join-Path $runRoot 'run-summary.md'

$scope = [ordered]@{
    verificationProfile = $VerificationProfile
    idempotencyEnabled = [bool]$idempotencyEnabled
    exportEnabled = [bool]$exportEnabled
    scenarioSlug = $ScenarioSlug
    payloadFolder = [IO.Path]::GetRelativePath($repoRoot, $paths.PayloadFolder).Replace('\', '/')
    environmentUrl = if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) { '[not configured]' } else { $EnvironmentUrl }
    solutionUniqueName = if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { '[not configured]' } else { $SolutionUniqueName }
    publisherPrefix = if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) { '[not configured]' } else { $PublisherPrefix.ToLowerInvariant() }
}
$scopeHashSource = "$($scope.scenarioSlug)|$($scope.payloadFolder)|$($scope.environmentUrl)|$($scope.solutionUniqueName)|$($scope.publisherPrefix)"
# Never resume evidence from a different mode or verification policy. Old state
# intentionally requires a fresh run rather than guessing its execution policy.
$scopeHashSource += "|$Mode|$VerificationProfile|$([bool]$idempotencyEnabled)|$([bool]$exportEnabled)"
foreach ($artifact in @('spec.md', 'plan.md', 'tasks.md', 'answers.md', 'field-type-decisions.json', 'html-reports.json', 'report-mappings.md')) {
    $artifactPath = Join-Path $paths.ScenarioFolder $artifact
    $scopeHashSource += "|${artifact}:$(if (Test-Path -LiteralPath $artifactPath -PathType Leaf) { (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash } else { 'absent' })"
}
$scopeHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($scopeHashSource))).ToLowerInvariant()

$stageDefinitions = @(
    [pscustomobject]@{ Name = 'validate'; Script = '15-dry-validate.ps1'; Optional = $false; Enabled = $true; Arguments = @{ ScenarioSlug = $ScenarioSlug; PayloadsFolder = $paths.PayloadFolder; PublisherPrefixOverride = $PublisherPrefix; PreviewOnly = $true } }
    [pscustomobject]@{ Name = 'tables'; Script = '20-build-tables.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder } }
    [pscustomobject]@{ Name = 'columns'; Script = '30-build-columns.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; EnvironmentUrl = $EnvironmentUrl; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'relationships'; Script = '40-build-relationships.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder } }
    [pscustomobject]@{ Name = 'semantic-metadata'; Script = '14-validate-semantic-fields.ps1'; Optional = $false; Enabled = $true; Arguments = @{ ScenarioSlug = $ScenarioSlug; Mode = 'Metadata'; PayloadsFolder = $paths.PayloadFolder; EnvironmentUrl = $EnvironmentUrl; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'solution'; Script = '50-add-to-solution.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; FailIfSolutionHasForeignTables = [bool]$StrictSolutionIsolation } }
    [pscustomobject]@{ Name = 'business-process-flow'; Script = '55-build-business-process-flows.ps1'; Optional = $true; Enabled = $hasBpfPayload; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug } }
    [pscustomobject]@{ Name = 'forms-views'; Script = '60-build-forms-views.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug } }
    [pscustomobject]@{ Name = 'native-reporting'; Script = '64-build-charts-dashboard.ps1'; Optional = $true; Enabled = $hasReportingPayload; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; SolutionUniqueName = $SolutionUniqueName; PublisherPrefix = $PublisherPrefix; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'app-module'; Script = '62-build-app-module.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'web-resources'; Script = '65-build-web-resources.ps1'; Optional = $true; Enabled = $reportsEnabled; Arguments = @{ ScenarioSlug = $ScenarioSlug; EnvironmentUrl = $EnvironmentUrl; SolutionUniqueName = $SolutionUniqueName; PublisherPrefix = $PublisherPrefix; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'synthetic-data'; Script = '66-seed-synthetic-data.ps1'; Optional = $true; Enabled = $hasDataPayload; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; SolutionUniqueName = $SolutionUniqueName; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'security-roles'; Script = '68-build-security-roles.ps1'; Optional = $true; Enabled = $hasSecurityRolesPayload; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; SolutionUniqueName = $SolutionUniqueName; Mode = $Mode; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'solution-membership-first-pass'; Script = '50-add-to-solution.ps1'; Optional = $true; Enabled = $idempotencyEnabled; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; InventoryOnly = $true; EnforceExportGate = $true } }
    [pscustomobject]@{ Name = 'idempotency-baseline'; Script = '85-verify-idempotency.ps1'; Optional = $true; Enabled = $idempotencyEnabled; Arguments = @{ ScenarioSlug = $ScenarioSlug; Phase = 'CaptureBaseline' } }
    [pscustomobject]@{ Name = 'rerun-forms-views'; Script = '60-build-forms-views.ps1'; Optional = $true; Enabled = $idempotencyEnabled; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug } }
    [pscustomobject]@{ Name = 'rerun-native-reporting'; Script = '64-build-charts-dashboard.ps1'; Optional = $true; Enabled = $idempotencyEnabled -and $hasReportingPayload; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; SolutionUniqueName = $SolutionUniqueName; PublisherPrefix = $PublisherPrefix; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'rerun-app-module'; Script = '62-build-app-module.ps1'; Optional = $true; Enabled = $idempotencyEnabled; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'rerun-synthetic-data'; Script = '66-seed-synthetic-data.ps1'; Optional = $true; Enabled = $idempotencyEnabled -and $hasDataPayload; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; SolutionUniqueName = $SolutionUniqueName; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'rerun-security-roles'; Script = '68-build-security-roles.ps1'; Optional = $true; Enabled = $idempotencyEnabled -and $hasSecurityRolesPayload; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; SolutionUniqueName = $SolutionUniqueName; Mode = $Mode; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'solution-membership-final'; Script = '50-add-to-solution.ps1'; Optional = $false; Enabled = $true; Arguments = @{ PayloadsFolder = $paths.PayloadFolder; ScenarioSlug = $ScenarioSlug; InventoryOnly = $true; EnforceExportGate = $true } }
    [pscustomobject]@{ Name = 'idempotency-verification'; Script = '85-verify-idempotency.ps1'; Optional = $true; Enabled = $idempotencyEnabled; Arguments = @{ ScenarioSlug = $ScenarioSlug; Phase = 'Verify' } }
    [pscustomobject]@{ Name = 'semantic-metadata-final'; Script = '14-validate-semantic-fields.ps1'; Optional = $false; Enabled = $true; Arguments = @{ ScenarioSlug = $ScenarioSlug; Mode = 'Metadata'; PayloadsFolder = $paths.PayloadFolder; EnvironmentUrl = $EnvironmentUrl; RequestInvoker = $RequestInvoker } }
    [pscustomobject]@{ Name = 'unmanaged-export'; Script = '95-export-unmanaged-solution.ps1'; Optional = $true; Enabled = $exportEnabled; Arguments = @{ ScenarioSlug = $ScenarioSlug; SolutionUniqueName = $SolutionUniqueName } }
    [pscustomobject]@{ Name = 'post-build'; Script = '80-post-build-analysis.ps1'; Optional = $false; Enabled = $true; Arguments = @{ ScenarioSlug = $ScenarioSlug; PayloadFolder = $paths.PayloadFolder; PreviewOnly = $true } }
)

$runState = $null
if ($Resume -and (Test-Path -LiteralPath $statePath)) {
    $runState = Read-WizardJsonFile -Path $statePath
    if ($runState.scopeHash -ne $scopeHash) {
        throw 'Resume state belongs to a different scenario, environment, solution, publisher, payload folder, execution mode, or verification policy.'
    }
}
if ($null -eq $runState) {
    $runState = [pscustomobject]@{
        runId = [guid]::NewGuid().ToString()
        scopeHash = $scopeHash
        mode = $Mode
        verificationProfile = $VerificationProfile
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
$previousStages = @($runState.stages)
foreach ($stage in $stageDefinitions) {
    $existing = @($previousStages | Where-Object { $_.name -eq $stage.Name -and $_.status -eq 'completed' })
    if ($Resume -and $existing.Count -gt 0 -and $stage.Name -notin @('columns', 'semantic-metadata', 'semantic-metadata-final')) {
        $results.Add($existing[0]) | Out-Null
        Write-Host "RESUME: $($stage.Name) already completed." -ForegroundColor DarkGray
        continue
    }

    if (-not $stage.Enabled) {
        $result = [pscustomobject]@{ name = $stage.Name; script = $stage.Script; status = 'skipped'; reason = 'not enabled by scenario or verification profile'; durationSeconds = 0 }
        $results.Add($result) | Out-Null
        Write-Host "SKIP: $($stage.Name)" -ForegroundColor DarkGray
        continue
    }

    $previewExecutableStages = @('validate', 'app-module', 'native-reporting', 'synthetic-data', 'security-roles', 'rerun-security-roles', 'idempotency-baseline', 'idempotency-verification', 'unmanaged-export', 'post-build')
    if ($Mode -eq 'Preview' -and $stage.Name -notin $previewExecutableStages) {
        $details = @()
        if ($stage.Name -eq 'forms-views') {
            $viewContractPath = Join-Path (Join-Path (Join-Path $repoRoot 'specs') $ScenarioSlug) 'views.json'
            if (Test-Path -LiteralPath $viewContractPath) {
                $viewContract = Get-Content -LiteralPath $viewContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
                $details = @($viewContract.Views | ForEach-Object { "$($_.TableLogicalName)|$($_.Name)|$($_.Disposition)" })
            }
        }
        $result = [pscustomobject]@{ name = $stage.Name; script = $stage.Script; status = 'planned'; reason = 'mutation suppressed in preview mode'; details = $details; durationSeconds = 0 }
        $results.Add($result) | Out-Null
        Write-Host "PLAN: $($stage.Script)$(if ($details.Count -gt 0) { " [$($details -join '; ')]" })" -ForegroundColor Cyan
        continue
    }

    $scriptPath = Join-Path $PSScriptRoot $stage.Script
    $arguments = @{} + $stage.Arguments
    if ($Mode -eq 'Preview' -and $stage.Name -in $previewExecutableStages) { $arguments.PreviewOnly = $true }
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
    # Revalidation checkpoints must not discard completed later-stage evidence.
    $processedNames = @($results | ForEach-Object name)
    $runState.stages = @($results.ToArray()) + @($previousStages | Where-Object { $_.name -notin $processedNames })
    Write-WizardAtomicJson -Path $statePath -InputObject $runState -Depth 20
    if ($status -eq 'failed') { break }
}

$failed = @($results | Where-Object status -eq 'failed')
$summary = [ordered]@{
    runId = $runState.runId
    mode = $Mode
    verificationProfile = $VerificationProfile
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
    "- Verification profile: $VerificationProfile",
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