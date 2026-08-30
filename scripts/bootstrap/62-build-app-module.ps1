<#
=============================================================================
COMPONENT:    Build App Module
FILE:         scripts/bootstrap/62-build-app-module.ps1
VERSION:      0.3.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API | Model-Driven App Metadata

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Creates or updates the scenario app module and attaches the intended solution
components for the model-driven application shell.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          app module settings, scenario mapping, and solution context
- Outputs:         app module metadata and summary artifacts
- Dependencies:    Dataverse Web API, helper validation logic, planning files
- Side Effects:    mutates app module metadata and writes summary artifacts

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. App module wiring must be enabled for the scenario.
2. Required forms, views, and tables must already be available.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ App module wiring completes successfully for enabled scenarios.
✔ Reruns remain idempotent and do not increase unique component attachments.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.
v0.2.0  2026-08-10  Added profile-aware sitemap and landing-view validation.
v0.3.0  2026-08-30  Replaced broad publishing with app-module-scoped PublishXml.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Skip safely when app module wiring is not enabled.
- Preserve idempotent component attachment behavior on rerun.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Creates or updates a scenario-aware model-driven app module and attaches
    intended forms, views, and BPFs when configured.

.DESCRIPTION
    Uses the AppModule table plus AddAppComponents and ValidateApp.
    Safe to rerun: existing apps are updated in place and component adds are
    idempotent.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
    [string]$ScenarioSlug = '',
    [string]$PayloadsFolder = '',
    [bool]$EnableAppModuleWiring = $true,
    [bool]$EnableArtifactManifest = $true,
    [bool]$StrictMode = $true,
    [bool]$PreviewOnly = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot 'helpers\wizard-telemetry.ps1'
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName '62-build-app-module.ps1'
}

$hardeningHelper = Join-Path $PSScriptRoot 'helpers\wizard-hardening.ps1'
if (-not (Test-Path $hardeningHelper)) {
    Write-Host "Missing helper script: $hardeningHelper" -ForegroundColor Red
    exit 1
}

. $hardeningHelper

$dataverseRuntimeHelper = Join-Path $PSScriptRoot 'helpers\dataverse-runtime.ps1'
if (-not (Test-Path $dataverseRuntimeHelper)) {
    Write-Host "Missing helper script: $dataverseRuntimeHelper" -ForegroundColor Red
    exit 1
}
. $dataverseRuntimeHelper

$envFile = Join-Path $repoRoot '.env.ps1'
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    $AccessToken = $global:DV_TOKEN
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { $SolutionUniqueName = $global:DV_SOLUTION_NAME }
    if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) { $PublisherPrefix = $global:DV_PUBLISHER_PREFIX }
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = ''
    )

    $headers = @{
        Authorization = "Bearer $AccessToken"
        'Content-Type' = 'application/json'
        'OData-Version' = '4.0'
        'OData-MaxVersion' = '4.0'
        Accept = 'application/json'
    }

    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ([string]::IsNullOrWhiteSpace($Body)) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }

    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body
}

function Get-AppModule {
    param(
        [string]$UniqueName,
        [string]$DisplayName
    )

    $safe = $UniqueName.Replace("'", "''")
    $safeDisplayName = $DisplayName.Replace("'", "''")
    return @((Invoke-Dv -Method 'Get' -Path "appmodules?`$select=appmoduleid,name,uniquename,description&`$filter=uniquename eq '$safe' or name eq '$safeDisplayName'").value)
}

function Test-ComponentInTargetSolution {
    param(
        [string]$ObjectId,
        [string]$ComponentTypeLabel
    )

    $safeSolutionName = $SolutionUniqueName.Replace("'", "''")
    $solutions = @((Invoke-Dv -Method 'Get' -Path "solutions?`$select=solutionid&`$filter=uniquename eq '$safeSolutionName'").value)
    if ($solutions.Count -ne 1) { throw "Expected exactly one target solution '$SolutionUniqueName'; found $($solutions.Count)." }
    $componentType = Get-SolutionComponentTypeValue -Label $ComponentTypeLabel
    if ($null -eq $componentType) { throw "Dataverse component type '$ComponentTypeLabel' could not be resolved." }
    $solutionId = $solutions[0].solutionid
    $members = @((Invoke-Dv -Method 'Get' -Path "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $solutionId and objectid eq $ObjectId and componenttype eq $componentType").value)
    return $members.Count -eq 1
}

