<#
=============================================================================
COMPONENT:    Power Apps Grid Integration Tests
FILE:         scripts/ci/test-power-apps-grid.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-01
ENVIRONMENT:  PowerShell 7 | Credential-free CI
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scriptPath = Join-Path $repoRoot 'scripts/bootstrap/61-configure-power-apps-grid.ps1'
$workRoot = Join-Path $repoRoot '.wizard-metrics/test-work/power-apps-grid'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-Contract {
    param([string]$Scenario, [bool]$Editing)
    $folder = Join-Path $repoRoot "specs/$Scenario"
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    [ordered]@{
        version = '1.0'
        tables = @([ordered]@{
            tableLogicalName = 'contoso_workitem'; scope = 'all-views'
            enableEditing = $Editing; filtering = $true; sorting = $true
            grouping = $true; aggregation = $true; columnReordering = $true
            multiselect = $true; rangeSelection = $true; jumpBar = $false
            pagination = $true; optionSetColors = $true; statusIcons = $true
            typeIcons = $true; persona = 'Dispatcher'; rationale = 'Operational triage'
        })
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $folder 'grid-controls.json') -Encoding UTF8
    return $folder
}

function New-EntityFixture {
    param([string]$Folder, [string]$Table = 'contoso_workitem', [bool]$Editing = $true, [bool]$IncludeControl = $true, [bool]$Filtering = $true)
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    $control = if ($IncludeControl) { '<customControl name="Microsoft.PowerApps.PowerAppsOneGrid" formFactor="0" />' } else { '<customControl name="Other.Control" />' }
    @"
<Entity><Name>$Table</Name><CustomControlDefaultConfigs><CustomControlDefaultConfig>
<ControlDescriptionXML>$control</ControlDescriptionXML><parameters>
<EnableEditing>$($Editing.ToString().ToLowerInvariant())</EnableEditing>
<EnableFiltering>$($Filtering.ToString().ToLowerInvariant())</EnableFiltering>
<EnableSorting>true</EnableSorting><EnableGrouping>true</EnableGrouping>
<EnableAggregation>true</EnableAggregation><EnableColumnMoving>true</EnableColumnMoving>
<EnableMultipleSelection>true</EnableMultipleSelection><EnableRangeSelection>true</EnableRangeSelection>
<EnableJumpBar>false</EnableJumpBar><EnablePagination>true</EnablePagination>
<EnableDropdownColor>true</EnableDropdownColor><ShowStatusIcons>true</ShowStatusIcons>
<ShowDataTypeIcons>true</ShowDataTypeIcons></parameters>
</CustomControlDefaultConfig></CustomControlDefaultConfigs></Entity>
"@ | Set-Content -LiteralPath (Join-Path $Folder 'Entity.xml') -Encoding UTF8
}

function Invoke-ExpectedFailure {
    param([scriptblock]$Action, [string]$Contains)
    try { & $Action; throw 'Expected failure did not occur.' } catch {
        Assert-True ($_.Exception.Message -match [regex]::Escape($Contains)) "Expected failure containing '$Contains'; got: $($_.Exception.Message)"
    }
}

