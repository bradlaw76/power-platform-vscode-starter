<#
COMPONENT: Native source integration regressions | VERSION: 1.0
FILE: scripts/ci/test-native-source-integration.ps1
ENVIRONMENT: PowerShell 7, offline fixtures below the repository
ARCHITECTURE: Real stages 14/30/65/90 and preflight; unrelated runner stages stubbed.
SECURITY: Synthetic approvals/transport only; no authentication, PAC or native acceptance.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixture = Join-Path $root ".wizard-metrics\native-integration-$([guid]::NewGuid().ToString('N'))"
$bootstrap = Join-Path $fixture 'scripts\bootstrap'
$profile = Get-Content (Join-Path $root 'wizard.profile.json') -Raw | ConvertFrom-Json
$checks = 0
$before = @{}
foreach ($name in @('DV_ENVIRONMENT_URL', 'DV_TOKEN', 'DV_SOLUTION_NAME', 'DV_PUBLISHER_PREFIX', 'WIZARD_METRICS_OPTOUT')) {
    $before[$name] = [Environment]::GetEnvironmentVariable($name)
}
function Assert-Integration([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Assert-IntegrationBlock([scriptblock]$Action, [string]$Pattern) {
    $message = ''
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-Integration ($message -match $Pattern) "Expected '$Pattern', received '$message'."
}
function Write-FixtureJson([string]$Path, $Value) {
    $Value | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $Path
}
try {
    $ownership = Get-Content (Join-Path $root 'distribution\ownership-policy.json') -Raw | ConvertFrom-Json
    $fixtureAssets = @($profile.capabilityPreflight.requiredSourceFiles) + @($ownership.groups | Where-Object category -in @('core-runtime', 'helper', 'schema-profile') | ForEach-Object paths)
    foreach ($name in $fixtureAssets | Sort-Object -Unique) {
        $destination = Join-Path $fixture $name
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination $destination
    }
    $runner = Join-Path $bootstrap '90-run-build.ps1'
    foreach ($match in [regex]::Matches((Get-Content $runner -Raw), "Script = '([^']+)'")) {
        if ($match.Groups[1].Value -in @('14-validate-semantic-fields.ps1', '30-build-columns.ps1', '65-build-web-resources.ps1')) { continue }
        Set-Content -LiteralPath (Join-Path $bootstrap $match.Groups[1].Value) -Value '$global:LASTEXITCODE = 0'
    }
    $semantic = Get-Content (Join-Path $root 'schemas\examples\field-type-decisions.example.json') -Raw | ConvertFrom-Json -AsHashtable
    $slug = $semantic.scenarioSlug
    $planning = Join-Path $fixture "specs\$slug"
    $payloads = Join-Path $fixture "payloads\scenarios\$slug"
    New-Item -ItemType Directory -Path $planning, $payloads -Force | Out-Null
    $field = $semantic.fields[0]
    $field.expectedMetadata.LogicalName = $field.field
    $row = "| $($field.decisionId) | $($field.table) | $($field.field) | $($field.businessMeaning) | choice | true | Picklist | $($field.choice.scope):$($field.choice.name) | $($field.rationale) |"
    $documents = "field-type-decisions.json`n| Decision | Table | Field | Business meaning | Semantic category | Bounded values? | Dataverse type | Scope or target | Rationale |`n| --- | --- | --- | --- | --- | --- | --- | --- | --- |`n$row"
    foreach ($name in @('spec.md', 'plan.md', 'tasks.md')) { Set-Content (Join-Path $planning $name) $documents }
    Write-FixtureJson (Join-Path $planning 'field-type-decisions.json') $semantic
    Write-FixtureJson (Join-Path $payloads 'columns-test.json') @{ TableLogicalName = $field.table; Columns = @($field.expectedMetadata) }
    $env:DV_ENVIRONMENT_URL = 'https://native-fixture.invalid'
    $env:DV_TOKEN = 'synthetic-not-a-credential'
    $env:DV_SOLUTION_NAME = 'NativeFixture'
    $env:DV_PUBLISHER_PREFIX = 'sample'
    $env:WIZARD_METRICS_OPTOUT = '1'
    $state = @{ exists = $false; type = 'PicklistType'; status = 0; requests = [Collections.Generic.List[object]]::new() }
    $transport = {
        param($request)
        $state.requests.Add($request)
        if ($state.status) { throw "HTTP $($state.status) synthetic failure" }
        if ($request.Method -eq 'Get') {
            if (-not $state.exists) { throw 'HTTP 404 synthetic absent column' }
            $metadata = $field.expectedMetadata | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable
            $metadata.AttributeTypeName = @{ Value = $state.type }
            $metadata.MetadataId = '11111111-1111-1111-1111-111111111111'
            return $metadata
        }
        if ($request.Uri.EndsWith('/Attributes')) { $state.exists = $true; return @{} }
        if ($request.Uri.EndsWith('/PublishXml')) { return @{} }
        throw 'Unexpected synthetic request.'
    }.GetNewClosure()
    $columns = Join-Path $bootstrap '30-build-columns.ps1'
    $global:LASTEXITCODE = 0
    & $columns -ScenarioSlug $slug -PreviewOnly -RequestInvoker $transport
    & $runner -ScenarioSlug $slug -Mode Preview -VerificationProfile Demo -RequestInvoker $transport
    Assert-Integration ($state.requests.Count -eq 0) 'Preview must be credential-free without metadata/mutation calls.'
    $summaryPath = Join-Path $fixture ".wizard-metrics\runs\$slug\run-summary.json"
    $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    Assert-Integration (@($summary.stages | Where-Object { $_.name -like 'semantic-metadata*' -and $_.status -eq 'planned' }).Count -eq 2) 'Preview must plan both Metadata gates.'
    & $runner -ScenarioSlug $slug -Mode Apply -VerificationProfile Demo -RequestInvoker $transport
    $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    $names = @($summary.stages.name)
    Assert-Integration ([Array]::IndexOf($names, 'semantic-metadata') -gt [Array]::IndexOf($names, 'relationships')) 'First Metadata gate must follow relationships.'
    Assert-Integration ([Array]::IndexOf($names, 'semantic-metadata-final') -lt [Array]::IndexOf($names, 'unmanaged-export')) 'Final Metadata gate must precede export.'
    Assert-Integration (@($state.requests | Where-Object { $_.Uri.EndsWith('/Attributes') -and $_.Method -eq 'Post' }).Count -eq 1) 'Exactly one approved Choice must be created.'
    $publish = @($state.requests | Where-Object { $_.Uri.EndsWith('/PublishXml') })
    Assert-Integration ($publish.Count -eq 1 -and $publish[0].Body.Contains('<entity>sample_workitem</entity>')) 'Publication must remain scoped.'
    $state.requests.Clear()
    & $columns -ScenarioSlug $slug -RequestInvoker $transport
    Assert-Integration (@($state.requests | Where-Object Method -ne 'Get').Count -eq 0) 'Matching rerun must not mutate.'
    $state.type = 'StringType'
    Assert-IntegrationBlock { & $runner -ScenarioSlug $slug -Mode Apply -VerificationProfile Demo -Resume -RequestInvoker $transport } 'expected PicklistType; actual StringType'
    Assert-Integration (@($state.requests | Where-Object Method -ne 'Get').Count -eq 0) 'Resumed wrong-type metadata must block before mutations.'
    $checkpoint = Get-Content (Join-Path $fixture ".wizard-metrics\runs\$slug\current-run.json") -Raw | ConvertFrom-Json
    Assert-Integration (@($checkpoint.stages | Where-Object { $_.name -eq 'post-build' -and $_.status -eq 'completed' }).Count -eq 1) 'Failed revalidation must preserve completed later-stage evidence for recovery.'
    $state.type = 'PicklistType'
    $state.status = 403
    Assert-IntegrationBlock { & $columns -ScenarioSlug $slug -RequestInvoker $transport } '403'
    $state.status = 0
    $retry = @{ calls = 0; refreshes = 0; sleeps = 0; headers = @() }
    $retryTransport = {
        param($request)
        $retry.calls++
        $retry.headers += $request.Headers.Authorization
        if ($retry.calls -eq 1) { throw 'HTTP 401 synthetic token expiry' }
        if ($retry.calls -eq 2) { throw 'HTTP 429 synthetic throttle' }
        return & $transport $request
    }.GetNewClosure()
    $refresh = { param($url) $retry.refreshes++; return 'refreshed-synthetic-token' }.GetNewClosure()
    $sleep = { param($seconds) $retry.sleeps++ }.GetNewClosure()
    & $columns -ScenarioSlug $slug -RequestInvoker $retryTransport -TokenProvider $refresh -SleepAction $sleep
    Assert-Integration ($retry.calls -eq 4 -and $retry.refreshes -eq 1 -and $retry.sleeps -eq 1 -and $retry.headers[2] -eq 'Bearer refreshed-synthetic-token') 'Real column call path must retain 401 refresh and 429 retry without auth/sleep.'
    $semantic.approval.approved = $false
    Write-FixtureJson (Join-Path $planning 'field-type-decisions.json') $semantic
    $state.requests.Clear()
    Assert-IntegrationBlock { & $runner -ScenarioSlug $slug -Mode Apply -RequestInvoker $transport } 'approval|approved'
    Assert-Integration ($state.requests.Count -eq 0) 'Unapproved semantic inputs must block before requests.'
    $semantic.approval.approved = $true
    Write-FixtureJson (Join-Path $planning 'field-type-decisions.json') $semantic
    Add-Content (Join-Path $planning 'spec.md') 'Changed input bytes'
    Assert-IntegrationBlock { & $runner -ScenarioSlug $slug -Mode Apply -VerificationProfile Demo -Resume -RequestInvoker $transport } 'Resume state belongs'
    $accelerator = Join-Path $planning 'accelerator'
    New-Item -ItemType Directory -Path $accelerator -Force | Out-Null
    Write-FixtureJson (Join-Path $accelerator 'accelerator-decision.json') @{ selectedOption = 'hybrid' }
    Assert-IntegrationBlock { & $runner -ScenarioSlug $slug -Mode Apply -RequestInvoker $transport } 'FAST-dependent'
    Remove-Item -LiteralPath $accelerator -Recurse -Force

    $requirement = 'Supervisors need processing-state counts for work items.'
    Add-Content (Join-Path $planning 'spec.md') "`n## Custom tables to create (input -> generated logical)`n- Work Item -> sample_workitem`n`n## Required Data Entities`nWork Item`n`n## Reporting Requirements`n$requirement"
    $answers = "## Reporting Selection`n- Native dashboards: no`n- HTML reports: yes`n- Decision: confirmed`n- Mapping status: approved`n"
    Set-Content (Join-Path $planning 'answers.md') $answers
    $html = Get-Content (Join-Path $root 'schemas\examples\html-reports.example.json') -Raw | ConvertFrom-Json
    $html.Approved = $true
    $html.Reports[0].TableLogicalName = 'sample_workitem'
    $html.Reports[0].Requirements[0].Excerpt = $requirement
    $html.Reports[0].Metrics[1].RequiredFields[1] = 'sample_processing'
    $definition = Join-Path $planning 'html-reports.json'
    Write-FixtureJson $definition $html
    Set-Content (Join-Path $planning 'report-mappings.md') "| sample_workitem | $($html.Reports[0].Title) | HTML | $($html.Reports[0].Placement) | sample_processing | Reviewed counts | Supervisor | Reconcile |"
    $snapshot = Join-Path $fixture 'metadata.json'
    Write-FixtureJson $snapshot @{ entities = @(@{ logicalName = 'sample_workitem'; displayName = 'Work Item'; exists = $true; primaryIdAttribute = 'sample_workitemid'; primaryNameAttribute = 'sample_name'; fields = @('sample_workitemid', 'sample_name', 'sample_processing'); rowCount = 2 }) }
    $reports = Join-Path $bootstrap '65-build-web-resources.ps1'
    $beforePreviewRequests = $state.requests.Count
    & $reports -ScenarioSlug $slug -PreviewReportQueriesOnly -MetadataSnapshotPath $snapshot -RequestInvoker $transport
    Assert-Integration ($state.requests.Count -eq $beforePreviewRequests) 'Report preview must never use the injected metadata/mutation transport.'
    $config = Get-Content (Join-Path $planning "report-artifacts\config\$slug-supervisor-report.config.json") -Raw | ConvertFrom-Json
    Assert-Integration (@($config.metrics).Count -eq 2 -and $config.report.requirements[0].Excerpt -eq $requirement) 'Generate only documented metrics and retain their requirements.'
    Assert-Integration (@($config.metrics | Where-Object key -match 'priority|owner|queue').Count -eq 0) 'Never invent generic report metrics.'
    & $runner -ScenarioSlug $slug -Mode Preview -VerificationProfile Demo -RequestInvoker $transport
    $html.Approved = $false
    Write-FixtureJson $definition $html
    foreach ($action in @({ & $reports -ScenarioSlug $slug -PreviewReportQueriesOnly -MetadataSnapshotPath $snapshot }, { & $runner -ScenarioSlug $slug -Mode Preview -RequestInvoker $transport })) {
        Assert-IntegrationBlock $action 'approval'
    }
    $html.Approved = $true
    Write-FixtureJson $definition $html
    (Get-Content (Join-Path $planning 'spec.md') -Raw).Replace($requirement, 'The requirement changed.') | Set-Content (Join-Path $planning 'spec.md')
    Assert-IntegrationBlock { & $reports -ScenarioSlug $slug -PreviewReportQueriesOnly -MetadataSnapshotPath $snapshot } 'excerpt does not match'
    Assert-IntegrationBlock { & $runner -ScenarioSlug $slug -Mode Preview -RequestInvoker $transport } 'excerpt does not match'
    Remove-Item $definition
    Assert-IntegrationBlock { & $reports -ScenarioSlug $slug -PreviewReportQueriesOnly -MetadataSnapshotPath $snapshot } 'Missing:'
    Assert-IntegrationBlock { & $runner -ScenarioSlug $slug -Mode Preview -RequestInvoker $transport } 'Missing:'
    Set-Content (Join-Path $planning 'answers.md') $answers.Replace('HTML reports: yes', 'HTML reports: no')
    Write-FixtureJson (Join-Path $payloads 'reporting-unapproved.json') @{}
    Assert-IntegrationBlock { & $runner -ScenarioSlug $slug -Mode Preview -RequestInvoker $transport } 'Native dashboards were declined'
    Remove-Item (Join-Path $payloads 'reporting-unapproved.json')
    $output = & pwsh -NoProfile -File (Join-Path $root 'scripts\bootstrap\12-check-wizard-capabilities.ps1') -RepoRoot $fixture -RequireNativeBuild
    $preflight = $output | ConvertFrom-Json
    Assert-Integration ($LASTEXITCODE -eq 0 -and $preflight.native.buildIntegrationVerified -and -not $preflight.nativeApproval) 'Preflight requires integrated source, not deployment approval.'
    $source = Get-Content $columns -Raw
    $source.Replace('Assert-WizardSemanticPayloads -Plan', 'Write-Output -Plan') | Set-Content $columns
    $output = & pwsh -NoProfile -File (Join-Path $root 'scripts\bootstrap\12-check-wizard-capabilities.ps1') -RepoRoot $fixture -RequireNativeBuild
    Assert-Integration ($LASTEXITCODE -eq 1 -and ($output | ConvertFrom-Json).native.missingHooks.Count -gt 0) 'A missing actual source hook must block preflight.'
    Set-Content $columns $source
    $policyPath = Join-Path $fixture 'distribution\ownership-policy.json'
    $policy = Get-Content $policyPath -Raw | ConvertFrom-Json
    $policy.groups[1].paths = @($policy.groups[1].paths | Where-Object { $_ -ne 'scripts/bootstrap/helpers/reporting-plan.ps1' })
    Write-FixtureJson $policyPath $policy
    $output = & pwsh -NoProfile -File (Join-Path $root 'scripts\bootstrap\12-check-wizard-capabilities.ps1') -RepoRoot $fixture -RequireNativeBuild
    Assert-Integration ($LASTEXITCODE -eq 1 -and ($output | ConvertFrom-Json).native.dependencyClosure -eq 'incomplete') 'A missing install dependency must block preflight.'
    Write-Host "Native source integration checks passed: $checks."
} finally {
    foreach ($name in $before.Keys) { [Environment]::SetEnvironmentVariable($name, $before[$name]) }
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
