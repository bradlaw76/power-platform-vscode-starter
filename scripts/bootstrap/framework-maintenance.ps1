<#
=============================================================================
COMPONENT:    Framework Maintenance Authorization Gate
FILE:         scripts/bootstrap/framework-maintenance.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
ENVIRONMENT:  PowerShell 7 | Git
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9._/-]*$')]
    [string]$Task,
    [Parameter(Mandatory)]
    [ValidateSet('modify', 'commit', 'push')]
    [string]$Operation,
    [Parameter(Mandatory)]
    [string]$FrameworkRoot,
    [string[]]$ApprovedPaths = @(),
    [switch]$ApproveModify,
    [switch]$ApproveCommit,
    [switch]$ApprovePush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$frameworkRootPath = [IO.Path]::GetFullPath($FrameworkRoot)
$helperPath = Join-Path $PSScriptRoot 'helpers/wizard-source-protection.ps1'
. $helperPath

if ($Task -match '(^|/)\.\.?(/|$)') {
    throw 'Framework Maintenance Mode rejects traversal in the task branch name.'
}

$approvalSwitch = @{
    modify = [bool]$ApproveModify
    commit = [bool]$ApproveCommit
    push = [bool]$ApprovePush
}
$unexpectedApprovals = @($approvalSwitch.Keys | Where-Object { $_ -ne $Operation -and $approvalSwitch[$_] })
if ($unexpectedApprovals.Count -gt 0) {
    throw "Framework Maintenance Mode requires separate approval; unexpected approval(s): $($unexpectedApprovals -join ', ')."
}

$approval = Assert-WizardFrameworkMaintenanceApproval -FrameworkRoot $frameworkRootPath -Operation $Operation -Approved:$approvalSwitch[$Operation]
$identity = Get-WizardGitIdentity -RepositoryPath $frameworkRootPath
if (-not $identity.Root.Equals($frameworkRootPath, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Framework Maintenance Mode requires FrameworkRoot to be the Git repository root: $frameworkRootPath"
}
if ($approval.Branch -cne "framework-maintenance/$Task") {
    throw "Framework Maintenance Mode task '$Task' does not match the current branch '$($approval.Branch)'."
}

$approvedPathsResolved = [Collections.Generic.List[string]]::new()
foreach ($relativePath in @($ApprovedPaths)) {
    if ([string]::IsNullOrWhiteSpace($relativePath) -or [IO.Path]::IsPathRooted($relativePath) -or $relativePath -match '(^|[\\/])\.\.?([\\/]|$)') {
        throw "Framework Maintenance Mode requires a safe FrameworkRoot-relative approved path: '$relativePath'."
    }
    $resolvedPath = Resolve-WizardPhysicalPath -Path (Join-Path $frameworkRootPath $relativePath)
    if (-not (Test-WizardPathWithin -Path $resolvedPath -Root $frameworkRootPath) -or
        (Test-WizardPathWithin -Path $resolvedPath -Root (Join-Path $frameworkRootPath '.git'))) {
        throw "Framework Maintenance Mode rejected an approved path outside framework source: '$relativePath'."
    }
    $approvedPathsResolved.Add([IO.Path]::GetRelativePath($frameworkRootPath, $resolvedPath).Replace('\', '/'))
}

if ($Operation -eq 'modify' -and $approvedPathsResolved.Count -eq 0) {
    throw 'Framework Maintenance Mode requires at least one explicitly approved file path for modifications.'
}
if ($Operation -ne 'modify' -and $approvedPathsResolved.Count -gt 0) {
    throw 'Commit and push approvals are separate and cannot be combined with modification path approval.'
}

[pscustomobject]@{
    Mode = 'Framework Maintenance'
    FrameworkRoot = $frameworkRootPath
    Branch = $approval.Branch
    Operation = $Operation
    ApprovedPaths = @($approvedPathsResolved.ToArray())
}
