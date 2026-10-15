<#
=============================================================================
COMPONENT:    Accelerator Requirements Matching Acceptance Tests
FILE:         scripts/ci/test-accelerator-requirements-matching.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Credential-free fixtures
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "accelerator-matching-$([guid]::NewGuid().ToString('N'))"
$evaluationTime = [datetime]'2026-10-15T20:00:00Z'

. (Join-Path $repoRoot 'scripts/accelerators/requirements-matching.ps1')

function New-TestModule {
    param(
        [Parameter(Mandatory)] [string]$Slug,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Description,
        [string]$Version = 'v1.2.1.0',
        [bool]$SourceAvailable = $true,
        [string]$SourceUrl = ''
    )

    if ([string]::IsNullOrWhiteSpace($SourceUrl)) {
        $SourceUrl = "https://raw.githubusercontent.com/microsoft/industry-solutions/main/_modules/$Slug.md"
    }
    return [pscustomobject][ordered]@{
        itemId = "microsoft-fast:module:$Slug"
        providerId = 'microsoft-fast'
        itemType = 'module'
        slug = $Slug
        name = $Name
        sourcePath = "_modules/$Slug.md"
        sourceUrl = $SourceUrl
        contentHash = Get-AcceleratorStringSha256 -Value $Description
        frontMatter = [pscustomobject]@{
            title = $Name
            description = $Description
            latest_release = $Version
            module_category = 'acceptance-fixture'
        }
        availability = [pscustomobject]@{
            documented = $true
            sourceAvailable = $SourceAvailable
            packageVerified = $false
            environmentVerified = $false
        }
    }
}

$catalogItems = @(
    New-TestModule `
        -Slug 'core' `
        -Name 'Core' `
        -Description 'Foundational module providing shared entities for organizational structure, people management, governance, legal compliance, risk management, and content documentation.'
    New-TestModule `
        -Slug 'investigations' `
        -Name 'Investigations' `
        -Description 'Manage formal investigations from intake through resolution with comprehensive case tracking, evidence chain-of-custody, interview documentation, and corrective action monitoring.'
    New-TestModule `
        -Slug 'training-and-certification' `
        -Name 'Training and Certification' `
        -Description 'Manage learning delivery, academic programs, credentialing, and qualification requirements across higher education, workforce development, and regulated industries.'
    New-TestModule `
        -Slug 'asset-management' `
        -Name 'Asset Management' `
        -Description 'Track, categorize, and manage organizational assets with a modern, reusable solution for accountability and lifecycle management.'
)
$catalog = New-AcceleratorCatalogSnapshot `
    -ProviderId 'microsoft-fast' `
    -Items $catalogItems `
    -Coverage @{ modules = 4; acceptanceFixture = $true } `
    -SourceState 'available'

$packageRoot = Join-Path $repoRoot 'specs/fast-solution-accelerator-discovery/evidence/pkg'
$packages = @(
    Get-Content -Raw (Join-Path $packageRoot 'core.json') | ConvertFrom-Json
    Get-Content -Raw (Join-Path $packageRoot 'investigations.json') | ConvertFrom-Json
    Get-Content -Raw (Join-Path $packageRoot 'training-certification.json') | ConvertFrom-Json
)
$environmentEvidence = [pscustomobject]@{
    schemaVersion = '1.1'
    providerId = 'microsoft-fast'
    scenarioSlug = 'fast-003a-gcc-validation'
    level = 'environment-preflight'
    status = 'action-required'
    readinessStatus = 'action-required'
    validatedAtUtc = '2026-10-15T19:00:00Z'
    expiresAtUtc = '2026-10-16T19:00:00Z'
    catalogSnapshotId = $catalog.snapshotId
    environment = [pscustomobject]@{
        environmentId = 'fixture-environment'
        environmentUrl = 'https://fixture.crm9.dynamics.com'
        tenantId = 'fixture-tenant'
        organizationVersion = '9.2.26091.167'
    }
    requiredModules = @($packages | ForEach-Object {
        [pscustomobject]@{
            packageId = $_.packageId
            moduleId = $_.moduleId
            solutionUniqueName = $_.solution.uniqueName
            version = $_.solution.version
            sha256 = $_.sha256
        }
    })
    evidence = [pscustomobject]@{
        coreAssessment = 'missing-prerequisites-potentially-available'
        metadataFingerprint = 'fixture-gcc-missing-core'
    }
}

