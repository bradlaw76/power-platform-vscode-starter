<#
=============================================================================
COMPONENT:    Build Business Process Flows
FILE:         scripts/bootstrap/55-build-business-process-flows.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API | Designer-authored BPF

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Validates scenario-driven business process flow plans and integrates a process
authored through the supported Power Apps designer when enabled.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          BPF design files, planning artifacts, and environment data
- Outputs:         handoff plan, validation artifacts, and console guidance
- Dependencies:    Dataverse Web API, BPF helper logic, planning files
- Side Effects:    may activate, solution-add, and app-link an existing BPF

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Scenario planning must justify a staged lifecycle.
2. Required process artifacts and entity mappings must already exist.
3. Apply mode requires a matching BPF authored in the Power Apps designer.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Enabled BPF scenarios produce a validated designer handoff.
✔ Apply mode refuses unsupported direct process metadata creation.
✔ Inapplicable scenarios skip safely without mutating the environment.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.2.0  2026-08-24  Enforced supported designer-authored BPF provisioning.
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Skip safely when BPF is not enabled or not justified.
- Keep process root and stage mappings aligned with planning files.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Validates and integrates designer-authored Business Process Flows from process-*.json.

.DESCRIPTION
    Reads scenario-specific process payloads and validates them against planning artifacts plus table/column/relationship payloads.
    Preview mode writes a handoff plan without Dataverse mutation. Apply mode requires a matching category-4 process authored
    through the supported Power Apps designer, then validates, activates, adds, and links that existing component.

.PARAMETER EnvironmentUrl     Defaults to $env:DV_ENVIRONMENT_URL.
.PARAMETER AccessToken        Defaults to $env:DV_TOKEN.
.PARAMETER SolutionUniqueName Defaults to $env:DV_SOLUTION_NAME.
.PARAMETER PayloadsFolder     Optional payload folder override.
.PARAMETER ScenarioSlug       Scenario slug used to resolve payloads/scenarios/<slug>/ and specs/<slug>/.
.PARAMETER EnableBusinessProcessFlow
    If false, the script writes a skipped report and exits without attempting Dataverse changes.
.PARAMETER BusinessProcessFlowName
    Optional override for the process display name in the payload.
.PARAMETER PrimaryProcessEntity
    Optional override for the process root entity logical name in the payload.
.PARAMETER FailIfBpfDefinitionIncomplete
    When true, validation failures stop the run. When false, incomplete definitions are skipped with a report.
.PARAMETER PreferUpdateExistingBpf
    Retained for contract compatibility. Existing BPF metadata is never rewritten by this script.
.PARAMETER PreviewOnly
    Writes validation and designer-handoff artifacts without requiring credentials or mutating Dataverse.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PayloadsFolder = '',
    [string]$ScenarioSlug = '',
    [bool]$EnableBusinessProcessFlow = $true,
    [string]$BusinessProcessFlowName = '',
    [string]$PrimaryProcessEntity = '',
    [bool]$FailIfBpfDefinitionIncomplete = $true,
    [bool]$PreferUpdateExistingBpf = $true,
    [bool]$PreviewOnly = $false,
    [int]$MinimumStageCount = 2,
    [int]$MinimumConditionCount = 2,
    [int]$MinimumStepCount = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot 'helpers\wizard-telemetry.ps1'
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName '55-build-business-process-flows.ps1'
}

$hardeningHelper = Join-Path $PSScriptRoot 'helpers\wizard-hardening.ps1'
if (Test-Path $hardeningHelper) {
    . $hardeningHelper
}

. (Join-Path $PSScriptRoot 'helpers\bpf-validation.ps1')

$envFile = Join-Path $repoRoot '.env.ps1'
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    $AccessToken = $global:DV_TOKEN
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName) -and -not [string]::IsNullOrWhiteSpace($global:DV_SOLUTION_NAME)) {
        $SolutionUniqueName = $global:DV_SOLUTION_NAME
    }
}

if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    $scenarioDirs = @(Get-ChildItem -Path (Join-Path $repoRoot 'specs') -Directory -ErrorAction SilentlyContinue)
    if ($scenarioDirs.Count -eq 1) {
        $ScenarioSlug = $scenarioDirs[0].Name
    }
}

if (Get-Command Initialize-WizardArtifactManifest -ErrorAction SilentlyContinue) {
    Initialize-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $env:DV_PUBLISHER_PREFIX | Out-Null
}

