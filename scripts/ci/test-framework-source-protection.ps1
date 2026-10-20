Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts/bootstrap/helpers/wizard-source-protection.ps1')
$maintenanceScript = Join-Path $repoRoot 'scripts/bootstrap/framework-maintenance.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "wizard-source-protection-$([guid]::NewGuid().ToString('N'))"
$frameworkRoot = Join-Path $testRoot 'framework'
$targetRoot = Join-Path $testRoot 'application'
$nestedTarget = Join-Path $targetRoot 'nested'
$worktreeTarget = Join-Path $testRoot 'framework-worktree'
$sameRepositoryClone = Join-Path $testRoot 'same-framework-repository'
$installedFramework = Join-Path $testRoot 'installed-framework'
$sharedRemote = 'https://github.com/bradlaw76/power-platform-vscode-starter.git'

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

    New-Item -ItemType Directory -Path $installedFramework -Force | Out-Null
    @{
        repositoryUrl = 'https://github.com/bradlaw76/power-platform-vscode-starter'
        version = 'test'
        commit = '0123456789abcdef0123456789abcdef01234567'
        readOnlyDistribution = $true
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $installedFramework 'wizard-framework-install.json') -Encoding utf8
    $installedIdentity = Get-WizardGitIdentity -RepositoryPath $installedFramework
    if ($installedIdentity.InstalledCommit -ne '0123456789abcdef0123456789abcdef01234567' -or
        $installedIdentity.Remotes -notcontains 'github.com/bradlaw76/power-platform-vscode-starter') {
        throw 'The packaged framework identity manifest was not recognized.'
    }
    $null = Assert-WizardApplicationRepositoryIdentity -FrameworkRoot $installedFramework -TargetProjectRoot $targetRoot

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
        } 'sharing the framework Git remote'
    }

    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'set-url', 'origin', 'ssh://git@github.com/example/wizard-framework.git')
    Assert-Throws {
        Assert-WizardApplicationRepositoryIdentity -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
    } 'sharing the framework Git remote'
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'set-url', 'origin', 'git@github.com:example/wizard-framework.git')
    Assert-Throws {
        Assert-WizardApplicationRepositoryIdentity -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
    } 'sharing the framework Git remote'

    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('config', 'url.https://github.com/example/.insteadOf', 'github:')
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'set-url', 'origin', 'github:wizard-framework')
    Assert-Throws {
        Assert-WizardApplicationRepositoryIdentity -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
    } 'sharing the framework Git remote'
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('config', '--unset', 'url.https://github.com/example/.insteadOf')
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'set-url', 'origin', 'https://github.com/example/application.git')

    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'remove', 'origin')
    Assert-Throws {
        Assert-WizardApplicationRepositoryIdentity -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
    } 'exactly one identifiable'
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'add', 'origin', 'https://github.com/example/application.git')
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'add', 'upstream', 'https://github.com/example/another-application.git')
    Assert-Throws {
        Assert-WizardApplicationRepositoryIdentity -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot
    } 'exactly one identifiable'
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'remove', 'upstream')
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('remote', 'set-url', '--push', 'origin', $sharedRemote)
    Assert-Throws {
        Assert-WizardApplicationGitOperation -FrameworkRoot $frameworkRoot -TargetProjectRoot $targetRoot -Operation push
    } 'exactly one identifiable'
    Invoke-TestGit -WorkingDirectory $targetRoot -Arguments @('config', '--unset', 'remote.origin.pushurl')

    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('worktree', 'add', '-b', 'application-worktree', $worktreeTarget)
    Assert-Throws {
        Assert-WizardApplicationRepositoryIdentity -FrameworkRoot $frameworkRoot -TargetProjectRoot $worktreeTarget
    } 'sharing the framework Git directory or worktree'

    $wizardPath = Join-Path $repoRoot 'scripts/bootstrap/05-start-wizard.ps1'
    $frameworkStatusBefore = @(& git -C $repoRoot status --porcelain)
    $directFrameworkOutput = @(& pwsh -NoProfile -NonInteractive -File $wizardPath -TargetProjectRoot $repoRoot 2>&1)
    if ($LASTEXITCODE -eq 0) {
        throw "The production wizard entry point did not reject FrameworkRoot as TargetProjectRoot:`n$($directFrameworkOutput -join "`n")"
    }
    $frameworkStatusAfter = @(& git -C $repoRoot status --porcelain)
    if (@(Compare-Object $frameworkStatusBefore $frameworkStatusAfter).Count -gt 0) {
        throw 'The production wizard entry point changed the framework worktree before rejecting FrameworkRoot as the target.'
    }

    $validatorPath = Join-Path $repoRoot 'scripts/bootstrap/15-dry-validate.ps1'
    $directValidatorOutput = @(& pwsh -NoProfile -NonInteractive -File $validatorPath -RepoRoot $repoRoot -PreviewOnly $true 2>&1)
    if ($LASTEXITCODE -eq 0) {
        throw "The production validator did not reject FrameworkRoot as its application root:`n$($directValidatorOutput -join "`n")"
    }
    $frameworkStatusAfterValidator = @(& git -C $repoRoot status --porcelain)
    if (@(Compare-Object $frameworkStatusBefore $frameworkStatusAfterValidator).Count -gt 0) {
        throw 'The production validator changed the framework worktree before rejecting FrameworkRoot as the target.'
    }

    $cloneOutput = @(& git clone --no-checkout $repoRoot $sameRepositoryClone 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Could not create same-repository target fixture: $($cloneOutput -join "`n")" }
    $frameworkRemote = (@(& git -C $repoRoot remote get-url origin 2>$null) -join "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($frameworkRemote)) { throw 'Could not resolve the framework remote for the production entry-point test.' }
    Invoke-TestGit -WorkingDirectory $sameRepositoryClone -Arguments @('remote', 'set-url', 'origin', $frameworkRemote)
    $statusBeforeWizard = @(& git -C $sameRepositoryClone status --porcelain)
    $wizardOutput = @(& pwsh -NoProfile -NonInteractive -File $wizardPath -TargetProjectRoot $sameRepositoryClone 2>&1)
    if ($LASTEXITCODE -eq 0) {
        throw "The production wizard entry point did not fail closed for a separate framework clone:`n$($wizardOutput -join "`n")"
    }
    $statusAfterWizard = @(& git -C $sameRepositoryClone status --porcelain)
    if (@(Compare-Object $statusBeforeWizard $statusAfterWizard).Count -gt 0) {
        throw 'The production wizard entry point wrote files before rejecting the framework clone.'
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
    if (Test-Path -LiteralPath (Join-Path $frameworkDocs 'new.md')) { throw 'Unapproved framework modification created a file.' }
    Assert-Throws {
        & $maintenanceScript -Task test -Operation modify -FrameworkRoot $frameworkRoot -ApprovedPaths @('docs/new.md') -FileUpdates @{ 'docs/new.md' = 'approved'; 'README.md' = 'unapproved' } -ApproveModify
    } 'exactly the approved paths'
    $modifyApproval = & $maintenanceScript -Task test -Operation modify -FrameworkRoot $frameworkRoot -ApprovedPaths @('docs/new.md') -FileUpdates @{ 'docs/new.md' = 'approved change' } -ApproveModify
    if ($modifyApproval.Mode -ne 'Framework Maintenance' -or -not $modifyApproval.Completed -or
        @($modifyApproval.ApprovedPaths) -notcontains 'docs/new.md' -or
        (Get-Content -LiteralPath (Join-Path $frameworkDocs 'new.md') -Raw).Trim() -cne 'approved change') {
        throw 'Framework Maintenance Mode did not write the exact approved framework file.'
    }
    $baselineCommit = ((& git -C $frameworkRoot rev-parse HEAD) -join '').Trim()
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('add', 'docs/new.md')
    Assert-Throws {
        & $maintenanceScript -Task test -Operation commit -FrameworkRoot $frameworkRoot -ApprovedPaths @('README.md') -CommitMessage 'wrong scope' -ApproveCommit
    } 'exactly match the staged paths'
    $commitApproval = & $maintenanceScript -Task test -Operation commit -FrameworkRoot $frameworkRoot -ApprovedPaths @('docs/new.md') -CommitMessage 'approved change' -ApproveCommit
    if ($commitApproval.Operation -ne 'commit' -or -not $commitApproval.Completed) { throw 'Framework Maintenance Mode failed the separate commit approval.' }
    Invoke-TestGit -WorkingDirectory $frameworkRoot -Arguments @('update-ref', 'refs/remotes/origin/main', $baselineCommit)
    Assert-Throws {
        & $maintenanceScript -Task test -Operation push -FrameworkRoot $frameworkRoot -ApprovedPaths @('README.md') -BaseRef origin/main -ApprovePush
    } 'exactly match the commits ahead'
    $pushApproval = & $maintenanceScript -Task test -Operation push -FrameworkRoot $frameworkRoot -ApprovedPaths @('docs/new.md') -BaseRef origin/main -ApprovePush -WhatIf
    if ($pushApproval.Operation -ne 'push' -or $pushApproval.Completed) { throw 'Framework Maintenance Mode did not honor its dry-run push boundary.' }
    Assert-Throws {
        & $maintenanceScript -Task test -Operation modify -FrameworkRoot $frameworkRoot -ApprovedPaths @('../escape.md') -ApproveModify
    } 'safe FrameworkRoot-relative approved path'
    $maintenanceLink = Join-Path $frameworkRoot 'outside-link'
    New-Item -ItemType SymbolicLink -Path $maintenanceLink -Target $testRoot | Out-Null
    Assert-Throws {
        & $maintenanceScript -Task test -Operation modify -FrameworkRoot $frameworkRoot -ApprovedPaths @('outside-link/escape.md') -FileUpdates @{ 'outside-link/escape.md' = 'escape' } -ApproveModify
    } 'outside framework source'
    $nestedFrameworkRepo = Join-Path $frameworkRoot 'nested-framework'
    New-Item -ItemType Directory -Path $nestedFrameworkRepo -Force | Out-Null
    Invoke-TestGit -WorkingDirectory $nestedFrameworkRepo -Arguments @('init', '-b', 'nested')
    Assert-Throws {
        & $maintenanceScript -Task test -Operation modify -FrameworkRoot $frameworkRoot -ApprovedPaths @('nested-framework/escape.md') -FileUpdates @{ 'nested-framework/escape.md' = 'escape' } -ApproveModify
    } 'nested Git repository'

    Write-Host 'Framework source protection tests passed.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
