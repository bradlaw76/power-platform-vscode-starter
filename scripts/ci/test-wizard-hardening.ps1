Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts/bootstrap/helpers/wizard-hardening.ps1')

function New-TestWizardRepo {
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("wizard-hardening-test-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path (Join-Path $root 'specs/test-scenario') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $root 'payloads') -Force | Out-Null

  @'
# Discovery Answers

## Scenario
- Name: Test Scenario
- Slug: test-scenario

## Wizard Answers
12. Solution (new/existing): new -- TestSolution
13. Publisher prefix (new/existing): new -- tst

## Optional Report Web Resources
- Enabled: yes
- Selected Reports: Agent Performance

## Application Profile
- Profile: standalone-model-driven
- Table Strategy: custom-only
- Form Strategy: create-new-forms
- Entry Point Table: tst_agent
- Landing View: Active Agents
- Review App Mode: create-or-update
- Required App Artifacts: all run-created tables, forms, views, and processes

## App Module
- Enabled: yes
- App Name: Test App
- Unique Name: tst_testapp
- Navigation Group: Operations
'@ | Set-Content -Path (Join-Path $root 'specs/test-scenario/answers.md') -Encoding UTF8

  @'
# spec.md

## Explicit Entity Mapping (Required)

### Standard reused tables (display -> logical)
- Case -> incident

### Custom tables to create (input -> generated logical)
- Agent -> tst_agent
'@ | Set-Content -Path (Join-Path $root 'specs/test-scenario/spec.md') -Encoding UTF8

  @'
# plan.md

- Solution unique name: TestSolution
- Publisher prefix: tst

## Explicit Entity Mapping (Required Before Payloads)

### Standard reused tables (display -> logical)
- Case -> incident

### Custom tables to create (input -> generated logical)
- Agent -> tst_agent

### Custom fields to add
- tst_agent.tst_region

### Relationships to create
- incident (referencing) -> tst_agent (referenced)
'@ | Set-Content -Path (Join-Path $root 'specs/test-scenario/plan.md') -Encoding UTF8

  '# tasks.md' | Set-Content -Path (Join-Path $root 'specs/test-scenario/tasks.md') -Encoding UTF8
  '{"EntityDefinition":{"SchemaName":"tst_agent"}}' | Set-Content -Path (Join-Path $root 'payloads/table-agent.json') -Encoding UTF8
  '{"TableLogicalName":"tst_agent","Columns":[{"LogicalName":"tst_region"}]}' | Set-Content -Path (Join-Path $root 'payloads/columns-agent.json') -Encoding UTF8
  '{"Relationships":[{"SchemaName":"tst_incident_tst_agent","RelationshipDefinition":{"SchemaName":"tst_incident_tst_agent","ReferencedEntity":"tst_agent","ReferencingEntity":"incident"}}]}' | Set-Content -Path (Join-Path $root 'payloads/relationships-agent.json') -Encoding UTF8
  return $root
}

function Remove-TestWizardRepo {
  param([string]$Path)

  if (Test-Path $Path) {
    Remove-Item -Path $Path -Recurse -Force
  }
}

$testRepo = New-TestWizardRepo
try {
  $validation = Test-WizardBuildContract -RepoRoot $testRepo -ScenarioSlug 'test-scenario' -StrictMode $true
  if ($validation.Status -ne 'passed') {
    throw "Expected passed build contract validation, got '$($validation.Status)'."
  }

  $expected = New-WizardExpectedArtifacts -RepoRoot $testRepo -ScenarioSlug 'test-scenario' -PublisherPrefix 'tst'
  if ($expected.Tables -notcontains 'tst_agent') {
    throw 'Expected custom table in expected artifact set.'
  }

  $scan = New-WizardContaminationVerdict -CurrentComponents @(
    [pscustomobject]@{ Kind = 'table'; Name = 'tst_agent' },
    [pscustomobject]@{ Kind = 'table'; Name = 'contact' },
    [pscustomobject]@{ Kind = 'webresource'; Name = 'tst_reports/agent-performance.html' }
  ) -ExpectedArtifacts $expected -PublisherPrefix 'tst'
  if ($scan.Verdict -ne 'contaminated') {
    throw "Expected contaminated verdict, got '$($scan.Verdict)'."
  }

  $appConfig = Get-WizardAppModuleConfig -RepoRoot $testRepo -ScenarioSlug 'test-scenario' -PublisherPrefix 'tst'
  if (-not $appConfig.ValidationPassed) {
    throw 'Expected app module config validation to pass.'
  }
  if ($appConfig.ApplicationProfile -ne 'standalone-model-driven') {
    throw 'Expected standalone model-driven application profile.'
  }
  if ($appConfig.FormStrategy -ne 'create-new-forms') {
    throw 'Expected create-new-forms strategy.'
  }
  if ($appConfig.EntryPointTable -ne 'tst_agent') {
    throw 'Expected tst_agent as the entry-point table.'
  }
  if ($appConfig.LandingView -ne 'Active Agents') {
    throw 'Expected Active Agents as the landing view.'
  }
  if ($appConfig.ReviewAppMode -ne 'create-or-update') {
    throw 'Expected create-or-update review app mode.'
  }

  $existingApp = [pscustomobject]@{ appmoduleid = 'app-id'; uniquename = 'tst_review' }
  $existingSiteMap = [pscustomobject]@{ sitemapid = 'sitemap-id'; sitemapnameunique = 'tst_review_sitemap' }
  foreach ($rerun in 1..2) {
    if ((Get-WizardUpsertAction -ExistingItems @($existingApp)) -ne 'update') {
      throw "App rerun $rerun should update the deterministic existing app, not create a duplicate."
    }
    if ((Get-WizardUpsertAction -ExistingItems @($existingSiteMap)) -ne 'update') {
      throw "Sitemap rerun $rerun should update the deterministic existing sitemap, not create a duplicate."
    }
  }
  if ((Get-WizardUpsertAction -ExistingItems @()) -ne 'create') {
    throw 'A missing deterministic artifact should select create on the first run.'
  }

  Add-WizardArtifactManifestItem -RepoRoot $testRepo -ScenarioSlug 'test-scenario' -SolutionName 'TestSolution' -PublisherPrefix 'tst' -Kind 'table' -Name 'tst_agent' -Status 'created' -Step '20-build-tables.ps1' | Out-Null
  $manifest = Get-Content -Path (Join-Path $testRepo '.wizard-metrics/artifacts/manifest/generated-artifact-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if (@($manifest.items).Count -ne 1) {
    throw 'Expected one manifest item.'
  }

  Remove-Item -Path (Join-Path $testRepo 'specs/test-scenario/tasks.md') -Force
  $failedValidation = Test-WizardBuildContract -RepoRoot $testRepo -ScenarioSlug 'test-scenario' -StrictMode $true
  if ($failedValidation.Status -ne 'failed') {
    throw 'Expected contract validation to fail when tasks.md is missing.'
  }
}
finally {
  Remove-TestWizardRepo -Path $testRepo
}

Write-Host 'Wizard hardening checks passed.' -ForegroundColor Green