$artifactPaths = Get-ScenarioArtifactPaths -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug
$artifactText = Get-PlanningArtifactContent -Paths @($artifactPaths.AnswersPath, $artifactPaths.SpecPath, $artifactPaths.PlanPath, $artifactPaths.TasksPath)
$scenarioPayloadFolder = Get-ScenarioPayloadFolder -RepoRoot $repoRoot -PayloadsFolder $PayloadsFolder -ScenarioSlug $ScenarioSlug
$processDefinitions = @(Get-BpfDefinitions -PayloadFolder $scenarioPayloadFolder)
$reportFolder = Join-Path $artifactPaths.ScenarioFolder 'reports'
$reportPath = Join-Path $reportFolder 'business-process-flow-report.json'
$handoffPath = Join-Path $reportFolder 'business-process-flow-designer-handoff.md'
$runtimeNotes = New-Object System.Collections.Generic.List[string]

function Get-RetryDelaySeconds {
    param([int]$Attempt)

    $delay = [Math]::Pow(2, [Math]::Max(0, ($Attempt - 1)))
    return [int][Math]::Min(30, $delay)
}

function Test-IsRetryableDataverseError {
    param([System.Exception]$Exception)

    if ($null -eq $Exception) { return $false }
    $message = ($Exception.Message ?? '')
    return (
        $message -match '429' -or
        $message -match 'Too Many Requests' -or
        $message -match 'timeout' -or
        $message -match 'temporar' -or
        $message -match 'lock' -or
        $message -match 'busy' -or
        $message -match 'throttl' -or
        $message -match '503'
    )
}

function Get-BpfDerivedMetrics {
    param([array]$StageSummaries)

    $stageCount = @($StageSummaries).Count
    $conditionCount = 0
    $stepCount = 0
    foreach ($stage in @($StageSummaries)) {
        if (-not [string]::IsNullOrWhiteSpace(($stage.EntryCriteria ?? '').Trim())) { $conditionCount++ }
        if (-not [string]::IsNullOrWhiteSpace(($stage.ExitCriteria ?? '').Trim())) { $conditionCount++ }
        $stepCount += @($stage.RequiredFields).Count
    }

    return [pscustomobject]@{
        StageCount = $stageCount
        ConditionCount = $conditionCount
        StepCount = $stepCount
    }
}

function Test-BpfRuntimeThresholds {
    param(
        [array]$StageSummaries,
        [int]$MinStage,
        [int]$MinCondition,
        [int]$MinStep
    )

    $metrics = Get-BpfDerivedMetrics -StageSummaries $StageSummaries
    $passed = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]

    if ($metrics.StageCount -lt $MinStage) {
        $failed.Add("Stage threshold failed: expected >= $MinStage but found $($metrics.StageCount).") | Out-Null
    } else {
        $passed.Add("Stage threshold passed: $($metrics.StageCount) >= $MinStage.") | Out-Null
    }

    if ($metrics.ConditionCount -lt $MinCondition) {
        $failed.Add("Condition threshold failed: expected >= $MinCondition but found $($metrics.ConditionCount).") | Out-Null
    } else {
        $passed.Add("Condition threshold passed: $($metrics.ConditionCount) >= $MinCondition.") | Out-Null
    }

    if ($metrics.StepCount -lt $MinStep) {
        $failed.Add("Step threshold failed: expected >= $MinStep but found $($metrics.StepCount).") | Out-Null
    } else {
        $passed.Add("Step threshold passed: $($metrics.StepCount) >= $MinStep.") | Out-Null
    }

    return [pscustomobject]@{
        Metrics = $metrics
        Passed = $passed.ToArray()
        Failed = $failed.ToArray()
        Thresholds = [ordered]@{
            MinimumStageCount = $MinStage
            MinimumConditionCount = $MinCondition
            MinimumStepCount = $MinStep
        }
    }
}

function Get-BranchPredicateSummary {
    param([array]$StageSummaries)

    return @($StageSummaries | Sort-Object Order | ForEach-Object {
        [ordered]@{
            StageOrder = $_.Order
            StageName = $_.StageName
            EntryCriteria = $_.EntryCriteria
            ExitCriteria = $_.ExitCriteria
        }
    })
}

function Write-BpfReportFile {
    param([hashtable]$Report)

    New-Item -ItemType Directory -Path $reportFolder -Force | Out-Null
    Set-Content -Path $reportPath -Value ($Report | ConvertTo-Json -Depth 12) -Encoding UTF8
}

