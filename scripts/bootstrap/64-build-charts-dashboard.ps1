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
    [switch]$AcknowledgeWriteFreeze,
    [ValidateRange(1,100000)][int]$ChoiceMaxRows = 10000,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')
. (Join-Path $PSScriptRoot 'helpers/wizard-hardening.ps1')
. (Join-Path $PSScriptRoot 'helpers/reporting-wizard.ps1')

$envFile = Join-Path $repoRoot '.env.ps1'
if (Test-Path -LiteralPath $envFile) {
    . $envFile
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) { $EnvironmentUrl = $global:DV_ENVIRONMENT_URL }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) { $AccessToken = $global:DV_TOKEN }
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { $SolutionUniqueName = $global:DV_SOLUTION_NAME }
    if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) { $PublisherPrefix = $global:DV_PUBLISHER_PREFIX }
}

function ConvertTo-WizardXmlValue { param([string]$Value) return [Security.SecurityElement]::Escape($Value) }

function ConvertTo-WizardStableGuid {
    param([Parameter(Mandatory)] [string]$Value)
    $hash = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))
    return [guid]::new([byte[]]$hash[0..15])
}

function Get-WizardDashboardControlSignatures {
    param([string]$FormXml)
    if ([string]::IsNullOrWhiteSpace($FormXml)) { return @() }
    try { [xml]$document = $FormXml } catch { return @() }
    return @($document.SelectNodes('//control[parameters/VisualizationId]') | ForEach-Object {
        $parameters = $_.SelectSingleNode('parameters')
        $visualizationNode = $parameters.SelectSingleNode('VisualizationId')
        $viewNode = $parameters.SelectSingleNode('ViewId')
        $targetEntityNode = $parameters.SelectSingleNode('TargetEntityType')
        $chartGridModeNode = $parameters.SelectSingleNode('ChartGridMode')
        $visualizationId = "$(if ($null -eq $visualizationNode) { '' } else { $visualizationNode.InnerText })".Trim('{}').ToLowerInvariant()
        $viewId = "$(if ($null -eq $viewNode) { '' } else { $viewNode.InnerText })".Trim('{}').ToLowerInvariant()
        $targetEntity = "$(if ($null -eq $targetEntityNode) { '' } else { $targetEntityNode.InnerText })".ToLowerInvariant()
        $chartGridMode = "$(if ($null -eq $chartGridModeNode) { '' } else { $chartGridModeNode.InnerText })".ToLowerInvariant()
        "$visualizationId|$viewId|$targetEntity|$chartGridMode"
    })
}

