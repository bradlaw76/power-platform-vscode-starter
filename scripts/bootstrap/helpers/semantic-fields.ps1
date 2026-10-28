<#
=============================================================================
COMPONENT:    Semantic Field Contract
FILE:         scripts/bootstrap/helpers/semantic-fields.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API
OVERVIEW:     Validates approved semantic decisions, payloads and live metadata.
ARCHITECTURE: Shared fail-closed helper; no writes, approvals or migrations.
TEST CASES:   Missing design, wrong types, duplicate options and drift must fail.
NON-NEGOTIABLES: Business meaning precedes metadata; never infer approval.
=============================================================================
#>

Set-StrictMode -Version Latest

function Assert-SemanticValue {
    param($Expected, $Actual, [string]$Context)

    if ($Expected -is [System.Collections.IDictionary]) {
        if ($Actual -isnot [System.Collections.IDictionary]) { throw "Semantic mismatch at ${Context}: expected an object." }
        foreach ($key in $Expected.Keys) {
            if (-not $Actual.Contains($key)) { throw "Semantic mismatch at ${Context}.${key}: missing approved property." }
            Assert-SemanticValue $Expected[$key] $Actual[$key] "$Context.$key"
        }
    } elseif ($Expected -is [array]) {
        if ($Actual -isnot [array] -or $Expected.Count -ne $Actual.Count) { throw "Semantic mismatch at ${Context}: array cardinality differs." }
        $identity = if ($Context.EndsWith('.LocalizedLabels')) { 'LanguageCode' } elseif ($Context.EndsWith('.Options')) { 'Value' } else { '' }
        for ($i = 0; $i -lt $Expected.Count; $i++) {
            $actualItem = $Actual[$i]
            if ($identity) {
                $matches = @($Actual | Where-Object { $_[$identity] -ceq $Expected[$i][$identity] })
                if ($matches.Count -ne 1) { throw "Semantic mismatch at ${Context}: missing/duplicate $identity." }
                $actualItem = $matches[0]
            }
            Assert-SemanticValue $Expected[$i] $actualItem "$Context[$i]"
        }
    } elseif ($Expected -is [string]) {
        if ($Actual -isnot [string] -or $Expected -cne $Actual) { throw "Semantic mismatch at ${Context}: expected '$Expected', actual '$Actual'." }
    } elseif ($null -eq $Expected) {
        if ($null -ne $Actual) { throw "Semantic mismatch at ${Context}: expected no value, actual '$Actual'." }
    } elseif ($Expected -is [bool]) {
        if ($Actual -isnot [bool] -or $Expected -ne $Actual) { throw "Semantic mismatch at ${Context}: expected Boolean '$Expected', actual '$Actual'." }
    } elseif ($Actual -isnot [ValueType] -or $Actual -is [bool]) {
        throw "Semantic mismatch at ${Context}: expected numeric '$Expected', actual '$Actual'."
    } elseif ($Expected -ne $Actual -or $null -eq $Actual) {
        throw "Semantic mismatch at ${Context}: expected '$Expected', actual '$Actual'."
    }
}

function Get-SemanticMetadataClass {
    param([string]$Category, [System.Collections.IDictionary]$Metadata)
    $types = @{
        'identifier' = 'String'; 'whole-number' = 'Integer'; 'decimal' = 'Decimal'
        'floating-point' = 'Double'; 'currency' = 'Money'; 'date-time' = 'DateTime'
        'yes-no' = 'Boolean'; 'choice' = 'Picklist'; 'multi-select-choice' = 'MultiSelectPicklist'
        'lookup' = 'Lookup'; 'file' = 'File'; 'image' = 'Image'
    }
    if ($Category -in @('free-text', 'identifier') -or
        ($Category -eq 'date-time' -and $Metadata['@odata.type'] -in @('Microsoft.Dynamics.CRM.StringAttributeMetadata', 'Microsoft.Dynamics.CRM.MemoAttributeMetadata'))) {
        if ($Metadata['@odata.type'] -ceq 'Microsoft.Dynamics.CRM.MemoAttributeMetadata') { return 'Memo' }
        return 'String'
    }
    if ($Category -eq 'choice' -and $Metadata['@odata.type'] -in @('Microsoft.Dynamics.CRM.StatusAttributeMetadata', 'Microsoft.Dynamics.CRM.StateAttributeMetadata')) {
        return $Metadata['@odata.type'].Split('.')[-1].Replace('AttributeMetadata', '')
    }
    return $types[$Category]
}

