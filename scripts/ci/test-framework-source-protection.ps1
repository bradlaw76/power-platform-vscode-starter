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
    Set-Content -LiteralPath (Join-Path $frameworkRoot 'README.md') -Value 'framework maintenance baseline'
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('add', 'README.md')
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('commit', '-m', 'baseline')
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('branch', 'main')

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
    $protectedFile = Join-Path $frameworkDocs 'protected.md'
    Set-Content -LiteralPath $protectedFile -Value 'framework-owned'
    foreach ($caller in @('ordinary user', 'repository owner')) {
        Assert-Throws {
            $writePath = Assert-WizardWritablePath -Path $protectedFile -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
            Set-Content -LiteralPath $writePath -Value "unauthorized by $caller"
        } 'outside TargetProjectRoot'
        if ((Get-Content -LiteralPath $protectedFile -Raw).Trim() -cne 'framework-owned') {
            throw "Application Authoring Mode modified a framework file for $caller."
        }
    }
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
    foreach ($operation in @('stage', 'commit', 'push', 'pull-request')) {
        Assert-Throws {
            $null = Assert-WizardApplicationGitOperation -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot -Operation $operation
        } 'shares a remote'
    }

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
    Set-Content -LiteralPath (Join-Path $frameworkDocs 'new.md') -Value 'approved change'
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('add', 'docs/new.md')
    Assert-Throws {
        & $maintenanceScript -Task test -Operation commit -FrameworkRoot $frameworkRoot -ApprovedPaths @('README.md') -ApproveCommit
    } 'exactly match the affected files'
    $commitApproval = & $maintenanceScript -Task test -Operation commit -FrameworkRoot $frameworkRoot -ApprovedPaths @('docs/new.md') -ApproveCommit
    if ($commitApproval.Operation -ne 'commit') { throw 'Framework Maintenance Mode failed the separate commit approval.' }
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('commit', '-m', 'approved change')
    Assert-Throws {
        & $maintenanceScript -Task test -Operation push -FrameworkRoot $frameworkRoot -ApprovedPaths @('README.md') -BaseRef main -ApprovePush
    } 'exactly match the affected files'
    $pushApproval = & $maintenanceScript -Task test -Operation push -FrameworkRoot $frameworkRoot -ApprovedPaths @('docs/new.md') -BaseRef main -ApprovePush
    if ($pushApproval.Operation -ne 'push') { throw 'Framework Maintenance Mode failed the separate push approval.' }
    Assert-Throws {
        & $maintenanceScript -Task test -Operation modify -FrameworkRoot $frameworkRoot -ApprovedPaths @('../escape.md') -ApproveModify
    } 'safe FrameworkRoot-relative approved path'

    Write-Host 'Framework source protection tests passed.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