function Get-SolutionComponentTypeValue {
    param([string]$Label)

    $meta = Invoke-Dv -Method 'Get' -Path "EntityDefinitions(LogicalName='solutioncomponent')/Attributes(LogicalName='componenttype')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName&`$expand=OptionSet"
    foreach ($opt in @($meta.OptionSet.Options)) {
        if ($opt.Label.UserLocalizedLabel.Label -eq $Label) {
            return [int]$opt.Value
        }
    }

    return $null
}

function Add-AppToSolution {
    param([string]$AppModuleId)

    $componentType = Get-SolutionComponentTypeValue -Label 'App Module'
    if ($null -eq $componentType) {
        return 'skipped'
    }

    $body = @{ ComponentId = $AppModuleId; ComponentType = $componentType; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $true } | ConvertTo-Json -Compress
    try {
        Invoke-Dv -Method 'Post' -Path 'AddSolutionComponent' -Body $body | Out-Null
        return 'added'
    } catch {
        if ($_.Exception.Message -like '*already*' -or $_.Exception.Message -like '*duplicate*') {
            return 'skipped'
        }
        throw
    }
}

function Get-EntityDefinition {
    param([string]$LogicalName)
    return Invoke-Dv -Method 'Get' -Path "EntityDefinitions(LogicalName='$LogicalName')?`$select=LogicalName,MetadataId"
}

function Get-MainFormComponent {
    param([string]$LogicalName)
    return @((Invoke-Dv -Method 'Get' -Path "systemforms?`$select=formid,name,objecttypecode,type&`$filter=objecttypecode eq '$LogicalName' and type eq 2").value | Select-Object -First 1)
}

function Get-ViewComponent {
    param(
        [string]$LogicalName,
        [string]$ViewName
    )

    $safeLogicalName = $LogicalName.Replace("'", "''")
    $safeViewName = $ViewName.Replace("'", "''")
    return @((Invoke-Dv -Method 'Get' -Path "savedqueries?`$select=savedqueryid,name,returnedtypecode&`$filter=returnedtypecode eq '$safeLogicalName' and querytype eq 0 and name eq '$safeViewName'").value | Select-Object -First 1)
}

function Get-BpfComponent {
    param([string]$Name)

    $safe = $Name.Replace("'", "''")
    return @((Invoke-Dv -Method 'Get' -Path "workflows?`$select=workflowid,name,uniquename,category&`$filter=(name eq '$safe' or uniquename eq '$safe') and category eq 4").value | Select-Object -First 1)
}

function New-AppComponentRef {
    param(
        [string]$ODataType,
        [string]$IdProperty,
        [string]$IdValue
    )

    return [ordered]@{
        '@odata.type' = $ODataType
        $IdProperty = $IdValue
    }
}

function Add-AppComponents {
    param(
        [string]$AppId,
        [object[]]$Components
    )

    if (@($Components).Count -eq 0) {
        return
    }

    $body = @{ AppId = $AppId; Components = @($Components) } | ConvertTo-Json -Depth 10 -Compress
    Invoke-Dv -Method 'Post' -Path 'AddAppComponents' -Body $body | Out-Null
}