function Get-WizardSinglePayload {
    param([string]$Folder, [string]$Pattern)
    $files = @(Get-ChildItem -LiteralPath $Folder -Filter $Pattern -File)
    if ($files.Count -ne 1) { throw "Expected exactly one '$Pattern' payload; found $($files.Count)." }
    return Get-Content -LiteralPath $files[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-WizardDashboardDefinitions {
    param($Payload)

    $hasLegacy = $Payload.PSObject.Properties.Name -contains 'Dashboard'
    $hasMultiple = $Payload.PSObject.Properties.Name -contains 'Dashboards'
    $dashboards = if ($hasMultiple) { @($Payload.Dashboards) } elseif ($hasLegacy) { @($Payload.Dashboard) } else { @() }
    if ($dashboards.Count -eq 0) { throw 'Reporting payload must define Dashboard or a non-empty Dashboards array.' }

    $duplicateNames = @($dashboards | Group-Object Name | Where-Object Count -gt 1)
    if ($duplicateNames.Count -gt 0) { throw "Dashboard names must be unique; duplicate '$($duplicateNames[0].Name)'." }
    if ($hasLegacy -and $hasMultiple) {
        $legacyMatch = @($dashboards | Where-Object Name -ceq $Payload.Dashboard.Name)
        if ($legacyMatch.Count -ne 1 -or (@($legacyMatch[0].ChartNames) -join "`n") -cne (@($Payload.Dashboard.ChartNames) -join "`n")) {
            throw 'Legacy Dashboard must exactly match one Dashboards definition when both contracts are supplied.'
        }
    }
    return $dashboards
}

function Invoke-WizardReportingStage {
    param(
        [string]$RepoRoot, [string]$ScenarioSlug, [string]$PayloadsFolder,
        [string]$EnvironmentUrl, [string]$AccessToken, [string]$SolutionUniqueName, [string]$PublisherPrefix,
        [switch]$PreviewOnly, [scriptblock]$RequestInvoker, [switch]$AcknowledgeWriteFreeze,
        [ValidateRange(1,100000)][int]$ChoiceMaxRows = 10000
    )
    . (Join-Path $PSScriptRoot 'helpers/choice-migration.ps1')
    if (-not $PreviewOnly) {
        Assert-WizardChoiceCutover -PayloadsFolder $PayloadsFolder -ScenarioSlug $ScenarioSlug `
            -SolutionUniqueName $SolutionUniqueName -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker -AcknowledgeWriteFreeze:$AcknowledgeWriteFreeze -ChoiceMaxRows $ChoiceMaxRows
    }
    $payload = Get-WizardSinglePayload -Folder $PayloadsFolder -Pattern 'reporting-*.json'
    if (-not $payload.Enabled) { return @() }
    $dashboards = @(Get-WizardDashboardDefinitions -Payload $payload)
    $chartNames = @($payload.Charts | ForEach-Object { "$($_.Name)" })
    $duplicateChartNames = @($chartNames | Group-Object | Where-Object Count -gt 1)
    if ($duplicateChartNames.Count -gt 0) { throw "Chart names must be unique; duplicate '$($duplicateChartNames[0].Name)'." }
    foreach ($dashboard in $dashboards) {
        foreach ($chartName in @($dashboard.ChartNames)) {
            if ($chartNames -cnotcontains "$chartName") { throw "Dashboard '$($dashboard.Name)' references unknown chart '$chartName'." }
        }
    }
    $marker = "Wizard scenario=$ScenarioSlug; stage=64-build-charts-dashboard.ps1"
    $evidenceItems = [Collections.Generic.List[object]]::new()
    if ($PreviewOnly) {
        foreach ($chart in @($payload.Charts)) { $evidenceItems.Add([pscustomobject]@{ kind='chart'; name=$chart.Name; table=$chart.TableLogicalName; action='planned' }) }
        foreach ($dashboard in $dashboards) { $evidenceItems.Add([pscustomobject]@{ kind='dashboard'; name=$dashboard.Name; action='planned' }) }
    } else {
        foreach ($required in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName, $PublisherPrefix)) { if ([string]::IsNullOrWhiteSpace($required)) { throw 'Reporting apply requires explicit environment, token, solution, and publisher prefix.' } }
        Initialize-WizardArtifactManifest -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix | Out-Null
        $invoke = { param($method,$path,$body=$null) Invoke-WizardDataverseRequest -Method $method -Path $path -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body $body -RequestInvoker $RequestInvoker }
        $safeSolution = ConvertTo-WizardODataLiteral $SolutionUniqueName
        $solutions = @((& $invoke Get "solutions?`$select=solutionid&`$filter=uniquename eq '$safeSolution'").value)
        if ($solutions.Count -ne 1) { throw "Expected exactly one selected solution '$SolutionUniqueName'; found $($solutions.Count)." }
        $solutionId = "$($solutions[0].solutionid)"
        $chartIds = @{}
        foreach ($chart in @($payload.Charts)) {
            $safeName = ConvertTo-WizardODataLiteral $chart.Name
            $matches = @((& $invoke Get "savedqueryvisualizations?`$select=savedqueryvisualizationid,name,primaryentitytypecode,description,datadescription,presentationdescription&`$filter=name eq '$safeName'").value)
            if ($matches.Count -gt 1) { throw "Chart identity collision for '$($chart.Name)': found $($matches.Count)." }
            if ($matches.Count -eq 1 -and ($matches[0].primaryentitytypecode -cne $chart.TableLogicalName -or $matches[0].description -cne $marker)) { throw "Chart '$($chart.Name)' is not owned by scenario '$ScenarioSlug'." }
            $dataXml = New-WizardNativeChartDataDescription -Chart $chart
            $presentationXml = New-WizardNativeChartPresentationDescription -Chart $chart
            $body = @{ name=$chart.Name; primaryentitytypecode=$chart.TableLogicalName; description=$marker; datadescription=$dataXml; presentationdescription=$presentationXml }
            if ($matches.Count -eq 0) {
                & $invoke Post 'savedqueryvisualizations' $body | Out-Null
                $created = @((& $invoke Get "savedqueryvisualizations?`$select=savedqueryvisualizationid,name,primaryentitytypecode,description&`$filter=name eq '$safeName'").value)
                if ($created.Count -ne 1 -or $created[0].description -cne $marker -or $created[0].primaryentitytypecode -cne $chart.TableLogicalName) { throw "Chart '$($chart.Name)' did not resolve exactly once after create." }
                $id = "$($created[0].savedqueryvisualizationid)"
                $action = 'created'
            } else {
                $id = "$($matches[0].savedqueryvisualizationid)"
                if ("$($matches[0].datadescription)" -ceq $dataXml -and "$($matches[0].presentationdescription)" -ceq $presentationXml) {
                    $action = 'skipped'
                } else {
                    & $invoke Patch "savedqueryvisualizations($id)" $body | Out-Null
                    $action = 'updated'
                }
            }
            & $invoke Post 'AddSolutionComponent' @{ ComponentId=$id; ComponentType=59; SolutionUniqueName=$SolutionUniqueName; AddRequiredComponents=$false } | Out-Null
            $explicitMembership = @((& $invoke Get "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $solutionId and objectid eq $id and componenttype eq 59").value)
            $membershipMode = 'explicit'
            if ($explicitMembership.Count -eq 0) {
                $entity = & $invoke Get "EntityDefinitions(LogicalName='$($chart.TableLogicalName)')?`$select=MetadataId"
                $entityMembership = @((& $invoke Get "solutioncomponents?`$select=solutioncomponentid,rootcomponentbehavior&`$filter=_solutionid_value eq $solutionId and objectid eq $($entity.MetadataId) and componenttype eq 1").value)
                if ($entityMembership.Count -ne 1 -or [int]$entityMembership[0].rootcomponentbehavior -ne 0) {
                    throw "Chart '$($chart.Name)' is neither an explicit solution component nor inherited through an include-all table root."
                }
                $membershipMode = 'inherited-from-table'
            } elseif ($explicitMembership.Count -ne 1) {
                throw "Chart '$($chart.Name)' has ambiguous explicit solution membership."
            }
            $chartIds[$chart.Name] = $id
            $evidenceItems.Add([pscustomobject]@{ kind='chart'; name=$chart.Name; table=$chart.TableLogicalName; id=$id; action=$action; solutionMembership=$membershipMode })
            Add-WizardArtifactManifestItem -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'chart' -Name "$($chart.TableLogicalName)|$($chart.Name)" -Status $action -Step '64-build-charts-dashboard.ps1' -Details @{ id=$id; table=$chart.TableLogicalName; solutionMembership=$membershipMode } | Out-Null
        }
        $viewIds = @{}
        foreach ($tableLogicalName in @($payload.Charts.TableLogicalName | Sort-Object -Unique)) {
            $safeTable = ConvertTo-WizardODataLiteral $tableLogicalName
            $views = @((& $invoke Get "savedqueries?`$select=savedqueryid,name,description,returnedtypecode,querytype&`$filter=returnedtypecode eq '$safeTable' and querytype eq 0").value | Where-Object {
                "$($_.description)" -like "Generated by 60-build-forms-views.ps1*scenario=$ScenarioSlug*"
            })
            if ($views.Count -ne 1) { throw "Expected exactly one wizard-owned public view for dashboard table '$tableLogicalName'; found $($views.Count)." }
            $viewIds[$tableLogicalName] = "$($views[0].savedqueryid)"
        }
        foreach ($dashboard in $dashboards) {
            $dashboardName = "$($dashboard.Name)"
            $safeDashboardName = ConvertTo-WizardODataLiteral $dashboardName
            $dashboardMatches = @((& $invoke Get "systemforms?`$select=formid,name,type,description,formxml&`$filter=name eq '$safeDashboardName' and type eq 0").value)
            if ($dashboardMatches.Count -gt 1) { throw "Dashboard identity collision for '$dashboardName': found $($dashboardMatches.Count)." }
            if ($dashboardMatches.Count -eq 1 -and $dashboardMatches[0].description -cne $marker) { throw "Dashboard '$dashboardName' is not owned by scenario '$ScenarioSlug'." }
            $tabId = ConvertTo-WizardStableGuid "$ScenarioSlug|$dashboardName|tab"
            $sectionId = ConvertTo-WizardStableGuid "$ScenarioSlug|$dashboardName|section"
            $rows = @($dashboard.ChartNames | ForEach-Object {
                $chartName = "$_"
                $chartDefinition = @($payload.Charts | Where-Object Name -ceq $chartName)
                if ($chartDefinition.Count -ne 1) { throw "Dashboard '$dashboardName' cannot resolve chart definition '$chartName'." }
                $tableLogicalName = "$($chartDefinition[0].TableLogicalName)"
                $viewId = "$($viewIds[$tableLogicalName])"
                $cellId = ConvertTo-WizardStableGuid "$ScenarioSlug|$dashboardName|$chartName|cell"
                $controlGuid = ConvertTo-WizardStableGuid "$ScenarioSlug|$dashboardName|$chartName|control"
                $controlId = "Component$($controlGuid.ToString('N').Substring(0, 8))"
                $label = ConvertTo-WizardXmlValue $chartName
                $table = ConvertTo-WizardXmlValue $tableLogicalName
                $cell = "<row><cell colspan='4' rowspan='9' showlabel='true' id='{$cellId}' auto='false'><labels><label description='$label' languagecode='1033'/></labels><control id='$controlId' uniqueid='{$controlGuid}' classid='{E7A81278-8635-4d9e-8D4D-59480B391C5B}' indicationOfSubgrid='true'><parameters><TargetEntityType>$table</TargetEntityType><ChartGridMode>Chart</ChartGridMode><EnableQuickFind>true</EnableQuickFind><EnableViewPicker>true</EnableViewPicker><EnableJumpBar>true</EnableJumpBar><RecordsPerPage>5</RecordsPerPage><HeaderColorCode>#F3F3F3</HeaderColorCode><ViewId>{$viewId}</ViewId><IsUserView>false</IsUserView><ViewIds/><AutoExpand>Fixed</AutoExpand><VisualizationId>{$($chartIds[$chartName])}</VisualizationId><IsUserChart>false</IsUserChart><EnableChartPicker>false</EnableChartPicker><RelationshipName/></parameters></control></cell></row>"
                $cell + (('<row/>' * 8) -join '')
            }) -join ''
            $formXml = "<form><tabs><tab showlabel='false' verticallayout='true' id='{$tabId}'><labels><label description='Dashboard' languagecode='1033'/></labels><columns><column width='100%'><sections><section showlabel='false' showbar='false' columns='1111' id='{$sectionId}'><labels><label description='Charts' languagecode='1033'/></labels><rows>$rows</rows></section></sections></column></columns></tab></tabs><controlDescriptions/></form>"
            $dashboardBody = @{ name=$dashboardName; type=0; formactivationstate=1; description=$marker; formxml=$formXml }
            if ($dashboardMatches.Count -eq 0) {
                & $invoke Post 'systemforms' $dashboardBody | Out-Null
                $createdDashboard=@((& $invoke Get "systemforms?`$select=formid,name,type,description,formxml&`$filter=name eq '$safeDashboardName' and type eq 0").value)
                if($createdDashboard.Count-ne 1-or $createdDashboard[0].description-cne $marker){throw "Dashboard '$dashboardName' did not resolve exactly once after create."}
                $dashboardId="$($createdDashboard[0].formid)"
                $dashboardAction='created'
            } else {
                $dashboardId="$($dashboardMatches[0].formid)"
                $currentControlSignatures = @(Get-WizardDashboardControlSignatures -FormXml "$($dashboardMatches[0].formxml)")
                $desiredControlSignatures = @(Get-WizardDashboardControlSignatures -FormXml $formXml)
                if (($currentControlSignatures -join ',') -cne ($desiredControlSignatures -join ',')) {
                    & $invoke Delete "systemforms($dashboardId)" | Out-Null
                    & $invoke Post 'systemforms' $dashboardBody | Out-Null
                    $recreatedDashboard = @((& $invoke Get "systemforms?`$select=formid,name,type,description,formxml&`$filter=name eq '$safeDashboardName' and type eq 0").value)
                    if ($recreatedDashboard.Count -ne 1 -or $recreatedDashboard[0].description -cne $marker) {
                        throw "Dashboard '$dashboardName' did not resolve exactly once after replacement."
                    }
                    $dashboardId = "$($recreatedDashboard[0].formid)"
                    $recreatedControlSignatures = @(Get-WizardDashboardControlSignatures -FormXml "$($recreatedDashboard[0].formxml)")
                    if (($recreatedControlSignatures -join ',') -cne ($desiredControlSignatures -join ',')) {
                        throw "Dashboard '$dashboardName' did not retain its native chart controls after replacement."
                    }
                    $dashboardAction='recreated'
                } else {
                    $dashboardAction='skipped'
                }
            }
            if ([string]::IsNullOrWhiteSpace($dashboardId)) { throw "Dashboard '$dashboardName' has no ID." }
            & $invoke Post 'AddSolutionComponent' @{ ComponentId=$dashboardId; ComponentType=60; SolutionUniqueName=$SolutionUniqueName; AddRequiredComponents=$false } | Out-Null
            $dashboardMembership = @((& $invoke Get "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $solutionId and objectid eq $dashboardId and componenttype eq 60").value)
            if ($dashboardMembership.Count -ne 1) { throw "Dashboard '$dashboardName' does not have exact solution membership." }
            $evidenceItems.Add([pscustomobject]@{ kind='dashboard'; name=$dashboardName; id=$dashboardId; action=$dashboardAction; solutionMembership='explicit' })
            Add-WizardArtifactManifestItem -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'dashboard' -Name $dashboardName -Status $dashboardAction -Step '64-build-charts-dashboard.ps1' -Details @{ id=$dashboardId; chartNames=@($dashboard.ChartNames) } | Out-Null
        }
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
    Invoke-WizardReportingStage -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -SolutionUniqueName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -PreviewOnly:$PreviewOnly -RequestInvoker $RequestInvoker -AcknowledgeWriteFreeze:$AcknowledgeWriteFreeze -ChoiceMaxRows $ChoiceMaxRows | Out-Null
}