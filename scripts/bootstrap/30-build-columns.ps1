<#
.SYNOPSIS
    Adds columns to existing Dataverse tables from columns-*.json payload files.
    Safe to rerun — skips columns that already exist on the table.

.PARAMETER EnvironmentUrl  Defaults to $env:DV_ENVIRONMENT_URL (set by 10-auth-connect.ps1).
.PARAMETER AccessToken     Defaults to $env:DV_TOKEN.
.PARAMETER PayloadsFolder  Folder containing columns-*.json. Defaults to ../../payloads.

.EXAMPLE
    pwsh ./scripts/bootstrap/30-build-columns.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken    = $env:DV_TOKEN,
    [string]$PayloadsFolder = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile; $EnvironmentUrl = $global:DV_ENVIRONMENT_URL; $AccessToken = $global:DV_TOKEN
}
if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "Run 10-auth-connect.ps1 first." -ForegroundColor Red; exit 1
}
if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "payloads"
}

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "") {
    $h = @{ "Authorization"="Bearer $AccessToken"; "Content-Type"="application/json";
            "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Accept"="application/json" }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
}

function Test-ColumnExists([string]$Table, [string]$Column) {
    try { Invoke-Dv "Get" "EntityDefinitions(LogicalName='$Table')/Attributes(LogicalName='$Column')?`$select=LogicalName" | Out-Null; return $true }
    catch { return $false }
}

Write-Host ""
Write-Host "=== Build Columns ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host ""

$payloads = @(Get-ChildItem -Path $PayloadsFolder -Filter "columns-*.json" -ErrorAction SilentlyContinue)
if ($payloads.Count -eq 0) {
    Write-Host "No columns-*.json found in: $PayloadsFolder" -ForegroundColor Yellow; exit 0
}

$created = 0; $skipped = 0; $failed = 0

foreach ($file in $payloads) {
    $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $tableName = $doc.TableLogicalName
    if ([string]::IsNullOrWhiteSpace($tableName)) {
        Write-Host "  SKIP $($file.Name) — missing TableLogicalName property" -ForegroundColor Yellow
        $skipped++; continue
    }
    $tableName = $tableName.ToLower()

    Write-Host "  Table: $tableName" -ForegroundColor Cyan
    foreach ($col in $doc.Columns) {
        $schema  = $col.SchemaName
        $logical = $col.LogicalName
        if ([string]::IsNullOrWhiteSpace($logical) -and -not [string]::IsNullOrWhiteSpace($schema)) {
            $logical = $schema
        }

        if ([string]::IsNullOrWhiteSpace($logical)) {
            Write-Host "    SKIP (missing SchemaName/LogicalName)" -ForegroundColor Yellow
            $skipped++
            continue
        }

        $logical = $logical.ToLower()
        Write-Host "    $logical " -NoNewline

        if (Test-ColumnExists $tableName $logical) {
            Write-Host "(exists — skipped)" -ForegroundColor DarkGray
            $skipped++; continue
        }

        try {
            $col.LogicalName = $logical
            $body = $col | ConvertTo-Json -Depth 20 -Compress
            Invoke-Dv "Post" "EntityDefinitions(LogicalName='$tableName')/Attributes" $body | Out-Null
            Write-Host "(created)" -ForegroundColor Green
            $created++
        } catch {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host ""
Write-Host "Columns — created: $created  skipped: $skipped  failed: $failed"
if ($failed -gt 0) { exit 1 }
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/40-build-relationships.ps1"

