<#
=============================================================================
COMPONENT:    Framework Context Preflight Regression Tests
FILE:         scripts/ci/test-framework-context-preflight.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-23
ENVIRONMENT:  PowerShell 7 | Git | Offline CI
OVERVIEW
Execute positive and negative identity checks against isolated Git fixtures.
ARCHITECTURE
- Inputs: production preflight and maintenance scripts.
- Outputs: assertion count or terminating failure.
- Side Effects: temporary local repositories only; removed after execution.
TEST CASES
- Exact baseline, SSH identity, dirty tree, detached/wrong branch, stale HEAD.
- Wrong/ambiguous remotes, wrong root, missing approval, and blocked writes.
NON-NEGOTIABLES
- Never fetch, push, or change the operator repository's refs or index.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$preflight = Join-Path $repoRoot 'scripts/bootstrap/framework-context-preflight.ps1'
$maintenance = Join-Path $repoRoot 'scripts/bootstrap/framework-maintenance.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "framework-context-$([guid]::NewGuid().ToString('N'))"
$fixture = Join-Path $testRoot 'framework'
$script:checks = 0

function Invoke-FixtureGit {
    param([string[]]$Arguments)
    $output = @(& git -C $fixture @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Fixture Git failed: $($output -join "`n")" }
    return $output
}

function Assert-Rejected {
    param([scriptblock]$Action, [string]$Message)
    $before = @(Invoke-FixtureGit @('status', '--porcelain=v1', '--untracked-files=all'))
    $refsBefore = @(Invoke-FixtureGit @('show-ref', '--head'))
    $rejected = $false
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notlike "*$Message*") { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw "Expected rejection: $Message" }
    $after = @(Invoke-FixtureGit @('status', '--porcelain=v1', '--untracked-files=all'))
    $refsAfter = @(Invoke-FixtureGit @('show-ref', '--head'))
    if (($before -join "`n") -cne ($after -join "`n") -or
        ($refsBefore -join "`n") -cne ($refsAfter -join "`n")) {
        throw 'Rejected operation changed the fixture worktree/index or refs.'
    }
    $script:checks++
}

