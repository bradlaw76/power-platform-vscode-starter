<#
=============================================================================
COMPONENT:    Dataverse Report Wizard
FILE:         scripts/bootstrap/08-report-wizard.ps1
VERSION:      0.1.0
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

Creates a validated reporting payload, FetchXML preview, and report mapping.
Use -Deploy only after reviewing the generated artifacts.
=============================================================================
#>

[CmdletBinding()]
param(
    [string]$ScenarioSlug = '',
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
    [string]$MetadataSnapshotPath = '',
    [string]$ConfigurationPath = '',
    [switch]$Force,
    [switch]$Deploy,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')
. (Join-Path $PSScriptRoot 'helpers/reporting-wizard.ps1')

$isOffline = -not [string]::IsNullOrWhiteSpace($MetadataSnapshotPath)
if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    $ScenarioSlug = Read-WizardReportValue -Prompt 'Scenario slug (lowercase letters, numbers, and hyphens)'
}
if ($ScenarioSlug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
    throw "Scenario slug '$ScenarioSlug' must contain lowercase letters, numbers, and single hyphens."
}
if (-not $isOffline -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    $EnvironmentUrl = Read-WizardReportValue -Prompt 'Dataverse environment URL (for example, https://your-org.crm.dynamics.com)'
}
if (-not $isOffline -and [string]::IsNullOrWhiteSpace($AccessToken) -and $null -eq $RequestInvoker) {
    $connection = Connect-WizardReportEnvironment -EnvironmentUrl $EnvironmentUrl
    $EnvironmentUrl = $connection.EnvironmentUrl
    $AccessToken = $connection.AccessToken
}

$snapshot = if ([string]::IsNullOrWhiteSpace($MetadataSnapshotPath)) {
    $null
} else {
    Import-WizardReportMetadataSnapshot -Path $MetadataSnapshotPath
}

$apps = @(Get-WizardReportApps -MetadataSnapshot $snapshot -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker)
$tables = @(Get-WizardReportTables -MetadataSnapshot $snapshot -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker)
$attributeCache = @{}
$attributeResolver = {
    param($tableLogicalName)
    if (-not $attributeCache.ContainsKey($tableLogicalName)) {
        $attributeCache[$tableLogicalName] = @(Get-WizardReportAttributes -TableLogicalName $tableLogicalName -MetadataSnapshot $snapshot -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker)
    }
    return @($attributeCache[$tableLogicalName])
}

