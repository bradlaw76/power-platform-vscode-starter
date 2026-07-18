<#
.SYNOPSIS
    Builds a run matrix from disclosed wizard step telemetry events.

.DESCRIPTION
    Reads .wizard-metrics/events.jsonl, groups events by run, and prints a matrix
    showing which bootstrap steps each run reached or completed.

.PARAMETER RepoRoot
    Optional repository root. Defaults to the current script parent traversal.

.PARAMETER EventsPath
    Optional explicit path to an events.jsonl file.

.PARAMETER OutputPath
    Optional path to save the generated matrix. Defaults to
    .wizard-metrics/build-progress-matrix.md when Format is Markdown.

.PARAMETER Format
    Output format. Defaults to Markdown.

.EXAMPLE
    pwsh ./scripts/bootstrap/81-build-progress-matrix.ps1
#>

param(
    [string]$RepoRoot = '',
    [string]$EventsPath = '',
    [string]$OutputPath = '',
    [ValidateSet('Markdown', 'Table', 'Json')]
    [string]$Format = 'Markdown',
    [switch]$IgnoreProfileEstimates,
    [int]$IdleGapMinutes = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$defaultEstimatedMinutesSavedByStep = @{
    '00' = 5
    '01' = 8
    '05' = 20
    '06' = 12
    '07' = 8
    '10' = 20
    '15' = 10
    '20' = 25
    '30' = 20
    '40' = 20
    '50' = 15
    '60' = 30
    '65' = 20
    '80' = 10
}

$profileEstimatedMinutesSavedByStep = @{}
if (-not $IgnoreProfileEstimates) {
    $profilePath = Join-Path $RepoRoot 'wizard.profile.json'
    if (Test-Path $profilePath) {
        try {
            $profile = Get-Content -Path $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $estimateNode = $profile.execution.telemetry.estimatedMinutesSavedByStep
            if ($null -ne $estimateNode) {
                foreach ($prop in $estimateNode.PSObject.Properties) {
                    $minutes = 0
                    if ([int]::TryParse("$($prop.Value)", [ref]$minutes) -and $minutes -ge 0) {
                        $profileEstimatedMinutesSavedByStep[$prop.Name] = $minutes
                    }
                }
            }
        } catch {
            Write-Host "Warning: unable to parse estimatedMinutesSavedByStep from wizard.profile.json. Using defaults." -ForegroundColor Yellow
        }
    }
}

$telemetryHelper = Join-Path $PSScriptRoot 'helpers\wizard-telemetry.ps1'
. $telemetryHelper

$pathInfo = Get-WizardTelemetryPathInfo -RepoRoot $RepoRoot
if ([string]::IsNullOrWhiteSpace($EventsPath)) {
    $EventsPath = $pathInfo.EventsPath
}

if (-not (Test-Path $EventsPath)) {
    Write-Host "No telemetry events found at $EventsPath" -ForegroundColor Yellow
    exit 0
}

$events = New-Object System.Collections.Generic.List[object]
foreach ($line in Get-Content -Path $EventsPath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    try {
        [void]$events.Add(($line | ConvertFrom-Json))
    } catch {
        Write-Host "Skipping unreadable telemetry line in $EventsPath" -ForegroundColor Yellow
    }
}

if ($events.Count -eq 0) {
    Write-Host 'No readable telemetry events were found.' -ForegroundColor Yellow
    exit 0
}

$catalog = @(Get-WizardTelemetryCatalog | Sort-Object StepOrder)
$rows = New-Object System.Collections.Generic.List[object]
$runAnalytics = New-Object System.Collections.Generic.List[object]
$stepDurationsByCode = @{}
$dropOffCounts = @{}
$completionByDay = @{}
$optionalUsageCounts = @{ '06' = 0; '07' = 0; '65' = 0 }
$pathUsageCounts = @{ CoreOnly = 0; CorePlusOptional = 0 }
$totalFailedStepEvents = 0
$parseIssueCount = 0
$errorCategoryCounts = @{}
$runStepRetryAccumulator = 0
$runStepCountAccumulator = 0
$rerunSuccessNumerator = 0
$rerunSuccessDenominator = 0
$runCompletionCount = 0
$workflowCompletionCount = 0
$buildCompletionCount = 0

$coreCompletionStepCodes = @('00', '10', '20', '30', '40', '50', '60')
$workflowCompletionStepCodes = @($coreCompletionStepCodes + '80')
$optionalStepCodes = @('06', '07', '65')

if ($IdleGapMinutes -lt 0) { $IdleGapMinutes = 0 }
$idleGapThresholdSeconds = [math]::Round($IdleGapMinutes * 60.0, 2)

function Get-EstimatedMinutesForStepCode {
    param([string]$StepCode)

    if ($profileEstimatedMinutesSavedByStep.ContainsKey($StepCode)) {
        return [int]$profileEstimatedMinutesSavedByStep[$StepCode]
    }

    if ($defaultEstimatedMinutesSavedByStep.ContainsKey($StepCode)) {
        return [int]$defaultEstimatedMinutesSavedByStep[$StepCode]
    }

    return 0
}

function Get-Percentile {
    param(
        [double[]]$Values,
        [double]$Percent
    )

    if ($null -eq $Values -or $Values.Count -eq 0) {
        return 0
    }

    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 1) {
        return [math]::Round($sorted[0], 1)
    }

    $rank = ($Percent / 100.0) * ($sorted.Count - 1)
    $lowerIndex = [math]::Floor($rank)
    $upperIndex = [math]::Ceiling($rank)
    if ($lowerIndex -eq $upperIndex) {
        return [math]::Round($sorted[$lowerIndex], 1)
    }

    $weight = $rank - $lowerIndex
    $interpolated = $sorted[$lowerIndex] + (($sorted[$upperIndex] - $sorted[$lowerIndex]) * $weight)
    return [math]::Round($interpolated, 1)
}

