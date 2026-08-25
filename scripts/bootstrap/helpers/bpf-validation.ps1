<#
=============================================================================
COMPONENT:    BPF Validation Helper
FILE:         scripts/bootstrap/helpers/bpf-validation.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | BPF Validation Logic

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Provides shared validation logic for business process flow inputs, mappings,
and generated artifacts.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            helper module
- Inputs:          BPF metadata, scenario mappings, and file content
- Outputs:         validation results returned to calling scripts
- Dependencies:    PowerShell runtime and repo planning conventions
- Side Effects:    none beyond returned validation data

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Load this helper from a bootstrap or test script that needs BPF checks.
2. Provide scenario artifacts consistent with repo planning rules.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Valid BPF inputs pass helper validation.
✔ Missing process-root or stage-mapping data is flagged clearly.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Keep helper behavior deterministic and side-effect free.
- Preserve alignment with planning and BPF contract rules.
- Update this header when the helper contract materially changes.
=============================================================================
#>

Set-StrictMode -Version Latest

function ConvertTo-BpfBoolean {
    param(
        $Value,
        [bool]$Default = $false
    )

    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return $Value }

    $normalized = "$Value".Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($normalized)) { return $Default }
    return @('1', 'true', 'yes', 'y') -contains $normalized
}

function Split-BpfList {
    param($Value)

    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return @($Value | ForEach-Object { "$_".Trim().ToLowerInvariant() } | Where-Object { $_ })
    }

    return @(("$Value" -split '[,;\r\n]+' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ }))
}

function New-StringHashSet {
    return ,(New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase))
}

function Add-HashSetValues {
    param(
        [System.Collections.Generic.HashSet[string]]$Set,
        [string[]]$Values
    )

    foreach ($value in @($Values)) {
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [void]$Set.Add($value.Trim().ToLowerInvariant())
        }
    }
}

function Get-MarkdownSectionLines {
    param(
        [string]$Text,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Text) -or [string]::IsNullOrWhiteSpace($Heading)) {
        return @()
    }

    $lines = $Text -split "`r?`n"
    $index = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].Trim() -eq $Heading.Trim()) {
            $index = $i
            break
        }
    }

    if ($index -lt 0) { return @() }

    $results = New-Object System.Collections.Generic.List[string]
    for ($i = $index + 1; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line -match '^#{2,6}\s+') {
            break
        }
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $results.Add($line) | Out-Null
        }
    }

    return $results.ToArray()
}

function Get-ScenarioArtifactPaths {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug
    )

    $scenarioFolder = Join-Path (Join-Path $RepoRoot 'specs') $ScenarioSlug
    return [ordered]@{
        ScenarioFolder = $scenarioFolder
        AnswersPath    = Join-Path $scenarioFolder 'answers.md'
        SpecPath       = Join-Path $scenarioFolder 'spec.md'
        PlanPath       = Join-Path $scenarioFolder 'plan.md'
        TasksPath      = Join-Path $scenarioFolder 'tasks.md'
    }
}

function Get-ScenarioPayloadFolder {
    param(
        [string]$RepoRoot,
        [string]$PayloadsFolder,
        [string]$ScenarioSlug
    )

    if (-not [string]::IsNullOrWhiteSpace($PayloadsFolder) -and (Test-Path $PayloadsFolder)) {
        $processFiles = @(Get-ChildItem -Path $PayloadsFolder -Filter 'process-*.json' -ErrorAction SilentlyContinue)
        if ($processFiles.Count -gt 0) {
            return $PayloadsFolder
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ScenarioSlug)) {
        $scenarioFolder = Join-Path (Join-Path $RepoRoot 'payloads\scenarios') $ScenarioSlug
        if (Test-Path $scenarioFolder) {
            return $scenarioFolder
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($PayloadsFolder) -and (Test-Path $PayloadsFolder)) {
        return $PayloadsFolder
    }

    return Join-Path $RepoRoot 'payloads'
}

function Get-PlanningArtifactContent {
    param([string[]]$Paths)

    $content = New-Object System.Collections.Generic.List[string]
    foreach ($path in @($Paths)) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path $path)) {
            $content.Add((Get-Content -Path $path -Raw -Encoding UTF8)) | Out-Null
        }
    }

    return ($content -join "`n")
}

