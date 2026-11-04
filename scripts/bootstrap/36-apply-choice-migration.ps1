<#
=============================================================================
COMPONENT:    Apply Choice-Column Migration
FILE:         scripts/bootstrap/36-apply-choice-migration.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-16
ENVIRONMENT:  PowerShell 7 | Dataverse Web API | Destructive retrofit
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [ValidateSet('Snapshot', 'Apply', 'Verify')] [string]$Phase = 'Snapshot',
    [string]$PayloadsFolder = '',
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [switch]$ConfirmDestructiveMigration,
    [string]$AuthorizationReference = '',
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')
. (Join-Path $PSScriptRoot 'helpers/solution-isolation.ps1')
. (Join-Path $PSScriptRoot 'helpers/choice-migration-verification.ps1')
$env:WIZARD_CHOICE_MIGRATION_SKIP_MAIN = 'true'
try {
    . (Join-Path $PSScriptRoot '35-preview-choice-migration.ps1') `
        -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder `
        -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken `
        -RequestInvoker $RequestInvoker
} finally {
    Remove-Item Env:WIZARD_CHOICE_MIGRATION_SKIP_MAIN -ErrorAction SilentlyContinue
}

function New-WizardPicklistColumnBody {
    param(
        [Parameter(Mandatory)] [object]$Plan,
        [Parameter(Mandatory)] [guid]$GlobalChoiceMetadataId
    )

    return [ordered]@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
        AttributeType = 'Picklist'
        AttributeTypeName = [ordered]@{ Value = 'PicklistType' }
        SourceTypeMask = 0
        SchemaName = "$($Plan.OriginalColumn.SchemaName)"
        LogicalName = "$($Plan.ColumnLogicalName)"
        DisplayName = $Plan.OriginalColumn.DisplayName
        Description = $Plan.OriginalColumn.Description
        RequiredLevel = $Plan.OriginalColumn.RequiredLevel
        'GlobalOptionSet@odata.bind' = "/GlobalOptionSetDefinitions($GlobalChoiceMetadataId)"
    }
}

function Get-ChoiceRows {
    param(
        [Parameter(Mandatory)] [object]$Plan,
        [Parameter(Mandatory)] [hashtable]$TableMetadata,
        [Parameter(Mandatory)] [scriptblock]$Invoke
    )

    $tableName = $Plan.TableLogicalName
    if (-not $TableMetadata.ContainsKey($tableName)) {
        $TableMetadata[$tableName] = & $Invoke Get "EntityDefinitions(LogicalName='$tableName')?`$select=EntitySetName,PrimaryIdAttribute"
    }
    $metadata = $TableMetadata[$tableName]
    $entitySetName = "$($metadata.EntitySetName)"
    $primaryId = "$($metadata.PrimaryIdAttribute)"
    $columnName = $Plan.ColumnLogicalName
    $sourceTagField = "$($script:DataPayload.SourceTagField)"
    $collectionUri = [uri]($EnvironmentUrl.TrimEnd('/') + "/api/data/v9.2/$entitySetName")
    $visited = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $getPage = {
        param([string]$Path)
        if (-not $visited.Add($Path)) { throw "Choice row paging repeated a page for '$tableName.$columnName'." }
        $page = & $Invoke Get $Path
        $values = $page.PSObject.Properties['value']
        if ($null -eq $values -or $null -eq $values.Value) {
            throw "Choice row paging returned an invalid page for '$tableName.$columnName'."
        }
        $next = Get-OptionalPropertyValue -InputObject $page -PropertyName '@odata.nextLink'
        if (-not [string]::IsNullOrWhiteSpace("$next")) {
            $nextUri = $null
            $relative = ConvertTo-DvRelativePath -NextLink "$next"
            if (-not [uri]::TryCreate($collectionUri, "$next", [ref]$nextUri) -or
                $nextUri.Scheme -cne $collectionUri.Scheme -or
                $nextUri.Authority -ine $collectionUri.Authority -or
                $nextUri.AbsolutePath -cne $collectionUri.AbsolutePath -or
                $nextUri.UserInfo -ne '' -or $nextUri.Fragment -ne '' -or
                ($relative -split '\?', 2)[0] -cne $entitySetName) {
                throw "Choice row paging returned an invalid next link for '$tableName.$columnName'."
            }
        }
        return $page
    }
    $rows = @(Invoke-SolutionIsolationPagedGet -InvokeGet $getPage `
        -Path "${entitySetName}?`$select=$primaryId,$columnName,$sourceTagField&`$filter=$columnName ne null")
    return [pscustomobject]@{
        EntitySetName = $entitySetName
        PrimaryIdAttribute = $primaryId
        Rows = $rows
    }
}

function Assert-ChoiceRowsAreSyntheticAndMapped {
    param(
        [Parameter(Mandatory)] [object]$Plan,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Rows
    )

    foreach ($row in $Rows) {
        $sourceTag = "$($row.($script:DataPayload.SourceTagField))"
        if ($sourceTag -ne "$($script:DataPayload.SourceTag)") {
            throw "Attribute '$($Plan.TableLogicalName).$($Plan.ColumnLogicalName)' contains a non-synthetic populated value."
        }
        $oldValue = "$($row.($Plan.ColumnLogicalName))"
        if ($null -eq $Plan.ValueMap.PSObject.Properties[$oldValue]) {
            throw "Attribute '$($Plan.TableLogicalName).$($Plan.ColumnLogicalName)' contains unmapped value '$oldValue'."
        }
    }
}

function Assert-ChoiceSnapshotIsCurrent {
    param(
        [Parameter(Mandatory)] [object]$Snapshot,
        [Parameter(Mandatory)] [object]$Plan,
        [Parameter(Mandatory)] [object]$Attribute,
        [Parameter(Mandatory)] [object]$RowsResult
    )

    $message = "Choice migration snapshot is stale or invalid for '$($Plan.TableLogicalName).$($Plan.ColumnLogicalName)'; refresh Snapshot before Apply."
    $bindings = @($Snapshot.bindings | Where-Object {
        $_.tableLogicalName -ceq $Plan.TableLogicalName -and $_.columnLogicalName -ceq $Plan.ColumnLogicalName
    })
    if ($bindings.Count -ne 1) { throw $message }
    $binding = $bindings[0]
    $savedAttributeId = [guid]::Empty
    $currentAttributeId = [guid]::Empty
    if (-not [guid]::TryParse("$($binding.metadataId)", [ref]$savedAttributeId) -or
        -not [guid]::TryParse("$($Attribute.MetadataId)", [ref]$currentAttributeId) -or
        $savedAttributeId -eq [guid]::Empty -or $savedAttributeId -ne $currentAttributeId -or
        $binding.globalChoiceName -cne $Plan.GlobalChoiceName -or
        $binding.entitySetName -cne $RowsResult.EntitySetName -or
        $binding.primaryIdAttribute -cne $RowsResult.PrimaryIdAttribute -or
        ($binding.originalColumn | ConvertTo-Json -Depth 40 -Compress) -cne
        ($Plan.OriginalColumn | ConvertTo-Json -Depth 40 -Compress)) {
        throw $message
    }
    $savedRows = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($row in @($binding.rows)) {
        $id = [guid]::Empty
        $newValue = 0
        $mapping = $Plan.ValueMap.PSObject.Properties["$($row.oldValue)"]
        if (-not [guid]::TryParse("$($row.id)", [ref]$id) -or $id -eq [guid]::Empty -or
            -not [int]::TryParse("$($row.newValue)", [ref]$newValue) -or
            $null -eq $mapping -or $newValue -ne [int]$mapping.Value -or
            -not $savedRows.TryAdd($id.ToString(), $row)) {
            throw $message
        }
    }
    if ($savedRows.Count -ne @($RowsResult.Rows).Count) { throw $message }
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($row in @($RowsResult.Rows)) {
        $id = [guid]::Empty
        if (-not [guid]::TryParse("$($row.($RowsResult.PrimaryIdAttribute))", [ref]$id) -or
            -not $seen.Add($id.ToString()) -or -not $savedRows.ContainsKey($id.ToString()) -or
            "$($row.($Plan.ColumnLogicalName))" -cne "$($savedRows[$id.ToString()].oldValue)") {
            throw $message
        }
    }
}

function Publish-ChoiceMigrationTables {
    param(
        [Parameter(Mandatory)] [object[]]$Plans,
        [Parameter(Mandatory)] [scriptblock]$Invoke
    )

    $entities = @($Plans.TableLogicalName | Sort-Object -Unique | ForEach-Object { "<entity>$_</entity>" }) -join ''
    & $Invoke Post 'PublishXml' @{ ParameterXml = "<importexportxml><entities>$entities</entities></importexportxml>" } | Out-Null
}

if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path $repoRoot "payloads/scenarios/$ScenarioSlug"
}
if (([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken) -or
    [string]::IsNullOrWhiteSpace($SolutionUniqueName)) -and
    (Test-Path -LiteralPath (Join-Path $repoRoot '.env.ps1'))) {
    $environment = Import-WizardEnvironment -RepoRoot $repoRoot
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) { $EnvironmentUrl = $environment.EnvironmentUrl }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) { $AccessToken = $environment.AccessToken }
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { $SolutionUniqueName = $environment.SolutionUniqueName }
}
foreach ($required in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName)) {
    if ([string]::IsNullOrWhiteSpace($required)) {
        throw 'Choice migration requires an environment, access token, and solution unique name.'
    }
}

$payload = Get-ChoiceMigrationPayload -Folder $PayloadsFolder
$contract = Get-ChoiceMigrationPlan -Payload $payload -Folder $PayloadsFolder
$script:DataPayload = $contract.DataPayload
$snapshotPath = Join-Path $repoRoot ".wizard-metrics/artifacts/choice-migration/$ScenarioSlug-snapshot.json"
$applyEvidencePath = Join-Path $repoRoot ".wizard-metrics/artifacts/choice-migration/$ScenarioSlug-apply.json"
$invoke = {
    param([string]$Method, [string]$Path, [object]$Body = $null)
    Invoke-WizardDataverseRequest -Method $Method -Path $Path -EnvironmentUrl $EnvironmentUrl `
        -AccessToken $AccessToken -Body $Body -RequestInvoker $RequestInvoker
}
$tableMetadata = @{}

