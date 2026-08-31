<#
=============================================================================
COMPONENT:    Solution Isolation Helper
FILE:         scripts/bootstrap/helpers/solution-isolation.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Solution Scope Enforcement

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Provides helper functions that keep generated artifacts and solution operations
scoped to the approved scenario entities.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            helper module
- Inputs:          entity names, solution metadata, and scenario mappings
- Outputs:         filtered or normalized scope data for callers
- Dependencies:    PowerShell runtime and repo scenario conventions
- Side Effects:    none beyond returned helper results

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Load this helper from scripts that enforce scenario or solution scope.
2. Provide entity metadata in the repo's expected shapes.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ In-scope entities are retained in helper output.
✔ Out-of-scope entities are excluded consistently.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Keep scope enforcement deterministic and reviewable.
- Do not broaden solution scope beyond approved mappings.
- Update this header when the helper contract materially changes.
=============================================================================
#>

function Add-EntityName {
    param(
        [System.Collections.Generic.HashSet[string]]$Set,
        [string]$Name
    )

    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        [void]$Set.Add($Name.Trim().ToLowerInvariant())
    }
}

function Get-OptionalPropertyValue {
    param(
        [object]$InputObject,
        [string]$PropertyName
    )

    if ($null -eq $InputObject) {
        return $null
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-PayloadEntityNames {
    param([string]$Folder)

    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    $tableFiles = @(Get-ChildItem -Path $Folder -Filter "table-*.json" -ErrorAction SilentlyContinue)
    foreach ($file in $tableFiles) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $entityDefinition = Get-OptionalPropertyValue -InputObject $doc -PropertyName 'EntityDefinition'
        $schemaName = (Get-OptionalPropertyValue -InputObject $entityDefinition -PropertyName 'LogicalName') ??
            (Get-OptionalPropertyValue -InputObject $entityDefinition -PropertyName 'SchemaName') ??
            (Get-OptionalPropertyValue -InputObject $doc -PropertyName 'LogicalName') ??
            (Get-OptionalPropertyValue -InputObject $doc -PropertyName 'SchemaName')
        Add-EntityName -Set $names -Name $schemaName
    }

    $columnFiles = @(Get-ChildItem -Path $Folder -Filter "columns-*.json" -ErrorAction SilentlyContinue)
    foreach ($file in $columnFiles) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        Add-EntityName -Set $names -Name (Get-OptionalPropertyValue -InputObject $doc -PropertyName 'TableLogicalName')
    }

    $relationshipFiles = @(Get-ChildItem -Path $Folder -Filter "relationships-*.json" -ErrorAction SilentlyContinue)
    foreach ($file in $relationshipFiles) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $rels = @((Get-OptionalPropertyValue -InputObject $doc -PropertyName 'Relationships') ?? $doc)
        foreach ($rel in $rels) {
            $relationshipDefinition = Get-OptionalPropertyValue -InputObject $rel -PropertyName 'RelationshipDefinition'
            Add-EntityName -Set $names -Name ((Get-OptionalPropertyValue -InputObject $rel -PropertyName 'ReferencedEntity') ?? (Get-OptionalPropertyValue -InputObject $relationshipDefinition -PropertyName 'ReferencedEntity'))
            Add-EntityName -Set $names -Name ((Get-OptionalPropertyValue -InputObject $rel -PropertyName 'ReferencingEntity') ?? (Get-OptionalPropertyValue -InputObject $relationshipDefinition -PropertyName 'ReferencingEntity'))
            Add-EntityName -Set $names -Name ((Get-OptionalPropertyValue -InputObject $rel -PropertyName 'Entity1LogicalName') ?? (Get-OptionalPropertyValue -InputObject $relationshipDefinition -PropertyName 'Entity1LogicalName'))
            Add-EntityName -Set $names -Name ((Get-OptionalPropertyValue -InputObject $rel -PropertyName 'Entity2LogicalName') ?? (Get-OptionalPropertyValue -InputObject $relationshipDefinition -PropertyName 'Entity2LogicalName'))
        }
    }

    return @($names | Sort-Object)
}

