<#
=============================================================================
COMPONENT:    Prepare Choice-Migration Dependencies
FILE:         scripts/bootstrap/37-prepare-choice-dependencies.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API | GET-only preparation
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [string]$PayloadsFolder = '',
    [ValidateSet('Offline', 'Preview')] [string]$Mode = 'Offline',
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$PreviewEvidencePath = '',
    [string]$HandoffPath = '',
    [string]$OutputPath = '',
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')

function Get-ChoiceDependencyInputs {
    param(
        [Parameter(Mandatory)] [string]$PayloadFolder,
        [Parameter(Mandatory)] [string]$EvidenceFile,
        [Parameter(Mandatory)] [string]$HandoffFile
    )

    if (-not (Test-Path -LiteralPath $EvidenceFile -PathType Leaf)) {
        throw "Stage 35 Preview evidence was not found at '$EvidenceFile'."
    }
    if (-not (Test-Path -LiteralPath $HandoffFile -PathType Leaf)) {
        throw "Choice-migration dependency handoff was not found at '$HandoffFile'."
    }

    $evidence = Get-Content -LiteralPath $EvidenceFile -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 40
    if ("$($evidence.scenarioSlug)" -cne $ScenarioSlug -or "$($evidence.mode)" -cne 'Preview' -or
        [int]$evidence.mutationCount -ne 0 -or [int]$evidence.bindingCount -ne 29) {
        throw 'Stage 35 evidence must match the scenario and contain a mutation-free 29-binding Preview.'
    }

    $references = [System.Collections.Generic.List[object]]::new()
    foreach ($binding in @($evidence.bindings)) {
        $field = "$($binding.tableLogicalName).$($binding.columnLogicalName)"
        foreach ($dependency in @($binding.dependencies)) {
            [void]$references.Add([pscustomobject]@{
                ComponentType = [int]$dependency.dependentComponentType
                ObjectId = "$($dependency.dependentComponentObjectId)".ToLowerInvariant()
                Field = $field
            })
        }
    }
    if ($references.Count -ne 60) {
        throw "Choice dependency preparation requires exactly 60 references; found $($references.Count)."
    }

    $supportedTypes = @(26, 29, 59, 60)
    $unsupported = @($references | Where-Object ComponentType -notin $supportedTypes)
    if ($unsupported.Count -gt 0) {
        throw "Choice dependency preparation found unsupported component type '$($unsupported[0].ComponentType)'."
    }

    $components = @($references | Group-Object ComponentType, ObjectId | ForEach-Object {
        $first = $_.Group[0]
        [pscustomobject]@{
            ComponentType = $first.ComponentType
            ObjectId = $first.ObjectId
            ImpactedFields = @($_.Group.Field | Sort-Object -Unique)
        }
    } | Sort-Object ComponentType, ObjectId)
    if ($components.Count -ne 37) {
        throw "Choice dependency preparation requires exactly 37 unique components; found $($components.Count)."
    }

    $expectedCounts = @{ 26 = 13; 29 = 2; 59 = 7; 60 = 15 }
    foreach ($componentType in $expectedCounts.Keys) {
        $actual = @($components | Where-Object ComponentType -eq $componentType).Count
        if ($actual -ne $expectedCounts[$componentType]) {
            throw "Component type $componentType requires $($expectedCounts[$componentType]) unique components; found $actual."
        }
    }

    $handoff = Get-Content -LiteralPath $HandoffFile -Raw -Encoding UTF8
    $missingIds = @($components | Where-Object { $handoff -notmatch [regex]::Escape($_.ObjectId) })
    if ($missingIds.Count -gt 0) {
        throw "Dependency handoff does not cover component '$($missingIds[0].ObjectId)'."
    }

    $reportingFiles = @(Get-ChildItem -LiteralPath $PayloadFolder -Filter 'reporting-*.json' -File)
    if ($reportingFiles.Count -ne 1) {
        throw "Expected exactly one reporting payload in '$PayloadFolder'; found $($reportingFiles.Count)."
    }
    $reporting = Get-Content -LiteralPath $reportingFiles[0].FullName -Raw -Encoding UTF8 |
        ConvertFrom-Json -Depth 30

    return [pscustomobject]@{
        Evidence = $evidence
        References = @($references)
        Components = $components
        Reporting = $reporting
    }
}

function Remove-XmlNodes {
    param(
        [Parameter(Mandatory)] [xml]$Document,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Xml.XmlNode[]]$Nodes
    )

    foreach ($node in @($Nodes)) {
        if ($null -ne $node.ParentNode) {
            [void]$node.ParentNode.RemoveChild($node)
        }
    }
}

function Assert-FieldsRemoved {
    param(
        [Parameter(Mandatory)] [string[]]$XmlValues,
        [Parameter(Mandatory)] [string[]]$Fields,
        [Parameter(Mandatory)] [string]$Component
    )

    $combined = $XmlValues -join "`n"
    foreach ($field in $Fields) {
        $column = ($field -split '\.', 2)[1]
        if ($combined -match "(?i)(['`"])$([regex]::Escape($column))\1") {
            throw "Temporary definition for '$Component' still references '$field'."
        }
    }
}

