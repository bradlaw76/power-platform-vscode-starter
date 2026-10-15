<#
=============================================================================
COMPONENT:    Style Choice Options
FILE:         scripts/bootstrap/35-style-choice-options.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-01
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Applies approved pastel colors and optional inline icon prefixes to existing
options on wizard-owned unmanaged local Dataverse Choice columns.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            optional metadata presentation stage after column creation
- Inputs:          choice-presentations-*.json payloads
- Outputs:         updated option labels/colors, preview/report artifacts
- Dependencies:    Dataverse Web API, scenario identity, runtime helpers
- Side Effects:    Apply updates Choice option metadata and publishes tables

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Preview is credential-free and non-mutating.
✔ Apply requires the exact preview hash.
✔ Colors and inline label icons are read back and verified.
✔ Reruns issue no metadata update when the desired state already exists.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Version 1 updates existing options only; it never inserts or deletes values.
- Only unmanaged local Picklist columns with explicit ownership are eligible.
- Icons are redundant inline label prefixes, not separate metadata.
- Publish only tables changed by this stage.
=============================================================================
#>

[CmdletBinding()]
param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$PayloadsFolder = '',
    [string]$ScenarioSlug = '',
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
    [string]$ApprovedPlanHash = '',
    [switch]$PreviewOnly,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$hardeningHelper = Join-Path $PSScriptRoot 'helpers\wizard-hardening.ps1'
$runtimeHelper = Join-Path $PSScriptRoot 'helpers\dataverse-runtime.ps1'
$telemetryHelper = Join-Path $PSScriptRoot 'helpers\wizard-telemetry.ps1'
foreach ($helper in @($hardeningHelper, $runtimeHelper, $telemetryHelper)) {
    if (Test-Path -LiteralPath $helper -PathType Leaf) { . $helper }
}

$script:ChoicePalette = [ordered]@{
    'pastel-apricot'  = '#FFD1A3'
    'pastel-blue'     = '#B9DDF5'
    'pastel-gray'     = '#D9E1E8'
    'pastel-lavender' = '#D8C4F1'
    'pastel-mint'     = '#C8E6C9'
    'pastel-peach'    = '#FAD7A0'
    'pastel-rose'     = '#F5BEC8'
    'pastel-yellow'   = '#F7E7A9'
}
$script:ChoiceIcons = [ordered]@{
    'none'             = ''
    'circle-filled'    = '●'
    'diamond-filled'   = '◆'
    'diamond-outline'  = '◇'
    'info'             = 'ℹ'
    'square-filled'    = '■'
    'triangle-filled'  = '▲'
    'triangle-outline' = '△'
    'warning'          = '⚠'
}

function Get-ChoicePresentationProperty {
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-ChoicePresentationLabel {
    param($Label, [int]$LanguageCode)
    $localized = @(Get-ChoicePresentationProperty $Label 'LocalizedLabels' @())
    $match = @($localized | Where-Object { [int](Get-ChoicePresentationProperty $_ 'LanguageCode' 0) -eq $LanguageCode } | Select-Object -First 1)
    if ($match.Count -eq 1) { return "$(Get-ChoicePresentationProperty $match[0] 'Label' '')" }
    return "$(Get-ChoicePresentationProperty (Get-ChoicePresentationProperty $Label 'UserLocalizedLabel') 'Label' '')"
}

function New-ChoicePresentationLabel {
    param([string]$Text, [int]$LanguageCode)
    return [ordered]@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.Label'
        LocalizedLabels = @([ordered]@{
            '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'
            Label = $Text
            LanguageCode = $LanguageCode
        })
    }
}

function Get-ChoicePresentationHash {
    param($Plan)
    $json = $Plan | ConvertTo-Json -Depth 20 -Compress
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($json))).ToLowerInvariant()
}

