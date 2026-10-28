<#
=============================================================================
COMPONENT:    Explicit Authenticated Read-only Verification Command
FILE:         scripts/accelerators/invoke-trusted-environment-verification.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Existing credentials | External signing certificate
-----------------------------------------------------------------------------
OVERVIEW
Collects signed target-specific evidence only after explicit scope confirmation.
NON-NEGOTIABLES
No environment-file fallback, automatic login, certificate generation or writes.
=============================================================================
#>
[CmdletBinding()]
param(
    [switch]$EnableAuthenticatedVerification,
    [switch]$ConfirmReadOnlyScope,
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [Parameter(Mandatory)] [string]$EnvironmentUrl,
    [Parameter(Mandatory)] [guid]$EnvironmentId,
    [Parameter(Mandatory)] [guid]$TenantId,
    [Parameter(Mandatory)] [string]$SolutionUniqueName,
    [Parameter(Mandatory)] [Security.Cryptography.X509Certificates.X509Certificate2]$SigningCertificate,
    [ValidateSet('Live', 'Mock')] [string]$CollectionMode = 'Mock',
    [string]$PackageManifestPath = '',
    [string]$WorkspaceRoot = '',
    [string]$OutputFolder = '',
    [ValidateRange(1, 3600)] [int]$EvidenceTimeToLiveSeconds = 900,
    [scriptblock]$TokenProvider,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'trusted-environment-verification.ps1')
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { $WorkspaceRoot = $adapterRoot }
$WorkspaceRoot = [IO.Path]::GetFullPath($WorkspaceRoot)
if ([string]::IsNullOrWhiteSpace($OutputFolder)) { $OutputFolder = "specs\$ScenarioSlug\accelerator\verification" }
$outputPath = Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path (Join-Path $OutputFolder 'trusted-environment-verification.json')
$paths = Get-ExecutionPlanningPaths -WorkspaceRoot $WorkspaceRoot -ScenarioSlug $ScenarioSlug
$protectedInputs = @($paths.Values) + @("specs\$ScenarioSlug\accelerator\build-plan\build-plan-manifest.json", $PackageManifestPath)
$manifestPath = if (-not [string]::IsNullOrWhiteSpace($PackageManifestPath)) {
    Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $PackageManifestPath
} elseif ($paths.Contains('packageManifest')) { $paths.packageManifest } else { '' }
if (-not [string]::IsNullOrWhiteSpace($manifestPath)) {
    $manifest = Read-BuildPlanningJson -Path $manifestPath
    if (-not (Test-ExecutionSchema $manifest 'package-input-manifest')) { throw 'Package manifest is not valid for output protection.' }
    foreach ($entry in $manifest.packages) {
        $protectedInputs += if ([IO.Path]::IsPathRooted($entry.path)) { $entry.path } else { Join-Path (Split-Path $manifestPath -Parent) $entry.path }
    }
}
foreach ($inputPath in $protectedInputs) {
    if (-not [string]::IsNullOrWhiteSpace($inputPath) -and $outputPath -ieq (Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $inputPath)) {
        throw 'Verification output cannot overwrite a planning input.'
    }
}
$envelope = Invoke-TrustedEnvironmentVerification -EnableAuthenticatedVerification:$EnableAuthenticatedVerification `
    -ConfirmReadOnlyScope:$ConfirmReadOnlyScope -WorkspaceRoot $WorkspaceRoot -ScenarioSlug $ScenarioSlug `
    -EnvironmentUrl $EnvironmentUrl -EnvironmentId $EnvironmentId -TenantId $TenantId -SolutionUniqueName $SolutionUniqueName `
    -SigningCertificate $SigningCertificate -CollectionMode $CollectionMode -PackageManifestPath $PackageManifestPath `
    -EvidenceTimeToLiveSeconds $EvidenceTimeToLiveSeconds -TokenProvider $TokenProvider -RequestInvoker $RequestInvoker
New-Item -ItemType Directory -Path (Split-Path $outputPath -Parent) -Force | Out-Null
Set-Content -LiteralPath $outputPath -Value ($envelope | ConvertTo-Json -Depth 100) -Encoding utf8NoBOM
Write-Host "GET-only verification complete=$($envelope.payload.complete); mode=$CollectionMode. No execution is authorized. Evidence: $outputPath"
return $envelope
