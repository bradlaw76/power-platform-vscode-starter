<#
=============================================================================
COMPONENT:    Choice Migration Apply Tests
FILE:         scripts/ci/test-choice-migration-apply.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-16
ENVIRONMENT:  PowerShell 7 | Credential-free stateful Dataverse mock
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$stage = Join-Path $repoRoot 'scripts/bootstrap/36-apply-choice-migration.ps1'
$payloadFolder = Join-Path $repoRoot 'payloads/scenarios/federal-foia-management'
$migrationPayload = Get-Content -LiteralPath (Join-Path $payloadFolder 'choice-migration-federal-foia-management.json') -Raw |
    ConvertFrom-Json -Depth 40
$dataPayload = Get-Content -LiteralPath (Join-Path $payloadFolder 'data-federal-foia-management.json') -Raw |
    ConvertFrom-Json -Depth 40

function New-TestGuid {
    param([Parameter(Mandatory)] [string]$Seed)
    return [Guid]::new([Security.Cryptography.MD5]::HashData([Text.Encoding]::UTF8.GetBytes($Seed))).ToString()
}

$solutionId = New-TestGuid 'solution'
$attributeTypes = @{}
$attributeIds = @{}
$bindingByKey = @{}
foreach ($binding in @($migrationPayload.Bindings)) {
    $key = "$($binding.TableLogicalName)|$($binding.ColumnLogicalName)"
    $attributeTypes[$key] = 'String'
    $attributeIds[$key] = New-TestGuid "attribute|$key|string"
    $bindingByKey[$key] = $binding
}

$recordsByEntitySet = @{}
$tableByEntitySet = @{}
foreach ($table in @($dataPayload.Tables)) {
    $entitySet = "unit_$($table.TableLogicalName)"
    $primaryId = "$($table.TableLogicalName)id"
    $tableByEntitySet[$entitySet] = [pscustomobject]@{
        LogicalName = "$($table.TableLogicalName)"
        PrimaryIdAttribute = $primaryId
    }
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($record in @($table.Records)) {
        $values = @{}
        foreach ($property in $record.Values.PSObject.Properties) {
            $values[$property.Name] = $property.Value
        }
        $values["$($dataPayload.SourceTagField)"] = "$($dataPayload.SourceTag)"
        [void]$records.Add([pscustomobject]@{
            Id = New-TestGuid "row|$entitySet|$($record.Key)"
            Values = $values
        })
    }
    $recordsByEntitySet[$entitySet] = $records
}

$choices = @{}
$memberships = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$calls = [System.Collections.Generic.List[object]]::new()
$state = [pscustomobject]@{
    DependencyCount = 1
    PicklistCreateCount = 0
    FailPicklistCreateAt = 0
    HiddenChoiceName = ''
    SimulateDelayedChoice = $true
    PageSize = 1
    PageFault = ''
    MismatchedChoiceName = ''
}

