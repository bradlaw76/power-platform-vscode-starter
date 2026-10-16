<#
=============================================================================
COMPONENT:    Provider-Neutral Accelerator Requirements Matching
FILE:         scripts/accelerators/requirements-matching.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | JSON

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Normalizes requirements, evaluates documented accelerator evidence, verifies
physical component reuse from package metadata, computes dependency-aware
deltas, and produces deterministic architecture alternatives.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            standalone planning service between discovery and architecture
- Inputs:          requirements, catalog snapshot, packages, optional preflight
- Outputs:         evidence matrix, deltas, dependencies, architecture options
- Side Effects:    none; artifact writing is an explicit separate function

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Documentation keywords alone never prove physical or process coverage.
- Missing or conflicting evidence produces VERIFY, not invented capability.
- Environment readiness never changes functional matching evidence.
- No Dataverse, network, wizard-stage, or build-stage access.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'accelerator-catalog.ps1')

function Get-AcceleratorMatchingValue {
    param(
        [AllowNull()] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name,
        [AllowNull()] [object]$DefaultValue = $null
    )

    if ($null -eq $InputObject) { return $DefaultValue }
    if ($InputObject -is [Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $DefaultValue
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $DefaultValue }
    return $property.Value
}

function ConvertTo-AcceleratorStringArray {
    param([AllowNull()] [object]$Value)

    if ($null -eq $Value) { return @() }
    return @($Value | ForEach-Object {
        if ($_ -is [string]) {
            @($_ -split '[,;\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            })
        } else {
            "$_".Trim()
        }
    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

function Get-AcceleratorMeaningfulTerms {
    param([AllowNull()] [string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $ignored = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($word in @(
        'a', 'an', 'and', 'app', 'application', 'as', 'at', 'be', 'by',
        'component', 'create', 'data', 'for', 'from', 'in', 'include',
        'is', 'it', 'manage', 'management', 'must', 'name', 'new', 'of',
        'on', 'or', 'record', 'records', 'should', 'solution', 'status',
        'system', 'table', 'that', 'the', 'their', 'to', 'track', 'use',
        'user', 'users', 'with'
    )) {
        $ignored.Add($word) | Out-Null
    }
    return @(
        [regex]::Matches($Text.ToLowerInvariant(), '[a-z0-9]+') |
            ForEach-Object { $_.Value } |
            Where-Object { $_.Length -ge 3 -and -not $ignored.Contains($_) } |
            Sort-Object -Unique
    )
}

function Test-AcceleratorTermEquivalent {
    param(
        [Parameter(Mandatory)] [string]$Left,
        [Parameter(Mandatory)] [string]$Right
    )

    if ([string]::Equals($Left, $Right, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $minimum = [Math]::Min($Left.Length, $Right.Length)
    if ($minimum -lt 6) { return $false }
    $prefixLength = 0
    while ($prefixLength -lt $minimum -and
        [char]::ToLowerInvariant($Left[$prefixLength]) -eq [char]::ToLowerInvariant($Right[$prefixLength])) {
        $prefixLength++
    }
    return $prefixLength -ge 6
}

function Get-AcceleratorMatchedTerms {
    param(
        [string[]]$RequirementTerms,
        [string[]]$EvidenceTerms
    )

    return @($RequirementTerms | Where-Object {
        $requiredTerm = $_
        @($EvidenceTerms | Where-Object {
            Test-AcceleratorTermEquivalent -Left $requiredTerm -Right $_
        }).Count -gt 0
    } | Sort-Object -Unique)
}

function ConvertTo-NormalizedAcceleratorRequirements {
    param(
        [Parameter(Mandatory)] [object]$Requirements,
        [string]$ScenarioSlug = 'accelerator-analysis'
    )

    $entries = [Collections.Generic.List[object]]::new()
    if ($Requirements -is [string]) {
        $lines = @($Requirements -replace "`r", '' -split "`n" | ForEach-Object {
            ($_ -replace '^\s*(?:[-*+]|\d+[.)])\s*', '').Trim()
        } | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith('#')
        })
        if ($lines.Count -eq 0) { $lines = @("$Requirements".Trim()) }
        foreach ($line in $lines) { $entries.Add($line) | Out-Null }
    } else {
        foreach ($entry in @($Requirements)) { $entries.Add($entry) | Out-Null }
    }

    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $normalized = [Collections.Generic.List[object]]::new()
    foreach ($entry in $entries) {
        if ($entry -is [string]) {
            $statement = "$entry".Trim()
            $requirementId = ''
            $acceptanceCriteria = @()
            $actors = @()
            $entities = @()
            $integrations = @()
            $requiredCapabilities = @()
            $priority = 'unspecified'
        } else {
            $statement = ''
            foreach ($statementProperty in @('statement', 'description', 'text', 'businessRequirement', 'name')) {
                $value = "$(Get-AcceleratorMatchingValue -InputObject $entry -Name $statementProperty -DefaultValue '')".Trim()
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    $statement = $value
                    break
                }
            }
            $requirementId = "$(Get-AcceleratorMatchingValue -InputObject $entry -Name 'requirementId' -DefaultValue (
                Get-AcceleratorMatchingValue -InputObject $entry -Name 'id' -DefaultValue ''
            ))".Trim()
            $acceptanceCriteria = ConvertTo-AcceleratorStringArray (
                Get-AcceleratorMatchingValue -InputObject $entry -Name 'acceptanceCriteria' -DefaultValue @()
            )
            $actors = ConvertTo-AcceleratorStringArray (
                Get-AcceleratorMatchingValue -InputObject $entry -Name 'actors' -DefaultValue @()
            )
            $entities = ConvertTo-AcceleratorStringArray (
                Get-AcceleratorMatchingValue -InputObject $entry -Name 'entities' -DefaultValue @()
            )
            $integrations = ConvertTo-AcceleratorStringArray (
                Get-AcceleratorMatchingValue -InputObject $entry -Name 'integrations' -DefaultValue @()
            )
            $requiredCapabilities = ConvertTo-AcceleratorStringArray (
                Get-AcceleratorMatchingValue -InputObject $entry -Name 'requiredCapabilities' -DefaultValue (
                    Get-AcceleratorMatchingValue -InputObject $entry -Name 'capabilities' -DefaultValue @()
                )
            )
            $priority = "$(Get-AcceleratorMatchingValue -InputObject $entry -Name 'priority' -DefaultValue 'unspecified')"
        }
        if ([string]::IsNullOrWhiteSpace($statement)) {
            throw 'Every requirement must include a non-empty statement or description.'
        }
        if ([string]::IsNullOrWhiteSpace($requirementId)) {
            $hashInput = "$ScenarioSlug|$($statement.ToLowerInvariant())"
            $requirementId = "REQ-$((Get-AcceleratorStringSha256 -Value $hashInput).Substring(0, 10).ToUpperInvariant())"
        }
        if (-not $seen.Add($requirementId)) {
            throw "Duplicate requirement ID '$requirementId'."
        }
        $combinedText = @($statement, $acceptanceCriteria, $requiredCapabilities) -join ' '
        $ambiguityMarkers = @(
            'tbd', 'to be determined', 'unknown', 'unsure', 'maybe', 'either',
            'or something', 'not decided', 'conflicting'
        )
        $uncertainties = @($ambiguityMarkers | Where-Object {
            $combinedText.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
        } | ForEach-Object { "Requirement contains ambiguity marker '$_'." })
        if (@(Get-AcceleratorMeaningfulTerms -Text $combinedText).Count -lt 2) {
            $uncertainties += 'Requirement has insufficient distinctive business detail.'
        }
        $normalized.Add([pscustomobject][ordered]@{
            requirementId = $requirementId
            scenarioSlug = $ScenarioSlug
            statement = $statement
            acceptanceCriteria = @($acceptanceCriteria)
            actors = @($actors)
            entities = @($entities)
            integrations = @($integrations)
            requiredCapabilities = @($requiredCapabilities)
            priority = $priority
            uncertainties = @($uncertainties | Sort-Object -Unique)
            normalizedTerms = @(Get-AcceleratorMeaningfulTerms -Text $combinedText)
        }) | Out-Null
    }
    return @($normalized.ToArray() | Sort-Object requirementId)
}

function Get-AcceleratorCatalogEvidenceText {
    param([Parameter(Mandatory)] [object]$Item)

    $frontMatter = Get-AcceleratorMatchingValue -InputObject $Item -Name 'frontMatter'
    $values = [Collections.Generic.List[string]]::new()
    foreach ($value in @(
        (Get-AcceleratorMatchingValue -InputObject $Item -Name 'name' -DefaultValue ''),
        (Get-AcceleratorMatchingValue -InputObject $Item -Name 'description' -DefaultValue ''),
        (Get-AcceleratorMatchingValue -InputObject $frontMatter -Name 'title' -DefaultValue ''),
        (Get-AcceleratorMatchingValue -InputObject $frontMatter -Name 'description' -DefaultValue ''),
        (Get-AcceleratorMatchingValue -InputObject $frontMatter -Name 'module_category' -DefaultValue '')
    )) {
        if (-not [string]::IsNullOrWhiteSpace("$value")) { $values.Add("$value") | Out-Null }
    }
    foreach ($name in @('tags', 'capabilities', 'workflows', 'actors')) {
        foreach ($value in @(Get-AcceleratorMatchingValue -InputObject $Item -Name $name -DefaultValue @())) {
            if (-not [string]::IsNullOrWhiteSpace("$value")) { $values.Add("$value") | Out-Null }
        }
    }
    return ($values.ToArray() -join ' ')
}

function Get-AcceleratorPackageComponents {
    param([Parameter(Mandatory)] [object]$Package)

    $components = [Collections.Generic.List[object]]::new()
    $moduleId = "$(Get-AcceleratorMatchingValue -InputObject $Package -Name 'moduleId' -DefaultValue '')"
    $packageId = "$(Get-AcceleratorMatchingValue -InputObject $Package -Name 'packageId' -DefaultValue '')"
    $version = "$(Get-AcceleratorMatchingValue -InputObject (
        Get-AcceleratorMatchingValue -InputObject $Package -Name 'solution'
    ) -Name 'version' -DefaultValue '')"
    foreach ($table in @(Get-AcceleratorMatchingValue -InputObject $Package -Name 'tables' -DefaultValue @())) {
        $tableName = "$(Get-AcceleratorMatchingValue -InputObject $table -Name 'displayName' -DefaultValue (
            Get-AcceleratorMatchingValue -InputObject $table -Name 'logicalName' -DefaultValue ''
        ))"
        $tableIdentity = "$(Get-AcceleratorMatchingValue -InputObject $table -Name 'logicalName' -DefaultValue '')"
        $components.Add([pscustomobject]@{
            kind = 'table'; identity = $tableIdentity; name = $tableName
            moduleId = $moduleId; packageId = $packageId; version = $version
        }) | Out-Null
        foreach ($attribute in @(Get-AcceleratorMatchingValue -InputObject $table -Name 'attributes' -DefaultValue @())) {
            $attributeIdentity = "$(Get-AcceleratorMatchingValue -InputObject $attribute -Name 'logicalName' -DefaultValue (
                Get-AcceleratorMatchingValue -InputObject $attribute -Name 'physicalName' -DefaultValue ''
            ))"
            $components.Add([pscustomobject]@{
                kind = 'attribute'
                identity = "$tableIdentity.$attributeIdentity"
                name = "$tableName $attributeIdentity"
                moduleId = $moduleId; packageId = $packageId; version = $version
            }) | Out-Null
        }
    }
    foreach ($definition in @(
        [pscustomobject]@{ Collection = 'relationships'; Kind = 'relationship'; Identity = @('name'); Name = @('name', 'referencingEntity', 'referencedEntity') },
        [pscustomobject]@{ Collection = 'optionSets'; Kind = 'choice'; Identity = @('name'); Name = @('displayName', 'name') },
        [pscustomobject]@{ Collection = 'forms'; Kind = 'form'; Identity = @('formId'); Name = @('name', 'tableLogicalName', 'formType') },
        [pscustomobject]@{ Collection = 'views'; Kind = 'view'; Identity = @('savedQueryId'); Name = @('name', 'tableLogicalName') },
        [pscustomobject]@{ Collection = 'apps'; Kind = 'application'; Identity = @('schemaName'); Name = @('schemaName', 'kind') }
    )) {
        foreach ($component in @(Get-AcceleratorMatchingValue -InputObject $Package -Name $definition.Collection -DefaultValue @())) {
            $identity = @($definition.Identity | ForEach-Object {
                "$(Get-AcceleratorMatchingValue -InputObject $component -Name $_ -DefaultValue '')"
            } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join '|'
            $name = @($definition.Name | ForEach-Object {
                "$(Get-AcceleratorMatchingValue -InputObject $component -Name $_ -DefaultValue '')"
            } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' '
            if ([string]::IsNullOrWhiteSpace($identity)) { $identity = $name }
            if (-not [string]::IsNullOrWhiteSpace($identity)) {
                $components.Add([pscustomobject]@{
                    kind = $definition.Kind; identity = $identity; name = $name
                    moduleId = $moduleId; packageId = $packageId; version = $version
                }) | Out-Null
            }
        }
    }
    return @($components.ToArray() | Sort-Object kind, identity -Unique)
}

function Get-AcceleratorCandidateMatches {
    param(
        [Parameter(Mandatory)] [object]$Requirement,
        [Parameter(Mandatory)] [object]$CatalogSnapshot,
        [object[]]$PackageMetadata = @()
    )

    $packagesByModule = @{}
    $componentsByModule = @{}
    foreach ($package in @($PackageMetadata)) {
        $moduleId = "$(Get-AcceleratorMatchingValue -InputObject $package -Name 'moduleId' -DefaultValue '')"
        if (-not [string]::IsNullOrWhiteSpace($moduleId)) {
            $packagesByModule[$moduleId] = $package
            $componentsByModule[$moduleId] = @(Get-AcceleratorPackageComponents -Package $package)
        }
    }
    $requirementTerms = @($Requirement.normalizedTerms)
    $candidates = [Collections.Generic.List[object]]::new()
    foreach ($item in @($CatalogSnapshot.items | Where-Object itemType -eq 'module')) {
        $itemId = "$($item.itemId)"
        $evidenceText = Get-AcceleratorCatalogEvidenceText -Item $item
        $documentedTerms = @(Get-AcceleratorMeaningfulTerms -Text $evidenceText)
        $matchedTerms = @(Get-AcceleratorMatchedTerms -RequirementTerms $requirementTerms -EvidenceTerms $documentedTerms)
        $name = "$($item.name)"
        $nameMatch = -not [string]::IsNullOrWhiteSpace($name) -and
            $Requirement.statement.IndexOf($name, [StringComparison]::OrdinalIgnoreCase) -ge 0
        $capabilityCoverage = @($Requirement.requiredCapabilities | ForEach-Object {
            $capability = "$_"
            $capabilityTerms = @(Get-AcceleratorMeaningfulTerms -Text $capability)
            $capabilityMatches = @(Get-AcceleratorMatchedTerms -RequirementTerms $capabilityTerms -EvidenceTerms $documentedTerms)
            [pscustomobject]@{
                capability = $capability
                documented = $capabilityTerms.Count -gt 0 -and $capabilityMatches.Count -eq $capabilityTerms.Count
                matchedTerms = $capabilityMatches
            }
        })
        $documentedCapabilityCount = @($capabilityCoverage | Where-Object documented).Count
        $catalogRelevant = $nameMatch -or $matchedTerms.Count -ge 2 -or $documentedCapabilityCount -gt 0
        if (-not $catalogRelevant) { continue }

        $availability = Get-AcceleratorMatchingValue -InputObject $item -Name 'availability'
        $documented = [bool](Get-AcceleratorMatchingValue -InputObject $availability -Name 'documented' -DefaultValue $false)
        $sourceAvailable = [bool](Get-AcceleratorMatchingValue -InputObject $availability -Name 'sourceAvailable' -DefaultValue $false)
        $package = if ($packagesByModule.ContainsKey($itemId)) { $packagesByModule[$itemId] } else { $null }
        $componentMatches = @()
        if ($null -ne $package) {
            $componentMatches = @($componentsByModule[$itemId] | ForEach-Object {
                $component = $_
                $componentTerms = @(Get-AcceleratorMeaningfulTerms -Text "$($component.name) $($component.identity)")
                $terms = @(Get-AcceleratorMatchedTerms -RequirementTerms $requirementTerms -EvidenceTerms $componentTerms)
                if ($terms.Count -gt 0) {
                    [pscustomobject][ordered]@{
                        kind = $component.kind
                        identity = $component.identity
                        name = $component.name
                        matchedTerms = $terms
                        evidenceLevel = 'package-verified'
                    }
                }
            } | Sort-Object kind, identity -Unique | Select-Object -First 20)
        }
        $unsupportedCapabilities = @($capabilityCoverage | Where-Object { -not $_.documented } | ForEach-Object capability)
        $fitBand = if (-not $documented -or -not $sourceAvailable) {
            'verification-required'
        } elseif ($null -eq $package) {
            'documented-only'
        } elseif ($Requirement.requiredCapabilities.Count -gt 0 -and $unsupportedCapabilities.Count -eq 0 -and
            $componentMatches.Count -gt 0) {
            'verified-foundation'
        } elseif ($componentMatches.Count -gt 0) {
            'partial-verified-foundation'
        } else {
            'documented-without-component-correlation'
        }
        $solution = if ($null -ne $package) {
            Get-AcceleratorMatchingValue -InputObject $package -Name 'solution'
        } else {
            $null
        }
        $candidates.Add([pscustomobject][ordered]@{
            moduleId = $itemId
            moduleName = $name
            documentedVersion = "$(Get-AcceleratorMatchingValue -InputObject (
                Get-AcceleratorMatchingValue -InputObject $item -Name 'frontMatter'
            ) -Name 'latest_release' -DefaultValue '')"
            packageId = "$(Get-AcceleratorMatchingValue -InputObject $package -Name 'packageId' -DefaultValue '')"
            packageVersion = "$(Get-AcceleratorMatchingValue -InputObject $solution -Name 'version' -DefaultValue '')"
            fitBand = $fitBand
            matchedDocumentedTerms = $matchedTerms
            capabilityCoverage = $capabilityCoverage
            componentEvidence = $componentMatches
            unsupportedCapabilities = $unsupportedCapabilities
            evidenceLevel = if ($null -ne $package) { 'package-verified' } elseif ($documented) { 'conceptual' } else { 'unverified' }
            sourceReferences = @(
                [pscustomobject]@{
                    itemId = $itemId
                    sourceUrl = "$(Get-AcceleratorMatchingValue -InputObject $item -Name 'sourceUrl' -DefaultValue '')"
                    contentHash = "$(Get-AcceleratorMatchingValue -InputObject $item -Name 'contentHash' -DefaultValue '')"
                    claim = "$(Get-AcceleratorMatchingValue -InputObject (
                        Get-AcceleratorMatchingValue -InputObject $item -Name 'frontMatter'
                    ) -Name 'description' -DefaultValue $evidenceText)"
                    evidenceLevel = 'conceptual'
                }
            )
            availability = [pscustomobject]@{
                documented = $documented
                sourceAvailable = $sourceAvailable
                packageVerified = $null -ne $package
                environmentVerified = [bool](Get-AcceleratorMatchingValue -InputObject $availability -Name 'environmentVerified' -DefaultValue $false)
            }
        }) | Out-Null
    }
    return @($candidates.ToArray() | Sort-Object {
        switch ($_.fitBand) {
            'verified-foundation' { 0 }
            'partial-verified-foundation' { 1 }
            'documented-only' { 2 }
            'documented-without-component-correlation' { 3 }
            default { 4 }
        }
    }, moduleId)
}

