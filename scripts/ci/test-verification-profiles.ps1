<# Credential-free execution-policy tests. Real orchestrator and state helpers;
   replaced stage bodies. No authentication, PAC, or Dataverse calls are possible
   through these stubs. This is not live component or journey validation. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('wizard-profiles-' + [guid]::NewGuid().ToString('N'))
$bootstrap = Join-Path $fixture 'scripts/bootstrap'
$scenario = 'ci-profiles'
$payloads = Join-Path $fixture "payloads/scenarios/$scenario"
$planning = Join-Path $fixture "specs/$scenario"
$tokenBefore = $env:DV_TOKEN
$script:assertions = 0
function Assert-Profile {
    param([bool]$Condition, [string]$Message)
    $script:assertions++
    if (-not $Condition) { throw $Message }
}
try {
    New-Item -ItemType Directory -Path "$bootstrap/helpers",$payloads,$planning -Force | Out-Null
    foreach ($name in @('90-run-build.ps1','helpers/dataverse-runtime.ps1','helpers/wizard-run-state.ps1')) {
        Copy-Item (Join-Path $repoRoot "scripts/bootstrap/$name") (Join-Path $bootstrap $name)
    }
    foreach ($name in @('spec.md','plan.md','tasks.md')) { Set-Content (Join-Path $planning $name) 'Synthetic fixture; reports enabled' }
    foreach ($name in @('reporting-ci.json','data-ci.json','security-roles-ci.json','process-ci.json')) { Set-Content (Join-Path $payloads $name) '{}' }
    $stub = @'
[CmdletBinding()]
param($ScenarioSlug,$PayloadsFolder,$PublisherPrefixOverride,$SolutionUniqueName,
    $PublisherPrefix,$RequestInvoker,$Mode,$Phase,$PayloadFolder,
    [switch]$PreviewOnly,[switch]$FailIfSolutionHasForeignTables,
    [switch]$InventoryOnly,[switch]$EnforceExportGate)
$global:LASTEXITCODE = 0
$name = Split-Path $PSCommandPath -Leaf
[ordered]@{script=$name; preview=[bool]$PreviewOnly; inventory=[bool]$InventoryOnly; gate=[bool]$EnforceExportGate; phase=$Phase} |
    ConvertTo-Json -Compress | Add-Content (Join-Path $PSScriptRoot 'calls.jsonl')
if ((Test-Path (Join-Path $PSScriptRoot 'fail-membership')) -and $InventoryOnly) { throw 'Synthetic membership failure' }
'@
    $source = Get-Content (Join-Path $bootstrap '90-run-build.ps1') -Raw
    foreach ($match in [regex]::Matches($source, "Script = '([^']+)'")) {
        Set-Content (Join-Path $bootstrap $match.Groups[1].Value) $stub
    }
    $env:DV_TOKEN = 'synthetic-no-network'
    $common = @{ScenarioSlug=$scenario; EnvironmentUrl='https://fixture.invalid'; SolutionUniqueName='Fixture'; PublisherPrefix='test'}
    $summaryPath = Join-Path $fixture ".wizard-metrics/runs/$scenario/run-summary.json"
    foreach ($mode in @('Preview','Apply')) {
        foreach ($profile in @('Legacy','Acceptance','Demo')) {
            & (Join-Path $bootstrap '90-run-build.ps1') @common -Mode $mode -VerificationProfile $profile
            $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
            Assert-Profile ($summary.verificationProfile -eq $profile) 'Summary lost verification profile.'
            $skip = $profile -eq 'Demo'
            foreach ($stage in @('idempotency-baseline','rerun-forms-views','rerun-native-reporting','rerun-app-module','rerun-synthetic-data','rerun-security-roles','idempotency-verification','unmanaged-export')) {
                $result = @($summary.stages | Where-Object name -eq $stage)[0]
                Assert-Profile (($result.status -eq 'skipped') -eq $skip) "$mode/$profile unexpected policy for $stage"
            }
            foreach ($stage in @('validate','tables','columns','relationships','solution','forms-views','native-reporting','app-module','synthetic-data','security-roles','solution-membership-final','post-build')) {
                $result = @($summary.stages | Where-Object name -eq $stage)[0]
                Assert-Profile ($result.status -in @('planned','completed')) "$mode/$profile bypassed required $stage"
            }
        }
    }
    foreach ($option in @('VerifyIdempotency','ExportSolution','Both')) {
        $selected = @{}
        if ($option -in @('VerifyIdempotency','Both')) { $selected.VerifyIdempotency = $true }
        if ($option -in @('ExportSolution','Both')) { $selected.ExportSolution = $true }
        & (Join-Path $bootstrap '90-run-build.ps1') @common -Mode Apply -VerificationProfile Demo @selected
        $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
        Assert-Profile ((@($summary.stages | Where-Object name -eq 'unmanaged-export')[0].status -eq 'completed') -eq $selected.ContainsKey('ExportSolution')) 'Export opt-in is not independent.'
        Assert-Profile ((@($summary.stages | Where-Object name -eq 'idempotency-verification')[0].status -eq 'completed') -eq $selected.ContainsKey('VerifyIdempotency')) 'Rerun opt-in is not independent.'
    }
    # Preserve the original positional interface when new policy is unspecified.
    & (Join-Path $bootstrap '90-run-build.ps1') $scenario Apply 'https://fixture.invalid' Fixture test
    $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    Assert-Profile ($summary.scope.environmentUrl -eq 'https://fixture.invalid' -and $summary.scope.solutionUniqueName -eq 'Fixture') 'Original positional binding changed.'
    & (Join-Path $bootstrap '90-run-build.ps1') @common -Mode Preview -VerificationProfile Demo -VerifyIdempotency -ExportSolution
    $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    Assert-Profile ($summary.status -eq 'preview-complete') 'Preview opt-ins changed execution mode.'
    Assert-Profile (@($summary.stages | Where-Object name -eq 'rerun-forms-views')[0].status -eq 'planned') 'Preview opt-in executed a mutating stage.'
    $lastCall = @(Get-Content (Join-Path $bootstrap 'calls.jsonl') | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object script -eq '95-export-unmanaged-solution.ps1')[-1]
    Assert-Profile $lastCall.preview 'Preview export lost its PreviewOnly flag.'
    # A pre-policy saved scope hash must not be reused as current evidence.
    $statePath = Join-Path $fixture ".wizard-metrics/runs/$scenario/current-run.json"
    $state = Get-Content $statePath -Raw | ConvertFrom-Json
    $oldHashSource = "$scenario|payloads/scenarios/$scenario|https://fixture.invalid|Fixture|test"
    $state.scopeHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($oldHashSource))).ToLowerInvariant()
    $state | ConvertTo-Json -Depth 20 | Set-Content $statePath
    $rejected = $false
    try { & (Join-Path $bootstrap '90-run-build.ps1') @common -Mode Preview -Resume } catch { $rejected = $_.Exception.Message -match 'Resume state belongs' }
    Assert-Profile $rejected 'Legacy-format state was reused.'
    # Omitted profile remains Legacy; absent optional payloads never invent reruns.
    & (Join-Path $bootstrap '90-run-build.ps1') @common -Mode Apply
    $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    Assert-Profile ($summary.verificationProfile -eq 'Legacy') 'Default profile changed.'
    Assert-Profile (@($summary.stages | Where-Object name -eq 'unmanaged-export')[0].status -eq 'completed') 'Default export changed.'
    foreach ($name in @('reporting-ci.json','data-ci.json','security-roles-ci.json')) { Remove-Item (Join-Path $payloads $name) }
    foreach ($profile in @('Legacy','Acceptance','Demo')) {
        & (Join-Path $bootstrap '90-run-build.ps1') @common -Mode Apply -VerificationProfile $profile -VerifyIdempotency
        $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
        Assert-Profile (@($summary.stages | Where-Object name -eq 'idempotency-baseline')[0].status -eq 'skipped') 'Absent payload enabled unsupported reruns.'
        Assert-Profile (@($summary.stages | Where-Object name -eq 'solution-membership-final')[0].status -eq 'completed') 'Absent payload bypassed final membership.'
    }
    foreach ($name in @('reporting-ci.json','data-ci.json','security-roles-ci.json')) { Set-Content (Join-Path $payloads $name) '{}' }
    # Resume may reuse only the same mode and effective policy.
    & (Join-Path $bootstrap '90-run-build.ps1') @common -Mode Apply -VerificationProfile Demo
    foreach ($changed in @(@{VerificationProfile='Acceptance';Mode='Apply'},@{VerificationProfile='Demo';Mode='Preview'},@{VerificationProfile='Demo';Mode='Apply';ExportSolution=$true},@{VerificationProfile='Demo';Mode='Apply';VerifyIdempotency=$true})) {
        $rejected = $false
        try { & (Join-Path $bootstrap '90-run-build.ps1') @common @changed -Resume } catch { $rejected = $_.Exception.Message -match 'Resume state belongs' }
        Assert-Profile $rejected 'Cross-mode/profile/option resume was not rejected.'
    }
    $before = @(Get-Content (Join-Path $bootstrap 'calls.jsonl')).Count
    & (Join-Path $bootstrap '90-run-build.ps1') @common -Mode Apply -VerificationProfile Demo -Resume
    Assert-Profile (@(Get-Content (Join-Path $bootstrap 'calls.jsonl')).Count -eq $before) 'Same-policy resume repeated completed stages.'
    Set-Content (Join-Path $bootstrap 'fail-membership') 'fail'
    $failed = $false
    try { & (Join-Path $bootstrap '90-run-build.ps1') @common -Mode Apply -VerificationProfile Demo -ExportSolution } catch { $failed = $_.Exception.Message -match 'Synthetic membership failure' }
    Assert-Profile $failed 'Demo bypassed membership failure.'
    $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    Assert-Profile ($summary.status -eq 'failed') 'Failure not recorded.'
    Assert-Profile (@($summary.stages | Where-Object name -eq 'unmanaged-export').Count -eq 0) 'Export continued after failed membership.'
    $calls = @(Get-Content (Join-Path $bootstrap 'calls.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
    Assert-Profile (@($calls | Where-Object { $_.inventory -and -not $_.gate }).Count -eq 0) 'Membership gate was disabled.'
} finally {
    $env:DV_TOKEN = $tokenBefore
    if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force }
}
Write-Host "Verification profiles passed: $script:assertions assertions. Stage bodies stubbed; no live validation."
