<#
=============================================================================
COMPONENT:    Reporting and Synthetic Data Stage Tests
FILE:         scripts/ci/test-reporting-and-data-stages.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-31
ENVIRONMENT:  PowerShell 7 | Credential-free CI
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$payloads = Join-Path $repoRoot 'payloads/scenarios/gcc-framework-acceptance'
$testRepoRoot = Join-Path ([IO.Path]::GetTempPath()) "wizard-report-data-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $testRepoRoot -Force | Out-Null
$env:WIZARD_REPORTING_SKIP_MAIN = 'true'
$env:WIZARD_DATA_SKIP_MAIN = 'true'
. (Join-Path $repoRoot 'scripts/bootstrap/64-build-charts-dashboard.ps1') -ScenarioSlug 'ignored'
. (Join-Path $repoRoot 'scripts/bootstrap/66-seed-synthetic-data.ps1') -ScenarioSlug 'ignored'
Remove-Item Env:WIZARD_REPORTING_SKIP_MAIN, Env:WIZARD_DATA_SKIP_MAIN

$transportCalls = [Collections.Generic.List[object]]::new()
$charts = [Collections.Generic.List[object]]::new()
$dashboardState = [Collections.Generic.List[object]]::new()
$reportInvoker = {
    param($request)
    $path = ($request.Uri -split '/api/data/v9.2/')[1]
    $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
    $transportCalls.Add([pscustomobject]@{ Method=$request.Method; Path=$path; Body=$body })
    if ($path -like 'solutions?*') { return [pscustomobject]@{ value=@([pscustomobject]@{ solutionid='solution-id' }) } }
    if ($path -like 'savedqueryvisualizations?*') {
        $name = [uri]::UnescapeDataString($path) -replace ".*name eq '([^']+)'.*", '$1'
        return [pscustomobject]@{ value=@($charts | Where-Object name -eq $name) }
    }
    if ($path -like 'systemforms?*') {
        $name = [uri]::UnescapeDataString($path) -replace ".*name eq '([^']+)'.*", '$1'
        return [pscustomobject]@{ value=@($dashboardState | Where-Object name -eq $name) }
    }
    if ($request.Method -eq 'Post' -and $path -eq 'savedqueryvisualizations') {
        $item = [pscustomobject]@{ savedqueryvisualizationid="chart-$($charts.Count + 1)"; name=$body.name; primaryentitytypecode=$body.primaryentitytypecode; description=$body.description }
        $charts.Add($item); return $item
    }
    if ($request.Method -eq 'Post' -and $path -eq 'systemforms') {
        $item = [pscustomobject]@{ formid='dashboard-1'; name=$body.name; type=0; description=$body.description }
        $dashboardState.Add($item); return $item
    }
    return [pscustomobject]@{}
}

$firstReports = @(Invoke-WizardReportingStage -RepoRoot $testRepoRoot -ScenarioSlug 'gcc-framework-acceptance' -PayloadsFolder $payloads -EnvironmentUrl 'https://unit.test' -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -PublisherPrefix 'ppvs' -RequestInvoker $reportInvoker)
$firstReportIds = @($firstReports.id)
$secondReports = @(Invoke-WizardReportingStage -RepoRoot $testRepoRoot -ScenarioSlug 'gcc-framework-acceptance' -PayloadsFolder $payloads -EnvironmentUrl 'https://unit.test' -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -PublisherPrefix 'ppvs' -RequestInvoker $reportInvoker)
if ($charts.Count -ne 2 -or $dashboardState.Count -ne 1) { throw 'Reporting rerun created duplicates.' }
if (Compare-Object $firstReportIds @($secondReports.id)) { throw 'Reporting IDs changed on rerun.' }
if (@($transportCalls | Where-Object { $_.Method -eq 'Post' -and $_.Path -in @('savedqueryvisualizations','systemforms') }).Count -ne 3) { throw 'Reporting rerun issued duplicate create requests.' }
$beforePreview = $transportCalls.Count
Invoke-WizardReportingStage -RepoRoot $testRepoRoot -ScenarioSlug 'gcc-framework-acceptance' -PayloadsFolder $payloads -PreviewOnly | Out-Null
if ($transportCalls.Count -ne $beforePreview) { throw 'Reporting preview invoked transport.' }
$charts.Add([pscustomobject]@{ savedqueryvisualizationid='collision'; name=$charts[0].name; primaryentitytypecode=$charts[0].primaryentitytypecode; description=$charts[0].description })
try { Invoke-WizardReportingStage -RepoRoot $testRepoRoot -ScenarioSlug 'gcc-framework-acceptance' -PayloadsFolder $payloads -EnvironmentUrl 'https://unit.test' -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -PublisherPrefix 'ppvs' -RequestInvoker $reportInvoker | Out-Null; throw 'Expected reporting collision failure.' } catch { if ($_.Exception.Message -notmatch 'collision') { throw } }

