<#
=============================================================================
COMPONENT:    Additive Choice Migration
FILE:         scripts/bootstrap/helpers/choice-migration.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-20
ENVIRONMENT:  PowerShell 7 | Dataverse Web API | Offline injected tests
OVERVIEW:     Fail-closed global Choice metadata and preview-first row backfill.
NON-NEGOTIABLES: Legacy columns never change; no deletes; no row data in evidence.
=============================================================================
#>

function Get-WizardChoiceContract {
    param([Parameter(Mandatory)][string]$Folder)
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { return $null }
    $files = @(Get-ChildItem -LiteralPath $Folder -Filter 'choices-*.json' -File)
    if ($files.Count -eq 0) { return $null }
    if ($files.Count -ne 1) { throw 'Expected one Choice contract.' }
    $contract = Get-Content -LiteralPath $files[0].FullName -Raw | ConvertFrom-Json -AsHashtable
    if ($contract.Version -ne 1 -or $contract.ScenarioSlug -cne 'federal-foia-management' -or
        $contract.SolutionUniqueName -cne 'FederalFOIAManagement' -or $contract.PublisherPrefix -cne 'foia' -or
        $contract.SourceTagField -cne 'foia_syntheticsourcetag' -or $contract.SourceTag -cne 'federal-foia-synthetic-v1') {
        throw 'Unsupported Choice scenario/solution contract.'
    }
    $seen = @{}
    foreach ($name in $contract.Choices.Keys) {
        $labels = @($contract.Choices[$name])
        if ($name -cnotmatch '^foia_[a-z0-9_]+$' -or $labels.Count -eq 0 -or
            @($labels | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or
            @($labels | Group-Object | Where-Object Count -gt 1).Count -gt 0) { throw 'Invalid or ambiguous Choice options.' }
    }
    foreach ($field in $contract.Fields) {
        if ($field.Table -cnotmatch '^(foia_[a-z0-9_]+|contact|incident)$' -or
            $field.Source -cnotmatch '^foia_[a-z0-9_]+$' -or $field.Target -cne "$($field.Source)choice" -or
            -not $contract.Choices.Contains($field.Choice) -or [string]::IsNullOrWhiteSpace($field.Label)) { throw 'Invalid Choice field mapping.' }
        foreach ($kind in @('Source','Target')) {
            $key = "$($field.Table).$($field[$kind])"
            if ($seen.ContainsKey($key)) { throw 'Duplicate or overlapping Choice field mapping.' }
            $seen[$key] = $true
        }
        $map = @{}
        for ($index = 0; $index -lt $contract.Choices[$field.Choice].Count; $index++) {
            $map[$contract.Choices[$field.Choice][$index]] = 100000000 + $index
        }
        foreach ($alias in $field.Aliases.Keys) {
            $value = $field.Aliases[$alias]
            if ([string]::IsNullOrWhiteSpace($alias) -or $alias -cne $alias.Trim() -or
                ($null -ne $value -and ($value -isnot [int] -and $value -isnot [long] -or
                 $value -lt 100000000 -or $value -ge (100000000 + $contract.Choices[$field.Choice].Count)))) {
                throw 'Invalid Choice alias value.'
            }
            if ($map.ContainsKey($alias) -and $map[$alias] -ne $value) { throw 'Ambiguous Choice alias.' }
            $map[$alias] = $value
        }
        $field.Map = $map
    }
    return $contract
}

function ConvertTo-WizardChoiceValue {
    param([Parameter(Mandatory)]$Field, $Value)
    if ($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) { return $null }
    if ($Value -isnot [string] -or -not $Field.Map.ContainsKey($Value.Trim())) {
        throw 'Unmapped categorical value detected (at least 1); review mappings privately. No rows written.'
    }
    return $Field.Map[$Value.Trim()]
}

function Assert-WizardChoiceInteger {
    param($Value, [int]$Count)
    if ($null -ne $Value -and (($Value -isnot [int] -and $Value -isnot [long]) -or
        $Value -lt 100000000 -or $Value -ge (100000000 + $Count))) { throw 'Invalid Choice integer.' }
}

function New-WizardChoiceLabel {
    param([string]$Text)
    return @{ LocalizedLabels = @(@{ Label = $Text; LanguageCode = 1033 }) }
}

function Assert-WizardChoiceOptions {
    param($Metadata, [string[]]$Labels)
    if (-not $Metadata.IsGlobal -or $Metadata.OptionSetType -ne 'Picklist' -or
        @($Metadata.Options).Count -ne $Labels.Count) { throw 'Global Choice type/options conflict.' }
    for ($index = 0; $index -lt $Labels.Count; $index++) {
        $options = @($Metadata.Options | Where-Object Value -eq (100000000 + $index))
        if ($options.Count -ne 1) { throw 'Global Choice numeric options conflict.' }
        $localized = @($options[0].Label.LocalizedLabels | Where-Object LanguageCode -eq 1033)
        if ($localized.Count -ne 1 -or $localized[0].Label -cne $Labels[$index]) { throw 'Global Choice label conflict.' }
    }
}

function Invoke-WizardChoiceMigration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PayloadsFolder,
        [Parameter(Mandatory)][string]$ScenarioSlug,
        [Parameter(Mandatory)][string]$SolutionUniqueName,
        [Parameter(Mandatory)][string]$EnvironmentUrl,
        [Parameter(Mandatory)][string]$AccessToken,
        [ValidateSet('Metadata','Backfill','Validate')][string]$Mode = 'Metadata',
        [switch]$Apply,
        [switch]$ApproveBackfill,
        [switch]$AcknowledgeWriteFreeze,
        [ValidateRange(1,100000)][int]$MaxRows = 10000,
        [ValidateRange(1,5000)][int]$PageSize = 250,
        [scriptblock]$RequestInvoker,
        [scriptblock]$TokenProvider,
        [scriptblock]$SleepAction
    )
    $contract = Get-WizardChoiceContract $PayloadsFolder
    if ($null -eq $contract -or $ScenarioSlug -cne $contract.ScenarioSlug -or
        $SolutionUniqueName -cne $contract.SolutionUniqueName -or
        [string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
        throw 'Choice migration requires explicit matching scenario, environment and solution.'
    }
    if ($Apply -and $Mode -eq 'Validate') { throw 'Validate is read-only.' }
    if ($Apply -and $Mode -eq 'Backfill' -and -not $ApproveBackfill) { throw 'Backfill requires separate approval after preview.' }
    if (($Mode -eq 'Validate' -or ($Apply -and $Mode -eq 'Backfill')) -and -not $AcknowledgeWriteFreeze) {
        throw 'Write freeze acknowledgement required for backfill apply and cutover validation.'
    }
    $invoke = {
        param($method, $path, $body = $null, $headers = @{})
        Invoke-WizardDataverseRequest -Method $method -Path $path -Body $body -AdditionalHeaders $headers `
            -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker `
            -TokenProvider $TokenProvider -SleepAction $SleepAction
    }
    $getOptional = {
        param($path)
        try { & $invoke Get $path } catch {
            if ((Get-WizardHttpStatusCode $_) -ne 404) { throw 'Choice metadata read failed (not a missing component).' }
            return $null
        }
    }
    # All metadata conflicts and ownership checks are resolved before any mutation.
    $solutions = @((& $invoke Get "solutions?`$select=solutionid,ismanaged&`$expand=publisherid(`$select=customizationprefix)&`$filter=uniquename eq '$SolutionUniqueName'").value)
    if ($solutions.Count -ne 1 -or $solutions[0].ismanaged -or
        $solutions[0].publisherid.customizationprefix -cne $contract.PublisherPrefix) { throw 'Choice solution/publisher safety check failed.' }
    $solutionId = [guid]$solutions[0].solutionid
    $tables = @{}
    $globals = @{}
    $attributes = @{}
    $inventory = [Collections.Generic.List[object]]::new()
    foreach ($name in $contract.Choices.Keys) {
        $existing = & $getOptional "GlobalOptionSetDefinitions(Name='$name')"
        if ($null -ne $existing) {
            Assert-WizardChoiceOptions $existing $contract.Choices[$name]
            if ($Mode -ne 'Metadata') {
                $choiceId = [guid]$existing.MetadataId
                $members = @((& $invoke Get "solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $solutionId and componenttype eq 9 and objectid eq $choiceId").value)
                if ($members.Count -ne 1) { throw 'Global Choice is missing from selected solution.' }
            }
        }
        elseif ($Mode -ne 'Metadata') { throw 'Choice metadata missing; apply additive metadata first.' }
        $globals[$name] = $existing
    }
    foreach ($group in @($contract.Fields | Group-Object Table)) {
        $table = $group.Name
        $meta = & $invoke Get "EntityDefinitions(LogicalName='$table')?`$select=MetadataId,LogicalName,EntitySetName,PrimaryIdAttribute,IsOptimisticConcurrencyEnabled"
        if ($meta.LogicalName -cne $table -or $meta.EntitySetName -cnotmatch '^[a-z][a-z0-9_]+$' -or
            $meta.PrimaryIdAttribute -cnotmatch '^[a-z][a-z0-9_]+$') { throw 'Invalid Choice table metadata.' }
        $tableId = [guid]$meta.MetadataId
        $membership = @((& $invoke Get "solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $solutionId and componenttype eq 1 and objectid eq $tableId").value)
        if ($membership.Count -ne 1) { throw 'Choice table must already belong to selected solution.' }
        if ($Mode -ne 'Metadata' -and -not $meta.IsOptimisticConcurrencyEnabled) { throw 'Choice backfill requires optimistic concurrency.' }
        $tables[$table] = $meta
        foreach ($field in $group.Group) {
            $source = & $invoke Get "EntityDefinitions(LogicalName='$table')/Attributes(LogicalName='$($field.Source)')?`$select=AttributeType"
            if ($source.AttributeType -ne 'String') { throw 'Legacy source type conflict; no conversion is allowed.' }
            $target = & $getOptional "EntityDefinitions(LogicalName='$table')/Attributes(LogicalName='$($field.Target)')"
            if ($null -ne $target) {
                if ($target.AttributeType -ne 'Picklist') { throw 'Target Choice type conflict.' }
                $picklist = & $invoke Get "EntityDefinitions(LogicalName='$table')/Attributes(LogicalName='$($field.Target)')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$expand=OptionSet"
                if ($picklist.OptionSet.Name -cne $field.Choice) { throw 'Target global Choice binding conflict.' }
                Assert-WizardChoiceOptions $picklist.OptionSet $contract.Choices[$field.Choice]
                if ($Mode -ne 'Metadata') {
                    $columnId = [guid]$picklist.MetadataId
                    $members = @((& $invoke Get "solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $solutionId and componenttype eq 2 and objectid eq $columnId").value)
                    if ($members.Count -ne 1) { throw 'Choice column is missing from selected solution.' }
                }
            } elseif ($Mode -ne 'Metadata') { throw 'Target Choice column missing.' }
            $attributes["$table.$($field.Target)"] = $target
        }
    }
    if ($Mode -eq 'Metadata') {
        if ($Apply) {
            $solutionHeader = @{ 'MSCRM.SolutionUniqueName' = $SolutionUniqueName }
            foreach ($name in $contract.Choices.Keys) {
                if ($null -eq $globals[$name]) {
                    $options = @(for ($i = 0; $i -lt $contract.Choices[$name].Count; $i++) {
                        @{ Value = 100000000 + $i; Label = New-WizardChoiceLabel $contract.Choices[$name][$i] }
                    })
                    & $invoke Post 'GlobalOptionSetDefinitions' @{
                        '@odata.type'='Microsoft.Dynamics.CRM.OptionSetMetadata'; Name=$name; IsGlobal=$true
                        OptionSetType='Picklist'; DisplayName=(New-WizardChoiceLabel $name); Options=$options
                    } $solutionHeader | Out-Null
                }
                $globalChoice = & $invoke Get "GlobalOptionSetDefinitions(Name='$name')"
                Assert-WizardChoiceOptions $globalChoice $contract.Choices[$name]
                $globals[$name] = $globalChoice
                $choiceId = [guid]$globalChoice.MetadataId
                $before = @((& $invoke Get "solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $solutionId and componenttype eq 9 and objectid eq $choiceId").value)
                if ($before.Count -eq 0) {
                    & $invoke Post 'AddSolutionComponent' @{
                        ComponentId=$choiceId; ComponentType=9; SolutionUniqueName=$SolutionUniqueName
                        AddRequiredComponents=$false; DoNotIncludeSubcomponents=$true
                    } | Out-Null
                } elseif ($before.Count -ne 1) { throw 'Ambiguous global Choice solution membership.' }
                $members = @((& $invoke Get "solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $solutionId and componenttype eq 9 and objectid eq $choiceId").value)
                if ($members.Count -ne 1) { throw 'Global Choice missing after solution sync.' }
                $inventory.Add([pscustomobject]@{ Kind='global-choice'; Name=$name; Id="$choiceId"; ComponentType=9; Membership=$(if ($before.Count -eq 0) {'Added'} else {'Already in solution'}) })
            }
            foreach ($field in $contract.Fields) {
                if ($null -eq $attributes["$($field.Table).$($field.Target)"]) {
                    & $invoke Post "EntityDefinitions(LogicalName='$($field.Table)')/Attributes" @{
                        '@odata.type'='Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
                        SchemaName=$field.Target; LogicalName=$field.Target
                        DisplayName=(New-WizardChoiceLabel $field.Label)
                        RequiredLevel=@{ Value='None' }
                        'GlobalOptionSet@odata.bind'="/GlobalOptionSetDefinitions($([guid]$globals[$field.Choice].MetadataId))"
                    } $solutionHeader | Out-Null
                }
                $created = & $invoke Get "EntityDefinitions(LogicalName='$($field.Table)')/Attributes(LogicalName='$($field.Target)')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$expand=OptionSet"
                if ($created.AttributeType -ne 'Picklist' -or $created.OptionSet.Name -cne $field.Choice) { throw 'Created Choice metadata verification failed.' }
                Assert-WizardChoiceOptions $created.OptionSet $contract.Choices[$field.Choice]
                $columnId = [guid]$created.MetadataId
                $before = @((& $invoke Get "solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $solutionId and componenttype eq 2 and objectid eq $columnId").value)
                if ($before.Count -eq 0) {
                    & $invoke Post 'AddSolutionComponent' @{
                        ComponentId=$columnId; ComponentType=2; SolutionUniqueName=$SolutionUniqueName
                        AddRequiredComponents=$false
                    } | Out-Null
                } elseif ($before.Count -ne 1) { throw 'Ambiguous Choice column solution membership.' }
                $members = @((& $invoke Get "solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $solutionId and componenttype eq 2 and objectid eq $columnId").value)
                if ($members.Count -ne 1) { throw 'Choice column missing after solution sync.' }
                $inventory.Add([pscustomobject]@{ Kind='column'; Name="$($field.Table).$($field.Target)"; Id="$columnId"; ComponentType=2; Membership=$(if ($before.Count -eq 0) {'Added'} else {'Already in solution'}) })
            }
            $entities = ($tables.Keys | Sort-Object | ForEach-Object { "<entity>$_</entity>" }) -join ''
            $optionSets = ($contract.Choices.Keys | Sort-Object | ForEach-Object { "<optionset>$_</optionset>" }) -join ''
            & $invoke Post 'PublishXml' @{ ParameterXml="<importexportxml><entities>$entities</entities><optionsets>$optionSets</optionsets></importexportxml>" } | Out-Null
        }
        return [pscustomobject]@{ Mode=$Mode; Applied=[bool]$Apply; GlobalChoices=$globals.Count; Columns=$attributes.Count; Rows=0; Pending=0; Inventory=@($inventory.ToArray()) }
    }
    $pending = [Collections.Generic.List[object]]::new()
    $rowCount = 0
    $historicalTablesExcluded = @('foia_clockevent', 'foia_auditevent')
    foreach ($table in @($tables.Keys | Where-Object { $_ -notin $historicalTablesExcluded } | Sort-Object)) {
        $meta = $tables[$table]
        $fields = @($contract.Fields | Where-Object Table -eq $table)
        $select = @($meta.PrimaryIdAttribute, $contract.SourceTagField) + @($fields.Source) + @($fields.Target)
        $filter = (@($fields.Source) + @($fields.Target) | ForEach-Object { "$_ ne null" }) -join ' or '
        $path = "$($meta.EntitySetName)?`$select=$($select -join ',')&`$filter=$filter&`$orderby=$($meta.PrimaryIdAttribute)&`$top=$($MaxRows + 1)"
        $pages = 0
        $seenIds = @{}
        $seenPages = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        do {
            if (-not $seenPages.Add($path)) { throw 'Choice continuation loop detected; no rows written.' }
            if (++$pages -gt $MaxRows + 1) { throw 'Choice paging limit exceeded.' }
            $page = & $invoke Get $path $null @{ Prefer="odata.maxpagesize=$PageSize" }
            foreach ($row in @($page.value)) {
                if (++$rowCount -gt $MaxRows) { throw 'Choice row bound exceeded; increase explicitly after review. No rows written.' }
                $id = [guid]$row.($meta.PrimaryIdAttribute)
                if ($seenIds.ContainsKey("$id")) { throw 'Duplicate Choice source row; no rows written.' }
                $seenIds["$id"] = $true
                $body = @{}
                foreach ($field in $fields) {
                    if ($row.PSObject.Properties.Name -notcontains $field.Source -or
                        $row.PSObject.Properties.Name -notcontains $field.Target) { throw 'Choice source read is incomplete.' }
                }
                $hasCategoricalData = @($fields | Where-Object {
                    -not [string]::IsNullOrWhiteSpace("$($row.($_.Source))") -or $null -ne $row.($_.Target)
                }).Count -gt 0
                if ($hasCategoricalData -and ($row.PSObject.Properties.Name -notcontains $contract.SourceTagField -or
                    $row.($contract.SourceTagField) -cne $contract.SourceTag)) { throw 'Choice source row is outside approved scenario ownership; no rows written.' }
                foreach ($field in $fields) {
                    $value = ConvertTo-WizardChoiceValue $field $row.($field.Source)
                    $targetValue = $row.($field.Target)
                    Assert-WizardChoiceInteger $targetValue $contract.Choices[$field.Choice].Count
                    if ($null -ne $targetValue) {
                        if (-not [string]::IsNullOrWhiteSpace("$($row.($field.Source))") -and $targetValue -ne $value) {
                            throw "Conflicting target in $table.$($field.Target); no rows written."
                        }
                    } elseif ($null -ne $value) { $body[$field.Target] = $value }
                }
                if ($body.Count -gt 0) {
                    $etag = $row.PSObject.Properties['@odata.etag']
                    if ($null -eq $etag -or "$($etag.Value)" -notmatch '^W/"[0-9]+"$') { throw 'Missing safe row concurrency token.' }
                    $pending.Add(@{ Table=$table; Path="$($meta.EntitySetName)($id)"; Body=$body; ETag=$etag.Value })
                }
            }
            $next = $page.PSObject.Properties['@odata.nextLink']
            $path = if ($null -eq $next -or [string]::IsNullOrWhiteSpace("$($next.Value)")) { '' } else {
                $prefix = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$($meta.EntitySetName)?"
                if (-not "$($next.Value)".StartsWith($prefix, [StringComparison]::Ordinal)) { throw 'Unsafe Choice continuation URL.' }
                "$($next.Value)".Substring("$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/".Length)
            }
        } while ($path)
    }
    if ($Mode -eq 'Validate' -and $pending.Count -gt 0) { throw 'Choice cutover blocked: backfill is incomplete.' }
    if ($Apply) {
        foreach ($item in $pending) {
            try { & $invoke Patch $item.Path $item.Body @{ 'If-Match'=$item.ETag } | Out-Null }
            catch { throw 'Choice row update failed; stop and preview again. Earlier rows may be migrated; legacy data is intact.' }
        }
    }
    return [pscustomobject]@{ Mode=$Mode; Applied=[bool]$Apply; Rows=$rowCount; Pending=$pending.Count; Updated= $(if ($Apply) { $pending.Count } else { 0 }); HistoricalTablesExcluded=$historicalTablesExcluded }
}