function Get-AcceleratorDependencyIdentity {
    param(
        [Parameter(Mandatory)] [object]$Dependency,
        [Parameter(Mandatory)] [string]$SourceModuleId
    )

    $required = Get-AcceleratorMatchingValue -InputObject $Dependency -Name 'required'
    return @(
        $SourceModuleId,
        "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'type' -DefaultValue '')",
        "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'id' -DefaultValue '')",
        "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'solution' -DefaultValue '')",
        "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'package' -DefaultValue '')",
        "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'schemaName' -DefaultValue '')",
        "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'uniqueName' -DefaultValue '')",
        "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'parentDisplayName' -DefaultValue '')",
        "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'displayName' -DefaultValue '')"
    ) -join '|'
}

function New-AcceleratorDependencyManifest {
    param(
        [string[]]$SelectedModuleIds,
        [object[]]$PackageMetadata = @()
    )

    $packageByModule = @{}
    $moduleBySolution = @{}
    foreach ($package in @($PackageMetadata)) {
        $moduleId = "$($package.moduleId)"
        $packageByModule[$moduleId] = $package
        $solutionName = "$(Get-AcceleratorMatchingValue -InputObject $package.solution -Name 'uniqueName' -DefaultValue '')"
        if (-not [string]::IsNullOrWhiteSpace($solutionName)) {
            $moduleBySolution[$solutionName.ToLowerInvariant()] = $moduleId
        }
    }
    $queue = [Collections.Generic.Queue[string]]::new()
    foreach ($moduleId in @($SelectedModuleIds | Sort-Object -Unique)) { $queue.Enqueue($moduleId) }
    $visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $edges = [Collections.Generic.List[object]]::new()
    $unresolved = [Collections.Generic.List[object]]::new()
    while ($queue.Count -gt 0) {
        $moduleId = $queue.Dequeue()
        if (-not $visited.Add($moduleId)) { continue }
        if (-not $packageByModule.ContainsKey($moduleId)) {
            $unresolved.Add([pscustomobject]@{
                sourceModuleId = $moduleId
                identity = "module-package|$moduleId"
                reason = 'No package-verified metadata is available for this selected module.'
            }) | Out-Null
            continue
        }
        $package = $packageByModule[$moduleId]
        foreach ($dependency in @($package.declaredDependencies)) {
            $required = $dependency.required
            $solutionReference = "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'solution' -DefaultValue '')"
            $solutionName = if ($solutionReference -match '^(?<name>[A-Za-z0-9_]+)') { $Matches.name } else { '' }
            $targetModuleId = if (-not [string]::IsNullOrWhiteSpace($solutionName) -and
                $moduleBySolution.ContainsKey($solutionName.ToLowerInvariant())) {
                $moduleBySolution[$solutionName.ToLowerInvariant()]
            } else {
                ''
            }
            $identity = Get-AcceleratorDependencyIdentity -Dependency $dependency -SourceModuleId $moduleId
            $versionConstraint = if ($solutionReference -match '\((?<version>[^)]+)\)') { $Matches.version } else { '' }
            $targetVersion = if (-not [string]::IsNullOrWhiteSpace($targetModuleId)) {
                "$($packageByModule[$targetModuleId].solution.version)"
            } else {
                ''
            }
            $edge = [pscustomobject][ordered]@{
                identity = $identity
                sourceModuleId = $moduleId
                targetModuleId = $targetModuleId
                targetSolution = $solutionName
                dependencyType = if ([string]::IsNullOrWhiteSpace($targetModuleId)) { 'external-component' } else { 'required-module' }
                componentType = "$(Get-AcceleratorMatchingValue -InputObject $required -Name 'type' -DefaultValue '')"
                componentIdentity = @(
                    (Get-AcceleratorMatchingValue -InputObject $required -Name 'id' -DefaultValue ''),
                    (Get-AcceleratorMatchingValue -InputObject $required -Name 'schemaName' -DefaultValue ''),
                    (Get-AcceleratorMatchingValue -InputObject $required -Name 'uniqueName' -DefaultValue ''),
                    (Get-AcceleratorMatchingValue -InputObject $required -Name 'parentDisplayName' -DefaultValue ''),
                    (Get-AcceleratorMatchingValue -InputObject $required -Name 'displayName' -DefaultValue '')
                ) -join '|'
                versionConstraint = $versionConstraint
                selectedTargetVersion = $targetVersion
                versionStatus = if ([string]::IsNullOrWhiteSpace($versionConstraint)) {
                    'not-declared'
                } elseif ($versionConstraint -eq $targetVersion) {
                    'exact'
                } else {
                    'unverified'
                }
                evidenceLevel = 'package-verified'
            }
            $edges.Add($edge) | Out-Null
            if (-not [string]::IsNullOrWhiteSpace($targetModuleId)) {
                $queue.Enqueue($targetModuleId)
            } elseif ([string]::IsNullOrWhiteSpace($solutionName)) {
                $unresolved.Add([pscustomobject]@{
                    sourceModuleId = $moduleId
                    identity = $identity
                    reason = 'Dependency does not expose a uniquely resolvable solution identity.'
                }) | Out-Null
            }
        }
    }
    $deduplicatedEdges = @($edges.ToArray() | Sort-Object identity -Unique)
    $moduleDependencies = @(
        $deduplicatedEdges |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.targetModuleId) } |
            Group-Object { "$($_.sourceModuleId)|$($_.targetModuleId)" } |
            ForEach-Object {
                $group = @($_.Group)
                [pscustomobject][ordered]@{
                    identity = $_.Name
                    sourceModuleId = "$($group[0].sourceModuleId)"
                    targetModuleId = "$($group[0].targetModuleId)"
                    targetSolution = "$($group[0].targetSolution)"
                    dependencyType = 'required-module'
                    versionConstraints = @($group.versionConstraint | Where-Object {
                        -not [string]::IsNullOrWhiteSpace($_)
                    } | Sort-Object -Unique)
                    selectedTargetVersion = "$($group[0].selectedTargetVersion)"
                    versionStatus = if (@($group.versionStatus | Where-Object { $_ -eq 'unverified' }).Count -gt 0) {
                        'unverified'
                    } elseif (@($group.versionStatus | Where-Object { $_ -eq 'exact' }).Count -gt 0) {
                        'exact'
                    } else {
                        'not-declared'
                    }
                    componentDependencyCount = $group.Count
                    evidenceLevel = 'package-verified'
                }
            } |
            Sort-Object identity
    )
    $foundationModules = @(
        $moduleDependencies |
            ForEach-Object { $_.targetModuleId } |
            Sort-Object -Unique
    )
    $dependencyNodes = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($dependency in $moduleDependencies) {
        $dependencyNodes.Add("$($dependency.sourceModuleId)") | Out-Null
        $dependencyNodes.Add("$($dependency.targetModuleId)") | Out-Null
    }
    $adjacency = @{}
    $incomingCount = @{}
    foreach ($node in $dependencyNodes) {
        $adjacency[$node] = [Collections.Generic.List[string]]::new()
        $incomingCount[$node] = 0
    }
    foreach ($dependency in $moduleDependencies) {
        $source = "$($dependency.sourceModuleId)"
        $target = "$($dependency.targetModuleId)"
        $adjacency[$source].Add($target)
        $incomingCount[$target]++
    }
    $acyclicQueue = [Collections.Generic.Queue[string]]::new()
    foreach ($node in @($dependencyNodes | Sort-Object)) {
        if ($incomingCount[$node] -eq 0) { $acyclicQueue.Enqueue($node) }
    }
    $acyclicNodeCount = 0
    while ($acyclicQueue.Count -gt 0) {
        $node = $acyclicQueue.Dequeue()
        $acyclicNodeCount++
        foreach ($target in $adjacency[$node]) {
            $incomingCount[$target]--
            if ($incomingCount[$target] -eq 0) { $acyclicQueue.Enqueue($target) }
        }
    }
    $cycles = @(
        if ($acyclicNodeCount -ne $dependencyNodes.Count) {
            [pscustomobject][ordered]@{
                candidateNodes = @($dependencyNodes | Where-Object { $incomingCount[$_] -gt 0 } | Sort-Object)
                reason = 'The module dependency graph contains a cyclic subgraph; FAST-dependent execution is blocked.'
            }
        }
    )
    return [pscustomobject][ordered]@{
        selectedModules = @($SelectedModuleIds | Sort-Object -Unique)
        transitiveModules = @($visited | Sort-Object)
        foundationModules = $foundationModules
        specialtyModules = @($SelectedModuleIds | Where-Object { $foundationModules -notcontains $_ } | Sort-Object -Unique)
        moduleDependencies = $moduleDependencies
        componentDependencies = $deduplicatedEdges
        unresolvedDependencies = @($unresolved.ToArray() | Sort-Object identity -Unique)
        duplicateEdgesRemoved = $edges.Count - $deduplicatedEdges.Count
        cycles = $cycles
        versionPolicy = 'Exact matches are reported; differing versions remain unverified without an explicit compatibility policy.'
    }
}

