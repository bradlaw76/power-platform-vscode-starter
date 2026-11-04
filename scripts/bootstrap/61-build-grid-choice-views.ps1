<#
=============================================================================
COMPONENT:    FOIA Choice Grid Views
FILE:         scripts/bootstrap/61-build-grid-choice-views.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-22
ENVIRONMENT:  PowerShell 7 | Supported Dataverse savedquery APIs
OVERVIEW:     Add separately owned FOIA views without editing existing views.
ARCHITECTURE: Reuse stage-60 XML builders, explicit solution/app membership.
TEST CASES:   Exact views, FOIA filters, stable IDs, untouched original views.
NON-NEGOTIABLES: Never change internal grid-control metadata or record values.
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ScenarioSlug,
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [Parameter(Mandatory)][string]$AccessToken,
    [Parameter(Mandatory)][string]$SolutionUniqueName,
    [Parameter(Mandatory)][string]$PublisherPrefix,
    [Parameter(Mandatory)][guid]$AppId,
    [scriptblock]$RequestInvoker
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$env:WIZARD_FORMS_VIEWS_SKIP_MAIN = 'true'
try {
    . (Join-Path $PSScriptRoot '60-build-forms-views.ps1') -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -PublisherPrefix $PublisherPrefix -ScenarioSlug $ScenarioSlug
} finally {
    Remove-Item Env:WIZARD_FORMS_VIEWS_SKIP_MAIN
}
. (Join-Path $PSScriptRoot 'helpers\dataverse-runtime.ps1')
$folder = Join-Path $repoRoot ".wizard-metrics\artifacts\grid-controls\$ScenarioSlug"
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$payload = Get-Content -LiteralPath (Join-Path $repoRoot "payloads\scenarios\$ScenarioSlug\grid-views-$ScenarioSlug.json") -Raw | ConvertFrom-Json
$grid = Get-Content -LiteralPath (Join-Path $repoRoot "specs\$ScenarioSlug\grid-controls.json") -Raw | ConvertFrom-Json
if ($grid.solutionUniqueName -cne $SolutionUniqueName) { throw 'Grid solution identity mismatch.' }
$invoke = {
    param([string]$Method, [string]$Path, $Body = $null)
    Invoke-WizardDataverseRequest -Method $Method -Path $Path -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body $Body -RequestInvoker $RequestInvoker
}
$solution = @((& $invoke Get "solutions?`$select=solutionid&`$filter=uniquename eq '$SolutionUniqueName'").value)
if ($solution.Count -ne 1) { throw 'Expected one target solution.' }
$appMembers = @((& $invoke Get "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $($solution[0].solutionid) and objectid eq $AppId and componenttype eq 80").value)
if ($appMembers.Count -ne 1) { throw 'Target app must belong uniquely to the selected solution.' }
$app = & $invoke Get "appmodules($AppId)?`$select=appmoduleidunique"
$appUniqueId = ([guid]$app.appmoduleidunique).ToString()
$records = [Collections.Generic.List[object]]::new()
$pending = [Collections.Generic.List[object]]::new()
foreach ($view in $payload.Views) {
    if ($view.Name -notmatch '^FOIA ' -or $view.Disposition -cne 'create-custom' -or
        $view.TableLogicalName -notin $grid.tables -or $view.Filter.Operator -cne 'not-null' -or
        -not $view.Filter.Attribute.StartsWith("${PublisherPrefix}_", [StringComparison]::Ordinal)) {
        throw 'Only explicitly scoped, FOIA-named, FOIA-filtered custom views are allowed.'
    }
    $table = & $invoke Get "EntityDefinitions(LogicalName='$($view.TableLogicalName)')?`$select=PrimaryIdAttribute,PrimaryNameAttribute,ObjectTypeCode"
    $fields = @($view.Columns | ForEach-Object { [pscustomobject]@{ LogicalName = $_ } })
    $fetchFields = @($fields) + @([pscustomobject]@{ LogicalName = $table.PrimaryIdAttribute })
    $fetch = New-StarterViewFetchXml -TableLogical $view.TableLogicalName -PrimaryField $table.PrimaryNameAttribute -Fields $fetchFields -FilterToActiveRecords $false -FilterDefinition $view.Filter -SortDefinition $view.Sort
    [xml]$layout = New-StarterViewLayoutXml -Fields $fields -PrimaryField $table.PrimaryNameAttribute -PrimaryIdField $table.PrimaryIdAttribute
    $layout.grid.SetAttribute('object', [string]$table.ObjectTypeCode)
    $marker = "Wizard scenario=$ScenarioSlug; surface=grid-choice-overview"
    $safeName = $view.Name.Replace("'", "''")
    $existing = @((& $invoke Get "savedqueries?`$select=savedqueryid,name,description,fetchxml,layoutxml,ismanaged&`$filter=returnedtypecode eq '$($view.TableLogicalName)' and querytype eq 0 and name eq '$safeName'").value)
    if ($existing.Count -gt 1) { throw "Ambiguous view '$($view.Name)'." }
    if ($existing.Count -eq 1) {
        [xml]$currentFetch = $existing[0].fetchxml
        $currentFetch.fetch.RemoveAttribute('savedqueryid')
        if ($existing[0].ismanaged -or $existing[0].description -cne $marker -or
            $currentFetch.OuterXml -cne ([xml]$fetch).OuterXml -or
            ([xml]$existing[0].layoutxml).OuterXml -cne $layout.OuterXml) {
            throw "Existing view '$($view.Name)' is not the exact owned definition; refusing overwrite."
        }
    }
    $pending.Add([pscustomobject]@{ View = $view; Existing = $existing; Fetch = $fetch; Layout = $layout.OuterXml; Marker = $marker })
}
foreach ($item in $pending) {
    $view = $item.View
    $action = 'already-exists'
    if ($item.Existing.Count -eq 0) {
        $id = [guid]::NewGuid().ToString()
        & $invoke Post 'savedqueries' @{
            savedqueryid = $id; name = $view.Name; returnedtypecode = $view.TableLogicalName
            querytype = 0; description = $item.Marker; fetchxml = $item.Fetch; layoutxml = $item.Layout
        } | Out-Null
        $action = 'created'
    } else { $id = ([guid]$item.Existing[0].savedqueryid).ToString() }
    $members = @((& $invoke Get "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $($solution[0].solutionid) and objectid eq $id and componenttype eq 26").value)
    if ($members.Count -eq 0) {
        & $invoke Post 'AddSolutionComponent' @{ ComponentId = $id; ComponentType = 26; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $false } | Out-Null
    } elseif ($members.Count -ne 1) { throw "Ambiguous view membership '$id'." }
    $appViews = @((& $invoke Get "appmodulecomponents?`$select=objectid,componenttype&`$filter=_appmoduleidunique_value eq $appUniqueId and componenttype eq 26 and objectid eq $id").value)
    if ($appViews.Count -eq 0) {
        & $invoke Post 'AddAppComponents' @{ AppId = $AppId.ToString(); Components = @(
            @{ '@odata.type' = 'Microsoft.Dynamics.CRM.savedquery'; savedqueryid = $id }
        ) } | Out-Null
    } elseif ($appViews.Count -ne 1) { throw "Ambiguous app view '$id'." }
    Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'view' -Name "$($view.TableLogicalName)|$($view.Name)" -Status $action -Step '61-build-grid-choice-views.ps1' -Details @{ id = $id; source = "grid-views-$ScenarioSlug.json" } | Out-Null
    $records.Add([pscustomobject]@{ table = $view.TableLogicalName; name = $view.Name; id = $id; action = $action; fetchXml = $item.Fetch; layoutXml = $item.Layout })
}
$entities = @($grid.tables | ForEach-Object { '<entity>' + [Security.SecurityElement]::Escape($_) + '</entity>' }) -join ''
& $invoke Post 'PublishXml' @{ ParameterXml = "<importexportxml><entities>$entities</entities><appmodules><appmodule>$AppId</appmodule></appmodules></importexportxml>" } | Out-Null
$records.ToArray() | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $folder 'choice-views.json') -Encoding utf8
return $records.ToArray() | Select-Object table, name, id, action
