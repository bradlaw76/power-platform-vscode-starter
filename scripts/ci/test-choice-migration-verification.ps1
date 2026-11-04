<#
=============================================================================
COMPONENT:    Choice Migration Verification Tests
FILE:         scripts/ci/test-choice-migration-verification.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-21
ENVIRONMENT:  PowerShell 7 | Credential-free metadata and export fixtures
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts/bootstrap/helpers/choice-migration-verification.ps1')
. (Join-Path $repoRoot 'scripts/bootstrap/helpers/solution-isolation.ps1')
$payloadPath = Join-Path $repoRoot 'payloads/scenarios/federal-foia-management/choice-migration-federal-foia-management.json'
$payload = Get-Content -LiteralPath $payloadPath -Raw | ConvertFrom-Json -Depth 40
$dataPayload = Get-Content -LiteralPath (Join-Path $repoRoot 'payloads/scenarios/federal-foia-management/data-federal-foia-management.json') -Raw | ConvertFrom-Json -Depth 40
$convertedColumns = 0
$convertedValues = 0
foreach ($binding in $payload.Bindings) {
    $documents = @(Get-ChildItem -LiteralPath (Split-Path $payloadPath -Parent) -Filter 'columns-*.json' | ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json -Depth 40
    } | Where-Object TableLogicalName -eq $binding.TableLogicalName)
    $column = @($documents[0].Columns | Where-Object LogicalName -eq $binding.ColumnLogicalName)[0]
    $effective = ConvertTo-WizardMigratedColumn -Payload $payload -TableLogicalName $binding.TableLogicalName -Column $column
    if ($effective.'@odata.type' -ne 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata' -or
        $effective.'GlobalOptionSet@odata.bind' -cne "/GlobalOptionSetDefinitions(Name='$($binding.GlobalChoiceName)')" -or
        $effective.PSObject.Properties.Name -contains 'MaxLength' -or
        $column.'@odata.type' -ne 'Microsoft.Dynamics.CRM.StringAttributeMetadata') { throw 'Effective migrated column metadata is incorrect or mutated the rollback source.' }
    $convertedColumns++
}
foreach ($table in $dataPayload.Tables) {
    foreach ($record in $table.Records) {
        $values = [ordered]@{}
        foreach ($property in $record.Values.PSObject.Properties) { $values[$property.Name] = $property.Value }
        ConvertTo-WizardMigratedValues -Payload $payload -TableLogicalName $table.TableLogicalName -Values $values
        foreach ($binding in @($payload.Bindings | Where-Object TableLogicalName -eq $table.TableLogicalName)) {
            if ($values.Contains($binding.ColumnLogicalName) -and $null -ne $values[$binding.ColumnLogicalName]) {
                if ($values[$binding.ColumnLogicalName] -isnot [int]) { throw 'Migrated synthetic value is not numeric.' }
                $convertedValues++
            }
        }
    }
}
if ($convertedColumns -ne 29 -or $convertedValues -ne 97) { throw 'Incorrect effective payload conversion counts.' }
$solutionId = [guid]::NewGuid().ToString()
$choices = @{}
$attributes = @{}
foreach ($choice in $payload.GlobalChoices) {
    $choices[$choice.Name] = [pscustomobject]@{
        Name = $choice.Name; MetadataId = [guid]::NewGuid().ToString()
        IsGlobal = $true; OptionSetType = 'Picklist'
        Options = @($choice.Options | ForEach-Object {
            [pscustomobject]@{
                Value = $_.Value
                Label = [pscustomobject]@{ LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = Get-WizardChoiceDisplayLabel $_ }) }
                Color = Get-WizardChoiceColor $_
            }
        })
    }
}
foreach ($binding in $payload.Bindings) {
    $attributes["$($binding.TableLogicalName).$($binding.ColumnLogicalName)"] = [pscustomobject]@{
        LogicalName = $binding.ColumnLogicalName; AttributeType = 'Picklist'
        MetadataId = [guid]::NewGuid().ToString()
        GlobalOptionSet = $choices[$binding.GlobalChoiceName]
    }
}
$state = @{ MissingMembership = $false; MissingColumnMembership = $false; IncludeAll = $false }
$invokeGet = {
    param($Path)
    if ($Path -match "^GlobalOptionSetDefinitions\(Name='([^']+)'\)") { return $choices[$Matches[1]] }
    if ($Path -match "^EntityDefinitions\(LogicalName='([^']+)'\)/Attributes\(LogicalName='([^']+)'\)") {
        return $attributes["$($Matches[1]).$($Matches[2])"]
    }
    if ($Path -match "^EntityDefinitions\(LogicalName='([^']+)'\)\?") {
        return [pscustomobject]@{ MetadataId = $solutionId }
    }
    if ($Path -like 'solutioncomponents?*') {
        return [pscustomobject]@{ value = if ($state.MissingMembership -or
            ($state.MissingColumnMembership -and $Path -match 'componenttype eq (1|2)\b') -or
            ($state.IncludeAll -and $Path -match 'componenttype eq 2')) {
            @()
        } else { @([pscustomobject]@{ solutioncomponentid = [guid]::NewGuid().ToString() }) } }
    }
    throw "Unexpected GET: $Path"
}.GetNewClosure()