if ($Phase -eq 'Snapshot') {
    $snapshotBindings = [System.Collections.Generic.List[object]]::new()
    foreach ($plan in @($contract.Plans)) {
        $attribute = & $invoke Get "EntityDefinitions(LogicalName='$($plan.TableLogicalName)')/Attributes(LogicalName='$($plan.ColumnLogicalName)')?`$select=MetadataId,LogicalName,AttributeType"
        if ("$($attribute.AttributeType)" -ne 'String') {
            throw "Snapshot requires String attribute '$($plan.TableLogicalName).$($plan.ColumnLogicalName)'; found '$($attribute.AttributeType)'."
        }
        $rowsResult = Get-ChoiceRows -Plan $plan -TableMetadata $tableMetadata -Invoke $invoke
        Assert-ChoiceRowsAreSyntheticAndMapped -Plan $plan -Rows @($rowsResult.Rows)
        $dependencies = @((& $invoke Get "RetrieveDependenciesForDelete(ObjectId=$($attribute.MetadataId),ComponentType=2)").value)
        [void]$snapshotBindings.Add([pscustomobject]@{
            tableLogicalName = $plan.TableLogicalName
            columnLogicalName = $plan.ColumnLogicalName
            globalChoiceName = $plan.GlobalChoiceName
            metadataId = "$($attribute.MetadataId)"
            entitySetName = $rowsResult.EntitySetName
            primaryIdAttribute = $rowsResult.PrimaryIdAttribute
            originalColumn = $plan.OriginalColumn
            dependencies = @($dependencies)
            rows = @($rowsResult.Rows | ForEach-Object {
                $oldValue = "$($_.($plan.ColumnLogicalName))"
                [pscustomobject]@{
                    id = "$($_.($rowsResult.PrimaryIdAttribute))"
                    oldValue = $oldValue
                    newValue = [int]$plan.ValueMap.PSObject.Properties[$oldValue].Value
                }
            })
        })
    }
    New-Item -ItemType Directory -Path (Split-Path $snapshotPath -Parent) -Force | Out-Null
    [ordered]@{
        scenarioSlug = $ScenarioSlug
        migrationId = "$($payload.MigrationId)"
        environmentUrl = $EnvironmentUrl.TrimEnd('/')
        solutionUniqueName = $SolutionUniqueName
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        bindingCount = $contract.Plans.Count
        globalChoiceCount = $contract.Choices.Count
        syntheticOnly = $true
        bindings = @($snapshotBindings)
    } | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
    Write-Host "Choice migration Snapshot passed: $($contract.Plans.Count) bindings; 0 mutations." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
    throw "Choice migration snapshot is missing: $snapshotPath"
}
$snapshot = Get-Content -LiteralPath $snapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 40
if ("$($snapshot.scenarioSlug)" -ne $ScenarioSlug -or "$($snapshot.migrationId)" -ne "$($payload.MigrationId)" -or
    "$($snapshot.environmentUrl)".TrimEnd('/') -ne $EnvironmentUrl.TrimEnd('/') -or
    "$($snapshot.solutionUniqueName)" -ne $SolutionUniqueName -or -not $snapshot.syntheticOnly) {
    throw 'Choice migration snapshot identity does not match the current scenario, environment, solution, or contract.'
}

