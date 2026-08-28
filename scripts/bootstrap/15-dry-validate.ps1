<#
=============================================================================
COMPONENT:    Dry Validate
FILE:         scripts/bootstrap/15-dry-validate.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Dataverse Metadata Validation

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Runs pre-build validation checks against planning artifacts and environment
inputs before any Dataverse metadata creation begins.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          planning files, payload assumptions, and environment values
- Outputs:         validation pass/fail feedback and readiness artifacts
- Dependencies:    repo helpers, planning files, and validation logic
- Side Effects:    writes validation artifacts and telemetry when enabled

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Planning artifacts must exist and be internally consistent.
2. Auth and solution identity should already be validated.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Valid planning context passes readiness checks.
✔ Missing mappings or contract drift fail before build steps run.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Preserve the planning gate before metadata changes.
- Fail fast on contract mismatches that would cause build rework.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Runs local dry validation for standard/custom Dataverse modeling rules.

.DESCRIPTION
    Performs static checks only (no Dataverse API calls):
    - Spec/plan explicit mapping section exists
    - Optional report web resource settings are structurally valid in scenario answers
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
    [string]$PublisherPrefixOverride = "",
    [string]$ScenarioSlug = "",
    [bool]$EnableBuildContractValidation = $true,
    [bool]$EnableArtifactManifest = $true,
    [bool]$EnableAppModuleWiring = $true,
    [bool]$StrictMode = $true,
    [bool]$FastMode = $false,
    [bool]$PreviewOnly = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $RepoRoot -StepName "15-dry-validate.ps1"
}

$hardeningHelper = Join-Path $PSScriptRoot "helpers\wizard-hardening.ps1"
if (Test-Path $hardeningHelper) {
    . $hardeningHelper
}

