<#
=============================================================================
COMPONENT:    Contract Integrity Test
FILE:         scripts/ci/test-contract-integrity.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-24
ENVIRONMENT:  PowerShell 7 | CI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Validates that the executable wizard surface matches wizard.profile.json and
the canonical documentation surfaces.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            CI contract gate
- Inputs:          wizard profile, scripts, skills, and documentation
- Outputs:         actionable failures or a successful contract check
- Dependencies:    PowerShell 7
- Side Effects:    none

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Missing configured modules and folders fail the check.
✔ Missing local script/document references fail the check.
✔ Ambiguous script numbers and contract-version drift fail the check.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Keep this test credential-free and safe for pull-request CI.
- Do not silently exempt missing behavior declared mandatory by the profile.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$profilePath = Join-Path $repoRoot 'wizard.profile.json'
$wizardProfile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
$bootstrapFolder = Join-Path $repoRoot $wizardProfile.conventions.bootstrapFolder
$failures = [System.Collections.Generic.List[string]]::new()

function Add-ContractFailure {
    param([string]$Message)

    $failures.Add($Message) | Out-Null
}

function Test-RequiredPath {
    param(
        [string]$RelativePath,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $RelativePath))) {
        Add-ContractFailure "$Description is missing: $RelativePath"
    }
}

if ($wizardProfile.discovery.defaultMode -ne 'demo-builder') {
    Add-ContractFailure 'wizard.profile.json must default to demo-builder.'
}

$wizardModeNames = @($wizardProfile.discovery.modes.PSObject.Properties.Name)
foreach ($requiredMode in @('demo-builder', 'advanced-builder', 'framework-acceptance')) {
    if ($wizardModeNames -notcontains $requiredMode) {
        Add-ContractFailure "wizard.profile.json is missing mode '$requiredMode'."
    }
}

if (-not [bool]$wizardProfile.discovery.modes.'framework-acceptance'.explicitSelectionRequired) {
    Add-ContractFailure 'Framework Acceptance must require explicit selection.'
}

$wizardScriptPath = Join-Path $bootstrapFolder '05-start-wizard.ps1'
$wizardScriptText = Get-Content -LiteralPath $wizardScriptPath -Raw
if ($wizardScriptText -notmatch "\[string\]\`$Mode\s*=\s*'demo-builder'" -or
    $wizardScriptText -notmatch "ValidateSet\('demo-builder',\s*'advanced-builder',\s*'framework-acceptance'\)") {
    Add-ContractFailure '05-start-wizard.ps1 must expose the three modes and default to demo-builder.'
}

foreach ($folderProperty in @('payloadFolder', 'scenarioFolder', 'bootstrapFolder')) {
    $relativeFolder = "$($wizardProfile.conventions.$folderProperty)"
    Test-RequiredPath -RelativePath $relativeFolder -Description "Configured $folderProperty folder"
}

foreach ($moduleName in @($wizardProfile.execution.coreModules)) {
    Test-RequiredPath -RelativePath (Join-Path $wizardProfile.conventions.bootstrapFolder $moduleName) -Description 'Core module'
}

foreach ($optionalModule in @($wizardProfile.execution.optionalModules.PSObject.Properties)) {
    if ([bool]$optionalModule.Value.enabled) {
        Test-RequiredPath -RelativePath (Join-Path $wizardProfile.conventions.bootstrapFolder $optionalModule.Value.script) -Description "Enabled optional module '$($optionalModule.Name)'"
    }
}

$prerequisiteScriptPath = Join-Path $bootstrapFolder '00-prereq-check.ps1'
$prerequisiteScriptText = Get-Content -LiteralPath $prerequisiteScriptPath -Raw
if ($prerequisiteScriptText -notmatch '\[string\[\]\]\$Arguments' -or $prerequisiteScriptText -notmatch '&\s+\$Command\s+@Arguments') {
    Add-ContractFailure '00-prereq-check.ps1 must pass version arguments through a non-automatic argument-array parameter.'
}
if ($prerequisiteScriptText -notmatch '\$exitCode\s*=\s*\$LASTEXITCODE' -or $prerequisiteScriptText -notmatch '\$exitCode\s+-ne\s+0') {
    Add-ContractFailure '00-prereq-check.ps1 must reject installed tools whose version command exits unsuccessfully.'
}
if ($prerequisiteScriptText -notmatch 'Power Platform CLI[^\r\n]+-Arguments\s+@\(''help''\)') {
    Add-ContractFailure "00-prereq-check.ps1 must probe PAC CLI with 'pac help', which returns a reliable process exit code."
}

$tableScriptText = Get-Content -LiteralPath (Join-Path $bootstrapFolder '20-build-tables.ps1') -Raw
if ($tableScriptText -notmatch '\$Payload\.EntityDefinition\s*\?\?\s*\$Payload' -or
    $tableScriptText -notmatch 'Microsoft\.Dynamics\.CRM\.EntityMetadata' -or
    $tableScriptText -notmatch 'IsPrimaryName\s*=\s*\$true') {
    Add-ContractFailure '20-build-tables.ps1 must translate wrapped table payloads into EntityMetadata with a primary-name attribute.'
}

