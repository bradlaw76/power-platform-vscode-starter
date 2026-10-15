<#
=============================================================================
COMPONENT:    FAST Environment Preflight Tests
FILE:         scripts/ci/test-fast-environment-preflight.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Mocked read-only evidence
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$evidenceRoot = Join-Path $repoRoot 'specs/fast-solution-accelerator-discovery/evidence/pkg'
. (Join-Path $repoRoot 'scripts/accelerators/environment-compatibility.ps1')

$core = Get-Content -LiteralPath (Join-Path $evidenceRoot 'core.json') -Raw | ConvertFrom-Json
$investigations = Get-Content -LiteralPath (Join-Path $evidenceRoot 'investigations.json') -Raw | ConvertFrom-Json
$packages = @($core, $investigations)
$snapshotId = "sha256:$('a' * 64)"
$now = [datetime]'2026-10-15T12:00:00Z'

$catalog = Test-FastCatalogCompatibility -ScenarioSlug fixture -CatalogSnapshotId $snapshotId -SelectedPackages $packages
if ($catalog.status -ne 'action-required' -or
    @($catalog.checks | Where-Object code -eq 'dependency.environment-resolution-required').Count -lt 4) {
    throw 'Level 1 did not report package dependencies requiring environment resolution.'
}

$dependencyKeys = @($packages.declaredDependencies | ForEach-Object {
    Get-FastDependencyKey -Dependency $_
})
$readyEvidence = [pscustomobject]@{
    accessState = 'connected'
    connected = $true
    environmentId = 'environment-1'
    environmentUrl = 'https://fixture.crm.dynamics.com'
    tenantId = 'tenant-1'
    collectedAtUtc = $now.ToString('o')
    installedSolutions = @($packages | ForEach-Object {
        [pscustomobject]@{
            uniqueName = $_.solution.uniqueName
            version = $_.solution.version
            publisherUniqueName = $_.publisher.uniqueName
            publisherPrefix = $_.publisher.customizationPrefix
        }
    })
    satisfiedDependencyKeys = $dependencyKeys
    permissions = @('read-solutions', 'read-metadata')
}
$ready = Test-FastEnvironmentPreflight -ScenarioSlug fixture -CatalogSnapshotId $snapshotId -SelectedPackages $packages -EnvironmentEvidence $readyEvidence -NowUtc $now
if ($ready.status -ne 'ready') {
    throw 'Level 2 ready fixture did not return ready.'
}
$validationSchema = Join-Path $repoRoot 'schemas/accelerators/environment-validation.schema.json'
if (-not (Test-Json -Json ($catalog | ConvertTo-Json -Depth 100) -SchemaFile $validationSchema -ErrorAction Stop) -or
    -not (Test-Json -Json ($ready | ConvertTo-Json -Depth 100) -SchemaFile $validationSchema -ErrorAction Stop)) {
    throw 'Generated environment validation evidence does not match its schema.'
}

$missing = $readyEvidence | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$missing.installedSolutions = @($readyEvidence.installedSolutions | Where-Object uniqueName -ne $investigations.solution.uniqueName)
if ((Test-FastEnvironmentPreflight -ScenarioSlug fixture -CatalogSnapshotId $snapshotId -SelectedPackages $packages -EnvironmentEvidence $missing -NowUtc $now).status -ne 'action-required') {
    throw 'Missing specialty solution did not return action-required.'
}

$incompatible = $readyEvidence | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$incompatible.installedSolutions = @(
    [pscustomobject]@{ uniqueName = $core.solution.uniqueName; version = '1.0.0.0' },
    $readyEvidence.installedSolutions[1]
)
if ((Test-FastEnvironmentPreflight -ScenarioSlug fixture -CatalogSnapshotId $snapshotId -SelectedPackages $packages -EnvironmentEvidence $incompatible -NowUtc $now).status -ne 'incompatible') {
    throw 'Older installed Core did not return incompatible.'
}

$stale = $readyEvidence | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$stale.collectedAtUtc = $now.AddDays(-2).ToString('o')
if ((Test-FastEnvironmentPreflight -ScenarioSlug fixture -CatalogSnapshotId $snapshotId -SelectedPackages $packages -EnvironmentEvidence $stale -NowUtc $now).status -ne 'unverified') {
    throw 'Stale evidence did not return unverified.'
}

foreach ($accessState in @('offline', 'user-declined')) {
    $unavailable = $readyEvidence | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $unavailable.accessState = $accessState
    $unavailable.connected = $false
    $result = Test-FastEnvironmentPreflight -ScenarioSlug fixture -CatalogSnapshotId $snapshotId -SelectedPackages $packages -EnvironmentEvidence $unavailable -NowUtc $now
    if ($result.status -ne 'unverified' -or @($result.checks | Where-Object code -eq "environment.$accessState").Count -ne 1) {
        throw "Access state '$accessState' did not return explicit unverified evidence."
    }
}

$customGate = Test-FastDependentBuildGate -Architecture fully-custom -CurrentCatalogSnapshotId $snapshotId -CurrentEnvironmentId environment-1
if (-not $customGate.Allowed) {
    throw 'Fully custom architecture was incorrectly blocked by the FAST gate.'
}
$readyGate = Test-FastDependentBuildGate -Architecture hybrid -ValidationEvidence $ready -CurrentCatalogSnapshotId $snapshotId -CurrentEnvironmentId environment-1 -SelectedPackages $packages -NowUtc $now
if (-not $readyGate.Allowed) {
    throw 'Fresh ready evidence did not open the FAST-dependent build gate.'
}
$staleGate = Test-FastDependentBuildGate -Architecture hybrid -ValidationEvidence $ready -CurrentCatalogSnapshotId $snapshotId -CurrentEnvironmentId environment-1 -SelectedPackages $packages -NowUtc $now.AddDays(2)
if ($staleGate.Allowed) {
    throw 'Stale evidence incorrectly opened the FAST-dependent build gate.'
}

$plan = New-FastInstallationVerificationPlan -ScenarioSlug fixture -CatalogSnapshotId $snapshotId -SelectedPackages $packages -EnvironmentId environment-1
if ($plan.executionImplemented -or $plan.authorized) {
    throw 'Level 3 must remain an unauthorized, unimplemented workflow plan in FAST-002.'
}

Write-Host 'FAST environment compatibility tests passed.' -ForegroundColor Green
