<#
=============================================================================
COMPONENT:    Reporting Wizard Helper
FILE:         scripts/bootstrap/helpers/reporting-wizard.ps1
VERSION:      0.1.0
ENVIRONMENT:  PowerShell 7 | Dataverse Web API
=============================================================================
#>

Set-StrictMode -Version Latest

function Get-WizardObjectValue {
    param(
        [object]$InputObject,
        [Parameter(Mandatory)] [string[]]$Names,
        [object]$Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }
    foreach ($name in $Names) {
        if ($InputObject -is [Collections.IDictionary] -and $InputObject.Contains($name) -and $null -ne $InputObject[$name]) {
            return $InputObject[$name]
        }
        $property = $InputObject.PSObject.Properties[$name]
        if ($null -ne $property -and $null -ne $property.Value) {
            return $property.Value
        }
    }
    return $Default
}

function Get-WizardMetadataLabel {
    param(
        [object]$Label,
        [string]$Fallback
    )

    if ($null -ne $Label) {
        $userLabel = Get-WizardObjectValue -InputObject $Label -Names @('UserLocalizedLabel')
        $userLabelText = Get-WizardObjectValue -InputObject $userLabel -Names @('Label') -Default ''
        if (-not [string]::IsNullOrWhiteSpace("$userLabelText")) {
            return "$userLabelText"
        }
        $localizedLabels = @(Get-WizardObjectValue -InputObject $Label -Names @('LocalizedLabels') -Default @())
        $localized = @($localizedLabels | Where-Object { -not [string]::IsNullOrWhiteSpace("$(Get-WizardObjectValue -InputObject $_ -Names @('Label') -Default '')") } | Select-Object -First 1)
        if ($localized.Count -eq 1) {
            return "$(Get-WizardObjectValue -InputObject $localized[0] -Names @('Label') -Default $Fallback)"
        }
    }
    return $Fallback
}

function Invoke-WizardDataverseCollection {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [string]$AccessToken,
        [scriptblock]$RequestInvoker
    )

    $items = [Collections.Generic.List[object]]::new()
    $nextPath = $Path
    while (-not [string]::IsNullOrWhiteSpace($nextPath)) {
        $response = Invoke-WizardDataverseRequest -Method Get -Path $nextPath -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker
        foreach ($item in @($response.value)) {
            $items.Add($item)
        }
        $nextLinkProperty = $response.PSObject.Properties['@odata.nextLink']
        $nextPath = if ($null -ne $nextLinkProperty) { "$($nextLinkProperty.Value)" } else { '' }
    }
    return @($items)
}

function Import-WizardReportMetadataSnapshot {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Report metadata snapshot not found: $Path"
    }
    $snapshot = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 50
    if ($null -eq $snapshot.Apps -or $null -eq $snapshot.Tables) {
        throw "Report metadata snapshot must contain 'Apps' and 'Tables' arrays."
    }
    return $snapshot
}

function Get-WizardReportApps {
    param(
        [object]$MetadataSnapshot,
        [string]$EnvironmentUrl,
        [string]$AccessToken,
        [scriptblock]$RequestInvoker
    )

    $apps = if ($null -ne $MetadataSnapshot) {
        @($MetadataSnapshot.Apps)
    } else {
        if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
            throw 'Live app discovery requires an environment URL and access token.'
        }
        @(Invoke-WizardDataverseCollection -Path 'appmodules?$select=appmoduleid,name,uniquename' -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker)
    }

    return @($apps | ForEach-Object {
        [pscustomobject]@{
            Id = "$(Get-WizardObjectValue -InputObject $_ -Names @('AppModuleId', 'appmoduleid') -Default '')"
            Name = "$(Get-WizardObjectValue -InputObject $_ -Names @('Name', 'name') -Default '')"
            UniqueName = "$(Get-WizardObjectValue -InputObject $_ -Names @('UniqueName', 'uniquename') -Default '')"
        }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_.UniqueName) } | Sort-Object Name, UniqueName)
}

