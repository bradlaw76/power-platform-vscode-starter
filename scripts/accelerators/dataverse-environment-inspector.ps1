<#
=============================================================================
COMPONENT:    FAST Dataverse Environment Inspector
FILE:         scripts/accelerators/dataverse-environment-inspector.ps1
VERSION:      0.2.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Collects bounded, cacheable, read-only Dataverse evidence for FAST Level 2
environment preflight. It never sends a mutating request or stores credentials.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            authenticated read-only environment evidence collector
- Inputs:          environment URL/token, selected packages, catalog snapshot
- Outputs:         normalized environment evidence and metadata fingerprint
- Dependencies:    shared Dataverse runtime and accelerator catalog helpers
- Side Effects:    optional local cache write under an explicit cache root

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Uses GET requests only and groups table/component metadata checks.
✔ Reuses fresh cache entries bound to environment, snapshot, and packages.
✔ Handles authentication, permission, throttling, and timeout failures safely.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never log, return, or persist an access token.
- Never invoke a Dataverse mutation, action import, or solution installation.
- Never treat package presence as proof that a future import will succeed.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'accelerator-catalog.ps1')
. (Join-Path $PSScriptRoot 'environment-compatibility.ps1')
. (Join-Path $PSScriptRoot '../bootstrap/helpers/dataverse-runtime.ps1')

function Get-FastObjectPropertyValue {
    param(
        [AllowNull()] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name,
        [AllowNull()] [object]$DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
        return $DefaultValue
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }
    return $property.Value
}

function Assert-FastDataverseEnvironmentUrl {
    param([Parameter(Mandatory)] [string]$EnvironmentUrl)

    $uri = $null
    if (-not [Uri]::TryCreate($EnvironmentUrl, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -cne 'https' -or
        -not [string]::IsNullOrWhiteSpace($uri.UserInfo) -or
        -not [string]::IsNullOrWhiteSpace($uri.Query) -or
        -not [string]::IsNullOrWhiteSpace($uri.Fragment)) {
        throw 'Dataverse environment URL must be an absolute HTTPS origin without credentials, query, or fragment.'
    }
    $address = $null
    if ([Net.IPAddress]::TryParse($uri.Host, [ref]$address) -or
        $uri.IsLoopback -or
        $uri.Host -eq 'localhost') {
        throw 'Dataverse environment URL must not target localhost or an IP address.'
    }
    return $uri.GetLeftPart([UriPartial]::Authority).TrimEnd('/')
}

function Get-FastEnvironmentInspectionCacheKey {
    param(
        [Parameter(Mandatory)] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [string]$CatalogSnapshotId,
        [Parameter(Mandatory)] [object[]]$SelectedPackages
    )

    $packageKeys = @($SelectedPackages | ForEach-Object {
        [ordered]@{
            packageId = "$($_.packageId)"
            moduleId = "$($_.moduleId)"
            solutionUniqueName = "$($_.solution.uniqueName)"
            version = "$($_.solution.version)"
            sha256 = "$($_.sha256)"
            dependencies = @($_.declaredDependencies | ForEach-Object {
                [ordered]@{
                    key = Get-FastDependencyKey -Dependency $_
                    packageVersion = "$($_.required.packageVersion)"
                    solution = "$($_.required.solution)"
                }
            } | Sort-Object key)
        }
    } | Sort-Object packageId)
    $identity = [ordered]@{
        schemaVersion = '1.0'
        environmentUrl = $EnvironmentUrl.ToLowerInvariant()
        catalogSnapshotId = $CatalogSnapshotId
        packages = $packageKeys
    }
    return Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $identity)
}

function Get-FastCachedEnvironmentInspection {
    param(
        [Parameter(Mandatory)] [string]$CachePath,
        [Parameter(Mandatory)] [string]$ExpectedCacheKey,
        [datetime]$NowUtc = [DateTime]::UtcNow
    )

    if (-not (Test-Path -LiteralPath $CachePath -PathType Leaf)) {
        return $null
    }
    $cached = Get-Content -LiteralPath $CachePath -Raw -Encoding UTF8 | ConvertFrom-Json -DateKind String
    if ("$($cached.cacheKey)" -cne $ExpectedCacheKey) {
        return $null
    }
    try {
        [DateTimeOffset]$parsedCacheExpiry = [DateTimeOffset]::Parse(
            "$($cached.expiresAtUtc)",
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind
        )
    } catch {
        return $null
    }
    if ($parsedCacheExpiry.UtcTicks -le $NowUtc.ToUniversalTime().Ticks) {
        return $null
    }
    $evidence = $cached.evidence
    $evidence.cache = [pscustomobject]@{
        hit = $true
        cacheKey = $ExpectedCacheKey
        expiresAtUtc = $parsedCacheExpiry.UtcDateTime.ToString('o')
    }
    return $evidence
}

