<#
=============================================================================
COMPONENT:    FAST-007 Execution Readiness Acceptance
FILE:         scripts/ci/test-execution-readiness.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Synthetic local fixtures
-----------------------------------------------------------------------------
OVERVIEW
Exercises cross-domain readiness, material changes and nonexecuting boundaries.
NON-NEGOTIABLES
No live services, package installation, authorization issuance or build stages.
=============================================================================
#>
[CmdletBinding()]
param([string]$SampleOutputFolder = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts\accelerators\execution-readiness.ps1')
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "fast007-$([guid]::NewGuid().ToString('N'))"
$failures = [Collections.Generic.List[string]]::new()
$checks = 0
$clock = [DateTimeOffset]'2026-10-19T12:00:00Z'
$environmentId = [guid]'11111111-1111-4111-8111-111111111111'
$tenantId = [guid]'22222222-2222-4222-8222-222222222222'

function Assert-Readiness {
    param([bool]$Condition, [string]$Message)
    $script:checks++
    if (-not $Condition) { $failures.Add($Message) | Out-Null }
}

function Write-FixtureJson {
    param([string]$Path, [object]$Value)
    New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
    Set-Content -LiteralPath $Path -Value (ConvertTo-Json -InputObject $Value -Depth 100) -Encoding utf8NoBOM
}

function New-ReadinessFixture {
    param([string]$Slug, [switch]$Hybrid)
    $root = Join-Path $tempRoot $Slug
    $scenario = Join-Path $root "specs\$Slug"
    $accel = Join-Path $scenario 'accelerator'
    $decision = [pscustomobject][ordered]@{
        schemaVersion = '1.0'; decisionId = "sha256:$('0' * 64)"; scenarioSlug = $Slug
        wizardMode = 'demo-builder'; evaluationStatus = 'evaluated'; analysisId = "sha256:$('a' * 64)"
        catalogSnapshotId = "sha256:$('b' * 64)"; recommendedOption = 'fully-custom'
        selectedOption = 'fully-custom'; explicitApproval = $true
        rationale = 'Synthetic approved application architecture; not deployment authorization.'
        selectedPackages = @(); environmentReadiness = [pscustomobject]@{}
        fastDependentExecutionAllowed = $false; fullyCustomExecutionAllowed = $true
        recordedAtUtc = '2026-10-19T10:00:00Z'
    }
    $coverage = @([pscustomobject]@{
        requirementId = 'REQ-001'; description = "Manage $Slug records"; dispositions = @('BUILD')
        candidateModuleId = ''; candidates = @(); acceptanceCriteria = @('Users can complete the primary task.')
    })
    $trace = @([pscustomobject]@{
        requirementId = 'REQ-001'; acceptanceCriteria = @('Users can complete the primary task.'); evidenceReferences = @()
    })
    $initialBasis = [ordered]@{
        scenarioSlug = $Slug; mode = $decision.wizardMode; evaluationStatus = $decision.evaluationStatus
        analysisId = $decision.analysisId; snapshotId = $decision.catalogSnapshotId
        recommendedOption = $decision.recommendedOption; selectedOption = $decision.selectedOption
        selectedPackages = @($decision.selectedPackages); rationale = $decision.rationale
    }
    $decision.decisionId = "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $initialBasis))"
    $plan = New-ProviderNeutralBuildPlan -Decision $decision `
        -AnalysisManifest ([pscustomobject]@{ analysisId = $decision.analysisId; snapshotId = $decision.catalogSnapshotId; providerId = 'synthetic' }) `
        -CoverageMatrix $coverage -ComponentDelta @([pscustomobject]@{ requirementId = 'REQ-001' }) `
        -SchemaPlan ([pscustomobject]@{ reuse = @(); extend = @(); build = @(); integrate = @(); verify = @() }) `
        -DependencyManifest ([pscustomobject]@{}) -EnvironmentReadiness ([pscustomobject]@{}) `
        -AcceptanceTraceability $trace -ScenarioMappings ([pscustomobject]@{
            publisherPrefix = 'tst'; appName = "$Slug application"; bpfEnabled = $false
            tables = @([pscustomobject]@{ displayName = 'Primary Record'; logicalName = 'tst_record' })
            fields = @(); relationships = @()
        })
    $inputs = [ordered]@{
        decision = "specs\$Slug\accelerator\accelerator-decision.json"
        analysisManifest = "specs\$Slug\accelerator\accelerator-analysis-manifest.json"
        coverage = "specs\$Slug\accelerator\requirements-coverage-matrix.json"
        componentDelta = "specs\$Slug\accelerator\component-delta-analysis.json"
        schemaPlan = "specs\$Slug\accelerator\schema-reuse-extension-plan.json"
        dependencies = "specs\$Slug\accelerator\dependency-manifest.json"
        environment = "specs\$Slug\accelerator\environment-readiness-reference.json"
        traceability = "specs\$Slug\accelerator\acceptance-traceability.json"
        spec = "specs\$Slug\spec.md"
    }
    $packages = @()
    if ($Hybrid) {
        $decision.selectedOption = 'hybrid'; $decision.recommendedOption = 'hybrid'
        $decision.selectedPackages = @([pscustomobject]@{
            moduleId = 'synthetic-records'; packageId = 'synthetic-records-v1'; version = '1.0.0.0'; sha256 = 'c' * 64
        })
        $plan.architecture = 'hybrid'
        $plan.environment = [pscustomobject]@{
            requiredForArchitecture = $true; environmentUrl = 'https://synthetic.example.test'
            gateOpen = $true; status = 'ready'; limitations = @()
        }
        $plan.componentPlans[0].action = 'REUSE'; $plan.componentPlans[0].managed = $true
        $plan.componentPlans[0].ownership = 'accelerator-managed'
        $packageMetadata = [pscustomobject]@{
            evidenceType = 'package-verified'; providerId = 'synthetic'; moduleId = 'synthetic-records'
            packageId = 'synthetic-records-v1'; fileName = 'not-an-installed-package.zip'; sizeBytes = 1; sha256 = 'c' * 64
            solution = [pscustomobject]@{ uniqueName = 'synthetic_records'; displayName = 'Synthetic Records'; version = '1.0.0.0'; managed = $true }
            publisher = [pscustomobject]@{ uniqueName = 'synthetic'; displayName = 'Synthetic'; customizationPrefix = 'tst'; optionValuePrefix = 10000 }
            rootComponents = @(); tables = @(); relationships = @(); declaredDependencies = @(); forms = @(); views = @()
        }
        Write-FixtureJson -Path (Join-Path $accel 'package.json') -Value $packageMetadata
        Write-FixtureJson -Path (Join-Path $accel 'package-input-manifest.json') -Value ([pscustomobject]@{
            schemaVersion = '1.0'; providerId = 'synthetic'; packages = @([pscustomobject]@{
                path = 'package.json'; moduleId = 'synthetic-records'; packageId = 'synthetic-records-v1'
                version = '1.0.0.0'; sha256 = 'c' * 64
            })
        })
        $inputs.packageManifest = "specs\$Slug\accelerator\package-input-manifest.json"
        $packages = @([pscustomobject]@{
            moduleId = 'synthetic-records'; packageId = 'synthetic-records-v1'; sha256 = 'c' * 64
            solutionUniqueName = 'synthetic_records'; version = '1.0.0.0'; installed = $true; dependencies = @()
        })
    }
    $basis = [ordered]@{
        scenarioSlug = $Slug; mode = $decision.wizardMode; evaluationStatus = $decision.evaluationStatus
        analysisId = $decision.analysisId; snapshotId = $decision.catalogSnapshotId
        recommendedOption = $decision.recommendedOption; selectedOption = $decision.selectedOption
        selectedPackages = @($decision.selectedPackages); rationale = $decision.rationale
    }
    $decision.decisionId = "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $basis))"
    $plan.decisionId = $decision.decisionId
    foreach ($task in $plan.componentPlans) { $task.requirementIds = @('REQ-001') }
    foreach ($item in $plan.traceability) {
        $item.decisionId = $decision.decisionId
        $item.taskIds = @($plan.componentPlans.taskId | Sort-Object)
    }
    foreach ($entry in $inputs.GetEnumerator()) {
        $path = Join-Path $root $entry.Value
        if ($entry.Key -eq 'decision') { Write-FixtureJson $path $decision }
        elseif ($entry.Key -eq 'coverage') { Write-FixtureJson $path $coverage }
        elseif ($entry.Key -eq 'traceability') { Write-FixtureJson $path $trace }
        elseif ($entry.Key -eq 'spec') { Set-Content -LiteralPath $path -Value "# Synthetic $Slug" -Encoding utf8NoBOM }
        elseif ($entry.Key -ne 'packageManifest') { Write-FixtureJson $path ([pscustomobject]@{ fixture = $entry.Key }) }
    }
    $fingerprints = [ordered]@{}
    foreach ($entry in $inputs.GetEnumerator()) { $fingerprints[$entry.Key] = Get-BuildPlanningFileHash (Join-Path $root $entry.Value) }
    $plan.inputFingerprints = [pscustomobject]$fingerprints
    $plan.planId = Get-ExecutionPlanIdentity $plan
    $planPath = Join-Path $accel 'build-plan\build-plan-manifest.json'
    Write-FixtureJson $planPath $plan
    $evidence = [pscustomobject][ordered]@{
        schemaVersion = '1.0'; decisionId = $decision.decisionId; planId = $plan.planId
        planSha256 = Get-BuildPlanningFileHash $planPath
        environment = [pscustomobject]@{ environmentId = $environmentId.ToString(); tenantId = $tenantId.ToString(); url = 'https://synthetic.example.test' }
        observedAtUtc = '2026-10-19T11:00:00Z'; expiresAtUtc = '2026-10-19T13:00:00Z'
        inputArtifacts = @($inputs.GetEnumerator() | ForEach-Object { [pscustomobject]@{ key = $_.Key; path = $_.Value } })
        packages = $packages
        components = @($plan.componentPlans | ForEach-Object {
            [pscustomobject]@{
                taskId = $_.taskId; componentKind = $_.componentKind; componentIdentity = $_.componentIdentity
                exists = $_.action -eq 'REUSE'; ownership = $_.ownership; managed = $_.managed
                customizable = $true; allowedActions = @('CREATE', 'REUSE', 'EXTEND', 'INTEGRATE')
            }
        })
        security = [pscustomobject]@{
            principalId = '33333333-3333-4333-8333-333333333333'
            grantedPermissions = @('read-metadata', 'customize', 'write-solution', 'configure-integration')
        }
    }
    $evidencePath = Join-Path $accel 'execution-evidence.json'
    Write-FixtureJson $evidencePath $evidence
    return [pscustomobject]@{ root = $root; slug = $Slug; decision = $decision; plan = $plan; evidence = $evidence; evidencePath = $evidencePath; planPath = $planPath }
}

function Invoke-FixtureReadiness {
    param([object]$Fixture, [switch]$RebindPlan)
    if ($RebindPlan) {
        $Fixture.plan.planId = Get-ExecutionPlanIdentity $Fixture.plan
        Write-FixtureJson $Fixture.planPath $Fixture.plan
        $Fixture.evidence.planId = $Fixture.plan.planId
        $Fixture.evidence.planSha256 = Get-BuildPlanningFileHash $Fixture.planPath
    }
    Write-FixtureJson $Fixture.evidencePath $Fixture.evidence
    return Get-ExecutionReadiness -WorkspaceRoot $Fixture.root -ScenarioSlug $Fixture.slug -EvidencePath $Fixture.evidencePath `
        -EnvironmentUrl 'https://synthetic.example.test' -EnvironmentId $environmentId -TenantId $tenantId -EvaluationTimeUtc $clock
}

function Save-SyntheticReport {
    param([object]$Report, [string]$Name)
    if (-not [string]::IsNullOrWhiteSpace($SampleOutputFolder)) {
        Write-FixtureJson (Join-Path $SampleOutputFolder "$Name\execution-readiness.json") $Report
    }
}

try {
    foreach ($slug in @('equipment-maintenance', 'event-registration', 'employee-onboarding')) {
        $fixture = New-ReadinessFixture $slug
        $report = Invoke-FixtureReadiness $fixture
        Assert-Readiness ($report.status -eq 'READY_FOR_APPROVAL') "$slug should be eligible for review: $($report.findings | ConvertTo-Json -Compress)"
        Assert-Readiness (-not $report.executionAuthorized -and $report.authorizedOperationCategories.Count -eq 0) "$slug authorized execution."
        Assert-Readiness ((ConvertTo-AcceleratorCanonicalJson $report) -ceq (ConvertTo-AcceleratorCanonicalJson (Invoke-FixtureReadiness $fixture))) "$slug rerun was nondeterministic."
        Assert-Readiness ($report.dependencyOrder.Count -eq $fixture.plan.componentPlans.Count) "$slug dependency order incomplete."
        Save-SyntheticReport $report $slug
    }
    $hybrid = New-ReadinessFixture 'library-circulation' -Hybrid
    $readyHybrid = Invoke-FixtureReadiness $hybrid
    Assert-Readiness ($readyHybrid.status -eq 'READY_FOR_APPROVAL') "Hybrid should be eligible: $($readyHybrid.findings | ConvertTo-Json -Compress)"
    Save-SyntheticReport $readyHybrid 'library-circulation-hybrid'
    $hybrid.plan.componentPlans[0].action = 'EXTEND'
    $extension = Invoke-FixtureReadiness $hybrid -RebindPlan
    Assert-Readiness ($extension.status -eq 'READY_FOR_APPROVAL' -and -not $extension.executionAuthorized) 'Verified non-direct extension was not eligible for human review.'
    $chain = New-ReadinessFixture 'package-chain' -Hybrid
    $chainFolder = Split-Path $chain.evidencePath -Parent
    $primary = Read-BuildPlanningJson (Join-Path $chainFolder 'package.json')
    $base = $primary | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $base.moduleId = 'synthetic-base'; $base.packageId = 'synthetic-base-v1'
    $base.solution.uniqueName = 'synthetic_base'; $base.sha256 = 'd' * 64
    Write-FixtureJson (Join-Path $chainFolder 'base.json') $base
    $primary.declaredDependencies = @([pscustomobject]@{ required = [pscustomobject]@{ solution = 'synthetic_base (1.0.0.0)' } })
    Write-FixtureJson (Join-Path $chainFolder 'package.json') $primary
    $manifestPath = Join-Path $chainFolder 'package-input-manifest.json'
    $manifest = Read-BuildPlanningJson $manifestPath
    $manifest.packages += [pscustomobject]@{
        path = 'base.json'; moduleId = $base.moduleId; packageId = $base.packageId; version = '1.0.0.0'; sha256 = $base.sha256
    }
    Write-FixtureJson $manifestPath $manifest
    $chain.plan.inputFingerprints.packageManifest = Get-BuildPlanningFileHash $manifestPath
    $chain.evidence.packages += [pscustomobject]@{
        moduleId = $base.moduleId; packageId = $base.packageId; sha256 = $base.sha256
        solutionUniqueName = $base.solution.uniqueName; version = '1.0.0.0'; installed = $true; dependencies = @()
    }
    $chainReport = Invoke-FixtureReadiness $chain -RebindPlan
    Assert-Readiness ($chainReport.status -eq 'READY_FOR_APPROVAL') "Pinned transitive package metadata was not accepted: $($chainReport.findings | ConvertTo-Json -Compress)"
    Assert-Readiness (($chainReport.packageDependencyOrder -join ',') -ceq 'synthetic_base,synthetic_records') 'Declared package prerequisites were not ordered before dependent solutions.'
    $primary.declaredDependencies[0].required.solution = 'synthetic_base (2.0.0.0)'
    Write-FixtureJson (Join-Path $chainFolder 'package.json') $primary
    $minimumVersionReport = Invoke-FixtureReadiness $chain
    Assert-Readiness ($minimumVersionReport.status -eq 'BLOCKED_PREREQUISITES') 'Declared minimum package version was not enforced.'
    Assert-Readiness ($minimumVersionReport.scopeSha256 -cne $chainReport.scopeSha256) 'Changed transitive dependency metadata did not invalidate the authorization scope.'

    $cases = @(
        @{ name = 'missing-prerequisites'; hybrid = $true; status = 'BLOCKED_PREREQUISITES'; mutate = { param($f) $f.evidence.packages[0].installed = $false } },
        @{ name = 'stale-evidence'; hybrid = $false; status = 'BLOCKED_EVIDENCE'; mutate = { param($f) $f.evidence.expiresAtUtc = '2026-10-19T11:30:00Z' } },
        @{ name = 'future-evidence'; hybrid = $false; status = 'BLOCKED_EVIDENCE'; mutate = { param($f) $f.evidence.observedAtUtc = '2026-10-19T12:30:00Z' } },
        @{ name = 'overlong-evidence'; hybrid = $false; status = 'BLOCKED_EVIDENCE'; mutate = { param($f) $f.evidence.expiresAtUtc = '2026-10-21T13:00:00Z' } },
        @{ name = 'conflicting-components'; hybrid = $false; status = 'BLOCKED_COMPATIBILITY'; mutate = { param($f) $f.evidence.components[0].exists = $true } },
        @{ name = 'managed-overwrite'; hybrid = $true; status = 'BLOCKED_COMPATIBILITY'; mutate = { param($f) $f.plan.componentPlans[0].directModificationAllowed = $true } },
        @{ name = 'managed-restricted'; hybrid = $true; status = 'BLOCKED_COMPATIBILITY'; mutate = { param($f) $f.plan.componentPlans[0].action = 'EXTEND'; $f.evidence.components[0].customizable = $false } },
        @{ name = 'missing-permissions'; hybrid = $false; status = 'BLOCKED_SECURITY'; mutate = { param($f) $f.evidence.security.grantedPermissions = @('read-metadata') } },
        @{ name = 'unauthorized-decision'; hybrid = $false; status = 'BLOCKED_DECISION_CHANGE'; mutate = { param($f) $f.decision.explicitApproval = $false; Write-FixtureJson (Join-Path $f.root "specs\$($f.slug)\accelerator\accelerator-decision.json") $f.decision } },
        @{ name = 'changed-environment'; hybrid = $false; status = 'BLOCKED_DECISION_CHANGE'; mutate = { param($f) $f.evidence.environment.environmentId = '44444444-4444-4444-8444-444444444444' } },
        @{ name = 'changed-package'; hybrid = $true; status = 'BLOCKED_DECISION_CHANGE'; mutate = { param($f) $f.evidence.packages[0].sha256 = 'd' * 64 } },
        @{ name = 'changed-package-version'; hybrid = $true; status = 'BLOCKED_DECISION_CHANGE'; mutate = { param($f) $f.evidence.packages[0].version = '2.0.0.0' } },
        @{ name = 'changed-input'; hybrid = $false; status = 'BLOCKED_DECISION_CHANGE'; mutate = { param($f) Add-Content (Join-Path $f.root "specs\$($f.slug)\spec.md") 'Material change' } },
        @{ name = 'missing-ownership'; hybrid = $false; status = 'BLOCKED_EVIDENCE'; mutate = { param($f) $f.evidence.components = @() } },
        @{ name = 'traceability-gap'; hybrid = $false; status = 'BLOCKED_EVIDENCE'; mutate = { param($f) $f.plan.traceability[0].taskIds = @() } },
        @{ name = 'dependency-cycle'; hybrid = $false; status = 'BLOCKED_COMPATIBILITY'; mutate = { param($f) $f.plan.componentPlans[0].dependencies = @($f.plan.componentPlans[0].taskId) } },
        @{ name = 'package-cycle'; hybrid = $true; status = 'BLOCKED_COMPATIBILITY'; mutate = { param($f) $f.evidence.packages[0].dependencies = @('synthetic_records') } },
        @{ name = 'transitive-dependency'; hybrid = $true; status = 'BLOCKED_COMPATIBILITY'; mutate = { param($f) $f.evidence.packages[0].dependencies = @('missing_solution') } },
        @{ name = 'duplicate-package'; hybrid = $true; status = 'BLOCKED_COMPATIBILITY'; mutate = { param($f) $f.evidence.packages += $f.evidence.packages[0] } },
        @{ name = 'duplicate-task'; hybrid = $false; status = 'BLOCKED_EVIDENCE'; mutate = { param($f) $f.plan.componentPlans += $f.plan.componentPlans[0] } },
        @{ name = 'unresolved-ownership'; hybrid = $false; status = 'BLOCKED_COMPATIBILITY'; mutate = { param($f) $f.evidence.components[0].ownership = 'unresolved' } },
        @{ name = 'deferred-operation'; hybrid = $false; status = 'BLOCKED_COMPATIBILITY'; mutate = { param($f) $f.plan.componentPlans[0].action = 'DEFER'; $f.plan.componentPlans[0].status = 'verification-required' } },
        @{ name = 'empty-principal'; hybrid = $false; status = 'BLOCKED_SECURITY'; mutate = { param($f) $f.evidence.security.principalId = [guid]::Empty.ToString() } },
        @{ name = 'blocked-plan'; hybrid = $false; status = 'BLOCKED_PREREQUISITES'; mutate = { param($f) $f.plan.status = 'blocked' } },
        @{ name = 'blocked-actions'; hybrid = $false; status = 'BLOCKED_PREREQUISITES'; mutate = { param($f) $f.plan.blockedActions = @('Pending prerequisite.') } },
        @{ name = 'destructive-operation'; hybrid = $false; status = 'BLOCKED_EVIDENCE'; mutate = { param($f) $f.plan.componentPlans[0].action = 'DELETE' } }
    )
    foreach ($case in $cases) {
        $fixture = New-ReadinessFixture $case.name -Hybrid:$case.hybrid
        $before = Invoke-FixtureReadiness $fixture
        & $case.mutate $fixture
        $report = Invoke-FixtureReadiness $fixture -RebindPlan
        Assert-Readiness ($report.status -eq $case.status) "$($case.name): expected $($case.status), got $($report.status): $($report.findings | ConvertTo-Json -Compress)"
        Assert-Readiness (-not $report.executionAuthorized -and -not $report.eligibleForHumanApproval -and $report.blockedOperations.Count -gt 0) "$($case.name): blocked result granted approval or omitted blocked operations."
        Assert-Readiness ($report.scopeSha256 -cne $before.scopeSha256) "$($case.name): material change did not invalidate prior authorization scope."
        if ($case.name -in @('missing-prerequisites', 'stale-evidence', 'conflicting-components',
            'managed-restricted', 'missing-permissions', 'unauthorized-decision', 'changed-package')) {
            Save-SyntheticReport $report $case.name
        }
    }
    $fixture = New-ReadinessFixture 'immutable-plan'
    $fixture.plan.componentPlans[0].displayName = 'Tampered bytes'
    Write-FixtureJson $fixture.planPath $fixture.plan
    $report = Invoke-FixtureReadiness $fixture
    Assert-Readiness ($report.status -eq 'BLOCKED_DECISION_CHANGE') 'Unbound plan changes were not blocked.'
    $whitespace = New-ReadinessFixture 'plan-byte-binding'
    Add-Content -LiteralPath $whitespace.planPath -Value ' '
    $unchangedPlanIdentity = Get-ExecutionPlanIdentity (Read-BuildPlanningJson $whitespace.planPath)
    Assert-Readiness ($unchangedPlanIdentity -ceq $whitespace.plan.planId) 'Whitespace-only test unexpectedly changed canonical plan content.'
    $byteReport = Invoke-FixtureReadiness $whitespace
    Assert-Readiness ($byteReport.status -eq 'BLOCKED_DECISION_CHANGE') 'Exact plan SHA-256 binding allowed whitespace-only byte changes.'
    $lifetime = New-ReadinessFixture 'exact-evidence-lifetime'
    $lifetime.evidence.expiresAtUtc = '2026-10-20T11:00:00Z'
    Assert-Readiness ((Invoke-FixtureReadiness $lifetime).status -eq 'READY_FOR_APPROVAL') 'Evidence with exactly a 24-hour lifetime was rejected.'
    $lifetime.evidence.expiresAtUtc = '2026-10-20T11:00:01Z'
    Assert-Readiness ((Invoke-FixtureReadiness $lifetime).status -eq 'BLOCKED_EVIDENCE') 'Evidence lifetime one second over the 24-hour maximum was accepted.'

    $missing = New-ReadinessFixture 'missing-evidence'
    Remove-Item -LiteralPath $missing.evidencePath
    $missingReport = Get-ExecutionReadiness -WorkspaceRoot $missing.root -ScenarioSlug $missing.slug -EvidencePath $missing.evidencePath `
        -EnvironmentUrl 'https://synthetic.example.test' -EnvironmentId $environmentId -TenantId $tenantId -EvaluationTimeUtc $clock
    Assert-Readiness ($missingReport.status -eq 'BLOCKED_EVIDENCE' -and $null -eq $missingReport.evidenceSha256) 'Missing evidence did not produce a blocked report with an absent digest.'
    Set-Content -LiteralPath $missing.evidencePath -Value '{invalid'
    $invalidReport = Get-ExecutionReadiness -WorkspaceRoot $missing.root -ScenarioSlug $missing.slug -EvidencePath $missing.evidencePath `
        -EnvironmentUrl 'https://synthetic.example.test' -EnvironmentId $environmentId -TenantId $tenantId -EvaluationTimeUtc $clock
    Assert-Readiness ($invalidReport.status -eq 'BLOCKED_EVIDENCE') 'Malformed evidence did not fail closed.'
    $expired = New-ReadinessFixture 'expired-clock'
    $pastExpiry = Get-ExecutionReadiness -WorkspaceRoot $expired.root -ScenarioSlug $expired.slug -EvidencePath $expired.evidencePath `
        -EnvironmentUrl 'https://synthetic.example.test' -EnvironmentId $environmentId -TenantId $tenantId -EvaluationTimeUtc $clock.AddHours(2)
    Assert-Readiness ($pastExpiry.status -eq 'BLOCKED_EVIDENCE') 'Advancing the evaluation clock did not revoke readiness.'
    $fixture = New-ReadinessFixture 'hook-ready'
    $copyScripts = Join-Path $fixture.root 'scripts\accelerators'
    New-Item -ItemType Directory -Path $copyScripts -Force | Out-Null
    foreach ($name in @('accelerator-catalog.ps1', 'build-planning-adapter.ps1', 'execution-readiness.ps1', 'invoke-execution-readiness.ps1')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot "scripts\accelerators\$name") -Destination $copyScripts
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'schemas') -Destination $fixture.root -Recurse
    $bootstrap = Join-Path $fixture.root 'scripts\bootstrap'
    New-Item -ItemType Directory -Path $bootstrap -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\bootstrap\90-run-build.ps1') -Destination $bootstrap
    $hook = & (Join-Path $bootstrap '90-run-build.ps1') -ScenarioSlug $fixture.slug -ExecutionReadinessOnly `
        -ExecutionEvidencePath $fixture.evidencePath -EnvironmentUrl 'https://synthetic.example.test' `
        -ReadinessEnvironmentId $environmentId -ReadinessTenantId $tenantId -ReadinessEvaluationTimeUtc $clock
    Assert-Readiness ($hook.status -eq 'READY_FOR_APPROVAL' -and -not $hook.executionAuthorized) 'Ready preflight did not remain nonexecuting.'
    Assert-Readiness (-not (Test-Path (Join-Path $fixture.root '.wizard-metrics'))) 'Preflight initialized build state.'
    Assert-Readiness (-not (Test-Path (Join-Path $fixture.root 'payloads'))) 'Preflight required or generated payloads.'
    $fixture.plan.architecture = 'hybrid'
    Write-FixtureJson $fixture.planPath $fixture.plan
    Remove-Item -LiteralPath (Join-Path $fixture.root "specs\$($fixture.slug)\accelerator\accelerator-decision.json")
    try {
        & (Join-Path $bootstrap '90-run-build.ps1') -ScenarioSlug $fixture.slug -Mode Apply
        Assert-Readiness $false 'FAST-dependent plan with missing decision executed.'
    } catch { Assert-Readiness ($_.Exception.Message -match 'FAST-dependent or unresolved build execution is disabled') 'Missing decision bypassed the FAST plan guard.' }
    try {
        & (Join-Path $bootstrap '90-run-build.ps1') -ScenarioSlug $fixture.slug -ExecutionReadinessOnly -Mode Apply
        Assert-Readiness $false 'Preflight accepted Apply.'
    } catch { Assert-Readiness ($_.Exception.Message -match 'nonexecuting') 'Preflight Apply failed for the wrong reason.' }
    try {
        & (Join-Path $repoRoot 'scripts\bootstrap\90-run-build.ps1') -ScenarioSlug 'fast-005a-fraud-investigation-advanced' -Mode Apply
        Assert-Readiness $false 'FAST-dependent Apply executed.'
    } catch { Assert-Readiness ($_.Exception.Message -match 'FAST-dependent or unresolved build execution is disabled') 'FAST Apply failed for the wrong reason.' }
    try {
        & (Join-Path $repoRoot 'scripts\accelerators\invoke-execution-readiness.ps1') -ScenarioSlug $fixture.slug `
            -EvidencePath $fixture.evidencePath -EnvironmentUrl 'https://synthetic.example.test' -EnvironmentId $environmentId -TenantId $tenantId
        Assert-Readiness $false 'Readiness was enabled by default.'
    } catch { Assert-Readiness ($_.Exception.Message -match 'disabled by default') 'Default-off command failed for the wrong reason.' }

    foreach ($name in @('execution-readiness.ps1', 'invoke-execution-readiness.ps1')) {
        $source = Get-Content (Join-Path $repoRoot "scripts\accelerators\$name") -Raw
        Assert-Readiness ($source -notmatch '(?i)Invoke-RestMethod|Invoke-WebRequest|\bpac\s+(solution|auth)|20-build|30-build|40-build|50-add|RequestInvoker') "$name contains an execution/network surface."
        Assert-Readiness ($source -notmatch '(?i)\bfraud\b|\binvestigation\b|\bhealthcare\b|\beducation\b|\bgovernment\b') "$name hardcodes a business domain."
    }
    $authorizationSchema = Get-Content (Join-Path $repoRoot 'schemas\accelerators\build-authorization.schema.json') -Raw | ConvertFrom-Json
    foreach ($required in @('decisionId', 'decisionSha256', 'planId', 'planSha256', 'scopeSha256', 'environment', 'operationCategories', 'taskIds', 'approver', 'approvedAtUtc', 'expiresAtUtc', 'prerequisiteEvidence')) {
        Assert-Readiness ($authorizationSchema.required -contains $required) "Authorization contract omits $required."
    }
    Assert-Readiness (-not (Test-ExecutionSchema ([pscustomobject]@{ schemaVersion = '1.0' }) 'build-authorization')) 'Incomplete authorization passed its schema.'
    Assert-Readiness (@(Get-ChildItem $tempRoot -Filter 'build-authorization.json' -Recurse -File).Count -eq 0) 'Tests generated an authorization record.'
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
if ($failures.Count -gt 0) { throw "FAST-007 failed ($($failures.Count)/$checks):`n - $($failures -join "`n - ")" }
Write-Host "FAST-007 execution readiness passed: $checks assertions; 4 cross-domain applications and $($cases.Count) negative scenarios. No execution authorization issued." -ForegroundColor Green