function ConvertTo-SiteMapIdPart {
    param([string]$Value)

    $safe = [regex]::Replace($Value.ToLowerInvariant(), '[^a-z0-9_]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'item' }
    return $safe
}

function ConvertTo-XmlAttributeValue {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

function New-AppSiteMapXml {
    param(
        [string]$AppName,
        [string]$NavigationGroup,
        [string[]]$Tables
    )

    $areaId = "area_$(ConvertTo-SiteMapIdPart -Value $AppName)"
    $groupId = "group_$(ConvertTo-SiteMapIdPart -Value $NavigationGroup)"
    $subAreas = foreach ($table in $Tables) {
        $safeTable = ConvertTo-XmlAttributeValue -Value $table
        "      <SubArea Id=`"subarea_$(ConvertTo-SiteMapIdPart -Value $table)`" Entity=`"$safeTable`" />"
    }

    return @"
<SiteMap>
  <Area Id="$areaId" Title="$(ConvertTo-XmlAttributeValue -Value $AppName)" ShowGroups="true">
    <Group Id="$groupId" Title="$(ConvertTo-XmlAttributeValue -Value $NavigationGroup)">
$($subAreas -join [Environment]::NewLine)
    </Group>
  </Area>
</SiteMap>
"@
}

function Get-AppSiteMap {
    param(
        [string]$UniqueName,
        [string]$DisplayName
    )

    $safe = $UniqueName.Replace("'", "''")
    $safeDisplayName = $DisplayName.Replace("'", "''")
    return @((Invoke-Dv -Method 'Get' -Path "sitemaps?`$select=sitemapid,sitemapname,sitemapnameunique,sitemapxml&`$filter=sitemapnameunique eq '$safe' or sitemapname eq '$safeDisplayName'").value)
}

function Set-AppSiteMap {
    param(
        [string]$UniqueName,
        [string]$DisplayName,
        [string]$SiteMapXml
    )

    $existingSiteMaps = @(Get-AppSiteMap -UniqueName $UniqueName -DisplayName $DisplayName)
    $body = @{
        sitemapname = $DisplayName
        sitemapnameunique = $UniqueName
        sitemapxml = $SiteMapXml
        isappaware = $true
        showhome = $true
        showpinned = $true
        showrecents = $true
    } | ConvertTo-Json -Compress

    if ((Get-WizardUpsertAction -ExistingItems $existingSiteMaps) -eq 'update') {
        if ($existingSiteMaps[0].sitemapnameunique -cne $UniqueName -or $existingSiteMaps[0].sitemapname -cne $DisplayName) {
            throw "Cannot update site map '$DisplayName': same-name or same-unique-name metadata does not match the scenario contract."
        }
        if (-not (Test-ComponentInTargetSolution -ObjectId $existingSiteMaps[0].sitemapid -ComponentTypeLabel 'Site Map')) {
            throw "Cannot update site map '$DisplayName': it is not uniquely owned by target solution '$SolutionUniqueName'."
        }
        Invoke-Dv -Method 'Patch' -Path "sitemaps($($existingSiteMaps[0].sitemapid))" -Body $body | Out-Null
        return [pscustomobject]@{ Id = $existingSiteMaps[0].sitemapid; Action = 'updated' }
    }

    Invoke-Dv -Method 'Post' -Path 'sitemaps' -Body $body | Out-Null
    $created = @(Get-AppSiteMap -UniqueName $UniqueName -DisplayName $DisplayName)
    if ($created.Count -eq 0) {
        throw "Site map '$UniqueName' was not found after create."
    }
    return [pscustomobject]@{ Id = $created[0].sitemapid; Action = 'created' }
}

function Get-AppReportPaths {
    $root = Join-Path $repoRoot '.wizard-metrics\artifacts\app-module'
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    return [pscustomobject]@{
        SummaryPath = Join-Path $root 'app-module-summary.json'
        NavigationPath = Join-Path $root 'navigation-summary.json'
        ValidationPath = Join-Path $root 'app-module-validation.json'
    }
}

$appConfig = Get-WizardAppModuleConfig -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder -PublisherPrefix $PublisherPrefix
$paths = Get-AppReportPaths

if ($EnableArtifactManifest -and -not $PreviewOnly) {
    Initialize-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $appConfig.ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix | Out-Null
}

if (-not $EnableAppModuleWiring -or -not $appConfig.Enabled) {
    [ordered]@{ status = 'skipped'; reason = 'app module wiring disabled'; scenarioSlug = $appConfig.ScenarioSlug } | ConvertTo-Json -Depth 10 | Set-Content -Path $paths.SummaryPath -Encoding UTF8
    if (-not $PreviewOnly -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $appConfig.ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appmodule' -Name ($appConfig.UniqueName ?? 'app-module') -Status 'skipped' -Step '62-build-app-module.ps1' -Details @{ reason = 'disabled' } | Out-Null
    }
    Write-Host 'App module wiring disabled or not requested for this scenario. Skipping.' -ForegroundColor Yellow
    exit 0
}

if (-not $appConfig.ValidationPassed) {
    [ordered]@{ status = 'failed'; errors = @($appConfig.ValidationErrors); scenarioSlug = $appConfig.ScenarioSlug } | ConvertTo-Json -Depth 10 | Set-Content -Path $paths.ValidationPath -Encoding UTF8
    if (-not $PreviewOnly -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $appConfig.ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appmodule' -Name $appConfig.UniqueName -Status 'failed' -Step '62-build-app-module.ps1' -Details @{ validationErrors = @($appConfig.ValidationErrors) } | Out-Null
    }
    Write-Host 'App module wiring contract is incomplete.' -ForegroundColor Red
    exit 1
}

$orderedTables = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($appConfig.EntryPointTable) -and $appConfig.Tables -contains $appConfig.EntryPointTable) {
    $orderedTables.Add($appConfig.EntryPointTable) | Out-Null
}
foreach ($table in @($appConfig.Tables | Sort-Object)) {
    if (-not $orderedTables.Contains($table)) {
        $orderedTables.Add($table) | Out-Null
    }
}

if ($PreviewOnly) {
    $siteMapUniqueName = "$(ConvertTo-SiteMapIdPart -Value $appConfig.UniqueName)_sitemap"
    $navigationItems = foreach ($table in @($orderedTables.ToArray())) {
        $viewIdentity = @($appConfig.Views | Where-Object { $_ -like "$table|*" } | Select-Object -First 1)
        [ordered]@{
            group = $appConfig.NavigationGroup
            type = 'table'
            name = $table
            isEntryPoint = ($table -eq $appConfig.EntryPointTable)
            view = if ($table -eq $appConfig.EntryPointTable) { $appConfig.LandingView } elseif ($viewIdentity.Count -gt 0) { $viewIdentity[0] } else { '' }
        }
    }

    [ordered]@{
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        scenarioSlug = $appConfig.ScenarioSlug
        appName = $appConfig.AppName
        appUniqueName = $appConfig.UniqueName
        action = 'preview'
        applicationProfile = $appConfig.ApplicationProfile
        entryPointTable = $appConfig.EntryPointTable
        landingView = $appConfig.LandingView
        siteMapUniqueName = $siteMapUniqueName
        siteMapAction = 'preview'
        tables = @($orderedTables.ToArray())
        forms = @($appConfig.Forms)
        views = @($appConfig.Views)
        bpfs = @($appConfig.Bpfs)
        liveResolution = 'not attempted'
        solutionMembership = 'proposed, not live-verified'
    } | ConvertTo-Json -Depth 20 | Set-Content -Path $paths.SummaryPath -Encoding UTF8

    [ordered]@{
        appUniqueName = $appConfig.UniqueName
        siteMapUniqueName = $siteMapUniqueName
        navigationGroup = $appConfig.NavigationGroup
        entryPointTable = $appConfig.EntryPointTable
        landingView = $appConfig.LandingView
        siteMapAction = 'preview'
        items = @($navigationItems)
        structuralValidation = [ordered]@{
            hasGroup = -not [string]::IsNullOrWhiteSpace($appConfig.NavigationGroup)
            hasItems = @($navigationItems).Count -gt 0
            hasEntryPoint = @($navigationItems | Where-Object { $_.isEntryPoint }).Count -eq 1
            hasLandingView = -not [string]::IsNullOrWhiteSpace($appConfig.LandingView)
            hasSiteMap = -not [string]::IsNullOrWhiteSpace($siteMapUniqueName)
        }
    } | ConvertTo-Json -Depth 20 | Set-Content -Path $paths.NavigationPath -Encoding UTF8

    [ordered]@{
        appUniqueName = $appConfig.UniqueName
        validationSuccess = $true
        validationIssues = @()
        previewOnly = $true
        liveResolution = 'not attempted'
    } | ConvertTo-Json -Depth 20 | Set-Content -Path $paths.ValidationPath -Encoding UTF8

    Write-Host ''
    Write-Host '=== Build App Module ===' -ForegroundColor Cyan
    Write-Host "  App:        $($appConfig.AppName) [$($appConfig.UniqueName)]"
    Write-Host '  Action:     preview (local contract only)'
    Write-Host '  Live reads: none'
    Write-Host "  Summary:    $($paths.SummaryPath)"
    Write-Host "  Navigation: $($paths.NavigationPath)"
    Write-Host "  Validation: $($paths.ValidationPath)"

    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message 'App module local preview completed.'
    }
    exit 0
}