function Set-FastCachedEnvironmentInspection {
    param(
        [Parameter(Mandatory)] [string]$CachePath,
        [Parameter(Mandatory)] [string]$CacheKey,
        [Parameter(Mandatory)] [object]$Evidence,
        [Parameter(Mandatory)] [datetime]$ExpiresAtUtc
    )

    $folder = Split-Path $CachePath -Parent
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $temporaryPath = "$CachePath.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [ordered]@{
            schemaVersion = '1.0'
            cacheKey = $CacheKey
            expiresAtUtc = $ExpiresAtUtc.ToUniversalTime().ToString('o')
            evidence = $Evidence
        } | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $temporaryPath -Encoding utf8NoBOM
        Move-Item -LiteralPath $temporaryPath -Destination $CachePath -Force
    } finally {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}

function Split-FastCollection {
    param(
        [object[]]$InputObject,
        [ValidateRange(1, 100)] [int]$Size = 20
    )

    $items = @($InputObject)
    for ($offset = 0; $offset -lt $items.Count; $offset += $Size) {
        , @($items[$offset..([Math]::Min($offset + $Size - 1, $items.Count - 1))])
    }
}

function Get-FastRequiredSolutionNames {
    param([Parameter(Mandatory)] [object[]]$SelectedPackages)

    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($package in @($SelectedPackages)) {
        if (-not [string]::IsNullOrWhiteSpace("$($package.solution.uniqueName)")) {
            $names.Add("$($package.solution.uniqueName)") | Out-Null
        }
        foreach ($dependency in @($package.declaredDependencies)) {
            foreach ($candidate in @(
                "$($dependency.required.packageAppName)",
                "$($dependency.required.solution)",
                "$($dependency.required.package)"
            )) {
                if ($candidate -match '^(?<name>[A-Za-z0-9_]+)(?:\s|\()') {
                    $names.Add($Matches.name) | Out-Null
                }
            }
        }
    }
    return @($names | Sort-Object)
}

function Get-FastDependencyQueryDefinition {
    param(
        [Parameter(Mandatory)] [object]$Dependency,
        [object[]]$PackageMetadata = @()
    )

    $required = $Dependency.required
    $type = "$($required.type)"
    $id = "$($required.id)".Trim('{}')
    $schemaName = "$($required.schemaName)"
    $uniqueName = "$($required.uniqueName)"
    switch ($type) {
        '2' {
            if ([string]::IsNullOrWhiteSpace($schemaName) -or
                [string]::IsNullOrWhiteSpace("$($required.parentDisplayName)")) {
                return $null
            }
            $parentTables = @($PackageMetadata.tables | Where-Object {
                [string]::Equals("$($_.displayName)", "$($required.parentDisplayName)", [StringComparison]::OrdinalIgnoreCase)
            })
            if ($parentTables.Count -ne 1) {
                return $null
            }
            $tableLogicalName = "$($parentTables[0].logicalName)"
            return [pscustomobject]@{
                Group = "attributes:$tableLogicalName"
                EntitySet = "EntityDefinitions(LogicalName='$(ConvertTo-WizardODataLiteral $tableLogicalName)')/Attributes"
                Select = 'MetadataId,LogicalName'
                Filter = "LogicalName eq '$(ConvertTo-WizardODataLiteral $schemaName)'"
                MatchProperty = 'LogicalName'
                MatchValue = $schemaName
            }
        }
        '9' {
            if ([string]::IsNullOrWhiteSpace($schemaName)) { return $null }
            return [pscustomobject]@{
                Group = 'globaloptionsets'
                EntitySet = 'GlobalOptionSetDefinitions'
                Select = 'MetadataId,Name'
                Filter = "Name eq '$(ConvertTo-WizardODataLiteral $schemaName)'"
                MatchProperty = 'Name'
                MatchValue = $schemaName
            }
        }
        '60' {
            if ([string]::IsNullOrWhiteSpace($id)) { return $null }
            return [pscustomobject]@{
                Group = 'systemforms'
                EntitySet = 'systemforms'
                Select = 'formid,name'
                Filter = "formid eq $id"
                MatchProperty = 'formid'
                MatchValue = $id
            }
        }
        '61' {
            if ([string]::IsNullOrWhiteSpace($schemaName)) { return $null }
            return [pscustomobject]@{
                Group = 'webresources'
                EntitySet = 'webresourceset'
                Select = 'webresourceid,name'
                Filter = "name eq '$(ConvertTo-WizardODataLiteral $schemaName)'"
                MatchProperty = 'name'
                MatchValue = $schemaName
            }
        }
        '66' {
            if ([string]::IsNullOrWhiteSpace($schemaName)) { return $null }
            return [pscustomobject]@{
                Group = 'customcontrols'
                EntitySet = 'customcontrols'
                Select = 'customcontrolid,name'
                Filter = "name eq '$(ConvertTo-WizardODataLiteral $schemaName)'"
                MatchProperty = 'name'
                MatchValue = $schemaName
            }
        }
        'SettingDefinition' {
            if ([string]::IsNullOrWhiteSpace($uniqueName)) { return $null }
            return [pscustomobject]@{
                Group = 'settingdefinitions'
                EntitySet = 'settingdefinitions'
                Select = 'settingdefinitionid,uniquename,displayname'
                Filter = "uniquename eq '$(ConvertTo-WizardODataLiteral $uniqueName)'"
                MatchProperty = 'uniquename'
                MatchValue = $uniqueName
            }
        }
        default {
            return $null
        }
    }
}

