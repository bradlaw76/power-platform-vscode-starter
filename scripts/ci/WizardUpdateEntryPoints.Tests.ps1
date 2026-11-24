<#
=============================================================================
COMPONENT:    H009 Entry Point Acceptance
FILE:         scripts/ci/WizardUpdateEntryPoints.Tests.ps1
VERSION:      0.1.1
AUTHOR:       Power Platform VS Code Starter
ENVIRONMENT:  PowerShell 7 | Pester 5.7.1 | Windows and Linux
OVERVIEW:     Executes the real terminal and agent-shared offline commands.
NON-NEGOTIABLES: No home, cloud, tenant or application writes.
=============================================================================
#>
BeforeAll {
    $runtime = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $start = Join-Path $runtime 'scripts/bootstrap/05-start-wizard.ps1'
    $shared = Join-Path $runtime 'scripts/bootstrap/04-check-wizard-update.ps1'
    . (Join-Path $runtime 'scripts/bootstrap/helpers/wizard-version.ps1')
}

Describe 'H009 actual terminal and agent shared commands' {
    It 'U19 prints early unknown release and independent inspected versions without intake' {
        $output = & pwsh -NoProfile -NonInteractive -File $start -VersionOnly 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'release unknown - development checkout'
        $output | Should -Match 'Contract: 1.10.0 \| Profile: 1.6'
        $output | Should -Match 'offline-unknown'
        $output | Should -Not -Match 'Wizard output created:'
    }

    It 'U16 supports the actual shared agent command, not a separate updater' {
        $output = & pwsh -NoProfile -NonInteractive -File $shared -Action Status -RuntimeRoot $runtime -AsJson
        $LASTEXITCODE | Should -Be 0
        $status = $output | ConvertFrom-Json
        $status.installedRelease | Should -BeNullOrEmpty
        $status.contractVersion | Should -Be '1.10.0'
        $status.updateState | Should -Be 'offline-unknown'
        foreach ($file in @('.github/skills/power-platform-wizard-init/SKILL.md', '.claude/skills/power-platform-vscode-wizard/SKILL.md')) {
            $content = Get-Content (Join-Path $runtime $file) -Raw
            $content | Should -Match '04-check-wizard-update.ps1 -Action Status'
            $content | Should -Match 'Review/Update/Skip'
        }
    }

    It 'resolves relative runtime paths from the PowerShell location, not the process directory' {
        $expected = & git -C $runtime rev-parse --verify HEAD
        $LASTEXITCODE | Should -Be 0
        $processDirectory = [Environment]::CurrentDirectory
        Push-Location $runtime
        try {
            [Environment]::CurrentDirectory = $TestDrive
            $status = Get-WizardVersion -RuntimeRoot '.'
            $status.sourceRevision | Should -Be $expected
            $status.contractVersion | Should -Be '1.10.0'
        } finally {
            [Environment]::CurrentDirectory = $processDirectory
            Pop-Location
        }
    }

    It 'runs a copied no-Git runtime from a different caller directory with spaces' {
        $target = Join-Path $TestDrive 'runtime with spaces'
        $bootstrap = Join-Path $target 'scripts/bootstrap'
        $null = New-Item -ItemType Directory -Path (Join-Path $bootstrap 'helpers') -Force
        Copy-Item $shared (Join-Path $bootstrap '04-check-wizard-update.ps1')
        Copy-Item (Join-Path $runtime 'scripts/bootstrap/helpers/wizard-version.ps1') (Join-Path $bootstrap 'helpers/wizard-version.ps1')
        Copy-Item (Join-Path $runtime 'wizard.profile.json') $target
        Copy-Item (Join-Path $runtime 'wizard.release.json') $target
        Push-Location $TestDrive
        try {
            $output = & pwsh -NoProfile -NonInteractive -File (Join-Path $bootstrap '04-check-wizard-update.ps1') -Action Status -AsJson
            $LASTEXITCODE | Should -Be 0
            $status = $output | ConvertFrom-Json
            $status.sourceRevision | Should -BeNullOrEmpty
            $status.installedRelease | Should -BeNullOrEmpty
            $status.contractVersion | Should -Be '1.10.0'
            $status.updateState | Should -Be 'offline-unknown'
            Test-Path (Join-Path $target '.wizard-update') | Should -BeFalse
        } finally {
            Pop-Location
        }
    }

    It 'U17 Skip succeeds with no Python or target writes' {
        $target = Join-Path $TestDrive 'no-runtime'
        $null = New-Item -ItemType Directory $target
        $before = @(Get-ChildItem -Force $target).Count
        $output = & pwsh -NoProfile -NonInteractive -File $shared -Action Skip -RuntimeRoot $target -PythonExecutable 'missing-h009-python' -AsJson
        $LASTEXITCODE | Should -Be 0
        ($output | ConvertFrom-Json).status | Should -Be 'skipped'
        @(Get-ChildItem -Force $target).Count | Should -Be $before
    }

    It 'U09 missing runtime and invalid metadata report diagnostics without blocking' {
        $target = Join-Path $TestDrive 'copied-skill'
        $null = New-Item -ItemType Directory $target
        (Get-WizardVersion -RuntimeRoot $target).diagnostics | Should -Not -BeNullOrEmpty
        Set-Content (Join-Path $target 'wizard.profile.json') '{broken'
        Set-Content (Join-Path $target 'wizard.release.json') '{broken'
        $status = Get-WizardVersion -RuntimeRoot $target
        $status.installedRelease | Should -BeNullOrEmpty
        $status.updateState | Should -Be 'unverified'
        $status.diagnostics.Count | Should -BeGreaterThan 0
    }

    It 'U06 a descriptor release claim is never installed provenance' {
        $target = Join-Path $TestDrive 'claimed-release'
        $null = New-Item -ItemType Directory $target
        Set-Content (Join-Path $target 'wizard.release.json') '{"schemaVersion":"1.0","product":"power-platform-vscode-starter","releaseVersion":"99.0.0"}'
        $status = Get-WizardVersion -RuntimeRoot $target
        $status.installedRelease | Should -BeNullOrEmpty
        $status.updateState | Should -Be 'unverified'
    }

    It 'U03 unavailable optional version helper does not block the startup-only path' {
        $target = Join-Path $TestDrive 'partial-runtime/scripts/bootstrap'
        $null = New-Item -ItemType Directory -Path $target -Force
        $copiedStart = Join-Path $target '05-start-wizard.ps1'
        Copy-Item $start $copiedStart
        $output = & pwsh -NoProfile -NonInteractive -File $copiedStart -VersionOnly 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0
        $output | Should -Match 'version status unavailable'
        $output | Should -Match 'no update authorized'
    }
}
