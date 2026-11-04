<#
=============================================================================
COMPONENT:    Choice Migration Stage Tests
FILE:         scripts/ci/test-choice-migration-stage.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-16
ENVIRONMENT:  PowerShell 7 | Credential-free Dataverse mocks
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$stage = Join-Path $repoRoot 'scripts/bootstrap/35-preview-choice-migration.ps1'
$payloadFolder = Join-Path $repoRoot 'payloads/scenarios/federal-foia-management'
$dataPayload = Get-Content -LiteralPath (Join-Path $payloadFolder 'data-federal-foia-management.json') -Raw |
    ConvertFrom-Json -Depth 30

$offlineCalls = [System.Collections.Generic.List[object]]::new()
$offlineInvoker = {
    param($request)
    [void]$offlineCalls.Add($request)
    throw 'Offline mode must not call Dataverse.'
}.GetNewClosure()
& $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
    -Mode Offline -RequestInvoker $offlineInvoker
if ($offlineCalls.Count -ne 0) { throw 'Offline choice migration validation made a transport call.' }

function New-TestGuid {
    param([Parameter(Mandatory)] [string]$Seed)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Seed)
    $hash = [Security.Cryptography.MD5]::HashData($bytes)
    return [Guid]::new($hash).ToString()
}

$tableByEntitySet = @{}
foreach ($table in @($dataPayload.Tables)) {
    $tableByEntitySet["unit_$($table.TableLogicalName)"] = $table
}
$calls = [System.Collections.Generic.List[object]]::new()
$testState = [pscustomobject]@{ InjectForeignValue = $false; ForeignInjected = $false }
$requestInvoker = {
    param($request)
    $path = [Uri]::UnescapeDataString(($request.Uri -split '/api/data/v9.2/')[1])
    [void]$calls.Add([pscustomobject]@{ Method = "$($request.Method)"; Path = $path })
    if ("$($request.Method)" -ne 'Get') { throw "Unexpected mutating request: $($request.Method) $path" }

    if ($path -match "^EntityDefinitions\(LogicalName='(?<table>[^']+)'\)/Attributes\(LogicalName='(?<column>[^']+)'\)") {
        return [pscustomobject]@{
            MetadataId = New-TestGuid "attribute|$($Matches.table)|$($Matches.column)"
            LogicalName = $Matches.column
            AttributeType = 'String'
        }
    }
    if ($path -match "^EntityDefinitions\(LogicalName='(?<table>[^']+)'\)\?") {
        return [pscustomobject]@{
            EntitySetName = "unit_$($Matches.table)"
            PrimaryIdAttribute = "$($Matches.table)id"
        }
    }
    if ($path -match '^RetrieveDependenciesForDelete\(ObjectId=(?<id>[0-9a-f-]+),ComponentType=2\)$') {
        return [pscustomobject]@{ value = @([pscustomobject]@{
            dependencyid = New-TestGuid "dependency|$($Matches.id)"
            dependentcomponenttype = 24
            dependentcomponentobjectid = New-TestGuid "form|$($Matches.id)"
            dependencytype = 2
        }) }
    }

    $entitySet = ($path -split '\?')[0]
    if ($tableByEntitySet.ContainsKey($entitySet)) {
        $table = $tableByEntitySet[$entitySet]
        if ($path -notmatch '\$select=(?<select>[^&]+)') { throw "Missing select clause: $path" }
        $selected = @($Matches.select -split ',')
        $primaryId = $selected[0]
        $columnName = $selected[1]
        $sourceTagField = $selected[2]
        $rows = [System.Collections.Generic.List[object]]::new()
        foreach ($record in @($table.Records)) {
            $property = $record.Values.PSObject.Properties[$columnName]
            if ($null -eq $property -or $null -eq $property.Value) { continue }
            $sourceTag = "$($dataPayload.SourceTag)"
            if ($testState.InjectForeignValue -and -not $testState.ForeignInjected) {
                $sourceTag = 'foreign-source'
                $testState.ForeignInjected = $true
            }
            $row = [ordered]@{
                $primaryId = New-TestGuid "row|$entitySet|$($record.Key)"
                $columnName = $property.Value
                $sourceTagField = $sourceTag
            }
            [void]$rows.Add([pscustomobject]$row)
        }
        return [pscustomobject]@{ value = @($rows) }
    }

    throw "Unexpected Dataverse request: $($request.Method) $path"
}.GetNewClosure()

& $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
    -Mode Preview -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
    -RequestInvoker $requestInvoker
if (@($calls | Where-Object Method -ne 'Get').Count -ne 0) {
    throw 'Choice migration Preview issued a mutating request.'
}
$evidencePath = Join-Path $repoRoot '.wizard-metrics/artifacts/choice-migration/federal-foia-management.json'
$evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json -Depth 30
if ($evidence.mode -ne 'Preview' -or $evidence.globalChoiceCount -ne 26 -or
    $evidence.bindingCount -ne 29 -or $evidence.mutationCount -ne 0) {
    throw 'Choice migration Preview evidence has incorrect counts or mode.'
}
if (@($evidence.bindings).Count -ne 29 -or
    @($evidence.bindings | Where-Object dependencyCount -ne 1).Count -ne 0) {
    throw 'Choice migration Preview did not retain dependency evidence for all bindings.'
}

$calls.Clear()
$testState.InjectForeignValue = $true
$testState.ForeignInjected = $false
try {
    & $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder `
        -Mode Preview -EnvironmentUrl 'https://unit.test' -AccessToken 'token' `
        -RequestInvoker $requestInvoker
    throw 'Expected foreign populated-value failure.'
} catch {
    if ($_.Exception.Message -notmatch 'non-synthetic value') { throw }
}
if (@($calls | Where-Object Method -ne 'Get').Count -ne 0) {
    throw 'Foreign-value failure issued a mutating request.'
}

Write-Host 'Choice migration stage tests passed.' -ForegroundColor Green