function Write-BpfDesignerHandoff {
    param(
        [object]$Definition,
        [object]$Validation
    )

    New-Item -ItemType Directory -Path $reportFolder -Force | Out-Null
    $uniqueName = ConvertTo-WorkflowUniqueName -Value $Definition.BusinessProcessFlowName
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Business Process Flow Designer Handoff') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('This repository does not create BPF definition metadata through direct Dataverse Web API workflow payloads.') | Out-Null
    $lines.Add('Create the process with the Power Apps Business Process Flow designer, add it to the target solution, publish it, then rerun step 55.') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Display name: $($Definition.BusinessProcessFlowName)") | Out-Null
    $lines.Add("- Expected unique name: $uniqueName") | Out-Null
    $lines.Add("- Primary table: $($Definition.PrimaryProcessEntity)") | Out-Null
    $lines.Add("- Target solution: $SolutionUniqueName") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Stages') | Out-Null
    foreach ($stage in @($Validation.StageSummaries | Sort-Object Order)) {
        $lines.Add('') | Out-Null
        $lines.Add("### $($stage.Order). $($stage.StageName)") | Out-Null
        $lines.Add("- Table: $($stage.EntityLogicalName)") | Out-Null
        $lines.Add("- Required fields: $(@($stage.RequiredFields) -join ', ')") | Out-Null
        $lines.Add("- Entry criteria: $($stage.EntryCriteria)") | Out-Null
        $lines.Add("- Exit criteria: $($stage.ExitCriteria)") | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($stage.RelationshipLogicalName)) {
            $lines.Add("- Relationship: $($stage.RelationshipLogicalName)") | Out-Null
        }
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Verification') | Out-Null
    $lines.Add('1. Activate the process in the designer.') | Out-Null
    $lines.Add('2. Confirm the process is present in the target unmanaged solution.') | Out-Null
    $lines.Add('3. Rerun step 55 in apply mode; it validates and links the existing process.') | Out-Null
    Set-Content -Path $handoffPath -Value ($lines -join "`r`n") -Encoding UTF8
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = ''
    )

    $headers = @{
        Authorization      = "Bearer $AccessToken"
        'Content-Type'     = 'application/json'
        'OData-Version'    = '4.0'
        'OData-MaxVersion' = '4.0'
        Accept             = 'application/json'
    }

    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ([string]::IsNullOrWhiteSpace($Body)) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }

    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body
}

function Invoke-DvWithRetry {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = '',
        [int]$MaxAttempts = 5
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return Invoke-Dv -Method $Method -Path $Path -Body $Body
        } catch {
            if ($attempt -ge $MaxAttempts -or -not (Test-IsRetryableDataverseError -Exception $_.Exception)) {
                throw
            }

            $delaySeconds = Get-RetryDelaySeconds -Attempt $attempt
            $note = "Retry $attempt/$MaxAttempts for $Method $Path after transient Dataverse issue: $($_.Exception.Message)"
            $runtimeNotes.Add($note) | Out-Null
            Write-Host "  RETRY: $note" -ForegroundColor Yellow
            Start-Sleep -Seconds $delaySeconds
        }
    }
}

function ConvertTo-WorkflowUniqueName {
    param([string]$Value)

    $slug = ($Value ?? '').Trim().ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '_')
    $slug = $slug.Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return 'wizard_bpf'
    }

    return "wizard_$slug"
}

function Get-ExistingWorkflow {
    param([string]$UniqueName)

    $safeName = $UniqueName.Replace("'", "''")
    $resp = Invoke-Dv -Method 'Get' -Path "workflows?`$select=workflowid,name,uniquename,category,statecode,statuscode&`$filter=uniquename eq '$safeName'"
    return @($resp.value | Select-Object -First 1)
}

function Get-Solution {
    param([string]$UniqueName)

    $safeName = $UniqueName.Replace("'", "''")
    $resp = Invoke-Dv -Method 'Get' -Path "solutions?`$select=solutionid,uniquename&`$filter=uniquename eq '$safeName'"
    return @($resp.value | Select-Object -First 1)
}

function Get-ComponentTypeValue {
    param([string]$Label)

    $meta = Invoke-Dv -Method 'Get' -Path "EntityDefinitions(LogicalName='solutioncomponent')/Attributes(LogicalName='componenttype')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName&`$expand=OptionSet"
    foreach ($opt in @($meta.OptionSet.Options)) {
        $optionLabel = $opt.Label.UserLocalizedLabel.Label
        if ($optionLabel -eq $Label) {
            return [int]$opt.Value
        }
    }

    throw "Unable to resolve solution component type '$Label'."
}

