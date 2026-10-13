Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$tables = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/20-build-tables.ps1') -Raw
$columns = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/30-build-columns.ps1') -Raw
$relationships = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/40-build-relationships.ps1') -Raw
$addToSolution = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/50-add-to-solution.ps1') -Raw
$businessProcessFlows = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/55-build-business-process-flows.ps1') -Raw
$solutionIsolation = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/helpers/solution-isolation.ps1') -Raw
$formsViews = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/60-build-forms-views.ps1') -Raw
$chartsDashboard = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/64-build-charts-dashboard.ps1') -Raw
$demoScriptWizard = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/06-demo-script-wizard.ps1') -Raw
$authConnect = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/10-auth-connect.ps1') -Raw

foreach ($sensitiveOutput in @('Signed in as:', '(?m)^\s*pac auth list\s*$')) {
  if ($authConnect -match $sensitiveOutput) {
    throw "Auth connect still prints sensitive account or PAC profile details: $sensitiveOutput"
  }
}

foreach ($required in @("Join-Path 'scenarios' `$Slug", 'Trim([char]96)', "publisher prefix must contain 3-8 lowercase letters", "customizationprefix eq")) {
  if ($authConnect -notmatch [regex]::Escape($required)) {
    throw "Auth connect environment verification appears incomplete: missing $required."
  }
}

foreach ($required in @('How long should the demo be, in minutes?', '$durationMinutes -lt 1', 'Duration minutes: $durationMinutes', 'Duration: $durationMinutes minutes')) {
  if ($demoScriptWizard -notmatch [regex]::Escape($required)) {
    throw "Demo script wizard duration intake appears incomplete: missing $required."
  }
}

foreach ($required in @('$entities = @(Split-Items', '$artifacts = @(Split-Items')) {
  if ($demoScriptWizard -notmatch [regex]::Escape($required)) {
    throw "Demo script wizard must preserve single-item parsing results as collections: missing $required."
  }
}

foreach ($required in @('Business Outcome And Audience', 'Application And Data Architecture', 'Primary success measure', 'Required App Artifacts')) {
  if ($demoScriptWizard -notmatch [regex]::Escape($required)) {
    throw "Demo script wizard does not support current advanced-builder planning headings: missing $required."
  }
}

foreach ($required in @('function Get-SentenceFragment', 'Get-SentenceFragment -Value $AudiencePersona', 'Get-SentenceFragment -Value $SuccessCriteria', 'address this need:')) {
  if ($demoScriptWizard -notmatch [regex]::Escape($required)) {
    throw "Demo script wizard does not normalize sentence fragments: missing $required."
  }
}

foreach ($required in @('helpers\dataverse-runtime.ps1', 'Invoke-WizardDataverseRequest', 'if (Test-Path $envFile)')) {
  if ($tables -notmatch [regex]::Escape($required)) {
    throw "Table build must use the shared resilient Dataverse runtime: missing $required."
  }
  if ($columns -notmatch [regex]::Escape($required)) {
    throw "Column build must use the shared resilient Dataverse runtime: missing $required."
  }
}

foreach ($required in @("if (-not `$PreviewOnly -and (Test-Path -LiteralPath `$envFile))", '$env:DV_SOLUTION_NAME', '$env:DV_PUBLISHER_PREFIX')) {
  if ($relationships -notmatch [regex]::Escape($required)) {
    throw "Relationship build must load provenance identities independently of credential parameters: missing $required."
  }
}

foreach ($required in @('helpers\dataverse-runtime.ps1', 'Invoke-WizardDataverseRequest', 'if (Test-Path $envFile)')) {
  if ($addToSolution -notmatch [regex]::Escape($required)) {
    throw "Add-to-solution must use resilient transport and load provenance identities independently of credential parameters: missing $required."
  }
  if ($businessProcessFlows -notmatch [regex]::Escape($required)) {
    throw "Business-process-flow integration must use resilient transport and load provenance identities independently of credential parameters: missing $required."
  }
}