function ConvertTo-DvRelativePath {
    param([string]$NextLink)

    if ([string]::IsNullOrWhiteSpace($NextLink)) {
        return ""
    }

    if ($NextLink -notmatch '^(?i)https?://') {
        return $NextLink
    }

    $marker = '/api/data/v9.2/'
    $index = $NextLink.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) {
        return $NextLink
    }

    return $NextLink.Substring($index + $marker.Length)
}

function Invoke-SolutionIsolationPagedGet {
    param(
        [scriptblock]$InvokeGet,
        [string]$Path
    )

    $items = New-Object 'System.Collections.Generic.List[object]'
    $nextPath = $Path

    while (-not [string]::IsNullOrWhiteSpace($nextPath)) {
        $page = & $InvokeGet $nextPath
        foreach ($item in @($page.value)) {
            [void]$items.Add($item)
        }

        $nextPath = ConvertTo-DvRelativePath -NextLink (Get-OptionalPropertyValue -InputObject $page -PropertyName '@odata.nextLink')
    }

    return $items.ToArray()
}

function Get-EntityDefinitionByLogicalName {
    param(
        [scriptblock]$InvokeGet,
        [string]$LogicalName
    )

    if ([string]::IsNullOrWhiteSpace($LogicalName)) {
        return $null
    }

    try {
        return & $InvokeGet "EntityDefinitions(LogicalName='$LogicalName')?`$select=LogicalName,MetadataId"
    } catch {
        return $null
    }
}

function Get-EntityDefinitionByMetadataId {
    param(
        [scriptblock]$InvokeGet,
        [string]$MetadataId
    )

    if ([string]::IsNullOrWhiteSpace($MetadataId)) {
        return $null
    }

    try {
        return & $InvokeGet "EntityDefinitions($MetadataId)?`$select=LogicalName,MetadataId"
    } catch {
        return $null
    }
}

function Get-SolutionTableIsolationReport {
    param(
        [scriptblock]$InvokeGet,
        [string]$SolutionId,
        [string[]]$ExpectedEntityNames
    )

    $expectedSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @($ExpectedEntityNames)) {
        Add-EntityName -Set $expectedSet -Name $name
    }

    $currentTables = New-Object 'System.Collections.Generic.List[object]'
    $metadataCache = @{}
    $components = @(Invoke-SolutionIsolationPagedGet -InvokeGet $InvokeGet -Path "solutioncomponents?`$select=solutioncomponentid,objectid,_solutionid_value,componenttype&`$filter=componenttype eq 1")

    foreach ($component in $components) {
        if (("$($component._solutionid_value)").Trim().ToLowerInvariant() -ne $SolutionId.Trim().ToLowerInvariant()) {
            continue
        }

        $metadataId = ("$($component.objectid)").Trim()
        if ([string]::IsNullOrWhiteSpace($metadataId)) {
            continue
        }

        if (-not $metadataCache.ContainsKey($metadataId)) {
            $metadataCache[$metadataId] = Get-EntityDefinitionByMetadataId -InvokeGet $InvokeGet -MetadataId $metadataId
        }

        $logicalName = $metadataCache[$metadataId].LogicalName
        if ([string]::IsNullOrWhiteSpace($logicalName)) {
            $logicalName = "[metadata:$metadataId]"
        }

        [void]$currentTables.Add([pscustomobject]@{
            LogicalName         = $logicalName.Trim().ToLowerInvariant()
            MetadataId          = $metadataId.ToLowerInvariant()
            SolutionComponentId = ("$($component.solutioncomponentid)").Trim()
        })
    }

    $dedupedCurrent = @($currentTables | Sort-Object LogicalName, SolutionComponentId -Unique)
    $foreignTables = @($dedupedCurrent | Where-Object { -not $expectedSet.Contains($_.LogicalName) })

    return [pscustomobject]@{
        ExpectedTables = @($expectedSet | Sort-Object)
        CurrentTables  = $dedupedCurrent
        ForeignTables  = @($foreignTables | Sort-Object LogicalName)
    }
}

