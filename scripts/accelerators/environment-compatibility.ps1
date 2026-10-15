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

function New-AcceleratorEnvironmentValidationResult {
    param(
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [string]$Level,
        [Parameter(Mandatory)] [string]$CatalogSnapshotId,
        [Parameter(Mandatory)] [object[]]$SelectedPackages,
        [Parameter(Mandatory)] [object[]]$Checks,
        [object]$Environment = $null,
        [string[]]$Limitations = @(),
        [object]$Authorization = $null,
        [datetime]$ValidatedAtUtc = [DateTime]::UtcNow,
        [timespan]$TimeToLive = ([TimeSpan]::FromHours(24))
    )

    $status = Resolve-AcceleratorValidationStatus -Checks $Checks
    return [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        providerId = 'microsoft-fast'
        scenarioSlug = $ScenarioSlug
        level = $Level
        status = $status
        validatedAtUtc = $ValidatedAtUtc.ToUniversalTime().ToString('o')
        expiresAtUtc = $ValidatedAtUtc.ToUniversalTime().Add($TimeToLive).ToString('o')
        catalogSnapshotId = $CatalogSnapshotId
        environment = $Environment
        selectedPackages = @($SelectedPackages | ForEach-Object {
            [pscustomobject]@{
                packageId = "$($_.packageId)"
                moduleId = "$($_.moduleId)"
                solutionUniqueName = "$($_.solution.uniqueName)"
                version = "$($_.solution.version)"
                sha256 = "$($_.sha256)"
            }
        })
        checks = @($Checks)
        limitations = @($Limitations)
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
    if ($accessState -in @('offline', 'user-declined')) {
        $message = if ($accessState -eq 'offline') {
            'Read-only environment validation could not run because the environment was offline.'
        } else {
            'The user declined read-only environment validation.'
        }
        $checks.Add((New-AcceleratorValidationCheck -Code "environment.$accessState" -Status 'unverified' -Message $message)) | Out-Null
        return New-AcceleratorEnvironmentValidationResult `
            -ScenarioSlug $ScenarioSlug `
            -Level 'environment-preflight' `
            -CatalogSnapshotId $CatalogSnapshotId `
            -SelectedPackages $SelectedPackages `
            -Checks $checks.ToArray() `
            -Environment $null `
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

    $collectedAt = [DateTime]::MinValue
    if (-not [DateTime]::TryParse("$($EnvironmentEvidence.collectedAtUtc)", [ref]$collectedAt)) {
        $checks.Add((New-AcceleratorValidationCheck -Code 'evidence.timestamp' -Status 'unverified' -Message 'Environment evidence has no valid collection timestamp.')) | Out-Null
    } elseif ($collectedAt.ToUniversalTime().Add($EvidenceTimeToLive) -lt $NowUtc.ToUniversalTime()) {
        $checks.Add((New-AcceleratorValidationCheck -Code 'evidence.stale' -Status 'unverified' -Message 'Environment validation evidence is stale.' -Evidence $EnvironmentEvidence.collectedAtUtc)) | Out-Null
    } else {
        $checks.Add((New-AcceleratorValidationCheck -Code 'evidence.fresh' -Status 'ready' -Message 'Environment validation evidence is within its validity window.' -Evidence $EnvironmentEvidence.collectedAtUtc)) | Out-Null
    }

    $installedSolutions = @($EnvironmentEvidence.installedSolutions)
    foreach ($package in @($SelectedPackages)) {
        $expectedName = "$($package.solution.uniqueName)"
        $installed = @($installedSolutions | Where-Object {
            [string]::Equals("$($_.uniqueName)", $expectedName, [StringComparison]::OrdinalIgnoreCase)
        })
        if ($installed.Count -eq 0) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.missing' -Status 'action-required' -Message "Required solution '$expectedName' is not installed." -Evidence @{
                expectedVersion = "$($package.solution.version)"
            })) | Out-Null
            continue
        }
        if ($installed.Count -gt 1) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.ambiguous' -Status 'incompatible' -Message "Multiple installed solutions match '$expectedName'.")) | Out-Null
            continue
        }

        $installedVersion = [version]"$($installed[0].version)"
        $requiredVersion = [version]"$($package.solution.version)"
        if ($installedVersion -lt $requiredVersion) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.version.incompatible' -Status 'incompatible' -Message "Installed '$expectedName' version '$installedVersion' is older than selected package '$requiredVersion'.")) | Out-Null
        } else {
            $checks.Add((New-AcceleratorValidationCheck -Code 'solution.version.ready' -Status 'ready' -Message "Installed '$expectedName' version '$installedVersion' satisfies selected package '$requiredVersion'.")) | Out-Null
        }
    }

    $satisfiedDependencyKeys = @($EnvironmentEvidence.satisfiedDependencyKeys | ForEach-Object {
        "$_".ToLowerInvariant()
    })
    foreach ($package in @($SelectedPackages)) {
        foreach ($dependency in @($package.declaredDependencies)) {
            $key = @(
                "$($dependency.required.solution)",
                "$($dependency.required.package)",
                "$($dependency.required.schemaName)",
                "$($dependency.required.displayName)"
            ) -join '|'
            $normalizedKey = $key.ToLowerInvariant()
            if ($satisfiedDependencyKeys -contains $normalizedKey) {
                $checks.Add((New-AcceleratorValidationCheck -Code 'dependency.satisfied' -Status 'ready' -Message "Dependency '$($dependency.required.displayName)' is satisfied." -Evidence $key)) | Out-Null
            } else {
                $checks.Add((New-AcceleratorValidationCheck -Code 'dependency.missing' -Status 'action-required' -Message "Dependency '$($dependency.required.displayName)' is not verified in the environment." -Evidence $key)) | Out-Null
            }
        }
    }

    $permissions = @($EnvironmentEvidence.permissions | ForEach-Object { "$_".ToLowerInvariant() })
    foreach ($requiredPermission in @('read-solutions', 'read-metadata')) {
        if ($permissions -notcontains $requiredPermission) {
            $checks.Add((New-AcceleratorValidationCheck -Code 'permission.missing' -Status 'unverified' -Message "Permission evidence '$requiredPermission' is missing.")) | Out-Null
        }
    }

    return New-AcceleratorEnvironmentValidationResult `
        -ScenarioSlug $ScenarioSlug `
        -Level 'environment-preflight' `
        -CatalogSnapshotId $CatalogSnapshotId `
        -SelectedPackages $SelectedPackages `
        -Checks $checks.ToArray() `
        -Environment ([pscustomobject]@{
            environmentId = "$($EnvironmentEvidence.environmentId)"
            environmentUrl = "$($EnvironmentEvidence.environmentUrl)"
            tenantId = "$($EnvironmentEvidence.tenantId)"
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
    if ([DateTime]::Parse("$($ValidationEvidence.expiresAtUtc)").ToUniversalTime() -lt $NowUtc.ToUniversalTime()) {
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
