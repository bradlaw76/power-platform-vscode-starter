<#
=============================================================================
COMPONENT:    FAST Live Environment Preflight Tests
FILE:         scripts/ci/test-fast-live-environment-preflight.ps1
VERSION:      0.2.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Mocked Dataverse responses
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$evidenceRoot = Join-Path $repoRoot 'specs/fast-solution-accelerator-discovery/evidence/pkg'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "fast-live-preflight-$([guid]::NewGuid().ToString('N'))"
$snapshotId = "sha256:$('a' * 64)"
$changedSnapshotId = "sha256:$('b' * 64)"
$now = [datetime]'2026-10-15T12:00:00Z'

. (Join-Path $repoRoot 'scripts/accelerators/dataverse-environment-inspector.ps1')

$core = Get-Content -LiteralPath (Join-Path $evidenceRoot 'core.json') -Raw | ConvertFrom-Json
$investigations = Get-Content -LiteralPath (Join-Path $evidenceRoot 'investigations.json') -Raw | ConvertFrom-Json

function New-FastTestHttpError {
    param(
        [int]$StatusCode,
        [string]$Message = "HTTP $StatusCode",
        [string]$RetryAfter = ''
    )

    $exception = [Exception]::new($Message)
    $response = [pscustomobject]@{ StatusCode = $StatusCode; Headers = @{} }
    if (-not [string]::IsNullOrWhiteSpace($RetryAfter)) {
        $response.Headers['Retry-After'] = $RetryAfter
    }
    $exception | Add-Member -NotePropertyName Response -NotePropertyValue $response
    return [Management.Automation.ErrorRecord]::new($exception, "Http$StatusCode", 'InvalidOperation', $null)
}

function Reset-FastMockState {
    $script:fastMockState = [ordered]@{
        environmentId = '11111111-1111-1111-1111-111111111111'
        organizationVersion = '9.2.26000.100'
        installCore = $true
        coreVersion = $core.solution.version
        installSpecialty = $true
        specialtyVersion = $investigations.solution.version
        missingDependencyGroup = ''
        denySolutions = $false
        authenticationFailure = $false
        timeoutAll = $false
        throttleOnce = $false
        throttled = $false
        requests = [Collections.Generic.List[object]]::new()
        delays = [Collections.Generic.List[int]]::new()
    }
}

