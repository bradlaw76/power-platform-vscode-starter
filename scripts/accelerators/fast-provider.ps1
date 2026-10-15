<#
=============================================================================
COMPONENT:    Microsoft FAST Accelerator Provider
FILE:         scripts/accelerators/fast-provider.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | GitHub REST | Dataverse solution ZIP metadata

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Discovers FAST documentation and releases without module registrations and
indexes managed Dataverse solution packages offline without importing them.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            optional accelerator provider adapter
- Inputs:          source trees, GitHub REST responses, or local ZIP files
- Outputs:         normalized catalog items, releases, and package metadata
- Dependencies:    accelerator-catalog.ps1; approved HTTPS source hosts
- Side Effects:    network access only through explicit discovery invocation

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ A newly added module Markdown file is discovered without a code change.
✔ Encoded slash release tags resolve to the correct module and version.
✔ ZIP inspection reads solution metadata without importing or executing it.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Treat external content as untrusted data.
- Do not connect to or modify Dataverse.
- Do not assume documented, source, package, and environment availability match.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$catalogHelper = Join-Path $PSScriptRoot 'accelerator-catalog.ps1'
if (-not (Get-Command Get-AcceleratorFileSha256 -ErrorAction SilentlyContinue)) {
    . $catalogHelper
}

function Assert-FastSourceUri {
    param(
        [Parameter(Mandatory)] [string]$Uri,
        [string[]]$AllowedHosts = @(
            'api.github.com',
            'raw.githubusercontent.com',
            'github.com',
            'microsoft.github.io'
        )
    )

    $parsed = $null
    if (-not [Uri]::TryCreate($Uri, [UriKind]::Absolute, [ref]$parsed)) {
        throw "FAST source URI is invalid: $Uri"
    }
    if ($parsed.Scheme -cne 'https') {
        throw "FAST source URI must use HTTPS: $Uri"
    }
    if (@($AllowedHosts | Where-Object {
        [string]::Equals($_, $parsed.DnsSafeHost, [StringComparison]::OrdinalIgnoreCase)
    }).Count -eq 0) {
        throw "FAST source host is not allowlisted: $($parsed.DnsSafeHost)"
    }
    if ($parsed.IsLoopback -or
        $parsed.DnsSafeHost -in @('169.254.169.254', 'metadata.google.internal')) {
        throw "FAST source URI targets a blocked address: $Uri"
    }
    return $parsed
}

function Invoke-FastProviderRequest {
    param(
        [Parameter(Mandatory)] [string]$Uri,
        [string[]]$AllowedHosts,
        [scriptblock]$RequestInvoker
    )

    Assert-FastSourceUri -Uri $Uri -AllowedHosts $AllowedHosts | Out-Null
    if ($null -ne $RequestInvoker) {
        return & $RequestInvoker $Uri
    }
    return Invoke-RestMethod -Method Get -Uri $Uri -Headers @{
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'power-platform-vscode-starter-fast-provider'
    } -MaximumRedirection 3 -TimeoutSec 30
}