$records = @{}
$dataCreates = 0
$dataInvoker = {
    param($request)
    $path = [uri]::UnescapeDataString(($request.Uri -split '/api/data/v9.2/')[1])
    $body = if ($request.Body) { $request.Body | ConvertFrom-Json } else { $null }
    if ($path -like 'solutions?*') { return [pscustomobject]@{ value=@([pscustomobject]@{ solutionid='solution-id' }) } }
    if ($path -match "EntityDefinitions\(LogicalName='([^']+)'\)") {
        $logicalName=$Matches[1]; return [pscustomobject]@{ LogicalName=$logicalName; EntitySetName="${logicalName}s"; PrimaryIdAttribute="${logicalName}id" }
    }
    if ($request.Method -eq 'Get' -and $path -match '^([^?]+)\?.*\$filter=([^ ]+) eq ''([^'']+)''') {
        $set=$Matches[1]; $value=$Matches[3]; $matches=@($records.Values | Where-Object { $_.set -eq $set -and $_.key -eq $value }); return [pscustomobject]@{ value=$matches }
    }
    if ($request.Method -eq 'Post') {
        $set=$path; $keyProperty=@($body.PSObject.Properties | Where-Object Name -in @('ppvs_assettag','ppvs_requestnumber'))[0]; $idProperty=$set.TrimEnd('s')+'id'; $id="record-$($records.Count + 1)"
        $item=[pscustomobject]@{ set=$set; key="$($keyProperty.Value)"; ppvs_acceptancesourcetag=$body.ppvs_acceptancesourcetag }; $item | Add-Member -NotePropertyName $idProperty -NotePropertyValue $id
        $records["$set|$($keyProperty.Value)"]=$item; $script:dataCreates++; return $item
    }
    return [pscustomobject]@{}
}
$firstData = @(Invoke-WizardSyntheticDataStage -RepoRoot $testRepoRoot -ScenarioSlug 'gcc-framework-acceptance' -PayloadsFolder $payloads -EnvironmentUrl 'https://unit.test' -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -RequestInvoker $dataInvoker)
$firstDataIds = @($firstData.id)
$secondData = @(Invoke-WizardSyntheticDataStage -RepoRoot $testRepoRoot -ScenarioSlug 'gcc-framework-acceptance' -PayloadsFolder $payloads -EnvironmentUrl 'https://unit.test' -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -RequestInvoker $dataInvoker)
if ($records.Count -ne 8 -or $dataCreates -ne 8) { throw 'Synthetic-data rerun created duplicates.' }
if (Compare-Object $firstDataIds @($secondData.id)) { throw 'Synthetic-data IDs changed on rerun.' }
$beforeDataPreview=$dataCreates
Invoke-WizardSyntheticDataStage -RepoRoot $testRepoRoot -ScenarioSlug 'gcc-framework-acceptance' -PayloadsFolder $payloads -PreviewOnly | Out-Null
if ($dataCreates -ne $beforeDataPreview) { throw 'Synthetic-data preview invoked transport.' }

Write-Host 'Reporting and synthetic-data stage tests passed.' -ForegroundColor Green
Remove-Item -LiteralPath $testRepoRoot -Recurse -Force -ErrorAction SilentlyContinue