function Assert-WizardChoiceCutover {
    param([string]$PayloadsFolder, [string]$ScenarioSlug, [string]$SolutionUniqueName,
        [string]$EnvironmentUrl, [string]$AccessToken, [scriptblock]$RequestInvoker, [switch]$AcknowledgeWriteFreeze,
        [ValidateRange(1,100000)][int]$ChoiceMaxRows = 10000)
    if ($null -eq (Get-WizardChoiceContract $PayloadsFolder)) { return }
    Invoke-WizardChoiceMigration -PayloadsFolder $PayloadsFolder -ScenarioSlug $ScenarioSlug `
        -SolutionUniqueName $SolutionUniqueName -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken `
        -Mode Validate -RequestInvoker $RequestInvoker `
        -AcknowledgeWriteFreeze:$AcknowledgeWriteFreeze -MaxRows $ChoiceMaxRows | Out-Null
}

function Assert-WizardChoiceSeedPayload {
    param($Payload, [string]$PayloadsFolder)
    $contract = Get-WizardChoiceContract $PayloadsFolder
    if ($null -eq $contract) { return }
    foreach ($table in $Payload.Tables) {
        $fields = @($contract.Fields | Where-Object Table -eq $table.TableLogicalName)
        foreach ($record in $table.Records) {
            foreach ($field in $fields) {
                if ($record.Values.PSObject.Properties.Name -contains $field.Source) { throw 'Legacy categorical seed writes are forbidden.' }
                $value = $record.Values.PSObject.Properties[$field.Target]
                if ($null -ne $value) { Assert-WizardChoiceInteger $value.Value $contract.Choices[$field.Choice].Count }
            }
            foreach ($property in $record.Values.PSObject.Properties) {
                if ($property.Name -like '*choice' -and $property.Name -notin @($fields | ForEach-Object Target)) { throw 'Unknown seed Choice column.' }
            }
        }
    }
}