function Get-WizardReportTables {
    param(
        [object]$MetadataSnapshot,
        [string]$EnvironmentUrl,
        [string]$AccessToken,
        [scriptblock]$RequestInvoker
    )

    $tables = if ($null -ne $MetadataSnapshot) {
        @($MetadataSnapshot.Tables)
    } else {
        if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
            throw 'Live table discovery requires an environment URL and access token.'
        }
        @(Invoke-WizardDataverseCollection -Path 'EntityDefinitions?$select=LogicalName,DisplayName,PrimaryIdAttribute,IsPrivate&$filter=IsPrivate eq false' -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker)
    }

    return @($tables | ForEach-Object {
        $logicalName = "$(Get-WizardObjectValue -InputObject $_ -Names @('LogicalName') -Default '')"
        $displayName = Get-WizardObjectValue -InputObject $_ -Names @('DisplayName')
        $displayNameText = Get-WizardObjectValue -InputObject $_ -Names @('DisplayNameText') -Default $logicalName
        [pscustomobject]@{
            LogicalName = $logicalName
            DisplayName = Get-WizardMetadataLabel -Label $displayName -Fallback $displayNameText
            PrimaryIdAttribute = "$(Get-WizardObjectValue -InputObject $_ -Names @('PrimaryIdAttribute') -Default '')"
            Attributes = @(Get-WizardObjectValue -InputObject $_ -Names @('Attributes') -Default @())
        }
    } | Where-Object { $_.LogicalName -match '^[a-z][a-z0-9_]*$' } | Sort-Object DisplayName, LogicalName)
}

function Get-WizardReportAttributes {
    param(
        [Parameter(Mandatory)] [string]$TableLogicalName,
        [object]$MetadataSnapshot,
        [string]$EnvironmentUrl,
        [string]$AccessToken,
        [scriptblock]$RequestInvoker
    )

    if ($null -ne $MetadataSnapshot) {
        $table = @($MetadataSnapshot.Tables | Where-Object { $_.LogicalName -ceq $TableLogicalName })
        if ($table.Count -ne 1) {
            throw "Table '$TableLogicalName' did not resolve exactly once in the metadata snapshot."
        }
        $attributes = @($table[0].Attributes)
    } else {
        $safeTable = ConvertTo-WizardODataLiteral $TableLogicalName
        $path = "EntityDefinitions(LogicalName='$safeTable')/Attributes?`$select=LogicalName,DisplayName,AttributeType,IsValidForRead"
        $attributes = @(Invoke-WizardDataverseCollection -Path $path -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker)
    }

    return @($attributes | ForEach-Object {
        $logicalName = "$(Get-WizardObjectValue -InputObject $_ -Names @('LogicalName') -Default '')"
        $displayName = Get-WizardObjectValue -InputObject $_ -Names @('DisplayName')
        $displayNameText = Get-WizardObjectValue -InputObject $_ -Names @('DisplayNameText') -Default $logicalName
        $isValidForRead = Get-WizardObjectValue -InputObject $_ -Names @('IsValidForRead') -Default $true
        [pscustomobject]@{
            LogicalName = $logicalName
            DisplayName = Get-WizardMetadataLabel -Label $displayName -Fallback $displayNameText
            AttributeType = "$(Get-WizardObjectValue -InputObject $_ -Names @('AttributeType') -Default '')"
            IsValidForRead = [bool]$isValidForRead
        }
    } | Where-Object {
        $_.IsValidForRead -and
        $_.LogicalName -match '^[a-z][a-z0-9_]*$' -and
        $_.AttributeType -notin @('Virtual', 'EntityName', 'ManagedProperty', 'CalendarRules', 'PartyList')
    } | Sort-Object DisplayName, LogicalName)
}

function Test-WizardReportChart {
    param(
        [Parameter(Mandatory)] [object]$Chart,
        [Parameter(Mandatory)] [object[]]$Tables,
        [Parameter(Mandatory)] [scriptblock]$AttributeResolver
    )

    $errors = [Collections.Generic.List[string]]::new()
    $table = @($Tables | Where-Object { $_.LogicalName -ceq "$($Chart.TableLogicalName)" })
    if ($table.Count -ne 1) {
        $errors.Add("Table '$($Chart.TableLogicalName)' was not found in reportable metadata.")
        return @($errors)
    }

    $attributes = @(& $AttributeResolver "$($Chart.TableLogicalName)")
    foreach ($fieldName in @("$($Chart.CategoryField)", "$($Chart.AggregateField)")) {
        if (@($attributes | Where-Object { $_.LogicalName -ceq $fieldName }).Count -ne 1) {
            $errors.Add("Field '$fieldName' was not found on table '$($Chart.TableLogicalName)'.")
        }
    }
    $filters = @(Get-WizardObjectValue -InputObject $Chart -Names @('Filters') -Default @())
    foreach ($filter in $filters) {
        if (@($attributes | Where-Object { $_.LogicalName -ceq "$($filter.Field)" }).Count -ne 1) {
            $errors.Add("Filter field '$($filter.Field)' was not found on table '$($Chart.TableLogicalName)'.")
        }
    }

    if ("$($Chart.Aggregate)" -in @('sum', 'avg', 'min', 'max')) {
        $measure = @($attributes | Where-Object { $_.LogicalName -ceq "$($Chart.AggregateField)" })
        if ($measure.Count -eq 1 -and $measure[0].AttributeType -notin @('BigInt', 'Decimal', 'Double', 'Integer', 'Money')) {
            $errors.Add("Aggregate '$($Chart.Aggregate)' requires a numeric measure, but '$($Chart.AggregateField)' is '$($measure[0].AttributeType)'.")
        }
    }
    return @($errors)
}

