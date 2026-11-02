<#
COMPONENT: Skills 3-4 Offline Parity and Safety Contracts
ENVIRONMENT: PowerShell 7 | Offline CI
NON-NEGOTIABLES: Read-only checks; never connect to Dataverse or change files.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$checks = 0
$skills = @{
 'dataverse-solution-validator' = @('STATIC', 'ENVIRONMENT', 'DEPLOYMENT/USABILITY', 'semantic-field-type-standard.md', 'requirements-traceability.md', 'FAIL', 'BLOCKED', 'NOT VERIFIED', 'read-only', 'TargetProjectRoot', 'Critical', 'High', 'Moderate', 'Low', 'solution-validation.md', 'Task', 'report-mappings.md');
 'power-platform-demo-data-designer' = @('planning-only', '66-seed-synthetic-data.ps1', 'data-*.json', 'synthetic', 'demo-data-plan.json', 'lookup', 'natural keys', 'idempotency', 'latest/all/selected', 'source-record limit', 'standard/OOB', 'separately approved', 'TargetProjectRoot', 'blocked', 'schema validation')
}
foreach ($name in $skills.Keys) {
  $pair = @()
  foreach ($platform in @('.github', '.claude')) {
    $path = Join-Path $root "$platform/skills/$name/SKILL.md"
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing skill: $path" }
    $text = Get-Content -LiteralPath $path -Raw
    if ($text -notmatch "(?s)^---\r?\nname: $name\r?\ndescription: .+?\r?\n---") { throw "Invalid metadata: $path" }
    $checks++
    foreach ($term in $skills[$name]) {
      if (-not $text.Contains($term)) { throw "Missing [$term] in $path" }
      $checks++
    }
    $pair += $text
  }
  if ($pair[0] -cne $pair[1]) { throw "Copilot and Claude drifted: $name" }
  $checks++
}
Write-Host "Skills 3-4: $checks offline contract assertions passed."
