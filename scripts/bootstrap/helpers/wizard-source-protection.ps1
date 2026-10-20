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
    # Fail before telemetry, planning, or any application files are written.
    $null = Assert-WizardApplicationRepositoryIdentity -FrameworkRoot $roots.FrameworkRoot -TargetProjectRoot $roots.TargetProjectRoot
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
        $manifestPath = Join-Path $RepositoryPath 'wizard-framework-install.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            throw "Unable to establish Git repository identity for '$RepositoryPath'."
        }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($manifest.readOnlyDistribution -ne $true -or
            $manifest.repositoryUrl -ne 'https://github.com/bradlaw76/power-platform-vscode-starter' -or
            $manifest.commit -notmatch '^[a-f0-9]{40}$') {
            throw "Framework installation identity manifest is invalid: $manifestPath"
        }
        $root = Resolve-WizardPhysicalPath -Path $RepositoryPath
        $remoteIdentity = ConvertTo-WizardCanonicalGitRemote -Url $manifest.repositoryUrl
        return [pscustomobject]@{
            Root = $root
            CommonDirectory = Join-Path $root '.wizard-framework-install'
            Remotes = @($remoteIdentity)
            InstalledCommit = $manifest.commit
        }
    }
    $root = Resolve-WizardPhysicalPath -Path (($rootOutput -join "`n").Trim())
    $commonOutput = @(& git -C $RepositoryPath rev-parse --git-common-dir 2>$null)
    if ($LASTEXITCODE -ne 0 -or $commonOutput.Count -eq 0) {
        throw "Unable to establish Git common directory for '$RepositoryPath'."
    }
    $commonDirectory = ($commonOutput -join "`n").Trim()
    if (-not [IO.Path]::IsPathRooted($commonDirectory)) {
        $commonDirectory = Join-Path $root $commonDirectory
    }
    $commonDirectory = Resolve-WizardPhysicalPath -Path $commonDirectory

    $remoteNames = @(& git -C $RepositoryPath remote 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "Unable to list Git remotes for '$RepositoryPath'." }
    $remoteValues = [Collections.Generic.List[string]]::new()
    foreach ($remoteName in $remoteNames) {
        $fetchUrls = @(& git -C $RepositoryPath remote get-url --all "$remoteName" 2>$null)
        if ($LASTEXITCODE -ne 0) { throw "Unable to resolve fetch URL for Git remote '$remoteName'." }
        $pushUrls = @(& git -C $RepositoryPath remote get-url --push --all "$remoteName" 2>$null)
        if ($LASTEXITCODE -ne 0) { throw "Unable to resolve push URL for Git remote '$remoteName'." }
        $urls = @($fetchUrls) + @($pushUrls)
        foreach ($url in $urls) {
            $remoteIdentity = ConvertTo-WizardCanonicalGitRemote -Url "$url"
            if (-not [string]::IsNullOrWhiteSpace($remoteIdentity)) { $remoteValues.Add($remoteIdentity) }
        }
    }
    $remotes = @($remoteValues.ToArray() | Sort-Object -Unique)

    return [pscustomobject]@{ Root = $root; CommonDirectory = $commonDirectory; Remotes = @($remotes) }
}

function ConvertTo-WizardCanonicalGitRemote {
    param([Parameter(Mandatory)] [string]$Url)

    $value = $Url.Trim()
    if ($value -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://' -and
        $value -match '^(?:[^@/]+@)?(?<host>[^:/]+):(?<path>.+)$') {
        $hostName = $Matches.host
        $path = $Matches.path
        $scheme = 'ssh'
    } else {
        $uri = $null
        if (-not [Uri]::TryCreate($value, [UriKind]::Absolute, [ref]$uri) -or
            $uri.Scheme -notin @('https', 'http', 'ssh', 'git') -or
            [string]::IsNullOrWhiteSpace($uri.Host)) {
            throw "Unable to canonicalize Git remote URL '$Url'."
        }
        $hostName = $uri.IdnHost
        $path = [Uri]::UnescapeDataString($uri.AbsolutePath).TrimStart('/')
        $scheme = $uri.Scheme
        if ($uri.Port -gt 0 -and
            -not (($scheme -eq 'https' -and $uri.Port -eq 443) -or
                ($scheme -eq 'http' -and $uri.Port -eq 80) -or
                ($scheme -eq 'ssh' -and $uri.Port -eq 22) -or
                ($scheme -eq 'git' -and $uri.Port -eq 9418))) {
            $hostName = "$hostName`:$($uri.Port)"
        }
    }

    $path = $path.Trim().Trim('/')
    if ($path.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase)) {
        $path = $path.Substring(0, $path.Length - 4)
    }
    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "Git remote URL '$Url' does not identify a repository path."
    }

    $normalizedHost = $hostName.ToLowerInvariant()
    $normalizedPath = ($path -split '/' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join '/'
    if ([string]::IsNullOrWhiteSpace($normalizedPath)) {
        throw "Git remote URL '$Url' does not identify a repository path."
    }
    return "$normalizedHost/$($normalizedPath.ToLowerInvariant())"
}

function Assert-WizardApplicationRepositoryIdentity {
    param(
        [Parameter(Mandatory)] [string]$FrameworkRoot,
        [Parameter(Mandatory)] [string]$TargetProjectRoot
    )

    $frameworkIdentity = Get-WizardGitIdentity -RepositoryPath $FrameworkRoot
    $targetIdentity = Get-WizardGitIdentity -RepositoryPath $TargetProjectRoot
    if (-not $targetIdentity.Root.Equals($TargetProjectRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Application Authoring Mode requires TargetProjectRoot to identify its Git repository root."
    }
    if ($targetIdentity.CommonDirectory.Equals($frameworkIdentity.CommonDirectory, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Critical: Application Authoring Mode rejected a target sharing the framework Git directory or worktree.'
    }
    if ($targetIdentity.Root.Equals($frameworkIdentity.Root, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Critical: Application Authoring Mode rejected the framework repository as an application target.'
    }
    if ($frameworkIdentity.Remotes.Count -ne 1 -or $targetIdentity.Remotes.Count -ne 1) {
        throw 'Application Authoring Mode requires exactly one identifiable framework and target Git remote.'
    }
    $sharedRemotes = @($targetIdentity.Remotes | Where-Object { $frameworkIdentity.Remotes -contains $_ })
    if ($sharedRemotes.Count -gt 0) {
        throw 'Critical: Application Authoring Mode rejected a target sharing the framework Git remote.'
    }
    return $targetIdentity
}

function Assert-WizardApplicationGitOperation {
    param(
        [Parameter(Mandatory)] [string]$FrameworkRoot,
        [Parameter(Mandatory)] [string]$TargetProjectRoot,
        [Parameter(Mandatory)] [ValidateSet('stage', 'commit', 'push', 'pull-request')] [string]$Operation
    )

    $roots = Assert-WizardApplicationRoots -FrameworkRoot $FrameworkRoot -TargetProjectRoot $TargetProjectRoot
    $identity = Assert-WizardApplicationRepositoryIdentity -FrameworkRoot $roots.FrameworkRoot -TargetProjectRoot $roots.TargetProjectRoot
    return $identity
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
