Describe 'Dataverse alternate-key support' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../bootstrap/helpers/dataverse-runtime.ps1')
        . (Join-Path $PSScriptRoot '../bootstrap/helpers/alternate-keys.ps1')
    }

    It 'treats an exact schema and attribute-set match as existing' {
        $result = Resolve-WizardAlternateKeyAction -TableLogicalName 'foia_releasepackage' `
            -SchemaName 'foia_AK_ReleasePackage_NumberVersion' `
            -KeyAttributes @('foia_packagenumber', 'foia_packageversion') `
            -ExistingKeys @([pscustomobject]@{
                SchemaName = 'foia_AK_ReleasePackage_NumberVersion'
                KeyAttributes = @('foia_packagenumber', 'foia_packageversion')
                MetadataId = '00000000-0000-0000-0000-000000000001'
            })
        $result.Action | Should -Be 'existing'
    }

    It 'fails when an existing schema name has different attributes' {
        {
            Resolve-WizardAlternateKeyAction -TableLogicalName 'foia_releasepackage' `
                -SchemaName 'foia_AK_ReleasePackage_NumberVersion' `
                -KeyAttributes @('foia_packagenumber', 'foia_packageversion') `
                -ExistingKeys @([pscustomobject]@{
                    SchemaName = 'foia_AK_ReleasePackage_NumberVersion'
                    KeyAttributes = @('foia_packagenumber')
                })
        } | Should -Throw '*do not exactly match*'
    }

    It 'fails when the exact attribute shape exists under another schema name' {
        {
            Resolve-WizardAlternateKeyAction -TableLogicalName 'foia_appeal' `
                -SchemaName 'foia_AK_Appeal_Number' `
                -KeyAttributes @('foia_appealnumber') `
                -ExistingKeys @([pscustomobject]@{
                    SchemaName = 'legacy_AppealNumber'
                    KeyAttributes = @('foia_appealnumber')
                })
        } | Should -Throw '*differently named key*'
    }

    It 'discovers keys but never calls mutation transport in preview' {
        $payloadFolder = Join-Path $TestDrive 'payloads'
        New-Item -ItemType Directory -Path $payloadFolder | Out-Null
        @{
            TableLogicalName = 'foia_appeal'
            Keys = @(@{
                SchemaName = 'foia_AK_Appeal_Number'
                KeyAttributes = @('foia_appealnumber')
            })
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $payloadFolder 'keys-appeal.json')

        $global:alternateKeyMethods = @()
        $result = @(Invoke-WizardAlternateKeyStage -PayloadsFolder $payloadFolder `
            -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' -PreviewOnly `
            -RequestInvoker {
                param($request)
                $global:alternateKeyMethods += $request.Method
                return @{ value = @() }
            })

        $result.Action | Should -Be 'planned'
        $global:alternateKeyMethods | Should -Be @('Get')
    }

    It 'posts EntityKeyMetadata through the shared runtime in apply mode' {
        $payloadFolder = Join-Path $TestDrive 'payloads-apply'
        New-Item -ItemType Directory -Path $payloadFolder | Out-Null
        @{
            TableLogicalName = 'foia_foiarequest'
            Keys = @(@{
                SchemaName = 'foia_AK_FoiaRequest_TrackingNumber'
                KeyAttributes = @('foia_trackingnumber')
            })
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $payloadFolder 'keys-request.json')

        $global:alternateKeyRequests = @()
        $result = @(Invoke-WizardAlternateKeyStage -PayloadsFolder $payloadFolder `
            -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' `
            -RequestInvoker {
                param($request)
                $global:alternateKeyRequests += $request
                if ($request.Method -eq 'Get') { return @{ value = @() } }
                return @{ MetadataId = '00000000-0000-0000-0000-000000000002' }
            })

        $result.Action | Should -Be 'created'
        $global:alternateKeyRequests.Count | Should -Be 2
        $global:alternateKeyRequests[1].Method | Should -Be 'Post'
        $global:alternateKeyRequests[1].Uri | Should -Match "/EntityDefinitions\(LogicalName='foia_foiarequest'\)/Keys$"
        $body = $global:alternateKeyRequests[1].Body | ConvertFrom-Json
        $body.'@odata.type' | Should -Be 'Microsoft.Dynamics.CRM.EntityKeyMetadata'
        $body.DisplayName.LocalizedLabels[0].Label | Should -Be 'foia_AK_FoiaRequest_TrackingNumber'
        $body.DisplayName.LocalizedLabels[0].LanguageCode | Should -Be 1033
        @($body.KeyAttributes) | Should -Be @('foia_trackingnumber')
    }

    It 'adds a resolved entity key to the target solution once' {
        $payloadFolder = Join-Path $TestDrive 'payloads-solution'
        New-Item -ItemType Directory -Path $payloadFolder | Out-Null
        @{
            TableLogicalName = 'foia_appeal'
            Keys = @(@{
                SchemaName = 'foia_AK_Appeal_Number'
                KeyAttributes = @('foia_appealnumber')
            })
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $payloadFolder 'keys-appeal.json')

        $keyId = '00000000-0000-0000-0000-000000000014'
        $solutionId = '00000000-0000-0000-0000-000000000099'
        $global:alternateKeySolutionRequests = @()
        $result = @(Invoke-WizardAlternateKeyStage -PayloadsFolder $payloadFolder `
            -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' `
            -SolutionUniqueName 'FederalFOIAManagement' -RequestInvoker {
                param($request)
                $global:alternateKeySolutionRequests += $request
                if ($request.Uri -match '/Keys\?') {
                    return @{ value = @(@{ SchemaName = 'foia_AK_Appeal_Number'; KeyAttributes = @('foia_appealnumber'); MetadataId = $keyId }) }
                }
                if ($request.Uri -match '/solutions\?') { return @{ value = @(@{ solutionid = $solutionId }) } }
                if ($request.Uri -match '/solutioncomponents\?') { return @{ value = @() } }
                return @{ ok = $true }
            })

        $result.SolutionMembership | Should -Be 'added'
        $addRequest = @($global:alternateKeySolutionRequests | Where-Object { $_.Uri -match '/AddSolutionComponent$' })
        $addRequest.Count | Should -Be 1
        $addBody = $addRequest[0].Body | ConvertFrom-Json
        $addBody.ComponentType | Should -Be 14
        $addBody.ComponentId | Should -Be $keyId
        $addBody.SolutionUniqueName | Should -Be 'FederalFOIAManagement'
    }

    It 'waits for a newly created key to propagate before adding it to the solution' {
        $payloadFolder = Join-Path $TestDrive 'payloads-propagation'
        New-Item -ItemType Directory -Path $payloadFolder | Out-Null
        @{
            TableLogicalName = 'foia_appeal'
            Keys = @(@{
                SchemaName = 'foia_AK_Appeal_Number'
                DisplayName = 'Appeal Number'
                KeyAttributes = @('foia_appealnumber')
            })
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $payloadFolder 'keys-appeal.json')

        $keyId = '00000000-0000-0000-0000-000000000014'
        $solutionId = '00000000-0000-0000-0000-000000000099'
        $global:keyDiscoveryCalls = 0
        $global:keyPropagationSleeps = 0
        $result = @(Invoke-WizardAlternateKeyStage -PayloadsFolder $payloadFolder `
            -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'token' `
            -SolutionUniqueName 'FederalFOIAManagement' -SleepAction {
                param($seconds)
                $global:keyPropagationSleeps++
            } -RequestInvoker {
                param($request)
                if ($request.Uri -match '/Keys\?') {
                    $global:keyDiscoveryCalls++
                    if ($global:keyDiscoveryCalls -lt 3) { return @{ value = @() } }
                    return @{ value = @(@{ SchemaName = 'foia_AK_Appeal_Number'; KeyAttributes = @('foia_appealnumber'); MetadataId = $keyId }) }
                }
                if ($request.Method -eq 'Post' -and $request.Uri -match '/Keys$') { return @{} }
                if ($request.Uri -match '/solutions\?') { return @{ value = @(@{ solutionid = $solutionId }) } }
                if ($request.Uri -match '/solutioncomponents\?') { return @{ value = @() } }
                return @{ ok = $true }
            })

        $result.MetadataId | Should -Be $keyId
        $result.SolutionMembership | Should -Be 'added'
        $global:keyDiscoveryCalls | Should -Be 3
        $global:keyPropagationSleeps | Should -Be 1
    }
}
