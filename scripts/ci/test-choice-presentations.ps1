<#
=============================================================================
COMPONENT:    Choice Presentation Tests
FILE:         scripts/ci/test-choice-presentations.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-01
ENVIRONMENT:  PowerShell 7 | Credential-Free CI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Validates pastel Choice colors and optional inline icon label prefixes without
contacting Dataverse.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scriptPath = Join-Path $repoRoot 'scripts\bootstrap\35-style-choice-options.ps1'
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ("choice-presentation-test-" + [guid]::NewGuid().ToString('N'))
$scenario = 'choice-presentation-test'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-ThrowsLike {
    param([scriptblock]$Action, [string]$Pattern)
    try {
        & $Action
        throw "Expected failure matching '$Pattern'."
    } catch {
        if ($_.Exception.Message -notlike $Pattern) { throw }
    }
}

function New-Option {
    param([int]$Value, [string]$Label, [string]$Color)
    [pscustomobject]@{
        Value = $Value
        Color = $Color
        Label = [pscustomobject]@{
            LocalizedLabels = @([pscustomobject]@{ Label = $Label; LanguageCode = 1033 })
        }
    }
}

if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $workRoot "payloads\scenarios\$scenario") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $workRoot 'schemas\payloads') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $workRoot "specs\$scenario") -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot 'schemas\payloads\choice-presentations.schema.json') -Destination (Join-Path $workRoot 'schemas\payloads')

$payloadFolder = Join-Path $workRoot "payloads\scenarios\$scenario"
[ordered]@{
    version = '1.0'
    TableLogicalName = 'contoso_case'
    ColumnLogicalName = 'contoso_allegationtype'
    Ownership = 'wizard-owned-unmanaged-local-choice'
    LanguageCode = 1033
    Options = @(
        [ordered]@{ Value = 100000000; Label = 'Unreported Earnings'; ColorToken = 'pastel-peach'; Icon = 'triangle-filled' },
        [ordered]@{ Value = 100000001; Label = 'Late-Reported Earnings'; ColorToken = 'pastel-lavender'; Icon = 'diamond-filled' },
        [ordered]@{ Value = 100000002; Label = 'Suspicious Wage Report'; ColorToken = 'pastel-blue'; Icon = 'info' }
    )
} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $payloadFolder 'choice-presentations-contoso-case.json') -Encoding UTF8

$env:WIZARD_CHOICE_PRESENTATION_SKIP_MAIN = 'true'
. $scriptPath

$script:Metadata = [pscustomobject]@{
    LogicalName = 'contoso_allegationtype'
    IsManaged = $false
    OptionSet = [pscustomobject]@{
        IsGlobal = $false
        IsCustomOptionSet = $true
        Options = @(
            (New-Option 100000000 'Unreported Earnings' '#FFFFFF'),
            (New-Option 100000001 'Late-Reported Earnings' '#FFFFFF'),
            (New-Option 100000002 'Suspicious Wage Report' '#FFFFFF')
        )
    }
}
$script:Requests = [Collections.Generic.List[object]]::new()
$script:Invoker = {
    param($Request)
    $marker = '/api/data/v9.2/'
    $path = $Request.Uri.Substring($Request.Uri.IndexOf($marker) + $marker.Length)
    $body = if ($null -eq $Request.Body) { $null } else { $Request.Body | ConvertFrom-Json }
    $script:Requests.Add([pscustomobject]@{ Method = $Request.Method; Path = $path; Body = $body }) | Out-Null
    if ($Request.Method -eq 'Get' -and $path -like "EntityDefinitions(LogicalName='contoso_case')/Attributes*") {
        return $script:Metadata
    }
    if ($Request.Method -eq 'Post' -and $path -eq 'UpdateOptionValue') {
        $option = @($script:Metadata.OptionSet.Options | Where-Object Value -eq ([int]$body.Value))[0]
        $option.Color = "$($body.Color)"
        $option.Label = $body.Label
        return [pscustomobject]@{}
    }
    if ($Request.Method -eq 'Post' -and $path -eq 'PublishXml') { return [pscustomobject]@{} }
    throw "Unexpected mocked request: $($Request.Method) $path"
}

