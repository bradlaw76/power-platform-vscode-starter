<#
=============================================================================
COMPONENT:    Power Apps Grid Maker Handoff and Verification
FILE:         scripts/bootstrap/61-configure-power-apps-grid.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-01
ENVIRONMENT:  PowerShell 7 | Power Platform Bootstrap Runtime

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Creates a credential-free maker handoff for table-level Power Apps grid
configuration and verifies the result from a supported unmanaged solution
export. It never writes internal custom-control metadata.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            optional experience verification gate
- Inputs:          specs/<scenario>/grid-controls.json; exported Entity.xml
- Outputs:         handoff and verification artifacts
- Dependencies:    PowerShell 7; PAC CLI only when exporting
- Side Effects:    local artifacts; supported read-only solution export

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never mutate customcontroldefaultconfigs or solution XML.
- Never claim Preview applied maker configuration.
- Verify Microsoft.PowerApps.PowerAppsOneGrid before app assembly.
=============================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')]
    [string]$ScenarioSlug,
    [ValidateSet('Preview', 'Verify')]
    [string]$Mode = 'Preview',
    [string]$UnpackedSolutionFolder = '',
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$contractPath = Join-Path $repoRoot "specs/$ScenarioSlug/grid-controls.json"
$schemaPath = Join-Path $repoRoot 'schemas/payloads/grid-controls.schema.json'
$artifactRoot = Join-Path $repoRoot ".wizard-metrics/artifacts/grid-controls/$ScenarioSlug"

if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    throw "Grid contract not found: $contractPath"
}
if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
    throw "Grid schema not found: $schemaPath"
}

