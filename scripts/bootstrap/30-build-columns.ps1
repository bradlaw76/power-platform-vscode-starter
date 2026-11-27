<#
=============================================================================
COMPONENT:    Build Columns
FILE:         scripts/bootstrap/30-build-columns.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-11-27
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
- Outputs:         verified column IDs, scoped publication and build artifacts
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
✔ Reused standard fields are not recreated as custom metadata.
✔ Wrong-type metadata blocks all creation; only genuine 404 allows creation.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
2026-11-27  Q13-R9B accept approved base Choice presentation during created readback.
2026-11-26  Q13-R7 selective semantic enforcement; alternate-key/retry paths retained.
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
    [switch]$PreviewOnly,
    [scriptblock]$TokenProvider,
    [scriptblock]$RequestInvoker,
    [scriptblock]$SleepAction,
    [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')]
    [string]$ScenarioSlug
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

. (Join-Path $PSScriptRoot "helpers\dataverse-runtime.ps1")
. (Join-Path $PSScriptRoot "helpers\alternate-keys.ps1")

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if (-not $PreviewOnly -and (Test-Path $envFile)) {
    . $envFile
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
        $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        $AccessToken = $global:DV_TOKEN
    }
}
$scenarioContext = if (Get-Command Get-WizardScenarioContext -ErrorAction SilentlyContinue) {
    Get-WizardScenarioContext -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder
} else { $null }
$solutionName = if (Get-Variable global:DV_SOLUTION_NAME -ErrorAction SilentlyContinue) { $global:DV_SOLUTION_NAME } elseif ($env:DV_SOLUTION_NAME) { $env:DV_SOLUTION_NAME } else { '' }
$publisherPrefix = if (Get-Variable global:DV_PUBLISHER_PREFIX -ErrorAction SilentlyContinue) { $global:DV_PUBLISHER_PREFIX } elseif ($env:DV_PUBLISHER_PREFIX) { $env:DV_PUBLISHER_PREFIX } else { '' }
if (-not $PreviewOnly -and (Get-Command Initialize-WizardArtifactManifest -ErrorAction SilentlyContinue)) {
    Initialize-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix | Out-Null
}
if (-not $PreviewOnly -and ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken))) {
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
    $requestBody = if ([string]::IsNullOrWhiteSpace($Body)) { $null } else { $Body }
    return Invoke-WizardDataverseRequest -Method $Method -Path $Path -EnvironmentUrl $EnvironmentUrl `
        -AccessToken $AccessToken -Body $requestBody -TokenProvider $TokenProvider `
        -RequestInvoker $RequestInvoker -SleepAction $SleepAction
}

Write-Host ""
Write-Host "=== Build Columns ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host ""

$payloads = @(Get-ChildItem -Path $PayloadsFolder -Filter "columns-*.json" -ErrorAction SilentlyContinue)
$keyPayloads = @(Get-ChildItem -Path $PayloadsFolder -Filter "keys-*.json" -ErrorAction SilentlyContinue)
if ($payloads.Count -eq 0 -and $keyPayloads.Count -eq 0) {
    Write-Host "No columns-*.json or keys-*.json found in: $PayloadsFolder" -ForegroundColor Yellow
    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message "No column or alternate-key payloads found."
    }
}
if ($payloads.Count -eq 0) {
    Write-Host "No columns-*.json found; processing alternate-key declarations only." -ForegroundColor DarkGray
}

$created = 0; $skipped = 0; $failed = 0
$creationFailure = $null
$createdFields = [Collections.Generic.List[object]]::new()
$readMetadata = { param($path) Invoke-Dv 'Get' $path }
$missing = [Collections.Generic.List[object]]::new()
$changedTables = [Collections.Generic.HashSet[string]]::new()
$stageFields = @($semanticPlan.fields | Where-Object { $_.disposition -ne 'create-relationship' })
foreach ($field in $stageFields) {
    if ($PreviewOnly) { $skipped++; continue }
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
    Publish-WizardCustomizations -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -ParameterXml (New-WizardEntityPublishXml -EntityLogicalNames @($changedTables)) -TokenProvider $TokenProvider -RequestInvoker $RequestInvoker -SleepAction $SleepAction | Out-Null
}
foreach ($field in $createdFields) {
    $live = Get-WizardSemanticLiveAttribute -Field $field -ReadMetadata $readMetadata
    Assert-WizardSemanticLiveField -Field $field -Live $live -ReadMetadata $readMetadata -PayloadsFolder $PayloadsFolder -AllowBasePresentation
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

$keyCreated = 0; $keyExisting = 0; $keyPlanned = 0
try {
    $keyResults = @(Invoke-WizardAlternateKeyStage -PayloadsFolder $PayloadsFolder `
        -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -PreviewOnly:$PreviewOnly `
        -SolutionUniqueName $solutionName -TokenProvider $TokenProvider `
        -RequestInvoker $RequestInvoker -SleepAction $SleepAction)
    foreach ($result in $keyResults) {
        switch ($result.Action) {
            'created' { $keyCreated++ }
            'existing' { $keyExisting++ }
            'planned' { $keyPlanned++ }
        }
        Write-Host "  Key: $($result.TableLogicalName).$($result.SchemaName) [$($result.KeyAttributes -join ', ')] ($($result.Action))" -ForegroundColor $(if ($result.Action -eq 'created') { 'Green' } else { 'DarkGray' })
        if (-not $PreviewOnly -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'key' -Name "$($result.TableLogicalName).$($result.SchemaName)" -Status $(if ($result.Action -eq 'existing') { 'skipped' } else { $result.Action }) -Step '30-build-columns.ps1' -Details @{
                table = $result.TableLogicalName
                schemaName = $result.SchemaName
                keyAttributes = @($result.KeyAttributes)
                metadataId = $result.MetadataId
                payload = $result.Payload
                solutionMembership = $result.SolutionMembership
            } | Out-Null
        }
    }
} catch {
    $failed++
    Write-Host "Alternate keys FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if (-not $PreviewOnly -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioContext.ScenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix -Kind 'key' -Name '[alternate-key-stage]' -Status 'failed' -Step '30-build-columns.ps1' -Details @{ error = $_.Exception.Message } | Out-Null
    }
}
Write-Host "Keys — created: $keyCreated  existing: $keyExisting  planned: $keyPlanned  failed: $(if ($failed -gt 0) { 1 } else { 0 })"
if ($failed -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Column or alternate-key build failed."
    }
    exit 1
}
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/40-build-relationships.ps1"
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Column build completed."
}