foreach ($value in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName, $appConfig.UniqueName, $appConfig.AppName)) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Host 'Missing required values for app module wiring.' -ForegroundColor Red
        exit 1
    }
}

$existing = @(Get-AppModule -UniqueName $appConfig.UniqueName -DisplayName $appConfig.AppName)
$upsertAction = Get-WizardUpsertAction -ExistingItems $existing
$action = if ($upsertAction -eq 'update') { 'updated' } else { 'created' }
$appModuleId = ''
if ($upsertAction -eq 'update') {
    $appModuleId = $existing[0].appmoduleid
    $expectedDescription = "Wizard-managed app for scenario '$($appConfig.ScenarioSlug)'."
    if ($existing[0].uniquename -cne $appConfig.UniqueName -or $existing[0].name -cne $appConfig.AppName -or $existing[0].description -cne $expectedDescription) {
        throw "Cannot update app '$($appConfig.AppName)': same-name or same-unique-name metadata does not match the scenario contract."
    }
    if (-not (Test-ComponentInTargetSolution -ObjectId $appModuleId -ComponentTypeLabel 'App Module')) {
        throw "Cannot update app '$($appConfig.AppName)': it is not uniquely owned by target solution '$SolutionUniqueName'."
    }
    if (-not $PreviewOnly) {
        $patchBody = @{ name = $appConfig.AppName; description = "Wizard-managed app for scenario '$($appConfig.ScenarioSlug)'." } | ConvertTo-Json -Compress
        Invoke-Dv -Method 'Patch' -Path "appmodules($appModuleId)" -Body $patchBody | Out-Null
    }
} else {
    if (-not $PreviewOnly) {
        $createBody = @{ name = $appConfig.AppName; uniquename = $appConfig.UniqueName; webresourceid = '953b9fac-1e5e-e611-80d6-00155ded156f'; description = "Wizard-managed app for scenario '$($appConfig.ScenarioSlug)'." } | ConvertTo-Json -Compress
        $createResult = Invoke-Dv -Method 'Post' -Path 'appmodules' -Body $createBody
        $appModuleId = ($createResult.appmoduleid ?? '')
    }

    if ([string]::IsNullOrWhiteSpace($appModuleId)) {
        $created = @(Get-AppModule -UniqueName $appConfig.UniqueName -DisplayName $appConfig.AppName)
        if ($created.Count -gt 0) {
            $appModuleId = $created[0].appmoduleid
        }
    }
}

