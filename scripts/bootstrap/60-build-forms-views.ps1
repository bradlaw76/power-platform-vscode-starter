<#
=============================================================================
COMPONENT:    Build Forms Views
FILE:         scripts/bootstrap/60-build-forms-views.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API | Model-Driven App Metadata

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Builds starter forms and views for approved scenario tables so users can work
with generated metadata inside the model-driven experience.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          scenario mapping, existing tables, and form/view design data
- Outputs:         created or updated forms/views and build artifacts
- Dependencies:    Dataverse Web API, planning files, repo helpers
- Side Effects:    mutates app metadata and writes local artifacts/telemetry

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Required tables and fields must already exist.
2. Form/view scope must align with the approved scenario design.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Starter forms and views are created for scoped tables.
✔ Population logic respects explicit mapping and scenario isolation.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Do not create artifacts for out-of-scope tables.
- Keep generated forms and views aligned with scenario mappings.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
  Creates or updates a payload-driven Main form and Active view for every
  custom table in the table payload set. Publishes customizations when done.

.PARAMETER EnvironmentUrl   Defaults to $env:DV_ENVIRONMENT_URL.
.PARAMETER AccessToken      Defaults to $env:DV_TOKEN.
.PARAMETER PublisherPrefix  Defaults to $env:DV_PUBLISHER_PREFIX.
.PARAMETER MinBusinessFieldsPerForm
  Minimum number of business fields required on each target form, excluding
  the primary name and optional owner control.
.PARAMETER MinBusinessColumnsPerView
  Minimum number of business columns required on each target view, excluding
  the primary name and optional metadata tail columns.
.PARAMETER IncludeOwnerOnForms
  Adds ownerid as a trailing metadata field when the attribute exists.
.PARAMETER IncludeOwnerInViews
  Adds ownerid as a trailing metadata column when the attribute exists.
.PARAMETER IncludeStatusInViews
  Adds statuscode as a trailing metadata column when the attribute exists.
.PARAMETER PreferFormName
  Target Main form name to create/update. Supported values: Starter Main Form,
  Information.
.PARAMETER FailIfUnderpopulatedForms
  Fails the step if a target form contains fewer business fields than the
  configured minimum after the merge completes.
.PARAMETER FailIfUnderpopulatedViews
  Fails the step if a target view contains fewer business columns than the
  configured minimum after the merge completes.
.PARAMETER ScenarioSlug
  Scenario folder under specs/. If omitted and there is exactly one scenario,
  that scenario is used automatically for view field prioritization.

.EXAMPLE
    pwsh ./scripts/bootstrap/60-build-forms-views.ps1
#>

param(
  [string]$EnvironmentUrl  = $env:DV_ENVIRONMENT_URL,
  [string]$AccessToken     = $env:DV_TOKEN,
  [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
  [string]$PayloadsFolder  = '',
  [string]$ScenarioSlug = '',
  [int]$MinBusinessFieldsPerForm = 4,
  [int]$MinBusinessColumnsPerView = 4,
  [bool]$IncludeOwnerOnForms = $false,
  [bool]$IncludeOwnerInViews = $false,
  [bool]$IncludeStatusInViews = $true,
  [ValidateSet('Starter Main Form', 'Information')]
  [string]$PreferFormName = 'Starter Main Form',
  [ValidateSet('auto', 'create-new-forms', 'update-in-place')]
  [string]$FormStrategy = 'auto',
  [bool]$FailIfUnderpopulatedForms = $true,
  [bool]$FailIfUnderpopulatedViews = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot 'helpers\wizard-telemetry.ps1'
if (Test-Path $telemetryHelper) {
  . $telemetryHelper
  Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName '60-build-forms-views.ps1'
}

$hardeningHelper = Join-Path $PSScriptRoot 'helpers\wizard-hardening.ps1'
if (Test-Path $hardeningHelper) {
  . $hardeningHelper
}

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) '.env.ps1'

$script:SystemFieldNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($fieldName in @(
  'ownerid', 'owningbusinessunit', 'owningteam', 'owninguser',
  'createdon', 'createdby', 'modifiedon', 'modifiedby',
  'statecode', 'statuscode', 'importsequencenumber', 'overriddencreatedon',
  'timezoneruleversionnumber', 'utcconversiontimezonecode', 'versionnumber'
)) {
  [void]$script:SystemFieldNames.Add($fieldName)
}

$script:WizardManagedViewMarker = 'Generated by 60-build-forms-views.ps1'

$script:UnsupportedAttributeTypes = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($typeName in @('Virtual', 'PartyList', 'ManagedProperty', 'EntityName', 'Image', 'File')) {
  [void]$script:UnsupportedAttributeTypes.Add($typeName)
}

function Get-PropertyValue {
  param(
    $Object,
    [string]$Name,
    $Default = $null
  )

  if ($null -eq $Object) { return $Default }
  $prop = $Object.PSObject.Properties[$Name]
  if ($null -eq $prop) { return $Default }
  return $prop.Value
}

function Invoke-Dv {
  param(
    [string]$Method,
    [string]$Path,
    [string]$Body = ''
  )

  $headers = @{
    Authorization      = "Bearer $AccessToken"
    'Content-Type'     = 'application/json'
    'OData-Version'    = '4.0'
    'OData-MaxVersion' = '4.0'
    Accept             = 'application/json'
  }

  $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
  if ([string]::IsNullOrWhiteSpace($Body)) {
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
  }

  return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body
}

function ConvertTo-Boolean {
  param(
    $Value,
    [bool]$Default = $false
  )

  if ($null -eq $Value) { return $Default }
  if ($Value -is [bool]) { return $Value }

  $parsed = $false
  if ([bool]::TryParse("$Value", [ref]$parsed)) {
    return $parsed
  }

  return $Default
}

function Test-WizardFormsViewsSkipMain {
  $value = [Environment]::GetEnvironmentVariable('WIZARD_FORMS_VIEWS_SKIP_MAIN')
  if ([string]::IsNullOrWhiteSpace($value)) { return $false }
  return @('1', 'true', 'yes', 'y') -contains $value.Trim().ToLowerInvariant()
}

function Get-EntitiesFromPayloads {
  param(
    [string]$Folder
  )

  $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $tableFiles = @(Get-ChildItem -Path $Folder -Filter 'table-*.json' -ErrorAction SilentlyContinue)

  foreach ($file in $tableFiles) {
    $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $schemaName = Get-PropertyValue -Object (Get-PropertyValue -Object $doc -Name 'EntityDefinition') -Name 'SchemaName'
    if ([string]::IsNullOrWhiteSpace($schemaName)) {
      $schemaName = Get-PropertyValue -Object $doc -Name 'SchemaName'
    }

    if ([string]::IsNullOrWhiteSpace($schemaName)) { continue }

    [void]$names.Add($schemaName.ToLowerInvariant())
  }

  $columnFiles = @(Get-ChildItem -Path $Folder -Filter 'columns-*.json' -ErrorAction SilentlyContinue)
  foreach ($file in $columnFiles) {
    $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $tableName = Get-PropertyValue -Object $doc -Name 'TableLogicalName'
    if (-not [string]::IsNullOrWhiteSpace($tableName)) {
      [void]$names.Add($tableName.ToLowerInvariant())
    }
  }

  return @([string[]]$names)
}

function Get-FriendlyLabelFromLogicalName {
  param(
    [string]$LogicalName,
    [string]$Prefix
  )

  if ([string]::IsNullOrWhiteSpace($LogicalName)) { return 'Field' }

  $value = $LogicalName.ToLowerInvariant()
  if (-not [string]::IsNullOrWhiteSpace($Prefix)) {
    $normalized = $Prefix.ToLowerInvariant() + '_'
    if ($value.StartsWith($normalized)) {
      $value = $value.Substring($normalized.Length)
    }
  }

  $value = ($value -replace '_', ' ').Trim()
  if ([string]::IsNullOrWhiteSpace($value)) { return 'Field' }

  $culture = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
  return $culture.TextInfo.ToTitleCase($value)
}

function Get-DisplayLabel {
  param(
    $DisplayName,
    [string]$LogicalName,
    [string]$Prefix
  )

  $labels = @(Get-PropertyValue -Object $DisplayName -Name 'LocalizedLabels' -Default @())
  if ($labels.Count -gt 0) {
    $englishLabel = @($labels | Where-Object { (Get-PropertyValue -Object $_ -Name 'LanguageCode' -Default 0) -eq 1033 } | Select-Object -First 1)
    if ($englishLabel.Count -gt 0) {
      $value = Get-PropertyValue -Object $englishLabel[0] -Name 'Label'
      if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
      }
    }

    $firstLabel = $labels | Select-Object -First 1
    $firstValue = Get-PropertyValue -Object $firstLabel -Name 'Label'
    if (-not [string]::IsNullOrWhiteSpace($firstValue)) {
      return $firstValue
    }
  }

  return Get-FriendlyLabelFromLogicalName -LogicalName $LogicalName -Prefix $Prefix
}

function Get-PrimaryFieldLabel {
  param(
    [string]$TableLogical,
    [string]$PrimaryField,
    [string]$Prefix
  )

  try {
    $metadata = Invoke-Dv -Method 'Get' -Path "EntityDefinitions(LogicalName='$TableLogical')/Attributes(LogicalName='$PrimaryField')?`$select=LogicalName&`$expand=DisplayName"
    return Get-DisplayLabel -DisplayName (Get-PropertyValue -Object $metadata -Name 'DisplayName') -LogicalName $PrimaryField -Prefix $Prefix
  } catch {
    return Get-FriendlyLabelFromLogicalName -LogicalName $PrimaryField -Prefix $Prefix
  }
}

function ConvertTo-SearchText {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return ' '
  }

  $normalized = $Value.ToLowerInvariant() -replace '[^a-z0-9]+', ' '
  $normalized = ($normalized -replace '\s+', ' ').Trim()
  return " $normalized "
}

