Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$readme = Get-Content (Join-Path $repoRoot 'README.md') -Raw
$onboarding = Get-Content (Join-Path $repoRoot 'docs/onboarding.md') -Raw
$prompt = Get-Content (Join-Path $repoRoot '.github/prompts/power-platform-demo-wizard.prompt.md') -Raw
$contract = Get-Content (Join-Path $repoRoot 'docs/wizard-contract-v1.md') -Raw
$wizardContract = Get-Content (Join-Path $repoRoot 'wizard.profile.json') -Raw | ConvertFrom-Json
$startWizard = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/05-start-wizard.ps1') -Raw
$sourceControlStandardsPath = Join-Path $repoRoot 'requirements/GithubInstructions_General.md'

$requiredQuestions = [int]$wizardContract.discovery.coreQuestions

if ($requiredQuestions -ne 11) {
  throw "Expected requiredQuestions=11 in wizard.profile.json, found $requiredQuestions"
}

if ($contract -notmatch 'Required Question Set \(11(?:\s+core)?') {
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

if (-not [bool]$wizardContract.discovery.optionalQuestionModules.'source-control') {
  throw 'Profile does not enable the source-control extension block.'
}

foreach ($moduleName in @('user-tasks', 'demo-data')) {
  if (-not [bool]$wizardContract.discovery.optionalQuestionModules.$moduleName) {
    throw "Profile does not enable the $moduleName extension block."
  }
}

foreach ($contentCheck in @($onboarding, $prompt, $contract)) {
  if ($contentCheck -notmatch 'GithubInstructions_General\.md') {
    throw 'Wizard contract surface is missing the GitHub engineering standards reference.'
  }
}

if (-not (Test-Path $sourceControlStandardsPath)) {
  throw 'Canonical GitHub engineering standards file is missing.'
}

foreach ($requiredWizardText in @('Get-SourceControlPreflight', 'SourceControlBranch', 'Source Control Plan')) {
  if ($startWizard -notmatch [regex]::Escape($requiredWizardText)) {
    throw "Terminal wizard is missing source-control integration: $requiredWizardText"
  }
}

foreach ($requiredPlanningText in @('UserTaskDefinitions', 'RelationshipRequirements', 'DemoDataStandardTableStrategy', 'DemoDataRecordCounts', 'DemoDataHeroRecords', 'DemoDataTaskSourceRecordLimit', 'demo-data-plan.json')) {
  if ($startWizard -notmatch [regex]::Escape($requiredPlanningText)) {
    throw "Terminal wizard is missing expanded planning integration: $requiredPlanningText"
  }
}

foreach ($contentCheck in @($onboarding, $prompt, $contract)) {
  foreach ($requiredPlanningText in @('demo-data-plan.json', 'per-table', 'hero record', 'Task activit', 'done definition')) {
    if ($contentCheck -notmatch [regex]::Escape($requiredPlanningText)) {
      throw "Wizard contract surface is missing expanded planning guidance: $requiredPlanningText"
    }
  }
}

Write-Host 'Docs consistency checks passed.' -ForegroundColor Green