function Get-ChoicePresentationContracts {
    param([string]$Folder, [string]$SchemaPath)
    $contracts = [Collections.Generic.List[object]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $Folder -Filter 'choice-presentations-*.json' -File | Sort-Object Name)) {
        $json = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        if (-not (Test-Json -Json $json -SchemaFile $SchemaPath -ErrorAction Stop)) {
            throw "Choice presentation payload failed schema validation: $($file.FullName)"
        }
        $payload = $json | ConvertFrom-Json
        $languageCode = [int](Get-ChoicePresentationProperty $payload 'LanguageCode' 1033)
        $seenValues = [Collections.Generic.HashSet[int]]::new()
        $options = [Collections.Generic.List[object]]::new()
        foreach ($option in @($payload.Options | Sort-Object Value)) {
            $value = [int]$option.Value
            if (-not $seenValues.Add($value)) {
                throw "Duplicate option value '$value' in '$($file.Name)'."
            }
            $icon = "$(Get-ChoicePresentationProperty $option 'Icon' 'none')"
            $label = "$($option.Label)".Trim()
            $displayLabel = if ($icon -eq 'none') { $label } else { "$($script:ChoiceIcons[$icon]) $label" }
            if ($displayLabel.Length -gt 100) {
                throw "Decorated option label for value '$value' exceeds 100 characters."
            }
            $options.Add([pscustomobject][ordered]@{
                value = $value
                semanticLabel = $label
                displayLabel = $displayLabel
                colorToken = "$($option.ColorToken)"
                color = $script:ChoicePalette["$($option.ColorToken)"]
                icon = $icon
            })
        }
        $contracts.Add([pscustomobject][ordered]@{
            sourceFile = $file.Name
            tableLogicalName = "$($payload.TableLogicalName)"
            columnLogicalName = "$($payload.ColumnLogicalName)"
            ownership = "$($payload.Ownership)"
            languageCode = $languageCode
            options = @($options.ToArray())
        })
    }
    return @($contracts.ToArray())
}

function Get-ChoicePresentationMetadataPath {
    param([string]$TableLogicalName, [string]$ColumnLogicalName)
    return "EntityDefinitions(LogicalName='$TableLogicalName')/Attributes(LogicalName='$ColumnLogicalName')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName,IsManaged&`$expand=OptionSet"
}

function Assert-ChoicePresentationMetadata {
    param($Contract, $Metadata)
    if ("$(Get-ChoicePresentationProperty $Metadata 'LogicalName')" -cne $Contract.columnLogicalName) {
        throw "Choice column '$($Contract.tableLogicalName).$($Contract.columnLogicalName)' was not resolved exactly."
    }
    if ([bool](Get-ChoicePresentationProperty $Metadata 'IsManaged' $false)) {
        throw "Choice column '$($Contract.tableLogicalName).$($Contract.columnLogicalName)' is managed and cannot be styled."
    }
    $optionSet = Get-ChoicePresentationProperty $Metadata 'OptionSet'
    if ($null -eq $optionSet) {
        throw "Column '$($Contract.tableLogicalName).$($Contract.columnLogicalName)' is not a local Picklist Choice."
    }
    if ([bool](Get-ChoicePresentationProperty $optionSet 'IsGlobal' $false)) {
        throw "Choice column '$($Contract.tableLogicalName).$($Contract.columnLogicalName)' uses a global Choice. Version 1 supports local Choices only."
    }
    if (-not [bool](Get-ChoicePresentationProperty $optionSet 'IsCustomOptionSet' $false)) {
        throw "Choice column '$($Contract.tableLogicalName).$($Contract.columnLogicalName)' does not use a custom local Choice."
    }
    return $optionSet
}

function Test-ChoicePresentationOption {
    param($Actual, $Expected, [int]$LanguageCode)
    if ($null -eq $Actual) { return $false }
    $actualLabel = Get-ChoicePresentationLabel (Get-ChoicePresentationProperty $Actual 'Label') $LanguageCode
    $actualColor = "$(Get-ChoicePresentationProperty $Actual 'Color' '')"
    return $actualLabel -ceq $Expected.displayLabel -and $actualColor -ieq $Expected.color
}

