[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)] [string]$PackagePath,
    [Parameter(Mandatory)] [string]$ExpectedSha256,
    [Parameter(Mandatory)] [string]$ExpectedCommit,
    [Parameter(Mandatory)] [string]$DestinationRoot
)

$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    if ($IsWindows) {
        $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Install the framework from an elevated PowerShell session.'
        }
        return
    }
    $uid = (& id -u).Trim()
    if ($LASTEXITCODE -ne 0 -or $uid -ne '0') {
        throw 'Install the framework as root so application-authoring users cannot modify it.'
    }
}

function Set-FrameworkReadOnlyPermissions {
    param([Parameter(Mandatory)] [string]$Path)

    if ($IsWindows) {
        $icacls = Join-Path $env:SystemRoot 'System32/icacls.exe'
        & $icacls $Path '/inheritance:r' '/grant:r' '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' '/T' '/C' | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to apply read-only framework ACLs to '$Path'."
        }
        return
    }

    $rootGroup = if ($IsMacOS) { 'wheel' } else { 'root' }
    & chown -R "root:$rootGroup" $Path
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to assign framework ownership to root: '$Path'."
    }
    & chmod -R a-w $Path
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to remove framework write permissions from '$Path'."
    }
}

if ($ExpectedSha256 -notmatch '^[A-Fa-f0-9]{64}$') {
    throw 'ExpectedSha256 must be a 64-character SHA-256 digest.'
}
if ($ExpectedCommit -notmatch '^[A-Fa-f0-9]{40}$') {
    throw 'ExpectedCommit must be a full 40-character commit SHA.'
}

$package = (Resolve-Path -LiteralPath $PackagePath).Path
$actualHash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash
if ($actualHash -ine $ExpectedSha256) {
    throw "Framework package checksum mismatch. Expected $ExpectedSha256; received $actualHash."
}

$destination = [IO.Path]::GetFullPath($DestinationRoot)
$expectedInstallBase = if ($IsWindows) {
    Join-Path $env:ProgramFiles 'Power Platform Wizard'
} elseif ($IsMacOS) {
    '/Library/Application Support/Power Platform Wizard'
} else {
    '/opt/power-platform-vscode-starter'
}
$expectedDestination = [IO.Path]::GetFullPath((Join-Path $expectedInstallBase $ExpectedCommit))
$comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
if (-not [string]::Equals($destination, $expectedDestination, $comparison)) {
    throw "DestinationRoot must be the protected versioned install path '$expectedDestination'."
}
if (Test-Path -LiteralPath $destination) {
    throw "Refusing to overwrite existing framework installation '$destination'."
}

$staging = Join-Path ([IO.Path]::GetTempPath()) ("wizard-framework-" + [guid]::NewGuid().ToString('N'))
$expanded = Join-Path $staging 'expanded'
try {
    New-Item -ItemType Directory -Path $expanded -Force -WhatIf:$false | Out-Null
    Expand-Archive -LiteralPath $package -DestinationPath $expanded -Force -WhatIf:$false
    $manifests = @(Get-ChildItem -LiteralPath $expanded -Filter 'wizard-framework-install.json' -File -Recurse)
    if ($manifests.Count -ne 1) {
        throw "Expected exactly one framework identity manifest in the package; found $($manifests.Count)."
    }

    $manifest = Get-Content -LiteralPath $manifests[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.repositoryUrl -ne 'https://github.com/bradlaw76/power-platform-vscode-starter' -or
        $manifest.commit -ine $ExpectedCommit -or
        $manifest.readOnlyDistribution -ne $true) {
        throw 'Framework package identity does not match the approved repository, commit, and read-only distribution.'
    }

    $packageRoot = $manifests[0].Directory.FullName
    if (-not $PSCmdlet.ShouldProcess($destination, "Install verified framework commit $ExpectedCommit read-only")) {
        return
    }
    Assert-Administrator
    New-Item -ItemType Directory -Path $expectedInstallBase -Force | Out-Null
    Move-Item -LiteralPath $packageRoot -Destination $destination
    Set-FrameworkReadOnlyPermissions -Path $destination
    Set-FrameworkReadOnlyPermissions -Path $expectedInstallBase
    Write-Output "Installed read-only framework commit $ExpectedCommit at '$destination'."
}
catch {
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
    }
    throw
}
finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force -WhatIf:$false
    }
}
