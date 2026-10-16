<#
=============================================================================
COMPONENT:    Accelerator Build Planning Tests
FILE:         scripts/ci/test-accelerator-build-planning.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-16
ENVIRONMENT:  PowerShell 7 | CI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Validates the provider-neutral, dry-run-only FAST-006 planning adapter.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts\accelerators\build-planning-adapter.ps1')
$failures = [Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $failures.Add($Message) | Out-Null }
}

function New-TestDecision {
    param([string]$ScenarioSlug)

    $analysis = [pscustomobject][ordered]@{
        analysisId = "sha256:$('a' * 64)"
        providerId = 'fixture-provider'
        snapshotId = "sha256:$('b' * 64)"
    }
    $basis = [ordered]@{
        scenarioSlug = $ScenarioSlug
        mode = 'advanced-builder'
        evaluationStatus = 'completed'
        analysisId = $analysis.analysisId
        snapshotId = $analysis.snapshotId
        recommendedOption = 'fully-custom'
        selectedOption = 'fully-custom'
        selectedPackages = @()
        rationale = 'Approved industry-agnostic CI fixture.'
    }
    $decision = [pscustomobject][ordered]@{
        schemaVersion = '1.0'
        decisionId = "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $basis))"
        scenarioSlug = $basis.scenarioSlug
        wizardMode = $basis.mode
        evaluationStatus = $basis.evaluationStatus
        analysisId = $basis.analysisId
        catalogSnapshotId = $basis.snapshotId
        recommendedOption = $basis.recommendedOption
        selectedOption = $basis.selectedOption
        selectedPackages = @()
        rationale = $basis.rationale
        explicitApproval = $true
        recordedAtUtc = '2026-10-16T12:00:00Z'
    }
    return [pscustomobject]@{ analysis = $analysis; decision = $decision }
}