function Resolve-AcceleratorEnvironmentReference {
    param(
        [AllowNull()] [object]$EnvironmentEvidence,
        [Parameter(Mandatory)] [object]$CatalogSnapshot,
        [object[]]$PackageMetadata = @(),
        [datetime]$EvaluationTimeUtc = [DateTime]::UtcNow
    )

    if ($null -eq $EnvironmentEvidence) {
        return [pscustomobject][ordered]@{
            provided = $false; status = 'not-provided'; fresh = $false
            snapshotMatch = $false; packageMatch = $false
            executionGateOpen = $false; environmentUrl = ''; coreAssessment = 'unverified'
            metadataFingerprint = ''; expiresAtUtc = ''
            limitations = @('No environment evidence was supplied; matching remains available but FAST-dependent execution is blocked.')
        }
    }
    $status = "$(Get-AcceleratorMatchingValue -InputObject $EnvironmentEvidence -Name 'readinessStatus' -DefaultValue (
        Get-AcceleratorMatchingValue -InputObject $EnvironmentEvidence -Name 'status' -DefaultValue 'unverified'
    ))"
    $expires = "$(Get-AcceleratorMatchingValue -InputObject $EnvironmentEvidence -Name 'expiresAtUtc' -DefaultValue '')"
    $fresh = $false
    if (-not [string]::IsNullOrWhiteSpace($expires)) {
        try {
            $fresh = [DateTimeOffset]::Parse($expires).UtcDateTime -gt $EvaluationTimeUtc.ToUniversalTime()
        } catch {
            $fresh = $false
        }
    }
    $snapshotId = "$(Get-AcceleratorMatchingValue -InputObject $CatalogSnapshot -Name 'snapshotId' -DefaultValue '')"
    $evidenceSnapshotId = "$(Get-AcceleratorMatchingValue -InputObject $EnvironmentEvidence -Name 'catalogSnapshotId' -DefaultValue '')"
    $snapshotMatch = $snapshotId -ceq $evidenceSnapshotId
    $requiredPackageIds = @($EnvironmentEvidence.requiredModules | ForEach-Object { "$($_.packageId)" })
    $selectedPackageIds = @($PackageMetadata | ForEach-Object { "$($_.packageId)" })
    $packageMatch = $selectedPackageIds.Count -gt 0 -and
        @($selectedPackageIds | Where-Object { $requiredPackageIds -notcontains $_ }).Count -eq 0
    $evidence = Get-AcceleratorMatchingValue -InputObject $EnvironmentEvidence -Name 'evidence'
    return [pscustomobject][ordered]@{
        provided = $true
        status = $status
        fresh = $fresh
        snapshotMatch = $snapshotMatch
        packageMatch = $packageMatch
        executionGateOpen = $status -eq 'ready' -and $fresh -and $snapshotMatch -and $packageMatch
        environmentUrl = "$(Get-AcceleratorMatchingValue -InputObject (
            Get-AcceleratorMatchingValue -InputObject $EnvironmentEvidence -Name 'environment'
        ) -Name 'environmentUrl' -DefaultValue '')"
        coreAssessment = "$(Get-AcceleratorMatchingValue -InputObject $evidence -Name 'coreAssessment' -DefaultValue 'unverified')"
        metadataFingerprint = "$(Get-AcceleratorMatchingValue -InputObject $evidence -Name 'metadataFingerprint' -DefaultValue '')"
        expiresAtUtc = $expires
        limitations = @(
            if (-not $fresh) { 'Environment evidence is absent or stale.' }
            if (-not $snapshotMatch) { 'Environment evidence references a different catalog snapshot.' }
            if (-not $packageMatch) { 'Environment evidence does not cover every selected package identity.' }
            if ($status -ne 'ready') { "Environment readiness is '$status'." }
        )
    }
}

