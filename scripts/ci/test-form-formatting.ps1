<#
=============================================================================
COMPONENT:    Dataverse Form Formatter Tests
FILE:         scripts/ci/test-form-formatting.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-09-30
ENVIRONMENT:  PowerShell 7 | Credential-Free CI

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Exercises Version 1 form formatting through an injected Dataverse transport.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Preview emits stable review artifacts without mutation.
✔ Apply enforces the approved hash, snapshots, patches, scoped-publishes,
  verifies readback, records a manifest item, and is idempotent.
✔ Unsafe ownership, unknown fields, duplicates, and malformed XML fail closed.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scriptPath = Join-Path $repoRoot 'scripts\bootstrap\63-format-forms.ps1'
$workRoot = Join-Path $repoRoot '.wizard-metrics\test-work\form-formatting'
$scenario = 'formatter-test'

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

function Write-Layout {
    param([string]$FieldName = 'ppvs_name', [switch]$Duplicate)
    $fields = if ($Duplicate) { @($FieldName, $FieldName) } else { @($FieldName, 'ppvs_requester') }
    [ordered]@{
        version = '1.0'
        forms = @(
            [ordered]@{
                tableLogicalName = 'ppvs_request'
                formName = 'Request Main'
                ownership = 'wizard-owned-only'
                tabs = @(
                    [ordered]@{
                        key = 'summary'
                        label = 'Summary'
                        layout = 'two-column'
                        sections = @(
                            [ordered]@{
                                key = 'request'
                                label = 'Request details'
                                columns = 2
                                fields = $fields
                            },
                            [ordered]@{
                                key = 'notes'
                                label = 'Notes'
                                columns = 3
                                fields = @(
                                    'ppvs_notes',
                                    [ordered]@{ logicalName = 'ppvs_approved'; component = 'toggle' }
                                )
                            },
                            [ordered]@{
                                key = 'routing'
                                label = 'Routing'
                                columns = 1
                                fields = @(
                                    [ordered]@{ logicalName = 'ppvs_routing'; component = 'option-set-wrapper' }
                                )
                            }
                        )
                    }
                )
                preserve = [ordered]@{
                    unlistedControls = $true
                    eventHandlers = $true
                    formLibraries = $true
                    headersAndFooters = $true
                }
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $workRoot "specs\$scenario\form-layouts.json") -Encoding UTF8
}

function New-Attribute {
    param([string]$Name, [string]$Label, [string]$Type = 'String')
    return [pscustomobject]@{
        LogicalName = $Name
        AttributeType = $Type
        IsValidForForm = $true
        DisplayName = [pscustomobject]@{
            LocalizedLabels = @([pscustomobject]@{ LanguageCode = 1033; Label = $Label })
        }
    }
}

if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $workRoot "specs\$scenario") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $workRoot 'schemas\payloads') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot 'schemas\payloads\form-layouts.schema.json') -Destination (Join-Path $workRoot 'schemas\payloads\form-layouts.schema.json')

$env:WIZARD_FORM_FORMATTING_SKIP_MAIN = 'true'
. $scriptPath -ScenarioSlug $scenario

