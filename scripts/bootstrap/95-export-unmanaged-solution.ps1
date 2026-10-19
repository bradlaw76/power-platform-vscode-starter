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
$frameworkRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/wizard-source-protection.ps1')
$applicationRoots = Initialize-WizardApplicationContext -FrameworkRoot $frameworkRoot
$repoRoot = $applicationRoots.TargetProjectRoot
if ([string]::IsNullOrWhiteSpace($SolutionUniqueName) -and -not $PreviewOnly) { throw 'SolutionUniqueName is required.' }
$effectiveSolutionName = if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { '[not configured]' } else { $SolutionUniqueName }
if ([string]::IsNullOrWhiteSpace($OutputFolder)) { $OutputFolder = Join-Path $repoRoot ".wizard-metrics/exports/$ScenarioSlug" }
$membershipPath = Join-Path $repoRoot ".wizard-metrics/artifacts/contamination/$ScenarioSlug/solution-membership-report.json"
$evidencePath = Join-Path $repoRoot ".wizard-metrics/artifacts/export/$ScenarioSlug.json"
$zipPath = Join-Path $OutputFolder "$effectiveSolutionName.zip"
$unpackPath = Join-Path $OutputFolder 'unpacked'
$null = Assert-WizardWritablePath -Path $evidencePath -FrameworkRoot $frameworkRoot -TargetProjectRoot $repoRoot
$null = Assert-WizardWritablePath -Path $OutputFolder -FrameworkRoot $frameworkRoot -TargetProjectRoot $repoRoot
$null = Assert-WizardWritablePath -Path $zipPath -FrameworkRoot $frameworkRoot -TargetProjectRoot $repoRoot
$null = Assert-WizardWritablePath -Path $unpackPath -FrameworkRoot $frameworkRoot -TargetProjectRoot $repoRoot
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
$inheritedMembership = @($membership.Items | Where-Object {
    [string]::IsNullOrWhiteSpace("$($_.ObjectId)") -or $null -eq $_.ComponentType
})
$invalidInheritedMembership = @($inheritedMembership | Where-Object {
    "$($_.Reason)" -notlike 'Inherited from include-all table root*'
})
if ($invalidInheritedMembership.Count -gt 0) {
    throw "Membership item '$($invalidInheritedMembership[0].Category)|$($invalidInheritedMembership[0].Name)' lacks explicit or inherited component evidence."
}
$rootCategories = @('tables', 'flows', 'dashboards', 'model-driven-apps', 'sitemap-updates', 'web-resources', 'security-roles')
$schemaIdentityCategories = @('tables', 'model-driven-apps', 'sitemap-updates', 'web-resources')
$expectedComponents = @($membership.Items | Where-Object {
    $_.Category -in $rootCategories -and -not [string]::IsNullOrWhiteSpace("$($_.ObjectId)") -and $null -ne $_.ComponentType
} | ForEach-Object {
    $identity = if ($_.Category -in $schemaIdentityCategories) {
        "schema:$("$($_.Name)".Trim().ToLowerInvariant())"
    } else {
        "id:$(& $normalizeId $_.ObjectId)"
    }
    [pscustomobject]@{ Key="$($_.ComponentType)|$identity"; Category="$($_.Category)"; Name="$($_.Name)"; ComponentType="$($_.ComponentType)"; ObjectId=(& $normalizeId $_.ObjectId) }
})
$rootComponentsNode = $solutionXml.ImportExportXml.SolutionManifest.RootComponents
$rootComponentNodes = if ($null -ne $rootComponentsNode -and $rootComponentsNode.PSObject.Properties.Name -contains 'RootComponent') { @($rootComponentsNode.RootComponent) } else { @() }
$packageComponents = @($rootComponentNodes | ForEach-Object {
    $componentType = $_.GetAttribute('type')
    $objectId = & $normalizeId $_.GetAttribute('id')
    $schemaName = $_.GetAttribute('schemaName').Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($componentType) -or ([string]::IsNullOrWhiteSpace($objectId) -and [string]::IsNullOrWhiteSpace($schemaName))) {
        throw 'Unpacked Solution.xml contains a root component without a type and stable ID or schema name.'
    }
    $identity = if (-not [string]::IsNullOrWhiteSpace($objectId)) { "id:$objectId" } else { "schema:$schemaName" }
    [pscustomobject]@{ Key="$componentType|$identity"; ComponentType=$componentType; ObjectId=$objectId; SchemaName=$schemaName }
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
[ordered]@{ scenarioSlug=$ScenarioSlug; solution=$SolutionUniqueName; preview=$false; managed=$false; importPermitted=$false; zip=$zipPath; unpacked=$unpackPath; files=$files; membershipItemCount=@($membership.Items).Count; inheritedMembershipItemCount=$inheritedMembership.Count; inspection=[ordered]@{ expected=$expectedComponents.Count; matched=$expectedComponents.Count; missing=@(); unrelated=@() } } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $evidencePath -Encoding UTF8