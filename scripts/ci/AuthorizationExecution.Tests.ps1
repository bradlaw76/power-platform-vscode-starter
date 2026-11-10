<#
=============================================================================
COMPONENT:    Authorization and Execution Contract Tests
FILE:         scripts/ci/AuthorizationExecution.Tests.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-11-10
ENVIRONMENT:  PowerShell 7 | Pester 5.7.1 | Credential-free CI
-----------------------------------------------------------------------------
OVERVIEW
Validates policy scenarios, instruction inheritance and real local installation.
ARCHITECTURE
- Inputs: canonical policy, instruction surfaces and existing skill installer
- Outputs: Pester assertions; temporary fixture files under TestDrive
- Dependencies: Pester 5.7.1
- Side Effects: isolated fixture installation only; no project or network writes
NON-NEGOTIABLES
- Contract assertions are not proof of agent compliance or live deployment.
- Never install into the operator's actual home or weaken existing safety gates.
=============================================================================
#>

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $policyRelativePath = 'docs\policies\authorization-and-execution.md'
    $policyPath = Join-Path $repoRoot $policyRelativePath
    $policy = Get-Content -LiteralPath $policyPath -Raw
    $surfaces = @(
        '.github\copilot-instructions.md'
        '.github\prompts\power-platform-demo-wizard.prompt.md'
        '.github\skills\power-platform-wizard-init\SKILL.md'
        '.github\skills\dataverse-report-wizard\SKILL.md'
        '.github\skills\dataverse-form-formatter\SKILL.md'
        '.claude\skills\power-platform-vscode-wizard\SKILL.md'
        '.claude\skills\dataverse-report-wizard\SKILL.md'
        '.claude\skills\dataverse-form-formatter\SKILL.md'
        'docs\onboarding.md'
        'docs\wizard-contract-v1.md'
        'docs\skill-distribution.md'
        'CONTRIBUTING.md'
        'README.md'
        'requirements\GithubInstructions_General.md'
        'requirements\how-to-build-dynamics-model-driven-apps-wizard.md'
        'requirements\how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md'
    )

    function Invoke-FixtureSkillInstaller {
        param([string]$InstallerPath, [string]$HomePath)

        $previousHome = $HOME
        try {
            Set-Variable -Name HOME -Value $HomePath -Force
            & $InstallerPath
        }
        finally {
            Set-Variable -Name HOME -Value $previousHome -Force
        }
    }
}

Describe 'Authorization and execution policy contract' {
    It '<Id> documents the required operational decision' -ForEach @(
        @{ Id = 'AUTH-01'; Expected = 'Reuse valid authorization; do not ask again'; Rule = 'Never create redundant owner-approval gates when authorization is already valid' }
        @{ Id = 'AUTH-02'; Expected = 'BLOCKED for deployment; request the missing target scope'; Rule = 'If scope is unclear, stop that operation' }
        @{ Id = 'AUTH-03'; Expected = 'Correct the dependency, run focused checks and resume within scope'; Rule = 'Fix technical errors autonomously within scope' }
        @{ Id = 'AUTH-04'; Expected = 'Reuse the verified pattern after compatibility checks'; Rule = 'Prior success is evidence for a method, not permission' }
        @{ Id = 'AUTH-05'; Expected = 'Preserve it; block the conflicting operation, never delete/recreate it'; Rule = 'production components outside the approved change set' }
        @{ Id = 'AUTH-06'; Expected = 'Continue the independent test; report the blocked dependency separately'; Rule = 'continue independent authorized work only when it does not depend' }
        @{ Id = 'AUTH-07'; Expected = 'Report SOURCE COMPLETE and TESTED, not DEPLOYED or LIVE VERIFIED'; Rule = 'TESTED does not imply DEPLOYED' }
        @{ Id = 'AUTH-08'; Expected = 'Reconcile uncertain writes; no unchanged deterministic retries; bound transient attempts'; Rule = 'at most three total attempts per operation' }
    ) {
        $row = @($policy -split '\r?\n' | Where-Object { $_ -match "^\| $Id \|" })
        $row.Count | Should -Be 1
        $row[0] | Should -Match ([regex]::Escape($Expected))
        ($policy -replace '\s+', ' ') | Should -Match ([regex]::Escape($Rule))
    }

    It 'keeps one canonical policy referenced by every existing entry point' {
        foreach ($surface in $surfaces) {
            $content = Get-Content -LiteralPath (Join-Path $repoRoot $surface) -Raw
            $content | Should -Match 'authorization-and-execution\.md' -Because $surface
            $content | Should -Not -Match 'Require explicit approval before commit and separate approval before push'
        }
    }

    It 'preserves stronger safety gates and distinguishes all evidence states' {
        foreach ($rule in @(
            'platform confirmations', 'signed approvals', 'environment security controls',
            'scenario spec.md, plan.md and tasks.md', 'plan-hash approvals',
            'solution membership/export gates', 'FAST-dependent Apply remains blocked',
            'executionAuthorized: false', 'Commit permission alone does not permit push',
            'read back by stable component identity', 'unchanged deterministic error gets no retry',
            'HANDOFF NOT WRITTEN - BLOCKED'
        )) {
            ($policy -replace '`', '' -replace '\s+', ' ') | Should -Match ([regex]::Escape($rule))
        }
        foreach ($status in @('SOURCE COMPLETE', 'TESTED', 'DEPLOYED', 'LIVE VERIFIED', 'BLOCKED')) {
            $policy | Should -Match "(?m)^\| $status \|"
        }
    }

    It 'requires project inheritance without overwriting existing instructions' {
        ($policy -replace '\s+', ' ') | Should -Match 'include this policy or an explicitly reviewed equivalent operational contract'
        ($policy -replace '\s+', ' ') | Should -Match 'do not silently replace existing instructions'
        foreach ($skill in @('power-platform-vscode-wizard', 'dataverse-report-wizard', 'dataverse-form-formatter')) {
            $content = Get-Content (Join-Path $repoRoot ".claude\skills\$skill\SKILL.md") -Raw
            $content | Should -Match 'references/authorization-and-execution.md'
            ($content -replace '\s+', ' ') | Should -Match 'If neither exists, report BLOCKED for mutating work'
        }
    }
}

