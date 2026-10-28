<#
=============================================================================
COMPONENT:    Build Columns
FILE:         scripts/bootstrap/30-build-columns.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Creates approved Dataverse columns on standard or custom tables according to
the scenario mapping and payload definitions.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          column payloads and approved semantic field inventory
- Outputs:         verified columns/IDs, scoped publication and build artifacts
- Dependencies:    Dataverse Web API, planning files, repo helpers
- Side Effects:    creates Dataverse metadata and local telemetry/artifacts

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Table mapping and payload readiness rules must already be satisfied.
2. Required tables must exist or be reusable in the target environment.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Approved custom fields are created on the intended tables.
✔ Existing wrong-type fields stop before any column creation.
✔ Only a genuine 404 permits creation; other metadata read failures propagate.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v1.0.0  2026-10-19  Enforced semantic planning, metadata drift and scoped publish.
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Respect the standard-vs-custom mapping from planning.
- Avoid duplicate custom field creation on rerun where supported.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Adds columns to existing Dataverse tables from columns-*.json payload files.
    Safe to rerun: verifies existing metadata against approved semantic decisions.

.PARAMETER EnvironmentUrl  Defaults to $env:DV_ENVIRONMENT_URL (set by 10-auth-connect.ps1).
.PARAMETER AccessToken     Defaults to $env:DV_TOKEN.
.PARAMETER PayloadsFolder  Folder containing columns-*.json. Defaults to ../../payloads.

.EXAMPLE
    pwsh ./scripts/bootstrap/30-build-columns.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken    = $env:DV_TOKEN,
    [string]$PayloadsFolder = "",
    [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')]
    [string]$ScenarioSlug,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers\dataverse-runtime.ps1')
. (Join-Path $PSScriptRoot 'helpers\semantic-fields.ps1')
if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    if (-not [string]::IsNullOrWhiteSpace($PayloadsFolder) -and
        (Split-Path (Split-Path $PayloadsFolder -Parent) -Leaf) -eq 'scenarios') {
        $ScenarioSlug = Split-Path $PayloadsFolder -Leaf
    } else { throw 'Stage 30 requires ScenarioSlug or an unambiguous scenario payload folder.' }
}
$paths = Resolve-WizardScenarioPaths -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder
$PayloadsFolder = $paths.PayloadFolder
$semanticPlan = Read-WizardSemanticPlan -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug
$approvedColumns = Assert-WizardSemanticPayloads -Plan $semanticPlan -PayloadsFolder $PayloadsFolder -PassThru
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "30-build-columns.ps1"
}

$hardeningHelper = Join-Path $PSScriptRoot "helpers\wizard-hardening.ps1"
if (Test-Path $hardeningHelper) {
    . $hardeningHelper
}

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile; $EnvironmentUrl = $global:DV_ENVIRONMENT_URL; $AccessToken = $global:DV_TOKEN
}
$scenarioContext = if (Get-Command Get-WizardScenarioContext -ErrorAction SilentlyContinue) {
    Get-WizardScenarioContext -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder
} else { $null }
$solutionName = if (Get-Variable global:DV_SOLUTION_NAME -ErrorAction SilentlyContinue) { $global:DV_SOLUTION_NAME } else { '' }
$publisherPrefix = if (Get-Variable global:DV_PUBLISHER_PREFIX -ErrorAction SilentlyContinue) { $global:DV_PUBLISHER_PREFIX } else { '' }
if (Get-Command Initialize-WizardArtifactManifest -ErrorAction SilentlyContinue) {
    Initialize-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix | Out-Null
}
if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "Run 10-auth-connect.ps1 first." -ForegroundColor Red; exit 1
}
if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path $repoRoot "payloads"
}

