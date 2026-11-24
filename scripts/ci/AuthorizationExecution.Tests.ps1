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
        '.claude\skills\power-platform-vscode-wizard\SKILL.md'
        '.claude\skills\dataverse-report-wizard\SKILL.md'
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
        @{ Id = 'AUTH-09'; Expected = 'Reuse standing scope; verify target and effects, retain separate required approvals'; Rule = 'Nonproduction status and credentials alone never constitute authorization' }
        @{ Id = 'AUTH-10'; Expected = 'Implement the bounded repair; reconcile administration and documentation before closure'; Rule = 'unless they establish real authority, satisfy an enforced policy or resolve conflicting writers' }
        @{ Id = 'AUTH-11'; Expected = 'Stop the affected operation for its required pre-change gate; retrospective documentation is not approval'; Rule = 'Retrospective documentation is not retrospective permission' }
        @{ Id = 'AUTH-12'; Expected = 'Recover before restart; lease expiry alone does not release the writer'; Rule = 'Lease expiry alone is insufficient evidence of release' }
        @{ Id = 'AUTH-13'; Expected = 'Check current ownership evidence; preserve the H ID, do not treat it as permanent ownership'; Rule = 'H IDs track outcomes, not permanent component ownership' }
        @{ Id = 'AUTH-14'; Expected = 'Queue dependency-ready authorized work; preserve the hold and verify actual executor support'; Rule = 'native message queueing is not proof of durable recovery or unattended permission' }
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

    It 'distributes repair authority and writer recovery without weakening real gates' {
        foreach ($surface in $surfaces) {
            $content = (Get-Content -LiteralPath (Join-Path $repoRoot $surface) -Raw) -replace '\s+', ' '
            foreach ($rule in @(
                'standing scoped nonproduction', 'accepted requirements',
                'real authority', 'enforced policy', 'conflicting writers',
                'H IDs track outcomes, not permanent component ownership',
                'checkpoint', 'resource evidence', 'lease expiry alone',
                'before closure', 'semantic/report/hash/', 'FAST/security',
                'QUEUED_AUTONOMOUS_DELIVERY.md'
            )) {
                $content | Should -Match ([regex]::Escape($rule)) -Because "$surface must inherit $rule"
            }
        }
    }

    It 'requires before-change repair evidence and refuses retroactive permission' {
        $contract = $policy -replace '\s+', ' '
        foreach ($rule in @(
            'minimum change contract', 'recoverable before-state/rollback',
            'New requirements, schema/type changes, report meaning, security boundaries',
            'scope change, expiration, revocation, production target, destructive effect',
            'Standing permission cannot approve a semantic/report definition or sign an artifact hash',
            'explicit read-only allocation restriction still binds',
            'active process/session state, latest durable checkpoint/journal',
            'actual resource state and in-flight writes',
            'Do not delete locks or reset state merely to force a restart',
            'a fresh session does not reset that budget'
        )) {
            $contract | Should -Match ([regex]::Escape($rule))
        }
    }

    It 'offers executable-session queue instructions without claiming a durable executor' {
        $queue = Get-Content -LiteralPath (Join-Path $repoRoot 'docs\QUEUED_AUTONOMOUS_DELIVERY.md') -Raw
        $queue | Should -Match 'https://code\.visualstudio\.com/docs/agents/overview'
        $queue | Should -Match 'Add to Queue'
        $queue | Should -Match 'chat\.requestQueuing\.defaultAction'
        ($queue -replace '\s+', ' ') | Should -Match 'For \*\*explicitly autonomous multi-change work\*\*, recommend a dependency-aware queue'
        ($queue -replace '\s+', ' ') | Should -Match 'does not guarantee task success, reboot recovery'
        ($queue -replace '\s+', ' ') | Should -Match 'Lease expiry alone is insufficient'
        ($queue -replace '\s+', ' ') | Should -Match 'If no durable executor is configured, state this explicitly'
        foreach ($surface in $surfaces | Where-Object { $_ -match 'SKILL\.md$|prompt\.md$|copilot-instructions\.md$' }) {
            $content = Get-Content -LiteralPath (Join-Path $repoRoot $surface) -Raw
            $content | Should -Match 'https://code\.visualstudio\.com/docs/agents/overview' -Because $surface
            ($content -replace '\s+', ' ') | Should -Match 'explicitly autonomous multi-change work'
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
        foreach ($skill in @('power-platform-vscode-wizard', 'dataverse-report-wizard')) {
            $content = Get-Content (Join-Path $repoRoot ".claude\skills\$skill\SKILL.md") -Raw
            $content | Should -Match 'references/authorization-and-execution.md'
            ($content -replace '\s+', ' ') | Should -Match 'If neither exists, report BLOCKED for mutating work'
        }
    }

    It 'keeps impact review proportional without removing live or release safeguards' {
        $impact = Get-Content -LiteralPath (Join-Path $repoRoot 'docs\scenario-change-impact-gate.md') -Raw
        foreach ($changeClass in @('Minor maintenance', 'Bounded scenario delta', 'New or cross-cutting scenario')) {
            $impact | Should -Match ([regex]::Escape($changeClass))
        }
        $impact | Should -Match 'A minor edit must not restart discovery'
        $impact | Should -Match 'proportional review is not a waiver'
        $impact | Should -Match 'A timeframe-only change updates delivery context'
        foreach ($surface in @(
            '.github\copilot-instructions.md', '.github\prompts\power-platform-demo-wizard.prompt.md',
            '.github\skills\power-platform-wizard-init\SKILL.md', '.claude\skills\power-platform-vscode-wizard\SKILL.md',
            'README.md', 'docs\onboarding.md', 'docs\wizard-contract-v1.md',
            'requirements\how-to-build-dynamics-model-driven-apps-wizard.md'
        )) {
            $content = Get-Content -LiteralPath (Join-Path $repoRoot $surface) -Raw
            $content | Should -Match 'scenario-change-impact-gate\.md' -Because $surface
            $content | Should -Match '(?i)minor maintenance.{0,90}focused checks' -Because $surface
            $content | Should -Match '(?i)(do not regenerate|without regenerating) the full matrix' -Because $surface
            $content | Should -Match '(?i)native field/security proof|native field and security proof' -Because $surface
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
        $skills.Count | Should -Be 2
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
