<#
=============================================================================
COMPONENT:    Choice Dependency Preparation Tests
FILE:         scripts/ci/test-choice-dependency-preparation.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Credential-free Dataverse mocks
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$stage = Join-Path $repoRoot 'scripts/bootstrap/37-prepare-choice-dependencies.ps1'
$payloadFolder = Join-Path $repoRoot 'payloads/scenarios/federal-foia-management'
$migration = Get-Content -LiteralPath (Join-Path $payloadFolder 'choice-migration-federal-foia-management.json') -Raw |
    ConvertFrom-Json -Depth 40
$reporting = Get-Content -LiteralPath (Join-Path $payloadFolder 'reporting-federal-foia-management.json') -Raw |
    ConvertFrom-Json -Depth 30

function New-TestGuid {
    param([Parameter(Mandatory)] [string]$Seed)
    return [Guid]::new([Security.Cryptography.MD5]::HashData([Text.Encoding]::UTF8.GetBytes($Seed))).ToString()
}

$allFields = @($migration.Bindings | ForEach-Object { "$($_.TableLogicalName).$($_.ColumnLogicalName)" })
$components = [System.Collections.Generic.List[object]]::new()
foreach ($typeAndCount in @(@(26, 13), @(29, 2), @(60, 15))) {
    for ($index = 0; $index -lt $typeAndCount[1]; $index++) {
        $type = $typeAndCount[0]
        [void]$components.Add([pscustomobject]@{
            Type = $type
            Id = New-TestGuid "$type|$index"
            Name = "Unit $type $index"
            Table = if ($type -eq 60 -and $index -lt 2) { "foia_federal_foia_unit_${index}_lifecycle" } else { "unit_table_$index" }
            Fields = [System.Collections.Generic.List[string]]::new()
        })
    }
}

$chartSpecs = @(
    @('Active Requests by Lifecycle Stage', 'foia_foiarequest.foia_lifecyclestage'),
    @('Appeals by Outcome', 'foia_appeal.foia_outcome'),
    @('Approved Exemptions by Authority', 'foia_exemptiondecision.foia_approvalstate'),
    @('Clock Events by Type', 'foia_clockevent.foia_eventtype'),
    @('Expedited Requests by Decision', 'foia_foiarequest.foia_expediteddecision'),
    @('Open Reviews by Type', 'foia_reviewtask.foia_reviewtype'),
    @('Release Packages by Approval State', 'foia_releasepackage.foia_approvalstate')
)
for ($index = 0; $index -lt $chartSpecs.Count; $index++) {
    $chartPayload = @($reporting.Charts | Where-Object Name -ceq $chartSpecs[$index][0])[0]
    $component = [pscustomobject]@{
        Type = 59
        Id = New-TestGuid "59|$index"
        Name = $chartSpecs[$index][0]
        Table = "$($chartPayload.TableLogicalName)"
        Fields = [System.Collections.Generic.List[string]]::new()
    }
    [void]$component.Fields.Add($chartSpecs[$index][1])
    [void]$components.Add($component)
}

$fieldIndex = 0
foreach ($component in @($components | Where-Object Type -ne 59)) {
    [void]$component.Fields.Add($allFields[$fieldIndex % $allFields.Count])
    $fieldIndex++
}
while (($components | ForEach-Object Fields | Measure-Object).Count -lt 60) {
    foreach ($component in $components) {
        if (($components | ForEach-Object Fields | Measure-Object).Count -ge 60) { break }
        $candidate = $allFields[$fieldIndex % $allFields.Count]
        $fieldIndex++
        if ($component.Fields -contains $candidate) { continue }
        [void]$component.Fields.Add($candidate)
    }
}

