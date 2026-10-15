Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$payloadFolder = Join-Path $repoRoot 'payloads/scenarios/federal-foia-management'
$keyFiles = @(Get-ChildItem -LiteralPath $payloadFolder -Filter 'keys-*.json' -File | Sort-Object Name)
if ($keyFiles.Count -eq 0) { throw 'Federal FOIA alternate-key payloads are missing.' }

$columnsByTable = @{}
foreach ($file in @(Get-ChildItem -LiteralPath $payloadFolder -Filter 'columns-*.json' -File)) {
    $document = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    $columns = @{}
    foreach ($column in @($document.Columns)) {
        $logicalName = ("$($column.LogicalName ?? $column.SchemaName)").Trim().ToLowerInvariant()
        $columns[$logicalName] = $column
    }
    $columnsByTable[("$($document.TableLogicalName)").Trim().ToLowerInvariant()] = $columns
}

$requiredDeclarations = [ordered]@{
    'foia_foiarequest' = @('foia_trackingnumber')
    'foia_searchtask' = @('foia_searchtasknumber')
    'foia_reviewtask' = @('foia_reviewtasknumber')
    'foia_responsiverecord' = @('foia_recordidentifier')
    'foia_exemptiondecision' = @('foia_decisionnumber')
    'foia_redactiondecision' = @('foia_redactionnumber')
    'foia_releasepackage' = @('foia_packagenumber', 'foia_packageversion')
    'foia_appeal' = @('foia_appealnumber')
    'foia_clockevent' = @('foia_eventidentifier')
    'foia_auditevent' = @('foia_eventidentifier')
    'foia_aiassistancerecord' = @('foia_assistanceidentifier')
}
$supportedMetadataTypes = @(
    'Microsoft.Dynamics.CRM.StringAttributeMetadata',
    'Microsoft.Dynamics.CRM.IntegerAttributeMetadata',
    'Microsoft.Dynamics.CRM.DecimalAttributeMetadata',
    'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata',
    'Microsoft.Dynamics.CRM.PicklistAttributeMetadata',
    'Microsoft.Dynamics.CRM.LookupAttributeMetadata'
)
$declarations = @{}
$schemaNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

foreach ($file in $keyFiles) {
    $document = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    $table = ("$($document.TableLogicalName)").Trim().ToLowerInvariant()
    if (-not $columnsByTable.ContainsKey($table)) { throw "Key payload $($file.Name) targets a table without a column payload: $table." }
    foreach ($key in @($document.Keys)) {
        if (-not $schemaNames.Add("$($key.SchemaName)")) { throw "Duplicate alternate-key schema name: $($key.SchemaName)." }
        $attributes = @($key.KeyAttributes | ForEach-Object { ("$_").Trim().ToLowerInvariant() })
        if ($declarations.ContainsKey($table)) { throw "Federal FOIA currently supports one controlled alternate key per declared table; duplicate table payload: $table." }
        $estimatedBytes = 0
        foreach ($attribute in $attributes) {
            if (-not $columnsByTable[$table].ContainsKey($attribute)) { throw "Key '$($key.SchemaName)' references missing column '$table.$attribute'." }
            $column = $columnsByTable[$table][$attribute]
            $metadataType = "$($column.'@odata.type')"
            if ($metadataType -notin $supportedMetadataTypes) { throw "Key '$($key.SchemaName)' uses unsupported Dataverse alternate-key type '$metadataType' on '$attribute'." }
            $estimatedBytes += if ($metadataType -eq 'Microsoft.Dynamics.CRM.StringAttributeMetadata') { 2 * [int]$column.MaxLength } else { 16 }
        }
        if ($estimatedBytes -gt 900) { throw "Key '$($key.SchemaName)' can exceed the Dataverse 900-byte alternate-key limit (estimated $estimatedBytes bytes)." }
        $declarations[$table] = $attributes
    }
}

foreach ($expected in $requiredDeclarations.GetEnumerator()) {
    if (-not $declarations.ContainsKey($expected.Key)) { throw "Missing controlled identifier key for table '$($expected.Key)'." }
    if (($declarations[$expected.Key] -join '|') -cne (@($expected.Value) -join '|')) {
        throw "Controlled identifier key for '$($expected.Key)' does not match the approved attribute shape."
    }
}
if ($declarations.Count -ne $requiredDeclarations.Count) {
    throw "Unexpected Federal FOIA key declarations found. Expected $($requiredDeclarations.Count), found $($declarations.Count)."
}

$columnStage = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/bootstrap/30-build-columns.ps1') -Raw
foreach ($required in @('helpers\alternate-keys.ps1', 'Invoke-WizardAlternateKeyStage', "-Kind 'key'", '-PreviewOnly:$PreviewOnly', '-SolutionUniqueName $solutionName')) {
    if ($columnStage -notmatch [regex]::Escape($required)) { throw "Column stage is missing alternate-key contract: $required." }
}

Write-Host "Alternate-key contract passed: $($declarations.Count) schema-bound Federal FOIA keys use supported Dataverse shapes." -ForegroundColor Green
