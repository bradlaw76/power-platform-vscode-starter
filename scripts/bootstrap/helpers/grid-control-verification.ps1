<#
=============================================================================
COMPONENT:    Grid Control Package Verification
FILE:         scripts/bootstrap/helpers/grid-control-verification.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-22
ENVIRONMENT:  PowerShell 7 | Read-only unmanaged package inspection
OVERVIEW:     Verify selected Web grids, actual boolean values, and FOIA views.
ARCHITECTURE: Inspect exported XML only; never write control metadata.
TEST CASES:   Reject mobile-only registration, missing settings and wrong colors.
NON-NEGOTIABLES: static=true is a binding qualifier, not the property's value.
=============================================================================
#>
function Assert-WizardGridControlPackage {
    param([object]$Contract, [object[]]$Views, [object]$Membership, [string]$UnpackPath)

    if ($Contract.runtimeControl -cne 'Microsoft.PowerApps.PowerAppsOneGrid' -or
        $Contract.client -cne 'Web' -or $Contract.enableEditing -ne $false -or
        $Contract.optionSetColors -ne $true -or @($Contract.tables).Count -eq 0 -or
        @($Contract.tables | Sort-Object -Unique).Count -ne @($Contract.tables).Count) {
        throw 'Grid contract must identify unique tables and the read-only color-enabled native Web grid.'
    }
    $documents = @(Get-ChildItem -LiteralPath (Join-Path $UnpackPath 'Entities') -Filter 'Entity.xml' -Recurse -File | ForEach-Object {
        $entityDocument = [xml](Get-Content -LiteralPath $_.FullName -Raw)
        [pscustomobject]@{ File = $_.FullName; Xml = $entityDocument }
    })
    $tables = foreach ($table in $Contract.tables) {
        $entityMatches = @($documents | Where-Object { $_.Xml.SelectSingleNode('/Entity/Name').InnerText -ieq $table })
        if ($entityMatches.Count -ne 1) { throw "Expected one exported entity definition for '$table'." }
        $controls = @($entityMatches[0].Xml.SelectNodes('//CustomControlDefaultConfigs//customControl[@formFactor="2"]'))
        if ($controls.Count -ne 1 -or $controls[0].GetAttribute('name') -cne $Contract.runtimeControl) {
            throw "Table '$table' does not select the native Power Apps grid for Web."
        }
        foreach ($setting in @(@{ Name = 'EnableEditing'; Expected = $false }, @{ Name = 'EnableDropdownColor'; Expected = $true })) {
            $nodes = @($controls[0].SelectNodes("parameters/$($setting.Name)"))
            if ($nodes.Count -ne 1 -or $nodes[0].InnerText.Trim() -notmatch '^(?i:yes|no|true|false|1|0)$') {
                throw "Table '$table' lacks a unique boolean value for '$($setting.Name)'."
            }
            $actual = $nodes[0].InnerText.Trim() -match '^(?i:yes|true|1)$'
            if ($actual -ne $setting.Expected) { throw "Table '$table' has incorrect '$($setting.Name)'." }
        }
        [pscustomobject]@{
            tableLogicalName = $table; runtimeControl = $Contract.runtimeControl
            client = 'Web'; enableEditing = $false; optionSetColors = $true
            entityXml = [IO.Path]::GetRelativePath($UnpackPath, $entityMatches[0].File)
        }
    }
    $verifiedViews = foreach ($view in $Views) {
        $name = "$($view.TableLogicalName)|$($view.Name)"
        $members = @($Membership.Items | Where-Object {
            $_.Category -eq 'views' -and $_.Name -ceq $name -and
            $_.State -in @('Added', 'Already in solution')
        })
        if ($members.Count -ne 1) { throw "New FOIA view '$name' lacks exact solution membership." }
        $id = ([guid]$members[0].ObjectId).ToString()
        $files = @(Get-ChildItem -LiteralPath (Join-Path $UnpackPath 'Entities') -Filter "*$id*.xml" -Recurse -File)
        if ($files.Count -ne 1) { throw "New FOIA view '$name' is absent from the exported package." }
        $viewDocument = [xml](Get-Content -LiteralPath $files[0].FullName -Raw)
        $labels = @($viewDocument.SelectNodes('/savedqueries/savedquery/LocalizedNames/LocalizedName[@languagecode="1033"]'))
        $entity = $viewDocument.SelectSingleNode('/savedqueries/savedquery/fetchxml/fetch/entity')
        if ($labels.Count -ne 1 -or $labels[0].GetAttribute('description') -cne $view.Name -or
            $null -eq $entity -or $entity.GetAttribute('name') -cne $view.TableLogicalName -or
            $entity.SelectNodes("filter[not(@type) or @type='and']/condition[@attribute='$($view.Filter.Attribute)' and @operator='not-null' and not(@entityname)]").Count -ne 1) {
            throw "New FOIA view '$name' has incorrect labels, table, or FOIA filter."
        }
        $columns = @($viewDocument.SelectNodes('/savedqueries/savedquery/layoutxml/grid/row/cell') | ForEach-Object { $_.GetAttribute('name') })
        if (($columns -join ',') -cne ($view.Columns -join ',')) { throw "New FOIA view '$name' has incorrect columns/order." }
        [pscustomobject]@{ tableLogicalName = $view.TableLogicalName; name = $view.Name; id = $id }
    }
    return [pscustomobject]@{
        tableCount = @($tables).Count; viewCount = @($verifiedViews).Count
        tables = @($tables); views = @($verifiedViews); verificationBasis = 'Exported selected Web controls and FOIA public views'
    }
}