function Get-PlannedTableLogicalNames {
    param(
        [string]$ArtifactText,
        [string]$Heading
    )

    $set = New-StringHashSet
    foreach ($line in @(Get-MarkdownSectionLines -Text $ArtifactText -Heading $Heading)) {
        if ($line -match '->\s*([a-z0-9_]+)') {
            [void]$set.Add($Matches[1].Trim().ToLowerInvariant())
        }
    }

    return $set
}

function Get-PlannedFieldsByEntity {
    param([string]$ArtifactText)

    $map = @{}
    foreach ($line in @(Get-MarkdownSectionLines -Text $ArtifactText -Heading '### Standard fields reused')) {
        foreach ($match in [regex]::Matches($line, '([a-z0-9_]+)\.([a-z0-9_]+)', 'IgnoreCase')) {
            $entity = $match.Groups[1].Value.Trim().ToLowerInvariant()
            $field = $match.Groups[2].Value.Trim().ToLowerInvariant()
            if (-not $map.ContainsKey($entity)) {
                $map[$entity] = New-StringHashSet
            }
            [void]$map[$entity].Add($field)
        }
    }

    return $map
}

function Get-RelationshipIndex {
    param([string]$PayloadFolder)

    $relationships = New-Object System.Collections.Generic.List[object]
    $files = @(Get-ChildItem -Path $PayloadFolder -Filter 'relationships-*.json' -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $items = @($doc.Relationships ?? $doc)
        foreach ($item in $items) {
            $definition = $item.RelationshipDefinition ?? $item
            $schemaName = ($item.SchemaName ?? $definition.SchemaName ?? '').Trim().ToLowerInvariant()
            $referencingEntity = ($definition.ReferencingEntity ?? '').Trim().ToLowerInvariant()
            $referencedEntity = ($definition.ReferencedEntity ?? '').Trim().ToLowerInvariant()
            $relationships.Add([pscustomobject]@{
                SchemaName        = $schemaName
                ReferencingEntity = $referencingEntity
                ReferencedEntity  = $referencedEntity
                SourceFile        = $file.FullName
            }) | Out-Null
        }
    }

    return $relationships.ToArray()
}

function Get-PayloadEntityAndFieldIndex {
    param(
        [string]$PayloadFolder,
        [string]$ArtifactText
    )

    $entities = New-StringHashSet
    $fieldsByEntity = @{}

    foreach ($logicalName in @(Get-PlannedTableLogicalNames -ArtifactText $ArtifactText -Heading '### Standard reused tables (display -> logical)')) {
        [void]$entities.Add($logicalName)
    }
    foreach ($logicalName in @(Get-PlannedTableLogicalNames -ArtifactText $ArtifactText -Heading '### Custom tables to create (input -> generated logical)')) {
        [void]$entities.Add($logicalName)
    }

    $plannedFields = Get-PlannedFieldsByEntity -ArtifactText $ArtifactText
    foreach ($entityName in $plannedFields.Keys) {
        if (-not $fieldsByEntity.ContainsKey($entityName)) {
            $fieldsByEntity[$entityName] = New-StringHashSet
        }
        Add-HashSetValues -Set $fieldsByEntity[$entityName] -Values @($plannedFields[$entityName])
    }

    foreach ($file in @(Get-ChildItem -Path $PayloadFolder -Filter 'table-*.json' -ErrorAction SilentlyContinue)) {
        $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $schemaName = ($doc.EntityDefinition.SchemaName ?? $doc.SchemaName ?? '').Trim().ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($schemaName)) {
            [void]$entities.Add($schemaName)
        }
    }

    foreach ($file in @(Get-ChildItem -Path $PayloadFolder -Filter 'columns-*.json' -ErrorAction SilentlyContinue)) {
        $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $tableLogicalName = ($doc.TableLogicalName ?? '').Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($tableLogicalName)) { continue }

        [void]$entities.Add($tableLogicalName)
        if (-not $fieldsByEntity.ContainsKey($tableLogicalName)) {
            $fieldsByEntity[$tableLogicalName] = New-StringHashSet
        }

        foreach ($column in @($doc.Columns)) {
            $logicalName = ($column.LogicalName ?? $column.SchemaName ?? '').Trim().ToLowerInvariant()
            if (-not [string]::IsNullOrWhiteSpace($logicalName)) {
                [void]$fieldsByEntity[$tableLogicalName].Add($logicalName)
            }
        }
    }

    foreach ($relationship in @(Get-RelationshipIndex -PayloadFolder $PayloadFolder)) {
        Add-HashSetValues -Set $entities -Values @($relationship.ReferencingEntity, $relationship.ReferencedEntity)
    }

    return [pscustomobject]@{
        Entities       = $entities
        FieldsByEntity = $fieldsByEntity
    }
}