function New-AcceleratorRequirementDecision {
    param(
        [Parameter(Mandatory)] [object]$Requirement,
        [object[]]$Candidates = @()
    )

    $primary = @($Candidates | Select-Object -First 1)
    $dispositions = [Collections.Generic.List[string]]::new()
    $gaps = [Collections.Generic.List[string]]::new()
    $risks = [Collections.Generic.List[string]]::new()
    $schema = [ordered]@{
        tables = @(); attributes = @(); relationships = @()
        forms = @(); views = @(); workflows = @()
    }
    if ($Requirement.uncertainties.Count -gt 0) {
        $dispositions.Add('VERIFY') | Out-Null
        foreach ($uncertainty in $Requirement.uncertainties) { $risks.Add($uncertainty) | Out-Null }
    } elseif ($primary.Count -eq 0) {
        $dispositions.Add('BUILD') | Out-Null
        $gaps.Add('No documented accelerator capability has sufficient evidence for this requirement.') | Out-Null
        if ($Requirement.entities.Count -gt 0) {
            $schema.tables = @($Requirement.entities | ForEach-Object { "Design a new table for '$_'; no logical name is inferred." })
        } else {
            $schema.tables = @('Complete requirement-specific table design before payload generation.')
        }
    } else {
        $candidate = $primary[0]
        switch ($candidate.fitBand) {
            'verified-foundation' {
                $dispositions.Add('REUSE') | Out-Null
            }
            'partial-verified-foundation' {
                $dispositions.Add('EXTEND') | Out-Null
                $gaps.Add('Package components provide a verified foundation, but documentation does not establish complete process coverage.') | Out-Null
            }
            default {
                $dispositions.Add('VERIFY') | Out-Null
                $gaps.Add('Documented relevance exists without sufficient physical or source evidence for implementation reuse.') | Out-Null
            }
        }
        foreach ($gap in @($candidate.unsupportedCapabilities)) {
            $gaps.Add("Required capability '$gap' is not established by documented evidence.") | Out-Null
        }
        $componentEvidence = @($candidate.componentEvidence)
        $schema.tables = @($componentEvidence | Where-Object kind -eq 'table' | ForEach-Object { "Reuse $($_.identity)" })
        $schema.attributes = @($componentEvidence | Where-Object kind -eq 'attribute' | ForEach-Object { "Reuse $($_.identity)" })
        $schema.relationships = @($componentEvidence | Where-Object kind -eq 'relationship' | ForEach-Object { "Reuse $($_.identity)" })
        $schema.forms = @($componentEvidence | Where-Object kind -eq 'form' | ForEach-Object { "Reuse $($_.identity)" })
        $schema.views = @($componentEvidence | Where-Object kind -eq 'view' | ForEach-Object { "Reuse $($_.identity)" })
        if ($dispositions -contains 'EXTEND') {
            $schema.workflows = @($gaps | ForEach-Object { "Design extension for: $_" })
        }
        if (-not $candidate.availability.sourceAvailable) {
            $risks.Add('Catalog source is unavailable or archived; verify the pinned evidence before reuse.') | Out-Null
        }
    }
    if ($Requirement.integrations.Count -gt 0 -or
        $Requirement.statement -match '(?i)\b(?:integrat|external system|api|connector)\w*') {
        if (-not $dispositions.Contains('INTEGRATE')) { $dispositions.Add('INTEGRATE') | Out-Null }
    }
    if ($dispositions.Count -eq 0) { $dispositions.Add('VERIFY') | Out-Null }
    $candidateModule = if ($primary.Count -gt 0) { "$($primary[0].moduleId)" } else { '' }
    $candidateVersion = if ($primary.Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace("$($primary[0].packageVersion)")) {
            "$($primary[0].packageVersion)"
        } else {
            "$($primary[0].documentedVersion)"
        }
    } else { '' }
    return [pscustomobject][ordered]@{
        requirementId = $Requirement.requirementId
        description = $Requirement.statement
        dispositions = @($dispositions.ToArray() | Sort-Object)
        candidateModuleId = $candidateModule
        candidateVersion = $candidateVersion
        candidates = @($Candidates)
        fitExplanation = if ($primary.Count -eq 0) {
            'No evidence-grounded accelerator candidate was found.'
        } else {
            "Candidate '$($primary[0].moduleName)' is classified '$($primary[0].fitBand)' from documented claims plus independently reported package evidence."
        }
        evidenceLevel = if ($primary.Count -gt 0) { "$($primary[0].evidenceLevel)" } else { 'unverified' }
        gaps = @($gaps.ToArray() | Sort-Object -Unique)
        proposedSchemaChanges = [pscustomobject]$schema
        integrations = @($Requirement.integrations)
        dependencies = @()
        effortAssumptions = @(
            if ($dispositions -contains 'REUSE') { 'Lower customization effort is plausible, subject to environment readiness and detailed process validation.' }
            if ($dispositions -contains 'EXTEND') { 'Moderate customization effort is assumed until every documented gap is designed.' }
            if ($dispositions -contains 'BUILD') { 'Custom schema and experience design effort is required.' }
            if ($dispositions -contains 'INTEGRATE') { 'Connector, security, error handling, and external API lifecycle effort is required.' }
            if ($dispositions -contains 'VERIFY') { 'Estimation remains provisional until evidence gaps are resolved.' }
        )
        risks = @($risks.ToArray() | Sort-Object -Unique)
        unresolvedQuestions = @($Requirement.uncertainties)
        acceptanceCriteria = @($Requirement.acceptanceCriteria)
        taskReferences = @(
            "FAST004-$($Requirement.requirementId)-EVIDENCE",
            "FAST004-$($Requirement.requirementId)-DESIGN",
            "FAST004-$($Requirement.requirementId)-ACCEPTANCE"
        )
    }
}