function New-IndustryPlan {
    param(
        [string]$ScenarioSlug,
        [string]$RequirementId,
        [string]$Description,
        [string[]]$TableNames,
        [bool]$ExternalIntegration = $false
    )

    $approval = New-TestDecision -ScenarioSlug $ScenarioSlug
    $coverage = [pscustomobject]@{
        requirementId = $RequirementId
        description = $Description
        dispositions = if ($ExternalIntegration) { @('BUILD', 'INTEGRATE') } else { @('BUILD') }
        candidateModuleId = ''
        candidates = @()
        acceptanceCriteria = @('The requirement is verifiably implemented.')
    }
    $tables = @(
        $TableNames | ForEach-Object {
            [pscustomobject]@{
                displayName = $_
                logicalName = "tst_$($_.ToLowerInvariant() -replace '[^a-z0-9]+', '')"
            }
        }
    )
    return New-ProviderNeutralBuildPlan `
        -Decision $approval.decision `
        -AnalysisManifest $approval.analysis `
        -CoverageMatrix @($coverage) `
        -ComponentDelta @([pscustomobject]@{ requirementId = $RequirementId }) `
        -SchemaPlan ([pscustomobject]@{ reuse = @(); extend = @(); build = @(); integrate = @(); verify = @() }) `
        -DependencyManifest ([pscustomobject]@{}) `
        -EnvironmentReadiness ([pscustomobject]@{}) `
        -AcceptanceTraceability @([pscustomobject]@{ requirementId = $RequirementId; acceptanceCriteria = @('The requirement is verifiably implemented.'); evidenceReferences = @() }) `
        -ScenarioMappings ([pscustomobject]@{
            publisherPrefix = 'tst'
            appName = "$ScenarioSlug application"
            bpfEnabled = $false
            tables = $tables
            fields = @()
            relationships = @()
        })
}

$fixtures = @(
    @{ slug = 'equipment-maintenance'; id = 'REQ-EQUIPMENT-001'; description = 'Track equipment inventory and maintenance schedules'; tables = @('Equipment', 'Maintenance Schedule'); integration = $false },
    @{ slug = 'employee-onboarding'; id = 'REQ-ONBOARDING-001'; description = 'Coordinate employee onboarding and task approvals'; tables = @('Employee Onboarding', 'Approval Task'); integration = $false },
    @{ slug = 'event-registration'; id = 'REQ-EVENT-001'; description = 'Manage event registration and attendance'; tables = @('Event', 'Registration', 'Attendance'); integration = $false },
    @{ slug = 'customer-service'; id = 'REQ-SERVICE-001'; description = 'Manage customer service requests'; tables = @('Service Request'); integration = $false },
    @{ slug = 'external-api'; id = 'REQ-EXTERNAL-001'; description = 'Synchronize application records with an external API'; tables = @('Application Record', 'Integration Audit'); integration = $true },
    @{ slug = 'relevant-accelerator'; id = 'REQ-REUSE-001'; description = 'Plan a solution when accelerator evidence may be relevant'; tables = @('Reusable Record'); integration = $false },
    @{ slug = 'no-accelerator'; id = 'REQ-NOMATCH-001'; description = 'Plan a solution with no relevant accelerator'; tables = @('Novel Record'); integration = $false },
    @{ slug = 'fully-custom-no-fast'; id = 'REQ-CUSTOM-001'; description = 'Plan a fully custom application without FAST evaluation'; tables = @('Custom Record'); integration = $false }
)

foreach ($fixture in $fixtures) {
    try {
        $first = New-IndustryPlan -ScenarioSlug $fixture.slug -RequirementId $fixture.id -Description $fixture.description -TableNames $fixture.tables -ExternalIntegration $fixture.integration
        $second = New-IndustryPlan -ScenarioSlug $fixture.slug -RequirementId $fixture.id -Description $fixture.description -TableNames $fixture.tables -ExternalIntegration $fixture.integration
        Assert-True ($first.architecture -eq 'fully-custom') "$($fixture.slug): architecture was not Fully Custom."
        Assert-True (-not [bool]$first.executionAuthorized) "$($fixture.slug): dry-run plan authorized execution."
        Assert-True (-not [bool]$first.environment.requiredForArchitecture) "$($fixture.slug): Fully Custom inherited an environment gate."
        Assert-True (@($first.componentPlans | Where-Object ownership -eq 'accelerator-managed').Count -eq 0) "$($fixture.slug): Fully Custom inherited accelerator ownership."
        Assert-True ($first.planId -ceq $second.planId) "$($fixture.slug): repeated plan ID was not deterministic."
    } catch {
        $failures.Add("$($fixture.slug): $($_.Exception.Message)") | Out-Null
    }
}

$hybridPath = Join-Path $repoRoot 'specs\fast-005a-fraud-investigation-advanced\accelerator\build-plan\build-plan-manifest.json'
$customPath = Join-Path $repoRoot 'specs\fast-006-fraud-investigation-fully-custom\accelerator\build-plan\build-plan-manifest.json'
foreach ($requiredPlanPath in @($hybridPath, $customPath)) {
    Assert-True (Test-Path -LiteralPath $requiredPlanPath -PathType Leaf) "Missing acceptance plan: $requiredPlanPath"
}
if (Test-Path -LiteralPath $hybridPath -PathType Leaf) {
    $hybrid = Get-Content -LiteralPath $hybridPath -Raw | ConvertFrom-Json
    Assert-True ($hybrid.architecture -eq 'hybrid' -and $hybrid.status -eq 'blocked') 'GCC Hybrid plan must remain blocked.'
    Assert-True (-not [bool]$hybrid.executionAuthorized) 'Hybrid dry-run plan authorized execution.'
    Assert-True (@($hybrid.componentPlans | Where-Object { $_.managed -and $_.directModificationAllowed }).Count -eq 0) 'A managed component permits direct modification.'
    Assert-True (@($hybrid.componentPlans | Where-Object { $_.componentIdentity -eq 'fiv_report' -and $_.action -eq 'CREATE' }).Count -eq 1) 'Report was not kept solution-owned.'
    Assert-True (@($hybrid.componentPlans | Group-Object taskId | Where-Object Count -gt 1).Count -eq 0) 'Hybrid plan contains duplicate task IDs.'
}
if (Test-Path -LiteralPath $customPath -PathType Leaf) {
    $custom = Get-Content -LiteralPath $customPath -Raw | ConvertFrom-Json
    Assert-True ($custom.architecture -eq 'fully-custom' -and $custom.status -eq 'dry-run-ready') 'Fully Custom acceptance plan is not independently ready.'
    Assert-True (@($custom.componentPlans | Where-Object ownership -eq 'accelerator-managed').Count -eq 0) 'Fully Custom acceptance plan references accelerator ownership.'

    $decisionChangeFolder = Join-Path ([IO.Path]::GetTempPath()) "fast006-decision-$([guid]::NewGuid().ToString('N'))"
    try {
        Write-ProviderNeutralBuildPlanArtifacts -Plan $custom -OutputFolder $decisionChangeFolder | Out-Null
        $changed = $custom | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        $changed.decisionId = "sha256:$('c' * 64)"
        $rejected = $false
        try {
            Write-ProviderNeutralBuildPlanArtifacts -Plan $changed -OutputFolder $decisionChangeFolder | Out-Null
        } catch {
            $rejected = $_.Exception.Message -match 'decision changed'
        }
        Assert-True $rejected 'Changed approved decision did not require explicit build-plan approval.'
        Write-ProviderNeutralBuildPlanArtifacts -Plan $changed -OutputFolder $decisionChangeFolder -ApproveDecisionChange | Out-Null
    } finally {
        if (Test-Path -LiteralPath $decisionChangeFolder) {
            Remove-Item -LiteralPath $decisionChangeFolder -Recurse -Force
        }
    }
}

$productionText = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\accelerators\build-planning-adapter.ps1') -Raw
foreach ($domainToken in @('fraud', 'investigation', 'healthcare', 'government', 'education', 'manufacturing')) {
    Assert-True ($productionText -notmatch "(?i)\b$domainToken\b") "Production adapter contains domain-coupled token '$domainToken'."
}
$executableText = $productionText -replace '(?s)<#.*?#>', ''
Assert-True ($executableText -notmatch '(?im)^\s*(?:&\s+pac\b|pac\s+solution\b|Invoke-RestMethod\b|Invoke-WebRequest\b)') 'Production adapter contains a live execution or network command.'

$unapproved = New-TestDecision -ScenarioSlug 'unapproved'
$unapproved.decision.explicitApproval = $false
$threw = $false
try {
    Assert-ApprovedArchitectureDecision -Decision $unapproved.decision -AnalysisManifest $unapproved.analysis -PackageMetadata @()
} catch {
    $threw = $_.Exception.Message -match 'not explicitly approved'
}
Assert-True $threw 'Unapproved architecture decision was not rejected.'

if ($failures.Count -gt 0) {
    throw "Accelerator build-planning validation failed:`n - $($failures -join "`n - ")"
}

Write-Host "Accelerator build-planning validation passed: $($fixtures.Count) unrelated fixtures plus Hybrid and Fully Custom acceptance plans." -ForegroundColor Green