function Write-ChoicePresentationPreview {
    param([string]$ArtifactFolder, $Plan, [string]$PlanHash, [bool]$Applied)
    New-Item -ItemType Directory -Path $ArtifactFolder -Force | Out-Null
    [ordered]@{
        version = '1.0'
        scenarioSlug = $Plan.scenarioSlug
        applied = $Applied
        planHash = $PlanHash
        contracts = $Plan.contracts
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $ArtifactFolder 'choice-presentation-plan.json') -Encoding UTF8

    $rows = @($Plan.contracts | ForEach-Object {
        $contract = $_
        @($contract.options | ForEach-Object {
            "<tr><td><code>$([Net.WebUtility]::HtmlEncode($contract.tableLogicalName)).$([Net.WebUtility]::HtmlEncode($contract.columnLogicalName))</code></td><td>$($_.value)</td><td style=`"background:$($_.color);color:#172b4d`">$([Net.WebUtility]::HtmlEncode($_.displayLabel))</td><td><code>$($_.color)</code></td></tr>"
        })
    }) -join "`n"
    @"
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Choice presentation preview</title><style>body{font:1rem/1.5 system-ui;max-width:75rem;margin:auto;padding:2rem;color:#172b4d}table{border-collapse:collapse;width:100%}th,td{border:1px solid #777;padding:.65rem;text-align:left}.notice{border-left:.4rem solid #0067b8;padding:1rem;background:#eef6fc}</style></head>
<body><main><h1>Choice presentation preview</h1><p class="notice"><strong>Plan hash:</strong> <code>$PlanHash</code>. Icons are inline label prefixes and remain redundant with text.</p>
<table><caption>Pastel colors and inline labels</caption><thead><tr><th>Choice column</th><th>Value</th><th>Rendered label</th><th>Color</th></tr></thead><tbody>$rows</tbody></table></main></body></html>
"@ | Set-Content -LiteralPath (Join-Path $ArtifactFolder 'choice-presentation-preview.html') -Encoding UTF8
}

function Invoke-WizardChoicePresentation {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug,
        [string]$PayloadsFolder,
        [string]$EnvironmentUrl,
        [string]$AccessToken,
        [string]$SolutionUniqueName,
        [string]$PublisherPrefix,
        [string]$ApprovedPlanHash,
        [switch]$PreviewOnly,
        [scriptblock]$RequestInvoker
    )

    $schemaPath = Join-Path $RepoRoot 'schemas\payloads\choice-presentations.schema.json'
    $contracts = @(Get-ChoicePresentationContracts -Folder $PayloadsFolder -SchemaPath $schemaPath)
    if ($contracts.Count -eq 0) {
        return [pscustomobject]@{ Skipped = $true; ChangedCount = 0; PlanHash = ''; ArtifactFolder = '' }
    }
    $plan = [pscustomobject][ordered]@{
        version = '1.0'
        scenarioSlug = $ScenarioSlug
        contracts = $contracts
    }
    $planHash = Get-ChoicePresentationHash $plan
    $artifactFolder = Join-Path $RepoRoot ".wizard-metrics\artifacts\choice-presentations\$ScenarioSlug"
    Write-ChoicePresentationPreview -ArtifactFolder $artifactFolder -Plan $plan -PlanHash $planHash -Applied $false
    if ($PreviewOnly) {
        Write-Host "Choice presentation preview created: $artifactFolder" -ForegroundColor Green
        Write-Host "Approved plan hash: $planHash" -ForegroundColor Cyan
        return [pscustomobject]@{ Skipped = $false; ChangedCount = $contracts.Count; PlanHash = $planHash; ArtifactFolder = $artifactFolder }
    }

    if ($ApprovedPlanHash -cne $planHash) {
        throw "ApprovedPlanHash mismatch. Run Preview and approve exact hash '$planHash'."
    }
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
        throw 'Apply requires SolutionUniqueName.'
    }
    if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) {
        throw 'Apply requires PublisherPrefix.'
    }
    if ($null -eq $RequestInvoker -and ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken))) {
        throw 'Apply requires Dataverse credentials unless RequestInvoker is supplied.'
    }
    $invoke = {
        param([string]$Method, [string]$Path, $Body = $null)
        Invoke-WizardDataverseRequest -Method $Method -Path $Path -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body $Body -RequestInvoker $RequestInvoker
    }

    $changedTables = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $changedCount = 0
    foreach ($contract in $contracts) {
        if (-not $contract.columnLogicalName.StartsWith("$($PublisherPrefix.ToLowerInvariant())_", [StringComparison]::Ordinal)) {
            throw "Choice column '$($contract.columnLogicalName)' is outside publisher prefix '$PublisherPrefix' and is not wizard-owned."
        }
        $metadataPath = Get-ChoicePresentationMetadataPath $contract.tableLogicalName $contract.columnLogicalName
        $metadata = & $invoke Get $metadataPath
        $optionSet = Assert-ChoicePresentationMetadata -Contract $contract -Metadata $metadata
        $actualByValue = @{}
        foreach ($actual in @(Get-ChoicePresentationProperty $optionSet 'Options' @())) {
            $actualByValue[[int](Get-ChoicePresentationProperty $actual 'Value' -1)] = $actual
        }
        foreach ($expected in $contract.options) {
            if (-not $actualByValue.ContainsKey($expected.value)) {
                throw "Option value '$($expected.value)' does not exist on '$($contract.tableLogicalName).$($contract.columnLogicalName)'. Version 1 never inserts options."
            }
            if ([bool](Get-ChoicePresentationProperty $actualByValue[$expected.value] 'IsManaged' $false)) {
                throw "Option value '$($expected.value)' on '$($contract.tableLogicalName).$($contract.columnLogicalName)' is managed and cannot be styled."
            }
            if (Test-ChoicePresentationOption -Actual $actualByValue[$expected.value] -Expected $expected -LanguageCode $contract.languageCode) { continue }
            $body = [ordered]@{
                EntityLogicalName = $contract.tableLogicalName
                AttributeLogicalName = $contract.columnLogicalName
                Value = $expected.value
                Label = New-ChoicePresentationLabel -Text $expected.displayLabel -LanguageCode $contract.languageCode
                Color = $expected.color
                MergeLabels = $true
                ParentValues = @()
                SolutionUniqueName = $SolutionUniqueName
            }
            & $invoke Post 'UpdateOptionValue' $body | Out-Null
            $changedCount++
            [void]$changedTables.Add($contract.tableLogicalName)
        }
    }

    if ($changedTables.Count -gt 0) {
        $publishXml = New-WizardEntityPublishXml -EntityLogicalNames @($changedTables)
        & $invoke Post 'PublishXml' @{ ParameterXml = $publishXml } | Out-Null
    }

    foreach ($contract in $contracts) {
        $verified = $false
        for ($attempt = 1; $attempt -le 5 -and -not $verified; $attempt++) {
            $metadata = & $invoke Get (Get-ChoicePresentationMetadataPath $contract.tableLogicalName $contract.columnLogicalName)
            $optionSet = Assert-ChoicePresentationMetadata -Contract $contract -Metadata $metadata
            $actualByValue = @{}
            foreach ($actual in @(Get-ChoicePresentationProperty $optionSet 'Options' @())) {
                $actualByValue[[int](Get-ChoicePresentationProperty $actual 'Value' -1)] = $actual
            }
            $mismatches = @($contract.options | Where-Object {
                -not (Test-ChoicePresentationOption -Actual $actualByValue[$_.value] -Expected $_ -LanguageCode $contract.languageCode)
            })
            $verified = $mismatches.Count -eq 0
            if (-not $verified -and $attempt -lt 5) {
                Start-Sleep -Seconds ([Math]::Pow(2, $attempt - 1))
            }
        }
        if (-not $verified) {
            throw "Readback verification failed for '$($contract.tableLogicalName).$($contract.columnLogicalName)' after 5 attempts."
        }
    }

    Write-ChoicePresentationPreview -ArtifactFolder $artifactFolder -Plan $plan -PlanHash $planHash -Applied $true
    if (Get-Command Initialize-WizardArtifactManifest -ErrorAction SilentlyContinue) {
        Initialize-WizardArtifactManifest -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix | Out-Null
        foreach ($contract in $contracts) {
            Add-WizardArtifactManifestItem -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'choice-presentation' -Name "$($contract.tableLogicalName).$($contract.columnLogicalName)" -Status $(if ($changedTables.Contains($contract.tableLogicalName)) { 'updated' } else { 'unchanged' }) -Step '35-style-choice-options.ps1' -Details @{ planHash = $planHash; source = $contract.sourceFile } | Out-Null
        }
    }
    return [pscustomobject]@{ Skipped = $false; ChangedCount = $changedCount; PlanHash = $planHash; ArtifactFolder = $artifactFolder }
}

if ($env:WIZARD_CHOICE_PRESENTATION_SKIP_MAIN -ne 'true') {
    if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
        if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) { throw 'ScenarioSlug or PayloadsFolder is required.' }
        $PayloadsFolder = Join-Path $repoRoot "payloads\scenarios\$ScenarioSlug"
    }
    if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
        $ScenarioSlug = Split-Path $PayloadsFolder -Leaf
    }
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName '35-style-choice-options.ps1'
    $result = Invoke-WizardChoicePresentation -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -SolutionUniqueName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -ApprovedPlanHash $ApprovedPlanHash -PreviewOnly:$PreviewOnly -RequestInvoker $RequestInvoker
    Complete-WizardStepTelemetry -Message "Choice presentation stage completed; changed=$($result.ChangedCount)."
}