function Get-MainFormStatus {
    param(
        [string]$EntityLogicalName,
        [string]$TargetFormName
    )

    $safeEntity = $EntityLogicalName.Replace("'", "''")
    $resp = Invoke-Dv -Method 'Get' -Path "systemforms?`$select=formid,name,objecttypecode,type&`$filter=objecttypecode eq '$safeEntity' and type eq 2"
    $forms = @($resp.value)
    if ([string]::IsNullOrWhiteSpace($TargetFormName)) {
        return [pscustomobject]@{ Exists = $forms.Count -gt 0; Match = @($forms | Select-Object -First 1) }
    }

    $match = @($forms | Where-Object { $_.name -eq $TargetFormName } | Select-Object -First 1)
    return [pscustomobject]@{ Exists = $match.Count -gt 0; Match = $match }
}

function Upsert-BpfWorkflow {
    param(
        [object]$Definition,
        [string]$SolutionName,
        [bool]$PreferUpdate
    )

    $processName = ($Definition.BusinessProcessFlowName ?? '').Trim()
    $uniqueName = ConvertTo-WorkflowUniqueName -Value $processName
    $existing = @(Get-ExistingWorkflow -UniqueName $uniqueName)
    if ($existing.Count -eq 0) {
        throw "Supported BPF prerequisite is missing. Create '$processName' in the Power Apps designer with unique name '$uniqueName', add it to solution '$SolutionName', publish it, and rerun. Handoff: $handoffPath"
    }

    $existingProcess = $existing[0]
    if ([int]$existingProcess.category -ne 4) {
        throw "Workflow '$uniqueName' exists but is not a Business Process Flow (category 4). Refusing to modify it."
    }

    $workflowId = $existingProcess.workflowid

    $componentType = Get-ComponentTypeValue -Label 'Process'
    $addBody = [ordered]@{ ComponentId = $workflowId; ComponentType = $componentType; SolutionUniqueName = $SolutionName; AddRequiredComponents = $true } | ConvertTo-Json -Compress
    Invoke-DvWithRetry -Method 'Post' -Path 'AddSolutionComponent' -Body $addBody | Out-Null

    return [ordered]@{ Action = 'validated-existing'; WorkflowId = $workflowId; SolutionAddStatus = 'added'; UniqueName = $uniqueName; MetadataMutation = 'none' }
}

Write-Host ''
Write-Host '=== Build Business Process Flows ===' -ForegroundColor Cyan
Write-Host "  Scenario:    $ScenarioSlug"
Write-Host "  Payloads:    $scenarioPayloadFolder"
Write-Host "  Report path: $reportPath"
Write-Host ''

if (-not $EnableBusinessProcessFlow) {
    $report = New-BpfReport -Status 'skipped' -ProcessName $BusinessProcessFlowName -TargetEntity $PrimaryProcessEntity -StageSummaries @() -Validation ([pscustomobject]@{ Passed = @(); Failed = @(); Warnings = @('EnableBusinessProcessFlow=false') }) -InputsUsed @{ ScenarioSlug = $ScenarioSlug; PayloadFolder = $scenarioPayloadFolder } -DataverseResult @{}
    Write-BpfReportFile -Report $report
    if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $env:DV_PUBLISHER_PREFIX -Kind 'bpf' -Name ($BusinessProcessFlowName ?? 'business-process-flow') -Status 'skipped' -Step '55-build-business-process-flows.ps1' -Details @{ reason = 'disabled' } | Out-Null
    }
    Write-Host 'Business Process Flow generation disabled by parameter. Skipping.' -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path $scenarioPayloadFolder)) {
    $report = New-BpfReport -Status 'skipped' -ProcessName $BusinessProcessFlowName -TargetEntity $PrimaryProcessEntity -StageSummaries @() -Validation ([pscustomobject]@{ Passed = @(); Failed = @(); Warnings = @("Payload folder not found: $scenarioPayloadFolder") }) -InputsUsed @{ ScenarioSlug = $ScenarioSlug; PayloadFolder = $scenarioPayloadFolder } -DataverseResult @{}
    Write-BpfReportFile -Report $report
    if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $env:DV_PUBLISHER_PREFIX -Kind 'bpf' -Name ($BusinessProcessFlowName ?? 'business-process-flow') -Status 'skipped' -Step '55-build-business-process-flows.ps1' -Details @{ reason = 'missing scenario payload folder' } | Out-Null
    }
    Write-Host 'No scenario payload folder found for BPF. Skipping.' -ForegroundColor Yellow
    exit 0
}