$bindings = [System.Collections.Generic.List[object]]::new()
foreach ($binding in $migration.Bindings) {
    $field = "$($binding.TableLogicalName).$($binding.ColumnLogicalName)"
    $dependencies = [System.Collections.Generic.List[object]]::new()
    foreach ($component in @($components | Where-Object { $_.Fields -contains $field })) {
        [void]$dependencies.Add([pscustomobject]@{
            dependencyId = New-TestGuid "dependency|$field|$($component.Id)"
            dependentComponentType = $component.Type
            dependentComponentObjectId = $component.Id
            dependencyType = 2
        })
    }
    [void]$bindings.Add([pscustomobject]@{
        tableLogicalName = "$($binding.TableLogicalName)"
        columnLogicalName = "$($binding.ColumnLogicalName)"
        dependencies = @($dependencies)
    })
}

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "foia-choice-dependency-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
try {
    $evidencePath = Join-Path $fixtureRoot 'preview.json'
    $handoffPath = Join-Path $fixtureRoot 'handoff.md'
    $outputPath = Join-Path $fixtureRoot 'prepared.json'
    [ordered]@{
        scenarioSlug = 'federal-foia-management'
        mode = 'Preview'
        mutationCount = 0
        bindingCount = 29
        bindings = @($bindings)
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    ($components.Id | ForEach-Object { "- $_" }) -join "`n" |
        Set-Content -LiteralPath $handoffPath -Encoding UTF8

    $calls = [System.Collections.Generic.List[object]]::new()
    $requestInvoker = {
        param($request)
        if ("$($request.Method)" -ne 'Get') { throw "Unexpected mutation: $($request.Method)" }
        $path = [Uri]::UnescapeDataString(($request.Uri -split '/api/data/v9.2/')[1])
        [void]$calls.Add([pscustomobject]@{ Method = "$($request.Method)"; Path = $path })
        if ($path -notmatch '^(?<set>savedqueries|workflows|savedqueryvisualizations|systemforms)\((?<id>[0-9a-f-]+)\)') {
            throw "Unexpected request: $path"
        }
        $component = @($components | Where-Object Id -eq $Matches.id)
        if ($component.Count -ne 1) { throw "Unknown component: $path" }
        $component = $component[0]
        $columns = @($component.Fields | ForEach-Object { ($_ -split '\.', 2)[1] })
        switch ($component.Type) {
            26 {
                $attributes = $columns | ForEach-Object { "<attribute name='$_'/>" }
                $cells = $columns | ForEach-Object { "<cell name='$_' width='100'/>" }
                return [pscustomobject]@{
                    savedqueryid = $component.Id; name = $component.Name; returnedtypecode = $component.Table
                    fetchxml = "<fetch><entity name='$($component.Table)'>$($attributes -join '')</entity></fetch>"
                    layoutxml = "<grid><row>$($cells -join '')</row></grid>"
                }
            }
            29 {
                return [pscustomobject]@{
                    workflowid = $component.Id; name = $component.Name; uniquename = "unit_$($component.Id.Replace('-', ''))"
                    category = 4; statecode = 1; statuscode = 2
                }
            }
            59 {
                $chartPayload = @($reporting.Charts | Where-Object Name -ceq $component.Name)[0]
                $target = $columns[0]
                $targetXml = if ($component.Name -ceq 'Approved Exemptions by Authority') {
                    "<attribute name='$($chartPayload.CategoryField)' alias='group' groupby='true'/><filter><condition attribute='$target' operator='eq' value='Approved'/></filter>"
                } else {
                    "<attribute name='$target' alias='group' groupby='true'/>"
                }
                return [pscustomobject]@{
                    savedqueryvisualizationid = $component.Id; name = $component.Name
                    primaryentitytypecode = $component.Table
                    datadescription = "<visualization><datadefinition><fetchcollection><fetch aggregate='true'><entity name='$($component.Table)'><attribute name='$($chartPayload.AggregateField)' alias='aggregate' aggregate='$($chartPayload.Aggregate)'/>$targetXml</entity></fetch></fetchcollection></datadefinition></visualization>"
                    presentationdescription = '<Chart><Series/></Chart>'
                }
            }
            60 {
                $controls = $columns | ForEach-Object { "<cell><control id='$_' datafieldname='$_'/></cell>" }
                return [pscustomobject]@{
                    formid = $component.Id; name = $component.Name; objecttypecode = $component.Table; type = 2
                    formxml = "<form><tabs><tab><columns><column><sections><section><rows><row>$($controls -join '')</row></rows></section></sections></column></columns></tab></tabs></form>"
                }
            }
        }
    }.GetNewClosure()

    & $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder -Mode Preview `
        -EnvironmentUrl 'https://unit.test' -AccessToken 'token' -PreviewEvidencePath $evidencePath `
        -HandoffPath $handoffPath -OutputPath $outputPath -RequestInvoker $requestInvoker

    $result = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json -Depth 40
    if ($result.referenceCount -ne 60 -or $result.componentCount -ne 37 -or
        $result.stage60ComponentCount -ne 26 -or $result.stage64ComponentCount -ne 7 -or
        $result.designerComponentCount -ne 4 -or $result.mutationCount -ne 0) {
        throw 'Dependency preparation evidence has incorrect counts.'
    }
    if ($calls.Count -ne 37 -or @($calls | Where-Object Method -ne 'Get').Count -ne 0) {
        throw 'Dependency preparation did not make exactly 37 GET-only component requests.'
    }
    $automated = @($result.components | Where-Object handling -in @('stage-60', 'stage-64'))
    if (@($automated | Where-Object { $null -eq $_.temporary }).Count -ne 0) {
        throw 'An automated dependency has no temporary definition.'
    }

    $brokenHandoff = Join-Path $fixtureRoot 'broken-handoff.md'
    ($components.Id | Select-Object -Skip 1 | ForEach-Object { "- $_" }) -join "`n" |
        Set-Content -LiteralPath $brokenHandoff -Encoding UTF8
    try {
        & $stage -ScenarioSlug 'federal-foia-management' -PayloadsFolder $payloadFolder -Mode Offline `
            -PreviewEvidencePath $evidencePath -HandoffPath $brokenHandoff -OutputPath $outputPath
        throw 'Expected incomplete handoff failure.'
    } catch {
        if ($_.Exception.Message -notmatch 'does not cover component') { throw }
    }
} finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}

Write-Host 'Choice dependency preparation tests passed.' -ForegroundColor Green
