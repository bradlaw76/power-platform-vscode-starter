<#
.SYNOPSIS
    Runs local dry validation for standard/custom Dataverse modeling rules.

.DESCRIPTION
    Performs static checks only (no Dataverse API calls):
    - Spec/plan explicit mapping section exists
    - payloads/ exists and contains expected payload files
    - table payloads do not include known standard tables
    - custom entity logical names are lowercase and prefix-compliant
    - column payload table logical names are lowercase
    - relationship payload entity references are lowercase

.PARAMETER RepoRoot
    Optional repo root path. Defaults to script parent traversal.

.PARAMETER PayloadsFolder
    Optional payload folder override. Defaults to <RepoRoot>/payloads.

.PARAMETER PublisherPrefixOverride
    Optional publisher prefix override (for example mixed/uppercase input testing).
    The validator normalizes this to lowercase for logical-name checks.

.EXAMPLE
    pwsh ./scripts/bootstrap/15-dry-validate.ps1
#>

param(
    [string]$RepoRoot = "",
    [string]$PayloadsFolder = "",
    [string]$PublisherPrefixOverride = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$payloadsFolder = if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    Join-Path $RepoRoot "payloads"
} else {
    $PayloadsFolder
}
$specsFolder = Join-Path $RepoRoot "specs"
$envFile = Join-Path $RepoRoot ".env.ps1"

$standardTables = @(
    "account", "activitypointer", "appointment", "case", "contact", "email", "incident",
    "lead", "opportunity", "phonecall", "product", "task"
)

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$passes = New-Object System.Collections.Generic.List[string]

function Add-Pass([string]$msg) { [void]$passes.Add($msg) }
function Add-Warn([string]$msg) { [void]$warnings.Add($msg) }
function Add-Error([string]$msg) { [void]$errors.Add($msg) }

function Get-OptionalPropertyValue {
    param(
        $Object,
        [string]$PropertyName
    )

    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$PropertyName]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Is-LowercaseLogicalName([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $false }
    return $value -cmatch '^[a-z0-9_]+$'
}

$publisherPrefix = ""
if (-not [string]::IsNullOrWhiteSpace($PublisherPrefixOverride)) {
    $publisherPrefix = $PublisherPrefixOverride.ToLower()
    Add-Pass "Using publisher prefix override (normalized): $publisherPrefix"
} elseif (Test-Path $envFile) {
    try {
        $envText = Get-Content $envFile -Raw
        $prefixMatch = [regex]::Match($envText, 'DV_PUBLISHER_PREFIX\s*=\s*"([^"]+)"')
        if ($prefixMatch.Success) {
            $publisherPrefix = $prefixMatch.Groups[1].Value.ToLower()
            Add-Pass "Resolved publisher prefix from .env.ps1: $publisherPrefix"
        } else {
            Add-Warn "Could not resolve DV_PUBLISHER_PREFIX from .env.ps1. Prefix checks will be limited."
        }
    } catch {
        Add-Warn "Unable to parse .env.ps1 for publisher prefix: $($_.Exception.Message)"
    }
} else {
    Add-Warn ".env.ps1 not found. Prefix checks will be limited."
}

# Validate explicit mapping section in spec/plan files
$specFiles = @()
if (Test-Path $specsFolder) {
    $specFiles = @(Get-ChildItem -Path $specsFolder -Filter "*.md" -Recurse -ErrorAction SilentlyContinue)
}

if ($specFiles.Count -eq 0) {
    Add-Warn "No specs markdown files found under specs/."
} else {
    $mappingHits = 0
    foreach ($f in $specFiles) {
        $text = Get-Content $f.FullName -Raw
        if ($text -match "Explicit Entity Mapping") {
            $mappingHits++
        }
    }

    if ($mappingHits -gt 0) {
        Add-Pass "Found explicit entity mapping section(s) in planning artifacts."
    } else {
        Add-Error "No 'Explicit Entity Mapping' section found in specs artifacts."
    }
}

