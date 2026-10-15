<#
=============================================================================
COMPONENT:    FAST Catalog Synchronization
FILE:         scripts/accelerators/sync-fast-catalog.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | GitHub REST | Offline solution ZIP inspection

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Creates immutable FAST catalog snapshots from live or fixture sources. The
provider remains disabled unless this script receives the explicit enable flag.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            explicit catalog synchronization entry point
- Inputs:          live sources or fixture tree/releases; optional ZIP folder
- Outputs:         candidate snapshot and optional promotion pointer
- Dependencies:    accelerator-catalog.ps1 and fast-provider.ps1
- Side Effects:    approved source reads and explicit snapshot-folder writes

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Invocation without -EnableFast stops before source or package access.
✔ Fixture and live discovery share normalized snapshot contracts.
✔ Source failure can return only a previously promoted snapshot when requested.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never import solution packages or connect to Dataverse.
- Never overwrite an immutable snapshot.
- Never promote a partial or failed candidate implicitly.
=============================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Live', 'Fixture')]
    [string]$SourceMode,
    [switch]$EnableFast,
    [string]$SourceRoot = '',
    [string]$ReleasesJsonPath = '',
    [string]$PackageFolder = '',
    [Parameter(Mandatory)]
    [string]$SnapshotRoot,
    [switch]$Promote,
    [switch]$AllowOfflineFallback,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'accelerator-catalog.ps1')
. (Join-Path $PSScriptRoot 'fast-provider.ps1')

if (-not $EnableFast) {
    throw 'FAST catalog synchronization is disabled by default. Pass -EnableFast for an explicit catalog-only run.'
}

$discovery = $null
if ($SourceMode -eq 'Fixture') {
    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw "Fixture source root not found: $SourceRoot"
    }
    if (-not (Test-Path -LiteralPath $ReleasesJsonPath -PathType Leaf)) {
        throw "Fixture release inventory not found: $ReleasesJsonPath"
    }
    $sourceResult = Get-FastCatalogItemsFromSourceTree -SourceRoot $SourceRoot
    $releaseDocuments = @(Get-Content -LiteralPath $ReleasesJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    $releases = @(ConvertTo-FastReleaseInventory -ReleaseDocuments $releaseDocuments)
    $discovery = [pscustomobject]@{
        Items = @($sourceResult.Items)
        Releases = $releases
        SourceManifest = @($sourceResult.SourceManifest)
        Coverage = [ordered]@{
            documents = @($sourceResult.Items).Count
            modules = @($sourceResult.Items | Where-Object itemType -eq 'module').Count
            useCases = @($sourceResult.Items | Where-Object itemType -eq 'use-case').Count
            personas = @($sourceResult.Items | Where-Object itemType -eq 'persona').Count
            dataModels = @($sourceResult.Items | Where-Object itemType -eq 'data-model').Count
            releases = $releaseDocuments.Count
        }
    }
} else {
    try {
        $discovery = Invoke-FastSourceDiscovery -RequestInvoker $RequestInvoker
    } catch {
        if (-not $AllowOfflineFallback) {
            throw
        }
        Write-Warning "FAST live source discovery failed; using only the promoted snapshot because -AllowOfflineFallback was specified. $($_.Exception.Message)"
        $promoted = Get-AcceleratorPromotedSnapshot -ProviderId 'microsoft-fast' -SnapshotRoot $SnapshotRoot -AllowMissing
        if ($null -eq $promoted) {
            throw 'FAST live source discovery failed and no promoted snapshot is available.'
        }
        $promoted
        return
    }
}

