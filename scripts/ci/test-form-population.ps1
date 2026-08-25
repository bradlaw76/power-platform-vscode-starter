Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sourceScript = Join-Path $repoRoot 'scripts/bootstrap/60-build-forms-views.ps1'
$sourceTelemetryHelper = Join-Path $repoRoot 'scripts/bootstrap/helpers/wizard-telemetry.ps1'

function New-TestRepo {
  $path = Join-Path ([System.IO.Path]::GetTempPath()) ("wizard-form-tests-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path (Join-Path $path 'scripts/bootstrap/helpers') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $path 'payloads') -Force | Out-Null
  Copy-Item -Path $sourceScript -Destination (Join-Path $path 'scripts/bootstrap/60-build-forms-views.ps1') -Force
  Copy-Item -Path $sourceTelemetryHelper -Destination (Join-Path $path 'scripts/bootstrap/helpers/wizard-telemetry.ps1') -Force
  return $path
}

function Write-TestPayloads {
  param(
    [string]$RepoPath,
    [string]$TableLogical,
    [array]$Columns
  )

  @"
{
  "EntityDefinition": {
    "SchemaName": "$TableLogical"
  }
}
"@ | Set-Content -Path (Join-Path $RepoPath 'payloads/table-test.json') -Encoding UTF8

  $columnPayload = [pscustomobject]@{
    TableLogicalName = $TableLogical
    Columns = @($Columns)
  }
  $columnPayload | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $RepoPath 'payloads/columns-test.json') -Encoding UTF8
}

function Write-TestColumnPayload {
  param(
    [string]$RepoPath,
    [string]$TableLogical,
    [array]$Columns
  )

  $columnPayload = [pscustomobject]@{
    TableLogicalName = $TableLogical
    Columns = @($Columns)
  }
  $columnPayload | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $RepoPath 'payloads/columns-test.json') -Encoding UTF8
}

function Write-TestScenario {
  param(
    [string]$RepoPath,
    [string]$ScenarioSlug,
    [string]$SpecContent,
    [string]$PlanContent = ''
  )

  $scenarioRoot = Join-Path $RepoPath "specs/$ScenarioSlug"
  New-Item -ItemType Directory -Path $scenarioRoot -Force | Out-Null
  'placeholder answers' | Set-Content -Path (Join-Path $scenarioRoot 'answers.md') -Encoding UTF8
  $SpecContent | Set-Content -Path (Join-Path $scenarioRoot 'spec.md') -Encoding UTF8
  $PlanContent | Set-Content -Path (Join-Path $scenarioRoot 'plan.md') -Encoding UTF8
}

function New-Attribute {
  param(
    [string]$LogicalName,
    [string]$Label,
    [string]$AttributeType = 'String',
    [bool]$IsPrimaryId = $false,
    [bool]$IsPrimaryName = $false,
    [bool]$IsValidForForm = $true
  )

  return [pscustomobject]@{
    LogicalName = $LogicalName
    AttributeType = $AttributeType
    IsPrimaryId = $IsPrimaryId
    IsPrimaryName = $IsPrimaryName
    IsValidForForm = $IsValidForForm
    DisplayName = [pscustomobject]@{
      LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = $Label })
    }
  }
}

function New-MockContext {
  param(
    [string]$TableLogical,
    [string]$PrimaryField,
    [string]$PrimaryIdField,
    [array]$Attributes
  )

  return [pscustomobject]@{
    Table = [pscustomobject]@{
      LogicalName = $TableLogical
      PrimaryNameAttribute = $PrimaryField
      PrimaryIdAttribute = $PrimaryIdField
      IsCustomEntity = $true
    }
    Attributes = @($Attributes)
    Forms = New-Object System.Collections.Generic.List[object]
    Views = New-Object System.Collections.Generic.List[object]
    Requests = New-Object System.Collections.Generic.List[object]
  }
}

function Get-MockPath {
  param([string]$Uri)

  $marker = '/api/data/v9.2/'
  $index = $Uri.IndexOf($marker, [System.StringComparison]::OrdinalIgnoreCase)
  if ($index -lt 0) {
    throw "Unexpected Dataverse URI: $Uri"
  }

  return $Uri.Substring($index + $marker.Length)
}

