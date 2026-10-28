<#
=============================================================================
COMPONENT:    Repository Update Advisor
FILE:         scripts/bootstrap/helpers/repository-updates.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-27
ENVIRONMENT:  PowerShell 7 | Git | Local filesystem
OVERVIEW:     Compares repository snapshots and records diagnostic provenance.
ARCHITECTURE: Schema-validated catalog/context; Git subprocesses; no Dataverse.
SIDE EFFECTS: Opt-in fetch updates one private ref; explicit archive writes only.
TEST CASES:   Offline history states, relevance, dirty identity, immutable runs.
NON-NEGOTIABLES: Never pull, tag, push, adopt updates or authorize deployment.
=============================================================================
#>
Set-StrictMode -Version Latest
$script:repositoryUpdateRuntimeRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent

function Read-WizardRepositoryDocument {
    param([string]$Path, [string]$SchemaName)

    $json = [IO.File]::ReadAllText($Path)
    $schema = Join-Path $script:repositoryUpdateRuntimeRoot "schemas\repository-updates\$SchemaName.schema.json"
    if (-not (Test-Json -Json $json -SchemaFile $schema -ErrorAction Stop)) {
        throw "Repository update document failed $SchemaName schema validation."
    }
    return $json | ConvertFrom-Json
}

function Invoke-WizardRepositoryGit {
    param([string]$RepoRoot, [string[]]$Arguments)

    $git = Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $git.Source
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $info.Environment['GIT_TERMINAL_PROMPT'] = '0'
    $info.Environment['GCM_INTERACTIVE'] = 'Never'
    $info.Environment['GIT_OPTIONAL_LOCKS'] = '0'
    foreach ($argument in @('-C', $RepoRoot, '-c', 'credential.interactive=false') + $Arguments) {
        $info.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(20000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw 'Repository Git check timed out after 20 seconds.'
        }
        # Do not expose Git stderr: a remote URL may contain credentials.
        $null = $stderr.GetAwaiter().GetResult()
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.GetAwaiter().GetResult() }
    } finally {
        $process.Dispose()
    }
}

function Get-WizardRepositoryGitText {
    param([string]$RepoRoot, [string[]]$Arguments)

    $result = Invoke-WizardRepositoryGit -RepoRoot $RepoRoot -Arguments $Arguments
    if ($result.ExitCode -ne 0) { throw "Repository Git '$($Arguments[0])' failed (exit $($result.ExitCode))." }
    return $result.Output
}

function Get-WizardRepositoryCatalog {
    $catalog = Read-WizardRepositoryDocument -Path (Join-Path $script:repositoryUpdateRuntimeRoot 'repository-updates.json') -SchemaName catalog
    $duplicates = @($catalog.capabilities | Group-Object id | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) { throw 'Repository update catalog has duplicate capability IDs.' }
    return $catalog
}

