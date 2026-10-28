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

function Get-ManifestProvenanceSnapshot {
    param([string]$RepositoryRoot)

    $manifestRoot = Join-Path $RepositoryRoot '.wizard-metrics/artifacts/manifest'
    if (-not (Test-Path -LiteralPath $manifestRoot -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $manifestRoot -Filter 'generated-artifact-manifest.json' -File -Recurse | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($manifestRoot, $_.FullName).Replace('\', '/'))|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
    })
}

$gitRoot = $repoRoot
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "semantic-preview-$([guid]::NewGuid().ToString('N'))"
. (Join-Path $repoRoot 'scripts\ci\helpers\semantic-preview-fixtures.ps1')
$telemetryBefore = $env:WIZARD_METRICS_OPTOUT
try {
$env:WIZARD_METRICS_OPTOUT = '1'
New-SemanticPreviewWorkspace -SourceRoot $repoRoot -TargetRoot $fixtureRoot -ScenarioSlugs @('contoso-case-tracker', 'gcc-framework-acceptance')
$repoRoot = $fixtureRoot
$orchestrator = Join-Path $repoRoot 'scripts\bootstrap\90-run-build.ps1'
$tokenBefore = $env:DV_TOKEN
$before = Get-GitPreviewSnapshot -RepositoryRoot $gitRoot
$manifestBefore = @(Get-ManifestProvenanceSnapshot -RepositoryRoot $gitRoot)
& pwsh -NoProfile -File $orchestrator -ScenarioSlug 'contoso-case-tracker' -Mode Preview
if ($LASTEXITCODE -ne 0) {
    throw "Orchestrated preview failed with exit code $LASTEXITCODE."
}

$environmentBefore = $env:DV_ENVIRONMENT_URL
$solutionBefore = $env:DV_SOLUTION_NAME
$prefixBefore = $env:DV_PUBLISHER_PREFIX
$gridContractPath = Join-Path $repoRoot 'specs/gcc-framework-acceptance/grid-controls.json'
$choicePresentationPath = Join-Path $repoRoot 'payloads/scenarios/gcc-framework-acceptance/choice-presentations-ppvs-checkoutrequest.json'
try {
    [ordered]@{
        version = '1.0'
        TableLogicalName = 'ppvs_checkoutrequest'
        ColumnLogicalName = 'ppvs_lifecyclestage'
        Ownership = 'wizard-owned-unmanaged-local-choice'
        Options = @([ordered]@{ Value = 100000000; Label = 'Requested'; ColorToken = 'pastel-blue'; Icon = 'info' })
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $choicePresentationPath -Encoding UTF8
    $env:DV_ENVIRONMENT_URL = 'https://preview.invalid'
    $env:DV_TOKEN = 'preview-no-token'
    $env:DV_SOLUTION_NAME = 'LabEquipmentCheckoutAcceptance20260826'
    $env:DV_PUBLISHER_PREFIX = 'ppvs'
    & pwsh -NoProfile -File $orchestrator -ScenarioSlug 'gcc-framework-acceptance' -Mode Preview -EnvironmentUrl 'https://preview.invalid' -SolutionUniqueName 'LabEquipmentCheckoutAcceptance20260826' -PublisherPrefix 'ppvs' -StrictSolutionIsolation
    if ($LASTEXITCODE -ne 0) {
        throw "Enabled-app orchestrated preview failed with exit code $LASTEXITCODE."
    }
    $previewSummary = Get-Content -LiteralPath (Join-Path $repoRoot '.wizard-metrics/runs/gcc-framework-acceptance/run-summary.json') -Raw | ConvertFrom-Json
    $formsViewsPreview = @($previewSummary.stages | Where-Object { $_.name -eq 'forms-views' })[0]
    $gridPreview = @($previewSummary.stages | Where-Object { $_.name -eq 'grid-control' })[0]
    $choicePreview = @($previewSummary.stages | Where-Object { $_.name -eq 'choice-presentations' })[0]
    if ($choicePreview.status -ne 'completed') {
        throw "Choice-presentation Preview did not complete: $($choicePreview.reason)"
    }
    $choicePreviewReport = Get-Content -LiteralPath (Join-Path $repoRoot '.wizard-metrics/artifacts/choice-presentations/gcc-framework-acceptance/choice-presentation-plan.json') -Raw | ConvertFrom-Json
    if ($choicePreviewReport.applied) {
        throw 'Choice-presentation Preview incorrectly reported metadata as applied.'
    }
    if ($gridPreview.status -ne 'skipped') {
        throw 'Grid-control stage changed behavior when grid-controls.json was absent.'
    }
    if (@($formsViewsPreview.details) -notcontains 'ppvs_checkoutrequest|Active Checkout Requests|adopt-generated-active') {
        throw 'Credential-free preview did not report generated Active-view adoption.'
    }
    if (@($formsViewsPreview.details) -notcontains 'ppvs_labasset|Available Lab Assets|create-custom') {
        throw 'Credential-free preview did not report the custom availability view.'
    }

    [ordered]@{
        version = '1.0'
        tables = @([ordered]@{
            tableLogicalName = 'ppvs_checkoutrequest'; scope = 'all-views'; enableEditing = $false
            filtering = $true; sorting = $true; grouping = $false; aggregation = $false
            columnReordering = $false; multiselect = $true; rangeSelection = $true
            jumpBar = $false; pagination = $false; optionSetColors = $false
            statusIcons = $true; typeIcons = $false
        })
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $gridContractPath -Encoding UTF8
    & pwsh -NoProfile -File $orchestrator -ScenarioSlug 'gcc-framework-acceptance' -Mode Preview -EnvironmentUrl 'https://preview.invalid' -SolutionUniqueName 'LabEquipmentCheckoutAcceptance20260826' -PublisherPrefix 'ppvs' -StrictSolutionIsolation
    if ($LASTEXITCODE -ne 0) {
        throw "Grid-enabled orchestrated preview failed with exit code $LASTEXITCODE."
    }
    $gridEnabledSummary = Get-Content -LiteralPath (Join-Path $repoRoot '.wizard-metrics/runs/gcc-framework-acceptance/run-summary.json') -Raw | ConvertFrom-Json
    $gridEnabledPreview = @($gridEnabledSummary.stages | Where-Object { $_.name -eq 'grid-control' })[0]
    if ($gridEnabledPreview.status -ne 'completed') {
        throw "Grid-enabled orchestrated preview did not complete stage 61: $($gridEnabledPreview.reason)"
    }
    $gridPreviewReport = Get-Content -LiteralPath (Join-Path $repoRoot '.wizard-metrics/artifacts/grid-controls/gcc-framework-acceptance/preview-report.json') -Raw | ConvertFrom-Json
    if ($gridPreviewReport.applied) {
        throw 'Grid-enabled orchestrated preview incorrectly reported maker configuration as applied.'
    }
} finally {
    Remove-Item -LiteralPath $gridContractPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $choicePresentationPath -Force -ErrorAction SilentlyContinue
    $env:DV_ENVIRONMENT_URL = $environmentBefore
    $env:DV_TOKEN = $tokenBefore
    $env:DV_SOLUTION_NAME = $solutionBefore
    $env:DV_PUBLISHER_PREFIX = $prefixBefore
}
$after = Get-GitPreviewSnapshot -RepositoryRoot $gitRoot
$manifestAfter = @(Get-ManifestProvenanceSnapshot -RepositoryRoot $gitRoot)

if ($before.Head -ne $after.Head -or $before.Branch -ne $after.Branch -or $before.IndexHash -ne $after.IndexHash) {
    throw 'Preview changed Git HEAD, branch, or index.'
}
if (@(Compare-Object $before.StagedFiles $after.StagedFiles).Count -ne 0) {
    throw 'Preview changed the staged file set.'
}
if ($env:DV_TOKEN -ne $tokenBefore) {
    throw 'Preview changed the Dataverse access-token environment value.'
}
if (@(Compare-Object $manifestBefore $manifestAfter).Count -ne 0) {
    throw 'Preview created, deleted, or altered artifact manifest provenance.'
}

Write-Host 'Preview non-mutation checks passed.' -ForegroundColor Green
} finally {
    $env:WIZARD_METRICS_OPTOUT = $telemetryBefore
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
