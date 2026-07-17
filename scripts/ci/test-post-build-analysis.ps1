Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scriptPath = Join-Path $repoRoot 'scripts/bootstrap/80-post-build-analysis.ps1'

if (-not (Test-Path $scriptPath)) {
  throw 'Missing script under test: scripts/bootstrap/80-post-build-analysis.ps1'
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("post-build-analysis-test-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
  $specPath = Join-Path $tempRoot 'spec.md'
  $planPath = Join-Path $tempRoot 'plan.md'
  $tasksPath = Join-Path $tempRoot 'tasks.md'
  $payloadRoot = Join-Path $tempRoot 'payloads'
  $readmePath = Join-Path $tempRoot 'README.md'

  New-Item -ItemType Directory -Path $payloadRoot -Force | Out-Null

  @"
# Spec

## Scenario Summary
Unit test scenario summary.

### Standard reused tables (display -> logical)
- Contact -> contact

### Custom tables to create (input -> generated logical)
- Account Notes -> tst_accountnote

### Relationships to create
- tst_accountnote (referencing) -> contact (referenced)

## Required Experience and Artifacts
Main form, active view
"@ | Set-Content -Path $specPath -Encoding UTF8

  @"
# Plan

- Environment: https://example.crm.dynamics.com
- Solution type: Unmanaged
- Solution unique name: UnitTestSolution
- Publisher prefix: tst
"@ | Set-Content -Path $planPath -Encoding UTF8

  @"
# Tasks

- [ ] Validate artifacts in Maker portal
- [ ] Optional report follow-up
"@ | Set-Content -Path $tasksPath -Encoding UTF8

  @"
{
  "EntityDefinition": {
    "SchemaName": "tst_accountnote"
  }
}
"@ | Set-Content -Path (Join-Path $payloadRoot 'table-tst_accountnote.json') -Encoding UTF8

  @"
{
  "TableLogicalName": "contact",
  "Columns": [
    {
      "LogicalName": "tst_priority"
    }
  ]
}
"@ | Set-Content -Path (Join-Path $payloadRoot 'columns-contact.json') -Encoding UTF8

  @"
{
  "Relationships": [
    {
      "RelationshipDefinition": {
        "SchemaName": "tst_contact_tst_accountnote",
        "ReferencingEntity": "tst_accountnote",
        "ReferencingAttribute": "tst_contactid",
        "ReferencedEntity": "contact"
      }
    }
  ]
}
"@ | Set-Content -Path (Join-Path $payloadRoot 'relationships-main.json') -Encoding UTF8

  @"
{
  "Name": "tst_summary.html"
}
"@ | Set-Content -Path (Join-Path $payloadRoot 'webresource-summary.json') -Encoding UTF8

  @"
# Temporary README

Line before marker.
BEGIN GENERATED BUILD SUMMARY
old summary value
END GENERATED BUILD SUMMARY
Line after marker.
"@ | Set-Content -Path $readmePath -Encoding UTF8

  $hashBeforePreview = (Get-FileHash -Path $readmePath -Algorithm SHA256).Hash

  & pwsh -NoProfile -File $scriptPath `
    -ScenarioSlug 'unit-test-scenario' `
    -SpecPath $specPath `
    -PlanPath $planPath `
    -TasksPath $tasksPath `
    -PayloadFolder $payloadRoot `
    -ReadmePath $readmePath `
    -PreviewOnly

  if ($LASTEXITCODE -ne 0) {
    throw 'PreviewOnly execution failed for post-build analysis script.'
  }

  $hashAfterPreview = (Get-FileHash -Path $readmePath -Algorithm SHA256).Hash
  if ($hashBeforePreview -ne $hashAfterPreview) {
    throw 'PreviewOnly mode modified README. Expected no file writes.'
  }

  $answers = "y`nn`n"
  $answers | & pwsh -NoProfile -File $scriptPath `
    -ScenarioSlug 'unit-test-scenario' `
    -SpecPath $specPath `
    -PlanPath $planPath `
    -TasksPath $tasksPath `
    -PayloadFolder $payloadRoot `
    -ReadmePath $readmePath

  if ($LASTEXITCODE -ne 0) {
    throw 'Interactive README update execution failed for post-build analysis script.'
  }

  $updatedReadme = Get-Content -Path $readmePath -Raw
  if ($updatedReadme -notmatch 'BEGIN GENERATED BUILD SUMMARY') {
    throw 'Updated README is missing begin marker.'
  }
  if ($updatedReadme -notmatch 'END GENERATED BUILD SUMMARY') {
    throw 'Updated README is missing end marker.'
  }
  if ($updatedReadme -notmatch [regex]::Escape('Line before marker.')) {
    throw 'README content before marker was unexpectedly modified.'
  }
  if ($updatedReadme -notmatch [regex]::Escape('Line after marker.')) {
    throw 'README content after marker was unexpectedly modified.'
  }
  if ($updatedReadme -match [regex]::Escape('old summary value')) {
    throw 'Old generated summary content was not replaced.'
  }
  if ($updatedReadme -notmatch [regex]::Escape('### Scenario and solution metadata')) {
    throw 'Generated summary heading was not written into README markers.'
  }
  if ($updatedReadme -notmatch [regex]::Escape('- Scenario slug: unit-test-scenario')) {
    throw 'Generated summary metadata did not include the provided scenario slug.'
  }
  if ($updatedReadme -notmatch [regex]::Escape('### Recommended next enhancements')) {
    throw 'Generated summary did not include recommended next enhancements section.'
  }

  Write-Host 'Post-build analysis tests passed.' -ForegroundColor Green
}
finally {
  if (Test-Path $tempRoot) {
    Remove-Item -Path $tempRoot -Recurse -Force
  }
}