function Get-FormFieldNames {
  param([string]$FormXml)

  [xml]$document = $FormXml
  $fields = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($control in @($document.SelectNodes('//control[@datafieldname]'))) {
    [void]$fields.Add($control.GetAttribute('datafieldname'))
  }
  return @($fields)
}

function Get-ViewFieldNamesFromLayoutXml {
  param([string]$LayoutXml)

  [xml]$document = $LayoutXml
  $fields = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($cell in @($document.SelectNodes('//cell[@name]'))) {
    [void]$fields.Add($cell.GetAttribute('name'))
  }
  return @($fields)
}

function Get-ViewFieldNamesFromFetchXml {
  param([string]$FetchXml)

  [xml]$document = $FetchXml
  $fields = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($attribute in @($document.SelectNodes('//entity/attribute[@name]'))) {
    [void]$fields.Add($attribute.GetAttribute('name'))
  }
  return @($fields)
}

function Assert-Condition {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
}

function Invoke-RestMethod {
  param(
    [string]$Method,
    [string]$Uri,
    $Headers,
    [string]$Body
  )

  $path = Get-MockPath -Uri $Uri
  $script:MockContext.Requests.Add([pscustomobject]@{ Method = $Method; Path = $path; Body = $Body }) | Out-Null

  if (($Method -eq 'Get') -and ($path -like "EntityDefinitions(LogicalName='*')/Attributes?*")) {
    return [pscustomobject]@{ value = @($script:MockContext.Attributes) }
  }

  if (($Method -eq 'Get') -and ($path -like "EntityDefinitions(LogicalName='*')/Attributes(LogicalName='*')?*")) {
    if ($path -match "Attributes\(LogicalName='([^']+)'\)") {
      $logicalName = $Matches[1]
      return @($script:MockContext.Attributes | Where-Object { $_.LogicalName -eq $logicalName } | Select-Object -First 1)[0]
    }
  }

  if (($Method -eq 'Get') -and ($path -match "^EntityDefinitions\(LogicalName='[^']+'\)\?")) {
    return $script:MockContext.Table
  }

  if (($Method -eq 'Get') -and ($path -like 'systemforms?*')) {
    return [pscustomobject]@{ value = @($script:MockContext.Forms.ToArray()) }
  }

  if (($Method -eq 'Post') -and ($path -eq 'systemforms')) {
    $payload = $Body | ConvertFrom-Json
    $form = [pscustomobject]@{
      formid = [guid]::NewGuid().ToString()
      name = $payload.name
      type = $payload.type
      formxml = $payload.formxml
    }
    $script:MockContext.Forms.Add($form) | Out-Null
    return $form
  }

  if (($Method -eq 'Patch') -and ($path -match '^systemforms\(([^)]+)\)$')) {
    $formId = $Matches[1]
    $payload = $Body | ConvertFrom-Json
    $form = @($script:MockContext.Forms | Where-Object { $_.formid -eq $formId } | Select-Object -First 1)[0]
    $form.formxml = $payload.formxml
    return $form
  }

  if (($Method -eq 'Get') -and ($path -like 'savedqueries?*')) {
    return [pscustomobject]@{ value = @($script:MockContext.Views.ToArray()) }
  }

  if (($Method -eq 'Post') -and ($path -eq 'savedqueries')) {
    $payload = $Body | ConvertFrom-Json
    $view = [pscustomobject]@{
      savedqueryid = [guid]::NewGuid().ToString()
      name = $payload.name
      description = $payload.description
      fetchxml = $payload.fetchxml
      layoutxml = $payload.layoutxml
    }
    $script:MockContext.Views.Add($view) | Out-Null
    return $view
  }

  if (($Method -eq 'Patch') -and ($path -match '^savedqueries\(([^)]+)\)$')) {
    $viewId = $Matches[1].Trim()
    $payload = $Body | ConvertFrom-Json
    $view = @($script:MockContext.Views | Where-Object { $_.savedqueryid -eq $viewId } | Select-Object -First 1)[0]
    $view.name = $payload.name
    $view.description = $payload.description
    $view.fetchxml = $payload.fetchxml
    $view.layoutxml = $payload.layoutxml
    return $view
  }

  if (($Method -eq 'Post') -and ($path -eq 'PublishAllXml')) {
    return [pscustomobject]@{}
  }

  throw "Unhandled mock request: $Method $path"
}