function New-AcceleratorArchitectureOptions {
    param(
        [Parameter(Mandatory)] [object[]]$CoverageMatrix,
        [Parameter(Mandatory)] [object]$EnvironmentReference,
        [AllowNull()] [object]$DependencyManifest = $null
    )

    $matched = @($CoverageMatrix | Where-Object { -not [string]::IsNullOrWhiteSpace($_.candidateModuleId) }).Count
    $reuse = @($CoverageMatrix | Where-Object { $_.dispositions -contains 'REUSE' }).Count
    $extend = @($CoverageMatrix | Where-Object { $_.dispositions -contains 'EXTEND' }).Count
    $build = @($CoverageMatrix | Where-Object { $_.dispositions -contains 'BUILD' }).Count
    $verify = @($CoverageMatrix | Where-Object { $_.dispositions -contains 'VERIFY' }).Count
    $fastSuitable = $matched -gt 0 -and $build -eq 0 -and $verify -eq 0 -and $extend -eq 0
    $hybridSuitable = $matched -gt 0 -and ($extend -gt 0 -or $build -gt 0 -or $verify -gt 0)
    $dependencyGateOpen = $null -eq $DependencyManifest -or (
        @($DependencyManifest.cycles).Count -eq 0 -and
        @($DependencyManifest.unresolvedDependencies).Count -eq 0 -and
        @($DependencyManifest.moduleDependencies | Where-Object versionStatus -eq 'unverified').Count -eq 0
    )
    $fastExecutionGateOpen = [bool]$EnvironmentReference.executionGateOpen -and $dependencyGateOpen
    $recommended = if ($fastSuitable) {
        'fast-based'
    } elseif ($hybridSuitable) {
        'hybrid'
    } else {
        'fully-custom'
    }
    $rankOrder = switch ($recommended) {
        'fast-based' { @('fast-based', 'hybrid', 'fully-custom') }
        'hybrid' { @('hybrid', 'fully-custom', 'fast-based') }
        default { @('fully-custom', 'hybrid', 'fast-based') }
    }
    $options = @(
        [pscustomobject][ordered]@{
            optionId = 'fast-based'
            rank = [array]::IndexOf($rankOrder, 'fast-based') + 1
            architectureSuitable = $fastSuitable
            executionGateOpen = $fastExecutionGateOpen
            status = if (-not $fastSuitable) { 'not-recommended' } elseif ($fastExecutionGateOpen) { 'ready-for-approved-planning' } elseif (-not $dependencyGateOpen) { 'planning-only-dependency-blocked' } else { 'planning-only-environment-blocked' }
            rationale = "Verified reuse requirements: $reuse; extension requirements: $extend; custom-build requirements: $build; verification requirements: $verify."
            dependencies = 'Requires every selected accelerator module and its transitive prerequisites.'
            userMaySelect = $true
        },
        [pscustomobject][ordered]@{
            optionId = 'hybrid'
            rank = [array]::IndexOf($rankOrder, 'hybrid') + 1
            architectureSuitable = $hybridSuitable -or $fastSuitable
            executionGateOpen = $fastExecutionGateOpen
            status = if (-not ($hybridSuitable -or $fastSuitable)) { 'not-recommended' } elseif ($fastExecutionGateOpen) { 'ready-for-approved-planning' } elseif (-not $dependencyGateOpen) { 'planning-only-dependency-blocked' } else { 'planning-only-fast-portions-blocked' }
            rationale = "Accelerator candidates cover $matched requirement(s), while $extend extension, $build build, and $verify verification result(s) require explicit delta work."
            dependencies = 'FAST-derived portions require verified modules; custom portions remain independent.'
            userMaySelect = $true
        },
        [pscustomobject][ordered]@{
            optionId = 'fully-custom'
            rank = [array]::IndexOf($rankOrder, 'fully-custom') + 1
            architectureSuitable = $true
            executionGateOpen = $true
            status = 'available'
            rationale = 'Uses the existing wizard generation path without FAST package or environment prerequisites.'
            dependencies = 'No FAST dependency.'
            userMaySelect = $true
        }
    )
    return [pscustomobject]@{
        recommendedOption = $recommended
        options = @($options | Sort-Object rank)
    }
}

