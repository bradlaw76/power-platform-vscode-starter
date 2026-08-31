<#
=============================================================================
COMPONENT:    Verify Second Run Idempotency
FILE:         scripts/bootstrap/85-verify-idempotency.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-31
ENVIRONMENT:  PowerShell 7 | Local evidence only
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [ValidateSet('CaptureBaseline', 'Verify')] [string]$Phase = 'Verify',
    [switch]$PreviewOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$artifactRoot = Join-Path $repoRoot '.wizard-metrics/artifacts'
$verificationRoot = Join-Path $artifactRoot "idempotency/$ScenarioSlug"
$baselinePath = Join-Path $verificationRoot 'baseline.json'
$resultPath = Join-Path $verificationRoot 'verification.json'

function Get-WizardEvidenceSnapshot {
    param([string]$ArtifactRoot, [string]$ScenarioSlug)
    $sources = [ordered]@{
        manifest = Join-Path $ArtifactRoot "manifest/$ScenarioSlug/generated-artifact-manifest.json"
        reporting = Join-Path $ArtifactRoot "reporting/$ScenarioSlug.json"
        data = Join-Path $ArtifactRoot "data/$ScenarioSlug.json"
        membership = Join-Path $ArtifactRoot "contamination/$ScenarioSlug/solution-membership-report.json"
    }
    $requiredSources = @('manifest', 'membership')
    $identities = [Collections.Generic.List[object]]::new()
    foreach ($sourceName in $sources.Keys) {
        $path = $sources[$sourceName]
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            if ($sourceName -in $requiredSources) { throw "Idempotency evidence is missing: $path" }
            continue
        }
        $document = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        $entries = switch ($sourceName) {
            'manifest' { @($document.items | ForEach-Object { [pscustomobject]@{ identity="manifest|$($_.kind)|$($_.name)"; id="$($_.details.id ?? $_.details.objectId ?? $_.details.ObjectId)"; action="$($_.status)" } }) }
            'reporting' { @($document.items | ForEach-Object { [pscustomobject]@{ identity="reporting|$($_.kind)|$($_.name)"; id="$($_.id)"; action="$($_.action)" } }) }
            'data' { @($document.records | ForEach-Object { [pscustomobject]@{ identity="data|$($_.table)|$($_.key)"; id="$($_.id)"; action="$($_.action)" } }) }
            'membership' { @($document.Items | Where-Object State -ne 'Unauthorized' | ForEach-Object { [pscustomobject]@{ identity="membership|$($_.Category)|$($_.Name)"; id="$($_.ObjectId)"; action="$($_.State)" } }) }
        }
        foreach ($entry in $entries) { $identities.Add($entry) }
    }
    $missingIds = @($identities | Where-Object { $_.identity -match '^(?:reporting|data|membership)\|' -and [string]::IsNullOrWhiteSpace($_.id) })
    if ($missingIds.Count -gt 0) { throw "Idempotency evidence is missing stable IDs: $($missingIds.identity -join ', ')." }
    $duplicates = @($identities | Group-Object identity | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) { throw "Duplicate idempotency identities: $($duplicates.Name -join ', ')." }
    $duplicateIds = @($identities | Where-Object { -not [string]::IsNullOrWhiteSpace($_.id) } | Group-Object identity,id | Where-Object Count -gt 1)
    if ($duplicateIds.Count -gt 0) { throw 'Duplicate identity/ID evidence was detected.' }
    return @($identities | Sort-Object identity)
}

New-Item -ItemType Directory -Path $verificationRoot -Force | Out-Null
if ($PreviewOnly) {
    [ordered]@{ scenarioSlug=$ScenarioSlug; preview=$true; phase=$Phase; status='planned' } | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding UTF8
    exit 0
}
$snapshot = @(Get-WizardEvidenceSnapshot -ArtifactRoot $artifactRoot -ScenarioSlug $ScenarioSlug)
if ($Phase -eq 'CaptureBaseline') {
    [ordered]@{ scenarioSlug=$ScenarioSlug; capturedAtUtc=[DateTime]::UtcNow.ToString('o'); identities=$snapshot } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $baselinePath -Encoding UTF8
    exit 0
}
if (-not (Test-Path -LiteralPath $baselinePath -PathType Leaf)) { throw 'Idempotency baseline is missing. Run CaptureBaseline before the second pass.' }
$baseline = Get-Content -LiteralPath $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json
$baselineByIdentity = @{}; foreach ($item in @($baseline.identities)) { $baselineByIdentity[$item.identity] = $item }
$currentByIdentity = @{}; foreach ($item in $snapshot) { $currentByIdentity[$item.identity] = $item }
$failures = [Collections.Generic.List[string]]::new()
foreach ($identity in @($baselineByIdentity.Keys + $currentByIdentity.Keys | Sort-Object -Unique)) {
    if (-not $baselineByIdentity.ContainsKey($identity)) { $failures.Add("New identity on second run: $identity"); continue }
    if (-not $currentByIdentity.ContainsKey($identity)) { $failures.Add("Missing identity on second run: $identity"); continue }
    if ($baselineByIdentity[$identity].id -cne $currentByIdentity[$identity].id) { $failures.Add("ID changed on second run: $identity") }
    if ($identity -match '^(?:reporting|data)\|' -and $currentByIdentity[$identity].action -eq 'created') { $failures.Add("Second run created a duplicate candidate: $identity") }
}
$result = [ordered]@{ scenarioSlug=$ScenarioSlug; verifiedAtUtc=[DateTime]::UtcNow.ToString('o'); stableIds=$failures.Count -eq 0; duplicateCount=0; failures=@($failures) }
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resultPath -Encoding UTF8
if ($failures.Count -gt 0) { throw "Second-run idempotency verification failed:`n - $($failures -join "`n - ")" }