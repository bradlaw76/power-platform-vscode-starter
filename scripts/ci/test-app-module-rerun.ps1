<#
=============================================================================
COMPONENT:    App Module Rerun Test
FILE:         scripts/ci/test-app-module-rerun.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-31
ENVIRONMENT:  PowerShell 7 | Credential-free CI
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scriptPath = Join-Path $repoRoot 'scripts/bootstrap/62-build-app-module.ps1'
$payloads = Join-Path $repoRoot 'payloads/scenarios/gcc-framework-acceptance'
$calls = [Collections.Generic.List[object]]::new()
$appState = [Collections.Generic.List[object]]::new()
$siteMapState = [Collections.Generic.List[object]]::new()
$requestInvoker = {
    param($request)
    $body = if ([string]::IsNullOrWhiteSpace($request.Body)) { $null } else { $request.Body | ConvertFrom-Json }
    $calls.Add([pscustomobject]@{ Method=$request.Method; Path=$request.Path; Body=$body })
    if ($request.Path -like 'appmodules?*') { return [pscustomobject]@{ value=@($appState) } }
    if ($request.Method -eq 'Post' -and $request.Path -eq 'appmodules') {
        $app = [pscustomobject]@{ appmoduleid='11111111-1111-1111-1111-111111111111'; name=$body.name; uniquename=$body.uniquename; description=$body.description }
        $appState.Add($app); return $app
    }
    if ($request.Path -like "EntityDefinitions(LogicalName='*" -and $request.Path -notlike '*solutioncomponent*') {
        $name = $request.Path -replace ".*LogicalName='([^']+)'.*", '$1'
        return [pscustomobject]@{ LogicalName=$name; MetadataId="metadata-$name" }
    }
    if ($request.Path -like 'systemforms?*type eq 0*') { return [pscustomobject]@{ value=@([pscustomobject]@{ formid='dashboard-id'; name='Dashboard'; type=0 }) } }
    if ($request.Path -like 'systemforms?*') { return [pscustomobject]@{ value=@([pscustomobject]@{ formid='form-id'; name='Main'; type=2 }) } }
    if ($request.Path -like 'savedqueries?*') { return [pscustomobject]@{ value=@([pscustomobject]@{ savedqueryid='view-id'; name='Requested View' }) } }
    if ($request.Path -like 'savedqueryvisualizations?*') { return [pscustomobject]@{ value=@([pscustomobject]@{ savedqueryvisualizationid='chart-id'; name='Chart' }) } }
    if ($request.Path -like 'workflows?*') { return [pscustomobject]@{ value=@([pscustomobject]@{ workflowid='bpf-id'; name='BPF' }) } }
    if ($request.Path -like 'sitemaps?*') { return [pscustomobject]@{ value=@($siteMapState) } }
    if ($request.Method -eq 'Post' -and $request.Path -eq 'sitemaps') {
        $siteMap = [pscustomobject]@{ sitemapid='22222222-2222-2222-2222-222222222222'; sitemapname=$body.sitemapname; sitemapnameunique=$body.sitemapnameunique; sitemapxml=$body.sitemapxml }
        $siteMapState.Add($siteMap); return [pscustomobject]@{}
    }
    if ($request.Path -like "EntityDefinitions(LogicalName='solutioncomponent')/*") {
        return [pscustomobject]@{ OptionSet=[pscustomobject]@{ Options=@(
            [pscustomobject]@{ Value=80; Label=[pscustomobject]@{ UserLocalizedLabel=[pscustomobject]@{ Label='App Module' } } },
            [pscustomobject]@{ Value=62; Label=[pscustomobject]@{ UserLocalizedLabel=[pscustomobject]@{ Label='Site Map' } } }
        ) } }
    }
    if ($request.Path -like 'solutions?*') { return [pscustomobject]@{ value=@([pscustomobject]@{ solutionid='solution-id' }) } }
    if ($request.Path -like 'solutioncomponents?*') { return [pscustomobject]@{ value=@([pscustomobject]@{ solutioncomponentid='membership-id' }) } }
    if ($request.Path -like 'ValidateApp(*') { return [pscustomobject]@{ AppValidationResponse=[pscustomobject]@{ ValidationSuccess=$true; ValidationIssueList=@() } } }
    return [pscustomobject]@{}
}

& $scriptPath -EnvironmentUrl 'https://unit.test' -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -PublisherPrefix 'ppvs' -ScenarioSlug 'gcc-framework-acceptance' -PayloadsFolder $payloads -EnableArtifactManifest $false -RequestInvoker $requestInvoker
$firstSummary = Get-Content -LiteralPath (Join-Path $repoRoot '.wizard-metrics/artifacts/app-module/app-module-summary.json') -Raw | ConvertFrom-Json
& $scriptPath -EnvironmentUrl 'https://unit.test' -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -PublisherPrefix 'ppvs' -ScenarioSlug 'gcc-framework-acceptance' -PayloadsFolder $payloads -EnableArtifactManifest $false -RequestInvoker $requestInvoker
$secondSummary = Get-Content -LiteralPath (Join-Path $repoRoot '.wizard-metrics/artifacts/app-module/app-module-summary.json') -Raw | ConvertFrom-Json
if ($appState.Count -ne 1 -or $siteMapState.Count -ne 1) { throw 'App/sitemap rerun created duplicates.' }
if ($firstSummary.appModuleId -cne $secondSummary.appModuleId -or $firstSummary.siteMapId -cne $secondSummary.siteMapId) { throw 'App/sitemap IDs changed on rerun.' }
if (@($calls | Where-Object { $_.Method -eq 'Post' -and $_.Path -in @('appmodules','sitemaps') }).Count -ne 2) { throw 'App/sitemap second run issued a create request.' }
if (@($calls | Where-Object Path -like 'solutioncomponents?*').Count -lt 2) { throw 'App/sitemap updates did not verify target-solution ownership.' }
$publishCalls = @($calls | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'PublishXml' })
if ($publishCalls.Count -ne 2 -or @($publishCalls | Where-Object { $_.Body.ParameterXml -notmatch '<appmodules><appmodule>11111111-1111-1111-1111-111111111111</appmodule></appmodules>' }).Count -gt 0) { throw 'App publication was not scoped to the stable app ID.' }
Write-Host 'App module create/rerun test passed.' -ForegroundColor Green