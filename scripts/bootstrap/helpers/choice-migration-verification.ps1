<#
=============================================================================
COMPONENT:    Choice Migration Verification
FILE:         scripts/bootstrap/helpers/choice-migration-verification.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-11-04
ENVIRONMENT:  PowerShell 7 | Current Choice provisioning and exact assertions
=============================================================================
#>

. (Join-Path $PSScriptRoot 'choice-presentation-tokens.ps1')

function Get-WizardEffectiveChoiceContract {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug,
        [string]$SolutionUniqueName,
        [string]$PublisherPrefix = '',
        [string]$PayloadsFolder = '',
        [switch]$Required,
        [switch]$PreMigrationBackup
    )

    if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
        $PayloadsFolder = Join-Path $RepoRoot "payloads/scenarios/$ScenarioSlug"
    }
    $files = @(if (Test-Path -LiteralPath $PayloadsFolder -PathType Container) {
        Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'choice-migration-*.json' -File
    })
    if ($files.Count -gt 1) { throw 'Effective Choice contract requires exactly one migration payload.' }
    $declared = $false
    if ($files.Count -eq 1) {
        $document = Get-Content -LiteralPath $files[0].FullName -Raw | ConvertFrom-Json -Depth 40
        $declared = $null -ne $document.PSObject.Properties['CurrentSchema']
    }
    $payload = Get-WizardRequiredChoiceMigration -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug `
        -SolutionUniqueName $SolutionUniqueName -PayloadsFolder $PayloadsFolder `
        -Required:($Required -or ($declared -and -not $PreMigrationBackup))
    if ($null -eq $payload) { return $null }
    if ($declared) {
        $identity = $payload.CurrentSchema
        if ($identity.ScenarioSlug -cne $ScenarioSlug -or $identity.SolutionUniqueName -cne $SolutionUniqueName -or
            (-not [string]::IsNullOrWhiteSpace($PublisherPrefix) -and $identity.PublisherPrefix -cne $PublisherPrefix)) {
            throw 'Current Choice schema identity does not match the scenario, solution, or publisher.'
        }
        foreach ($name in @($payload.GlobalChoices.Name) + @($payload.Bindings.ColumnLogicalName)) {
            if (-not $name.StartsWith("$($identity.PublisherPrefix)_", [StringComparison]::Ordinal)) {
                throw "Current Choice schema component '$name' does not match its publisher."
            }
            if (@($payload.GlobalChoices | Group-Object Name | Where-Object Count -ne 1).Count -gt 0 -or
                @($payload.Bindings | Group-Object TableLogicalName,ColumnLogicalName | Where-Object Count -ne 1).Count -gt 0) {
                throw 'Current Choice schema has duplicate definitions or bindings.'
            }
            foreach ($choice in $payload.GlobalChoices) {
                if (@($choice.Options | Group-Object Value | Where-Object Count -ne 1).Count -gt 0) {
                    throw "Current Choice schema '$($choice.Name)' has duplicate option values."
                }
            }
            foreach ($binding in $payload.Bindings) {
                $choice = @($payload.GlobalChoices | Where-Object Name -ceq $binding.GlobalChoiceName)
                if ($choice.Count -ne 1 -or @($binding.ValueMap.PSObject.Properties.Value | Where-Object { $_ -notin @($choice[0].Options.Value) }).Count -gt 0) {
                    throw 'Current Choice schema has an undefined choice or value mapping.'
                }
            }
        }
    }
    return $payload
}

