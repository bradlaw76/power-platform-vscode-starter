Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$workflowPath = Join-Path $repoRoot '.github/workflows/dataverse-integration.yml'
$workflow = Get-Content -LiteralPath $workflowPath -Raw

$requiredPatterns = [ordered]@{
    'Separate exact-confirmation gate' = "CONFIRMATION -cne 'I_CONFIRM_DISPOSABLE_ENVIRONMENT'"
    'Job-level confirmation condition' = "inputs.disposable_environment_confirmation == 'I_CONFIRM_DISPOSABLE_ENVIRONMENT'"
    'Slug validation before path construction' = '$env:SCENARIO_SLUG -notmatch ''^[a-z0-9]+(?:-[a-z0-9]+)*$'''
    'Unique temporary target root' = 'Join-Path $env:RUNNER_TEMP "dataverse-target-$env:GITHUB_RUN_ID-$env:GITHUB_RUN_ATTEMPT"'
    'Framework root exported explicitly' = 'WIZARD_FRAMEWORK_ROOT=$frameworkRoot'
    'Target root exported explicitly' = 'WIZARD_TARGET_PROJECT_ROOT=$targetRoot'
    'Only selected scenario payload copied' = 'Copy-Item -LiteralPath $sourcePayload'
    'Only selected scenario specification copied' = 'Copy-Item -LiteralPath $sourceSpec'
    'Target-root static preview' = '-TargetProjectRoot $env:WIZARD_TARGET_PROJECT_ROOT'
    'Target-root payload resolution' = 'Join-Path $env:WIZARD_TARGET_PROJECT_ROOT "payloads/scenarios/$env:SCENARIO_SLUG"'
    'Export written under target root' = 'Join-Path $env:WIZARD_TARGET_PROJECT_ROOT ''out'''
    'Artifacts stored outside framework checkout' = 'Join-Path $env:RUNNER_TEMP ''integration-artifacts'''
    'Artifact upload uses runner temp' = 'path: ${{ runner.temp }}/integration-artifacts'
    'Cleanup limited to target root' = 'Join-Path $env:WIZARD_TARGET_PROJECT_ROOT ''out'''
}

foreach ($check in $requiredPatterns.GetEnumerator()) {
    if (-not $workflow.Contains($check.Value)) {
        throw "Dataverse integration workflow preflight failed: $($check.Key) is missing or changed."
    }
}

$forbiddenPatterns = [ordered]@{
    'Framework-relative generated export' = 'Join-Path ''out'''
    'Framework-relative artifact root' = 'Path -Path integration-artifacts'
    'Framework-relative scenario payload' = "Join-Path 'payloads/scenarios'"
    'Framework-relative scenario specification' = "Join-Path 'specs' `$env:SCENARIO_SLUG"
    'Framework-relative raw export cleanup' = "Remove-Item -LiteralPath 'out'"
}

foreach ($check in $forbiddenPatterns.GetEnumerator()) {
    if ($workflow.Contains($check.Value)) {
        throw "Dataverse integration workflow preflight failed: $($check.Key) remains."
    }
}

Write-Host "Dataverse integration workflow preflight passed ($($requiredPatterns.Count) required checks, $($forbiddenPatterns.Count) forbidden-path checks)." -ForegroundColor Green
