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
    [string]$BaseRef = '',
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
    $parent = Split-Path -Parent $resolvedPath
    while (-not [string]::IsNullOrWhiteSpace($parent) -and
        (Test-WizardPathWithin -Path $parent -Root $frameworkRootPath) -and
        -not $parent.Equals($frameworkRootPath, [StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path -LiteralPath (Join-Path $parent '.git')) {
            throw "Framework Maintenance Mode rejected a path inside a nested Git repository: '$relativePath'."
        }
        $nextParent = Split-Path -Parent $parent
        if ($nextParent -eq $parent) { break }
        $parent = $nextParent
    }
    $approvedPathsResolved.Add([IO.Path]::GetRelativePath($frameworkRootPath, $resolvedPath).Replace('\', '/'))
}

if ($approvedPathsResolved.Count -eq 0) {
    throw "Framework Maintenance Mode requires exact approved file paths for '$Operation'."
}

$approvedSet = @($approvedPathsResolved.ToArray() | Sort-Object -Unique)
if ($approvedSet.Count -ne $approvedPathsResolved.Count) {
    throw 'Framework Maintenance Mode rejects duplicate approved file paths.'
}
if ($Operation -eq 'commit') {
    $operationPaths = @(& git -C $identity.Root diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify staged framework paths for commit approval.' }
} elseif ($Operation -eq 'push') {
    if ([string]::IsNullOrWhiteSpace($BaseRef)) {
        $upstreamOutput = @(& git -C $identity.Root rev-parse --abbrev-ref '@{upstream}' 2>$null)
        if ($LASTEXITCODE -ne 0 -or $upstreamOutput.Count -eq 0) {
            throw 'Framework Maintenance Mode push approval requires an upstream branch or an explicit -BaseRef.'
        }
        $BaseRef = ($upstreamOutput -join "`n").Trim()
    }
    $null = @(& git -C $identity.Root rev-parse --verify "$BaseRef^{commit}" 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "Framework Maintenance Mode could not resolve push comparison ref '$BaseRef'." }
    $operationPaths = @(& git -C $identity.Root diff --name-only "$BaseRef...HEAD")
    if ($LASTEXITCODE -ne 0) { throw "Unable to verify framework paths pending push against '$BaseRef'." }
} else {
    $operationPaths = $approvedSet
}
$normalizedOperationPaths = @($operationPaths | ForEach-Object { "$_".Replace('\', '/') } | Sort-Object -Unique)
if ($normalizedOperationPaths.Count -eq 0 -or
    (@(Compare-Object $approvedSet $normalizedOperationPaths).Count -gt 0)) {
    throw "Framework Maintenance Mode '$Operation' approval paths must exactly match the affected files."
}

[pscustomobject]@{
    Mode = 'Framework Maintenance'
    FrameworkRoot = $frameworkRootPath
    Branch = $approval.Branch
    Operation = $Operation
    ApprovedPaths = $approvedSet
}