function New-TemporaryViewDefinition {
    param(
        [Parameter(Mandatory)] [object]$Live,
        [Parameter(Mandatory)] [string[]]$Fields
    )

    [xml]$fetch = "$($Live.fetchxml)"
    [xml]$layout = "$($Live.layoutxml)"
    foreach ($field in $Fields) {
        $column = ($field -split '\.', 2)[1]
        $literal = $column.Replace("'", "&apos;")
        Remove-XmlNodes -Document $fetch -Nodes @($fetch.SelectNodes("//attribute[@name='$literal']"))
        Remove-XmlNodes -Document $fetch -Nodes @($fetch.SelectNodes("//order[@attribute='$literal']"))
        Remove-XmlNodes -Document $fetch -Nodes @($fetch.SelectNodes("//condition[@attribute='$literal']"))
        Remove-XmlNodes -Document $layout -Nodes @($layout.SelectNodes("//cell[@name='$literal']"))
    }
    Assert-FieldsRemoved -XmlValues @($fetch.OuterXml, $layout.OuterXml) -Fields $Fields -Component "$($Live.name)"
    return [pscustomobject]@{ fetchXml = $fetch.OuterXml; layoutXml = $layout.OuterXml }
}

function New-TemporaryFormDefinition {
    param(
        [Parameter(Mandatory)] [object]$Live,
        [Parameter(Mandatory)] [string[]]$Fields
    )

    [xml]$form = "$($Live.formxml)"
    foreach ($field in $Fields) {
        $column = ($field -split '\.', 2)[1]
        $literal = $column.Replace("'", "&apos;")
        $controls = @($form.SelectNodes("//control[@datafieldname='$literal' or @id='$literal']"))
        foreach ($control in $controls) {
            $cell = $control
            while ($null -ne $cell -and "$($cell.Name)" -ne 'cell') { $cell = $cell.ParentNode }
            if ($null -eq $cell -or $null -eq $cell.ParentNode) {
                throw "Form '$($Live.name)' field '$field' is not contained by a removable cell."
            }
            [void]$cell.ParentNode.RemoveChild($cell)
        }
    }
    Assert-FieldsRemoved -XmlValues @($form.OuterXml) -Fields $Fields -Component "$($Live.name)"
    return [pscustomobject]@{ formXml = $form.OuterXml }
}

function New-TemporaryChartDefinition {
    param(
        [Parameter(Mandatory)] [object]$Live,
        [Parameter(Mandatory)] [string[]]$Fields,
        [Parameter(Mandatory)] [object]$ChartPayload
    )

    [xml]$data = "$($Live.datadescription)"
    $presentation = "$($Live.presentationdescription)"
    foreach ($field in $Fields) {
        $column = ($field -split '\.', 2)[1]
        $literal = $column.Replace("'", "&apos;")
        Remove-XmlNodes -Document $data -Nodes @($data.SelectNodes("//condition[@attribute='$literal']"))
        foreach ($attribute in @($data.SelectNodes("//attribute[@name='$literal']"))) {
            if ("$($attribute.groupby)" -ieq 'true') {
                $attribute.SetAttribute('name', "$($ChartPayload.AggregateField)")
            } else {
                throw "Chart '$($Live.name)' uses '$field' outside a removable filter or replaceable group-by."
            }
        }
    }
    Assert-FieldsRemoved -XmlValues @($data.OuterXml, $presentation) -Fields $Fields -Component "$($Live.name)"
    return [pscustomobject]@{
        dataDescription = $data.OuterXml
        presentationDescription = $presentation
    }
}

if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path $repoRoot "payloads/scenarios/$ScenarioSlug"
}
if ([string]::IsNullOrWhiteSpace($PreviewEvidencePath)) {
    $PreviewEvidencePath = Join-Path $repoRoot ".wizard-metrics/artifacts/choice-migration/$ScenarioSlug.json"
}
if ([string]::IsNullOrWhiteSpace($HandoffPath)) {
    $HandoffPath = Join-Path $repoRoot "specs/$ScenarioSlug/reports/choice-migration-dependency-handoff.md"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot ".wizard-metrics/artifacts/choice-migration/$ScenarioSlug-dependency-preparation.json"
}

