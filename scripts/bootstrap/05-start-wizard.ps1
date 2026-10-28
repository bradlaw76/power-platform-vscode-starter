<#
=============================================================================
COMPONENT:    Start Wizard
FILE:         scripts/bootstrap/05-start-wizard.ps1
VERSION:      0.10.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-27
ENVIRONMENT:  PowerShell 7 | VS Code | Power Platform Planning Workflow

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Runs the interactive discovery wizard that captures scenario answers and
scaffolds scenario-level planning artifacts before any build scripts run.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          user discovery answers and scenario slug information
- Outputs:         answers.md, spec.md, plan.md, and tasks.md artifacts
- Dependencies:    repo planning conventions and helper telemetry script
- Side Effects:    writes planning files under specs/<scenario-slug>

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Run after the user is ready to answer discovery questions.
2. Use the repo's planning-first workflow from docs/onboarding.md.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ New scenarios produce planning artifacts in the expected folder.
✔ Retrofit scenarios capture current state before remaining work.
✔ Source-control intake is read-only and persists scenario lifecycle decisions.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.
v0.2.0  2026-08-09  Added profile-driven source-control preflight and planning.
v0.3.0  2026-08-10  Added standalone model-driven app architecture intake.
v0.4.0  2026-08-18  Added report scoping, mapping artifact, and critical-table gate.
v0.5.0  2026-08-18  Added entry-table resolution and landing-view action planning.
v0.6.0  2026-08-26  Added Demo, Advanced, and Framework Acceptance modes.
v0.7.0  2026-08-28  Added safe generated Active-view disposition planning.
v0.8.0  2026-10-15  Added default-off accelerator architecture recommendations.
v0.9.0  2026-10-16  Added startup preference and FAST-005A acceptance corrections.
v0.10.0 2026-10-27  Added local-first startup update advice and opt-in fetch.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Do not bypass the planning gate before implementation scripts.
- Keep discovery outputs aligned with repo docs and prompts.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Runs an interactive repository wizard for a new Power Platform or Dynamics
    365 demo/app idea and scaffolds Spec Kit starter files.

.DESCRIPTION
    Prompts the user with discovery questions, captures answers, and writes
    starter `spec.md`, `plan.md`, `tasks.md`, and `answers.md` files to a
    scenario folder under `specs/<scenario-slug>/`.

    If generated files already exist for the chosen scenario, the script prompts
    before overwriting unless -Force is used.

    Use -Retrofit when the user already has a partial implementation. The script
    will ask for current state (what is already built) and use that as the basis
    for `spec.md`, with `plan.md` capturing only the remaining work.

    This script does not authenticate or create Dataverse artifacts. It is the
    planning step that should happen before `10-auth-connect.ps1` and scripts
    `20`-`60` when starting a new idea.

.PARAMETER Force
    Overwrite existing generated files without prompting.

.PARAMETER Retrofit
    Use mid-project retrofit mode. Asks for current state instead of greenfield
    discovery, and generates spec.md reflecting what exists plus plan.md for
    remaining work.

.PARAMETER Mode
    Selects discovery depth. Demo Builder is the seven-prompt default. Advanced
    Builder exposes technical controls. Framework Acceptance adds explicit
    environment safety, isolation, rerun, retention, cleanup, and evidence
    controls.

.PARAMETER AnswersFile
    Optional JSON file containing an ordered array of answers for unattended
    acceptance testing.

.PARAMETER WorkspaceRoot
    Optional repository root used for isolated acceptance testing. Defaults to
    the repository containing this script.

.PARAMETER FetchRepositoryUpdates
    Explicitly fetch the configured upstream into an isolated update-check ref.
    The default startup comparison uses cached local Git metadata only.

.PARAMETER SkipRepositoryUpdateCheck
    Skip the startup advisor. Cannot be combined with FetchRepositoryUpdates.

.EXAMPLE
    pwsh ./scripts/bootstrap/05-start-wizard.ps1

.EXAMPLE
    pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Force

.EXAMPLE
    pwsh ./scripts/bootstrap/05-start-wizard.ps1 -Mode advanced-builder -Retrofit
#>

param(
    [switch]$Force,
    [switch]$Retrofit,
    [ValidateSet('demo-builder', 'advanced-builder', 'framework-acceptance')]
    [string]$Mode = 'demo-builder',
    [string]$AnswersFile,
    [string]$WorkspaceRoot,
    [switch]$FetchRepositoryUpdates,
    [switch]$SkipRepositoryUpdateCheck,
    [switch]$EnableAcceleratorRecommendations,
    [ValidateSet('', 'evaluate', 'fully-custom', 'prefer-fast')]
    [string]$AcceleratorPreference = '',
    [string]$AcceleratorCatalogSnapshotPath = '',
    [string[]]$AcceleratorPackageMetadataPaths = @(),
    [string]$AcceleratorPackageManifestPath = '',
    [string]$AcceleratorEnvironmentValidationPath = '',
    [ValidateSet('', 'fast-based', 'hybrid', 'fully-custom')]
    [string]$AcceleratorArchitectureChoice = '',
    [string]$AcceleratorDecisionRationale = '',
    [switch]$ApproveAcceleratorDecisionChange,
    [datetime]$AcceleratorEvaluationTimeUtc = [DateTime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$implementationRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$repoRoot = if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
    $implementationRoot
} else {
    [System.IO.Path]::GetFullPath($WorkspaceRoot)
}
if ($FetchRepositoryUpdates -and $SkipRepositoryUpdateCheck) {
    throw 'FetchRepositoryUpdates cannot be combined with SkipRepositoryUpdateCheck.'
}
if (-not $SkipRepositoryUpdateCheck) {
    . (Join-Path $PSScriptRoot 'helpers\repository-updates.ps1')
    try {
        $updateReport = Get-WizardRepositoryUpdateReport -RepoRoot $repoRoot -Fetch:$FetchRepositoryUpdates
        Show-WizardRepositoryUpdateReport $updateReport
    } catch {
        Write-Warning "Repository update advisor unavailable: $($_.Exception.Message)"
    }
}
$acceleratorIntegrationPath = Join-Path $PSScriptRoot '..\accelerators\wizard-accelerator-integration.ps1'
. $acceleratorIntegrationPath
$acceleratorRecommendationsEnabled = Test-WizardAcceleratorRecommendationsEnabled `
    -ExplicitEnable:$EnableAcceleratorRecommendations
$scriptedAnswers = $null
$scriptedAnswerIndex = 0
if (-not [string]::IsNullOrWhiteSpace($AnswersFile)) {
    if (-not (Test-Path -LiteralPath $AnswersFile -PathType Leaf)) {
        throw "Answers file not found: $AnswersFile"
    }

    $loadedAnswers = @(Get-Content -LiteralPath $AnswersFile -Raw -Encoding UTF8 | ConvertFrom-Json)
    $scriptedAnswers = @($loadedAnswers | ForEach-Object { [string]$_ })
}
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "05-start-wizard.ps1"
}

function Read-WizardInput {
    param([string]$Prompt)

    if ($null -eq $scriptedAnswers) {
        return Read-Host $Prompt
    }

    if ($scriptedAnswerIndex -ge $scriptedAnswers.Count) {
        throw "Scripted answers exhausted at prompt: $Prompt"
    }

    $value = $scriptedAnswers[$scriptedAnswerIndex]
    $script:scriptedAnswerIndex++
    return $value
}

function Read-RequiredValue {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    while ($true) {
        $value = if ([string]::IsNullOrWhiteSpace($Default)) {
            Read-WizardInput $Prompt
        }
        else {
            Read-WizardInput "$Prompt [$Default]"
        }

        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = $Default
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        Write-Host "A value is required." -ForegroundColor Yellow
    }
}

function Read-ChoiceValue {
    param(
        [string]$Prompt,
        [string[]]$AllowedValues,
        [string]$Default = ''
    )

    while ($true) {
        $value = (Read-RequiredValue -Prompt $Prompt -Default $Default).ToLowerInvariant()
        if ($AllowedValues -contains $value) {
            return $value
        }

        function Read-AcceleratorPreferenceValue {
            while ($true) {
                $value = (Read-RequiredValue `
                    -Prompt 'Accelerator preference (A=evaluate, B=fully-custom, C=prefer-fast)' `
                    -Default 'A').Trim().ToLowerInvariant()
                switch ($value) {
                    { $_ -in @('a', 'evaluate') } { return 'evaluate' }
                    { $_ -in @('b', 'fully-custom') } { return 'fully-custom' }
                    { $_ -in @('c', 'prefer-fast') } { return 'prefer-fast' }
                    default { Write-Host 'Enter A, B, C, evaluate, fully-custom, or prefer-fast.' -ForegroundColor Yellow }
                }
            }
        }

        Write-Host "Choose one of: $($AllowedValues -join ', ')." -ForegroundColor Yellow
    }
}

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = [regex]::Replace($slug, "[^a-z0-9]+", "-")
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "new-scenario"
    }
    return $slug
}

function Get-SourceControlPreflight {
    param([string]$RepositoryRoot)

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        return [ordered]@{ Available = $false }
    }

    $topLevel = (& git -C $RepositoryRoot rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return [ordered]@{ Available = $false }
    }

    $branch = ((& git -C $RepositoryRoot branch --show-current 2>$null) -join "`n").Trim()
    $remote = ((& git -C $RepositoryRoot remote get-url origin 2>$null) -join "`n").Trim()
    $status = @(& git -C $RepositoryRoot status --short 2>$null)
    $recentCommit = ((& git -C $RepositoryRoot log -1 --oneline 2>$null) -join "`n").Trim()
    $defaultBranchRef = ((& git -C $RepositoryRoot symbolic-ref refs/remotes/origin/HEAD 2>$null) -join "`n").Trim()
    $defaultBranch = if ($defaultBranchRef -match '^refs/remotes/origin/(.+)$') { $Matches[1] } else { "unknown" }

    return [ordered]@{
        Available     = $true
        TopLevel      = (($topLevel -join "`n").Trim())
        Branch        = $branch
        DefaultBranch = $defaultBranch
        Remote        = $remote
        Dirty         = ($status.Count -gt 0)
        ChangedCount  = $status.Count
        RecentCommit  = $recentCommit
    }
}

function Resolve-StandardLogicalName {
    param([string]$Name)

    $key = ($Name ?? "").Trim().ToLower()
    $map = @{
        "account"     = "account"
        "activity"    = "activitypointer"
        "case"        = "incident"
        "contact"     = "contact"
        "incident"    = "incident"
        "lead"        = "lead"
        "opportunity" = "opportunity"
        "product"     = "product"
        "task"        = "task"
    }

    if ($map.ContainsKey($key)) { return $map[$key] }
    return $key
}

function Convert-ToCustomLogicalName {
    param(
        [string]$Name,
        [string]$Prefix
    )

    $normalizedPrefix = ($Prefix ?? "").Trim().ToLower()
    $candidate = ($Name ?? "").Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($candidate)) { return "" }

    if ($candidate.Contains("_")) { return $candidate }
    $candidate = [regex]::Replace($candidate, "[^a-z0-9]+", "")
    if ([string]::IsNullOrWhiteSpace($candidate)) { return "" }

    if ([string]::IsNullOrWhiteSpace($normalizedPrefix)) { return $candidate }
    return "$normalizedPrefix`_$candidate"
}

function Format-StandardTableMapping {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Trim().ToLower() -eq "none") {
        return "- None"
    }

    $lines = @()
    $items = @($Value -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($item in $items) {
        $logical = Resolve-StandardLogicalName $item
        $lines += "- $item -> $logical"
    }

    if ($lines.Count -eq 0) { return "- None" }
    return ($lines -join "`n")
}

function Format-CustomTableMapping {
    param(
        [string]$Value,
        [string]$Prefix
    )

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Trim().ToLower() -eq "none") {
        return "- None"
    }

    $lines = @()
    $items = @($Value -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    foreach ($item in $items) {
        $logical = Convert-ToCustomLogicalName -Name $item -Prefix $Prefix
        if (-not [string]::IsNullOrWhiteSpace($logical)) {
            $lines += "- $item -> $logical"
        }
    }

    if ($lines.Count -eq 0) { return "- None" }
    return ($lines -join "`n")
}

function Get-PlannedTableLogicalNames {
    param(
        [string]$StandardTables,
        [string]$CustomTables,
        [string]$PublisherPrefix,
        [string]$ExistingTables = ""
    )

    $logicalNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($table in @(Split-ListValues -Value $StandardTables)) {
        if ($table.ToLowerInvariant() -ne 'none') {
            $logicalNames.Add((Resolve-StandardLogicalName -Name $table)) | Out-Null
        }
    }
    foreach ($table in @(Split-ListValues -Value $CustomTables)) {
        if ($table.ToLowerInvariant() -ne 'none') {
            $logicalNames.Add((Convert-ToCustomLogicalName -Name $table -Prefix $PublisherPrefix)) | Out-Null
        }
    }
    foreach ($table in @(Split-ListValues -Value $ExistingTables)) {
        if ($table.ToLowerInvariant() -eq 'none') { continue }

        $normalized = $table.Trim().ToLowerInvariant()
        $logicalNames.Add($normalized) | Out-Null
        $logicalNames.Add((Resolve-StandardLogicalName -Name $table)) | Out-Null
        $logicalNames.Add((Convert-ToCustomLogicalName -Name $table -Prefix $PublisherPrefix)) | Out-Null
    }

    return @($logicalNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object)
}

function Get-PredictablePluralDisplayName {
    param([string]$DisplayName)

    $name = ($DisplayName ?? '').Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    $words = @($name -split '\s+')
    $noun = $words[-1]
    if ($noun -notmatch '^[A-Za-z]+$') { return $null }

    $pluralNoun = if ($noun -match '(?i)[^aeiou]y$') {
        $noun.Substring(0, $noun.Length - 1) + 'ies'
    } elseif ($noun -match '(?i)(s|x|z|ch|sh)$') {
        $noun + 'es'
    } else {
        $noun + 's'
    }
    $words[-1] = $pluralNoun
    return ($words -join ' ')
}

