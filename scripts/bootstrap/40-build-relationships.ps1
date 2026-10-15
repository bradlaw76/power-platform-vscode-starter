<#
=============================================================================
COMPONENT:    Build Relationships
FILE:         scripts/bootstrap/40-build-relationships.ps1
VERSION:      0.2.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-06
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

Creates payload-driven Dataverse 1:N and N:N relationship metadata. Preview is
credential-free; apply uses the shared resilient Dataverse runtime.
=============================================================================
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$PayloadsFolder = '',
    [switch]$PreviewOnly,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$runtimeHelper = Join-Path $PSScriptRoot 'helpers\dataverse-runtime.ps1'
if (-not (Test-Path -LiteralPath $runtimeHelper -PathType Leaf)) {
    throw "Dataverse runtime helper not found: $runtimeHelper"
}
. $runtimeHelper

$telemetryHelper = Join-Path $PSScriptRoot 'helpers\wizard-telemetry.ps1'
if (Test-Path -LiteralPath $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName '40-build-relationships.ps1'
}
$hardeningHelper = Join-Path $PSScriptRoot 'helpers\wizard-hardening.ps1'
if (Test-Path -LiteralPath $hardeningHelper) { . $hardeningHelper }

$envFile = Join-Path $repoRoot '.env.ps1'
if (-not $PreviewOnly -and (Test-Path -LiteralPath $envFile)) {
    . $envFile
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
        $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        $AccessToken = $global:DV_TOKEN
    }
}
if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) { $PayloadsFolder = Join-Path $repoRoot 'payloads' }
if (-not (Test-Path -LiteralPath $PayloadsFolder -PathType Container)) {
    throw "Payload folder not found: $PayloadsFolder"
}
if (-not $PreviewOnly -and ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken))) {
    throw 'Environment URL and access token are required in apply mode. Run 10-auth-connect.ps1 first.'
}

$scenarioContext = if (Get-Command Get-WizardScenarioContext -ErrorAction SilentlyContinue) {
    Get-WizardScenarioContext -RepoRoot $repoRoot -ScenarioSlug '' -PayloadsFolder $PayloadsFolder
} else { $null }
$scenarioSlug = if ($null -ne $scenarioContext) { "$($scenarioContext.ScenarioSlug)" } else { '' }
$solutionName = if (Get-Variable global:DV_SOLUTION_NAME -ErrorAction SilentlyContinue) { "$global:DV_SOLUTION_NAME" } elseif ($env:DV_SOLUTION_NAME) { "$env:DV_SOLUTION_NAME" } else { '' }
$publisherPrefix = if (Get-Variable global:DV_PUBLISHER_PREFIX -ErrorAction SilentlyContinue) { "$global:DV_PUBLISHER_PREFIX" } elseif ($env:DV_PUBLISHER_PREFIX) { "$env:DV_PUBLISHER_PREFIX" } else { '' }
if (-not $PreviewOnly -and -not [string]::IsNullOrWhiteSpace($scenarioSlug) -and
    (Get-Command Initialize-WizardArtifactManifest -ErrorAction SilentlyContinue)) {
    Initialize-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $scenarioSlug -SolutionName $solutionName -PublisherPrefix $publisherPrefix | Out-Null
}

function Get-RelationshipDefinition {
    param([Parameter(Mandatory)] [object]$Relationship)
    return $Relationship.RelationshipDefinition ?? $Relationship
}

function Get-RelationshipKind {
    param([Parameter(Mandatory)] [object]$Definition)

    $odataType = "$($Definition.'@odata.type')"
    if ($odataType -eq 'Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata') { return 'ManyToMany' }
    if ([string]::IsNullOrWhiteSpace($odataType) -or $odataType -eq 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata') {
        return 'OneToMany'
    }
    throw "Unsupported relationship metadata type '$odataType'."
}

