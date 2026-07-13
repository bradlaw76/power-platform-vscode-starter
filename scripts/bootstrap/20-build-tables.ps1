<#
.SYNOPSIS
    Creates Dataverse tables from JSON payload files.
    Safe to rerun — skips tables that already exist.

.DESCRIPTION
    Loads all table-*.json files from the payloads/ folder adjacent to this script's
    parent directory. Calls the Dataverse EntityDefinitions API for each table.

    Reads environment config from .env.ps1 (written by 10-auth-connect.ps1).
    Values can also be passed directly as parameters.

.PARAMETER EnvironmentUrl
    Dataverse environment URL. Defaults to $env:DV_ENVIRONMENT_URL.

.PARAMETER AccessToken
    Bearer token. Defaults to $env:DV_TOKEN.

.PARAMETER PayloadsFolder
    Path to the folder containing table-*.json files. Defaults to ../../payloads.

.EXAMPLE
    pwsh ./scripts/bootstrap/20-build-tables.ps1
    pwsh ./scripts/bootstrap/20-build-tables.ps1 -EnvironmentUrl "https://org.crm.dynamics.com" -AccessToken $token
#>

param(
    [string]$EnvironmentUrl  = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken     = $env:DV_TOKEN,
    [string]$PayloadsFolder  = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Load session env if not already set ───────────────────────────────────
$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    $AccessToken    = $global:DV_TOKEN
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "Environment URL and token are required." -ForegroundColor Red
    Write-Host "Run 10-auth-connect.ps1 first, or pass -EnvironmentUrl and -AccessToken."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "payloads"
}

$tableDetectionHelper = Join-Path $PSScriptRoot "helpers\table-detection.ps1"
if (Test-Path $tableDetectionHelper) {
    . $tableDetectionHelper
}

# ── Helpers ────────────────────────────────────────────────────────────────
function Invoke-Dv {
    param([string]$Method, [string]$Path, [string]$Body = "")
    $headers = @{
        "Authorization"    = "Bearer $AccessToken"
        "Content-Type"     = "application/json"
        "OData-Version"    = "4.0"
        "OData-MaxVersion" = "4.0"
        "Accept"           = "application/json"
    }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

function Test-TableExists([string]$LogicalName) {
    try {
        Invoke-Dv "Get" "EntityDefinitions(LogicalName='$LogicalName')?`$select=LogicalName" | Out-Null
        return $true
    } catch { return $false }
}

# ── Main ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Build Tables ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Payloads:    $PayloadsFolder"
Write-Host ""

$payloads = @(Get-ChildItem -Path $PayloadsFolder -Filter "table-*.json" -ErrorAction SilentlyContinue)
if ($payloads.Count -eq 0) {
    Write-Host "No table-*.json files found in: $PayloadsFolder" -ForegroundColor Yellow
    Write-Host "Create at least one table payload file and rerun."
    exit 0
}

$created = 0; $skipped = 0; $failed = 0

foreach ($file in $payloads) {
    $payload = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $name    = $payload.EntityDefinition.SchemaName ?? $payload.SchemaName
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Host "  SKIP  $($file.Name) — could not determine SchemaName" -ForegroundColor Yellow
        $skipped++; continue
    }

    $logical = $name.ToLower()
    Write-Host "  $name " -NoNewline

    if (Get-Command Test-IsStandardTable -ErrorAction SilentlyContinue) {
        if (Test-IsStandardTable $logical) {
            Write-Host "(standard table in payload — skipped)" -ForegroundColor Yellow
            $skipped++; continue
        }
    }

    if (Test-TableExists $logical) {
        Write-Host "(exists — skipped)" -ForegroundColor DarkGray
        $skipped++; continue
    }

    try {
        Invoke-Dv "Post" "EntityDefinitions" (Get-Content $file.FullName -Raw) | Out-Null
        Write-Host "(created)" -ForegroundColor Green
        $created++
    } catch {
        Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "Tables — created: $created  skipped: $skipped  failed: $failed"
if ($failed -gt 0) { exit 1 }
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/30-build-columns.ps1"

