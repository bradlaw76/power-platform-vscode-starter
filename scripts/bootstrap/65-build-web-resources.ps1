<#
=============================================================================
COMPONENT:    Build Web Resources
FILE:         scripts/bootstrap/65-build-web-resources.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web Resources | HTML Report Generation

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Generates optional HTML report web resources from scenario design inputs and
prepares them for solution inclusion.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          scenario report settings, design data, and output paths
- Outputs:         generated report web resource files and summary artifacts
- Dependencies:    scenario planning files and local report-generation logic
- Side Effects:    writes local artifact files for later solution packaging

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Reporting must be enabled in scenario planning.
2. Required report mappings and design inputs must already exist.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Enabled report scenarios generate all intended HTML resource files.
✔ Missing report metadata surfaces clear validation failures.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Keep report generation scoped to approved scenario outputs.
- Do not treat optional reporting as a mandatory build step.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Generates scenario-driven HTML report web resources backed by Dataverse queries.

.DESCRIPTION
    Reads scenario design artifacts from specs/<scenario-slug>/ and builds
    report HTML plus per-report config and validation artifacts. In live modes,
    the generated HTML web resources query Dataverse at runtime by using
    model-driven app compatible client APIs. In preview mode, the script emits
    local artifacts and intended queries without uploading web resources.

    Generated local artifacts:
      - specs/<scenario-slug>/webresources/*.html
      - specs/<scenario-slug>/report-artifacts/config/*.json
      - specs/<scenario-slug>/report-artifacts/query-preview.json
      - specs/<scenario-slug>/report-artifacts/report-validation.json

    Live Dataverse validation resolves entity and field metadata when available.
    Sparse data is handled with explicit zero-state messaging instead of static
    KPI claims.

.PARAMETER ScenarioSlug
    Scenario folder under specs/. If omitted and there is exactly one scenario,
    that scenario is used automatically.

.PARAMETER ReportMode
    Reporting mode:
      - live: live Dataverse data only
      - live-with-design-fallback: live data with design summary fallback
      - static: design-summary-only fallback output

.PARAMETER EnableLiveDataverseReports
    Enables runtime Dataverse querying in the generated HTML when a compatible
    client API is available.

.PARAMETER FailIfReportEntitiesMissing
    Fail generation when a scenario-required report entity cannot be resolved.

.PARAMETER FailIfReportFieldsMissing
    Fail generation when a scenario-required report field cannot be resolved.

.PARAMETER IncludeDesignSummaryWhenNoData
    When true, render a separate design metadata summary when no live records
    are detected.

.PARAMETER PreviewReportQueriesOnly
    Generates HTML and config artifacts plus a query preview artifact, but skips
    Dataverse web resource upsert.

.PARAMETER MetadataSnapshotPath
    Optional local JSON snapshot used for offline entity/field/data validation in
    preview mode and CI. Expected shape:

    {
      "entities": [
        {
          "logicalName": "incident",
          "displayName": "Case",
          "primaryIdAttribute": "incidentid",
          "primaryNameAttribute": "title",
          "fields": ["incidentid", "title", "statuscode", "ownerid"],
          "rowCount": 12
        }
      ]
    }
#>

param(
    [string]$ScenarioSlug = "",
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
    [ValidateSet("live", "live-with-design-fallback", "static")]
    [string]$ReportMode = "live-with-design-fallback",
    [bool]$EnableLiveDataverseReports = $true,
    [bool]$FailIfReportEntitiesMissing = $true,
    [bool]$FailIfReportFieldsMissing = $true,
    [bool]$IncludeDesignSummaryWhenNoData = $true,
    [switch]$PreviewReportQueriesOnly,
    [string]$MetadataSnapshotPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-RequiredValue {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    while ($true) {
        $value = if ([string]::IsNullOrWhiteSpace($Default)) {
            Read-Host $Prompt
        }
        else {
            Read-Host "$Prompt [$Default]"
        }

        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = $Default
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        Write-Host "A value is required." -ForegroundColor Yellow
    }
}

function Get-MarkdownSectionValue {
    param(
        [string]$Content,
        [string]$Heading
    )

    $pattern = "(?ms)^#{2,6}\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^#{2,6}\s+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim()
}

function Get-ListValue {
    param(
        [string]$Block,
        [string]$Label
    )

    $pattern = "(?m)^-\s+$([regex]::Escape($Label)):\s*(.+)$"
    $match = [regex]::Match($Block, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim()
}

function Split-Items {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return @($Value -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Get-MarkdownListItems {
    param([string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return @()
    }

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($line in @($Content -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        if ($trimmed -match '^[-*]\s+(.+)$') {
            $items.Add($matches[1].Trim())
        }
        elseif ($trimmed -match '^\d+\.\s+(.+)$') {
            $items.Add($matches[1].Trim())
        }
        else {
            $items.Add($trimmed)
        }
    }

    return $items.ToArray()
}

function ConvertTo-HtmlSafeText {
    param([string]$Value)

    if ($null -eq $Value) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

function ConvertTo-ODataSafeString {
    param([string]$Value)

    if ($null -eq $Value) { return "" }
    return $Value.Replace("'", "''")
}

function Test-TruthyValue {
    param([string]$Value)

    $normalized = ($Value ?? "").Trim().ToLowerInvariant()
    return @("yes", "y", "true", "1") -contains $normalized
}

function ConvertToLogicalName {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    return $Value.Trim().ToLowerInvariant()
}

function Split-Words {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return @($Value -split ',|/|;| and ' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Join-TextLines {
    param([string[]]$Values)

    return (@($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join " ").Trim()
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = "",
        [string]$Prefer = ""
    )

    $headers = @{
        "Authorization"    = "Bearer $AccessToken"
        "Content-Type"     = "application/json"
        "OData-Version"    = "4.0"
        "OData-MaxVersion" = "4.0"
        "Accept"           = "application/json"
    }

    if (-not [string]::IsNullOrWhiteSpace($Prefer)) {
        $headers["Prefer"] = $Prefer
    }

    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body
    }

    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

function Get-WebResourceComponentType {
    try {
        $meta = Invoke-Dv "Get" "EntityDefinitions(LogicalName='solutioncomponent')/Attributes(LogicalName='componenttype')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName&`$expand=OptionSet"
        foreach ($opt in @($meta.OptionSet.Options)) {
            $label = $opt.Label.UserLocalizedLabel.Label
            if ($label -eq "Web Resource" -or $label -eq "WebResource") {
                return [int]$opt.Value
            }
        }
    }
    catch {
        Write-Host "Warning: unable to resolve Web Resource component type dynamically. Using fallback 61." -ForegroundColor Yellow
    }

    return 61
}

function Set-DataverseWebResource {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$Description,
        [string]$Content,
        [int]$WebResourceType,
        [int]$ComponentType,
        [string]$TargetSolutionUniqueName
    )

    $safeName = ConvertTo-ODataSafeString $Name
    $existing = (Invoke-Dv "Get" "webresourceset?`$select=webresourceid,name&`$filter=name eq '$safeName'").value | Select-Object -First 1
    $contentBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Content))
    $body = [ordered]@{
        name            = $Name
        displayname     = $DisplayName
        description     = $Description
        webresourcetype = $WebResourceType
        content         = $contentBase64
    } | ConvertTo-Json -Compress

    $result = [ordered]@{
        Name              = $Name
        Status            = ""
        WebResourceId     = ""
        AddedToSolution   = $false
        SkippedInSolution = $false
    }

    if ($null -eq $existing) {
        Invoke-Dv "Post" "webresourceset" $body | Out-Null
        $existing = (Invoke-Dv "Get" "webresourceset?`$select=webresourceid,name&`$filter=name eq '$safeName'").value | Select-Object -First 1
        $result.Status = "created"
    }
    else {
        Invoke-Dv "Patch" "webresourceset($($existing.webresourceid))" $body | Out-Null
        $result.Status = "updated"
    }

    $result.WebResourceId = "$($existing.webresourceid)"

    if (-not [string]::IsNullOrWhiteSpace($result.WebResourceId)) {
        try {
            $addBody = @{ ComponentId = $result.WebResourceId; ComponentType = $ComponentType; SolutionUniqueName = $TargetSolutionUniqueName; AddRequiredComponents = $true } | ConvertTo-Json -Compress
            Invoke-Dv "Post" "AddSolutionComponent" $addBody | Out-Null
            $result.AddedToSolution = $true
        }
        catch {
            if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
                $result.SkippedInSolution = $true
            }
            else {
                throw
            }
        }
    }

    return [pscustomobject]$result
}

function Get-MappingDictionary {
    param([string[]]$Lines)

    $map = [ordered]@{}
    foreach ($line in @($Lines)) {
        if ($line -match '^(?<display>.+?)\s*->\s*(?<logical>[a-z0-9_]+)$') {
            $display = $matches['display'].Trim()
            $logical = ConvertToLogicalName $matches['logical']
            if (-not [string]::IsNullOrWhiteSpace($display) -and -not [string]::IsNullOrWhiteSpace($logical)) {
                $map[$display] = $logical
            }
        }
    }

    return $map
}

function Get-FieldMappings {
    param([string[]]$Lines)

    $fields = New-Object System.Collections.Generic.List[object]
    foreach ($line in @($Lines)) {
        if ($line -match '^(?<entity>[a-z0-9_]+)\.(?<field>[a-z0-9_]+)$') {
            $fields.Add([pscustomobject]@{
                EntityLogicalName = ConvertToLogicalName $matches['entity']
                FieldLogicalName  = ConvertToLogicalName $matches['field']
                Source            = 'spec'
            })
        }
    }

    return $fields.ToArray()
}

function Get-RelationshipMappings {
    param([string[]]$Lines)

    $items = New-Object System.Collections.Generic.List[object]
    foreach ($line in @($Lines)) {
        if ($line -match '^(?<referencing>[a-z0-9_]+).*?->\s*(?<referenced>[a-z0-9_]+)') {
            $items.Add([pscustomobject]@{
                ReferencingEntity = ConvertToLogicalName $matches['referencing']
                ReferencedEntity  = ConvertToLogicalName $matches['referenced']
                Source            = 'spec'
            })
        }
    }

    return $items.ToArray()
}

function Get-PayloadMetadata {
    param(
        [string]$RepoRoot,
        [System.Collections.Generic.HashSet[string]]$RelevantEntities,
        [string]$PublisherPrefixValue
    )

    $payloadRoot = Join-Path $RepoRoot 'payloads'
    $result = [ordered]@{
        Tables        = New-Object System.Collections.Generic.List[object]
        Columns       = New-Object System.Collections.Generic.List[object]
        Relationships = New-Object System.Collections.Generic.List[object]
    }

    if (-not (Test-Path $payloadRoot)) {
        return [pscustomobject]$result
    }

    $normalizedPrefix = ConvertToLogicalName $PublisherPrefixValue
    foreach ($file in @(Get-ChildItem -Path $payloadRoot -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue)) {
        try {
            $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20

            $entityDefinition = if ($doc.PSObject.Properties['EntityDefinition']) { $doc.EntityDefinition } else { $null }
            if ($null -ne $entityDefinition) {
                $schemaName = ConvertToLogicalName "$($entityDefinition.SchemaName)"
                $displayName = if ($null -ne $entityDefinition.DisplayName.LocalizedLabels) { "$($entityDefinition.DisplayName.LocalizedLabels[0].Label)" } else { $schemaName }
                $include = $RelevantEntities.Contains($schemaName)
                if (-not $include -and -not [string]::IsNullOrWhiteSpace($normalizedPrefix) -and $schemaName.StartsWith("$normalizedPrefix`_")) {
                    $include = $true
                }
                if ($include) {
                    $result.Tables.Add([pscustomobject]@{
                        LogicalName = $schemaName
                        DisplayName = $displayName
                        Source      = $file.FullName
                    })
                }
                continue
            }

            if ($doc.PSObject.Properties['TableLogicalName'] -and $doc.PSObject.Properties['Columns']) {
                $tableLogicalName = ConvertToLogicalName "$($doc.TableLogicalName)"
                if ($RelevantEntities.Contains($tableLogicalName)) {
                    foreach ($column in @($doc.Columns)) {
                        $logicalName = ConvertToLogicalName "$($column.LogicalName)"
                        if (-not [string]::IsNullOrWhiteSpace($logicalName)) {
                            $result.Columns.Add([pscustomobject]@{
                                EntityLogicalName = $tableLogicalName
                                FieldLogicalName  = $logicalName
                                Source            = $file.FullName
                            })
                        }
                    }
                }
                continue
            }

            $relationships = if ($doc.PSObject.Properties['Relationships'] -and $null -ne $doc.Relationships) { @($doc.Relationships) } else { @() }
            foreach ($relationship in $relationships) {
                $definition = if ($null -ne $relationship.RelationshipDefinition) { $relationship.RelationshipDefinition } else { $relationship }
                $referenced = ConvertToLogicalName "$($definition.ReferencedEntity)"
                $referencing = ConvertToLogicalName "$($definition.ReferencingEntity)"
                if ($RelevantEntities.Contains($referenced) -or $RelevantEntities.Contains($referencing)) {
                    $result.Relationships.Add([pscustomobject]@{
                        ReferencedEntity  = $referenced
                        ReferencingEntity = $referencing
                        ReferencingField  = ConvertToLogicalName "$($definition.ReferencingAttribute)"
                        Source            = $file.FullName
                    })
                }
            }
        }
        catch {
            Write-Host "Warning: payload parse skipped for $($file.FullName): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    return [pscustomobject]$result
}

function Get-ScenarioDefinition {
    param(
        [string]$ScenarioSlugValue,
        [string]$AnswersContent,
        [string]$SpecContent,
        [string]$PlanContent
    )

    $scenarioBlock = Get-MarkdownSectionValue -Content $AnswersContent -Heading 'Scenario'
    $applicationProfileBlock = Get-MarkdownSectionValue -Content $AnswersContent -Heading 'Application Profile'
    $wizardBlock = Get-MarkdownSectionValue -Content $AnswersContent -Heading 'Wizard Answers'
    $optionalBlock = Get-MarkdownSectionValue -Content $AnswersContent -Heading 'Optional Report Web Resources'

    $scenarioName = Get-ListValue -Block $scenarioBlock -Label 'Name'
    if ([string]::IsNullOrWhiteSpace($scenarioName)) {
        $summary = Get-MarkdownSectionValue -Content $SpecContent -Heading 'Scenario Summary'
        if (-not [string]::IsNullOrWhiteSpace($summary)) {
            $scenarioName = $summary
        }
    }
    if ([string]::IsNullOrWhiteSpace($scenarioName)) {
        $scenarioName = $ScenarioSlugValue
    }

    $problemStatement = Get-MarkdownSectionValue -Content $SpecContent -Heading 'Problem Statement'
    $successCriteria = @(Get-MarkdownListItems -Content (Get-MarkdownSectionValue -Content $SpecContent -Heading 'Success Criteria'))
    $artifacts = @(Get-MarkdownListItems -Content (Get-MarkdownSectionValue -Content $SpecContent -Heading 'Required Experience and Artifacts'))
    $requiredEntityDisplayNames = @(Split-Items -Value (Get-MarkdownSectionValue -Content $SpecContent -Heading 'Required Data Entities'))

    $standardTableMap = Get-MappingDictionary -Lines (Get-MarkdownListItems -Content (Get-MarkdownSectionValue -Content $SpecContent -Heading 'Standard reused tables (display -> logical)'))
    $customTableMap = Get-MappingDictionary -Lines (Get-MarkdownListItems -Content (Get-MarkdownSectionValue -Content $SpecContent -Heading 'Custom tables to create (input -> generated logical)'))

    $entityMap = [ordered]@{}
    foreach ($key in $standardTableMap.Keys) { $entityMap[$key] = $standardTableMap[$key] }
    foreach ($key in $customTableMap.Keys) { $entityMap[$key] = $customTableMap[$key] }

    $standardFields = @(Get-FieldMappings -Lines (Get-MarkdownListItems -Content (Get-MarkdownSectionValue -Content $SpecContent -Heading 'Standard fields reused')))
    $customFields = @(Get-FieldMappings -Lines (Get-MarkdownListItems -Content (Get-MarkdownSectionValue -Content $SpecContent -Heading 'Custom fields to add')))
    $relationships = @(Get-RelationshipMappings -Lines (Get-MarkdownListItems -Content (Get-MarkdownSectionValue -Content $SpecContent -Heading 'Relationships to create')))

    $targetAudience = Get-MarkdownSectionValue -Content $SpecContent -Heading 'Target Audience'
    if ([string]::IsNullOrWhiteSpace($targetAudience)) {
        $targetAudience = [regex]::Match($wizardBlock, '(?im)^3\.\s*Target audience:\s*(.+)$').Groups[1].Value.Trim()
    }

    $users = Get-MarkdownSectionValue -Content $SpecContent -Heading 'Users'
    if ([string]::IsNullOrWhiteSpace($users)) {
        $users = [regex]::Match($wizardBlock, '(?im)^5\.\s*Users:\s*(.+)$').Groups[1].Value.Trim()
    }

    $demoDataRequirement = Get-MarkdownSectionValue -Content $SpecContent -Heading 'Demo Data Requirement'
    if ([string]::IsNullOrWhiteSpace($demoDataRequirement)) {
        $demoDataRequirement = [regex]::Match($wizardBlock, '(?im)^10\.\s*Demo data needed:\s*(.+)$').Groups[1].Value.Trim()
    }

    $includeReports = [regex]::Match($wizardBlock, '(?im)^19\.\s*Create optional HTML report web resources.*:\s*(.+)$').Groups[1].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($includeReports)) {
        $includeReports = Get-ListValue -Block $optionalBlock -Label 'Enabled'
    }

    $selectedReports = Get-ListValue -Block $optionalBlock -Label 'Selected Reports'
    if ([string]::IsNullOrWhiteSpace($selectedReports)) {
        $selectedReports = Get-ListValue -Block $optionalBlock -Label 'Report set'
    }

    $applicationProfile = Get-ListValue -Block $applicationProfileBlock -Label 'Profile'

    $docSignals = (Join-TextLines -Values @(
        $scenarioName,
        $problemStatement,
        $targetAudience,
        $users,
        ($requiredEntityDisplayNames -join ' '),
        ($artifacts -join ' '),
        ($successCriteria -join ' '),
        $PlanContent
    )).ToLowerInvariant()

    $reportProfile = 'general'
    if ($docSignals -match 'case|intake|support|ticket|service request|incident') {
        $reportProfile = 'intake-case'
    }
    elseif ($docSignals -match 'fraud|evidence|discrepanc|referral|finding') {
        $reportProfile = 'evidence-review'
    }
    elseif ($docSignals -match 'review|workflow|queue|approval|stage') {
        $reportProfile = 'workflow-review'
    }

    return [pscustomobject]@{
        ScenarioSlug               = $ScenarioSlugValue
        ScenarioName               = $scenarioName
        ApplicationProfile         = $applicationProfile.ToLowerInvariant()
        ProblemStatement           = $problemStatement
        SuccessCriteria            = $successCriteria
        Artifacts                  = $artifacts
        TargetAudience             = $targetAudience
        Users                      = $users
        Roles                      = @(Split-Words -Value "$targetAudience, $users")
        RequiredEntityDisplayNames = $requiredEntityDisplayNames
        EntityMap                  = $entityMap
        StandardFields             = $standardFields
        CustomFields               = $customFields
        Relationships              = $relationships
        DemoDataRequired           = (Test-TruthyValue -Value $demoDataRequirement)
        IncludeReports             = (Test-TruthyValue -Value $includeReports)
        SelectedReports            = @(Split-Items -Value $selectedReports)
        ReportProfile              = $reportProfile
    }
}

function Get-RelevantEntities {
    param([pscustomobject]$Scenario)

    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($displayName in @($Scenario.RequiredEntityDisplayNames)) {
        $logical = ConvertToLogicalName ($Scenario.EntityMap[$displayName])
        if (-not [string]::IsNullOrWhiteSpace($logical)) {
            [void]$set.Add($logical)
        }
    }
    foreach ($relationship in @($Scenario.Relationships)) {
        if (-not [string]::IsNullOrWhiteSpace($relationship.ReferencingEntity)) {
            [void]$set.Add($relationship.ReferencingEntity)
        }
        if (-not [string]::IsNullOrWhiteSpace($relationship.ReferencedEntity)) {
            [void]$set.Add($relationship.ReferencedEntity)
        }
    }
    foreach ($field in @($Scenario.StandardFields + $Scenario.CustomFields)) {
        if (-not [string]::IsNullOrWhiteSpace($field.EntityLogicalName)) {
            [void]$set.Add($field.EntityLogicalName)
        }
    }

    return $set
}

function Get-PrimaryScenarioEntity {
    param([pscustomobject]$Scenario)

    foreach ($displayName in @($Scenario.RequiredEntityDisplayNames)) {
        $logical = ConvertToLogicalName ($Scenario.EntityMap[$displayName])
        if (-not [string]::IsNullOrWhiteSpace($logical)) {
            return [pscustomobject]@{
                DisplayName = $displayName
                LogicalName = $logical
            }
        }
    }

    foreach ($key in $Scenario.EntityMap.Keys) {
        return [pscustomobject]@{
            DisplayName = $key
            LogicalName = ConvertToLogicalName $Scenario.EntityMap[$key]
        }
    }

    return [pscustomobject]@{
        DisplayName = $Scenario.ScenarioName
        LogicalName = ''
    }
}

function Get-MetadataSnapshot {
    param([string]$Path)

    $snapshot = @{}
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
        return $snapshot
    }

    $doc = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
    foreach ($entity in @($doc.entities)) {
        $logicalName = ConvertToLogicalName "$($entity.logicalName)"
        if ([string]::IsNullOrWhiteSpace($logicalName)) {
            continue
        }

        $snapshot[$logicalName] = [pscustomobject]@{
            LogicalName          = $logicalName
            DisplayName          = "$($entity.displayName)"
            PrimaryIdAttribute   = ConvertToLogicalName "$($entity.primaryIdAttribute)"
            PrimaryNameAttribute = ConvertToLogicalName "$($entity.primaryNameAttribute)"
            Fields               = @($entity.fields | ForEach-Object { ConvertToLogicalName "$_" } | Where-Object { $_ })
            RowCount             = if ($null -ne $entity.rowCount) { [int]$entity.rowCount } else { 0 }
            Source               = 'snapshot'
            Exists               = $true
        }
    }

    return $snapshot
}

function Get-LiveEntityMetadata {
    param([string]$LogicalName)

    $safeName = ConvertTo-ODataSafeString $LogicalName
    $entity = Invoke-Dv "Get" "EntityDefinitions(LogicalName='$safeName')?`$select=LogicalName,PrimaryIdAttribute,PrimaryNameAttribute"
    $attributeResponse = Invoke-Dv "Get" "EntityDefinitions(LogicalName='$safeName')/Attributes?`$select=LogicalName"
    $fields = @($attributeResponse.value | ForEach-Object { ConvertToLogicalName "$($_.LogicalName)" } | Where-Object { $_ })
    $countResponse = Invoke-Dv "Get" "$LogicalName?`$top=1&`$select=$($entity.PrimaryIdAttribute)"
    $rowCount = if (@($countResponse.value).Count -gt 0) { 1 } else { 0 }

    return [pscustomobject]@{
        LogicalName          = ConvertToLogicalName "$($entity.LogicalName)"
        DisplayName          = $LogicalName
        PrimaryIdAttribute   = ConvertToLogicalName "$($entity.PrimaryIdAttribute)"
        PrimaryNameAttribute = ConvertToLogicalName "$($entity.PrimaryNameAttribute)"
        Fields               = $fields
        RowCount             = $rowCount
        Source               = 'live'
        Exists               = $true
    }
}

function Resolve-EntityMetadataMap {
    param(
        [pscustomobject]$Scenario,
        [pscustomobject]$PayloadMetadata,
        [hashtable]$Snapshot,
        [bool]$CanUseLiveMetadata
    )

    $map = @{}
    $relevantEntities = Get-RelevantEntities -Scenario $Scenario
    foreach ($logicalName in @($relevantEntities)) {
        $logicalName = ConvertToLogicalName $logicalName
        if ([string]::IsNullOrWhiteSpace($logicalName)) {
            continue
        }

        $payloadFields = @($PayloadMetadata.Columns | Where-Object { $_.EntityLogicalName -eq $logicalName } | ForEach-Object { $_.FieldLogicalName })
        $designFields = @(
            $Scenario.StandardFields | Where-Object { $_.EntityLogicalName -eq $logicalName } | ForEach-Object { $_.FieldLogicalName }
        ) + @(
            $Scenario.CustomFields | Where-Object { $_.EntityLogicalName -eq $logicalName } | ForEach-Object { $_.FieldLogicalName }
        ) + @($payloadFields)
        $designFields = @($designFields | Where-Object { $_ } | Select-Object -Unique)

        $resolved = $null
        if ($Snapshot.ContainsKey($logicalName)) {
            $resolved = $Snapshot[$logicalName]
        }
        elseif ($CanUseLiveMetadata) {
            try {
                $resolved = Get-LiveEntityMetadata -LogicalName $logicalName
            }
            catch {
                $resolved = [pscustomobject]@{
                    LogicalName          = $logicalName
                    DisplayName          = $logicalName
                    PrimaryIdAttribute   = ''
                    PrimaryNameAttribute = ''
                    Fields               = $designFields
                    RowCount             = 0
                    Source               = 'live-unresolved'
                    Exists               = $false
                    Error                = $_.Exception.Message
                }
            }
        }
        else {
            $resolved = [pscustomobject]@{
                LogicalName          = $logicalName
                DisplayName          = $logicalName
                PrimaryIdAttribute   = if ($logicalName -eq 'incident') { 'incidentid' } else { '' }
                PrimaryNameAttribute = if ($logicalName -eq 'incident') { 'title' } else { '' }
                Fields               = $designFields
                RowCount             = 0
                Source               = 'design'
                Exists               = $true
            }
        }

        $map[$logicalName] = [pscustomobject]@{
            LogicalName          = $logicalName
            DisplayName          = if (-not [string]::IsNullOrWhiteSpace($resolved.DisplayName)) { $resolved.DisplayName } else { $logicalName }
            PrimaryIdAttribute   = ConvertToLogicalName "$($resolved.PrimaryIdAttribute)"
            PrimaryNameAttribute = ConvertToLogicalName "$($resolved.PrimaryNameAttribute)"
            Fields               = @($resolved.Fields | ForEach-Object { ConvertToLogicalName "$_" } | Where-Object { $_ } | Select-Object -Unique)
            RowCount             = if ($null -ne $resolved.RowCount) { [int]$resolved.RowCount } else { 0 }
            Source               = "$($resolved.Source)"
            Exists               = [bool]$resolved.Exists
            Error                = if ($resolved.PSObject.Properties['Error']) { "$($resolved.Error)" } else { '' }
        }
    }

    return $map
}

function Test-EntityHasField {
    param(
        [hashtable]$MetadataMap,
        [string]$EntityLogicalName,
        [string]$FieldLogicalName
    )

    $entity = $MetadataMap[(ConvertToLogicalName $EntityLogicalName)]
    if ($null -eq $entity) {
        return $false
    }

    return @($entity.Fields) -contains (ConvertToLogicalName $FieldLogicalName)
}

function New-AggregateCountFetchXml {
    param(
        [string]$EntityLogicalName,
        [string]$IdField,
        [string]$Alias
    )

    return "<fetch aggregate='true'><entity name='$EntityLogicalName'><attribute name='$IdField' alias='$Alias' aggregate='count' /></entity></fetch>"
}

function New-GroupByFetchXml {
    param(
        [string]$EntityLogicalName,
        [string]$IdField,
        [string]$GroupField,
        [string]$CountAlias,
        [string]$GroupAlias
    )

    return "<fetch aggregate='true'><entity name='$EntityLogicalName'><attribute name='$IdField' alias='$CountAlias' aggregate='count' /><attribute name='$GroupField' alias='$GroupAlias' groupby='true' /></entity></fetch>"
}

function New-RecentRecordsFetchXml {
    param(
        [string]$EntityLogicalName,
        [string]$NameField,
        [string]$DateField
    )

    return "<fetch top='8'><entity name='$EntityLogicalName'><attribute name='$NameField' /><attribute name='$DateField' /><order attribute='$DateField' descending='true' /></entity></fetch>"
}

function Get-ScenarioReportDefinitions {
    param(
        [pscustomobject]$Scenario,
        [pscustomobject]$PrimaryEntity
    )

    $roles = if (@($Scenario.Roles).Count -gt 0) { $Scenario.Roles } else { @('operators', 'supervisors', 'stakeholders') }
    $primaryLabel = if (-not [string]::IsNullOrWhiteSpace($PrimaryEntity.DisplayName)) { $PrimaryEntity.DisplayName } else { $Scenario.ScenarioName }
    $standalone = $Scenario.ApplicationProfile -eq 'standalone-model-driven'

    $definitions = @(
        [pscustomobject]@{
            Key      = 'agent'
            Title    = if ($standalone) { "$($Scenario.ScenarioName) - Operational Workspace" } else { "$($Scenario.ScenarioName) - Agent Operations Report" }
            Subtitle = "Live $primaryLabel workload and queue signals for $($roles[0])."
            Audience = if ($roles.Count -gt 0) { $roles[0] } else { 'frontline users' }
            Purpose  = "Tracks frontline activity for the scenario problem statement: $($Scenario.ProblemStatement)"
            Focus    = @('counts', 'priority', 'recent-records')
            IconKind = 'agent'
        },
        [pscustomobject]@{
            Key      = 'supervisor'
            Title    = if ($standalone) { "$($Scenario.ScenarioName) - Team Workload" } else { "$($Scenario.ScenarioName) - Supervisor Oversight Report" }
            Subtitle = if ($standalone) { 'Live backlog, ownership, and work distribution for team leads.' } else { 'Live backlog, ownership, and escalation visibility for operational leads.' }
            Audience = if ($roles.Count -gt 1) { $roles[1] } else { 'supervisors' }
            Purpose  = "Monitors queue health, owner distribution, and work-in-flight for $primaryLabel records."
            Focus    = @('counts', 'status', 'owner', 'age')
            IconKind = 'supervisor'
        },
        [pscustomobject]@{
            Key      = 'executive-kpi'
            Title    = if ($standalone) { "$($Scenario.ScenarioName) - Management KPI" } else { "$($Scenario.ScenarioName) - Executive Scenario KPI Report" }
            Subtitle = 'Scenario-specific KPI summary tied to actual Dataverse records and success criteria.'
            Audience = if ($roles.Count -gt 2) { $roles[2] } else { 'decision makers' }
            Purpose  = 'Summarizes operational progress against the scenario design and success signals.'
            Focus    = @('counts', 'status', 'priority')
            IconKind = 'executive'
        }
    )

    $selected = @($Scenario.SelectedReports | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
    if ($selected.Count -eq 0 -or $selected -contains 'all') {
        return $definitions
    }

    $filtered = @($definitions | Where-Object {
        $selected -contains $_.Key -or
        $selected -contains $_.Title.ToLowerInvariant() -or
        $selected -contains ($_.Key -replace '-', ' ') -or
        ($_.Key -eq 'agent' -and $selected -contains 'operational workspace') -or
        ($_.Key -eq 'supervisor' -and $selected -contains 'team workload') -or
        ($_.Key -eq 'executive-kpi' -and $selected -contains 'management kpi')
    })

    if ($filtered.Count -eq 0) {
        return $definitions
    }

    return $filtered
}

function Get-MetricCandidates {
    param(
        [pscustomobject]$Scenario,
        [pscustomobject]$Report,
        [pscustomobject]$PrimaryEntity
    )

    $entityLogicalName = $PrimaryEntity.LogicalName
    $entityDisplayName = $PrimaryEntity.DisplayName
    $scenarioProfile = $Scenario.ReportProfile
    $candidates = New-Object System.Collections.Generic.List[object]

    $candidates.Add([pscustomobject]@{
        Key               = 'total-records'
        Title             = "Total $entityDisplayName Records"
        Kind              = 'aggregate-count'
        EntityLogicalName = $entityLogicalName
        RequiredFields    = @('__primaryid__')
        Optional          = $false
        Reason            = 'Core operational record count is always relevant when a primary scenario entity exists.'
    })

    if ($Report.Focus -contains 'status' -or $scenarioProfile -in @('intake-case', 'workflow-review', 'evidence-review')) {
        $candidates.Add([pscustomobject]@{
            Key               = 'status-breakdown'
            Title             = "$entityDisplayName by Status"
            Kind              = 'aggregate-group'
            EntityLogicalName = $entityLogicalName
            RequiredFields    = @('__primaryid__', 'statuscode|statecode')
            Optional          = $false
            Reason            = 'Status is part of the scenario success and queue visibility requirements.'
        })
    }

    if ($Report.Focus -contains 'priority' -or $scenarioProfile -eq 'intake-case') {
        $candidates.Add([pscustomobject]@{
            Key               = 'priority-breakdown'
            Title             = "$entityDisplayName by Priority"
            Kind              = 'aggregate-group'
            EntityLogicalName = $entityLogicalName
            RequiredFields    = @('__primaryid__', 'prioritycode|cct_priority|priorityid|*_priority')
            Optional          = $false
            Reason            = 'Priority visibility is explicitly referenced in case-style scenario artifacts.'
        })
    }

    if ($Report.Focus -contains 'owner') {
        $candidates.Add([pscustomobject]@{
            Key               = 'owner-breakdown'
            Title             = "$entityDisplayName by Owner"
            Kind              = 'aggregate-group'
            EntityLogicalName = $entityLogicalName
            RequiredFields    = @('__primaryid__', 'ownerid|*_agent|assignedto|owner')
            Optional          = $false
            Reason            = 'Operational ownership is needed for supervisor oversight.'
        })
    }

    if ($Report.Focus -contains 'recent-records') {
        $candidates.Add([pscustomobject]@{
            Key               = 'recent-records'
            Title             = "Recent $entityDisplayName Records"
            Kind              = 'list'
            EntityLogicalName = $entityLogicalName
            RequiredFields    = @('__primaryname__', 'createdon|modifiedon')
            Optional          = $false
            Reason            = 'Recent record flow gives operators a grounded live activity view.'
        })
    }

    if ($Report.Focus -contains 'age' -or $scenarioProfile -in @('intake-case', 'workflow-review')) {
        $candidates.Add([pscustomobject]@{
            Key               = 'queue-age'
            Title             = "Aged $entityDisplayName Queue"
            Kind              = 'list'
            EntityLogicalName = $entityLogicalName
            RequiredFields    = @('__primaryname__', 'createdon', 'statuscode|statecode')
            Optional          = $true
            Reason            = 'Queue age is relevant when the scenario mentions backlog, review, or intake flow.'
        })
    }

    return $candidates.ToArray()
}

function Resolve-MetricCandidate {
    param(
        [pscustomobject]$Metric,
        [hashtable]$MetadataMap
    )

    $entityLogicalName = ConvertToLogicalName $Metric.EntityLogicalName
    $entityMetadata = $MetadataMap[$entityLogicalName]
    if ($null -eq $entityMetadata -or -not $entityMetadata.Exists) {
        return [pscustomobject]@{
            Key              = $Metric.Key
            Title            = $Metric.Title
            Kind             = $Metric.Kind
            EntityLogicalName = $entityLogicalName
            Enabled          = $false
            MissingEntities  = @($entityLogicalName)
            MissingFields    = @()
            SkipReason       = "Entity '$entityLogicalName' could not be resolved."
            Optional         = [bool]$Metric.Optional
            Query            = $null
            Reason           = $Metric.Reason
        }
    }

    $resolvedFields = New-Object System.Collections.Generic.List[string]
    $missingFields = New-Object System.Collections.Generic.List[string]

    foreach ($requirement in @($Metric.RequiredFields)) {
        if ($requirement -eq '__primaryid__') {
            if ([string]::IsNullOrWhiteSpace($entityMetadata.PrimaryIdAttribute)) {
                $missingFields.Add('__primaryid__')
            } else {
                $resolvedFields.Add($entityMetadata.PrimaryIdAttribute)
            }
            continue
        }

        if ($requirement -eq '__primaryname__') {
            if ([string]::IsNullOrWhiteSpace($entityMetadata.PrimaryNameAttribute)) {
                $missingFields.Add('__primaryname__')
            } else {
                $resolvedFields.Add($entityMetadata.PrimaryNameAttribute)
            }
            continue
        }

        $tokens = @($requirement -split '\|')
        $resolved = ''
        foreach ($token in $tokens) {
            $normalized = ConvertToLogicalName $token
            if ($normalized.StartsWith('*')) {
                $suffix = $normalized.TrimStart('*')
                foreach ($field in @($entityMetadata.Fields)) {
                    if ($field.EndsWith($suffix)) {
                        $resolved = $field
                        break
                    }
                }
            }
            elseif (Test-EntityHasField -MetadataMap $MetadataMap -EntityLogicalName $entityLogicalName -FieldLogicalName $normalized) {
                $resolved = $normalized
            }

            if (-not [string]::IsNullOrWhiteSpace($resolved)) {
                break
            }
        }

        if ([string]::IsNullOrWhiteSpace($resolved)) {
            $missingFields.Add($requirement)
        }
        else {
            $resolvedFields.Add($resolved)
        }
    }

    if ($missingFields.Count -gt 0) {
        return [pscustomobject]@{
            Key              = $Metric.Key
            Title            = $Metric.Title
            Kind             = $Metric.Kind
            EntityLogicalName = $entityLogicalName
            Enabled          = $false
            MissingEntities  = @()
            MissingFields    = @($missingFields)
            SkipReason       = "Required fields were not resolved: $($missingFields -join ', ')"
            Optional         = [bool]$Metric.Optional
            Query            = $null
            Reason           = $Metric.Reason
        }
    }

    $query = $null
    switch ($Metric.Kind) {
        'aggregate-count' {
            $query = [pscustomobject]@{
                Key               = $Metric.Key
                Kind              = $Metric.Kind
                EntityLogicalName = $entityLogicalName
                FieldsUsed        = @($resolvedFields)
                FetchXml          = New-AggregateCountFetchXml -EntityLogicalName $entityLogicalName -IdField $entityMetadata.PrimaryIdAttribute -Alias 'recordcount'
                ValueAlias        = 'recordcount'
            }
        }
        'aggregate-group' {
            $groupField = @($resolvedFields | Where-Object { $_ -ne $entityMetadata.PrimaryIdAttribute }) | Select-Object -First 1
            $query = [pscustomobject]@{
                Key               = $Metric.Key
                Kind              = $Metric.Kind
                EntityLogicalName = $entityLogicalName
                FieldsUsed        = @($resolvedFields)
                FetchXml          = New-GroupByFetchXml -EntityLogicalName $entityLogicalName -IdField $entityMetadata.PrimaryIdAttribute -GroupField $groupField -CountAlias 'recordcount' -GroupAlias 'groupvalue'
                ValueAlias        = 'recordcount'
                GroupAlias        = 'groupvalue'
            }
        }
        'list' {
            $dateField = @($resolvedFields | Where-Object { $_ -in @('createdon', 'modifiedon') }) | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($dateField)) {
                $dateField = @($resolvedFields | Where-Object { $_ -ne $entityMetadata.PrimaryNameAttribute }) | Select-Object -First 1
            }
            $query = [pscustomobject]@{
                Key               = $Metric.Key
                Kind              = $Metric.Kind
                EntityLogicalName = $entityLogicalName
                FieldsUsed        = @($resolvedFields)
                FetchXml          = New-RecentRecordsFetchXml -EntityLogicalName $entityLogicalName -NameField $entityMetadata.PrimaryNameAttribute -DateField $dateField
                NameField         = $entityMetadata.PrimaryNameAttribute
                DateField         = $dateField
            }
        }
    }

    return [pscustomobject]@{
        Key              = $Metric.Key
        Title            = $Metric.Title
        Kind             = $Metric.Kind
        EntityLogicalName = $entityLogicalName
        Enabled          = $true
        MissingEntities  = @()
        MissingFields    = @()
        SkipReason       = ''
        Optional         = [bool]$Metric.Optional
        Query            = $query
        Reason           = $Metric.Reason
    }
}

function New-IconSvg {
    param([string]$Kind)

    switch ($Kind) {
        'agent' {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="4" fill="currentColor"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
        }
        'supervisor' {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="14" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M7 14l3-3 2 2 4-4" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
        }
        default {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20V10" stroke="currentColor" stroke-width="2"/><path d="M10 20V6" stroke="currentColor" stroke-width="2"/><path d="M16 20V13" stroke="currentColor" stroke-width="2"/><path d="M22 20V4" stroke="currentColor" stroke-width="2"/></svg>'
        }
    }
}

function New-ReportHtml {
    param(
        [pscustomobject]$Scenario,
        [pscustomobject]$Report,
        [pscustomobject]$ReportConfig
    )

    $safeTitle = ConvertTo-HtmlSafeText $Report.Title
    $safeSubtitle = ConvertTo-HtmlSafeText $Report.Subtitle
    $safeScenarioName = ConvertTo-HtmlSafeText $Scenario.ScenarioName
    $safeProblem = ConvertTo-HtmlSafeText $Scenario.ProblemStatement
    $generatedUtc = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm 'UTC'")
    $configJson = $ReportConfig | ConvertTo-Json -Depth 20 -Compress
    $iconSvg = New-IconSvg -Kind $Report.IconKind
    $designCriteria = ((@($Scenario.SuccessCriteria) | ForEach-Object { '<li>' + (ConvertTo-HtmlSafeText $_) + '</li>' }) -join '')
    $designArtifacts = ((@($Scenario.Artifacts) | ForEach-Object { '<li>' + (ConvertTo-HtmlSafeText $_) + '</li>' }) -join '')
    if ([string]::IsNullOrWhiteSpace($designCriteria)) { $designCriteria = '<li>No scenario success criteria were provided.</li>' }
    if ([string]::IsNullOrWhiteSpace($designArtifacts)) { $designArtifacts = '<li>No scenario operational artifacts were provided.</li>' }

    return @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>$safeTitle</title>
  <style>
    :root {
      --report-bg: #f5f8fb;
      --report-surface: #ffffff;
      --report-border: #d6e3ef;
      --report-text: #1f2937;
      --report-muted: #5f6b7a;
      --report-primary: #0f6cbd;
      --report-primary-strong: #0b4f8a;
      --report-accent: #cfe8ff;
      --report-good: #0f766e;
      --report-warn: #b45309;
      --report-bad: #b91c1c;
      --report-font: "Segoe UI", "Segoe UI Variable", Tahoma, sans-serif;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: var(--report-font);
      color: var(--report-text);
      background:
        radial-gradient(circle at 15% 0%, rgba(15,108,189,.10), transparent 32%),
        radial-gradient(circle at 100% 0%, rgba(207,232,255,.80), transparent 24%),
        var(--report-bg);
    }
    .page {
      max-width: 1280px;
      margin: 0 auto;
      padding: 28px;
      display: grid;
      gap: 16px;
    }
    .hero {
      background: linear-gradient(130deg, var(--report-primary-strong), var(--report-primary));
      color: #fff;
      border-radius: 18px;
      padding: 22px;
      box-shadow: 0 12px 30px rgba(11,79,138,.24);
      display: grid;
      gap: 10px;
    }
    .hero h1 { margin: 0; font-size: 30px; display: flex; align-items: center; gap: 10px; }
    .hero p { margin: 0; opacity: .96; }
    .hero-meta { display: flex; gap: 12px; flex-wrap: wrap; font-size: 13px; opacity: .92; }
    .hero-icon { width: 20px; height: 20px; display: inline-flex; }
    .banner {
      border-radius: 14px;
      padding: 14px 16px;
      border: 1px solid var(--report-border);
      background: var(--report-surface);
      color: var(--report-text);
    }
    .banner.good { border-color: rgba(15,118,110,.25); background: rgba(15,118,110,.08); }
    .banner.warn { border-color: rgba(180,83,9,.25); background: rgba(180,83,9,.08); }
    .banner.bad { border-color: rgba(185,28,28,.25); background: rgba(185,28,28,.08); }
    .card-grid {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 14px;
    }
    .card {
      background: var(--report-surface);
      border: 1px solid var(--report-border);
      border-radius: 16px;
      padding: 16px;
      box-shadow: 0 8px 20px rgba(31,41,55,.05);
      display: grid;
      gap: 8px;
    }
    .card h2 {
      margin: 0;
      font-size: 15px;
      color: var(--report-primary-strong);
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .card .kpi {
      font-size: 34px;
      font-weight: 700;
      line-height: 1;
      color: var(--report-primary-strong);
    }
    .card .meta {
      color: var(--report-muted);
      font-size: 13px;
    }
    .metric-list, .design-list {
      margin: 0;
      padding-left: 18px;
      color: var(--report-text);
    }
    .design-list li, .metric-list li { margin-bottom: 6px; }
    .section-grid {
      display: grid;
      grid-template-columns: 1.3fr .9fr;
      gap: 14px;
    }
    .subtle { color: var(--report-muted); }
    .badge-row { display: flex; flex-wrap: wrap; gap: 8px; }
    .badge {
      border-radius: 999px;
      padding: 4px 10px;
      border: 1px solid var(--report-border);
      background: #eef6fb;
      color: var(--report-primary-strong);
      font-size: 12px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }
    th, td {
      text-align: left;
      padding: 8px 10px;
      border-bottom: 1px solid var(--report-border);
    }
    th { color: var(--report-muted); font-weight: 600; }
    .hidden { display: none; }
    @media (max-width: 980px) {
      .card-grid, .section-grid { grid-template-columns: 1fr; }
      .hero h1 { font-size: 26px; }
      .page { padding: 18px; }
    }
  </style>
</head>
<body>
  <main class="page">
    <section class="hero">
      <h1><span class="hero-icon">$iconSvg</span>$safeTitle</h1>
      <p>$safeSubtitle</p>
      <div class="hero-meta">
        <span>Scenario: $safeScenarioName</span>
        <span>Generated: $generatedUtc</span>
        <span>Mode: __REPORT_MODE__</span>
      </div>
    </section>

    <section id="statusBanner" class="banner">Loading live report context...</section>

    <section class="card-grid" id="metricCards"></section>

    <section class="section-grid">
      <article class="card">
        <h2><span class="hero-icon">$iconSvg</span>Live Scenario Output</h2>
        <div id="metricSections" class="subtle">Query execution has not started yet.</div>
      </article>

      <article class="card" id="designSummaryCard">
        <h2><span class="hero-icon">$iconSvg</span>Design Summary</h2>
        <p>$safeProblem</p>
        <div class="badge-row" id="entityBadges"></div>
        <h3>Success Criteria</h3>
        <ul class="design-list">$designCriteria</ul>
        <h3>Operational Artifacts</h3>
        <ul class="design-list">$designArtifacts</ul>
      </article>
    </section>
  </main>

  <script>
    const reportConfig = $configJson;

    const entityBadgesHost = document.getElementById('entityBadges');
    const statusBanner = document.getElementById('statusBanner');
    const metricCardsHost = document.getElementById('metricCards');
    const metricSectionsHost = document.getElementById('metricSections');
    const designSummaryCard = document.getElementById('designSummaryCard');

    function renderEntityBadges() {
      entityBadgesHost.innerHTML = '';
      (reportConfig.entities || []).forEach((entity) => {
        const badge = document.createElement('span');
        badge.className = 'badge';
        badge.textContent = (entity.displayName || entity.logicalName) + ' (' + entity.logicalName + ')';
        entityBadgesHost.appendChild(badge);
      });
    }

    function setBanner(kind, text) {
            statusBanner.className = 'banner ' + kind;
      statusBanner.textContent = text;
    }

    function addMetricCard(title, value, meta) {
      const card = document.createElement('article');
      card.className = 'card';
            card.innerHTML = '<h2>' + title + '</h2><div class="kpi">' + value + '</div><div class="meta">' + (meta || '') + '</div>';
      metricCardsHost.appendChild(card);
    }

    function addSectionHtml(html) {
      const wrapper = document.createElement('div');
      wrapper.style.marginBottom = '14px';
      wrapper.innerHTML = html;
      metricSectionsHost.appendChild(wrapper);
    }

    function getXrmApi() {
      try {
        if (window.parent && window.parent.Xrm && window.parent.Xrm.WebApi) {
          return window.parent.Xrm.WebApi.online || window.parent.Xrm.WebApi;
        }
      } catch (err) {
      }

      if (window.Xrm && window.Xrm.WebApi) {
        return window.Xrm.WebApi.online || window.Xrm.WebApi;
      }

      return null;
    }

    function getAliasValue(record, alias) {
      const raw = record ? record[alias] : null;
      if (raw === null || raw === undefined) {
        return null;
      }
      if (typeof raw === 'object') {
        if (raw.Value !== undefined && raw.Value !== null) {
          return raw.Value;
        }
        if (raw.value !== undefined && raw.value !== null) {
          return raw.value;
        }
      }
      return raw;
    }

    function getFormattedValue(record, alias) {
            return record?.[alias + '@OData.Community.Display.V1.FormattedValue'] || String(getAliasValue(record, alias) ?? '');
    }

    async function executeFetch(query) {
      const api = getXrmApi();
      if (!api || typeof api.retrieveMultipleRecords !== 'function') {
        throw new Error('Dataverse client API is unavailable in this host.');
      }
            const options = '?fetchXml=' + encodeURIComponent(query.fetchXml);
      return api.retrieveMultipleRecords(query.entityLogicalName, options);
    }

    function renderZeroState(reasonText) {
      metricCardsHost.innerHTML = '';
      metricSectionsHost.innerHTML = '';
      addMetricCard('Operational Records', '0', 'No scenario records exist yet.');
      addMetricCard('Report Scope', reportConfig.scenario.primaryEntityDisplayName || reportConfig.scenario.scenarioName, 'Scenario design is ready, but live records were not detected.');
      addMetricCard('Fallback Mode', reportConfig.report.mode, reasonText || reportConfig.fallbackBehavior.zeroStateMessage);
            addSectionHtml('<p class="subtle">' + reportConfig.fallbackBehavior.zeroStateMessage + '</p>');
      designSummaryCard.classList.toggle('hidden', !reportConfig.fallbackBehavior.includeDesignSummaryWhenNoData);
      setBanner('warn', reportConfig.fallbackBehavior.zeroStateMessage);
    }

    function renderMetricResult(metric, response) {
      if (metric.kind === 'aggregate-count') {
        const first = response.entities?.[0] || {};
        const value = getAliasValue(first, metric.query.valueAlias) ?? 0;
        addMetricCard(metric.title, value, metric.reason || 'Live Dataverse aggregate');
        return;
      }

      if (metric.kind === 'aggregate-group') {
        const rows = (response.entities || []).map((entity) => {
          const groupValue = getFormattedValue(entity, metric.query.groupAlias);
          const countValue = getAliasValue(entity, metric.query.valueAlias) ?? 0;
          return '<tr><td>' + (groupValue || 'Unspecified') + '</td><td>' + countValue + '</td></tr>';
        }).join('');
        addSectionHtml('<h3>' + metric.title + '</h3><table><thead><tr><th>Value</th><th>Count</th></tr></thead><tbody>' + (rows || '<tr><td colspan="2">No grouped values found.</td></tr>') + '</tbody></table>');
        return;
      }

      if (metric.kind === 'list') {
        const rows = (response.entities || []).map((entity) => {
          const nameValue = entity?.[metric.query.nameField] || 'Unnamed record';
          const dateValue = entity?.[metric.query.dateField + '@OData.Community.Display.V1.FormattedValue'] || entity?.[metric.query.dateField] || 'n/a';
          return '<tr><td>' + nameValue + '</td><td>' + dateValue + '</td></tr>';
        }).join('');
        addSectionHtml('<h3>' + metric.title + '</h3><table><thead><tr><th>Record</th><th>Timestamp</th></tr></thead><tbody>' + (rows || '<tr><td colspan="2">No records found.</td></tr>') + '</tbody></table>');
      }
    }

    async function renderLiveData() {
      metricCardsHost.innerHTML = '';
      metricSectionsHost.innerHTML = '';
      const liveMetrics = (reportConfig.metrics || []).filter((metric) => metric.enabled && metric.query);
      if (reportConfig.report.mode === 'static' || reportConfig.report.enableLiveDataverseReports !== true) {
        renderZeroState('Live data querying is disabled for this report configuration.');
        return;
      }

      if (liveMetrics.length === 0) {
        renderZeroState('No live Dataverse queries were enabled for this scenario report.');
        return;
      }

      const summaryMetric = liveMetrics.find((metric) => metric.key === 'total-records');
      let summaryCount = 0;

      try {
        for (const metric of liveMetrics) {
          const response = await executeFetch(metric.query);
          if (metric.key === 'total-records') {
            const first = response.entities?.[0] || {};
            summaryCount = Number(getAliasValue(first, metric.query.valueAlias) ?? 0);
          }
          renderMetricResult(metric, response);
        }

        if (summaryMetric && summaryCount === 0) {
          renderZeroState(reportConfig.fallbackBehavior.zeroStateMessage);
          return;
        }

        setBanner('good', 'Live Dataverse data loaded for ' + reportConfig.report.title + '.');
        if (summaryCount > 0) {
          designSummaryCard.classList.toggle('hidden', !reportConfig.fallbackBehavior.includeDesignSummaryWhenNoData && reportConfig.report.mode === 'live');
        }
      } catch (error) {
        renderZeroState(error.message || 'Live Dataverse query failed.');
      }
    }

    renderEntityBadges();
    renderLiveData();
  </script>
</body>
</html>
"@.Replace('__REPORT_MODE__', (ConvertTo-HtmlSafeText $ReportConfig.report.mode))
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$specsRoot = Join-Path $repoRoot 'specs'

$telemetryHelper = Join-Path $PSScriptRoot 'helpers\wizard-telemetry.ps1'
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName '65-build-web-resources.ps1'
}

$hardeningHelper = Join-Path $PSScriptRoot 'helpers\wizard-hardening.ps1'
if (Test-Path $hardeningHelper) {
    . $hardeningHelper
}

$envFile = Join-Path $repoRoot '.env.ps1'
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl) -and -not $PreviewReportQueriesOnly) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    $AccessToken = $global:DV_TOKEN
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { $SolutionUniqueName = $global:DV_SOLUTION_NAME }
    if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) { $PublisherPrefix = $global:DV_PUBLISHER_PREFIX }
}

if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    $scenarioFolders = @(Get-ChildItem -Path $specsRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($scenarioFolders.Count -eq 1) {
        $ScenarioSlug = $scenarioFolders[0].Name
    }
    elseif ($scenarioFolders.Count -gt 1) {
        Write-Host 'Available scenarios:' -ForegroundColor Cyan
        $scenarioFolders | ForEach-Object { Write-Host "  - $($_.Name)" }
        $ScenarioSlug = Read-RequiredValue 'Scenario folder slug'
    }
    else {
        throw "No scenario folders found under '$specsRoot'."
    }
}

if (Get-Command Initialize-WizardArtifactManifest -ErrorAction SilentlyContinue) {
    Initialize-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix | Out-Null
}

$scenarioFolder = Join-Path $specsRoot $ScenarioSlug
$answersPath = Join-Path $scenarioFolder 'answers.md'
$specPath = Join-Path $scenarioFolder 'spec.md'
$planPath = Join-Path $scenarioFolder 'plan.md'
$outputFolder = Join-Path $scenarioFolder 'webresources'
$reportArtifactsRoot = Join-Path $scenarioFolder 'report-artifacts'
$reportConfigFolder = Join-Path $reportArtifactsRoot 'config'

if (-not (Test-Path $answersPath)) { throw "Missing scenario answers file: $answersPath" }
if (-not (Test-Path $specPath)) { throw "Missing scenario spec file: $specPath" }

$answersContent = Get-Content -Path $answersPath -Raw -Encoding UTF8
$specContent = Get-Content -Path $specPath -Raw -Encoding UTF8
$planContent = if (Test-Path $planPath) { Get-Content -Path $planPath -Raw -Encoding UTF8 } else { '' }

$scenario = Get-ScenarioDefinition -ScenarioSlugValue $ScenarioSlug -AnswersContent $answersContent -SpecContent $specContent -PlanContent $planContent
if (-not $scenario.IncludeReports) {
    Write-Host ''
    Write-Host '=== Build Report Web Resources ===' -ForegroundColor Cyan
    Write-Host "Scenario '$ScenarioSlug' has optional reports disabled. Nothing to generate." -ForegroundColor Yellow
    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message 'Optional report web resources disabled for scenario.'
    }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) {
    $publisherPrefixMatch = [regex]::Match($planContent, '(?im)^-\s*Publisher prefix:\s*([a-z0-9_]+)')
    if ($publisherPrefixMatch.Success) {
        $PublisherPrefix = $publisherPrefixMatch.Groups[1].Value.Trim()
    }
}
if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) {
    $PublisherPrefix = 'wiz'
}

$relevantEntities = Get-RelevantEntities -Scenario $scenario
$payloadMetadata = Get-PayloadMetadata -RepoRoot $repoRoot -RelevantEntities $relevantEntities -PublisherPrefixValue $PublisherPrefix
$snapshot = Get-MetadataSnapshot -Path $MetadataSnapshotPath
$canUseLiveMetadata = (-not $PreviewReportQueriesOnly) -and $EnableLiveDataverseReports -and $ReportMode -ne 'static'

if ($canUseLiveMetadata) {
    foreach ($v in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName, $PublisherPrefix)) {
        if ([string]::IsNullOrWhiteSpace($v)) {
            throw 'Missing required values. Run 10-auth-connect.ps1 first, or use -PreviewReportQueriesOnly for offline preview.'
        }
    }
}

$entityMetadataMap = Resolve-EntityMetadataMap -Scenario $scenario -PayloadMetadata $payloadMetadata -Snapshot $snapshot -CanUseLiveMetadata $canUseLiveMetadata
$primaryEntity = Get-PrimaryScenarioEntity -Scenario $scenario
$primaryMetadata = if (-not [string]::IsNullOrWhiteSpace($primaryEntity.LogicalName)) { $entityMetadataMap[$primaryEntity.LogicalName] } else { $null }
if ($null -ne $primaryMetadata) {
    $primaryEntity = [pscustomobject]@{
        DisplayName = $primaryEntity.DisplayName
        LogicalName = $primaryEntity.LogicalName
        RowCount    = $primaryMetadata.RowCount
    }
}

$reportDefinitions = @(Get-ScenarioReportDefinitions -Scenario $scenario -PrimaryEntity $primaryEntity)

Write-Host ''
Write-Host '=== Build Report Web Resources ===' -ForegroundColor Cyan
Write-Host "  Scenario:    $ScenarioSlug"
Write-Host "  Mode:        $ReportMode"
Write-Host "  PreviewOnly: $([bool]$PreviewReportQueriesOnly)"
if ($canUseLiveMetadata) {
    Write-Host "  Environment: $EnvironmentUrl"
    Write-Host "  Solution:    $SolutionUniqueName"
}
Write-Host ''

New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
New-Item -ItemType Directory -Path $reportArtifactsRoot -Force | Out-Null
New-Item -ItemType Directory -Path $reportConfigFolder -Force | Out-Null

$validationReports = New-Object System.Collections.Generic.List[object]
$queryPreview = New-Object System.Collections.Generic.List[object]
$created = 0
$updated = 0
$addedToSolution = 0
$skippedSolution = 0
$failed = 0
$webResourceComponentType = 61
$solution = $null

if ($canUseLiveMetadata -and -not $PreviewReportQueriesOnly) {
    $webResourceComponentType = Get-WebResourceComponentType
    $solution = (Invoke-Dv 'Get' "solutions?`$filter=uniquename eq '$SolutionUniqueName'&`$select=solutionid,uniquename").value | Select-Object -First 1
    if ($null -eq $solution) {
        throw "Solution '$SolutionUniqueName' was not found in this environment."
    }
}

foreach ($report in $reportDefinitions) {
    $metricCandidates = @(Get-MetricCandidates -Scenario $scenario -Report $report -PrimaryEntity $primaryEntity)
    $resolvedMetrics = @($metricCandidates | ForEach-Object { Resolve-MetricCandidate -Metric $_ -MetadataMap $entityMetadataMap })

    $missingEntities = New-Object System.Collections.Generic.List[string]
    $missingFields = New-Object System.Collections.Generic.List[string]
    foreach ($metric in $resolvedMetrics) {
        foreach ($entityName in @($metric.MissingEntities)) {
            if (-not $missingEntities.Contains($entityName)) {
                $missingEntities.Add($entityName)
            }
        }
        foreach ($fieldName in @($metric.MissingFields)) {
            if (-not $missingFields.Contains($fieldName)) {
                $missingFields.Add($fieldName)
            }
        }
    }

    $reportEntities = New-Object System.Collections.Generic.List[object]
    foreach ($displayName in @($scenario.RequiredEntityDisplayNames)) {
        $logicalName = ConvertToLogicalName ($scenario.EntityMap[$displayName])
        if ([string]::IsNullOrWhiteSpace($logicalName)) {
            continue
        }
        $metadata = $entityMetadataMap[$logicalName]
        $reportEntities.Add([pscustomobject]@{
            DisplayName          = $displayName
            LogicalName          = $logicalName
            Exists               = if ($null -ne $metadata) { [bool]$metadata.Exists } else { $false }
            Source               = if ($null -ne $metadata) { $metadata.Source } else { 'unresolved' }
            PrimaryIdAttribute   = if ($null -ne $metadata) { $metadata.PrimaryIdAttribute } else { '' }
            PrimaryNameAttribute = if ($null -ne $metadata) { $metadata.PrimaryNameAttribute } else { '' }
        })
        if (($null -eq $metadata -or -not $metadata.Exists) -and -not $missingEntities.Contains($logicalName)) {
            $missingEntities.Add($logicalName)
        }
    }

    $seedDataDetected = ($null -ne $primaryMetadata -and $primaryMetadata.RowCount -gt 0)
    $seedDataStatus = if ($seedDataDetected) {
        'detected'
    }
    elseif ($scenario.DemoDataRequired) {
        'planned-no-data'
    }
    else {
        'not-planned-or-unknown'
    }

    $reportConfig = [ordered]@{
        scenario = [ordered]@{
            scenarioSlug             = $scenario.ScenarioSlug
            scenarioName             = $scenario.ScenarioName
            primaryEntityLogicalName = $primaryEntity.LogicalName
            primaryEntityDisplayName = $primaryEntity.DisplayName
            problemStatement         = $scenario.ProblemStatement
            targetAudience           = $scenario.TargetAudience
            users                    = $scenario.Users
            roles                    = @($scenario.Roles)
            successCriteria          = @($scenario.SuccessCriteria)
            operationalArtifacts     = @($scenario.Artifacts)
            demoDataRequired         = [bool]$scenario.DemoDataRequired
        }
        report = [ordered]@{
            key                        = $report.Key
            title                      = $report.Title
            subtitle                   = $report.Subtitle
            purpose                    = $report.Purpose
            audience                   = $report.Audience
            mode                       = $ReportMode
            enableLiveDataverseReports = [bool]$EnableLiveDataverseReports
            previewOnly                = [bool]$PreviewReportQueriesOnly
        }
        entities = @($reportEntities | ForEach-Object {
            [ordered]@{
                displayName          = $_.DisplayName
                logicalName          = $_.LogicalName
                exists               = [bool]$_.Exists
                source               = $_.Source
                primaryIdAttribute   = $_.PrimaryIdAttribute
                primaryNameAttribute = $_.PrimaryNameAttribute
            }
        })
        fields = @($resolvedMetrics | Where-Object { $_.Enabled -and $null -ne $_.Query } | ForEach-Object {
            foreach ($field in @($_.Query.FieldsUsed)) {
                [ordered]@{
                    entityLogicalName = $_.EntityLogicalName
                    fieldLogicalName  = $field
                    metricKey         = $_.Key
                }
            }
        })
        metrics = @($resolvedMetrics | ForEach-Object {
            [ordered]@{
                key             = $_.Key
                title           = $_.Title
                kind            = $_.Kind
                entityLogicalName = $_.EntityLogicalName
                enabled         = [bool]$_.Enabled
                optional        = [bool]$_.Optional
                reason          = $_.Reason
                skipReason      = $_.SkipReason
                missingEntities = @($_.MissingEntities)
                missingFields   = @($_.MissingFields)
                query           = $_.Query
            }
        })
        queries = @($resolvedMetrics | Where-Object { $_.Enabled -and $null -ne $_.Query } | ForEach-Object { $_.Query })
        fallbackBehavior = [ordered]@{
            zeroStateMessage               = if ($scenario.DemoDataRequired) { 'No operational records yet. Demo data is planned for this scenario, but none was detected in the current environment.' } else { 'No operational records yet for this scenario in the current environment.' }
            includeDesignSummaryWhenNoData = [bool]$IncludeDesignSummaryWhenNoData
            designSummaryLabel             = 'Scenario design summary'
            seedDataStatus                 = $seedDataStatus
            seedDataDetected               = [bool]$seedDataDetected
        }
        validation = [ordered]@{
            metadataSource     = if ($snapshot.Count -gt 0) { 'snapshot' } elseif ($canUseLiveMetadata) { 'live' } else { 'design' }
            missingEntities    = @($missingEntities)
            missingFields      = @($missingFields)
            enabledMetricCount = @($resolvedMetrics | Where-Object { $_.Enabled }).Count
            skippedMetricCount = @($resolvedMetrics | Where-Object { -not $_.Enabled }).Count
            seedDataDetected   = [bool]$seedDataDetected
            seedDataStatus     = $seedDataStatus
        }
    }

    $reportConfigPath = Join-Path $reportConfigFolder "$($ScenarioSlug)-$($report.Key)-report.config.json"
    $reportConfig | ConvertTo-Json -Depth 20 | Set-Content -Path $reportConfigPath -Encoding UTF8

    $html = New-ReportHtml -Scenario $scenario -Report $report -ReportConfig $reportConfig
    $fileName = "$ScenarioSlug-$($report.Key)-report.html"
    $filePath = Join-Path $outputFolder $fileName
    Set-Content -Path $filePath -Value $html -Encoding UTF8

    $queryPreview.Add([pscustomobject]@{
        ReportKey = $report.Key
        FileName  = $fileName
        Queries   = @($reportConfig.queries)
    })

    $requiredMetricFailures = @($resolvedMetrics | Where-Object { -not $_.Enabled -and -not $_.Optional })
    $requiredMissingEntities = @($requiredMetricFailures | Where-Object { @($_.MissingEntities).Count -gt 0 })
    $requiredMissingFields = @($requiredMetricFailures | Where-Object { @($_.MissingFields).Count -gt 0 })
    $hasValidationFailure = ($FailIfReportEntitiesMissing -and $requiredMissingEntities.Count -gt 0) -or ($FailIfReportFieldsMissing -and $requiredMissingFields.Count -gt 0)
    $validationReports.Add([pscustomobject]@{
        ReportKey        = $report.Key
        Title            = $report.Title
        ConfigPath       = $reportConfigPath
        HtmlPath         = $filePath
        MissingEntities  = @($missingEntities)
        MissingFields    = @($missingFields)
        EnabledMetrics   = @($resolvedMetrics | Where-Object { $_.Enabled } | ForEach-Object { $_.Key })
        SkippedMetrics   = @($resolvedMetrics | Where-Object { -not $_.Enabled } | ForEach-Object { [pscustomobject]@{ key = $_.Key; reason = $_.SkipReason } })
        SeedDataStatus   = $seedDataStatus
        SeedDataDetected = [bool]$seedDataDetected
        ValidationFailed = [bool]$hasValidationFailure
    })

    if ($hasValidationFailure) {
        $failed++
        if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'webresource' -Name "$($PublisherPrefix.ToLowerInvariant())_reports/$fileName" -Status 'failed' -Step '65-build-web-resources.ps1' -Details @{ reportKey = $report.Key; reason = 'validation failed' } | Out-Null
        }
        Write-Host "  $($report.Key) (validation failed)" -ForegroundColor Red
        continue
    }

    if ($PreviewReportQueriesOnly) {
        if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'webresource' -Name "$($PublisherPrefix.ToLowerInvariant())_reports/$fileName" -Status 'skipped' -Step '65-build-web-resources.ps1' -Details @{ reportKey = $report.Key; reason = 'preview only' } | Out-Null
        }
        Write-Host "  $($report.Key) (preview generated)" -ForegroundColor Green
        continue
    }

    $webResourceName = "$($PublisherPrefix.ToLowerInvariant())_reports/$fileName"
    try {
        $webResourceResult = Set-DataverseWebResource -Name $webResourceName -DisplayName $report.Title -Description "Generated by 65-build-web-resources.ps1 for scenario '$ScenarioSlug'." -Content $html -WebResourceType 1 -ComponentType $webResourceComponentType -TargetSolutionUniqueName $SolutionUniqueName
        if ($webResourceResult.Status -eq 'created') { $created++ } else { $updated++ }
        if ($webResourceResult.AddedToSolution) { $addedToSolution++ }
        if ($webResourceResult.SkippedInSolution) { $skippedSolution++ }
        if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'webresource' -Name $webResourceName -Status $webResourceResult.Status -Step '65-build-web-resources.ps1' -Details @{ reportKey = $report.Key; addedToSolution = $webResourceResult.AddedToSolution; skippedInSolution = $webResourceResult.SkippedInSolution } | Out-Null
        }
        Write-Host "  $webResourceName ($($webResourceResult.Status))" -ForegroundColor $(if ($webResourceResult.Status -eq 'created') { 'Green' } else { 'DarkGray' })
    }
    catch {
        $failed++
        if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'webresource' -Name $webResourceName -Status 'failed' -Step '65-build-web-resources.ps1' -Details @{ reportKey = $report.Key; error = $_.Exception.Message } | Out-Null
        }
        Write-Host "  $($report.Key) (FAILED: $($_.Exception.Message))" -ForegroundColor Red
    }
}

$queryPreviewPath = Join-Path $reportArtifactsRoot 'query-preview.json'
$queryPreview | ConvertTo-Json -Depth 20 | Set-Content -Path $queryPreviewPath -Encoding UTF8

$validationArtifact = [ordered]@{
    generatedUtc                   = [DateTime]::UtcNow.ToString('o')
    scenarioSlug                   = $ScenarioSlug
    scenarioName                   = $scenario.ScenarioName
    reportMode                     = $ReportMode
    previewOnly                    = [bool]$PreviewReportQueriesOnly
    enableLiveDataverseReports     = [bool]$EnableLiveDataverseReports
    failIfReportEntitiesMissing    = [bool]$FailIfReportEntitiesMissing
    failIfReportFieldsMissing      = [bool]$FailIfReportFieldsMissing
    includeDesignSummaryWhenNoData = [bool]$IncludeDesignSummaryWhenNoData
    metadataSnapshotPath           = $MetadataSnapshotPath
    reports                        = $validationReports.ToArray()
}
$validationPath = Join-Path $reportArtifactsRoot 'report-validation.json'
$validationArtifact | ConvertTo-Json -Depth 20 | Set-Content -Path $validationPath -Encoding UTF8

Write-Host ''
if ($PreviewReportQueriesOnly) {
    Write-Host 'Preview artifacts generated.' -ForegroundColor Green
}
else {
    Write-Host "Reports generated — created: $created  updated: $updated  failed: $failed"
    Write-Host "Solution components — added: $addedToSolution  skipped: $skippedSolution"
}
Write-Host "HTML output folder: $outputFolder"
Write-Host "Config artifacts:   $reportConfigFolder"
Write-Host "Validation report:  $validationPath"
Write-Host "Query preview:      $queryPreviewPath"

if ($failed -gt 0 -or @($validationReports | Where-Object { $_.ValidationFailed }).Count -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message 'Web resource build failed validation or upload.'
    }
    exit 1
}

if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message 'Web resource build completed.'
}

exit 0
