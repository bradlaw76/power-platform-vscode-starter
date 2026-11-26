<#
=============================================================================
COMPONENT:    H009 Candidate Distribution Acceptance
FILE:         scripts/ci/test-wizard-distribution.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
ENVIRONMENT:  PowerShell 7 | Python 3.10+ | Offline Git fixtures
OVERVIEW:     Verifies exact source inventories without activating distribution.
NON-NEGOTIABLES: No publisher authority, release, environment or consumer writes.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runtime = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$python = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } else { 'python' }
$env:PYTHONDONTWRITEBYTECODE = '1'
& $python -m unittest discover -s (Join-Path $runtime 'scripts/ci') -p test_wizard_distribution.py -v
if ($LASTEXITCODE -ne 0) { throw "H009 distribution acceptance exited $LASTEXITCODE." }
$candidate = Join-Path $runtime 'distribution/candidate-inventory.json'
if (Test-Path -LiteralPath $candidate -PathType Leaf) {
    $inventory = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json
    & $python -B (Join-Path $runtime 'scripts/bootstrap/helpers/wizard_distribution.py') `
        --root $runtime --commit $inventory.sourceCommit `
        --policy (Join-Path $runtime 'distribution/ownership-policy.json') --verify $candidate
    if ($LASTEXITCODE -ne 0) { throw "H009 committed inventory verification exited $LASTEXITCODE." }
}
