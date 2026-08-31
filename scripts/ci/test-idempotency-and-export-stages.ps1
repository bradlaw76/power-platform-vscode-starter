<#
=============================================================================
COMPONENT:    Idempotency and Export Stage Tests
FILE:         scripts/ci/test-idempotency-and-export-stages.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-31
ENVIRONMENT:  PowerShell 7 | Credential-free CI
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scenario = 'ci-idempotency-export'
$artifactRoot = Join-Path $repoRoot '.wizard-metrics/artifacts'
$testPaths = @(
    (Join-Path $artifactRoot "manifest/$scenario"),
    (Join-Path $artifactRoot 'reporting'),
    (Join-Path $artifactRoot 'data'),
    (Join-Path $artifactRoot "contamination/$scenario")
)
foreach ($path in $testPaths) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
$manifestPath = Join-Path $testPaths[0] 'generated-artifact-manifest.json'
$reportingPath = Join-Path $testPaths[1] "$scenario.json"
$dataPath = Join-Path $testPaths[2] "$scenario.json"
$membershipPath = Join-Path $testPaths[3] 'solution-membership-report.json'
$manifest = @{ items=@(@{ kind='appmodule'; name='sample_app'; status='updated'; details=@{ id='app-1' } }) }
$reporting = @{ items=@(@{ kind='chart'; name='Sample Chart'; id='chart-1'; action='created' }) }
$data = @{ records=@(@{ table='sample'; key='KEY-1'; id='record-1'; action='created' }) }
$appId = '11111111-1111-1111-1111-111111111111'
$membership = @{ ExportAllowed=$true; Items=@(@{ Category='model-driven-apps'; Name='sample_app'; ObjectId=$appId; ComponentType=80; State='Already in solution' }) }
$manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
$reporting | ConvertTo-Json -Depth 10 | Set-Content $reportingPath
$data | ConvertTo-Json -Depth 10 | Set-Content $dataPath
$membership | ConvertTo-Json -Depth 10 | Set-Content $membershipPath

try {
    & (Join-Path $repoRoot 'scripts/bootstrap/85-verify-idempotency.ps1') -ScenarioSlug $scenario -Phase CaptureBaseline
    $reporting.items[0].action='updated'; $data.records[0].action='updated'
    $reporting | ConvertTo-Json -Depth 10 | Set-Content $reportingPath
    $data | ConvertTo-Json -Depth 10 | Set-Content $dataPath
    & (Join-Path $repoRoot 'scripts/bootstrap/85-verify-idempotency.ps1') -ScenarioSlug $scenario -Phase Verify
    $data.records[0].id='record-changed'; $data | ConvertTo-Json -Depth 10 | Set-Content $dataPath
    try { & (Join-Path $repoRoot 'scripts/bootstrap/85-verify-idempotency.ps1') -ScenarioSlug $scenario -Phase Verify; throw 'Expected changed-ID failure.' } catch { if ($_.Exception.Message -notmatch 'ID changed') { throw } }
    $data.records[0].id='record-1'; $data | ConvertTo-Json -Depth 10 | Set-Content $dataPath

    $outputFolder = Join-Path $repoRoot ".wizard-metrics/exports/$scenario"
    $pacCalls = [Collections.Generic.List[string]]::new()
    $includeUnrelatedComponent = $false
    $omitExpectedComponent = $false
    $pacInvoker = {
        param([string[]]$Arguments)
        $pacCalls.Add($Arguments -join ' ')
        if ($Arguments[1] -eq 'export') {
            $zip = $Arguments[[Array]::IndexOf($Arguments,'--path') + 1]
            New-Item -ItemType Directory -Path (Split-Path $zip -Parent) -Force | Out-Null
            Set-Content -LiteralPath $zip -Value 'mock zip'
        } elseif ($Arguments[1] -eq 'unpack') {
            $folder = $Arguments[[Array]::IndexOf($Arguments,'--folder') + 1]
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            $expected = if ($omitExpectedComponent) { '' } else { '<RootComponent type="80" id="{0}" schemaName="sample_app" />' -f $appId }
            $extra = if ($includeUnrelatedComponent) { '<RootComponent type="1" id="22222222-2222-2222-2222-222222222222" schemaName="foreign_table" />' } else { '' }
            ('<ImportExportXml><SolutionManifest><UniqueName>UnitSolution</UniqueName><RootComponents>{0}{1}</RootComponents></SolutionManifest></ImportExportXml>' -f $expected,$extra) | Set-Content -LiteralPath (Join-Path $folder 'Solution.xml')
        }
    }
    & (Join-Path $repoRoot 'scripts/bootstrap/95-export-unmanaged-solution.ps1') -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker
    if ($pacCalls.Count -ne 2 -or $pacCalls[0] -notmatch '--managed false' -or $pacCalls[1] -notmatch '--packagetype Unmanaged') { throw 'Export stage did not issue exact unmanaged export/unpack commands.' }
    if (@($pacCalls | Where-Object { $_ -match '(?i)\bimport\b' }).Count -ne 0) { throw 'Export stage attempted import.' }
    $exportEvidence = Get-Content -LiteralPath (Join-Path $artifactRoot "export/$scenario.json") -Raw | ConvertFrom-Json
    if ($exportEvidence.inspection.expected -ne 1 -or $exportEvidence.inspection.matched -ne 1) { throw 'Export stage did not record exact package inspection evidence.' }
    $omitExpectedComponent = $true
    try { & (Join-Path $repoRoot 'scripts/bootstrap/95-export-unmanaged-solution.ps1') -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker; throw 'Expected missing-component failure.' } catch { if ($_.Exception.Message -notmatch 'missing required component') { throw } }
    $omitExpectedComponent = $false
    $includeUnrelatedComponent = $true
    try { & (Join-Path $repoRoot 'scripts/bootstrap/95-export-unmanaged-solution.ps1') -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker; throw 'Expected unrelated-component failure.' } catch { if ($_.Exception.Message -notmatch 'unrelated component') { throw } }
    $source = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/bootstrap/95-export-unmanaged-solution.ps1') -Raw
    if ($source -match '(?i)solution[''"\s,]+import') { throw 'Export stage contains a solution import command.' }
} finally {
    Remove-Item -LiteralPath (Join-Path $artifactRoot "manifest/$scenario") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $reportingPath,$dataPath,(Join-Path $artifactRoot "contamination/$scenario"),(Join-Path $artifactRoot "idempotency/$scenario"),(Join-Path $artifactRoot "export/$scenario.json"),(Join-Path $repoRoot ".wizard-metrics/exports/$scenario") -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host 'Idempotency and export stage tests passed.' -ForegroundColor Green