$contractJson = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8
if (-not (Test-Json -Json $contractJson -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw "Grid contract failed schema validation: $contractPath"
}
$contract = $contractJson | ConvertFrom-Json
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null

$propertyTokens = [ordered]@{
    enableEditing    = @('EnableEditing')
    filtering        = @('EnableFiltering', 'Filtering')
    sorting          = @('EnableSorting', 'Sorting')
    grouping         = @('EnableGrouping', 'Grouping')
    aggregation      = @('EnableAggregation', 'Aggregation')
    columnReordering = @('EnableColumnMoving', 'AllowColumnReordering', 'EnableColumnReordering', 'ColumnReordering')
    multiselect      = @('EnableMultipleSelection', 'EnableMultiSelect', 'MultiSelect')
    rangeSelection   = @('EnableRangeSelection', 'RangeSelection')
    jumpBar          = @('EnableJumpBar', 'JumpBar')
    pagination       = @('EnablePagination', 'Pagination')
    optionSetColors  = @('EnableDropdownColor', 'EnableOptionSetColors', 'OptionSetColors')
    statusIcons      = @('ShowStatusIcons', 'EnableStatusIcons', 'StatusIcons')
    typeIcons        = @('ShowDataTypeIcons', 'ShowTypeIcons', 'EnableTypeIcons', 'TypeIcons')
}

function ConvertTo-HtmlText {
    param([AllowEmptyString()][string]$Value)
    return [Net.WebUtility]::HtmlEncode($Value)
}

function Get-XmlBooleanToken {
    param(
        [Parameter(Mandatory)][xml]$Xml,
        [Parameter(Mandatory)][string[]]$Names
    )

    foreach ($node in @($Xml.SelectNodes('//*'))) {
        $candidateName = $node.LocalName
        if ($node.Attributes['name']) { $candidateName = $node.Attributes['name'].Value }
        if (-not ($Names | Where-Object { $_ -ieq $candidateName })) { continue }

        $value = $node.InnerText.Trim()
        foreach ($attributeName in @('value', 'default', 'static')) {
            if ($node.Attributes[$attributeName]) {
                $value = $node.Attributes[$attributeName].Value.Trim()
                break
            }
        }
        if ($value -match '^(?i:true|1|yes)$') { return $true }
        if ($value -match '^(?i:false|0|no)$') { return $false }
    }
    return $null
}

function Test-EntityIdentity {
    param([Parameter(Mandatory)][xml]$Xml, [Parameter(Mandatory)][string]$LogicalName)

    foreach ($node in @($Xml.SelectNodes('//*'))) {
        if ($node.LocalName -in @('Name', 'LogicalName') -and $node.InnerText.Trim() -ieq $LogicalName) {
            return $true
        }
        foreach ($attributeName in @('Name', 'LogicalName', 'logicalName')) {
            if ($node.Attributes[$attributeName] -and $node.Attributes[$attributeName].Value -ieq $LogicalName) {
                return $true
            }
        }
    }
    return $false
}

if ($Mode -eq 'Preview') {
    $rows = @($contract.tables | ForEach-Object {
        [ordered]@{
            tableLogicalName = $_.tableLogicalName
            scope = $_.scope
            enableEditing = [bool]$_.enableEditing
            status = 'maker-action-required'
        }
    })
    $report = [ordered]@{
        version = '1.0'
        mode = 'Preview'
        scenarioSlug = $ScenarioSlug
        applied = $false
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        warning = 'Preview does not apply grid configuration. Complete the maker handoff and then run Verify.'
        tables = $rows
    }
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $artifactRoot 'preview-report.json') -Encoding UTF8

    $markdown = [System.Collections.Generic.List[string]]::new()
    $markdown.Add('# Power Apps grid maker handoff') | Out-Null
    $markdown.Add('') | Out-Null
    $markdown.Add('> **Not applied:** this preview is a handoff only. The wizard does not mutate internal custom-control metadata.') | Out-Null
    $markdown.Add('') | Out-Null
    $markdown.Add('For each table, open **classic solution explorer**, select the table, open **Controls**, choose **Add control**, select **Power Apps grid control**, enable it for the supported clients, and save/publish. Table-level configuration applies to **all views**. Configure **Enable editing** explicitly; do not assume it is enabled.') | Out-Null
    $markdown.Add('') | Out-Null
    $markdown.Add('| Table | Scope | Inline editing | Maker properties |') | Out-Null
    $markdown.Add('|---|---|---:|---|') | Out-Null
    foreach ($table in $contract.tables) {
        $settings = @($propertyTokens.Keys | ForEach-Object { "$_=$([bool]$table.$_)" }) -join '; '
        $markdown.Add("| ``$($table.tableLogicalName)`` | all views | $([bool]$table.enableEditing) | $settings |") | Out-Null
    }
    $markdown.Add('') | Out-Null
    $markdown.Add('After publishing, run stage 61 in `Verify` mode. Verification reads exported solution metadata and requires runtime control `Microsoft.PowerApps.PowerAppsOneGrid`; it does not edit the export or the environment.') | Out-Null
    $markdown -join "`n" | Set-Content -LiteralPath (Join-Path $artifactRoot 'maker-handoff.md') -Encoding UTF8

    $tableHtml = @($contract.tables | ForEach-Object {
        $table = $_
        $settings = @($propertyTokens.Keys | ForEach-Object { "$(ConvertTo-HtmlText $_)=$([bool]$table.$_)" }) -join '; '
        "<tr><th scope=`"row`"><code>$(ConvertTo-HtmlText $table.tableLogicalName)</code></th><td>All views</td><td>$([bool]$table.enableEditing)</td><td>$settings</td></tr>"
    }) -join "`n"
    @"
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Power Apps grid maker handoff</title><style>body{font:1rem/1.5 system-ui;max-width:75rem;margin:auto;padding:2rem}table{border-collapse:collapse;width:100%}th,td{border:1px solid #777;padding:.6rem;text-align:left}.warning{border-left:.4rem solid #a15c00;padding:1rem;background:#fff4ce}</style></head>
<body><main><h1>Power Apps grid maker handoff</h1><p class="warning"><strong>Not applied.</strong> This preview is an operator handoff and never writes internal metadata.</p>
<h2>Supported maker steps</h2><ol><li>Open classic solution explorer.</li><li>Open each table, then Controls.</li><li>Add Power Apps grid control and enable supported clients.</li><li>Configure Enable editing explicitly and set the requested properties.</li><li>Save and publish, then run stage 61 Verify.</li></ol>
<p>Table-level configuration applies to <strong>all views</strong>.</p><table><caption>Requested table grid settings</caption><thead><tr><th scope="col">Table</th><th scope="col">Scope</th><th scope="col">Inline editing</th><th scope="col">Properties</th></tr></thead><tbody>$tableHtml</tbody></table></main></body></html>
"@ | Set-Content -LiteralPath (Join-Path $artifactRoot 'maker-handoff.html') -Encoding UTF8
    Write-Host "Grid handoff created (configuration not applied): $artifactRoot" -ForegroundColor Yellow
    return
}

if ([string]::IsNullOrWhiteSpace($UnpackedSolutionFolder)) {
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
        throw 'Verify export requires -SolutionUniqueName (or DV_SOLUTION_NAME).'
    }
    if (-not (Get-Command pac -ErrorAction SilentlyContinue)) {
        throw 'Verify export requires PAC CLI. Install/authenticate PAC or pass -UnpackedSolutionFolder.'
    }
    $authOutput = (& pac auth list 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $authOutput -notmatch '(?i)active|\*') {
        throw 'Verify export requires an active PAC CLI authentication profile.'
    }
    $exportRoot = Join-Path $artifactRoot 'exported-solution'
    $zipPath = Join-Path $artifactRoot "$SolutionUniqueName-unmanaged.zip"
    if (Test-Path -LiteralPath $exportRoot) { Remove-Item -LiteralPath $exportRoot -Recurse -Force }
    & pac solution export --name $SolutionUniqueName --path $zipPath --managed false --overwrite | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "PAC solution export failed for '$SolutionUniqueName'." }
    & pac solution unpack --zipfile $zipPath --folder $exportRoot --packagetype Unmanaged | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "PAC solution unpack failed for '$SolutionUniqueName'." }
    $UnpackedSolutionFolder = $exportRoot
}

