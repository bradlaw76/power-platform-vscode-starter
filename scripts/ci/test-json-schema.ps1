<#
=============================================================================
COMPONENT:    JSON and Payload Schema Validation
FILE:         scripts/ci/test-json-schema.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-24
ENVIRONMENT:  PowerShell 7 | CI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Parses every repository JSON document and validates supported Dataverse
payload families against checked-in JSON Schemas without live credentials.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            CI validation
- Inputs:          repository JSON files and schemas/payloads/*.schema.json
- Outputs:         actionable failures or a successful validation message
- Dependencies:    PowerShell 7 Test-Json
- Side Effects:    none

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Every JSON file parses successfully.
✔ table, columns, relationships, and process payloads match their schema.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Keep this validation credential-free.
- Validate new payload families by explicit filename-to-schema mapping.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$schemaRoot = Join-Path $repoRoot 'schemas/payloads'
$schemaByFamily = [ordered]@{
    'table'         = Join-Path $schemaRoot 'table.schema.json'
    'columns'       = Join-Path $schemaRoot 'columns.schema.json'
    'relationships' = Join-Path $schemaRoot 'relationships.schema.json'
    'process'       = Join-Path $schemaRoot 'process.schema.json'
}
$failures = [System.Collections.Generic.List[string]]::new()
$parsedCount = 0
$validatedPayloadCount = 0

foreach ($schemaPath in $schemaByFamily.Values) {
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        $failures.Add("Missing payload schema: $schemaPath") | Out-Null
    }
}

$jsonFiles = @(Get-ChildItem -LiteralPath $repoRoot -Filter '*.json' -File -Recurse | Where-Object {
    $_.FullName -notmatch '[\\/](?:\.git|node_modules|out|\.wizard-metrics)[\\/]'
} | Sort-Object FullName)

foreach ($file in $jsonFiles) {
    $relativePath = [IO.Path]::GetRelativePath($repoRoot, $file.FullName)
    try {
        $json = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        $null = $json | ConvertFrom-Json -AsHashtable
        $parsedCount++
    } catch {
        $failures.Add("Invalid JSON in ${relativePath}: $($_.Exception.Message)") | Out-Null
        continue
    }

    if ($file.Name -notmatch '^(?<family>table|columns|relationships|process)-.+\.json$') {
        continue
    }

    $family = $Matches['family']
    $schemaPath = $schemaByFamily[$family]
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        continue
    }

    try {
        if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop)) {
            $failures.Add("Schema validation failed for $relativePath using $family.schema.json.") | Out-Null
            continue
        }
        $validatedPayloadCount++
    } catch {
        $failures.Add("Schema validation failed for ${relativePath}: $($_.Exception.Message)") | Out-Null
    }
}

if ($failures.Count -gt 0) {
    throw "JSON validation failed with $($failures.Count) issue(s):`n - $($failures -join "`n - ")"
}

Write-Host "JSON validation passed: $parsedCount documents parsed; $validatedPayloadCount payloads matched schemas." -ForegroundColor Green