function Get-BpfDefinitions {
    param([string]$PayloadFolder)

    $definitions = New-Object System.Collections.Generic.List[object]
    foreach ($file in @(Get-ChildItem -Path $PayloadFolder -Filter 'process-*.json' -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $doc) {
            $doc | Add-Member -NotePropertyName '__SourceFile' -NotePropertyValue $file.FullName -Force
            $definitions.Add($doc) | Out-Null
        }
    }

    return $definitions.ToArray()
}

function Get-BpfDesiredAction {
    param(
        $ExistingProcess,
        [bool]$PreferUpdateExistingBpf = $true
    )

    if ($null -eq $ExistingProcess) {
        return 'designer-handoff-required'
    }

    return 'validate-existing'
}

function Test-BpfDefinition {
    param(
        $Definition,
        [string]$ArtifactText,
        [string]$PayloadFolder
    )

    $passed = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $stageSummaries = New-Object System.Collections.Generic.List[object]

    if ($null -eq $Definition) {
        $failed.Add('BPF definition is missing.') | Out-Null
        return [pscustomobject]@{ Status = 'failed'; Passed = $passed.ToArray(); Failed = $failed.ToArray(); Warnings = $warnings.ToArray(); StageSummaries = @() }
    }

    $enabled = ConvertTo-BpfBoolean -Value $Definition.Enabled -Default:$false
    if (-not $enabled) {
        $warnings.Add('BPF definition is disabled. Skipping generation.') | Out-Null
        return [pscustomobject]@{ Status = 'skipped'; Passed = $passed.ToArray(); Failed = $failed.ToArray(); Warnings = $warnings.ToArray(); StageSummaries = @() }
    }

    $index = Get-PayloadEntityAndFieldIndex -PayloadFolder $PayloadFolder -ArtifactText $ArtifactText
    $relationships = @(Get-RelationshipIndex -PayloadFolder $PayloadFolder)
    $primaryEntity = ($Definition.PrimaryProcessEntity ?? '').Trim().ToLowerInvariant()
    $processName = ($Definition.BusinessProcessFlowName ?? '').Trim()
    $stages = @($Definition.StageDefinitions)

    if ([string]::IsNullOrWhiteSpace($processName)) {
        $failed.Add('BusinessProcessFlowName is required.') | Out-Null
    } else {
        $passed.Add("Process name supplied: $processName") | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($primaryEntity)) {
        $failed.Add('PrimaryProcessEntity is required and cannot be ambiguous.') | Out-Null
    } elseif (-not $index.Entities.Contains($primaryEntity)) {
        $failed.Add("Primary entity '$primaryEntity' was not found in payloads or explicit planning mappings.") | Out-Null
    } else {
        $passed.Add("Primary entity resolved: $primaryEntity") | Out-Null
    }

    if ($stages.Count -lt 2) {
        $failed.Add('At least 2 BPF stages are required to justify a staged business process.') | Out-Null
    }

    $seenOrders = New-StringHashSet
    foreach ($stage in @($stages | Sort-Object Order)) {
        $stageName = ($stage.StageName ?? '').Trim()
        $stageEntity = ($stage.EntityLogicalName ?? $primaryEntity ?? '').Trim().ToLowerInvariant()
        $requiredFields = @(Split-BpfList -Value $stage.RequiredFields)
        $entryCriteria = ($stage.EntryCriteria ?? '').Trim()
        $exitCriteria = ($stage.ExitCriteria ?? '').Trim()
        $relationshipProperty = $stage.PSObject.Properties['RelationshipLogicalName']
        $relationshipLogicalName = if ($null -eq $relationshipProperty) { '' } else { ("$($relationshipProperty.Value)").Trim().ToLowerInvariant() }
        $stageOrderKey = "$(($stage.Order ?? '').ToString())"

        if ([string]::IsNullOrWhiteSpace($stageName)) {
            $failed.Add('Each stage requires a StageName.') | Out-Null
        }
        if ([string]::IsNullOrWhiteSpace($stageOrderKey)) {
            $failed.Add("Stage '$stageName' is missing an Order value.") | Out-Null
        } elseif (-not $seenOrders.Add($stageOrderKey)) {
            $failed.Add("Stage order '$stageOrderKey' is duplicated.") | Out-Null
        }
        if ([string]::IsNullOrWhiteSpace($stageEntity)) {
            $failed.Add("Stage '$stageName' is missing EntityLogicalName.") | Out-Null
        } elseif (-not $index.Entities.Contains($stageEntity)) {
            $failed.Add("Stage '$stageName' references entity '$stageEntity', which is not present in payloads or planning mappings.") | Out-Null
        }
        if ($requiredFields.Count -eq 0) {
            $failed.Add("Stage '$stageName' must declare at least one required field.") | Out-Null
        }
        if ([string]::IsNullOrWhiteSpace($entryCriteria)) {
            $failed.Add("Stage '$stageName' is missing EntryCriteria.") | Out-Null
        }
        if ([string]::IsNullOrWhiteSpace($exitCriteria)) {
            $failed.Add("Stage '$stageName' is missing ExitCriteria.") | Out-Null
        }

        if (-not $index.FieldsByEntity.ContainsKey($stageEntity)) {
            $index.FieldsByEntity[$stageEntity] = New-StringHashSet
        }

        foreach ($fieldName in $requiredFields) {
            if (-not $index.FieldsByEntity[$stageEntity].Contains($fieldName)) {
                $failed.Add("Stage '$stageName' requires field '$stageEntity.$fieldName', but that field is not defined in payloads or standard field mappings.") | Out-Null
            }
        }

        if ($stageEntity -ne $primaryEntity) {
            if ([string]::IsNullOrWhiteSpace($relationshipLogicalName)) {
                $failed.Add("Stage '$stageName' is cross-table and must declare RelationshipLogicalName.") | Out-Null
            } else {
                $relationship = @($relationships | Where-Object {
                    $_.SchemaName -eq $relationshipLogicalName -and (
                        ($_.ReferencingEntity -eq $stageEntity -and $_.ReferencedEntity -eq $primaryEntity) -or
                        ($_.ReferencedEntity -eq $stageEntity -and $_.ReferencingEntity -eq $primaryEntity)
                    )
                } | Select-Object -First 1)
                if ($relationship.Count -eq 0) {
                    $failed.Add("Stage '$stageName' references relationship '$relationshipLogicalName', but no payload relationship connects '$stageEntity' to '$primaryEntity'.") | Out-Null
                }
            }
        }

        $stageSummaries.Add([pscustomobject]@{
            Order                  = $stage.Order
            StageName              = $stageName
            EntityLogicalName      = $stageEntity
            RequiredFields         = $requiredFields
            EntryCriteria          = $entryCriteria
            ExitCriteria           = $exitCriteria
            RelationshipLogicalName = $relationshipLogicalName
        }) | Out-Null
    }

    $formIntegration = $Definition.FormIntegration
    $targetFormName = ($formIntegration.TargetFormName ?? '').Trim()
    if ([string]::IsNullOrWhiteSpace($targetFormName)) {
        $failed.Add('FormIntegration.TargetFormName is required so the BPF can be validated against a Main form.') | Out-Null
    } else {
        $passed.Add("Target Main form declared: $targetFormName") | Out-Null
    }

    if ($failed.Count -gt 0) {
        return [pscustomobject]@{ Status = 'failed'; Passed = $passed.ToArray(); Failed = $failed.ToArray(); Warnings = $warnings.ToArray(); StageSummaries = $stageSummaries.ToArray() }
    }

    return [pscustomobject]@{ Status = 'passed'; Passed = $passed.ToArray(); Failed = $failed.ToArray(); Warnings = $warnings.ToArray(); StageSummaries = $stageSummaries.ToArray() }
}

function New-BpfReport {
    param(
        [string]$Status,
        [string]$ProcessName,
        [string]$TargetEntity,
        [array]$StageSummaries,
        [object]$Validation,
        [hashtable]$Inputs,
        [hashtable]$DataverseResult
    )

    return [ordered]@{
        Timestamp       = (Get-Date).ToString('o')
        Status          = $Status
        ProcessName     = $ProcessName
        TargetEntity    = $TargetEntity
        StagesCreated   = @($StageSummaries)
        Validation      = [ordered]@{
            Passed   = @($Validation.Passed)
            Failed   = @($Validation.Failed)
            Warnings = @($Validation.Warnings)
        }
        InputsUsed      = $Inputs
        DataverseResult = $DataverseResult
    }
}