# Validate payload folder presence
if (-not (Test-Path $payloadsFolder)) {
    Add-Warn "payloads/ folder not found. Build payload dry checks skipped."
} else {
    Add-Pass "Found payloads/ folder."

    $tablePayloads = @(Get-ChildItem -Path $payloadsFolder -Filter "table-*.json" -ErrorAction SilentlyContinue)
    $columnPayloads = @(Get-ChildItem -Path $payloadsFolder -Filter "columns-*.json" -ErrorAction SilentlyContinue)
    $relationshipPayloads = @(Get-ChildItem -Path $payloadsFolder -Filter "relationships-*.json" -ErrorAction SilentlyContinue)

    if ($tablePayloads.Count -eq 0) { Add-Warn "No table-*.json files found." } else { Add-Pass "Found $($tablePayloads.Count) table payload file(s)." }
    if ($columnPayloads.Count -eq 0) { Add-Warn "No columns-*.json files found." } else { Add-Pass "Found $($columnPayloads.Count) column payload file(s)." }
    if ($relationshipPayloads.Count -eq 0) { Add-Warn "No relationships-*.json files found." } else { Add-Pass "Found $($relationshipPayloads.Count) relationship payload file(s)." }

    foreach ($file in $tablePayloads) {
        try {
            $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $entityDefinition = Get-OptionalPropertyValue -Object $doc -PropertyName "EntityDefinition"
            $schemaName = Get-OptionalPropertyValue -Object $entityDefinition -PropertyName "SchemaName"
            if ([string]::IsNullOrWhiteSpace($schemaName)) {
                $schemaName = Get-OptionalPropertyValue -Object $doc -PropertyName "SchemaName"
            }
            if ([string]::IsNullOrWhiteSpace($schemaName)) {
                Add-Error "[$($file.Name)] Missing SchemaName."
                continue
            }

            $logical = $schemaName.ToLower()
            if ($standardTables -contains $logical) {
                Add-Error "[$($file.Name)] Standard table '$logical' must not be in table payloads."
            }

            if (-not (Is-LowercaseLogicalName $logical)) {
                Add-Error "[$($file.Name)] Logical name '$schemaName' is not lowercase-safe."
            }

            if (-not [string]::IsNullOrWhiteSpace($publisherPrefix)) {
                if ($logical -notlike "$publisherPrefix`_*") {
                    Add-Warn "[$($file.Name)] Custom table '$logical' does not start with prefix '$publisherPrefix'."
                }
            }
        } catch {
            Add-Error "[$($file.Name)] Invalid JSON or parse error: $($_.Exception.Message)"
        }
    }

    foreach ($file in $columnPayloads) {
        try {
            $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $tableName = $doc.TableLogicalName
            if ([string]::IsNullOrWhiteSpace($tableName)) {
                Add-Error "[$($file.Name)] Missing TableLogicalName."
                continue
            }
            if (-not (Is-LowercaseLogicalName $tableName)) {
                Add-Error "[$($file.Name)] TableLogicalName '$tableName' should be lowercase logical format."
            }
        } catch {
            Add-Error "[$($file.Name)] Invalid JSON or parse error: $($_.Exception.Message)"
        }
    }

    foreach ($file in $relationshipPayloads) {
        try {
            $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $relsProp = Get-OptionalPropertyValue -Object $doc -PropertyName "Relationships"
            $rels = if ($null -ne $relsProp) { @($relsProp) } else { @($doc) }
            foreach ($rel in $rels) {
                $relationshipDefinition = Get-OptionalPropertyValue -Object $rel -PropertyName "RelationshipDefinition"
                $refd = Get-OptionalPropertyValue -Object $rel -PropertyName "ReferencedEntity"
                $refg = Get-OptionalPropertyValue -Object $rel -PropertyName "ReferencingEntity"

                if ([string]::IsNullOrWhiteSpace($refd)) {
                    $refd = Get-OptionalPropertyValue -Object $relationshipDefinition -PropertyName "ReferencedEntity"
                }
                if ([string]::IsNullOrWhiteSpace($refg)) {
                    $refg = Get-OptionalPropertyValue -Object $relationshipDefinition -PropertyName "ReferencingEntity"
                }

                if (-not [string]::IsNullOrWhiteSpace($refd) -and -not (Is-LowercaseLogicalName $refd)) {
                    Add-Error "[$($file.Name)] ReferencedEntity '$refd' should be lowercase logical format."
                }
                if (-not [string]::IsNullOrWhiteSpace($refg) -and -not (Is-LowercaseLogicalName $refg)) {
                    Add-Error "[$($file.Name)] ReferencingEntity '$refg' should be lowercase logical format."
                }
            }
        } catch {
            Add-Error "[$($file.Name)] Invalid JSON or parse error: $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "=== Dry Validation Report ===" -ForegroundColor Cyan

foreach ($p in $passes) { Write-Host "PASS  $p" -ForegroundColor Green }
foreach ($w in $warnings) { Write-Host "WARN  $w" -ForegroundColor Yellow }
foreach ($e in $errors) { Write-Host "ERROR $e" -ForegroundColor Red }

Write-Host ""
Write-Host "Summary: PASS=$($passes.Count) WARN=$($warnings.Count) ERROR=$($errors.Count)"

if ($errors.Count -gt 0) { exit 1 }
exit 0
