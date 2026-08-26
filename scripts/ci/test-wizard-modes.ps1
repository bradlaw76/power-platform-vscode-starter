<#
=============================================================================
COMPONENT:    Wizard Modes Contract Test
FILE:         scripts/ci/test-wizard-modes.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-26
ENVIRONMENT:  PowerShell 7 | Credential-Free CI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Validates concise default intake, explicit advanced/acceptance selection, and
the shared planning-artifact contract used by the build pipeline.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Demo Builder is the default and uses seven prompts.
✔ Default output excludes acceptance, retention, and cleanup prompts.
✔ Demo Builder consolidates inferred recommendations for confirmation.
✔ Advanced Builder exposes technical controls.
✔ Framework Acceptance requires explicit selection.
✔ All modes emit the same core planning artifact names.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$wizardPath = Join-Path $repoRoot 'scripts/bootstrap/05-start-wizard.ps1'
$profile = Get-Content -LiteralPath (Join-Path $repoRoot 'wizard.profile.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wizard-modes-test-" + [guid]::NewGuid().ToString('N'))
$coreArtifacts = @('answers.md', 'spec.md', 'plan.md', 'tasks.md', 'report-mappings.md')

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function New-WizardTestWorkspace {
    param([string]$Name)

    $workspace = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path (Join-Path $workspace 'docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workspace 'payloads') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'wizard.profile.json') -Destination $workspace
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/wizard-contract-v1.md') -Destination (Join-Path $workspace 'docs')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/onboarding.md') -Destination (Join-Path $workspace 'docs')
    return $workspace
}

function Invoke-WizardFixture {
    param(
        [string]$Workspace,
        [string[]]$Answers,
        [string]$Mode
    )

    $answersPath = Join-Path $Workspace 'scripted-answers.json'
    $Answers | ConvertTo-Json | Set-Content -LiteralPath $answersPath -Encoding UTF8
    $arguments = @('-NoProfile', '-File', $wizardPath, '-Force', '-AnswersFile', $answersPath, '-WorkspaceRoot', $Workspace)
    if (-not [string]::IsNullOrWhiteSpace($Mode)) {
        $arguments += @('-Mode', $Mode)
    }

    $output = @(& pwsh @arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Wizard fixture failed for mode '$Mode':`n$($output -join "`n")"
    }
    return ($output -join "`n")
}

function Assert-ArtifactContract {
    param(
        [string]$Workspace,
        [string]$ScenarioSlug,
        [string]$Mode
    )

    $scenarioFolder = Join-Path $Workspace "specs/$ScenarioSlug"
    foreach ($artifact in $coreArtifacts) {
        $artifactPath = Join-Path $scenarioFolder $artifact
        Assert-True -Condition (Test-Path -LiteralPath $artifactPath -PathType Leaf) -Message "Mode '$Mode' did not emit $artifact."
    }

    foreach ($artifact in @('answers.md', 'spec.md', 'plan.md')) {
        $content = Get-Content -LiteralPath (Join-Path $scenarioFolder $artifact) -Raw -Encoding UTF8
        Assert-True -Condition $content.Contains("Wizard mode: $Mode") -Message "$artifact did not record mode '$Mode'."
    }
}

try {
    Assert-True -Condition ($profile.discovery.defaultMode -eq 'demo-builder') -Message 'Demo Builder must be the default mode.'
    $modeNames = @($profile.discovery.modes.PSObject.Properties.Name)
    Assert-True -Condition ($modeNames.Count -eq 3) -Message 'Exactly three wizard modes are required.'
    Assert-True -Condition ($modeNames -contains 'demo-builder' -and $modeNames -contains 'advanced-builder' -and $modeNames -contains 'framework-acceptance') -Message 'The required wizard modes are missing.'

    $demoMode = $profile.discovery.modes.'demo-builder'
    Assert-True -Condition ($demoMode.questionBudget -ge 6 -and $demoMode.questionBudget -le 8) -Message 'Demo Builder must use at most 6-8 questions.'
    Assert-True -Condition ([bool]$demoMode.inferTechnicalDesign) -Message 'Demo Builder must infer technical design.'
    Assert-True -Condition ([bool]$demoMode.consolidatedRecommendationConfirmation) -Message 'Demo Builder must consolidate recommendations for confirmation.'
    foreach ($forbiddenPrompt in @('destructive-cleanup-approval', 'retention-policy', 'rerun-proof-engineering', 'disposable-environment-confirmation')) {
        Assert-True -Condition (@($demoMode.forbiddenPrompts) -contains $forbiddenPrompt) -Message "Demo Builder must forbid '$forbiddenPrompt'."
        Assert-True -Condition (@($profile.discovery.modes.'advanced-builder'.forbiddenPrompts) -contains $forbiddenPrompt) -Message "Advanced Builder must forbid '$forbiddenPrompt'."
    }

    $advancedControls = @($profile.discovery.modes.'advanced-builder'.controls)
    foreach ($control in @('table-strategy', 'form-strategy', 'entry-point-table', 'named-landing-view', 'relationship-cardinality-requiredness-and-cascade', 'report-mappings')) {
        Assert-True -Condition ($advancedControls -contains $control) -Message "Advanced Builder is missing '$control'."
    }

    Assert-True -Condition ([bool]$profile.discovery.modes.'framework-acceptance'.explicitSelectionRequired) -Message 'Framework Acceptance must require explicit selection.'
    Assert-True -Condition (-not [bool]$profile.discovery.modes.'framework-acceptance'.default) -Message 'Framework Acceptance cannot be a default mode.'
    foreach ($modeProperty in @($profile.discovery.modes.PSObject.Properties)) {
        Assert-True -Condition ($null -eq $modeProperty.Value.PSObject.Properties['execution']) -Message "Mode '$($modeProperty.Name)' must use the shared execution pipeline."
    }

    $advancedAcceptanceTest = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/ci/test-wizard-source-control-acceptance.ps1') -Raw -Encoding UTF8
    Assert-True -Condition ($advancedAcceptanceTest -match '-Mode advanced-builder') -Message 'Advanced Builder must retain a runtime artifact acceptance test.'
    foreach ($artifact in $coreArtifacts) {
        Assert-True -Condition ($advancedAcceptanceTest.Contains("'$artifact'")) -Message "Advanced Builder acceptance does not verify $artifact."
    }

    $demoWorkspace = New-WizardTestWorkspace -Name 'demo'
    $demoOutput = Invoke-WizardFixture -Workspace $demoWorkspace -Mode '' -Answers @(
        'Equipment checkout for faster, accountable lab lending',
        'Lab coordinator | review and issue checkout requests',
        'Lab Asset, Checkout Request',
        'Review active requests, approve them, issue equipment, and record returns',
        'The coordinator completes the lifecycle with synthetic sample data',
        'Development environment; unmanaged solution',
        'yes'
    )
    Assert-True -Condition ($demoOutput -match 'Mode: demo-builder') -Message 'The omitted mode did not select Demo Builder.'
    Assert-True -Condition ($demoOutput -match 'Recommended technical design') -Message 'Demo Builder did not present consolidated recommendations.'
    Assert-True -Condition ($demoOutput -notmatch '(?i)A-acceptance|disposable|cleanup|retention') -Message 'Default Demo Builder output exposed acceptance or cleanup prompts.'
    Assert-ArtifactContract -Workspace $demoWorkspace -ScenarioSlug 'equipment-checkout-for-faster-accountable-lab-lending' -Mode 'demo-builder'

    $acceptanceWorkspace = New-WizardTestWorkspace -Name 'acceptance'
    $acceptanceOutput = Invoke-WizardFixture -Workspace $acceptanceWorkspace -Mode 'framework-acceptance' -Answers @(
        'Framework Mode Acceptance',
        'framework-mode-acceptance',
        'standalone-model-driven',
        'custom-only',
        'fma_request',
        'Active Requests',
        'all run-created tables, forms, views, processes, and reports',
        'Operations',
        'feature/framework-mode-acceptance',
        'specs/framework-mode-acceptance',
        'checkpoints',
        'applicable repo CI tests',
        'no',
        'squash',
        'Model-driven acceptance app',
        'Power Apps',
        'Framework maintainers',
        'Validate the framework mode contract',
        'Acceptance operator',
        'Request',
        'Request form, Active Requests view, review app',
        'The planned artifacts and lifecycle checks are reviewable',
        'Authorized acceptance environment',
        'No',
        'Unmanaged',
        'new',
        'FrameworkModeAcceptance',
        'new',
        'fma',
        'none',
        'Request',
        'none',
        'Request.fma_name',
        'none',
        'no',
        'no',
        'Acceptance operator | review request | per run | Request/Active Requests | evidence is captured',
        'review request | Framework maintainer | acceptance evidence is complete',
        'yes',
        'FrameworkModeAcceptance20260826',
        'fma',
        'Request A | acceptance walkthrough',
        'A second run returns an unchanged component inventory',
        'retain',
        'no',
        'Capture lifecycle, relationship, app navigation, and rerun evidence'
    )
    Assert-True -Condition ($acceptanceOutput -match 'Framework Acceptance controls') -Message 'Explicit Framework Acceptance did not expose its controls.'
    Assert-ArtifactContract -Workspace $acceptanceWorkspace -ScenarioSlug 'framework-mode-acceptance' -Mode 'framework-acceptance'

    $acceptanceAnswers = Get-Content -LiteralPath (Join-Path $acceptanceWorkspace 'specs/framework-mode-acceptance/answers.md') -Raw -Encoding UTF8
    Assert-True -Condition ($acceptanceAnswers -match 'Environment authorized: yes') -Message 'Framework Acceptance did not persist environment authorization.'
    Assert-True -Condition ($acceptanceAnswers -match 'Destructive cleanup separately approved: no') -Message 'Framework Acceptance did not preserve separate cleanup approval.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host 'Wizard mode contract checks passed.' -ForegroundColor Green