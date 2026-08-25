Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$readme = Get-Content (Join-Path $repoRoot 'README.md') -Raw
$onboarding = Get-Content (Join-Path $repoRoot 'docs/onboarding.md') -Raw
$prompt = Get-Content (Join-Path $repoRoot '.github/prompts/power-platform-demo-wizard.prompt.md') -Raw
$contract = Get-Content (Join-Path $repoRoot 'docs/wizard-contract-v1.md') -Raw
$wizardContract = Get-Content (Join-Path $repoRoot 'wizard.profile.json') -Raw | ConvertFrom-Json
$startWizard = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/05-start-wizard.ps1') -Raw
$initSkill = Get-Content (Join-Path $repoRoot '.github/skills/power-platform-wizard-init/SKILL.md') -Raw
$sourceControlStandardsPath = Join-Path $repoRoot 'requirements/GithubInstructions_General.md'

$requiredQuestions = [int]$wizardContract.discovery.coreQuestions

if ($requiredQuestions -ne 11) {
  throw "Expected requiredQuestions=11 in wizard.profile.json, found $requiredQuestions"
}

if ($contract -notmatch 'Required Question Set \(11(?:\s+core)?') {
  throw 'Contract missing required question set declaration.'
}

if ($readme -notmatch '11(?: core)? discovery questions') {
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

foreach ($contentCheck in @($readme, $onboarding, $prompt, $contract)) {
  foreach ($requiredProfileText in @('standalone-model-driven', 'dynamics-customer-service-extension', 'entry-point table', 'landing view')) {
    if ($contentCheck -notmatch [regex]::Escape($requiredProfileText)) {
      throw "Wizard contract surface is missing application profile guidance: $requiredProfileText"
    }
  }
}

if (@($wizardContract.applicationProfiles) -notcontains 'standalone-model-driven') {
  throw 'Profile does not declare standalone model-driven app support.'
}

if ($wizardContract.architectureIntent.questions -notcontains 'reviewApp: create-or-update (required)') {
  throw 'Profile does not enforce the mandatory review-app behavior.'
}

if (-not (Test-Path $sourceControlStandardsPath)) {
  throw 'Canonical GitHub engineering standards file is missing.'
}

foreach ($requiredWizardText in @('Get-SourceControlPreflight', 'SourceControlBranch', 'Source Control Plan')) {
  if ($startWizard -notmatch [regex]::Escape($requiredWizardText)) {
    throw "Terminal wizard is missing source-control integration: $requiredWizardText"
  }
}

foreach ($requiredPlanningText in @('UserTaskDefinitions', 'RelationshipRequirements', 'DemoDataStandardTableStrategy', 'DemoDataRecordCounts', 'DemoDataHeroRecords', 'DemoDataTaskSourceRecordLimit', 'demo-data-plan.json', 'ConvertTo-ReportMappingRows', 'CriticalReportTables', 'report-mappings.md', 'Report scoping is incomplete', 'Get-PlannedTableLogicalNames', 'Test-AndSetEntryPointPlan', 'EntryPointLandingViewPlan', 'is not present in the explicit table plan')) {
  if ($startWizard -notmatch [regex]::Escape($requiredPlanningText)) {
    throw "Terminal wizard is missing expanded planning integration: $requiredPlanningText"
  }
}

foreach ($requiredStartupText in @('First Response Contract', 'Initial setup', 'Before discovery', 'What will change', 'First decision', 'Start the Power Platform wizard in this repository.')) {
  if ($initSkill -notmatch [regex]::Escape($requiredStartupText)) {
    throw "Init skill is missing startup guidance: $requiredStartupText"
  }
}

foreach ($requiredInitBehavior in @('do not ask for confirmation again', 'Select scenario type before the start path', 'continue the intake in the current conversation', '05-start-wizard.ps1 -Retrofit', '.wizard-metrics/', 'non-destructive')) {
  if ($initSkill -notmatch [regex]::Escape($requiredInitBehavior)) {
    throw "Init skill is missing orchestration behavior: $requiredInitBehavior"
  }
}

foreach ($unsupportedInitBehavior in @('mode=quick|full', 'Quick mode:', 'Full mode:')) {
  if ($initSkill -match [regex]::Escape($unsupportedInitBehavior)) {
    throw "Init skill still advertises unsupported behavior: $unsupportedInitBehavior"
  }
}

foreach ($contentCheck in @($readme, $onboarding, $prompt)) {
  foreach ($requiredStartupText in @('/power-platform-wizard-init', 'Start the Power Platform wizard in this repository.', 'initial setup', '00-prereq-check.ps1', '.wizard-metrics/', 'WIZARD_METRICS_OPTOUT=1')) {
    if ($contentCheck -notmatch [regex]::Escape($requiredStartupText)) {
      throw "Wizard startup surface is missing guided-start content: $requiredStartupText"
    }
  }
}

foreach ($contentCheck in @($readme, $onboarding)) {
  if ($contentCheck -match [regex]::Escape('quick or full')) {
    throw 'Public startup guidance still advertises unsupported quick/full mode selection.'
  }
}

foreach ($requiredPromptBehavior in @('reuse that state', 'do not ask for confirmation again', 'select greenfield or retrofit after setup', 'Do not ask the user to choose chat again', 'do not invoke another wizard prompt')) {
  if ($prompt -notmatch [regex]::Escape($requiredPromptBehavior)) {
    throw "Direct wizard prompt is missing handoff behavior: $requiredPromptBehavior"
  }
}

foreach ($contentCheck in @($onboarding, $prompt, $contract)) {
  foreach ($requiredPlanningText in @('demo-data-plan.json', 'per-table', 'hero record', 'Task activit', 'done definition')) {
    if ($contentCheck -notmatch [regex]::Escape($requiredPlanningText)) {
      throw "Wizard contract surface is missing expanded planning guidance: $requiredPlanningText"
    }
  }
}

foreach ($contentCheck in @($onboarding, $prompt, $contract)) {
  foreach ($requiredReportText in @('report-mappings.md', 'critical')) {
    if ($contentCheck -notmatch [regex]::Escape($requiredReportText)) {
      throw "Wizard contract surface is missing report-scoping guidance: $requiredReportText"
    }
  }
}

foreach ($contentCheck in @($onboarding, $prompt, $contract)) {
  foreach ($requiredEntryPointText in @('entry-point', 'saved query')) {
    if ($contentCheck -notmatch [regex]::Escape($requiredEntryPointText)) {
      throw "Wizard contract surface is missing entry-point validation guidance: $requiredEntryPointText"
    }
  }
}

Write-Host 'Docs consistency checks passed.' -ForegroundColor Green