function Assert-Fails {
    param([scriptblock]$Action, [string]$Message)
    try { & $Action; throw 'Expected verification failure was not raised.' }
    catch { if ($_.Exception.Message -notmatch $Message) { throw } }
}

$inventory = @(Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId $solutionId -InvokeGet $invokeGet)
if (@($inventory | Where-Object ComponentType -eq 9).Count -ne 26 -or
    @($inventory | Where-Object ComponentType -eq 2).Count -ne 29) { throw 'Incorrect exact live inventory counts.' }
$state.IncludeAll = $true
$inherited = @(Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId $solutionId -InvokeGet $invokeGet)
if ($inherited.Count -ne 55) { throw 'Include-all membership lost verified column identities.' }
$state.IncludeAll = $false
$state.MissingMembership = $true
Assert-Fails { Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId $solutionId -InvokeGet $invokeGet } 'lacks unique solution membership'
$state.MissingMembership = $false
$state.MissingColumnMembership = $true
Assert-Fails { Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId $solutionId -InvokeGet $invokeGet } 'lacks explicit or include-all table membership'
$state.MissingColumnMembership = $false
$firstChoice = $choices[$payload.GlobalChoices[0].Name]
$oldLabel = $firstChoice.Options[0].Label.LocalizedLabels[0].Label
$firstChoice.Options[0].Label.LocalizedLabels[0].Label = 'Wrong label'
Assert-Fails { Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId $solutionId -InvokeGet $invokeGet } 'incorrect value or English label'
$firstChoice.Options[0].Label.LocalizedLabels[0].Label = $oldLabel
$oldColor = $firstChoice.Options[0].Color
$firstChoice.Options[0].Color = '#000000'
Assert-Fails { Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId $solutionId -InvokeGet $invokeGet } 'incorrect color'
$firstChoice.Options[0].Color = $oldColor
$oldValue = $firstChoice.Options[0].Value
$firstChoice.Options[0].Value = 999999999
Assert-Fails { Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId $solutionId -InvokeGet $invokeGet } 'incorrect value or English label'
$firstChoice.Options[0].Value = $oldValue
$firstAttribute = $attributes["$($payload.Bindings[0].TableLogicalName).$($payload.Bindings[0].ColumnLogicalName)"]
$oldSet = $firstAttribute.GlobalOptionSet
$firstAttribute.GlobalOptionSet = $choices[$payload.GlobalChoices[1].Name]
Assert-Fails { Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId $solutionId -InvokeGet $invokeGet } 'incorrect type or global choice binding'
$firstAttribute.GlobalOptionSet = $oldSet
$firstAttribute.AttributeType = 'String'
Assert-Fails { Get-WizardChoiceMigrationInventory -Payload $payload -SolutionId $solutionId -InvokeGet $invokeGet } 'incorrect type or global choice binding'
$firstAttribute.AttributeType = 'Picklist'
$expected = @{ 'global-choices' = @($payload.GlobalChoices.Name); columns = @($attributes.Keys) }
$membership = New-SolutionMembershipReport -ExpectedByCategory $expected -CurrentInventory $inventory -Strict
if (-not $membership.ExportAllowed -or $membership.Items.Count -ne 55) { throw 'Strict Choice membership did not pass.' }
$missing = New-SolutionMembershipReport -ExpectedByCategory $expected -CurrentInventory @($inventory | Select-Object -Skip 1) -Strict
if ($missing.ExportAllowed -or $missing.Counts.Missing -ne 1) { throw 'Missing global choice did not block export.' }
$foreign = [pscustomobject]@{ Category = 'global-choices'; Name = 'foreign_choice'; ObjectId = [guid]::NewGuid().ToString(); SolutionComponentId = 'foreign'; ComponentType = 9 }
$contaminated = New-SolutionMembershipReport -ExpectedByCategory $expected -CurrentInventory ($inventory + $foreign) -Strict
if ($contaminated.ExportAllowed -or $contaminated.Counts.Unauthorized -ne 1) { throw 'Foreign global choice did not block export.' }

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "foia-choice-verification-$([guid]::NewGuid().ToString('N'))"
$scenario = 'ci-choice-verification'
$outputFolder = Join-Path $fixtureRoot 'output'
try {
    foreach ($folder in @('scripts/bootstrap/helpers', 'schemas/payloads', "payloads/scenarios/$scenario", ".wizard-metrics/artifacts/contamination/$scenario")) {
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot $folder) -Force | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/bootstrap/95-export-unmanaged-solution.ps1') -Destination (Join-Path $fixtureRoot 'scripts/bootstrap')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/bootstrap/helpers/choice-migration-verification.ps1') -Destination (Join-Path $fixtureRoot 'scripts/bootstrap/helpers')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/bootstrap/helpers/choice-presentation-tokens.ps1') -Destination (Join-Path $fixtureRoot 'scripts/bootstrap/helpers')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'schemas/payloads/choice-migration.schema.json') -Destination (Join-Path $fixtureRoot 'schemas/payloads')
    Copy-Item -LiteralPath $payloadPath -Destination (Join-Path $fixtureRoot "payloads/scenarios/$scenario")
    $legacyPayload = $payload | ConvertTo-Json -Depth 40 | ConvertFrom-Json -Depth 40
    $legacyPayload.PSObject.Properties.Remove('CurrentSchema')
    $legacyPayload | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $fixtureRoot "payloads/scenarios/$scenario/$(Split-Path $payloadPath -Leaf)")
    $membershipPath = Join-Path $fixtureRoot ".wizard-metrics/artifacts/contamination/$scenario/solution-membership-report.json"
    $membership | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $membershipPath
    if ($null -ne (Get-WizardRequiredChoiceMigration -RepoRoot $fixtureRoot -ScenarioSlug $scenario -SolutionUniqueName UnitSolution)) {
        throw 'Pre-migration backup unexpectedly requires Picklist metadata.'
    }
    $required = Get-WizardRequiredChoiceMigration -RepoRoot $fixtureRoot -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -Required
    if (@($required.Bindings).Count -ne 29) { throw 'Explicit migration gate did not load the full contract.' }
    $state.PackageFault = ''
    $pacCalls = [Collections.Generic.List[string]]::new()
    $pacInvoker = {
        param([string[]]$Arguments)
        $pacCalls.Add($Arguments -join ' ')
        if ($Arguments[1] -eq 'export') {
            Set-Content -LiteralPath $Arguments[[Array]::IndexOf($Arguments, '--path') + 1] -Value 'mock package'
            return
        }
        $unpack = $Arguments[[Array]::IndexOf($Arguments, '--folder') + 1]
        New-Item -ItemType Directory -Path (Join-Path $unpack 'OptionSets') -Force | Out-Null
        $roots = @($payload.GlobalChoices | ForEach-Object { "<RootComponent type=`"9`" schemaName=`"$($_.Name)`" />" }) -join ''
        "<ImportExportXml><SolutionManifest><UniqueName>UnitSolution</UniqueName><RootComponents>$roots</RootComponents></SolutionManifest></ImportExportXml>" |
            Set-Content -LiteralPath (Join-Path $unpack 'Solution.xml')
        foreach ($choice in $payload.GlobalChoices) {
            if ($state.PackageFault -eq 'missing-choice' -and $choice.Name -eq $payload.GlobalChoices[0].Name) { continue }
            $options = @($choice.Options | ForEach-Object {
                $label = [Security.SecurityElement]::Escape((Get-WizardChoiceDisplayLabel $_))
                if ($state.PackageFault -eq 'label' -and $choice.Name -eq $payload.GlobalChoices[0].Name) { $label = 'Wrong' }
                $color = Get-WizardChoiceColor $_
                if ($state.PackageFault -eq 'color' -and $choice.Name -eq $payload.GlobalChoices[0].Name) { $color = '#000000' }
                "<option value=`"$($_.Value)`" Color=`"$color`"><labels><label description=`"$label`" languagecode=`"1033`" /></labels></option>"
            }) -join ''
            "<optionset Name=`"$($choice.Name)`"><IsGlobal>1</IsGlobal><OptionSetType>picklist</OptionSetType><options>$options</options></optionset>" |
                Set-Content -LiteralPath (Join-Path $unpack "OptionSets/$($choice.Name).xml")
        }
        foreach ($group in @($payload.Bindings | Group-Object TableLogicalName)) {
            $folder = Join-Path $unpack "Entities/$($group.Name)"
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            $fields = @($group.Group | ForEach-Object {
                if ($state.PackageFault -eq 'missing-column' -and $_.ColumnLogicalName -eq $payload.Bindings[0].ColumnLogicalName -and
                    $_.TableLogicalName -eq $payload.Bindings[0].TableLogicalName) { return }
                $type = if ($state.PackageFault -eq 'type') { 'nvarchar' } else { 'picklist' }
                $choiceName = if ($state.PackageFault -eq 'binding') { 'wrong_choice' } else { $_.GlobalChoiceName }
                "<attribute><LogicalName>$($_.ColumnLogicalName)</LogicalName><Type>$type</Type><OptionSetName>$choiceName</OptionSetName></attribute>"
            }) -join ''
            "<Entity><EntityInfo><entity Name=`"$($group.Name.ToUpperInvariant())`"><attributes>$fields</attributes></entity></EntityInfo></Entity>" |
                Set-Content -LiteralPath (Join-Path $folder 'Entity.xml')
        }
    }.GetNewClosure()
    $exportStage = Join-Path $fixtureRoot 'scripts/bootstrap/95-export-unmanaged-solution.ps1'
    & $exportStage -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker
    $result = Get-Content -LiteralPath (Join-Path $fixtureRoot ".wizard-metrics/artifacts/export/$scenario.json") -Raw | ConvertFrom-Json
    if ($result.inspection.matched -ne 26 -or $result.choiceMigration.globalChoiceCount -ne 26 -or
        $result.choiceMigration.picklistColumnCount -ne 29 -or $result.importPermitted) { throw 'Export did not prove the exact Choice package.' }
    foreach ($fault in @(
        @{ Name = 'missing-choice'; Message = 'missing the unique global Picklist' },
        @{ Name = 'label'; Message = 'incorrect value or English label' },
        @{ Name = 'color'; Message = 'incorrect color' },
        @{ Name = 'type'; Message = 'not bound to the approved global Picklist' },
        @{ Name = 'binding'; Message = 'not bound to the approved global Picklist' }
        @{ Name = 'missing-column'; Message = 'not bound to the approved global Picklist' }
    )) {
        $state.PackageFault = $fault.Name
        Assert-Fails { & $exportStage -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker } $fault.Message
    }
    if (@($pacCalls | Where-Object { $_ -match '\bimport\b' }).Count -gt 0) { throw 'Choice package test attempted import.' }
    $legacyPayload | Add-Member -NotePropertyName CurrentSchema -NotePropertyValue @{
        Version = '1.0.0'; ScenarioSlug = $scenario; SolutionUniqueName = 'UnitSolution'; PublisherPrefix = 'foia'
    }
    $legacyPayload | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $fixtureRoot "payloads/scenarios/$scenario/$(Split-Path $payloadPath -Leaf)")
    $current = Get-WizardEffectiveChoiceContract -RepoRoot $fixtureRoot -ScenarioSlug $scenario -SolutionUniqueName UnitSolution
    if ($current.Bindings.Count -ne 29) { throw 'Current contract did not enable fresh-source Choice gates.' }
    $state.PackageFault = ''
    & $exportStage -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker
    $state.PackageFault = 'type'
    Assert-Fails { & $exportStage -ScenarioSlug $scenario -SolutionUniqueName UnitSolution -OutputFolder $outputFolder -PacInvoker $pacInvoker -PreMigrationBackup } 'not bound to the approved global Picklist'
    Assert-Fails { Get-WizardEffectiveChoiceContract -RepoRoot $fixtureRoot -ScenarioSlug $scenario -SolutionUniqueName WrongSolution } 'identity does not match'
    $applyFolder = Join-Path $fixtureRoot '.wizard-metrics/artifacts/choice-migration'
    New-Item -ItemType Directory -Path $applyFolder -Force | Out-Null
    $apply = @{
        scenarioSlug = $scenario; migrationId = $payload.MigrationId; phase = 'Apply'
        solutionUniqueName = 'UnitSolution'; rollbackRequired = $false
    }
    $applyPath = Join-Path $applyFolder "$scenario-apply.json"
    $apply | ConvertTo-Json | Set-Content -LiteralPath $applyPath
    $automatic = Get-WizardRequiredChoiceMigration -RepoRoot $fixtureRoot -ScenarioSlug $scenario -SolutionUniqueName UnitSolution
    if ($automatic.MigrationId -cne $payload.MigrationId) { throw 'Apply evidence did not automatically enable strict Choice checks.' }
    $apply.solutionUniqueName = 'WrongSolution'
    $apply | ConvertTo-Json | Set-Content -LiteralPath $applyPath
    Assert-Fails { Get-WizardRequiredChoiceMigration -RepoRoot $fixtureRoot -ScenarioSlug $scenario -SolutionUniqueName UnitSolution } 'does not match'
} finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}
Write-Host 'Choice migration verification tests passed: 26 global choices, 29 Picklists, strict membership, exact exported definitions, and negative gates.' -ForegroundColor Green
