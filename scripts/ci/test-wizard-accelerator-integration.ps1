<#
=============================================================================
COMPONENT:    Wizard Accelerator Integration Acceptance Tests
FILE:         scripts/ci/test-wizard-accelerator-integration.ps1
VERSION:      0.2.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Credential-free fixtures

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Validates the default-off post-discovery accelerator recommendation seam,
mode-specific planning artifacts, explicit architecture decisions, and safety.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Disabled mode preserves existing wizard artifacts and prompts.
✔ Enabled Demo, Advanced, and Framework modes emit approved decisions.
✔ Missing Core blocks FAST execution without blocking planning.
✔ Fully Custom remains selectable for matches and catalog outages.
✔ Stable reruns are reproducible and changed decisions require approval.
✔ Startup preferences remain separate and Fully Custom bypasses matching.
✔ Granular requirements, schema rendering, package manifests, and Markdown pass.
✔ No Dataverse transport or build stage is invoked.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$wizardPath = Join-Path $repoRoot 'scripts/bootstrap/05-start-wizard.ps1'
$catalogFunctionsPath = Join-Path $repoRoot 'scripts/accelerators/accelerator-catalog.ps1'
$integrationFunctionsPath = Join-Path $repoRoot 'scripts/accelerators/wizard-accelerator-integration.ps1'
$packageRoot = Join-Path $repoRoot 'specs/fast-solution-accelerator-discovery/evidence/pkg'
$packageManifestPath = Join-Path $packageRoot 'package-input-manifest.json'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "wizard-accelerator-$([guid]::NewGuid().ToString('N'))"
$evaluationTime = [datetime]'2026-10-15T20:00:00Z'

. $catalogFunctionsPath
. $integrationFunctionsPath

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-AcceleratorWizardWorkspace {
    param([Parameter(Mandatory)] [string]$Name)

    $workspace = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path (Join-Path $workspace 'docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workspace 'payloads') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'wizard.profile.json') -Destination $workspace
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/wizard-contract-v1.md') -Destination (Join-Path $workspace 'docs')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/onboarding.md') -Destination (Join-Path $workspace 'docs')
    return $workspace
}

function New-AcceleratorCatalogItem {
    param(
        [Parameter(Mandatory)] [string]$Slug,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Description,
        [bool]$SourceAvailable = $true
    )

    return [pscustomobject][ordered]@{
        itemId = "microsoft-fast:module:$Slug"
        providerId = 'microsoft-fast'
        itemType = 'module'
        slug = $Slug
        name = $Name
        sourceUrl = "https://microsoft.github.io/industry-solutions/modules/$Slug/"
        contentHash = Get-AcceleratorStringSha256 -Value $Description
        frontMatter = [pscustomobject]@{
            title = $Name
            description = $Description
            latest_release = 'v1.2.1.0'
        }
        availability = [pscustomobject]@{
            documented = $true
            sourceAvailable = $SourceAvailable
            packageVerified = $true
            environmentVerified = $false
        }
    }
}

function Invoke-AcceleratorWizardFixture {
    param(
        [Parameter(Mandatory)] [string]$Workspace,
        [Parameter(Mandatory)] [string[]]$Answers,
        [Parameter(Mandatory)] [string]$Mode,
        [switch]$Enable,
        [string]$ArchitectureChoice = '',
        [ValidateSet('evaluate', 'fully-custom', 'prefer-fast')]
        [string]$Preference = 'evaluate',
        [string]$CatalogPath = '',
        [string]$PackageManifestPath = '',
        [string]$EnvironmentPath = '',
        [switch]$ApproveDecisionChange,
        [datetime]$EvaluationTime = $evaluationTime
    )

    $answersPath = Join-Path $Workspace 'scripted-answers.json'
    $Answers | ConvertTo-Json | Set-Content -LiteralPath $answersPath -Encoding UTF8
    $arguments = @(
        '-NoProfile', '-NonInteractive', '-File', $wizardPath,
        '-Force', '-AnswersFile', $answersPath, '-WorkspaceRoot', $Workspace,
        '-Mode', $Mode
    )
    if ($Enable) {
        $arguments += @(
            '-EnableAcceleratorRecommendations',
            '-AcceleratorPreference', $Preference,
            '-AcceleratorArchitectureChoice', $ArchitectureChoice,
            '-AcceleratorEvaluationTimeUtc', $EvaluationTime.ToString('o')
        )
        if (-not [string]::IsNullOrWhiteSpace($CatalogPath)) {
            $arguments += @('-AcceleratorCatalogSnapshotPath', $CatalogPath)
        }
        if (-not [string]::IsNullOrWhiteSpace($PackageManifestPath)) {
            $arguments += @('-AcceleratorPackageManifestPath', $PackageManifestPath)
        }
        if (-not [string]::IsNullOrWhiteSpace($EnvironmentPath)) {
            $arguments += @('-AcceleratorEnvironmentValidationPath', $EnvironmentPath)
        }
        if ($ApproveDecisionChange) { $arguments += '-ApproveAcceleratorDecisionChange' }
    }
    $output = @(& pwsh @arguments 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = $output -join "`n"
    }
}