function ConvertTo-WizardReportXmlValue {
    param([AllowEmptyString()] [string]$Value)
    return [Security.SecurityElement]::Escape($Value ?? '')
}

function New-WizardAggregateFetchXml {
    param([Parameter(Mandatory)] [object]$Chart)

    $table = ConvertTo-WizardReportXmlValue "$($Chart.TableLogicalName)"
    $category = ConvertTo-WizardReportXmlValue "$($Chart.CategoryField)"
    $aggregateField = ConvertTo-WizardReportXmlValue "$($Chart.AggregateField)"
    $aggregate = ConvertTo-WizardReportXmlValue "$($Chart.Aggregate)"
    $filterXml = ''
    $filters = @(Get-WizardObjectValue -InputObject $Chart -Names @('Filters') -Default @())
    if ($filters.Count -gt 0) {
        $conditions = foreach ($filter in $filters) {
            $field = ConvertTo-WizardReportXmlValue "$($filter.Field)"
            $operator = ConvertTo-WizardReportXmlValue "$($filter.Operator)"
            if ($operator -in @('null', 'not-null')) {
                "<condition attribute='$field' operator='$operator'/>"
            } else {
                $value = ConvertTo-WizardReportXmlValue "$($filter.Value)"
                "<condition attribute='$field' operator='$operator' value='$value'/>"
            }
        }
        $filterXml = "<filter type='and'>$($conditions -join '')</filter>"
    }

    return "<fetch mapping='logical' aggregate='true'><entity name='$table'><attribute name='$aggregateField' aggregate='$aggregate' alias='aggregatevalue'/><attribute name='$category' groupby='true' alias='categoryvalue'/>$filterXml</entity></fetch>"
}

function Select-WizardReportItem {
    param(
        [Parameter(Mandatory)] [string]$Prompt,
        [Parameter(Mandatory)] [object[]]$Items,
        [Parameter(Mandatory)] [scriptblock]$LabelSelector
    )

    if ($Items.Count -eq 0) {
        throw "No choices are available for '$Prompt'."
    }
    Write-Host ''
    Write-Host $Prompt -ForegroundColor Cyan
    for ($index = 0; $index -lt $Items.Count; $index++) {
        Write-Host "  [$($index + 1)] $(& $LabelSelector $Items[$index])"
    }
    while ($true) {
        $value = Read-Host 'Selection'
        $selectedIndex = 0
        if ([int]::TryParse($value, [ref]$selectedIndex) -and $selectedIndex -ge 1 -and $selectedIndex -le $Items.Count) {
            return $Items[$selectedIndex - 1]
        }
        Write-Warning "Enter a number from 1 to $($Items.Count)."
    }
}

function Read-WizardReportValue {
    param(
        [Parameter(Mandatory)] [string]$Prompt,
        [string]$Default = ''
    )

    while ($true) {
        $suffix = if ([string]::IsNullOrWhiteSpace($Default)) { '' } else { " [$Default]" }
        $value = (Read-Host "$Prompt$suffix").Trim()
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = $Default
        }
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
        Write-Warning 'A value is required.'
    }
}

