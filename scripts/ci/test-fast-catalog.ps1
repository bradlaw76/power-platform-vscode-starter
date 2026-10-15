<#
=============================================================================
COMPONENT:    FAST Catalog Infrastructure Tests
FILE:         scripts/ci/test-fast-catalog.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Credential-free CI
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixtureRoot = Join-Path $PSScriptRoot 'fixtures/fast'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "fast-catalog-$([guid]::NewGuid().ToString('N'))"

. (Join-Path $repoRoot 'scripts/accelerators/accelerator-catalog.ps1')
. (Join-Path $repoRoot 'scripts/accelerators/fast-provider.ps1')

try {
    $registryPath = Join-Path $repoRoot 'accelerator.providers.json'
    $registry = Get-AcceleratorProviderRegistry -RegistryPath $registryPath -RepoRoot $repoRoot
    if ($registry.Providers.Count -ne 1 -or $registry.Providers[0].Enabled) {
        throw 'FAST provider must be registered and disabled by default.'
    }
    if (@(Get-EnabledAcceleratorProviders -RegistryPath $registryPath -RepoRoot $repoRoot).Count -ne 0) {
        throw 'Disabled FAST provider was returned as enabled.'
    }

    $source = Get-FastCatalogItemsFromSourceTree -SourceRoot (Join-Path $fixtureRoot 'source')
    if (@($source.Items).Count -ne 5) {
        throw 'Fixture source discovery did not enumerate every supported collection dynamically.'
    }
    $future = @($source.Items | Where-Object slug -eq 'future-module')
    if ($future.Count -ne 1 -or @($future[0].documentedReleaseLinks).Count -ne 1) {
        throw 'A newly added module or its official release link was not discovered.'
    }

    $releaseDocuments = @(Get-Content -LiteralPath (Join-Path $fixtureRoot 'releases.json') -Raw | ConvertFrom-Json)
    $releases = @(ConvertTo-FastReleaseInventory -ReleaseDocuments $releaseDocuments)
    if ($releases.Count -ne 2 -or @($releases | Where-Object tag -eq 'future-module/v2.0.0.0').Count -ne 1) {
        throw 'Dynamic release discovery did not preserve slash-delimited tags.'
    }

    $coverage = @{ modules = 2; releases = 2 }
    $first = New-AcceleratorCatalogSnapshot -ProviderId microsoft-fast -Items $source.Items -Releases $releases -Coverage $coverage
    $second = New-AcceleratorCatalogSnapshot -ProviderId microsoft-fast -Items @($source.Items | Sort-Object itemId -Descending) -Releases @($releases | Sort-Object releaseId -Descending) -Coverage $coverage
    if ($first.snapshotId -cne $second.snapshotId) {
        throw 'Equivalent normalized catalog content produced different snapshot IDs.'
    }
    Start-Sleep -Milliseconds 20
    $refetchedSource = Get-FastCatalogItemsFromSourceTree -SourceRoot (Join-Path $fixtureRoot 'source')
    $refetched = New-AcceleratorCatalogSnapshot -ProviderId microsoft-fast -SourceManifest $refetchedSource.SourceManifest -Items $refetchedSource.Items -Releases $releases -Coverage $coverage
    $withInitialRetrieval = New-AcceleratorCatalogSnapshot -ProviderId microsoft-fast -SourceManifest $source.SourceManifest -Items $source.Items -Releases $releases -Coverage $coverage
    if ($refetched.snapshotId -cne $withInitialRetrieval.snapshotId) {
        throw 'Source retrieval timestamps changed an otherwise identical content-addressed snapshot.'
    }

    $write = Write-AcceleratorCatalogSnapshot -Snapshot $first -SnapshotRoot $tempRoot
    $repeat = Write-AcceleratorCatalogSnapshot -Snapshot $second -SnapshotRoot $tempRoot
    if ($write.Action -ne 'created' -or $repeat.Action -ne 'already-exists') {
        throw 'Immutable snapshot write behavior is incorrect.'
    }
    Set-AcceleratorPromotedSnapshot -ProviderId microsoft-fast -SnapshotId $first.snapshotId -SnapshotRoot $tempRoot | Out-Null
    $promoted = Get-AcceleratorPromotedSnapshot -ProviderId microsoft-fast -SnapshotRoot $tempRoot
    if ($promoted.snapshotId -cne $first.snapshotId) {
        throw 'Promoted snapshot could not be retrieved offline.'
    }

    $syncRoot = Join-Path $tempRoot 'fixture-sync'
    $sync = & (Join-Path $repoRoot 'scripts/accelerators/sync-fast-catalog.ps1') `
        -SourceMode Fixture `
        -EnableFast `
        -SourceRoot (Join-Path $fixtureRoot 'source') `
        -ReleasesJsonPath (Join-Path $fixtureRoot 'releases.json') `
        -SnapshotRoot $syncRoot `
        -Promote
    if ($sync.Snapshot.coverage.modules -ne 2 -or
        $sync.Snapshot.coverage.releases -ne 2 -or
        -not (Test-Path -LiteralPath $sync.PromotionPath -PathType Leaf)) {
        throw 'Fixture synchronization did not create and promote the expected catalog snapshot.'
    }
    $snapshotJson = $sync.Snapshot | ConvertTo-Json -Depth 100
    if (-not (Test-Json -Json $snapshotJson -SchemaFile (Join-Path $repoRoot 'schemas/accelerators/catalog-snapshot.schema.json') -ErrorAction Stop)) {
        throw 'Generated catalog snapshot does not match its schema.'
    }

    $changedItems = @($source.Items | Where-Object itemId -ne 'microsoft-fast:persona:investigator')
    $changedItems[0].name = 'Changed Core'
    $changedItems += [pscustomobject]@{ itemId = 'microsoft-fast:module:added'; name = 'Added' }
    $changed = New-AcceleratorCatalogSnapshot -ProviderId microsoft-fast -Items $changedItems
    $difference = Compare-AcceleratorCatalogSnapshot -Previous $first -Current $changed
    if ($difference.Added -notcontains 'microsoft-fast:module:added' -or
        $difference.Removed -notcontains 'microsoft-fast:persona:investigator' -or
        $difference.Changed.Count -ne 1) {
        throw 'Catalog added, changed, and removed detection is incorrect.'
    }

    $offlineOutput = & (Join-Path $repoRoot 'scripts/accelerators/sync-fast-catalog.ps1') `
        -SourceMode Live `
        -EnableFast `
        -SnapshotRoot $tempRoot `
        -AllowOfflineFallback `
        -RequestInvoker { throw 'simulated source outage' }
    if ("$($offlineOutput.snapshotId)" -cne $first.snapshotId) {
        throw 'Offline fallback did not return only the promoted snapshot.'
    }
    try {
        & (Join-Path $repoRoot 'scripts/accelerators/sync-fast-catalog.ps1') `
            -SourceMode Live `
            -EnableFast `
            -SnapshotRoot (Join-Path $tempRoot 'empty') `
            -RequestInvoker { throw 'simulated source outage' }
        throw 'Expected unavailable-source failure without explicit fallback.'
    } catch {
        if ($_.Exception.Message -notmatch 'simulated source outage') {
            throw
        }
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'FAST catalog infrastructure tests passed.' -ForegroundColor Green
