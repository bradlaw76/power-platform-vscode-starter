<#
=============================================================================
COMPONENT:    FOIA Global Choice Presentation
FILE:         scripts/bootstrap/38-style-global-choices.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-22
ENVIRONMENT:  PowerShell 7 | Dataverse Web API
OVERVIEW:     Apply original wizard pastel tokens and inline label symbols.
ARCHITECTURE: Migration inventory, hash-approved preview, global metadata actions.
TEST CASES:   No-write preview, full preflight, exact readback, zero-update rerun.
NON-NEGOTIABLES: Never insert/delete options, change IDs, or edit record values.
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ScenarioSlug,
    [Parameter(Mandatory)][string]$SolutionUniqueName,
    [Parameter(Mandatory)][string]$PublisherPrefix,
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [string]$AccessToken = '',
    [string]$ApprovedPlanHash = '',
    [switch]$PreviewOnly,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers\dataverse-runtime.ps1')
. (Join-Path $PSScriptRoot 'helpers\choice-migration-verification.ps1')

$payload = Get-WizardRequiredChoiceMigration -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionUniqueName $SolutionUniqueName -Required
$contracts = @($payload.GlobalChoices | Sort-Object Name | ForEach-Object {
    $choice = $_
    if (-not $choice.Name.StartsWith("${PublisherPrefix}_", [StringComparison]::Ordinal)) {
        throw "Choice '$($choice.Name)' is outside publisher '$PublisherPrefix'."
    }
    [ordered]@{
        name = $choice.Name
        options = @($choice.Options | Sort-Object Value | ForEach-Object {
            $color = Get-WizardChoiceColor -Option $_
            if ($null -eq $color) { throw "Choice '$($choice.Name)' lacks an explicit color for '$($_.Value)'." }
            [ordered]@{ value = $_.Value; semanticLabel = $_.Label; label = Get-WizardChoiceDisplayLabel -Option $_; color = $color }
        })
    }
})
$plan = [ordered]@{
    scenarioSlug = $ScenarioSlug; solutionUniqueName = $SolutionUniqueName
    publisherPrefix = $PublisherPrefix; environmentUrl = $EnvironmentUrl.TrimEnd('/')
    migrationId = $payload.MigrationId; choices = $contracts; bindings = $payload.Bindings
}
$hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
    [Text.Encoding]::UTF8.GetBytes(($plan | ConvertTo-Json -Depth 40 -Compress)))).ToLowerInvariant()
$folder = Join-Path $repoRoot ".wizard-metrics\artifacts\choice-presentations\$ScenarioSlug"
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$plan | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $folder 'preview.json') -Encoding utf8
$rows = foreach ($choice in $contracts) {
    foreach ($option in $choice.options) {
        $name = [Net.WebUtility]::HtmlEncode($choice.name)
        $label = [Net.WebUtility]::HtmlEncode($option.label)
        "<tr><td>$name</td><td>$($option.value)</td><td><span style='background:$($option.color);color:#242424;padding:4px 8px;border-radius:8px'>$label</span></td><td>$($option.color)</td></tr>"
    }
}
"<!doctype html><html lang='en'><meta charset='utf-8'><title>FOIA Choice presentation</title><body style='font-family:Segoe UI,sans-serif'><h1>FOIA Choice presentation</h1><p>26 shared Choices / 29 fields. Numeric values and semantic labels unchanged.</p><p>Plan hash: $hash</p><table cellpadding='8'><tr><th>Choice</th><th>Value</th><th>Display label</th><th>Pastel</th></tr>$($rows -join '')</table></body></html>" |
    Set-Content -LiteralPath (Join-Path $folder 'preview.html') -Encoding utf8
if ($PreviewOnly) {
    return [pscustomobject]@{ PlanHash = $hash; ChoiceCount = $contracts.Count; OptionCount = @($contracts.options).Count; PreviewPath = Join-Path $folder 'preview.html'; MutationCount = 0 }
}
if ($ApprovedPlanHash -cne $hash) { throw "Approve the exact preview hash '$hash' before Apply." }