if ($Phase -eq 'Verify') {
    $safeSolutionName = ConvertTo-WizardODataLiteral $SolutionUniqueName
    $solutions = @((& $invoke Get "solutions?`$select=solutionid&`$filter=uniquename eq '$safeSolutionName'").value)
    if ($solutions.Count -ne 1) { throw "Expected exactly one solution '$SolutionUniqueName'." }
    $invokeGet = { param($Path) & $invoke Get $Path }
    $verifiedInventory = @(Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId "$($solutions[0].solutionid)" -InvokeGet $invokeGet)
    $verified = 0
    foreach ($plan in @($contract.Plans)) {
        $attribute = & $invoke Get "EntityDefinitions(LogicalName='$($plan.TableLogicalName)')/Attributes(LogicalName='$($plan.ColumnLogicalName)')?`$select=MetadataId,LogicalName,AttributeType"
        if ("$($attribute.AttributeType)" -ne 'Picklist') {
            throw "Verify expected Picklist attribute '$($plan.TableLogicalName).$($plan.ColumnLogicalName)'; found '$($attribute.AttributeType)'."
        }
        $snapshotBinding = @($snapshot.bindings | Where-Object {
            $_.tableLogicalName -eq $plan.TableLogicalName -and $_.columnLogicalName -eq $plan.ColumnLogicalName
        })
        if ($snapshotBinding.Count -ne 1) { throw "Snapshot binding did not resolve for '$($plan.TableLogicalName).$($plan.ColumnLogicalName)'." }
        foreach ($row in @($snapshotBinding[0].rows)) {
            $result = & $invoke Get "$($snapshotBinding[0].entitySetName)($($row.id))?`$select=$($plan.ColumnLogicalName)"
            if ($null -eq $result.($plan.ColumnLogicalName) -or [int]$result.($plan.ColumnLogicalName) -ne [int]$row.newValue) {
                throw "Verify found incorrect choice value on '$($plan.TableLogicalName).$($plan.ColumnLogicalName)' record '$($row.id)'."
            }
        }
        $verified++
    }
    [ordered]@{
        scenarioSlug = $ScenarioSlug; migrationId = $payload.MigrationId
        environmentUrl = $EnvironmentUrl.TrimEnd('/'); solutionUniqueName = $SolutionUniqueName
        verifiedAtUtc = [DateTime]::UtcNow.ToString('o')
        globalChoiceCount = @($payload.GlobalChoices).Count; bindingCount = $verified
        inventory = $verifiedInventory; mutationCount = 0
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path (Split-Path $snapshotPath -Parent) "$ScenarioSlug-verification.json") -Encoding UTF8
    Write-Host "Choice migration Verify passed: $verified Picklist attributes; $(@($payload.GlobalChoices).Count) global choices; membership and values verified." -ForegroundColor Green
    exit 0
}

