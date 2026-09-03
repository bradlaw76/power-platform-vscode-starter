<#
=============================================================================
COMPONENT:    Build Charts Dashboard
FILE:         scripts/bootstrap/64-build-charts-dashboard.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-31
ENVIRONMENT:  PowerShell 7 | Dataverse Web API
=============================================================================
#>
[CmdletBinding()]
param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [string]$PayloadsFolder = '',
    [switch]$PreviewOnly,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')
. (Join-Path $PSScriptRoot 'helpers/wizard-hardening.ps1')
. (Join-Path $PSScriptRoot 'helpers/reporting-wizard.ps1')

function ConvertTo-WizardXmlValue { param([string]$Value) return [Security.SecurityElement]::Escape($Value) }

function ConvertTo-WizardStableGuid {
    param([Parameter(Mandatory)] [string]$Value)
    $hash = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))
    return [guid]::new([byte[]]$hash[0..15])
}

function Get-WizardSinglePayload {
    param([string]$Folder, [string]$Pattern)
    $files = @(Get-ChildItem -LiteralPath $Folder -Filter $Pattern -File)
    if ($files.Count -ne 1) { throw "Expected exactly one '$Pattern' payload; found $($files.Count)." }
    return Get-Content -LiteralPath $files[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Invoke-WizardReportingStage {
    param(
        [string]$RepoRoot, [string]$ScenarioSlug, [string]$PayloadsFolder,
        [string]$EnvironmentUrl, [string]$AccessToken, [string]$SolutionUniqueName, [string]$PublisherPrefix,
        [switch]$PreviewOnly, [scriptblock]$RequestInvoker
    )
    $payload = Get-WizardSinglePayload -Folder $PayloadsFolder -Pattern 'reporting-*.json'
    $marker = "Wizard scenario=$ScenarioSlug; stage=64-build-charts-dashboard.ps1"
    $evidenceItems = [Collections.Generic.List[object]]::new()
    if ($PreviewOnly) {
        foreach ($chart in @($payload.Charts)) { $evidenceItems.Add([pscustomobject]@{ kind='chart'; name=$chart.Name; table=$chart.TableLogicalName; action='planned' }) }
        $evidenceItems.Add([pscustomobject]@{ kind='dashboard'; name=$payload.Dashboard.Name; action='planned' })
    } else {
        foreach ($required in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName, $PublisherPrefix)) { if ([string]::IsNullOrWhiteSpace($required)) { throw 'Reporting apply requires explicit environment, token, solution, and publisher prefix.' } }
        Initialize-WizardArtifactManifest -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix | Out-Null
        $invoke = { param($method,$path,$body=$null) Invoke-WizardDataverseRequest -Method $method -Path $path -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body $body -RequestInvoker $RequestInvoker }
        $safeSolution = ConvertTo-WizardODataLiteral $SolutionUniqueName
        $solutions = @((& $invoke Get "solutions?`$select=solutionid&`$filter=uniquename eq '$safeSolution'").value)
        if ($solutions.Count -ne 1) { throw "Expected exactly one selected solution '$SolutionUniqueName'; found $($solutions.Count)." }
        $chartIds = @{}
        foreach ($chart in @($payload.Charts)) {
            $safeName = ConvertTo-WizardODataLiteral $chart.Name
            $matches = @((& $invoke Get "savedqueryvisualizations?`$select=savedqueryvisualizationid,name,primaryentitytypecode,description&`$filter=name eq '$safeName'").value)
            if ($matches.Count -gt 1) { throw "Chart identity collision for '$($chart.Name)': found $($matches.Count)." }
            if ($matches.Count -eq 1 -and ($matches[0].primaryentitytypecode -cne $chart.TableLogicalName -or $matches[0].description -cne $marker)) { throw "Chart '$($chart.Name)' is not owned by scenario '$ScenarioSlug'." }
            $category = ConvertTo-WizardXmlValue $chart.CategoryField
            $fetchXml = New-WizardAggregateFetchXml -Chart $chart
            $dataXml = "<datadefinition><fetchcollection>$fetchXml</fetchcollection><categorycollection><category alias='categoryvalue'><measurecollection><measure alias='aggregatevalue'/></measurecollection></category></categorycollection></datadefinition>"
            $requestedChartType = if ($chart.PSObject.Properties.Name -contains 'ChartType') { "$($chart.ChartType)" } else { 'column' }
            $chartType = switch ($requestedChartType) { 'pie' { 'Pie' } 'doughnut' { 'Doughnut' } 'bar' { 'Bar' } default { 'Column' } }
            $presentationXml = "<Chart Palette='BrightPastel'><Series><Series ChartType='$chartType' IsValueShownAsLabel='True' YValueMembers='aggregatevalue'/></Series><ChartAreas><ChartArea><AxisY/><AxisX Interval='1'/></ChartArea></ChartAreas><Legends><Legend/></Legends><Titles><Title Text='$(ConvertTo-WizardXmlValue $chart.Name)'/></Titles></Chart>"
            $body = @{ name=$chart.Name; primaryentitytypecode=$chart.TableLogicalName; description=$marker; datadescription=$dataXml; presentationdescription=$presentationXml }
            if ($matches.Count -eq 0) {
                & $invoke Post 'savedqueryvisualizations' $body | Out-Null
                $created = @((& $invoke Get "savedqueryvisualizations?`$select=savedqueryvisualizationid,name,primaryentitytypecode,description&`$filter=name eq '$safeName'").value)
                if ($created.Count -ne 1 -or $created[0].description -cne $marker -or $created[0].primaryentitytypecode -cne $chart.TableLogicalName) { throw "Chart '$($chart.Name)' did not resolve exactly once after create." }
                $id = "$($created[0].savedqueryvisualizationid)"
                $action = 'created'
            } else {
                $id = "$($matches[0].savedqueryvisualizationid)"
                & $invoke Patch "savedqueryvisualizations($id)" $body | Out-Null
                $action = 'updated'
            }
            & $invoke Post 'AddSolutionComponent' @{ ComponentId=$id; ComponentType=59; SolutionUniqueName=$SolutionUniqueName; AddRequiredComponents=$false } | Out-Null
            $chartIds[$chart.Name] = $id
            $evidenceItems.Add([pscustomobject]@{ kind='chart'; name=$chart.Name; table=$chart.TableLogicalName; id=$id; action=$action })
            Add-WizardArtifactManifestItem -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'chart' -Name "$($chart.TableLogicalName)|$($chart.Name)" -Status $action -Step '64-build-charts-dashboard.ps1' -Details @{ id=$id; table=$chart.TableLogicalName } | Out-Null
        }
        $dashboardName = $payload.Dashboard.Name
        $safeDashboardName = ConvertTo-WizardODataLiteral $dashboardName
        $dashboards = @((& $invoke Get "systemforms?`$select=formid,name,type,description&`$filter=name eq '$safeDashboardName' and type eq 0").value)
        if ($dashboards.Count -gt 1) { throw "Dashboard identity collision for '$dashboardName': found $($dashboards.Count)." }
        if ($dashboards.Count -eq 1 -and $dashboards[0].description -cne $marker) { throw "Dashboard '$dashboardName' is not owned by scenario '$ScenarioSlug'." }
        $cells = @($payload.Dashboard.ChartNames | ForEach-Object { if (-not $chartIds.ContainsKey($_)) { throw "Dashboard references unknown chart '$_'." }; $cellId=ConvertTo-WizardStableGuid "$ScenarioSlug|$dashboardName|$_|cell"; $controlId=ConvertTo-WizardStableGuid "$ScenarioSlug|$dashboardName|$_|control"; "<cell id='$cellId'><control id='$controlId' classid='{E7A81278-8635-4d9e-8D4D-59480B391C5B}'><parameters><VisualizationId>{$($chartIds[$_])}</VisualizationId></parameters></control></cell>" }) -join ''
        $formXml = "<form><tabs><tab name='dashboard'><columns><column width='100%'><sections><section name='charts'><rows><row>$cells</row></rows></section></sections></column></columns></tab></tabs></form>"
        $dashboardBody = @{ name=$dashboardName; type=0; formactivationstate=1; description=$marker; formxml=$formXml }
        if ($dashboards.Count -eq 0) { & $invoke Post 'systemforms' $dashboardBody | Out-Null; $createdDashboard=@((& $invoke Get "systemforms?`$select=formid,name,type,description&`$filter=name eq '$safeDashboardName' and type eq 0").value); if($createdDashboard.Count-ne 1-or $createdDashboard[0].description-cne $marker){throw "Dashboard '$dashboardName' did not resolve exactly once after create."}; $dashboardId="$($createdDashboard[0].formid)"; $dashboardAction='created' }
        else { $dashboardId="$($dashboards[0].formid)"; & $invoke Patch "systemforms($dashboardId)" $dashboardBody | Out-Null; $dashboardAction='updated' }
        if ([string]::IsNullOrWhiteSpace($dashboardId)) { throw "Dashboard '$dashboardName' has no ID." }
        & $invoke Post 'AddSolutionComponent' @{ ComponentId=$dashboardId; ComponentType=60; SolutionUniqueName=$SolutionUniqueName; AddRequiredComponents=$false } | Out-Null
        $evidenceItems.Add([pscustomobject]@{ kind='dashboard'; name=$dashboardName; id=$dashboardId; action=$dashboardAction })
        Add-WizardArtifactManifestItem -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'dashboard' -Name $dashboardName -Status $dashboardAction -Step '64-build-charts-dashboard.ps1' -Details @{ id=$dashboardId } | Out-Null
        $publishEntities = @($payload.Charts.TableLogicalName | Sort-Object -Unique)
        $publishXml = New-WizardEntityPublishXml -EntityLogicalNames $publishEntities
        & $invoke Post 'PublishXml' @{ ParameterXml=$publishXml } | Out-Null
    }
    $evidencePath = Join-Path $RepoRoot ".wizard-metrics/artifacts/reporting/$ScenarioSlug.json"
    New-Item -ItemType Directory -Path (Split-Path $evidencePath -Parent) -Force | Out-Null
    [ordered]@{ scenarioSlug=$ScenarioSlug; preview=[bool]$PreviewOnly; items=@($evidenceItems) } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    return @($evidenceItems)
}

if ($env:WIZARD_REPORTING_SKIP_MAIN -ne 'true') {
    if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) { $PayloadsFolder = Join-Path $repoRoot "payloads/scenarios/$ScenarioSlug" }
    Invoke-WizardReportingStage -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -SolutionUniqueName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -PreviewOnly:$PreviewOnly -RequestInvoker $RequestInvoker | Out-Null
}