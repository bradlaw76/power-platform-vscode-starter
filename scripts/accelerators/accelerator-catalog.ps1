<#
=============================================================================
COMPONENT:    Provider-Neutral Accelerator Catalog
FILE:         scripts/accelerators/accelerator-catalog.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | JSON

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Provides disabled-by-default provider registration, deterministic hashing,
immutable catalog snapshots, promotion pointers, and catalog change detection.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            accelerator catalog infrastructure
- Inputs:          provider registry and normalized provider data
- Outputs:         immutable snapshot folders and promotion pointers
- Dependencies:    PowerShell 7
- Side Effects:    writes only to an explicitly supplied snapshot root

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Disabled providers are not returned by the enabled-provider query.
✔ Identical content produces the same snapshot ID and cannot be overwritten.
✔ Added, changed, and removed items are reported deterministically.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Do not import or deploy accelerator packages.
- Do not register catalog work as a wizard build stage in FAST-002.
- Keep promoted snapshots immutable; promotion changes only a pointer.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-AcceleratorCanonicalValue {
    param([AllowNull()] [object]$InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [string] -or
        $InputObject -is [char] -or
        $InputObject -is [bool] -or
        $InputObject -is [byte] -or
        $InputObject -is [int16] -or
        $InputObject -is [int32] -or
        $InputObject -is [int64] -or
        $InputObject -is [decimal] -or
        $InputObject -is [double] -or
        $InputObject -is [single]) {
        return $InputObject
    }

    if ($InputObject -is [datetime]) {
        return $InputObject.ToUniversalTime().ToString('o')
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in @($InputObject.Keys | Sort-Object { "$_".ToLowerInvariant() })) {
            $ordered["$key"] = ConvertTo-AcceleratorCanonicalValue -InputObject $InputObject[$key]
        }
        return $ordered
    }

    if ($InputObject -is [System.Collections.IEnumerable]) {
        return @($InputObject | ForEach-Object {
            ConvertTo-AcceleratorCanonicalValue -InputObject $_
        })
    }

    $properties = @($InputObject.PSObject.Properties | Where-Object {
        $_.MemberType -in @('NoteProperty', 'Property', 'AliasProperty', 'ScriptProperty')
    } | Sort-Object { $_.Name.ToLowerInvariant() })
    if ($properties.Count -gt 0) {
        $ordered = [ordered]@{}
        foreach ($property in $properties) {
            $ordered[$property.Name] = ConvertTo-AcceleratorCanonicalValue -InputObject $property.Value
        }
        return $ordered
    }

    return "$InputObject"
}

function ConvertTo-AcceleratorCanonicalJson {
    param([AllowNull()] [object]$InputObject)

    $canonical = ConvertTo-AcceleratorCanonicalValue -InputObject $InputObject
    return ($canonical | ConvertTo-Json -Depth 100 -Compress)
}

