<#
=============================================================================
COMPONENT:    Accelerator Environment Compatibility
FILE:         scripts/accelerators/environment-compatibility.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Mockable read-only environment evidence

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Implements catalog-only compatibility and mockable read-only environment
preflight contracts. It defines, but does not execute, installation verification.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            FAST-dependent build gate evidence
- Inputs:          selected packages, catalog snapshot, environment evidence
- Outputs:         ready/action-required/incompatible/unverified result
- Dependencies:    no live Dataverse dependency in FAST-002
- Side Effects:    none

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Catalog validation reports declared dependencies without environment access.
✔ Mocked preflight distinguishes ready, missing, incompatible, and stale.
✔ The build gate permits custom-only and blocks unverified FAST execution.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never claim import success from static metadata.
- Never mutate an environment in FAST-002.
- Require explicit authorization before any future installation operation.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-AcceleratorValidationCheck {
    param(
        [Parameter(Mandatory)] [string]$Code,
        [Parameter(Mandatory)] [string]$Status,
        [Parameter(Mandatory)] [string]$Message,
        [object]$Evidence = $null
    )

    return [pscustomobject][ordered]@{
        code = $Code
        status = $Status
        message = $Message
        evidence = $Evidence
    }
}

function Resolve-AcceleratorValidationStatus {
    param([object[]]$Checks)

    if (@($Checks | Where-Object status -eq 'incompatible').Count -gt 0) {
        return 'incompatible'
    }
    if (@($Checks | Where-Object status -eq 'action-required').Count -gt 0) {
        return 'action-required'
    }
    if (@($Checks | Where-Object status -eq 'unverified').Count -gt 0) {
        return 'unverified'
    }
    return 'ready'
}

function Get-FastDependencyKey {
    param([Parameter(Mandatory)] [object]$Dependency)

    return @(
        "$($Dependency.required.type)",
        "$($Dependency.required.id)",
        "$($Dependency.required.solution)",
        "$($Dependency.required.package)",
        "$($Dependency.required.schemaName)",
        "$($Dependency.required.uniqueName)",
        "$($Dependency.required.parentDisplayName)",
        "$($Dependency.required.displayName)"
    ) -join '|'
}

function Get-FastValidationPropertyValue {
    param(
        [AllowNull()] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name,
        [AllowNull()] [object]$DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }
    return $property.Value
}

function New-AcceleratorEnvironmentValidationResult {
    param(
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [string]$Level,
        [Parameter(Mandatory)] [string]$CatalogSnapshotId,
        [Parameter(Mandatory)] [object[]]$SelectedPackages,
        [Parameter(Mandatory)] [object[]]$Checks,
        [object]$Environment = $null,
        [object[]]$InstalledModules = @(),
        [object[]]$DependencyAssessment = @(),
        [object[]]$MissingComponents = @(),
        [object[]]$IncompatibleComponents = @(),
        [object]$Evidence = $null,
        [string[]]$Limitations = @(),
        [object]$Authorization = $null,
        [string]$RecommendedNextAction = '',
        [datetime]$ValidatedAtUtc = [DateTime]::UtcNow,
        [timespan]$TimeToLive = ([TimeSpan]::FromHours(24))
    )

    $status = Resolve-AcceleratorValidationStatus -Checks $Checks
    if ([string]::IsNullOrWhiteSpace($RecommendedNextAction)) {
        $RecommendedNextAction = switch ($status) {
            'ready' { 'Proceed only through the separately authorized FAST-dependent build gate.' }
            'action-required' { 'Resolve the reported missing modules or dependencies, then run a fresh read-only preflight.' }
            'incompatible' { 'Resolve version, publisher, or component conflicts before selecting FAST-dependent generation.' }
            default { 'Obtain fresh, sufficient read-only environment evidence before FAST-dependent generation.' }
        }
    }
    $requiredModules = @($SelectedPackages | ForEach-Object {
        [pscustomobject]@{
            packageId = "$($_.packageId)"
            moduleId = "$($_.moduleId)"
            solutionUniqueName = "$($_.solution.uniqueName)"
            version = "$($_.solution.version)"
            sha256 = "$($_.sha256)"
        }
    })
    return [pscustomobject][ordered]@{
        schemaVersion = '1.1'
        providerId = 'microsoft-fast'
        scenarioSlug = $ScenarioSlug
        level = $Level
        status = $status
        readinessStatus = $status
        validatedAtUtc = $ValidatedAtUtc.ToUniversalTime().ToString('o')
        expiresAtUtc = $ValidatedAtUtc.ToUniversalTime().Add($TimeToLive).ToString('o')
        catalogSnapshotId = $CatalogSnapshotId
        environment = $Environment
        requiredModules = $requiredModules
        selectedPackages = $requiredModules
        installedModules = @($InstalledModules)
        dependencyAssessment = @($DependencyAssessment)
        missingComponents = @($MissingComponents)
        incompatibleComponents = @($IncompatibleComponents)
        checks = @($Checks)
        evidence = $Evidence
        limitations = @($Limitations)
        recommendedNextAction = $RecommendedNextAction
        authorization = $Authorization
    }
}