$componentRefs = New-Object System.Collections.Generic.List[object]
$navigationItems = New-Object System.Collections.Generic.List[object]
$localValidationIssues = New-Object System.Collections.Generic.List[string]
foreach ($table in @($orderedTables.ToArray())) {
    try {
        $entity = Get-EntityDefinition -LogicalName $table
        if ($null -ne $entity -and -not [string]::IsNullOrWhiteSpace($entity.MetadataId)) {
            $componentRefs.Add((New-AppComponentRef -ODataType 'Microsoft.Dynamics.CRM.EntityMetadata' -IdProperty 'MetadataId' -IdValue $entity.MetadataId)) | Out-Null
            $navigationItems.Add([pscustomobject]@{ group = $appConfig.NavigationGroup; type = 'table'; name = $table; isEntryPoint = ($table -eq $appConfig.EntryPointTable) }) | Out-Null
        }
    } catch {
        $localValidationIssues.Add("Table '$table' could not be resolved: $($_.Exception.Message)") | Out-Null
    }

    try {
        $form = @(Get-MainFormComponent -LogicalName $table)
        if ($form.Count -gt 0) {
            $componentRefs.Add((New-AppComponentRef -ODataType 'Microsoft.Dynamics.CRM.systemform' -IdProperty 'formid' -IdValue $form[0].formid)) | Out-Null
        }
    } catch {
        $localValidationIssues.Add("Main form for '$table' could not be resolved: $($_.Exception.Message)") | Out-Null
    }

    try {
        $requestedViewName = if ($table -eq $appConfig.EntryPointTable -and -not [string]::IsNullOrWhiteSpace($appConfig.LandingView)) { $appConfig.LandingView } else { 'Active Records' }
        $view = @(Get-ViewComponent -LogicalName $table -ViewName $requestedViewName)
        if ($view.Count -gt 0) {
            $componentRefs.Add((New-AppComponentRef -ODataType 'Microsoft.Dynamics.CRM.savedquery' -IdProperty 'savedqueryid' -IdValue $view[0].savedqueryid)) | Out-Null
            $navigationItem = @($navigationItems | Where-Object { $_.name -eq $table } | Select-Object -First 1)
            if ($navigationItem.Count -gt 0) {
                $navigationItem[0] | Add-Member -NotePropertyName view -NotePropertyValue $requestedViewName -Force
                $navigationItem[0] | Add-Member -NotePropertyName viewId -NotePropertyValue $view[0].savedqueryid -Force
            }
        } elseif ($table -eq $appConfig.EntryPointTable) {
            $localValidationIssues.Add("Landing view '$requestedViewName' was not found for entry-point table '$table'.") | Out-Null
        }
    } catch {
        $localValidationIssues.Add("View for '$table' could not be resolved: $($_.Exception.Message)") | Out-Null
    }
}