function Invoke-SolutionTableCleanup {
    param(
        [scriptblock]$InvokePost,
        [object[]]$ForeignTables,
        [string]$SolutionUniqueName,
        [switch]$Apply
    )

    $results = New-Object 'System.Collections.Generic.List[object]'

    foreach ($table in @($ForeignTables)) {
        $body = @{
            SolutionComponent = @{
                '@odata.type'      = 'Microsoft.Dynamics.CRM.solutioncomponent'
                solutioncomponentid = $table.SolutionComponentId
            }
            ComponentType      = 1
            SolutionUniqueName = $SolutionUniqueName
        } | ConvertTo-Json -Depth 5 -Compress

        if ($Apply) {
            & $InvokePost 'RemoveSolutionComponent' $body | Out-Null
            $status = 'Removed'
        } else {
            $status = 'WouldRemove'
        }

        [void]$results.Add([pscustomobject]@{
            LogicalName         = $table.LogicalName
            MetadataId          = $table.MetadataId
            SolutionComponentId = $table.SolutionComponentId
            Status              = $status
            RequestBody         = $body
        })
    }

    return $results.ToArray()
}

function ConvertTo-SolutionInventoryCategory {
    param([string]$Kind)

    $aliases = @{
        table = 'tables'
        column = 'columns'
        relationship = 'relationships'
        form = 'forms'
        view = 'views'
        appmodule = 'model-driven-apps'
        'model-driven-app' = 'model-driven-apps'
        sitemap = 'sitemap-updates'
        webresource = 'web-resources'
        dashboard = 'dashboards'
        chart = 'charts'
        flow = 'flows'
        bpf = 'flows'
    }

    $normalized = ("$Kind").Trim().ToLowerInvariant()
    if ($aliases.ContainsKey($normalized)) {
        return $aliases[$normalized]
    }
    return $normalized
}

function New-SolutionMembershipReport {
    param(
        [hashtable]$ExpectedByCategory,
        [object[]]$CurrentInventory = @(),
        [object[]]$FailedArtifacts = @(),
        [string[]]$MandatoryCategories = @('tables', 'columns', 'relationships', 'forms', 'views', 'model-driven-apps', 'sitemap-updates', 'web-resources', 'dashboards', 'charts'),
        [string[]]$OptionalCategories = @('flows'),
        [switch]$Strict
    )

    $categories = @($MandatoryCategories + $OptionalCategories | Select-Object -Unique)
    $items = [System.Collections.Generic.List[object]]::new()
    $matchedCurrentKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($category in $categories) {
        $expectedNames = if ($ExpectedByCategory.ContainsKey($category)) { @($ExpectedByCategory[$category]) } else { @() }
        foreach ($expectedName in @($expectedNames | Where-Object { -not [string]::IsNullOrWhiteSpace("$_") } | Sort-Object -Unique)) {
            $matches = @($CurrentInventory | Where-Object {
                (ConvertTo-SolutionInventoryCategory -Kind $_.Category) -eq $category -and
                ("$($_.Name)").Trim().Equals(("$expectedName").Trim(), [System.StringComparison]::OrdinalIgnoreCase)
            })
            $failures = @($FailedArtifacts | Where-Object {
                (ConvertTo-SolutionInventoryCategory -Kind $_.Kind) -eq $category -and
                ("$($_.Name)").Trim().Equals(("$expectedName").Trim(), [System.StringComparison]::OrdinalIgnoreCase)
            })
            $match = $matches | Select-Object -First 1
            $matchState = Get-OptionalPropertyValue -InputObject $match -PropertyName 'State'
            $state = if ($failures.Count -gt 0) { 'Failed' } elseif ($null -eq $match) { 'Missing' } elseif ($matchState -eq 'Added') { 'Added' } else { 'Already in solution' }
            $failureReason = if ($failures.Count -eq 0) {
                ''
            } else {
                (Get-OptionalPropertyValue -InputObject $failures[0] -PropertyName 'Reason') ??
                    (Get-OptionalPropertyValue -InputObject $failures[0] -PropertyName 'Error') ??
                    'artifact build failed'
            }
            if ($null -ne $match) {
                [void]$matchedCurrentKeys.Add("$category|$($match.SolutionComponentId)")
            }
            [void]$items.Add([pscustomobject]@{
                Category = $category
                Name = "$expectedName"
                ObjectId = if ($null -eq $match) { '' } else { "$($match.ObjectId)" }
                SolutionComponentId = if ($null -eq $match) { '' } else { "$($match.SolutionComponentId)" }
                ComponentType = if ($null -eq $match) { $null } else { $match.ComponentType }
                State = $state
                Required = $category -in $MandatoryCategories
                Reason = "$failureReason"
            })
        }
    }

    $unauthorized = @($CurrentInventory | Where-Object {
        $category = ConvertTo-SolutionInventoryCategory -Kind $_.Category
        $category -in $categories -and -not $matchedCurrentKeys.Contains("$category|$($_.SolutionComponentId)")
    } | ForEach-Object {
        [pscustomobject]@{
            Category = ConvertTo-SolutionInventoryCategory -Kind $_.Category
            Name = "$($_.Name)"
            ObjectId = "$($_.ObjectId)"
            SolutionComponentId = "$($_.SolutionComponentId)"
            ComponentType = $_.ComponentType
            State = 'Unauthorized'
            Required = $false
            Reason = 'Present in the solution but absent from the approved expected-artifact set.'
        }
    })
    foreach ($entry in $unauthorized) { [void]$items.Add($entry) }

    $blocking = @($items | Where-Object {
        ($_.Required -and $_.State -in @('Missing', 'Failed')) -or ($Strict -and $_.State -eq 'Unauthorized')
    })
    $counts = [ordered]@{}
    foreach ($state in @('Added', 'Already in solution', 'Failed', 'Missing', 'Unauthorized')) {
        $counts[$state] = @($items | Where-Object State -eq $state).Count
    }

    return [pscustomobject]@{
        GeneratedAtUtc = [DateTime]::UtcNow.ToString('o')
        Strict = [bool]$Strict
        Categories = $categories
        Items = @($items.ToArray())
        Counts = [pscustomobject]$counts
        ExportAllowed = $blocking.Count -eq 0
        BlockingItems = $blocking
    }
}

