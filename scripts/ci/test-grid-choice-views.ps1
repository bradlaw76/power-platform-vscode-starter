<#
=============================================================================
COMPONENT:    FOIA Grid Choice View Tests
FILE:         scripts/ci/test-grid-choice-views.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-22
ENVIRONMENT:  PowerShell 7 | Credential-free isolated mock
OVERVIEW:     Verify new FOIA-only views preserve existing view definitions.
ARCHITECTURE: Temporary repository, stateful savedquery and membership mock.
TEST CASES:   Create two, rerun stable IDs, fail foreign definitions, no PATCH.
NON-NEGOTIABLES: Never access live records or overwrite scenario evidence.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ('foia-grid-views-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'scripts') -Destination $temp -Recurse
    foreach ($folder in @('specs\federal-foia-management', 'payloads\scenarios\federal-foia-management')) {
        New-Item -ItemType Directory -Path (Join-Path $temp $folder) -Force | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $repo 'specs\federal-foia-management\grid-controls.json') -Destination (Join-Path $temp 'specs\federal-foia-management')
    Copy-Item -LiteralPath (Join-Path $repo 'payloads\scenarios\federal-foia-management\grid-views-federal-foia-management.json') -Destination (Join-Path $temp 'payloads\scenarios\federal-foia-management')
    $views = @{}
    $members = [Collections.Generic.HashSet[string]]::new()
    $appViews = [Collections.Generic.HashSet[string]]::new()
    $calls = [Collections.Generic.List[object]]::new()
    $transport = {
        param($request)
        $path = [Uri]::UnescapeDataString(($request.Uri -split '/api/data/v9.2/')[1])
        $body = if ($null -eq $request.Body) { $null } else { $request.Body | ConvertFrom-Json -Depth 40 }
        $calls.Add([pscustomobject]@{ Method = $request.Method; Path = $path; Body = $body })
        if ($request.Method -eq 'Get') {
            if ($path -like 'solutions?*') { return @{ value = @(@{solutionid = '11111111-1111-1111-1111-111111111111'}) } }
            if ($path -like 'solutioncomponents?*') {
                $present = $path -like '*componenttype eq 80'
                if ($path -match 'objectid eq ([0-9a-f-]+)') { $present = $present -or $members.Contains($Matches[1]) }
                return @{value = if ($present) { @(@{solutioncomponentid = [guid]::NewGuid().ToString()}) } else { @() }}
            }
            if ($path -match "^EntityDefinitions\(LogicalName='([^']+)'\)") {
                if ($Matches[1] -eq 'contact') {
                    return @{PrimaryIdAttribute = 'contactid'; PrimaryNameAttribute = 'fullname'; ObjectTypeCode = 2}
                }
                return @{PrimaryIdAttribute = 'incidentid'; PrimaryNameAttribute = 'title'; ObjectTypeCode = 112}
            }
            if ($path -like 'savedqueries?*' -and $path -match "name eq '([^']+)'") {
                return @{ value = if ($views.ContainsKey($Matches[1])) { @($views[$Matches[1]]) } else { @() } }
            }
            if ($path -like 'appmodules(*') { return @{appmoduleidunique = '33333333-3333-3333-3333-333333333333'} }
            if ($path -like 'appmodulecomponents?*' -and $path -match 'objectid eq ([0-9a-f-]+)') {
                return @{value = if ($appViews.Contains($Matches[1])) { @(@{objectid = $Matches[1]; componenttype = 26}) } else { @() }}
            }
        }
        if ($request.Method -eq 'Post') {
            switch ($path) {
                'savedqueries' {
                    [xml]$normalized = $body.fetchxml
                    $normalized.fetch.SetAttribute('savedqueryid', $body.savedqueryid)
                    $body.fetchxml = $normalized.OuterXml
                    $body | Add-Member -NotePropertyName ismanaged -NotePropertyValue $false
                    $views[$body.name] = $body
                    return
                }
                'AddSolutionComponent' { [void]$members.Add($body.ComponentId); return }
                'AddAppComponents' { foreach ($component in $body.Components) { [void]$appViews.Add($component.savedqueryid) }; return }
                'PublishXml' {
                    [xml]$xml = $body.ParameterXml
                    if ($xml.SelectNodes('//entity').Count -ne 13 -or $xml.SelectNodes('//appmodule').Count -ne 1) { throw 'Publish scope incorrect.' }
                    return
                }
            }
        }
        throw "Forbidden or unexpected request: $($request.Method) $path"
    }.GetNewClosure()
    $stage = Join-Path $temp 'scripts\bootstrap\61-build-grid-choice-views.ps1'
    $parameters = @{
        ScenarioSlug = 'federal-foia-management'; EnvironmentUrl = 'https://example.crm.dynamics.com'
        AccessToken = 'fake'; SolutionUniqueName = 'FederalFOIAManagement'; PublisherPrefix = 'foia'
        AppId = '22222222-2222-2222-2222-222222222222'; RequestInvoker = $transport
    }
    $first = @(& $stage @parameters)
    if ($first.Count -ne 2 -or @($first | Where-Object action -eq created).Count -ne 2 -or $views.Count -ne 2) { throw 'Two separately owned views were not created.' }
    foreach ($view in $views.Values) {
        [xml]$fetch = $view.fetchxml
        if ($view.name -notmatch '^FOIA ' -or $fetch.SelectNodes('//condition[@operator="not-null"]').Count -ne 1) { throw 'FOIA name or filter missing.' }
        [xml]$layout = $view.layoutxml
        $expected = if ($view.returnedtypecode -eq 'contact') { '2' } else { '112' }
        if ($layout.grid.object -ne $expected) { throw 'Incorrect standard-table layout type.' }
    }
    $calls.Clear()
    $second = @(& $stage @parameters)
    if (($first.id -join ',') -cne ($second.id -join ',') -or
        @($calls | Where-Object { $_.Method -ne 'Get' -and $_.Path -ne 'PublishXml' }).Count -ne 0) { throw 'Rerun changed view IDs or issued component writes.' }
    $views['FOIA Requester Choice Overview'].description = 'Foreign view'
    try { & $stage @parameters | Out-Null; throw 'Foreign view was overwritten.' } catch {
        if ($_.Exception.Message -notlike '*refusing overwrite*') { throw }
    }
    Write-Host 'Grid Choice views tests passed: two new FOIA-filtered views, stable rerun, scoped publish, no existing view edits.'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
