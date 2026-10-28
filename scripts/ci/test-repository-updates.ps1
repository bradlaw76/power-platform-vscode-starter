<#
=============================================================================
COMPONENT:    Repository Update Advisor Regression Tests
FILE:         scripts/ci/test-repository-updates.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-27
ENVIRONMENT:  PowerShell 7 | Git | Credential-free local fixtures
OVERVIEW:     Exercises history, relevance, fingerprints and immutable baselines.
ARCHITECTURE: Temporary repositories and local remotes; no external network.
TEST CASES:   All comparison states, fetch failure, schemas, resume, CLI.
NON-NEGOTIABLES: Never change the operator repository or contact Dataverse.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts\bootstrap\helpers\repository-updates.ps1')
$fixture = Join-Path ([IO.Path]::GetTempPath()) "repo-updates-$([guid]::NewGuid().ToString('N'))"
$origin = Join-Path $fixture 'origin'
$client = Join-Path $fixture 'client'
$script:assertions = 0

function Assert-Update {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
    $script:assertions++
}
function Assert-UpdateBlocked {
    param([scriptblock]$Action, [string]$Pattern)
    $message = ''
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-Update ($message -match $Pattern) "Expected failure '$Pattern', got '$message'."
}
function Invoke-FixtureGit {
    param([string]$Root, [string[]]$Arguments)
    return (Get-WizardRepositoryGitText $Root $Arguments).Trim()
}
function Save-FixtureFile {
    param([string]$Root, [string]$Path, [string]$Content)
    $fullPath = Join-Path $Root $Path
    [IO.Directory]::CreateDirectory((Split-Path $fullPath -Parent)) | Out-Null
    [IO.File]::WriteAllText($fullPath, $Content)
}
function Save-FixtureCommit {
    param([string]$Root)
    $null = Invoke-FixtureGit $Root @('add', '--all')
    $null = Invoke-FixtureGit $Root @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'core.hooksPath=', 'commit', '--no-gpg-sign', '-m', 'fixture change')
    return Invoke-FixtureGit $Root @('rev-parse', 'HEAD')
}
function Assert-UpdateSchema {
    param([object]$Value, [string]$Name)
    $json = $Value | ConvertTo-Json -Depth 30
    Assert-Update (Test-Json -Json $json -SchemaFile (Join-Path $repoRoot "schemas\repository-updates\$Name.schema.json")) "$Name schema rejected output."
}

