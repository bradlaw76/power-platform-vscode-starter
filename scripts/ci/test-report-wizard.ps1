Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scenarioSlug = "report-wizard-test-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$configurationPath = Join-Path ([IO.Path]::GetTempPath()) "$scenarioSlug.json"
$payloadFolder = Join-Path $repoRoot "payloads/scenarios/$scenarioSlug"
$scenarioFolder = Join-Path $repoRoot "specs/$scenarioSlug"

try {
    [ordered]@{
        ReportRequest = 'Show open cases grouped by priority for service managers.'
        TargetAppUniqueName = 'ppvs_customer_service'
        OutputTargets = @('fetchxml-preview', 'native-chart-dashboard')
        DashboardName = 'Case Operations'
        Charts = @(
            [ordered]@{
                Name = 'Open Cases by Priority'
                TableLogicalName = 'incident'
                CategoryField = 'prioritycode'
                AggregateField = 'incidentid'
                Aggregate = 'count'
                ChartType = 'column'
                Filters = @(
                    [ordered]@{ Field = 'statecode'; Operator = 'eq'; Value = '0' }
                )
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configurationPath -Encoding UTF8

    $wizard = Join-Path $repoRoot 'scripts/bootstrap/08-report-wizard.ps1'
    $snapshot = Join-Path $repoRoot 'scripts/ci/fixtures/report-wizard-metadata.json'
    . (Join-Path $repoRoot 'scripts/bootstrap/helpers/dataverse-runtime.ps1')
    . (Join-Path $repoRoot 'scripts/bootstrap/helpers/reporting-wizard.ps1')
    $metadata = Import-WizardReportMetadataSnapshot -Path $snapshot
    $apps = @(Get-WizardReportApps -MetadataSnapshot $metadata)
    $tables = @(Get-WizardReportTables -MetadataSnapshot $metadata)
    $recommendation = Get-WizardReportRecommendation -Request 'Show open cases by priority' -Apps $apps -Tables $tables -AttributeResolver {
        param($tableName)
        Get-WizardReportAttributes -TableLogicalName $tableName -MetadataSnapshot $metadata
    }
    if ($recommendation.Table.LogicalName -cne 'incident' -or $recommendation.Category.LogicalName -cne 'prioritycode' -or $recommendation.Aggregate -cne 'count' -or $recommendation.Filters[0].Field -cne 'statecode' -or $recommendation.Filters[0].Value -cne '0') {
        throw 'Natural-language report recommendation did not infer the expected table, category, aggregate, and open-state filter.'
    }
    $wizardContent = Get-Content -LiteralPath $wizard -Raw -Encoding UTF8
    foreach ($requiredPrompt in @('Dataverse environment URL', 'What do you want to see in the report?', 'Use this suggested design?')) {
        if ($wizardContent -notmatch [regex]::Escape($requiredPrompt)) {
            throw "Interactive report wizard is missing required prompt '$requiredPrompt'."
        }
    }
    & $wizard -ScenarioSlug $scenarioSlug -MetadataSnapshotPath $snapshot -ConfigurationPath $configurationPath

    $payloadPath = Join-Path $payloadFolder "reporting-$scenarioSlug.json"
    $previewPath = Join-Path $scenarioFolder 'report-artifacts/query-preview.json'
    $mappingPath = Join-Path $scenarioFolder 'report-mappings.md'
    foreach ($path in @($payloadPath, $previewPath, $mappingPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Expected report wizard artifact was not generated: $path"
        }
    }

    $payloadJson = Get-Content -LiteralPath $payloadPath -Raw -Encoding UTF8
    if (-not (Test-Json -Json $payloadJson -SchemaFile (Join-Path $repoRoot 'schemas/payloads/reporting.schema.json'))) {
        throw 'Generated reporting payload does not match its schema.'
    }
    $payload = $payloadJson | ConvertFrom-Json -Depth 20
    if ($payload.TargetAppUniqueName -cne 'ppvs_customer_service' -or @($payload.Charts).Count -ne 1) {
        throw 'Generated reporting payload lost wizard selections.'
    }

    $preview = Get-Content -LiteralPath $previewPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
    $fetchXml = "$($preview.Charts[0].FetchXml)"
    if ($fetchXml -notmatch "aggregate='true'" -or $fetchXml -notmatch "attribute='statecode' operator='eq' value='0'") {
        throw 'FetchXML preview does not contain the selected aggregate and filter.'
    }

    try {
        & $wizard -ScenarioSlug $scenarioSlug -MetadataSnapshotPath $snapshot -ConfigurationPath $configurationPath
        throw 'Expected overwrite protection to fail.'
    } catch {
        if ($_.Exception.Message -notmatch 'already exists') { throw }
    }
    & $wizard -ScenarioSlug $scenarioSlug -MetadataSnapshotPath $snapshot -ConfigurationPath $configurationPath -Force

    $calls = [Collections.Generic.List[object]]::new()
    $chartState = [Collections.Generic.List[object]]::new()
    $dashboardState = [Collections.Generic.List[object]]::new()
    $requestInvoker = {
        param($request)
        $path = [uri]::UnescapeDataString(($request.Uri -split '/api/data/v9.2/')[1])
        $body = if ($null -eq $request.Body) { $null } else { $request.Body | ConvertFrom-Json -Depth 20 }
        $calls.Add([pscustomobject]@{ Method = $request.Method; Path = $path; Body = $body })
        if ($path -like 'appmodules?*') {
            return [pscustomobject]@{ value = @([pscustomobject]@{ appmoduleid = '11111111-1111-1111-1111-111111111111'; name = 'Customer Service'; uniquename = 'ppvs_customer_service' }) }
        }
        if ($path -like "EntityDefinitions(LogicalName='incident')/Attributes?*") {
            return [pscustomobject]@{ value = @(
                [pscustomobject]@{ LogicalName = 'incidentid'; DisplayName = [pscustomobject]@{ UserLocalizedLabel = [pscustomobject]@{ Label = 'Case' } }; AttributeType = 'Uniqueidentifier'; IsValidForRead = $true },
                [pscustomobject]@{ LogicalName = 'prioritycode'; DisplayName = [pscustomobject]@{ UserLocalizedLabel = [pscustomobject]@{ Label = 'Priority' } }; AttributeType = 'Picklist'; IsValidForRead = $true },
                [pscustomobject]@{ LogicalName = 'statecode'; DisplayName = [pscustomobject]@{ UserLocalizedLabel = [pscustomobject]@{ Label = 'Status' } }; AttributeType = 'State'; IsValidForRead = $true }
            ) }
        }
        if ($path -like 'EntityDefinitions?*') {
            return [pscustomobject]@{ value = @([pscustomobject]@{ LogicalName = 'incident'; DisplayName = [pscustomobject]@{ UserLocalizedLabel = [pscustomobject]@{ Label = 'Case' } }; PrimaryIdAttribute = 'incidentid' }) }
        }
        if ($path -like 'solutions?*') {
            return [pscustomobject]@{ value = @([pscustomobject]@{ solutionid = 'solution-id' }) }
        }
        if ($path -like 'savedqueryvisualizations?*') {
            return [pscustomobject]@{ value = @($chartState) }
        }
        if ($path -like 'systemforms?*') {
            return [pscustomobject]@{ value = @($dashboardState) }
        }
        if ($request.Method -eq 'Post' -and $path -eq 'savedqueryvisualizations') {
            $chartState.Add([pscustomobject]@{ savedqueryvisualizationid = 'chart-id'; name = $body.name; primaryentitytypecode = $body.primaryentitytypecode; description = $body.description })
            return [pscustomobject]@{}
        }
        if ($request.Method -eq 'Post' -and $path -eq 'systemforms') {
            $dashboardState.Add([pscustomobject]@{ formid = 'dashboard-id'; name = $body.name; type = 0; description = $body.description })
            return [pscustomobject]@{}
        }
        return [pscustomobject]@{}
    }

    & $wizard -ScenarioSlug $scenarioSlug -EnvironmentUrl 'https://unit.test' -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -PublisherPrefix 'ppvs' -ConfigurationPath $configurationPath -Force -Deploy -RequestInvoker $requestInvoker
    $appComponentCall = @($calls | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'AddAppComponents' })
    if ($appComponentCall.Count -ne 1 -or @($appComponentCall[0].Body.Components).Count -ne 2) {
        throw 'Deployment did not attach the generated chart and dashboard to the selected app.'
    }
    $chartCreate = @($calls | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'savedqueryvisualizations' })
    if ($chartCreate.Count -ne 1 -or "$($chartCreate[0].Body.datadescription)" -notmatch "attribute='statecode' operator='eq' value='0'") {
        throw 'Native chart deployment did not preserve the wizard filter.'
    }
    if (@($calls | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'PublishXml' -and "$($_.Body.ParameterXml)" -match '<appmodules>' }).Count -ne 1) {
        throw 'Deployment did not publish the selected model-driven app.'
    }

    $invalidConfiguration = Get-Content -LiteralPath $configurationPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
    $invalidConfiguration.Charts[0].Aggregate = 'sum'
    $invalidConfiguration | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $configurationPath -Encoding UTF8
    try {
        & $wizard -ScenarioSlug $scenarioSlug -MetadataSnapshotPath $snapshot -ConfigurationPath $configurationPath -Force
        throw 'Expected nonnumeric aggregate validation to fail.'
    } catch {
        if ($_.Exception.Message -notmatch 'requires a numeric measure') { throw }
    }

    Write-Host 'Report wizard tests passed.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $configurationPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $payloadFolder -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $scenarioFolder -Recurse -Force -ErrorAction SilentlyContinue
}