if (-not $ConfirmDestructiveMigration -or [string]::IsNullOrWhiteSpace($AuthorizationReference)) {
    throw 'Apply requires -ConfirmDestructiveMigration and a non-empty -AuthorizationReference.'
}
if (@($snapshot.bindings).Count -ne $contract.Plans.Count -or
    [int]$snapshot.bindingCount -ne $contract.Plans.Count -or
    [int]$snapshot.globalChoiceCount -ne $contract.Choices.Count) {
    throw 'Choice migration snapshot is stale or invalid; refresh Snapshot before Apply.'
}

$attributeStates = [System.Collections.Generic.List[object]]::new()
foreach ($plan in @($contract.Plans)) {
    $attribute = & $invoke Get "EntityDefinitions(LogicalName='$($plan.TableLogicalName)')/Attributes(LogicalName='$($plan.ColumnLogicalName)')?`$select=MetadataId,LogicalName,AttributeType"
    [void]$attributeStates.Add([pscustomobject]@{ Plan = $plan; Attribute = $attribute })
}
$picklistCount = @($attributeStates | Where-Object { "$($_.Attribute.AttributeType)" -eq 'Picklist' }).Count
if ($picklistCount -eq $contract.Plans.Count) {
    Write-Host 'Choice migration Apply skipped: all 29 attributes are already Picklist.' -ForegroundColor DarkGray
    exit 0
}
if ($picklistCount -gt 0 -or @($attributeStates | Where-Object { "$($_.Attribute.AttributeType)" -ne 'String' }).Count -gt 0) {
    throw 'Apply found a mixed or unsupported attribute state; use rollback evidence before retrying.'
}

