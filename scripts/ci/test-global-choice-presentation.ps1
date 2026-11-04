<#
=============================================================================
COMPONENT:    Global Choice Presentation Tests
FILE:         scripts/ci/test-global-choice-presentation.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-22
ENVIRONMENT:  PowerShell 7 | Credential-free isolated Dataverse mock
OVERVIEW:     Verify hash approval, full preflight, safe updates, and exact style.
ARCHITECTURE: Temporary repository and stateful request transport.
TEST CASES:   Preview, drift/managed/membership rejection, Apply, rerun, color gate.
NON-NEGOTIABLES: No live access or mutation of real scenario evidence.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ('foia-style-test-' + [guid]::NewGuid().ToString('N'))
function Assert-Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-Rejected {
    param([scriptblock]$Action, [string]$Message)
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notlike "*$Message*") { throw }
        return
    }
    throw "Expected rejection: $Message"
}
try {
    foreach ($path in @('scripts\bootstrap\helpers','schemas\payloads','payloads\scenarios\federal-foia-management')) {
        New-Item -ItemType Directory -Path (Join-Path $temp $path) -Force | Out-Null
    }
    foreach ($path in @(
        'scripts\bootstrap\38-style-global-choices.ps1',
        'scripts\bootstrap\helpers\dataverse-runtime.ps1',
        'scripts\bootstrap\helpers\choice-migration-verification.ps1',
        'scripts\bootstrap\helpers\choice-presentation-tokens.ps1',
        'schemas\payloads\choice-migration.schema.json',
        'payloads\scenarios\federal-foia-management\choice-migration-federal-foia-management.json'
    )) { Copy-Item -LiteralPath (Join-Path $repo $path) -Destination (Join-Path $temp $path) }
    . (Join-Path $temp 'scripts\bootstrap\helpers\choice-migration-verification.ps1')
    $payload = Get-Content -LiteralPath (Join-Path $temp 'payloads\scenarios\federal-foia-management\choice-migration-federal-foia-management.json') -Raw | ConvertFrom-Json -Depth 40
    $choices = @{}
    foreach ($choice in $payload.GlobalChoices) {
        $choices[$choice.Name] = [pscustomobject]@{
            Name = $choice.Name; MetadataId = [guid]::NewGuid().ToString()
            IsManaged = $false; IsGlobal = $true; OptionSetType = 'Picklist'
            Options = @($choice.Options | ForEach-Object {
                [pscustomobject]@{ Value = $_.Value; Color = $null; IsManaged = $false; Label = [pscustomobject]@{
                    LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = $_.Label },
                        [pscustomobject]@{ LanguageCode = 1036; Label = 'Preserve translation' })
                } }
            })
        }
    }
    $state = @{ MissingMembership = $false; WrongBinding = $false; WrongReadbackColor = $false }
    $calls = [Collections.Generic.List[object]]::new()
    $transport = {
        param($request)
        $path = [Uri]::UnescapeDataString(($request.Uri -split '/api/data/v9.2/')[1])
        $body = if ($null -ne $request.Body) { $request.Body | ConvertFrom-Json -Depth 40 } else { $null }
        $calls.Add([pscustomobject]@{ Method = $request.Method; Path = $path; Body = $body })
        if ($path -like 'solutions?*') { return @{value = @(@{ solutionid = '11111111-1111-1111-1111-111111111111'; ismanaged = $false })} }
        if ($path -like 'solutioncomponents?*') {
            return @{value = if ($state.MissingMembership) { @() } else { @(@{ solutioncomponentid = [guid]::NewGuid().ToString() }) }}
        }
        if ($path -match "^GlobalOptionSetDefinitions\(Name='([^']+)'\)") {
            $metadata = $choices[$Matches[1]]
            if ($state.WrongReadbackColor) {
                $metadata = $metadata | ConvertTo-Json -Depth 40 | ConvertFrom-Json -Depth 40
                $metadata.Options[0].Color = '#000000'
            }
            return $metadata
        }
        if ($path -match "^EntityDefinitions\(LogicalName='([^']+)'\)/Attributes\(LogicalName='([^']+)'\)") {
            $table = $Matches[1]; $column = $Matches[2]
            $binding = @($payload.Bindings | Where-Object { $_.TableLogicalName -eq $table -and $_.ColumnLogicalName -eq $column })[0]
            return @{ LogicalName = $column; AttributeType = 'Picklist'; GlobalOptionSet = @{
                Name = $binding.GlobalChoiceName; MetadataId = if ($state.WrongBinding) { [guid]::Empty.ToString() } else { $choices[$binding.GlobalChoiceName].MetadataId }
            } }
        }
        if ($request.Method -eq 'Post' -and $path -eq 'UpdateOptionValue') {
            Assert-Test ($null -eq $body.PSObject.Properties['EntityLogicalName'] -and $null -eq $body.PSObject.Properties['AttributeLogicalName']) 'Global update incorrectly used local column parameters.'
            Assert-Test ($body.MergeLabels -and $body.SolutionUniqueName -eq 'FederalFOIAManagement') 'Update did not preserve translations or target solution.'
            $option = @($choices[$body.OptionSetName].Options | Where-Object Value -eq $body.Value)[0]
            $option.Color = $body.Color
            $option.Label.LocalizedLabels[0].Label = $body.Label.LocalizedLabels[0].Label
            return $null
        }
        if ($request.Method -eq 'Post' -and $path -eq 'PublishXml') {
            [xml]$xml = $body.ParameterXml
            Assert-Test ($xml.SelectNodes('//optionset').Count -eq 26 -and $xml.SelectNodes('//entity').Count -eq 0) 'Publish was not scoped to exactly 26 global Choices.'
            return $null
        }
        throw "Unexpected request $($request.Method) $path"
    }.GetNewClosure()
    $stage = Join-Path $temp 'scripts\bootstrap\38-style-global-choices.ps1'
    $stageArgs = @{ ScenarioSlug = 'federal-foia-management'; SolutionUniqueName = 'FederalFOIAManagement'; PublisherPrefix = 'foia'; EnvironmentUrl = 'https://example.crm.dynamics.com'; AccessToken = 'fake'; RequestInvoker = $transport }
    $preview = & $stage @stageArgs -PreviewOnly
    Assert-Test ($calls.Count -eq 0 -and $preview.ChoiceCount -eq 26 -and $preview.OptionCount -eq 162) 'Offline preview mutated or omitted options.'
    Assert-Rejected { & $stage @stageArgs -ApprovedPlanHash 'wrong' } 'Approve the exact preview hash'
    Assert-Test ($calls.Count -eq 0) 'Hash mismatch contacted Dataverse.'
    $stageArgs.ApprovedPlanHash = $preview.PlanHash
    $state.MissingMembership = $true
    Assert-Rejected { & $stage @stageArgs } 'lacks unique'
    $state.MissingMembership = $false
    $last = $choices['foia_validationstate']
    $last.IsManaged = $true
    Assert-Rejected { & $stage @stageArgs } 'exact unmanaged'
    $last.IsManaged = $false
    $last.Options[0].Label.LocalizedLabels[0].Label = 'Unexpected label'
    Assert-Rejected { & $stage @stageArgs } 'label drifted'
    $last.Options[0].Label.LocalizedLabels[0].Label = 'Pending'
    $state.WrongBinding = $true
    Assert-Rejected { & $stage @stageArgs } 'drifted'
    $state.WrongBinding = $false
    Assert-Test (@($calls | Where-Object Method -eq Post).Count -eq 0) 'Preflight failure caused a partial mutation.'
    $first = & $stage @stageArgs
    Assert-Test ($first.changedOptionCount -eq 162 -and $first.exactReadback) 'Apply did not verify all 162 styled options.'
    $backupHash = (Get-FileHash -LiteralPath $first.backupPath).Hash
    $calls.Clear()
    $second = & $stage @stageArgs
    Assert-Test ($second.changedOptionCount -eq 0 -and @($calls | Where-Object Method -eq Post).Count -eq 0) 'Rerun issued a write or duplicated an icon.'
    Assert-Test ((Get-FileHash -LiteralPath $first.backupPath).Hash -eq $backupHash) 'Rerun overwrote original metadata backup.'
    foreach ($choice in $payload.GlobalChoices) {
        foreach ($expected in $choice.Options) {
            $actual = @($choices[$choice.Name].Options | Where-Object Value -eq $expected.Value)[0]
            Assert-Test ($actual.Label.LocalizedLabels[0].Label -ceq (Get-WizardChoiceDisplayLabel $expected)) 'Rendered label is incorrect.'
            Assert-Test ($actual.Color -ceq (Get-WizardChoiceColor $expected)) 'Pastel color is incorrect.'
            Assert-Test ($actual.Label.LocalizedLabels[1].Label -ceq 'Preserve translation') 'Other language changed.'
        }
    }
    Write-Host 'Global Choice presentation tests passed: 26 sets, 162 options, full no-write preflight, original backup, exact style, and zero-write rerun.'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