function Get-PlannedCustomTableDisplayName {
    param(
        [string]$TableLogicalName,
        [string]$CustomTables,
        [string]$PublisherPrefix
    )

    $matches = @(Split-ListValues -Value $CustomTables | Where-Object {
        (Convert-ToCustomLogicalName -Name $_ -Prefix $PublisherPrefix) -ieq $TableLogicalName
    })
    if ($matches.Count -ne 1) { return $null }
    return $matches[0]
}

function Resolve-PlannedViewDisposition {
    param(
        [string]$TableLogicalName,
        [string]$ViewName,
        [string]$CustomTables,
        [string]$StandardTables,
        [string]$PublisherPrefix,
        [bool]$RetrofitMode
    )

    if ($RetrofitMode) {
        return [pscustomobject]@{ Disposition = 'explicit-decision-required'; Reason = 'retrofit table ownership requires an explicit decision' }
    }

    $customDisplayName = Get-PlannedCustomTableDisplayName -TableLogicalName $TableLogicalName -CustomTables $CustomTables -PublisherPrefix $PublisherPrefix
    $standardLogicalNames = @(Get-PlannedTableLogicalNames -StandardTables $StandardTables -CustomTables 'none' -PublisherPrefix $PublisherPrefix)
    if ($standardLogicalNames -contains $TableLogicalName -or [string]::IsNullOrWhiteSpace($customDisplayName)) {
        return [pscustomobject]@{ Disposition = 'explicit-decision-required'; Reason = 'table is standard, shared, preexisting, hybrid-standard, or not uniquely planned as new custom' }
    }

    $pluralDisplayName = Get-PredictablePluralDisplayName -DisplayName $customDisplayName
    if ([string]::IsNullOrWhiteSpace($pluralDisplayName)) {
        return [pscustomobject]@{ Disposition = 'explicit-decision-required'; Reason = 'generated plural table display name cannot be predicted safely' }
    }

    $generatedActiveViewName = "Active $pluralDisplayName"
    if ($ViewName -ceq $generatedActiveViewName) {
        return [pscustomobject]@{ Disposition = 'adopt-generated-active'; Reason = 'exact predictable generated Active-view name on a newly planned custom table' }
    }

    return [pscustomobject]@{ Disposition = 'create-custom'; Reason = "business view name is distinct from '$generatedActiveViewName'" }
}

function Test-AndSetEntryPointPlan {
    param(
        [System.Collections.IDictionary]$Answers,
        [bool]$RetrofitMode
    )

    $existingTables = if ($RetrofitMode) { $Answers["DataEntities"] } else { "" }
    $plannedTables = @(Get-PlannedTableLogicalNames -StandardTables $Answers["StandardTablesReused"] -CustomTables $Answers["CustomTablesToCreate"] -PublisherPrefix $Answers["PublisherPrefix"] -ExistingTables $existingTables)
    $entryPoint = $Answers["EntryPointTable"].Trim().ToLowerInvariant()
    if ($plannedTables -notcontains $entryPoint) {
        $plannedText = if ($plannedTables.Count -gt 0) { $plannedTables -join ', ' } else { 'none' }
        throw "Entry-point table '$entryPoint' is not present in the explicit table plan. Planned logical names: $plannedText"
    }

    $Answers["EntryPointTable"] = $entryPoint
    $viewPlan = Resolve-PlannedViewDisposition -TableLogicalName $entryPoint -ViewName $Answers["EntryPointLandingView"] -CustomTables $Answers["CustomTablesToCreate"] -StandardTables $Answers["StandardTablesReused"] -PublisherPrefix $Answers["PublisherPrefix"] -RetrofitMode $RetrofitMode
    $Answers["EntryPointLandingViewPlan"] = $viewPlan.Disposition
    $Answers["EntryPointLandingViewPlanReason"] = $viewPlan.Reason
    $Answers["EntryPointValidationStatus"] = "approved"
}

function Confirm-Overwrite {
    param([string[]]$Paths)

    Write-Host "" 
    Write-Host "The following files already exist and would be overwritten:" -ForegroundColor Yellow
    $Paths | ForEach-Object { Write-Host "  $_" }
    Write-Host "" 
    $answer = Read-WizardInput "Overwrite these files? (y/N)"
    return $answer -match '^(y|yes)$'
}

function Read-BooleanChoice {
    param(
        [string]$Prompt,
        [bool]$Default = $false
    )

    $defaultText = if ($Default) { "yes" } else { "no" }
    while ($true) {
        $value = Read-WizardInput "$Prompt [$defaultText]"
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $Default
        }

        switch ($value.Trim().ToLowerInvariant()) {
            'y' { return $true }
            'yes' { return $true }
            'true' { return $true }
            '1' { return $true }
            'n' { return $false }
            'no' { return $false }
            'false' { return $false }
            '0' { return $false }
        }

        Write-Host "Enter yes or no." -ForegroundColor Yellow
    }
}

function Read-PositiveInt {
    param(
        [string]$Prompt,
        [int]$Minimum = 1,
        [int]$Default = 1
    )

    while ($true) {
        $value = Read-WizardInput "$Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $Default
        }

        $parsed = 0
        if ([int]::TryParse($value.Trim(), [ref]$parsed) -and $parsed -ge $Minimum) {
            return $parsed
        }

        Write-Host "Enter a whole number greater than or equal to $Minimum." -ForegroundColor Yellow
    }
}

function Split-ListValues {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return @($Value -split '[,;\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Format-BulletList {
    param(
        [string]$Value,
        [string]$NoneValue = "- None"
    )

    $items = @(Split-ListValues -Value $Value)
    if ($items.Count -eq 0 -or ($items.Count -eq 1 -and $items[0].ToLowerInvariant() -eq 'none')) {
        return $NoneValue
    }

    return (($items | ForEach-Object { "- $_" }) -join "`n")
}

function Remove-MarkdownTrailingWhitespace {
    param([Parameter(Mandatory)] [string]$Value)

    $withoutTrailingWhitespace = [regex]::Replace(
        $Value,
        '[ \t]+(?=\r?$)',
        '',
        [Text.RegularExpressions.RegexOptions]::Multiline
    )
    return ($withoutTrailingWhitespace -replace "\r\n?", "`n")
}

function ConvertTo-ReportMappingRows {
    param([string]$Value)

    $rows = @()
    foreach ($entry in @($Value -split ';')) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }

        $parts = @($entry -split '\|' | ForEach-Object { $_.Trim() })
        if ($parts.Count -ne 8 -or @($parts | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
            throw "Each report mapping must contain 8 non-empty values: table | surface name | form/dashboard/view | target placement | required fields | decision supported | owner | validation checklist. Invalid entry: $entry"
        }

        $reportType = $parts[2].ToLowerInvariant()
        if (@('form', 'dashboard', 'view') -notcontains $reportType) {
            throw "Report type must be form, dashboard, or view. Invalid entry: $entry"
        }

        $rows += [pscustomobject]@{
            TableLogicalName   = $parts[0]
            SurfaceName        = $parts[1]
            ReportType         = $reportType
            TargetPlacement    = $parts[3]
            RequiredFields     = $parts[4]
            DecisionSupported  = $parts[5]
            Owner              = $parts[6]
            Validation         = $parts[7]
        }
    }

    if ($rows.Count -eq 0) {
        throw 'At least one report mapping is required when reports are enabled.'
    }

    return @($rows)
}

function Format-ReportMappingTable {
    param([array]$Rows)

    $lines = @(
        '| Table logical name | Report surface | Type | Target placement | Required fields | Business decision | Owner | Validation checklist |',
        '| --- | --- | --- | --- | --- | --- | --- | --- |'
    )
    foreach ($row in $Rows) {
        $values = @(
            $row.TableLogicalName,
            $row.SurfaceName,
            $row.ReportType,
            $row.TargetPlacement,
            $row.RequiredFields,
            $row.DecisionSupported,
            $row.Owner,
            $row.Validation
        ) | ForEach-Object { "$_" -replace '\|', '\|' }
        $lines += "| $($values -join ' | ') |"
    }

    return $lines -join "`n"
}

