Set-StrictMode -Version Latest

$script:WizardTelemetryContext = $null

function Test-WizardTelemetryOptOut {
    $value = [Environment]::GetEnvironmentVariable('WIZARD_METRICS_OPTOUT')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }

    return @('1', 'true', 'yes', 'y') -contains $value.Trim().ToLowerInvariant()
}

function Get-WizardTelemetryCatalog {
    return @(
        [pscustomobject]@{ StepKey = '00-prereq-check'; StepCode = '00'; StepOrder = 0; DisplayName = 'Prereq'; ScriptNames = @('00-prereq-check.ps1') }
        [pscustomobject]@{ StepKey = '01-install-skills'; StepCode = '01'; StepOrder = 1; DisplayName = 'Skills'; ScriptNames = @('01-install-skills.ps1') }
        [pscustomobject]@{ StepKey = '05-start-wizard'; StepCode = '05'; StepOrder = 2; DisplayName = 'Wizard'; ScriptNames = @('05-start-wizard.ps1') }
        [pscustomobject]@{ StepKey = '06-demo-script-wizard'; StepCode = '06'; StepOrder = 3; DisplayName = 'Demo Script'; ScriptNames = @('06-demo-script-wizard.ps1') }
        [pscustomobject]@{ StepKey = '07-demo-dry-run'; StepCode = '07'; StepOrder = 4; DisplayName = 'Dry Run'; ScriptNames = @('07-demo-dry-run.ps1') }
        [pscustomobject]@{ StepKey = '10-auth-connect'; StepCode = '10'; StepOrder = 5; DisplayName = 'Auth'; ScriptNames = @('10-auth-connect.ps1') }
        [pscustomobject]@{ StepKey = '15-dry-validate'; StepCode = '15'; StepOrder = 6; DisplayName = 'Validate'; ScriptNames = @('15-dry-validate.ps1') }
        [pscustomobject]@{ StepKey = '20-build-tables'; StepCode = '20'; StepOrder = 7; DisplayName = 'Tables'; ScriptNames = @('20-build-tables.ps1') }
        [pscustomobject]@{ StepKey = '30-build-columns'; StepCode = '30'; StepOrder = 8; DisplayName = 'Columns'; ScriptNames = @('30-build-columns.ps1') }
        [pscustomobject]@{ StepKey = '40-build-relationships'; StepCode = '40'; StepOrder = 9; DisplayName = 'Relationships'; ScriptNames = @('40-build-relationships.ps1') }
        [pscustomobject]@{ StepKey = '50-add-to-solution'; StepCode = '50'; StepOrder = 10; DisplayName = 'Solution'; ScriptNames = @('50-add-to-solution.ps1') }
        [pscustomobject]@{ StepKey = '60-build-forms-views'; StepCode = '60'; StepOrder = 11; DisplayName = 'Forms/Views'; ScriptNames = @('60-build-forms-views.ps1') }
        [pscustomobject]@{ StepKey = '65-build-web-resources'; StepCode = '65'; StepOrder = 12; DisplayName = 'Web Resources'; ScriptNames = @('65-build-web-resources.ps1', '70-build-web-resources.ps1') }
        [pscustomobject]@{ StepKey = '80-post-build-analysis'; StepCode = '80'; StepOrder = 13; DisplayName = 'Summary'; ScriptNames = @('80-post-build-analysis.ps1') }
    )
}

function Get-WizardTelemetryStepInfo {
    param([string]$StepName)

    foreach ($entry in Get-WizardTelemetryCatalog) {
        if ($entry.ScriptNames -contains $StepName) {
            return $entry
        }
    }

    return [pscustomobject]@{
        StepKey     = [System.IO.Path]::GetFileNameWithoutExtension($StepName)
        StepCode    = '--'
        StepOrder   = 999
        DisplayName = [System.IO.Path]::GetFileNameWithoutExtension($StepName)
        ScriptNames = @($StepName)
    }
}