if (-not [string]::IsNullOrWhiteSpace($ConfigurationPath)) {
    if (-not (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf)) {
        throw "Report wizard configuration not found: $ConfigurationPath"
    }
    $configuration = Get-Content -LiteralPath $ConfigurationPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 50
    $definition = [pscustomobject]@{
        ReportRequest = "$(Get-WizardObjectValue -InputObject $configuration -Names @('ReportRequest') -Default 'Configured report request')"
        TargetAppUniqueName = "$($configuration.TargetAppUniqueName)"
        OutputTargets = @($configuration.OutputTargets)
        Charts = @($configuration.Charts)
        DashboardName = "$($configuration.DashboardName)"
    }
} else {
    $reportRequest = Read-WizardReportValue -Prompt 'What do you want to see in the report? Describe the audience, decision, measures, groupings, and filters'
    $recommendation = Get-WizardReportRecommendation -Request $reportRequest -Apps $apps -Tables $tables -AttributeResolver $attributeResolver
    $recommendationReady = $null -ne $recommendation.App -and $null -ne $recommendation.Table -and $null -ne $recommendation.Category -and $null -ne $recommendation.Measure
    if ($recommendationReady) {
        Write-Host ''
        Write-Host 'Suggested report design' -ForegroundColor Cyan
        Write-Host "  App:         $($recommendation.App.Name) [$($recommendation.App.UniqueName)]"
        Write-Host "  Table:       $($recommendation.Table.DisplayName) [$($recommendation.Table.LogicalName)]"
        Write-Host "  Group by:    $($recommendation.Category.DisplayName) [$($recommendation.Category.LogicalName)]"
        Write-Host "  Calculation: $($recommendation.Aggregate) of $($recommendation.Measure.DisplayName) [$($recommendation.Measure.LogicalName)]"
        Write-Host "  Chart:       $($recommendation.ChartType)"
        $suggestedFilters = @($recommendation.Filters | ForEach-Object { "$($_.Field) $($_.Operator) $($_.Value)" })
        Write-Host "  Filters:     $(if ($suggestedFilters.Count -gt 0) { $suggestedFilters -join '; ' } else { 'none' })"
    }
    $useRecommendation = $recommendationReady -and (Read-WizardReportValue -Prompt 'Use this suggested design? (yes/no)' -Default 'yes') -match '^(?i)y(?:es)?$'
    $selectedApp = if ($useRecommendation) {
        $recommendation.App
    } else {
        Select-WizardReportItem -Prompt 'Select the target model-driven app' -Items $apps -LabelSelector { param($item) "$($item.Name) [$($item.UniqueName)]" }
    }
    $charts = [Collections.Generic.List[object]]::new()
    do {
        $selectedTable = if ($useRecommendation -and $charts.Count -eq 0) {
            $recommendation.Table
        } else {
            Select-WizardReportItem -Prompt 'Select a reporting table' -Items $tables -LabelSelector { param($item) "$($item.DisplayName) [$($item.LogicalName)]" }
        }
        $attributes = @(& $attributeResolver $selectedTable.LogicalName)
        $category = if ($useRecommendation -and $charts.Count -eq 0) {
            $recommendation.Category
        } else {
            Select-WizardReportItem -Prompt 'Select the category/grouping column' -Items $attributes -LabelSelector { param($item) "$($item.DisplayName) [$($item.LogicalName): $($item.AttributeType)]" }
        }
        $aggregateName = if ($useRecommendation -and $charts.Count -eq 0) {
            $recommendation.Aggregate
        } else {
            Select-WizardReportItem -Prompt 'Select the calculation' -Items @('count', 'countcolumn', 'sum', 'avg', 'min', 'max') -LabelSelector { param($item) $item }
        }
        $measureChoices = if ($aggregateName -in @('sum', 'avg', 'min', 'max')) {
            @($attributes | Where-Object AttributeType -in @('BigInt', 'Decimal', 'Double', 'Integer', 'Money'))
        } else {
            $attributes
        }
        $measure = if ($useRecommendation -and $charts.Count -eq 0 -and $measureChoices.LogicalName -contains $recommendation.Measure.LogicalName) {
            $recommendation.Measure
        } else {
            Select-WizardReportItem -Prompt 'Select the measure column' -Items $measureChoices -LabelSelector { param($item) "$($item.DisplayName) [$($item.LogicalName): $($item.AttributeType)]" }
        }
        $chartType = if ($useRecommendation -and $charts.Count -eq 0) {
            $recommendation.ChartType
        } else {
            Select-WizardReportItem -Prompt 'Select the chart type' -Items @('column', 'bar', 'pie', 'doughnut') -LabelSelector { param($item) $item }
        }
        $chartName = Read-WizardReportValue -Prompt 'Chart name' -Default "$($selectedTable.DisplayName) by $($category.DisplayName)"

        $filters = [Collections.Generic.List[object]]::new()
        if ($useRecommendation -and $charts.Count -eq 0) {
            foreach ($suggestedFilter in @($recommendation.Filters)) {
                $filters.Add($suggestedFilter)
            }
        }
        while ((Read-WizardReportValue -Prompt 'Add a filter? (yes/no)' -Default 'no') -match '^(?i)y(?:es)?$') {
            $filterField = Select-WizardReportItem -Prompt 'Select the filter column' -Items $attributes -LabelSelector { param($item) "$($item.DisplayName) [$($item.LogicalName)]" }
            $operator = Select-WizardReportItem -Prompt 'Select the filter operator' -Items @('eq', 'ne', 'gt', 'ge', 'lt', 'le', 'null', 'not-null') -LabelSelector { param($item) $item }
            $value = if ($operator -in @('null', 'not-null')) { '' } else { Read-WizardReportValue -Prompt 'Filter value' }
            $filters.Add([pscustomobject]@{ Field = $filterField.LogicalName; Operator = $operator; Value = $value })
        }

        $charts.Add([pscustomobject]@{
            Name = $chartName
            TableLogicalName = $selectedTable.LogicalName
            CategoryField = $category.LogicalName
            AggregateField = $measure.LogicalName
            Aggregate = $aggregateName
            ChartType = $chartType
            Filters = @($filters)
        })
        $addAnother = $charts.Count -lt 3 -and (Read-WizardReportValue -Prompt 'Add another chart? (yes/no)' -Default 'no') -match '^(?i)y(?:es)?$'
    } while ($addAnother)

    $definition = [pscustomobject]@{
        ReportRequest = $reportRequest
        TargetAppUniqueName = $selectedApp.UniqueName
        OutputTargets = @('fetchxml-preview', 'native-chart-dashboard')
        Charts = @($charts)
        DashboardName = Read-WizardReportValue -Prompt 'Dashboard name' -Default "$($selectedApp.Name) Reporting Dashboard"
    }
}