$requirements = @(
    [pscustomobject]@{
        id = 'REQ-FRAUD-001'
        description = 'Manage formal fraud investigations from intake through resolution with evidence chain custody, interview documentation, and corrective action monitoring.'
        requiredCapabilities = @(
            'investigation intake',
            'evidence chain custody',
            'interview documentation',
            'corrective action monitoring'
        )
        entities = @('Investigation', 'Evidence', 'Interview', 'Corrective Action')
        acceptanceCriteria = @('An investigator can trace evidence custody from intake to resolution.')
    },
    [pscustomobject]@{
        id = 'REQ-TRAIN-001'
        description = 'Manage learning delivery, credentialing, qualification requirements, and mobile renewal alerts.'
        requiredCapabilities = @(
            'learning delivery',
            'credentialing',
            'qualification requirements',
            'mobile renewal alerts'
        )
        acceptanceCriteria = @('A coordinator can identify credentials approaching renewal.')
    },
    [pscustomobject]@{
        id = 'REQ-HYBRID-001'
        description = 'Use investigation intake and evidence tracking, then integrate an external fraud scoring API and predictive referral workflow.'
        requiredCapabilities = @(
            'investigation intake',
            'evidence tracking',
            'predictive referral workflow'
        )
        integrations = @('External fraud scoring API')
        acceptanceCriteria = @('A referral stores the external risk decision and audit reference.')
    },
    [pscustomobject]@{
        id = 'REQ-CUSTOM-001'
        description = 'Plan cafeteria menus and calculate daily ingredient quantities for school lunches.'
        entities = @('Menu', 'Ingredient', 'Lunch Day')
        acceptanceCriteria = @('Kitchen staff can calculate quantities by expected attendance.')
    },
    [pscustomobject]@{
        id = 'REQ-DOCS-001'
        description = 'Track organizational assets, accountability, and lifecycle management.'
        requiredCapabilities = @('asset accountability', 'asset lifecycle management')
        acceptanceCriteria = @('An asset owner can review lifecycle state.')
    },
    [pscustomobject]@{
        id = 'REQ-AMBIGUOUS-001'
        description = 'TBD: use either investigations or training, maybe with an unknown workflow.'
        acceptanceCriteria = @('To be determined.')
    }
)