function ConvertTo-SolutionExpectedCategoryMap {
    param([object]$ExpectedArtifacts)

    return @{
        tables = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'Tables'))
        columns = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'Columns'))
        relationships = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'Relationships'))
        forms = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'Forms'))
        views = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'Views'))
        'model-driven-apps' = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'AppModules'))
        'sitemap-updates' = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'SiteMaps'))
        'web-resources' = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'WebResources'))
        dashboards = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'Dashboards'))
        charts = @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'Charts'))
        flows = @(
            @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'Bpfs')) +
            @((Get-OptionalPropertyValue -InputObject $ExpectedArtifacts -PropertyName 'Flows'))
        )
    }
}

function Write-SolutionMembershipReport {
    param(
        [object]$Report,
        [string]$JsonPath,
        [string]$MarkdownPath
    )

    foreach ($path in @($JsonPath, $MarkdownPath)) {
        $folder = Split-Path $path -Parent
        if (-not [string]::IsNullOrWhiteSpace($folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }
    }
    $Report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $JsonPath -Encoding UTF8

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Solution Membership Report') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Generated UTC: $($Report.GeneratedAtUtc)") | Out-Null
    $lines.Add("- Strict isolation: $($Report.Strict)") | Out-Null
    $lines.Add("- Export allowed: $($Report.ExportAllowed)") | Out-Null
    foreach ($state in @('Added', 'Already in solution', 'Failed', 'Missing', 'Unauthorized')) {
        $lines.Add("- ${state}: $($Report.Counts.$state)") | Out-Null
    }
    foreach ($category in @($Report.Categories)) {
        $lines.Add('') | Out-Null
        $lines.Add("## $category") | Out-Null
        $categoryItems = @($Report.Items | Where-Object Category -eq $category | Sort-Object Name, State)
        if ($categoryItems.Count -eq 0) {
            $lines.Add('- none') | Out-Null
            continue
        }
        foreach ($item in $categoryItems) {
            $idText = if ([string]::IsNullOrWhiteSpace("$($item.ObjectId)")) { '' } else { "; objectId=$($item.ObjectId); solutionComponentId=$($item.SolutionComponentId)" }
            $reasonText = if ([string]::IsNullOrWhiteSpace("$($item.Reason)")) { '' } else { "; reason=$($item.Reason)" }
            $lines.Add("- [$($item.State)] $($item.Name)$idText$reasonText") | Out-Null
        }
    }
    Set-Content -LiteralPath $MarkdownPath -Value $lines -Encoding UTF8

    return [pscustomobject]@{ JsonPath = $JsonPath; MarkdownPath = $MarkdownPath }
}
