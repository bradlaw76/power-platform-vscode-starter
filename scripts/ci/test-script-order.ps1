Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$profile = Get-Content (Join-Path $repoRoot 'wizard.profile.json') -Raw | ConvertFrom-Json
$onboarding = Get-Content (Join-Path $repoRoot 'docs/onboarding.md') -Raw
$prompt = Get-Content (Join-Path $repoRoot '.github/prompts/power-platform-demo-wizard.prompt.md') -Raw
$orchestrator = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/90-run-build.ps1') -Raw

$core = @($profile.execution.coreModules)

foreach ($script in $core) {
  if ($onboarding -notmatch [regex]::Escape($script)) {
    throw "Onboarding missing core script reference: $script"
  }
  if ($prompt -notmatch [regex]::Escape($script)) {
    throw "Prompt missing core script reference: $script"
  }
}

$formsIndex = $orchestrator.IndexOf("Name = 'forms-views'")
$columnsIndex = $orchestrator.IndexOf("Name = 'columns'")
$choiceIndex = $orchestrator.IndexOf("Name = 'choice-presentations'")
$relationshipsIndex = $orchestrator.IndexOf("Name = 'relationships'")
$gridIndex = $orchestrator.IndexOf("Name = 'grid-control'")
$reportingIndex = $orchestrator.IndexOf("Name = 'native-reporting'")
$appIndex = $orchestrator.IndexOf("Name = 'app-module'")
$semanticIndex = $orchestrator.IndexOf("Name = 'semantic-metadata'")
$semanticFinalIndex = $orchestrator.IndexOf("Name = 'semantic-metadata-final'")
$exportIndex = $orchestrator.IndexOf("Name = 'unmanaged-export'")
if ($semanticIndex -le $relationshipsIndex -or $semanticIndex -ge $formsIndex -or
    $semanticFinalIndex -le $formsIndex -or $semanticFinalIndex -ge $exportIndex) {
  throw 'Semantic live metadata gates must follow relationships and precede experience/export.'
}
if ($formsIndex -lt 0 -or $gridIndex -le $formsIndex -or $gridIndex -ge $reportingIndex -or $gridIndex -ge $appIndex) {
  throw 'Optional stage 61 must run after forms/views and before native reporting/app assembly.'
}
if ($columnsIndex -lt 0 -or $choiceIndex -le $columnsIndex -or $choiceIndex -ge $relationshipsIndex) {
  throw 'Optional stage 35 must run after column creation and before relationships.'
}

Write-Host 'Script order reference checks passed.' -ForegroundColor Green