$script:Form = [pscustomobject]@{
    formid = '11111111-1111-1111-1111-111111111111'
    name = 'Request Main'
    type = 2
    description = "Generated by 60-build-forms-views.ps1; scenario=$scenario"
    ismanaged = $false
    formactivationstate = 1
    iscustomizable = [pscustomobject]@{ Value = $true }
    formxml = "<form><formLibraries><Library name='keep.js'/></formLibraries><header><rows><row id='keep-empty-header-row'/><row><cell><control id='keep-header' datafieldname='ppvs_header'/></cell></row></rows></header><tabs><tab name='General'><labels><label description='General' languagecode='1033'/></labels><columns><column><sections><section name='unowned'><labels><label description='Original' languagecode='1033'/></labels><rows><row><cell><control id='ppvs_name' classid='{text-control}' datafieldname='ppvs_name'/></cell><cell><control id='keep-unknown' datafieldname='ppvs_unknown'/></cell></row><row><cell><control id='ppvs_requester' classid='{lookup-control}' datafieldname='ppvs_requester'><parameters><TargetEntityType>contact</TargetEntityType></parameters></control></cell></row><row><cell><control id='ppvs_notes' classid='{notes-control}' datafieldname='ppvs_notes'/></cell><cell><control id='ppvs_approved' classid='{boolean-control}' datafieldname='ppvs_approved'/></cell><cell><control id='ppvs_routing' classid='{choice-control}' datafieldname='ppvs_routing'/></cell></row></rows></section></sections></column></columns></tab></tabs><footer><rows><row id='keep-empty-footer-row'/><row><cell><control id='keep-footer'/></cell></row></rows></footer></form>"
}
$script:Attributes = @(
    (New-Attribute 'ppvs_name' 'Request name'),
    (New-Attribute 'ppvs_requester' 'Requester'),
    (New-Attribute 'ppvs_notes' 'Notes'),
    (New-Attribute 'ppvs_approved' 'Approved' 'Boolean'),
    (New-Attribute 'ppvs_routing' 'Routing' 'Picklist'),
    (New-Attribute 'ppvs_header' 'Header'),
    (New-Attribute 'ppvs_unknown' 'Unknown')
)
$script:FormQueryResults = @($script:Form)
$script:IsCustomEntity = $true
$script:Requests = [Collections.Generic.List[object]]::new()
$script:Invoker = {
    param($Request)
    $marker = '/api/data/v9.2/'
    $path = $Request.Uri.Substring($Request.Uri.IndexOf($marker) + $marker.Length)
    $script:Requests.Add([pscustomobject]@{ Method = $Request.Method; Path = $path; Body = $Request.Body }) | Out-Null
    if ($Request.Method -eq 'Get' -and $path -like "EntityDefinitions(LogicalName='ppvs_request')/Attributes?*") {
        return [pscustomobject]@{ value = @($script:Attributes) }
    }
    if ($Request.Method -eq 'Get' -and $path -like "EntityDefinitions(LogicalName='ppvs_request')?*") {
        return [pscustomobject]@{ LogicalName = 'ppvs_request'; IsCustomEntity = $script:IsCustomEntity }
    }
    if ($Request.Method -eq 'Get' -and $path.StartsWith('systemforms?', [StringComparison]::Ordinal)) {
        return [pscustomobject]@{ value = @($script:FormQueryResults) }
    }
    if ($Request.Method -eq 'Get' -and $path -like 'systemforms(*') {
        return $script:Form
    }
    if ($Request.Method -eq 'Patch' -and $path -like 'systemforms(*') {
        $script:Form.formxml = ($Request.Body | ConvertFrom-Json).formxml
        return [pscustomobject]@{}
    }
    if ($Request.Method -eq 'Post' -and $path -eq 'PublishXml') { return [pscustomobject]@{} }
    throw "Unexpected mocked request: $($Request.Method) $path"
}