function Assert-SemanticFieldDesign {
    param([System.Collections.IDictionary]$Field)
    $name = "$($Field.table).$($Field.field)"
    $metadata = $Field.expectedMetadata
    $category = $Field.semanticCategory
    $class = Get-SemanticMetadataClass $category $metadata
    if ($category -eq 'date-time' -and $class -in @('String', 'Memo') -and -not $Field.Contains('textException')) {
        throw "Date/time text interoperability for $name needs an explicitly approved textException."
    }
    if ($class -in @('State', 'Status') -and $Field.disposition -ne 'reuse') { throw "System State/Status fields must be reused, not created: $name." }
    if ($metadata['@odata.type'] -cne "Microsoft.Dynamics.CRM.${class}AttributeMetadata") {
        throw "Semantic type mismatch for ${name}: $category requires ${class}AttributeMetadata."
    }
    if ($metadata.SchemaName.ToLowerInvariant() -cne $Field.field) { throw "Schema name differs from field decision: $name." }
    if ($metadata.Contains('LogicalName') -and $metadata.LogicalName -cne $Field.field) { throw "Logical name differs from field decision: $name." }
    if ($Field.disposition -eq 'create-column' -and $category -eq 'lookup') {
        throw "Lookup $name must be created through an approved relationship, not a column POST."
    }
    if ($Field.disposition -eq 'create-relationship' -and $category -ne 'lookup') { throw "Only Lookups use create-relationship: $name." }
    $signals = '(?i)(?:^|[_\s])(?:status|state|stage|phase|lifecycle|type|kind|category|class|classification|disposition|outcome|result|decision|resolution|channel|method|mode|source|destination|repository|reason|priority|severity|risk|tier|level|access|approval|review|validation|verification|eligibility|frequency|cadence|format|region|segment)(?:$|[_\s])'
    $candidate = $Field.categoricalCandidate -or $Field.boundedValues -or
        ($category -ne 'identifier' -and "$($Field.field) $($Field.businessMeaning)" -match $signals)
    if (($Field.categoricalCandidate -or $Field.boundedValues) -and $category -notin @('yes-no', 'choice', 'multi-select-choice', 'lookup', 'free-text', 'identifier')) {
        throw "Categorical candidate $name needs a resolved Yes/No, Choice, multi-select Choice, Lookup or approved text exception."
    }
    if ($candidate -and $category -in @('free-text', 'identifier') -and -not $Field.Contains('textException')) {
        throw "Categorical text candidate $name needs an explicitly approved textException."
    }
    $requiredConfig = switch ($category) {
        'identifier' { @('uniqueness', 'alternateKey', 'caseSensitivity', 'formatting', 'leadingZeros', 'sourceOwnership') }
        { $_ -in @('whole-number', 'decimal', 'floating-point', 'currency') } { @('rounding', 'unitOfMeasure') }
        'date-time' { @('precision', 'integrationTimezone') }
        'yes-no' { @('logicalStates') }
        'multi-select-choice' { @('relatedRecordsAlternative', 'filteringAutomationIntegrationReporting') }
        'lookup' { @('cardinality', 'requiredness', 'existingOrNew', 'supportingTask') }
        { $_ -in @('file', 'image') } { @('integration', 'storage') }
        default { @() }
    }
    if ($category -eq 'currency') { $requiredConfig += @('currencyBehavior', 'baseCurrencyBehavior') }
    if ($category -eq 'image') { $requiredConfig += @('primaryImage', 'imageBehavior') }
    foreach ($key in $requiredConfig) {
        if (-not $Field.typeConfig.Contains($key) -or $null -eq $Field.typeConfig[$key] -or
            ($Field.typeConfig[$key] -is [string] -and [string]::IsNullOrWhiteSpace($Field.typeConfig[$key]))) {
            throw "Unresolved typeConfig.$key for $name."
        }
    }
    $requiredMetadata = switch ($class) {
        { $_ -in @('String', 'Memo') } { @('MaxLength') }
        'Integer' { @('MinValue', 'MaxValue') }
        { $_ -in @('Decimal', 'Double') } { @('Precision', 'MinValue', 'MaxValue') }
        'Money' { @('Precision', 'PrecisionSource', 'MinValue', 'MaxValue') }
        'DateTime' { @('Format', 'DateTimeBehavior') }
        'Boolean' { @('DefaultValue', 'OptionSet') }
        { $_ -in @('File', 'Image') } { @('MaxSizeInKB') }
        default { @() }
    }
    foreach ($key in $requiredMetadata) {
        if (-not $metadata.Contains($key) -or $null -eq $metadata[$key]) { throw "Unresolved expectedMetadata.$key for $name." }
    }
    foreach ($key in @('MaxLength', 'Precision', 'PrecisionSource', 'MinValue', 'MaxValue', 'MaxSizeInKB')) {
        if ($metadata.Contains($key) -and ($metadata[$key] -is [string] -or $metadata[$key] -is [bool] -or $metadata[$key] -isnot [ValueType])) {
            throw "Numeric metadata $key must be a number for $name."
        }
    }
    if ($metadata.Contains('MinValue') -and $metadata.MinValue -gt $metadata.MaxValue) { throw "Numeric range is reversed for $name." }
    if ($metadata.Contains('MaxLength') -and $metadata.MaxLength -le 0) { throw "Maximum length must be positive for $name." }
    if ($metadata.Contains('MaxSizeInKB') -and $metadata.MaxSizeInKB -le 0) { throw "Maximum binary size must be positive for $name." }
    if ($category -eq 'yes-no') {
        if ($Field.typeConfig.logicalStates -isnot [array] -or $Field.typeConfig.logicalStates.Count -ne 2 -or
            @($Field.typeConfig.logicalStates | Sort-Object -Unique).Count -ne 2) { throw "Yes/No $name requires exactly two distinct logical states." }
        if ($metadata.DefaultValue -isnot [bool] -or -not $metadata.OptionSet.Contains('TrueOption') -or -not $metadata.OptionSet.Contains('FalseOption')) {
            throw "Yes/No $name needs Boolean default and both labelled options."
        }
    }
    if ($category -eq 'date-time' -and $class -eq 'DateTime') {
        if ($metadata.Format -notin @('DateOnly', 'DateAndTime') -or
            $metadata.DateTimeBehavior.Value -notin @('DateOnly', 'UserLocal', 'TimeZoneIndependent') -or
            ($metadata.DateTimeBehavior.Value -eq 'DateOnly' -and $metadata.Format -ne 'DateOnly')) {
            throw "Invalid date/time format or behavior for $name."
        }
    }
    if ($category -eq 'lookup') {
        if (-not $Field.Contains('relationship') -or $Field.relationship.ReferencingEntity -cne $Field.table -or
            $Field.relationship.ReferencingAttribute -cne $Field.field) { throw "Lookup target/relationship is unresolved for $name." }
    }
    if ($metadata.Contains('AttributeTypeName')) {
        $allowedTypeNames = if ($category -eq 'lookup' -and $Field.disposition -eq 'reuse') { @('LookupType', 'CustomerType', 'OwnerType') } else { @("${class}Type") }
        if ($metadata.AttributeTypeName.Value -notin $allowedTypeNames) { throw "Contradictory AttributeTypeName for $name." }
    }
    if ($category -notin @('choice', 'multi-select-choice')) { return }
    if (-not $Field.Contains('choice')) { throw "Missing approved Choice inventory for $name." }
    $choice = $Field.choice
    $values = [Collections.Generic.HashSet[int]]::new()
    foreach ($option in $choice.options) {
        if (-not $values.Add($option.value)) { throw "Duplicate stable Choice option value for $name." }
        $languages = @($option.labels.LocalizedLabels.LanguageCode)
        if (@($languages | Sort-Object -Unique).Count -ne $languages.Count) { throw "Duplicate Choice label language for $name." }
    }
    if ($null -ne $choice.default -and -not $values.Contains($choice.default)) { throw "Unknown Choice default for $name." }
    if ($category -eq 'multi-select-choice' -and $null -ne $choice.default) { throw "Dataverse multi-select Choice does not support a default: $name." }
    if ($category -eq 'multi-select-choice' -and $metadata.Contains('DefaultFormValue')) { throw "Multi-select Choice $name must not emit DefaultFormValue." }
    foreach ($mapping in $choice.mappings.Values) {
        if (($mapping.applicable -and $mapping.entries.Count -eq 0) -or (-not $mapping.applicable -and $mapping.entries.Count -gt 0)) {
            throw "Unresolved mapping applicability for $name."
        }
        $sources = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($entry in $mapping.entries) {
            if (-not $sources.Add($entry.source) -or -not $values.Contains($entry.value)) { throw "Unknown, duplicate or ambiguous Choice mapping for $name." }
        }
    }
    if ($choice.scope -eq 'global') {
        $binding = "/GlobalOptionSetDefinitions(Name='$($choice.name)')"
        if ($metadata['GlobalOptionSet@odata.bind'] -cne $binding -or $metadata.Contains('OptionSet')) {
            throw "Global Choice binding differs from approved vocabulary for $name."
        }
    } else {
        $expectedOptions = @($choice.options | ForEach-Object { @{ Value = $_.value; Label = $_.labels } })
        Assert-SemanticValue @{ IsGlobal = $false; Options = $expectedOptions } $metadata['OptionSet'] "$name.OptionSet"
    }
    if ($category -eq 'choice') {
        $validDefault = if ($null -eq $choice.default) { $metadata['DefaultFormValue'] -in @($null, -1) } else { $metadata['DefaultFormValue'] -eq $choice.default }
        if (-not $metadata.Contains('DefaultFormValue') -or -not $validDefault) { throw "Choice default differs from approved inventory for $name." }
    }
}