function ConvertFrom-FastFrontMatter {
    param([Parameter(Mandatory)] [string]$Markdown)

    $result = [ordered]@{}
    $normalized = $Markdown -replace "`r`n", "`n"
    if (-not $normalized.StartsWith("---`n", [StringComparison]::Ordinal)) {
        return [pscustomobject]$result
    }
    $end = $normalized.IndexOf("`n---`n", 4, [StringComparison]::Ordinal)
    if ($end -lt 0) {
        return [pscustomobject]$result
    }

    $frontMatter = $normalized.Substring(4, $end - 4)
    foreach ($line in $frontMatter -split "`n") {
        if ($line -notmatch '^(?<key>[A-Za-z0-9_-]+):\s*(?<value>.*)$') {
            continue
        }
        $key = $Matches.key
        $value = $Matches.value.Trim()
        if ($value -match '^\[(?<items>.*)\]$') {
            $result[$key] = @($Matches.items.Split(',') | ForEach-Object {
                $_.Trim().Trim('"').Trim("'")
            } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        } elseif ($value -in @('true', 'false')) {
            $result[$key] = [bool]::Parse($value)
        } else {
            $result[$key] = $value.Trim('"').Trim("'")
        }
    }
    return [pscustomobject]$result
}

function Get-FastOfficialReleaseLinks {
    param([Parameter(Mandatory)] [string]$Markdown)

    $matches = [regex]::Matches(
        $Markdown,
        'https://github\.com/microsoft/industry-apps/releases/(?:tag|download)/[^\s\)"''<>]+',
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    return @($matches | ForEach-Object {
        $_.Value.TrimEnd('.', ',', ';')
    } | Sort-Object -Unique)
}

function ConvertFrom-FastMarkdownItem {
    param(
        [Parameter(Mandatory)] [string]$Collection,
        [Parameter(Mandatory)] [string]$RelativePath,
        [Parameter(Mandatory)] [string]$Content,
        [Parameter(Mandatory)] [string]$SourceUrl
    )

    $slug = [IO.Path]::GetFileNameWithoutExtension($RelativePath).ToLowerInvariant()
    $itemType = switch ($Collection) {
        '_modules' { 'module' }
        '_use_cases' { 'use-case' }
        '_personas' { 'persona' }
        '_agents' { 'agent' }
        '_portals' { 'portal' }
        '_data_models' { 'data-model' }
        default { 'document' }
    }
    $frontMatter = ConvertFrom-FastFrontMatter -Markdown $Content
    $titleProperty = $frontMatter.PSObject.Properties['title']
    $title = if ($null -ne $titleProperty -and -not [string]::IsNullOrWhiteSpace("$($titleProperty.Value)")) {
        "$($titleProperty.Value)"
    } else {
        (Get-Culture).TextInfo.ToTitleCase($slug.Replace('-', ' '))
    }
    $releaseLinks = Get-FastOfficialReleaseLinks -Markdown $Content
    $contentHash = Get-AcceleratorStringSha256 -Value $Content

    return [pscustomobject][ordered]@{
        itemId = "microsoft-fast:$itemType`:$slug"
        providerId = 'microsoft-fast'
        itemType = $itemType
        slug = $slug
        name = $title
        sourcePath = $RelativePath.Replace('\', '/')
        sourceUrl = $SourceUrl
        contentHash = $contentHash
        documentedReleaseLinks = $releaseLinks
        frontMatter = $frontMatter
        availability = [ordered]@{
            documented = $true
            sourceAvailable = $true
            packageVerified = $false
            environmentVerified = $false
        }
    }
}

function Get-FastCatalogItemsFromSourceTree {
    param(
        [Parameter(Mandatory)] [string]$SourceRoot,
        [string]$SourceBaseUrl = 'https://raw.githubusercontent.com/microsoft/industry-solutions/main'
    )

    $collections = @('_modules', '_use_cases', '_personas', '_agents', '_portals', '_data_models')
    $items = [Collections.Generic.List[object]]::new()
    $sourceManifest = [Collections.Generic.List[object]]::new()

    foreach ($collection in $collections) {
        $folder = Join-Path $SourceRoot $collection
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            continue
        }
        foreach ($file in @(Get-ChildItem -LiteralPath $folder -Filter '*.md' -File -Recurse |
            Where-Object Name -ne '_template.md' | Sort-Object FullName)) {
            $relative = [IO.Path]::GetRelativePath($SourceRoot, $file.FullName).Replace('\', '/')
            $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
            $url = "$($SourceBaseUrl.TrimEnd('/'))/$relative"
            $item = ConvertFrom-FastMarkdownItem -Collection $collection -RelativePath $relative -Content $content -SourceUrl $url
            $items.Add($item) | Out-Null
            $sourceManifest.Add([pscustomobject]@{
                canonicalUrl = $url
                sourceKind = $item.itemType
                contentHash = $item.contentHash
                retrievedAtUtc = [DateTime]::UtcNow.ToString('o')
            }) | Out-Null
        }
    }

    return [pscustomobject]@{
        Items = @($items.ToArray())
        SourceManifest = @($sourceManifest.ToArray())
    }
}

function ConvertTo-FastReleaseInventory {
    param([Parameter(Mandatory)] [object[]]$ReleaseDocuments)

    $releases = [Collections.Generic.List[object]]::new()
    foreach ($release in @($ReleaseDocuments)) {
        $tag = "$($release.tag_name)"
        if ($tag -notmatch '^(?<module>[^/]+)/v(?<version>.+)$') {
            continue
        }
        $module = $Matches.module.ToLowerInvariant()
        $version = $Matches.version
        $assets = @($release.assets | Where-Object { "$($_.name)" -match '(?i)\.zip$' } | ForEach-Object {
            $name = "$($_.name)"
            [pscustomobject][ordered]@{
                assetId = "github:$($_.id)"
                name = $name
                kind = if ($name -match '(?i)-managed-') { 'managed' } else { 'unmanaged' }
                sizeBytes = [int64]$_.size
                digest = "$($_.digest)"
                downloadUrl = "$($_.browser_download_url)"
                downloadCount = [int]$_.download_count
            }
        })
        if ($assets.Count -eq 0) {
            continue
        }
        $releases.Add([pscustomobject][ordered]@{
            releaseId = "microsoft-fast:$tag"
            providerId = 'microsoft-fast'
            moduleId = "microsoft-fast:module:$module"
            moduleSlug = $module
            tag = $tag
            version = $version
            releaseUrl = "$($release.html_url)"
            publishedAtUtc = "$($release.published_at)"
            prerelease = [bool]$release.prerelease
            assets = $assets
        }) | Out-Null
    }
    return @($releases.ToArray() | Sort-Object releaseId)
}

function Invoke-FastSourceDiscovery {
    param(
        [scriptblock]$RequestInvoker,
        [string[]]$AllowedHosts = @('api.github.com', 'raw.githubusercontent.com'),
        [int]$MaxReleasePages = 20
    )

    $treeUri = 'https://api.github.com/repos/microsoft/industry-solutions/git/trees/main?recursive=1'
    $tree = Invoke-FastProviderRequest -Uri $treeUri -AllowedHosts $AllowedHosts -RequestInvoker $RequestInvoker
    $collectionPattern = '^_(modules|use_cases|personas|agents|portals|data_models)/.+\.md$'
    $documents = @($tree.tree | Where-Object {
        "$($_.type)" -eq 'blob' -and "$($_.path)" -match $collectionPattern -and "$($_.path)" -notmatch '/_template\.md$'
    } | Sort-Object path)

    $items = [Collections.Generic.List[object]]::new()
    $sourceManifest = [Collections.Generic.List[object]]::new()
    foreach ($document in $documents) {
        $path = "$($document.path)"
        $collection = $path.Split('/')[0]
        $rawUri = "https://raw.githubusercontent.com/microsoft/industry-solutions/main/$path"
        $content = "$(Invoke-FastProviderRequest -Uri $rawUri -AllowedHosts $AllowedHosts -RequestInvoker $RequestInvoker)"
        $item = ConvertFrom-FastMarkdownItem -Collection $collection -RelativePath $path -Content $content -SourceUrl $rawUri
        $items.Add($item) | Out-Null
        $sourceManifest.Add([pscustomobject]@{
            canonicalUrl = $rawUri
            sourceKind = $item.itemType
            contentHash = $item.contentHash
            sourceObjectSha = "$($document.sha)"
            retrievedAtUtc = [DateTime]::UtcNow.ToString('o')
        }) | Out-Null
    }

    $releaseDocuments = [Collections.Generic.List[object]]::new()
    $releasePageCount = 0
    for ($page = 1; $page -le $MaxReleasePages; $page++) {
        $releasePageCount = $page
        $uri = "https://api.github.com/repos/microsoft/industry-apps/releases?per_page=100&page=$page"
        $pageResult = @(Invoke-FastProviderRequest -Uri $uri -AllowedHosts $AllowedHosts -RequestInvoker $RequestInvoker)
        if ($pageResult.Count -eq 0) {
            break
        }
        foreach ($release in $pageResult) {
            $releaseDocuments.Add($release) | Out-Null
        }
        if ($pageResult.Count -lt 100) {
            break
        }
    }

    return [pscustomobject]@{
        Items = @($items.ToArray())
        Releases = @(ConvertTo-FastReleaseInventory -ReleaseDocuments $releaseDocuments.ToArray())
        SourceManifest = @($sourceManifest.ToArray())
        Coverage = [ordered]@{
            documents = $items.Count
            modules = @($items | Where-Object itemType -eq 'module').Count
            useCases = @($items | Where-Object itemType -eq 'use-case').Count
            personas = @($items | Where-Object itemType -eq 'persona').Count
            dataModels = @($items | Where-Object itemType -eq 'data-model').Count
            releases = $releaseDocuments.Count
            releasePagesRead = $releasePageCount
        }
    }
}

function Read-FastZipEntryText {
    param(
        [Parameter(Mandatory)] [IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory)] [string]$EntryName
    )

    $entry = @($Archive.Entries | Where-Object {
        [string]::Equals($_.FullName, $EntryName, [StringComparison]::OrdinalIgnoreCase)
    }) | Select-Object -First 1
    if ($null -eq $entry) {
        throw "Required solution ZIP entry is missing: $EntryName"
    }
    $stream = $entry.Open()
    $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true)
    try {
        return $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

function Get-FastOptionalNodeValue {
    param(
        [AllowNull()] [object]$Node,
        [Parameter(Mandatory)] [string]$Name
    )

    if ($null -eq $Node) {
        return ''
    }
    $property = $Node.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return ''
    }
    return "$($property.Value)"
}

function Get-FastSolutionPackageMetadata {
    param(
        [Parameter(Mandatory)] [string]$ZipPath,
        [Parameter(Mandatory)] [string]$ModuleId,
        [string]$ReleaseTag = '',
        [string]$ReleaseUrl = '',
        [string]$AssetUrl = ''
    )

    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
        throw "FAST solution package not found: $ZipPath"
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        [xml]$solutionXml = Read-FastZipEntryText -Archive $archive -EntryName 'solution.xml'
        [xml]$customizationsXml = Read-FastZipEntryText -Archive $archive -EntryName 'customizations.xml'
        $entryCount = $archive.Entries.Count
    } finally {
        $archive.Dispose()
    }

    $manifest = $solutionXml.ImportExportXml.SolutionManifest
    $publisher = $manifest.Publisher
    $rootComponents = @($manifest.RootComponents.RootComponent | ForEach-Object {
        [pscustomobject][ordered]@{
            type = "$($_.type)"
            schemaName = "$($_.schemaName)"
            behavior = "$($_.behavior)"
        }
    })
    $tableRootNames = @($rootComponents | Where-Object type -eq '1' | ForEach-Object {
        "$($_.schemaName)".ToLowerInvariant()
    })

    $forms = [Collections.Generic.List[object]]::new()
    $views = [Collections.Generic.List[object]]::new()
    $tables = @($customizationsXml.ImportExportXml.Entities.Entity | ForEach-Object {
        $entityDefinition = $_
        $entityInfoProperty = $entityDefinition.PSObject.Properties['EntityInfo']
        $entityNode = if ($null -eq $entityInfoProperty -or $null -eq $entityInfoProperty.Value) {
            $null
        } else {
            $entityInfoProperty.Value.entity
        }
        $schemaName = if ($null -ne $entityNode) { "$($entityNode.Name)" } else { "$($entityDefinition.Name.'#text')" }
        $logicalName = $schemaName.ToLowerInvariant()
        $attributes = @(
            if ($null -ne $entityNode -and $null -ne $entityNode.attributes) {
                $entityNode.attributes.attribute | ForEach-Object {
                [pscustomobject][ordered]@{
                    logicalName = Get-FastOptionalNodeValue -Node $_ -Name 'LogicalName'
                    physicalName = Get-FastOptionalNodeValue -Node $_ -Name 'PhysicalName'
                    type = Get-FastOptionalNodeValue -Node $_ -Name 'Type'
                    requiredLevel = Get-FastOptionalNodeValue -Node $_ -Name 'RequiredLevel'
                    isCustomField = ((Get-FastOptionalNodeValue -Node $_ -Name 'IsCustomField') -eq '1')
                    introducedVersion = Get-FastOptionalNodeValue -Node $_ -Name 'IntroducedVersion'
                }
                }
            }
        )

        $formXmlProperty = $entityDefinition.PSObject.Properties['FormXml']
        $formsProperty = if ($null -eq $formXmlProperty -or $null -eq $formXmlProperty.Value) {
            $null
        } else {
            $formXmlProperty.Value.PSObject.Properties['forms']
        }
        $formNodes = if ($null -eq $formsProperty) {
            @()
        } else {
            @($formsProperty.Value)
        }
        foreach ($formsNode in $formNodes) {
            foreach ($form in @($formsNode.systemform)) {
                if ($null -eq $form) {
                    continue
                }
                $localizedNamesProperty = $form.PSObject.Properties['LocalizedNames']
                $localizedName = if ($null -eq $localizedNamesProperty) {
                    @()
                } else {
                    @($localizedNamesProperty.Value.LocalizedName | Select-Object -First 1)
                }
                $forms.Add([pscustomobject][ordered]@{
                    tableLogicalName = $logicalName
                    formId = Get-FastOptionalNodeValue -Node $form -Name 'formid'
                    formType = "$($formsNode.type)"
                    name = if ($localizedName.Count -eq 0) { '' } else { Get-FastOptionalNodeValue -Node $localizedName[0] -Name 'description' }
                    introducedVersion = Get-FastOptionalNodeValue -Node $form -Name 'IntroducedVersion'
                }) | Out-Null
            }
        }

        $savedQueriesProperty = $entityDefinition.PSObject.Properties['SavedQueries']
        $savedQueriesContainer = if ($null -eq $savedQueriesProperty -or $null -eq $savedQueriesProperty.Value) {
            $null
        } else {
            $savedQueriesProperty.Value.PSObject.Properties['savedqueries']
        }
        $savedQueryProperty = if ($null -eq $savedQueriesContainer -or $null -eq $savedQueriesContainer.Value) {
            $null
        } else {
            $savedQueriesContainer.Value.PSObject.Properties['savedquery']
        }
        $savedQueries = if ($null -eq $savedQueryProperty) {
            @()
        } else {
            @($savedQueryProperty.Value)
        }
        foreach ($view in $savedQueries) {
            if ($null -eq $view) {
                continue
            }
            $localizedNamesProperty = $view.PSObject.Properties['LocalizedNames']
            $localizedName = if ($null -eq $localizedNamesProperty) {
                @()
            } else {
                @($localizedNamesProperty.Value.LocalizedName | Select-Object -First 1)
            }
            $views.Add([pscustomobject][ordered]@{
                tableLogicalName = $logicalName
                savedQueryId = Get-FastOptionalNodeValue -Node $view -Name 'savedqueryid'
                queryType = Get-FastOptionalNodeValue -Node $view -Name 'querytype'
                name = if ($localizedName.Count -eq 0) { '' } else { Get-FastOptionalNodeValue -Node $localizedName[0] -Name 'description' }
                isDefault = ((Get-FastOptionalNodeValue -Node $view -Name 'isdefault') -eq '1')
                introducedVersion = Get-FastOptionalNodeValue -Node $view -Name 'IntroducedVersion'
            }) | Out-Null
        }

        [pscustomobject][ordered]@{
            schemaName = $schemaName
            logicalName = $logicalName
            displayName = Get-FastOptionalNodeValue -Node $entityDefinition.Name -Name 'LocalizedName'
            rootComponentIncluded = ($tableRootNames -contains $logicalName)
            attributes = $attributes
        }
    })

    $relationshipContainer = $customizationsXml.ImportExportXml.PSObject.Properties['EntityRelationships']
    $relationshipProperty = if ($null -eq $relationshipContainer -or $null -eq $relationshipContainer.Value) {
        $null
    } else {
        $relationshipContainer.Value.PSObject.Properties['EntityRelationship']
    }
    $relationshipNodes = if ($null -eq $relationshipProperty) { @() } else { @($relationshipProperty.Value) }
    $relationships = @($relationshipNodes | ForEach-Object {
        [pscustomobject][ordered]@{
            name = Get-FastOptionalNodeValue -Node $_ -Name 'Name'
            type = Get-FastOptionalNodeValue -Node $_ -Name 'EntityRelationshipType'
            referencingEntity = Get-FastOptionalNodeValue -Node $_ -Name 'ReferencingEntityName'
            referencedEntity = Get-FastOptionalNodeValue -Node $_ -Name 'ReferencedEntityName'
            referencingAttribute = Get-FastOptionalNodeValue -Node $_ -Name 'ReferencingAttributeName'
            introducedVersion = Get-FastOptionalNodeValue -Node $_ -Name 'IntroducedVersion'
            hierarchical = ((Get-FastOptionalNodeValue -Node $_ -Name 'IsHierarchical') -eq '1')
            cascades = [pscustomobject][ordered]@{
                assign = Get-FastOptionalNodeValue -Node $_ -Name 'CascadeAssign'
                delete = Get-FastOptionalNodeValue -Node $_ -Name 'CascadeDelete'
                archive = Get-FastOptionalNodeValue -Node $_ -Name 'CascadeArchive'
                reparent = Get-FastOptionalNodeValue -Node $_ -Name 'CascadeReparent'
                share = Get-FastOptionalNodeValue -Node $_ -Name 'CascadeShare'
                unshare = Get-FastOptionalNodeValue -Node $_ -Name 'CascadeUnshare'
                rollupView = Get-FastOptionalNodeValue -Node $_ -Name 'CascadeRollupView'
            }
        }
    })

    $optionSetsProperty = $customizationsXml.ImportExportXml.PSObject.Properties['optionsets']
    $optionSetProperty = if ($null -eq $optionSetsProperty -or $null -eq $optionSetsProperty.Value) {
        $null
    } else {
        $optionSetsProperty.Value.PSObject.Properties['optionset']
    }
    $optionSetNodes = if ($null -eq $optionSetProperty) {
        @()
    } else {
        @($optionSetProperty.Value)
    }
    $optionSets = @($optionSetNodes | ForEach-Object {
        [pscustomobject][ordered]@{
            name = Get-FastOptionalNodeValue -Node $_ -Name 'Name'
            displayName = Get-FastOptionalNodeValue -Node $_ -Name 'localizedName'
            type = Get-FastOptionalNodeValue -Node $_ -Name 'OptionSetType'
            global = ((Get-FastOptionalNodeValue -Node $_ -Name 'IsGlobal') -eq '1')
            introducedVersion = Get-FastOptionalNodeValue -Node $_ -Name 'IntroducedVersion'
            options = [object[]]@($(if ($null -ne $_.PSObject.Properties['options']) { $_.options.option }) | ForEach-Object {
                $label = @($(if ($null -ne $_.PSObject.Properties['labels']) { $_.labels.label }) | Select-Object -First 1)
                [pscustomobject]@{
                    value = Get-FastOptionalNodeValue -Node $_ -Name 'value'
                    label = if ($label.Count -eq 0) { '' } else { Get-FastOptionalNodeValue -Node $label[0] -Name 'description' }
                }
            })
        }
    })

    $missingDependenciesProperty = $manifest.PSObject.Properties['MissingDependencies']
    $missingDependencyProperty = if ($null -eq $missingDependenciesProperty -or $null -eq $missingDependenciesProperty.Value) {
        $null
    } else {
        $missingDependenciesProperty.Value.PSObject.Properties['MissingDependency']
    }
    $missingDependencyNodes = if ($null -eq $missingDependencyProperty) {
        @()
    } else {
        @($missingDependencyProperty.Value)
    }
    $dependencies = @($missingDependencyNodes | ForEach-Object {
        $required = $_.Required
        $dependent = $_.Dependent
        $packageProperty = $required.PSObject.Properties['package']
        $package = if ($null -eq $packageProperty) { $null } else { $packageProperty.Value }
        [pscustomobject][ordered]@{
            required = [pscustomobject][ordered]@{
                type = Get-FastOptionalNodeValue -Node $required -Name 'type'
                schemaName = Get-FastOptionalNodeValue -Node $required -Name 'schemaName'
                displayName = Get-FastOptionalNodeValue -Node $required -Name 'displayName'
                parentDisplayName = Get-FastOptionalNodeValue -Node $required -Name 'parentDisplayName'
                solution = Get-FastOptionalNodeValue -Node $required -Name 'solution'
                id = Get-FastOptionalNodeValue -Node $required -Name 'id'
                uniqueName = Get-FastOptionalNodeValue -Node $required -Name 'id.uniquename'
                packageAppName = Get-FastOptionalNodeValue -Node $package -Name 'appName'
                packageVersion = Get-FastOptionalNodeValue -Node $package -Name 'version'
                package = Get-FastOptionalNodeValue -Node $package -Name '#text'
            }
            dependent = [pscustomobject][ordered]@{
                type = Get-FastOptionalNodeValue -Node $dependent -Name 'type'
                schemaName = Get-FastOptionalNodeValue -Node $dependent -Name 'schemaName'
                displayName = Get-FastOptionalNodeValue -Node $dependent -Name 'displayName'
                parentDisplayName = Get-FastOptionalNodeValue -Node $dependent -Name 'parentDisplayName'
                id = Get-FastOptionalNodeValue -Node $dependent -Name 'id'
            }
        }
    })

    $apps = @($rootComponents | Where-Object type -in @('62', '80', '300') | ForEach-Object {
        [pscustomobject][ordered]@{
            componentType = $_.type
            schemaName = $_.schemaName
            kind = switch ($_.type) {
                '62' { 'sitemap' }
                '80' { 'model-driven-app' }
                '300' { 'canvas-app' }
            }
        }
    })

    $file = Get-Item -LiteralPath $ZipPath
    $hash = Get-AcceleratorFileSha256 -Path $ZipPath
    $moduleSlug = $ModuleId.ToLowerInvariant()
    return [pscustomobject][ordered]@{
        evidenceType = 'package-verified'
        providerId = 'microsoft-fast'
        moduleId = "microsoft-fast:module:$moduleSlug"
        packageId = "microsoft-fast:package:$moduleSlug`:$($manifest.Version):managed:$hash"
        releaseTag = if ([string]::IsNullOrWhiteSpace($ReleaseTag)) { $null } else { $ReleaseTag }
        releaseUrl = if ([string]::IsNullOrWhiteSpace($ReleaseUrl)) { $null } else { $ReleaseUrl }
        assetUrl = if ([string]::IsNullOrWhiteSpace($AssetUrl)) { $null } else { $AssetUrl }
        fileName = $file.Name
        sizeBytes = $file.Length
        sha256 = $hash
        zipEntryCount = $entryCount
        solution = [pscustomobject][ordered]@{
            uniqueName = "$($manifest.UniqueName)"
            displayName = Get-FastOptionalNodeValue -Node $manifest.LocalizedNames.LocalizedName -Name 'description'
            version = "$($manifest.Version)"
            managed = ("$($manifest.Managed)" -eq '1')
            packageVersion = Get-FastOptionalNodeValue -Node $solutionXml.ImportExportXml -Name 'SolutionPackageVersion'
            sourceOrganizationVersion = Get-FastOptionalNodeValue -Node $solutionXml.ImportExportXml -Name 'OrganizationVersion'
        }
        publisher = [pscustomobject][ordered]@{
            uniqueName = "$($publisher.UniqueName)"
            displayName = Get-FastOptionalNodeValue -Node $publisher.LocalizedNames.LocalizedName -Name 'description'
            description = Get-FastOptionalNodeValue -Node $publisher.Descriptions.Description -Name 'description'
            customizationPrefix = "$($publisher.CustomizationPrefix)"
            optionValuePrefix = [int]$publisher.CustomizationOptionValuePrefix
        }
        rootComponents = $rootComponents
        tables = $tables
        relationships = $relationships
        optionSets = $optionSets
        forms = @($forms.ToArray())
        views = @($views.ToArray())
        apps = $apps
        declaredDependencies = $dependencies
        limitations = @(
            'Package metadata was inspected offline and was not imported.',
            'Environment compatibility and installed dependency resolution were not verified.'
        )
    }
}
