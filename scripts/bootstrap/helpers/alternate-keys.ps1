<#
=============================================================================
COMPONENT:    Dataverse Alternate Keys
FILE:         scripts/bootstrap/helpers/alternate-keys.ps1
VERSION:      0.1.1
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-06
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Plans and applies schema-bound Dataverse alternate keys with collision-safe,
credential-free payload handling.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            metadata helper used by bootstrap step 30
- Inputs:          keys-*.json payloads and injectable Dataverse transport
- Outputs:         planned, created, or existing key results
- Dependencies:    helpers/dataverse-runtime.ps1
- Side Effects:    creates EntityKeyMetadata only outside preview mode

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Exact schema-name and attribute matches are idempotent.
✔ Name or attribute collisions fail before mutation.
✔ Preview mode performs discovery but suppresses metadata mutation.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Never store credentials in payloads or output.
- Never replace or silently accept a mismatched existing key.
- Use the shared Dataverse runtime for 401 refresh and 429 backoff.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.1  2026-10-08  Added required localized display names to key metadata.
v0.1.0  2026-10-06  Added alternate-key planning and creation support.
=============================================================================
#>

Set-StrictMode -Version Latest

function ConvertTo-WizardNormalizedKeyAttributes {
    param([object[]]$Attributes)

    return @($Attributes | ForEach-Object { ("$_").Trim().ToLowerInvariant() })
}

function Test-WizardKeyAttributeSequence {
    param(
        [object[]]$Left,
        [object[]]$Right
    )

    $leftValues = @(ConvertTo-WizardNormalizedKeyAttributes -Attributes $Left | Sort-Object)
    $rightValues = @(ConvertTo-WizardNormalizedKeyAttributes -Attributes $Right | Sort-Object)
    if ($leftValues.Count -ne $rightValues.Count) { return $false }
    for ($index = 0; $index -lt $leftValues.Count; $index++) {
        if ($leftValues[$index] -cne $rightValues[$index]) { return $false }
    }
    return $true
}

function Resolve-WizardAlternateKeyAction {
    param(
        [Parameter(Mandatory)] [string]$TableLogicalName,
        [Parameter(Mandatory)] [string]$SchemaName,
        [Parameter(Mandatory)] [string[]]$KeyAttributes,
        [object[]]$ExistingKeys = @()
    )

    $schemaMatches = @($ExistingKeys | Where-Object { ("$($_.SchemaName)").Equals($SchemaName, [StringComparison]::OrdinalIgnoreCase) })
    if ($schemaMatches.Count -gt 1) {
        throw "Alternate key collision on '$TableLogicalName': multiple keys use schema name '$SchemaName'."
    }
    if ($schemaMatches.Count -eq 1) {
        if (-not (Test-WizardKeyAttributeSequence -Left @($schemaMatches[0].KeyAttributes) -Right $KeyAttributes)) {
            $actual = @(ConvertTo-WizardNormalizedKeyAttributes -Attributes @($schemaMatches[0].KeyAttributes)) -join ', '
            throw "Alternate key mismatch on '$TableLogicalName.$SchemaName': existing attributes [$actual] do not exactly match payload attributes [$($KeyAttributes -join ', ')]."
        }
        return [pscustomobject]@{ Action = 'existing'; Existing = $schemaMatches[0] }
    }

    $attributeMatches = @($ExistingKeys | Where-Object {
        Test-WizardKeyAttributeSequence -Left @($_.KeyAttributes) -Right $KeyAttributes
    })
    if ($attributeMatches.Count -gt 0) {
        $names = @($attributeMatches | ForEach-Object { $_.SchemaName }) -join ', '
        throw "Alternate key mismatch on '$TableLogicalName': payload schema '$SchemaName' duplicates attributes already controlled by differently named key(s): $names."
    }

    return [pscustomobject]@{ Action = 'create'; Existing = $null }
}