if ($processDefinitions.Count -eq 0) {
    $report = New-BpfReport -Status 'skipped' -ProcessName $BusinessProcessFlowName -TargetEntity $PrimaryProcessEntity -StageSummaries @() -Validation ([pscustomobject]@{ Passed = @(); Failed = @(); Warnings = @('No process-*.json definition exists for this scenario. CRUD-only scenarios should skip BPF generation.') }) -InputsUsed @{ ScenarioSlug = $ScenarioSlug; PayloadFolder = $scenarioPayloadFolder } -DataverseResult @{}
    Write-BpfReportFile -Report $report
    if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $env:DV_PUBLISHER_PREFIX -Kind 'bpf' -Name ($BusinessProcessFlowName ?? 'business-process-flow') -Status 'skipped' -Step '55-build-business-process-flows.ps1' -Details @{ reason = 'no process payload' } | Out-Null
    }
    Write-Host 'No process-*.json payload found. Skipping BPF generation.' -ForegroundColor Yellow
    exit 0
}

$definition = $processDefinitions[0]
if (-not [string]::IsNullOrWhiteSpace($BusinessProcessFlowName)) {
    $definition.BusinessProcessFlowName = $BusinessProcessFlowName
}
if (-not [string]::IsNullOrWhiteSpace($PrimaryProcessEntity)) {
    $definition.PrimaryProcessEntity = $PrimaryProcessEntity
}
$definition.Enabled = $EnableBusinessProcessFlow
$definition.FailIfBpfDefinitionIncomplete = $FailIfBpfDefinitionIncomplete
$definition.PreferUpdateExistingBpf = $PreferUpdateExistingBpf

$validation = Test-BpfDefinition -Definition $definition -ArtifactText $artifactText -PayloadFolder $scenarioPayloadFolder
$inputsUsed = @{
    ScenarioSlug = $ScenarioSlug
    PayloadFolder = $scenarioPayloadFolder
    ProcessPayload = $definition.__SourceFile
    PlanningArtifacts = @($artifactPaths.AnswersPath, $artifactPaths.SpecPath, $artifactPaths.PlanPath, $artifactPaths.TasksPath)
    Parameters = @{ EnableBusinessProcessFlow = $EnableBusinessProcessFlow; BusinessProcessFlowName = $BusinessProcessFlowName; PrimaryProcessEntity = $PrimaryProcessEntity; FailIfBpfDefinitionIncomplete = $FailIfBpfDefinitionIncomplete; PreferUpdateExistingBpf = $PreferUpdateExistingBpf; MinimumStageCount = $MinimumStageCount; MinimumConditionCount = $MinimumConditionCount; MinimumStepCount = $MinimumStepCount }
}

if ($validation.Status -eq 'skipped') {
    $report = New-BpfReport -Status 'skipped' -ProcessName $definition.BusinessProcessFlowName -TargetEntity $definition.PrimaryProcessEntity -StageSummaries $validation.StageSummaries -Validation $validation -InputsUsed $inputsUsed -DataverseResult @{}
    Write-BpfReportFile -Report $report
    if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $env:DV_PUBLISHER_PREFIX -Kind 'bpf' -Name $definition.BusinessProcessFlowName -Status 'skipped' -Step '55-build-business-process-flows.ps1' -Details @{ reason = 'scenario does not justify bpf' } | Out-Null
    }
    Write-Host 'Scenario does not justify a Business Process Flow. Skipping.' -ForegroundColor Yellow
    exit 0
}

if ($validation.Status -eq 'failed') {
    $report = New-BpfReport -Status 'failed' -ProcessName $definition.BusinessProcessFlowName -TargetEntity $definition.PrimaryProcessEntity -StageSummaries $validation.StageSummaries -Validation $validation -InputsUsed $inputsUsed -DataverseResult @{}
    Write-BpfReportFile -Report $report
    foreach ($message in $validation.Failed) {
        Write-Host "  VALIDATION FAILED: $message" -ForegroundColor Red
    }
    if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $env:DV_PUBLISHER_PREFIX -Kind 'bpf' -Name $definition.BusinessProcessFlowName -Status 'failed' -Step '55-build-business-process-flows.ps1' -Details @{ validationFailures = @($validation.Failed) } | Out-Null
    }
    if ($FailIfBpfDefinitionIncomplete) {
        if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
            Register-WizardStepFailure -Message 'Business Process Flow validation failed.'
        }
        exit 1
    }

    Write-Host 'Validation failed, but FailIfBpfDefinitionIncomplete=false. Skipping Dataverse changes.' -ForegroundColor Yellow
    exit 0
}

foreach ($message in $validation.Passed) {
    Write-Host "  VALIDATED: $message" -ForegroundColor Green
}

foreach ($message in $validation.Warnings) {
    Write-Host "  WARNING: $message" -ForegroundColor Yellow
}