function Format-BpfStageBullets {
    param([array]$Stages)

    if ($null -eq $Stages -or $Stages.Count -eq 0) {
        return "- None"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($stage in @($Stages | Sort-Object Order)) {
        $requiredFields = if ($stage.RequiredFields.Count -gt 0) { $stage.RequiredFields -join ', ' } else { 'None' }
        $relationship = if ([string]::IsNullOrWhiteSpace($stage.RelationshipLogicalName)) { 'None' } else { $stage.RelationshipLogicalName }
        $lines.Add("- Stage $($stage.Order): $($stage.StageName) [entity=$($stage.EntityLogicalName); fields=$requiredFields; relationship=$relationship]") | Out-Null
        $lines.Add("  - Entry criteria: $($stage.EntryCriteria)") | Out-Null
        $lines.Add("  - Exit criteria: $($stage.ExitCriteria)") | Out-Null
    }

    return ($lines -join "`n")
}

function Read-BpfDiscovery {
    param(
        [string]$ScenarioName,
        [string]$ScenarioSlug
    )

    $enabled = Read-BooleanChoice -Prompt "E-bpf. Does this scenario need a Business Process Flow?" -Default:$false
    if (-not $enabled) {
        return [ordered]@{
            Enabled                      = $false
            BusinessProcessFlowName      = ""
            PrimaryProcessEntity         = ""
            FailIfBpfDefinitionIncomplete = $true
            PreferUpdateExistingBpf      = $true
            CrossTableProgression        = $false
            TargetFormName               = ""
            StageDefinitions             = @()
        }
    }

    Write-Host ""
    Write-Host "Business Process Flow discovery (only for scenarios with a real staged lifecycle)." -ForegroundColor Cyan

    $processName = Read-RequiredValue "    BPF display name" "$ScenarioName Process"
    $primaryEntity = Read-RequiredValue "    Primary entity / process root logical name (for example: incident)"
    $targetFormName = Read-RequiredValue "    Target Main form name for the process (for example: Information or Starter Main Form)"
    $failIfIncomplete = Read-BooleanChoice -Prompt "    Fail the build if the BPF definition is incomplete?" -Default:$true
    $preferUpdate = Read-BooleanChoice -Prompt "    Prefer update over duplicate create when a wizard-managed BPF already exists?" -Default:$true
    $crossTable = Read-BooleanChoice -Prompt "    Does the process require cross-table progression?" -Default:$false
    $stageCount = Read-PositiveInt -Prompt "    Number of BPF stages" -Minimum 2 -Default 4

    $stages = New-Object System.Collections.Generic.List[object]
    for ($index = 1; $index -le $stageCount; $index++) {
        Write-Host ""
        Write-Host "    Stage $index" -ForegroundColor Cyan
        $stageName = Read-RequiredValue "      Stage name"
        $defaultEntity = if ($index -eq 1) { $primaryEntity } else { $primaryEntity }
        $stageEntity = Read-RequiredValue "      Stage entity logical name" $defaultEntity
        $requiredFields = Split-ListValues (Read-RequiredValue "      Required fields for this stage (comma-separated logical names)")
        $entryCriteria = Read-RequiredValue "      Stage entry criteria"
        $exitCriteria = Read-RequiredValue "      Stage exit criteria"
        $relationshipLogicalName = ""
        if ($crossTable -or $stageEntity.Trim().ToLowerInvariant() -ne $primaryEntity.Trim().ToLowerInvariant()) {
            $relationshipLogicalName = Read-RequiredValue "      Supporting relationship logical name (required for cross-table stages)"
        }

        $stages.Add([pscustomobject]@{
            Order                  = $index
            StageName              = $stageName
            EntityLogicalName      = $stageEntity.Trim().ToLowerInvariant()
            RequiredFields         = @($requiredFields | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
            EntryCriteria          = $entryCriteria
            ExitCriteria           = $exitCriteria
            RelationshipLogicalName = $relationshipLogicalName.Trim().ToLowerInvariant()
        }) | Out-Null
    }

    return [ordered]@{
        Enabled                       = $true
        BusinessProcessFlowName       = $processName
        PrimaryProcessEntity          = $primaryEntity.Trim().ToLowerInvariant()
        FailIfBpfDefinitionIncomplete = $failIfIncomplete
        PreferUpdateExistingBpf       = $preferUpdate
        CrossTableProgression         = $crossTable
        TargetFormName                = $targetFormName
        StageDefinitions              = @($stages)
    }
}

$profilePath = Join-Path $repoRoot "wizard.profile.json"
$contractPath = Join-Path $repoRoot "docs\wizard-contract-v1.md"
$onboardingPath = Join-Path $repoRoot "docs\onboarding.md"
$payloadPath = Join-Path $repoRoot "payloads"
$reportsModuleEnabled = $true
$bpfModuleEnabled = $true
$sourceControlModuleEnabled = $true
$sourceControlBranchPattern = "feature/<scenario-slug>"

if (Test-Path $profilePath) {
    try {
        $profile = Get-Content -Path $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $profile.execution.optionalModules."web-resources") {
            $reportsModuleEnabled = [bool]$profile.execution.optionalModules."web-resources".enabled
        }
        if ($null -ne $profile.discovery.optionalQuestionModules."business-process-flow") {
            $bpfModuleEnabled = [bool]$profile.discovery.optionalQuestionModules."business-process-flow"
        }
        if ($null -ne $profile.discovery.optionalQuestionModules."source-control") {
            $sourceControlModuleEnabled = [bool]$profile.discovery.optionalQuestionModules."source-control"
        }
        if ($null -ne $profile.sourceControl.branchPattern) {
            $sourceControlBranchPattern = [string]$profile.sourceControl.branchPattern
        }
    } catch {
        Write-Host "Failed to parse wizard.profile.json. Fix profile JSON before running the wizard." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Warning: wizard.profile.json not found. Using default behavior." -ForegroundColor Yellow
}

foreach ($requiredPath in @($contractPath, $onboardingPath, $payloadPath)) {
    if (-not (Test-Path $requiredPath)) {
        Write-Host "Missing required contract path: $requiredPath" -ForegroundColor Red
        Write-Host "Run startup validation and restore missing folders/files before continuing." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "" 
Write-Host "=== Power Platform Demo Wizard ===" -ForegroundColor Cyan
Write-Host "Mode: $Mode" -ForegroundColor Cyan

if ($Retrofit) {
    Write-Host "RETROFIT MODE: Reverse-engineering spec from an existing/in-progress project." -ForegroundColor Yellow
    Write-Host "spec.md will capture current state. plan.md will capture remaining work."
} else {
    Write-Host "This wizard captures discovery answers and scaffolds Spec Kit starter files."
    Write-Host "Run this before authentication or build scripts when starting a new idea."
}

Write-Host ""

$selectedAcceleratorPreference = 'disabled'
if ($acceleratorRecommendationsEnabled) {
    Show-WizardAcceleratorPreferenceOptions
    $selectedAcceleratorPreference = if (-not [string]::IsNullOrWhiteSpace($AcceleratorPreference)) {
        $AcceleratorPreference
    } elseif ($null -ne $scriptedAnswers) {
        'evaluate'
    } else {
        Read-AcceleratorPreferenceValue
    }
    Write-Host "Selected accelerator preference: $selectedAcceleratorPreference" -ForegroundColor Cyan
}
$acceleratorMatchingRequested = $acceleratorRecommendationsEnabled -and
    $selectedAcceleratorPreference -ne 'fully-custom'

if ($Mode -eq 'demo-builder') {
    $answers = [ordered]@{}
    $answers["WizardMode"] = $Mode

    Write-Host "Demo Builder asks six business questions plus one consolidated recommendation confirmation, then generates the shared planning artifacts." -ForegroundColor Cyan
    $scenarioName = Read-RequiredValue "1. Describe the app idea and business outcome"
    $scenarioSlug = ConvertTo-Slug $scenarioName
    $primaryUserTask = Read-RequiredValue "2. Who is the primary user, and what is their top task?"
    $dataToTrack = Read-RequiredValue "3. What business records or data should the app track? (comma-separated)"
    $experienceAndLifecycle = Read-RequiredValue "4. What should users see or do, including any lifecycle stages?"
    $successAndData = Read-RequiredValue "5. What makes the demo successful, and should it include synthetic sample data?"
    $environmentAndOutput = Read-RequiredValue "6. What Environment URL and solution output do you expect? (for example, https://your-org.crm.dynamics.com; unmanaged solution)" "Environment URL; unmanaged solution"

    $publisherPrefix = ([regex]::Replace($scenarioSlug, '[^a-z]', '') + 'app').Substring(0, [Math]::Min(5, ([regex]::Replace($scenarioSlug, '[^a-z]', '') + 'app').Length))
    $customTables = @(Split-ListValues -Value $dataToTrack)
    $entryPointDisplayName = if ($customTables.Count -gt 0) { $customTables[0] } else { $scenarioName }
    $entryPointPluralDisplayName = Get-PredictablePluralDisplayName -DisplayName $entryPointDisplayName
    if ([string]::IsNullOrWhiteSpace($entryPointPluralDisplayName)) {
        throw "Demo Builder cannot predict the Dataverse plural display name for '$entryPointDisplayName'. Rerun with -Mode advanced-builder and make an explicit view disposition decision."
    }
    $entryPointTable = Convert-ToCustomLogicalName -Name $entryPointDisplayName -Prefix $publisherPrefix
    $solutionName = [regex]::Replace((Get-Culture).TextInfo.ToTitleCase($scenarioSlug.Replace('-', ' ')), '[^A-Za-z0-9]', '')
    $needsDemoData = if ($successAndData -match '(?i)\b(no|without)\s+(sample|synthetic|demo)\s+data\b') { 'No' } else { 'Yes' }
    $solutionType = if ($environmentAndOutput -match '(?i)\bunmanaged\b') { 'Unmanaged' } elseif ($environmentAndOutput -match '(?i)\bmanaged\b') { 'Managed' } else { 'Unmanaged' }
    $recommendModernGrid = "$primaryUserTask $experienceAndLifecycle" -match '(?i)\b(daily|frequent|high[- ]frequency|operations?|coordinator|triage|queue|bulk|list|grid|inline|active requests?|update records)\b'
    $recommendGridEditing = $recommendModernGrid -and "$primaryUserTask $experienceAndLifecycle" -match '(?i)\b(edit|update|triage|assign|bulk|inline|maintain)\b'

    Write-Host ""
    Write-Host "Recommended technical design:" -ForegroundColor Cyan
    Write-Host "  Standalone model-driven app; custom tables; new forms"
    Write-Host "  Entry point: $entryPointTable; landing view: Active $entryPointPluralDisplayName"
    Write-Host "  Review app includes all planned tables, forms, views, processes, and approved reports"
    Write-Host "  Power Apps grid for all $entryPointTable views: $recommendModernGrid; inline editing: $recommendGridEditing"
    Write-Host "  Solution: $solutionName ($solutionType); publisher prefix: $publisherPrefix"
    $answers["ScenarioName"] = $scenarioName
    $answers["ScenarioSlug"] = $scenarioSlug
    $answers["ApplicationProfile"] = 'standalone-model-driven'
    $answers["TableChoice"] = 'custom-only'
    $answers["FormStrategy"] = 'create-new-forms'
    $answers["PowerAppsGridEnabled"] = if ($recommendModernGrid) { 'yes' } else { 'no' }
    $answers["PowerAppsGridEditing"] = if ($recommendGridEditing) { 'yes' } else { 'no' }
    $answers["EntryPointTable"] = $entryPointTable
    $answers["EntryPointLandingView"] = "Active $entryPointPluralDisplayName"
    $answers["ReviewAppMode"] = 'create-or-update'
    $answers["ReviewAppArtifacts"] = 'all run-created tables, forms, views, processes, and approved reports'
    $answers["NavigationGroup"] = 'Operations'
    $answers["SourceControlBranch"] = $sourceControlBranchPattern.Replace('<scenario-slug>', $scenarioSlug)
    $answers["SourceControlWorkItem"] = "specs/$scenarioSlug"
    $answers["SourceControlCheckpoints"] = 'checkpoints'
    $answers["SourceControlCiChecks"] = 'applicable repo CI tests'
    $answers["SourceControlPullRequest"] = 'yes'
    $answers["SourceControlMergeStrategy"] = 'team-default'
    $answers["AppType"] = $scenarioName
    $answers["PlatformArea"] = 'Power Apps model-driven app on Dataverse'
    $answers["TargetAudience"] = $primaryUserTask
    $answers["BusinessProblem"] = $scenarioName
    $answers["Users"] = $primaryUserTask
    $answers["DataEntities"] = $dataToTrack
    $answers["ArtifactsNeeded"] = $experienceAndLifecycle
    $answers["SuccessLooksLike"] = $successAndData
    $answers["BuildEnvironment"] = $environmentAndOutput
    $answers["NeedsDemoData"] = $needsDemoData
    $answers["SolutionType"] = $solutionType
    $answers["SolutionChoice"] = 'new'
    $answers["SolutionName"] = $solutionName
    $answers["PrefixChoice"] = 'new'
    $answers["PublisherPrefix"] = $publisherPrefix
    $answers["ReviewAppEnabled"] = 'yes'
    $answers["AppName"] = "$scenarioName Review App"
    $answers["AppUniqueName"] = "$publisherPrefix`_$($scenarioSlug.Replace('-', '_'))_app".ToLowerInvariant()
    $answers["StandardTablesReused"] = 'none'
    $answers["CustomTablesToCreate"] = $dataToTrack
    $answers["StandardFieldsReused"] = 'none'
    $answers["CustomFieldsToAdd"] = 'to be refined during planning'
    $answers["RelationshipsToCreate"] = if ($customTables.Count -gt 1) { 'to be recommended and confirmed during planning' } else { 'none' }
    $reportingChoice = 'none'
    Write-Host "  Reporting choices: native = standard Dataverse charts/dashboard; html = tailored frontline, supervisor, or leadership reports; both = complementary surfaces; none = forms/views only."
    Write-Host "  Choose native/html/both/none in the consolidated confirmation. HTML content must be defined from this scenario's requirements, not a fixed set of generic KPIs."
    $answers["IncludeHtmlReports"] = 'no'
    $answers["IncludeNativeDashboards"] = 'no'
    $answers["UserTaskDefinitions"] = "$primaryUserTask | $experienceAndLifecycle | primary workflow | $entryPointTable/Active $entryPointPluralDisplayName | $successAndData"
    $answers["UserTaskOwnership"] = "$experienceAndLifecycle | app owner | $successAndData"
    $answers["RelationshipRequirements"] = if ($customTables.Count -gt 1) { 'recommendation pending stakeholder confirmation' } else { 'none' }
    $answers["CriticalReportTables"] = 'none'
    $answers["ReportMappings"] = 'none (reports explicitly disabled during intake)'
    $answers["ReportScopingStatus"] = 'approved-no-reports'
    $reportMappingRows = @()
    $answers["DemoDataScope"] = if ($needsDemoData -eq 'Yes') { 'all-created' } else { 'none' }
    $answers["DemoDataTables"] = if ($needsDemoData -eq 'Yes') { $dataToTrack } else { 'none' }
    $answers["DemoDataStandardTableStrategy"] = 'none'
    $answers["DemoDataRecordCounts"] = if ($needsDemoData -eq 'Yes') { 'small synthetic set; counts to be confirmed during planning' } else { 'none' }
    $answers["DemoDataScenarios"] = if ($needsDemoData -eq 'Yes') { $successAndData } else { 'none' }
    $answers["DemoDataHeroRecords"] = 'none'
    $answers["DemoDataRelationshipDistribution"] = 'none'
    $answers["DemoDataCreateTasks"] = 'no'
    $answers["DemoDataTaskParentTables"] = 'none'
    $answers["DemoDataTaskScope"] = 'none'
    $answers["DemoDataTaskSourceRecordLimit"] = '0'
    $answers["DemoDataTaskOrderBy"] = 'none'
    $answers["DemoDataTasksPerRecord"] = '0'
    $answers["DemoDataMethod"] = if ($needsDemoData -eq 'Yes') { 'scripted' } else { 'none' }
    $answers["DemoDataRerunBehavior"] = if ($needsDemoData -eq 'Yes') { 'upsert' } else { 'none' }
    $answers["DemoDataSourceTag"] = if ($needsDemoData -eq 'Yes') { $scenarioSlug } else { 'none' }
    $answers["DemoDataPrivacyConstraints"] = if ($needsDemoData -eq 'Yes') { 'synthetic data only; no personal or production data' } else { 'none' }
    $answers["DemoDataCleanup"] = 'no'
    $bpf = [ordered]@{ Enabled = $false; BusinessProcessFlowName = ''; PrimaryProcessEntity = ''; FailIfBpfDefinitionIncomplete = $true; PreferUpdateExistingBpf = $true; CrossTableProgression = $false; TargetFormName = ''; StageDefinitions = @() }
    Test-AndSetEntryPointPlan -Answers $answers -RetrofitMode $false
} else {
$scenarioName = Read-RequiredValue "Scenario or app name"
$scenarioSlugDefault = ConvertTo-Slug $scenarioName
$scenarioSlug = Read-RequiredValue "Scenario folder slug" $scenarioSlugDefault

$answers = [ordered]@{}
$answers["WizardMode"] = $Mode
$answers["ScenarioName"] = $scenarioName
$answers["ScenarioSlug"] = $scenarioSlug

Write-Host ""
Write-Host "Architecture intent (required before general discovery):" -ForegroundColor Cyan
$answers["ApplicationProfile"] = Read-ChoiceValue -Prompt "A0. Application profile" -AllowedValues @('standalone-model-driven', 'dynamics-sales-extension', 'dynamics-customer-service-extension', 'dynamics-field-service-extension', 'generic-dataverse-solution') -Default 'standalone-model-driven'
$answers["TableChoice"] = Read-ChoiceValue -Prompt "A1. Table strategy" -AllowedValues @('oob-only', 'custom-only', 'hybrid') -Default $(if ($answers["ApplicationProfile"] -eq 'standalone-model-driven') { 'custom-only' } else { 'hybrid' })
$answers["FormStrategy"] = if ($answers["TableChoice"] -eq 'custom-only') {
    'create-new-forms'
} else {
    Read-ChoiceValue -Prompt "A2. Form strategy for existing tables" -AllowedValues @('update-in-place', 'create-new-forms') -Default 'create-new-forms'
}
$answers["EntryPointTable"] = Read-RequiredValue "A3. Primary entry-point table logical name"
$answers["EntryPointLandingView"] = Read-RequiredValue "A4. Default landing view" "Active Records"
$answers["ReviewAppMode"] = 'create-or-update'
Write-Host "A5. Review app behavior: create-or-update (required by the repository contract)"
$answers["ReviewAppArtifacts"] = Read-RequiredValue "A6. Artifacts visible in the review app" "all run-created tables, forms, views, processes, and reports"
$answers["NavigationGroup"] = Read-RequiredValue "A7. Primary app navigation group" "Operations"
$answers["PowerAppsGridEnabled"] = Read-ChoiceValue -Prompt "A8. Use the modern Power Apps grid at table level for all views?" -AllowedValues @('yes', 'no') -Default 'no'
$answers["PowerAppsGridEditing"] = if ($answers["PowerAppsGridEnabled"] -eq 'yes') {
    Read-ChoiceValue -Prompt "A9. Enable inline editing in the Power Apps grid?" -AllowedValues @('yes', 'no') -Default 'no'
} else {
    'no'
}

if ($sourceControlModuleEnabled) {
    $gitPreflight = Get-SourceControlPreflight -RepositoryRoot $repoRoot
    Write-Host ""
    Write-Host "Source-control preflight (read-only):" -ForegroundColor Cyan
    if ($gitPreflight.Available) {
        Write-Host "  Repository: $($gitPreflight.TopLevel)"
        Write-Host "  Remote: $($gitPreflight.Remote)"
        Write-Host "  Current branch: $($gitPreflight.Branch)"
        Write-Host "  Default branch: $($gitPreflight.DefaultBranch)"
        Write-Host "  Recent commit: $($gitPreflight.RecentCommit)"
        Write-Host "  Working tree changes: $($gitPreflight.ChangedCount)"
        if ($gitPreflight.Dirty) {
            Write-Host "  Existing changes detected. The wizard will not stage, discard, or commit them during intake." -ForegroundColor Yellow
        }
        if ($gitPreflight.Branch -eq $gitPreflight.DefaultBranch) {
            Write-Host "  A scenario branch is required before implementation begins." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Git repository details are unavailable. Resolve this before implementation begins." -ForegroundColor Yellow
    }

    $defaultScenarioBranch = $sourceControlBranchPattern.Replace("<scenario-slug>", $scenarioSlug)
    $answers["SourceControlBranch"] = Read-RequiredValue "E-source-control. Scenario branch name" $defaultScenarioBranch
    $answers["SourceControlWorkItem"] = Read-RequiredValue "E-source-control. Related issue/spec/work item (enter 'none' if not applicable)" "specs/$scenarioSlug"
    $answers["SourceControlCheckpoints"] = Read-RequiredValue "E-source-control. Commit strategy (checkpoints/final-only)" "checkpoints"
    $answers["SourceControlCiChecks"] = Read-RequiredValue "E-source-control. Required validation or CI checks (comma-separated)" "applicable repo CI tests"
    $answers["SourceControlPullRequest"] = Read-RequiredValue "E-source-control. Push branch and prepare a pull request at handoff? (yes/no)" "yes"
    $answers["SourceControlMergeStrategy"] = Read-RequiredValue "E-source-control. Merge strategy (squash/merge/rebase/team-default)" "team-default"
} else {
    $answers["SourceControlBranch"] = "not configured"
    $answers["SourceControlWorkItem"] = "none"
    $answers["SourceControlCheckpoints"] = "final-only"
    $answers["SourceControlCiChecks"] = "applicable repo CI tests"
    $answers["SourceControlPullRequest"] = "no"
    $answers["SourceControlMergeStrategy"] = "team-default"
}

if ($Retrofit) {
    # --- Retrofit mode: ask for current state, not greenfield intent ---
    Write-Host ""
    Write-Host "Answer these questions based on what already exists, not what you plan to build." -ForegroundColor Cyan
    Write-Host ""

    $answers["AppType"] = Read-RequiredValue "1. What type of app or demo is this? (describe what already exists)"
    $answers["PlatformArea"] = Read-RequiredValue "2. What platform area is it built on? (D365 Sales, Customer Service, Power Apps, etc.)"
    $answers["TargetAudience"] = Read-RequiredValue "3. Who is the target audience?"
    $answers["BusinessProblem"] = Read-RequiredValue "4. What business problem is it solving? (based on current state)"
    $answers["Users"] = Read-RequiredValue "5. Who are the current users or user roles?"
    $answers["DataEntities"] = Read-RequiredValue "R1. What tables or entities have already been created? (comma-separated)"
    $answers["ArtifactsNeeded"] = Read-RequiredValue "R3. What forms, views, flows, or copilots are currently built or in progress?"
    $answers["SuccessLooksLike"] = Read-RequiredValue "8. What does a successful demo of this app look like?"
    $answers["BuildEnvironment"] = Read-RequiredValue "9. What Environment URL is it currently built in?"
    $answers["NeedsDemoData"] = Read-RequiredValue "10. Does it need demo data?" "Yes"
    $answers["SolutionType"] = Read-RequiredValue "11. Is the solution managed or unmanaged?" "Unmanaged"

    Write-Host ""
    Write-Host "Solution and publisher details (use existing values if already set up):" -ForegroundColor Cyan
    $answers["SolutionChoice"] = "existing"
    $answers["SolutionName"] = Read-RequiredValue "    Existing solution unique name"
    $answers["PrefixChoice"] = "existing"
    $answers["PublisherPrefix"] = Read-RequiredValue "    Existing publisher prefix (e.g. cct, fabrikam)"

    Write-Host ""
    Write-Host "Remaining work (leave blank or enter 'none' if fully built):" -ForegroundColor Cyan
    Write-Host ""
    $answers["RemainingEntities"] = Read-RequiredValue "E-retrofit. Tables or entities still to create (enter 'none' if complete)" "none"
    $answers["RemainingArtifacts"] = Read-RequiredValue "E-retrofit. Forms, views, flows, or copilots still to build (enter 'none' if complete)" "none"
    $answers["RemainingWork"] = Read-RequiredValue "E-retrofit. Any other remaining work not covered above (enter 'none' if complete)" "none"
} else {
    # --- Standard greenfield mode ---
    $answers["AppType"] = Read-RequiredValue "1. What type of demo or app are you building?"
    $answers["PlatformArea"] = Read-RequiredValue "2. Is it for Dynamics 365 Sales, Customer Service, Field Service, Contact Center, Power Apps, Power Pages, Copilot Studio, or Dataverse?"
    $answers["TargetAudience"] = Read-RequiredValue "3. Who is the target audience?"
    $answers["BusinessProblem"] = Read-RequiredValue "4. What business problem does it solve?"
    $answers["Users"] = Read-RequiredValue "5. Who are the users?"
    $answers["DataEntities"] = Read-RequiredValue "6. What data tables or entities are needed?"
    $answers["ArtifactsNeeded"] = Read-RequiredValue "7. What screens, forms, views, pages, flows, or copilots are needed?"
    $answers["SuccessLooksLike"] = Read-RequiredValue "8. What does a successful demo look like?"
    $answers["BuildEnvironment"] = Read-RequiredValue "9. What Environment URL should it be built in?"
    $answers["NeedsDemoData"] = Read-RequiredValue "10. Does it need demo data?" "Yes"
    $answers["SolutionType"] = Read-RequiredValue "11. Should the output be a managed or unmanaged solution?" "Unmanaged"

    $solutionChoice = Read-RequiredValue "E-solution-identity. New solution or use an existing one? (new/existing)" "new"
    $answers["SolutionChoice"] = $solutionChoice
    if ($solutionChoice -ieq "existing") {
        $answers["SolutionName"] = Read-RequiredValue "    Existing solution unique name"
    } else {
        $answers["SolutionName"] = Read-RequiredValue "    New solution unique name (no spaces, letters/numbers only, e.g. ContosoHRApp)"
    }

    $prefixChoice = Read-RequiredValue "E-solution-identity. New publisher prefix or use an existing one? (new/existing)" "new"
    $answers["PrefixChoice"] = $prefixChoice
    if ($prefixChoice -ieq "existing") {
        $answers["PublisherPrefix"] = Read-RequiredValue "    Existing prefix (e.g. cct, fabrikam)"
    } else {
        $answers["PublisherPrefix"] = Read-RequiredValue "    New prefix (3-8 lowercase letters, e.g. cto, demo)"
    }
}

$answers["ReviewAppEnabled"] = if ($answers["ReviewAppMode"] -eq 'create-or-update') { 'yes' } else { 'no' }
$answers["AppName"] = "$scenarioName Review App"
$answers["AppUniqueName"] = "$($answers["PublisherPrefix"])_$($scenarioSlug.Replace('-', '_'))_app".ToLowerInvariant()

if ($Retrofit) {
    Write-Host ""
    Write-Host "Entity mapping (based on what already exists):" -ForegroundColor Cyan
    Write-Host ""
    $answers["StandardTablesReused"] = Read-RequiredValue "E-table-mapping. Standard tables already reused (comma-separated display or logical names; enter 'none' if none)" "none"
    $answers["CustomTablesToCreate"] = Read-RequiredValue "E-table-mapping. Custom tables still to create (comma-separated; enter 'none' if all done)" "none"
    $answers["StandardFieldsReused"] = Read-RequiredValue "E-table-mapping. Standard fields already reused (table.field list; enter 'none' if none)" "none"
    $answers["CustomFieldsToAdd"] = Read-RequiredValue "E-table-mapping. Custom fields still to add (table.field list; enter 'none' if all done)" "none"
    $answers["RelationshipsToCreate"] = Read-RequiredValue "E-table-mapping. Relationships still to create (referencing -> referenced; enter 'none' if all done)" "none"
    if ($reportsModuleEnabled) {
        Write-Host "Native: standard Dataverse charts/dashboard. HTML: Dynamics-styled frontline, supervisor, or leadership reports derived from your requirements. Both must serve distinct tasks; none keeps forms/views only."
        $reportingChoice = Read-ChoiceValue -Prompt "E-reporting. Include native dashboards, custom HTML reports, both, or neither? (native/html/both/none)" -AllowedValues @('native', 'html', 'both', 'none', 'yes', 'no') -Default 'none'
        $answers["IncludeHtmlReports"] = if ($reportingChoice -in @('html', 'both', 'yes')) { 'yes' } else { 'no' }
        $answers["IncludeNativeDashboards"] = if ($reportingChoice -in @('native', 'both')) { 'yes' } else { 'no' }
    } else {
        $answers["IncludeHtmlReports"] = "no"
        $answers["IncludeNativeDashboards"] = "no"
    }
    if ($bpfModuleEnabled) {
        $bpf = Read-BpfDiscovery -ScenarioName $scenarioName -ScenarioSlug $scenarioSlug
    } else {
        $bpf = [ordered]@{ Enabled = $false; BusinessProcessFlowName = ""; PrimaryProcessEntity = ""; FailIfBpfDefinitionIncomplete = $true; PreferUpdateExistingBpf = $true; CrossTableProgression = $false; TargetFormName = ""; StageDefinitions = @() }
    }
} else {
    $answers["StandardTablesReused"] = Read-RequiredValue "E-table-mapping. Explicit mapping - standard tables to reuse (comma-separated display names or logical names; enter 'none' if none)" "none"
    $answers["CustomTablesToCreate"] = Read-RequiredValue "E-table-mapping. Explicit mapping - custom tables to create (comma-separated; enter 'none' if none)" "none"
    $answers["StandardFieldsReused"] = Read-RequiredValue "E-table-mapping. Explicit mapping - standard fields to reuse (table.field list; enter 'none' if none)" "none"
    $answers["CustomFieldsToAdd"] = Read-RequiredValue "E-table-mapping. Explicit mapping - custom fields to add (table.field list; enter 'none' if none)" "none"
    $answers["RelationshipsToCreate"] = Read-RequiredValue "E-table-mapping. Explicit mapping - relationships to create (referencing -> referenced; enter 'none' if none)" "none"
    if ($reportsModuleEnabled) {
        Write-Host "Native: standard Dataverse charts/dashboard. HTML: Dynamics-styled frontline, supervisor, or leadership reports derived from your requirements. Both must serve distinct tasks; none keeps forms/views only."
        $reportingChoice = Read-ChoiceValue -Prompt "E-reporting. Include native dashboards, custom HTML reports, both, or neither? (native/html/both/none)" -AllowedValues @('native', 'html', 'both', 'none', 'yes', 'no') -Default 'none'
        $answers["IncludeHtmlReports"] = if ($reportingChoice -in @('html', 'both', 'yes')) { 'yes' } else { 'no' }
        $answers["IncludeNativeDashboards"] = if ($reportingChoice -in @('native', 'both')) { 'yes' } else { 'no' }
    } else {
        $answers["IncludeHtmlReports"] = "no"
        $answers["IncludeNativeDashboards"] = "no"
    }
    if ($bpfModuleEnabled) {
        $bpf = Read-BpfDiscovery -ScenarioName $scenarioName -ScenarioSlug $scenarioSlug
    } else {
        $bpf = [ordered]@{ Enabled = $false; BusinessProcessFlowName = ""; PrimaryProcessEntity = ""; FailIfBpfDefinitionIncomplete = $true; PreferUpdateExistingBpf = $true; CrossTableProgression = $false; TargetFormName = ""; StageDefinitions = @() }
    }
}

Test-AndSetEntryPointPlan -Answers $answers -RetrofitMode $Retrofit.IsPresent

$answers["UserTaskDefinitions"] = Read-RequiredValue "E-user-tasks. Top user tasks (persona | task | frequency | entry table/view | outcome; semicolon-separated)"
$answers["UserTaskOwnership"] = Read-RequiredValue "E-user-tasks. Task ownership and done definitions (task | owner | done definition; semicolon-separated)"

if ($answers["RelationshipsToCreate"].Trim().ToLowerInvariant() -ne "none") {
    $answers["RelationshipRequirements"] = Read-RequiredValue "E-table-mapping. Relationship decisions (referencing -> referenced | cardinality | required/optional | existing/new | cascade behavior | supporting task/surface; semicolon-separated)"
} else {
    $answers["RelationshipRequirements"] = "none"
}

$reportMappingRows = @()
if ($answers["IncludeHtmlReports"] -eq 'yes' -or $answers["IncludeNativeDashboards"] -eq 'yes') {
    Write-Host ""
    Write-Host "Report scoping (required before implementation when reports are enabled)." -ForegroundColor Cyan
    $answers["CriticalReportTables"] = Read-RequiredValue "E-reporting. Critical or high-frequency table logical names (comma-separated)"
    $answers["ReportMappings"] = Read-RequiredValue "E-reporting. Report mappings (table | surface name | form/dashboard/view | target placement | required fields | decision supported | owner | validation checklist; semicolon-separated)"
    $reportMappingRows = @(ConvertTo-ReportMappingRows -Value $answers["ReportMappings"])

    $mappedReportTables = @($reportMappingRows | ForEach-Object { $_.TableLogicalName.Trim().ToLowerInvariant() } | Select-Object -Unique)
    $missingCriticalTables = @(Split-ListValues -Value $answers["CriticalReportTables"] | Where-Object { $mappedReportTables -notcontains $_.Trim().ToLowerInvariant() })
    if ($missingCriticalTables.Count -gt 0) {
        throw "Report scoping is incomplete. Critical tables require an approved report mapping: $($missingCriticalTables -join ', ')"
    }

    $answers["ReportScopingStatus"] = "approved"
} else {
    $answers["CriticalReportTables"] = "none"
    $answers["ReportMappings"] = "none (reports explicitly disabled during intake)"
    $answers["ReportScopingStatus"] = "approved-no-reports"
}

if ($answers["NeedsDemoData"] -match '^(?i:y|yes|true|1)$') {
    Write-Host ""
    Write-Host "Demo data planning (planning only; this wizard does not create Dataverse rows)." -ForegroundColor Cyan
    $answers["DemoDataScope"] = Read-RequiredValue "E-demo-data. Seed all scenario-created custom tables or selected tables? (all-created/selected)" "all-created"
    $defaultDemoDataTables = if ($answers["DemoDataScope"] -ieq "all-created") { $answers["CustomTablesToCreate"] } else { "" }
    $answers["DemoDataTables"] = Read-RequiredValue "E-demo-data. Tables to receive records (comma-separated)" $defaultDemoDataTables
    $answers["DemoDataStandardTableStrategy"] = Read-RequiredValue "E-demo-data. Standard reused table strategy (table=create/reuse-existing/both; semicolon-separated; enter 'none' if not targeted)" "none"
    $answers["DemoDataRecordCounts"] = Read-RequiredValue "E-demo-data. Record count per table (table=count; semicolon-separated)"
    $answers["DemoDataScenarios"] = Read-RequiredValue "E-demo-data. Business scenarios and lifecycle states the records must cover"
    $answers["DemoDataHeroRecords"] = Read-RequiredValue "E-demo-data. Hero records for demos (table | count | scenario/purpose; semicolon-separated; enter 'none' if not needed)" "none"
    $answers["DemoDataRelationshipDistribution"] = Read-RequiredValue "E-demo-data. Related-record distribution (for example: Case=10; Review=1-3 per Case)" "none"
    $answers["DemoDataCreateTasks"] = Read-RequiredValue "E-demo-data. Create related Dataverse Task activity records? (yes/no)" "no"
    if ($answers["DemoDataCreateTasks"] -match '^(?i:y|yes|true|1)$') {
        $answers["DemoDataTaskParentTables"] = Read-RequiredValue "E-demo-data. Parent tables whose records receive Task activities (comma-separated)" $answers["DemoDataTables"]
        $answers["DemoDataTaskScope"] = Read-RequiredValue "E-demo-data. Which parent records receive tasks? (latest/all/selected)" "latest"
        $answers["DemoDataTaskSourceRecordLimit"] = Read-RequiredValue "E-demo-data. Maximum parent records per table that receive tasks" "10"
        $answers["DemoDataTaskOrderBy"] = Read-RequiredValue "E-demo-data. Field and direction used to identify the latest records" "createdon desc"
        $answers["DemoDataTasksPerRecord"] = Read-RequiredValue "E-demo-data. Number of Task activities per selected parent record" "1"
    } else {
        $answers["DemoDataTaskParentTables"] = "none"
        $answers["DemoDataTaskScope"] = "none"
        $answers["DemoDataTaskSourceRecordLimit"] = "0"
        $answers["DemoDataTaskOrderBy"] = "none"
        $answers["DemoDataTasksPerRecord"] = "0"
    }
    $answers["DemoDataMethod"] = Read-RequiredValue "E-demo-data. Creation method (scripted/manual/import)" "scripted"
    if ($Mode -eq 'framework-acceptance') {
        $answers["DemoDataRerunBehavior"] = Read-RequiredValue "A-acceptance. Deterministic rerun behavior (upsert/replace/fail-if-present)" "upsert"
        $answers["DemoDataSourceTag"] = Read-RequiredValue "A-acceptance. Run-specific source tag used to identify acceptance-owned records" $scenarioSlug
        $answers["DemoDataPrivacyConstraints"] = Read-RequiredValue "A-acceptance. Synthetic-data/privacy constraints" "synthetic data only; no personal or production data"
        $answers["DemoDataCleanup"] = Read-RequiredValue "A-acceptance. Generate cleanup/reset instructions? (yes/no)" "no"
    } else {
        $answers["DemoDataRerunBehavior"] = 'upsert'
        $answers["DemoDataSourceTag"] = $scenarioSlug
        $answers["DemoDataPrivacyConstraints"] = 'synthetic data only; no personal or production data'
        $answers["DemoDataCleanup"] = 'no'
    }
} else {
    $answers["DemoDataScope"] = "none"
    $answers["DemoDataTables"] = "none"
    $answers["DemoDataStandardTableStrategy"] = "none"
    $answers["DemoDataRecordCounts"] = "none"
    $answers["DemoDataScenarios"] = "none"
    $answers["DemoDataHeroRecords"] = "none"
    $answers["DemoDataRelationshipDistribution"] = "none"
    $answers["DemoDataCreateTasks"] = "no"
    $answers["DemoDataTaskParentTables"] = "none"
    $answers["DemoDataTaskScope"] = "none"
    $answers["DemoDataTaskSourceRecordLimit"] = "0"
    $answers["DemoDataTaskOrderBy"] = "none"
    $answers["DemoDataTasksPerRecord"] = "0"
    $answers["DemoDataMethod"] = "none"
    $answers["DemoDataRerunBehavior"] = "none"
    $answers["DemoDataSourceTag"] = "none"
    $answers["DemoDataPrivacyConstraints"] = "none"
    $answers["DemoDataCleanup"] = "no"
}
}

if ($Mode -eq 'framework-acceptance') {
    Write-Host ""
    Write-Host "Framework Acceptance controls (explicit mode only):" -ForegroundColor Cyan
    $answers["AcceptanceEnvironmentAuthorization"] = Read-ChoiceValue -Prompt "A-acceptance. Is this environment explicitly authorized for framework acceptance?" -AllowedValues @('yes', 'no') -Default 'no'
    if ($answers["AcceptanceEnvironmentAuthorization"] -ne 'yes') {
        throw 'Framework Acceptance requires an explicitly authorized environment.'
    }
    $answers["AcceptanceIsolationName"] = Read-RequiredValue "A-acceptance. Timestamped acceptance-only solution name" $answers["SolutionName"]
    $answers["AcceptancePublisherPrefix"] = Read-RequiredValue "A-acceptance. Acceptance publisher prefix" $answers["PublisherPrefix"]
    $answers["AcceptanceHeroRecordLabels"] = Read-RequiredValue "A-acceptance. Hero record labels and purposes" $answers["DemoDataHeroRecords"]
    $answers["AcceptanceRerunProof"] = Read-RequiredValue "A-acceptance. Evidence that a second run is deterministic and idempotent"
    $answers["AcceptanceRetentionPolicy"] = Read-ChoiceValue -Prompt "A-acceptance. Retain acceptance artifacts after verification?" -AllowedValues @('retain', 'remove-after-approval') -Default 'retain'
    $answers["AcceptanceCleanupApproval"] = Read-ChoiceValue -Prompt "A-acceptance. Is destructive cleanup separately approved for this run?" -AllowedValues @('yes', 'no') -Default 'no'
    $answers["AcceptanceEvidencePlan"] = Read-RequiredValue "A-acceptance. Evidence to capture for lifecycle, availability, relationships, app navigation, and rerun checks"
} else {
    $answers["AcceptanceEnvironmentAuthorization"] = 'not applicable'
    $answers["AcceptanceIsolationName"] = 'not applicable'
    $answers["AcceptancePublisherPrefix"] = 'not applicable'
    $answers["AcceptanceHeroRecordLabels"] = 'not applicable'
    $answers["AcceptanceRerunProof"] = 'not applicable'
    $answers["AcceptanceRetentionPolicy"] = 'not applicable'
    $answers["AcceptanceCleanupApproval"] = 'not applicable'
    $answers["AcceptanceEvidencePlan"] = 'not applicable'
}

$answers["EnableBusinessProcessFlow"] = if ($bpf.Enabled) { "yes" } else { "no" }
$answers["BusinessProcessFlowName"] = $bpf.BusinessProcessFlowName
$answers["PrimaryProcessEntity"] = $bpf.PrimaryProcessEntity
$answers["FailIfBpfDefinitionIncomplete"] = if ($bpf.FailIfBpfDefinitionIncomplete) { "yes" } else { "no" }
$answers["PreferUpdateExistingBpf"] = if ($bpf.PreferUpdateExistingBpf) { "yes" } else { "no" }
$answers["BpfCrossTableProgression"] = if ($bpf.CrossTableProgression) { "yes" } else { "no" }
$answers["BpfTargetFormName"] = $bpf.TargetFormName
$answers["BpfStageDefinitions"] = @($bpf.StageDefinitions)
$answers["ReportTheme"] = if ($answers["ApplicationProfile"] -eq 'standalone-model-driven') { 'Power Apps neutral' } else { 'Dynamics blue' }
$answers["ReportSet"] = 'Only requirement-backed frontline, supervisor, or leadership reports approved in html-reports.json'

$answers["AcceleratorPreference"] = $selectedAcceleratorPreference
$answers["AcceleratorMatchingRequested"] = if ($acceleratorMatchingRequested) { 'yes' } else { 'no' }
$standardTableMapping = Format-StandardTableMapping -Value $answers["StandardTablesReused"]
$customTableMapping = Format-CustomTableMapping -Value $answers["CustomTablesToCreate"] -Prefix $answers["PublisherPrefix"]

$scenarioFolder = Join-Path $repoRoot (Join-Path "specs" $scenarioSlug)
New-Item -ItemType Directory -Path $scenarioFolder -Force | Out-Null

$acceleratorPreferenceRecord = if ($acceleratorRecommendationsEnabled) {
    New-WizardAcceleratorPreferenceRecord `
        -Preference $selectedAcceleratorPreference `
        -ScenarioSlug $scenarioSlug `
        -Mode $Mode `
        -RecordedAtUtc $AcceleratorEvaluationTimeUtc
} else {
    $null
}
$acceleratorEvaluation = $null
$acceleratorDecision = $null
$acceleratorPreferenceAnswersBlock = if ($acceleratorRecommendationsEnabled) {
@"
## Accelerator Startup Preference
- Preference: $selectedAcceleratorPreference
- Matching requested: $($acceleratorPreferenceRecord.matchingRequested)
- Final architecture selected at startup: no
- Deployment authorized at startup: no
- Preference artifact: accelerator/accelerator-preference.json
"@
} else { '' }
$acceleratorPreferenceSpecBlock = if ($acceleratorRecommendationsEnabled) {
@"
## Accelerator Startup Preference
- Preliminary preference: $selectedAcceleratorPreference
- Matching requested: $($acceleratorPreferenceRecord.matchingRequested)
- This preference is separate from final architecture approval and does not authorize deployment.
"@
} else { '' }
$acceleratorPreferencePlanBlock = if ($acceleratorRecommendationsEnabled) {
@"
## Accelerator Preference Plan
- Preserve the preliminary preference $selectedAcceleratorPreference in accelerator/accelerator-preference.json.
- Run matching only after requirements normalization and only when matching was requested.
- Keep the final architecture decision separate from this preference.
"@
} else { '' }
$acceleratorPreferenceTasksBlock = if ($acceleratorRecommendationsEnabled) {
@"
## Accelerator Preference Tasks
- [x] Record preliminary accelerator preference `$selectedAcceleratorPreference`.
- [x] Confirm the preference did not select an architecture or authorize deployment.
"@
} else { '' }
$acceleratorAnswersBlock = $acceleratorPreferenceAnswersBlock
$acceleratorSpecBlock = $acceleratorPreferenceSpecBlock
$acceleratorPlanBlock = $acceleratorPreferencePlanBlock
$acceleratorTasksBlock = $acceleratorPreferenceTasksBlock
$acceleratorOutputFolder = Join-Path $scenarioFolder 'accelerator'
$acceleratorPreferencePath = Join-Path $acceleratorOutputFolder 'accelerator-preference.json'
$acceleratorDecisionPath = Join-Path $acceleratorOutputFolder 'accelerator-decision.json'
$acceleratorDecisionMarkdownPath = Join-Path $acceleratorOutputFolder 'accelerator-decision.md'
if ($acceleratorMatchingRequested) {
    $acceleratorRequirements = ConvertTo-WizardAcceleratorRequirements `
        -Answers $answers `
        -ScenarioSlug $scenarioSlug
    $acceleratorEvaluation = Invoke-WizardAcceleratorEvaluation `
        -Requirements $acceleratorRequirements `
        -WorkspaceRoot $repoRoot `
        -ScenarioSlug $scenarioSlug `
        -CatalogSnapshotPath $AcceleratorCatalogSnapshotPath `
        -PackageMetadataPaths $AcceleratorPackageMetadataPaths `
        -PackageManifestPath $AcceleratorPackageManifestPath `
        -EnvironmentValidationPath $AcceleratorEnvironmentValidationPath `
        -EvaluationTimeUtc $AcceleratorEvaluationTimeUtc
    Show-WizardAcceleratorEvaluation `
        -Evaluation $acceleratorEvaluation `
        -Mode $Mode `
        -Preference $selectedAcceleratorPreference
    $availableArchitectureOptions = @($acceleratorEvaluation.options | ForEach-Object { "$($_.optionId)" })
    $confirmationOptions = @($availableArchitectureOptions)
    if ($Mode -eq 'demo-builder') {
        foreach ($architectureOption in $availableArchitectureOptions) {
            foreach ($reportOption in @('native', 'html', 'both', 'none')) {
                $confirmationOptions += "$architectureOption+$reportOption"
            }
        }
    }
    $architectureConfirmation = if ([string]::IsNullOrWhiteSpace($AcceleratorArchitectureChoice)) {
        Read-ChoiceValue `
            -Prompt $(if ($Mode -eq 'demo-builder') {
                '7. Select and approve the consolidated architecture; optionally append +native/+html/+both/+none for reporting'
            } else {
                'A-accelerator. Select and approve the architecture'
            }) `
            -AllowedValues $confirmationOptions `
            -Default "$($acceleratorEvaluation.recommendedOption)"
    } else {
        if ($availableArchitectureOptions -notcontains $AcceleratorArchitectureChoice) {
            throw "Architecture option '$AcceleratorArchitectureChoice' is unavailable. Choose one of: $($availableArchitectureOptions -join ', ')."
        }
        $AcceleratorArchitectureChoice
    }
    $confirmationParts = @($architectureConfirmation -split '\+', 2)
    $selectedArchitecture = $confirmationParts[0]
    if ($confirmationParts.Count -eq 2) {
        $answers["IncludeHtmlReports"] = if ($confirmationParts[1] -in @('html', 'both')) { 'yes' } else { 'no' }
        $answers["IncludeNativeDashboards"] = if ($confirmationParts[1] -in @('native', 'both')) { 'yes' } else { 'no' }
    }
    $acceleratorDecision = New-WizardAcceleratorDecision `
        -Evaluation $acceleratorEvaluation `
        -SelectedOption $selectedArchitecture `
        -ScenarioSlug $scenarioSlug `
        -Mode $Mode `
        -Rationale $AcceleratorDecisionRationale `
        -RecordedAtUtc $AcceleratorEvaluationTimeUtc
    Assert-WizardAcceleratorDecisionChange `
        -Decision $acceleratorDecision `
        -DecisionPath $acceleratorDecisionPath `
        -ApproveDecisionChange:$ApproveAcceleratorDecisionChange
    $acceleratorProjection = Get-WizardAcceleratorPlanningProjection `
        -Evaluation $acceleratorEvaluation `
        -Decision $acceleratorDecision
    $acceleratorAnswersBlock = "$acceleratorPreferenceAnswersBlock`n$($acceleratorProjection.Answers)"
    $acceleratorSpecBlock = "$acceleratorPreferenceSpecBlock`n$($acceleratorProjection.Spec)"
    $acceleratorPlanBlock = "$acceleratorPreferencePlanBlock`n$($acceleratorProjection.Plan)"
    $acceleratorTasksBlock = "$acceleratorPreferenceTasksBlock`n$($acceleratorProjection.Tasks)"
} elseif ($Mode -eq 'demo-builder') {
    $recommendationConfirmation = Read-ChoiceValue -Prompt "7. Accept recommendations and choose reporting (yes/none/native/html/both; no cancels)?" -AllowedValues @('yes', 'no', 'none', 'native', 'html', 'both') -Default 'yes'
    if ($recommendationConfirmation -eq 'no') {
        throw "Demo Builder recommendations were not approved. Rerun with -Mode advanced-builder to control the technical design."
    }
    if ($recommendationConfirmation -ne 'yes') {
        $reportingChoice = $recommendationConfirmation
        $answers["IncludeHtmlReports"] = if ($reportingChoice -in @('html', 'both')) { 'yes' } else { 'no' }
        $answers["IncludeNativeDashboards"] = if ($reportingChoice -in @('native', 'both')) { 'yes' } else { 'no' }
    }
}
if ($Mode -eq 'demo-builder' -and ($answers["IncludeHtmlReports"] -eq 'yes' -or $answers["IncludeNativeDashboards"] -eq 'yes')) {
    $answers["CriticalReportTables"] = $answers["EntryPointTable"]
    $answers["ReportScopingStatus"] = 'pending-review'
    $answers["ReportMappings"] = 'pending: derive report audiences, fields, calculations, and placements from the approved user tasks and success criteria'
}

# Write planning values to .env.ps1 so 10-auth-connect.ps1 can use them as defaults.
# 10-auth-connect.ps1 will overwrite this file with full auth + config when it runs.
$envFilePath = Join-Path $repoRoot ".env.ps1"
$planEnvContent = @"
# Planning values set by 05-start-wizard.ps1 -- do not commit this file.
# Run 10-auth-connect.ps1 next to complete authentication and full configuration.
`$env:DV_SOLUTION_NAME       = "$($answers["SolutionName"])"
`$env:DV_PUBLISHER_PREFIX    = "$($answers["PublisherPrefix"])"
`$global:DV_SOLUTION_NAME    = "`$env:DV_SOLUTION_NAME"
`$global:DV_PUBLISHER_PREFIX = "`$env:DV_PUBLISHER_PREFIX"
"@
Set-Content -Path $envFilePath -Value $planEnvContent -Encoding UTF8

$answersPath = Join-Path $scenarioFolder "answers.md"
$specPath = Join-Path $scenarioFolder "spec.md"
$planPath = Join-Path $scenarioFolder "plan.md"
$tasksPath = Join-Path $scenarioFolder "tasks.md"
$demoDataPlanPath = Join-Path $scenarioFolder "demo-data-plan.json"
$reportMappingsPath = Join-Path $scenarioFolder "report-mappings.md"
$viewsPath = Join-Path $scenarioFolder "views.json"
$gridControlsPath = Join-Path $scenarioFolder "grid-controls.json"
$scenarioPayloadFolder = Join-Path (Join-Path $repoRoot "payloads\scenarios") $scenarioSlug
$bpfPayloadPath = Join-Path $scenarioPayloadFolder "process-$scenarioSlug.json"

$viewsContract = [ordered]@{
    Views = @(
        [ordered]@{
            TableLogicalName = $answers["EntryPointTable"]
            Name             = $answers["EntryPointLandingView"]
            Disposition      = $answers["EntryPointLandingViewPlan"]
            DecisionReason   = $answers["EntryPointLandingViewPlanReason"]
            Columns          = @()
            Filter           = [ordered]@{ Attribute = 'statecode'; Operator = 'eq'; Value = '0' }
            Sort             = [ordered]@{ Attribute = ''; Descending = $false }
        }
    )
}
$viewsJson = $viewsContract | ConvertTo-Json -Depth 8
$gridControlsObject = if ($answers["PowerAppsGridEnabled"] -eq 'yes') {
    [ordered]@{
        version = '1.0'
        tables = @(
            [ordered]@{
                tableLogicalName = $answers["EntryPointTable"]
                scope = 'all-views'
                enableEditing = ($answers["PowerAppsGridEditing"] -eq 'yes')
                filtering = $true
                sorting = $true
                grouping = $false
                aggregation = $false
                columnReordering = $false
                multiselect = $true
                rangeSelection = $true
                jumpBar = $false
                pagination = $false
                optionSetColors = $false
                statusIcons = $true
                typeIcons = $false
                persona = $answers["Users"]
                rationale = 'Modern table-level grid for the planned operational landing experience.'
            }
        )
    }
} else { $null }
$gridControlsJson = if ($null -ne $gridControlsObject) { $gridControlsObject | ConvertTo-Json -Depth 8 } else { '' }

$standardFieldsList = Format-BulletList -Value $answers["StandardFieldsReused"]
$customFieldsList = Format-BulletList -Value $answers["CustomFieldsToAdd"]
$relationshipList = Format-BulletList -Value $answers["RelationshipsToCreate"]
$bpfStagesMarkdown = Format-BpfStageBullets -Stages @($answers["BpfStageDefinitions"])
$bpfPayloadObject = if ($bpf.Enabled) {
    [ordered]@{
        Enabled                       = $true
        BusinessProcessFlowName       = $bpf.BusinessProcessFlowName
        PrimaryProcessEntity          = $bpf.PrimaryProcessEntity
        FailIfBpfDefinitionIncomplete = $bpf.FailIfBpfDefinitionIncomplete
        PreferUpdateExistingBpf       = $bpf.PreferUpdateExistingBpf
        CrossTableProgression         = $bpf.CrossTableProgression
        FormIntegration               = [ordered]@{
            TargetFormName   = $bpf.TargetFormName
            RequireMainForm  = $true
        }
        StageDefinitions              = @($bpf.StageDefinitions | ForEach-Object {
            [ordered]@{
                Order                  = $_.Order
                StageName              = $_.StageName
                EntityLogicalName      = $_.EntityLogicalName
                RequiredFields         = @($_.RequiredFields)
                EntryCriteria          = $_.EntryCriteria
                ExitCriteria           = $_.ExitCriteria
                RelationshipLogicalName = $_.RelationshipLogicalName
            }
        })
    }
} else {
    $null
}
$bpfPayloadJson = if ($null -ne $bpfPayloadObject) { $bpfPayloadObject | ConvertTo-Json -Depth 10 } else { "" }
$demoDataPlanObject = if ($answers["NeedsDemoData"] -match '^(?i:y|yes|true|1)$') {
    [ordered]@{
        Enabled                 = $true
        Scope                   = $answers["DemoDataScope"]
        Tables                  = @(Split-ListValues -Value $answers["DemoDataTables"])
        StandardTableStrategy   = $answers["DemoDataStandardTableStrategy"]
        RecordCounts            = $answers["DemoDataRecordCounts"]
        Scenarios               = $answers["DemoDataScenarios"]
        HeroRecords             = $answers["DemoDataHeroRecords"]
        RelationshipDistribution = $answers["DemoDataRelationshipDistribution"]
        TaskGeneration          = [ordered]@{
            Enabled                 = ($answers["DemoDataCreateTasks"] -match '^(?i:y|yes|true|1)$')
            ParentTables            = @(Split-ListValues -Value $answers["DemoDataTaskParentTables"])
            Scope                   = $answers["DemoDataTaskScope"]
            SourceRecordLimit       = [int]$answers["DemoDataTaskSourceRecordLimit"]
            OrderBy                 = $answers["DemoDataTaskOrderBy"]
            TasksPerRecord          = [int]$answers["DemoDataTasksPerRecord"]
        }
        Method                  = $answers["DemoDataMethod"]
        RerunBehavior           = $answers["DemoDataRerunBehavior"]
        SourceTag               = $answers["DemoDataSourceTag"]
        PrivacyConstraints      = $answers["DemoDataPrivacyConstraints"]
        GenerateCleanup        = ($answers["DemoDataCleanup"] -match '^(?i:y|yes|true|1)$')
    }
} else {
    $null
}
$demoDataPlanJson = if ($null -ne $demoDataPlanObject) { $demoDataPlanObject | ConvertTo-Json -Depth 5 } else { "" }
$reportingSelectionBlock = @"
## Reporting Selection
- Native dashboards: $($answers["IncludeNativeDashboards"])
- HTML reports: $($answers["IncludeHtmlReports"])
- Native dashboards use standard Dataverse chart/dashboard components; HTML reports provide tailored persona-oriented layouts.
- Generate both only for distinct approved tasks. Neither is mandatory.
- HTML definitions: html-reports.json; require explicit approval, requirement excerpts from spec.md/plan.md, and matching report-mappings.md rows.
- Explain each report's audience, decision, metrics, data scope, placement, limitations, and overlap before approval.
"@
$reportMappingTable = if ($reportMappingRows.Count -gt 0) { Format-ReportMappingTable -Rows $reportMappingRows } elseif ($answers["ReportScopingStatus"] -eq 'pending-review') { '_Reporting selected; mapping approval is pending. Do not generate reporting payloads or HTML sources yet._' } else { '_No report surfaces selected. Reports were explicitly disabled during intake._' }
$reportMappingsContent = @"
# Report Mappings

## Scope Decision
- Status: $($answers["ReportScopingStatus"])
- Critical or high-frequency tables: $($answers["CriticalReportTables"])
- Reports enabled: $(if ($answers["IncludeHtmlReports"] -eq 'yes' -or $answers["IncludeNativeDashboards"] -eq 'yes') { 'yes' } else { 'no' })

$reportingSelectionBlock

## Report Mapping Table
$reportMappingTable

## Approval Gate
- Every critical or high-frequency table has an explicit report decision.
- Target placement and required fields must be validated against the approved table and form/view schema before implementation.
- Build scripts remain blocked until this mapping is reviewed with spec.md, plan.md, and tasks.md.
"@

$bpfSummaryBlock = if ($bpf.Enabled) {
@"
## Optional Business Process Flow
- Enabled: yes
- Name: $($bpf.BusinessProcessFlowName)
- Primary entity: $($bpf.PrimaryProcessEntity)
- Target Main form: $($bpf.TargetFormName)
- Cross-table progression: $($answers["BpfCrossTableProgression"])
- Fail if incomplete: $($answers["FailIfBpfDefinitionIncomplete"])
- Prefer update existing: $($answers["PreferUpdateExistingBpf"])

### BPF Stage Definitions
$bpfStagesMarkdown

### BPF Payload Draft
```json
$bpfPayloadJson
```
"@
} else {
@"
## Optional Business Process Flow
- Enabled: no
- Reason to skip: No staged lifecycle was captured during discovery.
"@
}

$targetFiles = @($answersPath, $specPath, $planPath, $tasksPath, $reportMappingsPath)
$targetFiles += $viewsPath
if ($null -ne $gridControlsObject) {
    $targetFiles += $gridControlsPath
} elseif (Test-Path -LiteralPath $gridControlsPath -PathType Leaf) {
    $targetFiles += $gridControlsPath
}
if ($null -ne $demoDataPlanObject) {
    $targetFiles += $demoDataPlanPath
}
if ($bpf.Enabled) {
    $targetFiles += $bpfPayloadPath
}
if ($acceleratorRecommendationsEnabled) {
    $targetFiles += $acceleratorPreferencePath
}
if ($acceleratorMatchingRequested) {
    $targetFiles += @($acceleratorDecisionPath, $acceleratorDecisionMarkdownPath)
}
$existingFiles = @($targetFiles | Where-Object { Test-Path $_ })
if ($existingFiles.Count -gt 0 -and -not $Force) {
    if (-not (Confirm-Overwrite -Paths $existingFiles)) {
        Write-Host "" 
        Write-Host "No files were changed. Re-run with a new scenario slug or use -Force." -ForegroundColor Yellow
        exit 0
    }
}

$answersContent = @"
# Discovery Answers

## Contract
- Contract: docs/wizard-contract-v1.md
- Profile: wizard.profile.json
- Wizard mode: $($answers["WizardMode"])

## Scenario
- Name: $($answers["ScenarioName"])
- Slug: $($answers["ScenarioSlug"])

## Application Profile
- Profile: $($answers["ApplicationProfile"])
- Table Strategy: $($answers["TableChoice"])
- Form Strategy: $($answers["FormStrategy"])
- Entry Point Table: $($answers["EntryPointTable"])
- Landing View: $($answers["EntryPointLandingView"])
- Entry Point Validation: $($answers["EntryPointValidationStatus"])
- Landing View Plan: $($answers["EntryPointLandingViewPlan"])
- Power Apps Grid (table-level, all views): $($answers["PowerAppsGridEnabled"])
- Power Apps Grid Inline Editing: $($answers["PowerAppsGridEditing"])
- Review App Mode: $($answers["ReviewAppMode"])
- Required App Artifacts: $($answers["ReviewAppArtifacts"])

## Framework Acceptance Controls
- Environment authorized: $($answers["AcceptanceEnvironmentAuthorization"])
- Isolated solution name: $($answers["AcceptanceIsolationName"])
- Publisher prefix: $($answers["AcceptancePublisherPrefix"])
- Hero record labels: $($answers["AcceptanceHeroRecordLabels"])
- Rerun evidence: $($answers["AcceptanceRerunProof"])
- Retention policy: $($answers["AcceptanceRetentionPolicy"])
- Destructive cleanup separately approved: $($answers["AcceptanceCleanupApproval"])
- Evidence plan: $($answers["AcceptanceEvidencePlan"])

## App Module
- Enabled: $($answers["ReviewAppEnabled"])
- App Name: $($answers["AppName"])
- Unique Name: $($answers["AppUniqueName"])
- Navigation Group: $($answers["NavigationGroup"])

## Required Question Set (11)
1. Type of demo/app: $($answers["AppType"])
2. Platform area: $($answers["PlatformArea"])
3. Target audience: $($answers["TargetAudience"])
4. Business problem: $($answers["BusinessProblem"])
5. Users: $($answers["Users"])
6. Data entities: $($answers["DataEntities"])
7. Needed artifacts: $($answers["ArtifactsNeeded"])
8. Success definition: $($answers["SuccessLooksLike"])
9. Build environment: $($answers["BuildEnvironment"])
10. Demo data needed: $($answers["NeedsDemoData"])
11. Solution output type: $($answers["SolutionType"])

## Extension Blocks
- business-process-flow: enabled=$($answers["EnableBusinessProcessFlow"]) ; primary=$($answers["PrimaryProcessEntity"]) ; name=$($answers["BusinessProcessFlowName"])
- table-strategy: $($answers["TableChoice"])
- solution-identity: solution=$($answers["SolutionChoice"]) -- $($answers["SolutionName"]); prefix=$($answers["PrefixChoice"]) -- $($answers["PublisherPrefix"])
- reporting: $($answers["IncludeHtmlReports"])
- source-control: branch=$($answers["SourceControlBranch"]); commits=$($answers["SourceControlCheckpoints"]); pull-request=$($answers["SourceControlPullRequest"])
$(if ($Retrofit) { "- retrofit: enabled" } else { "- retrofit: disabled" })

## Source Control Plan
- Standards: requirements/GithubInstructions_General.md
- Scenario branch: $($answers["SourceControlBranch"])
- Related work: $($answers["SourceControlWorkItem"])
- Commit strategy: $($answers["SourceControlCheckpoints"])
- Required validation/CI: $($answers["SourceControlCiChecks"])
- Pull request handoff: $($answers["SourceControlPullRequest"])
- Merge strategy: $($answers["SourceControlMergeStrategy"])
- Safety: inspect status and diff, stage explicit files, validate before commit, and require approval before commit or push.

## Optional Report Web Resources
- Enabled: $($answers["IncludeHtmlReports"])
- Selected Reports: $($answers["ReportSet"])
- Visual theme: $($answers["ReportTheme"])
- Integration: Create HTML web resources and add them to the selected solution.
- Report scoping status: $($answers["ReportScopingStatus"])
- Critical or high-frequency tables: $($answers["CriticalReportTables"])
- Mapping artifact: report-mappings.md

## Explicit Entity Mapping (Required Before Payloads)

### Standard reused tables (display -> logical)
$standardTableMapping

### Custom tables to create (input -> generated logical)
$customTableMapping

### Standard fields reused
$standardFieldsList

### Custom fields to add
$customFieldsList

### Relationships to create
$relationshipList

### Relationship decisions
$($answers["RelationshipRequirements"])

## User Task Plan
- Task definitions: $($answers["UserTaskDefinitions"])
- Ownership and done definitions: $($answers["UserTaskOwnership"])

## Demo Data Plan
- Enabled: $($answers["NeedsDemoData"])
- Scope: $($answers["DemoDataScope"])
- Tables: $($answers["DemoDataTables"])
- Standard reused table strategy: $($answers["DemoDataStandardTableStrategy"])
- Record counts: $($answers["DemoDataRecordCounts"])
- Scenarios and lifecycle states: $($answers["DemoDataScenarios"])
- Hero records: $($answers["DemoDataHeroRecords"])
- Related-record distribution: $($answers["DemoDataRelationshipDistribution"])
- Create Task activities: $($answers["DemoDataCreateTasks"])
- Task parent tables: $($answers["DemoDataTaskParentTables"])
- Task scope and source-record limit: $($answers["DemoDataTaskScope"]) -- $($answers["DemoDataTaskSourceRecordLimit"])
- Task ordering: $($answers["DemoDataTaskOrderBy"])
- Tasks per selected record: $($answers["DemoDataTasksPerRecord"])
- Creation method: $($answers["DemoDataMethod"])
- Rerun behavior: $($answers["DemoDataRerunBehavior"])
- Source tag: $($answers["DemoDataSourceTag"])
- Privacy constraints: $($answers["DemoDataPrivacyConstraints"])
- Cleanup/reset instructions: $($answers["DemoDataCleanup"])

$bpfSummaryBlock

$acceleratorAnswersBlock
"@

$retrofitLabel = if ($Retrofit) { " [RETROFIT — reflects current state]" } else { "" }
$retrofitPlanLabel = if ($Retrofit) { " [RETROFIT — captures remaining work only]" } else { "" }

$specContent = @"
# spec.md$retrofitLabel

## Scenario Summary
$($answers["ScenarioName"]) is a $($answers["AppType"]) for $($answers["PlatformArea"]).

## Application Architecture
- Wizard mode: $($answers["WizardMode"])
- Profile: $($answers["ApplicationProfile"])
- Table strategy: $($answers["TableChoice"])
- Form strategy: $($answers["FormStrategy"])
- Entry point: $($answers["EntryPointTable"])
- Landing view: $($answers["EntryPointLandingView"])
- Entry-point validation: $($answers["EntryPointValidationStatus"])
- Landing-view action: $($answers["EntryPointLandingViewPlan"])
- Review app: $($answers["ReviewAppMode"])
- Required app artifacts: $($answers["ReviewAppArtifacts"])
- Power Apps grid: enabled=$($answers["PowerAppsGridEnabled"]); scope=all-views; inline-editing=$($answers["PowerAppsGridEditing"])
- Grid contract: generate and review `grid-controls.json` when enabled; stage 61 is a maker handoff plus exported-solution verification gate, not metadata mutation.

## Problem Statement
$($answers["BusinessProblem"])

## Target Audience
$($answers["TargetAudience"])

## Users
$($answers["Users"])

## Required Data Entities
$($answers["DataEntities"])

### Table Strategy
- **Approach**: $($answers["TableChoice"])
- **Guidance**: See 'docs/standard-dataverse-tables.md' for out-of-box vs custom tables.

## Explicit Entity Mapping (Required)

### Standard reused tables (display -> logical)
$standardTableMapping

### Custom tables to create (input -> generated logical)
$customTableMapping

### Standard fields reused
$standardFieldsList

### Custom fields to add
$customFieldsList

### Relationships to create
$relationshipList

### Relationship decisions
$($answers["RelationshipRequirements"])

### Payload Generation Gate
- Do not generate payloads until this mapping is complete and stakeholder-approved.
- Do not include standard tables in table-creation payloads.
- Reuse out-of-box fields unless a true custom field is required.

### Semantic Field Decisions (Required for Every Use Case)
- Complete field-type-decisions.json before generating any columns payload.
- Follow docs/semantic-field-type-standard.md regardless of industry, wizard mode, table strategy or accelerator choice.
- Include every planned field exactly once, including reused and primary fields; mirror each FIELD decision ID and its decision row in this spec and plan.
- Resolve business meaning, bounded vocabulary, Choice versus Lookup, type settings, stable options, mappings and dependent surfaces.
- Categorical text needs separate explicit approval and documented consequences in both spec and plan.
- The generated semantic inventory is an unapproved draft, not permission to build.

## Optional Report Web Resources
- Enabled: $($answers["IncludeHtmlReports"])
- Report set: $($answers["ReportSet"])
- Visual style: $($answers["ReportTheme"]) tokens with icon-backed KPI cards.
- Integration scope: Create HTML web resources and add them to solution (no automatic form-tab insertion).
- Report scoping status: $($answers["ReportScopingStatus"])
- Critical or high-frequency tables: $($answers["CriticalReportTables"])
- Approved mapping: See report-mappings.md.

## User Tasks
- Task definitions: $($answers["UserTaskDefinitions"])
- Ownership and done definitions: $($answers["UserTaskOwnership"])

## Demo Data Requirements
- Enabled: $($answers["NeedsDemoData"])
- Scope and target tables: $($answers["DemoDataScope"]) -- $($answers["DemoDataTables"])
- Standard reused table strategy: $($answers["DemoDataStandardTableStrategy"])
- Record counts: $($answers["DemoDataRecordCounts"])
- Required scenarios/states: $($answers["DemoDataScenarios"])
- Hero records: $($answers["DemoDataHeroRecords"])
- Relationship distribution: $($answers["DemoDataRelationshipDistribution"])
- Task activity generation: $($answers["DemoDataCreateTasks"]) -- $($answers["DemoDataTaskScope"]) $($answers["DemoDataTaskSourceRecordLimit"]) records per table, ordered by $($answers["DemoDataTaskOrderBy"])
- Synthetic-data/privacy rule: $($answers["DemoDataPrivacyConstraints"])

## Optional Business Process Flow
- Enabled: $($answers["EnableBusinessProcessFlow"])
- Process name: $($answers["BusinessProcessFlowName"])
- Primary entity: $($answers["PrimaryProcessEntity"])
- Target Main form: $($answers["BpfTargetFormName"])
- Cross-table progression: $($answers["BpfCrossTableProgression"])
- Fail if definition incomplete: $($answers["FailIfBpfDefinitionIncomplete"])
- Prefer update existing: $($answers["PreferUpdateExistingBpf"])

### BPF Stage Definitions
$bpfStagesMarkdown

### BPF Generation Gate
- Build a BPF only when the scenario has a real staged lifecycle and the repo contains a matching `process-*.json` definition.
- Every stage must declare required fields, entry criteria, and exit criteria.
- Every cross-table stage must name the supporting relationship payload that justifies the transition.
- If the scenario is CRUD-only, leave BPF disabled and skip generation.

## Required Experience and Artifacts
$($answers["ArtifactsNeeded"])

## Success Criteria
$($answers["SuccessLooksLike"])

## Environment
$($answers["BuildEnvironment"])

## Demo Data Requirement
$($answers["NeedsDemoData"])

## Solution Packaging Decision
$($answers["SolutionType"])

## Solution and Publisher
- Solution: $($answers["SolutionName"]) ($($answers["SolutionChoice"]))
- Publisher prefix: $($answers["PublisherPrefix"]) ($($answers["PrefixChoice"]))

$acceleratorSpecBlock

## Acceptance Criteria
- The scenario is clear and approved.
- Required entities and artifacts are identified.
- Success measures are specific enough to validate.
- The environment and solution type are agreed before implementation.
"@

$planContent = @"
# plan.md$retrofitPlanLabel

## Build Approach
- Wizard mode: $($answers["WizardMode"])
- Application profile: $($answers["ApplicationProfile"])
- Platform area: $($answers["PlatformArea"])
- Environment: $($answers["BuildEnvironment"])
- Solution type: $($answers["SolutionType"])
- Solution unique name: $($answers["SolutionName"]) ($($answers["SolutionChoice"]))
- Publisher prefix: $($answers["PublisherPrefix"]) ($($answers["PrefixChoice"]))

$acceleratorPlanBlock

## Model-Driven App Plan
- Review app mode: $($answers["ReviewAppMode"])
- App name: $($answers["AppName"])
- App unique name: $($answers["AppUniqueName"])
- Navigation group: $($answers["NavigationGroup"])
- Entry-point table: $($answers["EntryPointTable"])
- Default landing view: $($answers["EntryPointLandingView"])
- Entry-point validation: $($answers["EntryPointValidationStatus"])
- Landing-view action: $($answers["EntryPointLandingViewPlan"])
- Form strategy: $($answers["FormStrategy"])
- Power Apps grid decision: enabled=$($answers["PowerAppsGridEnabled"]); table-level scope=all-views; inline-editing=$($answers["PowerAppsGridEditing"])
- Grid implementation: generate `grid-controls.json`, complete the classic solution explorer handoff, then verify exported metadata at stage 61 before app assembly.
- Required artifacts: $($answers["ReviewAppArtifacts"])
$(if ($Retrofit) { @"

## Current State (Already Built)
- Tables/entities already created: $($answers["DataEntities"])
- Artifacts already built: $($answers["ArtifactsNeeded"])

## Remaining Work
- Tables still to create: $($answers["RemainingEntities"])
- Artifacts still to build: $($answers["RemainingArtifacts"])
- Other: $($answers["RemainingWork"])
"@ })
## Proposed Workstreams
1. Discovery review and approval
2. Source-control preflight and scenario branch confirmation
3. Dataverse schema design
4. Forms/views/pages/app experience design
5. Flow/copilot automation design
6. Demo data planning
7. Solution export/unpack and Git checkpoint workflow
8. Optional report web resource design and generation
9. Validation, pull request preparation, and handoff

## User Task Implementation Plan
- Task definitions: $($answers["UserTaskDefinitions"])
- Owners and done definitions: $($answers["UserTaskOwnership"])

## Report Implementation Plan
- Scoping status: $($answers["ReportScopingStatus"])
- Critical or high-frequency tables: $($answers["CriticalReportTables"])
- Mapping artifact: report-mappings.md
- Gate: validate every mapped table, field, and target placement before creating report payloads or HTML sources.

## Demo Data Implementation Plan
- Scope: $($answers["DemoDataScope"])
- Target tables: $($answers["DemoDataTables"])
- Standard reused table strategy: $($answers["DemoDataStandardTableStrategy"])
- Counts: $($answers["DemoDataRecordCounts"])
- Scenarios and states: $($answers["DemoDataScenarios"])
- Hero records: $($answers["DemoDataHeroRecords"])
- Parent/child distribution: $($answers["DemoDataRelationshipDistribution"])
- Create Task activities: $($answers["DemoDataCreateTasks"])
- Task parent tables: $($answers["DemoDataTaskParentTables"])
- Task scope and source-record limit: $($answers["DemoDataTaskScope"]) -- $($answers["DemoDataTaskSourceRecordLimit"])
- Task ordering and count: $($answers["DemoDataTaskOrderBy"]) -- $($answers["DemoDataTasksPerRecord"]) per selected record
- Method: $($answers["DemoDataMethod"])
- Rerun behavior: $($answers["DemoDataRerunBehavior"])
- Source tag: $($answers["DemoDataSourceTag"])
- Privacy constraints: $($answers["DemoDataPrivacyConstraints"])
- Cleanup/reset instructions: $($answers["DemoDataCleanup"])
- Gate: data creation cannot begin until table counts, hero records, relationship distribution, bounded Task activity scope, and synthetic-data constraints are approved.

## Source Control Plan
- Standards: requirements/GithubInstructions_General.md
- Scenario branch: $($answers["SourceControlBranch"])
- Related work: $($answers["SourceControlWorkItem"])
- Commit strategy: $($answers["SourceControlCheckpoints"])
- Required validation/CI: $($answers["SourceControlCiChecks"])
- Pull request handoff: $($answers["SourceControlPullRequest"])
- Merge strategy: $($answers["SourceControlMergeStrategy"])
- Keep remote operations human-approved and verify the remote commit after push.

## Risks to Resolve
- Confirm environment availability and permissions.
- Confirm entity scope and artifact count.
- Confirm whether demo data must be scripted or manual.
- Confirm which entities are standard (out-of-box) and which are custom (to be created).

## Explicit Entity Mapping (Required Before Payloads)

### Standard reused tables (display -> logical)
$standardTableMapping

### Custom tables to create (input -> generated logical)
$customTableMapping

### Standard fields reused
$standardFieldsList

### Custom fields to add
$customFieldsList

### Relationships to create
$relationshipList

### Payload Readiness Rule
- Payload generation is blocked until this mapping is complete and approved.

### Semantic Field Architecture
- Complete and approve field-type-decisions.json under docs/semantic-field-type-standard.md.
- Record each FIELD decision ID and decision row here and in spec.md before column generation.
- Run stage 14 Planning before generation, Payload before build, and Metadata after relationships and before export.
- Stop on metadata drift; plan remediation without changing approved intent or deleting existing columns.
- Verify forms, views, charts, BPFs, automation, integrations and reports against the approved vocabulary.

## Optional Business Process Flow Plan
- Enabled: $($answers["EnableBusinessProcessFlow"])
- Build order dependency: run `55-build-business-process-flows.ps1` after `50-add-to-solution.ps1` and before `60-build-forms-views.ps1`.
- Process definition payload: `payloads/scenarios/$scenarioSlug/process-$scenarioSlug.json`
- Primary entity: $($answers["PrimaryProcessEntity"])
- Target Main form: $($answers["BpfTargetFormName"])
- Cross-table progression: $($answers["BpfCrossTableProgression"])

### Planned stages
$bpfStagesMarkdown

### BPF failure rules
- Fail if the primary entity is ambiguous or missing.
- Fail if any required stage field is missing from payload or explicit field mapping artifacts.
- Fail if any cross-table step is unsupported by a relationship payload.
- Skip BPF if the scenario does not define a real business progression.

## Validation Plan
- Verify artifacts in Maker portal.
- Verify solution export/unpack succeeds.
- Verify git changes are reviewable.
- Verify import into target environment succeeds.
- If HTML reports are enabled, approve html-reports.json against spec.md, plan.md, and report-mappings.md; verify only the approved report definitions are created and visible in solution.
- If BPF is enabled, verify the BPF build report matches the created Dataverse process metadata and the process is added only to the selected solution.
"@

$tasksContent = @"
# tasks.md

## Ordered Tasks

- [ ] Review 'answers.md' with stakeholder
- [ ] Confirm wizard mode '$($answers["WizardMode"])' is appropriate for this run
- [ ] Confirm application profile '$($answers["ApplicationProfile"])' and architecture intent
$acceleratorTasksBlock
- [ ] Confirm entry point '$($answers["EntryPointTable"])' opens with '$($answers["EntryPointLandingView"])'
- [ ] Execute landing-view action '$($answers["EntryPointLandingViewPlan"])' for '$($answers["EntryPointLandingView"])' on '$($answers["EntryPointTable"])' before app assembly
- [ ] Verify the named landing view resolves to a saved query before running '62-build-app-module.ps1'
- [ ] Confirm form strategy '$($answers["FormStrategy"])' for all existing tables
- [ ] Finalize 'spec.md'
- [ ] Finalize 'plan.md'
- [ ] Complete field-type-decisions.json for every planned field and record each FIELD decision in spec/plan
- [ ] Approve semantic types, Choice inventories/mappings and any separately approved categorical text exceptions
- [ ] Pass 14-validate-semantic-fields.ps1 Planning before column generation and Payload before build
- [ ] Validate live types after stage 30, Lookup relationships after 40, and all metadata before export; complete functional surface checks
- [ ] Review source-control standards in 'requirements/GithubInstructions_General.md'
- [ ] Confirm repository, remote, current/default branch, working-tree state, recent history, and applicable validation commands
- [ ] Create or switch to scenario branch '$($answers["SourceControlBranch"])' before implementation; do not absorb unrelated working-tree changes
- [ ] Approve build environment and permissions
- [ ] Review standard table reference: 'docs/standard-dataverse-tables.md'
- [ ] Complete explicit entity mapping in spec/plan (standard reused tables, custom tables to create, standard fields reused, custom fields to add, relationships)
- [ ] Validate relationship cardinality, requiredness, existing/new status, cascade behavior, and supporting task/surface: $($answers["RelationshipRequirements"])
- [ ] Convert approved user tasks into app work with named owners and done definitions: $($answers["UserTaskOwnership"])
- [ ] Map standard names to logical names (for example: Case -> incident, Contact -> contact) before payload design
- [ ] Confirm table payloads include only true custom tables
- [ ] Confirm out-of-box fields are reused unless custom fields are explicitly required
- [ ] Define custom table schemas and payloads
- [ ] Define Dataverse tables and columns for: $($answers["DataEntities"])
- [ ] Define required app artifacts for: $($answers["ArtifactsNeeded"])
- [ ] Review and approve report-mappings.md; every critical table must have an explicit report decision
- [ ] Validate mapped report table logical names, required fields, and target form/dashboard/view placements against the approved schema
- [ ] Create report payload and HTML source tasks for each approved mapping when reports are enabled
- [ ] Validate report data rendering, placement, ownership, and decision-support acceptance criteria for each approved mapping
- [ ] Confirm whether this scenario has a true staged lifecycle requiring a Business Process Flow
- [ ] If BPF is enabled, finalize `process-$scenarioSlug.json` with stage order, required fields, entry criteria, exit criteria, and cross-table relationships
- [ ] Approve demo data table scope and record counts: $($answers["DemoDataTables"]) -- $($answers["DemoDataRecordCounts"])
- [ ] Approve explicit create/reuse-existing/both decisions for standard reused tables: $($answers["DemoDataStandardTableStrategy"])
- [ ] Approve hero records: $($answers["DemoDataHeroRecords"])
- [ ] Approve bounded Task activity generation: $($answers["DemoDataCreateTasks"]) -- parents $($answers["DemoDataTaskParentTables"]), scope $($answers["DemoDataTaskScope"]), limit $($answers["DemoDataTaskSourceRecordLimit"]), order $($answers["DemoDataTaskOrderBy"]), tasks per record $($answers["DemoDataTasksPerRecord"])
- [ ] Approve demo data scenarios, relationship distribution, rerun behavior, source tagging, privacy constraints, and cleanup plan
- [ ] Confirm solution name '$($answers["SolutionName"])' and publisher prefix '$($answers["PublisherPrefix"])' with stakeholder
- [ ] Run 'pwsh ./scripts/bootstrap/00-prereq-check.ps1'
- [ ] Run 'pwsh ./scripts/bootstrap/10-auth-connect.ps1'  # validates solution + prefix via API
- [ ] Build tables with '20-build-tables.ps1'
- [ ] Build columns with '30-build-columns.ps1'
- [ ] Build relationships with '40-build-relationships.ps1'
- [ ] Add components to solution with '50-add-to-solution.ps1'
- [ ] If BPF is enabled, run '55-build-business-process-flows.ps1' and review the generated BPF build report
- [ ] Build starter forms/views with '60-build-forms-views.ps1'
- [ ] If Power Apps grid is enabled, review `grid-controls.json`, run stage 61 Preview, complete the classic solution explorer all-views maker handoff, configure inline editing explicitly, and pass stage 61 Verify against exported metadata before app assembly
- [ ] Create or update the review app with '62-build-app-module.ps1' and validate its entry table and landing view
- [ ] If native dashboards are selected, approve reporting-*.json and run '64-build-charts-dashboard.ps1' before app assembly
- [ ] If HTML reports are selected, review and explicitly approve html-reports.json, then run '70-build-web-resources.ps1'; verify data and planned placement
- [ ] At each approved checkpoint, inspect `git status` and `git diff`, run applicable validation, stage explicit files, and use a typed imperative commit message
- [ ] Export and unpack solution
- [ ] Create the final implementation commit after reviewing staged files and validation evidence
- [ ] Push only after approval, verify the remote branch contains the local commit, and prepare the pull request when enabled
- [ ] Pack and import solution
- [ ] Update 'docs/build-log.md'
"@

foreach ($contentName in @('answersContent', 'specContent', 'planContent', 'tasksContent')) {
    $contentValue = Get-Variable -Name $contentName -ValueOnly
    Set-Variable -Name $contentName -Value "$contentValue`n`n$reportingSelectionBlock`n"
}
Set-Content -Path $answersPath -Value (Remove-MarkdownTrailingWhitespace -Value $answersContent) -Encoding UTF8
Set-Content -Path $specPath -Value (Remove-MarkdownTrailingWhitespace -Value $specContent) -Encoding UTF8
Set-Content -Path $planPath -Value (Remove-MarkdownTrailingWhitespace -Value $planContent) -Encoding UTF8
Set-Content -Path $tasksPath -Value (Remove-MarkdownTrailingWhitespace -Value $tasksContent) -Encoding UTF8
$semanticDraftPath = Join-Path $scenarioFolder 'field-type-decisions.json'
if (-not (Test-Path -LiteralPath $semanticDraftPath)) {
    [ordered]@{
        schemaVersion = '1.0'
        scenarioSlug = $scenarioSlug
        approval = @{ approved = $false; approvedBy = ''; approvedAtUtc = '' }
        fields = @()
        surfaces = @{}
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $semanticDraftPath -Encoding UTF8
}
Set-Content -Path $reportMappingsPath -Value (Remove-MarkdownTrailingWhitespace -Value $reportMappingsContent) -Encoding UTF8
Set-Content -Path $viewsPath -Value $viewsJson -Encoding UTF8
if ($null -ne $gridControlsObject) {
    Set-Content -Path $gridControlsPath -Value $gridControlsJson -Encoding UTF8
} elseif (Test-Path -LiteralPath $gridControlsPath -PathType Leaf) {
    Remove-Item -LiteralPath $gridControlsPath -Force
}
if ($null -ne $demoDataPlanObject) {
    Set-Content -Path $demoDataPlanPath -Value $demoDataPlanJson -Encoding UTF8
}
if ($bpf.Enabled) {
    New-Item -ItemType Directory -Path $scenarioPayloadFolder -Force | Out-Null
    Set-Content -Path $bpfPayloadPath -Value $bpfPayloadJson -Encoding UTF8
}
if ($acceleratorRecommendationsEnabled) {
    $acceleratorPreferenceSchemaPath = Join-Path $implementationRoot 'schemas\accelerators\accelerator-preference.schema.json'
    Write-WizardAcceleratorPreferenceRecord `
        -PreferenceRecord $acceleratorPreferenceRecord `
        -OutputPath $acceleratorPreferencePath `
        -SchemaPath $acceleratorPreferenceSchemaPath
}
if ($acceleratorMatchingRequested) {
    $acceleratorDecisionSchemaPath = Join-Path $implementationRoot 'schemas\accelerators\architecture-decision.schema.json'
    $null = Write-WizardAcceleratorPlanningArtifacts `
        -Evaluation $acceleratorEvaluation `
        -Decision $acceleratorDecision `
        -OutputFolder $acceleratorOutputFolder `
        -SchemaPath $acceleratorDecisionSchemaPath `
        -ApproveDecisionChange:$ApproveAcceleratorDecisionChange
}

Write-Host ""
Write-Host "Wizard output created:" -ForegroundColor Green
Write-Host "  $answersPath"
Write-Host "  $specPath"
Write-Host "  $planPath"
Write-Host "  $tasksPath"
Write-Host "  $reportMappingsPath"
Write-Host "  $viewsPath"
if ($null -ne $gridControlsObject) {
    Write-Host "  $gridControlsPath"
}
if ($null -ne $demoDataPlanObject) {
    Write-Host "  $demoDataPlanPath"
}
if ($bpf.Enabled) {
    Write-Host "  $bpfPayloadPath"
}
if ($acceleratorRecommendationsEnabled) {
    Write-Host "  $acceleratorPreferencePath"
}
if ($acceleratorMatchingRequested) {
    Write-Host "  $acceleratorDecisionPath"
    Write-Host "  $acceleratorDecisionMarkdownPath"
}
Write-Host "  $envFilePath  (planning values for 10-auth-connect.ps1)"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
if ($Retrofit) {
    Write-Host "  1. Review spec.md — confirm it reflects current state accurately."
    Write-Host "  2. Review plan.md — confirm remaining work is complete and correct."
    Write-Host "  3. Generate a demo script: pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug $scenarioSlug"
    Write-Host "  4. Get stakeholder approval on current state + remaining work."
    Write-Host "  5. Then run: pwsh ./scripts/bootstrap/00-prereq-check.ps1"
} else {
    Write-Host "  1. Review and refine the generated files."
    Write-Host "  2. Generate a demo script: pwsh ./scripts/bootstrap/06-demo-script-wizard.ps1 -ScenarioSlug $scenarioSlug"
    Write-Host "  3. Get approval on scope, success criteria, and demo story."
    Write-Host "  4. Then run: pwsh ./scripts/bootstrap/00-prereq-check.ps1"
}
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Wizard files generated."
}