try {
    Write-Layout
    $preview = Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    Assert-True ($preview.ChangedCount -eq 1) 'Preview should report one planned update.'
    Assert-True (@($script:Requests | Where-Object Method -ne 'Get').Count -eq 0) 'Preview issued a mutation.'
    foreach ($artifact in @('form-formatting-plan.json', 'form-formatting-diff.md', 'form-formatting-preview.html', 'form-formatting-report.json')) {
        Assert-True (Test-Path (Join-Path $preview.ArtifactFolder $artifact)) "Missing preview artifact '$artifact'."
    }
    $html = Get-Content -LiteralPath (Join-Path $preview.ArtifactFolder 'form-formatting-preview.html') -Raw
    Assert-True ($html -like '*Approximation:*' -and $html -like '*<main>*' -and $html -like '*Component: toggle*' -and $html -like '*Component: option-set-wrapper*') 'HTML preview does not clearly show the planned layout and field components.'

    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Apply -ApprovedPlanHash ('0' * 64) -SolutionUniqueName 'FormatterSolution' -PublisherPrefix 'ppvs' -RequestInvoker $script:Invoker
    } '*ApprovedPlanHash mismatch*'

    $script:Requests.Clear()
    $apply = Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Apply -ApprovedPlanHash $preview.PlanHash -SolutionUniqueName 'FormatterSolution' -PublisherPrefix 'ppvs' -RequestInvoker $script:Invoker
    Assert-True (@($script:Requests | Where-Object Method -eq 'Patch').Count -eq 1) 'First apply should patch exactly one form.'
    Assert-True (@($script:Requests | Where-Object { $_.Method -eq 'Post' -and $_.Path -eq 'PublishXml' }).Count -eq 1) 'First apply should publish once.'
    $publishBody = @($script:Requests | Where-Object Path -eq 'PublishXml')[0].Body | ConvertFrom-Json
    Assert-True ($publishBody.ParameterXml -eq '<importexportxml><entities><entity>ppvs_request</entity></entities></importexportxml>') 'PublishXml was not table-scoped.'
    Assert-True (Test-Path (Join-Path $apply.ArtifactFolder 'form-formatting-before\11111111-1111-1111-1111-111111111111.formxml.xml')) 'Original FormXml snapshot is missing.'
    Assert-True ($script:Form.formxml -like '*keep-unknown*' -and $script:Form.formxml -like '*keep.js*' -and $script:Form.formxml -like '*keep-header*' -and $script:Form.formxml -like '*keep-footer*' -and $script:Form.formxml -like '*keep-empty-header-row*' -and $script:Form.formxml -like '*keep-empty-footer-row*') 'Unowned or unknown XML was not preserved.'
    Assert-True ($script:Form.formxml -like '*wizard-formatter-formatter-test-ppvs_request-tab-summary*') 'Formatter-owned tab was not generated.'
    Assert-True ($script:Form.formxml -like "*classid=`"{lookup-control}`"*" -and $script:Form.formxml -like '*<TargetEntityType>contact</TargetEntityType>*') 'Existing lookup control configuration was not preserved.'
    Assert-True ($script:Form.formxml -like '*name="MscrmControls.FieldControls.ToggleControl"*' -and $script:Form.formxml -like '*type="TwoOptions">ppvs_approved</value>*') 'Boolean Toggle component was not applied for all form factors.'
    Assert-True ($script:Form.formxml -like '*name="MscrmControls.OptionSet.OptionSetControl"*' -and $script:Form.formxml -like '*type="OptionSet">ppvs_routing</value>*') 'Choice OptionSet Wrapper component was not applied for all form factors.'
    [xml]$formatted = $script:Form.formxml
    Assert-True ($formatted.SelectNodes('/form/controlDescriptions/controlDescription/customControl[@name="MscrmControls.FieldControls.ToggleControl"]').Count -eq 3) 'Toggle component was not configured for web, tablet, and phone.'
    Assert-True ($formatted.SelectNodes('/form/controlDescriptions/controlDescription/customControl[@name="MscrmControls.OptionSet.OptionSetControl"]').Count -eq 3) 'OptionSet Wrapper was not configured for web, tablet, and phone.'
    $ids = @($formatted.SelectNodes('//*[@id]') | ForEach-Object { $_.GetAttribute('id') })
    Assert-True (@($ids | Group-Object | Where-Object Count -gt 1).Count -eq 0) 'Generated XML contains duplicate IDs.'
    $manifest = Get-Content -LiteralPath (Join-Path $workRoot ".wizard-metrics\artifacts\manifest\$scenario\generated-artifact-manifest.json") -Raw | ConvertFrom-Json
    Assert-True (@($manifest.items | Where-Object kind -eq 'form-formatting').Count -eq 1) 'Form formatting manifest item is missing.'

    $firstXml = $script:Form.formxml
    $script:Requests.Clear()
    $second = Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Apply -ApprovedPlanHash $preview.PlanHash -SolutionUniqueName 'FormatterSolution' -PublisherPrefix 'ppvs' -RequestInvoker $script:Invoker
    Assert-True ($second.ChangedCount -eq 0) 'Second apply should be unchanged.'
    Assert-True (@($script:Requests | Where-Object Method -in @('Patch', 'Post')).Count -eq 0) 'Second apply issued a mutation.'
    Assert-True ($script:Form.formxml -ceq $firstXml) 'Second apply changed FormXml.'

    Write-Layout -FieldName 'ppvs_missing'
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } "*Unknown field 'ppvs_missing'*"

    Write-Layout -Duplicate
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } "*Duplicate field*"

    Write-Layout
    @($script:Attributes | Where-Object LogicalName -eq 'ppvs_routing')[0].AttributeType = 'String'
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } "*component 'option-set-wrapper'*not 'Picklist'*"
    @($script:Attributes | Where-Object LogicalName -eq 'ppvs_routing')[0].AttributeType = 'Picklist'
    @($script:Attributes | Where-Object LogicalName -eq 'ppvs_approved')[0].AttributeType = 'String'
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } "*component 'toggle'*not 'Boolean'*"
    @($script:Attributes | Where-Object LogicalName -eq 'ppvs_approved')[0].AttributeType = 'Boolean'

    Write-Layout
    $savedMarker = $script:Form.description
    $script:Form.description = 'not wizard owned'
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } '*exact step 60 ownership marker*'
    $script:Form.description = $savedMarker

    $savedXml = $script:Form.formxml
    $script:Form.formxml = '<form><broken></form>'
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } '*Invalid FormXml*'
    $script:Form.formxml = $savedXml

    $script:FormQueryResults = @(
        $script:Form,
        [pscustomobject]@{
            formid = '22222222-2222-2222-2222-222222222222'
            name = $script:Form.name
            type = 2
            description = $script:Form.description
            ismanaged = $false
            iscustomizable = [pscustomobject]@{ Value = $true }
            formxml = $script:Form.formxml
        }
    )
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } '*Ambiguous Main form*'
    $script:FormQueryResults = @($script:Form)

    $layoutDocument = Get-Content -LiteralPath (Join-Path $workRoot "specs\$scenario\form-layouts.json") -Raw | ConvertFrom-Json
    $layoutDocument.forms[0] | Add-Member -NotePropertyName formId -NotePropertyValue $script:Form.formid
    $layoutDocument.forms[0].formName = 'Wrong Main'
    $layoutDocument | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $workRoot "specs\$scenario\form-layouts.json") -Encoding UTF8
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } "*resolved to 'Request Main', not declared form 'Wrong Main'*"
    Write-Layout

    $script:Form.ismanaged = $true
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } '*managed/noncustom*'
    $script:Form.ismanaged = $false

    $script:IsCustomEntity = $false
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } '*Version 1 formats wizard-owned custom forms only*'
    $script:IsCustomEntity = $true

    $script:Form.formactivationstate = 0
    Assert-ThrowsLike {
        Invoke-WizardFormFormatting -RepoRoot $workRoot -ScenarioSlug $scenario -Mode Preview -RequestInvoker $script:Invoker
    } '*inactive and cannot be formatted*'
    $script:Form.formactivationstate = 1

    $profile = Get-Content -LiteralPath (Join-Path $repoRoot 'wizard.profile.json') -Raw | ConvertFrom-Json
    Assert-True ($profile.execution.optionalModules.'form-formatting'.script -ceq '63-format-forms.ps1') 'Wizard profile does not register the optional form-formatting module.'
    $orchestratorText = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\bootstrap\90-run-build.ps1') -Raw
    Assert-True ($orchestratorText -match '\[string\]\$ApprovedFormFormattingPlanHash') 'Orchestrator does not expose the approved form-formatting plan hash.'
    $appIndex = $orchestratorText.IndexOf("Name = 'app-module'")
    $formatterIndex = $orchestratorText.IndexOf("Name = 'form-formatting'")
    $membershipIndex = $orchestratorText.IndexOf("Name = 'solution-membership-first-pass'")
    Assert-True ($appIndex -ge 0 -and $formatterIndex -gt $appIndex -and $membershipIndex -gt $formatterIndex) 'Form formatting is not ordered after app assembly and before solution membership.'
    Assert-True ($orchestratorText -match 'Name = ''rerun-form-formatting''.+Enabled = \$hasFormLayout') 'Orchestrator does not include the enabled formatter idempotency rerun.'

    Write-Host 'Form formatting tests passed: preview safety, 1/2/3-column artifacts, control preservation, approval, apply verification, orchestration, manifest, scoped publish, rejection paths, and idempotency.' -ForegroundColor Green
} finally {
    $env:WIZARD_FORM_FORMATTING_SKIP_MAIN = $null
    if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
}
