<#
COMPONENT: Framework Maintenance Operations
FILE: scripts/bootstrap/framework-maintenance.ps1
ENVIRONMENT: PowerShell 7 | Git
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9._/-]*$')]
    [string]$Task,
    [Parameter(Mandatory)]
    [ValidateSet('modify', 'commit', 'push')]
    [string]$Operation,
    [Parameter(Mandatory)]
    [string]$FrameworkRoot,
    [Parameter(Mandatory)]
    [string[]]$ApprovedPaths,
    [hashtable]$FileUpdates = @{},
    [string]$BaseRef,
    [string]$CommitMessage,
    [switch]$ApproveModify,
    [switch]$ApproveCommit,
    [switch]$ApprovePush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$frameworkRootPath = [IO.Path]::GetFullPath($FrameworkRoot)
. (Join-Path $PSScriptRoot 'helpers/wizard-source-protection.ps1')

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
if ($identity.Remotes.Count -ne 1 -or $identity.Remotes[0] -ne 'github.com/bradlaw76/power-platform-vscode-starter') {
    throw 'Framework Maintenance Mode requires the canonical framework Git repository and an unambiguous remote.'
}
if ($approval.Branch -cne "framework-maintenance/$Task") {
    throw "Framework Maintenance Mode task '$Task' does not match the current branch '$($approval.Branch)'."
}

