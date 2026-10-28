<#
=============================================================================
COMPONENT:    Semantic Field Regression Tests
FILE:         scripts/ci/test-semantic-fields.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Credential-free CI
OVERVIEW:     Exercises universal semantic planning, payload and live gates.
ARCHITECTURE: Synthetic temporary workspace and injected Dataverse transport.
TEST CASES:   Every category, unrelated use cases, fail-closed drift and reruns.
NON-NEGOTIABLES: No authentication, network, production approvals or migrations.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts\bootstrap\helpers\dataverse-runtime.ps1')
. (Join-Path $repoRoot 'scripts\bootstrap\helpers\semantic-fields.ps1')
$example = Get-Content -LiteralPath (Join-Path $repoRoot 'schemas\examples\field-type-decisions.example.json') -Raw
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "semantic-fields-$([guid]::NewGuid().ToString('N'))"
$checks = 0
$environmentBefore = @{}
foreach ($name in @('DV_ENVIRONMENT_URL', 'DV_TOKEN', 'DV_SOLUTION_NAME', 'DV_PUBLISHER_PREFIX', 'WIZARD_METRICS_OPTOUT')) { $environmentBefore[$name] = [Environment]::GetEnvironmentVariable($name) }
$globalBefore = @{}
foreach ($name in @('DV_SOLUTION_NAME', 'DV_PUBLISHER_PREFIX')) {
    $variable = Get-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
    $globalBefore[$name] = @{ exists = ($null -ne $variable); value = $(if ($null -ne $variable) { $variable.Value } else { $null }) }
}
function Copy-TestValue($Value) { return ($Value | ConvertTo-Json -Depth 60 | ConvertFrom-Json -AsHashtable) }
function Assert-Test([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Assert-Blocked([scriptblock]$Action, [string]$Pattern) {
    $message = ''
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-Test ($message -match $Pattern) "Expected block '$Pattern', actual '$message'."
}
function Write-TestScenario($Plan) {
    $folder = Join-Path $testRoot "specs\$($Plan.scenarioSlug)"
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $text = "field-type-decisions.json`n| Decision | Table | Field | Business meaning | Semantic category | Bounded values? | Dataverse type | Scope or target | Rationale |`n| --- | --- | --- | --- | --- | --- | --- | --- | --- |`n"
    $exceptions = ''
    foreach ($field in $Plan.fields) {
        $scope = if ($field.Contains('choice')) { "$($field.choice.scope):$($field.choice.name)" } elseif ($field.Contains('relationship')) { $field.relationship.ReferencedEntity } else { '-' }
        $class = Get-SemanticMetadataClass $field.semanticCategory $field.expectedMetadata
        $text += "| $($field.decisionId) | $($field.table) | $($field.field) | $($field.businessMeaning) | $($field.semanticCategory) | $($field.boundedValues.ToString().ToLowerInvariant()) | $class | $scope | $($field.rationale) |`n"
        if ($field.Contains('textException')) {
            $exceptions += "`n$($field.textException.reason)`n$($field.textException.alternativeConsidered)`n$($field.textException.consequences.Values -join "`n")"
        }
    }
    $text += $exceptions
    foreach ($file in @('spec.md', 'plan.md', 'tasks.md')) { Set-Content -LiteralPath (Join-Path $folder $file) -Value $text }
    $Plan | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath (Join-Path $folder 'field-type-decisions.json')
    $payload = Join-Path $testRoot "payloads\scenarios\$($Plan.scenarioSlug)"
    New-Item -ItemType Directory -Path $payload -Force | Out-Null
    @{ TableLogicalName = $Plan.fields[0].table; Columns = @($Plan.fields | Where-Object { $_.disposition -eq 'create-column' } | ForEach-Object { $_.expectedMetadata }) } |
        ConvertTo-Json -Depth 60 | Set-Content -LiteralPath (Join-Path $payload 'columns-test.json')
    return $payload
}
function New-TestField([string]$Category, [string]$Class, [hashtable]$Metadata, [hashtable]$Config) {
    $field = Copy-TestValue (($example | ConvertFrom-Json -AsHashtable).fields[0])
    $field.field = 'sample_value'
    $field.businessMeaning = 'Synthetic value with explicitly reviewed semantics'
    $field.semanticCategory = $Category
    $field.boundedValues = $false
    $field.categoricalCandidate = $false
    $field.Remove('choice')
    $field.typeConfig = $Config
    $field.expectedMetadata = @{
        '@odata.type' = "Microsoft.Dynamics.CRM.${Class}AttributeMetadata"
        SchemaName = $field.field
        DisplayName = @{ LocalizedLabels = @(@{ Label = 'Value'; LanguageCode = 1033 }) }
        RequiredLevel = @{ Value = 'None' }
    }
    foreach ($key in $Metadata.Keys) { $field.expectedMetadata[$key] = $Metadata[$key] }
    return $field
}
try {
    New-Item -ItemType Directory -Path (Join-Path $testRoot 'schemas\payloads') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'schemas\payloads\field-type-decisions.schema.json') -Destination (Join-Path $testRoot 'schemas\payloads')
    $plan = $example | ConvertFrom-Json -AsHashtable
    $payload = Write-TestScenario $plan
    $planDoc = Join-Path $testRoot "specs\$($plan.scenarioSlug)\plan.md"
    (Get-Content -LiteralPath $planDoc -Raw).Replace('| choice |', '| free-text |') | Set-Content -LiteralPath $planDoc
    Assert-Blocked { Read-WizardSemanticPlan $testRoot $plan.scenarioSlug } 'row differs'
    $payload = Write-TestScenario $plan
    $approved = Read-WizardSemanticPlan -RepoRoot $testRoot -ScenarioSlug $plan.scenarioSlug
    Assert-WizardSemanticPayloads $approved $payload
    Assert-Test ($approved.fields.Count -eq 1) 'Approved synthetic inventory did not load.'
    foreach ($useCase in @('museum-loans', 'water-quality', 'benefits-review')) {
        $domain = Copy-TestValue $plan
        $domain.scenarioSlug = $useCase
        $domain.fields[0].table = 'sample_' + $useCase.Replace('-', '')
        $domainPayload = Write-TestScenario $domain
        $domainPlan = Read-WizardSemanticPlan $testRoot $useCase
        Assert-WizardSemanticPayloads $domainPlan $domainPayload
        Assert-Test ($domainPlan.scenarioSlug -eq $useCase) 'Gate is incorrectly domain-specific.'
    }
    Assert-Blocked { Read-WizardSemanticPlan $testRoot 'missing-use-case' } 'missing.*field-type-decisions'
    $bad = Copy-TestValue $plan
    $bad.fields += Copy-TestValue $bad.fields[0]
    $null = Write-TestScenario $bad
    Assert-Blocked { Read-WizardSemanticPlan $testRoot $bad.scenarioSlug } 'Duplicate semantic'
    $payload = Write-TestScenario $plan
    Set-Content -LiteralPath (Join-Path $testRoot "specs\$($plan.scenarioSlug)\plan.md") -Value 'field-type-decisions.json'
    Assert-Blocked { Read-WizardSemanticPlan $testRoot $plan.scenarioSlug } 'missing semantic decision'
    $payload = Write-TestScenario $plan
    $bad = Copy-TestValue $plan.fields[0]
    $bad.expectedMetadata['@odata.type'] = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
    Assert-Blocked { Assert-SemanticFieldDesign $bad } 'Semantic type mismatch'
    $bad = Copy-TestValue $plan.fields[0]
    $bad.choice.options[1].value = $bad.choice.options[0].value
    Assert-Blocked { Assert-SemanticFieldDesign $bad } 'Duplicate stable'
    $bad = Copy-TestValue $plan.fields[0]
    $bad.choice.mappings.sample.entries[0].value = 999
    Assert-Blocked { Assert-SemanticFieldDesign $bad } 'unknown.*mapping'
    $bad = Copy-TestValue $plan.fields[0]
    $bad.choice.default = 999
    Assert-Blocked { Assert-SemanticFieldDesign $bad } 'Unknown Choice default'
    $bad = Copy-TestValue $plan.fields[0]
    $bad.choice.mappings.retrofit.applicable = $true
    Assert-Blocked { Assert-SemanticFieldDesign $bad } 'mapping applicability'
    $badPayload = @{ TableLogicalName = $plan.fields[0].table; Columns = @((Copy-TestValue $plan.fields[0].expectedMetadata)) }
    $badPayload.Columns[0]['@odata.type'] = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'
    $badPayload | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath (Join-Path $payload 'columns-test.json')
    Assert-Blocked { Assert-WizardSemanticPayloads $plan $payload } 'Semantic mismatch'
    $payload = Write-TestScenario $plan
    $unknown = Copy-TestValue $plan.fields[0].expectedMetadata
    $unknown.SchemaName = 'sample_unknown'
    @{ TableLogicalName = $plan.fields[0].table; Columns = @($unknown) } | ConvertTo-Json -Depth 60 |
        Set-Content -LiteralPath (Join-Path $payload 'columns-extra.json')
    Assert-Blocked { Assert-WizardSemanticPayloads $plan $payload } 'missing from semantic'
    Remove-Item -LiteralPath (Join-Path $payload 'columns-extra.json')

    $text = New-TestField 'free-text' 'String' @{ MaxLength = 100 } @{}
    $text.field = 'sample_category'
    $text.expectedMetadata.SchemaName = $text.field
    Assert-Blocked { Assert-SemanticFieldDesign $text } 'explicitly approved textException'
    $text.textException = @{
        approval = Copy-TestValue $plan.approval
        reason = 'External raw classification must be preserved for audit'
        alternativeConsidered = 'Choice and Lookup would lose the required raw representation'
        consequences = @{ reporting = 'Normalize downstream'; filtering = 'Exact raw match only'; automation = 'Explicit mapping'; integration = 'Raw code contract'; dataQuality = 'Validate at source boundary' }
    }
    $exception = Copy-TestValue $plan
    $exception.fields = @($text)
    $null = Write-TestScenario $exception
    $null = Read-WizardSemanticPlan $testRoot $exception.scenarioSlug
    Assert-Test $true 'Approved and documented exception did not pass.'
    $exception.fields[0].textException.approval.approved = $false
    $null = Write-TestScenario $exception
    Assert-Blocked { Read-WizardSemanticPlan $testRoot $exception.scenarioSlug } 'schema|JSON|approved|constant'
    $payload = Write-TestScenario $plan

    $cases = @(
        (New-TestField 'free-text' 'Memo' @{ MaxLength = 2000 } @{}),
        (New-TestField 'identifier' 'String' @{ MaxLength = 32 } @{ uniqueness = 'Source-owned'; alternateKey = 'Not needed'; caseSensitivity = 'Source exact'; formatting = 'Opaque'; leadingZeros = 'Preserve'; sourceOwnership = 'External system' }),
        (New-TestField 'whole-number' 'Integer' @{ MinValue = 0; MaxValue = 100 } @{ rounding = 'None'; unitOfMeasure = 'Items' }),
        (New-TestField 'decimal' 'Decimal' @{ Precision = 2; MinValue = 0; MaxValue = 100 } @{ rounding = 'Two decimal places'; unitOfMeasure = 'Hours' }),
        (New-TestField 'floating-point' 'Double' @{ Precision = 4; MinValue = -100; MaxValue = 100 } @{ rounding = 'Sensor precision'; unitOfMeasure = 'Meters' }),
        (New-TestField 'currency' 'Money' @{ Precision = 2; PrecisionSource = 2; MinValue = 0; MaxValue = 1000 } @{ rounding = 'Currency precision'; unitOfMeasure = 'Transaction currency'; currencyBehavior = 'Transaction currency'; baseCurrencyBehavior = 'Dataverse exchange rate' }),
        (New-TestField 'date-time' 'DateTime' @{ Format = 'DateOnly'; DateTimeBehavior = @{ Value = 'DateOnly' } } @{ precision = 'Calendar day'; integrationTimezone = 'No timezone conversion' }),
        (New-TestField 'yes-no' 'Boolean' @{ DefaultValue = $false; OptionSet = @{ TrueOption = @{ Value = 1; Label = @{ LocalizedLabels = @(@{ Label = 'Yes'; LanguageCode = 1033 }) } }; FalseOption = @{ Value = 0; Label = @{ LocalizedLabels = @(@{ Label = 'No'; LanguageCode = 1033 }) } } } } @{ logicalStates = @('Yes', 'No') }),
        (New-TestField 'file' 'File' @{ MaxSizeInKB = 1024 } @{ integration = 'Native file transfer'; storage = 'File capacity' }),
        (New-TestField 'image' 'Image' @{ MaxSizeInKB = 1024 } @{ integration = 'Native image transfer'; storage = 'Image capacity'; primaryImage = 'Not primary'; imageBehavior = 'Thumbnail with full-image storage disabled' })
    )
    foreach ($field in $cases) {
        Assert-SemanticFieldDesign $field
        $live = Copy-TestValue $field.expectedMetadata
        $live.AttributeTypeName = @{ Value = "$(Get-SemanticMetadataClass $field.semanticCategory $field.expectedMetadata)Type" }
        $reader = { param($path) $live }.GetNewClosure()
        $actual = Get-WizardSemanticLiveAttribute $field $reader
        Assert-WizardSemanticLiveField $field $actual $reader
        Assert-Test $true "Semantic category failed: $($field.semanticCategory)."
    }
    $binary = Copy-TestValue $cases[7]
    $binary.typeConfig.logicalStates += 'Unknown'
    Assert-Blocked { Assert-SemanticFieldDesign $binary } 'exactly two'
    $number = Copy-TestValue $cases[2]
    $number.expectedMetadata.MinValue = '0'
    Assert-Blocked { Assert-SemanticFieldDesign $number } 'must be a number'
    $multi = Copy-TestValue $plan.fields[0]
    $multi.semanticCategory = 'multi-select-choice'
    $multi.expectedMetadata['@odata.type'] = 'Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata'
    $multi.choice.default = $null
    $multi.expectedMetadata.Remove('DefaultFormValue')
    $multi.typeConfig = @{ relatedRecordsAlternative = 'No independent selected-record attributes'; filteringAutomationIntegrationReporting = 'Dataverse limitations reviewed and accepted' }
    Assert-SemanticFieldDesign $multi
    Assert-Test $true 'Multi-select design failed.'
    $none = Copy-TestValue $plan.fields[0]
    $none.choice.default = $null
    $none.expectedMetadata.DefaultFormValue = $null
    Assert-SemanticFieldDesign $none
    $noneLive = Copy-TestValue $none.expectedMetadata
    $noneLive.DefaultFormValue = -1
    Assert-WizardSemanticLiveField $none $noneLive {}
    Assert-Test $true 'Explicit no-default Choice should accept Dataverse null/-1 representations.'
    $noneLive.DefaultFormValue = 100000000
    Assert-Blocked { Assert-WizardSemanticLiveField $none $noneLive {} } 'expected no default'
    $dateText = New-TestField 'date-time' 'String' @{ MaxLength = 100 } @{ precision = 'Source lexical precision'; integrationTimezone = 'Preserve external date expression without Dataverse conversion' }
    Assert-Blocked { Assert-SemanticFieldDesign $dateText } 'interoperability.*approved'
    $dateText.textException = Copy-TestValue $text.textException
    Assert-SemanticFieldDesign $dateText
    Assert-Test $true 'Approved date interoperability exception should not require semantic misclassification.'
    $systemState = Copy-TestValue $plan.fields[0]
    $systemState.disposition = 'reuse'
    $systemState.expectedMetadata['@odata.type'] = 'Microsoft.Dynamics.CRM.StateAttributeMetadata'
    Assert-SemanticFieldDesign $systemState
    Assert-Test ((Get-SemanticMetadataClass $systemState.semanticCategory $systemState.expectedMetadata) -ceq 'State') 'System State must retain native metadata.'
    $global = Copy-TestValue $plan.fields[0]
    $global.choice.scope = 'global'
    $global.choice.name = 'sample_sharedprocessing'
    $global.expectedMetadata.Remove('OptionSet')
    $global.expectedMetadata['GlobalOptionSet@odata.bind'] = "/GlobalOptionSetDefinitions(Name='sample_sharedprocessing')"
    Assert-SemanticFieldDesign $global
    $globalLive = Copy-TestValue $global.expectedMetadata
    $globalLive.GlobalOptionSet = Copy-TestValue $plan.fields[0].expectedMetadata.OptionSet
    $globalLive.GlobalOptionSet.IsGlobal = $true
    $globalLive.GlobalOptionSet.Name = 'sample_sharedprocessing'
    Assert-WizardSemanticLiveField $global $globalLive {}
    $globalLive.GlobalOptionSet.Name = 'sample_wrong'
    Assert-Blocked { Assert-WizardSemanticLiveField $global $globalLive {} } 'Configuration drift.*Name'
    $lookup = New-TestField 'lookup' 'Lookup' @{} @{ cardinality = 'Many to one'; requiredness = 'Optional'; existingOrNew = 'New'; supportingTask = 'Assign governed owner' }
    $lookup.disposition = 'create-relationship'
    $lookup.relationship = @{ SchemaName = 'sample_department_workitem'; ReferencedEntity = 'sample_department'; ReferencingEntity = $lookup.table; ReferencingAttribute = $lookup.field; CascadeConfiguration = @{ Delete = 'Restrict' } }
    Assert-SemanticFieldDesign $lookup
    $lookupLive = Copy-TestValue $lookup.expectedMetadata
    $lookupLive.Targets = @('sample_department')
    $relationshipReader = { param($path) @{ value = @($lookup.relationship) } }.GetNewClosure()
    Assert-WizardSemanticLiveField $lookup $lookupLive $relationshipReader
    $lookupLive.Targets = @('sample_vendor')
    Assert-Blocked { Assert-WizardSemanticLiveField $lookup $lookupLive $relationshipReader } 'Configuration drift.*Targets'
    $wrongType = { param($path) @{ AttributeTypeName = @{ Value = 'StringType' } } }
    Assert-Blocked { Get-WizardSemanticLiveAttribute $plan.fields[0] $wrongType } 'expected PicklistType; actual StringType'
    Assert-Blocked { Get-WizardSemanticLiveAttribute $plan.fields[0] { throw 'HTTP 403 forbidden' } -AllowMissing } '403'
    $missing = Get-WizardSemanticLiveAttribute $plan.fields[0] { throw 'HTTP 404 not found' } -AllowMissing
    Assert-Test ($null -eq $missing) 'Only a real 404 may indicate absence.'
    Assert-Blocked { Get-WizardSemanticLiveAttribute $plan.fields[0] { throw 'transport unavailable' } -AllowMissing } 'transport unavailable'
    Assert-Blocked { Get-WizardSemanticLiveAttribute $plan.fields[0] { throw "Dataverse request failed (Get EntityDefinitions(LogicalName='sample_404'), HTTP 403): forbidden" } -AllowMissing } '403'
    Assert-Blocked { Get-WizardSemanticLiveAttribute $plan.fields[0] { throw "Dataverse request failed (Get EntityDefinitions(LogicalName='sample_404'), HTTP 0): transport failed" } -AllowMissing } 'transport failed'
    $liveChoice = Copy-TestValue $plan.fields[0].expectedMetadata
    $liveChoice.OptionSet.Options[0].Label.LocalizedLabels[0].Label = 'Wrong'
    Assert-Blocked { Assert-WizardSemanticLiveField $plan.fields[0] $liveChoice {} } 'Configuration drift.*Label'
    $payload = Write-TestScenario $plan
    @{ Enabled = $true; Tables = @(@{ TableLogicalName = $plan.fields[0].table; Records = @(@{ Values = @{ sample_processing = 'Unknown' } }) }) } |
        ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $payload 'data-test.json')
    Assert-Blocked { Assert-WizardSemanticPayloads $plan $payload } 'Unknown or nonnumeric seed'
    Remove-Item -LiteralPath (Join-Path $payload 'data-test.json')

    $bootstrap = Join-Path $testRoot 'scripts\bootstrap'
    New-Item -ItemType Directory -Path $bootstrap -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\bootstrap\helpers') -Destination $bootstrap -Recurse
    Copy-Item -LiteralPath (Join-Path $repoRoot 'wizard.profile.json') -Destination $testRoot
    Copy-Item -LiteralPath (Join-Path $repoRoot 'repository-updates.json') -Destination $testRoot
    Copy-Item -LiteralPath (Join-Path $repoRoot 'schemas\repository-updates') -Destination (Join-Path $testRoot 'schemas') -Recurse
    foreach ($script in @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'scripts\bootstrap') -Filter '*.ps1' -File)) {
        if ($script.Name -in @('14-validate-semantic-fields.ps1', '30-build-columns.ps1', '90-run-build.ps1')) {
            Copy-Item -LiteralPath $script.FullName -Destination $bootstrap
        } else {
            $stub = 'Add-Content -LiteralPath (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) ''stages.log'') -Value ''' + $script.Name + '''; $global:LASTEXITCODE = 0'
            Set-Content -LiteralPath (Join-Path $bootstrap $script.Name) -Value $stub
        }
    }
    $env:DV_ENVIRONMENT_URL = 'https://semantic-tests.invalid'
    $env:DV_TOKEN = 'synthetic-token-not-a-credential'
    $env:DV_SOLUTION_NAME = 'SemanticTest'
    $env:DV_PUBLISHER_PREFIX = 'sample'
    $env:WIZARD_METRICS_OPTOUT = '1'
    $global:DV_SOLUTION_NAME = 'SemanticTest'
    $global:DV_PUBLISHER_PREFIX = 'sample'
    $global:LASTEXITCODE = 0
    $payload = Write-TestScenario $plan
    $state = @{ exists = $false; type = 'PicklistType'; httpStatus = 0; requests = [Collections.Generic.List[object]]::new() }
    $columnDesign = Copy-TestValue $plan.fields[0].expectedMetadata
    $transport = {
        param($request)
        $state.requests.Add($request)
        if ($state.httpStatus -ne 0) { throw "HTTP $($state.httpStatus) synthetic transport failure" }
        if ($request.Method -eq 'Get') {
            if (-not $state.exists) { throw 'HTTP 404 synthetic absent column' }
            $result = $columnDesign | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable
            $result.AttributeTypeName = @{ Value = $state.type }
            $result.MetadataId = '11111111-1111-1111-1111-111111111111'
            return $result
        }
        if ($request.Method -eq 'Post' -and $request.Uri.EndsWith('/Attributes')) { $state.exists = $true; return @{} }
        if ($request.Method -eq 'Post' -and $request.Uri.EndsWith('/PublishXml')) { return @{} }
        throw "Unexpected synthetic request: $($request.Method) $($request.Uri)"
    }.GetNewClosure()
    & (Join-Path $bootstrap '90-run-build.ps1') -ScenarioSlug $plan.scenarioSlug -Mode Preview -RequestInvoker $transport
    Assert-Test ($state.requests.Count -eq 0) 'Orchestrated Preview queried Dataverse.'
    $preview = Get-Content -LiteralPath (Join-Path $testRoot ".wizard-metrics\runs\$($plan.scenarioSlug)\run-summary.json") -Raw | ConvertFrom-Json
    Assert-Test (@($preview.stages | Where-Object { $_.name -like 'semantic-metadata*' -and $_.status -eq 'planned' }).Count -eq 2) 'Preview must plan both live gates without running them.'
    & (Join-Path $bootstrap '90-run-build.ps1') -ScenarioSlug $plan.scenarioSlug -Mode Apply -RequestInvoker $transport
    $applySummary = Get-Content -LiteralPath (Join-Path $testRoot ".wizard-metrics\runs\$($plan.scenarioSlug)\run-summary.json") -Raw | ConvertFrom-Json
    $sourceRecord = Join-Path $testRoot ".wizard-metrics\artifacts\manifest\$($plan.scenarioSlug)\runs\$($applySummary.runId)\repository-baseline.json"
    Assert-Test (Test-Path -LiteralPath $sourceRecord) 'Apply must archive a source baseline per run.'
    $archivedSource = Get-Content -LiteralPath $sourceRecord -Raw | ConvertFrom-Json
    Assert-Test ($archivedSource.scenarioSlug -eq $plan.scenarioSlug -and $archivedSource.solutionUniqueName -eq 'SemanticTest' -and
        $archivedSource.publisherPrefix -eq 'sample' -and $archivedSource.baselineId -eq $applySummary.repositoryBaseline.baselineId) 'Archived source must bind run, scenario, solution and publisher.'
    Assert-Test (@($state.requests | Where-Object { $_.Method -eq 'Post' -and $_.Uri.EndsWith('/Attributes') }).Count -eq 1) 'Stage 30 must create precisely one approved Choice.'
    $create = @($state.requests | Where-Object { $_.Method -eq 'Post' -and $_.Uri.EndsWith('/Attributes') })[0]
    Assert-Test (($create.Body | ConvertFrom-Json).'@odata.type' -ceq 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata') 'Choice was generated as a string.'
    $publish = @($state.requests | Where-Object { $_.Uri.EndsWith('/PublishXml') })
    Assert-Test ($publish.Count -eq 1 -and $publish[0].Body.Contains('<entity>sample_workitem</entity>')) 'Column creation must publish only the changed table.'
    $report = Get-Content -LiteralPath (Join-Path $testRoot ".wizard-metrics\artifacts\semantic-fields\$($plan.scenarioSlug)\metadata-report.json") -Raw | ConvertFrom-Json
    Assert-Test ($report.status -eq 'verified' -and $report.results[0].metadataId -eq '11111111-1111-1111-1111-111111111111') 'Live evidence must persist metadata type/ID.'
    $state.requests.Clear()
    & (Join-Path $bootstrap '30-build-columns.ps1') -ScenarioSlug $plan.scenarioSlug -EnvironmentUrl $env:DV_ENVIRONMENT_URL -AccessToken $env:DV_TOKEN -RequestInvoker $transport
    Assert-Test (@($state.requests | Where-Object Method -ne 'Get').Count -eq 0) 'Matching-column rerun must not create or publish.'
    $state.type = 'StringType'
    $state.requests.Clear()
    Assert-Blocked { & (Join-Path $bootstrap '90-run-build.ps1') -ScenarioSlug $plan.scenarioSlug -Mode Apply -Resume -RequestInvoker $transport } 'expected PicklistType; actual StringType'
    Assert-Test (@($state.requests | Where-Object Method -ne 'Get').Count -eq 0) 'Wrong-type existing field must block before any column mutation.'
    Assert-Blocked { & (Join-Path $bootstrap '14-validate-semantic-fields.ps1') -ScenarioSlug $plan.scenarioSlug -Mode Metadata -RequestInvoker $transport } 'Configuration drift'
    $report = Get-Content -LiteralPath (Join-Path $testRoot ".wizard-metrics\artifacts\semantic-fields\$($plan.scenarioSlug)\metadata-report.json") -Raw | ConvertFrom-Json
    Assert-Test ($report.status -eq 'blocked' -and $report.results[0].actualType -ceq 'StringType' -and $report.results[0].error.Contains('actual StringType')) 'Drift must persist expected/actual evidence.'
    $state.type = 'PicklistType'
    $state.httpStatus = 403
    Assert-Blocked { & (Join-Path $bootstrap '30-build-columns.ps1') -ScenarioSlug $plan.scenarioSlug -EnvironmentUrl $env:DV_ENVIRONMENT_URL -AccessToken $env:DV_TOKEN -RequestInvoker $transport } '403'
    $state.httpStatus = 0
    Add-Content -LiteralPath (Join-Path $testRoot "specs\$($plan.scenarioSlug)\spec.md") -Value 'Changed design bytes'
    Assert-Blocked { & (Join-Path $bootstrap '90-run-build.ps1') -ScenarioSlug $plan.scenarioSlug -Mode Apply -Resume -RequestInvoker $transport } 'Resume state belongs'

    $partialPlan = Copy-TestValue $plan
    $second = Copy-TestValue $plan.fields[0]
    $second.decisionId = 'FIELD-secondary'
    $second.field = 'sample_secondary'
    $second.choice.name = 'sample_secondary'
    $second.expectedMetadata.SchemaName = 'sample_secondary'
    $partialPlan.fields += $second
    $null = Write-TestScenario $partialPlan
    $partial = @{ columns = @{}; posts = 0; publishes = 0 }
    $partialTransport = {
        param($request)
        if ($request.Method -eq 'Get') {
            $name = [regex]::Match($request.Uri, "Attributes\(LogicalName='([^']+)'\)").Groups[1].Value
            if (-not $partial.columns.Contains($name)) { throw 'HTTP 404 synthetic absent attribute' }
            $metadata = $partial.columns[$name]
            $metadata.AttributeTypeName = @{ Value = 'PicklistType' }
            $metadata.MetadataId = '22222222-2222-2222-2222-222222222222'
            return $metadata
        }
        if ($request.Uri.EndsWith('/Attributes')) {
            $partial.posts++
            if ($partial.posts -eq 2) { throw 'HTTP 403 synthetic second-column failure' }
            $metadata = $request.Body | ConvertFrom-Json -AsHashtable
            $partial.columns[$metadata.SchemaName] = $metadata
            return @{}
        }
        if ($request.Uri.EndsWith('/PublishXml')) { $partial.publishes++; return @{} }
        throw 'Unexpected partial-build transport request.'
    }.GetNewClosure()
    Assert-Blocked { & (Join-Path $bootstrap '30-build-columns.ps1') -ScenarioSlug $plan.scenarioSlug -EnvironmentUrl $env:DV_ENVIRONMENT_URL -AccessToken $env:DV_TOKEN -RequestInvoker $partialTransport } '403'
    Assert-Test ($partial.publishes -eq 1 -and $partial.columns.Count -eq 1) 'Partial creation failure must publish and inventory only successfully created approved columns before stopping.'
    $manifest = Get-Content -LiteralPath (Join-Path $testRoot ".wizard-metrics\artifacts\manifest\$($plan.scenarioSlug)\generated-artifact-manifest.json") -Raw | ConvertFrom-Json
    $createdColumn = @($manifest.items | Where-Object { $_.name -eq 'sample_workitem.sample_processing' -and $_.status -eq 'created' })
    Assert-Test ($createdColumn.Count -eq 1 -and $createdColumn[0].details.metadataId -eq '22222222-2222-2222-2222-222222222222') 'Successfully created partial-build columns must retain metadata IDs.'

    $null = Write-TestScenario $plan
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\bootstrap\95-export-unmanaged-solution.ps1') -Destination $bootstrap -Force
    $membershipFolder = Join-Path $testRoot ".wizard-metrics\artifacts\contamination\$($plan.scenarioSlug)"
    New-Item -ItemType Directory -Path $membershipFolder -Force | Out-Null
    @{ ExportAllowed = $true; Items = @(@{ Category = 'columns'; Name = 'sample_processing'; ObjectId = '11111111-1111-1111-1111-111111111111'; ComponentType = 2; State = 'Already in solution' }) } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $membershipFolder 'solution-membership-report.json')
    $pacState = @{ calls = 0 }
    $pacTransport = {
        param([string[]]$Arguments)
        $pacState.calls++
        if ($Arguments[1] -eq 'export') {
            $path = $Arguments[[Array]::IndexOf($Arguments, '--path') + 1]
            Set-Content -LiteralPath $path -Value 'Synthetic package'
        } else {
            $folder = $Arguments[[Array]::IndexOf($Arguments, '--folder') + 1]
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
            '<ImportExportXml><SolutionManifest><UniqueName>SemanticTest</UniqueName><RootComponents><RootComponent type="2" id="11111111-1111-1111-1111-111111111111" schemaName="sample_processing" /></RootComponents></SolutionManifest></ImportExportXml>' |
                Set-Content -LiteralPath (Join-Path $folder 'Solution.xml')
        }
    }.GetNewClosure()
    $state.type = 'StringType'
    Assert-Blocked { & (Join-Path $bootstrap '95-export-unmanaged-solution.ps1') -ScenarioSlug $plan.scenarioSlug -SolutionUniqueName 'SemanticTest' -RequestInvoker $transport -PacInvoker $pacTransport } 'Configuration drift'
    Assert-Test ($pacState.calls -eq 0) 'Direct export must block drift before invoking PAC.'
    $state.type = 'PicklistType'
    & (Join-Path $bootstrap '95-export-unmanaged-solution.ps1') -ScenarioSlug $plan.scenarioSlug -SolutionUniqueName 'SemanticTest' -RequestInvoker $transport -PacInvoker $pacTransport
    Assert-Test ($pacState.calls -eq 2) 'Valid direct export must validate live semantics, then export/unpack exactly once.'

    foreach ($file in @(
        '.github\copilot-instructions.md', '.github\prompts\power-platform-demo-wizard.prompt.md',
        '.github\skills\power-platform-wizard-init\SKILL.md', '.claude\skills\power-platform-vscode-wizard\SKILL.md',
        'docs\onboarding.md', 'docs\wizard-contract-v1.md', 'README.md',
        'requirements\how-to-build-dynamics-model-driven-apps-wizard.md',
        'requirements\how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md'
    )) {
        $content = Get-Content -LiteralPath (Join-Path $repoRoot $file) -Raw
        Assert-Test ($content.Contains('semantic-field-type-standard.md')) "Missing universal standard in $file."
        Assert-Test ($content.Contains('field-type-decisions')) "Missing semantic inventory in $file."
    }
    Write-Host "Semantic field regression checks passed: $checks." -ForegroundColor Green
} finally {
    foreach ($name in $environmentBefore.Keys) { [Environment]::SetEnvironmentVariable($name, $environmentBefore[$name]) }
    foreach ($name in $globalBefore.Keys) {
        if (-not $globalBefore[$name].exists) { Remove-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue }
        else { Set-Variable -Name $name -Scope Global -Value $globalBefore[$name].value }
    }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