foreach ($state in @($attributeStates)) {
    $dependencies = @((& $invoke Get "RetrieveDependenciesForDelete(ObjectId=$($state.Attribute.MetadataId),ComponentType=2)").value)
    if ($dependencies.Count -gt 0) {
        $types = @($dependencies.dependentcomponenttype | Sort-Object -Unique) -join ','
        throw "Apply is blocked: '$($state.Plan.TableLogicalName).$($state.Plan.ColumnLogicalName)' still has $($dependencies.Count) dependency record(s), component types [$types]."
    }
    $rowsResult = Get-ChoiceRows -Plan $state.Plan -TableMetadata $tableMetadata -Invoke $invoke
    Assert-ChoiceRowsAreSyntheticAndMapped -Plan $state.Plan -Rows @($rowsResult.Rows)
    Assert-ChoiceSnapshotIsCurrent -Snapshot $snapshot -Plan $state.Plan -Attribute $state.Attribute -RowsResult $rowsResult
}

$safeSolutionName = ConvertTo-WizardODataLiteral $SolutionUniqueName
$solutions = @((& $invoke Get "solutions?`$select=solutionid&`$filter=uniquename eq '$safeSolutionName'").value)
if ($solutions.Count -ne 1) { throw "Expected exactly one solution '$SolutionUniqueName'; found $($solutions.Count)." }
$solutionId = "$($solutions[0].solutionid)"
$getChoices = { param($Path) & $invoke Get $Path }
$existingGlobalChoices = @(Invoke-SolutionIsolationPagedGet -InvokeGet $getChoices -Path 'GlobalOptionSetDefinitions?$select=MetadataId,Name')
$globalChoiceIds = @{}
foreach ($choice in @($payload.GlobalChoices)) {
    $matches = @($existingGlobalChoices | Where-Object Name -CEQ "$($choice.Name)")
    if ($matches.Count -gt 1) { throw "Global choice '$($choice.Name)' resolved more than once." }
    if ($matches.Count -eq 1) {
        $metadata = & $invoke Get "GlobalOptionSetDefinitions(Name='$($choice.Name)')/Microsoft.Dynamics.CRM.OptionSetMetadata"
        Assert-WizardGlobalChoiceMetadata -Choice $choice -Metadata $metadata
        $choiceId = [guid]$metadata.MetadataId
        if ($choiceId -eq [guid]::Empty -or $choiceId -ne [guid]$matches[0].MetadataId) {
            throw "Global choice '$($choice.Name)' has an inconsistent metadata identity."
        }
        $globalChoiceIds["$($choice.Name)"] = $choiceId
    }
}
$createdChoiceNames = [System.Collections.Generic.List[string]]::new()
$deletedPlans = [System.Collections.Generic.List[object]]::new()
$createdPicklistPlans = [System.Collections.Generic.List[object]]::new()