$demoAnswers = @(
    'Fraud investigation management',
    'Investigator | manage formal investigations and evidence custody',
    'Investigation, Evidence, Interview, Corrective Action',
    'Manage investigation intake through resolution with interview documentation and corrective action monitoring',
    'Evidence chain custody is traceable with synthetic sample data',
    'Development environment; unmanaged solution'
)
$advancedAnswers = @(
    'Training Management', 'training-management', 'standalone-model-driven', 'custom-only', 'trn_credential', 'Active Credentials',
    'all run-created tables, forms, views, processes, and reports', 'Operations', 'no',
    'feature/training-management', 'specs/training-management', 'checkpoints', 'applicable repo CI tests', 'no', 'squash',
    'Training and certification management app', 'Power Apps', 'Training coordinators',
    'Manage learning delivery, credentialing, qualification requirements, and mobile renewal alerts',
    'Training coordinators', 'Credential, Qualification, Learning Delivery', 'Credential forms, qualification views, renewal workflow',
    'A coordinator identifies credentials approaching renewal', 'Development environment', 'No', 'Unmanaged',
    'new', 'TrainingManagement', 'new', 'trn', 'none', 'Credential, Qualification, Learning Delivery',
    'none', 'Credential.trn_name', 'none', 'no', 'no',
    'Coordinator | review credentials | daily | trn_credential/Active Credentials | renewal risks are visible',
    'review credentials | App owner | expiring credentials are visible', 'no', 'no'
)
$frameworkAnswers = @(
    'Investigation Hybrid Acceptance', 'investigation-hybrid-acceptance', 'standalone-model-driven', 'custom-only',
    'iha_investigation', 'Active Investigations', 'all run-created tables, forms, views, processes, and reports',
    'Operations', 'yes', 'yes', 'feature/investigation-hybrid-acceptance', 'specs/investigation-hybrid-acceptance',
    'checkpoints', 'applicable repo CI tests', 'no', 'squash',
    'Fraud investigation app', 'Power Apps', 'Fraud analysts',
    'Manage investigation intake and evidence tracking, integrate an external fraud scoring API, and add predictive referral workflow',
    'Fraud analysts', 'Investigation, Evidence', 'Investigation forms, evidence views, external API integration',
    'A referral stores the external risk decision and audit reference', 'Authorized GCC development environment',
    'No', 'Unmanaged', 'new', 'InvestigationHybridAcceptance', 'new', 'iha',
    'none', 'Investigation, Evidence', 'none', 'Investigation.iha_name', 'none',
    'no', 'no',
    'Analyst | review referral | per run | Investigation/Active Investigations | risk decision is recorded',
    'review referral | Framework maintainer | audit reference is complete',
    'yes', 'InvestigationHybridAcceptance20261015', 'iha', 'Referral A | acceptance walkthrough',
    'A second run returns an unchanged accelerator decision and artifact inventory',
    'retain', 'no', 'Capture accelerator coverage, decision, readiness, provenance, and rerun evidence'
)

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $packages = @(
        Get-Content -LiteralPath (Join-Path $packageRoot 'core.json') -Raw | ConvertFrom-Json
        Get-Content -LiteralPath (Join-Path $packageRoot 'investigations.json') -Raw | ConvertFrom-Json
        Get-Content -LiteralPath (Join-Path $packageRoot 'training-certification.json') -Raw | ConvertFrom-Json
    )
    $packagePaths = @(
        Join-Path $packageRoot 'core.json'
        Join-Path $packageRoot 'investigations.json'
        Join-Path $packageRoot 'training-certification.json'
    )
    $manifestPackages = @(Get-WizardAcceleratorPackageMetadata `
        -WorkspaceRoot $repoRoot `
        -PackageManifestPath $packageManifestPath)
    Assert-True ($manifestPackages.Count -eq 3) 'Package manifest did not load all three verified package indexes.'
    $catalogItems = @(
        New-AcceleratorCatalogItem -Slug 'core' -Name 'Core' -Description 'Foundational shared entities for organization, people, governance, compliance, risk, and content.'
        New-AcceleratorCatalogItem -Slug 'investigations' -Name 'Investigations' -Description 'Manage formal investigations from intake through resolution with case tracking, evidence chain-of-custody, interview documentation, and corrective action monitoring.'
        New-AcceleratorCatalogItem -Slug 'training-and-certification' -Name 'Training and Certification' -Description 'Manage learning delivery, credentialing, and qualification requirements across workforce development and regulated industries.'
    )
    $catalog = New-AcceleratorCatalogSnapshot -ProviderId 'microsoft-fast' -Items $catalogItems -SourceState 'available'
    $catalogPath = Join-Path $testRoot 'catalog.json'
    $catalog | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $catalogPath -Encoding UTF8
    $environment = [pscustomobject]@{
        schemaVersion = '1.1'
        providerId = 'microsoft-fast'
        scenarioSlug = 'fast-003a-gcc-validation'
        level = 'environment-preflight'
        status = 'action-required'
        readinessStatus = 'action-required'
        validatedAtUtc = '2026-10-15T19:00:00Z'
        expiresAtUtc = '2026-10-15T19:30:00Z'
        catalogSnapshotId = $catalog.snapshotId
        environment = [pscustomobject]@{
            environmentId = 'fixture-gcc'
            environmentUrl = 'https://fixture.crm9.dynamics.com'
            organizationVersion = '9.2.26091.167'
        }
        requiredModules = @($packages | ForEach-Object {
            [pscustomobject]@{ packageId = $_.packageId; moduleId = $_.moduleId }
        })
        evidence = [pscustomobject]@{
            coreAssessment = 'missing-prerequisites-potentially-available'
            metadataFingerprint = 'fixture-gcc-core-missing'
        }
    }
    $environmentPath = Join-Path $testRoot 'environment.json'
    $environment | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $environmentPath -Encoding UTF8

    $disabledWorkspace = New-AcceleratorWizardWorkspace -Name 'disabled'
    $disabled = Invoke-AcceleratorWizardFixture `
        -Workspace $disabledWorkspace `
        -Answers ($demoAnswers + @('yes')) `
        -Mode 'demo-builder'
    Assert-True ($disabled.ExitCode -eq 0) "Disabled wizard failed: $($disabled.Output)"
    $disabledScenario = Join-Path $disabledWorkspace 'specs/fraud-investigation-management'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $disabledScenario 'accelerator'))) 'Disabled mode emitted accelerator artifacts.'
    $disabledSpec = Get-Content -LiteralPath (Join-Path $disabledScenario 'spec.md') -Raw
    Assert-True (-not $disabledSpec.Contains('Accelerator Evaluation')) 'Disabled mode changed baseline planning content.'

    $demoWorkspace = New-AcceleratorWizardWorkspace -Name 'demo-enabled'
    $demo = Invoke-AcceleratorWizardFixture `
        -Workspace $demoWorkspace `
        -Answers $demoAnswers `
        -Mode 'demo-builder' `
        -Enable `
        -ArchitectureChoice 'fast-based' `
        -CatalogPath $catalogPath `
        -PackageManifestPath $packageManifestPath `
        -EnvironmentPath $environmentPath
    Assert-True ($demo.ExitCode -eq 0) "Enabled Demo Builder failed: $($demo.Output)"
    Assert-True ($demo.Output -match 'Accelerator architecture recommendation:') 'Demo Builder did not show a concise accelerator recommendation.'
    $demoDecisionPath = Join-Path $demoWorkspace 'specs/fraud-investigation-management/accelerator/accelerator-decision.json'
    $demoDecision = Get-Content -LiteralPath $demoDecisionPath -Raw | ConvertFrom-Json
    Assert-True ($demoDecision.selectedOption -eq 'fast-based') 'Demo Builder did not persist explicit FAST-based selection.'
    Assert-True (-not $demoDecision.fastDependentExecutionAllowed) 'Missing GCC Core did not keep FAST execution blocked.'
    $demoPreference = Get-Content -LiteralPath (Join-Path $demoWorkspace 'specs/fraud-investigation-management/accelerator/accelerator-preference.json') -Raw | ConvertFrom-Json
    Assert-True ($demoPreference.preference -eq 'evaluate' -and -not $demoPreference.finalArchitectureSelected) 'Demo preference was not persisted separately from architecture approval.'

    $advancedWorkspace = New-AcceleratorWizardWorkspace -Name 'advanced-enabled'
    $advanced = Invoke-AcceleratorWizardFixture `
        -Workspace $advancedWorkspace `
        -Answers $advancedAnswers `
        -Mode 'advanced-builder' `
        -Enable `
        -ArchitectureChoice 'hybrid' `
        -CatalogPath $catalogPath `
        -PackageManifestPath $packageManifestPath `
        -EnvironmentPath $environmentPath
    Assert-True ($advanced.ExitCode -eq 0) "Enabled Advanced Builder failed: $($advanced.Output)"
    Assert-True ($advanced.Output -match 'Requirement coverage:') 'Advanced Builder did not show requirement-level coverage.'
    $advancedMatrixPath = Join-Path $advancedWorkspace 'specs/training-management/accelerator/requirements-coverage-matrix.json'
    $advancedMatrix = @(Get-Content -LiteralPath $advancedMatrixPath -Raw | ConvertFrom-Json)
    Assert-True (@($advancedMatrix | Where-Object candidateModuleId -eq 'microsoft-fast:module:training-and-certification').Count -gt 0) 'Training capability was not evaluated in Advanced Builder.'
    Assert-True (@($advancedMatrix.candidates | Where-Object moduleId -eq 'microsoft-fast:module:training-and-certification' | Where-Object packageId).Count -gt 0) 'Training package metadata was not loaded through the package manifest.'

    $frameworkWorkspace = New-AcceleratorWizardWorkspace -Name 'framework-enabled'
    $framework = Invoke-AcceleratorWizardFixture `
        -Workspace $frameworkWorkspace `
        -Answers $frameworkAnswers `
        -Mode 'framework-acceptance' `
        -Enable `
        -ArchitectureChoice 'hybrid' `
        -CatalogPath $catalogPath `
        -PackageManifestPath $packageManifestPath `
        -EnvironmentPath $environmentPath `
        -EvaluationTime $evaluationTime.AddHours(1)
    Assert-True ($framework.ExitCode -eq 0) "Enabled Framework Acceptance failed: $($framework.Output)"
    $frameworkDecisionPath = Join-Path $frameworkWorkspace 'specs/investigation-hybrid-acceptance/accelerator/accelerator-decision.json'
    $firstDecisionContent = Get-Content -LiteralPath $frameworkDecisionPath -Raw
    $frameworkDecision = $firstDecisionContent | ConvertFrom-Json
    Assert-True ($frameworkDecision.selectedOption -eq 'hybrid') 'Framework Acceptance did not persist Hybrid selection.'
    Assert-True (-not $frameworkDecision.fastDependentExecutionAllowed) 'Stale missing-Core evidence opened the FAST build gate.'

    $repeat = Invoke-AcceleratorWizardFixture `
        -Workspace $frameworkWorkspace `
        -Answers $frameworkAnswers `
        -Mode 'framework-acceptance' `
        -Enable `
        -ArchitectureChoice 'hybrid' `
        -CatalogPath $catalogPath `
        -PackageManifestPath $packageManifestPath `
        -EnvironmentPath $environmentPath
    Assert-True ($repeat.ExitCode -eq 0) "Stable rerun failed: $($repeat.Output)"
    Assert-True ((Get-Content -LiteralPath $frameworkDecisionPath -Raw) -ceq $firstDecisionContent) 'Stable rerun changed the approved decision artifact.'

    $changed = Invoke-AcceleratorWizardFixture `
        -Workspace $frameworkWorkspace `
        -Answers $frameworkAnswers `
        -Mode 'framework-acceptance' `
        -Enable `
        -ArchitectureChoice 'fully-custom' `
        -CatalogPath $catalogPath `
        -PackageManifestPath $packageManifestPath `
        -EnvironmentPath $environmentPath
    Assert-True ($changed.ExitCode -ne 0) 'An architecture change succeeded without explicit change approval.'
    Assert-True ($changed.Output -match 'approved accelerator architecture decision changed') 'Changed decision did not fail with an explicit approval message.'
    Assert-True ((Get-Content -LiteralPath $frameworkDecisionPath -Raw) -ceq $firstDecisionContent) 'Rejected decision change modified the approved artifact.'

    $customWorkspace = New-AcceleratorWizardWorkspace -Name 'custom-override'
    $custom = Invoke-AcceleratorWizardFixture `
        -Workspace $customWorkspace `
        -Answers $demoAnswers `
        -Mode 'demo-builder' `
        -Enable `
        -ArchitectureChoice 'fully-custom' `
        -CatalogPath $catalogPath `
        -PackageManifestPath $packageManifestPath `
        -EnvironmentPath $environmentPath
    Assert-True ($custom.ExitCode -eq 0) "Fully Custom override failed: $($custom.Output)"
    $customDecision = Get-Content -LiteralPath (Join-Path $customWorkspace 'specs/fraud-investigation-management/accelerator/accelerator-decision.json') -Raw | ConvertFrom-Json
    Assert-True ($customDecision.fullyCustomExecutionAllowed -and -not $customDecision.fastDependentExecutionAllowed) 'Fully Custom did not remain independent from FAST readiness.'

    $bypassWorkspace = New-AcceleratorWizardWorkspace -Name 'custom-preference-bypass'
    $bypass = Invoke-AcceleratorWizardFixture `
        -Workspace $bypassWorkspace `
        -Answers ($demoAnswers + @('yes')) `
        -Mode 'demo-builder' `
        -Enable `
        -Preference 'fully-custom'
    Assert-True ($bypass.ExitCode -eq 0) "Fully Custom startup preference failed: $($bypass.Output)"
    $bypassFolder = Join-Path $bypassWorkspace 'specs/fraud-investigation-management/accelerator'
    Assert-True (Test-Path -LiteralPath (Join-Path $bypassFolder 'accelerator-preference.json')) 'Fully Custom preference was not persisted.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $bypassFolder 'accelerator-evaluation.json'))) 'Fully Custom preference did not bypass matching.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $bypassFolder 'accelerator-decision.json'))) 'Preliminary Fully Custom preference created a final architecture decision.'

    $preferFastWorkspace = New-AcceleratorWizardWorkspace -Name 'prefer-fast'
    $preferFast = Invoke-AcceleratorWizardFixture `
        -Workspace $preferFastWorkspace `
        -Answers $demoAnswers `
        -Mode 'demo-builder' `
        -Enable `
        -Preference 'prefer-fast' `
        -ArchitectureChoice 'hybrid' `
        -CatalogPath $catalogPath `
        -PackageManifestPath $packageManifestPath `
        -EnvironmentPath $environmentPath
    Assert-True ($preferFast.ExitCode -eq 0) "Prefer FAST preference failed: $($preferFast.Output)"
    $preferFastRecommendation = Get-Content -LiteralPath (Join-Path $preferFastWorkspace 'specs/fraud-investigation-management/accelerator/architecture-recommendation.json') -Raw | ConvertFrom-Json
    Assert-True (@($preferFastRecommendation.options.optionId) -contains 'hybrid') 'Prefer FAST removed Hybrid.'
    Assert-True (@($preferFastRecommendation.options.optionId) -contains 'fully-custom') 'Prefer FAST removed Fully Custom.'

    $offlineWorkspace = New-AcceleratorWizardWorkspace -Name 'catalog-unavailable'
    $offline = Invoke-AcceleratorWizardFixture `
        -Workspace $offlineWorkspace `
        -Answers $demoAnswers `
        -Mode 'demo-builder' `
        -Enable `
        -ArchitectureChoice 'fully-custom'
    Assert-True ($offline.ExitCode -eq 0) "Catalog-unavailable fallback failed: $($offline.Output)"
    $offlineDecision = Get-Content -LiteralPath (Join-Path $offlineWorkspace 'specs/fraud-investigation-management/accelerator/accelerator-decision.json') -Raw | ConvertFrom-Json
    Assert-True ($offlineDecision.evaluationStatus -eq 'catalog-unavailable') 'Catalog outage was not recorded explicitly.'
    Assert-True ($offlineDecision.selectedOption -eq 'fully-custom') 'Catalog outage did not preserve Fully Custom.'

    $granularAnswers = [ordered]@{
        BusinessProblem = 'Manage investigation intake, investigator assignment, evidence custody, interviews, external fraud scoring, supervisor approval, and investigation reporting'
        ArtifactsNeeded = 'Intake form, assignment view, custody timeline, interview form, scoring integration, approval workflow, reporting dashboard'
        DataEntities = 'Investigation, Investigator Assignment, Evidence, Evidence Custody Event, Interview, Fraud Score, Supervisor Approval, Report'
        SuccessLooksLike = 'Intake is recorded, assignment is visible, custody is traceable, interviews are documented, scoring is auditable, approval is recorded, reporting is accurate'
        UserTaskDefinitions = ''
        Users = 'Investigators and supervisors'
        ScenarioName = 'Fraud investigation'
    }
    $granularRequirements = @(ConvertTo-WizardAcceleratorRequirements -Answers $granularAnswers -ScenarioSlug 'fraud-investigation')
    Assert-True ($granularRequirements.Count -eq 7) 'Fraud workflow was not split into seven independently traceable requirements.'
    foreach ($expectedId in @(
        'REQ-INVESTIGATION-INTAKE-001',
        'REQ-INVESTIGATOR-ASSIGNMENT-001',
        'REQ-EVIDENCE-CUSTODY-001',
        'REQ-INTERVIEW-001',
        'REQ-EXTERNAL-FRAUD-SCORING-001',
        'REQ-SUPERVISOR-APPROVAL-001',
        'REQ-INVESTIGATION-REPORTING-001'
    )) {
        Assert-True (@($granularRequirements.id) -contains $expectedId) "Missing stable requirement ID '$expectedId'."
    }

    $advancedAnswersContent = Get-Content -LiteralPath (Join-Path $advancedWorkspace 'specs/training-management/answers.md') -Raw
    foreach ($expectedSchemaValue in @('Credential -> trn_credential', 'Qualification -> trn_qualification', 'Credential.trn_name')) {
        Assert-True ($advancedAnswersContent.Contains($expectedSchemaValue)) "Generated schema output lost '$expectedSchemaValue'."
    }
    foreach ($markdownPath in @(
        Join-Path $advancedWorkspace 'specs/training-management/spec.md'
        Join-Path $advancedWorkspace 'specs/training-management/plan.md'
    )) {
        $trailingWhitespace = [regex]::Matches((Get-Content -LiteralPath $markdownPath -Raw), '[ \t]+(?=\r?$)', 'Multiline')
        Assert-True ($trailingWhitespace.Count -eq 0) "Generated Markdown contains trailing whitespace: $markdownPath"
    }

    $source = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts/accelerators/wizard-accelerator-integration.ps1') -Raw
    foreach ($forbidden in @('Invoke-WizardDataverseRequest', 'Invoke-RestMethod', 'pac solution', '20-build-tables.ps1', '30-build-columns.ps1')) {
        Assert-True (-not $source.Contains($forbidden)) "Wizard accelerator integration contains forbidden runtime token '$forbidden'."
    }
    Assert-True (Test-WizardAcceleratorRecommendationsEnabled -ExplicitEnable) 'Explicit feature enablement was not recognized.'
    $originalFastEnabled = [Environment]::GetEnvironmentVariable('FAST_ENABLED')
    [Environment]::SetEnvironmentVariable('FAST_ENABLED', 'true')
    Assert-True (Test-WizardAcceleratorRecommendationsEnabled) 'FAST_ENABLED=true was not recognized.'
    [Environment]::SetEnvironmentVariable('FAST_ENABLED', $originalFastEnabled)

    Write-Host 'Wizard accelerator integration tests passed.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
