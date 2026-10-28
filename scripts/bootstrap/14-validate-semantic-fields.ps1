<#
=============================================================================
COMPONENT:    Semantic Planning and Metadata Gate
FILE:         scripts/bootstrap/14-validate-semantic-fields.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API
OVERVIEW:     Planning precedes generation; Payload precedes builds; Metadata
              validates deployed attributes and relationships using GET only.
ARCHITECTURE: Shared semantic helper and resilient Dataverse runtime.
TEST CASES:   Credential-free planning; missing inventory and drift stop builds.
NON-NEGOTIABLES: No default types, inferred approval, publication or migrations.
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')] [string]$ScenarioSlug,
    [ValidateSet('Planning', 'Payload', 'Metadata')] [string]$Mode = 'Planning',
    [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$PayloadsFolder = '',
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers\dataverse-runtime.ps1')
. (Join-Path $PSScriptRoot 'helpers\semantic-fields.ps1')
$paths = Resolve-WizardScenarioPaths -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder
$plan = Read-WizardSemanticPlan -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug
if ($Mode -ne 'Planning') {
    Assert-WizardSemanticPayloads -Plan $plan -PayloadsFolder $paths.PayloadFolder
}
if ($Mode -eq 'Metadata') {
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
        $environment = Import-WizardEnvironment -RepoRoot $RepoRoot
        $EnvironmentUrl = $environment.EnvironmentUrl
        $AccessToken = $environment.AccessToken
    }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) { throw 'Live semantic metadata validation requires existing authentication.' }
    $read = {
        param($path)
        Invoke-WizardDataverseRequest -Method Get -Path $path -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -RequestInvoker $RequestInvoker
    }
    $results = [Collections.Generic.List[object]]::new()
    $failure = $null
    foreach ($field in $plan.fields) {
        $live = $null
        try {
            $live = Get-WizardSemanticLiveAttribute -Field $field -ReadMetadata $read
            Assert-WizardSemanticLiveField -Field $field -Live $live -ReadMetadata $read -PayloadsFolder $paths.PayloadFolder
            $results.Add(@{ table = $field.table; field = $field.field; metadataId = $live.MetadataId; expectedType = $field.expectedMetadata['@odata.type']; actualType = $live.AttributeTypeName.Value; status = 'verified'; dependencies = $field.dependencies })
        } catch {
            $actualType = if ($null -ne $live -and $live.Contains('AttributeTypeName')) { $live.AttributeTypeName.Value } else { $_.Exception.Data['ActualType'] }
            $results.Add(@{ table = $field.table; field = $field.field; expectedType = $field.expectedMetadata['@odata.type']; actualType = $actualType; status = 'blocked'; error = $_.Exception.Message; dependencies = $field.dependencies })
            $failure = $_
            break
        }
    }
    $reportFolder = Join-Path $RepoRoot ".wizard-metrics\artifacts\semantic-fields\$ScenarioSlug"
    New-Item -ItemType Directory -Path $reportFolder -Force | Out-Null
    $reportPath = Join-Path $reportFolder 'metadata-report.json'
    @{ scenarioSlug = $ScenarioSlug; environmentUrl = $EnvironmentUrl; observedAtUtc = [DateTime]::UtcNow.ToString('o'); status = $(if ($null -eq $failure) { 'verified' } else { 'blocked' }); plannedFieldCount = $plan.fields.Count; results = @($results.ToArray()); functionalValidation = 'not-proven-by-metadata' } |
        ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Host "Semantic metadata evidence: $reportPath"
    if ($null -ne $failure) { throw $failure }
}
Write-Host "Semantic $Mode gate passed: $($plan.fields.Count) field decisions for $ScenarioSlug. Functional surface validation remains required." -ForegroundColor Green