foreach ($bpfName in @($appConfig.Bpfs)) {
    try {
        $bpf = @(Get-BpfComponent -Name $bpfName)
        if ($bpf.Count -gt 0) {
            $componentRefs.Add((New-AppComponentRef -ODataType 'Microsoft.Dynamics.CRM.workflow' -IdProperty 'workflowid' -IdValue $bpf[0].workflowid)) | Out-Null
        }
    } catch {}
}

$siteMapResult = [pscustomobject]@{ Id = ''; Action = if ($PreviewOnly) { 'preview' } else { 'skipped' } }
if ($orderedTables.Count -gt 0) {
    $siteMapUniqueName = "$(ConvertTo-SiteMapIdPart -Value $appConfig.UniqueName)_sitemap"
    $siteMapXml = New-AppSiteMapXml -AppName $appConfig.AppName -NavigationGroup $appConfig.NavigationGroup -Tables @($orderedTables.ToArray())
    if (-not $PreviewOnly) {
        try {
            $siteMapResult = Set-AppSiteMap -UniqueName $siteMapUniqueName -DisplayName "$($appConfig.AppName) Site Map" -SiteMapXml $siteMapXml
            $componentRefs.Add((New-AppComponentRef -ODataType 'Microsoft.Dynamics.CRM.sitemap' -IdProperty 'sitemapid' -IdValue $siteMapResult.Id)) | Out-Null
        } catch {
            $localValidationIssues.Add("App site map could not be created or updated: $($_.Exception.Message)") | Out-Null
        }
    }
}

$solutionAddStatus = 'skipped'
if (-not $PreviewOnly -and -not [string]::IsNullOrWhiteSpace($appModuleId)) {
    Add-AppComponents -AppId $appModuleId -Components @($componentRefs.ToArray())
    $solutionAddStatus = Add-AppToSolution -AppModuleId $appModuleId
    $publishXml = New-WizardAppModulePublishXml -AppModuleId $appModuleId
    Invoke-Dv -Method 'Post' -Path 'PublishXml' -Body (@{ ParameterXml = $publishXml } | ConvertTo-Json -Compress) | Out-Null
}