$UnpackedSolutionFolder = [IO.Path]::GetFullPath($UnpackedSolutionFolder)
if (-not (Test-Path -LiteralPath $UnpackedSolutionFolder -PathType Container)) {
    throw "Unpacked solution folder not found: $UnpackedSolutionFolder"
}
if ([string]::IsNullOrWhiteSpace($SolutionUniqueName) -or [string]::IsNullOrWhiteSpace($PublisherPrefix)) {
    throw 'Verify requires solution and publisher identity for scenario-scoped manifest provenance.'
}

$entityFiles = @(Get-ChildItem -LiteralPath $UnpackedSolutionFolder -Filter 'Entity.xml' -File -Recurse)
$verifiedTables = [System.Collections.Generic.List[object]]::new()
foreach ($table in $contract.tables) {
    $matches = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $entityFiles) {
        try { [xml]$xml = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 } catch { continue }
        if (Test-EntityIdentity -Xml $xml -LogicalName $table.tableLogicalName) {
            $matches.Add([pscustomobject]@{ File = $file; Xml = $xml }) | Out-Null
        }
    }
    if ($matches.Count -eq 0) { throw "No exported Entity.xml matched table '$($table.tableLogicalName)'." }
    if ($matches.Count -gt 1) { throw "Ambiguous exported metadata: $($matches.Count) Entity.xml files matched table '$($table.tableLogicalName)'." }

    $match = $matches[0]
    $configs = @($match.Xml.SelectNodes("//*[local-name()='CustomControlDefaultConfigs']"))
    if ($configs.Count -eq 0) {
        throw "Table '$($table.tableLogicalName)' has no CustomControlDefaultConfigs in exported metadata."
    }
    $oneGrid = @($configs[0].SelectNodes(".//*[local-name()='customControl' and @name='Microsoft.PowerApps.PowerAppsOneGrid']"))
    if ($oneGrid.Count -eq 0) {
        throw "Table '$($table.tableLogicalName)' does not declare Microsoft.PowerApps.PowerAppsOneGrid for its table-level all-views default."
    }
    $oneGridConfigNode = $oneGrid[0]
    while ($null -ne $oneGridConfigNode.ParentNode -and $oneGridConfigNode.LocalName -ne 'CustomControlDefaultConfig') {
        $oneGridConfigNode = $oneGridConfigNode.ParentNode
    }
    [xml]$oneGridConfigXml = $oneGridConfigNode.OuterXml

    $observed = [ordered]@{}
    foreach ($propertyName in $propertyTokens.Keys) {
        $actual = Get-XmlBooleanToken -Xml $oneGridConfigXml -Names $propertyTokens[$propertyName]
        if ($null -eq $actual) {
            throw "Table '$($table.tableLogicalName)' is missing exported property token '$($propertyTokens[$propertyName][0])' requested by '$propertyName'."
        }
        $expected = [bool]$table.$propertyName
        if ($actual -ne $expected) {
            throw "Table '$($table.tableLogicalName)' property '$propertyName' mismatch in exported metadata: expected $expected; found $actual."
        }
        $observed[$propertyName] = $actual
    }
    $verifiedTables.Add([ordered]@{
        tableLogicalName = $table.tableLogicalName
        scope = 'all-views'
        runtimeControl = 'Microsoft.PowerApps.PowerAppsOneGrid'
        entityXml = [IO.Path]::GetRelativePath($UnpackedSolutionFolder, $match.File.FullName).Replace('\', '/')
        properties = $observed
        status = 'verified-from-exported-metadata'
    }) | Out-Null
}

$verification = [ordered]@{
    version = '1.0'
    mode = 'Verify'
    scenarioSlug = $ScenarioSlug
    verified = $true
    readOnly = $true
    verificationBasis = 'Supported unmanaged solution export/unpack metadata; no internal metadata was mutated.'
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    tables = @($verifiedTables)
}
$verification | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $artifactRoot 'verification-report.json') -Encoding UTF8

. (Join-Path $PSScriptRoot 'helpers/wizard-hardening.ps1')
foreach ($table in $verifiedTables) {
    Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'grid-control' -Name "$($table.tableLogicalName)|all-views" -Status 'verified' -Step '61-configure-power-apps-grid.ps1' -Details @{ runtimeControl = $table.runtimeControl; scope = 'all-views'; source = $table.entityXml } | Out-Null
}
Write-Host "Power Apps grid verified from exported metadata for $($verifiedTables.Count) table(s)." -ForegroundColor Green
