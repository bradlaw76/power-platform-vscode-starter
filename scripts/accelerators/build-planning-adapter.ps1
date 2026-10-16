<#
=============================================================================
COMPONENT:    Provider-Neutral Accelerator Build Planning Adapter
FILE:         scripts/accelerators/build-planning-adapter.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-16
ENVIRONMENT:  PowerShell 7 | JSON | Spec Kit

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Translates an approved architecture decision and its evidence into a
deterministic, dry-run-only Dataverse implementation plan.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never calls Dataverse, PAC CLI, build stages, or solution import.
- Never recreates or directly modifies accelerator-managed components.
- Fully Custom plans have no accelerator package or environment dependency.
- Unsupported customization remains DEFER until verified.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$adapterRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'accelerator-catalog.ps1')

function Get-BuildPlanningValue {
    param(
        [AllowNull()] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name,
        [AllowNull()] [object]$DefaultValue = $null
    )

    if ($null -eq $InputObject) { return $DefaultValue }
    if ($InputObject -is [Collections.IDictionary] -and $InputObject.Contains($Name)) {
        return $InputObject[$Name]
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

function Get-BuildPlanningFileHash {
    param([Parameter(Mandatory)] [string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-BuildPlanningJson {
    param([Parameter(Mandatory)] [string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required build-planning input not found: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -DateKind String
}

function Get-BuildPlanningTerms {
    param([AllowEmptyString()] [string]$Value)

    $stopWords = @(
        'a', 'an', 'and', 'for', 'from', 'in', 'of', 'on', 'or', 'the', 'to',
        'with', 'create', 'manage', 'record', 'track'
    )
    return @(
        [regex]::Matches($Value.ToLowerInvariant(), '[a-z0-9]+') |
            ForEach-Object {
                $term = $_.Value
                if ($term.EndsWith('ies') -and $term.Length -gt 4) {
                    $term = "$($term.Substring(0, $term.Length - 3))y"
                } elseif ($term.EndsWith('s') -and -not $term.EndsWith('ss') -and $term.Length -gt 3) {
                    $term = $term.Substring(0, $term.Length - 1)
                }
                $term
            } |
            Where-Object { $_.Length -ge 2 -and $stopWords -notcontains $_ } |
            Sort-Object -Unique
    )
}

function Get-BuildPlanningDisplayKey {
    param([Parameter(Mandatory)] [string]$Value)
    return ([regex]::Replace($Value.ToLowerInvariant(), '[^a-z0-9]+', ''))
}

function Get-BuildPlanningMarkdownItems {
    param(
        [Parameter(Mandatory)] [string]$Markdown,
        [Parameter(Mandatory)] [string]$Heading
    )

    $escapedHeading = [regex]::Escape($Heading)
    $match = [regex]::Match(
        $Markdown,
        "(?ms)^###\s+$escapedHeading\s*\r?\n(?<body>.*?)(?=^###\s+|^##\s+|\z)"
    )
    if (-not $match.Success) { return @() }
    return @(
        $match.Groups['body'].Value -split '\r?\n' |
            ForEach-Object { ($_ -replace '^\s*-\s*', '').Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne 'None' }
    )
}

function Get-BuildPlanningMarkdownValue {
    param(
        [Parameter(Mandatory)] [string]$Markdown,
        [Parameter(Mandatory)] [string]$Label,
        [string]$DefaultValue = ''
    )

    $match = [regex]::Match($Markdown, "(?im)^\s*-\s*$([regex]::Escape($Label)):\s*(?<value>.+?)\s*$")
    if (-not $match.Success) { return $DefaultValue }
    return $match.Groups['value'].Value.Trim()
}

function Get-BuildPlanningMarkdownSectionValue {
    param(
        [Parameter(Mandatory)] [string]$Markdown,
        [Parameter(Mandatory)] [string]$Heading,
        [Parameter(Mandatory)] [string]$Label,
        [string]$DefaultValue = ''
    )

    $section = [regex]::Match(
        $Markdown,
        "(?ms)^##\s+$([regex]::Escape($Heading))\s*\r?\n(?<body>.*?)(?=^##\s+|\z)"
    )
    if (-not $section.Success) { return $DefaultValue }
    return Get-BuildPlanningMarkdownValue -Markdown $section.Groups['body'].Value -Label $Label -DefaultValue $DefaultValue
}

function ConvertTo-ScenarioComponentMappings {
    param(
        [Parameter(Mandatory)] [string]$SpecPath,
        [Parameter(Mandatory)] [string]$PublisherPrefix
    )

    if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) {
        throw "Scenario specification not found: $SpecPath"
    }
    $markdown = Get-Content -LiteralPath $SpecPath -Raw -Encoding UTF8
    $tables = @(
        Get-BuildPlanningMarkdownItems -Markdown $markdown -Heading 'Custom tables to create (input -> generated logical)' |
            ForEach-Object {
                if ($_ -notmatch '^(?<display>.+?)\s*->\s*(?<logical>[a-z0-9_]+)$') {
                    throw "Malformed custom table mapping in '$SpecPath': $_"
                }
                [pscustomobject][ordered]@{
                    displayName = $Matches.display.Trim()
                    logicalName = $Matches.logical.Trim()
                }
            }
    )
    $fields = @(
        Get-BuildPlanningMarkdownItems -Markdown $markdown -Heading 'Custom fields to add' |
            ForEach-Object {
                if ($_ -notmatch '^(?<table>[^.]+)\.(?<logical>[a-z0-9_]+)$') {
                    throw "Malformed custom field mapping in '$SpecPath': $_"
                }
                [pscustomobject][ordered]@{
                    tableDisplayName = $Matches.table.Trim()
                    logicalName = $Matches.logical.Trim()
                }
            }
    )
    $relationships = @(
        Get-BuildPlanningMarkdownItems -Markdown $markdown -Heading 'Relationships to create' |
            ForEach-Object {
                if ($_ -notmatch '^(?<child>.+?)\s*->\s*(?<parent>.+?)$') {
                    throw "Malformed relationship mapping in '$SpecPath': $_"
                }
                [pscustomobject][ordered]@{
                    childDisplayName = $Matches.child.Trim()
                    parentDisplayName = $Matches.parent.Trim()
                }
            }
    )
    $duplicateTables = @($tables | Group-Object logicalName | Where-Object Count -gt 1)
    if ($duplicateTables.Count -gt 0) {
        throw "Duplicate custom table logical name '$($duplicateTables[0].Name)'."
    }
    $duplicateRelationships = @(
        $relationships |
            Group-Object { "$($_.childDisplayName.ToLowerInvariant())|$($_.parentDisplayName.ToLowerInvariant())" } |
            Where-Object Count -gt 1
    )
    if ($duplicateRelationships.Count -gt 0) {
        throw "Duplicate relationship '$($duplicateRelationships[0].Name)'."
    }
    foreach ($table in $tables) {
        if (-not [string]::IsNullOrWhiteSpace($PublisherPrefix) -and
            -not $table.logicalName.StartsWith("$PublisherPrefix`_", [StringComparison]::OrdinalIgnoreCase)) {
            throw "Custom table '$($table.logicalName)' is not owned by publisher prefix '$PublisherPrefix'."
        }
    }
    foreach ($field in $fields) {
        if (-not [string]::IsNullOrWhiteSpace($PublisherPrefix) -and
            -not $field.logicalName.StartsWith("$PublisherPrefix`_", [StringComparison]::OrdinalIgnoreCase)) {
            throw "Custom field '$($field.logicalName)' is not owned by publisher prefix '$PublisherPrefix'."
        }
    }
    return [pscustomobject][ordered]@{
        publisherPrefix = $PublisherPrefix
        appName = Get-BuildPlanningMarkdownSectionValue -Markdown $markdown -Heading 'Solution and Publisher' -Label 'Solution' -DefaultValue 'Scenario model-driven application'
        bpfEnabled = (Get-BuildPlanningMarkdownSectionValue -Markdown $markdown -Heading 'Optional Business Process Flow' -Label 'Enabled' -DefaultValue 'no') -eq 'yes'
        tables = $tables
        fields = $fields
        relationships = $relationships
    }
}

function Assert-ApprovedArchitectureDecision {
    param(
        [Parameter(Mandatory)] [object]$Decision,
        [Parameter(Mandatory)] [object]$AnalysisManifest,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$PackageMetadata
    )

    if (-not [bool]$Decision.explicitApproval) {
        throw 'Architecture decision is not explicitly approved.'
    }
    if (@('fast-based', 'hybrid', 'fully-custom') -notcontains "$($Decision.selectedOption)") {
        throw "Unsupported approved architecture '$($Decision.selectedOption)'."
    }
    if ("$($Decision.analysisId)" -cne "$($AnalysisManifest.analysisId)" -or
        "$($Decision.catalogSnapshotId)" -cne "$($AnalysisManifest.snapshotId)") {
        throw 'Architecture decision does not match the approved analysis manifest.'
    }
    $basis = [ordered]@{
        scenarioSlug = "$($Decision.scenarioSlug)"
        mode = "$($Decision.wizardMode)"
        evaluationStatus = "$($Decision.evaluationStatus)"
        analysisId = "$($Decision.analysisId)"
        snapshotId = "$($Decision.catalogSnapshotId)"
        recommendedOption = "$($Decision.recommendedOption)"
        selectedOption = "$($Decision.selectedOption)"
        selectedPackages = @($Decision.selectedPackages)
        rationale = "$($Decision.rationale)"
    }
    $expectedDecisionId = "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $basis))"
    if ("$($Decision.decisionId)" -cne $expectedDecisionId) {
        throw 'Architecture decision ID does not match its canonical approved content.'
    }
    if ("$($Decision.selectedOption)" -eq 'fully-custom') {
        if (@($Decision.selectedPackages).Count -ne 0) {
            throw 'Fully Custom decisions must not contain accelerator packages.'
        }
        return
    }
    if ($PackageMetadata.Count -eq 0) {
        throw 'FAST-based and Hybrid decisions require verified package metadata.'
    }
    foreach ($selectedPackage in @($Decision.selectedPackages)) {
        $match = @($PackageMetadata | Where-Object {
            "$($_.moduleId)" -ceq "$($selectedPackage.moduleId)" -and
            "$($_.packageId)" -ceq "$($selectedPackage.packageId)"
        })
        if ($match.Count -ne 1 -or
            "$($match[0].solution.version)" -cne "$($selectedPackage.version)" -or
            "$($match[0].sha256)" -cne "$($selectedPackage.sha256)") {
            throw "Selected package identity, version, or SHA-256 mismatch for '$($selectedPackage.moduleId)'."
        }
    }
}

function New-BuildPlanningTask {
    param(
        [Parameter(Mandatory)] [string]$Action,
        [Parameter(Mandatory)] [string]$ComponentKind,
        [Parameter(Mandatory)] [string]$ComponentIdentity,
        [string]$DisplayName = '',
        [Parameter(Mandatory)] [string]$Ownership,
        [bool]$Managed = $false,
        [bool]$DirectModificationAllowed = $false,
        [string]$Status = 'planned',
        [string[]]$RequirementIds = @(),
        [string[]]$Dependencies = @(),
        [string[]]$SourceReferences = @(),
        [string[]]$ExpectedOutputs = @(),
        [string[]]$AcceptanceChecks = @(),
        [Parameter(Mandatory)] [string]$Reason
    )

    $basis = "$Action|$ComponentKind|$ComponentIdentity|$DisplayName|$Reason|$(@($RequirementIds | Sort-Object -Unique) -join ',')"
    return [pscustomobject][ordered]@{
        taskId = "FAST006-$Action-$((Get-AcceleratorStringSha256 -Value $basis).Substring(0, 12).ToUpperInvariant())"
        action = $Action
        componentKind = $ComponentKind
        componentIdentity = $ComponentIdentity
        displayName = $DisplayName
        ownership = $Ownership
        managed = $Managed
        directModificationAllowed = $DirectModificationAllowed
        status = $Status
        requirementIds = @($RequirementIds | Where-Object { $_ } | Sort-Object -Unique)
        dependencies = @($Dependencies | Where-Object { $_ } | Sort-Object -Unique)
        sourceReferences = @($SourceReferences | Where-Object { $_ } | Sort-Object -Unique)
        expectedOutputs = @($ExpectedOutputs)
        acceptanceChecks = @($AcceptanceChecks)
        reason = $Reason
    }
}

function Get-PackageTableIndex {
    param([object[]]$PackageMetadata = @())

    return @(
        foreach ($package in $PackageMetadata) {
            foreach ($table in @(Get-BuildPlanningValue -InputObject $package -Name 'tables' -DefaultValue @())) {
                [pscustomobject][ordered]@{
                    moduleId = "$($package.moduleId)"
                    packageId = "$($package.packageId)"
                    publisherPrefix = "$(Get-BuildPlanningValue -InputObject $package.publisher -Name 'customizationPrefix' -DefaultValue '')"
                    managed = [bool]$package.solution.managed
                    logicalName = "$($table.logicalName)"
                    displayName = "$($table.displayName)"
                    terms = @(Get-BuildPlanningTerms -Value "$($table.displayName)")
                }
            }
        }
    )
}

function Find-PackageTableMatch {
    param(
        [Parameter(Mandatory)] [object]$CustomTable,
        [object[]]$PackageTables = @()
    )

    $terms = @(Get-BuildPlanningTerms -Value "$($CustomTable.displayName)")
    if ($terms.Count -eq 0) { return $null }
    $ranked = @(
        foreach ($packageTable in $PackageTables) {
            $matched = @($terms | Where-Object { $packageTable.terms -contains $_ })
            $allTermsMatch = $matched.Count -eq $terms.Count
            if ($allTermsMatch -or $matched.Count -ge 2) {
                [pscustomobject]@{
                    table = $packageTable
                    matchedCount = $matched.Count
                    exactDisplay = "$($packageTable.displayName)" -ieq "$($CustomTable.displayName)"
                    extraTermCount = [Math]::Max(0, @($packageTable.terms).Count - $matched.Count)
                    score = $(if ("$($packageTable.displayName)" -ieq "$($CustomTable.displayName)") { 1000 } else { 0 }) +
                        ($matched.Count * 100) -
                        ([Math]::Max(0, @($packageTable.terms).Count - $matched.Count) * 10)
                }
            }
        }
    )
    if ($ranked.Count -eq 0) { return $null }
    return @(
        $ranked |
            Sort-Object @{ Expression = 'score'; Descending = $true }, @{ Expression = { $_.table.logicalName } }
    )[0].table
}

function Get-TopologicalBuildOrder {
    param([Parameter(Mandatory)] [object[]]$Tasks)

    $taskById = @{}
    foreach ($task in $Tasks) { $taskById[$task.taskId] = $task }
    $remaining = [Collections.Generic.List[string]]::new()
    foreach ($task in $Tasks) { $remaining.Add("$($task.taskId)") | Out-Null }
    $ordered = [Collections.Generic.List[string]]::new()
    while ($remaining.Count -gt 0) {
        $ready = @(
            $remaining |
                Where-Object {
                    $task = $taskById[$_]
                    @($task.dependencies | Where-Object { $ordered -notcontains $_ }).Count -eq 0
                } |
                Sort-Object
        )
        if ($ready.Count -eq 0) {
            throw 'Build-plan task dependency graph contains a cycle or missing task dependency.'
        }
        foreach ($taskId in $ready) {
            $ordered.Add($taskId) | Out-Null
            $remaining.Remove($taskId) | Out-Null
        }
    }
    return @($ordered)
}

function New-ProviderNeutralBuildPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Decision,
        [Parameter(Mandatory)] [object]$AnalysisManifest,
        [Parameter(Mandatory)] [object[]]$CoverageMatrix,
        [Parameter(Mandatory)] [object[]]$ComponentDelta,
        [Parameter(Mandatory)] [object]$SchemaPlan,
        [Parameter(Mandatory)] [object]$DependencyManifest,
        [Parameter(Mandatory)] [object]$EnvironmentReadiness,
        [Parameter(Mandatory)] [object[]]$AcceptanceTraceability,
        [Parameter(Mandatory)] [object]$ScenarioMappings,
        [AllowEmptyCollection()] [object[]]$PackageMetadata = @(),
        [string]$ExpectedEnvironmentUrl = '',
        [hashtable]$InputFingerprints = @{}
    )

    Assert-ApprovedArchitectureDecision `
        -Decision $Decision `
        -AnalysisManifest $AnalysisManifest `
        -PackageMetadata $PackageMetadata

    if (@($CoverageMatrix).Count -eq 0 -or @($AcceptanceTraceability).Count -eq 0) {
        throw 'Coverage and acceptance traceability inputs must not be empty.'
    }
    $coverageIds = @($CoverageMatrix | ForEach-Object { "$($_.requirementId)" } | Sort-Object -Unique)
    $traceabilityIds = @($AcceptanceTraceability | ForEach-Object { "$($_.requirementId)" } | Sort-Object -Unique)
    if (($coverageIds -join '|') -cne ($traceabilityIds -join '|')) {
        throw 'Coverage and acceptance traceability requirement IDs are inconsistent.'
    }
    $deltaIds = @($ComponentDelta | ForEach-Object { "$($_.requirementId)" } | Sort-Object -Unique)
    if (($coverageIds -join '|') -cne ($deltaIds -join '|')) {
        throw 'Coverage and component delta requirement IDs are inconsistent.'
    }
    foreach ($requiredSchemaDisposition in @('reuse', 'extend', 'build', 'integrate', 'verify')) {
        if ($null -eq $SchemaPlan.PSObject.Properties[$requiredSchemaDisposition]) {
            throw "Schema reuse and extension plan is missing '$requiredSchemaDisposition'."
        }
    }

    $architecture = "$($Decision.selectedOption)"
    $acceleratorDependent = $architecture -ne 'fully-custom'
    $providerId = if ($acceleratorDependent) { "$($AnalysisManifest.providerId)" } else { '' }
    $environmentLimitations = if ($acceleratorDependent) {
        @($EnvironmentReadiness.limitations | ForEach-Object { "$_" })
    } else {
        @()
    }
    if ($acceleratorDependent -and -not [string]::IsNullOrWhiteSpace($ExpectedEnvironmentUrl) -and
        "$($EnvironmentReadiness.environmentUrl)".TrimEnd('/') -cne $ExpectedEnvironmentUrl.TrimEnd('/')) {
        $environmentLimitations += "Environment identity mismatch: approved evidence is for '$($EnvironmentReadiness.environmentUrl)', requested target is '$ExpectedEnvironmentUrl'."
    }
    $environmentGateOpen = $acceleratorDependent -and
        [bool]$EnvironmentReadiness.fresh -and
        [bool]$EnvironmentReadiness.snapshotMatch -and
        [bool]$EnvironmentReadiness.packageMatch -and
        [bool]$EnvironmentReadiness.executionGateOpen -and
        $environmentLimitations.Count -eq 0

    $tasks = [Collections.Generic.List[object]]::new()
    $packageTables = if ($acceleratorDependent) {
        @(Get-PackageTableIndex -PackageMetadata $PackageMetadata)
    } else {
        @()
    }
    $selectedModuleIds = @($Decision.selectedPackages | ForEach-Object { "$($_.moduleId)" })
    $moduleTaskIds = @{}
    if ($acceleratorDependent) {
        foreach ($moduleId in @($DependencyManifest.transitiveModules | Sort-Object -Unique)) {
            if ($selectedModuleIds -notcontains $moduleId) {
                throw "Dependency module '$moduleId' is not pinned by the approved decision."
            }
            $selectedPackage = @($Decision.selectedPackages | Where-Object moduleId -eq $moduleId)[0]
            $moduleDependencies = @(
                $DependencyManifest.moduleDependencies |
                    Where-Object sourceModuleId -eq $moduleId |
                    ForEach-Object { "$($_.targetModuleId)" }
            )
            $task = New-BuildPlanningTask `
                -Action REUSE `
                -ComponentKind module `
                -ComponentIdentity $moduleId `
                -DisplayName $moduleId `
                -Ownership accelerator-managed `
                -Managed $true `
                -Status $(if ($environmentGateOpen) { 'planned' } else { 'blocked' }) `
                -Dependencies @() `
                -SourceReferences @("$($selectedPackage.packageId)", "sha256:$($selectedPackage.sha256)") `
                -ExpectedOutputs @('Use the installed, version-matched managed solution without recreating it.') `
                -AcceptanceChecks @('Installed solution identity, version, hash provenance, and dependencies match the approved decision.') `
                -Reason 'Approved architecture pins this accelerator module; direct managed-layer modification is prohibited.'
            $tasks.Add($task) | Out-Null
            $moduleTaskIds[$moduleId] = $task.taskId
            $task | Add-Member -NotePropertyName pendingModuleDependencies -NotePropertyValue $moduleDependencies
        }
        foreach ($task in @($tasks | Where-Object { $_.componentKind -eq 'module' })) {
            $task.dependencies = @(
                $task.pendingModuleDependencies |
                    ForEach-Object { $moduleTaskIds[$_] } |
                    Where-Object { $_ }
            )
            $task.PSObject.Properties.Remove('pendingModuleDependencies')
        }
    }

    $tableTaskByDisplay = @{}
    $tableIdentityByDisplay = @{}
    $tableOwnershipByDisplay = @{}
    $claimedPackageTables = @{}
    $orderedCustomTables = @(
        $ScenarioMappings.tables |
            Sort-Object @{ Expression = { @(Get-BuildPlanningTerms -Value "$($_.displayName)").Count }; Descending = $true }, logicalName
    )
    foreach ($customTable in $orderedCustomTables) {
        $customTableTerms = @(Get-BuildPlanningTerms -Value "$($customTable.displayName)")
        $relatedCoverage = @(
            $CoverageMatrix |
                Where-Object {
                    $requirementTerms = @(Get-BuildPlanningTerms -Value "$($_.description)")
                    @($requirementTerms | Where-Object { $customTableTerms -contains $_ }).Count -gt 0
                }
        )
        $evidencedModuleIds = @(
            $relatedCoverage |
                ForEach-Object { "$($_.candidateModuleId)" } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Sort-Object -Unique
        )
        $packageMatch = if ($acceleratorDependent) {
            Find-PackageTableMatch `
                -CustomTable $customTable `
                -PackageTables @(
                    $packageTables |
                        Where-Object {
                            $evidencedModuleIds -contains $_.moduleId -and
                            -not $claimedPackageTables.ContainsKey("$($_.logicalName)")
                        }
                )
        } else {
            $null
        }
        if ($null -ne $packageMatch) {
            $claimedPackageTables["$($packageMatch.logicalName)"] = "$($customTable.logicalName)"
            $requirementIds = @(
                $CoverageMatrix |
                    Where-Object {
                        $requirementTerms = @(Get-BuildPlanningTerms -Value "$($_.description)")
                        @($requirementTerms | Where-Object { $packageMatch.terms -contains $_ }).Count -gt 0
                    } |
                    ForEach-Object { "$($_.requirementId)" }
            )
            $task = New-BuildPlanningTask `
                -Action REUSE `
                -ComponentKind table `
                -ComponentIdentity "$($packageMatch.logicalName)" `
                -DisplayName "$($packageMatch.displayName)" `
                -Ownership accelerator-managed `
                -Managed $true `
                -Status $(if ($environmentGateOpen) { 'planned' } else { 'blocked' }) `
                -RequirementIds $requirementIds `
                -Dependencies @($moduleTaskIds[$packageMatch.moduleId]) `
                -SourceReferences @("$($packageMatch.packageId)") `
                -ExpectedOutputs @('Reference the existing managed table; emit no table-creation payload for this identity.') `
                -AcceptanceChecks @('No solution-owned table duplicates the managed component.', 'Managed table identity is environment-verified before execution.') `
                -Reason "The approved package supplies a compatible table; planned '$($customTable.logicalName)' creation is suppressed."
            $tasks.Add($task) | Out-Null
            $displayKey = Get-BuildPlanningDisplayKey -Value "$($customTable.displayName)"
            $tableTaskByDisplay[$displayKey] = $task.taskId
            $tableIdentityByDisplay[$displayKey] = "$($packageMatch.logicalName)"
            $tableOwnershipByDisplay[$displayKey] = 'accelerator-managed'
        } else {
            if (@($packageTables | ForEach-Object { "$($_.logicalName)" }) -contains "$($customTable.logicalName)") {
                throw "Custom table '$($customTable.logicalName)' conflicts with an accelerator-managed table identity."
            }
            $requirementIds = @(
                $CoverageMatrix |
                    Where-Object {
                        $requirementTerms = @(Get-BuildPlanningTerms -Value "$($_.description)")
                        $tableTerms = @(Get-BuildPlanningTerms -Value "$($customTable.displayName)")
                        @($requirementTerms | Where-Object { $tableTerms -contains $_ }).Count -gt 0
                    } |
                    ForEach-Object { "$($_.requirementId)" }
            )
            $task = New-BuildPlanningTask `
                -Action CREATE `
                -ComponentKind table `
                -ComponentIdentity "$($customTable.logicalName)" `
                -DisplayName "$($customTable.displayName)" `
                -Ownership solution-owned `
                -RequirementIds $requirementIds `
                -ExpectedOutputs @("Create solution-owned Dataverse table '$($customTable.logicalName)' in a future separately authorized build.") `
                -AcceptanceChecks @('Logical name uses the approved publisher prefix.', 'No managed or solution-owned table identity conflict exists.') `
                -Reason 'Approved scenario mapping requires a new solution-owned table not supplied by selected accelerator evidence.'
            $tasks.Add($task) | Out-Null
            $displayKey = Get-BuildPlanningDisplayKey -Value "$($customTable.displayName)"
            $tableTaskByDisplay[$displayKey] = $task.taskId
            $tableIdentityByDisplay[$displayKey] = "$($customTable.logicalName)"
            $tableOwnershipByDisplay[$displayKey] = 'solution-owned'
        }
    }

    foreach ($field in @($ScenarioMappings.fields | Sort-Object tableDisplayName, logicalName)) {
        $key = Get-BuildPlanningDisplayKey -Value "$($field.tableDisplayName)"
        if (-not $tableTaskByDisplay.ContainsKey($key)) {
            throw "Custom field '$($field.logicalName)' references unknown table '$($field.tableDisplayName)'."
        }
        $managedTarget = $tableOwnershipByDisplay[$key] -eq 'accelerator-managed'
        $action = if ($managedTarget) { 'DEFER' } else { 'CREATE' }
        $status = if ($managedTarget) { 'verification-required' } else { 'planned' }
        $task = New-BuildPlanningTask `
            -Action $action `
            -ComponentKind column `
            -ComponentIdentity "$($tableIdentityByDisplay[$key]).$($field.logicalName)" `
            -DisplayName "$($field.logicalName)" `
            -Ownership solution-owned `
            -Status $status `
            -Dependencies @($tableTaskByDisplay[$key]) `
            -ExpectedOutputs @("Define solution-owned column '$($field.logicalName)' only after data type and target customization support are approved.") `
            -AcceptanceChecks @('Column type, requiredness, ownership, and target-table customization support are explicitly validated.') `
            -Reason $(if ($managedTarget) {
                'The target table is accelerator-managed and package metadata does not prove supported customization; direct modification is deferred.'
            } else {
                'The approved scenario mapping requires a solution-owned column on a solution-owned table.'
            })
        $tasks.Add($task) | Out-Null
    }

    foreach ($relationship in @($ScenarioMappings.relationships | Sort-Object childDisplayName, parentDisplayName)) {
        $childKey = Get-BuildPlanningDisplayKey -Value "$($relationship.childDisplayName)"
        $parentKey = Get-BuildPlanningDisplayKey -Value "$($relationship.parentDisplayName)"
        if (-not $tableTaskByDisplay.ContainsKey($childKey) -or -not $tableTaskByDisplay.ContainsKey($parentKey)) {
            throw "Relationship '$($relationship.childDisplayName) -> $($relationship.parentDisplayName)' references an unknown table."
        }
        $managedEndpoint = $tableOwnershipByDisplay[$childKey] -eq 'accelerator-managed' -or
            $tableOwnershipByDisplay[$parentKey] -eq 'accelerator-managed'
        $identity = "$($tableIdentityByDisplay[$childKey])->$($tableIdentityByDisplay[$parentKey])"
        $task = New-BuildPlanningTask `
            -Action $(if ($managedEndpoint) { 'DEFER' } else { 'CREATE' }) `
            -ComponentKind relationship `
            -ComponentIdentity $identity `
            -DisplayName "$($relationship.childDisplayName) -> $($relationship.parentDisplayName)" `
            -Ownership solution-owned `
            -Status $(if ($managedEndpoint) { 'verification-required' } else { 'planned' }) `
            -Dependencies @($tableTaskByDisplay[$childKey], $tableTaskByDisplay[$parentKey]) `
            -ExpectedOutputs @('Create a solution-owned relationship only after cardinality, requiredness, cascade behavior, and ownership are approved.') `
            -AcceptanceChecks @('Relationship identity is unique.', 'Managed endpoint customization support is verified when applicable.') `
            -Reason $(if ($managedEndpoint) {
                'At least one endpoint is accelerator-managed; relationship creation is deferred until customization support is environment-verified.'
            } else {
                'Both relationship endpoints are solution-owned and the mapping is explicit.'
            })
        $tasks.Add($task) | Out-Null
    }

    foreach ($tableDisplay in @($tableTaskByDisplay.Keys | Sort-Object)) {
        $managedTarget = $tableOwnershipByDisplay[$tableDisplay] -eq 'accelerator-managed'
        foreach ($kind in @('form', 'view')) {
            $task = New-BuildPlanningTask `
                -Action $(if ($managedTarget) { 'DEFER' } else { 'CREATE' }) `
                -ComponentKind $kind `
                -ComponentIdentity "$($tableIdentityByDisplay[$tableDisplay]):starter-$kind" `
                -DisplayName "$tableDisplay starter $kind" `
                -Ownership solution-owned `
                -Status $(if ($managedTarget) { 'verification-required' } else { 'planned' }) `
                -Dependencies @($tableTaskByDisplay[$tableDisplay]) `
                -ExpectedOutputs @("Plan a solution-owned $kind without overwriting an accelerator-managed definition.") `
                -AcceptanceChecks @("Target table and $kind ownership are verified.") `
                -Reason $(if ($managedTarget) {
                    "Package metadata does not prove that a solution-owned $kind can safely extend this managed table."
                } else {
                    "A starter $kind is required for the solution-owned table."
                })
            $tasks.Add($task) | Out-Null
        }
    }

    $applicationTask = New-BuildPlanningTask `
        -Action CREATE `
        -ComponentKind application `
        -ComponentIdentity "$($Decision.scenarioSlug):model-driven-app" `
        -DisplayName "$($ScenarioMappings.appName)" `
        -Ownership solution-owned `
        -Dependencies @($tableTaskByDisplay.Values) `
        -ExpectedOutputs @('Create or update the scenario-owned review application without modifying an accelerator-managed app.') `
        -AcceptanceChecks @('Navigation references only validated tables and views.', 'Managed application definitions remain unchanged.') `
        -Reason 'The repository contract requires a scenario-owned model-driven review application.'
    $tasks.Add($applicationTask) | Out-Null

    if ([bool]$ScenarioMappings.bpfEnabled) {
        $bpfTask = New-BuildPlanningTask `
            -Action CREATE `
            -ComponentKind business-process-flow `
            -ComponentIdentity "$($Decision.scenarioSlug):business-process-flow" `
            -DisplayName 'Scenario business process flow' `
            -Ownership solution-owned `
            -Dependencies @($tableTaskByDisplay.Values) `
            -ExpectedOutputs @('Produce a designer handoff for a solution-owned business process flow.') `
            -AcceptanceChecks @('Stages and participating tables are explicitly approved before future activation.') `
            -Reason 'The scenario specification explicitly enables a business process flow.'
        $tasks.Add($bpfTask) | Out-Null
    }

    foreach ($coverage in @($CoverageMatrix | Sort-Object requirementId)) {
        $requirementId = "$($coverage.requirementId)"
        $sourceReferences = @(
            $coverage.candidates |
                ForEach-Object { $_.sourceReferences } |
                ForEach-Object { "$($_.sourceUrl)#$($_.contentHash)" }
        )
        if ($acceleratorDependent -and @($coverage.dispositions) -contains 'EXTEND') {
            $task = New-BuildPlanningTask `
                -Action DEFER `
                -ComponentKind dependency `
                -ComponentIdentity "$($coverage.candidateModuleId):extension:$requirementId" `
                -DisplayName "$($coverage.description)" `
                -Ownership unresolved `
                -Status verification-required `
                -RequirementIds @($requirementId) `
                -Dependencies @($moduleTaskIds["$($coverage.candidateModuleId)"]) `
                -SourceReferences $sourceReferences `
                -ExpectedOutputs @('Use only a separately owned extension after target component customizability is environment-verified.') `
                -AcceptanceChecks @('No managed-layer definition is overwritten.', 'Customization support is proven from fresh target-environment metadata.') `
                -Reason 'Functional fit is partial and package presence does not prove that direct customization is supported.'
            $tasks.Add($task) | Out-Null
        }
        if (@($coverage.dispositions) -contains 'INTEGRATE') {
            $task = New-BuildPlanningTask `
                -Action INTEGRATE `
                -ComponentKind integration `
                -ComponentIdentity "$($Decision.scenarioSlug):integration:$requirementId" `
                -DisplayName "$($coverage.description)" `
                -Ownership external `
                -RequirementIds @($requirementId) `
                -ExpectedOutputs @('Produce a connector/automation design covering authentication, error handling, observability, and data ownership.') `
                -AcceptanceChecks @($coverage.acceptanceCriteria) `
                -Reason 'The approved requirement disposition includes integration work; no connector or endpoint is inferred.'
            $tasks.Add($task) | Out-Null
        }
        if ("$($coverage.description)" -match '(?i)\breport(?:ing|s)?\b') {
            $task = New-BuildPlanningTask `
                -Action CREATE `
                -ComponentKind report `
                -ComponentIdentity "$($Decision.scenarioSlug):report:$requirementId" `
                -DisplayName "$($coverage.description)" `
                -Ownership solution-owned `
                -RequirementIds @($requirementId) `
                -Dependencies @($applicationTask.taskId) `
                -ExpectedOutputs @('Create a scenario-owned reporting design only after fields, placement, and ownership are approved.') `
                -AcceptanceChecks @($coverage.acceptanceCriteria) `
                -Reason 'The normalized requirement explicitly requests reporting.'
            $tasks.Add($task) | Out-Null
        }
        if ("$($coverage.description)" -match '(?i)\bapproval\b|\bworkflow\b|\bautomation\b') {
            $task = New-BuildPlanningTask `
                -Action CREATE `
                -ComponentKind automation `
                -ComponentIdentity "$($Decision.scenarioSlug):automation:$requirementId" `
                -DisplayName "$($coverage.description)" `
                -Ownership solution-owned `
                -RequirementIds @($requirementId) `
                -ExpectedOutputs @('Create a solution-owned automation design; runtime implementation requires a separate approval.') `
                -AcceptanceChecks @($coverage.acceptanceCriteria) `
                -Reason 'The normalized requirement explicitly requests approval, workflow, or automation behavior.'
            $tasks.Add($task) | Out-Null
        }
        if (@($coverage.dispositions) -contains 'VERIFY') {
            $task = New-BuildPlanningTask `
                -Action DEFER `
                -ComponentKind dependency `
                -ComponentIdentity "$($Decision.scenarioSlug):verification:$requirementId" `
                -DisplayName "$($coverage.description)" `
                -Ownership unresolved `
                -Status verification-required `
                -RequirementIds @($requirementId) `
                -SourceReferences $sourceReferences `
                -ExpectedOutputs @('Resolve evidence gaps before creating an executable component plan.') `
                -AcceptanceChecks @($coverage.acceptanceCriteria) `
                -Reason 'The approved requirement disposition requires additional verification.'
            $tasks.Add($task) | Out-Null
        }
    }

    $deduplicatedTasks = @(
        $tasks |
            Group-Object taskId |
            ForEach-Object {
                if ($_.Count -gt 1) {
                    $canonicalTasks = @(
                        $_.Group |
                            ForEach-Object { ConvertTo-AcceleratorCanonicalJson -InputObject $_ } |
                            Sort-Object -Unique
                    )
                    if ($canonicalTasks.Count -ne 1) {
                        throw "Conflicting deterministic build task ID '$($_.Name)'."
                    }
                }
                $_.Group[0]
            } |
            Sort-Object taskId
    )
    $orderedTaskIds = @(Get-TopologicalBuildOrder -Tasks $deduplicatedTasks)
    $edges = @(
        foreach ($task in $deduplicatedTasks) {
            foreach ($dependency in @($task.dependencies)) {
                [pscustomobject][ordered]@{
                    from = $dependency
                    to = "$($task.taskId)"
                    reason = 'Prerequisite component or module'
                }
            }
        }
    )

    $blockedActions = [Collections.Generic.List[string]]::new()
    $remediation = [Collections.Generic.List[string]]::new()
    $authorization = [Collections.Generic.List[string]]::new()
    $authorization.Add('FAST-006 produces dry-run plans only; a later phase must explicitly authorize build-stage integration.') | Out-Null
    $authorization.Add('Revalidate the approved decision and all input fingerprints immediately before any future execution.') | Out-Null
    if ($acceleratorDependent -and -not $environmentGateOpen) {
        $blockedActions.Add('All FAST-dependent reuse and extension execution is blocked.') | Out-Null
        foreach ($limitation in $environmentLimitations) {
            $remediation.Add("$limitation") | Out-Null
        }
        $remediation.Add('Run a separately authorized fresh read-only environment preflight after required managed solutions and dependencies are available.') | Out-Null
        $remediation.Add('Verify required customization permissions without modifying managed-layer definitions.') | Out-Null
    }
    foreach ($task in @($deduplicatedTasks | Where-Object status -eq 'verification-required')) {
        $blockedActions.Add("$($task.taskId): $($task.reason)") | Out-Null
    }
    $rollback = @(
        'Disable accelerator build planning without changing the approved architecture artifacts.',
        'Restore a prior scenario-local build-plan directory; build plans are content-addressed and contain no environment mutation.',
        'Roll back code through the FAST feature branch or the pre-FAST recovery references.',
        'Dataverse recovery is not required because FAST-006 performs no Dataverse operation.'
    )
    $traceability = @(
        foreach ($trace in @($AcceptanceTraceability | Sort-Object requirementId)) {
            $requirementId = "$($trace.requirementId)"
            [pscustomobject][ordered]@{
                requirementId = $requirementId
                taskIds = @(
                    $deduplicatedTasks |
                        Where-Object { @($_.requirementIds) -contains $requirementId } |
                        ForEach-Object { "$($_.taskId)" } |
                        Sort-Object -Unique
                )
                acceptanceCriteria = @($trace.acceptanceCriteria | ForEach-Object { "$_" })
                decisionId = "$($Decision.decisionId)"
            }
        }
    )

    $environment = [pscustomobject][ordered]@{
        requiredForArchitecture = $acceleratorDependent
        environmentUrl = if ($acceleratorDependent) { "$($EnvironmentReadiness.environmentUrl)" } else { '' }
        metadataFingerprint = if ($acceleratorDependent) { "$($EnvironmentReadiness.metadataFingerprint)" } else { '' }
        gateOpen = $environmentGateOpen
        status = if ($acceleratorDependent) { "$($EnvironmentReadiness.status)" } else { 'not-required' }
        fresh = if ($acceleratorDependent) { [bool]$EnvironmentReadiness.fresh } else { $false }
        snapshotMatch = if ($acceleratorDependent) { [bool]$EnvironmentReadiness.snapshotMatch } else { $false }
        packageMatch = if ($acceleratorDependent) { [bool]$EnvironmentReadiness.packageMatch } else { $false }
        limitations = @($environmentLimitations | Sort-Object -Unique)
    }
    $orderedInputFingerprints = [ordered]@{}
    foreach ($fingerprintName in @($InputFingerprints.Keys | Sort-Object)) {
        $orderedInputFingerprints[$fingerprintName] = "$($InputFingerprints[$fingerprintName])"
    }
    $planBasis = [ordered]@{
        scenarioSlug = "$($Decision.scenarioSlug)"
        decisionId = "$($Decision.decisionId)"
        architecture = $architecture
        inputFingerprints = $orderedInputFingerprints
        environment = $environment
        componentPlans = $deduplicatedTasks
        dependencyGraph = [ordered]@{
            nodes = @($deduplicatedTasks.taskId | Sort-Object -Unique)
            edges = $edges
            orderedTaskIds = $orderedTaskIds
        }
        blockedActions = @($blockedActions | Sort-Object -Unique)
        remediationChecklist = @($remediation | Sort-Object -Unique)
        authorizationRequirements = @($authorization)
        rollbackRecovery = $rollback
        traceability = $traceability
    }
    $planId = "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $planBasis))"
    return [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        planId = $planId
        scenarioSlug = "$($Decision.scenarioSlug)"
        decisionId = "$($Decision.decisionId)"
        architecture = $architecture
        providerId = $providerId
        dryRun = $true
        executionAuthorized = $false
        status = if ($acceleratorDependent -and -not $environmentGateOpen) { 'blocked' } else { 'dry-run-ready' }
        generatedAtUtc = "$($Decision.recordedAtUtc)"
        inputFingerprints = [pscustomobject]$orderedInputFingerprints
        environment = $environment
        managedSolutionPolicy = [pscustomobject][ordered]@{
            directManagedModificationAllowed = $false
            recreateManagedComponentsAllowed = $false
            extensionRequiresCustomizationEvidence = $true
            solutionOwnedPrefix = "$($ScenarioMappings.publisherPrefix)"
        }
        componentPlans = $deduplicatedTasks
        dependencyGraph = $planBasis.dependencyGraph
        blockedActions = $planBasis.blockedActions
        remediationChecklist = $planBasis.remediationChecklist
        authorizationRequirements = $planBasis.authorizationRequirements
        rollbackRecovery = $rollback
        traceability = $traceability
    }
}

function Write-ProviderNeutralBuildPlanArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Plan,
        [Parameter(Mandatory)] [string]$OutputFolder,
        [switch]$ApproveDecisionChange
    )

    $schemaPath = Join-Path $adapterRoot 'schemas\accelerators\build-plan.schema.json'
    $projectionSchemaPath = Join-Path $adapterRoot 'schemas\accelerators\build-plan-projection.schema.json'
    if (-not (Test-Json -Json ($Plan | ConvertTo-Json -Depth 100) -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw 'Provider-neutral build plan failed schema validation.'
    }
    $manifestPath = Join-Path $OutputFolder 'build-plan-manifest.json'
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        $existing = Read-BuildPlanningJson -Path $manifestPath
        if ("$($existing.decisionId)" -cne "$($Plan.decisionId)" -and -not $ApproveDecisionChange) {
            throw 'Approved architecture decision changed. Rerun with -ApproveBuildPlanDecisionChange only after explicit review.'
        }
    }
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    Set-Content -LiteralPath $manifestPath -Value ($Plan | ConvertTo-Json -Depth 100) -Encoding utf8NoBOM

    $projectionDefinitions = @(
        [pscustomobject]@{ File = 'component-reuse-extension-manifest.json'; Type = 'component-reuse-extension'; Items = @($Plan.componentPlans | Where-Object action -in @('REUSE', 'EXTEND', 'DEFER')) }
        [pscustomobject]@{ File = 'new-component-plan.json'; Type = 'new-component-creation'; Items = @($Plan.componentPlans | Where-Object action -eq 'CREATE') }
        [pscustomobject]@{ File = 'integration-automation-plan.json'; Type = 'integration-automation'; Items = @($Plan.componentPlans | Where-Object componentKind -in @('integration', 'automation')) }
        [pscustomobject]@{ File = 'ordered-dependency-graph.json'; Type = 'ordered-dependency-graph'; Items = @($Plan.dependencyGraph) }
        [pscustomobject]@{ File = 'readiness-authorization-assessment.json'; Type = 'readiness-authorization'; Items = @($Plan.environment, [pscustomobject]@{ requirements = $Plan.authorizationRequirements; executionAuthorized = $false }) }
        [pscustomobject]@{ File = 'blocked-actions-remediation.json'; Type = 'blocked-actions-remediation'; Items = @([pscustomobject]@{ blockedActions = $Plan.blockedActions; remediationChecklist = $Plan.remediationChecklist }) }
        [pscustomobject]@{ File = 'rollback-recovery-plan.json'; Type = 'rollback-recovery'; Items = @($Plan.rollbackRecovery) }
        [pscustomobject]@{ File = 'requirement-build-traceability.json'; Type = 'requirement-build-traceability'; Items = @($Plan.traceability) }
    )
    $written = [Collections.Generic.List[string]]::new()
    $written.Add($manifestPath) | Out-Null
    foreach ($definition in $projectionDefinitions) {
        $projection = [pscustomobject][ordered]@{
            schemaVersion = '1.0'
            artifactType = $definition.Type
            planId = "$($Plan.planId)"
            scenarioSlug = "$($Plan.scenarioSlug)"
            decisionId = "$($Plan.decisionId)"
            architecture = "$($Plan.architecture)"
            dryRun = $true
            items = @($definition.Items)
        }
        if (-not (Test-Json -Json ($projection | ConvertTo-Json -Depth 100) -SchemaFile $projectionSchemaPath -ErrorAction Stop)) {
            throw "Build-plan projection '$($definition.Type)' failed schema validation."
        }
        $path = Join-Path $OutputFolder $definition.File
        Set-Content -LiteralPath $path -Value ($projection | ConvertTo-Json -Depth 100) -Encoding utf8NoBOM
        $written.Add($path) | Out-Null
    }
    return [pscustomobject]@{
        OutputFolder = $OutputFolder
        ManifestPath = $manifestPath
        Artifacts = @($written)
    }
}
