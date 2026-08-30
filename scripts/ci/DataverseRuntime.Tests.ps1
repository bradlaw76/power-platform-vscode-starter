Describe 'Invoke-WizardDataverseRequest' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../bootstrap/helpers/dataverse-runtime.ps1')

        function New-TestHttpError {
            param(
                [int]$StatusCode,
                [string]$Message = "HTTP $StatusCode",
                [string]$RetryAfter = ''
            )

            $exception = [System.Exception]::new($Message)
            $response = [pscustomobject]@{
                StatusCode = $StatusCode
                Headers = @{}
            }
            if (-not [string]::IsNullOrWhiteSpace($RetryAfter)) {
                $response.Headers['Retry-After'] = $RetryAfter
            }
            $exception | Add-Member -NotePropertyName Response -NotePropertyValue $response
            return [System.Management.Automation.ErrorRecord]::new($exception, "Http$StatusCode", 'InvalidOperation', $null)
        }
    }

    It 'returns a successful response' {
        $result = Invoke-WizardDataverseRequest -Method Get -Path 'WhoAmI' -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' -RequestInvoker {
            param($request)
            [pscustomobject]@{ UserId = '00000000-0000-0000-0000-000000000001'; Uri = $request.Uri }
        }
        $result.UserId | Should -Be '00000000-0000-0000-0000-000000000001'
    }

    It 'does not call transport for a preview mutation' {
        $global:wizardTestTransportCalls = 0
        $result = Invoke-WizardDataverseRequest -Method Post -Path 'accounts' -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' -Body @{} -PreviewOnly -RequestInvoker {
            param($request)
            $global:wizardTestTransportCalls++
        }
        $result.Mutated | Should -BeFalse
        $global:wizardTestTransportCalls | Should -Be 0
    }

    It 'refreshes once after 401 and retries with the new token' {
        $global:wizardTestRequestCount = 0
        $global:wizardTestTokens = @()
        $result = Invoke-WizardDataverseRequest -Method Get -Path 'WhoAmI' -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'expired-token' -TokenProvider { 'fresh-token' } -RequestInvoker {
            param($request)
            $global:wizardTestRequestCount++
            $global:wizardTestTokens += $request.Headers.Authorization
            if ($global:wizardTestRequestCount -eq 1) { throw (New-TestHttpError -StatusCode 401) }
            return @{ ok = $true }
        }
        $result.ok | Should -BeTrue
        $global:wizardTestTokens | Should -Be @('Bearer expired-token', 'Bearer fresh-token')
    }

    It 'honors Retry-After for 429' {
        $global:wizardTestRequestCount = 0
        $global:wizardTestDelays = @()
        $result = Invoke-WizardDataverseRequest -Method Get -Path 'accounts' -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' -RequestInvoker {
            param($request)
            $global:wizardTestRequestCount++
            if ($global:wizardTestRequestCount -eq 1) { throw (New-TestHttpError -StatusCode 429 -RetryAfter '7') }
            return @{ ok = $true }
        } -SleepAction { param($seconds) $global:wizardTestDelays += $seconds }
        $result.ok | Should -BeTrue
        $global:wizardTestDelays | Should -Be @(7)
    }

    It 'retries a 5xx response' {
        $global:wizardTestRequestCount = 0
        $result = Invoke-WizardDataverseRequest -Method Get -Path 'accounts' -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' -RequestInvoker {
            param($request)
            $global:wizardTestRequestCount++
            if ($global:wizardTestRequestCount -eq 1) { throw (New-TestHttpError -StatusCode 503) }
            return @{ ok = $true }
        } -SleepAction { param($seconds) }
        $result.ok | Should -BeTrue
        $global:wizardTestRequestCount | Should -Be 2
    }

    It 'does not retry terminal <StatusCode> responses' -TestCases @(
        @{ StatusCode = 403 }
        @{ StatusCode = 404 }
        @{ StatusCode = 409 }
    ) {
        param($StatusCode)
        $global:wizardTestRequestCount = 0
        $global:wizardTestTerminalStatus = $StatusCode
        { Invoke-WizardDataverseRequest -Method Get -Path 'accounts' -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' -RequestInvoker {
                param($request)
                $global:wizardTestRequestCount++
                throw (New-TestHttpError -StatusCode $global:wizardTestTerminalStatus)
            } } | Should -Throw
        $global:wizardTestRequestCount | Should -Be 1
    }

    It 'sanitizes tokens from terminal errors' {
        $secret = 'header.payload.signature'
        $caughtMessage = ''
        try {
            Invoke-WizardDataverseRequest -Method Get -Path 'accounts' -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken $secret -RequestInvoker {
                param($request)
                throw (New-TestHttpError -StatusCode 403 -Message "Bearer header.payload.signature access_token=header.payload.signature")
            }
        } catch {
            $caughtMessage = $_.Exception.Message
        }
        $caughtMessage | Should -Not -Match ([regex]::Escape($secret))
        $caughtMessage | Should -Match 'Bearer \[REDACTED\]'
        $caughtMessage | Should -Match 'access_token=\[REDACTED\]'
    }
}