function Connect-WizardReportEnvironment {
    param([Parameter(Mandatory)] [string]$EnvironmentUrl)

    $normalizedUrl = $EnvironmentUrl.Trim().TrimEnd('/')
    $uri = $null
    if (-not [Uri]::TryCreate($normalizedUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
        throw 'The Dataverse environment URL must be an absolute HTTPS URL.'
    }

    if ($null -eq (Get-Command az -ErrorAction SilentlyContinue)) {
        throw 'Azure CLI is required for live report discovery. Run scripts/bootstrap/00-prereq-check.ps1.'
    }
    if ($null -eq (Get-Command pac -ErrorAction SilentlyContinue)) {
        throw 'Power Platform CLI is required for live report discovery. Run scripts/bootstrap/00-prereq-check.ps1.'
    }

    & az account show --output none 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Azure sign-in is required. Opening the interactive login...' -ForegroundColor Yellow
        & az login --allow-no-subscriptions --output none
        if ($LASTEXITCODE -ne 0) {
            throw 'Azure sign-in failed.'
        }
    }

    $token = Get-WizardDataverseToken -EnvironmentUrl $normalizedUrl
    & pac auth create --url $normalizedUrl | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Power Platform CLI authentication failed for '$normalizedUrl'."
    }

    return [pscustomobject]@{
        EnvironmentUrl = $normalizedUrl
        AccessToken = $token
    }
}

function Get-WizardReportRecommendation {
    param(
        [Parameter(Mandatory)] [string]$Request,
        [Parameter(Mandatory)] [object[]]$Apps,
        [Parameter(Mandatory)] [object[]]$Tables,
        [Parameter(Mandatory)] [scriptblock]$AttributeResolver
    )

    $requestText = $Request.ToLowerInvariant()
    $tokens = @([regex]::Matches($requestText, '[a-z0-9]+') | ForEach-Object Value | Where-Object Length -ge 3 | ForEach-Object {
        $_
        if ($_.EndsWith('s') -and $_.Length -gt 3) { $_.Substring(0, $_.Length - 1) }
    } | Sort-Object -Unique)
    $score = {
        param($displayName, $logicalName)
        $candidate = "$displayName $logicalName".ToLowerInvariant()
        $value = 0
        foreach ($token in $tokens) {
            if ($candidate.Contains($token)) { $value++ }
        }
        return $value
    }

    $rankedApps = @($Apps | ForEach-Object {
        [pscustomobject]@{ Item = $_; Score = & $score $_.Name $_.UniqueName }
    } | Sort-Object Score -Descending)
    $rankedTables = @($Tables | ForEach-Object {
        [pscustomobject]@{ Item = $_; Score = & $score $_.DisplayName $_.LogicalName }
    } | Sort-Object Score -Descending)
    $app = if ($rankedApps.Count -gt 0) { $rankedApps[0].Item } else { $null }
    $table = if ($rankedTables.Count -gt 0) { $rankedTables[0].Item } else { $null }
    if ($null -eq $table) {
        return [pscustomobject]@{ App = $app; Table = $null; Category = $null; Measure = $null; Aggregate = 'count'; ChartType = 'column'; Filters = @() }
    }

    $attributes = @(& $AttributeResolver $table.LogicalName)
    $aggregate = if ($requestText -match '\baverage|\bavg\b') {
        'avg'
    } elseif ($requestText -match '\bminimum|\bmin\b') {
        'min'
    } elseif ($requestText -match '\bmaximum|\bmax\b') {
        'max'
    } elseif ($requestText -match '\bsum\b|\btotal\b|\brevenue\b|\bamount\b|\bvalue\b') {
        'sum'
    } else {
        'count'
    }
    $chartType = if ($requestText -match '\bdoughnut\b|\bdonut\b') {
        'doughnut'
    } elseif ($requestText -match '\bpie\b') {
        'pie'
    } elseif ($requestText -match '\bbar\b') {
        'bar'
    } else {
        'column'
    }

    $rankedAttributes = @($attributes | ForEach-Object {
        [pscustomobject]@{ Item = $_; Score = & $score $_.DisplayName $_.LogicalName }
    } | Sort-Object Score -Descending)
    $category = @($rankedAttributes | Where-Object {
        $_.Item.AttributeType -in @('Picklist', 'State', 'Status', 'Lookup', 'Owner', 'Customer', 'DateTime', 'String')
    } | Sort-Object @{ Expression = {
        $preferred = $_.Item.LogicalName -match 'status|state|priority|owner|category|type|stage|date|createdon'
        $_.Score + $(if ($preferred) { 2 } else { 0 })
    }; Descending = $true } | Select-Object -First 1)
    $numeric = @($rankedAttributes | Where-Object {
        $_.Item.AttributeType -in @('BigInt', 'Decimal', 'Double', 'Integer', 'Money')
    } | Select-Object -First 1)
    $identifier = @($attributes | Where-Object {
        $_.LogicalName -ceq $table.PrimaryIdAttribute -or $_.AttributeType -eq 'Uniqueidentifier'
    } | Select-Object -First 1)
    $measure = if ($aggregate -in @('sum', 'avg', 'min', 'max') -and $numeric.Count -eq 1) {
        $numeric[0].Item
    } elseif ($identifier.Count -eq 1) {
        $identifier[0]
    } elseif ($rankedAttributes.Count -gt 0) {
        $rankedAttributes[0].Item
    } else {
        $null
    }
    $stateAttribute = @($attributes | Where-Object {
        $_.LogicalName -in @('statecode', 'statuscode') -or $_.AttributeType -in @('State', 'Status')
    } | Select-Object -First 1)
    $filters = if ($stateAttribute.Count -eq 1 -and $requestText -match '\bopen\b|\bactive\b') {
        @([pscustomobject]@{ Field = $stateAttribute[0].LogicalName; Operator = 'eq'; Value = '0' })
    } elseif ($stateAttribute.Count -eq 1 -and $requestText -match '\bclosed\b|\binactive\b') {
        @([pscustomobject]@{ Field = $stateAttribute[0].LogicalName; Operator = 'eq'; Value = '1' })
    } else {
        @()
    }

    return [pscustomobject]@{
        App = $app
        Table = $table
        Category = if ($category.Count -eq 1) { $category[0].Item } else { $null }
        Measure = $measure
        Aggregate = $aggregate
        ChartType = $chartType
        Filters = $filters
    }
}

