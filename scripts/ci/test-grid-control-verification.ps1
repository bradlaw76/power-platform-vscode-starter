<#
=============================================================================
COMPONENT:    Grid Control Verification Tests
FILE:         scripts/ci/test-grid-control-verification.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-22
ENVIRONMENT:  PowerShell 7 | Credential-free XML fixtures
OVERVIEW:     Verify selected Web control, actual property text, and new views.
ARCHITECTURE: Temporary exported-package fixtures and explicit negative gates.
TEST CASES:   Wrong client/control, editing/color drift, absent metadata/views.
NON-NEGOTIABLES: Never treat static=true as the boolean property's value.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repo 'scripts\bootstrap\helpers\grid-control-verification.ps1')
$contract = Get-Content -LiteralPath (Join-Path $repo 'specs\federal-foia-management\grid-controls.json') -Raw | ConvertFrom-Json
$views = (Get-Content -LiteralPath (Join-Path $repo 'payloads\scenarios\federal-foia-management\grid-views-federal-foia-management.json') -Raw | ConvertFrom-Json).Views
$temp = Join-Path ([IO.Path]::GetTempPath()) ('foia-grid-export-' + [guid]::NewGuid().ToString('N'))
$membership = [pscustomobject]@{Items = @($views | ForEach-Object {
    [pscustomobject]@{Category = 'views'; Name = "$($_.TableLogicalName)|$($_.Name)"; ObjectId = [guid]::NewGuid().ToString(); State = 'Already in solution'}
})}
function Write-Fixture {
    param([string]$Fault = '')
    foreach ($table in $contract.tables) {
        $folder = Join-Path $temp "Entities\$table"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $factor = if ($Fault -eq 'mobile-only') { '0' } else { '2' }
        $control = if ($Fault -eq 'wrong-control') { 'Wrong.Control' } else { $contract.runtimeControl }
        $editing = if ($Fault -eq 'editing') { 'yes' } else { 'no' }
        $color = if ($Fault -eq 'color') { 'no' } else { 'yes' }
        $properties = "<EnableEditing static='true'>$editing</EnableEditing><EnableDropdownColor static='true'>$color</EnableDropdownColor>"
        if ($Fault -eq 'missing-property') { $properties = '' }
        if ($Fault -eq 'duplicate-property') { $properties += "<EnableEditing static='true'>no</EnableEditing>" }
        if ($Fault -eq 'invalid-boolean') { $properties = "<EnableEditing static='true'>maybe</EnableEditing><EnableDropdownColor static='true'>yes</EnableDropdownColor>" }
        $config = "<CustomControlDefaultConfigs><CustomControlDefaultConfig><ControlDescriptionXML><controlDescriptions><controlDescription><customControl name='$control' formFactor='$factor'><parameters>$properties</parameters></customControl></controlDescription></controlDescriptions></ControlDescriptionXML></CustomControlDefaultConfig></CustomControlDefaultConfigs>"
        if ($Fault -eq 'missing-grid') { $config = '' }
        "<Entity><Name>$($table.ToUpperInvariant())</Name>$config</Entity>" | Set-Content -LiteralPath (Join-Path $folder 'Entity.xml')
    }
    foreach ($view in $views) {
        $member = @($membership.Items | Where-Object Name -eq "$($view.TableLogicalName)|$($view.Name)")[0]
        $folder = Join-Path $temp "Entities\$($view.TableLogicalName)\SavedQueries"
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $cells = @($view.Columns | ForEach-Object { "<cell name='$_'/>" }) -join ''
        $label = if ($Fault -eq 'view-label') { 'Wrong view' } else { $view.Name }
        $filter = if ($Fault -eq 'view-filter') { '' } else { "<filter><condition attribute='$($view.Filter.Attribute)' operator='not-null'/></filter>" }
        switch ($Fault) {
            'view-or-filter' { $filter = "<filter type='or'><condition attribute='$($view.Filter.Attribute)' operator='not-null'/><condition attribute='$($view.Columns[0])' operator='not-null'/></filter>" }
            'view-nested-or-filter' { $filter = "<filter type='and'><filter type='or'><condition attribute='$($view.Filter.Attribute)' operator='not-null'/><condition attribute='$($view.Columns[0])' operator='not-null'/></filter></filter>" }
            'view-aliased-filter' { $filter = "<filter type='and'><condition entityname='related' attribute='$($view.Filter.Attribute)' operator='not-null'/></filter>" }
            'view-and-filter' { $filter = "<filter type='and'><condition attribute='$($view.Filter.Attribute)' operator='not-null'/><condition attribute='$($view.Columns[0])' operator='not-null'/></filter>" }
        }
        if ($Fault -eq 'view-columns') { $cells = "<cell name='wrong_field'/>" }
        "<savedqueries><savedquery><LocalizedNames><LocalizedName description='$label' languagecode='1033'/></LocalizedNames><fetchxml><fetch><entity name='$($view.TableLogicalName)'>$filter</entity></fetch></fetchxml><layoutxml><grid><row>$cells</row></grid></layoutxml></savedquery></savedqueries>" |
            Set-Content -LiteralPath (Join-Path $folder "$($member.ObjectId).xml")
    }
}
try {
    Write-Fixture
    $result = Assert-WizardGridControlPackage -Contract $contract -Views $views -Membership $membership -UnpackPath $temp
    if ($result.tableCount -ne 13 -or $result.viewCount -ne 2) { throw 'Exact positive grid/view counts failed.' }
    Write-Fixture -Fault 'view-and-filter'
    $conjunction = Assert-WizardGridControlPackage -Contract $contract -Views $views -Membership $membership -UnpackPath $temp
    if ($conjunction.viewCount -ne 2) { throw 'Mandatory primary-table FOIA conjunction was rejected.' }
    foreach ($fault in @(
        @{Name = 'mobile-only'; Error = 'does not select'},
        @{Name = 'wrong-control'; Error = 'does not select'},
        @{Name = 'editing'; Error = 'incorrect'},
        @{Name = 'color'; Error = 'incorrect'},
        @{Name = 'missing-property'; Error = 'lacks a unique'},
        @{Name = 'duplicate-property'; Error = 'lacks a unique'},
        @{Name = 'invalid-boolean'; Error = 'lacks a unique'},
        @{Name = 'missing-grid'; Error = 'does not select'},
        @{Name = 'view-label'; Error = 'incorrect labels'},
        @{Name = 'view-filter'; Error = 'incorrect labels'},
        @{Name = 'view-or-filter'; Error = 'incorrect labels'},
        @{Name = 'view-nested-or-filter'; Error = 'incorrect labels'},
        @{Name = 'view-aliased-filter'; Error = 'incorrect labels'},
        @{Name = 'view-columns'; Error = 'incorrect columns'}
    )) {
        Write-Fixture -Fault $fault.Name
        $failed = $false
        try { Assert-WizardGridControlPackage -Contract $contract -Views $views -Membership $membership -UnpackPath $temp | Out-Null } catch {
            if ($_.Exception.Message -notlike "*$($fault.Error)*") { throw }
            $failed = $true
        }
        if (-not $failed) { throw "Grid gate incorrectly accepted '$($fault.Name)'." }
    }
    Write-Host 'Grid control verification tests passed: 13 selected Web grids, actual read-only/color values, two FOIA-scoped views, and fourteen negative gates.'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
