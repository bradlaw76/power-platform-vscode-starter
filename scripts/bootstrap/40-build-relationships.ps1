<#
.SYNOPSIS
    Creates lookup relationships between Dataverse tables from a relationships-*.json
    payload file. Safe to rerun — skips relationships that already exist.

.PARAMETER EnvironmentUrl  Defaults to $env:DV_ENVIRONMENT_URL.
.PARAMETER AccessToken     Defaults to $env:DV_TOKEN.
.PARAMETER PayloadsFolder  Defaults to ../../payloads.

.EXAMPLE
    pwsh ./scripts/bootstrap/40-build-relationships.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken    = $env:DV_TOKEN,
    [string]$PayloadsFolder = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "40-build-relationships.ps1"
}

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile; $EnvironmentUrl = $global:DV_ENVIRONMENT_URL; $AccessToken = $global:DV_TOKEN
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
    $h = @{ "Authorization"="Bearer $AccessToken"; "Content-Type"="application/json";
            "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Accept"="application/json" }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
}

function Test-RelationshipExists([string]$SchemaName) {
    try {
        $resp = Invoke-Dv "Get" "RelationshipDefinitions?`$filter=SchemaName eq '$SchemaName'&`$select=SchemaName"
        $matches = @($resp.value | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.SchemaName) -and $_.SchemaName.Equals($SchemaName, [System.StringComparison]::OrdinalIgnoreCase)
        })
        return $matches.Count -gt 0
    } catch { return $false }
}

function Normalize-RelationshipEntityNames($RelationshipObject) {
    if ($null -eq $RelationshipObject) { return }

    foreach ($propName in @("ReferencedEntity", "ReferencingEntity", "Entity1LogicalName", "Entity2LogicalName")) {
        $prop = $RelationshipObject.PSObject.Properties[$propName]
        if ($null -ne $prop -and $prop.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($prop.Value)) {
            $prop.Value = $prop.Value.Trim()
        }
    }

    $definition = $RelationshipObject.PSObject.Properties["RelationshipDefinition"]
    if ($null -ne $definition -and $null -ne $definition.Value) {
        foreach ($propName in @("ReferencedEntity", "ReferencingEntity", "Entity1LogicalName", "Entity2LogicalName")) {
            $prop = $definition.Value.PSObject.Properties[$propName]
            if ($null -ne $prop -and $prop.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($prop.Value)) {
                $prop.Value = $prop.Value.Trim()
            }
        }
    }
}

Write-Host ""
Write-Host "=== Build Relationships ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host ""

$payloads = @(Get-ChildItem -Path $PayloadsFolder -Filter "relationships-*.json" -ErrorAction SilentlyContinue)
if ($payloads.Count -eq 0) {
    Write-Host "No relationships-*.json found in: $PayloadsFolder" -ForegroundColor Yellow
    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message "No relationship payloads found."
    }
    exit 0
}

$created = 0; $skipped = 0; $failed = 0

foreach ($file in $payloads) {
    $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $rels = @($doc.Relationships ?? $doc)

    foreach ($rel in $rels) {
        Normalize-RelationshipEntityNames $rel
        $schema = $rel.SchemaName ?? $rel.RelationshipDefinition.SchemaName
        if ([string]::IsNullOrWhiteSpace($schema)) {
            Write-Host "  SKIP $($file.Name) — missing relationship SchemaName" -ForegroundColor Yellow
            $skipped++
            continue
        }
        Write-Host "  $schema " -NoNewline

        if (Test-RelationshipExists $schema) {
            Write-Host "(exists — skipped)" -ForegroundColor DarkGray
            $skipped++; continue
        }

        try {
            $body = ($rel | ConvertTo-Json -Depth 20 -Compress)
            Invoke-Dv "Post" "RelationshipDefinitions" $body | Out-Null
            Write-Host "(created)" -ForegroundColor Green
            $created++
        } catch {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host ""
Write-Host "Relationships — created: $created  skipped: $skipped  failed: $failed"
if ($failed -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Relationship build failed for one or more payloads."
    }
    exit 1
}
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Relationship build completed."
}
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/50-add-to-solution.ps1"