function Write-WizardReportArtifacts {
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [object]$Definition,
        [switch]$Force
    )

    $payloadFolder = Join-Path $RepoRoot "payloads/scenarios/$ScenarioSlug"
    $scenarioFolder = Join-Path $RepoRoot "specs/$ScenarioSlug"
    $artifactFolder = Join-Path $scenarioFolder 'report-artifacts'
    New-Item -ItemType Directory -Path $payloadFolder, $scenarioFolder, $artifactFolder -Force | Out-Null

    $payloadPath = Join-Path $payloadFolder "reporting-$ScenarioSlug.json"
    if ((Test-Path -LiteralPath $payloadPath) -and -not $Force) {
        throw "Reporting payload already exists. Review it and rerun with -Force to replace it: $payloadPath"
    }

    $chartNames = @($Definition.Charts | ForEach-Object { "$($_.Name)" })
    if (@($chartNames | Sort-Object -Unique).Count -ne $chartNames.Count) {
        throw 'Chart names must be unique.'
    }
    $payload = [ordered]@{
        Enabled = $true
        ReportRequest = "$($Definition.ReportRequest)"
        TargetAppUniqueName = "$($Definition.TargetAppUniqueName)"
        OutputTargets = @($Definition.OutputTargets)
        Charts = @($Definition.Charts | ForEach-Object {
            [ordered]@{
                Name = "$($_.Name)"
                TableLogicalName = "$($_.TableLogicalName)"
                CategoryField = "$($_.CategoryField)"
                AggregateField = "$($_.AggregateField)"
                Aggregate = "$($_.Aggregate)"
                ChartType = "$($_.ChartType)"
                Filters = @(Get-WizardObjectValue -InputObject $_ -Names @('Filters') -Default @())
            }
        })
        Dashboard = [ordered]@{
            Name = "$($Definition.DashboardName)"
            ChartNames = $chartNames
        }
    }

    $payloadJson = $payload | ConvertTo-Json -Depth 20
    $schemaPath = Join-Path $RepoRoot 'schemas/payloads/reporting.schema.json'
    if (-not (Test-Json -Json $payloadJson -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw 'Generated reporting payload failed schema validation.'
    }
    Set-Content -LiteralPath $payloadPath -Value $payloadJson -Encoding UTF8

    $preview = [ordered]@{
        ScenarioSlug = $ScenarioSlug
        TargetAppUniqueName = $payload.TargetAppUniqueName
        OutputTargets = @($payload.OutputTargets)
        Charts = @($payload.Charts | ForEach-Object {
            [ordered]@{
                Name = $_.Name
                FetchXml = New-WizardAggregateFetchXml -Chart $_
            }
        })
    }
    $previewPath = Join-Path $artifactFolder 'query-preview.json'
    $preview | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $previewPath -Encoding UTF8

    $mappingLines = [Collections.Generic.List[string]]::new()
    $mappingLines.Add('# Report Mappings')
    $mappingLines.Add('')
    $mappingLines.Add("- Requested outcome: $($payload.ReportRequest)")
    $mappingLines.Add("- Target app: $($payload.TargetAppUniqueName)")
    $mappingLines.Add("- Dashboard: $($payload.Dashboard.Name)")
    $mappingLines.Add("- Output targets: $($payload.OutputTargets -join ', ')")
    $mappingLines.Add('')
    $mappingLines.Add('| Table | Chart | Category | Measure | Aggregate | Filters |')
    $mappingLines.Add('|---|---|---|---|---|---|')
    foreach ($chart in $payload.Charts) {
        $filterSummary = @($chart.Filters | ForEach-Object { "$($_.Field) $($_.Operator) $($_.Value)".Trim() }) -join '; '
        if ([string]::IsNullOrWhiteSpace($filterSummary)) { $filterSummary = 'none' }
        $mappingLines.Add("| $($chart.TableLogicalName) | $($chart.Name) | $($chart.CategoryField) | $($chart.AggregateField) | $($chart.Aggregate) | $filterSummary |")
    }
    $mappingPath = Join-Path $scenarioFolder 'report-mappings.md'
    Set-Content -LiteralPath $mappingPath -Value ($mappingLines -join "`r`n") -Encoding UTF8

    return [pscustomobject]@{
        PayloadFolder = $payloadFolder
        PayloadPath = $payloadPath
        PreviewPath = $previewPath
        MappingPath = $mappingPath
    }
}