$originalSkipMain = [Environment]::GetEnvironmentVariable('WIZARD_FORMS_VIEWS_SKIP_MAIN')
[Environment]::SetEnvironmentVariable('WIZARD_FORMS_VIEWS_SKIP_MAIN', 'true')

try {
  $richRepo = New-TestRepo
  Write-TestPayloads -RepoPath $richRepo -TableLogical 'tst_case' -Columns @(
    [pscustomobject]@{ LogicalName = 'tst_name'; DisplayName = [pscustomobject]@{ LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = 'Case Name' }) } },
    [pscustomobject]@{ LogicalName = 'tst_description'; DisplayName = [pscustomobject]@{ LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = 'Description' }) } },
    [pscustomobject]@{ LogicalName = 'tst_priority'; DisplayName = [pscustomobject]@{ LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = 'Priority' }) } },
    [pscustomobject]@{ LogicalName = 'tst_category'; DisplayName = [pscustomobject]@{ LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = 'Category' }) } },
    [pscustomobject]@{ LogicalName = 'ownerid'; DisplayName = [pscustomobject]@{ LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = 'Owner' }) } }
  )
  Write-TestScenario -RepoPath $richRepo -ScenarioSlug 'case-scenario' -SpecContent @"
# spec.md

## Required Experience and Artifacts
- Active records view should surface description, priority, category, region, owner, and status for queue review.
- Missing expected field reference: tst_case.tst_missingqueue
"@

  $script:MockContext = New-MockContext -TableLogical 'tst_case' -PrimaryField 'tst_name' -PrimaryIdField 'tst_caseid' -Attributes @(
    (New-Attribute -LogicalName 'tst_caseid' -Label 'Case' -AttributeType 'Uniqueidentifier' -IsPrimaryId $true),
    (New-Attribute -LogicalName 'tst_name' -Label 'Case Name' -IsPrimaryName $true),
    (New-Attribute -LogicalName 'tst_description' -Label 'Description'),
    (New-Attribute -LogicalName 'tst_priority' -Label 'Priority'),
    (New-Attribute -LogicalName 'tst_category' -Label 'Category'),
    (New-Attribute -LogicalName 'tst_region' -Label 'Region'),
    (New-Attribute -LogicalName 'statuscode' -Label 'Status' -AttributeType 'Picklist'),
    (New-Attribute -LogicalName 'ownerid' -Label 'Owner' -AttributeType 'Lookup'),
    (New-Attribute -LogicalName 'createdon' -Label 'Created On' -AttributeType 'DateTime')
  )

  . (Join-Path $richRepo 'scripts/bootstrap/60-build-forms-views.ps1')

  $firstRunExitCode = Invoke-WizardFormsViewsBuild -EnvironmentUrl 'https://mock.crm.dynamics.com' -AccessToken 'token' -PublisherPrefix 'tst' -PayloadsFolder (Join-Path $richRepo 'payloads') -MinBusinessFieldsPerForm 4 -MinBusinessColumnsPerView 4 -IncludeOwnerOnForms $true -IncludeOwnerInViews $true -IncludeStatusInViews $true -PreferFormName 'Starter Main Form' -FailIfUnderpopulatedForms $true -FailIfUnderpopulatedViews $true
  Assert-Condition -Condition ($firstRunExitCode -eq 0) -Message 'Expected populated form scenario to succeed.'
  Assert-Condition -Condition ($script:MockContext.Forms.Count -eq 1) -Message 'Expected one Main form to be created.'
  Assert-Condition -Condition ($script:MockContext.Views.Count -eq 1) -Message 'Expected one working view to be created.'

  $createdFields = @(Get-FormFieldNames -FormXml $script:MockContext.Forms[0].formxml)
  foreach ($expectedField in @('tst_name', 'tst_description', 'tst_priority', 'tst_category', 'tst_region', 'ownerid')) {
    Assert-Condition -Condition ($createdFields -contains $expectedField) -Message "Expected field $expectedField to be placed on the form."
  }

  $viewLayoutFields = @(Get-ViewFieldNamesFromLayoutXml -LayoutXml $script:MockContext.Views[0].layoutxml)
  $viewFetchFields = @(Get-ViewFieldNamesFromFetchXml -FetchXml $script:MockContext.Views[0].fetchxml)
  foreach ($expectedField in @('tst_name', 'tst_description', 'tst_priority', 'tst_category', 'tst_region', 'statuscode', 'ownerid')) {
    Assert-Condition -Condition ($viewLayoutFields -contains $expectedField) -Message "Expected view layout field $expectedField to be placed on the view."
    Assert-Condition -Condition ($viewFetchFields -contains $expectedField) -Message "Expected view fetch field $expectedField to be placed on the view."
  }

  $formPostCountAfterFirstRun = @($script:MockContext.Requests | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'systemforms' }).Count
  $formPatchCountAfterFirstRun = @($script:MockContext.Requests | Where-Object { $_.Method -eq 'Patch' -and $_.Path -like 'systemforms(*' }).Count
  $viewPostCountAfterFirstRun = @($script:MockContext.Requests | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'savedqueries' }).Count
  $viewPatchCountAfterFirstRun = @($script:MockContext.Requests | Where-Object { $_.Method -eq 'Patch' -and $_.Path -like 'savedqueries(*' }).Count

  $secondRunExitCode = Invoke-WizardFormsViewsBuild -EnvironmentUrl 'https://mock.crm.dynamics.com' -AccessToken 'token' -PublisherPrefix 'tst' -PayloadsFolder (Join-Path $richRepo 'payloads') -MinBusinessFieldsPerForm 4 -MinBusinessColumnsPerView 4 -IncludeOwnerOnForms $true -IncludeOwnerInViews $true -IncludeStatusInViews $true -PreferFormName 'Starter Main Form' -FailIfUnderpopulatedForms $true -FailIfUnderpopulatedViews $true
  Assert-Condition -Condition ($secondRunExitCode -eq 0) -Message 'Expected rerun to remain successful.'

  $formPostCountAfterSecondRun = @($script:MockContext.Requests | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'systemforms' }).Count
  $formPatchCountAfterSecondRun = @($script:MockContext.Requests | Where-Object { $_.Method -eq 'Patch' -and $_.Path -like 'systemforms(*' }).Count
  $viewPostCountAfterSecondRun = @($script:MockContext.Requests | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'savedqueries' }).Count
  $viewPatchCountAfterSecondRun = @($script:MockContext.Requests | Where-Object { $_.Method -eq 'Patch' -and $_.Path -like 'savedqueries(*' }).Count
  Assert-Condition -Condition ($formPostCountAfterSecondRun -eq $formPostCountAfterFirstRun) -Message 'Rerun should not create duplicate forms.'
  Assert-Condition -Condition ($formPatchCountAfterSecondRun -eq $formPatchCountAfterFirstRun) -Message 'Rerun should not add duplicate controls.'
  Assert-Condition -Condition ($viewPostCountAfterSecondRun -eq $viewPostCountAfterFirstRun) -Message 'Rerun should not create duplicate views.'
  Assert-Condition -Condition ($viewPatchCountAfterSecondRun -eq $viewPatchCountAfterFirstRun) -Message 'Rerun should not add duplicate view columns.'

  $reportPath = Join-Path $richRepo '.wizard-metrics/artifacts/forms/form-population-report.json'
  Assert-Condition -Condition (Test-Path $reportPath) -Message 'Expected form population report artifact to be generated.'
  $report = Get-Content -Path $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Condition -Condition ($report.tables.Count -eq 1) -Message 'Expected one table in the report.'
  Assert-Condition -Condition ($report.tables[0].businessFieldsPlaced -eq 4) -Message 'Expected report to record four business fields placed.'
  Assert-Condition -Condition (@($report.tables[0].missingExpectedFields).Count -eq 0) -Message 'Expected no missing expected fields in the populated scenario.'

  $viewReportPath = Join-Path $richRepo '.wizard-metrics/artifacts/views/view-population-report.json'
  Assert-Condition -Condition (Test-Path $viewReportPath) -Message 'Expected view population report artifact to be generated.'
  $viewReport = Get-Content -Path $viewReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Condition -Condition ($viewReport.tables.Count -eq 1) -Message 'Expected one table in the view report.'
  Assert-Condition -Condition ($viewReport.tables[0].businessColumnCount -eq 4) -Message 'Expected four business columns on the view.'
  Assert-Condition -Condition (@($viewReport.tables[0].missingExpectedColumns) -contains 'tst_missingqueue') -Message 'Expected missing scenario field to be reported for the view.'
  Assert-Condition -Condition (((@($viewReport.tables[0].columnsPlaced) | Sort-Object) -join ',') -eq ((@($viewLayoutFields) | Sort-Object) -join ',')) -Message 'Expected view report columns to match the actual layout.'

  $sparseRepo = New-TestRepo
  Write-TestPayloads -RepoPath $sparseRepo -TableLogical 'tst_sparse' -Columns @(
    [pscustomobject]@{ LogicalName = 'tst_name'; DisplayName = [pscustomobject]@{ LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = 'Sparse Name' }) } },
    [pscustomobject]@{ LogicalName = 'tst_flag'; DisplayName = [pscustomobject]@{ LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = 'Flag' }) } }
  )
  Write-TestScenario -RepoPath $sparseRepo -ScenarioSlug 'sparse-scenario' -SpecContent @"