function Get-WizardRepositoryBaseline {
    param([string]$RepoRoot, [DateTimeOffset]$CapturedAtUtc = [DateTimeOffset]::UtcNow)

    $baseline = [ordered]@{
        schemaVersion = '1.0'
        status = 'unverified'
        reason = ''
        repository = 'unknown'
        baselineId = "ppvs-$($CapturedAtUtc.UtcDateTime.ToString('yyyyMMddTHHmmssfffffffZ'))-unverified"
        commitSha = $null
        capturedAtUtc = $CapturedAtUtc.ToUniversalTime().ToString('o')
        contractVersion = $null
        workingTreeDirty = $null
        localChangesSha256 = $null
    }
    try {
        $catalog = Get-WizardRepositoryCatalog
        $baseline.repository = $catalog.repository
        $profile = Get-Content -LiteralPath (Join-Path $RepoRoot 'wizard.profile.json') -Raw | ConvertFrom-Json
        $baseline.contractVersion = [string]$profile.contractVersion
        $actualRoot = (Get-WizardRepositoryGitText $RepoRoot @('rev-parse', '--show-toplevel')).Trim()
        if ([IO.Path]::GetFullPath($actualRoot).TrimEnd('\', '/') -ne [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')) {
            throw 'Workspace is not the Git repository root.'
        }
        $baseline.commitSha = (Get-WizardRepositoryGitText $RepoRoot @('rev-parse', '--verify', 'HEAD^{commit}')).Trim()
        $status = Get-WizardRepositoryGitText $RepoRoot @('status', '--porcelain=v1', '-z', '--untracked-files=all')
        $working = Get-WizardRepositoryGitText $RepoRoot @('diff', '--binary', '--no-ext-diff', '--no-textconv', 'HEAD', '--')
        $staged = Get-WizardRepositoryGitText $RepoRoot @('diff', '--cached', '--binary', '--no-ext-diff', '--no-textconv', 'HEAD', '--')
        $untracked = Get-WizardRepositoryGitText $RepoRoot @('ls-files', '--others', '--exclude-standard', '-z')
        $parts = [Collections.Generic.List[string]]::new()
        foreach ($path in $untracked.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)) {
            $hash = (Get-FileHash -LiteralPath (Join-Path $RepoRoot $path) -Algorithm SHA256).Hash.ToLowerInvariant()
            $parts.Add("$path`0$hash")
        }
        $bytes = [Text.Encoding]::UTF8.GetBytes("$status`0$working`0$staged`0$($parts -join "`0")")
        $baseline.localChangesSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        $baseline.workingTreeDirty = $status.Length -gt 0
        $baseline.baselineId = "ppvs-$($CapturedAtUtc.UtcDateTime.ToString('yyyyMMddTHHmmssfffffffZ'))-$($baseline.commitSha.Substring(0, 12))"
        $baseline.status = 'verified'
    } catch {
        $baseline.reason = "Source identity unavailable: $($_.Exception.Message)"
    }
    return [pscustomobject]$baseline
}

function Get-WizardRepositoryRecommendations {
    param([object]$Catalog, [string[]]$ChangedFiles, [object]$Context)

    $enabled = @()
    $disabled = @()
    if ($null -ne $Context) {
        $enabled = @($Context.enabledCapabilities)
        $disabled = @($Context.disabledCapabilities)
        foreach ($id in $enabled + $disabled) {
            if ($id -notin @($Catalog.capabilities.id)) { throw "Unknown repository update capability: $id" }
            if ($id -in $enabled -and $id -in $disabled) { throw "Conflicting repository update capability: $id" }
            if ($id -in $disabled -and @($Catalog.capabilities | Where-Object id -eq $id)[0].scope -eq 'all') {
                throw "Universal repository update capability cannot be disabled: $id"
            }
        }
    }
    $matched = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($capability in $Catalog.capabilities) {
        $paths = @($ChangedFiles | Where-Object {
            $path = $_
            @($capability.paths | Where-Object { $path -clike $_ }).Count -gt 0
        })
        if ($paths.Count -eq 0) { continue }
        foreach ($path in $paths) { $null = $matched.Add($path) }
        $relevance = if ($capability.scope -eq 'all' -or $capability.id -in $enabled) { 'applicable' }
            elseif ($capability.id -in $disabled) { 'not-selected' } else { 'unknown' }
        $action = if ($relevance -eq 'not-selected') { 'not-applicable' }
            elseif ($relevance -eq 'unknown') { 'review-needed' }
            elseif ($capability.category -in @('governance', 'compatibility-review', 'experimental')) { 'review-required' }
            elseif ($capability.category -eq 'documentation') { 'informational' }
            elseif ($capability.scope -eq 'selected') { 'optional-review' } else { 'recommended-review' }
        [pscustomobject]@{
            capabilityId = $capability.id; title = $capability.title; category = $capability.category
            relevance = $relevance; action = $action
            reason = "$($capability.guidance) Relevance: $relevance; based on changed paths and explicit selections only."
            paths = $paths
        }
    }
    $unknown = @($ChangedFiles | Where-Object { -not $matched.Contains($_) })
    if ($unknown.Count -gt 0) {
        [pscustomobject]@{
            capabilityId = 'unclassified'; title = 'Unclassified changes'; category = 'unclassified'
            relevance = 'unknown'; action = 'review-needed'
            reason = 'No catalog rule matches these paths. Review manually; no compatibility or usefulness inferred.'
            paths = $unknown
        }
    }
}

function Get-WizardRepositoryUpdateReport {
    param(
        [string]$RepoRoot,
        [string]$Remote = '',
        [string]$Branch = '',
        [string]$BaselineCommit = 'HEAD',
        [string]$ScenarioSlug = '',
        [switch]$Fetch
    )

    $catalog = Get-WizardRepositoryCatalog
    if (-not $Remote) { $Remote = $catalog.remote }
    if (-not $Branch) { $Branch = $catalog.branch }
    if ($Remote -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') { throw 'Use a configured Git remote name, not a URL or option.' }
    if ($ScenarioSlug -and $ScenarioSlug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw 'Invalid scenario slug.' }
    $context = $null
    if ($ScenarioSlug) {
        $contextPath = Join-Path $RepoRoot "specs\$ScenarioSlug\repo-update-context.json"
        if (Test-Path -LiteralPath $contextPath) {
            $context = Read-WizardRepositoryDocument $contextPath context
            if ($context.scenarioSlug -cne $ScenarioSlug) { throw 'Repository update context scenario mismatch.' }
            $null = @(Get-WizardRepositoryRecommendations $catalog @() $context)
        }
    }
    $baseline = Get-WizardRepositoryBaseline -RepoRoot $RepoRoot
    $report = [ordered]@{
        schemaVersion = '1.0'; checkedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
        status = 'unable-to-check'; reason = ''
        freshness = 'cached-not-network-verified'; remote = $Remote; branch = $Branch
        comparisonBaseSha = $null; upstreamSha = $null; baseline = $baseline
        changedFiles = @(); recommendations = @()
    }
    try {
        if ($baseline.status -ne 'verified') { throw $baseline.reason }
        $null = Get-WizardRepositoryGitText $RepoRoot @('check-ref-format', "refs/heads/$Branch")
        $null = Get-WizardRepositoryGitText $RepoRoot @('remote', 'get-url', $Remote)
        $ref = "refs/remotes/$Remote/$Branch"
        $privateRef = "refs/wizard-update-check/$Remote/$Branch"
        if ($Fetch) {
            $report.freshness = 'fetch-failed'
            $ref = $privateRef
            $null = Get-WizardRepositoryGitText $RepoRoot @('fetch', '--no-tags', '--no-write-fetch-head', '--no-recurse-submodules', '--refmap=', $Remote, "+refs/heads/${Branch}:$ref")
            $report.freshness = 'fetched'
        } else {
            $cached = Invoke-WizardRepositoryGit $RepoRoot @('show-ref', '--verify', '--quiet', $privateRef)
            if ($cached.ExitCode -eq 0) { $ref = $privateRef }
            elseif ($cached.ExitCode -ne 1) { throw 'Unable to resolve cached update-check ref.' }
        }
        $report.comparisonBaseSha = (Get-WizardRepositoryGitText $RepoRoot @('rev-parse', '--verify', '--end-of-options', "$BaselineCommit^{commit}")).Trim()
        $report.upstreamSha = (Get-WizardRepositoryGitText $RepoRoot @('rev-parse', '--verify', '--end-of-options', "$ref^{commit}")).Trim()
        $merge = Invoke-WizardRepositoryGit $RepoRoot @('merge-base', $report.comparisonBaseSha, $report.upstreamSha)
        if ($merge.ExitCode -eq 1) {
            $shallow = (Get-WizardRepositoryGitText $RepoRoot @('rev-parse', '--is-shallow-repository')).Trim()
            if ($shallow -eq 'true') { throw 'History is shallow; fetch the required history explicitly before comparing.' }
            $report.status = 'unrelated-history'
            $report.reason = 'No shared ancestor; no adoption recommendation can be made.'
        } elseif ($merge.ExitCode -ne 0) {
            throw 'Unable to resolve shared Git history.'
        } else {
            $ancestor = $merge.Output.Trim()
            $report.status = if ($report.comparisonBaseSha -eq $report.upstreamSha) { 'up-to-date' }
                elseif ($ancestor -eq $report.comparisonBaseSha) { 'updates-available' }
                elseif ($ancestor -eq $report.upstreamSha) { 'local-ahead' } else { 'diverged' }
            if ($report.status -in @('updates-available', 'diverged')) {
                # Classify upstream-side changes only, not deletion of local-only work.
                $changed = Get-WizardRepositoryGitText $RepoRoot @('diff', '--name-only', '--no-renames', '-z', $ancestor, $report.upstreamSha, '--')
                $report.changedFiles = @($changed.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries))
                $report.recommendations = @(Get-WizardRepositoryRecommendations $catalog $report.changedFiles $context)
            }
            $report.reason = 'Compared resolved commits. Recommendations are advisory; no updates were applied.'
        }
    } catch {
        $report.status = 'unable-to-check'
        $report.reason = $_.Exception.Message
    }
    return [pscustomobject]$report
}

function Show-WizardRepositoryUpdateReport {
    param([object]$Report)

    if ($Report.status -eq 'unable-to-check') {
        Write-Warning "Repository update check: unable-to-check. $($Report.reason)"
        return
    }
    Write-Host "Repository updates: $($Report.status) [$($Report.freshness)]"
    Write-Host "Source baseline: $($Report.baseline.baselineId); locally modified: $($Report.baseline.workingTreeDirty)"
    foreach ($item in $Report.recommendations) {
        Write-Host "  [$($item.category)] $($item.title): $($item.action)"
    }
    Write-Host 'No updates applied. Cached metadata does not prove upstream is current.'
}

function Save-WizardRepositoryBaseline {
    param(
        [string]$RepoRoot,
        [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')] [string]$ScenarioSlug,
        [ValidatePattern('^[a-fA-F0-9-]{36}$')] [string]$RunId,
        [string]$SolutionUniqueName,
        [string]$PublisherPrefix,
        [object]$Baseline
    )

    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName) -or [string]::IsNullOrWhiteSpace($PublisherPrefix)) {
        throw 'Run repository baseline requires explicit solution and publisher identity.'
    }
    $record = [ordered]@{
        scenarioSlug = $ScenarioSlug; runId = ([guid]$RunId).ToString()
        solutionUniqueName = $SolutionUniqueName; publisherPrefix = $PublisherPrefix
    }
    foreach ($property in $Baseline.PSObject.Properties) {
        if ($record.Contains($property.Name)) { throw "Source baseline cannot override run identity: $($property.Name)" }
        $record[$property.Name] = $property.Value
    }
    $json = $record | ConvertTo-Json -Depth 10
    $schema = Join-Path $script:repositoryUpdateRuntimeRoot 'schemas\repository-updates\baseline.schema.json'
    if (-not (Test-Json -Json $json -SchemaFile $schema -ErrorAction Stop)) { throw 'Invalid repository baseline.' }
    $folder = Join-Path $RepoRoot ".wizard-metrics\artifacts\manifest\$ScenarioSlug\runs\$RunId"
    $path = Join-Path $folder 'repository-baseline.json'
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    if (Test-Path -LiteralPath $path) {
        $existing = [IO.File]::ReadAllText($path) | ConvertFrom-Json
        $expected = $json | ConvertFrom-Json
        if (($existing | ConvertTo-Json -Depth 10 -Compress) -cne ($expected | ConvertTo-Json -Depth 10 -Compress)) {
            throw 'An immutable run repository baseline already exists with different content.'
        }
        return $path
    }

    $tempPath = Join-Path $folder ".$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $stream = [IO.FileStream]::new($tempPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
            $stream.Write($bytes)
            $stream.Flush($true)
        } finally { $stream.Dispose() }
        [IO.File]::Move($tempPath, $path, $false)
    } finally {
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
    }
    return $path
}

function Assert-WizardRepositoryResumeBaseline {
    param([object]$Previous, [object]$Current)

    if ($null -eq $Previous) { throw 'Resume state has no repository baseline. Start a new run instead of relabeling historical work.' }
    if ($Previous.status -eq 'unverified' -and $Current.status -eq 'unverified') {
        Write-Warning 'Resume source identity remains unverified; Git reproducibility cannot be established.'
        return
    }
    foreach ($name in @('status', 'repository', 'commitSha', 'contractVersion', 'workingTreeDirty', 'localChangesSha256')) {
        if ($Previous.$name -cne $Current.$name) {
            throw "Resume repository baseline changed ($name). Start a new run after reviewing source changes."
        }
    }
}
