<#
=============================================================================
COMPONENT:    H009 Shared Version and Update Choices
FILE:         scripts/bootstrap/04-check-wizard-update.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
ENVIRONMENT:  PowerShell 7 | Optional Python 3.10+ for on-demand updates
OVERVIEW:     Terminal and agents share one updater, offline by default.
NON-NEGOTIABLES: No hidden updates, installs, release inference or tenant work.
=============================================================================
#>
[CmdletBinding()]
param(
    [ValidateSet('Status', 'Check', 'Review', 'Update', 'Skip', 'Recover')]
    [string]$Action = 'Status',
    [string]$RuntimeRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$PythonExecutable = 'python',
    [switch]$AsJson,
    [switch]$Online,
    [switch]$Offline,
    [string]$EnvelopePath,
    [string]$SourcePath,
    [string]$FixtureRoot,
    [string]$TrustedEnvelopeSha256,
    [string]$SignaturePath,
    [string]$TrustKeyPath,
    [string]$OpenSslPath,
    [string]$PlanPath,
    [string]$ApprovedPlanSha256,
    [string]$TransactionPath,
    [switch]$InstructionMigration,
    [string]$PreviousInstructionRoot,
    [switch]$RemoveCreatedInstructions
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (($PreviousInstructionRoot -or $RemoveCreatedInstructions) -and -not $InstructionMigration) {
    throw 'PreviousInstructionRoot and RemoveCreatedInstructions require explicit InstructionMigration.'
}
if ($RemoveCreatedInstructions -and $Action -ne 'Recover') {
    throw 'RemoveCreatedInstructions requires explicit Recover and the original approved plan hash.'
}
if ($Online -and $Offline) { throw 'Choose online or offline, not both.' }
if ($Online -and $Action -ne 'Check') { throw 'Online is allowed only for an explicitly selected Check action.' }
if ($Action -eq 'Skip') {
    $result = [ordered]@{ status = 'skipped'; continueDiscovery = $true; writes = 0 }
    if ($AsJson) { $result | ConvertTo-Json } else { Write-Host 'Skipped for now; continue the existing wizard unchanged.' }
    return
}
. (Join-Path $PSScriptRoot 'helpers/wizard-version.ps1')
if ($Action -eq 'Status' -and -not $EnvelopePath -and -not $InstructionMigration) {
    if ($AsJson) { Get-WizardVersion -RuntimeRoot $RuntimeRoot | ConvertTo-Json -Depth 8 }
    else { Show-WizardVersion -RuntimeRoot $RuntimeRoot }
    return
}
if (-not (Get-Command $PythonExecutable -ErrorAction SilentlyContinue)) {
    throw 'Optional Python 3.10+ is unavailable. Update check is unavailable; ordinary discovery and Skip need no Python. No installation performed.'
}
if ($Action -eq 'Update' -and (-not $PlanPath -or -not $ApprovedPlanSha256)) {
    throw 'Review changes first; Update requires the exact saved PlanPath and ApprovedPlanSha256. No update authorized.'
}
$verbs = @{ Status = 'status'; Check = 'check'; Review = 'preview'; Update = 'apply'; Recover = 'recover' }
$arguments = @((Join-Path $PSScriptRoot 'helpers/wizard_update.py'), $verbs[$Action], '--root', $RuntimeRoot)
if ($Online) { $arguments += '--online' } else { $arguments += '--offline' }
$options = [ordered]@{
    '--envelope' = $EnvelopePath
    '--source' = $SourcePath
    '--fixture-root' = $FixtureRoot
    '--trusted-envelope-sha256' = $TrustedEnvelopeSha256
    '--signature' = $SignaturePath
    '--trust-key' = $TrustKeyPath
    '--openssl-path' = $OpenSslPath
    '--plan' = $PlanPath
    '--approved-plan-sha256' = $ApprovedPlanSha256
    '--transaction' = $TransactionPath
    '--previous-instructions' = $PreviousInstructionRoot
}
if ($InstructionMigration) {
    $arguments += @('--instruction-source', (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
}
if ($RemoveCreatedInstructions) { $arguments += '--remove-created-instructions' }
foreach ($option in $options.GetEnumerator()) {
    if ($option.Value) { $arguments += @($option.Key, $option.Value) }
}
& $PythonExecutable @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
