<#
=============================================================================
COMPONENT:    Current Choice Contract Reproducibility Tests
FILE:         scripts/ci/test-current-choice-contract.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-11-04
ENVIRONMENT:  PowerShell 7 | Credential-free isolated Dataverse mock
OVERVIEW:     Prove normal schema and seed stages work without Apply evidence.
ARCHITECTURE: Isolated application Git root; stateful metadata and row transport.
TEST CASES:   Preview, create, rerun, identity/type/value failures, backup gates.
NON-NEGOTIABLES: No live requests, credentials, destructive migration, or imports.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ('foia-current-contract-' + [guid]::NewGuid().ToString('N'))
$oldSolution = $env:DV_SOLUTION_NAME
$oldPrefix = $env:DV_PUBLISHER_PREFIX
$oldSkip = $env:WIZARD_DATA_SKIP_MAIN

function Assert-Rejected {
    param([scriptblock]$Action, [string]$Message)
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notlike "*$Message*") { throw }
        return
    }
    throw "Expected rejection: $Message"
}

try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($folder in @('scripts', 'schemas')) {
        Copy-Item -LiteralPath (Join-Path $repo $folder) -Destination $temp -Recurse
    }
    $scenario = 'federal-foia-management'
    $folder = Join-Path $temp "payloads\scenarios\$scenario"
    New-Item -ItemType Directory -Path (Split-Path $folder -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo "payloads\scenarios\$scenario") -Destination $folder -Recurse
    New-Item -ItemType Directory -Path (Join-Path $temp 'specs') | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo "specs\$scenario") -Destination (Join-Path $temp "specs\$scenario") -Recurse
    Copy-Item -LiteralPath (Join-Path $repo 'wizard.profile.json') -Destination $temp
    & git -C $temp init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Fixture Git init failed.' }
    & git -C $temp remote add origin https://example.invalid/foia-current-contract.git
    if ($LASTEXITCODE -ne 0) { throw 'Fixture remote setup failed.' }
    . (Join-Path $temp 'scripts\bootstrap\helpers\choice-migration-verification.ps1')
    $contract = Get-WizardEffectiveChoiceContract -RepoRoot $temp -ScenarioSlug $scenario -SolutionUniqueName FederalFOIAManagement -PublisherPrefix foia
    if ($contract.CurrentSchema.Version -cne '1.0.0' -or $contract.GlobalChoices.Count -ne 26 -or $contract.Bindings.Count -ne 29) {
        throw 'Fresh-source current contract did not resolve exactly.'
    }
    Assert-Rejected { Get-WizardEffectiveChoiceContract -RepoRoot $temp -ScenarioSlug $scenario -SolutionUniqueName WrongSolution } 'identity does not match'
    Assert-Rejected { Get-WizardEffectiveChoiceContract -RepoRoot $temp -ScenarioSlug $scenario -SolutionUniqueName FederalFOIAManagement -PublisherPrefix other } 'identity does not match'
    if ($null -ne (Get-WizardEffectiveChoiceContract -RepoRoot $temp -ScenarioSlug $scenario -SolutionUniqueName FederalFOIAManagement -PreMigrationBackup)) {
        throw 'Explicit pre-migration backup unexpectedly selected the current contract.'
    }
    if ($null -eq (Get-WizardEffectiveChoiceContract -RepoRoot $temp -ScenarioSlug $scenario -SolutionUniqueName FederalFOIAManagement -PreMigrationBackup -Required)) {
        throw 'Pre-migration backup bypassed mandatory Choice checks.'
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $folder -Filter 'keys-*.json' -File)) {
        Remove-Item -LiteralPath $file.FullName
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $folder -Filter 'columns-*.json' -File)) {
        $document = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -Depth 40
        $names = @($contract.Bindings | Where-Object TableLogicalName -eq $document.TableLogicalName | ForEach-Object ColumnLogicalName)
        $document.Columns = @($document.Columns | Where-Object LogicalName -in $names)
        $document | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $file.FullName
    }
    $dataPath = Join-Path $folder 'data-federal-foia-management.json'
    $data = Get-Content -LiteralPath $dataPath -Raw | ConvertFrom-Json -Depth 40
    $attributes = @{}
    $choices = @{}
    $rows = @{}
    foreach ($table in $data.Tables) { $attributes[$table.TableLogicalName] = @{}; $rows[$table.TableLogicalName] = @{} }
    $calls = [Collections.Generic.List[object]]::new()
    $transport = {
        param($request)
        $path = [Uri]::UnescapeDataString(($request.Uri -split '/api/data/v9.2/')[1])
        $body = if ($null -eq $request.Body) { $null } else { $request.Body | ConvertFrom-Json -Depth 40 }
        $calls.Add([pscustomobject]@{ Method = $request.Method; Path = $path; Body = $body })
        if ($request.Method -eq 'Get') {
            if ($path -eq 'GlobalOptionSetDefinitions?$select=MetadataId,Name') { return @{value = @($choices.Values)} }
            if ($path -match "^GlobalOptionSetDefinitions\(Name='([^']+)'\)") { return $choices[$Matches[1]] }
            if ($path -like 'solutions?*') { return @{value = @(@{solutionid = '11111111-1111-1111-1111-111111111111'})} }
            if ($path -match "^EntityDefinitions\(LogicalName='([^']+)'\)/Attributes\?") {
                return @{value = @($attributes[$Matches[1]].Values)}
            }
            if ($path -match "^EntityDefinitions\(LogicalName='([^']+)'\)/Attributes\(LogicalName='([^']+)'\)") {
                if ($attributes[$Matches[1]].ContainsKey($Matches[2])) { return $attributes[$Matches[1]][$Matches[2]] }
                throw '404 attribute not found'
            }
            if ($path -match "^EntityDefinitions\(LogicalName='([^']+)'\)\?") {
                return @{LogicalName = $Matches[1]; EntitySetName = "unit_$($Matches[1])"; PrimaryIdAttribute = "$($Matches[1])id"}
            }
            if ($path -match "^unit_([^?]+)\?.*? eq '([^']+)'") {
                $tableName = $Matches[1]; $key = $Matches[2]
                return @{value = if ($rows[$tableName].ContainsKey($key)) { @($rows[$tableName][$key]) } else { @() }}
            }
        }
        if ($request.Method -eq 'Post') {
            if ($path -eq 'GlobalOptionSetDefinitions') {
                $body | Add-Member -NotePropertyName MetadataId -NotePropertyValue ([guid]::NewGuid().ToString())
                $choices[$body.Name] = $body
                return
            }
            if ($path -match "^EntityDefinitions\(LogicalName='([^']+)'\)/Attributes$") {
                $tableName = $Matches[1]
                $binding = @($contract.Bindings | Where-Object { $_.TableLogicalName -eq $tableName -and $_.ColumnLogicalName -eq $body.LogicalName })[0]
                if ($body.'@odata.type' -cne 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata' -or
                    $body.'GlobalOptionSet@odata.bind' -cne "/GlobalOptionSetDefinitions($($choices[$binding.GlobalChoiceName].MetadataId))") {
                    throw 'Column was not created as the exact GUID-bound Picklist.'
                }
                $body | Add-Member -NotePropertyName GlobalOptionSet -NotePropertyValue $choices[$binding.GlobalChoiceName]
                $attributes[$tableName][$body.LogicalName] = $body
                return
            }
            if ($path -eq 'PublishXml') {
                [xml]$xml = $body.ParameterXml
                if ($xml.SelectNodes('//optionset').Count -ne 26) { throw 'Global Choice publish scope is incomplete.' }
                return
            }
            if ($path -match '^unit_([a-z0-9_]+)$') {
                $tableName = $Matches[1]
                $table = @($data.Tables | Where-Object TableLogicalName -eq $tableName)[0]
                $body | Add-Member -NotePropertyName "${tableName}id" -NotePropertyValue ([guid]::NewGuid().ToString())
                $rows[$tableName]["$($body.($table.NaturalKey))"] = $body
                return
            }
        }
        if ($request.Method -eq 'Patch' -and $path -match '^unit_([a-z0-9_]+)\(([0-9a-f-]+)\)$') { return }
        throw "Unexpected or forbidden request: $($request.Method) $path"
    }.GetNewClosure()
    $invoke = {
        param($method, $path, $body)
        $request = [pscustomobject]@{ Method = $method; Uri = "https://example.invalid/api/data/v9.2/$path"; Body = if ($null -eq $body) { $null } else { $body | ConvertTo-Json -Depth 40 } }
        & $transport $request
    }.GetNewClosure()
    $preview = @(Initialize-WizardCurrentChoices -Payload $contract -ScenarioSlug $scenario -Invoke $invoke -PreviewOnly)
    if (@($preview | Where-Object Action -eq planned).Count -ne 26 -or @($calls | Where-Object Method -ne Get).Count -ne 0) {
        throw 'Current Choice preview mutated or lost planned global Choices.'
    }
    $env:DV_SOLUTION_NAME = 'FederalFOIAManagement'
    $env:DV_PUBLISHER_PREFIX = 'foia'
    $parameters = @{ PayloadsFolder = $folder; EnvironmentUrl = 'https://example.invalid'; AccessToken = 'fake'; RequestInvoker = $transport; SleepAction = { param($seconds) } }
    & (Join-Path $temp 'scripts\bootstrap\30-build-columns.ps1') @parameters
    if ($choices.Count -ne 26 -or @($attributes.Values | ForEach-Object { $_.Values }).Count -ne 29) {
        throw 'Fresh-source stage 30 did not create exactly 26 Choices and 29 Picklists.'
    }
    $calls.Clear()
    & (Join-Path $temp 'scripts\bootstrap\30-build-columns.ps1') @parameters
    if (@($calls | Where-Object { $_.Method -ne 'Get' -and $_.Path -ne 'PublishXml' }).Count -ne 0) {
        throw 'Current schema rerun issued metadata mutations.'
    }
    $env:WIZARD_DATA_SKIP_MAIN = 'true'
    . (Join-Path $temp 'scripts\bootstrap\66-seed-synthetic-data.ps1') -ScenarioSlug $scenario
    $seedArguments = @{ RepoRoot = $temp; ScenarioSlug = $scenario; PayloadsFolder = $folder; EnvironmentUrl = 'https://example.invalid'; AccessToken = 'fake'; SolutionUniqueName = 'FederalFOIAManagement'; RequestInvoker = $transport }
    $calls.Clear()
    $first = @(Invoke-WizardSyntheticDataStage @seedArguments)
    $numericValues = 0
    foreach ($call in @($calls | Where-Object { $_.Method -eq 'Post' -and $_.Path -like 'unit_*' })) {
        foreach ($binding in @($contract.Bindings | Where-Object { "unit_$($_.TableLogicalName)" -eq $call.Path })) {
            $property = $call.Body.PSObject.Properties[$binding.ColumnLogicalName]
            if ($null -ne $property -and $null -ne $property.Value) {
                if ($property.Value -isnot [long] -and $property.Value -isnot [int]) { throw 'Seed sent a categorical label instead of a numeric value.' }
                $numericValues++
            }
        }
    }
    $second = @(Invoke-WizardSyntheticDataStage @seedArguments)
    if ($first.Count -ne 41 -or $numericValues -ne 97 -or ($first.id -join ',') -cne ($second.id -join ',') -or @($second | Where-Object action -ne updated).Count -ne 0) {
        throw 'Fresh-source seeding did not preserve 41 identities and 97 numeric values.'
    }
    $binding = $contract.Bindings[0]
    $attribute = $attributes[$binding.TableLogicalName][$binding.ColumnLogicalName]
    $attribute.AttributeType = 'String'
    $calls.Clear()
    Assert-Rejected { Initialize-WizardCurrentChoices -Payload $contract -ScenarioSlug $scenario -Invoke $invoke } 'missing or incompatible'
    Assert-Rejected { Invoke-WizardSyntheticDataStage @seedArguments } 'missing or incompatible'
    if (@($calls | Where-Object Method -ne Get).Count -ne 0) { throw 'Incompatible metadata caused a mutation.' }
    $attribute.AttributeType = 'Picklist'
    $table = @($data.Tables | Where-Object TableLogicalName -eq $binding.TableLogicalName)[0]
    $record = @($table.Records | Where-Object { $null -ne $_.Values.PSObject.Properties[$binding.ColumnLogicalName] })[0]
    $record.Values.($binding.ColumnLogicalName) = 'Unmapped label'
    $data | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $dataPath
    $calls.Clear()
    Assert-Rejected { Invoke-WizardSyntheticDataStage @seedArguments } 'unmapped label'
    if ($calls.Count -ne 0) { throw 'Invalid seed values reached the transport.' }
    if (Test-Path -LiteralPath (Join-Path $temp ".wizard-metrics\artifacts\choice-migration\$scenario-apply.json")) {
        throw 'Normal stages fabricated migration Apply evidence.'
    }
    Write-Host 'Current Choice contract tests passed: 26 Choices, 29 GUID-bound Picklists, 97 numeric values, 41 stable records, no Apply evidence, and negative gates.'
} finally {
    $env:DV_SOLUTION_NAME = $oldSolution
    $env:DV_PUBLISHER_PREFIX = $oldPrefix
    $env:WIZARD_DATA_SKIP_MAIN = $oldSkip
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