# spec.md

## Required Experience and Artifacts
- Sparse queue review view should include flag, status, owner, escalation, and review outcome.
"@

  $script:MockContext = New-MockContext -TableLogical 'tst_sparse' -PrimaryField 'tst_name' -PrimaryIdField 'tst_sparseid' -Attributes @(
    (New-Attribute -LogicalName 'tst_sparseid' -Label 'Sparse' -AttributeType 'Uniqueidentifier' -IsPrimaryId $true),
    (New-Attribute -LogicalName 'tst_name' -Label 'Sparse Name' -IsPrimaryName $true),
    (New-Attribute -LogicalName 'tst_flag' -Label 'Flag'),
    (New-Attribute -LogicalName 'statuscode' -Label 'Status' -AttributeType 'Picklist'),
    (New-Attribute -LogicalName 'createdon' -Label 'Created On' -AttributeType 'DateTime'),
    (New-Attribute -LogicalName 'ownerid' -Label 'Owner' -AttributeType 'Lookup')
  )

  . (Join-Path $sparseRepo 'scripts/bootstrap/60-build-forms-views.ps1')
  $failureExitCode = Invoke-WizardFormsViewsBuild -EnvironmentUrl 'https://mock.crm.dynamics.com' -AccessToken 'token' -PublisherPrefix 'tst' -PayloadsFolder (Join-Path $sparseRepo 'payloads') -MinBusinessFieldsPerForm 4 -MinBusinessColumnsPerView 4 -IncludeOwnerOnForms $false -IncludeOwnerInViews $false -IncludeStatusInViews $false -PreferFormName 'Information' -FailIfUnderpopulatedForms $true -FailIfUnderpopulatedViews $true
  Assert-Condition -Condition ($failureExitCode -eq 1) -Message 'Expected under-populated form scenario to fail.'

  $failureReportPath = Join-Path $sparseRepo '.wizard-metrics/artifacts/forms/form-population-report.json'
  Assert-Condition -Condition (Test-Path $failureReportPath) -Message 'Expected report artifact even when validation fails.'
  $failureReport = Get-Content -Path $failureReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Condition -Condition ($failureReport.tables[0].underpopulated -eq $true) -Message 'Expected report to mark the sparse form as under-populated.'

  $failureViewReportPath = Join-Path $sparseRepo '.wizard-metrics/artifacts/views/view-population-report.json'
  Assert-Condition -Condition (Test-Path $failureViewReportPath) -Message 'Expected sparse view report artifact even when validation fails.'
  $failureViewReport = Get-Content -Path $failureViewReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-Condition -Condition ($failureViewReport.tables[0].underpopulated -eq $true) -Message 'Expected sparse view report to mark the view as under-populated.'

  $mixedRepo = New-TestRepo
  Write-TestColumnPayload -RepoPath $mixedRepo -TableLogical 'account' -Columns @(
    [pscustomobject]@{ LogicalName = 'tst_segment'; DisplayName = [pscustomobject]@{ LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = 'Segment' }) } }
  )
  Write-TestScenario -RepoPath $mixedRepo -ScenarioSlug 'mixed-scenario' -SpecContent '# mixed standard-table extension'

  $script:MockContext = New-MockContext -TableLogical 'account' -PrimaryField 'name' -PrimaryIdField 'accountid' -Attributes @(
    (New-Attribute -LogicalName 'accountid' -Label 'Account' -AttributeType 'Uniqueidentifier' -IsPrimaryId $true),
    (New-Attribute -LogicalName 'name' -Label 'Account Name' -IsPrimaryName $true),
    (New-Attribute -LogicalName 'tst_segment' -Label 'Segment'),
    (New-Attribute -LogicalName 'description' -Label 'Description'),
    (New-Attribute -LogicalName 'telephone1' -Label 'Main Phone'),
    (New-Attribute -LogicalName 'websiteurl' -Label 'Website'),
    (New-Attribute -LogicalName 'statuscode' -Label 'Status' -AttributeType 'Picklist')
  )
  $script:MockContext.Table.IsCustomEntity = $false
  $existingFormXml = '<form><tabs><tab name="general"><columns><column><sections><section name="general_section"><rows><row><cell><control id="name" datafieldname="name" /></cell></row></rows></section></sections></column></columns></tab></tabs></form>'
  $script:MockContext.Forms.Add([pscustomobject]@{ formid = [guid]::NewGuid().ToString(); name = 'Information'; type = 2; formxml = $existingFormXml }) | Out-Null

  . (Join-Path $mixedRepo 'scripts/bootstrap/60-build-forms-views.ps1')
  $mixedExitCode = Invoke-WizardFormsViewsBuild -EnvironmentUrl 'https://mock.crm.dynamics.com' -AccessToken 'token' -PublisherPrefix 'tst' -PayloadsFolder (Join-Path $mixedRepo 'payloads') -ScenarioSlug 'mixed-scenario' -MinBusinessFieldsPerForm 1 -MinBusinessColumnsPerView 1 -IncludeOwnerOnForms $false -IncludeOwnerInViews $false -IncludeStatusInViews $true -PreferFormName 'Starter Main Form' -FormStrategy 'create-new-forms' -FailIfUnderpopulatedForms $true -FailIfUnderpopulatedViews $true
  Assert-Condition -Condition ($mixedExitCode -eq 0) -Message 'Expected mixed standard-table extension to succeed.'
  Assert-Condition -Condition ($script:MockContext.Forms.Count -eq 2) -Message 'Expected a new wizard form alongside the existing Information form.'
  Assert-Condition -Condition ($script:MockContext.Forms[0].formxml -eq $existingFormXml) -Message 'Expected the existing Information form to remain unchanged.'
  Assert-Condition -Condition (@($script:MockContext.Forms | Where-Object { $_.name -eq 'Starter Main Form' }).Count -eq 1) -Message 'Expected one Starter Main Form for the standard table.'

  Write-Host 'Form population tests passed.' -ForegroundColor Green
}
finally {
  [Environment]::SetEnvironmentVariable('WIZARD_FORMS_VIEWS_SKIP_MAIN', $originalSkipMain)
}

exit 0