function Read-WizardSemanticPlan {
    param([string]$RepoRoot, [string]$ScenarioSlug)
    $folder = Join-Path $RepoRoot "specs\$ScenarioSlug"
    $path = Join-Path $folder 'field-type-decisions.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Semantic planning gate: missing $path. Upgrade planning explicitly; no legacy bypass or inferred text types."
    }
    $json = Get-Content -LiteralPath $path -Raw
    if (-not (Test-Json -Json $json -SchemaFile (Join-Path $RepoRoot 'schemas\payloads\field-type-decisions.schema.json') -ErrorAction Stop)) {
        throw "Semantic planning gate: invalid or unapproved inventory $path."
    }
    $plan = ConvertFrom-Json -InputObject $json -AsHashtable
    if ($plan.scenarioSlug -cne $ScenarioSlug) { throw 'Semantic inventory scenario identity mismatch.' }
    $planning = @{}
    $decisionRows = @{}
    foreach ($file in @('spec.md', 'plan.md', 'tasks.md')) {
        $planning[$file] = Get-Content -LiteralPath (Join-Path $folder $file) -Raw
        if (-not $planning[$file].Contains('field-type-decisions.json')) { throw "$file must reference field-type-decisions.json." }
        if ($file -ne 'tasks.md') {
            $rows = @{}
            foreach ($line in ($planning[$file] -split '\r?\n')) {
                if ($line -notmatch '^\s*\|\s*`?FIELD-') { continue }
                $cells = @([regex]::Split($line.Trim().Trim('|'), '(?<!\\)\|') | ForEach-Object { $_.Trim().Replace('\|', '|').Replace('`', '') })
                if ($cells.Count -lt 9 -or $rows.Contains($cells[0])) { throw "Malformed or duplicate semantic decision table row in $file." }
                $rows[$cells[0]] = $cells
            }
            $decisionRows[$file] = $rows
        }
    }
    $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $globals = @{}
    foreach ($field in $plan.fields) {
        $key = "$($field.table).$($field.field)"
        if (-not $keys.Add($key) -or -not $ids.Add($field.decisionId)) { throw "Duplicate semantic decision: $key." }
        foreach ($file in @('spec.md', 'plan.md')) {
            if (-not $decisionRows[$file].Contains($field.decisionId)) {
                throw "$file is missing semantic decision $($field.decisionId) for $key."
            }
            $scope = if ($field.Contains('choice')) { "$($field.choice.scope):$($field.choice.name)" } elseif ($field.Contains('relationship')) { $field.relationship.ReferencedEntity } else { '-' }
            $expectedRow = @($field.decisionId, $field.table, $field.field, $field.businessMeaning, $field.semanticCategory, $field.boundedValues.ToString().ToLowerInvariant(), (Get-SemanticMetadataClass $field.semanticCategory $field.expectedMetadata), $scope, $field.rationale)
            $actualRow = $decisionRows[$file][$field.decisionId]
            for ($i = 0; $i -lt $expectedRow.Count; $i++) {
                if ([regex]::Replace($actualRow[$i], '\s+', ' ') -cne [regex]::Replace($expectedRow[$i], '\s+', ' ')) {
                    throw "$file semantic decision row differs from inventory: $($field.decisionId), column $($i + 1)."
                }
            }
            if ($field.Contains('textException')) {
                foreach ($text in @($field.textException.reason, $field.textException.alternativeConsidered) + @($field.textException.consequences.Values)) {
                    if (-not $planning[$file].Contains($text)) { throw "$file must document the approved text exception and consequences for $key." }
                }
            }
        }
        Assert-SemanticFieldDesign $field
        if ($field.Contains('choice') -and $field.choice.scope -eq 'global') {
            $name = $field.choice.name
            if ($globals.Contains($name)) {
                Assert-SemanticValue $globals[$name] $field.choice.options "Shared vocabulary $name"
            } else { $globals[$name] = $field.choice.options }
        }
    }
    foreach ($file in @('spec.md', 'plan.md')) {
        if ($decisionRows[$file].Count -ne $plan.fields.Count) { throw "$file contains unplanned semantic decision rows." }
    }
    return $plan
}