function Get-ScenarioContext {
  param(
    [string]$RepoRoot,
    [string]$ScenarioSlug
  )

  $specsRoot = Join-Path $RepoRoot 'specs'
  if (-not (Test-Path $specsRoot)) {
    return $null
  }

  $resolvedSlug = $ScenarioSlug
  if ([string]::IsNullOrWhiteSpace($resolvedSlug)) {
    $scenarioFolders = @(Get-ChildItem -Path $specsRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($scenarioFolders.Count -eq 1) {
      $resolvedSlug = $scenarioFolders[0].Name
    } else {
      return $null
    }
  }

  $scenarioFolder = Join-Path $specsRoot $resolvedSlug
  if (-not (Test-Path $scenarioFolder)) {
    return $null
  }

  $markdownFiles = @(Get-ChildItem -Path $scenarioFolder -Filter '*.md' -File -ErrorAction SilentlyContinue | Sort-Object Name)
  if ($markdownFiles.Count -eq 0) {
    return [pscustomobject]@{
      ScenarioSlug      = $resolvedSlug
      ScenarioFolder    = $scenarioFolder
      Content           = ''
      RawLowerContent   = ''
      NormalizedContent = ' '
      SourceFiles       = @()
    }
  }

  $contentBlocks = New-Object System.Collections.Generic.List[string]
  foreach ($file in $markdownFiles) {
    $contentBlocks.Add((Get-Content -Path $file.FullName -Raw -Encoding UTF8)) | Out-Null
  }

  $content = ($contentBlocks.ToArray() -join [Environment]::NewLine)
  return [pscustomobject]@{
    ScenarioSlug      = $resolvedSlug
    ScenarioFolder    = $scenarioFolder
    Content           = $content
    RawLowerContent   = $content.ToLowerInvariant()
    NormalizedContent = ConvertTo-SearchText -Value $content
    SourceFiles       = @($markdownFiles | ForEach-Object { $_.FullName })
  }
}

function Get-PayloadFieldsForTable {
  param(
    [string]$Folder,
    [string]$TableLogical,
    [string]$Prefix
  )

  $results = New-Object System.Collections.Generic.List[object]
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $columnFiles = @(Get-ChildItem -Path $Folder -Filter 'columns-*.json' -ErrorAction SilentlyContinue | Sort-Object Name)

  foreach ($file in $columnFiles) {
    $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $tableName = Get-PropertyValue -Object $doc -Name 'TableLogicalName'
    if ([string]::IsNullOrWhiteSpace($tableName)) { continue }
    if ($tableName.ToLowerInvariant() -ne $TableLogical.ToLowerInvariant()) { continue }

    foreach ($col in @(Get-PropertyValue -Object $doc -Name 'Columns' -Default @())) {
      $logical = Get-PropertyValue -Object $col -Name 'LogicalName'
      if ([string]::IsNullOrWhiteSpace($logical)) {
        $logical = Get-PropertyValue -Object $col -Name 'SchemaName'
      }

      if ([string]::IsNullOrWhiteSpace($logical)) { continue }

      $logical = $logical.ToLowerInvariant()
      if (-not $seen.Add($logical)) { continue }

      $label = Get-DisplayLabel -DisplayName (Get-PropertyValue -Object $col -Name 'DisplayName') -LogicalName $logical -Prefix $Prefix
      $results.Add([pscustomobject]@{
        LogicalName = $logical
        Label       = $label
        Source      = 'payload'
      }) | Out-Null
    }
  }

  return @($results.ToArray())
}

function Get-TableAttributesMetadata {
  param(
    [string]$TableLogical,
    [string]$Prefix
  )

  $results = New-Object System.Collections.Generic.List[object]
  $response = Invoke-Dv -Method 'Get' -Path "EntityDefinitions(LogicalName='$TableLogical')/Attributes?`$select=LogicalName,AttributeType,IsPrimaryId,IsPrimaryName,IsValidForForm,IsValidForRead&`$expand=DisplayName"
  foreach ($attribute in @(Get-PropertyValue -Object $response -Name 'value' -Default @())) {
    $logical = Get-PropertyValue -Object $attribute -Name 'LogicalName'
    if ([string]::IsNullOrWhiteSpace($logical)) { continue }

    $logical = $logical.ToLowerInvariant()
    $attributeType = Get-PropertyValue -Object $attribute -Name 'AttributeType' -Default ''
    $isPrimaryId = ConvertTo-Boolean -Value (Get-PropertyValue -Object $attribute -Name 'IsPrimaryId')
    $isPrimaryName = ConvertTo-Boolean -Value (Get-PropertyValue -Object $attribute -Name 'IsPrimaryName')
    $isValidForForm = ConvertTo-Boolean -Value (Get-PropertyValue -Object $attribute -Name 'IsValidForForm') -Default $true
    $isValidForRead = ConvertTo-Boolean -Value (Get-PropertyValue -Object $attribute -Name 'IsValidForRead') -Default $true
    $label = Get-DisplayLabel -DisplayName (Get-PropertyValue -Object $attribute -Name 'DisplayName') -LogicalName $logical -Prefix $Prefix

    $results.Add([pscustomobject]@{
      LogicalName    = $logical
      Label          = $label
      AttributeType  = "$attributeType"
      IsPrimaryId    = $isPrimaryId
      IsPrimaryName  = $isPrimaryName
      IsValidForForm = $isValidForForm
      IsValidForRead = $isValidForRead
    }) | Out-Null
  }

  return @($results.ToArray())
}

function New-AttributeMetadataMap {
  param([array]$Attributes)

  $map = @{}
  foreach ($attribute in $Attributes) {
    $map[$attribute.LogicalName.ToLowerInvariant()] = $attribute
  }
  return $map
}

function Test-OwnerField {
  param([string]$LogicalName)

  return @('ownerid', 'owningbusinessunit', 'owningteam', 'owninguser') -contains $LogicalName.ToLowerInvariant()
}

function Test-StatusField {
  param([string]$LogicalName)

  return @('statuscode') -contains $LogicalName.ToLowerInvariant()
}

function Get-EligibilityResult {
  param(
    $Attribute,
    [string]$PrimaryField,
    [string]$PrimaryIdField,
    [bool]$IncludeOwner
  )

  $logical = $Attribute.LogicalName.ToLowerInvariant()
  if ($logical -eq $PrimaryField.ToLowerInvariant()) {
    return [pscustomobject]@{ Eligible = $true; Reason = ''; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if ($Attribute.IsPrimaryId -or $logical -eq $PrimaryIdField.ToLowerInvariant()) {
    return [pscustomobject]@{ Eligible = $false; Reason = 'primary key guid'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if ($script:SystemFieldNames.Contains($logical)) {
    if (($logical -eq 'ownerid') -and $IncludeOwner) {
      return [pscustomobject]@{ Eligible = $true; Reason = ''; IsBusiness = $false; IncludeAsMetadata = $true }
    }

    return [pscustomobject]@{ Eligible = $false; Reason = 'system field'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if (Test-OwnerField -LogicalName $logical) {
    return [pscustomobject]@{ Eligible = $false; Reason = 'system field'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if (-not $Attribute.IsValidForForm) {
    return [pscustomobject]@{ Eligible = $false; Reason = 'not valid for form'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if ($script:UnsupportedAttributeTypes.Contains($Attribute.AttributeType)) {
    return [pscustomobject]@{ Eligible = $false; Reason = 'unsupported type'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  return [pscustomobject]@{ Eligible = $true; Reason = ''; IsBusiness = $true; IncludeAsMetadata = $false }
}

function Add-SkipRecord {
  param(
    [System.Collections.Generic.List[object]]$Target,
    [string]$LogicalName,
    [string]$Reason,
    [string]$Source
  )

  $Target.Add([pscustomobject]@{
    field  = $LogicalName
    reason = $Reason
    source = $Source
  }) | Out-Null
}

function Get-DesiredFormFields {
  param(
    [string]$PrimaryField,
    [string]$PrimaryLabel,
    [string]$PrimaryIdField,
    [array]$PayloadFields,
    [array]$Attributes,
    [int]$MinimumBusinessFields,
    [bool]$IncludeOwner
  )

  $attributeMap = New-AttributeMetadataMap -Attributes $Attributes
  $orderedFields = New-Object System.Collections.Generic.List[object]
  $skippedFields = New-Object System.Collections.Generic.List[object]
  $missingExpectedFields = New-Object System.Collections.Generic.List[string]
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $businessFieldCount = 0
  $ownerField = $null

  $orderedFields.Add([pscustomobject]@{
    LogicalName = $PrimaryField.ToLowerInvariant()
    Label       = $PrimaryLabel
    Source      = 'primary'
    IsBusiness  = $false
  }) | Out-Null
  [void]$seen.Add($PrimaryField.ToLowerInvariant())

  foreach ($payloadField in $PayloadFields) {
    $logical = $payloadField.LogicalName.ToLowerInvariant()
    if ($seen.Contains($logical)) { continue }

    if (-not $attributeMap.ContainsKey($logical)) {
      Add-SkipRecord -Target $skippedFields -LogicalName $logical -Reason 'missing attribute' -Source 'payload'
      $missingExpectedFields.Add($logical) | Out-Null
      continue
    }

    $attribute = $attributeMap[$logical]
    $eligibility = Get-EligibilityResult -Attribute $attribute -PrimaryField $PrimaryField -PrimaryIdField $PrimaryIdField -IncludeOwner $IncludeOwner
    if (-not $eligibility.Eligible) {
      Add-SkipRecord -Target $skippedFields -LogicalName $logical -Reason $eligibility.Reason -Source 'payload'
      if ($eligibility.IsBusiness -eq $false -and $eligibility.IncludeAsMetadata -eq $false) {
        $missingExpectedFields.Add($logical) | Out-Null
      }
      continue
    }

    if ($eligibility.IncludeAsMetadata) {
      $ownerField = [pscustomobject]@{
        LogicalName = $attribute.LogicalName
        Label       = $attribute.Label
        Source      = 'payload'
        IsBusiness  = $false
      }
      continue
    }

    $orderedFields.Add([pscustomobject]@{
      LogicalName = $attribute.LogicalName
      Label       = $attribute.Label
      Source      = 'payload'
      IsBusiness  = $eligibility.IsBusiness
    }) | Out-Null
    [void]$seen.Add($logical)
    if ($eligibility.IsBusiness) {
      $businessFieldCount++
    }
  }

  if ($businessFieldCount -lt $MinimumBusinessFields) {
    $fallbackCandidates = @($Attributes | Sort-Object Label, LogicalName)
    foreach ($attribute in $fallbackCandidates) {
      $logical = $attribute.LogicalName.ToLowerInvariant()
      if ($seen.Contains($logical)) { continue }

      $eligibility = Get-EligibilityResult -Attribute $attribute -PrimaryField $PrimaryField -PrimaryIdField $PrimaryIdField -IncludeOwner $IncludeOwner
      if (-not $eligibility.Eligible) {
        Add-SkipRecord -Target $skippedFields -LogicalName $logical -Reason $eligibility.Reason -Source 'fallback'
        continue
      }

      if ($eligibility.IncludeAsMetadata) {
        if ($null -eq $ownerField) {
          $ownerField = [pscustomobject]@{
            LogicalName = $attribute.LogicalName
            Label       = $attribute.Label
            Source      = 'fallback'
            IsBusiness  = $false
          }
        }
        continue
      }

      $orderedFields.Add([pscustomobject]@{
        LogicalName = $attribute.LogicalName
        Label       = $attribute.Label
        Source      = 'fallback'
        IsBusiness  = $eligibility.IsBusiness
      }) | Out-Null
      [void]$seen.Add($logical)
      if ($eligibility.IsBusiness) {
        $businessFieldCount++
      }

      if ($businessFieldCount -ge $MinimumBusinessFields) {
        break
      }
    }
  }

  if ($IncludeOwner -and $null -ne $ownerField -and -not $seen.Contains($ownerField.LogicalName.ToLowerInvariant())) {
    $orderedFields.Add($ownerField) | Out-Null
    [void]$seen.Add($ownerField.LogicalName.ToLowerInvariant())
  }

  return [pscustomobject]@{
    Fields                = @($orderedFields.ToArray())
    SkippedFields         = @($skippedFields.ToArray())
    MissingExpectedFields = @($missingExpectedFields.ToArray() | Select-Object -Unique)
  }
}

function Add-ScoredCandidate {
  param(
    [hashtable]$Target,
    [string]$LogicalName,
    [int]$Score,
    [string]$Reason
  )

  $key = $LogicalName.ToLowerInvariant()
  if (-not $Target.ContainsKey($key) -or $Target[$key].Score -lt $Score) {
    $Target[$key] = [pscustomobject]@{
      LogicalName = $key
      Score       = $Score
      Reason      = $Reason
    }
  }
}

function Get-ScenarioFieldCandidates {
  param(
    [string]$TableLogical,
    [array]$Attributes,
    $ScenarioContext
  )

  $candidateMap = @{}
  $missingExpectedFields = New-Object System.Collections.Generic.List[string]
  if ($null -eq $ScenarioContext) {
    return [pscustomobject]@{
      Candidates            = @()
      MissingExpectedFields = @()
    }
  }

  $attributeMap = New-AttributeMetadataMap -Attributes $Attributes
  $tablePattern = "\b$([regex]::Escape($TableLogical.ToLowerInvariant()))\.([a-z0-9_]+)\b"
  foreach ($match in [regex]::Matches($ScenarioContext.RawLowerContent, $tablePattern)) {
    $fieldLogical = $match.Groups[1].Value.ToLowerInvariant()
    if ($attributeMap.ContainsKey($fieldLogical)) {
      Add-ScoredCandidate -Target $candidateMap -LogicalName $fieldLogical -Score 300 -Reason 'scenario explicit logical reference'
    } else {
      $missingExpectedFields.Add($fieldLogical) | Out-Null
    }
  }

  $keywordSignals = @('status', 'workflow', 'review', 'queue', 'routing', 'risk', 'escalation', 'priority', 'owner', 'assigned', 'agent', 'approval', 'stage')
  foreach ($attribute in $Attributes) {
    $logical = $attribute.LogicalName.ToLowerInvariant()
    $normalizedLogical = ConvertTo-SearchText -Value $logical
    $normalizedLabel = ConvertTo-SearchText -Value $attribute.Label
    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]

    if ($ScenarioContext.NormalizedContent.Contains($normalizedLogical)) {
      $score += 220
      $reasons.Add('logical name mention') | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace($attribute.Label) -and $ScenarioContext.NormalizedContent.Contains($normalizedLabel)) {
      $score += 180
      $reasons.Add('label mention') | Out-Null
    }

    foreach ($keyword in $keywordSignals) {
      $keywordToken = " $keyword "
      if ($ScenarioContext.NormalizedContent.Contains($keywordToken) -and ($normalizedLogical.Contains($keywordToken) -or $normalizedLabel.Contains($keywordToken))) {
        $score += 25
        $reasons.Add("keyword:$keyword") | Out-Null
      }
    }

    if ($score -gt 0) {
      Add-ScoredCandidate -Target $candidateMap -LogicalName $logical -Score $score -Reason (($reasons.ToArray() | Select-Object -Unique) -join ', ')
    }
  }

  return [pscustomobject]@{
    Candidates            = @($candidateMap.Values | Sort-Object @{ Expression = 'Score'; Descending = $true }, LogicalName)
    MissingExpectedFields = @($missingExpectedFields.ToArray() | Select-Object -Unique)
  }
}

function Get-ViewEligibilityResult {
  param(
    $Attribute,
    [string]$PrimaryField,
    [string]$PrimaryIdField,
    [bool]$IncludeOwner,
    [bool]$IncludeStatus
  )

  $logical = $Attribute.LogicalName.ToLowerInvariant()
  if ($logical -eq $PrimaryField.ToLowerInvariant()) {
    return [pscustomobject]@{ Eligible = $true; Reason = ''; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if ($Attribute.IsPrimaryId -or $logical -eq $PrimaryIdField.ToLowerInvariant()) {
    return [pscustomobject]@{ Eligible = $false; Reason = 'primary key guid'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if (-not (ConvertTo-Boolean -Value (Get-PropertyValue -Object $Attribute -Name 'IsValidForRead') -Default $true)) {
    return [pscustomobject]@{ Eligible = $false; Reason = 'not valid for read'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if ($script:SystemFieldNames.Contains($logical)) {
    if (($logical -eq 'ownerid') -and $IncludeOwner) {
      return [pscustomobject]@{ Eligible = $true; Reason = ''; IsBusiness = $false; IncludeAsMetadata = $true }
    }

    if ((Test-StatusField -LogicalName $logical) -and $IncludeStatus) {
      return [pscustomobject]@{ Eligible = $true; Reason = ''; IsBusiness = $false; IncludeAsMetadata = $true }
    }

    return [pscustomobject]@{ Eligible = $false; Reason = 'system field'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if (Test-OwnerField -LogicalName $logical) {
    return [pscustomobject]@{ Eligible = $false; Reason = 'system field'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  if ($script:UnsupportedAttributeTypes.Contains($Attribute.AttributeType)) {
    return [pscustomobject]@{ Eligible = $false; Reason = 'unsupported type'; IsBusiness = $false; IncludeAsMetadata = $false }
  }

  return [pscustomobject]@{ Eligible = $true; Reason = ''; IsBusiness = $true; IncludeAsMetadata = $false }
}

function Get-DesiredViewFields {
  param(
    [string]$TableLogical,
    [string]$PrimaryField,
    [string]$PrimaryLabel,
    [string]$PrimaryIdField,
    [array]$PayloadFields,
    [array]$Attributes,
    [int]$MinimumBusinessFields,
    [bool]$IncludeOwner,
    [bool]$IncludeStatus,
    $ScenarioContext
  )

  $attributeMap = New-AttributeMetadataMap -Attributes $Attributes
  $orderedFields = New-Object System.Collections.Generic.List[object]
  $skippedFields = New-Object System.Collections.Generic.List[object]
  $missingExpectedFields = New-Object System.Collections.Generic.List[string]
  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $businessFieldCount = 0
  $ownerField = $null
  $statusField = $null

  $orderedFields.Add([pscustomobject]@{
    LogicalName = $PrimaryField.ToLowerInvariant()
    Label       = $PrimaryLabel
    Source      = 'primary'
    IsBusiness  = $false
  }) | Out-Null
  [void]$seen.Add($PrimaryField.ToLowerInvariant())

  foreach ($payloadField in $PayloadFields) {
    $logical = $payloadField.LogicalName.ToLowerInvariant()
    if ($seen.Contains($logical)) { continue }

    if (-not $attributeMap.ContainsKey($logical)) {
      Add-SkipRecord -Target $skippedFields -LogicalName $logical -Reason 'missing attribute' -Source 'payload'
      $missingExpectedFields.Add($logical) | Out-Null
      continue
    }

    $attribute = $attributeMap[$logical]
    $eligibility = Get-ViewEligibilityResult -Attribute $attribute -PrimaryField $PrimaryField -PrimaryIdField $PrimaryIdField -IncludeOwner $IncludeOwner -IncludeStatus $IncludeStatus
    if (-not $eligibility.Eligible) {
      Add-SkipRecord -Target $skippedFields -LogicalName $logical -Reason $eligibility.Reason -Source 'payload'
      continue
    }

    if ($eligibility.IncludeAsMetadata) {
      if ((Test-OwnerField -LogicalName $logical) -and $null -eq $ownerField) {
        $ownerField = [pscustomobject]@{ LogicalName = $attribute.LogicalName; Label = $attribute.Label; Source = 'payload'; IsBusiness = $false }
      }

      if ((Test-StatusField -LogicalName $logical) -and $null -eq $statusField) {
        $statusField = [pscustomobject]@{ LogicalName = $attribute.LogicalName; Label = $attribute.Label; Source = 'payload'; IsBusiness = $false }
      }
      continue
    }

    $orderedFields.Add([pscustomobject]@{ LogicalName = $attribute.LogicalName; Label = $attribute.Label; Source = 'payload'; IsBusiness = $true }) | Out-Null
    [void]$seen.Add($logical)
    $businessFieldCount++
  }

  $scenarioCandidates = Get-ScenarioFieldCandidates -TableLogical $TableLogical -Attributes $Attributes -ScenarioContext $ScenarioContext
  foreach ($missingField in @($scenarioCandidates.MissingExpectedFields)) {
    $missingExpectedFields.Add($missingField) | Out-Null
  }

  foreach ($scenarioCandidate in @($scenarioCandidates.Candidates)) {
    $logical = $scenarioCandidate.LogicalName.ToLowerInvariant()
    if ($seen.Contains($logical)) { continue }
    if (-not $attributeMap.ContainsKey($logical)) {
      Add-SkipRecord -Target $skippedFields -LogicalName $logical -Reason 'missing attribute' -Source 'scenario'
      $missingExpectedFields.Add($logical) | Out-Null
      continue
    }

    $attribute = $attributeMap[$logical]
    $eligibility = Get-ViewEligibilityResult -Attribute $attribute -PrimaryField $PrimaryField -PrimaryIdField $PrimaryIdField -IncludeOwner $IncludeOwner -IncludeStatus $IncludeStatus
    if (-not $eligibility.Eligible) {
      Add-SkipRecord -Target $skippedFields -LogicalName $logical -Reason $eligibility.Reason -Source 'scenario'
      continue
    }

    if ($eligibility.IncludeAsMetadata) {
      if ((Test-OwnerField -LogicalName $logical) -and $null -eq $ownerField) {
        $ownerField = [pscustomobject]@{ LogicalName = $attribute.LogicalName; Label = $attribute.Label; Source = 'scenario'; IsBusiness = $false }
      }

      if ((Test-StatusField -LogicalName $logical) -and $null -eq $statusField) {
        $statusField = [pscustomobject]@{ LogicalName = $attribute.LogicalName; Label = $attribute.Label; Source = 'scenario'; IsBusiness = $false }
      }
      continue
    }

    $orderedFields.Add([pscustomobject]@{ LogicalName = $attribute.LogicalName; Label = $attribute.Label; Source = 'scenario'; IsBusiness = $true }) | Out-Null
    [void]$seen.Add($logical)
    $businessFieldCount++
  }

  if ($businessFieldCount -lt $MinimumBusinessFields) {
    foreach ($attribute in @($Attributes | Sort-Object Label, LogicalName)) {
      $logical = $attribute.LogicalName.ToLowerInvariant()
      if ($seen.Contains($logical)) { continue }

      $eligibility = Get-ViewEligibilityResult -Attribute $attribute -PrimaryField $PrimaryField -PrimaryIdField $PrimaryIdField -IncludeOwner $IncludeOwner -IncludeStatus $IncludeStatus
      if (-not $eligibility.Eligible) {
        Add-SkipRecord -Target $skippedFields -LogicalName $logical -Reason $eligibility.Reason -Source 'fallback'
        continue
      }

      if ($eligibility.IncludeAsMetadata) {
        if ((Test-OwnerField -LogicalName $logical) -and $null -eq $ownerField) {
          $ownerField = [pscustomobject]@{ LogicalName = $attribute.LogicalName; Label = $attribute.Label; Source = 'fallback'; IsBusiness = $false }
        }

        if ((Test-StatusField -LogicalName $logical) -and $null -eq $statusField) {
          $statusField = [pscustomobject]@{ LogicalName = $attribute.LogicalName; Label = $attribute.Label; Source = 'fallback'; IsBusiness = $false }
        }
        continue
      }

      $orderedFields.Add([pscustomobject]@{ LogicalName = $attribute.LogicalName; Label = $attribute.Label; Source = 'fallback'; IsBusiness = $true }) | Out-Null
      [void]$seen.Add($logical)
      $businessFieldCount++
      if ($businessFieldCount -ge $MinimumBusinessFields) {
        break
      }
    }
  }

  foreach ($metadataField in @($statusField, $ownerField)) {
    if ($null -eq $metadataField) { continue }
    $logical = $metadataField.LogicalName.ToLowerInvariant()
    if ($seen.Contains($logical)) { continue }
    $orderedFields.Add($metadataField) | Out-Null
    [void]$seen.Add($logical)
  }

  return [pscustomobject]@{
    Fields                = @($orderedFields.ToArray())
    SkippedFields         = @($skippedFields.ToArray())
    MissingExpectedFields = @($missingExpectedFields.ToArray() | Select-Object -Unique)
  }
}

function New-XmlElement {
  param(
    [xml]$Document,
    [string]$Name,
    [hashtable]$Attributes = $null,
    [string]$InnerText = ''
  )

  $element = $Document.CreateElement($Name)
  if ($null -ne $Attributes) {
    foreach ($key in $Attributes.Keys) {
      [void]$element.SetAttribute($key, "$($Attributes[$key])")
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($InnerText)) {
    $element.InnerText = $InnerText
  }

  return $element
}

function Set-LabelNode {
  param(
    [xml]$Document,
    [System.Xml.XmlElement]$Parent,
    [string]$Text
  )

  $labelsNode = $Parent.SelectSingleNode('labels')
  if ($null -eq $labelsNode) {
    $labelsNode = New-XmlElement -Document $Document -Name 'labels'
    [void]$Parent.AppendChild($labelsNode)
  }

  $labelNode = $labelsNode.SelectSingleNode("label[@languagecode='1033']")
  if ($null -eq $labelNode) {
    $labelNode = New-XmlElement -Document $Document -Name 'label' -Attributes @{ description = $Text; languagecode = '1033' }
    [void]$labelsNode.AppendChild($labelNode)
  } elseif ($labelNode.GetAttribute('description') -ne $Text) {
    $labelNode.SetAttribute('description', $Text)
  }
}

function New-FieldCellNode {
  param(
    [xml]$Document,
    [string]$FieldLogicalName,
    [string]$FieldLabel,
    [int]$CellIndex
  )

  $cellId = '{0:d12}' -f $CellIndex
  $cell = New-XmlElement -Document $Document -Name 'cell' -Attributes @{ id = "{00000000-0000-0000-0000-$cellId}" }
  $labels = New-XmlElement -Document $Document -Name 'labels'
  $label = New-XmlElement -Document $Document -Name 'label' -Attributes @{ description = $FieldLabel; languagecode = '1033' }
  [void]$labels.AppendChild($label)
  [void]$cell.AppendChild($labels)

  $control = New-XmlElement -Document $Document -Name 'control' -Attributes @{
    id            = $FieldLogicalName
    classid       = '{4273EDBD-AC1D-40d3-9FB2-095C621B552D}'
    datafieldname = $FieldLogicalName
    disabled      = 'false'
  }
  [void]$cell.AppendChild($control)

  return $cell
}

function New-EmptyCellNode {
  param(
    [xml]$Document,
    [int]$CellIndex
  )

  $cellId = '{0:d12}' -f $CellIndex
  return New-XmlElement -Document $Document -Name 'cell' -Attributes @{ id = "{00000000-0000-0000-0000-$cellId}" }
}

function Get-ExistingControlSetFromDocument {
  param([xml]$Document)

  $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($control in @($Document.SelectNodes('//control[@datafieldname]'))) {
    $dataFieldName = $control.GetAttribute('datafieldname')
    if (-not [string]::IsNullOrWhiteSpace($dataFieldName)) {
      [void]$set.Add($dataFieldName.ToLowerInvariant())
    }
  }
  return ,$set
}

function Get-NextCellIndex {
  param([xml]$Document)

  return (@($Document.SelectNodes('//cell')).Count + 2)
}

function Initialize-FormScaffold {
  param([xml]$Document)

  $formNode = $Document.SelectSingleNode('/form')
  if ($null -eq $formNode) {
    $Document.RemoveAll()
    $formNode = $Document.CreateElement('form')
    [void]$Document.AppendChild($formNode)
  }

  $tabsNode = $formNode.SelectSingleNode('tabs')
  if ($null -eq $tabsNode) {
    $tabsNode = New-XmlElement -Document $Document -Name 'tabs'
    [void]$formNode.AppendChild($tabsNode)
  }

  $tabNode = $tabsNode.SelectSingleNode("tab[@name='general']")
  if ($null -eq $tabNode) {
    $tabNode = $tabsNode.SelectSingleNode('tab')
  }
  if ($null -eq $tabNode) {
    $tabNode = New-XmlElement -Document $Document -Name 'tab' -Attributes @{
      name      = 'general'
      id        = '{00000000-0000-0000-0000-000000000001}'
      labelid   = ''
      showlabel = 'true'
      expanded  = 'true'
    }
    Set-LabelNode -Document $Document -Parent $tabNode -Text 'General'
    [void]$tabsNode.AppendChild($tabNode)
  }

  $columnsNode = $tabNode.SelectSingleNode('columns')
  if ($null -eq $columnsNode) {
    $columnsNode = New-XmlElement -Document $Document -Name 'columns'
    [void]$tabNode.AppendChild($columnsNode)
  }

  $columnNode = $columnsNode.SelectSingleNode('column')
  if ($null -eq $columnNode) {
    $columnNode = New-XmlElement -Document $Document -Name 'column' -Attributes @{ width = '100%' }
    [void]$columnsNode.AppendChild($columnNode)
  }

  $sectionsNode = $columnNode.SelectSingleNode('sections')
  if ($null -eq $sectionsNode) {
    $sectionsNode = New-XmlElement -Document $Document -Name 'sections'
    [void]$columnNode.AppendChild($sectionsNode)
  }

  $generalSection = $sectionsNode.SelectSingleNode("section[@name='general_section']")
  if ($null -eq $generalSection) {
    $generalSection = New-XmlElement -Document $Document -Name 'section' -Attributes @{
      name      = 'general_section'
      showlabel = 'true'
      showbar   = 'true'
    }
    Set-LabelNode -Document $Document -Parent $generalSection -Text 'General'
    [void]$sectionsNode.AppendChild($generalSection)
  }

  $generalRows = $generalSection.SelectSingleNode('rows')
  if ($null -eq $generalRows) {
    $generalRows = New-XmlElement -Document $Document -Name 'rows'
    [void]$generalSection.AppendChild($generalRows)
  }

  $detailsSection = $sectionsNode.SelectSingleNode("section[@name='details_section']")
  if ($null -eq $detailsSection) {
    $detailsSection = New-XmlElement -Document $Document -Name 'section' -Attributes @{
      name      = 'details_section'
      showlabel = 'true'
      showbar   = 'true'
    }
    Set-LabelNode -Document $Document -Parent $detailsSection -Text 'Details'
    $detailsRows = New-XmlElement -Document $Document -Name 'rows'
    [void]$detailsSection.AppendChild($detailsRows)
    [void]$sectionsNode.AppendChild($detailsSection)
  }

  $detailsRowsNode = $detailsSection.SelectSingleNode('rows')
  if ($null -eq $detailsRowsNode) {
    $detailsRowsNode = New-XmlElement -Document $Document -Name 'rows'
    [void]$detailsSection.AppendChild($detailsRowsNode)
  }

  return [pscustomobject]@{
    GeneralRows    = $generalRows
    DetailsRows    = $detailsRowsNode
    DetailsSection = $detailsSection
  }
}

function Add-FieldsToRows {
  param(
    [xml]$Document,
    [System.Xml.XmlElement]$RowsNode,
    [array]$Fields,
    [ref]$CellIndex
  )

  for ($index = 0; $index -lt $Fields.Count; $index += 2) {
    $rowNode = New-XmlElement -Document $Document -Name 'row'
    [void]$rowNode.AppendChild((New-FieldCellNode -Document $Document -FieldLogicalName $Fields[$index].LogicalName -FieldLabel $Fields[$index].Label -CellIndex $CellIndex.Value))
    $CellIndex.Value++

    if ($index + 1 -lt $Fields.Count) {
      [void]$rowNode.AppendChild((New-FieldCellNode -Document $Document -FieldLogicalName $Fields[$index + 1].LogicalName -FieldLabel $Fields[$index + 1].Label -CellIndex $CellIndex.Value))
      $CellIndex.Value++
    } else {
      [void]$rowNode.AppendChild((New-EmptyCellNode -Document $Document -CellIndex $CellIndex.Value))
      $CellIndex.Value++
    }

    [void]$RowsNode.AppendChild($rowNode)
  }
}

function Convert-FormXmlToDocument {
  param([string]$FormXml)

  if ([string]::IsNullOrWhiteSpace($FormXml)) {
    return [xml]'<form />'
  }

  try {
    return [xml]$FormXml
  } catch {
    return $null
  }
}

function Merge-FieldsIntoFormXml {
  param(
    [string]$ExistingFormXml,
    [array]$DesiredFields
  )

  $document = Convert-FormXmlToDocument -FormXml $ExistingFormXml
  if ($null -eq $document) {
    $document = [xml]'<form />'
  }

  $existingControls = Get-ExistingControlSetFromDocument -Document $document
  $fieldsToAdd = @($DesiredFields | Where-Object { -not $existingControls.Contains($_.LogicalName.ToLowerInvariant()) })
  if (($fieldsToAdd.Count -eq 0) -and -not [string]::IsNullOrWhiteSpace($ExistingFormXml)) {
    return [pscustomobject]@{
      FormXml        = $ExistingFormXml
      AddedFieldList = @()
    }
  }

  $scaffold = Initialize-FormScaffold -Document $document
  $desiredGeneral = @($DesiredFields | Select-Object -First 6)
  $desiredDetails = @($DesiredFields | Select-Object -Skip 6)
  $generalToAdd = @($desiredGeneral | Where-Object { -not $existingControls.Contains($_.LogicalName.ToLowerInvariant()) })
  $detailsToAdd = @($desiredDetails | Where-Object { -not $existingControls.Contains($_.LogicalName.ToLowerInvariant()) })
  $cellIndex = Get-NextCellIndex -Document $document
  $cellIndexRef = [ref]$cellIndex

  if ($generalToAdd.Count -gt 0) {
    Add-FieldsToRows -Document $document -RowsNode $scaffold.GeneralRows -Fields $generalToAdd -CellIndex $cellIndexRef
  }

  if ($detailsToAdd.Count -gt 0) {
    Add-FieldsToRows -Document $document -RowsNode $scaffold.DetailsRows -Fields $detailsToAdd -CellIndex $cellIndexRef
  }

  if (@($scaffold.DetailsRows.SelectNodes('row')).Count -eq 0) {
    [void]$scaffold.DetailsSection.ParentNode.RemoveChild($scaffold.DetailsSection)
  }

  return [pscustomobject]@{
    FormXml        = $document.OuterXml
    AddedFieldList = @($fieldsToAdd)
  }
}

function Get-UniqueControlNamesFromFormXml {
  param([string]$FormXml)

  $document = Convert-FormXmlToDocument -FormXml $FormXml
  if ($null -eq $document) {
    return @()
  }

  $set = Get-ExistingControlSetFromDocument -Document $document
  return @([string[]]$set)
}

function Get-BusinessFieldCountFromFormXml {
  param(
    [string]$FormXml,
    [hashtable]$AttributeMap,
    [string]$PrimaryField,
    [string]$PrimaryIdField
  )

  $count = 0
  foreach ($logicalName in @(Get-UniqueControlNamesFromFormXml -FormXml $FormXml)) {
    $resolved = $logicalName.ToLowerInvariant()
    if ($resolved -eq $PrimaryField.ToLowerInvariant()) { continue }
    if (-not $AttributeMap.ContainsKey($resolved)) { continue }

    $eligibility = Get-EligibilityResult -Attribute $AttributeMap[$resolved] -PrimaryField $PrimaryField -PrimaryIdField $PrimaryIdField -IncludeOwner $false
    if ($eligibility.IsBusiness) {
      $count++
    }
  }

  return $count
}

function New-StarterViewFetchXml {
  param(
    [string]$TableLogical,
    [string]$PrimaryField,
    [array]$Fields,
    [bool]$FilterToActiveRecords
  )

  $attributeLines = New-Object System.Collections.Generic.List[string]
  foreach ($field in @($Fields)) {
    $attributeLines.Add("    <attribute name=`"$($field.LogicalName)`" />") | Out-Null
  }

  $filterBlock = ''
  if ($FilterToActiveRecords) {
    $filterBlock = @"
    <filter type="and">
      <condition attribute="statecode" operator="eq" value="0" />
    </filter>
"@
  }

  return @"
<fetch version="1.0" output-format="xml-platform" mapping="logical" distinct="false">
  <entity name="$TableLogical">
$($attributeLines.ToArray() -join [Environment]::NewLine)
    <order attribute="$PrimaryField" descending="false" />
$filterBlock
  </entity>
</fetch>
"@
}

function New-StarterViewLayoutXml {
  param(
    [array]$Fields,
    [string]$PrimaryField,
    [string]$PrimaryIdField
  )

  $resolvedPrimaryId = if ([string]::IsNullOrWhiteSpace($PrimaryIdField)) { "$PrimaryField`id" } else { $PrimaryIdField }
  $cellLines = New-Object System.Collections.Generic.List[string]
  foreach ($field in @($Fields)) {
    $width = if ($field.LogicalName.ToLowerInvariant() -eq $PrimaryField.ToLowerInvariant()) { 300 } else { 150 }
    $cellLines.Add("    <cell name=`"$($field.LogicalName)`" width=`"$width`" />") | Out-Null
  }

  return @"
<grid name="resultset" object="1" jump="$PrimaryField" select="1" icon="1" preview="1">
  <row name="result" id="$resolvedPrimaryId">
$($cellLines.ToArray() -join [Environment]::NewLine)
  </row>
</grid>
"@
}

function Get-FieldNamesFromViewLayoutXml {
  param([string]$LayoutXml)

  if ([string]::IsNullOrWhiteSpace($LayoutXml)) {
    return @()
  }

  try {
    [xml]$document = $LayoutXml
  } catch {
    return @()
  }

  $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($cell in @($document.SelectNodes('//cell[@name]'))) {
    $name = $cell.GetAttribute('name')
    if (-not [string]::IsNullOrWhiteSpace($name)) {
      [void]$set.Add($name.ToLowerInvariant())
    }
  }

  return @([string[]]$set)
}

function Get-FieldNamesFromViewFetchXml {
  param([string]$FetchXml)

  if ([string]::IsNullOrWhiteSpace($FetchXml)) {
    return @()
  }

  try {
    [xml]$document = $FetchXml
  } catch {
    return @()
  }

  $set = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($attribute in @($document.SelectNodes('//entity/attribute[@name]'))) {
    $name = $attribute.GetAttribute('name')
    if (-not [string]::IsNullOrWhiteSpace($name)) {
      [void]$set.Add($name.ToLowerInvariant())
    }
  }

  return @([string[]]$set)
}

function Get-ViewPopulationAnalysis {
  param(
    [string]$LayoutXml,
    [string]$FetchXml,
    [hashtable]$AttributeMap,
    [string]$PrimaryField,
    [string]$PrimaryIdField,
    [bool]$IncludeOwner,
    [bool]$IncludeStatus
  )

  $layoutColumns = @(Get-FieldNamesFromViewLayoutXml -LayoutXml $LayoutXml)
  $fetchColumns = @(Get-FieldNamesFromViewFetchXml -FetchXml $FetchXml)
  $fetchSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($field in $fetchColumns) {
    [void]$fetchSet.Add($field)
  }

  $layoutOnly = New-Object System.Collections.Generic.List[string]
  $businessColumns = New-Object System.Collections.Generic.List[string]
  foreach ($field in $layoutColumns) {
    if (-not $fetchSet.Contains($field)) {
      $layoutOnly.Add($field) | Out-Null
      continue
    }

    if (-not $AttributeMap.ContainsKey($field)) {
      continue
    }

    $eligibility = Get-ViewEligibilityResult -Attribute $AttributeMap[$field] -PrimaryField $PrimaryField -PrimaryIdField $PrimaryIdField -IncludeOwner $IncludeOwner -IncludeStatus $IncludeStatus
    if ($eligibility.IsBusiness) {
      $businessColumns.Add($field) | Out-Null
    }
  }

  $layoutSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($field in $layoutColumns) {
    [void]$layoutSet.Add($field)
  }

  $fetchOnly = New-Object System.Collections.Generic.List[string]
  foreach ($field in $fetchColumns) {
    if (-not $layoutSet.Contains($field)) {
      $fetchOnly.Add($field) | Out-Null
    }
  }

  return [pscustomobject]@{
    LayoutColumns   = @($layoutColumns)
    FetchColumns    = @($fetchColumns)
    BusinessColumns = @($businessColumns.ToArray())
    LayoutOnly      = @($layoutOnly.ToArray())
    FetchOnly       = @($fetchOnly.ToArray())
  }
}

function Test-IsWizardManagedView {
  param(
    $View,
    [string]$PrimaryField
  )

  $description = Get-PropertyValue -Object $View -Name 'description' -Default ''
  if (-not [string]::IsNullOrWhiteSpace($description) -and $description -like "*$script:WizardManagedViewMarker*") {
    return $true
  }

  $layoutColumns = @(Get-FieldNamesFromViewLayoutXml -LayoutXml (Get-PropertyValue -Object $View -Name 'layoutxml' -Default ''))
  $fetchColumns = @(Get-FieldNamesFromViewFetchXml -FetchXml (Get-PropertyValue -Object $View -Name 'fetchxml' -Default ''))
  if ((Get-PropertyValue -Object $View -Name 'name' -Default '') -eq 'Active Records' -and $layoutColumns.Count -le 3) {
    return (($layoutColumns -contains $PrimaryField.ToLowerInvariant()) -and ($layoutColumns -contains 'createdon') -and ($layoutColumns -contains 'modifiedon') -and ($fetchColumns -contains 'createdon') -and ($fetchColumns -contains 'modifiedon'))
  }

  return $false
}

function Get-TargetMainForm {
  param(
    [array]$ExistingForms,
    [string]$PreferredFormName,
    [string]$FormStrategy = 'legacy'
  )

  $preferred = @($ExistingForms | Where-Object { $_.name -eq $PreferredFormName } | Select-Object -First 1)
  if ($preferred.Count -gt 0) { return $preferred[0] }

  if ($FormStrategy -eq 'create-new-forms') { return $null }

  $alternateName = if ($PreferredFormName -eq 'Starter Main Form') { 'Information' } else { 'Starter Main Form' }
  $alternate = @($ExistingForms | Where-Object { $_.name -eq $alternateName } | Select-Object -First 1)
  if ($alternate.Count -gt 0) { return $alternate[0] }

  return $null
}

function Write-FormPopulationReport {
  param(
    [string]$RepoRoot,
    [string]$PreferredFormName,
    [int]$MinimumBusinessFields,
    [bool]$IncludeOwner,
    [bool]$FailOnUnderpopulated,
    [array]$TableReports
  )

  $reportRoot = Join-Path $RepoRoot '.wizard-metrics\artifacts\forms'
  New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
  $reportPath = Join-Path $reportRoot 'form-population-report.json'

  $payload = [pscustomobject]@{
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    preferFormName = $PreferredFormName
    minBusinessFieldsPerForm = $MinimumBusinessFields
    includeOwnerOnForms = $IncludeOwner
    failIfUnderpopulatedForms = $FailOnUnderpopulated
    tables = @($TableReports)
  }

  $payload | ConvertTo-Json -Depth 12 | Set-Content -Path $reportPath -Encoding UTF8
  return $reportPath
}

function Write-ViewPopulationReport {
  param(
    [string]$RepoRoot,
    [string]$ScenarioSlug,
    [int]$MinimumBusinessColumns,
    [bool]$IncludeOwner,
    [bool]$IncludeStatus,
    [bool]$FailOnUnderpopulated,
    [array]$TableReports
  )

  $reportRoot = Join-Path $RepoRoot '.wizard-metrics\artifacts\views'
  New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
  $reportPath = Join-Path $reportRoot 'view-population-report.json'

  $payload = [pscustomobject]@{
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    scenarioSlug = $ScenarioSlug
    minBusinessColumnsPerView = $MinimumBusinessColumns
    includeOwnerInViews = $IncludeOwner
    includeStatusInViews = $IncludeStatus
    failIfUnderpopulatedViews = $FailOnUnderpopulated
    tables = @($TableReports)
  }

  $payload | ConvertTo-Json -Depth 14 | Set-Content -Path $reportPath -Encoding UTF8
  return $reportPath
}

function Invoke-WizardFormsViewsBuild {
  param(
    [string]$EnvironmentUrl,
    [string]$AccessToken,
    [string]$PublisherPrefix,
    [string]$PayloadsFolder,
    [string]$ScenarioSlug,
    [int]$MinBusinessFieldsPerForm,
    [int]$MinBusinessColumnsPerView,
    [bool]$IncludeOwnerOnForms,
    [bool]$IncludeOwnerInViews,
    [bool]$IncludeStatusInViews,
    [string]$PreferFormName,
    [string]$FormStrategy = 'auto',
    [bool]$FailIfUnderpopulatedForms,
    [bool]$FailIfUnderpopulatedViews
  )

  if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    $AccessToken = $global:DV_TOKEN
    if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) {
      $PublisherPrefix = $global:DV_PUBLISHER_PREFIX
    }
  }

  foreach ($value in @($EnvironmentUrl, $AccessToken, $PublisherPrefix)) {
    if ([string]::IsNullOrWhiteSpace($value)) {
      Write-Host 'Missing required values. Run 10-auth-connect.ps1 first.' -ForegroundColor Red
      return 1
    }
  }

  if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path $repoRoot 'payloads'
  }

  if (-not (Test-Path $PayloadsFolder)) {
    Write-Host "Payload folder not found: $PayloadsFolder" -ForegroundColor Red
    Write-Host "Expected payload location is the repo root 'payloads/' folder." -ForegroundColor Yellow
    return 1
  }

  if ($MinBusinessFieldsPerForm -lt 0) {
    Write-Host 'MinBusinessFieldsPerForm must be zero or greater.' -ForegroundColor Red
    return 1
  }

  if ($MinBusinessColumnsPerView -lt 0) {
    Write-Host 'MinBusinessColumnsPerView must be zero or greater.' -ForegroundColor Red
    return 1
  }

  $scenarioContext = Get-ScenarioContext -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug
  $resolvedFormStrategy = $FormStrategy
  if ($resolvedFormStrategy -eq 'auto') {
    $resolvedFormStrategy = 'legacy'
    if ($null -ne $scenarioContext -and (Get-Command Get-WizardAppModuleConfig -ErrorAction SilentlyContinue)) {
      try {
        $appConfig = Get-WizardAppModuleConfig -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -PayloadsFolder $PayloadsFolder -PublisherPrefix $PublisherPrefix
        if (@('create-new-forms', 'update-in-place') -contains $appConfig.FormStrategy) {
          $resolvedFormStrategy = $appConfig.FormStrategy
        }
      } catch {}
    }
  }
  if (Get-Command Initialize-WizardArtifactManifest -ErrorAction SilentlyContinue) {
    Initialize-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $(if ($null -eq $scenarioContext) { '' } else { $scenarioContext.ScenarioSlug }) -SolutionName $env:DV_SOLUTION_NAME -PublisherPrefix $PublisherPrefix | Out-Null
  }

  $normalizedPrefix = $PublisherPrefix.ToLowerInvariant()
  Write-Host ''
  Write-Host '=== Build Forms and Views ===' -ForegroundColor Cyan
  Write-Host "  Environment: $EnvironmentUrl"
  Write-Host "  Prefix:      $normalizedPrefix"
  Write-Host "  Payloads:    $PayloadsFolder"
  Write-Host "  Scenario:    $(if ($null -eq $scenarioContext) { 'not resolved' } else { $scenarioContext.ScenarioSlug })"
  Write-Host "  Target form: $PreferFormName"
  Write-Host "  Form strategy: $resolvedFormStrategy"
  Write-Host "  Min fields:  $MinBusinessFieldsPerForm"
  Write-Host "  Min view columns: $MinBusinessColumnsPerView"
  Write-Host "  Add owner:   $IncludeOwnerOnForms"
  Write-Host "  View owner:  $IncludeOwnerInViews"
  Write-Host "  View status: $IncludeStatusInViews"
  Write-Host ''

  $payloadEntities = @(Get-EntitiesFromPayloads -Folder $PayloadsFolder)
  if ($payloadEntities.Count -eq 0) {
    Write-Host '  No entities found in table or column payloads. Nothing to generate.' -ForegroundColor Yellow
    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
      Complete-WizardStepTelemetry -Message 'No custom entities found for forms/views build.'
    }
    return 0
  }

  $tables = @()
  foreach ($logicalName in $payloadEntities | Sort-Object) {
    try {
      $entity = Invoke-Dv -Method 'Get' -Path "EntityDefinitions(LogicalName='$logicalName')?`$select=LogicalName,PrimaryNameAttribute,PrimaryIdAttribute,MetadataId,IsCustomEntity"
      $tables += $entity
    } catch {
      Write-Host "  $logicalName (not found — skipped)" -ForegroundColor Yellow
    }
  }

  Write-Host "  Payload-declared tables found: $($tables.Count)"
  Write-Host ''

  $formsCreated = 0
  $formsUpdated = 0
  $formsSkipped = 0
  $viewsCreated = 0
  $viewsUpdated = 0
  $viewsSkipped = 0
  $failed = 0
  $underpopulatedFailures = New-Object System.Collections.Generic.List[object]
  $underpopulatedViewFailures = New-Object System.Collections.Generic.List[object]
  $formTableReports = New-Object System.Collections.Generic.List[object]
  $viewTableReports = New-Object System.Collections.Generic.List[object]

  foreach ($table in $tables) {
    $logical = (Get-PropertyValue -Object $table -Name 'LogicalName').ToLowerInvariant()
    $primary = (Get-PropertyValue -Object $table -Name 'PrimaryNameAttribute').ToLowerInvariant()
    $primaryId = (Get-PropertyValue -Object $table -Name 'PrimaryIdAttribute').ToLowerInvariant()
    Write-Host "  $logical" -ForegroundColor Cyan

    try {
      $attributes = @(Get-TableAttributesMetadata -TableLogical $logical -Prefix $normalizedPrefix)
      if ($attributes.Count -eq 0) {
        Write-Host "    Form (FAILED: unable to read table attributes for '$logical')" -ForegroundColor Red
        $failed++
        continue
      }

      $attributeMap = New-AttributeMetadataMap -Attributes $attributes
      if (-not $attributeMap.ContainsKey($primary)) {
        Write-Host "    Form (FAILED: primary field '$primary' not found on '$logical')" -ForegroundColor Red
        $failed++
        continue
      }

      $primaryLabel = Get-PrimaryFieldLabel -TableLogical $logical -PrimaryField $primary -Prefix $normalizedPrefix
      $payloadFields = @(Get-PayloadFieldsForTable -Folder $PayloadsFolder -TableLogical $logical -Prefix $normalizedPrefix)
      $selection = Get-DesiredFormFields -PrimaryField $primary -PrimaryLabel $primaryLabel -PrimaryIdField $primaryId -PayloadFields $payloadFields -Attributes $attributes -MinimumBusinessFields $MinBusinessFieldsPerForm -IncludeOwner $IncludeOwnerOnForms
      $orderedFields = @($selection.Fields)
      $skippedFields = @($selection.SkippedFields)
      $missingExpectedFields = @($selection.MissingExpectedFields)

      $existingForms = @((Invoke-Dv -Method 'Get' -Path "systemforms?`$select=formid,name,type,formxml&`$filter=objecttypecode eq '$logical' and type eq 2").value)
      $targetForm = Get-TargetMainForm -ExistingForms $existingForms -PreferredFormName $PreferFormName -FormStrategy $resolvedFormStrategy
      $targetFormName = if ($null -eq $targetForm) { $PreferFormName } else { $targetForm.name }
      $formAction = 'skipped'

      if ($null -eq $targetForm) {
        $formAction = 'created'
        $mergeResult = Merge-FieldsIntoFormXml -ExistingFormXml '' -DesiredFields $orderedFields
        $formBody = @{
          name           = $PreferFormName
          objecttypecode = $logical
          type           = 2
          formxml        = $mergeResult.FormXml
        } | ConvertTo-Json -Compress
        Invoke-Dv -Method 'Post' -Path 'systemforms' -Body $formBody | Out-Null
        Write-Host "    Form ($PreferFormName created)" -ForegroundColor Green
        $formsCreated++
        $currentFormXml = $mergeResult.FormXml
      } else {
        $mergeResult = Merge-FieldsIntoFormXml -ExistingFormXml $targetForm.formxml -DesiredFields $orderedFields
        $currentFormXml = $mergeResult.FormXml
        if ($targetForm.formxml -ne $mergeResult.FormXml) {
          $patchBody = @{ formxml = $mergeResult.FormXml } | ConvertTo-Json -Compress
          Invoke-Dv -Method 'Patch' -Path "systemforms($($targetForm.formid))" -Body $patchBody | Out-Null
          Write-Host "    Form (updated $targetFormName with missing controls)" -ForegroundColor Green
          $formsUpdated++
          $formAction = 'updated'
        } else {
          Write-Host "    Form ($targetFormName already contains expected controls — skipped)" -ForegroundColor DarkGray
          $formsSkipped++
        }
      }

      $totalFieldsPlaced = (Get-UniqueControlNamesFromFormXml -FormXml $currentFormXml).Count
      $businessFieldsPlaced = Get-BusinessFieldCountFromFormXml -FormXml $currentFormXml -AttributeMap $attributeMap -PrimaryField $primary -PrimaryIdField $primaryId
      $underpopulated = $businessFieldsPlaced -lt $MinBusinessFieldsPerForm

      Write-Host "    Summary: total fields placed=$totalFieldsPlaced; business fields placed=$businessFieldsPlaced" -ForegroundColor Gray
      if ($skippedFields.Count -gt 0) {
        $skipSummary = ($skippedFields | ForEach-Object { "$($_.field) [$($_.reason)]" }) -join ', '
        Write-Host "    Skipped: $skipSummary" -ForegroundColor Yellow
      } else {
        Write-Host '    Skipped: none' -ForegroundColor DarkGray
      }

      if ($underpopulated) {
        $message = "business fields placed=$businessFieldsPlaced; minimum required=$MinBusinessFieldsPerForm"
        Write-Host "    Validation: UNDER-POPULATED ($message)" -ForegroundColor Red
        $underpopulatedFailures.Add([pscustomobject]@{
          table = $logical
          form = $targetFormName
          businessFieldsPlaced = $businessFieldsPlaced
          minBusinessFieldsPerForm = $MinBusinessFieldsPerForm
        }) | Out-Null

        if ($FailIfUnderpopulatedForms) {
          $failed++
        }
      } else {
        Write-Host '    Validation: populated' -ForegroundColor Green
      }

      $formTableReports.Add([pscustomobject]@{
        table = $logical
        formAction = $formAction
        formUsed = $targetFormName
        totalFieldsPlaced = $totalFieldsPlaced
        businessFieldsPlaced = $businessFieldsPlaced
        fieldsPlaced = @($orderedFields | ForEach-Object { $_.LogicalName })
        skippedFields = @($skippedFields)
        missingExpectedFields = @($missingExpectedFields)
        underpopulated = $underpopulated
      }) | Out-Null

      if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        $manifestStatus = if ($underpopulated -and $FailIfUnderpopulatedForms) { 'failed' } else { $formAction }
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $(if ($null -eq $scenarioContext) { '' } else { $scenarioContext.ScenarioSlug }) -SolutionName $env:DV_SOLUTION_NAME -PublisherPrefix $PublisherPrefix -Kind 'form' -Name "$logical|main" -Status $manifestStatus -Step '60-build-forms-views.ps1' -Details @{ formName = $targetFormName; businessFieldsPlaced = $businessFieldsPlaced; underpopulated = $underpopulated } | Out-Null
      }
    } catch {
      Write-Host "    Form (FAILED: $($_.Exception.Message))" -ForegroundColor Red
      if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $(if ($null -eq $scenarioContext) { '' } else { $scenarioContext.ScenarioSlug }) -SolutionName $env:DV_SOLUTION_NAME -PublisherPrefix $PublisherPrefix -Kind 'form' -Name "$logical|main" -Status 'failed' -Step '60-build-forms-views.ps1' -Details @{ error = $_.Exception.Message } | Out-Null
      }
      $failed++
    }

    try {
      $viewSelection = Get-DesiredViewFields -TableLogical $logical -PrimaryField $primary -PrimaryLabel $primaryLabel -PrimaryIdField $primaryId -PayloadFields $payloadFields -Attributes $attributes -MinimumBusinessFields $MinBusinessColumnsPerView -IncludeOwner $IncludeOwnerInViews -IncludeStatus $IncludeStatusInViews -ScenarioContext $scenarioContext
      $desiredViewFields = @($viewSelection.Fields)
      $viewSkippedFields = @($viewSelection.SkippedFields)
      $missingExpectedViewFields = @($viewSelection.MissingExpectedFields)
      $viewName = 'Active Records'

      $existingViews = @((Invoke-Dv -Method 'Get' -Path "savedqueries?`$select=savedqueryid,name,layoutxml,fetchxml,description&`$filter=returnedtypecode eq '$logical' and querytype eq 0").value)
      $targetView = $existingViews | Where-Object { $_.name -eq $viewName } | Select-Object -First 1
      $desiredFetchXml = New-StarterViewFetchXml -TableLogical $logical -PrimaryField $primary -Fields $desiredViewFields -FilterToActiveRecords ($attributeMap.ContainsKey('statecode'))
      $desiredLayoutXml = New-StarterViewLayoutXml -Fields $desiredViewFields -PrimaryField $primary -PrimaryIdField $primaryId
      $viewAction = 'created'
      $currentFetchXml = $desiredFetchXml
      $currentLayoutXml = $desiredLayoutXml

      if ($null -eq $targetView) {
        $viewBody = @{
          name             = $viewName
          description      = $script:WizardManagedViewMarker
          returnedtypecode = $logical
          querytype        = 0
          fetchxml         = $desiredFetchXml
          layoutxml        = $desiredLayoutXml
          iscustomizable   = @{ Value = $true }
        } | ConvertTo-Json -Compress
        Invoke-Dv -Method 'Post' -Path 'savedqueries' -Body $viewBody | Out-Null
        Write-Host "    View  ($viewName created)" -ForegroundColor Green
        $viewsCreated++
      } else {
        $currentFetchXml = Get-PropertyValue -Object $targetView -Name 'fetchxml' -Default ''
        $currentLayoutXml = Get-PropertyValue -Object $targetView -Name 'layoutxml' -Default ''
        if (Test-IsWizardManagedView -View $targetView -PrimaryField $primary) {
          $viewAction = 'validated'
          if (($currentFetchXml -ne $desiredFetchXml) -or ($currentLayoutXml -ne $desiredLayoutXml) -or ((Get-PropertyValue -Object $targetView -Name 'description' -Default '') -notlike "*$script:WizardManagedViewMarker*")) {
            $patchBody = @{
              name        = $viewName
              description = $script:WizardManagedViewMarker
              fetchxml    = $desiredFetchXml
              layoutxml   = $desiredLayoutXml
            } | ConvertTo-Json -Compress
            Invoke-Dv -Method 'Patch' -Path "savedqueries($((Get-PropertyValue -Object $targetView -Name 'savedqueryid')))" -Body $patchBody | Out-Null
            Write-Host "    View  ($viewName updated)" -ForegroundColor Green
            $viewsUpdated++
            $viewAction = 'updated'
            $currentFetchXml = $desiredFetchXml
            $currentLayoutXml = $desiredLayoutXml
          } else {
            Write-Host "    View  ($viewName already matches expected columns — skipped)" -ForegroundColor DarkGray
            $viewsSkipped++
          }
        } else {
          $viewAction = 'manual-preserved'
          $viewsSkipped++
          Write-Host "    View  ($viewName exists but is not wizard-managed — preserved)" -ForegroundColor Yellow
        }
      }

      $viewAnalysis = Get-ViewPopulationAnalysis -LayoutXml $currentLayoutXml -FetchXml $currentFetchXml -AttributeMap $attributeMap -PrimaryField $primary -PrimaryIdField $primaryId -IncludeOwner $IncludeOwnerInViews -IncludeStatus $IncludeStatusInViews
      $businessViewColumns = @($viewAnalysis.BusinessColumns)
      $underpopulatedView = $businessViewColumns.Count -lt $MinBusinessColumnsPerView

      Write-Host "    View summary: business columns placed=$($businessViewColumns.Count); columns=$((@($viewAnalysis.LayoutColumns) -join ', '))" -ForegroundColor Gray
      if ($viewSkippedFields.Count -gt 0) {
        $viewSkipSummary = ($viewSkippedFields | ForEach-Object { "$($_.field) [$($_.reason)]" }) -join ', '
        Write-Host "    View skipped: $viewSkipSummary" -ForegroundColor Yellow
      } else {
        Write-Host '    View skipped: none' -ForegroundColor DarkGray
      }

      if ($missingExpectedViewFields.Count -gt 0) {
        Write-Host "    View missing expected: $($missingExpectedViewFields -join ', ')" -ForegroundColor Yellow
      } else {
        Write-Host '    View missing expected: none' -ForegroundColor DarkGray
      }

      if (($viewAnalysis.LayoutOnly.Count -gt 0) -or ($viewAnalysis.FetchOnly.Count -gt 0)) {
        Write-Host "    View XML mismatch: layout-only=[$($viewAnalysis.LayoutOnly -join ', ')]; fetch-only=[$($viewAnalysis.FetchOnly -join ', ')]" -ForegroundColor Yellow
      }

      if ($underpopulatedView) {
        Write-Host "    View validation: UNDER-POPULATED (business columns placed=$($businessViewColumns.Count); minimum required=$MinBusinessColumnsPerView)" -ForegroundColor Red
        $underpopulatedViewFailures.Add([pscustomobject]@{
          table = $logical
          view = $viewName
          businessColumnsPlaced = $businessViewColumns.Count
          minBusinessColumnsPerView = $MinBusinessColumnsPerView
        }) | Out-Null

        if ($FailIfUnderpopulatedViews) {
          $failed++
        }
      } else {
        Write-Host '    View validation: populated' -ForegroundColor Green
      }

      $viewTableReports.Add([pscustomobject]@{
        table = $logical
        viewName = $viewName
        viewAction = $viewAction
        wizardManaged = ($viewAction -ne 'manual-preserved')
        columnsPlaced = @($viewAnalysis.LayoutColumns)
        fetchColumns = @($viewAnalysis.FetchColumns)
        businessColumnsPlaced = @($businessViewColumns)
        businessColumnCount = $businessViewColumns.Count
        skippedColumns = @($viewSkippedFields)
        missingExpectedColumns = @($missingExpectedViewFields)
        layoutOnlyColumns = @($viewAnalysis.LayoutOnly)
        fetchOnlyColumns = @($viewAnalysis.FetchOnly)
        underpopulated = $underpopulatedView
      }) | Out-Null

      if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        $viewManifestStatus = if ($underpopulatedView -and $FailIfUnderpopulatedViews) { 'failed' } elseif ($viewAction -eq 'manual-preserved' -or $viewAction -eq 'validated') { 'skipped' } else { $viewAction }
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $(if ($null -eq $scenarioContext) { '' } else { $scenarioContext.ScenarioSlug }) -SolutionName $env:DV_SOLUTION_NAME -PublisherPrefix $PublisherPrefix -Kind 'view' -Name "$logical|active" -Status $viewManifestStatus -Step '60-build-forms-views.ps1' -Details @{ viewName = $viewName; businessColumnCount = $businessViewColumns.Count; underpopulated = $underpopulatedView } | Out-Null
      }
    } catch {
      Write-Host "    View  (FAILED: $($_.Exception.Message))" -ForegroundColor Red
      if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $(if ($null -eq $scenarioContext) { '' } else { $scenarioContext.ScenarioSlug }) -SolutionName $env:DV_SOLUTION_NAME -PublisherPrefix $PublisherPrefix -Kind 'view' -Name "$logical|active" -Status 'failed' -Step '60-build-forms-views.ps1' -Details @{ error = $_.Exception.Message } | Out-Null
      }
      $failed++
    }
  }

  $formReportPath = Write-FormPopulationReport -RepoRoot $repoRoot -PreferredFormName $PreferFormName -MinimumBusinessFields $MinBusinessFieldsPerForm -IncludeOwner $IncludeOwnerOnForms -FailOnUnderpopulated $FailIfUnderpopulatedForms -TableReports @($formTableReports.ToArray())
  $viewReportPath = Write-ViewPopulationReport -RepoRoot $repoRoot -ScenarioSlug $(if ($null -eq $scenarioContext) { '' } else { $scenarioContext.ScenarioSlug }) -MinimumBusinessColumns $MinBusinessColumnsPerView -IncludeOwner $IncludeOwnerInViews -IncludeStatus $IncludeStatusInViews -FailOnUnderpopulated $FailIfUnderpopulatedViews -TableReports @($viewTableReports.ToArray())

  Write-Host ''
  Write-Host '  Publishing all customizations...' -NoNewline
  try {
    Invoke-Dv -Method 'Post' -Path 'PublishAllXml' -Body '{}' | Out-Null
    Write-Host ' done.' -ForegroundColor Green
  } catch {
    Write-Host " WARNING: publish failed. Publish manually in maker portal. $($_.Exception.Message)" -ForegroundColor Yellow
  }

  Write-Host ''
  Write-Host "Form report artifact: $formReportPath"
  Write-Host "View report artifact: $viewReportPath"
  Write-Host "Forms created: $formsCreated  Forms updated: $formsUpdated  Forms skipped: $formsSkipped  Views created: $viewsCreated  Views updated: $viewsUpdated  Views skipped: $viewsSkipped  Failures: $failed"

  if ($underpopulatedFailures.Count -gt 0) {
    $failureSummary = ($underpopulatedFailures | ForEach-Object { "$($_.table) ($($_.businessFieldsPlaced)/$($_.minBusinessFieldsPerForm))" }) -join ', '
    Write-Host "Under-populated forms: $failureSummary" -ForegroundColor Red
  }

  if ($underpopulatedViewFailures.Count -gt 0) {
    $viewFailureSummary = ($underpopulatedViewFailures | ForEach-Object { "$($_.table) ($($_.businessColumnsPlaced)/$($_.minBusinessColumnsPerView))" }) -join ', '
    Write-Host "Under-populated views: $viewFailureSummary" -ForegroundColor Red
  }

  if ($failed -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
      Register-WizardStepFailure -Message 'Forms/views build failed for one or more tables.'
    }
    return 1
  }

  Write-Host ''
  Write-Host 'Build complete. Verify in Power Apps Maker at:'
  Write-Host '  https://make.powerapps.com'
  if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message 'Forms/views build completed.'
  }

  return 0
}

if (-not (Test-WizardFormsViewsSkipMain)) {
  $exitCode = Invoke-WizardFormsViewsBuild -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -PublisherPrefix $PublisherPrefix -PayloadsFolder $PayloadsFolder -ScenarioSlug $ScenarioSlug -MinBusinessFieldsPerForm $MinBusinessFieldsPerForm -MinBusinessColumnsPerView $MinBusinessColumnsPerView -IncludeOwnerOnForms $IncludeOwnerOnForms -IncludeOwnerInViews $IncludeOwnerInViews -IncludeStatusInViews $IncludeStatusInViews -PreferFormName $PreferFormName -FormStrategy $FormStrategy -FailIfUnderpopulatedForms $FailIfUnderpopulatedForms -FailIfUnderpopulatedViews $FailIfUnderpopulatedViews
  if ($MyInvocation.InvocationName -ne '.') {
    exit $exitCode
  }
}