function Add-WizardReportsToApp {
    param(
        [Parameter(Mandatory)] [object]$Payload,
        [Parameter(Mandatory)] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [string]$AccessToken,
        [scriptblock]$RequestInvoker
    )

    $appUniqueName = "$(Get-WizardObjectValue -InputObject $Payload -Names @('TargetAppUniqueName') -Default '')"
    if ([string]::IsNullOrWhiteSpace($appUniqueName)) {
        throw 'The reporting payload does not identify a target model-driven app.'
    }

    $invoke = {
        param($method, $path, $body = $null)
        Invoke-WizardDataverseRequest -Method $method -Path $path -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body $body -RequestInvoker $RequestInvoker
    }
    $safeAppName = ConvertTo-WizardODataLiteral $appUniqueName
    $apps = @((& $invoke Get "appmodules?`$select=appmoduleid,name,uniquename&`$filter=uniquename eq '$safeAppName'").value)
    if ($apps.Count -ne 1) {
        throw "Target app '$appUniqueName' must resolve exactly once; found $($apps.Count)."
    }

    $components = [Collections.Generic.List[object]]::new()
    foreach ($chart in @($Payload.Charts)) {
        $safeChartName = ConvertTo-WizardODataLiteral "$($chart.Name)"
        $safeTableName = ConvertTo-WizardODataLiteral "$($chart.TableLogicalName)"
        $matches = @((& $invoke Get "savedqueryvisualizations?`$select=savedqueryvisualizationid,name,primaryentitytypecode&`$filter=name eq '$safeChartName' and primaryentitytypecode eq '$safeTableName'").value)
        if ($matches.Count -ne 1) {
            throw "Chart '$($chart.Name)' must resolve exactly once before app wiring; found $($matches.Count)."
        }
        $components.Add([ordered]@{
            '@odata.type' = 'Microsoft.Dynamics.CRM.savedqueryvisualization'
            savedqueryvisualizationid = "$($matches[0].savedqueryvisualizationid)"
        })
    }

    $dashboardName = "$($Payload.Dashboard.Name)"
    $safeDashboardName = ConvertTo-WizardODataLiteral $dashboardName
    $dashboards = @((& $invoke Get "systemforms?`$select=formid,name,type&`$filter=name eq '$safeDashboardName' and type eq 0").value)
    if ($dashboards.Count -ne 1) {
        throw "Dashboard '$dashboardName' must resolve exactly once before app wiring; found $($dashboards.Count)."
    }
    $components.Add([ordered]@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.systemform'
        formid = "$($dashboards[0].formid)"
    })

    $appId = "$($apps[0].appmoduleid)"
    & $invoke Post 'AddAppComponents' @{
        AppId = $appId
        Components = @($components)
    } | Out-Null
    & $invoke Post 'PublishXml' @{
        ParameterXml = New-WizardAppModulePublishXml -AppModuleId $appId
    } | Out-Null

    return [pscustomobject]@{
        AppModuleId = $appId
        AppUniqueName = $appUniqueName
        ComponentCount = $components.Count
    }
}