function Get-AcceleratorStringSha256 {
    param([Parameter(Mandatory)] [string]$Value)

    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-AcceleratorFileSha256 {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File not found for SHA-256 calculation: $Path"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-AcceleratorProviderRegistry {
    param(
        [Parameter(Mandatory)] [string]$RegistryPath,
        [Parameter(Mandatory)] [string]$RepoRoot
    )

    if (-not (Test-Path -LiteralPath $RegistryPath -PathType Leaf)) {
        throw "Accelerator provider registry not found: $RegistryPath"
    }

    $registry = Get-Content -LiteralPath $RegistryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace("$($registry.version)")) {
        throw 'Accelerator provider registry version is required.'
    }

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $resolvedProviders = @($registry.providers | ForEach-Object {
        $id = "$($_.id)".Trim().ToLowerInvariant()
        if (-not $seen.Add($id)) {
            throw "Duplicate accelerator provider id: $id"
        }
        $adapterPath = [IO.Path]::GetFullPath((Join-Path $RepoRoot "$($_.adapter)"))
        $repoPath = [IO.Path]::GetFullPath($RepoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $adapterPath.StartsWith($repoPath, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Provider adapter resolves outside the repository: $adapterPath"
        }
        [pscustomobject]@{
            Id = $id
            DisplayName = "$($_.displayName)"
            Enabled = [bool]$_.enabled
            AdapterPath = $adapterPath
            SourceHosts = @($_.sourceHosts | ForEach-Object { "$_".Trim().ToLowerInvariant() })
        }
    })

    return [pscustomobject]@{
        Version = "$($registry.version)"
        Providers = $resolvedProviders
    }
}

function Get-EnabledAcceleratorProviders {
    param(
        [Parameter(Mandatory)] [string]$RegistryPath,
        [Parameter(Mandatory)] [string]$RepoRoot
    )

    $registry = Get-AcceleratorProviderRegistry -RegistryPath $RegistryPath -RepoRoot $RepoRoot
    return @($registry.Providers | Where-Object Enabled)
}

function New-AcceleratorCatalogSnapshot {
    param(
        [Parameter(Mandatory)] [string]$ProviderId,
        [object[]]$SourceManifest = @(),
        [object[]]$Items = @(),
        [object[]]$Releases = @(),
        [object[]]$Packages = @(),
        [hashtable]$Coverage = @{},
        [object[]]$ValidationResults = @(),
        [ValidateSet('available', 'partial', 'unavailable', 'retired')]
        [string]$SourceState = 'available',
        [string]$PreviousPromotedSnapshotId = ''
    )

    $provider = $ProviderId.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($provider)) {
        throw 'ProviderId is required.'
    }

    $normalized = [ordered]@{
        schemaVersion = '1.0'
        providerId = $provider
        sourceState = $SourceState
        sourceManifest = @($SourceManifest | Sort-Object { "$($_.canonicalUrl)|$($_.contentHash)" } | ForEach-Object {
            ConvertTo-AcceleratorCanonicalValue -InputObject $_
        })
        items = @($Items | Sort-Object { "$($_.itemId)" } | ForEach-Object {
            ConvertTo-AcceleratorCanonicalValue -InputObject $_
        })
        releases = @($Releases | Sort-Object { "$($_.releaseId)" } | ForEach-Object {
            ConvertTo-AcceleratorCanonicalValue -InputObject $_
        })
        packages = @($Packages | Sort-Object { "$($_.packageId)" } | ForEach-Object {
            ConvertTo-AcceleratorCanonicalValue -InputObject $_
        })
        coverage = ConvertTo-AcceleratorCanonicalValue -InputObject $Coverage
        validationResults = @($ValidationResults | ForEach-Object {
            ConvertTo-AcceleratorCanonicalValue -InputObject $_
        })
    }
    $hashSourceManifest = @($normalized.sourceManifest | ForEach-Object {
        $stableRecord = [ordered]@{}
        foreach ($key in @($_.Keys | Sort-Object { "$_".ToLowerInvariant() })) {
            if ("$key" -cne 'retrievedAtUtc') {
                $stableRecord["$key"] = $_[$key]
            }
        }
        $stableRecord
    })
    $hashInput = [ordered]@{
        schemaVersion = $normalized.schemaVersion
        providerId = $normalized.providerId
        sourceState = $normalized.sourceState
        sourceManifest = $hashSourceManifest
        items = $normalized.items
        releases = $normalized.releases
        packages = $normalized.packages
        coverage = $normalized.coverage
        validationResults = $normalized.validationResults
    }
    $contentHash = Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $hashInput)

    return [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        providerId = $provider
        snapshotId = "sha256:$contentHash"
        contentHash = $contentHash
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        status = 'candidate'
        sourceState = $SourceState
        sourceManifest = $normalized.sourceManifest
        items = $normalized.items
        releases = $normalized.releases
        packages = $normalized.packages
        coverage = $normalized.coverage
        validationResults = $normalized.validationResults
        previousPromotedSnapshotId = if ([string]::IsNullOrWhiteSpace($PreviousPromotedSnapshotId)) { $null } else { $PreviousPromotedSnapshotId }
    }
}

function Write-AcceleratorCatalogSnapshot {
    param(
        [Parameter(Mandatory)] [object]$Snapshot,
        [Parameter(Mandatory)] [string]$SnapshotRoot
    )

    $providerFolder = Join-Path $SnapshotRoot "$($Snapshot.providerId)"
    $snapshotFolder = Join-Path $providerFolder "$($Snapshot.contentHash)"
    $catalogPath = Join-Path $snapshotFolder 'catalog.json'
    $manifestPath = Join-Path $snapshotFolder 'snapshot-manifest.json'

    if (Test-Path -LiteralPath $snapshotFolder) {
        if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
            throw "Existing snapshot folder is incomplete and cannot be overwritten: $snapshotFolder"
        }
        $existing = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ("$($existing.contentHash)" -cne "$($Snapshot.contentHash)") {
            throw "Existing snapshot content hash mismatch: $snapshotFolder"
        }
        return [pscustomobject]@{
            SnapshotFolder = $snapshotFolder
            CatalogPath = $catalogPath
            ManifestPath = $manifestPath
            Action = 'already-exists'
        }
    }

    New-Item -ItemType Directory -Path $snapshotFolder -Force | Out-Null
    $Snapshot | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $catalogPath -Encoding utf8NoBOM
    [ordered]@{
        snapshotId = $Snapshot.snapshotId
        contentHash = $Snapshot.contentHash
        providerId = $Snapshot.providerId
        createdAtUtc = $Snapshot.createdAtUtc
        sourceState = $Snapshot.sourceState
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM

    return [pscustomobject]@{
        SnapshotFolder = $snapshotFolder
        CatalogPath = $catalogPath
        ManifestPath = $manifestPath
        Action = 'created'
    }
}

