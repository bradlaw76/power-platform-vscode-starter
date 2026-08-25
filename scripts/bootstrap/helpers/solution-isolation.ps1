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