try {
    [IO.Directory]::CreateDirectory($origin) | Out-Null
    $null = Invoke-FixtureGit $origin @('init', '-b', 'main')
    Save-FixtureFile $origin 'wizard.profile.json' '{"contractVersion":"2.2.0"}'
    Save-FixtureFile $origin '.gitignore' ".wizard-metrics/`n"
    Save-FixtureFile $origin 'docs\guide.md' 'original'
    $initial = Save-FixtureCommit $origin
    $null = Invoke-FixtureGit $fixture @('clone', $origin, $client)
    $clean = Get-WizardRepositoryBaseline $client ([DateTimeOffset]'2026-10-27T19:00:00Z')
    Assert-Update ($clean.status -eq 'verified' -and -not $clean.workingTreeDirty) 'Clean Git baseline must be verified.'
    Assert-Update ($clean.commitSha -eq $initial -and $clean.baselineId -match '^ppvs-20261027T1900000000000Z-') 'Timestamp/full SHA identity is wrong.'
    Assert-UpdateSchema $clean baseline
    $report = Get-WizardRepositoryUpdateReport $client
    Assert-Update ($report.status -eq 'up-to-date' -and $report.freshness -eq 'cached-not-network-verified') 'Initial cached comparison failed.'
    Assert-UpdateSchema $report report

    Save-FixtureFile $origin 'scripts\bootstrap\65-build-web-resources.ps1' 'fixture report change'
    Save-FixtureFile $origin 'unknown.bin' 'unknown'
    Save-FixtureFile $origin 'docs\guide.md' 'updated'
    $upstream = Save-FixtureCommit $origin
    $null = Invoke-FixtureGit $origin @('tag', 'fixture-upstream-tag')
    Assert-Update ((Get-WizardRepositoryUpdateReport $client).status -eq 'up-to-date') 'Default check unexpectedly fetched.'
    $before = Get-WizardRepositoryBaseline $client
    $report = Get-WizardRepositoryUpdateReport -RepoRoot $client -Fetch
    Assert-Update ($report.status -eq 'updates-available' -and $report.freshness -eq 'fetched') 'Opt-in local-remote fetch failed.'
    Assert-Update ($report.comparisonBaseSha -eq $initial -and $report.upstreamSha -eq $upstream) 'Report must identify exact compared commits.'
    Assert-Update (@($report.changedFiles).Count -eq 3) 'Changed-file comparison is incomplete.'
    Assert-Update (@($report.recommendations | Where-Object { $_.capabilityId -eq 'html-reports' -and $_.action -eq 'review-needed' }).Count -eq 1) 'Unknown optional relevance must require review.'
    Assert-Update (@($report.recommendations | Where-Object capabilityId -eq 'unclassified').Count -eq 1) 'Unclassified changes must remain visible.'
    Assert-UpdateSchema $report report
    $after = Get-WizardRepositoryBaseline $client
    Assert-Update ($before.commitSha -eq $after.commitSha -and $before.localChangesSha256 -eq $after.localChangesSha256) 'Fetch changed source HEAD/index/worktree.'
    Assert-Update (-not (Test-Path -LiteralPath (Join-Path $client '.git\FETCH_HEAD'))) 'Fetch must not write FETCH_HEAD.'
    Assert-Update ((Invoke-FixtureGit $client @('tag', '--list')).Length -eq 0) 'Fetch must not create local tags.'
    Assert-Update ((Invoke-FixtureGit $client @('rev-parse', 'refs/remotes/origin/main')) -eq $initial) 'Advisor fetch must not overwrite normal remote-tracking refs.'
    Assert-Update ((Get-WizardRepositoryUpdateReport $client).status -eq 'updates-available') 'Later local checks must reuse the advisor fetch cache.'

    $context = [pscustomobject]@{ schemaVersion = '1.0'; scenarioSlug = 'sample'; enabledCapabilities = @('html-reports'); disabledCapabilities = @('fast') }
    Save-FixtureFile $client 'specs\sample\repo-update-context.json' ($context | ConvertTo-Json)
    Assert-UpdateSchema $context context
    $report = Get-WizardRepositoryUpdateReport -RepoRoot $client -ScenarioSlug sample
    Assert-Update (@($report.recommendations | Where-Object { $_.capabilityId -eq 'html-reports' -and $_.action -eq 'optional-review' }).Count -eq 1) 'Explicit selected capability must be relevant.'
    $context.enabledCapabilities = @()
    $context.disabledCapabilities = @('html-reports')
    Save-FixtureFile $client 'specs\sample\repo-update-context.json' ($context | ConvertTo-Json)
    $report = Get-WizardRepositoryUpdateReport -RepoRoot $client -ScenarioSlug sample
    Assert-Update (@($report.recommendations | Where-Object { $_.capabilityId -eq 'html-reports' -and $_.action -eq 'not-applicable' }).Count -eq 1) 'Explicit opt-out must be preserved.'
    $context.enabledCapabilities = @('html-reports')
    Save-FixtureFile $client 'specs\sample\repo-update-context.json' ($context | ConvertTo-Json)
    Assert-UpdateBlocked { Get-WizardRepositoryUpdateReport -RepoRoot $client -ScenarioSlug sample } 'Conflicting'
    $context.enabledCapabilities = @('unknown-capability')
    $context.disabledCapabilities = @()
    Save-FixtureFile $client 'specs\sample\repo-update-context.json' ($context | ConvertTo-Json)
    Assert-UpdateBlocked { Get-WizardRepositoryUpdateReport -RepoRoot $client -ScenarioSlug sample } 'Unknown'
    $context.enabledCapabilities = @()
    $context.disabledCapabilities = @('semantic-fields')
    Save-FixtureFile $client 'specs\sample\repo-update-context.json' ($context | ConvertTo-Json)
    Assert-UpdateBlocked { Get-WizardRepositoryUpdateReport -RepoRoot $client -ScenarioSlug sample } 'cannot be disabled'
    $context.scenarioSlug = 'wrong'
    Save-FixtureFile $client 'specs\sample\repo-update-context.json' ($context | ConvertTo-Json)
    Assert-UpdateBlocked { Get-WizardRepositoryUpdateReport -RepoRoot $client -ScenarioSlug sample } 'scenario mismatch'
    Remove-Item -LiteralPath (Join-Path $client 'specs\sample\repo-update-context.json')
    Assert-UpdateBlocked { Get-WizardRepositoryUpdateReport -RepoRoot $client -Remote '--upload-pack=bad' } 'configured Git remote'
    $invalidBranch = Get-WizardRepositoryUpdateReport -RepoRoot $client -Branch 'bad..branch'
    Assert-Update ($invalidBranch.status -eq 'unable-to-check') 'Invalid branch accepted.'
    $missingBase = Get-WizardRepositoryUpdateReport -RepoRoot $client -BaselineCommit 'missing-commit'
    Assert-Update ($missingBase.status -eq 'unable-to-check') 'Missing baseline accepted.'
    $explicitBase = Get-WizardRepositoryUpdateReport -RepoRoot $client -BaselineCommit $initial
    Assert-Update ($explicitBase.comparisonBaseSha -eq $initial) 'Explicit historical baseline ignored.'

    Save-FixtureFile $client 'local.txt' 'local committed work'
    $localCommit = Save-FixtureCommit $client
    Assert-Update ((Get-WizardRepositoryUpdateReport $client).status -eq 'diverged') 'Diverged history not detected.'
    $null = Invoke-FixtureGit $client @('update-ref', 'refs/wizard-update-check/origin/main', $initial)
    Assert-Update ((Get-WizardRepositoryUpdateReport $client).status -eq 'local-ahead') 'Local-ahead history not detected.'
    $null = Invoke-FixtureGit $origin @('checkout', '--orphan', 'unrelated')
    Save-FixtureFile $origin 'orphan.txt' 'unrelated work'
    $orphan = Save-FixtureCommit $origin
    Assert-Update ((Get-WizardRepositoryUpdateReport -RepoRoot $client -Branch unrelated -Fetch).status -eq 'unrelated-history') 'Unrelated history not detected.'
    $null = Invoke-FixtureGit $client @('remote', 'set-url', 'origin', (Join-Path $fixture 'absent'))
    $failedFetch = Get-WizardRepositoryUpdateReport -RepoRoot $client -Fetch
    Assert-Update ($failedFetch.status -eq 'unable-to-check' -and $failedFetch.freshness -eq 'fetch-failed') 'Failed fetch must not fall back to cached success.'
    Assert-Update (-not ($failedFetch.reason.Contains($fixture))) 'Report leaked remote path.'
    $null = Invoke-FixtureGit $client @('remote', 'set-url', 'origin', $origin)

    Save-FixtureFile $client 'docs\guide.md' 'dirty tracked'
    $dirty = Get-WizardRepositoryBaseline $client
    Assert-Update ($dirty.workingTreeDirty -and $dirty.localChangesSha256 -ne $clean.localChangesSha256) 'Tracked edits not fingerprinted.'
    Save-FixtureFile $client 'new.txt' 'untracked one'
    $untrackedOne = Get-WizardRepositoryBaseline $client
    Save-FixtureFile $client 'new.txt' 'untracked two'
    $untrackedTwo = Get-WizardRepositoryBaseline $client
    Assert-Update ($untrackedOne.localChangesSha256 -ne $untrackedTwo.localChangesSha256) 'Untracked contents not fingerprinted.'
    $null = Invoke-FixtureGit $client @('add', 'docs/guide.md')
    $staged = Get-WizardRepositoryBaseline $client
    Assert-Update ($staged.localChangesSha256 -ne $untrackedTwo.localChangesSha256) 'Index state not fingerprinted.'
    $runId = [guid]::NewGuid().ToString()
    $archiveArguments = @{ RepoRoot = $client; ScenarioSlug = 'sample'; RunId = $runId; SolutionUniqueName = 'SampleSolution'; PublisherPrefix = 'sample' }
    $path = Save-WizardRepositoryBaseline @archiveArguments -Baseline $staged
    $originalHash = (Get-FileHash -LiteralPath $path).Hash
    $null = Save-WizardRepositoryBaseline @archiveArguments -Baseline $staged
    Assert-Update ((Get-FileHash -LiteralPath $path).Hash -eq $originalHash) 'Idempotent baseline archive changed bytes.'
    Assert-UpdateBlocked { Save-WizardRepositoryBaseline @archiveArguments -Baseline $clean } 'immutable'
    $archiveArguments.SolutionUniqueName = 'DifferentSolution'
    Assert-UpdateBlocked { Save-WizardRepositoryBaseline @archiveArguments -Baseline $staged } 'immutable'
    $archiveArguments.SolutionUniqueName = 'SampleSolution'
    $secondRunArguments = $archiveArguments.Clone()
    $secondRunArguments.RunId = [guid]::NewGuid().ToString()
    $secondPath = Save-WizardRepositoryBaseline @secondRunArguments -Baseline $clean
    Assert-Update ($path -ne $secondPath -and (Get-FileHash -LiteralPath $path).Hash -eq $originalHash) 'A new run must preserve the previous archived baseline.'
    Assert-UpdateBlocked { Save-WizardRepositoryBaseline -RepoRoot $client -ScenarioSlug sample -RunId $runId -Baseline $clean } 'explicit solution'
    Assert-Update ((Get-WizardRepositoryBaseline $client).localChangesSha256 -eq $staged.localChangesSha256) 'Ignored provenance altered source fingerprint.'
    Assert-WizardRepositoryResumeBaseline $staged (Get-WizardRepositoryBaseline $client)
    Assert-UpdateBlocked { Assert-WizardRepositoryResumeBaseline $staged $dirty } 'baseline changed'
    Assert-UpdateBlocked { Assert-WizardRepositoryResumeBaseline $null $dirty } 'no repository baseline'
    $noGit = Join-Path $fixture 'no-git'
    Save-FixtureFile $noGit 'wizard.profile.json' '{"contractVersion":"2.2.0"}'
    $unverified = Get-WizardRepositoryBaseline $noGit
    Assert-Update ($unverified.status -eq 'unverified' -and $unverified.reason.Length -gt 0) 'Missing Git must be explicitly unverified.'
    Assert-UpdateSchema $unverified baseline
    Assert-WizardRepositoryResumeBaseline $unverified $unverified

    $cli = Join-Path $repoRoot 'scripts\bootstrap\check-repository-updates.ps1'
    & pwsh -NoProfile -NonInteractive -File $cli -WorkspaceRoot $client -OutputFolder (Join-Path $client '.wizard-metrics\updates')
    Assert-Update ($LASTEXITCODE -eq 0) 'Standalone CLI comparison failed.'
    $saved = Read-WizardRepositoryDocument (Join-Path $client '.wizard-metrics\updates\repository-update-report.json') report
    Assert-Update ($saved.baseline.commitSha -eq $localCommit) 'CLI report lost baseline identity.'
    & pwsh -NoProfile -NonInteractive -File $cli -WorkspaceRoot $noGit *> $null
    Assert-Update ($LASTEXITCODE -ne 0) 'Standalone CLI must exit nonzero when unable to check.'

    $startup = Join-Path $repoRoot 'scripts\bootstrap\05-start-wizard.ps1'
    $startupLog = Join-Path $fixture 'startup.log'
    $missingAnswers = Join-Path $fixture 'absent-answers.json'
    & pwsh -NoProfile -NonInteractive -File $startup -WorkspaceRoot $client -AnswersFile $missingAnswers *> $startupLog
    Assert-Update ($LASTEXITCODE -ne 0) 'Missing answers fixture should stop before discovery.'
    $startupText = [IO.File]::ReadAllText($startupLog)
    Assert-Update ($startupText -match 'Repository updates: local-ahead') 'Terminal startup did not automatically show local update advice.'
    & pwsh -NoProfile -NonInteractive -File $startup -WorkspaceRoot $client -AnswersFile $missingAnswers -SkipRepositoryUpdateCheck *> $startupLog
    Assert-Update ($LASTEXITCODE -ne 0) 'Skipped advisor must still enforce the answers-file gate.'
    Assert-Update ([IO.File]::ReadAllText($startupLog) -notmatch 'Repository updates:|Source baseline:') 'Skip switch did not suppress the startup advisor.'
    & pwsh -NoProfile -NonInteractive -File $startup -FetchRepositoryUpdates -SkipRepositoryUpdateCheck *> $startupLog
    Assert-Update ($LASTEXITCODE -ne 0 -and [IO.File]::ReadAllText($startupLog) -match 'cannot be combined') 'Conflicting startup switches must fail before discovery/fetch.'

    $shallow = Join-Path $fixture 'shallow'
    $originUri = [Uri]::new("$origin$([IO.Path]::DirectorySeparatorChar)").AbsoluteUri
    $null = Invoke-FixtureGit $fixture @('clone', '--depth=1', '--branch', 'main', $originUri, $shallow)
    $null = Invoke-FixtureGit $shallow @('fetch', '--depth=1', '--no-tags', 'origin', '+refs/heads/unrelated:refs/remotes/origin/unrelated')
    $shallowReport = Get-WizardRepositoryUpdateReport -RepoRoot $shallow -Branch unrelated
    Assert-Update ($shallowReport.status -eq 'unable-to-check' -and $shallowReport.reason -match 'shallow') 'Shallow history must not be called unrelated/up-to-date without proof.'
    Assert-Update ($orphan -ne $initial) 'Fixture did not produce unrelated history.'
    Write-Host "Repository update advisor passed: $script:assertions assertions; local fixture remotes only." -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
