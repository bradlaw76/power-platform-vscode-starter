<#
=============================================================================
COMPONENT:    Dataverse Runtime Helper
FILE:         scripts/bootstrap/helpers/dataverse-runtime.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-24
ENVIRONMENT:  PowerShell 7 | Dataverse Web API | PAC CLI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Provides the shared, credential-safe runtime used by wizard build stages.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap helper
- Inputs:          environment context, request details, scenario paths
- Outputs:         Dataverse responses and sanitized runtime errors
- Dependencies:    PowerShell 7; Azure CLI only for default token refresh
- Side Effects:    HTTP mutations only when PreviewOnly is false

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Preview mode never invokes transport for mutating requests.
✔ A 401 refreshes once; 429 and 5xx responses retry within the limit.
✔ Errors remove bearer tokens and common secret values.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never include access tokens or secrets in output, telemetry, or exceptions.
- Honor Retry-After when Dataverse supplies it.
- Keep request transport injectable for credential-free Pester tests.
=============================================================================
#>

Set-StrictMode -Version Latest

function Import-WizardEnvironment {
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [string]$EnvironmentFile = '.env.ps1'
    )

    $path = if ([IO.Path]::IsPathRooted($EnvironmentFile)) { $EnvironmentFile } else { Join-Path $RepoRoot $EnvironmentFile }
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Wizard environment file not found. Run 10-auth-connect.ps1 first: $path"
    }

    . $path
    return [pscustomobject]@{
        EnvironmentUrl = "$($global:DV_ENVIRONMENT_URL)".TrimEnd('/')
        AccessToken = "$($global:DV_TOKEN)"
        SolutionUniqueName = "$($global:DV_SOLUTION_NAME)"
        PublisherPrefix = "$($global:DV_PUBLISHER_PREFIX)".ToLowerInvariant()
    }
}

function Get-WizardDataverseToken {
    param([Parameter(Mandatory)] [string]$EnvironmentUrl)

    $token = & az account get-access-token --resource "$($EnvironmentUrl.TrimEnd('/'))/" --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($token -join '').Trim())) {
        throw 'Unable to refresh the Dataverse access token. Run 10-auth-connect.ps1 and retry.'
    }
    return ($token -join '').Trim()
}

function ConvertTo-WizardODataLiteral {
    param([AllowEmptyString()] [string]$Value)
    return ($Value ?? '').Replace("'", "''")
}

function ConvertTo-WizardRelativeDataversePath {
    param([Parameter(Mandatory)] [string]$Path)

    if ($Path -notmatch '^(?i)https?://') { return $Path.TrimStart('/') }
    $uri = [Uri]$Path
    $marker = '/api/data/v9.2/'
    $index = $uri.AbsoluteUri.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) { throw 'The supplied URL is not a Dataverse v9.2 Web API URL.' }
    return $uri.AbsoluteUri.Substring($index + $marker.Length)
}

function Get-WizardHttpStatusCode {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)

    $responseProperty = $ErrorRecord.Exception.PSObject.Properties['Response']
    $response = if ($null -ne $responseProperty) { $responseProperty.Value } else { $null }
    $statusProperty = if ($null -ne $response) { $response.PSObject.Properties['StatusCode'] } else { $null }
    if ($null -ne $statusProperty -and $null -ne $statusProperty.Value) {
        return [int]$statusProperty.Value
    }
    if ($ErrorRecord.Exception.Message -match '(?<!\d)(?<status>401|403|404|409|429|5\d\d)(?!\d)') {
        return [int]$Matches.status
    }
    return 0
}

function Get-WizardRetryAfterSeconds {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [int]$Attempt
    )

    $responseProperty = $ErrorRecord.Exception.PSObject.Properties['Response']
    $response = if ($null -ne $responseProperty) { $responseProperty.Value } else { $null }
    $headersProperty = if ($null -ne $response) { $response.PSObject.Properties['Headers'] } else { $null }
    if ($null -ne $headersProperty -and $null -ne $headersProperty.Value) {
        $retryAfter = $headersProperty.Value['Retry-After']
        $seconds = 0
        if ($null -ne $retryAfter -and [int]::TryParse("$retryAfter", [ref]$seconds)) {
            return [Math]::Max(0, [Math]::Min(120, $seconds))
        }
    }
    return [Math]::Min(30, [Math]::Pow(2, [Math]::Max(0, $Attempt - 1)))
}