function Get-WizardRequiredChoiceMigration {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug,
        [string]$SolutionUniqueName,
        [string]$PayloadsFolder = '',
        [switch]$Required
    )

    $evidencePath = Join-Path $RepoRoot ".wizard-metrics/artifacts/choice-migration/$ScenarioSlug-apply.json"
    $evidence = if (Test-Path -LiteralPath $evidencePath -PathType Leaf) {
        Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
    } else { $null }
    if (-not $Required -and $null -eq $evidence) { return $null }
    if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
        $PayloadsFolder = Join-Path $RepoRoot "payloads/scenarios/$ScenarioSlug"
    }
    $files = @(if (Test-Path -LiteralPath $PayloadsFolder -PathType Container) {
        Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'choice-migration-*.json' -File
    })
    if ($files.Count -ne 1) { throw 'Choice verification requires exactly one migration payload.' }
    $json = Get-Content -LiteralPath $files[0].FullName -Raw
    if (-not (Test-Json -Json $json -SchemaFile (Join-Path $RepoRoot 'schemas/payloads/choice-migration.schema.json'))) {
        throw 'Choice verification migration payload failed schema validation.'
    }
    $payload = $json | ConvertFrom-Json -Depth 40
    if ($null -ne $evidence -and (
        $evidence.scenarioSlug -cne $ScenarioSlug -or $evidence.migrationId -cne $payload.MigrationId -or
        $evidence.solutionUniqueName -cne $SolutionUniqueName -or $evidence.phase -cne 'Apply' -or
        $evidence.rollbackRequired -ne $false)) {
        throw 'Choice migration Apply evidence does not match the scenario, solution, or migration.'
    }
    return $payload
}

function New-WizardLocalizedLabel {
    param([Parameter(Mandatory)] [string]$Text)

    $localized = [ordered]@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'
        Label = $Text
        LanguageCode = 1033
        IsManaged = $false
    }
    return [ordered]@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.Label'
        LocalizedLabels = @($localized)
        UserLocalizedLabel = $localized
    }
}

function New-WizardGlobalChoiceBody {
    param([Parameter(Mandatory)] [object]$Choice, [string]$ScenarioSlug, [string]$MigrationId)

    return [ordered]@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'
        Name = "$($Choice.Name)"
        DisplayName = New-WizardLocalizedLabel -Text "$($Choice.DisplayName)"
        Description = New-WizardLocalizedLabel -Text "Wizard scenario=$ScenarioSlug; migration=$MigrationId"
        OptionSetType = 'Picklist'
        IsGlobal = $true
        Options = @($Choice.Options | ForEach-Object {
            [ordered]@{
                Value = [int]$_.Value
                Label = New-WizardLocalizedLabel -Text (Get-WizardChoiceDisplayLabel -Option $_)
                Color = Get-WizardChoiceColor -Option $_
            }
        })
    }
}