$thresholdValidation = Test-BpfRuntimeThresholds -StageSummaries $validation.StageSummaries -MinStage $MinimumStageCount -MinCondition $MinimumConditionCount -MinStep $MinimumStepCount
foreach ($message in @($thresholdValidation.Passed)) {
    Write-Host "  VALIDATED: $message" -ForegroundColor Green
}

if (@($thresholdValidation.Failed).Count -gt 0) {
    foreach ($message in @($thresholdValidation.Failed)) {
        Write-Host "  VALIDATION FAILED: $message" -ForegroundColor Red
    }
    $report = New-BpfReport -Status 'failed' -ProcessName $definition.BusinessProcessFlowName -TargetEntity $definition.PrimaryProcessEntity -StageSummaries $validation.StageSummaries -Validation ([pscustomobject]@{ Passed = @($validation.Passed + $thresholdValidation.Passed); Failed = @($validation.Failed + $thresholdValidation.Failed); Warnings = $validation.Warnings }) -InputsUsed $inputsUsed -DataverseResult @{ Thresholds = $thresholdValidation.Thresholds; Metrics = $thresholdValidation.Metrics }
    Write-BpfReportFile -Report $report
    if ($FailIfBpfDefinitionIncomplete) { exit 1 }
    exit 0
}

Write-BpfDesignerHandoff -Definition $definition -Validation $validation
if ($PreviewOnly) {
    $previewResult = @{
        Provisioning = 'designer-handoff-required'
        MetadataMutation = 'none'
        HandoffPath = $handoffPath
        ExpectedUniqueName = ConvertTo-WorkflowUniqueName -Value $definition.BusinessProcessFlowName
        Thresholds = $thresholdValidation.Thresholds
        Metrics = $thresholdValidation.Metrics
    }
    $report = New-BpfReport -Status 'preview' -ProcessName $definition.BusinessProcessFlowName -TargetEntity $definition.PrimaryProcessEntity -StageSummaries $validation.StageSummaries -Validation $validation -InputsUsed $inputsUsed -DataverseResult $previewResult
    Write-BpfReportFile -Report $report
    Write-Host "Preview complete. No Dataverse mutation was attempted. Designer handoff: $handoffPath" -ForegroundColor Green
    exit 0
}

foreach ($required in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName)) {
    if ([string]::IsNullOrWhiteSpace($required)) {
        $report = New-BpfReport -Status 'failed' -ProcessName $definition.BusinessProcessFlowName -TargetEntity $definition.PrimaryProcessEntity -StageSummaries $validation.StageSummaries -Validation ([pscustomobject]@{ Passed = $validation.Passed; Failed = @('Run 10-auth-connect.ps1 first so EnvironmentUrl, AccessToken, and SolutionUniqueName are available.'); Warnings = $validation.Warnings }) -InputsUsed $inputsUsed -DataverseResult @{}
        Write-BpfReportFile -Report $report
        Write-Host 'Run 10-auth-connect.ps1 first.' -ForegroundColor Red
        exit 1
    }
}

$solution = @(Get-Solution -UniqueName $SolutionUniqueName)
if ($solution.Count -eq 0) {
    $report = New-BpfReport -Status 'failed' -ProcessName $definition.BusinessProcessFlowName -TargetEntity $definition.PrimaryProcessEntity -StageSummaries $validation.StageSummaries -Validation ([pscustomobject]@{ Passed = $validation.Passed; Failed = @("Solution '$SolutionUniqueName' not found."); Warnings = $validation.Warnings }) -InputsUsed $inputsUsed -DataverseResult @{}
    Write-BpfReportFile -Report $report
    Write-Host "Solution '$SolutionUniqueName' not found." -ForegroundColor Red
    exit 1
}

$formIntegration = $definition.FormIntegration
$targetFormName = ($formIntegration.TargetFormName ?? '').Trim()
$formStatus = Get-MainFormStatus -EntityLogicalName $definition.PrimaryProcessEntity -TargetFormName $targetFormName
if (-not $formStatus.Exists) {
    Write-Host "  WARNING: Target Main form '$targetFormName' was not found yet for entity '$($definition.PrimaryProcessEntity)'. Script 60 should create or confirm the form next." -ForegroundColor Yellow
}