function ConvertTo-WizardSafeErrorMessage {
    param(
        [Parameter(Mandatory)] [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string[]]$SecretValues = @()
    )

    $message = "$($ErrorRecord.Exception.Message)"
    try {
        if ($null -ne $ErrorRecord.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
            $message = $ErrorRecord.ErrorDetails.Message
        }
    } catch {}

    $message = [regex]::Replace($message, '(?i)Bearer\s+[A-Za-z0-9._~+/-]+=*', 'Bearer [REDACTED]')
    $message = [regex]::Replace($message, '(?i)(access[_-]?token|client[_-]?secret|password)\s*[:=]\s*[^\s,;]+', '$1=[REDACTED]')
    foreach ($secret in @($SecretValues | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $message = $message.Replace($secret, '[REDACTED]')
    }
    return $message
}

function Invoke-WizardDataverseRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [ValidateSet('Get', 'Post', 'Patch', 'Put', 'Delete')] [string]$Method,
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [string]$AccessToken,
        [object]$Body,
        [switch]$PreviewOnly,
        [int]$MaxAttempts = 5,
        [scriptblock]$TokenProvider,
        [scriptblock]$RequestInvoker,
        [scriptblock]$SleepAction
    )

    $isMutation = $Method -ne 'Get'
    if ($PreviewOnly -and $isMutation) {
        return [pscustomobject]@{ Preview = $true; Method = $Method; Path = $Path; Mutated = $false }
    }

    if ($null -eq $TokenProvider) {
        $TokenProvider = { param($url) Get-WizardDataverseToken -EnvironmentUrl $url }
    }
    if ($null -eq $RequestInvoker) {
        $RequestInvoker = {
            param($request)
            $parameters = @{
                Method = $request.Method
                Uri = $request.Uri
                Headers = $request.Headers
            }
            if ($null -ne $request.Body) {
                $parameters.Body = $request.Body
                $parameters.ContentType = 'application/json'
            }
            Invoke-RestMethod @parameters
        }
    }
    if ($null -eq $SleepAction) {
        $SleepAction = { param($seconds) Start-Sleep -Seconds $seconds }
    }

    $currentToken = $AccessToken
    $refreshed = $false
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $headers = @{
            Authorization = "Bearer $currentToken"
            Accept = 'application/json'
            'OData-Version' = '4.0'
            'OData-MaxVersion' = '4.0'
        }
        $request = [pscustomobject]@{
            Method = $Method
            Uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$(ConvertTo-WizardRelativeDataversePath -Path $Path)"
            Headers = $headers
            Body = if ($null -eq $Body) { $null } elseif ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 30 -Compress }
        }

        try {
            return & $RequestInvoker $request
        } catch {
            $statusCode = Get-WizardHttpStatusCode -ErrorRecord $_
            if ($statusCode -eq 401 -and -not $refreshed) {
                $currentToken = & $TokenProvider $EnvironmentUrl
                $refreshed = $true
                continue
            }

            $retryable = $false
            if ($statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -le 599)) {
                $retryable = $true
            } elseif ($statusCode -eq 0 -and $_.Exception.Message -match '(?i)timeout|temporar|connection reset') {
                $retryable = $true
            }
            if ($retryable -and $attempt -lt $MaxAttempts) {
                & $SleepAction (Get-WizardRetryAfterSeconds -ErrorRecord $_ -Attempt $attempt)
                continue
            }

            $safeMessage = ConvertTo-WizardSafeErrorMessage -ErrorRecord $_ -SecretValues @($currentToken, $AccessToken)
            throw "Dataverse request failed ($Method $Path, HTTP $statusCode): $safeMessage"
        }
    }
}

function Wait-WizardDataverseOperation {
    param(
        [Parameter(Mandatory)] [scriptblock]$StatusProvider,
        [int]$TimeoutSeconds = 300,
        [int]$PollIntervalSeconds = 5,
        [scriptblock]$SleepAction
    )

    if ($null -eq $SleepAction) { $SleepAction = { param($seconds) Start-Sleep -Seconds $seconds } }
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $status = & $StatusProvider
        if ($status.Completed) { return $status }
        if ($status.Failed) { throw "Dataverse operation failed: $($status.Message)" }
        if ([DateTime]::UtcNow -ge $deadline) { break }
        & $SleepAction $PollIntervalSeconds
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "Dataverse operation timed out after $TimeoutSeconds second(s)."
}

function Publish-WizardCustomizations {
    param(
        [Parameter(Mandatory)] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [string]$AccessToken,
        [string]$ParameterXml = '',
        [switch]$PreviewOnly,
        [scriptblock]$RequestInvoker
    )

    if ([string]::IsNullOrWhiteSpace($ParameterXml)) {
        return Invoke-WizardDataverseRequest -Method Post -Path 'PublishAllXml' -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body @{} -PreviewOnly:$PreviewOnly -RequestInvoker $RequestInvoker
    }
    return Invoke-WizardDataverseRequest -Method Post -Path 'PublishXml' -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body @{ ParameterXml = $ParameterXml } -PreviewOnly:$PreviewOnly -RequestInvoker $RequestInvoker
}

function Resolve-WizardScenarioPaths {
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [string]$PayloadsFolder = ''
    )

    if ($ScenarioSlug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        throw "Invalid scenario slug '$ScenarioSlug'. Use lowercase letters, numbers, and single hyphens."
    }
    $scenarioFolder = Join-Path $RepoRoot "specs/$ScenarioSlug"
    $payloadFolder = if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) { Join-Path $RepoRoot "payloads/scenarios/$ScenarioSlug" } else { $PayloadsFolder }
    return [pscustomobject]@{
        ScenarioFolder = $scenarioFolder
        PayloadFolder = $payloadFolder
        ReportsFolder = Join-Path $scenarioFolder 'reports'
    }
}