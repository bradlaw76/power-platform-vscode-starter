<#
=============================================================================
COMPONENT:    Wizard Accelerator Recommendation Integration
FILE:         scripts/accelerators/wizard-accelerator-integration.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Local Spec Kit planning

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Connects normalized wizard discovery answers to the provider-neutral
requirements matcher before architecture finalization.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Disabled unless the caller explicitly opts in or FAST_ENABLED is true.
- Reads only local catalog, package, and optional environment evidence.
- Does not authenticate, call Dataverse, run build stages, or mutate solutions.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'requirements-matching.ps1')

function Get-WizardAcceleratorValue {
    param(
        [AllowNull()] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Name,
        [AllowNull()] [object]$DefaultValue = $null
    )

    if ($null -eq $InputObject) { return $DefaultValue }
    if ($InputObject -is [Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $DefaultValue
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

function Test-WizardAcceleratorRecommendationsEnabled {
    param([switch]$ExplicitEnable)

    if ($ExplicitEnable) { return $true }
    return [Environment]::GetEnvironmentVariable('FAST_ENABLED') -match '^(?i:true|1|yes|on)$'
}

function Resolve-WizardAcceleratorInputPath {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Path,
        [Parameter(Mandatory)] [string]$WorkspaceRoot
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $resolved = if ([IO.Path]::IsPathRooted($Path)) {
        $Path
    } else {
        Join-Path $WorkspaceRoot $Path
    }
    return [IO.Path]::GetFullPath($resolved)
}

function ConvertTo-WizardAcceleratorRequirements {
    param(
        [Parameter(Mandatory)] [Collections.IDictionary]$Answers,
        [Parameter(Mandatory)] [string]$ScenarioSlug
    )

    $businessProblem = "$(Get-WizardAcceleratorValue -InputObject $Answers -Name 'BusinessProblem' -DefaultValue '')".Trim()
    $artifacts = "$(Get-WizardAcceleratorValue -InputObject $Answers -Name 'ArtifactsNeeded' -DefaultValue '')".Trim()
    $dataEntities = @(
        "$(Get-WizardAcceleratorValue -InputObject $Answers -Name 'DataEntities' -DefaultValue '')" -split '[,;\r\n]+' |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ine 'none' }
    )
    $success = "$(Get-WizardAcceleratorValue -InputObject $Answers -Name 'SuccessLooksLike' -DefaultValue '')".Trim()
    $userTasks = "$(Get-WizardAcceleratorValue -InputObject $Answers -Name 'UserTaskDefinitions' -DefaultValue '')".Trim()
    $integrations = @(
        "$businessProblem $artifacts $userTasks" -split '[.;\r\n]+' |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '(?i)\b(?:api|connector|integrat|external system)\w*' }
    )

    $requirements = [Collections.Generic.List[object]]::new()
    if (-not [string]::IsNullOrWhiteSpace($businessProblem)) {
        $requirements.Add([pscustomobject][ordered]@{
            id = 'REQ-BUSINESS-001'
            description = $businessProblem
            actors = @("$(Get-WizardAcceleratorValue -InputObject $Answers -Name 'Users' -DefaultValue '')")
            entities = $dataEntities
            acceptanceCriteria = @($success | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            integrations = $integrations
        }) | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($artifacts) -or
        -not [string]::IsNullOrWhiteSpace($userTasks)) {
        $requirements.Add([pscustomobject][ordered]@{
            id = 'REQ-EXPERIENCE-001'
            description = @($artifacts, $userTasks | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }) -join '. '
            actors = @("$(Get-WizardAcceleratorValue -InputObject $Answers -Name 'Users' -DefaultValue '')")
            entities = $dataEntities
            acceptanceCriteria = @($success | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            integrations = $integrations
        }) | Out-Null
    }
    if ($requirements.Count -eq 0) {
        $requirements.Add([pscustomobject][ordered]@{
            id = 'REQ-SCENARIO-001'
            description = "$(Get-WizardAcceleratorValue -InputObject $Answers -Name 'ScenarioName' -DefaultValue $ScenarioSlug)"
            entities = $dataEntities
            acceptanceCriteria = @($success | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }) | Out-Null
    }
    return @($requirements.ToArray())
}

function Invoke-WizardAcceleratorEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Requirements,
        [Parameter(Mandatory)] [string]$WorkspaceRoot,
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [string]$CatalogSnapshotPath = '',
        [string[]]$PackageMetadataPaths = @(),
        [string]$EnvironmentValidationPath = '',
        [datetime]$EvaluationTimeUtc = [DateTime]::UtcNow
    )

    $catalogPath = Resolve-WizardAcceleratorInputPath -Path $CatalogSnapshotPath -WorkspaceRoot $WorkspaceRoot
    if ([string]::IsNullOrWhiteSpace($catalogPath) -or
        -not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        return [pscustomobject][ordered]@{
            status = 'catalog-unavailable'
            message = 'No readable promoted accelerator catalog snapshot was supplied. The fully custom workflow remains available.'
            analysis = $null
            packageMetadata = @()
            options = @([pscustomobject][ordered]@{
                optionId = 'fully-custom'
                rank = 1
                architectureSuitable = $true
                executionGateOpen = $true
                status = 'available'
                rationale = 'The accelerator catalog is unavailable, so planning continues through the existing fully custom workflow.'
                dependencies = 'No accelerator dependency.'
                userMaySelect = $true
            })
            recommendedOption = 'fully-custom'
        }
    }

    $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $packages = @(
        foreach ($packagePath in $PackageMetadataPaths) {
            $resolvedPackagePath = Resolve-WizardAcceleratorInputPath -Path $packagePath -WorkspaceRoot $WorkspaceRoot
            if (-not (Test-Path -LiteralPath $resolvedPackagePath -PathType Leaf)) {
                throw "Accelerator package metadata file not found: $resolvedPackagePath"
            }
            Get-Content -LiteralPath $resolvedPackagePath -Raw -Encoding UTF8 | ConvertFrom-Json
        }
    )
    $environmentEvidence = if ([string]::IsNullOrWhiteSpace($EnvironmentValidationPath)) {
        $null
    } else {
        $resolvedEnvironmentPath = Resolve-WizardAcceleratorInputPath `
            -Path $EnvironmentValidationPath `
            -WorkspaceRoot $WorkspaceRoot
        if (-not (Test-Path -LiteralPath $resolvedEnvironmentPath -PathType Leaf)) {
            throw "Accelerator environment evidence file not found: $resolvedEnvironmentPath"
        }
        Get-Content -LiteralPath $resolvedEnvironmentPath -Raw -Encoding UTF8 | ConvertFrom-Json -DateKind String
    }

    $analysis = Invoke-AcceleratorRequirementsAnalysis `
        -Requirements $Requirements `
        -CatalogSnapshot $catalog `
        -PackageMetadata $packages `
        -EnvironmentEvidence $environmentEvidence `
        -ScenarioSlug $ScenarioSlug `
        -ProviderEnabled $true `
        -EvaluationTimeUtc $EvaluationTimeUtc
    return [pscustomobject][ordered]@{
        status = 'evaluated'
        message = 'Accelerator requirements analysis completed from local evidence.'
        analysis = $analysis
        packageMetadata = $packages
        options = @($analysis.architectureOptions)
        recommendedOption = "$($analysis.recommendedOption)"
    }
}

function Show-WizardAcceleratorEvaluation {
    param(
        [Parameter(Mandatory)] [object]$Evaluation,
        [ValidateSet('demo-builder', 'advanced-builder', 'framework-acceptance')]
        [string]$Mode
    )

    Write-Host ''
    Write-Host 'Accelerator architecture recommendation:' -ForegroundColor Cyan
    Write-Host "  $($Evaluation.message)"
    if ($Evaluation.status -ne 'evaluated') {
        Write-Host '  Fully Custom remains available; no accelerator evidence will be used.' -ForegroundColor Yellow
        return
    }

    $analysis = $Evaluation.analysis
    Write-Host "  Recommended option: $($analysis.recommendedOption)"
    Write-Host "  Environment readiness: $($analysis.environmentReadiness.status)"
    Write-Host "  FAST-dependent execution gate: $(@($analysis.architectureOptions | Where-Object optionId -eq $analysis.recommendedOption)[0].executionGateOpen)"
    if ($Mode -eq 'demo-builder') {
        foreach ($option in @($analysis.architectureOptions | Sort-Object rank)) {
            Write-Host "  $($option.rank). $($option.optionId): $($option.status)"
        }
        Write-Host '  Fully Custom always remains selectable.'
        return
    }

    Write-Host ''
    Write-Host '  Requirement coverage:' -ForegroundColor Cyan
    foreach ($decision in @($analysis.coverageMatrix)) {
        Write-Host "    $($decision.requirementId): $(@($decision.dispositions) -join ', ') -> $($decision.candidateModuleId)"
        Write-Host "      Evidence: $($decision.evidenceLevel); gaps: $(@($decision.gaps) -join '; ')"
    }
    Write-Host ''
    Write-Host "  Modules: $(@($analysis.dependencyManifest.selectedModules) -join ', ')"
    Write-Host "  Dependency risks: unresolved=$(@($analysis.dependencyManifest.unresolvedDependencies).Count); cycles=$(@($analysis.dependencyManifest.cycles).Count)"
    foreach ($option in @($analysis.architectureOptions | Sort-Object rank)) {
        Write-Host "  $($option.rank). $($option.optionId): $($option.rationale)"
        Write-Host "     Status=$($option.status); execution-gate-open=$($option.executionGateOpen)"
    }
}

function New-WizardAcceleratorDecision {
    param(
        [Parameter(Mandatory)] [object]$Evaluation,
        [Parameter(Mandatory)]
        [ValidateSet('fast-based', 'hybrid', 'fully-custom')]
        [string]$SelectedOption,
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [string]$Mode,
        [string]$Rationale = '',
        [datetime]$RecordedAtUtc = [DateTime]::UtcNow
    )

    $availableOptions = @($Evaluation.options | ForEach-Object { "$($_.optionId)" })
    if ($availableOptions -notcontains $SelectedOption) {
        throw "Architecture option '$SelectedOption' is unavailable. Choose one of: $($availableOptions -join ', ')."
    }
    $analysis = $Evaluation.analysis
    $analysisId = if ($null -eq $analysis) { '' } else { "$($analysis.analysisId)" }
    $snapshotId = if ($null -eq $analysis) { '' } else { "$($analysis.snapshotId)" }
    $selectedModuleIds = if ($null -eq $analysis -or $SelectedOption -eq 'fully-custom') {
        @()
    } else {
        @($analysis.dependencyManifest.transitiveModules | Sort-Object -Unique)
    }
    $selectedPackages = @(
        $Evaluation.packageMetadata |
            Where-Object { $selectedModuleIds -contains "$($_.moduleId)" } |
            ForEach-Object {
                [pscustomobject][ordered]@{
                    moduleId = "$($_.moduleId)"
                    packageId = "$($_.packageId)"
                    version = "$(Get-WizardAcceleratorValue -InputObject $_.solution -Name 'version' -DefaultValue '')"
                    sha256 = "$(Get-WizardAcceleratorValue -InputObject $_ -Name 'sha256' -DefaultValue '')"
                }
            } |
            Sort-Object moduleId, packageId
    )
    $selectedArchitecture = @($Evaluation.options | Where-Object optionId -eq $SelectedOption)[0]
    $decisionRationale = if ([string]::IsNullOrWhiteSpace($Rationale)) {
        "The user explicitly selected '$SelectedOption' after reviewing the evidence-grounded architecture options."
    } else {
        $Rationale.Trim()
    }
    $basis = [ordered]@{
        scenarioSlug = $ScenarioSlug
        mode = $Mode
        evaluationStatus = "$($Evaluation.status)"
        analysisId = $analysisId
        snapshotId = $snapshotId
        recommendedOption = "$($Evaluation.recommendedOption)"
        selectedOption = $SelectedOption
        selectedPackages = $selectedPackages
        rationale = $decisionRationale
    }
    return [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        decisionId = "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $basis))"
        scenarioSlug = $ScenarioSlug
        wizardMode = $Mode
        evaluationStatus = "$($Evaluation.status)"
        analysisId = $analysisId
        catalogSnapshotId = $snapshotId
        recommendedOption = "$($Evaluation.recommendedOption)"
        selectedOption = $SelectedOption
        explicitApproval = $true
        rationale = $decisionRationale
        selectedPackages = $selectedPackages
        environmentReadiness = if ($null -eq $analysis) {
            [pscustomobject]@{ status = 'not-evaluated'; executionGateOpen = $false; metadataFingerprint = '' }
        } else {
            $analysis.environmentReadiness
        }
        fastDependentExecutionAllowed = $SelectedOption -ne 'fully-custom' -and [bool]$selectedArchitecture.executionGateOpen
        fullyCustomExecutionAllowed = $SelectedOption -eq 'fully-custom'
        recordedAtUtc = $RecordedAtUtc.ToUniversalTime().ToString('o')
    }
}

function Write-WizardAcceleratorPlanningArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Evaluation,
        [Parameter(Mandatory)] [object]$Decision,
        [Parameter(Mandatory)] [string]$OutputFolder,
        [Parameter(Mandatory)] [string]$SchemaPath,
        [switch]$ApproveDecisionChange
    )

    $decisionPath = Join-Path $OutputFolder 'accelerator-decision.json'
    Assert-WizardAcceleratorDecisionChange `
        -Decision $Decision `
        -DecisionPath $decisionPath `
        -ApproveDecisionChange:$ApproveDecisionChange
    if (-not (Test-Json -Json ($Decision | ConvertTo-Json -Depth 100) -SchemaFile $SchemaPath -ErrorAction Stop)) {
        throw 'Accelerator architecture decision failed schema validation.'
    }

    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    $analysisArtifacts = $null
    $analysisPath = Join-Path $OutputFolder 'accelerator-evaluation.json'
    $sameAnalysis = $false
    if ($Evaluation.status -eq 'evaluated' -and
        (Test-Path -LiteralPath $analysisPath -PathType Leaf)) {
        $existingAnalysis = Get-Content -LiteralPath $analysisPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $sameAnalysis = "$($existingAnalysis.analysisId)" -ceq "$($Evaluation.analysis.analysisId)"
    }
    if ($Evaluation.status -eq 'evaluated') {
        if ($sameAnalysis) {
            $analysisArtifacts = [pscustomobject]@{
                OutputFolder = $OutputFolder
                ManifestPath = Join-Path $OutputFolder 'accelerator-analysis-manifest.json'
                Artifacts = @()
            }
        } else {
            $analysisArtifacts = Write-AcceleratorRequirementsAnalysisArtifacts `
                -Analysis $Evaluation.analysis `
                -OutputFolder $OutputFolder
        }
    }
    $decisionMarkdownPath = Join-Path $OutputFolder 'accelerator-decision.md'
    $sameDecision = $false
    if (Test-Path -LiteralPath $decisionPath -PathType Leaf) {
        $existingDecision = Get-Content -LiteralPath $decisionPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $sameDecision = "$($existingDecision.decisionId)" -ceq "$($Decision.decisionId)"
    }
    if (-not $sameDecision) {
        Set-Content -LiteralPath $decisionPath -Value ($Decision | ConvertTo-Json -Depth 100) -Encoding utf8NoBOM
        $decisionMarkdown = @(
            '# Accelerator Architecture Decision',
            '',
            "**Decision ID:** ``$($Decision.decisionId)``",
            "**Evaluation status:** $($Decision.evaluationStatus)",
            "**Recommended:** $($Decision.recommendedOption)",
            "**Selected:** $($Decision.selectedOption)",
            "**Explicit approval:** $($Decision.explicitApproval)",
            '',
            '## Rationale',
            '',
            $Decision.rationale,
            '',
            '## Build safety',
            '',
            "- FAST-dependent execution allowed: $($Decision.fastDependentExecutionAllowed)",
            "- Fully custom execution allowed: $($Decision.fullyCustomExecutionAllowed)",
            "- Environment readiness: $($Decision.environmentReadiness.status)",
            '',
            'This decision records planning approval only. It does not authorize',
            'solution import, Dataverse mutation, or FAST-dependent generation.'
        )
        Set-Content -LiteralPath $decisionMarkdownPath -Value $decisionMarkdown -Encoding utf8NoBOM
    }
    return [pscustomobject]@{
        DecisionPath = $decisionPath
        DecisionMarkdownPath = $decisionMarkdownPath
        AnalysisArtifacts = $analysisArtifacts
    }
}

function Assert-WizardAcceleratorDecisionChange {
    param(
        [Parameter(Mandatory)] [object]$Decision,
        [Parameter(Mandatory)] [string]$DecisionPath,
        [switch]$ApproveDecisionChange
    )

    if (-not (Test-Path -LiteralPath $DecisionPath -PathType Leaf)) { return }
    $existing = Get-Content -LiteralPath $DecisionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ("$($existing.decisionId)" -cne "$($Decision.decisionId)" -and -not $ApproveDecisionChange) {
        throw 'The approved accelerator architecture decision changed. Rerun with -ApproveAcceleratorDecisionChange only after explicit review.'
    }
}

function Get-WizardAcceleratorPlanningProjection {
    param(
        [Parameter(Mandatory)] [object]$Evaluation,
        [Parameter(Mandatory)] [object]$Decision
    )

    $analysis = $Evaluation.analysis
    $modules = if ($Decision.selectedPackages.Count -eq 0) {
        'none'
    } else {
        @($Decision.selectedPackages | ForEach-Object {
            "$($_.moduleId) $($_.version) [$($_.sha256)]"
        }) -join '; '
    }
    $coverage = if ($null -eq $analysis) {
        '- Catalog unavailable; accelerator coverage was not evaluated.'
    } else {
        @($analysis.coverageMatrix | ForEach-Object {
            "- $($_.requirementId): $(@($_.dispositions) -join ', ') | candidate=$($_.candidateModuleId) | evidence=$($_.evidenceLevel)"
        }) -join "`n"
    }
    $tasks = if ($null -eq $analysis) {
        '- [ ] Continue through the existing fully custom planning workflow.'
    } else {
        @($analysis.coverageMatrix | ForEach-Object {
            "- [ ] $($_.requirementId): implement $(@($_.dispositions) -join ', ') delta and verify acceptance criteria."
        }) -join "`n"
    }
    return [pscustomobject]@{
        Answers = @"
## Accelerator Architecture Decision
- Feature enabled: yes
- Evaluation status: $($Evaluation.status)
- Analysis ID: $($Decision.analysisId)
- Catalog snapshot: $($Decision.catalogSnapshotId)
- Recommended architecture: $($Decision.recommendedOption)
- User-selected architecture: $($Decision.selectedOption)
- Explicit approval: $($Decision.explicitApproval)
- Selected packages: $modules
- Environment readiness: $($Decision.environmentReadiness.status)
- FAST-dependent execution allowed: $($Decision.fastDependentExecutionAllowed)
- Decision artifact: accelerator/accelerator-decision.json
"@
        Spec = @"
## Accelerator Evaluation
- Recommended architecture: $($Decision.recommendedOption)
- Approved architecture: $($Decision.selectedOption)
- Catalog snapshot: $($Decision.catalogSnapshotId)
- Selected packages: $modules
- Environment readiness: $($Decision.environmentReadiness.status)
- FAST-dependent generation gate: $($Decision.fastDependentExecutionAllowed)

### Requirement coverage
$coverage
"@
        Plan = @"
## Accelerator Architecture Plan
- Reproduce from `accelerator/accelerator-evaluation.json` and `accelerator/accelerator-decision.json`.
- Preserve selected architecture `$($Decision.selectedOption)` unless an explicitly approved decision change is recorded.
- Revalidate environment readiness before any future FAST-dependent execution.
- Keep fully custom work independent from FAST package prerequisites.
- Do not import packages or mutate Dataverse during planning.
"@
        Tasks = @"
## Accelerator Decision Tasks
$tasks
- [ ] Confirm the approved architecture decision ID `$($Decision.decisionId)` before implementation.
$(if ($Decision.selectedOption -ne 'fully-custom') { '- [ ] Obtain fresh ready environment evidence before any FAST-dependent build.' } else { '- [x] No FAST environment evidence is required for the approved fully custom path.' })
"@
    }
}
