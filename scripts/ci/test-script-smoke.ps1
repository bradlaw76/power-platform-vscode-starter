Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$relationships = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/40-build-relationships.ps1') -Raw
$addToSolution = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/50-add-to-solution.ps1') -Raw
$formsViews = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/60-build-forms-views.ps1') -Raw

if ($relationships -notmatch 'SchemaName\.Equals\(\$SchemaName') {
  throw 'Relationship existence check is missing an explicit returned-data SchemaName comparison.'
}

foreach ($required in @('ReferencedEntity', 'ReferencingEntity', 'Entity1LogicalName', 'Entity2LogicalName')) {
  if ($addToSolution -notmatch [regex]::Escape($required)) {
    throw "Add-to-solution relationship entity lookup appears incomplete: missing $required."
  }
}

if ($formsViews -notmatch 'PrimaryIdAttribute') {
  throw 'Forms/views script does not query PrimaryIdAttribute.'
}

if ($formsViews -notmatch '\$resolvedPrimaryId') {
  throw 'Forms/views layout does not use resolved primary id field.'
}

foreach ($scriptName in @('65-build-web-resources.ps1', '70-build-web-resources.ps1', '80-post-build-analysis.ps1', '81-build-progress-matrix.ps1', '82-build-progress-report.ps1', 'helpers/wizard-telemetry.ps1')) {
  $parseErrors = $null
  $parseTokens = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $repoRoot "scripts/bootstrap/$scriptName"),
    [ref]$parseTokens,
    [ref]$parseErrors
  ) | Out-Null
  if ($parseErrors.Count -gt 0) {
    throw "$scriptName has PowerShell parse errors: $(($parseErrors | ForEach-Object { $_.Message }) -join '; ')"
  }
}

Write-Host 'Script smoke checks passed.' -ForegroundColor Green