function Assert-WizardSemanticPayloads {
    param([System.Collections.IDictionary]$Plan, [string]$PayloadsFolder, [switch]$PassThru)
    $seen = @{}
    $columns = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'table-*.json' -File)) {
        $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        $table = $doc.EntityDefinition.SchemaName.ToLowerInvariant()
        $primary = "$($table.Split('_', 2)[0])_name"
        $key = "$table.$primary"
        if ($seen.Contains($key)) { throw "Duplicate table primary field payload: $key." }
        $seen[$key] = @{ disposition = 'table-primary' }
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'columns-*.json' -File)) {
        $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        foreach ($column in $doc.Columns) {
            $logical = if ($column.Contains('LogicalName')) { $column.LogicalName } else { $column.SchemaName.ToLowerInvariant() }
            $key = "$($doc.TableLogicalName).$logical"
            if ($seen.Contains($key)) { throw "Duplicate column payload: $key." }
            $seen[$key] = @{ metadata = $column; disposition = 'create-column' }
            $columns[$key] = $column
        }
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'relationships-*.json' -File)) {
        $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        $relationships = if ($doc.Contains('Relationships')) { $doc.Relationships } else { @($doc) }
        foreach ($item in $relationships) {
            $relationship = if ($item.Contains('RelationshipDefinition')) { $item.RelationshipDefinition } else { $item }
            if (-not $relationship.Contains('ReferencedEntity')) { continue }
            if (-not $relationship.Contains('Lookup')) { throw "Relationship $($relationship.SchemaName) needs explicit Lookup metadata; semantic generation cannot infer labels/types." }
            $lookup = $relationship.Lookup
            $key = "$($relationship.ReferencingEntity).$($lookup.SchemaName.ToLowerInvariant())"
            if ($seen.Contains($key)) { throw "Duplicate relationship/column payload: $key." }
            $seen[$key] = @{ metadata = $lookup; relationship = $relationship; disposition = 'create-relationship' }
        }
    }
    foreach ($field in $Plan.fields) {
        $key = "$($field.table).$($field.field)"
        if ($field.disposition -eq 'reuse') {
            if ($seen.Contains($key)) { throw "Reused/primary field $key must not also be created as a column/relationship." }
            continue
        }
        if (-not $seen.Contains($key) -or $seen[$key].disposition -cne $field.disposition) { throw "Missing approved payload for $key." }
        if ($field.disposition -eq 'table-primary') {
            Assert-SemanticValue @{
                '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
                MaxLength = 100
                RequiredLevel = @{ Value = 'ApplicationRequired' }
                DisplayName = @{ LocalizedLabels = @(@{ Label = 'Name'; LanguageCode = 1033 }) }
            } $field.expectedMetadata $key
            $seen.Remove($key)
            continue
        }
        Assert-SemanticValue $field.expectedMetadata $seen[$key].metadata $key
        Assert-SemanticValue $seen[$key].metadata $field.expectedMetadata "$key.unapprovedMetadata"
        if ($field.disposition -eq 'create-relationship') {
            $expected = @{}
            foreach ($property in $field.relationship.Keys) {
                if ($property -ne 'ReferencingAttribute') { $expected[$property] = $field.relationship[$property] }
            }
            Assert-SemanticValue $expected $seen[$key].relationship "$key.relationship"
        }
        $seen.Remove($key)
    }
    if ($seen.Count -gt 0) { throw "Payload fields missing from semantic decision inventory: $($seen.Keys -join ', ')." }
    foreach ($field in $Plan.fields) {
        if ($field.Contains('choice')) {
            $null = Get-SemanticPresentationOptions -Field $field -PayloadsFolder $PayloadsFolder
        }
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'choice-presentations-*.json' -File)) {
        $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        $fields = @($Plan.fields | Where-Object { $_.table -ceq $doc.TableLogicalName -and $_.field -ceq $doc.ColumnLogicalName })
        if ($fields.Count -ne 1 -or $fields[0].semanticCategory -ne 'choice' -or $fields[0].choice.scope -ne 'local') {
            throw 'Choice presentation requires a planned local Choice, never text or an unplanned field.'
        }
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'data-*.json' -File)) {
        $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        if (-not $doc.Enabled) { continue }
        foreach ($table in $doc.Tables) {
            foreach ($field in @($Plan.fields | Where-Object { $_.table -ceq $table.TableLogicalName -and $_.Contains('choice') })) {
                foreach ($record in $table.Records) {
                    if (-not $record.Values.Contains($field.field) -or $null -eq $record.Values[$field.field]) { continue }
                    $value = $record.Values[$field.field]
                    $values = if ($field.semanticCategory -eq 'multi-select-choice') { "$value".Split(',') } else { @($value) }
                    foreach ($item in $values) {
                        $number = 0
                        if (($field.semanticCategory -eq 'choice' -and $item -is [string]) -or
                            -not [int]::TryParse("$item", [ref]$number) -or $number -notin @($field.choice.options.value)) {
                            throw "Unknown or nonnumeric seed Choice value for $($field.table).$($field.field); apply approved mappings before generation."
                        }
                    }
                }
            }
        }
    }
    if ($PassThru) { return $columns }
}

