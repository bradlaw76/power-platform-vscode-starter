Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixturesRoot = Join-Path $repoRoot 'scripts/ci/fixtures'

function Assert-Condition {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function New-TestRepo {
  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('pp-wizard-reports-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
  Copy-Item -Path (Join-Path $repoRoot '*') -Destination $tempRoot -Recurse -Force
  return $tempRoot
}

function Enable-ScenarioReports {
  param([string]$RepoPath)

  $answersPath = Join-Path $RepoPath 'specs/contoso-case-tracker/answers.md'
  $content = Get-Content -Path $answersPath -Raw -Encoding UTF8
  if ($content -notmatch '(?ims)^##\s+Optional Report Web Resources\s*$') {
    $content = $content.TrimEnd() + "`r`n`r`n## Optional Report Web Resources`r`n- Enabled: yes`r`n- Selected Reports: all`r`n- Report Mode: live-with-design-fallback`r`n"
  }
  else {
    $content = [regex]::Replace($content, '(?ims)^##\s+Optional Report Web Resources\s*\r?\n(.*?)(?=^##\s+|\z)', "## Optional Report Web Resources`r`n- Enabled: yes`r`n- Selected Reports: all`r`n- Report Mode: live-with-design-fallback`r`n")
  }
  Set-Content -Path $answersPath -Value $content -Encoding UTF8
  $scenarioFolder = Split-Path $answersPath -Parent
  $requirement = 'Reports show case counts, documented priority distribution, and supervisor ownership distribution.'
  Add-Content -LiteralPath (Join-Path $scenarioFolder 'spec.md') -Value "`n## HTML Reporting Requirements`n$requirement"
  $reports = @(
    @{ Key = 'agent'; Level = 'frontline'; Title = 'Agent Case Activity'; Fields = @('cct_priority') },
    @{ Key = 'supervisor'; Level = 'supervisor'; Title = 'Supervisor Ownership'; Fields = @('cct_priority', 'ownerid') },
    @{ Key = 'executive-kpi'; Level = 'leadership'; Title = 'Leadership Case Distribution'; Fields = @('cct_priority') }
  )
  $definitions = @($reports | ForEach-Object {
    $metrics = @(@{ Key = 'total-cases'; Title = 'Total Cases'; Kind = 'aggregate-count'; RequiredFields = @('__primaryid__') })
    foreach ($field in $_.Fields) {
      $metrics += @{ Key = "by-$($field.Replace('_','-'))"; Title = "Cases by $field"; Kind = 'aggregate-group'; RequiredFields = @('__primaryid__', $field) }
    }
    @{
      Key = $_.Key; Level = $_.Level; Title = $_.Title; Audience = $_.Level
      Purpose = $requirement; Placement = 'Review app Reports group'; TableLogicalName = 'incident'
      Requirements = @(@{ Document = 'spec.md'; Excerpt = $requirement }); Metrics = $metrics
    }
  })
  @{ Version = '1.0'; Approved = $true; Reports = $definitions } | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $scenarioFolder 'html-reports.json')
  $mappingRows = @('| Table logical name | Report surface | Type | Target placement | Required fields | Business decision | Owner | Validation checklist |',
    '| --- | --- | --- | --- | --- | --- | --- | --- |')
  foreach ($report in $reports) {
    $mappingRows += "| incident | $($report.Title) | dashboard | Review app Reports group | $($report.Fields -join ', ') | Case oversight | $($report.Level) | Counts reconcile |"
  }
  Set-Content -LiteralPath (Join-Path $scenarioFolder 'report-mappings.md') -Value ($mappingRows -join "`n")
}

function Invoke-PreviewRun {
  param(
    [string]$RepoPath,
    [string]$SnapshotPath,
    [bool]$ExpectSuccess
  )

  $params = @{
    ScenarioSlug = 'contoso-case-tracker'
    PreviewReportQueriesOnly = $true
    MetadataSnapshotPath = $SnapshotPath
    ReportMode = 'live-with-design-fallback'
    EnableLiveDataverseReports = $true
    FailIfReportEntitiesMissing = $true
    FailIfReportFieldsMissing = $true
    IncludeDesignSummaryWhenNoData = $true
  }

  Push-Location $RepoPath
  try {
    & (Join-Path $RepoPath 'scripts/bootstrap/65-build-web-resources.ps1') @params
    $exitCode = $LASTEXITCODE
  }
  finally {
    Pop-Location
  }

  if ($ExpectSuccess) {
    Assert-Condition -Condition ($exitCode -eq 0) -Message "Expected preview run to succeed, but exit code was $exitCode."
  }
  else {
    Assert-Condition -Condition ($exitCode -ne 0) -Message 'Expected preview run to fail for missing field validation.'
  }
}

$tempRepos = New-Object System.Collections.Generic.List[string]

try {
  $sparseRepo = New-TestRepo
  $tempRepos.Add($sparseRepo)
  Enable-ScenarioReports -RepoPath $sparseRepo
  Invoke-PreviewRun -RepoPath $sparseRepo -SnapshotPath (Join-Path $fixturesRoot 'report-metadata-sparse.json') -ExpectSuccess $true

  $sparseValidationPath = Join-Path $sparseRepo 'specs/contoso-case-tracker/report-artifacts/report-validation.json'
  $sparseQueryPreviewPath = Join-Path $sparseRepo 'specs/contoso-case-tracker/report-artifacts/query-preview.json'
  $sparseHtmlPath = Join-Path $sparseRepo 'specs/contoso-case-tracker/webresources/contoso-case-tracker-agent-report.html'
  Assert-Condition -Condition (Test-Path $sparseValidationPath) -Message 'Expected sparse validation artifact to be generated.'
  Assert-Condition -Condition (Test-Path $sparseQueryPreviewPath) -Message 'Expected sparse query preview artifact to be generated.'
  Assert-Condition -Condition (Test-Path $sparseHtmlPath) -Message 'Expected sparse HTML report to be generated.'

  $sparseValidation = Get-Content -Path $sparseValidationPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
  Assert-Condition -Condition (@($sparseValidation.reports).Count -eq 3) -Message 'Expected three report validation entries in sparse mode.'
  Assert-Condition -Condition (@($sparseValidation.reports | Where-Object { $_.SeedDataStatus -eq 'planned-no-data' }).Count -eq 3) -Message 'Expected all sparse reports to detect planned-no-data state.'
  Assert-Condition -Condition ((Get-Content -Path $sparseHtmlPath -Raw -Encoding UTF8) -match 'No operational records yet') -Message 'Expected sparse HTML to contain a zero-state message.'

  $richRepo = New-TestRepo
  $tempRepos.Add($richRepo)
  Enable-ScenarioReports -RepoPath $richRepo
  Invoke-PreviewRun -RepoPath $richRepo -SnapshotPath (Join-Path $fixturesRoot 'report-metadata-rich.json') -ExpectSuccess $true

  $richValidationPath = Join-Path $richRepo 'specs/contoso-case-tracker/report-artifacts/report-validation.json'
  $richConfigPath = Join-Path $richRepo 'specs/contoso-case-tracker/report-artifacts/config/contoso-case-tracker-supervisor-report.config.json'
  $richHtmlPath = Join-Path $richRepo 'specs/contoso-case-tracker/webresources/contoso-case-tracker-supervisor-report.html'
  $richValidation = Get-Content -Path $richValidationPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
  $richConfig = Get-Content -Path $richConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20

  Assert-Condition -Condition (@($richValidation.reports | Where-Object { $_.SeedDataDetected -eq $true }).Count -eq 3) -Message 'Expected demo data detection for all rich reports.'
  Assert-Condition -Condition (@($richConfig.queries).Count -ge 2) -Message 'Expected rich report config to contain live queries.'
  Assert-Condition -Condition ((@($richConfig.metrics | Where-Object { $_.enabled -eq $true }).Count) -ge 2) -Message 'Expected rich report config to enable multiple metrics.'
  Assert-Condition -Condition ((Get-Content -Path $richHtmlPath -Raw -Encoding UTF8) -match 'retrieveMultipleRecords') -Message 'Expected generated rich HTML to use Dataverse runtime querying.'
  Assert-Condition -Condition ($richConfig.report.title -eq 'Supervisor Ownership') -Message 'HTML title must come from the approved definition.'
  Assert-Condition -Condition ($richConfig.report.requirements[0].Document -eq 'spec.md') -Message 'HTML config must retain its requirement source.'
  Assert-Condition -Condition (@($richConfig.metrics | Where-Object { $_.key -in @('queue-age', 'status-breakdown', 'recent-records') }).Count -eq 0) -Message 'Generator must not invent undocumented metrics.'

  . (Join-Path $repoRoot 'scripts\bootstrap\helpers\reporting-plan.ps1')
  $richScenarioFolder = Join-Path $richRepo 'specs\contoso-case-tracker'
  $definitionPath = Join-Path $richScenarioFolder 'html-reports.json'
  $approvedJson = Get-Content -LiteralPath $definitionPath -Raw
  foreach ($failureCase in @('unapproved', 'stale-source', 'outside-scenario', 'unmapped-field', 'duplicate-key', 'unmapped-placement')) {
    $invalid = $approvedJson | ConvertFrom-Json -Depth 20
    switch ($failureCase) {
      'unapproved' { $invalid.Approved = $false }
      'stale-source' { $invalid.Reports[0].Requirements[0].Excerpt = 'This requirement does not exist in the scenario.' }
      'outside-scenario' { $invalid.Reports[0].TableLogicalName = 'unrelated_table' }
      'unmapped-field' { $invalid.Reports[0].Metrics[1].RequiredFields[1] = 'unapproved_field' }
      'duplicate-key' { $invalid.Reports[1].Key = $invalid.Reports[0].Key }
      'unmapped-placement' { $invalid.Reports[0].Placement = 'Unapproved form tab' }
    }
    $invalid | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $definitionPath
    $rejected = $false
    try { Read-WizardHtmlReportPlan -RepoRoot $repoRoot -ScenarioFolder $richScenarioFolder | Out-Null } catch { $rejected = $true }
    Assert-Condition -Condition $rejected -Message "Expected '$failureCase' HTML plan rejection."
  }
  Set-Content -LiteralPath $definitionPath -Value $approvedJson

  Invoke-PreviewRun -RepoPath $richRepo -SnapshotPath (Join-Path $fixturesRoot 'report-metadata-rich.json') -ExpectSuccess $true
  $htmlFiles = @(Get-ChildItem -Path (Join-Path $richRepo 'specs/contoso-case-tracker/webresources') -Filter '*.html' -File)
  $configFiles = @(Get-ChildItem -Path (Join-Path $richRepo 'specs/contoso-case-tracker/report-artifacts/config') -Filter '*.json' -File)
  Assert-Condition -Condition ($htmlFiles.Count -eq 3) -Message 'Expected rerun to keep exactly three HTML report files.'
  Assert-Condition -Condition ($configFiles.Count -eq 3) -Message 'Expected rerun to keep exactly three report config files.'

  $customRepo = New-TestRepo
  $tempRepos.Add($customRepo)
  Enable-ScenarioReports -RepoPath $customRepo
  $customFolder = Join-Path $customRepo 'specs\contoso-case-tracker'
  $customSpecPath = Join-Path $customFolder 'spec.md'
  $customRequirement = 'Lab supervisors need checkout request counts by lifecycle stage.'
  $customSpec = (Get-Content -LiteralPath $customSpecPath -Raw).Replace('- Customer -> cct_customer', "- Customer -> cct_customer`n- Checkout Request -> lab_checkoutrequest")
  Set-Content -LiteralPath $customSpecPath -Value "$customSpec`n$customRequirement"
  $customPlan = Get-Content -LiteralPath (Join-Path $repoRoot 'schemas\examples\html-reports.example.json') -Raw | ConvertFrom-Json
  $customPlan.Approved = $true
  $customPlan.Reports[0].Requirements[0].Excerpt = $customRequirement
  $customPlan | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $customFolder 'html-reports.json')
  Set-Content -LiteralPath (Join-Path $customFolder 'report-mappings.md') -Value '| lab_checkoutrequest | Checkout Request Oversight | dashboard | Review app Reports group | lab_lifecyclestage | Lifecycle oversight | Lab supervisors | Counts reconcile |'
  $customSnapshot = Get-Content -LiteralPath (Join-Path $fixturesRoot 'report-metadata-rich.json') -Raw | ConvertFrom-Json
  $customSnapshot.entities += [pscustomobject]@{
    logicalName = 'lab_checkoutrequest'; displayName = 'Checkout Request'
    primaryIdAttribute = 'lab_checkoutrequestid'; primaryNameAttribute = 'lab_name'
    fields = @('lab_checkoutrequestid', 'lab_name', 'lab_lifecyclestage'); rowCount = 0
  }
  $customSnapshotPath = Join-Path $customFolder 'metadata-snapshot.json'
  $customSnapshot | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $customSnapshotPath
  Invoke-PreviewRun -RepoPath $customRepo -SnapshotPath $customSnapshotPath -ExpectSuccess $true
  $customHtml = @(Get-ChildItem -LiteralPath (Join-Path $customFolder 'webresources') -Filter '*.html')
  Assert-Condition -Condition ($customHtml.Count -eq 1) -Message 'A single approved report must not expand into a fixed trio.'
  $customConfig = Get-Content -LiteralPath (Join-Path $customFolder 'report-artifacts\config\contoso-case-tracker-supervisor-report.config.json') -Raw | ConvertFrom-Json
  Assert-Condition -Condition ($customConfig.report.title -eq 'Checkout Request Oversight') -Message 'Custom scenario title was not preserved.'
  Assert-Condition -Condition (@($customConfig.queries | Where-Object { $_.EntityLogicalName -ne 'lab_checkoutrequest' }).Count -eq 0) -Message 'Queries must target the approved report table, not a generic case table.'
  Assert-Condition -Condition ($customConfig.queries[1].FetchXml -match "groupby='true'.*lab_lifecyclestage|name='lab_lifecyclestage'.*groupby='true'") -Message 'Custom lifecycle metric must use the exact documented field.'
  Assert-Condition -Condition (-not $customConfig.fallbackBehavior.seedDataDetected) -Message 'Data in another scenario table must not imply records exist for this report.'

  $missingRepo = New-TestRepo
  $tempRepos.Add($missingRepo)
  Enable-ScenarioReports -RepoPath $missingRepo
  Invoke-PreviewRun -RepoPath $missingRepo -SnapshotPath (Join-Path $fixturesRoot 'report-metadata-missing-field.json') -ExpectSuccess $false

  Write-Host 'Live report generation checks passed.' -ForegroundColor Green
}
finally {
  foreach ($path in $tempRepos) {
    if (Test-Path $path) {
      Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

exit 0