$mockInvoker = {
    param($request)
    $marker = '/api/data/v9.2/'
    $path = [Uri]::UnescapeDataString($request.Uri.Substring($request.Uri.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase) + $marker.Length))
    $script:fastMockState.requests.Add([pscustomobject]@{
        Method = $request.Method
        Path = $path
        TimeoutSec = $request.TimeoutSec
    }) | Out-Null

    if ($script:fastMockState.timeoutAll) {
        throw [TimeoutException]::new('simulated Dataverse timeout')
    }
    if ($script:fastMockState.authenticationFailure) {
        throw (New-FastTestHttpError -StatusCode 401 -Message 'HTTP 401 invalid token token-must-not-leak')
    }
    if ($script:fastMockState.throttleOnce -and -not $script:fastMockState.throttled) {
        $script:fastMockState.throttled = $true
        throw (New-FastTestHttpError -StatusCode 429 -RetryAfter '2')
    }
    if ($path -eq 'WhoAmI') {
        return [pscustomobject]@{ OrganizationId = $script:fastMockState.environmentId; UserId = 'user-id' }
    }
    if ($path -eq 'RetrieveVersion()') {
        return [pscustomobject]@{ Version = $script:fastMockState.organizationVersion }
    }
    if ($path -like 'solutions?*') {
        if ($script:fastMockState.denySolutions) {
            throw (New-FastTestHttpError -StatusCode 403)
        }
        $solutions = [Collections.Generic.List[object]]::new()
        if ($script:fastMockState.installCore) {
            $solutions.Add([pscustomobject]@{
                solutionid = 'core-solution-id'
                uniquename = $core.solution.uniqueName
                friendlyname = $core.solution.displayName
                version = $script:fastMockState.coreVersion
                ismanaged = $true
                _publisherid_value = 'publisher-id'
                publisherid = [pscustomobject]@{
                    uniquename = $core.publisher.uniqueName
                    customizationprefix = $core.publisher.customizationPrefix
                }
            }) | Out-Null
        }
        if ($script:fastMockState.installSpecialty) {
            $solutions.Add([pscustomobject]@{
                solutionid = 'specialty-solution-id'
                uniquename = $investigations.solution.uniqueName
                friendlyname = $investigations.solution.displayName
                version = $script:fastMockState.specialtyVersion
                ismanaged = $true
                _publisherid_value = 'publisher-id'
                publisherid = [pscustomobject]@{
                    uniquename = $investigations.publisher.uniqueName
                    customizationprefix = $investigations.publisher.customizationPrefix
                }
            }) | Out-Null
        }
        return [pscustomobject]@{ value = @($solutions.ToArray()) }
    }
    if ($path -like 'EntityDefinitions?*') {
        $matches = [regex]::Matches($path, "LogicalName eq '([^']+)'")
        return [pscustomobject]@{
            value = @($matches | ForEach-Object {
                [pscustomobject]@{ MetadataId = [guid]::NewGuid(); LogicalName = $_.Groups[1].Value; SchemaName = $_.Groups[1].Value }
            })
        }
    }
    if ($path -like "EntityDefinitions(LogicalName='*')/Attributes?*") {
        $matches = [regex]::Matches($path, "LogicalName eq '([^']+)'")
        return [pscustomobject]@{
            value = @($matches | ForEach-Object {
                [pscustomobject]@{ MetadataId = [guid]::NewGuid(); LogicalName = $_.Groups[1].Value }
            })
        }
    }
    if ($path -like 'GlobalOptionSetDefinitions?*') {
        $matches = [regex]::Matches($path, "Name eq '([^']+)'")
        return [pscustomobject]@{
            value = @($matches | ForEach-Object {
                [pscustomobject]@{ MetadataId = [guid]::NewGuid(); Name = $_.Groups[1].Value }
            })
        }
    }
    if ($path -like 'systemforms?*') {
        if ($script:fastMockState.missingDependencyGroup -eq 'systemforms') { return [pscustomobject]@{ value = @() } }
        $matches = [regex]::Matches($path, 'formid eq ([0-9a-f-]+)', 'IgnoreCase')
        return [pscustomobject]@{ value = @($matches | ForEach-Object { [pscustomobject]@{ formid = $_.Groups[1].Value; name = 'Form' } }) }
    }
    if ($path -like 'webresourceset?*') {
        if ($script:fastMockState.missingDependencyGroup -eq 'webresources') { return [pscustomobject]@{ value = @() } }
        $matches = [regex]::Matches($path, "name eq '([^']+)'")
        return [pscustomobject]@{ value = @($matches | ForEach-Object { [pscustomobject]@{ webresourceid = [guid]::NewGuid(); name = $_.Groups[1].Value } }) }
    }
    if ($path -like 'customcontrols?*') {
        if ($script:fastMockState.missingDependencyGroup -eq 'customcontrols') { return [pscustomobject]@{ value = @() } }
        $matches = [regex]::Matches($path, "name eq '([^']+)'")
        return [pscustomobject]@{ value = @($matches | ForEach-Object { [pscustomobject]@{ customcontrolid = [guid]::NewGuid(); name = $_.Groups[1].Value } }) }
    }
    if ($path -like 'settingdefinitions?*') {
        if ($script:fastMockState.missingDependencyGroup -eq 'settingdefinitions') { return [pscustomobject]@{ value = @() } }
        $matches = [regex]::Matches($path, "uniquename eq '([^']+)'")
        return [pscustomobject]@{ value = @($matches | ForEach-Object { [pscustomobject]@{ settingdefinitionid = [guid]::NewGuid(); uniquename = $_.Groups[1].Value } }) }
    }
    throw "Unexpected read-only test request: $path"
}

$sleepAction = {
    param($seconds)
    $script:fastMockState.delays.Add([int]$seconds) | Out-Null
}

