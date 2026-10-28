<#
=============================================================================
COMPONENT:    Quality Runner Regression Tests
FILE:         scripts/ci/QualityRunner.Tests.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Pester 5
-----------------------------------------------------------------------------
OVERVIEW
Isolates aggregate status propagation without rerunning the repository suites.
=============================================================================
#>
Describe 'Quality runner result propagation' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
        $runnerPath = Join-Path $repoRoot 'run-quality.ps1'
    }

    It 'parses the summary interpolation without errors' {
        $tokens = $null; $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($runnerPath, [ref]$tokens, [ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }

    It 'returns the actual aggregate exit code for <Failure>' -TestCases @(
        @{ Failure = 'none'; Expected = 0 },
        @{ Failure = 'markdown'; Expected = 1 },
        @{ Failure = 'parse'; Expected = 1 },
        @{ Failure = 'analyzer'; Expected = 1 },
        @{ Failure = 'json'; Expected = 1 },
        @{ Failure = 'contract'; Expected = 1 },
        @{ Failure = 'standalone'; Expected = 1 },
        @{ Failure = 'pester'; Expected = 1 },
        @{ Failure = 'pester-container'; Expected = 1 }
    ) {
        param($Failure, $Expected)
        $fixture = Join-Path $TestDrive $Failure
        New-Item -Path (Join-Path $fixture 'scripts\ci') -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $runnerPath -Destination (Join-Path $fixture 'run-quality.ps1')
        Set-Content -LiteralPath (Join-Path $fixture 'scripts\ci\test-json-schema.ps1') -Value $(if ($Failure -eq 'json') { "throw 'Mock JSON failure'" } else { '$null = 1' })
        Set-Content -LiteralPath (Join-Path $fixture 'scripts\ci\test-contract-integrity.ps1') -Value $(if ($Failure -eq 'contract') { "throw 'Mock contract failure'" } else { '$null = 1' })
        Set-Content -LiteralPath (Join-Path $fixture 'scripts\ci\test-isolated.ps1') -Value $(if ($Failure -eq 'parse') { 'function {' } else { '$null = 1' })
        $command = @"
Set-Location -LiteralPath '$($fixture.Replace("'", "''"))'
function npx { `$global:LASTEXITCODE = $(if ($Failure -eq 'markdown') { 1 } else { 0 }) }
function Import-Module {}
function Invoke-ScriptAnalyzer { $(if ($Failure -eq 'analyzer') { "'Mock analyzer finding'" } else { '' }) }
function pwsh { `$global:LASTEXITCODE = $(if ($Failure -eq 'standalone') { 1 } else { 0 }) }
function Invoke-Pester { [pscustomobject]@{ PassedCount = 1; FailedCount = $(if ($Failure -eq 'pester') { 1 } else { 0 }); Result = '$(if ($Failure -like 'pester*') { 'Failed' } else { 'Passed' })' } }
& '.\run-quality.ps1'
"@
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $output = & @(Get-Command pwsh -CommandType Application)[0].Source -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
        $LASTEXITCODE | Should -Be $Expected -Because ($output -join [Environment]::NewLine)
    }

    It 'checks the current demo-timer prompt instead of obsolete copy' {
        $smoke = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\ci\test-script-smoke.ps1') -Raw
        $wizard = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\bootstrap\06-demo-script-wizard.ps1') -Raw
        $prompt = 'How long should the demo timer run, in minutes?'
        $smoke.Contains($prompt) | Should -BeTrue
        $wizard.Contains($prompt) | Should -BeTrue
        $smoke.Contains('How long should the demo be, in minutes?') | Should -BeFalse
    }
}