try {
    $dataverseResult = Upsert-BpfWorkflow -Definition $definition -SolutionName $SolutionUniqueName -PreferUpdate:$PreferUpdateExistingBpf
    $activation = Ensure-WorkflowActivated -WorkflowId $dataverseResult.WorkflowId
    $processComponentType = Get-ComponentTypeValue -Label 'Process'
    $isInSolution = Test-WorkflowInSolution -WorkflowId $dataverseResult.WorkflowId -SolutionId $solution[0].solutionid -ProcessComponentType $processComponentType

    $appLinkage = [ordered]@{ Status = 'not-configured'; AppUniqueName = ''; AppModuleId = ''; Added = $false; ValidationSuccess = $null; Notes = @() }
    if (Get-Command Get-WizardAppModuleConfig -ErrorAction SilentlyContinue) {
        try {
            $appConfig = Get-WizardAppModuleConfig -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $scenarioPayloadFolder -PublisherPrefix $env:DV_PUBLISHER_PREFIX
            if ($appConfig.Enabled -and -not [string]::IsNullOrWhiteSpace(($appConfig.UniqueName ?? ''))) {
                $appLinkage.Status = 'pending-app-module'
                $appLinkage.AppUniqueName = $appConfig.UniqueName
                $app = @(Get-AppModule -UniqueName $appConfig.UniqueName)
                if ($app.Count -gt 0) {
                    $appLinkage.AppModuleId = $app[0].appmoduleid
                    Add-WorkflowToAppModule -AppModuleId $app[0].appmoduleid -WorkflowId $dataverseResult.WorkflowId
                    $appLinkage.Added = $true
                    $appValidation = Invoke-DvWithRetry -Method 'Get' -Path "ValidateApp(AppModuleId=$($app[0].appmoduleid))"
                    if ($null -ne $appValidation -and $null -ne $appValidation.AppValidationResponse) {
                        $appLinkage.ValidationSuccess = $appValidation.AppValidationResponse.ValidationSuccess
                    }
                    $appLinkage.Status = 'linked'
                }
            }
        } catch {
            $appLinkage.Status = 'linkage-check-failed'
            $appLinkage.Notes = @($_.Exception.Message)
        }
    }

    $gateFailures = New-Object System.Collections.Generic.List[string]
    if (-not $activation.Activated) {
        $gateFailures.Add("Workflow '$($definition.BusinessProcessFlowName)' is not active after activation attempt.") | Out-Null
    }
    if (-not $isInSolution) {
        $gateFailures.Add("Workflow '$($definition.BusinessProcessFlowName)' is not present in solution '$SolutionUniqueName'.") | Out-Null
    }

    $branchPredicates = Get-BranchPredicateSummary -StageSummaries $validation.StageSummaries
    $dataverseResult = [ordered]@{
        Action = $dataverseResult.Action
        WorkflowId = $dataverseResult.WorkflowId
        UniqueName = $dataverseResult.UniqueName
        SolutionAddStatus = $dataverseResult.SolutionAddStatus
        Activation = $activation
        SolutionMembership = [ordered]@{ InSolution = $isInSolution; SolutionUniqueName = $SolutionUniqueName; ComponentType = 29 }
        Thresholds = $thresholdValidation.Thresholds
        Metrics = $thresholdValidation.Metrics
        BranchPredicateSummary = $branchPredicates
        AppLinkage = $appLinkage
        RuntimeNotes = @($runtimeNotes)
        Provisioning = 'designer-authored-existing-process'
        MetadataMutation = $dataverseResult.MetadataMutation
        HandoffPath = $handoffPath
    }

    $effectiveValidation = [pscustomobject]@{
        Passed = @($validation.Passed + $thresholdValidation.Passed)
        Failed = if ($gateFailures.Count -gt 0) { @($validation.Failed + $thresholdValidation.Failed + $gateFailures.ToArray()) } else { @($validation.Failed + $thresholdValidation.Failed) }
        Warnings = $validation.Warnings
    }

    $status = if ($gateFailures.Count -gt 0) { 'failed' } else { $dataverseResult.Action }
    $report = New-BpfReport -Status $status -ProcessName $definition.BusinessProcessFlowName -TargetEntity $definition.PrimaryProcessEntity -StageSummaries $validation.StageSummaries -Validation $effectiveValidation -InputsUsed $inputsUsed -DataverseResult $dataverseResult
    Write-BpfReportFile -Report $report
    if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $env:DV_PUBLISHER_PREFIX -Kind 'bpf' -Name $definition.BusinessProcessFlowName -Status $status -Step '55-build-business-process-flows.ps1' -Details @{ workflowId = $dataverseResult.WorkflowId; solutionAddStatus = $dataverseResult.SolutionAddStatus; activated = $activation.Activated; inSolution = $isInSolution } | Out-Null
    }

    Write-Host ''
    Write-Host 'BPF build summary:' -ForegroundColor Cyan
    Write-Host "  Process name:        $($definition.BusinessProcessFlowName)"
    Write-Host "  Target entity:       $($definition.PrimaryProcessEntity)"
    Write-Host "  Stage count:         $($validation.StageSummaries.Count)"
    Write-Host "  Condition count:     $($thresholdValidation.Metrics.ConditionCount)"
    Write-Host "  Step count:          $($thresholdValidation.Metrics.StepCount)"
    Write-Host "  Solution add status: $($dataverseResult.SolutionAddStatus)"
    Write-Host "  Active state:        $($activation.Activated)"
    Write-Host "  In solution:         $isInSolution"
    Write-Host "  App linkage status:  $($appLinkage.Status)"
    foreach ($stage in @($validation.StageSummaries | Sort-Object Order)) {
        Write-Host "  - Stage $($stage.Order): $($stage.StageName) [$($stage.EntityLogicalName)] -> $($stage.RequiredFields -join ', ')"
    }
    Write-Host "  Report:              $reportPath"

    if ($gateFailures.Count -gt 0) {
        foreach ($message in @($gateFailures.ToArray())) {
            Write-Host "  GATE FAILED: $message" -ForegroundColor Red
        }
        if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
            Register-WizardStepFailure -Message 'Business Process Flow post-build gates failed.'
        }
        exit 1
    }

    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message 'Business Process Flow build completed.'
    }
} catch {
    $message = $_.Exception.Message
    $report = New-BpfReport -Status 'failed' -ProcessName $definition.BusinessProcessFlowName -TargetEntity $definition.PrimaryProcessEntity -StageSummaries $validation.StageSummaries -Validation ([pscustomobject]@{ Passed = $validation.Passed; Failed = @($message); Warnings = $validation.Warnings }) -InputsUsed $inputsUsed -DataverseResult @{}
    Write-BpfReportFile -Report $report
    if (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue) {
        Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $env:DV_PUBLISHER_PREFIX -Kind 'bpf' -Name $definition.BusinessProcessFlowName -Status 'failed' -Step '55-build-business-process-flows.ps1' -Details @{ error = $message } | Out-Null
    }
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Business Process Flow build failed: $message"
    }
    throw
}