function Add-CountValue {
    param(
        [hashtable]$Map,
        [string]$Key,
        [int]$Amount = 1
    )

    if ([string]::IsNullOrWhiteSpace($Key)) { return }
    if ($Map.ContainsKey($Key)) {
        $Map[$Key] = [int]$Map[$Key] + $Amount
    } else {
        $Map[$Key] = $Amount
    }
}

foreach ($runGroup in ($events | Group-Object RunId | Sort-Object Name)) {
    $runEntries = @($runGroup.Group | Sort-Object TimestampUtc)
    $firstEntry = $runEntries[0]
    $lastEntry = $runEntries[-1]
    $latestByStep = @{}

    foreach ($runEntry in $runEntries) {
        $latestByStep[$runEntry.StepKey] = $runEntry
    }

    $completedSteps = @($latestByStep.Values | Where-Object { $_.Status -eq 'Completed' } | Sort-Object StepOrder)
    $highestCompleted = if ($completedSteps.Count -gt 0) { $completedSteps[-1].StepCode } else { '-' }
    $currentStep = if ($null -ne $lastEntry) { $lastEntry.StepCode } else { '-' }
    $completedEventEntries = @($runEntries | Where-Object { $_.Status -eq 'Completed' } | Sort-Object TimestampUtc)

    $startedAt = [DateTime]::MinValue
    $startedAtDisplay = $firstEntry.TimestampUtc
    if ([DateTime]::TryParse("$($firstEntry.TimestampUtc)", [ref]$startedAt)) {
        $startedAtDisplay = $startedAt.ToString('yyyy-MM-dd HH:mm:ss')
    }

    $lastAt = [DateTime]::MinValue
    $lastAtDisplay = $lastEntry.TimestampUtc
    if ([DateTime]::TryParse("$($lastEntry.TimestampUtc)", [ref]$lastAt)) {
        $lastAtDisplay = $lastAt.ToString('yyyy-MM-dd HH:mm:ss')
    }

    $completedAtDisplay = '-'
    if ($completedEventEntries.Count -gt 0) {
        $completedAt = [DateTime]::MinValue
        if ([DateTime]::TryParse("$($completedEventEntries[-1].TimestampUtc)", [ref]$completedAt)) {
            $completedAtDisplay = $completedAt.ToString('yyyy-MM-dd HH:mm:ss')
        } else {
            $completedAtDisplay = "$($completedEventEntries[-1].TimestampUtc)"
        }
    }

    $runDurationMin = '-'
    $runDurationSeconds = 0.0
    if ($startedAt -ne [DateTime]::MinValue -and $lastAt -ne [DateTime]::MinValue -and $lastAt -ge $startedAt) {
        $runDurationSeconds = [math]::Round(($lastAt - $startedAt).TotalSeconds, 1)
        $runDurationMin = [math]::Round(($lastAt - $startedAt).TotalMinutes, 1)
    }

    $activeSeconds = 0.0
    if ($runEntries.Count -gt 1) {
        for ($i = 0; $i -lt ($runEntries.Count - 1); $i++) {
            $a = [DateTime]::MinValue
            $b = [DateTime]::MinValue
            if ([DateTime]::TryParse("$($runEntries[$i].TimestampUtc)", [ref]$a) -and [DateTime]::TryParse("$($runEntries[$i + 1].TimestampUtc)", [ref]$b)) {
                $gap = [math]::Max(0, ($b - $a).TotalSeconds)
                $activeSeconds += [math]::Min($gap, $idleGapThresholdSeconds)
            }
        }
    }
    $activeMinutes = [math]::Round(($activeSeconds / 60.0), 1)
    $waitingMinutes = if ($runDurationSeconds -gt 0) { [math]::Round(([math]::Max(0, $runDurationSeconds - $activeSeconds) / 60.0), 1) } else { 0 }

    $estimatedMinutesSaved = 0
    $failedSteps = New-Object System.Collections.Generic.List[string]
    $startedNotCompleted = New-Object System.Collections.Generic.List[string]
    $optionalUsed = New-Object System.Collections.Generic.List[string]
    $errorCategoriesForRun = New-Object System.Collections.Generic.List[string]

    $stepAttemptCounts = @{}
    $stepHadFailureThenCompleted = @{}

    foreach ($entry in $catalog) {
        $stepEntries = @($runEntries | Where-Object { $_.StepCode -eq $entry.StepCode } | Sort-Object TimestampUtc)
        $attemptCount = @($stepEntries | Where-Object { $_.Status -eq 'Started' }).Count
        $stepAttemptCounts[$entry.StepCode] = $attemptCount
        if ($attemptCount -gt 0) {
            $runStepCountAccumulator += 1
            $runStepRetryAccumulator += [math]::Max(0, ($attemptCount - 1))
        }

        $hadFailure = @($stepEntries | Where-Object { $_.Status -eq 'Failed' }).Count -gt 0
        $hadCompletion = @($stepEntries | Where-Object { $_.Status -eq 'Completed' }).Count -gt 0
        if ($hadFailure) {
            $rerunSuccessDenominator += 1
            if ($hadCompletion) {
                $rerunSuccessNumerator += 1
                $stepHadFailureThenCompleted[$entry.StepCode] = $true
            }
        }

        $stepStartedAt = [DateTime]::MinValue
        $stepEndedAt = [DateTime]::MinValue
        $startedEvent = @($stepEntries | Where-Object { $_.Status -eq 'Started' } | Select-Object -First 1)
        $terminalEvent = @($stepEntries | Where-Object { $_.Status -match 'Completed|Failed' } | Select-Object -Last 1)
        if ($startedEvent.Count -gt 0 -and $terminalEvent.Count -gt 0) {
            if ([DateTime]::TryParse("$($startedEvent[0].TimestampUtc)", [ref]$stepStartedAt) -and [DateTime]::TryParse("$($terminalEvent[0].TimestampUtc)", [ref]$stepEndedAt) -and $stepEndedAt -ge $stepStartedAt) {
                $durationSeconds = [math]::Round(($stepEndedAt - $stepStartedAt).TotalSeconds, 1)
                if (-not $stepDurationsByCode.ContainsKey($entry.StepCode)) {
                    $stepDurationsByCode[$entry.StepCode] = New-Object System.Collections.Generic.List[double]
                }
                $stepDurationsByCode[$entry.StepCode].Add($durationSeconds)
            }
        }
    }

    foreach ($entry in $catalog) {
        if ($latestByStep.ContainsKey($entry.StepKey)) {
            $status = "$($latestByStep[$entry.StepKey].Status)"
            if ($status -eq 'Completed') {
                $estimatedMinutesSaved += Get-EstimatedMinutesForStepCode -StepCode $entry.StepCode
                if ($optionalStepCodes -contains $entry.StepCode) {
                    $optionalUsed.Add($entry.StepCode)
                    if ($optionalUsageCounts.ContainsKey($entry.StepCode)) {
                        $optionalUsageCounts[$entry.StepCode] = [int]$optionalUsageCounts[$entry.StepCode] + 1
                    }
                }
            }
            if ($status -eq 'Failed') {
                $failedSteps.Add($entry.StepCode)
                $totalFailedStepEvents += 1
                $category = "$($latestByStep[$entry.StepKey].ErrorCategory)"
                if ([string]::IsNullOrWhiteSpace($category) -or $category -eq '-') {
                    $category = 'unknown'
                }
                Add-CountValue -Map $errorCategoryCounts -Key $category
                $errorCategoriesForRun.Add($category)
            }
        }

        $startedCount = @($runEntries | Where-Object { $_.StepCode -eq $entry.StepCode -and $_.Status -eq 'Started' }).Count
        $completedCount = @($runEntries | Where-Object { $_.StepCode -eq $entry.StepCode -and $_.Status -eq 'Completed' }).Count
        if ($startedCount -gt 0 -and $completedCount -eq 0) {
            $startedNotCompleted.Add($entry.StepCode)
        }
    }

    $estimatedHoursSaved = [math]::Round(($estimatedMinutesSaved / 60.0), 2)

    $dropOffStep = '-'
    if ($startedNotCompleted.Count -gt 0) {
        $dropOffStep = ($startedNotCompleted | Sort-Object {[int]$_} | Select-Object -First 1)
        Add-CountValue -Map $dropOffCounts -Key $dropOffStep
    }

    $buildComplete = $true
    foreach ($requiredStep in $coreCompletionStepCodes) {
        if (-not ($runEntries | Where-Object { $_.StepCode -eq $requiredStep -and $_.Status -eq 'Completed' } | Select-Object -First 1)) {
            $buildComplete = $false
            break
        }
    }

    $workflowComplete = $true
    foreach ($requiredStep in $workflowCompletionStepCodes) {
        if (-not ($runEntries | Where-Object { $_.StepCode -eq $requiredStep -and $_.Status -eq 'Completed' } | Select-Object -First 1)) {
            $workflowComplete = $false
            break
        }
    }

    $completionStatus = if ($workflowComplete) { 'WorkflowComplete' } elseif ($buildComplete) { 'BuildComplete' } elseif ($failedSteps.Count -gt 0) { 'Failed' } else { 'InProgress' }
    $runCompletionCount += 1
    if ($buildComplete) { $buildCompletionCount += 1 }
    if ($workflowComplete) { $workflowCompletionCount += 1 }

    if ($optionalUsed.Count -gt 0) {
        $pathUsageCounts.CorePlusOptional += 1
    } else {
        $pathUsageCounts.CoreOnly += 1
    }

    $startedDateKey = if ($startedAt -ne [DateTime]::MinValue) { $startedAt.ToString('yyyy-MM-dd') } else { 'unknown' }
    if (-not $completionByDay.ContainsKey($startedDateKey)) {
        $completionByDay[$startedDateKey] = [ordered]@{ Runs = 0; BuildComplete = 0; WorkflowComplete = 0 }
    }
    $completionByDay[$startedDateKey].Runs += 1
    if ($buildComplete) { $completionByDay[$startedDateKey].BuildComplete += 1 }
    if ($workflowComplete) { $completionByDay[$startedDateKey].WorkflowComplete += 1 }

    $profileVersion = "$($lastEntry.ProfileVersion)"
    if ([string]::IsNullOrWhiteSpace($profileVersion)) { $profileVersion = 'unknown' }
    $contractVersion = "$($lastEntry.ContractVersion)"
    if ([string]::IsNullOrWhiteSpace($contractVersion)) { $contractVersion = 'unknown' }
    $repoRevision = "$($lastEntry.RepoRevision)"
    if ([string]::IsNullOrWhiteSpace($repoRevision)) { $repoRevision = 'unknown' }
    $telemetrySchemaVersion = "$($lastEntry.TelemetrySchemaVersion)"
    if ([string]::IsNullOrWhiteSpace($telemetrySchemaVersion)) { $telemetrySchemaVersion = 'unknown' }

    $retriesForRun = 0
    foreach ($code in $stepAttemptCounts.Keys) {
        $retriesForRun += [math]::Max(0, ([int]$stepAttemptCounts[$code] - 1))
    }

    $row = [ordered]@{
        RunId = if ($runGroup.Name.Length -gt 8) { $runGroup.Name.Substring(0, 8) } else { $runGroup.Name }
        StartedDate = if ($startedAt -ne [DateTime]::MinValue) { $startedAt.ToString('yyyy-MM-dd') } else { '-' }
        StartedUtc = $startedAtDisplay
        LastEventUtc = $lastAtDisplay
        CompletedUtc = $completedAtDisplay
        RunDurationMin = $runDurationMin
        ActiveMinutes = $activeMinutes
        WaitingMinutes = $waitingMinutes
        EstimatedSavedMin = $estimatedMinutesSaved
        EstimatedSavedHours = $estimatedHoursSaved
        CompletionStatus = $completionStatus
        DropOffStep = $dropOffStep
        FailedSteps = if ($failedSteps.Count -gt 0) { ($failedSteps | Sort-Object -Unique) -join ',' } else { '-' }
        RetryCount = $retriesForRun
        ErrorCategories = if ($errorCategoriesForRun.Count -gt 0) { ($errorCategoriesForRun | Sort-Object -Unique) -join ',' } else { '-' }
        OptionalModulesUsed = if ($optionalUsed.Count -gt 0) { ($optionalUsed | Sort-Object -Unique) -join ',' } else { '-' }
        ProfileVersion = $profileVersion
        ContractVersion = $contractVersion
        RepoRevision = $repoRevision
        TelemetrySchemaVersion = $telemetrySchemaVersion
        HighestCompleted = $highestCompleted
        CurrentStep = $currentStep
    }

    foreach ($entry in $catalog) {
        $stepEntry = $null
        if ($latestByStep.ContainsKey($entry.StepKey)) {
            $stepEntry = $latestByStep[$entry.StepKey]
        }

        $value = '-'
        if ($null -ne $stepEntry) {
            switch ($stepEntry.Status) {
                'Completed' { $value = 'done' }
                'Failed' { $value = 'fail' }
                'Started' { $value = 'start' }
                default { $value = $stepEntry.Status }
            }
        }

        $row[$entry.StepCode] = $value
    }

    [void]$rows.Add([pscustomobject]$row)
    [void]$runAnalytics.Add([pscustomobject]@{
        RunId = $row.RunId
        CompletionStatus = $completionStatus
        DropOffStep = $dropOffStep
        RetryCount = $retriesForRun
        ActiveMinutes = $activeMinutes
        WaitingMinutes = $waitingMinutes
        RunDurationMin = if ($runDurationMin -eq '-') { 0 } else { [double]$runDurationMin }
        EstimatedSavedMin = $estimatedMinutesSaved
        OptionalModulesUsed = $row.OptionalModulesUsed
        StartedDate = $row.StartedDate
    })
}