function Invoke-AcceleratorRequirementsAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Requirements,
        [Parameter(Mandatory)] [object]$CatalogSnapshot,
        [object[]]$PackageMetadata = @(),
        [AllowNull()] [object]$EnvironmentEvidence = $null,
        [string]$ProviderId = '',
        [string]$ScenarioSlug = 'accelerator-analysis',
        [bool]$ProviderEnabled = $true,
        [datetime]$EvaluationTimeUtc = [DateTime]::UtcNow
    )

    $snapshotProvider = "$(Get-AcceleratorMatchingValue -InputObject $CatalogSnapshot -Name 'providerId' -DefaultValue '')"
    if ([string]::IsNullOrWhiteSpace($ProviderId)) { $ProviderId = $snapshotProvider }
    if (-not [string]::Equals($ProviderId, $snapshotProvider, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Provider '$ProviderId' does not match catalog provider '$snapshotProvider'."
    }
    $normalizedRequirements = @(ConvertTo-NormalizedAcceleratorRequirements -Requirements $Requirements -ScenarioSlug $ScenarioSlug)
    $requirementsHash = Get-AcceleratorStringSha256 -Value (
        ConvertTo-AcceleratorCanonicalJson -InputObject $normalizedRequirements
    )
    $environmentReference = Resolve-AcceleratorEnvironmentReference `
        -EnvironmentEvidence $EnvironmentEvidence `
        -CatalogSnapshot $CatalogSnapshot `
        -PackageMetadata $PackageMetadata `
        -EvaluationTimeUtc $EvaluationTimeUtc

    if (-not $ProviderEnabled) {
        $customOptions = New-AcceleratorArchitectureOptions -CoverageMatrix @(
            $normalizedRequirements | ForEach-Object {
                New-AcceleratorRequirementDecision -Requirement $_ -Candidates @()
            }
        ) -EnvironmentReference $environmentReference
        $disabledBasis = [ordered]@{
            providerId = $ProviderId
            snapshotId = "$($CatalogSnapshot.snapshotId)"
            requirementsHash = $requirementsHash
            status = 'disabled'
        }
        return [pscustomobject][ordered]@{
            schemaVersion = '1.0'
            analysisId = "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson $disabledBasis))"
            providerId = $ProviderId
            snapshotId = "$($CatalogSnapshot.snapshotId)"
            scenarioSlug = $ScenarioSlug
            status = 'disabled'
            evaluatedAtUtc = $EvaluationTimeUtc.ToUniversalTime().ToString('o')
            requirementsHash = $requirementsHash
            requirements = $normalizedRequirements
            coverageMatrix = @()
            componentDeltaAnalysis = @()
            schemaPlan = [pscustomobject]@{ reuse = @(); extend = @(); build = @(); integrate = @(); verify = @() }
            dependencyManifest = [pscustomobject]@{ selectedModules = @(); transitiveModules = @(); moduleDependencies = @(); componentDependencies = @(); unresolvedDependencies = @(); duplicateEdgesRemoved = 0; cycles = @() }
            environmentReadiness = $environmentReference
            architectureOptions = @($customOptions.options | Where-Object optionId -eq 'fully-custom')
            recommendedOption = 'fully-custom'
            finalChoiceRequired = $true
            acceptanceTraceability = @()
            limitations = @('Provider evaluation is disabled. Existing wizard behavior remains custom-only.')
        }
    }

    $coverage = [Collections.Generic.List[object]]::new()
    foreach ($requirement in $normalizedRequirements) {
        $candidates = @(Get-AcceleratorCandidateMatches `
            -Requirement $requirement `
            -CatalogSnapshot $CatalogSnapshot `
            -PackageMetadata $PackageMetadata)
        $coverage.Add((New-AcceleratorRequirementDecision -Requirement $requirement -Candidates $candidates)) | Out-Null
    }
    $coverageMatrix = @($coverage.ToArray() | Sort-Object requirementId)
    $selectedModuleIds = @($coverageMatrix.candidateModuleId | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    } | Sort-Object -Unique)
    $dependencyManifest = New-AcceleratorDependencyManifest `
        -SelectedModuleIds $selectedModuleIds `
        -PackageMetadata $PackageMetadata
    foreach ($decision in $coverageMatrix) {
        $decision.dependencies = @(
            $dependencyManifest.moduleDependencies |
                Where-Object sourceModuleId -eq $decision.candidateModuleId
        )
    }
    $architecture = New-AcceleratorArchitectureOptions `
        -CoverageMatrix $coverageMatrix `
        -EnvironmentReference $environmentReference `
        -DependencyManifest $dependencyManifest
    $schemaPlan = [pscustomobject][ordered]@{
        reuse = @($coverageMatrix | Where-Object { $_.dispositions -contains 'REUSE' } | ForEach-Object { $_.proposedSchemaChanges })
        extend = @($coverageMatrix | Where-Object { $_.dispositions -contains 'EXTEND' } | ForEach-Object { $_.proposedSchemaChanges })
        build = @($coverageMatrix | Where-Object { $_.dispositions -contains 'BUILD' } | ForEach-Object { $_.proposedSchemaChanges })
        integrate = @($coverageMatrix | Where-Object { $_.dispositions -contains 'INTEGRATE' } | ForEach-Object { $_.integrations })
        verify = @($coverageMatrix | Where-Object { $_.dispositions -contains 'VERIFY' } | ForEach-Object {
            [pscustomobject]@{ requirementId = $_.requirementId; gaps = $_.gaps; questions = $_.unresolvedQuestions }
        })
    }
    $deltaAnalysis = @($coverageMatrix | ForEach-Object {
        [pscustomobject][ordered]@{
            requirementId = $_.requirementId
            dispositions = $_.dispositions
            candidateModuleId = $_.candidateModuleId
            existingComponents = @($_.candidates | Select-Object -First 1 | ForEach-Object componentEvidence)
            gaps = $_.gaps
            proposedSchemaChanges = $_.proposedSchemaChanges
            integrations = $_.integrations
            effortAssumptions = $_.effortAssumptions
            risks = $_.risks
        }
    })
    $traceability = @($coverageMatrix | ForEach-Object {
        [pscustomobject][ordered]@{
            requirementId = $_.requirementId
            acceptanceCriteria = $_.acceptanceCriteria
            dispositions = $_.dispositions
            evidenceReferences = @($_.candidates | ForEach-Object sourceReferences)
            taskReferences = $_.taskReferences
        }
    })
    $analysisBasis = [ordered]@{
        providerId = $ProviderId
        snapshotId = "$($CatalogSnapshot.snapshotId)"
        requirementsHash = $requirementsHash
        coverageMatrix = $coverageMatrix
        dependencyManifest = $dependencyManifest
        environmentFingerprint = "$($environmentReference.metadataFingerprint)"
    }
    return [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        analysisId = "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $analysisBasis))"
        providerId = $ProviderId
        snapshotId = "$($CatalogSnapshot.snapshotId)"
        scenarioSlug = $ScenarioSlug
        status = 'evaluated'
        sourceState = "$(Get-AcceleratorMatchingValue -InputObject $CatalogSnapshot -Name 'sourceState' -DefaultValue 'unavailable')"
        evaluatedAtUtc = $EvaluationTimeUtc.ToUniversalTime().ToString('o')
        requirementsHash = $requirementsHash
        requirements = $normalizedRequirements
        coverageMatrix = $coverageMatrix
        componentDeltaAnalysis = $deltaAnalysis
        schemaPlan = $schemaPlan
        dependencyManifest = $dependencyManifest
        environmentReadiness = $environmentReference
        architectureOptions = $architecture.options
        recommendedOption = $architecture.recommendedOption
        finalChoiceRequired = $true
        acceptanceTraceability = $traceability
        limitations = @(
            'Matching is explainable planning evidence, not deployment authorization.',
            'Documentation establishes functional claims; package metadata establishes physical components only.',
            'A table-name match alone never proves end-to-end business-process coverage.',
            'Environment evidence affects execution readiness, not architectural relevance.',
            'The user retains final architecture choice.'
        )
    }
}

function Write-AcceleratorRequirementsAnalysisArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Analysis,
        [Parameter(Mandatory)] [string]$OutputFolder
    )

    $resolvedFolder = [IO.Path]::GetFullPath($OutputFolder)
    New-Item -ItemType Directory -Path $resolvedFolder -Force | Out-Null
    $documents = [ordered]@{
        'accelerator-evaluation.json' = $Analysis
        'requirements-coverage-matrix.json' = @($Analysis.coverageMatrix)
        'component-delta-analysis.json' = @($Analysis.componentDeltaAnalysis)
        'schema-reuse-extension-plan.json' = $Analysis.schemaPlan
        'dependency-manifest.json' = $Analysis.dependencyManifest
        'environment-readiness-reference.json' = $Analysis.environmentReadiness
        'architecture-recommendation.json' = [pscustomobject]@{
            recommendedOption = $Analysis.recommendedOption
            finalChoiceRequired = $Analysis.finalChoiceRequired
            options = $Analysis.architectureOptions
        }
        'acceptance-traceability.json' = @($Analysis.acceptanceTraceability)
    }
    $manifestItems = [Collections.Generic.List[object]]::new()
    foreach ($entry in $documents.GetEnumerator()) {
        $path = Join-Path $resolvedFolder $entry.Key
        $json = $entry.Value | ConvertTo-Json -Depth 100
        Set-Content -LiteralPath $path -Value $json -Encoding utf8NoBOM
        $manifestItems.Add([pscustomobject]@{
            file = $entry.Key
            sha256 = Get-AcceleratorFileSha256 -Path $path
        }) | Out-Null
    }

    $matrixLines = [Collections.Generic.List[string]]::new()
    $matrixLines.Add('# Requirements to Accelerator Matrix') | Out-Null
    $matrixLines.Add('') | Out-Null
    $matrixLines.Add("| Requirement | Disposition | Candidate | Evidence | Gaps |") | Out-Null
    $matrixLines.Add('| --- | --- | --- | --- | --- |') | Out-Null
    foreach ($decision in @($Analysis.coverageMatrix)) {
        $description = "$($decision.description)".Replace('|', '\|')
        $gaps = (@($decision.gaps) -join '; ').Replace('|', '\|')
        $matrixLines.Add("| $($decision.requirementId): $description | $(@($decision.dispositions) -join ', ') | $($decision.candidateModuleId) | $($decision.evidenceLevel) | $gaps |") | Out-Null
    }
    $matrixPath = Join-Path $resolvedFolder 'requirements-to-accelerator-matrix.md'
    Set-Content -LiteralPath $matrixPath -Value $matrixLines.ToArray() -Encoding utf8NoBOM
    $manifestItems.Add([pscustomobject]@{
        file = 'requirements-to-accelerator-matrix.md'
        sha256 = Get-AcceleratorFileSha256 -Path $matrixPath
    }) | Out-Null

    $adrLines = @(
        '# ADR: Accelerator Architecture Selection',
        '',
        '**Status:** Proposed - explicit user decision required',
        "**Analysis ID:** ``$($Analysis.analysisId)``",
        "**Catalog snapshot:** ``$($Analysis.snapshotId)``",
        '',
        '## Recommendation',
        '',
        "Recommended planning option: **$($Analysis.recommendedOption)**.",
        '',
        'This recommendation does not authorize accelerator installation,',
        'Dataverse mutation, or FAST-dependent execution.',
        '',
        '## Options',
        ''
    )
    foreach ($option in @($Analysis.architectureOptions | Sort-Object rank)) {
        $adrLines += "### $($option.rank). $($option.optionId)"
        $adrLines += ''
        $adrLines += "- Status: $($option.status)"
        $adrLines += "- Architecture suitable: $($option.architectureSuitable)"
        $adrLines += "- Execution gate open: $($option.executionGateOpen)"
        $adrLines += "- Rationale: $($option.rationale)"
        $adrLines += ''
    }
    $adrLines += @(
        '## Decision gate',
        '',
        'The user must select an option before any later wizard integration may',
        'translate this planning evidence into executable work.'
    )
    $adrPath = Join-Path $resolvedFolder 'ADR-accelerator-selection.md'
    Set-Content -LiteralPath $adrPath -Value $adrLines -Encoding utf8NoBOM
    $manifestItems.Add([pscustomobject]@{
        file = 'ADR-accelerator-selection.md'
        sha256 = Get-AcceleratorFileSha256 -Path $adrPath
    }) | Out-Null

    $manifest = [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        analysisId = $Analysis.analysisId
        providerId = $Analysis.providerId
        snapshotId = $Analysis.snapshotId
        requirementsHash = $Analysis.requirementsHash
        artifacts = @($manifestItems.ToArray() | Sort-Object file)
    }
    $manifestPath = Join-Path $resolvedFolder 'accelerator-analysis-manifest.json'
    Set-Content -LiteralPath $manifestPath -Value ($manifest | ConvertTo-Json -Depth 20) -Encoding utf8NoBOM
    return [pscustomobject]@{
        OutputFolder = $resolvedFolder
        ManifestPath = $manifestPath
        Artifacts = @($manifest.artifacts.file) + @('accelerator-analysis-manifest.json')
    }
}