function Get-WorkflowDetails {
    param([string]$WorkflowId)

    return Invoke-DvWithRetry -Method 'Get' -Path "workflows($WorkflowId)?`$select=workflowid,name,uniquename,category,statecode,statuscode,clientdata,uidata"
}

function Ensure-WorkflowActivated {
    param([string]$WorkflowId)

    $before = Get-WorkflowDetails -WorkflowId $WorkflowId
    if (($before.statecode ?? -1) -eq 1) {
        return [pscustomobject]@{ Activated = $true; StateCode = $before.statecode; StatusCode = $before.statuscode; Action = 'already-active' }
    }

    $body = @{ EntityId = $WorkflowId } | ConvertTo-Json -Compress
    Invoke-DvWithRetry -Method 'Post' -Path 'Microsoft.Dynamics.CRM.ActivateWorkflow' -Body $body | Out-Null

    $after = Get-WorkflowDetails -WorkflowId $WorkflowId
    return [pscustomobject]@{ Activated = (($after.statecode ?? -1) -eq 1); StateCode = $after.statecode; StatusCode = $after.statuscode; Action = 'activate-attempted' }
}

function Test-WorkflowInSolution {
    param(
        [string]$WorkflowId,
        [string]$SolutionId,
        [int]$ProcessComponentType
    )

    $resp = Invoke-DvWithRetry -Method 'Get' -Path "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq guid'$SolutionId' and objectid eq guid'$WorkflowId' and componenttype eq $ProcessComponentType"
    return @($resp.value).Count -gt 0
}

function Get-AppModule {
    param([string]$UniqueName)

    $safe = $UniqueName.Replace("'", "''")
    $resp = Invoke-DvWithRetry -Method 'Get' -Path "appmodules?`$select=appmoduleid,name,uniquename&`$filter=uniquename eq '$safe'"
    return @($resp.value | Select-Object -First 1)
}

function Add-WorkflowToAppModule {
    param(
        [string]$AppModuleId,
        [string]$WorkflowId
    )

    $component = [ordered]@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.workflow'
        workflowid = $WorkflowId
    }

    $body = @{ AppId = $AppModuleId; Components = @($component) } | ConvertTo-Json -Depth 10 -Compress
    Invoke-DvWithRetry -Method 'Post' -Path 'AddAppComponents' -Body $body | Out-Null
}
