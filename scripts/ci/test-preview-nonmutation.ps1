<#
=============================================================================
COMPONENT:    Preview Non-Mutation Acceptance
FILE:         scripts/ci/test-preview-nonmutation.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-24
ENVIRONMENT:  PowerShell 7 | Git | Credential-Free CI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Runs canonical and enabled-app scenarios in orchestrated preview mode and
verifies that Git references and the index do not change.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            credential-free acceptance test
- Inputs:          Contoso synthetic scenario planning and payload fixtures
- Outputs:         pass/fail process status
- Dependencies:    Git and bootstrap preview runtime
- Side Effects:    ignored local telemetry and preview report artifacts only

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never authenticate or call Dataverse.
- Never stage, commit, switch branches, or update Git references.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$orchestrator = Join-Path $repoRoot 'scripts/bootstrap/90-run-build.ps1'

function Get-GitPreviewSnapshot {
    param([string]$RepositoryRoot)

    Push-Location $RepositoryRoot
    try {
        $head = (& git rev-parse HEAD).Trim()
        $branch = ((& git branch --show-current) | Out-String).Trim()
        $indexHash = ((& git diff --cached) | Out-String | ForEach-Object { $_ } | & git hash-object --stdin).Trim()
        $stagedFiles = @(& git diff --cached --name-only)
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to capture Git preview snapshot.'
        }
        return [pscustomobject]@{ Head = $head; Branch = $branch; IndexHash = $indexHash; StagedFiles = $stagedFiles }
    } finally {
        Pop-Location
    }
}

$tokenBefore = $env:DV_TOKEN
$before = Get-GitPreviewSnapshot -RepositoryRoot $repoRoot
& pwsh -NoProfile -File $orchestrator -ScenarioSlug 'contoso-case-tracker' -Mode Preview
if ($LASTEXITCODE -ne 0) {
    throw "Orchestrated preview failed with exit code $LASTEXITCODE."
}

$environmentBefore = $env:DV_ENVIRONMENT_URL
$solutionBefore = $env:DV_SOLUTION_NAME
$prefixBefore = $env:DV_PUBLISHER_PREFIX
try {
    $env:DV_ENVIRONMENT_URL = 'https://preview.invalid'
    $env:DV_TOKEN = 'preview-no-token'
    $env:DV_SOLUTION_NAME = 'LabEquipmentCheckoutAcceptance20260826'
    $env:DV_PUBLISHER_PREFIX = 'ppvs'
    & pwsh -NoProfile -File $orchestrator -ScenarioSlug 'gcc-framework-acceptance' -Mode Preview -EnvironmentUrl 'https://preview.invalid' -SolutionUniqueName 'LabEquipmentCheckoutAcceptance20260826' -PublisherPrefix 'ppvs' -StrictSolutionIsolation
    if ($LASTEXITCODE -ne 0) {
        throw "Enabled-app orchestrated preview failed with exit code $LASTEXITCODE."
    }
} finally {
    $env:DV_ENVIRONMENT_URL = $environmentBefore
    $env:DV_TOKEN = $tokenBefore
    $env:DV_SOLUTION_NAME = $solutionBefore
    $env:DV_PUBLISHER_PREFIX = $prefixBefore
}
$after = Get-GitPreviewSnapshot -RepositoryRoot $repoRoot

if ($before.Head -ne $after.Head -or $before.Branch -ne $after.Branch -or $before.IndexHash -ne $after.IndexHash) {
    throw 'Preview changed Git HEAD, branch, or index.'
}
if (@(Compare-Object $before.StagedFiles $after.StagedFiles).Count -ne 0) {
    throw 'Preview changed the staged file set.'
}
if ($env:DV_TOKEN -ne $tokenBefore) {
    throw 'Preview changed the Dataverse access-token environment value.'
}

Write-Host 'Preview non-mutation checks passed.' -ForegroundColor Green
