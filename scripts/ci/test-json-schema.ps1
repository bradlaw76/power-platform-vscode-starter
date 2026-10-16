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
✔ All registered payload families match their schema.

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
$acceleratorSchemaRoot = Join-Path $repoRoot 'schemas/accelerators'
$schemaByFamily = [ordered]@{
    'table'         = Join-Path $schemaRoot 'table.schema.json'
    'columns'       = Join-Path $schemaRoot 'columns.schema.json'
    'relationships' = Join-Path $schemaRoot 'relationships.schema.json'
    'process'       = Join-Path $schemaRoot 'process.schema.json'
    'reporting'     = Join-Path $schemaRoot 'reporting.schema.json'
    'data'          = Join-Path $schemaRoot 'data.schema.json'
    'form-layouts'  = Join-Path $schemaRoot 'form-layouts.schema.json'
    'grid-controls' = Join-Path $schemaRoot 'grid-controls.schema.json'
    'choice-presentations' = Join-Path $schemaRoot 'choice-presentations.schema.json'
}
$failures = [System.Collections.Generic.List[string]]::new()
$parsedCount = 0
$validatedPayloadCount = 0
$validatedAcceleratorCount = 0

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

    $acceleratorSchemaPath = if ($relativePath -ceq 'accelerator.providers.json') {
        Join-Path $acceleratorSchemaRoot 'provider-registry.schema.json'
    } elseif ($relativePath -match '^specs[\\/]fast-solution-accelerator-discovery[\\/]evidence[\\/]pkg[\\/](?:core|investigations|training-certification)\.json$') {
        Join-Path $acceleratorSchemaRoot 'package-metadata.schema.json'
    } elseif ($relativePath -ceq 'specs\fast-solution-accelerator-discovery\evidence\pkg\package-input-manifest.json') {
        Join-Path $acceleratorSchemaRoot 'package-input-manifest.schema.json'
    } else {
        $null
    }
    if ($null -ne $acceleratorSchemaPath) {
        try {
            if (-not (Test-Json -Json $json -SchemaFile $acceleratorSchemaPath -ErrorAction Stop)) {
                $failures.Add("Accelerator schema validation failed for $relativePath.") | Out-Null
            } else {
                $validatedAcceleratorCount++
            }
        } catch {
            $failures.Add("Accelerator schema validation failed for ${relativePath}: $($_.Exception.Message)") | Out-Null
        }
        continue
    }

    $isScenarioFormLayout = $file.Name -ceq 'form-layouts.json' -and
        $relativePath -match '^specs[\\/][^\\/]+[\\/]form-layouts\.json$'
    if ($isScenarioFormLayout) {
        $family = 'form-layouts'
    } elseif ($file.Name -ceq 'grid-controls.json' -and
        $relativePath -match '^specs[\\/][^\\/]+[\\/]grid-controls\.json$') {
        $family = 'grid-controls'
    } elseif ($file.Name -match '^(?<family>table|columns|relationships|process|reporting|data|choice-presentations)-.+\.json$') {
        $family = $Matches['family']
    } else {
        continue
    }
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

Write-Host "JSON validation passed: $parsedCount documents parsed; $validatedPayloadCount payloads and $validatedAcceleratorCount accelerator documents matched schemas." -ForegroundColor Green