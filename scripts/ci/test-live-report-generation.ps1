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

  Invoke-PreviewRun -RepoPath $richRepo -SnapshotPath (Join-Path $fixturesRoot 'report-metadata-rich.json') -ExpectSuccess $true
  $htmlFiles = @(Get-ChildItem -Path (Join-Path $richRepo 'specs/contoso-case-tracker/webresources') -Filter '*.html' -File)
  $configFiles = @(Get-ChildItem -Path (Join-Path $richRepo 'specs/contoso-case-tracker/report-artifacts/config') -Filter '*.json' -File)
  Assert-Condition -Condition ($htmlFiles.Count -eq 3) -Message 'Expected rerun to keep exactly three HTML report files.'
  Assert-Condition -Condition ($configFiles.Count -eq 3) -Message 'Expected rerun to keep exactly three report config files.'

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