$platformValidationResult = if ($PreviewOnly -or [string]::IsNullOrWhiteSpace($appModuleId)) {
    [pscustomobject]@{ ValidationSuccess = $true; ValidationIssueList = @() }
} else {
    try {
        (Invoke-Dv -Method 'Get' -Path "ValidateApp(AppModuleId=$appModuleId)").AppValidationResponse
    } catch {
        [pscustomobject]@{ ValidationSuccess = $false; ValidationIssueList = @($_.Exception.Message) }
    }
}
$allValidationIssues = @($localValidationIssues.ToArray()) + @($platformValidationResult.ValidationIssueList)
$validationResult = [pscustomobject]@{
    ValidationSuccess = ([bool]$platformValidationResult.ValidationSuccess -and $localValidationIssues.Count -eq 0)
    ValidationIssueList = @($allValidationIssues)
}

[ordered]@{
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    scenarioSlug = $appConfig.ScenarioSlug
    appName = $appConfig.AppName
    appUniqueName = $appConfig.UniqueName
    action = if ($PreviewOnly) { 'preview' } else { $action }
    appModuleId = $appModuleId
    solutionAddStatus = $solutionAddStatus
    applicationProfile = $appConfig.ApplicationProfile
    entryPointTable = $appConfig.EntryPointTable
    landingView = $appConfig.LandingView
    siteMapId = $siteMapResult.Id
    siteMapAction = $siteMapResult.Action
    tables = @($orderedTables.ToArray())
    attachedComponentCount = @($componentRefs.ToArray()).Count
} | ConvertTo-Json -Depth 20 | Set-Content -Path $paths.SummaryPath -Encoding UTF8

[ordered]@{
    appUniqueName = $appConfig.UniqueName
    navigationGroup = $appConfig.NavigationGroup
    entryPointTable = $appConfig.EntryPointTable
    landingView = $appConfig.LandingView
    siteMapId = $siteMapResult.Id
    siteMapAction = $siteMapResult.Action
    items = @($navigationItems.ToArray())
    structuralValidation = [ordered]@{
        hasGroup = -not [string]::IsNullOrWhiteSpace($appConfig.NavigationGroup)
        hasItems = $navigationItems.Count -gt 0
        hasEntryPoint = @($navigationItems | Where-Object { $_.isEntryPoint }).Count -eq 1
        hasLandingView = @($navigationItems | Where-Object { $_.isEntryPoint -and -not [string]::IsNullOrWhiteSpace($_.viewId) }).Count -eq 1
        hasSiteMap = $PreviewOnly -or -not [string]::IsNullOrWhiteSpace($siteMapResult.Id)
    }
} | ConvertTo-Json -Depth 20 | Set-Content -Path $paths.NavigationPath -Encoding UTF8

[ordered]@{
    appUniqueName = $appConfig.UniqueName
    validationSuccess = [bool]$validationResult.ValidationSuccess
    validationIssues = @($validationResult.ValidationIssueList)
    previewOnly = [bool]$PreviewOnly
} | ConvertTo-Json -Depth 20 | Set-Content -Path $paths.ValidationPath -Encoding UTF8

if (-not $PreviewOnly -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
    $manifestStatus = if (-not $validationResult.ValidationSuccess -and $StrictMode) { 'failed' } else { $action }
    Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $appConfig.ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appmodule' -Name $appConfig.UniqueName -Status $manifestStatus -Step '62-build-app-module.ps1' -Details @{ validationSuccess = [bool]$validationResult.ValidationSuccess; issueCount = @($validationResult.ValidationIssueList).Count } | Out-Null
}

Write-Host ''
Write-Host '=== Build App Module ===' -ForegroundColor Cyan
Write-Host "  App:        $($appConfig.AppName) [$($appConfig.UniqueName)]"
Write-Host "  Action:     $(if ($PreviewOnly) { 'preview' } else { $action })"
Write-Host "  Validation: $([bool]$validationResult.ValidationSuccess)"
Write-Host "  Summary:    $($paths.SummaryPath)"
Write-Host "  Navigation: $($paths.NavigationPath)"
Write-Host "  Validation: $($paths.ValidationPath)"

if (-not $validationResult.ValidationSuccess -and $StrictMode) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message 'App module wiring validation failed.'
    }
    exit 1
}

if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message 'App module wiring completed.'
}

exit 0