$relationshipScriptText = Get-Content -LiteralPath (Join-Path $bootstrapFolder '40-build-relationships.ps1') -Raw
if ($relationshipScriptText -notmatch '\$Relationship\.RelationshipDefinition\s*\?\?\s*\$Relationship' -or
    $relationshipScriptText -notmatch 'Microsoft\.Dynamics\.CRM\.LookupAttributeMetadata' -or
    $relationshipScriptText -notmatch '\$property\.Name\s+-ne\s+''ReferencingAttribute''') {
    Add-ContractFailure '40-build-relationships.ps1 must translate wrapped relationship payloads and create the referencing lookup metadata.'
}

$postBuildImplementations = @{
    'solution-inventory-collect' = '50-add-to-solution.ps1'
    'solution-inventory-sync' = '50-add-to-solution.ps1'
    'solution-membership-report' = '50-add-to-solution.ps1'
    'publish' = '80-post-build-analysis.ps1'
}
foreach ($postBuildStep in @($wizardProfile.execution.mandatoryPostBuildSteps)) {
    if ($postBuildStep -match '\.ps1$') {
        Test-RequiredPath -RelativePath (Join-Path $wizardProfile.conventions.bootstrapFolder $postBuildStep) -Description 'Mandatory post-build module'
        continue
    }

    if (-not $postBuildImplementations.ContainsKey($postBuildStep)) {
        Add-ContractFailure "Mandatory post-build step '$postBuildStep' has no documented implementing script."
        continue
    }

    $implementation = $postBuildImplementations[$postBuildStep]
    Test-RequiredPath -RelativePath (Join-Path $wizardProfile.conventions.bootstrapFolder $implementation) -Description "Implementation for mandatory post-build step '$postBuildStep'"
}

$canonicalSurfaces = @(
    'README.md',
    'MIGRATION.md',
    'docs/onboarding.md',
    'docs/wizard-contract-v1.md',
    '.github/copilot-instructions.md',
    '.github/prompts/power-platform-demo-wizard.prompt.md',
    '.github/skills/power-platform-wizard-init/SKILL.md',
    '.claude/skills/power-platform-vscode-wizard/SKILL.md'
)

foreach ($surface in $canonicalSurfaces) {
    $surfacePath = Join-Path $repoRoot $surface
    if (-not (Test-Path -LiteralPath $surfacePath)) {
        Add-ContractFailure "Canonical contract surface is missing: $surface"
        continue
    }

    $content = Get-Content -LiteralPath $surfacePath -Raw
    $scriptReferences = [regex]::Matches($content, '(?<![A-Za-z0-9_./-])(?:scripts/bootstrap/)?[0-9]{2}-[A-Za-z0-9._-]+\.ps1')
    foreach ($match in $scriptReferences) {
        $relativeScript = $match.Value.Replace('/', [IO.Path]::DirectorySeparatorChar)
        if (-not $relativeScript.StartsWith("scripts$([IO.Path]::DirectorySeparatorChar)bootstrap$([IO.Path]::DirectorySeparatorChar)")) {
            $relativeScript = Join-Path $wizardProfile.conventions.bootstrapFolder $relativeScript
        }
        Test-RequiredPath -RelativePath $relativeScript -Description "Script referenced by $surface"
    }

    $markdownLinks = [regex]::Matches($content, '\[[^\]]+\]\((?!https?://|mailto:|#)(?<path>[^)#]+)(?:#[^)]+)?\)')
    foreach ($match in $markdownLinks) {
        $target = [Uri]::UnescapeDataString($match.Groups['path'].Value)
        $resolvedTarget = Join-Path (Split-Path $surfacePath -Parent) $target
        if (-not (Test-Path -LiteralPath $resolvedTarget)) {
            Add-ContractFailure "Local link in $surface does not resolve: $target"
        }
    }
}

$numberedScripts = @(Get-ChildItem -LiteralPath $bootstrapFolder -Filter '*.ps1' -File | Where-Object { $_.Name -match '^(?<number>[0-9]{2})-' })
$duplicateNumbers = @($numberedScripts | Group-Object { [regex]::Match($_.Name, '^[0-9]{2}').Value } | Where-Object Count -gt 1)
foreach ($duplicate in $duplicateNumbers) {
    $names = @($duplicate.Group.Name | Sort-Object)
    $documentedWrapper = $false
    foreach ($script in $duplicate.Group) {
        $scriptText = Get-Content -LiteralPath $script.FullName -Raw
        if ($scriptText -match '(?i)compatibility wrapper|wrapper for|delegates to') {
            $documentedWrapper = $true
            break
        }
    }
    if (-not $documentedWrapper) {
        Add-ContractFailure "Bootstrap number $($duplicate.Name) is ambiguous: $($names -join ', '). Renumber or document a wrapper/implementation relationship."
    }
}

$contractText = Get-Content -LiteralPath (Join-Path $repoRoot 'docs/wizard-contract-v1.md') -Raw
$contractVersionMatch = [regex]::Match($contractText, '(?im)^Version:\s*(?<version>[^\s]+)\s*$')
if (-not $contractVersionMatch.Success) {
    Add-ContractFailure 'docs/wizard-contract-v1.md does not declare a Version value.'
} elseif ($contractVersionMatch.Groups['version'].Value -ne "$($wizardProfile.contractVersion)") {
    Add-ContractFailure "Contract version mismatch: profile=$($wizardProfile.contractVersion), document=$($contractVersionMatch.Groups['version'].Value)."
}

if ($failures.Count -gt 0) {
    $message = "Contract integrity failed with $($failures.Count) issue(s):`n - $($failures -join "`n - ")"
    throw $message
}

Write-Host 'Contract integrity checks passed.' -ForegroundColor Green