function Get-SemanticPresentationOptions {
    param([System.Collections.IDictionary]$Field, [string]$PayloadsFolder)
    $options = @($Field.choice.options | ForEach-Object { @{ Value = $_.value; Label = ($_.labels | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable) } })
    . (Join-Path $PSScriptRoot 'choice-presentation-tokens.ps1')
    $seen = [Collections.Generic.HashSet[string]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'choice-presentations-*.json' -File)) {
        $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
        if ($doc.TableLogicalName -cne $Field.table -or $doc.ColumnLogicalName -cne $Field.field) { continue }
        if ($Field.choice.scope -ne 'local') { throw 'Choice presentation is supported only for local Choices.' }
        $language = if ($doc.Contains('LanguageCode')) { $doc.LanguageCode } else { 1033 }
        foreach ($option in $doc.Options) {
            if (-not $seen.Add("$language|$($option.Value)")) { throw 'Duplicate Choice presentation target.' }
            $match = @($options | Where-Object { $_.Value -eq $option.Value })
            if ($match.Count -ne 1) { throw 'Choice presentation references an unapproved option.' }
            $label = @($match[0].Label.LocalizedLabels | Where-Object { $_.LanguageCode -eq $language })
            if ($label.Count -ne 1 -or $label[0].Label -cne $option.Label.Trim()) { throw 'Choice presentation changes the approved semantic vocabulary.' }
            $icon = if ($option.Contains('Icon')) { $option.Icon } else { 'none' }
            if (-not $script:ChoiceIcons.Contains($icon)) { throw 'Unknown Choice presentation icon.' }
            if ($icon -ne 'none') { $label[0].Label = "$($script:ChoiceIcons[$icon]) $($label[0].Label)" }
        }
    }
    return ,$options
}