if (-not (Test-Path $PayloadsFolder)) {
    Write-Host "Payload folder not found: $PayloadsFolder" -ForegroundColor Red
    Write-Host "Expected payload location is the repo root 'payloads/' folder." -ForegroundColor Yellow
    exit 1
}

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "") {
    $arguments = @{ Method = $Method; Path = $Path; EnvironmentUrl = $EnvironmentUrl; AccessToken = $AccessToken; RequestInvoker = $RequestInvoker }
    if ($Body) { $arguments.Body = $Body }
    Invoke-WizardDataverseRequest @arguments
}

Write-Host ""
Write-Host "=== Build Columns ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host ""

$created = 0; $skipped = 0; $failed = 0
$creationFailure = $null
$createdFields = [Collections.Generic.List[object]]::new()
$readMetadata = { param($path) Invoke-Dv 'Get' $path }
$missing = [Collections.Generic.List[object]]::new()
$changedTables = [Collections.Generic.HashSet[string]]::new()
$stageFields = @($semanticPlan.fields | Where-Object { $_.disposition -ne 'create-relationship' })
foreach ($field in $stageFields) {
    $live = Get-WizardSemanticLiveAttribute -Field $field -ReadMetadata $readMetadata -AllowMissing:($field.disposition -eq 'create-column')
    if ($null -eq $live) { $missing.Add($field); continue }
    Assert-WizardSemanticLiveField -Field $field -Live $live -ReadMetadata $readMetadata -PayloadsFolder $PayloadsFolder -AllowBasePresentation
    $skipped++
    Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'column' -Name "$($field.table).$($field.field)" -Status 'skipped' -Step '30-build-columns.ps1' -Details @{ metadataId = $live.MetadataId; reason = 'existing metadata matches approved semantic decision' } | Out-Null
}
foreach ($field in $missing) {
    if ($field.Contains('choice') -and $field.choice.scope -eq 'global') {
        $set = Invoke-Dv 'Get' "GlobalOptionSetDefinitions(Name='$($field.choice.name)')"
        $set = $set | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable
        Assert-SemanticValue @{
            IsGlobal = $true
            Name = $field.choice.name
            Options = @($field.choice.options | ForEach-Object { @{ Value = $_.value; Label = $_.labels } })
        } $set "$($field.table).$($field.field).GlobalOptionSet"
    }
}
foreach ($field in $missing) {
    try {
        $body = $approvedColumns["$($field.table).$($field.field)"] | ConvertTo-Json -Depth 40 -Compress
        Invoke-Dv 'Post' "EntityDefinitions(LogicalName='$($field.table)')/Attributes" $body | Out-Null
        $changedTables.Add($field.table) | Out-Null
        $createdFields.Add($field)
        $created++
    } catch {
        Register-WizardStepFailure -Message "Column creation failed: $($field.table).$($field.field)."
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'column' -Name "$($field.table).$($field.field)" -Status 'failed' -Step '30-build-columns.ps1' -Details @{ error = $_.Exception.Message } | Out-Null
        $failed++
        $creationFailure = $_
        break
    }
}
if ($changedTables.Count -gt 0) {
    Publish-WizardCustomizations -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -ParameterXml (New-WizardEntityPublishXml -EntityLogicalNames @($changedTables)) -RequestInvoker $RequestInvoker | Out-Null
}
foreach ($field in $createdFields) {
    $live = Get-WizardSemanticLiveAttribute -Field $field -ReadMetadata $readMetadata
    Assert-WizardSemanticLiveField -Field $field -Live $live -ReadMetadata $readMetadata
    Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'column' -Name "$($field.table).$($field.field)" -Status 'created' -Step '30-build-columns.ps1' -Details @{ metadataId = $live.MetadataId; semanticDecision = $field.decisionId; validated = $true } | Out-Null
}

Write-Host ""
Write-Host "Columns — created: $created  skipped: $skipped  failed: $failed"
if ($failed -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Column build failed for one or more payloads."
    }
    throw $creationFailure
}
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/40-build-relationships.ps1"
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Column build completed."
}
