<#
=============================================================================
COMPONENT:    Installed Framework Handoff
FILE:         scripts/bootstrap/09-framework-handoff.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
ENVIRONMENT:  PowerShell 7 | Python 3.11+ | Local consumer workspace
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ProjectRoot,
    [Parameter(Mandatory)] [string]$RuntimeWorkspace,
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [ValidateSet('start', 'preview', 'sync', 'enable', 'disable', 'rehearse', 'status', 'worker', 'browser', 'deploy', 'discover', 'deliver', 'feedback', 'agent-test', 'scenario', 'git-review')]
    [string]$Action = 'start',
    [string]$ContractPath,
    [string]$RecipePath,
    [string]$SnapshotPath,
    [string]$AdoptionPath,
    [string]$DeliveryContextPath,
    [string]$WorkerConfigPath,
    [string]$BrowserConfigPath,
    [string]$AuthorizationPath,
    [string]$TenantId,
    [ValidateSet('build', 'enhance', 'repair')] [string]$EntryPath,
    [ValidateSet('single-operator-demonstration', 'multi-persona-demonstration', 'production-oriented')] [string]$Fidelity,
    [string]$RequirementId,
    [string]$FeedbackPath,
    [switch]$RehearseSlice,
    [string]$AgentSuitePath,
    [string]$AgentConfigPath,
    [string]$AgentBaselinePath,
    [switch]$RepairAgentFixture,
    [ValidateSet('capture', 'replay', 'reset')] [string]$ScenarioOperation = 'replay',
    [switch]$AcceptScenario,
    [string]$GitReviewManifestPath,
    [string]$PythonExecutable = 'python',
    [string]$BuildDocument = 'BUILD.md',
    [switch]$EnableSpecKitSync
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$arguments = @(
    (Join-Path $PSScriptRoot 'helpers/framework-handoff.py'),
    '--project', $ProjectRoot, '--runtime', $RuntimeWorkspace,
    '--scenario', $ScenarioSlug, '--action', $Action.ToLowerInvariant(), '--build', $BuildDocument
)
foreach ($entry in @(
    @('--contract', $ContractPath), @('--recipe', $RecipePath),
    @('--snapshot', $SnapshotPath), @('--adoption', $AdoptionPath),
    @('--delivery', $DeliveryContextPath), @('--worker-config', $WorkerConfigPath),
    @('--browser-config', $BrowserConfigPath), @('--authorization', $AuthorizationPath), @('--tenant', $TenantId),
    @('--entry-path', $EntryPath), @('--fidelity', $Fidelity), @('--requirement', $RequirementId), @('--feedback', $FeedbackPath),
    @('--agent-suite', $AgentSuitePath), @('--agent-config', $AgentConfigPath), @('--agent-baseline', $AgentBaselinePath),
    @('--scenario-operation', $ScenarioOperation), @('--git-review-manifest', $GitReviewManifestPath)
)) {
    if (-not [string]::IsNullOrWhiteSpace($entry[1])) { $arguments += $entry }
}
if ($EnableSpecKitSync) { $arguments += '--enable-sync' }
if ($RehearseSlice) { $arguments += '--rehearse-slice' }
if ($RepairAgentFixture) { $arguments += '--repair-agent-fixture' }
if ($AcceptScenario) { $arguments += '--accept-scenario' }
& $PythonExecutable @arguments
exit $LASTEXITCODE