function Get-WizardSemanticLiveAttribute {
    param([System.Collections.IDictionary]$Field, [scriptblock]$ReadMetadata, [switch]$AllowMissing)
    $path = "EntityDefinitions(LogicalName='$($Field.table)')/Attributes(LogicalName='$($Field.field)')"
    try { $base = & $ReadMetadata "$path`?`$select=LogicalName,SchemaName,AttributeType,AttributeTypeName" }
    catch {
        if ($AllowMissing -and (Get-WizardHttpStatusCode $_) -eq 404) { return $null }
        throw
    }
    $base = $base | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable
    $class = Get-SemanticMetadataClass $Field.semanticCategory $Field.expectedMetadata
    $expectedType = if ($Field.expectedMetadata.Contains('AttributeTypeName')) { $Field.expectedMetadata.AttributeTypeName.Value } else { "${class}Type" }
    $actualType = if ($base.Contains('AttributeTypeName')) { $base.AttributeTypeName.Value } else { $base['AttributeType'] }
    if ($actualType -cne $expectedType) {
        $errorMessage = "Configuration drift: $($Field.table).$($Field.field); expected $expectedType; actual $actualType; affected dependencies: $($Field.dependencies -join ', '). Remediation planning required; no in-place type conversion."
        $exception = [InvalidOperationException]::new($errorMessage)
        $exception.Data['ActualType'] = $actualType
        throw $exception
    }
    $expand = if ($class -in @('Picklist', 'MultiSelectPicklist')) { '?$expand=OptionSet,GlobalOptionSet' } elseif ($class -in @('Boolean', 'State', 'Status')) { '?$expand=OptionSet' } else { '' }
    $live = & $ReadMetadata "$path/Microsoft.Dynamics.CRM.${class}AttributeMetadata$expand"
    return ($live | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable)
}

