<#
=============================================================================
COMPONENT:    GCC Framework Acceptance Planning Test
FILE:         scripts/ci/test-gcc-framework-acceptance-plan.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-26
ENVIRONMENT:  PowerShell 7 | Credential-Free CI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Validates the isolated GCC Framework Acceptance planning contract without
authenticating to or querying Dataverse.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Every custom component identity must use publisher prefix ppvs.
- Every synthetic row must use the approved acceptance source tag.
- Permanent-environment and cleanup prohibitions must remain explicit.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scenarioRoot = Join-Path $repoRoot 'specs/gcc-framework-acceptance'
$payloadRoot = Join-Path $repoRoot 'payloads/scenarios/gcc-framework-acceptance'
$solutionName = 'LabEquipmentCheckoutAcceptance20260826'
$sourceTag = 'ppvs-acceptance-20260826'
$heroLabel = 'LECA-20260826-001 — Full Review-to-Return Journey'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        $failures.Add($Message) | Out-Null
    }
}

$requiredScenarioFiles = @(
    'paused-answers.md',
    'answers.md',
    'spec.md',
    'plan.md',
    'tasks.md',
    'report-mappings.md',
    'forms.json',
    'views.json',
    'demo-data-plan.json',
    'component-inventory.md',
    'framework-acceptance-execution-plan.md',
    'authorization-boundary-record.md',
    'mutation-inventory.md',
    'revised-apply-plan.md',
    'reports/business-process-flow-designer-handoff.md'
)
foreach ($relativePath in $requiredScenarioFiles) {
    Assert-Condition -Condition (Test-Path -LiteralPath (Join-Path $scenarioRoot $relativePath) -PathType Leaf) -Message "Missing scenario artifact: $relativePath"
}

$tablePayloads = @(Get-ChildItem -LiteralPath $payloadRoot -Filter 'table-*.json' -File)
$columnPayloads = @(Get-ChildItem -LiteralPath $payloadRoot -Filter 'columns-*.json' -File)
$relationshipPayloads = @(Get-ChildItem -LiteralPath $payloadRoot -Filter 'relationships-*.json' -File)
$processPayloads = @(Get-ChildItem -LiteralPath $payloadRoot -Filter 'process-*.json' -File)
Assert-Condition -Condition ($tablePayloads.Count -eq 2) -Message "Expected 2 table payloads; found $($tablePayloads.Count)."
Assert-Condition -Condition ($columnPayloads.Count -eq 2) -Message "Expected 2 column payloads; found $($columnPayloads.Count)."
Assert-Condition -Condition ($relationshipPayloads.Count -eq 1) -Message "Expected 1 relationship payload; found $($relationshipPayloads.Count)."
Assert-Condition -Condition ($processPayloads.Count -eq 1) -Message "Expected 1 process payload; found $($processPayloads.Count)."

$customNames = [System.Collections.Generic.List[string]]::new()
foreach ($file in $tablePayloads) {
    $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $customNames.Add([string]$document.EntityDefinition.SchemaName) | Out-Null
}
foreach ($file in $columnPayloads) {
    $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $customNames.Add([string]$document.TableLogicalName) | Out-Null
    foreach ($column in @($document.Columns)) {
        $customNames.Add([string]$column.SchemaName) | Out-Null
    }
}
foreach ($file in $relationshipPayloads) {
    $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($relationship in @($document.Relationships)) {
        $definition = $relationship.RelationshipDefinition
        foreach ($name in @($relationship.SchemaName, $definition.SchemaName, $definition.ReferencedEntity, $definition.ReferencedAttribute, $definition.ReferencingEntity, $definition.ReferencingAttribute, $definition.Lookup.SchemaName)) {
            $customNames.Add([string]$name) | Out-Null
        }
    }
}
foreach ($name in @($customNames | Sort-Object -Unique)) {
    Assert-Condition -Condition ($name -match '^ppvs_[a-z0-9_]+$') -Message "Custom component identity does not use prefix ppvs: $name"
}

