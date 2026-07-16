Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$readme = Get-Content (Join-Path $repoRoot 'README.md') -Raw
$onboarding = Get-Content (Join-Path $repoRoot 'docs/onboarding.md') -Raw
$prompt = Get-Content (Join-Path $repoRoot '.github/prompts/power-platform-demo-wizard.prompt.md') -Raw
$contract = Get-Content (Join-Path $repoRoot 'docs/wizard-contract-v1.md') -Raw
$profile = Get-Content (Join-Path $repoRoot 'wizard.profile.json') -Raw | ConvertFrom-Json

$requiredQuestions = [int]$profile.discovery.requiredQuestions

if ($requiredQuestions -ne 11) {
  throw "Expected requiredQuestions=11 in wizard.profile.json, found $requiredQuestions"
}

if ($contract -notmatch 'Required Question Set \(11\)') {
  throw 'Contract missing required question set declaration.'
}

if ($readme -notmatch '11 discovery questions') {
  throw 'README does not state the canonical 11 required discovery questions.'
}

if ($onboarding -notmatch '11 required questions') {
  throw 'Onboarding does not state the canonical 11 required discovery questions.'
}

if ($prompt -notmatch 'Required Question Set \(11\)' -and $prompt -notmatch '11 required') {
  throw 'Prompt does not reference the 11-question required set.'
}

Write-Host 'Docs consistency checks passed.' -ForegroundColor Green