function Assert-WizardSemanticLiveField {
    param([System.Collections.IDictionary]$Field, [System.Collections.IDictionary]$Live, [scriptblock]$ReadMetadata, [string]$PayloadsFolder = '', [switch]$AllowBasePresentation)
    $name = "$($Field.table).$($Field.field)"
    $expected = @{}
    foreach ($key in $Field.expectedMetadata.Keys) {
        if ($key -notin @('@odata.type', 'GlobalOptionSet@odata.bind', 'OptionSet')) { $expected[$key] = $Field.expectedMetadata[$key] }
    }
    if ($Field.Contains('choice') -and $Field.semanticCategory -eq 'choice' -and $null -eq $Field.choice.default) {
        $expected.Remove('DefaultFormValue')
        if (-not $Live.Contains('DefaultFormValue') -or $Live.DefaultFormValue -notin @($null, -1)) {
            throw "Configuration drift: $name expected no default; actual '$($Live['DefaultFormValue'])'. Affected dependencies: $($Field.dependencies -join ', ')."
        }
    }
    try {
        Assert-SemanticValue $expected $Live $name
        if ($Field.semanticCategory -in @('choice', 'multi-select-choice')) {
            $choice = $Field.choice
            $set = if ($choice.scope -eq 'global') { $Live['GlobalOptionSet'] } else { $Live['OptionSet'] }
            $approvedSet = @{
                IsGlobal = ($choice.scope -eq 'global')
                Options = @($choice.options | ForEach-Object { @{ Value = $_.value; Label = $_.labels } })
            }
            if ($PayloadsFolder) { $approvedSet.Options = Get-SemanticPresentationOptions -Field $Field -PayloadsFolder $PayloadsFolder }
            if ($AllowBasePresentation) {
                foreach ($option in $approvedSet.Options) {
                    $baseOption = @($choice.options | Where-Object { $_.value -eq $option.Value })[0]
                    $liveOption = @($set.Options | Where-Object { $_.Value -eq $option.Value })
                    if ($liveOption.Count -ne 1) { continue }
                    foreach ($label in $option.Label.LocalizedLabels) {
                        $baseLabel = @($baseOption.labels.LocalizedLabels | Where-Object { $_.LanguageCode -eq $label.LanguageCode })[0]
                        $liveLabel = @($liveOption[0].Label.LocalizedLabels | Where-Object { $_.LanguageCode -eq $label.LanguageCode })
                        if ($liveLabel.Count -eq 1 -and $liveLabel[0].Label -ceq $baseLabel.Label) { $label.Label = $baseLabel.Label }
                    }
                }
            }
            if ($choice.scope -eq 'global') { $approvedSet.Name = $choice.name }
            Assert-SemanticValue $approvedSet $set "$name.OptionSet"
        } elseif ($Field.semanticCategory -eq 'yes-no') {
            Assert-SemanticValue $Field.expectedMetadata.OptionSet $Live['OptionSet'] "$name.OptionSet"
        }
        if ($Field.semanticCategory -eq 'lookup') {
            $targets = @(if ($Field.expectedMetadata.Contains('Targets')) { $Field.expectedMetadata.Targets } else { $Field.relationship.ReferencedEntity })
            Assert-SemanticValue $targets $Live['Targets'] "$name.Targets"
            $response = & $ReadMetadata "EntityDefinitions(LogicalName='$($Field.table)')/ManyToOneRelationships?`$filter=SchemaName eq '$($Field.relationship.SchemaName)'"
            $relationships = @($response.value)
            if ($relationships.Count -ne 1) { throw "Expected exactly one relationship for $name." }
            $relationship = $relationships[0] | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable
            Assert-SemanticValue $Field.relationship $relationship "$name.relationship"
        }
    } catch {
        throw "Configuration drift: $name; $($_.Exception.Message) Affected dependencies: $($Field.dependencies -join ', '). Stop and plan remediation; do not rewrite approved planning."
    }
}