function Assert-RelationshipPayload {
    param([Parameter(Mandatory)] [object]$Relationship, [Parameter(Mandatory)] [string]$PayloadName)

    $definition = Get-RelationshipDefinition -Relationship $Relationship
    $schema = "$($definition.SchemaName)".Trim()
    $wrapperSchema = "$($Relationship.SchemaName)".Trim()
    if ([string]::IsNullOrWhiteSpace($schema)) { throw "$PayloadName contains a relationship without RelationshipDefinition.SchemaName." }
    if ($schema -cnotmatch '^[A-Za-z][A-Za-z0-9_]*$') { throw "$PayloadName contains invalid relationship SchemaName '$schema'." }
    if (-not [string]::IsNullOrWhiteSpace($wrapperSchema) -and
        -not $wrapperSchema.Equals($schema, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$PayloadName wrapper SchemaName '$wrapperSchema' does not match definition SchemaName '$schema'."
    }

    $kind = Get-RelationshipKind -Definition $definition
    $required = if ($kind -eq 'ManyToMany') {
        @('Entity1LogicalName', 'Entity2LogicalName', 'IntersectEntityName')
    } else {
        @('ReferencedEntity', 'ReferencedAttribute', 'ReferencingEntity', 'ReferencingAttribute')
    }
    foreach ($name in $required) {
        if ([string]::IsNullOrWhiteSpace("$($definition.$name)")) {
            throw "$PayloadName relationship '$schema' is missing required $kind property '$name'."
        }
    }
    if ($kind -eq 'ManyToMany') {
        foreach ($forbidden in @('CascadeConfiguration', 'Lookup', 'ReferencedAttribute', 'ReferencingAttribute')) {
            if ($null -ne $definition.PSObject.Properties[$forbidden]) {
                throw "$PayloadName N:N relationship '$schema' must not specify '$forbidden'. N:N metadata has no cascade contract."
            }
        }
    }
    return [pscustomobject]@{ SchemaName = $schema; Kind = $kind; Definition = $definition }
}

function ConvertTo-DataverseRelationshipMetadata {
    param([Parameter(Mandatory)] [object]$Relationship)

    $definition = Get-RelationshipDefinition -Relationship $Relationship
    $kind = Get-RelationshipKind -Definition $definition
    $metadata = [ordered]@{}
    foreach ($property in $definition.PSObject.Properties) {
        if ($kind -eq 'ManyToMany' -or $property.Name -ne 'ReferencingAttribute') {
            $metadata[$property.Name] = $property.Value
        }
    }
    if ($kind -eq 'OneToMany') {
        if (-not $metadata.Contains('@odata.type')) {
            $metadata['@odata.type'] = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        }
        $lookupProperty = $definition.PSObject.Properties['Lookup']
        if ($null -eq $lookupProperty) {
            $referencedName = "$($definition.ReferencedEntity)".Split('_')[-1]
            $displayName = (Get-Culture).TextInfo.ToTitleCase($referencedName)
            $metadata.Lookup = [ordered]@{
                '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'
                SchemaName = "$($definition.ReferencingAttribute)"
                DisplayName = @{ LocalizedLabels = @(@{ Label = $displayName; LanguageCode = 1033 }) }
                Description = @{ LocalizedLabels = @(@{ Label = "Related $displayName"; LanguageCode = 1033 }) }
                RequiredLevel = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
            }
        }
    }
    return $metadata
}

function Invoke-Dv {
    param([string]$Method, [string]$Path, [object]$Body = $null)
    return Invoke-WizardDataverseRequest -Method $Method -Path $Path -EnvironmentUrl $EnvironmentUrl `
        -AccessToken $AccessToken -Body $Body -RequestInvoker $RequestInvoker
}

function Assert-ExistingRelationshipIdentity {
    param([Parameter(Mandatory)] [object]$Expected, [Parameter(Mandatory)] [object]$Actual)

    $schema = $Expected.SchemaName
    $actualType = "$($Actual.'@odata.type')"
    $expectedType = if ($Expected.Kind -eq 'ManyToMany') { 'ManyToManyRelationshipMetadata' } else { 'OneToManyRelationshipMetadata' }
    if (-not $actualType.EndsWith($expectedType, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Relationship '$schema' exists but is not $expectedType (actual '$actualType')."
    }
    $identityProperties = if ($Expected.Kind -eq 'ManyToMany') {
        @('Entity1LogicalName', 'Entity2LogicalName', 'IntersectEntityName')
    } else {
        @('ReferencedEntity', 'ReferencedAttribute', 'ReferencingEntity', 'ReferencingAttribute')
    }
    foreach ($name in $identityProperties) {
        $expectedValue = "$($Expected.Definition.$name)"
        $actualValue = "$($Actual.$name)"
        if ([string]::IsNullOrWhiteSpace($actualValue) -or
            -not $actualValue.Equals($expectedValue, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Relationship '$schema' exists with conflicting $name '$actualValue' (expected '$expectedValue')."
        }
    }
}

function Find-ExistingRelationship {
    param([Parameter(Mandatory)] [object]$Expected)

    $SchemaName = $Expected.SchemaName
    $literal = ConvertTo-WizardODataLiteral -Value $SchemaName
    $response = Invoke-Dv -Method Get -Path "RelationshipDefinitions?`$filter=SchemaName eq '$literal'"
    $matches = @($response.value | Where-Object {
        -not [string]::IsNullOrWhiteSpace("$($_.SchemaName)") -and
        $_.SchemaName.Equals($SchemaName, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($matches.Count -gt 1) { throw "Dataverse returned multiple relationships named '$($Expected.SchemaName)'." }
    if ($matches.Count -eq 0) { return $null }
    Assert-ExistingRelationshipIdentity -Expected $Expected -Actual $matches[0]
    return $matches[0]
}

function Add-RelationshipManifestItem {
    param([string]$Name, [string]$Status, [string]$Payload, [hashtable]$Extra = @{})
    if ($PreviewOnly -or [string]::IsNullOrWhiteSpace($scenarioSlug) -or
        -not (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) { return }
    $details = @{ payload = $Payload; relationshipType = $Extra.relationshipType }
    foreach ($key in $Extra.Keys) { $details[$key] = $Extra[$key] }
    Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $scenarioSlug -SolutionName $solutionName `
        -PublisherPrefix $publisherPrefix -Kind 'relationship' -Name $Name -Status $Status `
        -Step '40-build-relationships.ps1' -Details $details | Out-Null
}

Write-Host "`n=== Build Relationships ===" -ForegroundColor Cyan
Write-Host "  Mode: $(if ($PreviewOnly) { 'Preview' } else { 'Apply' })"
$payloads = @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'relationships-*.json' -File -ErrorAction SilentlyContinue)
if ($payloads.Count -eq 0) {
    Write-Host "No relationships-*.json found in: $PayloadsFolder" -ForegroundColor Yellow
    return
}

$created = 0
$skipped = 0
$previewed = 0
$failures = [Collections.Generic.List[string]]::new()
foreach ($file in $payloads) {
    try {
        $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $relationships = @($document.Relationships ?? $document)
        foreach ($relationship in $relationships) {
            try {
                $expected = Assert-RelationshipPayload -Relationship $relationship -PayloadName $file.Name
                $schema = $expected.SchemaName
                if ($PreviewOnly) {
                    $null = ConvertTo-DataverseRelationshipMetadata -Relationship $relationship
                    Write-Host "  $schema (would create $($expected.Kind))" -ForegroundColor Cyan
                    $previewed++
                    continue
                }
                $existing = Find-ExistingRelationship -Expected $expected
                if ($null -ne $existing) {
                    Write-Host "  $schema (exact identity exists - skipped)" -ForegroundColor DarkGray
                    Add-RelationshipManifestItem -Name $schema -Status 'skipped' -Payload $file.Name -Extra @{ reason = 'exact identity already exists'; relationshipType = $expected.Kind }
                    $skipped++
                    continue
                }
                $body = ConvertTo-DataverseRelationshipMetadata -Relationship $relationship
                Invoke-Dv -Method Post -Path 'RelationshipDefinitions' -Body $body | Out-Null
                Write-Host "  $schema (created $($expected.Kind))" -ForegroundColor Green
                Add-RelationshipManifestItem -Name $schema -Status 'created' -Payload $file.Name -Extra @{ relationshipType = $expected.Kind }
                $created++
            } catch {
                $name = try {
                    $failedDefinition = Get-RelationshipDefinition -Relationship $relationship
                    "$($failedDefinition.SchemaName)"
                } catch { '<unknown>' }
                $message = "$($file.Name): $name - $($_.Exception.Message)"
                Write-Host "  FAILED: $message" -ForegroundColor Red
                Add-RelationshipManifestItem -Name $name -Status 'failed' -Payload $file.Name -Extra @{ error = $_.Exception.Message; relationshipType = 'unknown' }
                $failures.Add($message) | Out-Null
            }
        }
    } catch {
        $failures.Add("$($file.Name): $($_.Exception.Message)") | Out-Null
    }
}

Write-Host "`nRelationships - created: $created  skipped: $skipped  previewed: $previewed  failed: $($failures.Count)"
if ($failures.Count -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message 'Relationship build failed for one or more payloads.'
    }
    throw "Relationship build failed:`n - $($failures -join "`n - ")"
}
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Relationship build completed (created=$created; skipped=$skipped; previewed=$previewed)."
}
if (-not $PreviewOnly) { Write-Host "`nNext step: pwsh ./scripts/bootstrap/50-add-to-solution.ps1" }
