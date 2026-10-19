Set-StrictMode -Version Latest

function Resolve-WizardPhysicalPath {
    param([Parameter(Mandatory)] [string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($fullPath)
    $current = $root
    $remainder = $fullPath.Substring($root.Length)
    foreach ($segment in @($remainder -split '[\\/]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $candidate = Join-Path $current $segment
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $target = $item.ResolveLinkTarget($true)
                if ($null -eq $target) {
                    throw "Unable to resolve symbolic link in protected path: $candidate"
                }
                $current = $target.FullName
            } else {
                $current = $item.FullName
            }
        } else {
            $current = $candidate
        }
    }

    return [IO.Path]::GetFullPath($current)
}

function Test-WizardPathWithin {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Root
    )

    $comparison = if ([IO.Path]::DirectorySeparatorChar -eq '\') {
        [StringComparison]::OrdinalIgnoreCase
    } else {
        [StringComparison]::Ordinal
    }
    $normalizedRoot = $Root.TrimEnd([char[]]@('\', '/'))
    if ($Path.Equals($normalizedRoot, $comparison)) { return $true }
    $prefix = $normalizedRoot + [IO.Path]::DirectorySeparatorChar
    return $Path.StartsWith($prefix, $comparison)
}

function Assert-WizardApplicationRoots {
    param(
        [Parameter(Mandatory)] [string]$FrameworkRoot,
        [Parameter(Mandatory)] [string]$TargetProjectRoot
    )

    if (-not (Test-Path -LiteralPath $FrameworkRoot -PathType Container)) {
        throw "FrameworkRoot must be an existing directory: $FrameworkRoot"
    }
    if (-not (Test-Path -LiteralPath $TargetProjectRoot -PathType Container)) {
        throw "TargetProjectRoot must be explicitly resolved to an existing directory: $TargetProjectRoot"
    }

    $framework = Resolve-WizardPhysicalPath -Path $FrameworkRoot
    $target = Resolve-WizardPhysicalPath -Path $TargetProjectRoot
    if ((Test-WizardPathWithin -Path $framework -Root $target) -or
        (Test-WizardPathWithin -Path $target -Root $framework)) {
        throw "Application Authoring Mode rejects identical or nested FrameworkRoot and TargetProjectRoot locations. FrameworkRoot='$framework'; TargetProjectRoot='$target'."
    }

    return [pscustomobject]@{
        FrameworkRoot = $framework
        TargetProjectRoot = $target
    }
}

function Initialize-WizardApplicationContext {
    param(
        [Parameter(Mandatory)] [string]$FrameworkRoot,
        [string]$TargetProjectRoot = $env:WIZARD_TARGET_PROJECT_ROOT
    )

    if ([string]::IsNullOrWhiteSpace($TargetProjectRoot)) {
        throw 'Application Authoring Mode requires an explicitly resolved TargetProjectRoot before this stage can run.'
    }
    $roots = Assert-WizardApplicationRoots -FrameworkRoot $FrameworkRoot -TargetProjectRoot $TargetProjectRoot
    foreach ($relativeRoot in @('specs', 'payloads', '.wizard-metrics', 'out', 'exports', 'solutions', 'docs')) {
        $treeRoot = Join-Path $roots.TargetProjectRoot $relativeRoot
        if (-not (Test-Path -LiteralPath $treeRoot -PathType Container)) { continue }
        $null = Assert-WizardWritablePath -Path $treeRoot -FrameworkRoot $roots.FrameworkRoot -TargetProjectRoot $roots.TargetProjectRoot
        foreach ($item in @(Get-ChildItem -LiteralPath $treeRoot -Force -Recurse -ErrorAction Stop)) {
            $physicalItem = Resolve-WizardPhysicalPath -Path $item.FullName
            if (-not (Test-WizardPathWithin -Path $physicalItem -Root $roots.TargetProjectRoot)) {
                throw "Critical: Application Authoring Mode found a symbolic-link escape from TargetProjectRoot: $($item.FullName) -> $physicalItem"
            }
            if ($item.PSIsContainer -and (Test-Path -LiteralPath (Join-Path $item.FullName '.git')) -and
                -not $physicalItem.Equals($roots.TargetProjectRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Application Authoring Mode found a nested Git repository in generated-output tree: $($item.FullName)"
            }
        }
    }
    $env:WIZARD_FRAMEWORK_ROOT = $roots.FrameworkRoot
    $env:WIZARD_TARGET_PROJECT_ROOT = $roots.TargetProjectRoot
    return $roots
}

function Assert-WizardWritablePath {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$FrameworkRoot,
        [Parameter(Mandatory)] [string]$TargetProjectRoot
    )

    $roots = Assert-WizardApplicationRoots -FrameworkRoot $FrameworkRoot -TargetProjectRoot $TargetProjectRoot
    $resolvedPath = Resolve-WizardPhysicalPath -Path $Path
    if (-not (Test-WizardPathWithin -Path $resolvedPath -Root $roots.TargetProjectRoot)) {
        throw "Application Authoring Mode blocked a write outside TargetProjectRoot: $resolvedPath"
    }
    if (Test-WizardPathWithin -Path $resolvedPath -Root $roots.FrameworkRoot) {
        throw "Critical: Application Authoring Mode blocked a write to FrameworkRoot: $resolvedPath"
    }

    $parent = Split-Path -Parent $resolvedPath
    while (-not [string]::IsNullOrWhiteSpace($parent) -and
        (Test-WizardPathWithin -Path $parent -Root $roots.TargetProjectRoot) -and
        -not $parent.Equals($roots.TargetProjectRoot, [StringComparison]::OrdinalIgnoreCase)) {
        if (Test-Path -LiteralPath (Join-Path $parent '.git')) {
            throw "Application Authoring Mode blocked an output inside a nested Git repository: $parent"
        }
        $nextParent = Split-Path -Parent $parent
        if ($nextParent -eq $parent) { break }
        $parent = $nextParent
    }

    return $resolvedPath
}

function Get-WizardGitIdentity {
    param([Parameter(Mandatory)] [string]$RepositoryPath)

    $rootOutput = @(& git -C $RepositoryPath rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or $rootOutput.Count -eq 0) {
        throw "Unable to establish Git repository identity for '$RepositoryPath'."
    }
    $root = Resolve-WizardPhysicalPath -Path (($rootOutput -join "`n").Trim())
    $remotes = @(& git -C $RepositoryPath remote get-url --all 2>$null | ForEach-Object {
        $remote = "$_".Trim()
        if ($remote -match '^git@([^:]+):(.+)$') {
            $remote = "https://$($Matches[1])/$($Matches[2])"
        }
        $remote = $remote.TrimEnd('/')
        if ($remote.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase)) {
            $remote = $remote.Substring(0, $remote.Length - 4)
        }
        $remote.ToLowerInvariant()
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    return [pscustomobject]@{ Root = $root; Remotes = @($remotes) }
}

function Assert-WizardApplicationGitOperation {
    param(
        [Parameter(Mandatory)] [string]$FrameworkRoot,
        [Parameter(Mandatory)] [string]$TargetProjectRoot,
        [Parameter(Mandatory)] [ValidateSet('stage', 'commit', 'push', 'pull-request')] [string]$Operation
    )

    $roots = Assert-WizardApplicationRoots -FrameworkRoot $FrameworkRoot -TargetProjectRoot $TargetProjectRoot
    $frameworkIdentity = Get-WizardGitIdentity -RepositoryPath $roots.FrameworkRoot
    $targetIdentity = Get-WizardGitIdentity -RepositoryPath $roots.TargetProjectRoot
    if (-not $targetIdentity.Root.Equals($roots.TargetProjectRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Application Authoring Mode requires TargetProjectRoot to be the Git repository root before $Operation."
    }
    if ($targetIdentity.Root.Equals($frameworkIdentity.Root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Critical: Application Authoring Mode rejected $Operation against the framework repository."
    }
    $sharedRemotes = @($targetIdentity.Remotes | Where-Object { $frameworkIdentity.Remotes -contains $_ })
    if ($sharedRemotes.Count -gt 0) {
        throw "Critical: Application Authoring Mode rejected $Operation because the target shares a remote with the framework repository."
    }

    return $targetIdentity
}

function Assert-WizardFrameworkMaintenanceApproval {
    param(
        [Parameter(Mandatory)] [string]$FrameworkRoot,
        [Parameter(Mandatory)] [ValidateSet('modify', 'commit', 'push')] [string]$Operation,
        [Parameter(Mandatory)] [bool]$Approved
    )

    $identity = Get-WizardGitIdentity -RepositoryPath $FrameworkRoot
    $branch = (@(& git -C $identity.Root branch --show-current 2>$null) -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or $branch -notmatch '^framework-maintenance/[a-z0-9][a-z0-9._/-]*$') {
        throw 'Framework Maintenance Mode requires a dedicated framework-maintenance/<task> branch.'
    }
    if (-not $Approved) {
        throw "Framework Maintenance Mode requires separate explicit approval for '$Operation'."
    }

    return [pscustomobject]@{ FrameworkRoot = $identity.Root; Branch = $branch; ApprovedOperation = $Operation }
}
