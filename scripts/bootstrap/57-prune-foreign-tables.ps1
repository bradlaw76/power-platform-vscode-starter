<#
=============================================================================
COMPONENT:    Prune Foreign Tables
FILE:         scripts/bootstrap/57-prune-foreign-tables.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Solution Metadata Maintenance

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Removes unintended foreign-table references from generated assets so the
scenario stays scoped to the approved solution boundary.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          solution artifacts, scenario scope, and table mapping
- Outputs:         pruned artifacts and review output
- Dependencies:    solution-isolation helper logic and planning files
- Side Effects:    rewrites local artifacts to enforce solution scope

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Scenario table scope must already be known.
2. Related artifacts must already have been generated.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Foreign-table references outside scenario scope are removed.
✔ Approved scenario tables remain intact after pruning.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Do not remove scenario-approved table references.
- Keep pruning deterministic and reviewable on rerun.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Removes foreign table components from an unmanaged Dataverse solution.

.DESCRIPTION
    Derives the expected table set from payload files, inspects table components
    already present in the target solution, and either reports what would be
    removed (default DryRun) or removes only the foreign table components.

.EXAMPLE
    pwsh ./scripts/bootstrap/57-prune-foreign-tables.ps1

.EXAMPLE
    pwsh ./scripts/bootstrap/57-prune-foreign-tables.ps1 -Mode Apply
#>

param(
    [string]$EnvironmentUrl     = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken        = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PayloadsFolder     = "",
    [ValidateSet('DryRun', 'Apply')]
    [string]$Mode = 'DryRun',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot '.env.ps1'
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl     = $global:DV_ENVIRONMENT_URL
    $AccessToken        = $global:DV_TOKEN
    $SolutionUniqueName = $SolutionUniqueName -ne '' ? $SolutionUniqueName : $global:DV_SOLUTION_NAME
}

foreach ($value in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName)) {
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Host 'Missing required values. Run 10-auth-connect.ps1 first.' -ForegroundColor Red
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path $repoRoot 'payloads'
}

if (-not (Test-Path $PayloadsFolder)) {
    Write-Host "Payload folder not found: $PayloadsFolder" -ForegroundColor Red
    exit 1
}

$solutionIsolationHelper = Join-Path $PSScriptRoot 'helpers\solution-isolation.ps1'
if (-not (Test-Path $solutionIsolationHelper)) {
    Write-Host "Missing helper script: $solutionIsolationHelper" -ForegroundColor Red
    exit 1
}

. $solutionIsolationHelper

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = ''
    )

    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type'  = 'application/json'
        'OData-Version' = '4.0'
        'OData-MaxVersion' = '4.0'
        'Accept' = 'application/json'
    }

    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body
    }

    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

Write-Host ''
Write-Host '=== Prune Foreign Tables From Solution ===' -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Solution:    $SolutionUniqueName"
Write-Host "  Payloads:    $PayloadsFolder"
Write-Host "  Mode:        $Mode"
Write-Host ''

$solution = (Invoke-Dv 'Get' "solutions?`$filter=uniquename eq '$SolutionUniqueName'&`$select=solutionid,uniquename").value | Select-Object -First 1
if ($null -eq $solution) {
    Write-Host "Solution '$SolutionUniqueName' not found in this environment." -ForegroundColor Red
    exit 1
}

$invokeDvGet = { param($path) Invoke-Dv 'Get' $path }
$invokeDvPost = { param($path, $body) Invoke-Dv 'Post' $path $body }

$expectedTables = @(Get-PayloadEntityNames -Folder $PayloadsFolder)
$tableReport = Get-SolutionTableIsolationReport -InvokeGet $invokeDvGet -SolutionId "$($solution.solutionid)" -ExpectedEntityNames $expectedTables

Write-Host "  Payload-derived expected tables: $($tableReport.ExpectedTables.Count)"
Write-Host "  Current solution tables:         $($tableReport.CurrentTables.Count)"
Write-Host "  Foreign tables detected:         $($tableReport.ForeignTables.Count)"
Write-Host ''

if ($tableReport.ForeignTables.Count -eq 0) {
    Write-Host 'Solution table set is already clean. Nothing to remove.' -ForegroundColor Green
    exit 0
}

Write-Host 'Foreign table components:' -ForegroundColor Yellow
foreach ($table in $tableReport.ForeignTables) {
    Write-Host "  - $($table.LogicalName)" -ForegroundColor Yellow
}
Write-Host ''

$previewResults = Invoke-SolutionTableCleanup -InvokePost $invokeDvPost -ForeignTables $tableReport.ForeignTables -SolutionUniqueName $SolutionUniqueName
if ($Mode -eq 'DryRun') {
    Write-Host 'Dry run only. The following table components would be removed:' -ForegroundColor Cyan
    foreach ($item in $previewResults) {
        Write-Host "  - $($item.LogicalName)" -ForegroundColor Cyan
    }
    Write-Host ''
    Write-Host "Apply cleanup with: pwsh ./scripts/bootstrap/57-prune-foreign-tables.ps1 -SolutionUniqueName \"$SolutionUniqueName\" -Mode Apply" -ForegroundColor Yellow
    exit 0
}

if (-not $Force) {
    $confirmation = Read-Host "Type REMOVE to prune $($tableReport.ForeignTables.Count) foreign table component(s) from solution '$SolutionUniqueName'"
    if ($confirmation -cne 'REMOVE') {
        Write-Host 'Cleanup cancelled. No components were removed.' -ForegroundColor Yellow
        exit 0
    }
}

$removed = 0
$failed = 0
foreach ($item in $tableReport.ForeignTables) {
    Write-Host "  Removing $($item.LogicalName)... " -NoNewline
    try {
        Invoke-SolutionTableCleanup -InvokePost $invokeDvPost -ForeignTables @($item) -SolutionUniqueName $SolutionUniqueName -Apply | Out-Null
        Write-Host 'removed' -ForegroundColor Green
        $removed++
    } catch {
        Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ''
Write-Host "Cleanup summary — removed: $removed  failed: $failed"
if ($failed -gt 0) {
    exit 1
}

Write-Host 'Solution table cleanup completed.' -ForegroundColor Green
