<#
=============================================================================
COMPONENT:    Export Unmanaged Solution
FILE:         scripts/bootstrap/95-export-unmanaged-solution.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-31
ENVIRONMENT:  PowerShell 7 | PAC CLI | Local inspection
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$OutputFolder = '',
    [switch]$PreviewOnly,
    [scriptblock]$PacInvoker
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ([string]::IsNullOrWhiteSpace($SolutionUniqueName) -and -not $PreviewOnly) { throw 'SolutionUniqueName is required.' }
$effectiveSolutionName = if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { '[not configured]' } else { $SolutionUniqueName }
if ([string]::IsNullOrWhiteSpace($OutputFolder)) { $OutputFolder = Join-Path $repoRoot ".wizard-metrics/exports/$ScenarioSlug" }
$membershipPath = Join-Path $repoRoot ".wizard-metrics/artifacts/contamination/$ScenarioSlug/solution-membership-report.json"
$evidencePath = Join-Path $repoRoot ".wizard-metrics/artifacts/export/$ScenarioSlug.json"
$zipPath = Join-Path $OutputFolder "$effectiveSolutionName.zip"
$unpackPath = Join-Path $OutputFolder 'unpacked'
$commands = @(
    @('solution','export','--name',$effectiveSolutionName,'--path',$zipPath,'--managed','false','--overwrite'),
    @('solution','unpack','--zipfile',$zipPath,'--folder',$unpackPath,'--packagetype','Unmanaged','--allowDelete','false')
)
New-Item -ItemType Directory -Path (Split-Path $evidencePath -Parent) -Force | Out-Null
if ($PreviewOnly) {
    [ordered]@{ scenarioSlug=$ScenarioSlug; solution=$effectiveSolutionName; preview=$true; commands=@($commands | ForEach-Object { "pac $($_ -join ' ')" }); importPermitted=$false } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    exit 0
}
if (-not (Test-Path -LiteralPath $membershipPath -PathType Leaf)) { throw 'Final solution membership report is missing; export is blocked.' }
$membership = Get-Content -LiteralPath $membershipPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $membership.ExportAllowed -or @($membership.Items | Where-Object State -in @('Missing','Failed','Unauthorized')).Count -gt 0) { throw 'Final solution membership did not pass; export is blocked.' }
if ($null -eq $PacInvoker) { $PacInvoker = { param([string[]]$Arguments) & pac @Arguments; if ($LASTEXITCODE -ne 0) { throw "pac exited with code $LASTEXITCODE." } } }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
Remove-Item -LiteralPath $zipPath,$unpackPath -Recurse -Force -ErrorAction SilentlyContinue
foreach ($arguments in $commands) { & $PacInvoker ([string[]]$arguments) }
if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw "PAC export did not create '$zipPath'." }
$solutionXmlPath = Get-ChildItem -LiteralPath $unpackPath -Filter 'Solution.xml' -File -Recurse | Select-Object -First 1
if ($null -eq $solutionXmlPath) { throw 'Unpacked solution does not contain Solution.xml.' }
[xml]$solutionXml = Get-Content -LiteralPath $solutionXmlPath.FullName -Raw -Encoding UTF8
$uniqueName = "$($solutionXml.ImportExportXml.SolutionManifest.UniqueName)"
if ($uniqueName -cne $SolutionUniqueName) { throw "Unpacked solution identity '$uniqueName' does not match '$SolutionUniqueName'." }
$normalizeId = { param($Value) "$Value".Trim().Trim('{','}').ToLowerInvariant() }
$expectedComponents = @($membership.Items | ForEach-Object {
    $objectId = & $normalizeId $_.ObjectId
    if ([string]::IsNullOrWhiteSpace($objectId) -or $null -eq $_.ComponentType) { throw "Membership item '$($_.Category)|$($_.Name)' lacks a component type or stable object ID." }
    [pscustomobject]@{ Key="$($_.ComponentType)|$objectId"; Category="$($_.Category)"; Name="$($_.Name)"; ComponentType="$($_.ComponentType)"; ObjectId=$objectId }
})
$rootComponentsNode = $solutionXml.ImportExportXml.SolutionManifest.RootComponents
$rootComponentNodes = if ($null -ne $rootComponentsNode -and $rootComponentsNode.PSObject.Properties.Name -contains 'RootComponent') { @($rootComponentsNode.RootComponent) } else { @() }
$packageComponents = @($rootComponentNodes | ForEach-Object {
    $objectId = & $normalizeId $_.id
    if ([string]::IsNullOrWhiteSpace($objectId) -or [string]::IsNullOrWhiteSpace("$($_.type)")) { throw 'Unpacked Solution.xml contains a root component without a type and stable object ID.' }
    [pscustomobject]@{ Key="$($_.type)|$objectId"; ComponentType="$($_.type)"; ObjectId=$objectId; SchemaName="$($_.schemaName)" }
})
$duplicateExpected = @($expectedComponents | Group-Object Key | Where-Object Count -gt 1)
$duplicatePackage = @($packageComponents | Group-Object Key | Where-Object Count -gt 1)
if ($duplicateExpected.Count -gt 0) { throw "Final membership contains duplicate component identity '$($duplicateExpected[0].Name)'." }
if ($duplicatePackage.Count -gt 0) { throw "Unpacked package contains duplicate root component identity '$($duplicatePackage[0].Name)'." }
$expectedKeys = @{}; foreach ($component in $expectedComponents) { $expectedKeys[$component.Key] = $component }
$packageKeys = @{}; foreach ($component in $packageComponents) { $packageKeys[$component.Key] = $component }
$missingComponents = @($expectedComponents | Where-Object { -not $packageKeys.ContainsKey($_.Key) })
$unrelatedComponents = @($packageComponents | Where-Object { -not $expectedKeys.ContainsKey($_.Key) })
if ($missingComponents.Count -gt 0) { throw "Unpacked package is missing required component '$($missingComponents[0].Category)|$($missingComponents[0].Name)' ($($missingComponents[0].Key))." }
if ($unrelatedComponents.Count -gt 0) { throw "Unpacked package contains unrelated component '$($unrelatedComponents[0].SchemaName)' ($($unrelatedComponents[0].Key))." }
$files = @(Get-ChildItem -LiteralPath $unpackPath -File -Recurse | ForEach-Object { [IO.Path]::GetRelativePath($unpackPath,$_.FullName).Replace('\','/') } | Sort-Object)
[ordered]@{ scenarioSlug=$ScenarioSlug; solution=$SolutionUniqueName; preview=$false; managed=$false; importPermitted=$false; zip=$zipPath; unpacked=$unpackPath; files=$files; membershipItemCount=@($membership.Items).Count; inspection=[ordered]@{ expected=$expectedComponents.Count; matched=$expectedComponents.Count; missing=@(); unrelated=@() } } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $evidencePath -Encoding UTF8