$invoke = {
    param([string]$Method, [string]$Path, $Body = $null)
    Invoke-WizardDataverseRequest -Method $Method -Path $Path -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body $Body -RequestInvoker $RequestInvoker
}
$solutions = @((& $invoke Get "solutions?`$select=solutionid,ismanaged&`$filter=uniquename eq '$SolutionUniqueName'").value)
if ($solutions.Count -ne 1 -or $solutions[0].ismanaged) { throw 'A unique unmanaged target solution is required.' }
$solutionId = ([guid]$solutions[0].solutionid).ToString()
$original = [Collections.Generic.List[object]]::new()
$choiceIds = @{}
foreach ($choice in $contracts) {
    $metadata = & $invoke Get "GlobalOptionSetDefinitions(Name='$($choice.name)')/Microsoft.Dynamics.CRM.OptionSetMetadata"
    if ($metadata.Name -cne $choice.name -or $metadata.IsGlobal -ne $true -or
        $metadata.OptionSetType -ne 'Picklist' -or $metadata.IsManaged -ne $false) {
        throw "Choice '$($choice.name)' is not the exact unmanaged global Picklist."
    }
    $id = ([guid]$metadata.MetadataId).ToString()
    $choiceIds[$choice.name] = $id
    $members = @((& $invoke Get "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $solutionId and objectid eq $id and componenttype eq 9").value)
    if ($members.Count -ne 1) { throw "Choice '$($choice.name)' lacks unique target-solution membership." }
    if (@($metadata.Options).Count -ne $choice.options.Count) { throw "Choice '$($choice.name)' option count drifted." }
    foreach ($expected in $choice.options) {
        $actual = @($metadata.Options | Where-Object Value -eq $expected.value)
        if ($actual.Count -ne 1) { throw "Choice '$($choice.name)' option '$($expected.value)' is missing or duplicated." }
        $labels = @($actual[0].Label.LocalizedLabels | Where-Object LanguageCode -eq 1033)
        if ($labels.Count -ne 1 -or $labels[0].Label -cnotin @($expected.semanticLabel, $expected.label)) {
            throw "Choice '$($choice.name)' option '$($expected.value)' label drifted."
        }
        $managed = $actual[0].PSObject.Properties['IsManaged']
        if ($null -ne $managed -and $managed.Value) { throw "Choice '$($choice.name)' contains a managed option." }
    }
    $original.Add($metadata)
}
foreach ($binding in $payload.Bindings) {
    $column = & $invoke Get "EntityDefinitions(LogicalName='$($binding.TableLogicalName)')/Attributes(LogicalName='$($binding.ColumnLogicalName)')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName,AttributeType&`$expand=GlobalOptionSet"
    if ($column.LogicalName -cne $binding.ColumnLogicalName -or $column.AttributeType -ne 'Picklist' -or
        $column.GlobalOptionSet.Name -cne $binding.GlobalChoiceName -or
        "$($column.GlobalOptionSet.MetadataId)" -ne $choiceIds[$binding.GlobalChoiceName]) {
        throw "Binding '$($binding.TableLogicalName).$($binding.ColumnLogicalName)' drifted."
    }
}
$backupPath = Join-Path $folder "original-$hash.json"
if (-not (Test-Path -LiteralPath $backupPath)) {
    [ordered]@{ planHash = $hash; plan = $plan; capturedAtUtc = [DateTime]::UtcNow.ToString('o'); choices = $original.ToArray() } |
        ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $backupPath -Encoding utf8
}
$changed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$updates = 0
foreach ($choice in $contracts) {
    $metadata = @($original | Where-Object Name -eq $choice.name)[0]
    foreach ($expected in $choice.options) {
        $actual = @($metadata.Options | Where-Object Value -eq $expected.value)[0]
        $label = @($actual.Label.LocalizedLabels | Where-Object LanguageCode -eq 1033)[0].Label
        if ($label -ceq $expected.label -and $actual.Color -ieq $expected.color) { continue }
        & $invoke Post 'UpdateOptionValue' ([ordered]@{
            OptionSetName = $choice.name; Value = $expected.value; Color = $expected.color
            Label = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(
                @{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; LanguageCode = 1033; Label = $expected.label }
            ) }
            MergeLabels = $true; ParentValues = @(); SolutionUniqueName = $SolutionUniqueName
        }) | Out-Null
        [void]$changed.Add($choice.name)
        $updates++
    }
}
if ($changed.Count -gt 0) {
    $nodes = @($changed | Sort-Object | ForEach-Object { '<optionset>' + [Security.SecurityElement]::Escape($_) + '</optionset>' }) -join ''
    & $invoke Post 'PublishXml' @{ ParameterXml = "<importexportxml><optionsets>$nodes</optionsets></importexportxml>" } | Out-Null
}
foreach ($expectedChoice in $payload.GlobalChoices) {
    $verified = $false
    for ($attempt = 1; $attempt -le 5 -and -not $verified; $attempt++) {
        $metadata = & $invoke Get "GlobalOptionSetDefinitions(Name='$($expectedChoice.Name)')/Microsoft.Dynamics.CRM.OptionSetMetadata"
        if ("$($metadata.MetadataId)" -ne $choiceIds[$expectedChoice.Name]) { throw 'Choice metadata identity changed unexpectedly.' }
        $options = @($metadata.Options | ForEach-Object {
            $labels = @($_.Label.LocalizedLabels | Where-Object LanguageCode -eq 1033)
            if ($labels.Count -ne 1) { throw 'Readback requires a unique English label.' }
            [pscustomobject]@{ Value = $_.Value; Label = $labels[0].Label; Color = $_.Color }
        })
        $verified = $options.Count -eq @($expectedChoice.Options).Count
        foreach ($expected in $expectedChoice.Options) {
            $actual = @($options | Where-Object Value -eq $expected.Value)
            if ($actual.Count -ne 1 -or $actual[0].Label -cne (Get-WizardChoiceDisplayLabel $expected) -or
                $actual[0].Color -ine (Get-WizardChoiceColor $expected)) { $verified = $false }
        }
        if (-not $verified -and $attempt -lt 5) { Start-Sleep -Seconds ([Math]::Pow(2, $attempt - 1)) }
    }
    Assert-WizardChoiceOptions -Choice $expectedChoice -Options $options
}
$result = [pscustomobject]@{
    scenarioSlug = $ScenarioSlug; solutionUniqueName = $SolutionUniqueName; environmentUrl = $EnvironmentUrl.TrimEnd('/')
    planHash = $hash; verifiedAtUtc = [DateTime]::UtcNow.ToString('o'); choiceCount = $contracts.Count
    optionCount = @($contracts.options).Count; changedOptionCount = $updates; publishedChoices = @($changed | Sort-Object)
    backupPath = $backupPath; exactReadback = $true
}
$receiptName = 'run-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffffffZ') + '.json'
$result | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $folder $receiptName) -Encoding utf8
if ($updates -gt 0 -and -not (Test-Path -LiteralPath (Join-Path $folder 'apply.json'))) {
    $result | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $folder 'apply.json') -Encoding utf8
}
$result | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $folder 'verification.json') -Encoding utf8
return $result
