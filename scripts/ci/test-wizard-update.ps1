<#
=============================================================================
COMPONENT:    H009 Cross-Platform Acceptance Runner
FILE:         scripts/ci/test-wizard-update.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
ENVIRONMENT:  PowerShell 7 | Python 3.10+ | Isolated Offline Fixtures
OVERVIEW:     Runs real updater negative/transaction tests without cloud writes.
NON-NEGOTIABLES: No remote trust activation or dependency installation.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runtime = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$python = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } else { 'python' }
$env:PYTHONDONTWRITEBYTECODE = '1'
Write-Host "H009 host: $([Runtime.InteropServices.RuntimeInformation]::OSDescription); PowerShell $($PSVersionTable.PSVersion)"
& $python --version
if ($LASTEXITCODE -ne 0) { throw 'Required H009 test Python is unavailable.' }
& $python -m unittest discover -s (Join-Path $runtime 'scripts/ci') -p test_wizard_update.py -v
if ($LASTEXITCODE -ne 0) { throw "H009 acceptance exited $LASTEXITCODE." }