try {
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    $null = Invoke-FixtureGit @('init', '-b', 'framework-maintenance/skills-1-2')
    $null = Invoke-FixtureGit @('config', 'user.name', 'Context Test')
    $null = Invoke-FixtureGit @('config', 'user.email', 'context@example.invalid')
    $null = Invoke-FixtureGit @('remote', 'add', 'origin', 'https://github.com/bradlaw76/power-platform-vscode-starter.git')
    Set-Content -LiteralPath (Join-Path $fixture 'baseline.txt') -Value 'baseline'
    $null = Invoke-FixtureGit @('add', 'baseline.txt')
    $null = Invoke-FixtureGit @('commit', '-m', 'baseline')
    $head = (Invoke-FixtureGit @('rev-parse', 'HEAD') -join '').Trim()
    $contextArgs = @{
        FrameworkRoot = $fixture
        ExpectedBranch = 'framework-maintenance/skills-1-2'
        ExpectedHead = $head
    }
    $result = & $preflight @contextArgs
    if (-not $result.Verified -or -not $result.Clean -or $result.Head -cne $head -or
        $result.Branch -cne $contextArgs.ExpectedBranch) { throw 'Exact baseline did not verify.' }
    $script:checks++
    Set-Content -LiteralPath (Join-Path $fixture 'unrelated.txt') -Value 'preserve'
    $result = & $preflight @contextArgs
    if ($result.Clean -or $result.WorkingTree.Count -ne 1) { throw 'Dirty worktree was not reported.' }
    $script:checks++
    $null = Invoke-FixtureGit @('remote', 'set-url', 'origin', 'git@github.com:bradlaw76/power-platform-vscode-starter.git')
    $null = & $preflight @contextArgs
    $script:checks++
    Assert-Rejected { & $preflight @contextArgs -ExpectedHead ('0' * 40) } 'HEAD mismatch'
    Assert-Rejected { & $preflight @contextArgs -ExpectedHead 'short' } 'Cannot validate argument'
    Assert-Rejected { & $preflight @contextArgs -ExpectedBranch 'main' } 'Cannot validate argument'
    Assert-Rejected { & $preflight @contextArgs -ExpectedBranch 'framework-maintenance/task/../escape' } 'traversal'
    New-Item -ItemType Directory -Path (Join-Path $fixture 'docs') | Out-Null
    Assert-Rejected { & $preflight @contextArgs -FrameworkRoot (Join-Path $fixture 'docs') } 'exact Git repository root'
    Assert-Rejected { & $preflight @contextArgs -FrameworkRoot (Join-Path $fixture 'missing') } 'existing FrameworkRoot'
    foreach ($branch in @('main', 'feature/application', 'framework-maintenance/another-task')) {
        $null = Invoke-FixtureGit @('switch', '-c', $branch)
        Assert-Rejected { & $preflight @contextArgs } 'branch mismatch'
        Assert-Rejected {
            & $maintenance -FrameworkRoot $fixture -Task skills-1-2 -ExpectedHead $head `
                -Operation modify -ApprovedPaths @('blocked.txt') -FileUpdates @{ 'blocked.txt' = 'blocked' } -ApproveModify
        } 'branch mismatch'
    }
    $null = Invoke-FixtureGit @('checkout', '--detach', $head)
    Assert-Rejected { & $preflight @contextArgs } 'branch mismatch'
    $null = Invoke-FixtureGit @('switch', 'framework-maintenance/skills-1-2')
    foreach ($url in @('https://github.com/example/application.git', 'not-a-repository-url')) {
        $null = Invoke-FixtureGit @('remote', 'set-url', 'origin', $url)
        Assert-Rejected { & $preflight @contextArgs } $(if ($url -eq 'not-a-repository-url') { 'canonicalize' } else { 'canonical framework repository' })
    }
    $null = Invoke-FixtureGit @('remote', 'set-url', 'origin', 'https://github.com/bradlaw76/power-platform-vscode-starter')
    $null = Invoke-FixtureGit @('remote', 'set-url', '--push', 'origin', 'https://github.com/example/application')
    Assert-Rejected { & $preflight @contextArgs } 'unambiguous fetch/push identity'
    $null = Invoke-FixtureGit @('config', '--unset', 'remote.origin.pushurl')
    $null = Invoke-FixtureGit @('remote', 'add', 'extra', 'https://github.com/example/another')
    Assert-Rejected { & $preflight @contextArgs } 'unambiguous fetch/push identity'
    $null = Invoke-FixtureGit @('remote', 'remove', 'extra')
    $null = Invoke-FixtureGit @('remote', 'remove', 'origin')
    Assert-Rejected { & $preflight @contextArgs } 'canonical framework repository'
    $null = Invoke-FixtureGit @('remote', 'add', 'origin', 'https://github.com/bradlaw76/power-platform-vscode-starter')
    $operationArgs = @{
        FrameworkRoot = $fixture
        Task = 'skills-1-2'
        ExpectedHead = $head
        ApprovedPaths = @('blocked.txt')
    }
    Assert-Rejected {
        $output = @(& pwsh -NoProfile -NonInteractive -File $maintenance -FrameworkRoot $fixture `
                -Task skills-1-2 -Operation modify -ApprovedPaths blocked.txt -ApproveModify 2>&1)
        if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
    } 'ExpectedHead'
    foreach ($operation in @('modify', 'commit', 'push')) {
        Assert-Rejected { & $maintenance @operationArgs -Operation $operation } 'separate explicit approval'
    }
    Assert-Rejected {
        & $maintenance @operationArgs -Operation modify -FileUpdates @{ 'blocked.txt' = 'blocked' } -ApproveModify -ApproveCommit
    } 'unexpected approval'
    Assert-Rejected {
        & $maintenance @operationArgs -ExpectedHead ('0' * 40) -Operation modify `
            -FileUpdates @{ 'blocked.txt' = 'blocked' } -ApproveModify
    } 'HEAD mismatch'
    $preview = & $maintenance @operationArgs -Operation modify `
        -FileUpdates @{ 'blocked.txt' = 'preview only' } -ApproveModify -WhatIf
    if ($preview.Completed -or $preview.VerifiedHead -cne $head -or
        (Test-Path -LiteralPath (Join-Path $fixture 'blocked.txt'))) {
        throw 'Approved maintenance preview did not preserve its verified no-write boundary.'
    }
    $script:checks++
    $null = Invoke-FixtureGit @('commit', '--allow-empty', '-m', 'new head')
    Assert-Rejected { & $preflight @contextArgs } 'HEAD mismatch'
    if (Test-Path -LiteralPath (Join-Path $fixture 'blocked.txt')) { throw 'A rejected operation wrote a file.' }
    Write-Host "Framework context preflight: $script:checks checks passed."
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