if (@($definition.Charts).Count -lt 1 -or @($definition.Charts).Count -gt 3) {
    throw 'The report wizard requires between one and three charts.'
}
if (@($apps | Where-Object UniqueName -ceq $definition.TargetAppUniqueName).Count -ne 1) {
    throw "Target app '$($definition.TargetAppUniqueName)' was not found in metadata."
}
if (@($definition.OutputTargets).Count -eq 0) {
    $definition.OutputTargets = @('fetchxml-preview')
}

$validationErrors = [Collections.Generic.List[string]]::new()
foreach ($chart in @($definition.Charts)) {
    foreach ($errorMessage in @(Test-WizardReportChart -Chart $chart -Tables $tables -AttributeResolver $attributeResolver)) {
        $validationErrors.Add($errorMessage)
    }
}
if ($validationErrors.Count -gt 0) {
    throw "Report definition validation failed:`n - $($validationErrors -join "`n - ")"
}

$paths = Write-WizardReportArtifacts -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -Definition $definition -Force:$Force
Write-Host ''
Write-Host 'Dataverse report wizard completed.' -ForegroundColor Green
Write-Host "  Payload:  $($paths.PayloadPath)"
Write-Host "  Preview:  $($paths.PreviewPath)"
Write-Host "  Mapping:  $($paths.MappingPath)"

if ($Deploy) {
    if (@($definition.OutputTargets) -notcontains 'native-chart-dashboard') {
        throw "Deployment was requested, but 'native-chart-dashboard' is not an output target."
    }
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
        $SolutionUniqueName = Read-WizardReportValue -Prompt 'Existing solution unique name for these reports'
    }
    if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) {
        $PublisherPrefix = Read-WizardReportValue -Prompt 'Existing publisher prefix for the solution'
    }
    foreach ($required in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName, $PublisherPrefix)) {
        if ([string]::IsNullOrWhiteSpace($required)) {
            throw 'Deployment requires environment URL, access token, solution unique name, and publisher prefix.'
        }
    }
    & (Join-Path $PSScriptRoot '64-build-charts-dashboard.ps1') -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -SolutionUniqueName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -ScenarioSlug $ScenarioSlug -PayloadsFolder $paths.PayloadFolder -RequestInvoker $RequestInvoker
    $payload = Get-Content -LiteralPath $paths.PayloadPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
    $appWiring = Add-WizardReportsToApp -Payload $payload -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker
    Write-Host "  App:      $($appWiring.AppUniqueName) ($($appWiring.ComponentCount) report components attached)"
}