$packages = [Collections.Generic.List[object]]::new()
$packageManifest = [Collections.Generic.List[object]]::new()
if (-not [string]::IsNullOrWhiteSpace($PackageFolder)) {
    if (-not (Test-Path -LiteralPath $PackageFolder -PathType Container)) {
        throw "FAST package folder not found: $PackageFolder"
    }
    foreach ($zip in @(Get-ChildItem -LiteralPath $PackageFolder -Filter '*.zip' -File | Sort-Object Name)) {
        $assetMatches = @($discovery.Releases | ForEach-Object {
            $release = $_
            @($release.assets | Where-Object {
                [string]::Equals("$($_.name)", $zip.Name, [StringComparison]::OrdinalIgnoreCase)
            } | ForEach-Object {
                [pscustomobject]@{
                    Release = $release
                    Asset = $_
                }
            })
        })
        if ($assetMatches.Count -ne 1) {
            throw "Package '$($zip.Name)' must resolve to exactly one discovered release asset; found $($assetMatches.Count)."
        }
        $match = $assetMatches[0]
        $package = Get-FastSolutionPackageMetadata `
            -ZipPath $zip.FullName `
            -ModuleId $match.Release.moduleSlug `
            -ReleaseTag $match.Release.tag `
            -ReleaseUrl $match.Release.releaseUrl `
            -AssetUrl $match.Asset.downloadUrl
        if (-not [string]::IsNullOrWhiteSpace("$($match.Asset.digest)") -and
            "$($match.Asset.digest)" -ne "sha256:$($package.sha256)") {
            throw "Package '$($zip.Name)' SHA-256 does not match its GitHub release digest."
        }
        $packages.Add($package) | Out-Null
        $packageManifest.Add([pscustomobject]@{
            canonicalUrl = "$($match.Asset.downloadUrl)"
            sourceKind = 'managed-solution-package'
            contentHash = "$($package.sha256)"
            releaseTag = "$($match.Release.tag)"
            retrievedAtUtc = [DateTime]::UtcNow.ToString('o')
        }) | Out-Null
    }
}

$packageModules = @($packages | ForEach-Object moduleId | Sort-Object -Unique)
foreach ($item in @($discovery.Items | Where-Object itemType -eq 'module')) {
    if ($packageModules -contains "$($item.itemId)") {
        $item.availability.packageVerified = $true
    }
}

$sourceManifest = @($discovery.SourceManifest) + @($packageManifest.ToArray())
$coverage = [ordered]@{}
if ($discovery.Coverage -is [System.Collections.IDictionary]) {
    foreach ($key in $discovery.Coverage.Keys) {
        $coverage["$key"] = $discovery.Coverage[$key]
    }
} else {
    foreach ($property in $discovery.Coverage.PSObject.Properties) {
        $coverage[$property.Name] = $property.Value
    }
}
$coverage['packageVerifiedModules'] = $packageModules.Count
$coverage['indexedPackages'] = $packages.Count

$previous = Get-AcceleratorPromotedSnapshot -ProviderId 'microsoft-fast' -SnapshotRoot $SnapshotRoot -AllowMissing
$snapshot = New-AcceleratorCatalogSnapshot `
    -ProviderId 'microsoft-fast' `
    -SourceManifest $sourceManifest `
    -Items $discovery.Items `
    -Releases $discovery.Releases `
    -Packages $packages.ToArray() `
    -Coverage $coverage `
    -SourceState 'available' `
    -PreviousPromotedSnapshotId $(if ($null -eq $previous) { '' } else { "$($previous.snapshotId)" })
$writeResult = Write-AcceleratorCatalogSnapshot -Snapshot $snapshot -SnapshotRoot $SnapshotRoot

$diff = if ($null -eq $previous) {
    [pscustomobject]@{
        PreviousSnapshotId = $null
        CurrentSnapshotId = $snapshot.snapshotId
        Added = @($snapshot.items.itemId)
        Changed = @()
        Removed = @()
        IsIdentical = $false
    }
} else {
    Compare-AcceleratorCatalogSnapshot -Previous $previous -Current $snapshot
}

$promotionPath = $null
if ($Promote) {
    if ($snapshot.sourceState -ne 'available') {
        throw 'Only a complete available-source snapshot can be promoted.'
    }
    $promotionPath = Set-AcceleratorPromotedSnapshot `
        -ProviderId 'microsoft-fast' `
        -SnapshotId $snapshot.snapshotId `
        -SnapshotRoot $SnapshotRoot
}

[pscustomobject]@{
    Snapshot = $snapshot
    WriteResult = $writeResult
    Difference = $diff
    PromotionPath = $promotionPath
}