try {
    $analysis = Invoke-AcceleratorRequirementsAnalysis `
        -Requirements $requirements `
        -CatalogSnapshot $catalog `
        -PackageMetadata $packages `
        -EnvironmentEvidence $environmentEvidence `
        -ScenarioSlug 'fast-004-acceptance' `
        -EvaluationTimeUtc $evaluationTime

    $fraud = @($analysis.coverageMatrix | Where-Object requirementId -eq 'REQ-FRAUD-001')[0]
    if ($fraud.dispositions -notcontains 'REUSE' -or
        $fraud.candidateModuleId -ne 'microsoft-fast:module:investigations' -or
        $fraud.evidenceLevel -ne 'package-verified' -or
        @($fraud.candidates[0].sourceReferences).Count -eq 0 -or
        @($fraud.candidates[0].componentEvidence).Count -eq 0) {
        throw 'Fraud investigations did not produce evidence-grounded REUSE.'
    }

    $training = @($analysis.coverageMatrix | Where-Object requirementId -eq 'REQ-TRAIN-001')[0]
    if ($training.dispositions -notcontains 'EXTEND' -or
        $training.candidateModuleId -ne 'microsoft-fast:module:training-and-certification' -or
        @($training.gaps | Where-Object { $_ -match 'mobile renewal alerts' }).Count -eq 0) {
        throw 'Training requirements did not produce a package-backed EXTEND delta.'
    }

    $hybrid = @($analysis.coverageMatrix | Where-Object requirementId -eq 'REQ-HYBRID-001')[0]
    if ($hybrid.dispositions -notcontains 'EXTEND' -or
        $hybrid.dispositions -notcontains 'INTEGRATE' -or
        $hybrid.integrations -notcontains 'External fraud scoring API') {
        throw 'Hybrid requirements did not preserve accelerator and integration deltas.'
    }

    $custom = @($analysis.coverageMatrix | Where-Object requirementId -eq 'REQ-CUSTOM-001')[0]
    if ($custom.dispositions -notcontains 'BUILD' -or
        -not [string]::IsNullOrWhiteSpace($custom.candidateModuleId)) {
        throw 'Unrelated custom requirements did not remain custom.'
    }

    $documentedOnly = @($analysis.coverageMatrix | Where-Object requirementId -eq 'REQ-DOCS-001')[0]
    if ($documentedOnly.dispositions -notcontains 'VERIFY' -or
        $documentedOnly.evidenceLevel -ne 'conceptual') {
        throw 'Documented capability without package evidence did not require verification.'
    }

    $ambiguous = @($analysis.coverageMatrix | Where-Object requirementId -eq 'REQ-AMBIGUOUS-001')[0]
    if ($ambiguous.dispositions -notcontains 'VERIFY' -or $ambiguous.unresolvedQuestions.Count -eq 0) {
        throw 'Ambiguous requirements did not produce explicit uncertainty.'
    }

    if ($analysis.environmentReadiness.status -ne 'action-required' -or
        $analysis.environmentReadiness.executionGateOpen -or
        $analysis.environmentReadiness.coreAssessment -ne 'missing-prerequisites-potentially-available') {
        throw 'Missing GCC Core evidence did not block execution while preserving analysis.'
    }
    if (@($analysis.coverageMatrix | Where-Object candidateModuleId).Count -eq 0) {
        throw 'Missing Core incorrectly prevented architectural matching.'
    }

    if (@($analysis.dependencyManifest.moduleDependencies | Where-Object {
        $_.targetModuleId -eq 'microsoft-fast:module:core'
    }).Count -ne 2) {
        throw 'Specialty-to-Core module dependencies were not grouped by module identity.'
    }
    if ($analysis.dependencyManifest.duplicateEdgesRemoved -le 0 -or
        @($analysis.dependencyManifest.componentDependencies | Group-Object identity | Where-Object Count -gt 1).Count -ne 0) {
        throw 'Repeated dependency display names inflated component dependency evidence.'
    }
    if (@($analysis.dependencyManifest.moduleDependencies | Where-Object versionStatus -eq 'unverified').Count -eq 0) {
        throw 'Unproven dependency version compatibility was not left unverified.'
    }
    $cyclePackages = @(
        [pscustomobject]@{
            moduleId = 'fixture:module:a'; packageId = 'fixture:package:a'
            solution = [pscustomobject]@{ uniqueName = 'fixture_a'; version = '1.0.0.0' }
            declaredDependencies = @([pscustomobject]@{
                required = [pscustomobject]@{ type = 'solution'; solution = 'fixture_b(1.0.0.0)' }
            })
        },
        [pscustomobject]@{
            moduleId = 'fixture:module:b'; packageId = 'fixture:package:b'
            solution = [pscustomobject]@{ uniqueName = 'fixture_b'; version = '1.0.0.0' }
            declaredDependencies = @([pscustomobject]@{
                required = [pscustomobject]@{ type = 'solution'; solution = 'fixture_a(1.0.0.0)' }
            })
        }
    )
    $cycleManifest = New-AcceleratorDependencyManifest `
        -SelectedModuleIds @('fixture:module:a') `
        -PackageMetadata $cyclePackages
    if ($cycleManifest.cycles.Count -ne 1 -or
        $cycleManifest.cycles[0].candidateNodes.Count -ne 2) {
        throw 'A cyclic transitive module dependency graph was not detected.'
    }

    $fraudOnly = Invoke-AcceleratorRequirementsAnalysis `
        -Requirements @($requirements[0]) `
        -CatalogSnapshot $catalog `
        -PackageMetadata $packages `
        -EnvironmentEvidence $environmentEvidence `
        -ScenarioSlug 'fraud-only' `
        -EvaluationTimeUtc $evaluationTime
    if ($fraudOnly.recommendedOption -ne 'fast-based' -or
        @($fraudOnly.architectureOptions | Where-Object optionId -eq 'fast-based')[0].executionGateOpen) {
        throw 'FAST-based suitability was not separated from blocked execution readiness.'
    }
    $cycleBlockedOptions = New-AcceleratorArchitectureOptions `
        -CoverageMatrix $fraudOnly.coverageMatrix `
        -EnvironmentReference ([pscustomobject]@{ executionGateOpen = $true }) `
        -DependencyManifest $cycleManifest
    if (@($cycleBlockedOptions.options | Where-Object optionId -eq 'fast-based')[0].executionGateOpen) {
        throw 'A dependency cycle did not close the FAST-dependent execution gate.'
    }
    $customOnly = Invoke-AcceleratorRequirementsAnalysis `
        -Requirements @($requirements[3]) `
        -CatalogSnapshot $catalog `
        -PackageMetadata $packages `
        -EnvironmentEvidence $environmentEvidence `
        -ScenarioSlug 'custom-only' `
        -EvaluationTimeUtc $evaluationTime
    if ($customOnly.recommendedOption -ne 'fully-custom') {
        throw 'A zero-match application did not recommend fully custom architecture.'
    }
    if (@($analysis.architectureOptions | Where-Object optionId -eq 'fully-custom').Count -ne 1) {
        throw 'The fully custom option was not preserved.'
    }

    $naturalLanguage = ConvertTo-NormalizedAcceleratorRequirements `
        -Requirements "Investigators need evidence chain custody.`nTraining coordinators need credential renewal." `
        -ScenarioSlug 'natural-language'
    $structured = ConvertTo-NormalizedAcceleratorRequirements `
        -Requirements @([pscustomobject]@{ description = 'Investigators need evidence chain custody.' }) `
        -ScenarioSlug 'natural-language'
    if ($naturalLanguage.Count -ne 2 -or
        @($naturalLanguage.requirementId) -notcontains $structured[0].requirementId) {
        throw 'Natural-language and structured requirement normalization is not stable.'
    }

    $componentNameOnly = Invoke-AcceleratorRequirementsAnalysis `
        -Requirements 'Evidence Access Log' `
        -CatalogSnapshot $catalog `
        -PackageMetadata $packages `
        -ScenarioSlug 'component-name-only' `
        -EvaluationTimeUtc $evaluationTime
    if ($componentNameOnly.coverageMatrix[0].dispositions -notcontains 'BUILD') {
        throw 'A package table-name match was incorrectly treated as functional coverage.'
    }

    $unavailableItems = @($catalogItems | ForEach-Object {
        $_ | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    })
    @($unavailableItems | Where-Object itemId -eq 'microsoft-fast:module:investigations')[0].availability.sourceAvailable = $false
    $unavailableCatalog = New-AcceleratorCatalogSnapshot `
        -ProviderId 'microsoft-fast' `
        -Items $unavailableItems `
        -SourceState 'unavailable'
    $unavailable = Invoke-AcceleratorRequirementsAnalysis `
        -Requirements @($requirements[0]) `
        -CatalogSnapshot $unavailableCatalog `
        -PackageMetadata $packages `
        -ScenarioSlug 'unavailable-source' `
        -EvaluationTimeUtc $evaluationTime
    if ($unavailable.coverageMatrix[0].dispositions -notcontains 'VERIFY') {
        throw 'Unavailable catalog source did not fail closed to VERIFY.'
    }

    $futureItem = New-TestModule `
        -Slug 'future-inspection-scheduling' `
        -Name 'Future Inspection Scheduling' `
        -Description 'Schedule field inspections, assign inspectors, and document inspection findings.' `
        -Version 'v9.9.9-fixture' `
        -SourceUrl 'https://fixtures.invalid/fast/future-inspection-scheduling'
    $futureCatalog = New-AcceleratorCatalogSnapshot `
        -ProviderId 'microsoft-fast' `
        -Items (@($catalogItems) + @($futureItem)) `
        -SourceState 'available'
    $future = Invoke-AcceleratorRequirementsAnalysis `
        -Requirements 'Schedule field inspections, assign inspectors, and document inspection findings.' `
        -CatalogSnapshot $futureCatalog `
        -PackageMetadata $packages `
        -ScenarioSlug 'future-module' `
        -EvaluationTimeUtc $evaluationTime
    if ($future.coverageMatrix[0].candidateModuleId -ne 'microsoft-fast:module:future-inspection-scheduling') {
        throw 'A newly discovered module required hardcoded matcher registration.'
    }

    $repeat = Invoke-AcceleratorRequirementsAnalysis `
        -Requirements $requirements `
        -CatalogSnapshot $catalog `
        -PackageMetadata $packages `
        -EnvironmentEvidence $environmentEvidence `
        -ScenarioSlug 'fast-004-acceptance' `
        -EvaluationTimeUtc $evaluationTime
    if ($repeat.analysisId -cne $analysis.analysisId -or
        (ConvertTo-AcceleratorCanonicalJson $repeat.coverageMatrix) -cne
        (ConvertTo-AcceleratorCanonicalJson $analysis.coverageMatrix)) {
        throw 'Repeated matching did not produce stable, reproducible results.'
    }

    $disabled = Invoke-AcceleratorRequirementsAnalysis `
        -Requirements $requirements `
        -CatalogSnapshot $catalog `
        -PackageMetadata $packages `
        -ProviderEnabled $false `
        -ScenarioSlug 'disabled' `
        -EvaluationTimeUtc $evaluationTime
    if ($disabled.status -ne 'disabled' -or
        $disabled.coverageMatrix.Count -ne 0 -or
        $disabled.recommendedOption -ne 'fully-custom') {
        throw 'Disabled provider behavior did not preserve the custom-only baseline.'
    }

    $schemaPath = Join-Path $repoRoot 'schemas/accelerators/requirements-analysis.schema.json'
    if (-not (Test-Json -Json ($analysis | ConvertTo-Json -Depth 100) -SchemaFile $schemaPath -ErrorAction Stop) -or
        -not (Test-Json -Json ($disabled | ConvertTo-Json -Depth 100) -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw 'Requirements analysis output failed schema validation.'
    }

    $artifacts = Write-AcceleratorRequirementsAnalysisArtifacts `
        -Analysis $analysis `
        -OutputFolder $tempRoot
    $expectedArtifacts = @(
        'accelerator-evaluation.json',
        'requirements-coverage-matrix.json',
        'component-delta-analysis.json',
        'schema-reuse-extension-plan.json',
        'dependency-manifest.json',
        'environment-readiness-reference.json',
        'architecture-recommendation.json',
        'acceptance-traceability.json',
        'requirements-to-accelerator-matrix.md',
        'ADR-accelerator-selection.md',
        'accelerator-analysis-manifest.json'
    )
    foreach ($name in $expectedArtifacts) {
        if (-not (Test-Path -LiteralPath (Join-Path $tempRoot $name) -PathType Leaf)) {
            throw "Expected Spec Kit analysis artifact was not generated: $name"
        }
    }
    $manifest = Get-Content -Raw $artifacts.ManifestPath | ConvertFrom-Json
    if ($manifest.analysisId -cne $analysis.analysisId -or $manifest.artifacts.Count -ne 10) {
        throw 'Analysis artifact manifest is incomplete or references the wrong analysis.'
    }

    $matchingSource = Get-Content -Raw (Join-Path $repoRoot 'scripts/accelerators/requirements-matching.ps1')
    if ($matchingSource -match 'Invoke-WizardDataverseRequest|Invoke-RestMethod|\bpac\s') {
        throw 'Requirements matching introduced Dataverse, network, or PAC access.'
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Accelerator requirements matching tests passed.' -ForegroundColor Green