function Assert-WizardChoiceColumnCompatibility {
    param([object]$Payload, [scriptblock]$InvokeGet, [switch]$AllowMissing)

    . (Join-Path $PSScriptRoot 'solution-isolation.ps1')
    foreach ($group in @($Payload.Bindings | Group-Object TableLogicalName)) {
        $attributes = @(Invoke-SolutionIsolationPagedGet -InvokeGet $InvokeGet `
            -Path "EntityDefinitions(LogicalName='$($group.Name)')/Attributes?`$select=LogicalName,AttributeType")
        foreach ($binding in $group.Group) {
            $matches = @($attributes | Where-Object LogicalName -eq $binding.ColumnLogicalName)
            if ($matches.Count -eq 0 -and $AllowMissing) { continue }
            if ($matches.Count -ne 1 -or $matches[0].AttributeType -ne 'Picklist') {
                throw "Current Choice field '$($group.Name).$($binding.ColumnLogicalName)' is missing or incompatible; use the separately approved migration path for existing text."
            }
            $attribute = & $InvokeGet "EntityDefinitions(LogicalName='$($group.Name)')/Attributes(LogicalName='$($binding.ColumnLogicalName)')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName,AttributeType&`$expand=GlobalOptionSet"
            if ($attribute.GlobalOptionSet.Name -cne $binding.GlobalChoiceName) {
                throw "Current Choice field '$($group.Name).$($binding.ColumnLogicalName)' has an incompatible global binding."
            }
        }
    }
}

function Initialize-WizardCurrentChoices {
    param(
        [object]$Payload,
        [string]$ScenarioSlug,
        [scriptblock]$Invoke,
        [switch]$PreviewOnly,
        [scriptblock]$SleepAction = { param($seconds) Start-Sleep -Seconds $seconds }
    )

    . (Join-Path $PSScriptRoot 'solution-isolation.ps1')
    $get = { param($path) & $Invoke Get $path }.GetNewClosure()
    Assert-WizardChoiceColumnCompatibility -Payload $Payload -InvokeGet $get -AllowMissing
    $existing = @(Invoke-SolutionIsolationPagedGet -InvokeGet $get -Path 'GlobalOptionSetDefinitions?$select=MetadataId,Name')
    $resolved = @{}
    foreach ($choice in $Payload.GlobalChoices) {
        $matches = @($existing | Where-Object Name -eq $choice.Name)
        if ($matches.Count -gt 1) { throw "Global choice '$($choice.Name)' resolved more than once." }
        if ($matches.Count -eq 1) {
            $metadata = & $get "GlobalOptionSetDefinitions(Name='$($choice.Name)')/Microsoft.Dynamics.CRM.OptionSetMetadata"
            Assert-WizardGlobalChoiceMetadata -Choice $choice -Metadata $metadata
            $resolved[$choice.Name] = ([guid]$metadata.MetadataId).ToString()
        }
    }
    foreach ($choice in $Payload.GlobalChoices) {
        $action = 'existing'
        if (-not $resolved.ContainsKey($choice.Name)) {
            $action = 'planned'
            if (-not $PreviewOnly) {
                & $Invoke Post 'GlobalOptionSetDefinitions' (New-WizardGlobalChoiceBody -Choice $choice -ScenarioSlug $ScenarioSlug -MigrationId $Payload.MigrationId) | Out-Null
                $matches = @()
                for ($attempt = 0; $attempt -lt 6; $attempt++) {
                    $visible = @(Invoke-SolutionIsolationPagedGet -InvokeGet $get -Path 'GlobalOptionSetDefinitions?$select=MetadataId,Name')
                    $matches = @($visible | Where-Object Name -eq $choice.Name)
                    if ($matches.Count -gt 0) { break }
                    if ($attempt -lt 5) { & $SleepAction 2 }
                }
                if ($matches.Count -ne 1) { throw "Global choice '$($choice.Name)' did not become uniquely visible." }
                $metadata = & $get "GlobalOptionSetDefinitions(Name='$($choice.Name)')/Microsoft.Dynamics.CRM.OptionSetMetadata"
                Assert-WizardGlobalChoiceMetadata -Choice $choice -Metadata $metadata
                $resolved[$choice.Name] = ([guid]$metadata.MetadataId).ToString()
                $action = 'created'
            }
        }
        [pscustomobject]@{ Name = $choice.Name; MetadataId = $resolved[$choice.Name]; Action = $action }
    }
}

function ConvertTo-WizardMigratedColumn {
    param([object]$Payload, [string]$TableLogicalName, [object]$Column)

    $binding = @($Payload.Bindings | Where-Object {
        $_.TableLogicalName -eq $TableLogicalName -and $_.ColumnLogicalName -eq $Column.LogicalName
    })
    if ($binding.Count -eq 0) { return $Column }
    if ($binding.Count -ne 1) { throw 'Migrated column binding is ambiguous.' }
    $result = $Column | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $result.'@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
    foreach ($name in @('MaxLength', 'Format', 'FormatName')) { $result.PSObject.Properties.Remove($name) }
    $result | Add-Member -NotePropertyName AttributeType -NotePropertyValue 'Picklist' -Force
    $result | Add-Member -NotePropertyName AttributeTypeName -NotePropertyValue @{ Value = 'PicklistType' } -Force
    $result | Add-Member -NotePropertyName 'GlobalOptionSet@odata.bind' -NotePropertyValue "/GlobalOptionSetDefinitions(Name='$($binding[0].GlobalChoiceName)')" -Force
    return $result
}

function ConvertTo-WizardMigratedValues {
    param([object]$Payload, [string]$TableLogicalName, [System.Collections.IDictionary]$Values)

    foreach ($binding in @($Payload.Bindings | Where-Object TableLogicalName -eq $TableLogicalName)) {
        $name = $binding.ColumnLogicalName
        if (-not $Values.Contains($name) -or $null -eq $Values[$name]) { continue }
        $value = $Values[$name]
        $choice = @($Payload.GlobalChoices | Where-Object Name -eq $binding.GlobalChoiceName)
        if ($value -is [int] -or $value -is [long]) {
            if ($choice.Count -ne 1 -or $value -notin @($choice[0].Options.Value)) {
                throw "Migrated seed field '$TableLogicalName.$name' has an undefined numeric value."
            }
        } else {
            $mapped = $binding.ValueMap.PSObject.Properties["$value"]
            if ($null -eq $mapped) { throw "Migrated seed field '$TableLogicalName.$name' has an unmapped label." }
            $Values[$name] = [int]$mapped.Value
            if ($choice.Count -ne 1 -or $Values[$name] -notin @($choice[0].Options.Value)) {
                throw "Migrated seed field '$TableLogicalName.$name' maps to an undefined numeric value."
            }
        }
    }
}

function Assert-WizardChoiceOptions {
    param([object]$Choice, [object[]]$Options)

    if ($Options.Count -ne @($Choice.Options).Count) {
        throw "Global choice '$($Choice.Name)' has an incorrect option count."
    }
    foreach ($expected in @($Choice.Options)) {
        $matches = @($Options | Where-Object { $_.Value -eq $expected.Value })
        if ($matches.Count -ne 1 -or $matches[0].Label -cne (Get-WizardChoiceDisplayLabel -Option $expected)) {
            throw "Global choice '$($Choice.Name)' has an incorrect value or English label for '$($expected.Value)'."
        }
        $color = Get-WizardChoiceColor -Option $expected
        if ($null -ne $color -and ($null -eq $matches[0].PSObject.Properties['Color'] -or $matches[0].Color -ine $color)) {
            throw "Global choice '$($Choice.Name)' has an incorrect color for '$($expected.Value)'."
        }
    }
}

function Assert-WizardGlobalChoiceMetadata {
    param([object]$Choice, [object]$Metadata)

    if ($Metadata.Name -cne $Choice.Name -or $Metadata.IsGlobal -ne $true -or $Metadata.OptionSetType -ne 'Picklist') {
        throw "Global choice '$($Choice.Name)' is not the expected global Picklist."
    }
    $options = @($Metadata.Options | ForEach-Object {
        $labels = @($_.Label.LocalizedLabels | Where-Object LanguageCode -eq 1033)
        if ($labels.Count -ne 1) { throw "Global choice '$($Choice.Name)' requires one English label per option." }
        [pscustomobject]@{ Value = $_.Value; Label = $labels[0].Label; Color = $_.Color }
    })
    Assert-WizardChoiceOptions -Choice $Choice -Options $options
}

function Get-WizardChoiceMigrationInventory {
    param(
        [object]$Payload,
        [string]$SolutionId,
        [scriptblock]$InvokeGet
    )

    $inventory = [Collections.Generic.List[object]]::new()
    $choiceIds = @{}
    foreach ($choice in @($Payload.GlobalChoices)) {
        $metadata = & $InvokeGet "GlobalOptionSetDefinitions(Name='$($choice.Name)')/Microsoft.Dynamics.CRM.OptionSetMetadata"
        Assert-WizardGlobalChoiceMetadata -Choice $choice -Metadata $metadata
        $choiceId = ([guid]$metadata.MetadataId).ToString()
        $members = @((& $InvokeGet "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $SolutionId and objectid eq $choiceId and componenttype eq 9").value)
        if ($members.Count -ne 1) { throw "Global choice '$($choice.Name)' lacks unique solution membership." }
        $choiceIds[$choice.Name] = $choiceId
        $inventory.Add([pscustomobject]@{
            Kind = 'global-choice'; Category = 'global-choices'; Name = $choice.Name
            ObjectId = $choiceId; ComponentType = 9; SolutionComponentId = "$($members[0].solutioncomponentid)"
        })
    }
    foreach ($binding in @($Payload.Bindings)) {
        $name = "$($binding.TableLogicalName).$($binding.ColumnLogicalName)"
        $attribute = & $InvokeGet "EntityDefinitions(LogicalName='$($binding.TableLogicalName)')/Attributes(LogicalName='$($binding.ColumnLogicalName)')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=MetadataId,LogicalName,AttributeType&`$expand=GlobalOptionSet"
        if ($attribute.AttributeType -ne 'Picklist' -or $attribute.LogicalName -cne $binding.ColumnLogicalName -or
            $attribute.GlobalOptionSet.Name -cne $binding.GlobalChoiceName -or
            "$($attribute.GlobalOptionSet.MetadataId)" -ne $choiceIds[$binding.GlobalChoiceName]) {
            throw "Choice column '$name' has an incorrect type or global choice binding."
        }
        $attributeId = ([guid]$attribute.MetadataId).ToString()
        $members = @((& $InvokeGet "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $SolutionId and objectid eq $attributeId and componenttype eq 2").value)
        if ($members.Count -eq 0) {
            $table = & $InvokeGet "EntityDefinitions(LogicalName='$($binding.TableLogicalName)')?`$select=MetadataId"
            $tableId = ([guid]$table.MetadataId).ToString()
            $members = @((& $InvokeGet "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $SolutionId and objectid eq $tableId and componenttype eq 1 and rootcomponentbehavior eq 0").value)
        }
        if ($members.Count -ne 1) { throw "Choice column '$name' lacks explicit or include-all table membership." }
        $inventory.Add([pscustomobject]@{
            Kind = 'column'; Category = 'columns'; Name = $name; ObjectId = $attributeId
            ComponentType = 2; SolutionComponentId = "$($members[0].solutioncomponentid)"
        })
    }
    return $inventory.ToArray()
}

function Assert-WizardChoiceMigrationPackage {
    param([object]$Payload, [object]$Membership, [string]$UnpackPath)

    $documents = @(Get-ChildItem -LiteralPath $UnpackPath -Filter '*.xml' -File -Recurse | Where-Object {
        $_.Name -eq 'Entity.xml' -or $_.Directory.Name -eq 'OptionSets'
    } | ForEach-Object {
        [xml](Get-Content -LiteralPath $_.FullName -Raw)
    })
    foreach ($choice in @($Payload.GlobalChoices)) {
        $members = @($Membership.Items | Where-Object {
            $_.Category -eq 'global-choices' -and $_.Name -ceq $choice.Name -and
            $_.ComponentType -eq 9 -and $_.State -in @('Added', 'Already in solution') -and
            -not [string]::IsNullOrWhiteSpace("$($_.ObjectId)")
        })
        if ($members.Count -ne 1) { throw "Package inspection lacks membership for global choice '$($choice.Name)'." }
        $definitions = @($documents | ForEach-Object {
            $_.SelectNodes("//optionset[@Name='$($choice.Name)'][options]")
        })
        if ($definitions.Count -ne 1 -or "$($definitions[0].IsGlobal)" -ne '1' -or
            "$($definitions[0].OptionSetType)" -ne 'picklist') {
            throw "Package is missing the unique global Picklist definition '$($choice.Name)'."
        }
        $options = @($definitions[0].SelectNodes('options/option') | ForEach-Object {
            $labels = @($_.SelectNodes("labels/label[@languagecode='1033']"))
            if ($labels.Count -ne 1) { throw "Package choice '$($choice.Name)' requires one English label per option." }
            [pscustomobject]@{ Value = [int]$_.GetAttribute('value'); Label = $labels[0].GetAttribute('description'); Color = $_.GetAttribute('Color') }
        })
        Assert-WizardChoiceOptions -Choice $choice -Options $options
    }
    foreach ($binding in @($Payload.Bindings)) {
        $name = "$($binding.TableLogicalName).$($binding.ColumnLogicalName)"
        $members = @($Membership.Items | Where-Object {
            $_.Category -eq 'columns' -and $_.Name -ceq $name -and $_.ComponentType -eq 2 -and
            $_.State -in @('Added', 'Already in solution') -and -not [string]::IsNullOrWhiteSpace("$($_.ObjectId)")
        })
        if ($members.Count -ne 1) { throw "Package inspection lacks verified column membership for '$name'." }
        $attributes = @($documents | ForEach-Object {
            $_.SelectNodes("//entity[translate(@Name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')='$($binding.TableLogicalName)']/attributes/attribute[LogicalName='$($binding.ColumnLogicalName)']")
        })
        if ($attributes.Count -ne 1 -or "$($attributes[0].Type)" -ne 'picklist' -or
            $attributes[0].SelectNodes("OptionSetName[text()='$($binding.GlobalChoiceName)'] | optionset[@Name='$($binding.GlobalChoiceName)']").Count -ne 1) {
            throw "Package column '$name' is not bound to the approved global Picklist."
        }
    }
    return [pscustomobject]@{
        migrationId = $Payload.MigrationId
        globalChoiceCount = @($Payload.GlobalChoices).Count
        picklistColumnCount = @($Payload.Bindings).Count
    }
}