function Test-FastCatalogCompatibility {
    param(
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [string]$CatalogSnapshotId,
        [Parameter(Mandatory)] [object[]]$SelectedPackages
    )

    $checks = [Collections.Generic.List[object]]::new()
    if ($SelectedPackages.Count -eq 0) {
        $checks.Add((New-AcceleratorValidationCheck -Code 'packages.none' -Status 'incompatible' -Message 'FAST selection has no package-verified module.')) | Out-Null
    }

    foreach ($package in @($SelectedPackages)) {
        if ("$($package.evidenceType)" -cne 'package-verified') {
            $checks.Add((New-AcceleratorValidationCheck -Code 'package.unverified' -Status 'incompatible' -Message "Package '$($package.packageId)' is not package-verified." -Evidence $package.packageId)) | Out-Null
            continue
        }
        if ("$($package.sha256)" -notmatch '^[a-f0-9]{64}$') {
            $checks.Add((New-AcceleratorValidationCheck -Code 'package.digest.invalid' -Status 'incompatible' -Message "Package '$($package.packageId)' has no valid SHA-256." -Evidence $package.sha256)) | Out-Null
        } else {
            $checks.Add((New-AcceleratorValidationCheck -Code 'package.digest.valid' -Status 'ready' -Message "Package '$($package.packageId)' has a validated SHA-256." -Evidence $package.sha256)) | Out-Null
        }
        if ([string]::IsNullOrWhiteSpace("$($package.solution.version)")) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'package.version.missing' -Status 'incompatible' -Message "Package '$($package.packageId)' has no solution version.")) | Out-Null
        }
        foreach ($dependency in @($package.declaredDependencies)) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'dependency.environment-resolution-required' -Status 'action-required' -Message "Declared dependency '$($dependency.required.displayName)' requires environment resolution." -Evidence $dependency)) | Out-Null
        }
    }

    $corePackages = @($SelectedPackages | Where-Object {
        "$($_.moduleId)" -eq 'microsoft-fast:module:core'
    })
    $specialtyPackages = @($SelectedPackages | Where-Object {
        "$($_.moduleId)" -ne 'microsoft-fast:module:core'
    })
    if ($specialtyPackages.Count -gt 0 -and $corePackages.Count -eq 0) {
        $checks.Add((New-AcceleratorValidationCheck -Code 'dependency.core.missing' -Status 'incompatible' -Message 'A specialty FAST module was selected without a package-verified Core package.')) | Out-Null
    }

    return New-AcceleratorEnvironmentValidationResult `
        -ScenarioSlug $ScenarioSlug `
        -Level 'catalog-compatibility' `
        -CatalogSnapshotId $CatalogSnapshotId `
        -SelectedPackages $SelectedPackages `
        -Checks $checks.ToArray() `
        -Limitations @(
            'Catalog compatibility does not access Dataverse.',
            'A ready catalog result does not prove that an import will succeed.'
        )
}

function Get-FastEnvironmentEvidence {
    param(
        [Parameter(Mandatory)] [scriptblock]$EnvironmentInspector,
        [Parameter(Mandatory)] [string]$EnvironmentUrl
    )

    $evidence = & $EnvironmentInspector $EnvironmentUrl
    if ($null -eq $evidence) {
        throw 'Environment inspector returned no evidence.'
    }
    return $evidence
}