$payloadsFolder = if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    Join-Path $RepoRoot "payloads"
} else {
    $PayloadsFolder
}
$payloadRootFolder = $payloadsFolder
$payloadValidationFolder = if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    $payloadsFolder
} elseif (
    (Split-Path $payloadsFolder -Leaf) -eq $ScenarioSlug -and
    (Split-Path (Split-Path $payloadsFolder -Parent) -Leaf) -eq 'scenarios'
) {
    $payloadRootFolder = Split-Path (Split-Path $payloadsFolder -Parent) -Parent
    $payloadsFolder
} else {
    Join-Path $payloadsFolder (Join-Path "scenarios" $ScenarioSlug)
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

function Test-LowercaseLogicalName([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $false }
    return $value -cmatch '^[a-z0-9_]+$'
}

function Test-TruthyValue {
    param([string]$Value)

    $normalized = ($Value ?? "").Trim().ToLower()
    return @("yes", "y", "true", "1") -contains $normalized
}

function Get-FriendlyFallbackLabel {
    param(
        [string]$LogicalName,
        [string]$Prefix
    )

    if ([string]::IsNullOrWhiteSpace($LogicalName)) { return "" }

    $value = $LogicalName.ToLower()
    if (-not [string]::IsNullOrWhiteSpace($Prefix)) {
        $normalized = $Prefix.ToLower() + "_"
        if ($value.StartsWith($normalized)) {
            $value = $value.Substring($normalized.Length)
        }
    }

    $value = $value -replace "_", " "
    $value = $value.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return "" }

    $culture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
    return $culture.TextInfo.ToTitleCase($value)
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
if (-not (Test-Path $payloadValidationFolder)) {
    Add-Warn "Scenario payload folder not found: $payloadValidationFolder. Build payload dry checks skipped."
} else {
    Add-Pass "Found payload folder: $payloadValidationFolder"

    $tablePayloads = @(Get-ChildItem -Path $payloadValidationFolder -Filter "table-*.json" -ErrorAction SilentlyContinue)
    $columnPayloads = @(Get-ChildItem -Path $payloadValidationFolder -Filter "columns-*.json" -ErrorAction SilentlyContinue)
    $relationshipPayloads = @(Get-ChildItem -Path $payloadValidationFolder -Filter "relationships-*.json" -ErrorAction SilentlyContinue)

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

            if (-not (Test-LowercaseLogicalName $logical)) {
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
            if (-not (Test-LowercaseLogicalName $tableName)) {
                Add-Error "[$($file.Name)] TableLogicalName '$tableName' should be lowercase logical format."
            }

            foreach ($col in @($doc.Columns)) {
                $logical = Get-OptionalPropertyValue -Object $col -PropertyName "LogicalName"
                if ([string]::IsNullOrWhiteSpace($logical)) {
                    $logical = Get-OptionalPropertyValue -Object $col -PropertyName "SchemaName"
                }

                if ([string]::IsNullOrWhiteSpace($logical)) {
                    Add-Error "[$($file.Name)] Column is missing LogicalName/SchemaName."
                    continue
                }

                $logical = $logical.ToLower()
                if (-not (Test-LowercaseLogicalName $logical)) {
                    Add-Error "[$($file.Name)] Column logical name '$logical' should be lowercase logical format."
                }

                $displayName = Get-OptionalPropertyValue -Object $col -PropertyName "DisplayName"
                $localized = @()
                if ($null -ne $displayName) {
                    $localizedProp = Get-OptionalPropertyValue -Object $displayName -PropertyName "LocalizedLabels"
                    if ($null -ne $localizedProp) {
                        $localized = @($localizedProp)
                    }
                }

                $nonEmptyLabels = @($localized | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Label) })
                if ($nonEmptyLabels.Count -eq 0) {
                    $fallback = Get-FriendlyFallbackLabel -LogicalName $logical -Prefix $publisherPrefix
                    if ([string]::IsNullOrWhiteSpace($fallback)) {
                        Add-Error "[$($file.Name)] Column '$logical' has no usable DisplayName label and no friendly fallback label."
                    } else {
                        Add-Warn "[$($file.Name)] Column '$logical' has no payload DisplayName label; form will use fallback '$fallback'."
                    }
                    continue
                }

                $label1033 = @($nonEmptyLabels | Where-Object { $_.LanguageCode -eq 1033 })
                if ($label1033.Count -eq 0) {
                    Add-Warn "[$($file.Name)] Column '$logical' has labels but none for language 1033; first available label will be used."
                }
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

                if (-not [string]::IsNullOrWhiteSpace($refd) -and -not (Test-LowercaseLogicalName $refd)) {
                    Add-Error "[$($file.Name)] ReferencedEntity '$refd' should be lowercase logical format."
                }
                if (-not [string]::IsNullOrWhiteSpace($refg) -and -not (Test-LowercaseLogicalName $refg)) {
                    Add-Error "[$($file.Name)] ReferencingEntity '$refg' should be lowercase logical format."
                }
            }
        } catch {
            Add-Error "[$($file.Name)] Invalid JSON or parse error: $($_.Exception.Message)"
        }
    }
}

# Validate optional report web resource settings in scenario answers files
$answersFiles = @()
if (Test-Path $specsFolder) {
    $answersFiles = @(Get-ChildItem -Path $specsFolder -Filter "answers.md" -Recurse -ErrorAction SilentlyContinue)
}

