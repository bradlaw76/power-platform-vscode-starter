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
$manifest = @{ items=@(
    @{ kind='appmodule'; name='sample_app'; status='updated'; details=@{ id='app-1' } },
    @{ kind='publish'; name='scoped_components'; status='completed'; details=@{} }
) }
$reporting = @{ items=@(@{ kind='chart'; name='Sample Chart'; id='chart-1'; action='created' }) }
$data = @{ records=@(@{ table='sample'; key='KEY-1'; id='record-1'; action='created' }) }
$appId = '11111111-1111-1111-1111-111111111111'
$choiceId = '22222222-2222-2222-2222-222222222222'
$membership = @{ ExportAllowed=$true; Items=@(
    @{ Category='model-driven-apps'; Name='sample_app'; ObjectId=$appId; ComponentType=80; State='Already in solution' },
    @{ Category='global-choices'; Name='sample_choice'; ObjectId=$choiceId; ComponentType=9; State='Already in solution' },
    @{ Category='columns'; Name='sample.sample_priority'; ObjectId=''; SolutionComponentId='sample-table-component'; ComponentType=$null; State='Already in solution'; Reason="Inherited from include-all table root 'sample'." }
) }
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
    $membership.Items[1].ObjectId='33333333-3333-3333-3333-333333333333'
    $membership | ConvertTo-Json -Depth 10 | Set-Content $membershipPath
    try { & (Join-Path $repoRoot 'scripts/bootstrap/85-verify-idempotency.ps1') -ScenarioSlug $scenario -Phase Verify; throw 'Expected changed Choice ID failure.' } catch { if ($_.Exception.Message -notmatch 'ID changed.*global-choices') { throw } }
    $membership.Items[1].ObjectId=$choiceId
    $membership | ConvertTo-Json -Depth 10 | Set-Content $membershipPath

    $outputFolder = Join-Path $repoRoot ".wizard-metrics/exports/$scenario"
    $pacCalls = [Collections.Generic.List[string]]::new()
    $includeUnrelatedComponent = $false
    $omitExpectedComponent = $false
    $omitChoiceComponent = $false
    $choiceById = $false
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
            $expected = if ($omitExpectedComponent) { '' } else { '<RootComponent type="80" schemaName="sample_app" />' }
            $choice = if ($omitChoiceComponent) { '' } elseif ($choiceById) { '<RootComponent type="9" id="22222222-2222-2222-2222-222222222222" />' } else { '<RootComponent type="9" schemaName="sample_choice" />' }
            $extra = if ($includeUnrelatedComponent) { '<RootComponent type="1" schemaName="foreign_table" />' } else { '' }
            ('<ImportExportXml><SolutionManifest><UniqueName>UnitSolution</UniqueName><RootComponents>{0}{1}{2}</RootComponents></SolutionManifest></ImportExportXml>' -f $expected,$choice,$extra) | Set-Content -LiteralPath (Join-Path $folder 'Solution.xml')
        }
    }
    & (Join-Path $repoRoot 'scripts/bootstrap/95-export-unmanaged-solution.ps1') -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker
    if ($pacCalls.Count -ne 2 -or $pacCalls[0] -notmatch '--managed false' -or $pacCalls[1] -notmatch '--packagetype Unmanaged') { throw 'Export stage did not issue exact unmanaged export/unpack commands.' }
    if (@($pacCalls | Where-Object { $_ -match '(?i)\bimport\b' }).Count -ne 0) { throw 'Export stage attempted import.' }
    $exportEvidence = Get-Content -LiteralPath (Join-Path $artifactRoot "export/$scenario.json") -Raw | ConvertFrom-Json
    if ($exportEvidence.inspection.expected -ne 2 -or $exportEvidence.inspection.matched -ne 2 -or $exportEvidence.inheritedMembershipItemCount -ne 1) { throw 'Export stage did not record exact explicit and inherited package inspection evidence.' }
    $choiceById = $true
    & (Join-Path $repoRoot 'scripts/bootstrap/95-export-unmanaged-solution.ps1') -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker
    $choiceById = $false
    $omitChoiceComponent = $true
    try { & (Join-Path $repoRoot 'scripts/bootstrap/95-export-unmanaged-solution.ps1') -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker; throw 'Expected missing Choice failure.' } catch { if ($_.Exception.Message -notmatch 'missing required component.*global-choices') { throw } }
    $omitChoiceComponent = $false
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