function Invoke-FastTestPreflight {
    param(
        [object[]]$Packages = @($core),
        [string]$Snapshot = $snapshotId,
        [string]$EnvironmentUrl = 'https://fixture.crm.dynamics.com',
        [datetime]$AtUtc = $now,
        [timespan]$CacheTtl = ([TimeSpan]::FromMinutes(15)),
        [switch]$ForceRefresh
    )

    $evidence = Invoke-FastDataverseEnvironmentInspection `
        -EnvironmentUrl $EnvironmentUrl `
        -AccessToken 'token-must-not-leak' `
        -CatalogSnapshotId $Snapshot `
        -SelectedPackages $Packages `
        -CacheRoot $tempRoot `
        -CacheTimeToLive $CacheTtl `
        -ForceRefresh:$ForceRefresh `
        -MaxAttempts 2 `
        -RequestTimeoutSec 5 `
        -TokenProvider { 'refreshed-token-must-not-leak' } `
        -RequestInvoker $mockInvoker `
        -SleepAction $sleepAction `
        -NowUtc $AtUtc
    $report = Test-FastEnvironmentPreflight `
        -ScenarioSlug fixture `
        -CatalogSnapshotId $Snapshot `
        -SelectedPackages $Packages `
        -EnvironmentEvidence $evidence `
        -EvidenceTimeToLive $CacheTtl `
        -NowUtc $AtUtc
    return [pscustomobject]@{ Evidence = $evidence; Report = $report }
}

try {
    Reset-FastMockState
    $compatible = Invoke-FastTestPreflight -ForceRefresh
    if ($compatible.Report.status -ne 'ready' -or
        $compatible.Report.evidence.coreAssessment -ne 'installed-and-verified') {
        throw 'Compatible installed Core did not produce ready, environment-verified evidence.'
    }
    if (@($script:fastMockState.requests | Where-Object Method -ne 'Get').Count -ne 0) {
        throw 'Live preflight attempted a Dataverse mutation.'
    }
    if (@($script:fastMockState.requests | Where-Object TimeoutSec -ne 5).Count -ne 0) {
        throw 'Live preflight did not apply the configured bounded request timeout.'
    }

    Reset-FastMockState
    $script:fastMockState.installCore = $false
    $missingCore = Invoke-FastTestPreflight -ForceRefresh
    if ($missingCore.Report.status -ne 'action-required' -or
        $missingCore.Report.evidence.coreAssessment -ne 'missing-prerequisites-potentially-available') {
        throw 'Missing Core with satisfied prerequisites was not classified correctly.'
    }

    Reset-FastMockState
    $script:fastMockState.coreVersion = '1.0.0.0'
    if ((Invoke-FastTestPreflight -ForceRefresh).Report.status -ne 'incompatible') {
        throw 'Wrong Core version did not return incompatible.'
    }

    Reset-FastMockState
    $script:fastMockState.missingDependencyGroup = 'customcontrols'
    $missingDependency = Invoke-FastTestPreflight -ForceRefresh
    if ($missingDependency.Report.status -ne 'action-required' -or
        $missingDependency.Report.evidence.coreAssessment -ne 'installed-incompatible-or-incomplete') {
        throw 'Missing Core dependency was not reported as action-required.'
    }

    Reset-FastMockState
    $script:fastMockState.installSpecialty = $false
    if ((Invoke-FastTestPreflight -Packages @($core, $investigations) -ForceRefresh).Report.status -ne 'action-required') {
        throw 'Missing specialty module did not return action-required.'
    }

    Reset-FastMockState
    if ((Invoke-FastTestPreflight -Packages @($core, $investigations) -ForceRefresh).Report.status -ne 'ready') {
        throw 'Compatible installed specialty module did not return ready.'
    }

    Reset-FastMockState
    $script:fastMockState.specialtyVersion = '1.0.0.0'
    if ((Invoke-FastTestPreflight -Packages @($core, $investigations) -ForceRefresh).Report.status -ne 'incompatible') {
        throw 'Incompatible specialty module did not return incompatible.'
    }

    Reset-FastMockState
    $script:fastMockState.denySolutions = $true
    $permissionFailure = Invoke-FastTestPreflight -ForceRefresh
    if ($permissionFailure.Report.status -ne 'unverified' -or
        $permissionFailure.Evidence.accessState -ne 'insufficient-permissions') {
        throw 'Insufficient solution-read permissions did not return unverified.'
    }

    Reset-FastMockState
    $script:fastMockState.authenticationFailure = $true
    $authenticationFailure = Invoke-FastTestPreflight -ForceRefresh
    if ($authenticationFailure.Report.status -ne 'unverified' -or
        $authenticationFailure.Evidence.accessState -ne 'authentication-failed') {
        throw 'Authentication failure did not return unverified.'
    }
    if (($authenticationFailure | ConvertTo-Json -Depth 100) -match 'token-must-not-leak|refreshed-token-must-not-leak') {
        throw 'Authentication failure evidence exposed credential material.'
    }

    Reset-FastMockState
    $script:fastMockState.throttleOnce = $true
    $throttled = Invoke-FastTestPreflight -ForceRefresh
    if ($throttled.Report.status -ne 'ready' -or $script:fastMockState.delays -notcontains 2) {
        throw 'Dataverse throttling did not honor bounded Retry-After handling.'
    }

    Reset-FastMockState
    $script:fastMockState.timeoutAll = $true
    $timeout = Invoke-FastTestPreflight -ForceRefresh
    if ($timeout.Report.status -ne 'unverified' -or $timeout.Evidence.accessState -ne 'unavailable') {
        throw 'Repeated Dataverse timeout did not return unavailable/unverified.'
    }

    Reset-FastMockState
    $cachedFirst = Invoke-FastTestPreflight -ForceRefresh
    $firstRequestCount = $script:fastMockState.requests.Count
    $script:fastMockState.timeoutAll = $true
    $cachedSecond = Invoke-FastTestPreflight
    if (-not $cachedSecond.Evidence.cache.hit -or $script:fastMockState.requests.Count -ne $firstRequestCount) {
        throw 'Fresh cache was not reused without Dataverse requests.'
    }
    $cacheFiles = @(Get-ChildItem -LiteralPath $tempRoot -Filter '*.json' -File)
    if (@($cacheFiles | Where-Object {
        (Get-Content -LiteralPath $_.FullName -Raw) -match 'token-must-not-leak|refreshed-token-must-not-leak'
    }).Count -ne 0) {
        throw 'A FAST preflight cache file contains credential material.'
    }

    Reset-FastMockState
    $stale = Invoke-FastTestPreflight -AtUtc ($now.AddMinutes(16))
    if ($stale.Evidence.cache.hit -or $script:fastMockState.requests.Count -eq 0) {
        throw "Stale cached validation was not refreshed: hit=$($stale.Evidence.cache.hit) requests=$($script:fastMockState.requests.Count) expires=$($stale.Evidence.cache.expiresAtUtc)"
    }

    Reset-FastMockState
    $catalogChanged = Invoke-FastTestPreflight -Snapshot $changedSnapshotId
    if ($catalogChanged.Evidence.cache.hit -or $script:fastMockState.requests.Count -eq 0) {
        throw 'Catalog snapshot change did not invalidate cached evidence.'
    }

    Reset-FastMockState
    $changedPackage = $core | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $changedPackage.sha256 = 'c' * 64
    $packageChanged = Invoke-FastTestPreflight -Packages @($changedPackage)
    if ($packageChanged.Evidence.cache.hit -or $script:fastMockState.requests.Count -eq 0) {
        throw 'Selected package hash change did not invalidate cached evidence.'
    }

    Reset-FastMockState
    $changedDependency = $core | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $changedDependency.declaredDependencies[0].required.packageVersion = '99.0.0.0'
    $dependencyChanged = Invoke-FastTestPreflight -Packages @($changedDependency)
    if ($dependencyChanged.Evidence.cache.hit -or $script:fastMockState.requests.Count -eq 0) {
        throw 'Dependency version change did not invalidate cached evidence.'
    }

    Reset-FastMockState
    $script:fastMockState.environmentId = '22222222-2222-2222-2222-222222222222'
    $environmentChanged = Invoke-FastTestPreflight -EnvironmentUrl 'https://second.crm.dynamics.com'
    if ($environmentChanged.Evidence.cache.hit -or
        $environmentChanged.Report.environment.environmentId -ne $script:fastMockState.environmentId) {
        throw 'Environment switching did not invalidate cached evidence.'
    }

    Reset-FastMockState
    try {
        & (Join-Path $repoRoot 'scripts/accelerators/invoke-fast-environment-preflight.ps1') `
            -ScenarioSlug fixture `
            -CatalogSnapshotId $snapshotId `
            -SelectedPackagePaths @('specs/fast-solution-accelerator-discovery/evidence/pkg/core.json') `
            -EnvironmentUrl 'https://fixture.crm.dynamics.com' `
            -AccessToken 'token-must-not-leak' `
            -RequestInvoker $mockInvoker
        throw 'Expected default-disabled live preflight failure.'
    } catch {
        if ($_.Exception.Message -notmatch 'disabled by default') {
            throw
        }
    }
    if ($script:fastMockState.requests.Count -ne 0) {
        throw 'Disabled live preflight accessed Dataverse.'
    }

    $schemaPath = Join-Path $repoRoot 'schemas/accelerators/environment-validation.schema.json'
    if (-not (Test-Json -Json ($compatible.Report | ConvertTo-Json -Depth 100) -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw 'Live preflight report does not match the versioned schema.'
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'FAST live environment preflight tests passed.' -ForegroundColor Green
