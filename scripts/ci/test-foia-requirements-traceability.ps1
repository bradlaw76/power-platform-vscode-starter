<#
=============================================================================
COMPONENT:    Federal FOIA Requirements Traceability Test
FILE:         scripts/ci/test-foia-requirements-traceability.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter Team
LAST UPDATED: 2026-10-06
ENVIRONMENT:  PowerShell 7 | VS Code

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Proves that the authoritative 300-item FOIA catalog and the categorized
84-item implementation profile are complete, unique, and represented in the
scenario crosswalk.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            CI test
- Inputs:          FOIA catalog, baseline, and traceability Markdown files
- Outputs:         Pass/fail console output
- Dependencies:    PowerShell 7
- Side Effects:    None

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Federal FOIA scenario planning artifacts exist.
2. Catalog and profile requirements use their documented stable ID formats.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Catalog contains each FOIA-REQ-001 through FOIA-REQ-300 exactly once.
✔ Profile contains 84 unique categorized IDs and the crosswalk covers both sets.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v1.0.0  2026-10-06  Added deterministic catalog/profile crosswalk validation.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Do not bypass repo workflow gates captured in docs/onboarding.md.
- Keep this test credential-free and free of external side effects.
- Update this header when the script's contract materially changes.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scenarioRoot = Join-Path $repoRoot 'specs/federal-foia-management'
$catalogPath = Join-Path $scenarioRoot 'Federal-FOIA-Solution-Requirements.md'
$baselinePath = Join-Path $scenarioRoot 'requirements-baseline.md'
$traceabilityPath = Join-Path $scenarioRoot 'requirement-traceability.md'

foreach ($path in @($catalogPath, $baselinePath, $traceabilityPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing FOIA traceability artifact: $path"
    }
}

$catalogRows = @(Get-Content $catalogPath | Where-Object { $_ -match '^FOIA-REQ-\d{3}:\s' })
$catalogIds = @(
    foreach ($row in $catalogRows) {
        [regex]::Match($row, 'FOIA-REQ-(\d{3})').Groups[1].Value
    }
)
$expectedCatalogIds = @(1..300 | ForEach-Object { $_.ToString('000') })
$catalogGroups = @($catalogIds | Group-Object)
$duplicateCatalogIds = @($catalogGroups | Where-Object Count -ne 1 | ForEach-Object Name)
$missingCatalogIds = @($expectedCatalogIds | Where-Object { $_ -notin $catalogIds })
$unexpectedCatalogIds = @($catalogIds | Where-Object { $_ -notin $expectedCatalogIds })

if ($catalogRows.Count -ne 300 -or $missingCatalogIds.Count -gt 0 -or $duplicateCatalogIds.Count -gt 0 -or $unexpectedCatalogIds.Count -gt 0) {
    throw "FOIA catalog IDs are invalid. Rows=$($catalogRows.Count); Missing=$($missingCatalogIds -join ','); Duplicates=$($duplicateCatalogIds -join ','); Unexpected=$($unexpectedCatalogIds -join ',')."
}

$profileRows = @(Get-Content $baselinePath | Where-Object { $_ -match '^\|\s*FOIA-(?!REQ-)[A-Z]+-\d{3}\s*\|' })
$profileIds = @(
    foreach ($row in $profileRows) {
        [regex]::Match($row, 'FOIA-(?!REQ-)[A-Z]+-\d{3}').Value
    }
)
$duplicateProfileIds = @($profileIds | Group-Object | Where-Object Count -ne 1 | ForEach-Object Name)

if ($profileRows.Count -ne 84 -or @($profileIds | Sort-Object -Unique).Count -ne 84 -or $duplicateProfileIds.Count -gt 0) {
    throw "FOIA profile IDs are invalid. Rows=$($profileRows.Count); Unique=$(@($profileIds | Sort-Object -Unique).Count); Duplicates=$($duplicateProfileIds -join ',')."
}

$traceabilityLines = @(Get-Content $traceabilityPath)
$traceabilityText = $traceabilityLines -join "`n"
$missingProfileMappings = @($profileIds | Where-Object { $traceabilityText -notmatch [regex]::Escape($_) })
if ($missingProfileMappings.Count -gt 0) {
    throw "Profile IDs missing from the traceability crosswalk: $($missingProfileMappings -join ',')."
}

$coveredCatalogNumbers = [System.Collections.Generic.List[int]]::new()
$rangePattern = '^\|\s*FOIA-REQ-(\d{3})\.\.(\d{3})\s*\|'
$rangeRows = @($traceabilityLines | Where-Object { $_ -match $rangePattern })
if ($rangeRows.Count -eq 0) {
    throw 'No FOIA catalog range rows were found in the traceability crosswalk.'
}

foreach ($line in $rangeRows) {
    $match = [regex]::Match($line, $rangePattern)
    $start = [int]$match.Groups[1].Value
    $end = [int]$match.Groups[2].Value
    if ($end -lt $start) {
        throw "Descending FOIA catalog range in traceability row: $line"
    }

    $cells = @($line.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
    if ($cells.Count -lt 4 -or [string]::IsNullOrWhiteSpace($cells[2]) -or [string]::IsNullOrWhiteSpace($cells[3])) {
        throw "FOIA catalog range row is missing its disposition or profile mapping: $line"
    }

    foreach ($number in $start..$end) {
        $coveredCatalogNumbers.Add($number)
    }
}

$coveredGroups = @($coveredCatalogNumbers | Group-Object)
$duplicateCatalogMappings = @($coveredGroups | Where-Object Count -ne 1 | ForEach-Object Name)
$missingCatalogMappings = @(1..300 | Where-Object { $_ -notin $coveredCatalogNumbers })
if ($missingCatalogMappings.Count -gt 0 -or $duplicateCatalogMappings.Count -gt 0) {
    $missingLabels = @($missingCatalogMappings | ForEach-Object { 'FOIA-REQ-' + $_.ToString('000') })
    $duplicateLabels = @($duplicateCatalogMappings | ForEach-Object { 'FOIA-REQ-' + ([int]$_).ToString('000') })
    throw "Catalog crosswalk ranges are invalid. Missing=$($missingLabels -join ','); Duplicates=$($duplicateLabels -join ',')."
}

Write-Host 'Federal FOIA requirements traceability checks passed: 300 catalog IDs and 84 profile IDs.' -ForegroundColor Green