foreach ($required in @("'columns-*.json'", "'relationships-*.json'", 'Test-SolutionComponentMembership', 'AddRequiredComponents = $false', '$expectedArtifacts.Tables', '[switch]$PublishScoped', '"PublishXml"')) {
  if ($addToSolution -notmatch [regex]::Escape($required)) {
    throw "Add-to-solution must explicitly synchronize only approved schema components: missing $required."
  }
}

if ($relationships -notmatch 'SchemaName\.Equals\(\$SchemaName') {
  throw 'Relationship existence check is missing an explicit returned-data SchemaName comparison.'
}

foreach ($required in @('ReferencedEntity', 'ReferencingEntity', 'Entity1LogicalName', 'Entity2LogicalName')) {
  if ($addToSolution -notmatch 'Get-PayloadEntityNames' -or $solutionIsolation -notmatch [regex]::Escape($required)) {
    throw "Payload-derived relationship entity lookup appears incomplete: missing $required."
  }
}

if ($formsViews -notmatch 'PrimaryIdAttribute') {
  throw 'Forms/views script does not query PrimaryIdAttribute.'
}

if ($formsViews -notmatch '\$resolvedPrimaryId') {
  throw 'Forms/views layout does not use resolved primary id field.'
}

foreach ($required in @('MinBusinessFieldsPerForm', 'MinBusinessColumnsPerView', 'IncludeOwnerOnForms', 'IncludeOwnerInViews', 'IncludeStatusInViews', 'PreferFormName', 'FailIfUnderpopulatedForms', 'FailIfUnderpopulatedViews', 'form-population-report.json', 'view-population-report.json', 'Get-ViewPopulationAnalysis', 'Generated by 60-build-forms-views.ps1')) {
  if ($formsViews -notmatch [regex]::Escape($required)) {
    throw "Forms/views hardening appears incomplete: missing $required."
  }
}

foreach ($required in @('helpers\dataverse-runtime.ps1', 'Invoke-WizardDataverseRequest', 'if (Test-Path $envFile)', "Exception.Message -match 'HTTP 404'")) {
  if ($formsViews -notmatch [regex]::Escape($required)) {
    throw "Forms/views resilient metadata lookup appears incomplete: missing $required."
  }
}

foreach ($required in @('helpers/dataverse-runtime.ps1', 'Invoke-WizardDataverseRequest', 'if (Test-Path -LiteralPath $envFile)', '$global:DV_SOLUTION_NAME', '$global:DV_PUBLISHER_PREFIX')) {
  if ($chartsDashboard -notmatch [regex]::Escape($required)) {
    throw "Charts/dashboard resilient runtime loading appears incomplete: missing $required."
  }
}

$bpfScript = Get-Content (Join-Path $repoRoot 'scripts/bootstrap/55-build-business-process-flows.ps1') -Raw
foreach ($required in @('EnableBusinessProcessFlow', 'BusinessProcessFlowName', 'PrimaryProcessEntity', 'FailIfBpfDefinitionIncomplete', 'PreferUpdateExistingBpf', 'business-process-flow-report.json', 'process-*.json')) {
  if ($bpfScript -notmatch [regex]::Escape($required)) {
    throw "BPF script appears incomplete: missing $required."
  }
}

$trackedScripts = @(& git -C $repoRoot ls-files --cached -- '*.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate tracked PowerShell scripts with Git.' }
$untrackedRepositoryScripts = @(& git -C $repoRoot ls-files --others --exclude-standard -- 'scripts/*.ps1' 'scripts/**/*.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate untracked repository PowerShell scripts with Git.' }
$repositoryScripts = @($trackedScripts + $untrackedRepositoryScripts | Sort-Object -Unique)
foreach ($relativeScriptPath in $repositoryScripts) {
  $scriptFile = Get-Item -LiteralPath (Join-Path $repoRoot $relativeScriptPath)
  $parseErrors = $null
  $parseTokens = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptFile.FullName,
    [ref]$parseTokens,
    [ref]$parseErrors
  ) | Out-Null
  if ($parseErrors.Count -gt 0) {
    throw "$relativeScriptPath has PowerShell parse errors: $(($parseErrors | ForEach-Object { $_.Message }) -join '; ')"
  }
}

Write-Host 'Script smoke checks passed.' -ForegroundColor Green
