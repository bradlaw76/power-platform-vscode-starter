<#
=============================================================================
COMPONENT:    Wizard Skill Parity Acceptance Tests
FILE:         scripts/ci/SkillParity.Tests.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-24
ENVIRONMENT:  PowerShell 7 | Pester 5.7.1 | CI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Ensures the Copilot and Claude wizard skills preserve the same planning gate,
authoritative sequence, shared script entry points, and required stages.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            CI acceptance test
- Inputs:          Copilot and Claude SKILL.md files
- Outputs:         Pester assertions
- Dependencies:    Pester 5.7.1
- Side Effects:    none

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Both skills require spec.md, plan.md, and tasks.md before build scripts.
✔ Both skills name the shared entry points and lifecycle stages.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Keep parity checks semantic enough to permit platform-specific wording.
- Treat docs/onboarding.md as the authoritative sequence.
=============================================================================
#>

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $skillPaths = [ordered]@{
        Copilot = Join-Path $repoRoot '.github/skills/power-platform-wizard-init/SKILL.md'
        Claude  = Join-Path $repoRoot '.claude/skills/power-platform-vscode-wizard/SKILL.md'
    }
    $skillContent = @{}
    foreach ($entry in $skillPaths.GetEnumerator()) {
        $skillContent[$entry.Key] = Get-Content -LiteralPath $entry.Value -Raw
    }
}

Describe 'Copilot and Claude wizard skill parity' {
    It '<Skill> uses docs/onboarding.md as the authoritative sequence' -ForEach @(
        @{ Skill = 'Copilot' }
        @{ Skill = 'Claude' }
    ) {
        $skillContent[$Skill] | Should -Match 'docs/onboarding\.md'
        $skillContent[$Skill] | Should -Match '(?i)authoritative|single source of truth'
    }

    It '<Skill> requires all planning artifacts before build scripts' -ForEach @(
        @{ Skill = 'Copilot' }
        @{ Skill = 'Claude' }
    ) {
        foreach ($artifact in @('spec.md', 'plan.md', 'tasks.md')) {
            $skillContent[$Skill] | Should -Match ([regex]::Escape($artifact))
        }
        $skillContent[$Skill] | Should -Match '(?is)(do not|never|must not).{0,120}(build|scripts? 20)'
    }

    It '<Skill> names shared orchestration script <ScriptName>' -ForEach @(
        foreach ($skill in @('Copilot', 'Claude')) {
            foreach ($scriptName in @(
                '00-prereq-check.ps1',
                '05-start-wizard.ps1',
                '10-auth-connect.ps1'
            )) {
                @{ Skill = $skill; ScriptName = $scriptName }
            }
        }
    ) {
        $skillContent[$Skill] | Should -Match ([regex]::Escape($ScriptName))
    }

    It '<Skill> covers required stage <Stage>' -ForEach @(
        $stagePatterns = [ordered]@{
            'discovery'               = '(?i)discovery'
            'planning gate'           = '(?i)planning gate|spec kit'
            'prerequisites'            = '(?i)prereq'
            'authentication'           = '(?i)auth'
            'build'                    = '(?i)build scripts?|build flow'
            'validation'               = '(?i)validat'
        }
        foreach ($skill in @('Copilot', 'Claude')) {
            foreach ($stage in $stagePatterns.GetEnumerator()) {
                @{ Skill = $skill; Stage = $stage.Key; Pattern = $stage.Value }
            }
        }
    ) {
        $skillContent[$Skill] | Should -Match $Pattern
    }
}