function Test-FastEnvironmentPreflight {
    param(
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [string]$CatalogSnapshotId,
        [Parameter(Mandatory)] [object[]]$SelectedPackages,
        [Parameter(Mandatory)] [object]$EnvironmentEvidence,
        [timespan]$EvidenceTimeToLive = ([TimeSpan]::FromHours(24)),
        [datetime]$NowUtc = [DateTime]::UtcNow
    )

    $checks = [Collections.Generic.List[object]]::new()
    $accessStateProperty = $EnvironmentEvidence.PSObject.Properties['accessState']
    $accessState = if ($null -eq $accessStateProperty) { 'connected' } else { "$($accessStateProperty.Value)" }
    $environmentId = "$(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'environmentId' -DefaultValue '')"
    $environmentUrl = "$(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'environmentUrl' -DefaultValue '')"
    $tenantId = "$(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'tenantId' -DefaultValue '')"
    $organizationVersion = "$(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'organizationVersion' -DefaultValue '')"
    $metadataFingerprint = "$(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'metadataFingerprint' -DefaultValue '')"
    $inspectionErrors = @(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'inspectionErrors' -DefaultValue @())
    $cacheEvidence = Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'cache'
    if ($accessState -ne 'connected') {
        $message = switch ($accessState) {
            'offline' { 'Read-only environment validation could not run because the environment was offline.' }
            'user-declined' { 'The user declined read-only environment validation.' }
            'authentication-failed' { 'Dataverse authentication failed; no environment compatibility claim can be made.' }
            'insufficient-permissions' { 'The caller lacks sufficient read permissions for environment compatibility verification.' }
            default { 'The selected Dataverse environment could not be inspected.' }
        }
        $checks.Add((New-AcceleratorValidationCheck -Code "environment.$accessState" -Status 'unverified' -Message $message)) | Out-Null
        return New-AcceleratorEnvironmentValidationResult `
            -ScenarioSlug $ScenarioSlug `
            -Level 'environment-preflight' `
            -CatalogSnapshotId $CatalogSnapshotId `
            -SelectedPackages $SelectedPackages `
            -Checks $checks.ToArray() `
            -Environment ([pscustomobject]@{
                environmentId = $environmentId
                environmentUrl = $environmentUrl
                tenantId = $tenantId
                organizationVersion = $organizationVersion
            }) `
            -Evidence ([pscustomobject]@{
                accessState = $accessState
                metadataFingerprint = $metadataFingerprint
                inspectionErrors = $inspectionErrors
                cache = $cacheEvidence
            }) `
            -Limitations @(
                'No environment compatibility claim can be made without current read-only evidence.',
                'Requirements analysis may continue, but FAST-dependent build execution remains blocked.'
            ) `
            -ValidatedAtUtc $NowUtc `
            -TimeToLive $EvidenceTimeToLive
    }

    if (-not [bool]$EnvironmentEvidence.connected) {
        $checks.Add((New-AcceleratorValidationCheck -Code 'environment.connection' -Status 'unverified' -Message 'The selected environment connection was not verified.')) | Out-Null
    } else {
        $checks.Add((New-AcceleratorValidationCheck -Code 'environment.connection' -Status 'ready' -Message 'The selected environment connection was verified.' -Evidence $EnvironmentEvidence.environmentUrl)) | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace("$($EnvironmentEvidence.environmentId)") -or
        [string]::IsNullOrWhiteSpace("$($EnvironmentEvidence.environmentUrl)")) {
        $checks.Add((New-AcceleratorValidationCheck -Code 'environment.identity' -Status 'unverified' -Message 'Environment identity evidence is incomplete.')) | Out-Null
    } else {
        $checks.Add((New-AcceleratorValidationCheck -Code 'environment.identity' -Status 'ready' -Message 'Environment identity is present.' -Evidence @{
            environmentId = "$($EnvironmentEvidence.environmentId)"
            environmentUrl = "$($EnvironmentEvidence.environmentUrl)"
        })) | Out-Null
    }

    try {
        $collectedAt = [DateTimeOffset]::Parse(
            "$($EnvironmentEvidence.collectedAtUtc)",
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind
        )
    } catch {
        $collectedAt = $null
    }
    if ($null -eq $collectedAt) {
        $checks.Add((New-AcceleratorValidationCheck -Code 'evidence.timestamp' -Status 'unverified' -Message 'Environment evidence has no valid collection timestamp.')) | Out-Null
    } elseif ($collectedAt.UtcDateTime.Add($EvidenceTimeToLive) -lt $NowUtc.ToUniversalTime()) {
        $checks.Add((New-AcceleratorValidationCheck -Code 'evidence.stale' -Status 'unverified' -Message 'Environment validation evidence is stale.' -Evidence $EnvironmentEvidence.collectedAtUtc)) | Out-Null
    } else {
        $checks.Add((New-AcceleratorValidationCheck -Code 'evidence.fresh' -Status 'ready' -Message 'Environment validation evidence is within its validity window.' -Evidence $EnvironmentEvidence.collectedAtUtc)) | Out-Null
    }

    $installedSolutions = @(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'installedSolutions' -DefaultValue @())
    $permissions = @(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'permissions' -DefaultValue @() | ForEach-Object { "$_".ToLowerInvariant() })
    $canReadSolutions = $permissions -contains 'read-solutions'
    $installedByName = @{}
    foreach ($solution in $installedSolutions) {
        $installedByName["$($solution.uniqueName)"] = $solution
    }
    $missingComponents = [Collections.Generic.List[object]]::new()
    $incompatibleComponents = [Collections.Generic.List[object]]::new()
    foreach ($package in @($SelectedPackages)) {
        $expectedName = "$($package.solution.uniqueName)"
        $installed = @($installedSolutions | Where-Object {
            [string]::Equals("$($_.uniqueName)", $expectedName, [StringComparison]::OrdinalIgnoreCase)
        })
        if (-not $canReadSolutions) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.unverified' -Status 'unverified' -Message "Installed solution '$expectedName' could not be verified because solution-read evidence is unavailable.")) | Out-Null
            continue
        }
        if ($installed.Count -eq 0) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.missing' -Status 'action-required' -Message "Required solution '$expectedName' is not installed." -Evidence @{
                expectedVersion = "$($package.solution.version)"
            })) | Out-Null
            $missingComponents.Add([pscustomobject]@{
                kind = 'solution'
                identity = $expectedName
                expectedVersion = "$($package.solution.version)"
                moduleId = "$($package.moduleId)"
            }) | Out-Null
            continue
        }
        if ($installed.Count -gt 1) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.ambiguous' -Status 'incompatible' -Message "Multiple installed solutions match '$expectedName'.")) | Out-Null
            continue
        }

        $installedVersion = [version]"$($installed[0].version)"
        $requiredVersion = [version]"$($package.solution.version)"
        if ($installedVersion -ne $requiredVersion) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.version.incompatible' -Status 'incompatible' -Message "Installed '$expectedName' version '$installedVersion' does not exactly match selected package '$requiredVersion'.")) | Out-Null
            $incompatibleComponents.Add([pscustomobject]@{
                kind = 'solution-version'
                identity = $expectedName
                expectedVersion = "$requiredVersion"
                installedVersion = "$installedVersion"
                moduleId = "$($package.moduleId)"
            }) | Out-Null
        } else {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.version.ready' -Status 'ready' -Message "Installed '$expectedName' version '$installedVersion' exactly matches the selected package.")) | Out-Null
        }

        $publisherUniqueName = "$(Get-FastValidationPropertyValue -InputObject $installed[0] -Name 'publisherUniqueName' -DefaultValue '')"
        $publisherPrefix = "$(Get-FastValidationPropertyValue -InputObject $installed[0] -Name 'publisherPrefix' -DefaultValue '')"
        if ([string]::IsNullOrWhiteSpace($publisherUniqueName) -or [string]::IsNullOrWhiteSpace($publisherPrefix)) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.publisher.unverified' -Status 'unverified' -Message "Publisher evidence for '$expectedName' is incomplete.")) | Out-Null
        } elseif (-not [string]::Equals($publisherUniqueName, "$($package.publisher.uniqueName)", [StringComparison]::OrdinalIgnoreCase) -or
            -not [string]::Equals($publisherPrefix, "$($package.publisher.customizationPrefix)", [StringComparison]::OrdinalIgnoreCase)) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.publisher.incompatible' -Status 'incompatible' -Message "Installed '$expectedName' publisher identity does not match the selected package.")) | Out-Null
            $incompatibleComponents.Add([pscustomobject]@{
                kind = 'publisher'
                identity = $expectedName
                expected = "$($package.publisher.uniqueName)|$($package.publisher.customizationPrefix)"
                installed = "$publisherUniqueName|$publisherPrefix"
                moduleId = "$($package.moduleId)"
            }) | Out-Null
        }
    }

    $dependencyAssessments = @(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'dependencyAssessments' -DefaultValue @())
    $dependencyByPackageKey = @{}
    foreach ($assessment in $dependencyAssessments) {
        $assessmentKey = "$($assessment.packageId)|$($assessment.key)".ToLowerInvariant()
        $dependencyByPackageKey[$assessmentKey] = $assessment
    }
    $satisfiedDependencyKeys = @(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'satisfiedDependencyKeys' -DefaultValue @() | ForEach-Object { "$_".ToLowerInvariant() })
    foreach ($package in @($SelectedPackages)) {
        foreach ($dependency in @($package.declaredDependencies)) {
            $key = Get-FastDependencyKey -Dependency $dependency
            $normalizedKey = $key.ToLowerInvariant()
            $packageDependencyKey = "$($package.packageId)|$key".ToLowerInvariant()
            $assessment = if ($dependencyByPackageKey.ContainsKey($packageDependencyKey)) {
                $dependencyByPackageKey[$packageDependencyKey]
            } else {
                $null
            }
            $dependencyStatus = if ($null -ne $assessment) {
                "$($assessment.status)"
            } elseif ($satisfiedDependencyKeys -contains $normalizedKey) {
                'satisfied'
            } else {
                'missing'
            }
            if ($dependencyStatus -eq 'satisfied') {
                $checks.Add((New-AcceleratorValidationCheck -Code 'dependency.satisfied' -Status 'ready' -Message "Dependency '$($dependency.required.displayName)' is satisfied." -Evidence $key)) | Out-Null
            } elseif ($dependencyStatus -eq 'incompatible') {
                $checks.Add((New-AcceleratorValidationCheck -Code 'dependency.incompatible' -Status 'incompatible' -Message "Dependency '$($dependency.required.displayName)' resolved ambiguously or incompatibly." -Evidence $key)) | Out-Null
                $incompatibleComponents.Add([pscustomobject]@{
                    kind = 'dependency'
                    identity = $key
                    moduleId = "$($package.moduleId)"
                }) | Out-Null
            } elseif ($dependencyStatus -eq 'unverified') {
                $checks.Add((New-AcceleratorValidationCheck -Code 'dependency.unverified' -Status 'unverified' -Message "Dependency '$($dependency.required.displayName)' could not be verified with current permissions or supported metadata." -Evidence $key)) | Out-Null
            } else {
                $checks.Add((New-AcceleratorValidationCheck -Code 'dependency.missing' -Status 'action-required' -Message "Dependency '$($dependency.required.displayName)' is not verified in the environment." -Evidence $key)) | Out-Null
                $missingComponents.Add([pscustomobject]@{
                    kind = 'dependency'
                    identity = $key
                    moduleId = "$($package.moduleId)"
                }) | Out-Null
            }
        }
    }

    foreach ($requiredPermission in @('read-solutions', 'read-metadata')) {
        if ($permissions -notcontains $requiredPermission) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'permission.missing' -Status 'unverified' -Message "Permission evidence '$requiredPermission' is missing.")) | Out-Null
        }
    }

    foreach ($package in @($SelectedPackages)) {
        if (-not $installedByName.ContainsKey("$($package.solution.uniqueName)")) {
            continue
        }
        $packageTables = @(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'requiredTables' -DefaultValue @() | Where-Object {
            "$($_.moduleId)" -eq "$($package.moduleId)"
        })
        foreach ($table in $packageTables) {
            if ("$($table.verificationState)" -ne 'verified') {
                $checks.Add((New-AcceleratorValidationCheck -Code 'table.unverified' -Status 'unverified' -Message "Required table '$($table.logicalName)' could not be verified.")) | Out-Null
            } elseif (-not [bool]$table.found) {
                $checks.Add((New-AcceleratorValidationCheck -Code 'table.missing' -Status 'incompatible' -Message "Installed solution '$($package.solution.uniqueName)' is missing required table '$($table.logicalName)'.")) | Out-Null
                $incompatibleComponents.Add([pscustomobject]@{
                    kind = 'table'
                    identity = "$($table.logicalName)"
                    moduleId = "$($package.moduleId)"
                }) | Out-Null
            }
        }
    }

    foreach ($limitation in @(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'permissionLimitations' -DefaultValue @())) {
        $checks.Add((New-AcceleratorValidationCheck -Code 'permission.limitation' -Status 'unverified' -Message "$limitation")) | Out-Null
    }

    $corePackage = @($SelectedPackages | Where-Object moduleId -eq 'microsoft-fast:module:core' | Select-Object -First 1)
    $coreAssessment = 'not-selected'
    if ($corePackage.Count -gt 0) {
        $core = $corePackage[0]
        $coreName = "$($core.solution.uniqueName)"
        $coreInstalled = $installedByName.ContainsKey($coreName)
        $coreDependencyEvidence = @($dependencyAssessments | Where-Object packageId -eq "$($core.packageId)")
        $coreTableEvidence = @(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'requiredTables' -DefaultValue @() | Where-Object {
            "$($_.moduleId)" -eq "$($core.moduleId)"
        })
        $coreBlockingEvidence = @($coreDependencyEvidence | Where-Object status -ne 'satisfied')
        $coreBlockingEvidence += @($coreTableEvidence | Where-Object {
            "$($_.verificationState)" -ne 'verified' -or -not [bool]$_.found
        })
        if ($coreInstalled) {
            $installedCore = $installedByName[$coreName]
            if ("$($installedCore.version)" -ne "$($core.solution.version)" -or
                -not [string]::Equals("$($installedCore.publisherUniqueName)", "$($core.publisher.uniqueName)", [StringComparison]::OrdinalIgnoreCase) -or
                -not [string]::Equals("$($installedCore.publisherPrefix)", "$($core.publisher.customizationPrefix)", [StringComparison]::OrdinalIgnoreCase)) {
                $coreBlockingEvidence += $installedCore
            }
        }
        if (-not $canReadSolutions) {
            $coreAssessment = 'inaccessible-or-insufficiently-verified'
        } elseif ($coreInstalled -and $coreBlockingEvidence.Count -eq 0) {
            $coreAssessment = 'installed-and-verified'
        } elseif ($coreInstalled) {
            $coreAssessment = 'installed-incompatible-or-incomplete'
        } elseif (@($coreDependencyEvidence | Where-Object status -in @('missing', 'incompatible')).Count -gt 0) {
            $coreAssessment = 'missing-with-known-blockers'
        } elseif (@($coreDependencyEvidence | Where-Object status -eq 'unverified').Count -gt 0) {
            $coreAssessment = 'inaccessible-or-insufficiently-verified'
        } else {
            $coreAssessment = 'missing-prerequisites-potentially-available'
        }
    }

    return New-AcceleratorEnvironmentValidationResult `
        -ScenarioSlug $ScenarioSlug `
        -Level 'environment-preflight' `
        -CatalogSnapshotId $CatalogSnapshotId `
        -SelectedPackages $SelectedPackages `
        -Checks $checks.ToArray() `
        -Environment ([pscustomobject]@{
            environmentId = $environmentId
            environmentUrl = $environmentUrl
            tenantId = $tenantId
            organizationVersion = $organizationVersion
        }) `
        -InstalledModules @(Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'installedFastModules' -DefaultValue @()) `
        -DependencyAssessment $dependencyAssessments `
        -MissingComponents $missingComponents.ToArray() `
        -IncompatibleComponents $incompatibleComponents.ToArray() `
        -Evidence ([pscustomobject]@{
            evidenceType = 'environment-verified'
            accessState = $accessState
            coreAssessment = $coreAssessment
            metadataFingerprint = $metadataFingerprint
            requestCount = Get-FastValidationPropertyValue -InputObject $EnvironmentEvidence -Name 'requestCount' -DefaultValue 0
            permissions = $permissions
            inspectionErrors = $inspectionErrors
            cache = $cacheEvidence
        }) `
        -Limitations @(
            'Preflight is read-only and does not prove that a future import will succeed.',
            'Runtime plugins, capacity, policies, and transient service conditions may require separate checks.'
        ) `
        -ValidatedAtUtc $NowUtc `
        -TimeToLive $EvidenceTimeToLive
}