function Invoke-WizardAlternateKeyStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$PayloadsFolder,
        [Parameter(Mandatory)] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [string]$AccessToken,
        [string]$SolutionUniqueName = '',
        [switch]$PreviewOnly,
        [scriptblock]$TokenProvider,
        [scriptblock]$RequestInvoker,
        [scriptblock]$SleepAction
    )

    if (-not (Get-Command Invoke-WizardDataverseRequest -ErrorAction SilentlyContinue)) {
        throw 'Invoke-WizardDataverseRequest is required. Load dataverse-runtime.ps1 before alternate-keys.ps1.'
    }

    $results = [System.Collections.Generic.List[object]]::new()
    $payloads = @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'keys-*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
    foreach ($file in $payloads) {
        $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $table = ("$($document.TableLogicalName)").Trim().ToLowerInvariant()
        $escapedTable = ConvertTo-WizardODataLiteral -Value $table
        $existingResponse = Invoke-WizardDataverseRequest -Method Get `
            -Path "EntityDefinitions(LogicalName='$escapedTable')/Keys?`$select=SchemaName,MetadataId,KeyAttributes,EntityKeyIndexStatus" `
            -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken `
            -TokenProvider $TokenProvider -RequestInvoker $RequestInvoker -SleepAction $SleepAction
        $existingKeys = @($existingResponse.value)

        foreach ($key in @($document.Keys)) {
            $schemaName = ("$($key.SchemaName)").Trim()
            $displayNameProperty = $key.PSObject.Properties['DisplayName']
            $displayName = if ($null -eq $displayNameProperty -or [string]::IsNullOrWhiteSpace("$($displayNameProperty.Value)")) {
                $schemaName
            } else {
                ("$($displayNameProperty.Value)").Trim()
            }
            $attributes = @(ConvertTo-WizardNormalizedKeyAttributes -Attributes @($key.KeyAttributes))
            $resolution = Resolve-WizardAlternateKeyAction -TableLogicalName $table -SchemaName $schemaName -KeyAttributes $attributes -ExistingKeys $existingKeys
            $action = 'existing'
            $metadataId = if ($resolution.Action -eq 'existing') { "$($resolution.Existing.MetadataId)" } else { '' }
            if ($resolution.Action -eq 'create') {
                $body = [ordered]@{
                    '@odata.type' = 'Microsoft.Dynamics.CRM.EntityKeyMetadata'
                    SchemaName = $schemaName
                    DisplayName = @{
                        LocalizedLabels = @(
                            @{
                                Label = $displayName
                                LanguageCode = 1033
                            }
                        )
                    }
                    KeyAttributes = $attributes
                }
                $creation = Invoke-WizardDataverseRequest -Method Post `
                    -Path "EntityDefinitions(LogicalName='$escapedTable')/Keys" `
                    -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body $body `
                    -PreviewOnly:$PreviewOnly -TokenProvider $TokenProvider -RequestInvoker $RequestInvoker -SleepAction $SleepAction
                $metadataIdProperty = if ($null -eq $creation) { $null } else { $creation.PSObject.Properties['MetadataId'] }
                $metadataId = if ($null -eq $metadataIdProperty) { '' } else { "$($metadataIdProperty.Value)" }
                $action = if ($PreviewOnly) { 'planned' } else { 'created' }
            }

            $solutionMembership = if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { 'not-requested' } elseif ($PreviewOnly) { 'planned' } else { 'pending' }
            if (-not $PreviewOnly -and -not [string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
                if ([string]::IsNullOrWhiteSpace($metadataId)) {
                    $propagationSleep = if ($null -eq $SleepAction) {
                        { param($seconds) Start-Sleep -Seconds $seconds }
                    } else {
                        $SleepAction
                    }
                    $createdMatches = @()
                    for ($propagationAttempt = 1; $propagationAttempt -le 12; $propagationAttempt++) {
                        $refreshedKeys = Invoke-WizardDataverseRequest -Method Get `
                            -Path "EntityDefinitions(LogicalName='$escapedTable')/Keys?`$select=SchemaName,MetadataId,KeyAttributes" `
                            -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken `
                            -TokenProvider $TokenProvider -RequestInvoker $RequestInvoker -SleepAction $SleepAction
                        $createdMatches = @($refreshedKeys.value | Where-Object { ("$($_.SchemaName)").Equals($schemaName, [StringComparison]::OrdinalIgnoreCase) })
                        if ($createdMatches.Count -eq 1) { break }
                        if ($createdMatches.Count -gt 1) {
                            throw "Alternate key '$table.$schemaName' resolved to multiple metadata records after creation."
                        }
                        if ($propagationAttempt -lt 12) { & $propagationSleep 5 }
                    }
                    if ($createdMatches.Count -ne 1) {
                        throw "Alternate key '$table.$schemaName' was created but its metadata ID is not uniquely discoverable. Rerun step 30 after Dataverse metadata propagation completes."
                    }
                    $metadataId = "$($createdMatches[0].MetadataId)"
                }

                $escapedSolution = ConvertTo-WizardODataLiteral -Value $SolutionUniqueName
                $solutionResponse = Invoke-WizardDataverseRequest -Method Get `
                    -Path "solutions?`$select=solutionid&`$filter=uniquename eq '$escapedSolution'" `
                    -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken `
                    -TokenProvider $TokenProvider -RequestInvoker $RequestInvoker -SleepAction $SleepAction
                $solutions = @($solutionResponse.value)
                if ($solutions.Count -ne 1) { throw "Target solution '$SolutionUniqueName' did not resolve uniquely while adding alternate key '$table.$schemaName'." }
                $solutionId = "$($solutions[0].solutionid)"
                $membershipResponse = Invoke-WizardDataverseRequest -Method Get `
                    -Path "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $solutionId and objectid eq $metadataId and componenttype eq 14" `
                    -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken `
                    -TokenProvider $TokenProvider -RequestInvoker $RequestInvoker -SleepAction $SleepAction
                if (@($membershipResponse.value).Count -eq 0) {
                    Invoke-WizardDataverseRequest -Method Post -Path 'AddSolutionComponent' `
                        -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken `
                        -Body @{ ComponentId = $metadataId; ComponentType = 14; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $true } `
                        -TokenProvider $TokenProvider -RequestInvoker $RequestInvoker -SleepAction $SleepAction | Out-Null
                    $solutionMembership = 'added'
                } else {
                    $solutionMembership = 'existing'
                }
            }

            $results.Add([pscustomobject]@{
                TableLogicalName = $table
                SchemaName = $schemaName
                KeyAttributes = $attributes
                Action = $action
                MetadataId = $metadataId
                SolutionMembership = $solutionMembership
                Payload = $file.Name
            }) | Out-Null
            $existingKeys += [pscustomobject]@{
                SchemaName = $schemaName
                KeyAttributes = $attributes
                MetadataId = $metadataId
            }
        }
    }

    return $results.ToArray()
}
