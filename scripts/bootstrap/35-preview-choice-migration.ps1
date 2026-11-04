<#
=============================================================================
COMPONENT:    Preview Choice-Column Migration
FILE:         scripts/bootstrap/35-preview-choice-migration.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-16
ENVIRONMENT:  PowerShell 7 | Dataverse Web API | Read-only retrofit planning
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [string]$PayloadsFolder = '',
    [ValidateSet('Offline', 'Preview')] [string]$Mode = 'Offline',
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')

function Get-ChoiceMigrationPayload {
    param([Parameter(Mandatory)] [string]$Folder)

    $files = @(Get-ChildItem -LiteralPath $Folder -Filter 'choice-migration-*.json' -File)
    if ($files.Count -ne 1) {
        throw "Expected exactly one choice-migration payload in '$Folder'; found $($files.Count)."
    }

    $schemaPath = Join-Path $repoRoot 'schemas/payloads/choice-migration.schema.json'
    $json = Get-Content -LiteralPath $files[0].FullName -Raw -Encoding UTF8
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "Choice-migration payload '$($files[0].Name)' failed schema validation."
    }
    return $json | ConvertFrom-Json -Depth 30
}

function Get-PayloadDocument {
    param(
        [Parameter(Mandatory)] [string]$Folder,
        [Parameter(Mandatory)] [string]$Filter,
        [Parameter(Mandatory)] [string]$Description
    )

    $files = @(Get-ChildItem -LiteralPath $Folder -Filter $Filter -File)
    if ($files.Count -ne 1) {
        throw "Expected exactly one $Description payload in '$Folder'; found $($files.Count)."
    }
    return Get-Content -LiteralPath $files[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 30
}

function Get-ChoiceMigrationPlan {
    param(
        [Parameter(Mandatory)] [object]$Payload,
        [Parameter(Mandatory)] [string]$Folder
    )

    if (-not $Payload.Enabled -or -not $Payload.Destructive -or
        -not $Payload.RequiresSeparateApplyApproval -or -not $Payload.SyntheticOnly) {
        throw 'Choice migration must remain enabled, destructive, separately approved, and synthetic-only.'
    }

    $choices = @{}
    foreach ($choice in @($Payload.GlobalChoices)) {
        $name = "$($choice.Name)"
        if ($choices.ContainsKey($name)) { throw "Duplicate global choice '$name'." }
        $values = @($choice.Options | ForEach-Object { [int]$_.Value })
        if (@($values | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
            throw "Global choice '$name' contains duplicate numeric values."
        }
        $labels = @($choice.Options | ForEach-Object { "$($_.Label)" })
        if (@($labels | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
            throw "Global choice '$name' contains duplicate labels."
        }
        $choices[$name] = $choice
    }

    $columnPayloads = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $Folder -Filter 'columns-*.json' -File)) {
        $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 30
        $columnPayloads["$($document.TableLogicalName)"] = $document
    }
    $dataPayload = Get-PayloadDocument -Folder $Folder -Filter 'data-*.json' -Description 'synthetic-data'

    $plans = [System.Collections.Generic.List[object]]::new()
    $bindingKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($binding in @($Payload.Bindings)) {
        $tableName = "$($binding.TableLogicalName)"
        $columnName = "$($binding.ColumnLogicalName)"
        $choiceName = "$($binding.GlobalChoiceName)"
        $bindingKey = "$tableName|$columnName"
        if (-not $bindingKeys.Add($bindingKey)) { throw "Duplicate choice binding '$bindingKey'." }
        if (-not $choices.ContainsKey($choiceName)) {
            throw "Choice binding '$bindingKey' references missing global choice '$choiceName'."
        }
        if (-not $columnPayloads.ContainsKey($tableName)) {
            throw "Choice binding '$bindingKey' has no columns payload."
        }

        $columns = @($columnPayloads[$tableName].Columns | Where-Object {
            "$($_.LogicalName)" -eq $columnName -or "$($_.SchemaName)" -eq $columnName
        })
        if ($columns.Count -ne 1) {
            throw "Choice binding '$bindingKey' must resolve exactly one column payload; found $($columns.Count)."
        }
        if ("$($columns[0].'@odata.type')" -ne 'Microsoft.Dynamics.CRM.StringAttributeMetadata') {
            throw "Choice binding '$bindingKey' is not currently declared as StringAttributeMetadata."
        }

        $choiceValues = @($choices[$choiceName].Options | ForEach-Object { [int]$_.Value })
        foreach ($mapping in $binding.ValueMap.PSObject.Properties) {
            if ([int]$mapping.Value -notin $choiceValues) {
                throw "Choice binding '$bindingKey' maps '$($mapping.Name)' to undefined value '$($mapping.Value)'."
            }
        }

        $dataTables = @($dataPayload.Tables | Where-Object TableLogicalName -eq $tableName)
        if ($dataTables.Count -ne 1) {
            throw "Choice binding '$bindingKey' must resolve exactly one synthetic-data table; found $($dataTables.Count)."
        }
        $seedValues = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($record in @($dataTables[0].Records)) {
            $property = $record.Values.PSObject.Properties[$columnName]
            if ($null -eq $property -or $null -eq $property.Value -or "$($property.Value)" -eq '') { continue }
            $label = "$($property.Value)"
            [void]$seedValues.Add($label)
            if ($null -eq $binding.ValueMap.PSObject.Properties[$label]) {
                throw "Choice binding '$bindingKey' has no mapping for seeded value '$label'."
            }
        }

        [void]$plans.Add([pscustomobject]@{
            TableLogicalName = $tableName
            ColumnLogicalName = $columnName
            GlobalChoiceName = $choiceName
            DisplayName = "$($columns[0].DisplayName.LocalizedLabels[0].Label)"
            RequiredLevel = "$($columns[0].RequiredLevel.Value)"
            OriginalColumn = $columns[0]
            SeedValues = @($seedValues | Sort-Object)
            ValueMap = $binding.ValueMap
        })
    }

    if ($choices.Count -ne 26 -or $plans.Count -ne 29) {
        throw "Choice migration requires exactly 26 global choices and 29 bindings; found $($choices.Count) and $($plans.Count)."
    }

    return [pscustomobject]@{
        Choices = $choices
        Plans = @($plans)
        DataPayload = $dataPayload
    }
}

if ($env:WIZARD_CHOICE_MIGRATION_SKIP_MAIN -ne 'true') {
if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path $repoRoot "payloads/scenarios/$ScenarioSlug"
}
$payload = Get-ChoiceMigrationPayload -Folder $PayloadsFolder
$contract = Get-ChoiceMigrationPlan -Payload $payload -Folder $PayloadsFolder
$evidence = [System.Collections.Generic.List[object]]::new()

if ($Mode -eq 'Preview') {
    if (([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) -and
        (Test-Path -LiteralPath (Join-Path $repoRoot '.env.ps1'))) {
        $environment = Import-WizardEnvironment -RepoRoot $repoRoot
        $EnvironmentUrl = $environment.EnvironmentUrl
        $AccessToken = $environment.AccessToken
    }
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
        throw 'Live choice-migration Preview requires an environment and access token.'
    }

    $invoke = {
        param([string]$Method, [string]$Path)
        if ($Method -ne 'Get') { throw "Choice-migration Preview prohibits mutating method '$Method'." }
        Invoke-WizardDataverseRequest -Method $Method -Path $Path -EnvironmentUrl $EnvironmentUrl `
            -AccessToken $AccessToken -RequestInvoker $RequestInvoker
    }
    $tableMetadata = @{}
    $safeSourceTag = ConvertTo-WizardODataLiteral "$($contract.DataPayload.SourceTag)"

    foreach ($plan in @($contract.Plans)) {
        $tableName = $plan.TableLogicalName
        $columnName = $plan.ColumnLogicalName
        $metadata = & $invoke Get "EntityDefinitions(LogicalName='$tableName')/Attributes(LogicalName='$columnName')?`$select=MetadataId,LogicalName,AttributeType"
        if ("$($metadata.AttributeType)" -ne 'String') {
            throw "Live attribute '$tableName.$columnName' must be String before migration; found '$($metadata.AttributeType)'."
        }
        $metadataId = "$($metadata.MetadataId)"
        if ([string]::IsNullOrWhiteSpace($metadataId)) {
            throw "Live attribute '$tableName.$columnName' has no MetadataId."
        }

        if (-not $tableMetadata.ContainsKey($tableName)) {
            $tableMetadata[$tableName] = & $invoke Get "EntityDefinitions(LogicalName='$tableName')?`$select=EntitySetName,PrimaryIdAttribute"
        }
        $entitySetName = "$($tableMetadata[$tableName].EntitySetName)"
        $primaryId = "$($tableMetadata[$tableName].PrimaryIdAttribute)"
        $rows = @((& $invoke Get "${entitySetName}?`$select=$primaryId,$columnName,$($contract.DataPayload.SourceTagField)&`$filter=$columnName ne null").value)
        $foreignRows = @($rows | Where-Object {
            "$($_.$($contract.DataPayload.SourceTagField))" -ne "$($contract.DataPayload.SourceTag)"
        })
        if ($foreignRows.Count -gt 0) {
            throw "Live attribute '$tableName.$columnName' contains $($foreignRows.Count) non-synthetic value(s); migration is blocked."
        }
        $unmappedRows = @($rows | Where-Object {
            $value = "$($_.$columnName)"
            $null -eq $plan.ValueMap.PSObject.Properties[$value]
        })
        if ($unmappedRows.Count -gt 0) {
            $firstValue = "$($unmappedRows[0].$columnName)"
            throw "Live attribute '$tableName.$columnName' contains unmapped value '$firstValue'; migration is blocked."
        }

        $dependencies = @((& $invoke Get "RetrieveDependenciesForDelete(ObjectId=$metadataId,ComponentType=2)").value)
        $dependencyCounts = @($dependencies | Group-Object dependentcomponenttype | Sort-Object Name | ForEach-Object {
            [pscustomobject]@{ componentType = [int]$_.Name; count = $_.Count }
        })
        [void]$evidence.Add([pscustomobject]@{
            tableLogicalName = $tableName
            columnLogicalName = $columnName
            metadataId = $metadataId
            currentType = 'String'
            globalChoiceName = $plan.GlobalChoiceName
            populatedSyntheticRecords = $rows.Count
            foreignPopulatedRecords = 0
            dependencyCount = $dependencies.Count
            dependencyCounts = $dependencyCounts
            dependencies = @($dependencies | ForEach-Object {
                [pscustomobject]@{
                    dependencyId = "$($_.dependencyid)"
                    dependentComponentType = [int]$_.dependentcomponenttype
                    dependentComponentObjectId = "$($_.dependentcomponentobjectid)"
                    dependencyType = [int]$_.dependencytype
                }
            })
        })
    }
} else {
    foreach ($plan in @($contract.Plans)) {
        [void]$evidence.Add([pscustomobject]@{
            tableLogicalName = $plan.TableLogicalName
            columnLogicalName = $plan.ColumnLogicalName
            currentPayloadType = 'StringAttributeMetadata'
            globalChoiceName = $plan.GlobalChoiceName
            seedValues = @($plan.SeedValues)
            mappedValueCount = @($plan.ValueMap.PSObject.Properties).Count
        })
    }
}

$evidencePath = Join-Path $repoRoot ".wizard-metrics/artifacts/choice-migration/$ScenarioSlug.json"
New-Item -ItemType Directory -Path (Split-Path $evidencePath -Parent) -Force | Out-Null
[ordered]@{
    scenarioSlug = $ScenarioSlug
    migrationId = "$($payload.MigrationId)"
    mode = $Mode
    destructive = $true
    applyAuthorized = $false
    syntheticOnly = $true
    globalChoiceCount = $contract.Choices.Count
    bindingCount = $contract.Plans.Count
    mutationCount = 0
    bindings = @($evidence)
} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8

Write-Host "Choice migration $Mode passed: $($contract.Choices.Count) global choices; $($contract.Plans.Count) bindings; 0 mutations." -ForegroundColor Green
}
