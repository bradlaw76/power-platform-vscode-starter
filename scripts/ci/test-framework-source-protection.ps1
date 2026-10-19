Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts/bootstrap/helpers/wizard-source-protection.ps1')
$maintenanceScript = Join-Path $repoRoot 'scripts/bootstrap/framework-maintenance.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "wizard-source-protection-$([guid]::NewGuid().ToString('N'))"
$frameworkRoot = Join-Path $testRoot 'framework'
$targetRoot = Join-Path $testRoot 'application'
$nestedTarget = Join-Path $targetRoot 'nested'
$sharedRemote = 'https://github.com/example/wizard-framework.git'

function Invoke-TestGit {
    param([string]$WorkingDirectory, [string[]]$Arguments)
    $output = @(& git -C $WorkingDirectory @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git -C $WorkingDirectory $($Arguments -join ' ') failed: $($output -join "`n")"
    }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$ExpectedText)
    try {
        & $Action
        throw "Expected failure containing '$ExpectedText'."
    } catch {
        if ($_.Exception.Message -notmatch [regex]::Escape($ExpectedText)) { throw }
    }
}

try {
    New-Item -ItemType Directory -Path $frameworkRoot, $targetRoot -Force | Out-Null
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('init', '-b', 'framework-maintenance/test')
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('config', 'user.name', 'Source Protection Test')
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('config', 'user.email', 'source-protection@example.invalid')
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('remote', 'add', 'origin', $sharedRemote)

    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('init', '-b', 'feature/application')
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('config', 'user.name', 'Source Protection Test')
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('config', 'user.email', 'source-protection@example.invalid')
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'add', 'origin', 'https://github.com/example/application.git')

    $roots = Assert-WizardApplicationRoots -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
    $allowedPath = Join-Path $roots.TargetProjectRoot 'specs/new-app/spec.md'
    if ((Assert-WizardWritablePath -Path $allowedPath -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot) -ne $allowedPath) {
        throw 'An application output beneath TargetProjectRoot was not preserved.'
    }
    Assert-Throws {
        Assert-WizardApplicationRoots -FrameworkRoot $frameworkRoot -TargetProjectRoot $frameworkRoot
    } 'identical or nested'
    New-Item -ItemType Directory -Path (Join-Path $frameworkRoot 'nested') -Force | Out-Null
    Assert-Throws {
        Assert-WizardApplicationRoots -FrameworkRoot $frameworkRoot -TargetProjectRoot (Join-Path $frameworkRoot 'nested')
    } 'identical or nested'
    Assert-Throws {
        Assert-WizardWritablePath -Path (Join-Path $targetRoot '../escaped.txt') -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
    } 'outside TargetProjectRoot'

    $frameworkDocs = Join-Path $frameworkRoot 'docs'
    New-Item -ItemType Directory -Path $frameworkDocs -Force | Out-Null
    $frameworkLink = Join-Path $targetRoot 'framework-docs'
    New-Item -ItemType SymbolicLink -Path $frameworkLink -Target $frameworkDocs | Out-Null
    Assert-Throws {
        Assert-WizardWritablePath -Path (Join-Path $frameworkLink 'evidence.json') -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
    } 'outside TargetProjectRoot'

    New-Item -ItemType Directory -Path $nestedTarget -Force | Out-Null
    Invoke-TestGit -WorkingDirectory $nestedTarget -Arguments @('init', '-b', 'nested')
    Assert-Throws {
        Assert-WizardWritablePath -Path (Join-Path $nestedTarget 'evidence.json') -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
    } 'nested Git repository'

    $null = Assert-WizardApplicationGitOperation -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot -Operation stage
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'set-url', 'origin', $sharedRemote)
    Assert-Throws {
        Assert-WizardApplicationGitOperation -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot -Operation push
    } 'shares a remote'

    Assert-Throws {
        Assert-WizardFrameworkMaintenanceApproval -FrameworkRoot $frameworkRoot -Operation modify -Approved:$false
    } 'separate explicit approval'
    foreach ($operation in @('modify', 'commit', 'push')) {
        $approval = Assert-WizardFrameworkMaintenanceApproval -FrameworkRoot $frameworkRoot -Operation $operation -Approved:$true
        if ($approval.Branch -ne 'framework-maintenance/test' -or $approval.ApprovedOperation -ne $operation) {
            throw "Framework maintenance approval did not isolate the '$operation' operation."
        }
    }
    Assert-Throws {
        & $maintenanceScript -Task test -Operation modify -FrameworkRoot $frameworkRoot -ApprovedPaths @('docs/new.md')
    } 'separate explicit approval'
    $modifyApproval = & $maintenanceScript -Task test -Operation modify -FrameworkRoot $frameworkRoot -ApprovedPaths @('docs/new.md') -ApproveModify
    if ($modifyApproval.Mode -ne 'Framework Maintenance' -or @($modifyApproval.ApprovedPaths) -notcontains 'docs/new.md') {
        throw 'Framework Maintenance Mode did not return the exact approved modification scope.'
    }
    foreach ($operation in @('commit', 'push')) {
        $switchName = "Approve$($operation.Substring(0, 1).ToUpperInvariant())$($operation.Substring(1))"
        $approvalArgs = @{}
        $approvalArgs[$switchName] = $true
        $approval = & $maintenanceScript -Task test -Operation $operation -FrameworkRoot $frameworkRoot @approvalArgs
        if ($approval.Operation -ne $operation) { throw "Framework Maintenance Mode failed the separate '$operation' approval." }
    }
    Assert-Throws {
        & $maintenanceScript -Task test -Operation modify -FrameworkRoot $frameworkRoot -ApprovedPaths @('../escape.md') -ApproveModify
    } 'safe FrameworkRoot-relative approved path'

    Write-Host 'Framework source protection tests passed.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