function Get-WizardTelemetryPathInfo {
    param([string]$RepoRoot)

    $metricsRoot = Join-Path $RepoRoot '.wizard-metrics'
    return [pscustomobject]@{
        RootPath       = $metricsRoot
        EventsPath     = Join-Path $metricsRoot 'events.jsonl'
        CurrentRunPath = Join-Path $metricsRoot 'current-run.json'
        MatrixPath     = Join-Path $metricsRoot 'build-progress-matrix.md'
        PrivacyPath    = Join-Path $metricsRoot 'privacy-counters.json'
    }
}

function Get-WizardTelemetryMetadata {
    param([string]$RepoRoot)

    $metadata = [ordered]@{
        TelemetrySchemaVersion = '2.0'
        ProfileVersion         = 'unknown'
        ContractVersion        = 'unknown'
        RepoRevision           = 'unknown'
    }

    $profilePath = Join-Path $RepoRoot 'wizard.profile.json'
    if (Test-Path $profilePath) {
        try {
            $profile = Get-Content -Path $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $profile.profileVersion -and -not [string]::IsNullOrWhiteSpace("$($profile.profileVersion)")) {
                $metadata.ProfileVersion = "$($profile.profileVersion)"
            }
            if ($null -ne $profile.contractVersion -and -not [string]::IsNullOrWhiteSpace("$($profile.contractVersion)")) {
                $metadata.ContractVersion = "$($profile.contractVersion)"
            }
        } catch {
            # Keep unknown defaults.
        }
    }

    try {
        $revision = (& git -C $RepoRoot rev-parse --short HEAD 2>$null)
        if ($LASTEXITCODE -eq 0) {
            $trimmed = ($revision -join '').Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $metadata.RepoRevision = $trimmed
            }
        }
    } catch {
        # Keep unknown defaults.
    }

    return [pscustomobject]$metadata
}

function Get-WizardErrorCategory {
    param([string]$Message)

    $text = ($Message ?? '').ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($text)) { return 'unknown' }

    if ($text -match 'auth|login|tenant|token|access\s*token|permission|forbidden|unauthor') { return 'auth' }
    if ($text -match 'payload|json|schema|mapping|logicalname|columns|relationships|table\-|columns\-|relationships\-') { return 'payload' }
    if ($text -match 'invoke\-|rest|dataverse|api|http|status\s*code|429|500|503|throttle') { return 'api' }
    if ($text -match 'prereq|validate|validation|missing required|not found|parse') { return 'validation' }
    if ($text -match 'timeout|network|dns|connect|unreachable|socket') { return 'network' }
    return 'unknown'
}

function Update-WizardTelemetryPrivacyCounters {
    param(
        [string]$PrivacyPath,
        [string]$CounterName
    )

    $state = $null
    if (Test-Path $PrivacyPath) {
        try {
            $state = Get-Content -Path $PrivacyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            $state = $null
        }
    }

    if ($null -eq $state) {
        $state = [pscustomobject]@{
            OptOutExecutions = 0
            OptInExecutions  = 0
            LastUpdatedUtc   = [DateTime]::UtcNow.ToString('o')
        }
    }

    $value = 0
    if ($null -ne $state.PSObject.Properties[$CounterName] -and [int]::TryParse("$($state.$CounterName)", [ref]$value)) {
        $state.$CounterName = $value + 1
    } else {
        Add-Member -InputObject $state -NotePropertyName $CounterName -NotePropertyValue 1 -Force
    }

    $state.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')
    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $PrivacyPath -Encoding UTF8
}