function Set-AcceleratorPromotedSnapshot {
    param(
        [Parameter(Mandatory)] [string]$ProviderId,
        [Parameter(Mandatory)] [string]$SnapshotId,
        [Parameter(Mandatory)] [string]$SnapshotRoot
    )

    if ($SnapshotId -notmatch '^sha256:(?<hash>[a-f0-9]{64})$') {
        throw "Invalid snapshot id: $SnapshotId"
    }
    $hash = $Matches.hash
    $providerFolder = Join-Path $SnapshotRoot $ProviderId
    $catalogPath = Join-Path (Join-Path $providerFolder $hash) 'catalog.json'
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        throw "Snapshot cannot be promoted because it does not exist: $SnapshotId"
    }

    $pointerPath = Join-Path $providerFolder 'promoted.json'
    $previous = $null
    if (Test-Path -LiteralPath $pointerPath -PathType Leaf) {
        $previous = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    [ordered]@{
        providerId = $ProviderId
        snapshotId = $SnapshotId
        promotedAtUtc = [DateTime]::UtcNow.ToString('o')
        previousSnapshotId = if ($null -eq $previous) { $null } else { "$($previous.snapshotId)" }
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $pointerPath -Encoding utf8NoBOM
    return $pointerPath
}

function Get-AcceleratorPromotedSnapshot {
    param(
        [Parameter(Mandatory)] [string]$ProviderId,
        [Parameter(Mandatory)] [string]$SnapshotRoot,
        [switch]$AllowMissing
    )

    $providerFolder = Join-Path $SnapshotRoot $ProviderId
    $pointerPath = Join-Path $providerFolder 'promoted.json'
    if (-not (Test-Path -LiteralPath $pointerPath -PathType Leaf)) {
        if ($AllowMissing) {
            return $null
        }
        throw "No promoted snapshot exists for provider '$ProviderId'."
    }
    $pointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ("$($pointer.snapshotId)" -notmatch '^sha256:(?<hash>[a-f0-9]{64})$') {
        throw "Promoted snapshot pointer is invalid for provider '$ProviderId'."
    }
    $catalogPath = Join-Path (Join-Path $providerFolder $Matches.hash) 'catalog.json'
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        throw "Promoted snapshot content is missing for provider '$ProviderId'."
    }
    return Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Compare-AcceleratorCatalogSnapshot {
    param(
        [Parameter(Mandatory)] [object]$Previous,
        [Parameter(Mandatory)] [object]$Current
    )

    $previousById = @{}
    foreach ($item in @($Previous.items)) {
        $previousById["$($item.itemId)"] = $item
    }
    $currentById = @{}
    foreach ($item in @($Current.items)) {
        $currentById["$($item.itemId)"] = $item
    }

    $added = @($currentById.Keys | Where-Object { -not $previousById.ContainsKey($_) } | Sort-Object)
    $removed = @($previousById.Keys | Where-Object { -not $currentById.ContainsKey($_) } | Sort-Object)
    $changed = @($currentById.Keys | Where-Object {
        if (-not $previousById.ContainsKey($_)) {
            return $false
        }
        $before = ConvertTo-AcceleratorCanonicalJson -InputObject $previousById[$_]
        $after = ConvertTo-AcceleratorCanonicalJson -InputObject $currentById[$_]
        return $before -cne $after
    } | Sort-Object)

    return [pscustomobject]@{
        PreviousSnapshotId = "$($Previous.snapshotId)"
        CurrentSnapshotId = "$($Current.snapshotId)"
        Added = $added
        Changed = $changed
        Removed = $removed
        IsIdentical = ($added.Count -eq 0 -and $changed.Count -eq 0 -and $removed.Count -eq 0)
    }
}