if ($answersFiles.Count -eq 0) {
    Add-Warn "No scenario answers.md files found under specs/. Optional report checks skipped."
} else {
    $reportEnabledCount = 0
    foreach ($file in $answersFiles) {
        try {
            $text = Get-Content $file.FullName -Raw
            $matchLine = [regex]::Match($text, '(?im)^19\.\s*Create optional HTML report web resources.*:\s*(.+)$')
            $enabledRaw = if ($matchLine.Success) {
                $matchLine.Groups[1].Value.Trim()
            } else {
                $enabledBlockMatch = [regex]::Match($text, '(?ims)^##\s+Optional Report Web Resources\s*\r?\n(.*?)(?=^##\s+|\z)')
                if ($enabledBlockMatch.Success) {
                    $inner = $enabledBlockMatch.Groups[1].Value
                    [regex]::Match($inner, '(?im)^-\s*Enabled:\s*(.+)$').Groups[1].Value.Trim()
                } else {
                    ""
                }
            }

            if ([string]::IsNullOrWhiteSpace($enabledRaw)) {
                Add-Pass "[$($file.Name)] Optional report web resource flag not present (legacy scenario format)."
                continue
            }

            if (Test-TruthyValue -Value $enabledRaw) {
                $reportEnabledCount++
                $optionalBlockMatch = [regex]::Match($text, '(?ims)^##\s+Optional Report Web Resources\s*\r?\n(.*?)(?=^##\s+|\z)')
                if (-not $optionalBlockMatch.Success) {
                    Add-Warn "[$($file.FullName)] Reports are enabled but the optional report configuration block was not found."
                } else {
                    $optionalText = $optionalBlockMatch.Groups[1].Value
                    $selectedReports = [regex]::Match($optionalText, '(?im)^-\s*(Selected Reports|Report set):\s*(.+)$').Groups[2].Value.Trim()
                    if ([string]::IsNullOrWhiteSpace($selectedReports)) {
                        Add-Warn "[$($file.FullName)] Reports are enabled but no selected report set was recorded."
                    }
                    $reportMode = [regex]::Match($optionalText, '(?im)^-\s*Report Mode:\s*(.+)$').Groups[1].Value.Trim()
                    if (-not [string]::IsNullOrWhiteSpace($reportMode) -and @('live', 'live-with-design-fallback', 'static') -notcontains $reportMode.ToLowerInvariant()) {
                        Add-Error "[$($file.FullName)] Report Mode '$reportMode' is invalid. Use live, live-with-design-fallback, or static."
                    }
                }
            } else {
                Add-Pass "[$($file.Name)] Optional report web resources disabled (expected when not needed)."
            }
        } catch {
            Add-Error "[$($file.FullName)] Failed optional report settings check: $($_.Exception.Message)"
        }
    }

    if ($reportEnabledCount -gt 0) {
        Add-Pass "Optional report web resources enabled for $reportEnabledCount scenario(s)."
    }
}

Write-Host ""
Write-Host "=== Dry Validation Report ===" -ForegroundColor Cyan

if (Get-Command Test-WizardBuildContract -ErrorAction SilentlyContinue) {
    $contractValidation = Test-WizardBuildContract -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $payloadRootFolder -EnableBuildContractValidation:$EnableBuildContractValidation -StrictMode:$StrictMode -EnableAppModuleWiring:$EnableAppModuleWiring
    foreach ($message in @($contractValidation.Passes)) { Add-Pass $message }
    foreach ($message in @($contractValidation.Warnings)) { Add-Warn $message }
    foreach ($message in @($contractValidation.Errors)) { Add-Error $message }

    if ($EnableArtifactManifest) {
        Initialize-WizardArtifactManifest -RepoRoot $RepoRoot -ScenarioSlug $contractValidation.ScenarioSlug -SolutionName $contractValidation.SolutionName -PublisherPrefix $contractValidation.PublisherPrefix | Out-Null
    }

    $artifactPaths = Write-WizardBuildContractArtifacts -RepoRoot $RepoRoot -ValidationResult $contractValidation
}

foreach ($p in $passes) { Write-Host "PASS  $p" -ForegroundColor Green }
foreach ($w in $warnings) { Write-Host "WARN  $w" -ForegroundColor Yellow }
foreach ($e in $errors) { Write-Host "ERROR $e" -ForegroundColor Red }

Write-Host ""
Write-Host "Summary: PASS=$($passes.Count) WARN=$($warnings.Count) ERROR=$($errors.Count)"
if ($null -ne $artifactPaths) {
    Write-Host "Contract JSON: $($artifactPaths.ContractJsonPath)"
    Write-Host "Contract MD:   $($artifactPaths.ContractMarkdownPath)"
}
if ($FastMode) {
    Write-Host "FastMode: enabled" -ForegroundColor DarkGray
}
if ($PreviewOnly) {
    Write-Host "PreviewOnly: enabled" -ForegroundColor DarkGray
}

if ($errors.Count -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Dry validation found errors."
    }
    exit 1
}
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Dry validation passed."
}
exit 0