$requestInvoker = {
    param($request)
    $path = [Uri]::UnescapeDataString(($request.Uri -split '/api/data/v9.2/')[1])
    $body = if ($null -eq $request.Body) { $null } else { $request.Body | ConvertFrom-Json -Depth 50 }
    [void]$calls.Add([pscustomobject]@{ Method = "$($request.Method)"; Path = $path; Body = $body })

    if ($request.Method -eq 'Get' -and
        $path -match "^EntityDefinitions\(LogicalName='(?<table>[^']+)'\)/Attributes\(LogicalName='(?<column>[^']+)'\)") {
        $key = "$($Matches.table)|$($Matches.column)"
        if (-not $attributeTypes.ContainsKey($key)) { throw "Attribute not found: $key" }
        return [pscustomobject]@{
            MetadataId = $attributeIds[$key]
            LogicalName = $Matches.column
            AttributeType = $attributeTypes[$key]
            GlobalOptionSet = [pscustomobject]@{
                Name = $bindingByKey[$key].GlobalChoiceName
                MetadataId = New-TestGuid "choice|$($bindingByKey[$key].GlobalChoiceName)"
            }
        }
    }
    if ($request.Method -eq 'Get' -and $path -match "^EntityDefinitions\(LogicalName='(?<table>[^']+)'\)\?") {
        return [pscustomobject]@{
            MetadataId = New-TestGuid "table|$($Matches.table)"
            EntitySetName = "unit_$($Matches.table)"
            PrimaryIdAttribute = "$($Matches.table)id"
        }
    }
    if ($request.Method -eq 'Get' -and $path -match '^RetrieveDependenciesForDelete\(ObjectId=(?<id>[0-9a-f-]+),ComponentType=2\)$') {
        $dependencies = if ($state.DependencyCount -gt 0) {
            @([pscustomobject]@{
                dependencyid = New-TestGuid "dependency|$($Matches.id)"
                dependentcomponenttype = 29
                dependentcomponentobjectid = New-TestGuid "process|$($Matches.id)"
                dependencytype = 2
            })
        } else { @() }
        return [pscustomobject]@{ value = $dependencies }
    }
    if ($request.Method -eq 'Get' -and $path -like 'solutions?*') {
        return [pscustomobject]@{ value = @([pscustomobject]@{ solutionid = $solutionId }) }
    }
    if ($request.Method -eq 'Get' -and $path -match '^GlobalOptionSetDefinitions\?') {
        if ($path -match '\$filter') { throw 'GlobalOptionSetDefinitions does not support $filter.' }
        if (-not [string]::IsNullOrWhiteSpace($state.HiddenChoiceName)) {
            $visible = @($choices.Values | Where-Object Name -ne $state.HiddenChoiceName)
            $state.HiddenChoiceName = ''
            return [pscustomobject]@{ value = $visible }
        }
        return [pscustomobject]@{ value = @($choices.Values) }
    }
    if ($request.Method -eq 'Get' -and $path -match "^GlobalOptionSetDefinitions\(Name='(?<name>[^']+)'\)") {
        if ($Matches.name -eq $state.MismatchedChoiceName) {
            $metadata = $choices[$Matches.name] | ConvertTo-Json -Depth 50 | ConvertFrom-Json -Depth 50
            $metadata.MetadataId = [guid]::Empty.ToString()
            return $metadata
        }
        return $choices[$Matches.name]
    }
    if ($request.Method -eq 'Post' -and $path -eq 'GlobalOptionSetDefinitions') {
        $name = "$($body.Name)"
        $choices[$name] = [pscustomobject]@{
            MetadataId = New-TestGuid "choice|$name"; Name = $name
            IsGlobal = $true; OptionSetType = 'Picklist'; Options = $body.Options
        }
        if ($state.SimulateDelayedChoice) {
            $state.HiddenChoiceName = $name
            $state.SimulateDelayedChoice = $false
        }
        return [pscustomobject]@{}
    }
    if ($request.Method -eq 'Get' -and $path -like 'solutioncomponents?*') {
        if ($path -notmatch 'objectid eq (?<id>[0-9a-f-]+)') { throw "Membership query has no object ID: $path" }
        return [pscustomobject]@{ value = if ($memberships.Contains($Matches.id) -or $path -match 'componenttype eq 1 and rootcomponentbehavior eq 0') {
            @([pscustomobject]@{ solutioncomponentid = New-TestGuid "membership|$($Matches.id)" })
        } else { @() } }
    }
    if ($request.Method -eq 'Post' -and $path -eq 'AddSolutionComponent') {
        [void]$memberships.Add("$($body.ComponentId)")
        return [pscustomobject]@{}
    }
    if ($request.Method -eq 'Delete' -and
        $path -match "^EntityDefinitions\(LogicalName='(?<table>[^']+)'\)/Attributes\((?<id>[0-9a-f-]+)\)$") {
        $key = @($attributeIds.Keys | Where-Object {
            $attributeIds[$_] -eq $Matches.id -and $_ -like "$($Matches.table)|*"
        })
        if ($key.Count -ne 1) { throw "Delete attribute did not resolve: $path" }
        $attributeTypes.Remove($key[0])
        $attributeIds.Remove($key[0])
        return [pscustomobject]@{}
    }
    if ($request.Method -eq 'Post' -and
        $path -match "^EntityDefinitions\(LogicalName='(?<table>[^']+)'\)/Attributes$") {
        $column = "$($body.LogicalName)"
        if ([string]::IsNullOrWhiteSpace($column)) { $column = "$($body.SchemaName)" }
        $key = "$($Matches.table)|$column"
        $odataType = "$($body.PSObject.Properties['@odata.type'].Value)"
        $type = if ($odataType -eq 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata') {
            'Picklist'
        } else {
            'String'
        }
        if ($type -eq 'Picklist') {
            $expectedChoiceId = New-TestGuid "choice|$($bindingByKey[$key].GlobalChoiceName)"
            if ($body.'GlobalOptionSet@odata.bind' -cne "/GlobalOptionSetDefinitions($expectedChoiceId)") {
                throw 'Picklist creation must bind the exact global choice metadata GUID.'
            }
            $state.PicklistCreateCount++
            if ($state.FailPicklistCreateAt -gt 0 -and $state.PicklistCreateCount -eq $state.FailPicklistCreateAt) {
                throw 'Injected picklist creation failure.'
            }
        }
        $attributeTypes[$key] = $type
        $attributeIds[$key] = New-TestGuid "attribute|$key|$type|$($state.PicklistCreateCount)"
        return [pscustomobject]@{}
    }
    if ($request.Method -eq 'Post' -and $path -eq 'PublishXml') {
        return [pscustomobject]@{}
    }

    $entitySet = ($path -split '[?(]')[0]
    if ($recordsByEntitySet.ContainsKey($entitySet)) {
        $tableInfo = $tableByEntitySet[$entitySet]
        if ($request.Method -eq 'Get' -and $path -match '^[^(]+\((?<id>[0-9a-f-]+)\)\?\$select=(?<column>[^&]+)$') {
            $record = @($recordsByEntitySet[$entitySet] | Where-Object Id -eq $Matches.id)
            if ($record.Count -ne 1) { throw "Record not found: $path" }
            $result = [ordered]@{}
            $result[$Matches.column] = $record[0].Values[$Matches.column]
            return [pscustomobject]$result
        }
        if ($request.Method -eq 'Get' -and $path -notmatch '\(') {
            if ($path -notmatch '\$select=(?<select>[^&]+)') { throw "Data query has no select: $path" }
            $selected = @($Matches.select -split ',')
            $primaryId = $selected[0]
            $column = $selected[1]
            $sourceTagField = $selected[2]
            $allRows = @($recordsByEntitySet[$entitySet] | Where-Object { $_.Values.ContainsKey($column) -and $null -ne $_.Values[$column] } | ForEach-Object {
                $result = [ordered]@{
                    $primaryId = $_.Id
                    $column = $_.Values[$column]
                    $sourceTagField = $_.Values[$sourceTagField]
                }
                [pscustomobject]$result
            })
            $skip = 0
            if ($path -match '\$skiptoken=(\d+)') { $skip = [int]$Matches[1] }
            $rows = @($allRows | Select-Object -Skip $skip -First $state.PageSize)
            if ($skip -gt 0 -and $rows.Count -gt 0) {
                if ($state.PageFault -eq 'foreign-row') { $rows[0].$sourceTagField = 'not-owned' }
                if ($state.PageFault -eq 'unmapped-row') { $rows[0].$column = 'not-mapped' }
                if ($state.PageFault -eq 'missing-values') { return [pscustomobject]@{ invalid = $true } }
            }
            $result = [pscustomobject]@{ value = $rows }
            if ($skip + $rows.Count -lt $allRows.Count) {
                $basePath = $path -replace '&\$skiptoken=\d+', ''
                $next = "https://unit.test/api/data/v9.2/$basePath&`$skiptoken=$($skip + $rows.Count)"
                switch ($state.PageFault) {
                    'cycle' { $next = $request.Uri }
                    'foreign-host' { $next = $next.Replace('https://unit.test/', 'https://other.invalid/') }
                    'wrong-collection' { $next = 'https://unit.test/api/data/v9.2/unrelated?$skiptoken=1' }
                }
                $result | Add-Member -NotePropertyName '@odata.nextLink' -NotePropertyValue $next
            }
            return $result
        }
        if ($request.Method -eq 'Patch' -and $path -match '^[^(]+\((?<id>[0-9a-f-]+)\)$') {
            $record = @($recordsByEntitySet[$entitySet] | Where-Object Id -eq $Matches.id)
            if ($record.Count -ne 1) { throw "Patch record not found: $path" }
            foreach ($property in $body.PSObject.Properties) {
                $record[0].Values[$property.Name] = $property.Value
            }
            return [pscustomobject]@{}
        }
    }

    throw "Unexpected Dataverse request: $($request.Method) $path"
}.GetNewClosure()