function Read-WizardTelemetryState {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        return Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Save-WizardTelemetryState {
    param(
        [string]$Path,
        $State
    )

    $State | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
}

function New-WizardTelemetryState {
    param(
        [string]$StepName,
        $StepInfo,
        $Metadata
    )

    $timestamp = [DateTime]::UtcNow.ToString('o')
    return [pscustomobject]@{
        RunId             = [guid]::NewGuid().ToString()
        StartedAtUtc      = $timestamp
        LastUpdatedAtUtc  = $timestamp
        LastStepName      = $StepName
        LastStepKey       = $StepInfo.StepKey
        LastStepOrder     = $StepInfo.StepOrder
        ProfileVersion    = $Metadata.ProfileVersion
        ContractVersion   = $Metadata.ContractVersion
        RepoRevision      = $Metadata.RepoRevision
        TelemetrySchemaVersion = $Metadata.TelemetrySchemaVersion
    }
}

function Write-WizardTelemetryEvent {
    param(
        [string]$EventsPath,
        $State,
        [string]$StepName,
        $StepInfo,
        [string]$Status,
        [string]$Message = '',
        [string]$ErrorCategory = ''
    )

    $normalizedErrorCategory = if ([string]::IsNullOrWhiteSpace($ErrorCategory)) { '-' } else { $ErrorCategory }

    $payload = [ordered]@{
        TimestampUtc = [DateTime]::UtcNow.ToString('o')
        RunId        = $State.RunId
        StepName     = $StepName
        StepKey      = $StepInfo.StepKey
        StepCode     = $StepInfo.StepCode
        StepDisplay  = $StepInfo.DisplayName
        StepOrder    = $StepInfo.StepOrder
        Status       = $Status
        Message      = $Message
        ErrorCategory = $normalizedErrorCategory
        ProfileVersion = $State.ProfileVersion
        ContractVersion = $State.ContractVersion
        RepoRevision = $State.RepoRevision
        TelemetrySchemaVersion = $State.TelemetrySchemaVersion
    }

    Add-Content -Path $EventsPath -Value ($payload | ConvertTo-Json -Compress) -Encoding UTF8
}

function Initialize-WizardStepTelemetry {
    param(
        [string]$RepoRoot,
        [string]$StepName
    )

    $pathInfo = Get-WizardTelemetryPathInfo -RepoRoot $RepoRoot
    New-Item -ItemType Directory -Path $pathInfo.RootPath -Force | Out-Null

    if (Test-WizardTelemetryOptOut) {
        Update-WizardTelemetryPrivacyCounters -PrivacyPath $pathInfo.PrivacyPath -CounterName 'OptOutExecutions'
        $script:WizardTelemetryContext = [pscustomobject]@{ Enabled = $false }
        return
    }

    Update-WizardTelemetryPrivacyCounters -PrivacyPath $pathInfo.PrivacyPath -CounterName 'OptInExecutions'

    $stepInfo = Get-WizardTelemetryStepInfo -StepName $StepName
    $metadata = Get-WizardTelemetryMetadata -RepoRoot $RepoRoot
    $state = Read-WizardTelemetryState -Path $pathInfo.CurrentRunPath
    $resetRun = $false

    if ($null -eq $state) {
        $resetRun = $true
    } else {
        $lastUpdated = [DateTime]::MinValue
        try {
            $lastUpdated = [DateTime]::Parse("$($state.LastUpdatedAtUtc)")
        } catch {
            $resetRun = $true
        }

        if (-not $resetRun) {
            if ($lastUpdated -lt [DateTime]::UtcNow.AddHours(-12)) {
                $resetRun = $true
            } elseif ($stepInfo.StepCode -eq '00' -and [int]$state.LastStepOrder -eq [int]$stepInfo.StepOrder) {
                # Treat each fresh prerequisite check invocation as a new run boundary.
                $resetRun = $true
            } elseif ([int]$stepInfo.StepOrder -lt [int]$state.LastStepOrder) {
                $resetRun = $true
            }
        }
    }

    if ($resetRun) {
        $state = New-WizardTelemetryState -StepName $StepName -StepInfo $stepInfo -Metadata $metadata
    } else {
        $state.LastUpdatedAtUtc = [DateTime]::UtcNow.ToString('o')
        $state.LastStepName = $StepName
        $state.LastStepKey = $stepInfo.StepKey
        $state.LastStepOrder = $stepInfo.StepOrder

        if ($state.PSObject.Properties['ProfileVersion']) {
            $state.ProfileVersion = $metadata.ProfileVersion
        } else {
            Add-Member -InputObject $state -NotePropertyName 'ProfileVersion' -NotePropertyValue $metadata.ProfileVersion
        }
        if ($state.PSObject.Properties['ContractVersion']) {
            $state.ContractVersion = $metadata.ContractVersion
        } else {
            Add-Member -InputObject $state -NotePropertyName 'ContractVersion' -NotePropertyValue $metadata.ContractVersion
        }
        if ($state.PSObject.Properties['RepoRevision']) {
            $state.RepoRevision = $metadata.RepoRevision
        } else {
            Add-Member -InputObject $state -NotePropertyName 'RepoRevision' -NotePropertyValue $metadata.RepoRevision
        }
        if ($state.PSObject.Properties['TelemetrySchemaVersion']) {
            $state.TelemetrySchemaVersion = $metadata.TelemetrySchemaVersion
        } else {
            Add-Member -InputObject $state -NotePropertyName 'TelemetrySchemaVersion' -NotePropertyValue $metadata.TelemetrySchemaVersion
        }
    }

    # Strip any legacy identifying fields from older telemetry state files.
    foreach ($legacyField in @('RepoRoot', 'UserName', 'MachineName')) {
        if ($state.PSObject.Properties[$legacyField]) {
            $state.PSObject.Properties.Remove($legacyField)
        }
    }

    Save-WizardTelemetryState -Path $pathInfo.CurrentRunPath -State $state
    Write-Host "Telemetry notice: non-identifying wizard step progress is recorded in .wizard-metrics/events.jsonl. Set WIZARD_METRICS_OPTOUT=1 to disable." -ForegroundColor DarkGray
    Write-WizardTelemetryEvent -EventsPath $pathInfo.EventsPath -State $state -StepName $StepName -StepInfo $stepInfo -Status 'Started'

    $script:WizardTelemetryContext = [pscustomobject]@{
        Enabled  = $true
        PathInfo = $pathInfo
        State    = $state
        StepName = $StepName
        StepInfo = $stepInfo
    }
}

function Complete-WizardStepTelemetry {
    param(
        [string]$Message = '',
        [switch]$FinalizeRun
    )

    if ($null -eq $script:WizardTelemetryContext -or -not $script:WizardTelemetryContext.Enabled) {
        return
    }

    $state = $script:WizardTelemetryContext.State
    $state.LastUpdatedAtUtc = [DateTime]::UtcNow.ToString('o')
    $state.LastStepName = $script:WizardTelemetryContext.StepName
    $state.LastStepKey = $script:WizardTelemetryContext.StepInfo.StepKey
    $state.LastStepOrder = $script:WizardTelemetryContext.StepInfo.StepOrder

    Write-WizardTelemetryEvent -EventsPath $script:WizardTelemetryContext.PathInfo.EventsPath -State $state -StepName $script:WizardTelemetryContext.StepName -StepInfo $script:WizardTelemetryContext.StepInfo -Status 'Completed' -Message $Message

    if ($FinalizeRun) {
        if (Test-Path $script:WizardTelemetryContext.PathInfo.CurrentRunPath) {
            Remove-Item -Path $script:WizardTelemetryContext.PathInfo.CurrentRunPath -Force
        }
    } else {
        Save-WizardTelemetryState -Path $script:WizardTelemetryContext.PathInfo.CurrentRunPath -State $state
    }
}

function Register-WizardStepFailure {
    param(
        [string]$Message = '',
        [switch]$FinalizeRun
    )

    if ($null -eq $script:WizardTelemetryContext -or -not $script:WizardTelemetryContext.Enabled) {
        return
    }

    $state = $script:WizardTelemetryContext.State
    $state.LastUpdatedAtUtc = [DateTime]::UtcNow.ToString('o')
    $errorCategory = Get-WizardErrorCategory -Message $Message

    Write-WizardTelemetryEvent -EventsPath $script:WizardTelemetryContext.PathInfo.EventsPath -State $state -StepName $script:WizardTelemetryContext.StepName -StepInfo $script:WizardTelemetryContext.StepInfo -Status 'Failed' -Message $Message -ErrorCategory $errorCategory

    if ($FinalizeRun) {
        if (Test-Path $script:WizardTelemetryContext.PathInfo.CurrentRunPath) {
            Remove-Item -Path $script:WizardTelemetryContext.PathInfo.CurrentRunPath -Force
        }
    } else {
        Save-WizardTelemetryState -Path $script:WizardTelemetryContext.PathInfo.CurrentRunPath -State $state
    }
}