$scenarios = @('grid-ci-preview', 'grid-ci-verified', 'grid-ci-failure')
try {
    Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($scenario in $scenarios) {
        Remove-Item -LiteralPath (Join-Path $repoRoot "specs/$scenario") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $repoRoot ".wizard-metrics/artifacts/grid-controls/$scenario") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $repoRoot ".wizard-metrics/artifacts/manifest/$scenario") -Recurse -Force -ErrorAction SilentlyContinue
    }

    $previewScenario = $scenarios[0]
    New-Contract -Scenario $previewScenario -Editing $true | Out-Null
    & $scriptPath -ScenarioSlug $previewScenario -Mode Preview
    $previewRoot = Join-Path $repoRoot ".wizard-metrics/artifacts/grid-controls/$previewScenario"
    foreach ($name in @('maker-handoff.md', 'maker-handoff.html', 'preview-report.json')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $previewRoot $name)) "Preview artifact missing: $name"
    }
    $preview = Get-Content -LiteralPath (Join-Path $previewRoot 'preview-report.json') -Raw | ConvertFrom-Json
    Assert-True (-not $preview.applied) 'Preview incorrectly claims configuration was applied.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $previewRoot 'maker-handoff.md') -Raw) -match 'classic solution explorer') 'Maker handoff lacks classic solution explorer steps.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoRoot ".wizard-metrics/artifacts/manifest/$previewScenario"))) 'Preview mutated the artifact manifest.'

    $verifiedScenario = $scenarios[1]
    $verifiedSpec = New-Contract -Scenario $verifiedScenario -Editing $true
    $fixture = Join-Path $workRoot 'verified/Entities/contoso_workitem'
    New-EntityFixture -Folder $fixture -Editing $true
    & $scriptPath -ScenarioSlug $verifiedScenario -Mode Verify -UnpackedSolutionFolder (Join-Path $workRoot 'verified') -SolutionUniqueName 'GridCiSolution' -PublisherPrefix 'contoso'
    $reportPath = Join-Path $repoRoot ".wizard-metrics/artifacts/grid-controls/$verifiedScenario/verification-report.json"
    $firstReport = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    Assert-True ($firstReport.verified -and $firstReport.tables[0].properties.enableEditing) 'OneGrid/editing=true was not verified.'
    Assert-True ($firstReport.tables[0].properties.grouping -and $firstReport.tables[0].properties.optionSetColors) 'Requested maker properties were not verified.'

    # Editing false is explicit and supported.
    New-Contract -Scenario $verifiedScenario -Editing $false | Out-Null
    New-EntityFixture -Folder $fixture -Editing $false
    & $scriptPath -ScenarioSlug $verifiedScenario -Mode Verify -UnpackedSolutionFolder (Join-Path $workRoot 'verified') -SolutionUniqueName 'GridCiSolution' -PublisherPrefix 'contoso'
    $secondReport = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    Assert-True (-not $secondReport.tables[0].properties.enableEditing) 'Editing=false was not verified.'
    & $scriptPath -ScenarioSlug $verifiedScenario -Mode Verify -UnpackedSolutionFolder (Join-Path $workRoot 'verified') -SolutionUniqueName 'GridCiSolution' -PublisherPrefix 'contoso'
    $manifest = Get-Content -LiteralPath (Join-Path $repoRoot ".wizard-metrics/artifacts/manifest/$verifiedScenario/generated-artifact-manifest.json") -Raw | ConvertFrom-Json
    Assert-True (@($manifest.items | Where-Object kind -eq 'grid-control').Count -eq 1) 'Stable rerun created duplicate manifest entries.'

    $failureScenario = $scenarios[2]
    New-Contract -Scenario $failureScenario -Editing $true | Out-Null
    $missingRoot = Join-Path $workRoot 'missing/Entities/contoso_workitem'
    New-EntityFixture -Folder $missingRoot -IncludeControl $false
    Invoke-ExpectedFailure { & $scriptPath -ScenarioSlug $failureScenario -Mode Verify -UnpackedSolutionFolder (Join-Path $workRoot 'missing') -SolutionUniqueName 'GridFailureSolution' -PublisherPrefix 'contoso' } 'does not declare Microsoft.PowerApps.PowerAppsOneGrid'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoRoot ".wizard-metrics/artifacts/manifest/$failureScenario"))) 'Failed verification wrote manifest provenance.'

    $mismatchRoot = Join-Path $workRoot 'mismatch/Entities/contoso_workitem'
    New-EntityFixture -Folder $mismatchRoot -Filtering $false
    Invoke-ExpectedFailure { & $scriptPath -ScenarioSlug $failureScenario -Mode Verify -UnpackedSolutionFolder (Join-Path $workRoot 'mismatch') -SolutionUniqueName 'GridFailureSolution' -PublisherPrefix 'contoso' } "property 'filtering' mismatch"

    $wrongRoot = Join-Path $workRoot 'wrong/Entities/wrong'
    New-EntityFixture -Folder $wrongRoot -Table 'contoso_other'
    Invoke-ExpectedFailure { & $scriptPath -ScenarioSlug $failureScenario -Mode Verify -UnpackedSolutionFolder (Join-Path $workRoot 'wrong') -SolutionUniqueName 'GridFailureSolution' -PublisherPrefix 'contoso' } 'No exported Entity.xml matched'

    $ambiguousRoot = Join-Path $workRoot 'ambiguous'
    New-EntityFixture -Folder (Join-Path $ambiguousRoot 'Entities/a')
    New-EntityFixture -Folder (Join-Path $ambiguousRoot 'Entities/b')
    Invoke-ExpectedFailure { & $scriptPath -ScenarioSlug $failureScenario -Mode Verify -UnpackedSolutionFolder $ambiguousRoot -SolutionUniqueName 'GridFailureSolution' -PublisherPrefix 'contoso' } 'Ambiguous exported metadata'

    $orchestrator = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/bootstrap/90-run-build.ps1') -Raw
    $formsIndex = $orchestrator.IndexOf("Name = 'forms-views'")
    $gridIndex = $orchestrator.IndexOf("Name = 'grid-control'")
    $reportingIndex = $orchestrator.IndexOf("Name = 'native-reporting'")
    $appIndex = $orchestrator.IndexOf("Name = 'app-module'")
    Assert-True ($formsIndex -ge 0 -and $gridIndex -gt $formsIndex -and $gridIndex -lt $reportingIndex -and $gridIndex -lt $appIndex) 'Stage 61 is not positioned after forms/views and before reporting/app assembly.'
    Assert-True ($orchestrator -match '\[string\]\$GridControlUnpackedSolutionFolder') 'Orchestrator override parameter is missing.'
    Assert-True ($orchestrator -match "Name = 'rerun-grid-control'") 'Grid verifier is absent from the idempotency rerun.'
    Assert-True ($orchestrator -match "-notin @\('grid-control', 'rerun-grid-control'\)") 'Orchestrated Preview would pass unsupported PreviewOnly to the grid stage.'

    $wizardText = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/bootstrap/05-start-wizard.ps1') -Raw
    Assert-True ($wizardText -match 'Use the modern Power Apps grid at table level for all views\?.+Default ''no''') 'Advanced intake must require explicit grid opt-in.'
    Assert-True ($wizardText -match 'Remove-Item -LiteralPath \$gridControlsPath -Force') 'Wizard reruns do not remove a stale grid contract when the feature is disabled.'

    Write-Host 'Power Apps grid integration tests passed.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($scenario in $scenarios) {
        Remove-Item -LiteralPath (Join-Path $repoRoot "specs/$scenario") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $repoRoot ".wizard-metrics/artifacts/grid-controls/$scenario") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $repoRoot ".wizard-metrics/artifacts/manifest/$scenario") -Recurse -Force -ErrorAction SilentlyContinue
    }
}
