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
  $testManifestPath = (Get-WizardArtifactPaths -RepoRoot $testRepo -ScenarioSlug 'test-scenario').ManifestJsonPath
  $manifest = Get-WizardArtifactManifest -RepoRoot $testRepo -ScenarioSlug 'test-scenario' -SolutionName 'TestSolution' -PublisherPrefix 'tst'
  if (@($manifest.items).Count -ne 1) {
    throw 'Expected one manifest item.'
  }

  Add-WizardArtifactManifestItem -RepoRoot $testRepo -ScenarioSlug 'Second Scenario' -SolutionName 'SecondSolution' -PublisherPrefix 'snd' -Kind 'table' -Name 'snd_case' -Status 'created' -Step '20-build-tables.ps1' | Out-Null
  $secondManifestPath = (Get-WizardArtifactPaths -RepoRoot $testRepo -ScenarioSlug 'second-scenario').ManifestJsonPath
  if ($testManifestPath -eq $secondManifestPath -or -not (Test-Path $testManifestPath) -or -not (Test-Path $secondManifestPath)) {
    throw 'Two scenarios must use separate normalized manifest paths.'
  }
  $firstManifestAfterSecond = Get-WizardArtifactManifest -RepoRoot $testRepo -ScenarioSlug 'test-scenario' -SolutionName 'TestSolution' -PublisherPrefix 'tst'
  if (@($firstManifestAfterSecond.items).Count -ne 1 -or $firstManifestAfterSecond.items[0].name -ne 'tst_agent') {
    throw 'A second scenario overwrote the first scenario manifest.'
  }

  foreach ($mismatch in @(
      @{ Scenario = 'test-scenario'; Solution = 'GccSolution'; Prefix = 'tst'; Expected = 'solution identity' },
      @{ Scenario = 'test-scenario'; Solution = 'TestSolution'; Prefix = 'gcc'; Expected = 'publisher identity' }
    )) {
    try {
      Get-WizardArtifactManifest -RepoRoot $testRepo -ScenarioSlug $mismatch.Scenario -SolutionName $mismatch.Solution -PublisherPrefix $mismatch.Prefix | Out-Null
      throw "Expected $($mismatch.Expected) mismatch to stop manifest access."
    } catch {
      if ($_.Exception.Message -notmatch [regex]::Escape($mismatch.Expected)) { throw }
    }
  }
  if ($null -ne (Get-WizardArtifactManifest -RepoRoot $testRepo -ScenarioSlug 'gcc-framework-acceptance' -SolutionName 'GccSolution' -PublisherPrefix 'gcc' -AllowMissing)) {
    throw 'A Contoso manifest must not authorize GCC scenario components.'
  }

  Add-WizardArtifactManifestItem -RepoRoot $testRepo -ScenarioSlug 'test-scenario' -SolutionName 'TestSolution' -PublisherPrefix 'tst' -Kind 'column' -Name 'tst_agent.tst_region' -Status 'created' -Step '30-build-columns.ps1' | Out-Null
  $rerunManifest = Get-WizardArtifactManifest -RepoRoot $testRepo -ScenarioSlug 'test-scenario' -SolutionName 'TestSolution' -PublisherPrefix 'tst'
  if (@($rerunManifest.items).Count -ne 2 -or @($rerunManifest.items | Where-Object name -eq 'tst_agent').Count -ne 1) {
    throw 'Scenario reruns must preserve existing history while adding later-stage items.'
  }

  $legacyPaths = Get-WizardArtifactPaths -RepoRoot $testRepo -ScenarioSlug 'legacy-scenario'
  [ordered]@{ scenarioSlug = 'legacy-scenario'; solutionName = 'LegacySolution'; publisherPrefix = 'leg'; runId = 'legacy'; items = @() } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $legacyPaths.LegacyManifestJsonPath -Encoding UTF8
  if (Test-Path -LiteralPath $legacyPaths.ManifestJsonPath) { throw 'Legacy global manifest was silently migrated.' }
  if ($null -ne (Get-WizardArtifactManifest -RepoRoot $testRepo -ScenarioSlug 'legacy-scenario' -SolutionName 'LegacySolution' -PublisherPrefix 'leg' -AllowMissing)) {
    throw 'Legacy global manifest was silently used as scenario provenance.'
  }
  try {
    Move-WizardLegacyArtifactManifest -RepoRoot $testRepo -ScenarioSlug 'legacy-scenario' -SolutionName 'WrongSolution' -PublisherPrefix 'leg' | Out-Null
    throw 'Legacy migration must reject a mismatched solution identity.'
  } catch {
    if ($_.Exception.Message -notmatch 'solution identity') { throw }
  }
  Move-WizardLegacyArtifactManifest -RepoRoot $testRepo -ScenarioSlug 'legacy-scenario' -SolutionName 'LegacySolution' -PublisherPrefix 'leg' | Out-Null
  $migrated = Get-WizardArtifactManifest -RepoRoot $testRepo -ScenarioSlug 'legacy-scenario' -SolutionName 'LegacySolution' -PublisherPrefix 'leg'
  if ($migrated.scenarioSlug -ne 'legacy-scenario') { throw 'Explicit validated legacy migration failed.' }

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