& $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
    -Phase Snapshot -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
    -SolutionUniqueName 'UnitSolution' -RequestInvoker $requestInvoker

$snapshotPath = Join-Path $repoRoot '.wizard-metrics/artifacts/choice-migration/federal-foia-management-snapshot.json'
$snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json -Depth 50
if ($snapshot.bindingCount -ne 29 -or $snapshot.globalChoiceCount -ne 26 -or
    @($snapshot.bindings).Count -ne 29 -or @($snapshot.bindings.rows).Count -ne 97) {
    throw 'Choice migration Snapshot evidence has incorrect counts.'
}
if (@($calls | Where-Object Path -match '\$skiptoken=').Count -eq 0) {
    throw 'Snapshot did not follow data pages.'
}
$snapshotJson = Get-Content -LiteralPath $snapshotPath -Raw

function Assert-MigrationRejected {
    param([string]$Phase = 'Apply', [Parameter(Mandatory)] [string]$Message)
    $before = $calls.Count
    try {
        & $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
            -Phase $Phase -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
            -SolutionUniqueName 'UnitSolution' -ConfirmDestructiveMigration `
            -AuthorizationReference 'unit-safety-gate' -RequestInvoker $requestInvoker
        throw "Expected migration rejection: $Message"
    } catch {
        if ($_.Exception.Message -like 'Expected migration rejection:*' -or
            $_.Exception.Message -notlike "*$Message*") { throw }
    }
    if (@($calls | Select-Object -Skip $before | Where-Object Method -ne 'Get').Count -ne 0) {
        throw 'Migration safety rejection issued a mutating request.'
    }
}

foreach ($fault in @('foreign-row', 'unmapped-row', 'missing-values', 'foreign-host', 'wrong-collection', 'cycle')) {
    $state.PageFault = $fault
    $message = switch ($fault) {
        'foreign-row' { 'non-synthetic' }
        'unmapped-row' { 'unmapped value' }
        'missing-values' { 'invalid page' }
        'cycle' { 'repeated a page' }
        default { 'invalid next link' }
    }
    Assert-MigrationRejected -Phase Snapshot -Message $message
    if ((Get-Content -LiteralPath $snapshotPath -Raw) -cne $snapshotJson) {
        throw 'Rejected Snapshot overwrote the previous evidence.'
    }
}
$state.PageFault = ''

$beforeGuardCalls = $calls.Count
try {
    & $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
        -Phase Apply -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
        -SolutionUniqueName 'UnitSolution' -RequestInvoker $requestInvoker
    throw 'Expected destructive confirmation failure.'
} catch {
    if ($_.Exception.Message -notmatch 'ConfirmDestructiveMigration') { throw }
}
if ($calls.Count -ne $beforeGuardCalls) { throw 'Apply confirmation gate made a Dataverse call.' }

$beforeDependencyCalls = $calls.Count
try {
    & $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
        -Phase Apply -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
        -SolutionUniqueName 'UnitSolution' -ConfirmDestructiveMigration `
        -AuthorizationReference 'unit-approved' -RequestInvoker $requestInvoker
    throw 'Expected dependency gate failure.'
} catch {
    if ($_.Exception.Message -notmatch 'still has 1 dependency') { throw }
}
$dependencyCalls = @($calls | Select-Object -Skip $beforeDependencyCalls)
if (@($dependencyCalls | Where-Object Method -ne 'Get').Count -ne 0) {
    throw 'Dependency gate issued a mutating request.'
}

$state.DependencyCount = 0
$firstBinding = $migrationPayload.Bindings[0]
$sourceRows = $recordsByEntitySet["unit_$($firstBinding.TableLogicalName)"]
$sourceRow = @($sourceRows | Where-Object { $_.Values.ContainsKey($firstBinding.ColumnLogicalName) })[0]
$originalLabel = $sourceRow.Values[$firstBinding.ColumnLogicalName]
$alternateLabel = @($firstBinding.ValueMap.PSObject.Properties | Where-Object Name -ne $originalLabel)[0].Name
$sourceRow.Values[$firstBinding.ColumnLogicalName] = $alternateLabel
Assert-MigrationRejected -Message 'snapshot is stale or invalid'
$sourceRow.Values[$firstBinding.ColumnLogicalName] = $null
Assert-MigrationRejected -Message 'snapshot is stale or invalid'
$sourceRow.Values[$firstBinding.ColumnLogicalName] = $originalLabel
$lateRow = @($sourceRows | Where-Object { $_.Values.ContainsKey($firstBinding.ColumnLogicalName) })[-1]
$lateLabel = $lateRow.Values[$firstBinding.ColumnLogicalName]
$lateRow.Values[$firstBinding.ColumnLogicalName] = @($firstBinding.ValueMap.PSObject.Properties | Where-Object Name -ne $lateLabel)[0].Name
Assert-MigrationRejected -Message 'snapshot is stale or invalid'
$lateRow.Values[$firstBinding.ColumnLogicalName] = $lateLabel
$sourceIndex = $sourceRows.IndexOf($sourceRow)
$sourceRows.RemoveAt($sourceIndex)
Assert-MigrationRejected -Message 'snapshot is stale or invalid'
$sourceRows.Insert($sourceIndex, $sourceRow)
$addedValues = @{
    "$($firstBinding.ColumnLogicalName)" = $originalLabel
    "$($dataPayload.SourceTagField)" = "$($dataPayload.SourceTag)"
}
$addedRow = [pscustomobject]@{ Id = New-TestGuid 'post-snapshot-row'; Values = $addedValues }
$sourceRows.Add($addedRow)
Assert-MigrationRejected -Message 'snapshot is stale or invalid'
[void]$sourceRows.Remove($addedRow)
$sourceRows.Add($sourceRow)
Assert-MigrationRejected -Message 'snapshot is stale or invalid'
$sourceRows.RemoveAt($sourceRows.Count - 1)
$attributeKey = "$($firstBinding.TableLogicalName)|$($firstBinding.ColumnLogicalName)"
$originalAttributeId = $attributeIds[$attributeKey]
$attributeIds[$attributeKey] = New-TestGuid 'post-snapshot-attribute'
Assert-MigrationRejected -Message 'snapshot is stale or invalid'
$attributeIds[$attributeKey] = $originalAttributeId

foreach ($fault in @('extra-binding', 'missing-binding', 'unknown-binding', 'duplicate-row', 'missing-row', 'wrong-value', 'wrong-definition', 'wrong-entityset', 'invalid-metadata-id')) {
    $invalidSnapshot = $snapshotJson | ConvertFrom-Json -Depth 50
    switch ($fault) {
        'extra-binding' { $invalidSnapshot.bindings += $invalidSnapshot.bindings[0] }
        'missing-binding' { $invalidSnapshot.bindings = @($invalidSnapshot.bindings | Select-Object -Skip 1) }
        'unknown-binding' { $invalidSnapshot.bindings[0].columnLogicalName = 'foia_unknown' }
        'duplicate-row' { $invalidSnapshot.bindings[0].rows += $invalidSnapshot.bindings[0].rows[0] }
        'missing-row' { $invalidSnapshot.bindings[0].rows = @($invalidSnapshot.bindings[0].rows | Select-Object -Skip 1) }
        'wrong-value' { $invalidSnapshot.bindings[0].rows[0].newValue = -1 }
        'wrong-definition' { $invalidSnapshot.bindings[0].originalColumn.SchemaName = 'foia_wrong' }
        'wrong-entityset' { $invalidSnapshot.bindings[0].entitySetName = 'unit_unrelated' }
        'invalid-metadata-id' { $invalidSnapshot.bindings[0].metadataId = 'invalid' }
    }
    $invalidSnapshot | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
    Assert-MigrationRejected -Message 'snapshot is stale or invalid'
}
$snapshotJson | Set-Content -LiteralPath $snapshotPath -Encoding UTF8 -NoNewline
foreach ($fault in @('foreign-row', 'unmapped-row', 'missing-values', 'foreign-host', 'wrong-collection', 'cycle')) {
    $state.PageFault = $fault
    $message = switch ($fault) {
        'foreign-row' { 'non-synthetic' }
        'unmapped-row' { 'unmapped value' }
        'missing-values' { 'invalid page' }
        'cycle' { 'repeated a page' }
        default { 'invalid next link' }
    }
    Assert-MigrationRejected -Message $message
}
$state.PageFault = ''
$emptyColumnValues = @($sourceRows | ForEach-Object { $_.Values[$firstBinding.ColumnLogicalName] })
foreach ($record in $sourceRows) { $record.Values[$firstBinding.ColumnLogicalName] = $null }
& $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
    -Phase Snapshot -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
    -SolutionUniqueName 'UnitSolution' -RequestInvoker $requestInvoker
$emptySnapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json -Depth 50
if (@($emptySnapshot.bindings[0].rows).Count -ne 0) { throw 'Empty field cohort was not captured exactly.' }
for ($index = 0; $index -lt $sourceRows.Count; $index++) {
    $sourceRows[$index].Values[$firstBinding.ColumnLogicalName] = $emptyColumnValues[$index]
}
$snapshotJson | Set-Content -LiteralPath $snapshotPath -Encoding UTF8 -NoNewline
. (Join-Path $repoRoot 'scripts\bootstrap\helpers\choice-migration-verification.ps1')
$existingChoice = $migrationPayload.GlobalChoices[-1]
$definition = New-WizardGlobalChoiceBody -Choice $existingChoice -ScenarioSlug 'federal-foia-management' -MigrationId $migrationPayload.MigrationId
$definition['MetadataId'] = New-TestGuid "choice|$($existingChoice.Name)"
$definitionJson = $definition | ConvertTo-Json -Depth 50
foreach ($fault in @('label', 'value', 'color', 'count', 'global', 'type', 'identity')) {
    $metadata = $definitionJson | ConvertFrom-Json -Depth 50
    $message = switch ($fault) {
        'label' { $metadata.Options[0].Label.LocalizedLabels[0].Label = 'Unexpected label'; 'incorrect value or English label' }
        'value' { $metadata.Options[0].Value = -1; 'incorrect value or English label' }
        'color' { $metadata.Options[0].Color = '#000000'; 'incorrect color' }
        'count' { $metadata.Options = @($metadata.Options | Select-Object -Skip 1); 'incorrect option count' }
        'global' { $metadata.IsGlobal = $false; 'expected global Picklist' }
        'type' { $metadata.OptionSetType = 'Boolean'; 'expected global Picklist' }
        'identity' { $state.MismatchedChoiceName = $existingChoice.Name; 'metadata identity' }
    }
    $choices[$existingChoice.Name] = $metadata
    Assert-MigrationRejected -Message $message
    $state.MismatchedChoiceName = ''
    $choices.Clear()
}
$choices[$existingChoice.Name] = $definitionJson | ConvertFrom-Json -Depth 50
$state.PicklistCreateCount = 0
& $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
    -Phase Apply -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
    -SolutionUniqueName 'UnitSolution' -ConfirmDestructiveMigration `
    -AuthorizationReference 'unit-approved' -RequestInvoker $requestInvoker
if (@($attributeTypes.Values | Where-Object { $_ -ne 'Picklist' }).Count -ne 0 -or $attributeTypes.Count -ne 29) {
    throw 'Successful Apply did not create exactly 29 Picklist attributes.'
}
if ($choices.Count -ne 26 -or $memberships.Count -ne 55) {
    throw 'Successful Apply did not add exactly 26 global choices and 29 recreated attributes.'
}

& $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
    -Phase Verify -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
    -SolutionUniqueName 'UnitSolution' -RequestInvoker $requestInvoker

$beforeRerunCalls = $calls.Count
& $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
    -Phase Apply -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
    -SolutionUniqueName 'UnitSolution' -ConfirmDestructiveMigration `
    -AuthorizationReference 'unit-approved' -RequestInvoker $requestInvoker
$rerunCalls = @($calls | Select-Object -Skip $beforeRerunCalls)
if (@($rerunCalls | Where-Object Method -ne 'Get').Count -ne 0) {
    throw 'Idempotent Apply rerun issued a mutating request.'
}

foreach ($key in @($attributeTypes.Keys)) {
    $attributeTypes[$key] = 'String'
    $attributeIds[$key] = New-TestGuid "rollback-source|$key"
}
foreach ($binding in @($migrationPayload.Bindings)) {
    $entitySet = "unit_$($binding.TableLogicalName)"
    foreach ($record in @($recordsByEntitySet[$entitySet])) {
        $property = $record.Values[$binding.ColumnLogicalName]
        if ($null -eq $property) { continue }
        $numeric = [int]$property
        $oldLabel = @($binding.ValueMap.PSObject.Properties | Where-Object { [int]$_.Value -eq $numeric } | Select-Object -First 1)
        if ($oldLabel.Count -eq 1) { $record.Values[$binding.ColumnLogicalName] = $oldLabel[0].Name }
    }
}
$state.PicklistCreateCount = 0
& $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
    -Phase Snapshot -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
    -SolutionUniqueName 'UnitSolution' -RequestInvoker $requestInvoker
$state.FailPicklistCreateAt = 5
try {
    & $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
        -Phase Apply -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
        -SolutionUniqueName 'UnitSolution' -ConfirmDestructiveMigration `
        -AuthorizationReference 'unit-rollback' -RequestInvoker $requestInvoker
    throw 'Expected injected Apply failure.'
} catch {
    if ($_.Exception.Message -notmatch 'String columns and synthetic values were restored') { throw }
}
if ($attributeTypes.Count -ne 29 -or @($attributeTypes.Values | Where-Object { $_ -ne 'String' }).Count -ne 0) {
    throw 'Rollback did not restore all 29 String attributes.'
}

Remove-Item -LiteralPath $snapshotPath,
    (Join-Path $repoRoot '.wizard-metrics/artifacts/choice-migration/federal-foia-management-verification.json'),
    (Join-Path $repoRoot '.wizard-metrics/artifacts/choice-migration/federal-foia-management-apply.json') `
    -Force -ErrorAction SilentlyContinue
Write-Host 'Choice migration apply tests passed.' -ForegroundColor Green
