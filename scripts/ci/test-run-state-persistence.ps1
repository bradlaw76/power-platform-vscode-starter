<#
=============================================================================
COMPONENT:    Run State Persistence Acceptance
FILE:         scripts/ci/test-run-state-persistence.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-31
ENVIRONMENT:  PowerShell 7 | Git | Credential-free CI
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$orchestrator = Join-Path $repoRoot 'scripts/bootstrap/90-run-build.ps1'
. (Join-Path $repoRoot 'scripts/bootstrap/helpers/wizard-run-state.ps1')

function Get-TrackedFileSnapshot {
    param([string]$RepositoryRoot)

    $snapshot = [Collections.Generic.List[string]]::new()
    foreach ($relativePath in @(& git -C $RepositoryRoot ls-files)) {
        $fullPath = Join-Path $RepositoryRoot $relativePath
        $hash = if (Test-Path -LiteralPath $fullPath -PathType Leaf) { (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash } else { '[missing]' }
        $snapshot.Add("$relativePath|$hash")
    }
    if ($LASTEXITCODE -ne 0) { throw 'Unable to capture tracked-file snapshot.' }
    return @($snapshot)
}

function Get-GitStateSnapshot {
    param([string]$RepositoryRoot)

    $head = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
    $index = ((& git -C $RepositoryRoot diff --cached) | Out-String | & git hash-object --stdin).Trim()
    $worktree = ((& git -C $RepositoryRoot diff) | Out-String | & git hash-object --stdin).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to capture Git state.' }
    return "$head|$index|$worktree"
}

$trackedBefore = @(Get-TrackedFileSnapshot -RepositoryRoot $repoRoot)
$gitBefore = Get-GitStateSnapshot -RepositoryRoot $repoRoot
$transportCallCount = 0
$tokenBefore = $env:DV_TOKEN
$tokenSentinel = 'run-state-secret-sentinel'
$env:DV_TOKEN = $tokenSentinel
$transport = {
    param($Request)
    $script:transportCallCount++
    throw "Preview invoked Dataverse transport for '$($Request.Uri)'."
}

for ($run = 1; $run -le 2; $run++) {
    & $orchestrator -ScenarioSlug 'gcc-framework-acceptance' -Mode Preview -EnvironmentUrl 'https://preview.invalid' -SolutionUniqueName 'LabEquipmentCheckoutAcceptance20260826' -PublisherPrefix 'ppvs' -StrictSolutionIsolation -RequestInvoker $transport
    $summaryPath = Join-Path $repoRoot '.wizard-metrics/runs/gcc-framework-acceptance/run-summary.json'
    $summary = Read-WizardJsonFile -Path $summaryPath
    if ($summary.status -ne 'preview-complete') { throw "Framework Acceptance preview $run did not complete." }
    foreach ($stageName in @('native-reporting', 'idempotency-baseline', 'idempotency-verification')) {
        $stage = @($summary.stages | Where-Object name -eq $stageName)
        if ($stage.Count -ne 1 -or $stage[0].status -ne 'completed') { throw "Framework Acceptance preview $run did not complete '$stageName'." }
    }
    $statePath = Join-Path $repoRoot '.wizard-metrics/runs/gcc-framework-acceptance/current-run.json'
    $state = Read-WizardJsonFile -Path $statePath
    if (@($state.stages).Count -ne @($summary.stages).Count) { throw "Framework Acceptance preview $run persisted an incomplete run state." }
    foreach ($evidencePath in @($statePath, $summaryPath)) {
        if ([IO.File]::ReadAllText($evidencePath) -match [regex]::Escape($tokenSentinel)) { throw "Preview serialized a Dataverse token into '$evidencePath'." }
    }
}
$env:DV_TOKEN = $tokenBefore

if ($transportCallCount -ne 0) { throw "Framework Acceptance previews invoked Dataverse transport $transportCallCount time(s)." }
$trackedAfter = @(Get-TrackedFileSnapshot -RepositoryRoot $repoRoot)
$gitAfter = Get-GitStateSnapshot -RepositoryRoot $repoRoot
if (@(Compare-Object $trackedBefore $trackedAfter).Count -ne 0) { throw 'Framework Acceptance previews changed checked-in file content.' }
if ($gitBefore -cne $gitAfter) { throw 'Framework Acceptance previews changed Git HEAD, index, or worktree state.' }

$atomicRoot = Join-Path ([IO.Path]::GetTempPath()) "wizard-run-state-$([guid]::NewGuid().ToString('N'))"
$atomicPath = Join-Path $atomicRoot 'current-run.json'
try {
    $original = [ordered]@{ runId='original'; scopeHash='scope'; mode='Preview'; startedAtUtc='2026-08-31T00:00:00Z'; stages=@() }
    Write-WizardAtomicJson -Path $atomicPath -InputObject $original
    $lockedStream = [IO.FileStream]::new($atomicPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        try {
            Write-WizardAtomicJson -Path $atomicPath -InputObject ([ordered]@{ runId='replacement'; stages=@() }) -RetryCount 1
            throw 'Expected the locked atomic replacement to fail.'
        } catch {
            $expectedFileSystemFailure = $_.Exception -is [IO.IOException] -or $_.Exception -is [UnauthorizedAccessException]
            if (-not $expectedFileSystemFailure) { throw }
        }
    } finally {
        $lockedStream.Dispose()
    }
    $preserved = Read-WizardJsonFile -Path $atomicPath
    if ($preserved.runId -cne 'original') { throw 'A failed atomic write corrupted the previous run state.' }
    if (@(Get-ChildItem -LiteralPath $atomicRoot -Filter '*.tmp' -File).Count -ne 0) { throw 'A failed atomic write left an orphan temporary file.' }
    Write-WizardAtomicJson -Path $atomicPath -InputObject ([ordered]@{ runId='replacement'; scopeHash='scope'; mode='Preview'; startedAtUtc='2026-08-31T00:00:00Z'; stages=@() })
    if ((Read-WizardJsonFile -Path $atomicPath).runId -cne 'replacement') { throw 'Atomic run-state recovery write failed.' }
} finally {
    Remove-Item -LiteralPath $atomicRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Run-state persistence checks passed.' -ForegroundColor Green