<#
=============================================================================
COMPONENT:    FAST Disabled Compatibility Tests
FILE:         scripts/ci/test-fast-disabled-compatibility.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Credential-free CI
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$registry = Get-Content -LiteralPath (Join-Path $repoRoot 'accelerator.providers.json') -Raw | ConvertFrom-Json
if (@($registry.providers | Where-Object enabled).Count -ne 0) {
    throw 'An accelerator provider is enabled by default.'
}

$wizardProfile = Get-Content -LiteralPath (Join-Path $repoRoot 'wizard.profile.json') -Raw
if ($wizardProfile -match '(?i)\bfast\b|accelerator') {
    throw 'FAST-002 must not alter the active wizard profile.'
}

$bootstrapFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'scripts/bootstrap') -Filter '*.ps1' -File -Recurse)
foreach ($file in $bootstrapFiles) {
    $source = Get-Content -LiteralPath $file.FullName -Raw
    if ($source -match '(?i)scripts[\\/]accelerators|sync-fast-catalog|microsoft-fast') {
        throw "FAST-002 is wired into an existing wizard runtime stage: $($file.Name)"
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "fast-disabled-$([guid]::NewGuid().ToString('N'))"
$invoked = $false
try {
    try {
        & (Join-Path $repoRoot 'scripts/accelerators/sync-fast-catalog.ps1') `
            -SourceMode Live `
            -SnapshotRoot $tempRoot `
            -RequestInvoker { $script:invoked = $true; throw 'must not run' }
        throw 'Expected disabled synchronization failure.'
    } catch {
        if ($_.Exception.Message -notmatch 'disabled by default') {
            throw
        }
    }
    if ($invoked -or (Test-Path -LiteralPath $tempRoot)) {
        throw 'Disabled synchronization performed source access or wrote catalog state.'
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'FAST disabled compatibility tests passed.' -ForegroundColor Green
