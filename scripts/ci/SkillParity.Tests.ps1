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

    Describe 'Copilot and Claude Dataverse report skill parity' {
        BeforeAll {
            $reportSkillPaths = [ordered]@{
                Copilot = Join-Path $repoRoot '.github/skills/dataverse-report-wizard/SKILL.md'
                Claude  = Join-Path $repoRoot '.claude/skills/dataverse-report-wizard/SKILL.md'
            }
            $reportSkillContent = @{}
            foreach ($entry in $reportSkillPaths.GetEnumerator()) {
                $reportSkillContent[$entry.Key] = Get-Content -LiteralPath $entry.Value -Raw
            }
        }

        It '<Skill> distinguishes skill availability from runtime installation' -ForEach @(
            @{ Skill = 'Copilot' }
            @{ Skill = 'Claude' }
        ) {
            $reportSkillContent[$Skill] | Should -Match '(?i)skill availability is not runtime installation'
            $reportSkillContent[$Skill] | Should -Match '(?i)copied `SKILL\.md` does not'
            $reportSkillContent[$Skill] | Should -Match '(?is)never overwrite existing\s+instructions, skills, scripts, specs, or payloads'
        }

        It '<Skill> names reporting runtime <RuntimeFile>' -ForEach @(
            foreach ($skill in @('Copilot', 'Claude')) {
                foreach ($runtimeFile in @(
                    '08-report-wizard.ps1',
                    '10-auth-connect.ps1',
                    '64-build-charts-dashboard.ps1',
                    'reporting-wizard.ps1',
                    'reporting.schema.json',
                    'test-report-wizard.ps1'
                )) {
                    @{ Skill = $skill; RuntimeFile = $runtimeFile }
                }
            }
        ) {
            $reportSkillContent[$Skill] | Should -Match ([regex]::Escape($RuntimeFile))
        }

        It '<Skill> defaults to simulation and gates live mutation' -ForEach @(
            @{ Skill = 'Copilot' }
            @{ Skill = 'Claude' }
        ) {
            $reportSkillContent[$Skill] | Should -Match '(?i)default to `?simulate'
            $reportSkillContent[$Skill] | Should -Match '(?i)never use `-Deploy` without explicit approval'
            $reportSkillContent[$Skill] | Should -Match '(?i)never describe a simulated deployment as a live deployment'
            $reportSkillContent[$Skill] | Should -Match 'report-mappings\.md'
            $reportSkillContent[$Skill] | Should -Match 'query-preview\.json|FetchXML preview'
        }

        It '<Skill> routes app or schema expansion to the full wizard' -ForEach @(
            @{ Skill = 'Copilot' }
            @{ Skill = 'Claude' }
        ) {
            $reportSkillContent[$Skill] | Should -Match '(?i)tables, columns, relationships, forms, views'
            $reportSkillContent[$Skill] | Should -Match 'spec\.md'
            $reportSkillContent[$Skill] | Should -Match 'plan\.md'
            $reportSkillContent[$Skill] | Should -Match 'tasks\.md'
        }
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
                '10-auth-connect.ps1',
                '55-build-business-process-flows.ps1',
                '64-build-charts-dashboard.ps1',
                '62-build-app-module.ps1',
                '66-seed-synthetic-data.ps1',
                '85-verify-idempotency.ps1',
                '95-export-unmanaged-solution.ps1',
                '90-run-build.ps1'
            )) {
                @{ Skill = $skill; ScriptName = $scriptName }
            }
        }
    ) {
        $skillContent[$Skill] | Should -Match ([regex]::Escape($ScriptName))
    }

    It '<Skill> distinguishes skill availability from runtime installation' -ForEach @(
        @{ Skill = 'Copilot' }
        @{ Skill = 'Claude' }
    ) {
        $skillContent[$Skill] | Should -Match '(?i)skill availability is not runtime installation'
        $skillContent[$Skill] | Should -Match '(?i)copied `SKILL\.md` does not provide'
        $skillContent[$Skill] | Should -Match '(?i)never overwrite existing instructions, skills, scripts, specs, or payloads'
    }

    It '<Skill> enforces supported BPF handoff and final membership gate' -ForEach @(
        @{ Skill = 'Copilot' }
        @{ Skill = 'Claude' }
    ) {
        $skillContent[$Skill] | Should -Match '(?i)designer handoff'
        $skillContent[$Skill] | Should -Match 'InventoryOnly'
        $skillContent[$Skill] | Should -Match 'EnforceExportGate'
    }

    It '<Skill> implements the three-mode discovery contract' -ForEach @(
        @{ Skill = 'Copilot' }
        @{ Skill = 'Claude' }
    ) {
        $skillContent[$Skill] | Should -Match 'demo-builder'
        $skillContent[$Skill] | Should -Match 'advanced-builder'
        $skillContent[$Skill] | Should -Match 'framework-acceptance'
        $skillContent[$Skill] | Should -Match '(?i)six business questions plus one consolidated'
        $skillContent[$Skill] | Should -Match '(?i)table.{0,24}strategy'
        $skillContent[$Skill] | Should -Match '(?i)form.{0,24}strategy'
        $skillContent[$Skill] | Should -Match '(?i)environment.{0,30}authoriz|authoriz.{0,30}environment'
        $skillContent[$Skill] | Should -Match '(?i)retention'
        $skillContent[$Skill] | Should -Match '(?i)separately approved cleanup'
        $skillContent[$Skill] | Should -Match '(?i)same.{0,20}pipeline|shared.{0,20}(execution|pipeline)'
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