$process = Get-Content -LiteralPath $processPayloads[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Condition -Condition ($process.PrimaryProcessEntity -eq 'ppvs_checkoutrequest') -Message 'BPF primary table must be ppvs_checkoutrequest.'
$expectedProcessUniqueName = 'ppvs_' + ([regex]::Replace($process.BusinessProcessFlowName.ToLowerInvariant(), '[^a-z0-9]+', '_').Trim('_'))
Assert-Condition -Condition ($expectedProcessUniqueName -eq 'ppvs_lab_equipment_checkout_lifecycle') -Message "Unexpected BPF unique name: $expectedProcessUniqueName"

$answers = Get-Content -LiteralPath (Join-Path $scenarioRoot 'answers.md') -Raw -Encoding UTF8
$plan = Get-Content -LiteralPath (Join-Path $scenarioRoot 'plan.md') -Raw -Encoding UTF8
$inventory = Get-Content -LiteralPath (Join-Path $scenarioRoot 'component-inventory.md') -Raw -Encoding UTF8
foreach ($document in @($answers, $plan, $inventory)) {
    Assert-Condition -Condition $document.Contains($solutionName) -Message "Planning artifact is missing solution identity $solutionName."
}
Assert-Condition -Condition ($answers -match '(?m)^- Unique Name: ppvs_[a-z0-9_]+\r?$') -Message 'Review app unique name must use prefix ppvs.'
Assert-Condition -Condition ($answers.Contains('Publisher unique name: `PowerPlatformVSCodeStarter`')) -Message 'Permanent publisher unique name is missing.'
Assert-Condition -Condition ($answers.Contains('create once as a permanent framework publisher; never include it in cleanup')) -Message 'Permanent publisher creation or cleanup exclusion is missing.'

$formsContract = Get-Content -LiteralPath (Join-Path $scenarioRoot 'forms.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$viewsContract = Get-Content -LiteralPath (Join-Path $scenarioRoot 'views.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Condition -Condition (@($formsContract.Forms | Where-Object Name -eq 'Lab Asset Main').Count -eq 1) -Message 'Lab Asset Main form contract is missing.'
Assert-Condition -Condition (@($formsContract.Forms | Where-Object Name -eq 'Checkout Request Main').Count -eq 1) -Message 'Checkout Request Main form contract is missing.'
Assert-Condition -Condition (@($viewsContract.Views | Where-Object { $_.Name -eq 'Active Checkout Requests' -and $_.Disposition -eq 'adopt-generated-active' }).Count -eq 1) -Message 'Active Checkout Requests must adopt the generated Active view.'
Assert-Condition -Condition (@($viewsContract.Views | Where-Object { $_.Name -eq 'Available Lab Assets' -and $_.Disposition -eq 'create-custom' }).Count -eq 1) -Message 'Available Lab Assets must be a separate custom view.'

$demoData = Get-Content -LiteralPath (Join-Path $scenarioRoot 'demo-data-plan.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Condition -Condition ($demoData.SolutionUniqueName -eq $solutionName) -Message 'Demo-data plan solution identity is incorrect.'
Assert-Condition -Condition ($demoData.PublisherPrefix -eq 'ppvs') -Message 'Demo-data plan publisher prefix is incorrect.'
Assert-Condition -Condition ($demoData.SourceTag -eq $sourceTag) -Message 'Demo-data plan source tag is incorrect.'
$records = @($demoData.Tables | ForEach-Object { @($_.Records) })
Assert-Condition -Condition ($records.Count -eq 8) -Message "Expected 8 synthetic records; found $($records.Count)."
foreach ($record in $records) {
    Assert-Condition -Condition ($record.ppvs_acceptancesourcetag -eq $sourceTag) -Message "Synthetic record '$($record.ppvs_name)' has an incorrect source tag."
}
$heroRecords = @($records | Where-Object { $_.ppvs_name -eq $heroLabel })
Assert-Condition -Condition ($heroRecords.Count -eq 1) -Message "Expected exactly one hero record '$heroLabel'; found $($heroRecords.Count)."

$safetyText = @(
    $answers
    Get-Content -LiteralPath (Join-Path $scenarioRoot 'paused-answers.md') -Raw -Encoding UTF8
    Get-Content -LiteralPath (Join-Path $scenarioRoot 'framework-acceptance-execution-plan.md') -Raw -Encoding UTF8
) -join "`n"
foreach ($requiredSafetyText in @('permanent', 'must not be reset or deleted', 'Cleanup authorization: not granted', 'Destructive cleanup | Prohibited')) {
    Assert-Condition -Condition ($safetyText -match [regex]::Escape($requiredSafetyText)) -Message "Missing permanent-environment safety constraint: $requiredSafetyText"
}

$boundaryRecord = Get-Content -LiteralPath (Join-Path $scenarioRoot 'authorization-boundary-record.md') -Raw -Encoding UTF8
Assert-Condition -Condition ($boundaryRecord.Contains('exceeded that preview authorization boundary')) -Message 'Authorization-boundary overrun is not recorded.'
Assert-Condition -Condition ($boundaryRecord.Contains('Dataverse mutations: none')) -Message 'No-mutation result is not recorded in the authorization-boundary record.'

if ($failures.Count -gt 0) {
    throw "GCC Framework Acceptance planning validation failed:`n - $($failures -join "`n - ")"
}

Write-Host "GCC Framework Acceptance planning checks passed: $($customNames.Count) prefixed identity references; $($records.Count) tagged synthetic records." -ForegroundColor Green