function New-FastInstallationVerificationPlan {
    param(
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [string]$CatalogSnapshotId,
        [Parameter(Mandatory)] [object[]]$SelectedPackages,
        [Parameter(Mandatory)] [string]$EnvironmentId,
        [bool]$Authorized = $false
    )

    return [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        providerId = 'microsoft-fast'
        scenarioSlug = $ScenarioSlug
        level = 'installation-verification'
        status = 'unverified'
        catalogSnapshotId = $CatalogSnapshotId
        environmentId = $EnvironmentId
        authorized = $Authorized
        executionImplemented = $false
        orderedOperations = @(
            'Confirm explicit environment modification authorization.',
            'Verify Core package and environment prerequisites.',
            'Import Core into an approved development or sandbox environment.',
            'Verify Core import outcome, installed version, dependencies, and components.',
            'Import each approved specialty module in dependency order.',
            'Verify each import outcome and post-import components.',
            'Persist installation verification evidence before FAST-dependent generation.'
        )
        selectedPackages = @($SelectedPackages | ForEach-Object { "$($_.packageId)" })
        limitations = @(
            'FAST-002 defines this workflow but does not implement package import.',
            'Authorization must be obtained separately for every environment modification.'
        )
    }
}

function Test-FastDependentBuildGate {
    param(
        [ValidateSet('fully-custom', 'fast-foundation', 'hybrid')]
        [Parameter(Mandatory)] [string]$Architecture,
        [object]$ValidationEvidence,
        [Parameter(Mandatory)] [string]$CurrentCatalogSnapshotId,
        [Parameter(Mandatory)] [string]$CurrentEnvironmentId,
        [object[]]$SelectedPackages = @(),
        [datetime]$NowUtc = [DateTime]::UtcNow
    )

    if ($Architecture -eq 'fully-custom') {
        return [pscustomobject]@{
            Allowed = $true
            Reason = 'Fully custom architecture does not require FAST environment evidence.'
        }
    }
    if ($null -eq $ValidationEvidence) {
        return [pscustomobject]@{
            Allowed = $false
            Reason = 'FAST-dependent execution requires environment validation evidence.'
        }
    }
    if ("$($ValidationEvidence.level)" -notin @('environment-preflight', 'installation-verification') -or
        "$($ValidationEvidence.status)" -ne 'ready') {
        return [pscustomobject]@{
            Allowed = $false
            Reason = 'FAST-dependent execution requires ready environment or installation verification.'
        }
    }
    if ("$($ValidationEvidence.catalogSnapshotId)" -cne $CurrentCatalogSnapshotId) {
        return [pscustomobject]@{
            Allowed = $false
            Reason = 'Catalog snapshot changed; revalidation is required.'
        }
    }
    if ("$($ValidationEvidence.environment.environmentId)" -cne $CurrentEnvironmentId) {
        return [pscustomobject]@{
            Allowed = $false
            Reason = 'Selected environment changed; revalidation is required.'
        }
    }
    try {
        $expiresAt = [DateTimeOffset]::Parse(
            "$($ValidationEvidence.expiresAtUtc)",
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind
        )
    } catch {
        $expiresAt = $null
    }
    if ($null -eq $expiresAt -or $expiresAt.UtcDateTime -lt $NowUtc.ToUniversalTime()) {
        return [pscustomobject]@{
            Allowed = $false
            Reason = 'Environment validation evidence is stale.'
        }
    }

    $validatedPackages = @($ValidationEvidence.selectedPackages | ForEach-Object {
        "$($_.packageId)|$($_.sha256)"
    } | Sort-Object)
    $currentPackages = @($SelectedPackages | ForEach-Object {
        "$($_.packageId)|$($_.sha256)"
    } | Sort-Object)
    if (Compare-Object $validatedPackages $currentPackages) {
        return [pscustomobject]@{
            Allowed = $false
            Reason = 'Selected package evidence changed; revalidation is required.'
        }
    }

    return [pscustomobject]@{
        Allowed = $true
        Reason = 'FAST foundation and selected package evidence are verified for the selected environment.'
    }
}