function New-FastUnavailableEnvironmentEvidence {
    param(
        [Parameter(Mandatory)] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [string]$AccessState,
        [Parameter(Mandatory)] [string]$ErrorCode,
        [Parameter(Mandatory)] [string]$Message,
        [datetime]$CollectedAtUtc = [DateTime]::UtcNow,
        [int]$RequestCount = 0
    )

    return [pscustomobject][ordered]@{
        accessState = $AccessState
        connected = $false
        environmentId = ''
        environmentUrl = $EnvironmentUrl
        tenantId = ''
        organizationVersion = ''
        collectedAtUtc = $CollectedAtUtc.ToUniversalTime().ToString('o')
        installedSolutions = @()
        installedFastModules = @()
        requiredTables = @()
        dependencyAssessments = @()
        satisfiedDependencyKeys = @()
        permissions = @()
        permissionLimitations = @($Message)
        inspectionErrors = @([pscustomobject]@{ code = $ErrorCode; message = $Message })
        metadataFingerprint = ''
        requestCount = $RequestCount
        cache = [pscustomobject]@{ hit = $false; cacheKey = ''; expiresAtUtc = $null }
    }
}

function Invoke-FastDataverseEnvironmentInspection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [string]$AccessToken,
        [Parameter(Mandatory)] [string]$CatalogSnapshotId,
        [Parameter(Mandatory)] [object[]]$SelectedPackages,
        [string]$TenantId = '',
        [string]$CacheRoot = '',
        [timespan]$CacheTimeToLive = ([TimeSpan]::FromMinutes(15)),
        [switch]$ForceRefresh,
        [ValidateRange(1, 300)] [int]$RequestTimeoutSec = 30,
        [ValidateRange(1, 10)] [int]$MaxAttempts = 4,
        [scriptblock]$TokenProvider,
        [scriptblock]$RequestInvoker,
        [scriptblock]$SleepAction,
        [datetime]$NowUtc = [DateTime]::UtcNow
    )

    if ($SelectedPackages.Count -eq 0) {
        throw 'At least one selected package is required for live FAST environment inspection.'
    }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        throw 'A Dataverse access token is required for live FAST environment inspection.'
    }
    $normalizedUrl = Assert-FastDataverseEnvironmentUrl -EnvironmentUrl $EnvironmentUrl
    $cacheKey = Get-FastEnvironmentInspectionCacheKey `
        -EnvironmentUrl $normalizedUrl `
        -CatalogSnapshotId $CatalogSnapshotId `
        -SelectedPackages $SelectedPackages
    $cachePath = if ([string]::IsNullOrWhiteSpace($CacheRoot)) {
        ''
    } else {
        Join-Path $CacheRoot "$cacheKey.json"
    }
    if (-not $ForceRefresh -and -not [string]::IsNullOrWhiteSpace($cachePath)) {
        $cached = Get-FastCachedEnvironmentInspection -CachePath $cachePath -ExpectedCacheKey $cacheKey -NowUtc $NowUtc
        if ($null -ne $cached) {
            return $cached
        }
    }

    $requestLog = [Collections.Generic.List[object]]::new()
    $permissions = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $permissionLimitations = [Collections.Generic.List[string]]::new()
    $inspectionErrors = [Collections.Generic.List[object]]::new()
    $invokeGet = {
        param([string]$Path, [string]$Capability)
        $requestLog.Add([pscustomobject]@{ Method = 'Get'; Path = $Path; Capability = $Capability }) | Out-Null
        $response = Invoke-WizardDataverseRequest `
            -Method Get `
            -Path $Path `
            -EnvironmentUrl $normalizedUrl `
            -AccessToken $AccessToken `
            -MaxAttempts $MaxAttempts `
            -TimeoutSec $RequestTimeoutSec `
            -TokenProvider $TokenProvider `
            -RequestInvoker $RequestInvoker `
            -SleepAction $SleepAction
        $permissions.Add($Capability) | Out-Null
        return $response
    }

    try {
        $identity = & $invokeGet 'WhoAmI' 'read-identity'
    } catch {
        $message = "$($_.Exception.Message)"
        $state = if ($message -match 'HTTP 401') { 'authentication-failed' } elseif ($message -match 'HTTP 403') { 'insufficient-permissions' } else { 'unavailable' }
        return New-FastUnavailableEnvironmentEvidence `
            -EnvironmentUrl $normalizedUrl `
            -AccessState $state `
            -ErrorCode "environment.$state" `
            -Message $message `
            -CollectedAtUtc $NowUtc `
            -RequestCount $requestLog.Count
    }

    $organizationVersion = ''
    try {
        $versionResponse = & $invokeGet 'RetrieveVersion()' 'read-version'
        $organizationVersion = "$(Get-FastObjectPropertyValue -InputObject $versionResponse -Name 'Version' -DefaultValue '')"
    } catch {
        $inspectionErrors.Add([pscustomobject]@{ code = 'version.unverified'; message = "$($_.Exception.Message)" }) | Out-Null
    }

    $installedSolutions = @()
    try {
        $requiredSolutionNames = @(Get-FastRequiredSolutionNames -SelectedPackages $SelectedPackages)
        $solutionFilters = @("startswith(uniquename,'appbase_')")
        $solutionFilters += @($requiredSolutionNames | ForEach-Object {
            "uniquename eq '$(ConvertTo-WizardODataLiteral $_)'"
        })
        $solutionPath = "solutions?`$select=solutionid,uniquename,friendlyname,version,ismanaged,_publisherid_value&`$expand=publisherid(`$select=publisherid,uniquename,customizationprefix)&`$filter=$($solutionFilters -join ' or ')"
        $solutionResponse = & $invokeGet $solutionPath 'read-solutions'
        $installedSolutions = @((Get-FastObjectPropertyValue -InputObject $solutionResponse -Name 'value' -DefaultValue @()) | ForEach-Object {
            $publisher = Get-FastObjectPropertyValue -InputObject $_ -Name 'publisherid'
            [pscustomobject][ordered]@{
                solutionId = "$(Get-FastObjectPropertyValue -InputObject $_ -Name 'solutionid' -DefaultValue '')"
                uniqueName = "$(Get-FastObjectPropertyValue -InputObject $_ -Name 'uniquename' -DefaultValue '')"
                friendlyName = "$(Get-FastObjectPropertyValue -InputObject $_ -Name 'friendlyname' -DefaultValue '')"
                version = "$(Get-FastObjectPropertyValue -InputObject $_ -Name 'version' -DefaultValue '')"
                managed = [bool](Get-FastObjectPropertyValue -InputObject $_ -Name 'ismanaged' -DefaultValue $false)
                publisherId = "$(Get-FastObjectPropertyValue -InputObject $_ -Name '_publisherid_value' -DefaultValue '')"
                publisherUniqueName = "$(Get-FastObjectPropertyValue -InputObject $publisher -Name 'uniquename' -DefaultValue '')"
                publisherPrefix = "$(Get-FastObjectPropertyValue -InputObject $publisher -Name 'customizationprefix' -DefaultValue '')"
            }
        })
    } catch {
        $message = "$($_.Exception.Message)"
        if ($message -match 'HTTP 403') {
            $permissionLimitations.Add('The caller cannot read installed solution and publisher metadata.') | Out-Null
        }
        $inspectionErrors.Add([pscustomobject]@{ code = 'solutions.unverified'; message = $message }) | Out-Null
    }

    $tableRecords = [Collections.Generic.List[object]]::new()
    $tableRequirements = @($SelectedPackages | ForEach-Object {
        $package = $_
        @($package.tables | ForEach-Object {
            [pscustomobject]@{
                moduleId = "$($package.moduleId)"
                solutionUniqueName = "$($package.solution.uniqueName)"
                logicalName = "$($_.logicalName)"
            }
        })
    })
    $uniqueTableNames = @($tableRequirements.logicalName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $foundTables = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($tableChunk in @(Split-FastCollection -InputObject $uniqueTableNames -Size 20)) {
        $filter = @($tableChunk | ForEach-Object {
            "LogicalName eq '$(ConvertTo-WizardODataLiteral $_)'"
        }) -join ' or '
        try {
            $tableResponse = & $invokeGet "EntityDefinitions?`$select=MetadataId,LogicalName,SchemaName&`$filter=$filter" 'read-metadata'
            foreach ($table in @(Get-FastObjectPropertyValue -InputObject $tableResponse -Name 'value' -DefaultValue @())) {
                $foundTables.Add("$(Get-FastObjectPropertyValue -InputObject $table -Name 'LogicalName' -DefaultValue '')") | Out-Null
            }
        } catch {
            $message = "$($_.Exception.Message)"
            if ($message -match 'HTTP 403') {
                $permissionLimitations.Add('The caller cannot read table metadata.') | Out-Null
            }
            $inspectionErrors.Add([pscustomobject]@{ code = 'tables.unverified'; message = $message }) | Out-Null
            break
        }
    }
    foreach ($requirement in $tableRequirements) {
        $tableRecords.Add([pscustomobject][ordered]@{
            moduleId = $requirement.moduleId
            solutionUniqueName = $requirement.solutionUniqueName
            logicalName = $requirement.logicalName
            found = $foundTables.Contains($requirement.logicalName)
            verificationState = if ($permissions.Contains('read-metadata')) { 'verified' } else { 'unverified' }
        }) | Out-Null
    }

    $dependencyAssessments = [Collections.Generic.List[object]]::new()
    $satisfiedDependencyKeys = [Collections.Generic.List[string]]::new()
    $dependencyQueries = [Collections.Generic.List[object]]::new()
    foreach ($package in @($SelectedPackages)) {
        foreach ($dependency in @($package.declaredDependencies)) {
            $key = Get-FastDependencyKey -Dependency $dependency
            $query = Get-FastDependencyQueryDefinition -Dependency $dependency -PackageMetadata $SelectedPackages
            if ($null -eq $query) {
                $dependencyAssessments.Add([pscustomobject][ordered]@{
                    packageId = "$($package.packageId)"
                    key = $key
                    type = "$($dependency.required.type)"
                    displayName = "$($dependency.required.displayName)"
                    status = 'unverified'
                    evidence = 'No supported read-only component query is defined for this dependency identity.'
                }) | Out-Null
                continue
            }
            $dependencyQueries.Add([pscustomobject]@{
                Package = $package
                Dependency = $dependency
                Key = $key
                Query = $query
            }) | Out-Null
        }
    }

    foreach ($queryGroup in @($dependencyQueries | Group-Object { $_.Query.Group })) {
        foreach ($queryChunk in @(Split-FastCollection -InputObject $queryGroup.Group -Size 20)) {
            $firstQuery = $queryChunk[0].Query
            $filters = @($queryChunk.Query.Filter | Sort-Object -Unique)
            $path = "$($firstQuery.EntitySet)?`$select=$($firstQuery.Select)&`$filter=$($filters -join ' or ')"
            try {
                $componentResponse = & $invokeGet $path "read-component-$($firstQuery.Group)"
                $components = @(Get-FastObjectPropertyValue -InputObject $componentResponse -Name 'value' -DefaultValue @())
                foreach ($queryRecord in $queryChunk) {
                    $query = $queryRecord.Query
                    $dependency = $queryRecord.Dependency
                    $matches = @($components | Where-Object {
                        [string]::Equals(
                            "$(Get-FastObjectPropertyValue -InputObject $_ -Name $query.MatchProperty -DefaultValue '')".Trim('{}'),
                            "$($query.MatchValue)".Trim('{}'),
                            [StringComparison]::OrdinalIgnoreCase
                        )
                    })
                    $status = if ($matches.Count -eq 1) { 'satisfied' } elseif ($matches.Count -eq 0) { 'missing' } else { 'incompatible' }
                    if ($status -eq 'satisfied') {
                        $satisfiedDependencyKeys.Add($queryRecord.Key) | Out-Null
                    }
                    $dependencyAssessments.Add([pscustomobject][ordered]@{
                        packageId = "$($queryRecord.Package.packageId)"
                        key = $queryRecord.Key
                        type = "$($dependency.required.type)"
                        displayName = "$($dependency.required.displayName)"
                        status = $status
                        evidence = "Dataverse $($query.Group) query returned $($matches.Count) exact match(es)."
                    }) | Out-Null
                }
            } catch {
                $message = "$($_.Exception.Message)"
                $inspectionErrors.Add([pscustomobject]@{ code = 'dependency.unverified'; message = $message }) | Out-Null
                foreach ($queryRecord in $queryChunk) {
                    $dependency = $queryRecord.Dependency
                    if ($message -match 'HTTP 403') {
                        $permissionLimitations.Add("The caller cannot verify dependency '$($dependency.required.displayName)'.") | Out-Null
                    }
                    $dependencyAssessments.Add([pscustomobject][ordered]@{
                        packageId = "$($queryRecord.Package.packageId)"
                        key = $queryRecord.Key
                        type = "$($dependency.required.type)"
                        displayName = "$($dependency.required.displayName)"
                        status = 'unverified'
                        evidence = $message
                    }) | Out-Null
                }
            }
        }
    }

    $installedFastModules = @($installedSolutions | Where-Object {
        "$($_.uniqueName)" -like 'appbase_*'
    } | Sort-Object uniqueName)
    $environmentId = "$(Get-FastObjectPropertyValue -InputObject $identity -Name 'OrganizationId' -DefaultValue '')"
    $fingerprintInput = [ordered]@{
        environmentId = $environmentId
        organizationVersion = $organizationVersion
        solutions = @($installedSolutions | Sort-Object uniqueName)
        tables = @($tableRecords | Sort-Object moduleId, logicalName)
        dependencies = @($dependencyAssessments | Sort-Object packageId, key)
        permissions = @($permissions | Sort-Object)
    }
    $metadataFingerprint = Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $fingerprintInput)
    $expiresAt = $NowUtc.ToUniversalTime().Add($CacheTimeToLive)
    $evidence = [pscustomobject][ordered]@{
        accessState = if ($permissionLimitations.Count -gt 0) { 'insufficient-permissions' } else { 'connected' }
        connected = $true
        environmentId = $environmentId
        environmentUrl = $normalizedUrl
        tenantId = $TenantId
        organizationVersion = $organizationVersion
        collectedAtUtc = $NowUtc.ToUniversalTime().ToString('o')
        installedSolutions = $installedSolutions
        installedFastModules = $installedFastModules
        requiredTables = @($tableRecords.ToArray())
        dependencyAssessments = @($dependencyAssessments.ToArray())
        satisfiedDependencyKeys = @($satisfiedDependencyKeys.ToArray())
        permissions = @($permissions | Sort-Object)
        permissionLimitations = @($permissionLimitations | Sort-Object -Unique)
        inspectionErrors = @($inspectionErrors.ToArray())
        metadataFingerprint = $metadataFingerprint
        requestCount = $requestLog.Count
        cache = [pscustomobject]@{
            hit = $false
            cacheKey = $cacheKey
            expiresAtUtc = $expiresAt.ToString('o')
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($cachePath)) {
        Set-FastCachedEnvironmentInspection `
            -CachePath $cachePath `
            -CacheKey $cacheKey `
            -Evidence $evidence `
            -ExpiresAtUtc $expiresAt
    }
    return $evidence
}