function Convert-RowsToMarkdown {
    param(
        [object[]]$InputRows,
        [object[]]$Catalog
    )

    $headers = @('RunId', 'StartedDate', 'StartedUtc', 'LastEventUtc', 'CompletedUtc', 'RunDurationMin', 'ActiveMinutes', 'WaitingMinutes', 'EstimatedSavedMin', 'EstimatedSavedHours', 'CompletionStatus', 'DropOffStep', 'FailedSteps', 'RetryCount', 'ErrorCategories', 'OptionalModulesUsed', 'ProfileVersion', 'ContractVersion', 'RepoRevision', 'TelemetrySchemaVersion', 'HighestCompleted', 'CurrentStep') + @($Catalog | ForEach-Object { $_.StepCode })
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Wizard Progress Matrix') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| ' + ($headers -join ' | ') + ' |') | Out-Null
    $lines.Add('| ' + (($headers | ForEach-Object { '---' }) -join ' | ') + ' |') | Out-Null

    foreach ($row in $InputRows) {
        $values = foreach ($header in $headers) {
            $row.$header
        }
        $lines.Add('| ' + ($values -join ' | ') + ' |') | Out-Null
    }

    return ($lines -join [Environment]::NewLine)
}

function Convert-SummaryToMarkdown {
    param(
        [object[]]$Catalog,
        [object[]]$RunRows,
        [System.Collections.Generic.List[object]]$RunAnalyticsRows
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('') | Out-Null
    $lines.Add('## Analytics Summary') | Out-Null
    $lines.Add('') | Out-Null

    $runCount = $RunRows.Count
    $buildCompletionRate = if ($runCount -gt 0) { [math]::Round((100.0 * $buildCompletionCount / $runCount), 1) } else { 0 }
    $workflowCompletionRate = if ($runCount -gt 0) { [math]::Round((100.0 * $workflowCompletionCount / $runCount), 1) } else { 0 }
    $avgRetriesPerStep = if ($runStepCountAccumulator -gt 0) { [math]::Round(($runStepRetryAccumulator / [double]$runStepCountAccumulator), 2) } else { 0 }
    $rerunSuccessRate = if ($rerunSuccessDenominator -gt 0) { [math]::Round((100.0 * $rerunSuccessNumerator / $rerunSuccessDenominator), 1) } else { 0 }

    $totalEstimatedSavedMinutes = ($RunRows | Measure-Object -Property EstimatedSavedMin -Sum).Sum
    if ($null -eq $totalEstimatedSavedMinutes) { $totalEstimatedSavedMinutes = 0 }
    $totalEstimatedSavedHours = [math]::Round(($totalEstimatedSavedMinutes / 60.0), 2)

    $totalActiveMinutes = ($RunAnalyticsRows | Measure-Object -Property ActiveMinutes -Sum).Sum
    if ($null -eq $totalActiveMinutes) { $totalActiveMinutes = 0 }
    $totalWaitingMinutes = ($RunAnalyticsRows | Measure-Object -Property WaitingMinutes -Sum).Sum
    if ($null -eq $totalWaitingMinutes) { $totalWaitingMinutes = 0 }

    $lines.Add('### Funnel and Value') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Runs: $runCount") | Out-Null
    $lines.Add("- Build completion rate: $buildCompletionRate%") | Out-Null
    $lines.Add("- Workflow completion rate: $workflowCompletionRate%") | Out-Null
    $lines.Add("- Total estimated time saved: $totalEstimatedSavedMinutes min ($totalEstimatedSavedHours h)") | Out-Null
    $lines.Add("- Total active minutes: $([math]::Round($totalActiveMinutes,1))") | Out-Null
    $lines.Add("- Total waiting minutes: $([math]::Round($totalWaitingMinutes,1))") | Out-Null

    $lines.Add('') | Out-Null
    $lines.Add('### Reliability') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Failed step events: $totalFailedStepEvents") | Out-Null
    $lines.Add("- Average retries per started step: $avgRetriesPerStep") | Out-Null
    $lines.Add("- Rerun success rate (failed then later completed): $rerunSuccessRate%") | Out-Null

    $lines.Add('') | Out-Null
    $lines.Add('### Adoption') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Core-only runs: $($pathUsageCounts.CoreOnly)") | Out-Null
    $lines.Add("- Core+optional runs: $($pathUsageCounts.CorePlusOptional)") | Out-Null
    $lines.Add("- Optional step usage 06-demo-script-wizard: $($optionalUsageCounts['06'])") | Out-Null
    $lines.Add("- Optional step usage 07-demo-dry-run: $($optionalUsageCounts['07'])") | Out-Null
    $lines.Add("- Optional step usage 65/70-web-resources: $($optionalUsageCounts['65'])") | Out-Null

    $lines.Add('') | Out-Null
    $lines.Add('### Error Categories') | Out-Null
    $lines.Add('') | Out-Null
    if ($errorCategoryCounts.Count -eq 0) {
        $lines.Add('- No failures captured.') | Out-Null
    } else {
        foreach ($kv in ($errorCategoryCounts.GetEnumerator() | Sort-Object Name)) {
            $lines.Add("- $($kv.Name): $($kv.Value)") | Out-Null
        }
    }

    $lines.Add('') | Out-Null
    $lines.Add('### Drop-Off Distribution') | Out-Null
    $lines.Add('') | Out-Null
    if ($dropOffCounts.Count -eq 0) {
        $lines.Add('- No drop-off steps captured.') | Out-Null
    } else {
        foreach ($kv in ($dropOffCounts.GetEnumerator() | Sort-Object Name)) {
            $lines.Add("- Step $($kv.Name): $($kv.Value)") | Out-Null
        }
    }

    $lines.Add('') | Out-Null
    $lines.Add('### Duration Metrics by Step (seconds)') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Step | Samples | Median | P90 |') | Out-Null
    $lines.Add('| --- | --- | --- | --- |') | Out-Null
    foreach ($entry in $Catalog) {
        $samples = @()
        if ($stepDurationsByCode.ContainsKey($entry.StepCode)) {
            $samples = $stepDurationsByCode[$entry.StepCode].ToArray()
        }
        $sampleCount = $samples.Count
        $median = if ($sampleCount -gt 0) { Get-Percentile -Values $samples -Percent 50 } else { 0 }
        $p90 = if ($sampleCount -gt 0) { Get-Percentile -Values $samples -Percent 90 } else { 0 }
        $lines.Add("| $($entry.StepCode) | $sampleCount | $median | $p90 |") | Out-Null
    }

    $lines.Add('') | Out-Null
    $lines.Add('### Completion by Day') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Date | Runs | BuildComplete | WorkflowComplete | BuildCompleteRate | WorkflowCompleteRate |') | Out-Null
    $lines.Add('| --- | --- | --- | --- | --- | --- |') | Out-Null
    foreach ($key in ($completionByDay.Keys | Sort-Object)) {
        $row = $completionByDay[$key]
        $runs = [int]$row.Runs
        $build = [int]$row.BuildComplete
        $workflow = [int]$row.WorkflowComplete
        $buildRate = if ($runs -gt 0) { [math]::Round((100.0 * $build / $runs), 1) } else { 0 }
        $workflowRate = if ($runs -gt 0) { [math]::Round((100.0 * $workflow / $runs), 1) } else { 0 }
        $lines.Add("| $key | $runs | $build | $workflow | $buildRate% | $workflowRate% |") | Out-Null
    }

    $privacyCounters = $null
    if (Test-Path $pathInfo.PrivacyPath) {
        try {
            $privacyCounters = Get-Content -Path $pathInfo.PrivacyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            $parseIssueCount += 1
        }
    }

    $lines.Add('') | Out-Null
    $lines.Add('### Governance and Data Quality') | Out-Null
    $lines.Add('') | Out-Null
    if ($null -ne $privacyCounters) {
        $optIn = [int]$privacyCounters.OptInExecutions
        $optOut = [int]$privacyCounters.OptOutExecutions
        $total = $optIn + $optOut
        $optOutRate = if ($total -gt 0) { [math]::Round((100.0 * $optOut / $total), 1) } else { 0 }
        $lines.Add("- Opt-in executions: $optIn") | Out-Null
        $lines.Add("- Opt-out executions: $optOut") | Out-Null
        $lines.Add("- Opt-out rate: $optOutRate%") | Out-Null
    } else {
        $lines.Add('- Privacy counters not available yet.') | Out-Null
    }
    $lines.Add("- Event parse issues detected during this report: $parseIssueCount") | Out-Null

    return ($lines -join [Environment]::NewLine)
}

function Get-StepDurationStats {
    param(
        [object[]]$Catalog
    )

    $stats = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $Catalog) {
        $samples = @()
        if ($stepDurationsByCode.ContainsKey($entry.StepCode)) {
            $samples = $stepDurationsByCode[$entry.StepCode].ToArray()
        }
        $sampleCount = $samples.Count
        $median = if ($sampleCount -gt 0) { Get-Percentile -Values $samples -Percent 50 } else { 0 }
        $p90 = if ($sampleCount -gt 0) { Get-Percentile -Values $samples -Percent 90 } else { 0 }

        [void]$stats.Add([pscustomobject]@{
            StepCode = $entry.StepCode
            Samples = $sampleCount
            MedianSeconds = $median
            P90Seconds = $p90
        })
    }

    return $stats.ToArray()
}

switch ($Format) {
    'Json' {
        $stepDurationStats = Get-StepDurationStats -Catalog $catalog
        $summaryObject = [ordered]@{
            runs = $rows
            dropOffCounts = $dropOffCounts
            errorCategoryCounts = $errorCategoryCounts
            optionalUsageCounts = $optionalUsageCounts
            completionByDay = $completionByDay
            stepDurationStats = $stepDurationStats
        }
        $output = $summaryObject | ConvertTo-Json -Depth 10
    }
    'Table' {
        $output = ($rows | Format-Table -AutoSize | Out-String).TrimEnd()
    }
    default {
        $matrixMarkdown = Convert-RowsToMarkdown -InputRows $rows.ToArray() -Catalog $catalog
        $summaryMarkdown = Convert-SummaryToMarkdown -Catalog $catalog -RunRows $rows.ToArray() -RunAnalyticsRows $runAnalytics
        $output = $matrixMarkdown + [Environment]::NewLine + $summaryMarkdown
    }
}

if ([string]::IsNullOrWhiteSpace($OutputPath) -and $Format -eq 'Markdown') {
    $OutputPath = $pathInfo.MatrixPath
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $output | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "Matrix written to: $OutputPath" -ForegroundColor Green
}

Write-Output $output
