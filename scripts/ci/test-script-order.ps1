Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$profile = Get-Content (Join-Path $repoRoot 'wizard.profile.json') -Raw | ConvertFrom-Json
$onboarding = Get-Content (Join-Path $repoRoot 'docs/onboarding.md') -Raw
$prompt = Get-Content (Join-Path $repoRoot '.github/prompts/power-platform-demo-wizard.prompt.md') -Raw

$core = @($profile.execution.coreModules)

foreach ($script in $core) {
  if ($onboarding -notmatch [regex]::Escape($script)) {
    throw "Onboarding missing core script reference: $script"
  }
  if ($prompt -notmatch [regex]::Escape($script)) {
    throw "Prompt missing core script reference: $script"
  }
}

Write-Host 'Script order reference checks passed.' -ForegroundColor Green
