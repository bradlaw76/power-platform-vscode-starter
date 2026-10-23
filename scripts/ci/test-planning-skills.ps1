<#
=============================================================================
COMPONENT:    Planning Skills Contract and Parity Tests
FILE:         scripts/ci/test-planning-skills.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-23
ENVIRONMENT:  PowerShell 7 | Offline CI
OVERVIEW
Check Copilot/Claude planning instructions, semantic types and traceability.
ARCHITECTURE
- Inputs: skill Markdown, canonical standards, entry-point instructions.
- Outputs: assertion count; no writes, authentication or external dependencies.
TEST CASES
- Both platforms preserve identical behavior, planning gates and boundaries.
- Native field mappings and traceability contracts are present and consistent.
NON-NEGOTIABLES
- These are static instruction checks, not live Dataverse or agent evaluations.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:checks = 0

function Assert-Contains {
    param([string]$Content, [string]$Pattern, [string]$Context)
    if ($Content -notmatch $Pattern) { throw "$Context is missing contract: $Pattern" }
    $script:checks++
}

foreach ($name in @('dataverse-solution-architect', 'power-platform-requirements-analyst')) {
    $contents = @()
    foreach ($platform in @('.github', '.claude')) {
        $path = "$platform/skills/$name/SKILL.md"
        $content = Get-Content -LiteralPath (Join-Path $repoRoot $path) -Raw
        Assert-Contains $content "(?s)^---\r?\nname: $name\r?\ndescription: .+?\r?\n---" $path
        foreach ($pattern in @(
            'Skill availability is not runtime installation',
            'read-only', 'FrameworkRoot', 'TargetProjectRoot',
            'docs/framework-maintenance-preflight\.md',
            'docs/onboarding\.md', 'docs/wizard-contract-v1\.md',
            'demo-builder', 'advanced-builder', 'framework-acceptance',
            'six business questions', 'consolidated', 'separately approved cleanup',
            'do not (implement|begin)', 'Do not begin Skill 3',
            'specs/<scenario-slug>/', 'spec\.md', 'plan\.md', 'tasks\.md',
            'answers\.md', 'report-mappings\.md', 'requirements-traceability\.md',
            'semantic-field-type-standard\.md', 'remaining work only',
            'cardinality', 'requiredness', 'cascade behavior',
            'latest/all/selected', 'ordering field', 'tasks per selected record',
            'approval', 'block', 'commit', 'push', 'merge'
        )) {
            Assert-Contains $content $pattern $path
        }
        $contents += ($content -replace '(?m)^FILE:.*$', 'FILE: platform-normalized')
    }
    if ($contents[0] -cne $contents[1]) { throw "Copilot/Claude instructions drifted for $name." }
    $script:checks++
}

$standard = Get-Content (Join-Path $repoRoot 'docs/semantic-field-type-standard.md') -Raw
foreach ($pattern in @(
        'StringAttributeMetadata, Email', 'StringAttributeMetadata, Phone',
        'StringAttributeMetadata, Url', 'MoneyAttributeMetadata',
        'DecimalAttributeMetadata', 'IntegerAttributeMetadata', 'DoubleAttributeMetadata',
        'BooleanAttributeMetadata', 'PicklistAttributeMetadata',
        'MultiSelectPicklistAttributeMetadata', 'LookupAttributeMetadata',
        'DateOnly format and DateOnly behavior', 'UserLocal behavior',
        'TimeZoneIndependent behavior', 'MemoAttributeMetadata',
        'FileAttributeMetadata', 'ImageAttributeMetadata', 'Duration',
        'leading zeros', 'never.*numeric', 'stable option values',
        'blocked', 'payload', 'Requirement IDs', 'Verification'
    )) {
    Assert-Contains $standard $pattern 'Semantic Field Type Standard'
}
$exampleMatch = [regex]::Match($standard, '(?s)```json\s*(.*?)\s*```')
if (-not $exampleMatch.Success) { throw 'Missing semantic field payload example.' }
$column = $exampleMatch.Groups[1].Value | ConvertFrom-Json
$envelope = @{ TableLogicalName = 'example_request'; Columns = @($column) } | ConvertTo-Json -Depth 20
$schemaPath = Join-Path $repoRoot 'schemas/payloads/columns.schema.json'
if (-not (Test-Json -Json $envelope -SchemaFile $schemaPath -ErrorAction Stop) -or
    $column.'@odata.type' -cne 'Microsoft.Dynamics.CRM.StringAttributeMetadata' -or
    $column.FormatName.Value -cne 'Email' -or $column.MaxLength -ne 254) {
    throw 'Email example does not preserve native type/format/length and existing payload schema.'
}
$script:checks++
$traceability = Get-Content (Join-Path $repoRoot 'docs/requirements-traceability.md') -Raw
foreach ($pattern in @(
        'REQ-###', 'Never renumber', 'Source / outcome', 'User task',
        'Success criterion', 'Design / field / relationship', 'Component / payload path',
        'Implementation task ID', 'Verification case / method', 'Evidence path / actual result',
        'Status / owner / approval', 'both directions', 'Not executed',
        'Reopen affected approvals', 'SPEC\.md', 'SYSTEM_MANIFEST\.json\.md'
    )) {
    Assert-Contains $traceability $pattern 'Traceability standard'
}
foreach ($path in @(
        '.github/copilot-instructions.md', 'CLAUDE.md',
        '.github/skills/power-platform-wizard-init/SKILL.md',
        '.claude/skills/power-platform-vscode-wizard/SKILL.md'
    )) {
    $content = Get-Content (Join-Path $repoRoot $path) -Raw
    foreach ($name in @('dataverse-solution-architect', 'power-platform-requirements-analyst')) {
        Assert-Contains $content $name $path
    }
    Assert-Contains $content 'framework-maintenance-preflight\.md' $path
}
Write-Host "Planning skills: $script:checks static contract checks passed."