try {
    foreach ($choice in @($payload.GlobalChoices)) {
        if (-not $globalChoiceIds.ContainsKey("$($choice.Name)")) {
            & $invoke Post 'GlobalOptionSetDefinitions' (New-WizardGlobalChoiceBody -Choice $choice -ScenarioSlug $ScenarioSlug -MigrationId $payload.MigrationId) | Out-Null
            [void]$createdChoiceNames.Add("$($choice.Name)")
            for ($attempt = 0; $attempt -lt 6; $attempt++) {
                $matches = @(Invoke-SolutionIsolationPagedGet -InvokeGet $getChoices -Path 'GlobalOptionSetDefinitions?$select=MetadataId,Name' |
                    Where-Object Name -CEQ "$($choice.Name)")
                if ($matches.Count -gt 0) { break }
                if ($attempt -lt 5) { Start-Sleep -Seconds 2 }
            }
            if ($matches.Count -ne 1) { throw "Global choice '$($choice.Name)' did not resolve exactly once." }
            $metadata = & $invoke Get "GlobalOptionSetDefinitions(Name='$($choice.Name)')/Microsoft.Dynamics.CRM.OptionSetMetadata"
            Assert-WizardGlobalChoiceMetadata -Choice $choice -Metadata $metadata
            $choiceId = [guid]$metadata.MetadataId
            if ($choiceId -eq [guid]::Empty -or $choiceId -ne [guid]$matches[0].MetadataId) {
                throw "Global choice '$($choice.Name)' has an inconsistent metadata identity."
            }
            $globalChoiceIds["$($choice.Name)"] = $choiceId
        }
        $choiceId = "$($globalChoiceIds[$choice.Name])"
        $membership = @((& $invoke Get "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $solutionId and objectid eq $choiceId and componenttype eq 9").value)
        if ($membership.Count -eq 0) {
            & $invoke Post 'AddSolutionComponent' @{
                ComponentId = $choiceId
                ComponentType = 9
                SolutionUniqueName = $SolutionUniqueName
                AddRequiredComponents = $false
            } | Out-Null
        }
    }

    foreach ($state in @($attributeStates)) {
        & $invoke Delete "EntityDefinitions(LogicalName='$($state.Plan.TableLogicalName)')/Attributes($($state.Attribute.MetadataId))" | Out-Null
        [void]$deletedPlans.Add($state.Plan)
    }
    foreach ($plan in @($contract.Plans)) {
        & $invoke Post "EntityDefinitions(LogicalName='$($plan.TableLogicalName)')/Attributes" (New-WizardPicklistColumnBody -Plan $plan -GlobalChoiceMetadataId $globalChoiceIds[$plan.GlobalChoiceName]) | Out-Null
        [void]$createdPicklistPlans.Add($plan)
    }
    foreach ($binding in @($snapshot.bindings)) {
        foreach ($row in @($binding.rows)) {
            & $invoke Patch "$($binding.entitySetName)($($row.id))" @{
                "$($binding.columnLogicalName)" = [int]$row.newValue
            } | Out-Null
        }
    }
    Publish-ChoiceMigrationTables -Plans @($contract.Plans) -Invoke $invoke
    foreach ($plan in @($contract.Plans)) {
        $attribute = & $invoke Get "EntityDefinitions(LogicalName='$($plan.TableLogicalName)')/Attributes(LogicalName='$($plan.ColumnLogicalName)')?`$select=MetadataId"
        & $invoke Post 'AddSolutionComponent' @{
            ComponentId = "$($attribute.MetadataId)"
            ComponentType = 2
            SolutionUniqueName = $SolutionUniqueName
            AddRequiredComponents = $false
        } | Out-Null
    }
} catch {
    $applyError = $_
    $rollbackErrors = [System.Collections.Generic.List[string]]::new()
    $rollbackPicklistPlans = @($createdPicklistPlans)
    [array]::Reverse($rollbackPicklistPlans)
    foreach ($plan in $rollbackPicklistPlans) {
        try {
            $attribute = & $invoke Get "EntityDefinitions(LogicalName='$($plan.TableLogicalName)')/Attributes(LogicalName='$($plan.ColumnLogicalName)')?`$select=MetadataId"
            & $invoke Delete "EntityDefinitions(LogicalName='$($plan.TableLogicalName)')/Attributes($($attribute.MetadataId))" | Out-Null
        } catch {
            [void]$rollbackErrors.Add("$($plan.TableLogicalName).$($plan.ColumnLogicalName): $($_.Exception.Message)")
        }
    }
    foreach ($plan in @($deletedPlans)) {
        try {
            & $invoke Post "EntityDefinitions(LogicalName='$($plan.TableLogicalName)')/Attributes" $plan.OriginalColumn | Out-Null
        } catch {
            [void]$rollbackErrors.Add("$($plan.TableLogicalName).$($plan.ColumnLogicalName): $($_.Exception.Message)")
        }
    }
    foreach ($binding in @($snapshot.bindings)) {
        foreach ($row in @($binding.rows)) {
            try {
                & $invoke Patch "$($binding.entitySetName)($($row.id))" @{
                    "$($binding.columnLogicalName)" = "$($row.oldValue)"
                } | Out-Null
            } catch {
                [void]$rollbackErrors.Add("$($binding.tableLogicalName).$($binding.columnLogicalName) row $($row.id): $($_.Exception.Message)")
            }
        }
    }
    try { Publish-ChoiceMigrationTables -Plans @($contract.Plans) -Invoke $invoke } catch {
        [void]$rollbackErrors.Add("Publish: $($_.Exception.Message)")
    }
    if ($rollbackErrors.Count -gt 0) {
        throw "Choice migration failed and rollback was incomplete. Apply error: $($applyError.Exception.Message). Rollback errors: $($rollbackErrors -join ' | ')"
    }
    throw "Choice migration failed; String columns and synthetic values were restored. Apply error: $($applyError.Exception.Message)"
}

New-Item -ItemType Directory -Path (Split-Path $applyEvidencePath -Parent) -Force | Out-Null
[ordered]@{
    scenarioSlug = $ScenarioSlug
    migrationId = "$($payload.MigrationId)"
    phase = 'Apply'
    environmentUrl = $EnvironmentUrl.TrimEnd('/')
    solutionUniqueName = $SolutionUniqueName
    authorizationReference = $AuthorizationReference
    appliedAtUtc = [DateTime]::UtcNow.ToString('o')
    globalChoiceCount = $contract.Choices.Count
    bindingCount = $contract.Plans.Count
    restoredSyntheticValueCount = @($snapshot.bindings.rows).Count
    dependencyPreflightCount = 0
    rollbackRequired = $false
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $applyEvidencePath -Encoding UTF8
Write-Host "Choice migration Apply passed: $($contract.Choices.Count) global choices; $($contract.Plans.Count) Picklist attributes." -ForegroundColor Green