Describe 'Portable skill policy installation' {
    BeforeEach {
        $fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $bootstrap = Join-Path $fixture 'scripts\bootstrap'
        New-Item -ItemType Directory -Path $bootstrap -Force | Out-Null
        $installer = Join-Path $bootstrap '01-install-skills.ps1'
        Copy-Item (Join-Path $repoRoot 'scripts\bootstrap\01-install-skills.ps1') $installer
        $skillSource = Join-Path $fixture '.claude\skills'
        New-Item -ItemType Directory -Path $skillSource -Force | Out-Null
        Copy-Item (Join-Path $repoRoot '.claude\skills\*') $skillSource -Recurse
        $fixturePolicy = Join-Path $fixture $policyRelativePath
        New-Item -ItemType Directory -Path (Split-Path $fixturePolicy -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $policyPath -Destination $fixturePolicy
        $fixtureHome = Join-Path $fixture 'home'
        New-Item -ItemType Directory -Path $fixtureHome -Force | Out-Null
    }

    It 'installs byte-identical policy for all skills and refreshes it on rerun' {
        $originalHome = $HOME
        Invoke-FixtureSkillInstaller -InstallerPath $installer -HomePath $fixtureHome
        $HOME | Should -Be $originalHome
        $sourceHash = (Get-FileHash -LiteralPath $fixturePolicy -Algorithm SHA256).Hash
        $skills = @(Get-ChildItem -LiteralPath $skillSource -Directory)
        $skills.Count | Should -Be 3
        foreach ($skill in $skills) {
            $installedPolicy = Join-Path $fixtureHome ".claude\skills\$($skill.Name)\references\authorization-and-execution.md"
            (Get-FileHash -LiteralPath $installedPolicy -Algorithm SHA256).Hash | Should -Be $sourceHash
            Set-Content -LiteralPath $installedPolicy -Value 'stale policy'
        }
        $sentinel = Join-Path $fixtureHome '.claude\skills\operator-owned.txt'
        Set-Content -LiteralPath $sentinel -Value 'preserve concurrent work'
        Invoke-FixtureSkillInstaller -InstallerPath $installer -HomePath $fixtureHome
        foreach ($skill in $skills) {
            $installedPolicy = Join-Path $fixtureHome ".claude\skills\$($skill.Name)\references\authorization-and-execution.md"
            (Get-FileHash -LiteralPath $installedPolicy -Algorithm SHA256).Hash | Should -Be $sourceHash
        }
        (Get-Content -LiteralPath $sentinel -Raw).Trim() | Should -Be 'preserve concurrent work'
        Test-Path (Join-Path $fixtureHome 'docs') | Should -BeFalse
    }

    It 'blocks installation before destination writes when canonical policy is missing' {
        Remove-Item -LiteralPath $fixturePolicy
        {
            Invoke-FixtureSkillInstaller -InstallerPath $installer -HomePath $fixtureHome
        } | Should -Throw '*Required authorization policy is missing*'
        Test-Path (Join-Path $fixtureHome '.claude') | Should -BeFalse
    }
}