$approvedPathsResolved = [Collections.Generic.List[string]]::new()
foreach ($relativePath in $ApprovedPaths) {
    if ([string]::IsNullOrWhiteSpace($relativePath) -or [IO.Path]::IsPathRooted($relativePath) -or
        $relativePath -match '(^|[\\/])\.\.?([\\/]|$)') {
        throw "Framework Maintenance Mode requires a safe FrameworkRoot-relative approved path: '$relativePath'."
    }
    $resolvedPath = Resolve-WizardPhysicalPath -Path (Join-Path $frameworkRootPath $relativePath)
    if (-not (Test-WizardPathWithin -Path $resolvedPath -Root $frameworkRootPath) -or
        (Test-WizardPathWithin -Path $resolvedPath -Root (Join-Path $frameworkRootPath '.git'))) {
        throw "Framework Maintenance Mode rejected an approved path outside framework source: '$relativePath'."
    }

    $pathPart = $resolvedPath
    while (Test-WizardPathWithin -Path $pathPart -Root $frameworkRootPath) {
        if (Test-Path -LiteralPath $pathPart) {
            $item = Get-Item -LiteralPath $pathPart -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Framework Maintenance Mode rejects symbolic links and junctions in approved paths: '$relativePath'."
            }
            if ($item.PSIsContainer -and
                -not $pathPart.Equals($frameworkRootPath, [StringComparison]::OrdinalIgnoreCase) -and
                (Test-Path -LiteralPath (Join-Path $pathPart '.git'))) {
                throw "Framework Maintenance Mode rejected a path inside a nested Git repository: '$relativePath'."
            }
        }
        if ($pathPart.Equals($frameworkRootPath, [StringComparison]::OrdinalIgnoreCase)) { break }
        $pathPart = Split-Path -Parent $pathPart
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

$fileUpdatePaths = @($FileUpdates.Keys | ForEach-Object { "$_".Replace('\', '/') } | Sort-Object -Unique)
$operationCompleted = $false
if ($Operation -eq 'modify') {
    if (@(Compare-Object $approvedSet $fileUpdatePaths).Count -gt 0 -or $fileUpdatePaths.Count -ne $approvedSet.Count) {
        throw 'Framework Maintenance Mode modifications must supply content for exactly the approved paths.'
    }
    $encoding = [Text.UTF8Encoding]::new($false)
    if ($PSCmdlet.ShouldProcess(($approvedSet -join ', '), "Write approved framework files for task '$Task'")) {
        foreach ($relativePath in $approvedSet) {
            if ($null -eq $FileUpdates[$relativePath]) {
                throw "Framework Maintenance Mode requires text content for '$relativePath'."
            }
            $resolvedPath = Resolve-WizardPhysicalPath -Path (Join-Path $frameworkRootPath $relativePath)
            $parent = Split-Path -Parent $resolvedPath
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
            [IO.File]::WriteAllText($resolvedPath, [string]$FileUpdates[$relativePath], $encoding)
        }
        $operationCompleted = $true
    }
    $operationPaths = $approvedSet
} elseif ($Operation -eq 'commit') {
    if ($fileUpdatePaths.Count -gt 0) { throw 'Commit approval cannot include file content updates.' }
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) { throw 'Commit approval requires an explicit -CommitMessage.' }
    $operationPaths = @(& git -C $identity.Root diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to verify staged framework paths for commit approval.' }
    $operationPaths = @($operationPaths | ForEach-Object { "$_".Replace('\', '/') } | Sort-Object -Unique)
    if ($operationPaths.Count -eq 0 -or @(Compare-Object $approvedSet $operationPaths).Count -gt 0) {
        throw 'Framework Maintenance Mode commit paths must exactly match the staged paths.'
    }
    if ($PSCmdlet.ShouldProcess($identity.Root, "Commit approved framework paths: $($approvedSet -join ', ')")) {
        $commitOutput = @(& git -C $identity.Root commit -m $CommitMessage 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Framework commit failed: $($commitOutput -join "`n")" }
        $operationCompleted = $true
    }
} else {
    if ($fileUpdatePaths.Count -gt 0) { throw 'Push approval cannot include file content updates.' }
    $upstream = @(& git -C $identity.Root rev-parse --symbolic-full-name '@{upstream}' 2>$null)
    if ($LASTEXITCODE -ne 0 -or $upstream.Count -eq 0) {
        if ([string]::IsNullOrWhiteSpace($BaseRef)) {
            throw 'Framework Maintenance Mode push requires a configured upstream or explicit -BaseRef.'
        }
        $comparisonRef = $BaseRef
    } else {
        $upstreamRef = ($upstream -join "`n").Trim()
        $comparisonRef = $upstreamRef
        if (-not [string]::IsNullOrWhiteSpace($BaseRef)) {
            $shortUpstream = $upstreamRef -replace '^refs/remotes/', ''
            if ($BaseRef -cne $upstreamRef -and $BaseRef -cne $shortUpstream) {
                throw 'Explicit -BaseRef must identify the configured upstream branch.'
            }
        }
    }
    if ($comparisonRef -match '^refs/remotes/(?<remote>[^/]+)/(?<branch>.+)$') {
        $remoteName = $Matches.remote
        $remoteBranch = $Matches.branch
    } elseif ($comparisonRef -match '^(?<remote>[^/]+)/(?<branch>.+)$') {
        $remoteName = $Matches.remote
        $remoteBranch = $Matches.branch
    } else {
        throw 'Push comparison reference must identify a remote-tracking branch.'
    }
    $remoteRef = "refs/remotes/$remoteName/$remoteBranch"
    $null = @(& git -C $identity.Root rev-parse --verify "$remoteRef^{commit}" 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "Unable to resolve framework push comparison ref '$remoteRef'." }
    $remoteUrls = @(& git -C $identity.Root remote get-url --all $remoteName)
    if ($LASTEXITCODE -ne 0 -or $remoteUrls.Count -eq 0) { throw "Unable to resolve push remote '$remoteName'." }
    foreach ($url in $remoteUrls) {
        if ((ConvertTo-WizardCanonicalGitRemote -Url "$url") -ne 'github.com/bradlaw76/power-platform-vscode-starter') {
            throw "Framework Maintenance Mode rejected push remote '$remoteName' because it is not the canonical framework repository."
        }
    }
    $operationPaths = @(& git -C $identity.Root diff --name-only "$remoteRef...HEAD")
    if ($LASTEXITCODE -ne 0) { throw "Unable to verify framework paths pending push against '$remoteRef'." }
    $operationPaths = @($operationPaths | ForEach-Object { "$_".Replace('\', '/') } | Sort-Object -Unique)
    if ($operationPaths.Count -eq 0 -or @(Compare-Object $approvedSet $operationPaths).Count -gt 0) {
        throw 'Framework Maintenance Mode push paths must exactly match the commits ahead of the approved upstream.'
    }
    $branch = $approval.Branch
    if ($PSCmdlet.ShouldProcess("$remoteName/$branch", "Push approved framework commits for task '$Task'")) {
        $pushOutput = @(& git -C $identity.Root push $remoteName "HEAD:refs/heads/$branch" 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Framework push failed: $($pushOutput -join "`n")" }
        $remoteHead = @(& git -C $identity.Root ls-remote $remoteName "refs/heads/$branch")
        if ($LASTEXITCODE -ne 0 -or $remoteHead.Count -eq 0 -or
            ($remoteHead[0] -split '\s+')[0] -ne ((& git -C $identity.Root rev-parse HEAD).Trim())) {
            throw 'Framework push returned success, but the remote branch did not verify at the expected commit.'
        }
        $operationCompleted = $true
    }
}

[pscustomobject]@{
    Mode = 'Framework Maintenance'
    FrameworkRoot = $frameworkRootPath
    Branch = $approval.Branch
    Operation = $Operation
    ApprovedPaths = $approvedSet
    Completed = $operationCompleted
}