try {
    $preview = Invoke-WizardChoicePresentation -RepoRoot $workRoot -ScenarioSlug $scenario -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://choice.invalid' -AccessToken 'injected-request-token' -SolutionUniqueName 'ChoiceSolution' -PublisherPrefix 'contoso' -ApprovedPlanHash '' -PreviewOnly -RequestInvoker $script:Invoker
    Assert-True ($preview.ChangedCount -eq 1) 'Preview did not report its choice contract.'
    Assert-True ($script:Requests.Count -eq 0) 'Preview contacted Dataverse.'
    $previewHtml = Get-Content -LiteralPath (Join-Path $preview.ArtifactFolder 'choice-presentation-preview.html') -Raw
    Assert-True ($previewHtml -like '*▲ Unreported Earnings*' -and $previewHtml -like '*#FAD7A0*') 'Preview omitted the inline icon or pastel color.'

    Assert-ThrowsLike {
        Invoke-WizardChoicePresentation -RepoRoot $workRoot -ScenarioSlug $scenario -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://choice.invalid' -AccessToken 'injected-request-token' -SolutionUniqueName 'ChoiceSolution' -PublisherPrefix 'contoso' -ApprovedPlanHash ('0' * 64) -RequestInvoker $script:Invoker
    } '*ApprovedPlanHash mismatch*'

    $script:Requests.Clear()
    $apply = Invoke-WizardChoicePresentation -RepoRoot $workRoot -ScenarioSlug $scenario -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://choice.invalid' -AccessToken 'injected-request-token' -SolutionUniqueName 'ChoiceSolution' -PublisherPrefix 'contoso' -ApprovedPlanHash $preview.PlanHash -RequestInvoker $script:Invoker
    Assert-True ($apply.ChangedCount -eq 3) 'Apply did not update all three options.'
    Assert-True (@($script:Requests | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'UpdateOptionValue' }).Count -eq 3) 'Apply issued an unexpected number of UpdateOptionValue actions.'
    Assert-True (@($script:Requests | Where-Object Path -eq 'PublishXml').Count -eq 1) 'Apply did not publish exactly once.'
    Assert-True ($script:Metadata.OptionSet.Options[0].Label.LocalizedLabels[0].Label -ceq '▲ Unreported Earnings') 'Inline icon was not written into the Choice label.'
    Assert-True ($script:Metadata.OptionSet.Options[1].Color -ceq '#D8C4F1') 'Pastel color was not written to option metadata.'

    $script:Requests.Clear()
    $rerun = Invoke-WizardChoicePresentation -RepoRoot $workRoot -ScenarioSlug $scenario -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://choice.invalid' -AccessToken 'injected-request-token' -SolutionUniqueName 'ChoiceSolution' -PublisherPrefix 'contoso' -ApprovedPlanHash $preview.PlanHash -RequestInvoker $script:Invoker
    Assert-True ($rerun.ChangedCount -eq 0) 'Idempotent rerun reported changes.'
    Assert-True (@($script:Requests | Where-Object Method -eq 'Post').Count -eq 0) 'Idempotent rerun issued a mutation.'

    $script:Metadata.OptionSet.IsGlobal = $true
    Assert-ThrowsLike {
        Invoke-WizardChoicePresentation -RepoRoot $workRoot -ScenarioSlug $scenario -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://choice.invalid' -AccessToken 'injected-request-token' -SolutionUniqueName 'ChoiceSolution' -PublisherPrefix 'contoso' -ApprovedPlanHash $preview.PlanHash -RequestInvoker $script:Invoker
    } '*Version 1 supports local Choices only*'
    $script:Metadata.OptionSet.IsGlobal = $false

    $script:Metadata.IsManaged = $true
    Assert-ThrowsLike {
        Invoke-WizardChoicePresentation -RepoRoot $workRoot -ScenarioSlug $scenario -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://choice.invalid' -AccessToken 'injected-request-token' -SolutionUniqueName 'ChoiceSolution' -PublisherPrefix 'contoso' -ApprovedPlanHash $preview.PlanHash -RequestInvoker $script:Invoker
    } '*is managed and cannot be styled*'
    $script:Metadata.IsManaged = $false

    $script:Metadata.OptionSet.IsCustomOptionSet = $false
    Assert-ThrowsLike {
        Invoke-WizardChoicePresentation -RepoRoot $workRoot -ScenarioSlug $scenario -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://choice.invalid' -AccessToken 'injected-request-token' -SolutionUniqueName 'ChoiceSolution' -PublisherPrefix 'contoso' -ApprovedPlanHash $preview.PlanHash -RequestInvoker $script:Invoker
    } '*does not use a custom local Choice*'
    $script:Metadata.OptionSet.IsCustomOptionSet = $true

    Assert-ThrowsLike {
        Invoke-WizardChoicePresentation -RepoRoot $workRoot -ScenarioSlug $scenario -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://choice.invalid' -AccessToken 'injected-request-token' -SolutionUniqueName 'ChoiceSolution' -PublisherPrefix 'wrong' -ApprovedPlanHash $preview.PlanHash -RequestInvoker $script:Invoker
    } "*outside publisher prefix 'wrong'*"

    $profile = Get-Content -LiteralPath (Join-Path $repoRoot 'wizard.profile.json') -Raw | ConvertFrom-Json
    Assert-True ($profile.execution.optionalModules.'choice-presentations'.script -ceq '35-style-choice-options.ps1') 'Wizard profile does not register stage 35.'
    $orchestrator = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\bootstrap\90-run-build.ps1') -Raw
    $columnsIndex = $orchestrator.IndexOf("Name = 'columns'")
    $choiceIndex = $orchestrator.IndexOf("Name = 'choice-presentations'")
    $relationshipsIndex = $orchestrator.IndexOf("Name = 'relationships'")
    Assert-True ($columnsIndex -ge 0 -and $choiceIndex -gt $columnsIndex -and $choiceIndex -lt $relationshipsIndex) 'Stage 35 is not ordered after columns and before relationships.'
    Assert-True ($orchestrator -match '\[string\]\$ApprovedChoicePresentationPlanHash') 'Orchestrator approval-hash parameter is missing.'

    Write-Host 'Choice presentation tests passed.' -ForegroundColor Green
} finally {
    $env:WIZARD_CHOICE_PRESENTATION_SKIP_MAIN = $null
    Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
}
