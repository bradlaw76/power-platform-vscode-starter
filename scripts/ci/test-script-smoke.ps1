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

Write-Host 'Script smoke checks passed.' -ForegroundColor Green