$inputs = Get-ChoiceDependencyInputs -PayloadFolder $PayloadsFolder -EvidenceFile $PreviewEvidencePath `
    -HandoffFile $HandoffPath
$prepared = [System.Collections.Generic.List[object]]::new()

if ($Mode -eq 'Preview') {
    if (([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) -and
        (Test-Path -LiteralPath (Join-Path $repoRoot '.env.ps1'))) {
        $environment = Import-WizardEnvironment -RepoRoot $repoRoot
        $EnvironmentUrl = $environment.EnvironmentUrl
        $AccessToken = $environment.AccessToken
    }
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
        throw 'Dependency preparation Preview requires an environment URL and access token.'
    }
    $invoke = {
        param([string]$Path)
        Invoke-WizardDataverseRequest -Method Get -Path $Path -EnvironmentUrl $EnvironmentUrl `
            -AccessToken $AccessToken -RequestInvoker $RequestInvoker
    }

    foreach ($component in $inputs.Components) {
        $id = $component.ObjectId
        $fields = @($component.ImpactedFields)
        switch ($component.ComponentType) {
            26 {
                $live = & $invoke "savedqueries($id)?`$select=savedqueryid,name,returnedtypecode,fetchxml,layoutxml"
                if ("$($live.savedqueryid)".ToLowerInvariant() -ne $id) { throw "Saved view '$id' did not resolve exactly." }
                $temporary = New-TemporaryViewDefinition -Live $live -Fields $fields
                [void]$prepared.Add([pscustomobject]@{
                    componentType = 26; objectId = $id; name = "$($live.name)"; table = "$($live.returnedtypecode)"
                    handling = 'stage-60'; impactedFields = $fields
                    original = @{ fetchXml = "$($live.fetchxml)"; layoutXml = "$($live.layoutxml)" }
                    temporary = $temporary
                })
            }
            29 {
                $live = & $invoke "workflows($id)?`$select=workflowid,name,uniquename,category,statecode,statuscode"
                if ("$($live.workflowid)".ToLowerInvariant() -ne $id -or [int]$live.category -ne 4) {
                    throw "BPF '$id' did not resolve as a category-4 process."
                }
                [void]$prepared.Add([pscustomobject]@{
                    componentType = 29; objectId = $id; name = "$($live.name)"; uniqueName = "$($live.uniquename)"
                    handling = 'power-apps-designer'; impactedFields = $fields; original = $live; temporary = $null
                })
            }
            59 {
                $live = & $invoke "savedqueryvisualizations($id)?`$select=savedqueryvisualizationid,name,primaryentitytypecode,datadescription,presentationdescription"
                if ("$($live.savedqueryvisualizationid)".ToLowerInvariant() -ne $id) { throw "Chart '$id' did not resolve exactly." }
                $chartPayload = @($inputs.Reporting.Charts | Where-Object Name -ceq "$($live.name)")
                if ($chartPayload.Count -ne 1) { throw "Chart '$($live.name)' must resolve exactly one reporting definition." }
                $temporary = New-TemporaryChartDefinition -Live $live -Fields $fields -ChartPayload $chartPayload[0]
                [void]$prepared.Add([pscustomobject]@{
                    componentType = 59; objectId = $id; name = "$($live.name)"; table = "$($live.primaryentitytypecode)"
                    handling = 'stage-64'; impactedFields = $fields
                    original = @{ dataDescription = "$($live.datadescription)"; presentationDescription = "$($live.presentationdescription)" }
                    temporary = $temporary
                })
            }
            60 {
                $live = & $invoke "systemforms($id)?`$select=formid,name,objecttypecode,type,formxml"
                if ("$($live.formid)".ToLowerInvariant() -ne $id -or [int]$live.type -ne 2) {
                    throw "System form '$id' did not resolve as a main form."
                }
                $isBpfBackingForm = "$($live.objecttypecode)" -like 'foia_federal_foia_*_lifecycle'
                $temporary = if ($isBpfBackingForm) { $null } else {
                    New-TemporaryFormDefinition -Live $live -Fields $fields
                }
                [void]$prepared.Add([pscustomobject]@{
                    componentType = 60; objectId = $id; name = "$($live.name)"; table = "$($live.objecttypecode)"
                    handling = if ($isBpfBackingForm) { 'power-apps-designer-generated' } else { 'stage-60' }
                    impactedFields = $fields
                    original = @{ formXml = "$($live.formxml)" }
                    temporary = $temporary
                })
            }
        }
    }
} else {
    foreach ($component in $inputs.Components) {
        [void]$prepared.Add([pscustomobject]@{
            componentType = $component.ComponentType
            objectId = $component.ObjectId
            handling = if ($component.ComponentType -eq 29) { 'power-apps-designer' } else { 'resolve-in-preview' }
            impactedFields = @($component.ImpactedFields)
        })
    }
}

$stage60Count = @($prepared | Where-Object handling -eq 'stage-60').Count
$stage64Count = @($prepared | Where-Object handling -eq 'stage-64').Count
$designerCount = @($prepared | Where-Object handling -like 'power-apps-designer*').Count
if ($Mode -eq 'Preview' -and ($stage60Count -ne 26 -or $stage64Count -ne 7 -or $designerCount -ne 4)) {
    throw "Prepared component counts are invalid: stage 60=$stage60Count; stage 64=$stage64Count; designer=$designerCount."
}

New-Item -ItemType Directory -Path (Split-Path $OutputPath -Parent) -Force | Out-Null
[ordered]@{
    scenarioSlug = $ScenarioSlug
    mode = $Mode
    sourcePreviewEvidence = $PreviewEvidencePath
    referenceCount = $inputs.References.Count
    componentCount = $inputs.Components.Count
    stage60ComponentCount = $stage60Count
    stage64ComponentCount = $stage64Count
    designerComponentCount = $designerCount
    mutationCount = 0
    components = @($prepared)
} | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Choice dependency $Mode passed: 60 references; 37 components; 0 mutations." -ForegroundColor Green
