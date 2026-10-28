<#
=============================================================================
COMPONENT:    Authenticated Environment Verification
FILE:         scripts/accelerators/trusted-environment-verification.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Authenticated GET-only Dataverse metadata
-----------------------------------------------------------------------------
OVERVIEW
Reuses the existing inspector to bind classified observations to planning.
NON-NEGOTIABLES
Explicit target and scope. No stored-target fallback, mutations or authorization.
Mock transport cannot label evidence Live. No credentials enter the artifact.
=============================================================================
#>

. (Join-Path $PSScriptRoot 'execution-readiness.ps1')
. (Join-Path $PSScriptRoot 'dataverse-environment-inspector.ps1')

function Get-VerifiedManagedBoolean {
    param([AllowNull()] [object]$Value)
    if ($Value -is [bool]) { return $Value }
    $nested = Get-FastObjectPropertyValue -InputObject $Value -Name 'Value'
    if ($nested -is [bool]) { return $nested }
    return $null
}

function Invoke-TrustedEnvironmentVerification {
    [CmdletBinding()]
    param(
        [switch]$EnableAuthenticatedVerification,
        [switch]$ConfirmReadOnlyScope,
        [Parameter(Mandatory)] [string]$WorkspaceRoot,
        [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [ValidatePattern('^https://[A-Za-z0-9.-]+(?::443)?/?$')] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [guid]$EnvironmentId,
        [Parameter(Mandatory)] [guid]$TenantId,
        [Parameter(Mandatory)] [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')] [string]$SolutionUniqueName,
        [Parameter(Mandatory)] [Security.Cryptography.X509Certificates.X509Certificate2]$SigningCertificate,
        [ValidateSet('Live', 'Mock')] [string]$CollectionMode = 'Mock',
        [string]$PackageManifestPath = '',
        [string]$AccessToken = '',
        [scriptblock]$TokenProvider,
        [scriptblock]$RequestInvoker,
        [scriptblock]$SleepAction,
        [ValidateRange(1, 3600)] [int]$EvidenceTimeToLiveSeconds = 900,
        [DateTimeOffset]$NowUtc = [DateTimeOffset]::UtcNow
    )

    if (-not $EnableAuthenticatedVerification -or -not $ConfirmReadOnlyScope) {
        throw 'Authenticated verification is disabled by default and requires explicit read-only scope confirmation.'
    }
    if ($EnvironmentId -eq [guid]::Empty -or $TenantId -eq [guid]::Empty) { throw 'Explicit nonempty environment and tenant identities are required.' }
    if ($CollectionMode -eq 'Live' -and ($null -ne $RequestInvoker -or $PSBoundParameters.ContainsKey('NowUtc'))) {
        throw 'Live verification rejects injected transports and simulated collection clocks.'
    }
    if ($CollectionMode -eq 'Mock' -and $null -eq $RequestInvoker) { throw 'Mock verification requires an injected transport and cannot contact a live service.' }
    if (-not $SigningCertificate.HasPrivateKey -or -not (Test-VerificationCertificateTime -Certificate $SigningCertificate -TimeUtc $NowUtc)) {
        throw 'Supply a valid operator-provisioned evidence signing certificate; no certificate is created automatically.'
    }
    $origin = Assert-FastDataverseEnvironmentUrl -EnvironmentUrl $EnvironmentUrl
    $paths = Get-ExecutionPlanningPaths -WorkspaceRoot $WorkspaceRoot -ScenarioSlug $ScenarioSlug
    $decision = Read-BuildPlanningJson -Path $paths.decision
    $planPath = Join-Path $WorkspaceRoot "specs\$ScenarioSlug\accelerator\build-plan\build-plan-manifest.json"
    $plan = Read-BuildPlanningJson -Path $planPath
    if (-not (Test-ExecutionSchema $decision 'architecture-decision') -or -not (Test-ExecutionSchema $plan 'build-plan') -or
        $plan.planId -cne (Get-ExecutionPlanIdentity $plan) -or $plan.decisionId -cne $decision.decisionId -or
        $plan.scenarioSlug -cne $ScenarioSlug -or $decision.scenarioSlug -cne $ScenarioSlug -or
        $plan.architecture -cne $decision.selectedOption) { throw 'Verification requires an approved, unchanged scenario-local decision and FAST-006 plan.' }
    if ($plan.architecture -ne 'fully-custom' -and
        $plan.environment.environmentUrl.TrimEnd('/').ToLowerInvariant() -cne $origin.ToLowerInvariant()) {
        throw 'The explicitly selected environment does not match the approved accelerator plan; no requests were issued.'
    }
    if (-not [string]::IsNullOrWhiteSpace($PackageManifestPath)) {
        $paths.packageManifest = Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $PackageManifestPath
    }
    $fingerprints = [ordered]@{}
    foreach ($entry in $paths.GetEnumerator() | Sort-Object Key) {
        $fingerprints[$entry.Key] = Get-BuildPlanningFileHash -Path $entry.Value
        if ($fingerprints[$entry.Key] -cne (Get-BuildPlanningValue $plan.inputFingerprints $entry.Key)) {
            throw "Pinned planning input '$($entry.Key)' changed; verification cannot query a target for a different plan."
        }
    }
    if (@($plan.inputFingerprints.PSObject.Properties).Count -ne $paths.Count) { throw 'Verification scope must contain every and only the pinned planning inputs.' }
    $packages = @()
    $packageFiles = @{}
    $missingDependencyMetadata = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if ($paths.Contains('packageManifest')) {
        $manifest = Read-BuildPlanningJson -Path $paths.packageManifest
        if (-not (Test-ExecutionSchema $manifest 'package-input-manifest')) { throw 'Package input manifest failed schema validation.' }
        $availablePackages = @(
            foreach ($entry in $manifest.packages) {
                $reference = if ([IO.Path]::IsPathRooted($entry.path)) { $entry.path } else { Join-Path (Split-Path $paths.packageManifest -Parent) $entry.path }
                $file = Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $reference
                $metadata = Read-BuildPlanningJson -Path $file
                if (-not (Test-ExecutionSchema $metadata 'package-metadata') -or $metadata.moduleId -cne $entry.moduleId -or
                    $metadata.packageId -cne $entry.packageId -or $metadata.sha256 -cne $entry.sha256 -or
                    $metadata.solution.version -cne $entry.version) { throw 'Package metadata identity or schema does not match its pinned manifest.' }
                if ($packageFiles.ContainsKey($metadata.moduleId)) { throw 'Package manifest contains an ambiguous module identity.' }
                $packageFiles[$metadata.moduleId] = $file
                $metadata
            }
        )
        $pending = [Collections.Generic.Queue[object]]::new()
        foreach ($selected in $decision.selectedPackages) {
            foreach ($candidate in @($availablePackages | Where-Object { $_.moduleId -ceq $selected.moduleId -and $_.packageId -ceq $selected.packageId })) {
                $pending.Enqueue($candidate)
            }
        }
        $included = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $scopedPackages = [Collections.Generic.List[object]]::new()
        while ($pending.Count -gt 0) {
            $package = $pending.Dequeue()
            if (-not $included.Add($package.moduleId)) { continue }
            $scopedPackages.Add($package) | Out-Null
            $fingerprints["package:$($package.moduleId)"] = Get-BuildPlanningFileHash -Path $packageFiles[$package.moduleId]
            foreach ($name in @(Get-FastRequiredSolutionNames -SelectedPackages @($package) | Where-Object { $_ -cne $package.solution.uniqueName })) {
                $candidates = @($availablePackages | Where-Object { $_.solution.uniqueName -ceq $name })
                if ($candidates.Count -ne 1) { $missingDependencyMetadata.Add($name) | Out-Null }
                else { $pending.Enqueue($candidates[0]) }
            }
        }
        $packages = @($scopedPackages.ToArray() | Sort-Object moduleId)
    }
    Assert-ApprovedArchitectureDecision -Decision $decision `
        -AnalysisManifest ([pscustomobject]@{ analysisId = $decision.analysisId; snapshotId = $decision.catalogSnapshotId }) -PackageMetadata $packages
    if ($decision.selectedOption -eq 'fully-custom' -and $packages.Count -gt 0) { throw 'Fully Custom verification must not inherit accelerator package dependencies.' }
    $checks = [Collections.Generic.List[object]]::new()
    function Add-VerificationCheck {
        param([string]$Id, [string]$Target, [string]$State, [bool]$Satisfied, [string]$Message,
            [string]$BlockingStatus = 'BLOCKED_EVIDENCE', [bool]$Required = $true)
        $checks.Add([pscustomobject][ordered]@{
            id = $Id; target = $Target; state = $State; satisfied = $Satisfied
            requiredForReadiness = $Required; blockingStatus = $BlockingStatus; message = $Message
        }) | Out-Null
    }
    foreach ($missing in $missingDependencyMetadata) {
        Add-VerificationCheck dependency-metadata $missing unavailable $false 'A transitive solution dependency lacks an exact pinned package metadata identity.'
    }
    if ($null -eq $TokenProvider) {
        $TokenProvider = if ($CollectionMode -eq 'Live') { { param($url) Get-WizardDataverseToken -EnvironmentUrl $url } } else { { throw 'Mock credentials are unavailable.' } }
    }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        try { $AccessToken = & $TokenProvider $origin }
        catch { Add-VerificationCheck credentials $origin unavailable $false 'Existing credentials could not be obtained; no automatic login or environment selection was attempted.' }
    }
    function Read-VerificationMetadata {
        param([string]$Path, [string]$Target)
        if ([string]::IsNullOrWhiteSpace($AccessToken)) { return $null }
        try {
            return Invoke-FastDataverseGet -EnvironmentUrl $origin -Path $Path -AccessToken $AccessToken `
                -RequireComplete -RequestInvoker $RequestInvoker -TokenProvider $TokenProvider -SleepAction $SleepAction
        } catch {
            $state = if ((Get-WizardHttpStatusCode -ErrorRecord $_) -eq 403) { 'inaccessible' } else { 'unavailable' }
            Add-VerificationCheck metadata-read $Target $state $false 'A required bounded GET failed; inaccessible or incomplete data is not compatibility evidence.'
            return $null
        }
    }
    $inspection = $null
    if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
        $inspection = Invoke-FastDataverseEnvironmentInspection -EnvironmentUrl $origin -AccessToken $AccessToken `
            -CatalogSnapshotId $decision.catalogSnapshotId -SelectedPackages $packages -ProviderNeutral -StrictReadOnlyVerification `
            -ForceRefresh -RequestInvoker $RequestInvoker -TokenProvider $TokenProvider -SleepAction $SleepAction -NowUtc $NowUtc.UtcDateTime
        Add-VerificationCheck authenticated-connection $origin $(if ($inspection.connected) { 'verified' } else { 'unavailable' }) `
            ([bool]$inspection.connected) 'WhoAmI authentication must succeed without using a stored environment target.'
        foreach ($errorRecord in $inspection.inspectionErrors) {
            Add-VerificationCheck package-inspection $errorRecord.code unavailable $false 'A required package metadata inspection could not be completed.'
        }
        foreach ($dependency in $inspection.dependencyAssessments) {
            Add-VerificationCheck package-component "$($dependency.packageId):$($dependency.key)" $(if ($dependency.status -eq 'unverified') { 'unsupported' } else { 'verified' }) `
                ($dependency.status -eq 'satisfied') 'Package component dependency must be verified by an exact supported metadata query.' BLOCKED_PREREQUISITES
        }
        foreach ($table in $inspection.requiredTables) {
            Add-VerificationCheck package-table "$($table.moduleId):$($table.logicalName)" `
                $(if ($table.verificationState -eq 'verified') { 'verified' } else { 'unavailable' }) `
                ([bool]$table.found) 'Every declared package table must have an exact observed logical-name match.' BLOCKED_PREREQUISITES
        }
    }
    $actualEnvironmentId = [guid]::Empty; $actualTenantId = [guid]::Empty; $organizationId = [guid]::Empty; $principalId = [guid]::Empty
    $detailResponse = Read-VerificationMetadata "RetrieveCurrentOrganization(AccessType=Microsoft.Dynamics.CRM.EndpointAccessType'Default')" 'environment-identity'
    $detail = Get-FastObjectPropertyValue $detailResponse 'Detail'
    $identityKnown = $null -ne $inspection -and
        [guid]::TryParse("$(Get-FastObjectPropertyValue $detail 'EnvironmentId')", [ref]$actualEnvironmentId) -and
        [guid]::TryParse("$(Get-FastObjectPropertyValue $detail 'TenantId')", [ref]$actualTenantId) -and
        [guid]::TryParse("$(Get-FastObjectPropertyValue $detail 'OrganizationId')", [ref]$organizationId) -and
        [guid]::TryParse("$(Get-FastObjectPropertyValue $inspection 'principalId')", [ref]$principalId) -and
        $actualEnvironmentId -ne [guid]::Empty -and $actualTenantId -ne [guid]::Empty -and $principalId -ne [guid]::Empty -and
        $organizationId.ToString() -ieq "$(Get-FastObjectPropertyValue $inspection 'organizationId')"
    Add-VerificationCheck environment-identity $origin $(if ($identityKnown) { 'verified' } else { 'unavailable' }) `
        ($identityKnown -and $actualEnvironmentId -eq $EnvironmentId -and $actualTenantId -eq $TenantId) `
        'Server-reported environment, tenant and organization must match the explicit target and WhoAmI context.' BLOCKED_DECISION_CHANGE
    $aadObjectId = $null
    if ($identityKnown) {
        $userResponse = Read-VerificationMetadata "systemusers?`$select=systemuserid,azureactivedirectoryobjectid&`$filter=systemuserid eq $principalId" 'authenticated-principal'
        if ($null -ne $userResponse -and @($userResponse.value).Count -eq 1) {
            $parsedAadId = [guid]::Empty
            if ([guid]::TryParse("$(Get-FastObjectPropertyValue $userResponse.value[0] 'azureactivedirectoryobjectid')", [ref]$parsedAadId)) {
                $aadObjectId = $parsedAadId.ToString()
            }
        }
    }
    $solutionResponse = Read-VerificationMetadata "solutions?`$select=solutionid,uniquename,version,ismanaged,_publisherid_value&`$expand=publisherid(`$select=publisherid,uniquename,customizationprefix)&`$filter=uniquename eq '$SolutionUniqueName'" 'extension-solution'
    $targetSolutions = @(if ($null -ne $solutionResponse) { $solutionResponse.value })
    $publisherPrefix = "$($plan.managedSolutionPolicy.solutionOwnedPrefix)"
    $targetPublisher = if ($targetSolutions.Count -eq 1) { Get-FastObjectPropertyValue $targetSolutions[0] 'publisherid' } else { $null }
    $targetPublisherId = [guid]::Empty; $targetSolutionId = [guid]::Empty
    $publisherMetadataKnown = $targetSolutions.Count -ne 1 -or ($null -ne $targetPublisher -and
        [guid]::TryParse("$(Get-FastObjectPropertyValue $targetPublisher 'publisherid')", [ref]$targetPublisherId) -and
        [guid]::TryParse("$(Get-FastObjectPropertyValue $targetSolutions[0] 'solutionid')", [ref]$targetSolutionId) -and
        $targetPublisherId -ne [guid]::Empty -and $targetSolutionId -ne [guid]::Empty -and
        "$(Get-FastObjectPropertyValue $targetSolutions[0] '_publisherid_value')" -ieq $targetPublisherId.ToString() -and
        -not [string]::IsNullOrWhiteSpace("$(Get-FastObjectPropertyValue $targetPublisher 'uniquename')") -and
        -not [string]::IsNullOrWhiteSpace("$(Get-FastObjectPropertyValue $targetPublisher 'customizationprefix')") -and
        (Get-FastObjectPropertyValue $targetSolutions[0] 'ismanaged') -is [bool])
    $publisherKnown = $targetSolutions.Count -eq 1 -and $publisherMetadataKnown -and
        "$(Get-FastObjectPropertyValue $targetSolutions[0] 'uniquename')" -ceq $SolutionUniqueName -and
        "$(Get-FastObjectPropertyValue $targetPublisher 'customizationprefix')" -ceq $publisherPrefix -and -not $targetSolutions[0].ismanaged
    Add-VerificationCheck extension-publisher $SolutionUniqueName $(if ($null -ne $solutionResponse -and $publisherMetadataKnown) { 'verified' } else { 'unavailable' }) `
        $publisherKnown 'The selected extension solution must be unmanaged and have the exact planned publisher identity/prefix.' BLOCKED_COMPATIBILITY
    $packageEvidence = @(
        foreach ($package in $packages) {
            $installed = @(if ($null -ne $inspection) { $inspection.installedSolutions | Where-Object uniqueName -CEQ $package.solution.uniqueName })
            $present = $installed.Count -eq 1
            Add-VerificationCheck installed-solution $package.solution.uniqueName verified $present 'The required solution must be installed exactly once.' BLOCKED_PREREQUISITES
            if ($present) {
                Add-VerificationCheck package-version $package.solution.uniqueName verified `
                    ($installed[0].version -ceq $package.solution.version) 'Installed solution version must exactly match the approved package.' BLOCKED_COMPATIBILITY
                Add-VerificationCheck package-publisher $package.solution.uniqueName verified `
                    ($installed[0].managed -eq $package.solution.managed -and
                     $installed[0].publisherUniqueName -ceq $package.publisher.uniqueName -and
                     $installed[0].publisherPrefix -ceq $package.publisher.customizationPrefix -and
                     -not [string]::IsNullOrWhiteSpace($installed[0].publisherId)) `
                    'Installed managed state and publisher identity must match verified package metadata.' BLOCKED_COMPATIBILITY
            }
            Add-VerificationCheck package-content-hash $package.packageId inferred $false `
                'The SHA-256 identifies the approved local package; Dataverse does not attest the original installed ZIP bytes.' BLOCKED_EVIDENCE $false
            $dependencyNames = @(Get-FastRequiredSolutionNames -SelectedPackages @($package) | Where-Object { $_ -cne $package.solution.uniqueName })
            [pscustomobject][ordered]@{
                moduleId = $package.moduleId; packageId = $package.packageId; sha256 = $package.sha256
                solutionUniqueName = $package.solution.uniqueName
                version = if ($present) { $installed[0].version } else { $package.solution.version }
                installed = $present; dependencies = $dependencyNames
            }
        }
    )
    $componentEvidence = [Collections.Generic.List[object]]::new()
    $metadataAccessible = $true
    foreach ($task in $plan.componentPlans) {
        $query = Get-FastPlannedComponentQuery -Task $task
        $exists = $false; $managed = $task.managed; $customizable = $false; $ownership = "$($task.ownership)"
        $allowed = @()
        if ($null -eq $query) {
            Add-VerificationCheck component-query $task.taskId unsupported $false 'This plan identity does not resolve to a concrete supported table or column; no name is inferred.'
            $metadataAccessible = $false
        } else {
            $parentExtensionAllowed = $true
            if ($task.componentKind -eq 'column' -and $task.action -in @('CREATE', 'EXTEND')) {
                $parentResponse = Read-VerificationMetadata "EntityDefinitions?`$select=LogicalName,IsCustomizable,CanCreateAttributes&`$filter=LogicalName eq '$($query.ParentLogicalName)'" $task.taskId
                $parents = @(if ($null -ne $parentResponse) { $parentResponse.value })
                $parentKnown = $parents.Count -eq 1 -and "$(Get-FastObjectPropertyValue $parents[0] 'LogicalName')" -ceq $query.ParentLogicalName -and
                    $null -ne (Get-VerifiedManagedBoolean (Get-FastObjectPropertyValue $parents[0] 'IsCustomizable')) -and
                    $null -ne (Get-VerifiedManagedBoolean (Get-FastObjectPropertyValue $parents[0] 'CanCreateAttributes'))
                $parentExtensionAllowed = $parentKnown -and
                    (Get-VerifiedManagedBoolean (Get-FastObjectPropertyValue $parents[0] 'IsCustomizable')) -eq $true -and
                    (Get-VerifiedManagedBoolean (Get-FastObjectPropertyValue $parents[0] 'CanCreateAttributes')) -eq $true
                Add-VerificationCheck parent-customization $task.taskId $(if ($parentKnown) { 'verified' } else { 'unsupported' }) `
                    $parentExtensionAllowed 'Column operations require exact parent metadata with customizable and attribute-creation rights.' BLOCKED_COMPATIBILITY
            }
            $response = Read-VerificationMetadata $query.Path $task.taskId
            if ($null -eq $response) { $metadataAccessible = $false }
            $records = @(if ($null -ne $response) { $response.value })
            Add-VerificationCheck component-cardinality $task.taskId $(if ($null -ne $response) { 'verified' } else { 'unavailable' }) `
                ($records.Count -le 1 -and @($records | Where-Object LogicalName -CNE $query.LogicalName).Count -eq 0) `
                'Metadata must return zero or one exact logical-name match, never an ambiguous or substituted component.' BLOCKED_COMPATIBILITY
            $exists = $records.Count -eq 1
            if (-not $exists -and $null -ne $response -and $records.Count -eq 0) {
                $managed = $false
                $ownership = 'solution-owned'
                if ($task.action -eq 'CREATE' -and $publisherKnown -and $parentExtensionAllowed -and $query.LogicalName.StartsWith("$publisherPrefix`_", [StringComparison]::Ordinal)) {
                    $allowed = @('CREATE')
                }
                Add-VerificationCheck prospective-owner $task.taskId inferred $true `
                    'The component is absent; future ownership is planned from the verified extension publisher, not observed component ownership.' BLOCKED_EVIDENCE $false
            } elseif ($exists) {
                $managedValue = Get-VerifiedManagedBoolean (Get-FastObjectPropertyValue $records[0] 'IsManaged')
                $customizableValue = Get-VerifiedManagedBoolean (Get-FastObjectPropertyValue $records[0] 'IsCustomizable')
                Add-VerificationCheck managed-property $task.taskId $(if ($null -ne $managedValue) { 'verified' } else { 'unsupported' }) `
                    ($null -ne $managedValue) 'Actual managed state must be returned by the metadata service.'
                $managed = $managedValue -eq $true; $customizable = $customizableValue -eq $true
                $metadataId = [guid]::Empty
                $memberships = @()
                if ([guid]::TryParse("$(Get-FastObjectPropertyValue $records[0] 'MetadataId')", [ref]$metadataId) -and $metadataId -ne [guid]::Empty) {
                    $membershipResponse = Read-VerificationMetadata "solutioncomponents?`$select=objectid,componenttype,_solutionid_value&`$filter=objectid eq $metadataId and componenttype eq $($query.ComponentType)" $task.taskId
                    $memberships = @(if ($null -ne $membershipResponse) { $membershipResponse.value })
                    $memberships = @($memberships | Where-Object {
                        "$(Get-FastObjectPropertyValue $_ 'objectid')" -ieq $metadataId.ToString() -and
                        "$(Get-FastObjectPropertyValue $_ 'componenttype')" -ceq "$($query.ComponentType)"
                    })
                }
                if ($managed) {
                    $owners = @(if ($null -ne $inspection) {
                        $inspection.installedSolutions | Where-Object { $owner = $_; $owner.managed -and
                            @($memberships | Where-Object { "$(Get-FastObjectPropertyValue $_ '_solutionid_value')" -ieq $owner.solutionId }).Count -gt 0 }
                    })
                    $ownership = if ($owners.Count -eq 1) { 'accelerator-managed' } else { 'unresolved' }
                } else {
                    $ownership = if ($publisherKnown -and $query.LogicalName.StartsWith("$publisherPrefix`_", [StringComparison]::Ordinal) -and
                        @($memberships | Where-Object { "$(Get-FastObjectPropertyValue $_ '_solutionid_value')" -ieq $targetSolutionId.ToString() }).Count -gt 0) { 'solution-owned' } else { 'unresolved' }
                }
                Add-VerificationCheck component-owner $task.taskId verified ($ownership -ne 'unresolved') `
                    'Ownership requires exact solution-component membership and publisher metadata; prefix alone is not ownership proof.' BLOCKED_COMPATIBILITY
                $allowed = @('REUSE')
                if ($task.action -eq 'EXTEND') {
                    $extensionAllowed = $parentExtensionAllowed -and $customizable -and
                        ($task.componentKind -ne 'table' -or (Get-VerifiedManagedBoolean (Get-FastObjectPropertyValue $records[0] 'CanCreateAttributes')) -eq $true)
                    Add-VerificationCheck customization $task.taskId $(if ($null -ne $customizableValue) { 'verified' } else { 'unsupported' }) `
                        $extensionAllowed 'Separate extensions require supported customizable metadata and table attribute-creation rights.' BLOCKED_COMPATIBILITY
                    if ($extensionAllowed) { $allowed += 'EXTEND' }
                }
            }
        }
        $componentEvidence.Add([pscustomobject][ordered]@{
            taskId = $task.taskId; componentKind = $task.componentKind; componentIdentity = $task.componentIdentity
            exists = $exists; ownership = $ownership; managed = [bool]$managed; customizable = $customizable; allowedActions = @($allowed)
        }) | Out-Null
    }
    $granted = [Collections.Generic.List[string]]::new()
    if ($metadataAccessible) { $granted.Add('read-metadata') | Out-Null }
    $capabilities = Get-VerificationPrivilegeRequirements -Plan $plan
    if (@($plan.componentPlans | Where-Object action -EQ 'INTEGRATE').Count -gt 0) {
        Add-VerificationCheck integration-permissions integration unsupported $false 'External integration privilege mapping is not supported; no permission is inferred.' BLOCKED_SECURITY
    }
    $privilegeCache = @{}
    foreach ($capability in $capabilities.GetEnumerator()) {
        $satisfied = $identityKnown
        foreach ($name in $capability.Value) {
            if (-not $privilegeCache.ContainsKey($name)) {
                $privilegeResponse = if ($identityKnown) {
                    Read-VerificationMetadata "systemusers($principalId)/Microsoft.Dynamics.CRM.RetrieveUserPrivilegeByPrivilegeName(PrivilegeName='$name',ExcludeTeamBasic=false)" $name
                } else { $null }
                $privileges = @(Get-FastObjectPropertyValue $privilegeResponse 'RolePrivileges')
                $known = $null -ne $privilegeResponse -and
                    (($privilegeResponse -is [Collections.IDictionary] -and $privilegeResponse.Contains('RolePrivileges')) -or
                     $null -ne $privilegeResponse.PSObject.Properties['RolePrivileges'])
                $hasGlobal = @($privileges | Where-Object {
                    "$(Get-FastObjectPropertyValue $_ 'PrivilegeName')" -ceq $name -and
                    "$(Get-FastObjectPropertyValue $_ 'Depth')" -in @('Global', '3') -and
                    "$(Get-FastObjectPropertyValue $_ 'PrivilegeId')" -match '^[a-fA-F0-9-]{36}$'
                }).Count -gt 0
                $privilegeCache[$name] = $known -and $hasGlobal
                Add-VerificationCheck privilege $name $(if ($known) { 'verified' } else { 'unavailable' }) `
                    $privilegeCache[$name] 'The authenticated principal requires the named effective Global privilege; successful reads do not imply write permissions.' BLOCKED_SECURITY
            }
            $satisfied = $satisfied -and $privilegeCache[$name]
        }
        if ($satisfied) { $granted.Add($capability.Key) | Out-Null }
    }
    $finalIdentity = Read-VerificationMetadata 'WhoAmI' 'authenticated-context-stable'
    Add-VerificationCheck authenticated-context-stable $principalId.ToString() `
        $(if ($null -ne $finalIdentity) { 'verified' } else { 'unavailable' }) `
        ($identityKnown -and "$(Get-FastObjectPropertyValue $finalIdentity 'UserId')" -ieq $principalId.ToString() -and
         "$(Get-FastObjectPropertyValue $finalIdentity 'OrganizationId')" -ieq $organizationId.ToString()) `
        'The authenticated principal and organization must remain stable through collection and token refresh.' BLOCKED_SECURITY
    $evidence = [pscustomobject][ordered]@{
        schemaVersion = '1.0'; decisionId = $decision.decisionId; planId = $plan.planId; planSha256 = Get-BuildPlanningFileHash $planPath
        environment = [pscustomobject]@{ environmentId = $actualEnvironmentId.ToString(); tenantId = $actualTenantId.ToString(); url = $origin.ToLowerInvariant() }
        observedAtUtc = $NowUtc.ToUniversalTime().ToString('o'); expiresAtUtc = $NowUtc.AddSeconds($EvidenceTimeToLiveSeconds).ToUniversalTime().ToString('o')
        inputArtifacts = @($paths.GetEnumerator() | Sort-Object Key | ForEach-Object {
            [pscustomobject]@{ key = $_.Key; path = [IO.Path]::GetRelativePath($WorkspaceRoot, $_.Value).Replace('\', '/') }
        })
        packages = $packageEvidence; components = @($componentEvidence.ToArray())
        security = [pscustomobject]@{ principalId = $principalId.ToString(); grantedPermissions = @($granted.ToArray() | Sort-Object -Unique) }
    }
    $payload = [pscustomobject][ordered]@{
        collectorVersion = '1.0'; collectionMode = $CollectionMode; decisionSha256 = $fingerprints.decision
        catalogSnapshotId = $decision.catalogSnapshotId; dependencyManifestSha256 = $fingerprints.dependencies
        inputFingerprints = [pscustomobject]$fingerprints; selectedPackages = @($decision.selectedPackages)
        authenticatedIdentity = [pscustomobject]@{ organizationId = $organizationId.ToString(); principalId = $principalId.ToString(); aadObjectId = $aadObjectId }
        complete = @($checks | Where-Object { $_.requiredForReadiness -and $_.state -ne 'verified' }).Count -eq 0
        checks = @($checks | Sort-Object id, target); evidence = $evidence
    }
    if (-not (Test-ExecutionSchema $evidence 'execution-evidence')) { throw 'Collected prerequisite evidence failed schema validation; no report was signed.' }
    $envelope = New-SignedEnvironmentVerification -Payload $payload -SigningCertificate $SigningCertificate
    if (-not (Test-ExecutionSchema $envelope 'trusted-environment-verification')) { throw 'Signed verification failed schema validation.' }
    return $envelope
}
