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
✔ Demo Builder is the default, with two delivery questions and a consolidated confirmation.
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
$formsViewsPath = Join-Path $repoRoot 'scripts/bootstrap/60-build-forms-views.ps1'
$profile = Get-Content -LiteralPath (Join-Path $repoRoot 'wizard.profile.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wizard-modes-test-" + [guid]::NewGuid().ToString('N'))
$coreArtifacts = @('answers.md', 'spec.md', 'plan.md', 'tasks.md', 'report-mappings.md', 'views.json')

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
        [string]$Mode,
        [string]$DeliveryGoal = '',
        [string]$DeliveryTimeframe = '',
        [string]$AcceptedContractPath = ''
    )

    $answersPath = Join-Path $Workspace 'scripted-answers.json'
    $Answers | ConvertTo-Json | Set-Content -LiteralPath $answersPath -Encoding UTF8
    $arguments = @('-NoProfile', '-File', $wizardPath, '-Force', '-AnswersFile', $answersPath, '-WorkspaceRoot', $Workspace)
    if (-not [string]::IsNullOrWhiteSpace($Mode)) {
        $arguments += @('-Mode', $Mode)
    }
    if (-not [string]::IsNullOrWhiteSpace($DeliveryGoal)) {
        $arguments += @('-DeliveryGoal', $DeliveryGoal)
    }
    if (-not [string]::IsNullOrWhiteSpace($DeliveryTimeframe)) {
        $arguments += @('-DeliveryTimeframe', $DeliveryTimeframe)
    }
    if (-not [string]::IsNullOrWhiteSpace($AcceptedContractPath)) {
        $arguments += @('-AcceptedContractPath', $AcceptedContractPath)
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

function Assert-Step60ConsumesViewsContract {
    param(
        [string]$Workspace,
        [string]$ScenarioSlug,
        [string]$ExpectedDisposition
    )

    $scenarioContext = [pscustomobject]@{ ScenarioFolder = (Join-Path $Workspace "specs/$ScenarioSlug") }
    $contract = Get-ScenarioSurfaceContract -ScenarioContext $scenarioContext
    Assert-True -Condition ($contract.Views.Count -eq 1) -Message "Step 60 did not consume the generated views.json for '$ScenarioSlug'."
    Assert-True -Condition ($contract.Views[0].Disposition -eq $ExpectedDisposition) -Message "Step 60 read an unexpected disposition for '$ScenarioSlug'."
}

try {
    $originalSkipMain = [Environment]::GetEnvironmentVariable('WIZARD_FORMS_VIEWS_SKIP_MAIN')
    [Environment]::SetEnvironmentVariable('WIZARD_FORMS_VIEWS_SKIP_MAIN', 'true')
    . $formsViewsPath
    Assert-True -Condition ($profile.discovery.defaultMode -eq 'demo-builder') -Message 'Demo Builder must be the default mode.'
    $modeNames = @($profile.discovery.modes.PSObject.Properties.Name)
    Assert-True -Condition ($modeNames.Count -eq 3) -Message 'Exactly three wizard modes are required.'
    Assert-True -Condition ($modeNames -contains 'demo-builder' -and $modeNames -contains 'advanced-builder' -and $modeNames -contains 'framework-acceptance') -Message 'The required wizard modes are missing.'

    $demoMode = $profile.discovery.modes.'demo-builder'
    Assert-True -Condition ($demoMode.questionBudget -eq 8 -and @($demoMode.questions).Count -eq 8) -Message 'Demo Builder must declare exactly six business and two delivery questions.'
    foreach ($modeProperty in @($profile.discovery.modes.PSObject.Properties)) {
        foreach ($question in @('delivery-goal', 'delivery-timeframe')) {
            Assert-True -Condition (@($modeProperty.Value.questions) -contains $question) -Message "Mode '$($modeProperty.Name)' is missing '$question'."
        }
    }
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
        'Checkout Request, Lab Asset',
        'Review active requests, approve them, issue equipment, and record returns',
        'The coordinator completes the lifecycle with synthetic sample data',
        'Development environment; unmanaged solution',
        'yes'
    )
    Assert-True -Condition ($demoOutput -match 'Mode: demo-builder') -Message 'The omitted mode did not select Demo Builder.'
    Assert-True -Condition ($demoOutput -match 'Recommended technical design') -Message 'Demo Builder did not present consolidated recommendations.'
    Assert-True -Condition ($demoOutput -notmatch '(?i)A-acceptance|disposable|cleanup|retention') -Message 'Default Demo Builder output exposed acceptance or cleanup prompts.'
    $demoSlug = 'equipment-checkout-for-faster-accountable-lab-lending'
    Assert-ArtifactContract -Workspace $demoWorkspace -ScenarioSlug $demoSlug -Mode 'demo-builder'
    $pendingAnswers = Get-Content -LiteralPath (Join-Path $demoWorkspace "specs/$demoSlug/answers.md") -Raw -Encoding UTF8
    Assert-True -Condition ($pendingAnswers.Contains('- Goal: unconfirmed')) -Message 'Legacy scripted wizard input must not silently choose a demo/production goal.'
    Assert-True -Condition ($pendingAnswers.Contains('Automation: guided')) -Message 'Unattended automation must remain off by default.'
    $customSpec = Get-Content -LiteralPath (Join-Path $demoWorkspace "specs/$demoSlug/spec.md") -Raw
    Assert-True -Condition ($customSpec -match 'Checkout Request -> [a-z]+_checkoutrequest') -Message 'Custom mapping must not disappear through the automatic $input variable.'

    $standardWorkspace = New-WizardTestWorkspace -Name 'standard-reuse'
    $standardAnswers = @(
        'Account work coordination',
        'Coordinator | coordinate work',
        'Account, Work Item',
        'Open an Account and save a linked Work Item',
        'Verify two-parent separation with synthetic data',
        'Synthetic rehearsal; unmanaged solution',
        'yes'
    )
    $null = Invoke-WizardFixture -Workspace $standardWorkspace -Mode '' -Answers $standardAnswers -DeliveryGoal 'connected-demo'
    $standardSpec = Get-Content -LiteralPath (Join-Path $standardWorkspace 'specs/account-work-coordination/spec.md') -Raw
    Assert-True -Condition ($standardSpec.Contains('- Entry point: account') -and $standardSpec.Contains('- Account -> account')) -Message 'Default Account planning must reuse the standard identity.'
    Assert-True -Condition ($standardSpec.Contains('- Table strategy: hybrid') -and $standardSpec.Contains('- Landing-view action: explicit-decision-required')) -Message 'Standard views require an explicit disposition.'

    $approvedWorkspace = New-WizardTestWorkspace -Name 'accepted-reuse'
    $approvedContract = @{
        schema_version = '1.0'
        evidence = @(@{ id = 'EV-owner'; kind = 'owner_requirement'; accepted = $true })
        requirements = @(@{ id = 'R1'; status = 'accepted'; evidence_ids = @('EV-owner') })
        components = @(
            @{ id = 'C1'; kind = 'table'; name = 'account'; requirement_ids = @('R1') },
            @{ id = 'C2'; kind = 'table'; name = 'ppd_workitem'; requirement_ids = @('R1') }
        )
        relationships = @(@{ id = 'REL1'; cardinality = 'one_to_many'; parent = 'account'; child = 'ppd_workitem'; lookup = 'ppd_accountid'; intent = @{ status = 'accepted'; evidence_ids = @('EV-owner') } })
    }
    $approvedPath = Join-Path $approvedWorkspace 'accepted-contract.json'
    $approvedContract | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $approvedPath -Encoding UTF8
    $null = Invoke-WizardFixture -Workspace $approvedWorkspace -Mode '' -Answers $standardAnswers -AcceptedContractPath $approvedPath
    $approvedSpec = Get-Content -LiteralPath (Join-Path $approvedWorkspace 'specs/account-work-coordination/spec.md') -Raw
    Assert-True -Condition ($approvedSpec.Contains('ppd_workitem -> ppd_workitem') -and $approvedSpec.Contains('one_to_many') -and $approvedSpec.Contains('ppd_accountid')) -Message 'Accepted custom identity and relationship intent must survive intake.'
    Assert-True -Condition ($approvedSpec.Contains('## Accepted Planning Source')) -Message 'Accepted planning provenance must be retained.'
    foreach ($fault in @('unaccepted', 'cardinality', 'endpoint')) {
        $negativeWorkspace = New-WizardTestWorkspace -Name "accepted-$fault"
        $negativePath = Join-Path $negativeWorkspace 'accepted-contract.json'
        $negative = $approvedContract | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
        if ($fault -eq 'unaccepted') { $negative.requirements[0].status = 'proposed' }
        elseif ($fault -eq 'cardinality') { $negative.relationships[0].cardinality = 'guessed' }
        else { $negative.relationships[0].parent = 'missing_table' }
        $negative | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $negativePath -Encoding UTF8
        $negativeOutput = @(& pwsh -NoProfile -File $wizardPath -WorkspaceRoot $negativeWorkspace -AcceptedContractPath $negativePath 2>&1)
        Assert-True -Condition ($LASTEXITCODE -ne 0 -and -not (Test-Path (Join-Path $negativeWorkspace 'specs'))) -Message "Invalid accepted $fault intent must fail before planning writes: $($negativeOutput -join ' ')"
    }

    $productionWorkspace = New-WizardTestWorkspace -Name 'production-delivery'
    $scriptedDemoAnswers = @(Get-Content -LiteralPath (Join-Path $demoWorkspace 'scripted-answers.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
    $productionOutput = Invoke-WizardFixture -Workspace $productionWorkspace -Mode '' -Answers $scriptedDemoAnswers -DeliveryGoal 'production' -DeliveryTimeframe '2026-12-15'
    Assert-ArtifactContract -Workspace $productionWorkspace -ScenarioSlug $demoSlug -Mode 'demo-builder'
    $productionPlan = Get-Content -LiteralPath (Join-Path $productionWorkspace "specs/$demoSlug/plan.md") -Raw -Encoding UTF8
    Assert-True -Condition ($productionPlan.Contains('- Goal: production')) -Message 'Production goal was not preserved.'
    Assert-True -Condition ($productionPlan.Contains('- Deadline/timeframe: 2026-12-15')) -Message 'User delivery timeframe was not preserved.'
    Assert-True -Condition ($productionPlan.Contains('Full applicable CI, security')) -Message 'Production validation cannot silently downgrade to demo checks.'
    Assert-True -Condition ($productionPlan.Contains('Execution: guided')) -Message 'Production delivery must not activate automation implicitly.'
    Assert-True -Condition ($productionOutput -match 'Delivery profile: production') -Message 'Explicit delivery parameters were not applied.'

    $multilineWorkspace = New-WizardTestWorkspace -Name 'multiline-delivery'
    $multilineAnswersPath = Join-Path $multilineWorkspace 'scripted-answers.json'
    $scriptedDemoAnswers | ConvertTo-Json | Set-Content -LiteralPath $multilineAnswersPath -Encoding UTF8
    $multilineOutput = @(& pwsh -NoProfile -File $wizardPath -Force -AnswersFile $multilineAnswersPath -WorkspaceRoot $multilineWorkspace -DeliveryGoal production -DeliveryTimeframe "next week`n## Unaccepted planning heading" 2>&1)
    $multilineExitCode = $LASTEXITCODE
    Assert-True -Condition ($multilineExitCode -ne 0 -and ($multilineOutput -join "`n") -match 'DeliveryTimeframe must be a single-line') -Message 'Multiline delivery context must fail explicitly instead of injecting planning headings.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $multilineWorkspace 'specs'))) -Message 'Rejected delivery context must not generate scenario artifacts.'

    $demoViews = Get-Content -LiteralPath (Join-Path $demoWorkspace "specs/$demoSlug/views.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True -Condition ($demoViews.Views.Count -eq 1) -Message 'Demo Builder must emit one entry-point view intent.'
    Assert-True -Condition ($demoViews.Views[0].Name -eq 'Active Checkout Requests') -Message 'Demo Builder did not use the predictable generated Active Checkout Requests view name.'
    Assert-True -Condition ($demoViews.Views[0].Disposition -eq 'adopt-generated-active') -Message 'Demo Builder must plan adoption for an exact generated Active-view collision on a new custom table.'
    Assert-Step60ConsumesViewsContract -Workspace $demoWorkspace -ScenarioSlug $demoSlug -ExpectedDisposition 'adopt-generated-active'

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

    $acceptanceViewsPath = Join-Path $acceptanceWorkspace 'specs/framework-mode-acceptance/views.json'
    $acceptanceViews = Get-Content -LiteralPath $acceptanceViewsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True -Condition ($acceptanceViews.Views[0].Disposition -eq 'adopt-generated-active') -Message 'Advanced-style intake must plan adoption for Active Requests on a newly planned Request table.'

    $distinctWorkspace = New-WizardTestWorkspace -Name 'distinct-business-view'
    $distinctAnswers = @(
        'Distinct Business View', 'distinct-business-view', 'standalone-model-driven', 'custom-only', 'dbv_labasset', 'Available Lab Assets',
        'all run-created tables, forms, views, processes, and reports', 'Operations', 'feature/distinct-business-view', 'specs/distinct-business-view',
        'checkpoints', 'applicable repo CI tests', 'no', 'squash', 'Model-driven asset app', 'Power Apps', 'Lab coordinators',
        'Track lab assets', 'Lab coordinators', 'Lab Asset', 'Asset form and availability view', 'Available assets are visible', 'Development',
        'No', 'Unmanaged', 'new', 'DistinctBusinessView', 'new', 'dbv', 'none', 'Lab Asset', 'none', 'LabAsset.dbv_name', 'none',
        'no', 'no', 'Coordinator | find asset | daily | dbv_labasset/Available Lab Assets | available assets are visible',
        'find asset | App owner | an available asset is visible', 'no', 'no'
    )
    $distinctOutput = Invoke-WizardFixture -Workspace $distinctWorkspace -Mode 'advanced-builder' -Answers $distinctAnswers
    Assert-True -Condition ($distinctOutput -match 'Mode: advanced-builder') -Message 'Distinct-view fixture did not run Advanced Builder.'
    Assert-ArtifactContract -Workspace $distinctWorkspace -ScenarioSlug 'distinct-business-view' -Mode 'advanced-builder'
    $distinctViews = Get-Content -LiteralPath (Join-Path $distinctWorkspace 'specs/distinct-business-view/views.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True -Condition ($distinctViews.Views[0].Name -eq 'Available Lab Assets') -Message 'Advanced Builder did not preserve the business view name.'
    Assert-True -Condition ($distinctViews.Views[0].Disposition -eq 'create-custom') -Message 'A distinct business view must use create-custom.'
    Assert-Step60ConsumesViewsContract -Workspace $distinctWorkspace -ScenarioSlug 'distinct-business-view' -ExpectedDisposition 'create-custom'

    $relationshipConflictWorkspace = New-WizardTestWorkspace -Name 'detailed-relationship-conflict'
    $relationshipConflictContract = $approvedContract | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable
    $relationshipConflictContract.components = @(@{ id = 'C1'; kind = 'table'; name = 'dbv_labasset'; requirement_ids = @('R1') })
    $relationshipConflictContract.relationships[0].parent = 'dbv_labasset'
    $relationshipConflictContract.relationships[0].child = 'dbv_labasset'
    $relationshipConflictContract.relationships[0].lookup = 'dbv_parentassetid'
    $relationshipConflictPath = Join-Path $relationshipConflictWorkspace 'accepted-contract.json'
    $relationshipConflictContract | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $relationshipConflictPath -Encoding UTF8
    $relationshipConflictMessage = ''
    try {
        $null = Invoke-WizardFixture -Workspace $relationshipConflictWorkspace -Mode 'advanced-builder' -Answers $distinctAnswers -AcceptedContractPath $relationshipConflictPath
    }
    catch {
        $relationshipConflictMessage = $_.Exception.Message
    }
    Assert-True -Condition ($relationshipConflictMessage.Contains('conflicts with accepted relationship decisions') -and -not (Test-Path (Join-Path $relationshipConflictWorkspace 'specs'))) -Message 'Detailed relationship contradictions must fail before planning writes.'

    $acceptanceAnswers = Get-Content -LiteralPath (Join-Path $acceptanceWorkspace 'specs/framework-mode-acceptance/answers.md') -Raw -Encoding UTF8
    Assert-True -Condition ($acceptanceAnswers -match 'Environment authorized: yes') -Message 'Framework Acceptance did not persist environment authorization.'
    Assert-True -Condition ($acceptanceAnswers -match 'Destructive cleanup separately approved: no') -Message 'Framework Acceptance did not preserve separate cleanup approval.'
}
finally {
    [Environment]::SetEnvironmentVariable('WIZARD_FORMS_VIEWS_SKIP_MAIN', $originalSkipMain)
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host 'Wizard mode contract checks passed.' -ForegroundColor Green