Describe 'Wait-WizardDataverseOperation' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../bootstrap/helpers/dataverse-runtime.ps1')
    }

    It 'returns a completed operation' {
        $result = Wait-WizardDataverseOperation -StatusProvider { @{ Completed = $true; Failed = $false } } -TimeoutSeconds 1
        $result.Completed | Should -BeTrue
    }

    It 'rejects a malformed status response' {
        { Wait-WizardDataverseOperation -StatusProvider { $null } -TimeoutSeconds 1 -SleepAction { param($seconds) } } | Should -Throw
    }

    It 'times out an incomplete operation' {
        { Wait-WizardDataverseOperation -StatusProvider { @{ Completed = $false; Failed = $false } } -TimeoutSeconds 0 -PollIntervalSeconds 0 -SleepAction { param($seconds) } } | Should -Throw '*timed out*'
    }
}

Describe 'Scoped wizard publication' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../bootstrap/helpers/dataverse-runtime.ps1')
    }

    It 'builds deterministic entity-scoped publication XML' {
        New-WizardEntityPublishXml -EntityLogicalNames @('ppvs_labasset', 'ppvs_checkoutrequest', 'ppvs_labasset') |
            Should -Be '<importexportxml><entities><entity>ppvs_checkoutrequest</entity><entity>ppvs_labasset</entity></entities></importexportxml>'
    }

    It 'builds app-module-scoped publication XML' {
        $appId = '00001111-aaaa-2222-bbbb-3333cccc4444'
        New-WizardAppModulePublishXml -AppModuleId $appId |
            Should -Be "<importexportxml><appmodules><appmodule>$appId</appmodule></appmodules></importexportxml>"
    }

    It 'rejects publication without an explicit scope' {
        { Publish-WizardCustomizations -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' -ParameterXml ' ' } |
            Should -Throw '*requires non-empty ParameterXml*'
    }

    It 'posts only to PublishXml' {
        $global:wizardPublishPath = ''
        $xml = New-WizardEntityPublishXml -EntityLogicalNames @('ppvs_labasset')
        Publish-WizardCustomizations -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' -ParameterXml $xml -RequestInvoker {
            param($request)
            $global:wizardPublishPath = $request.Uri
            return @{ ok = $true }
        } | Out-Null
        $global:wizardPublishPath | Should -Match '/PublishXml$'
        $global:wizardPublishPath | Should -Not -Match 'PublishAllXml'
    }
}

Describe 'Wizard upsert collision safety' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../bootstrap/helpers/wizard-hardening.ps1')
    }

    It 'rejects multiple matching components' {
        { Get-WizardUpsertAction -ExistingItems @(@{ id = 1 }, @{ id = 2 }) } |
            Should -Throw '*expected at most one matching component*'
    }
}