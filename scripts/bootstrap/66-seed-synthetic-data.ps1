<#
=============================================================================
COMPONENT:    Seed Synthetic Data
FILE:         scripts/bootstrap/66-seed-synthetic-data.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-31
ENVIRONMENT:  PowerShell 7 | Dataverse Web API
=============================================================================
#>
[CmdletBinding()]
param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL, [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [Parameter(Mandatory)] [string]$ScenarioSlug, [string]$PayloadsFolder = '',
    [switch]$PreviewOnly, [scriptblock]$RequestInvoker
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')

function Get-WizardDataPayload { param([string]$Folder) $files=@(Get-ChildItem -LiteralPath $Folder -Filter 'data-*.json' -File); if($files.Count -ne 1){throw "Expected exactly one data payload; found $($files.Count)."}; Get-Content $files[0].FullName -Raw -Encoding UTF8|ConvertFrom-Json }
function ConvertTo-WizardFilterLiteral { param($Value) if($Value -is [bool]){return $Value.ToString().ToLowerInvariant()}; if($Value -is [int] -or $Value -is [long] -or $Value -is [double]){return "$Value"}; return "'$(ConvertTo-WizardODataLiteral "$Value")'" }

function Invoke-WizardSyntheticDataStage {
    param([string]$RepoRoot,[string]$ScenarioSlug,[string]$PayloadsFolder,[string]$EnvironmentUrl,[string]$AccessToken,[string]$SolutionUniqueName,[switch]$PreviewOnly,[scriptblock]$RequestInvoker)
    $payload=Get-WizardDataPayload $PayloadsFolder
    $planned=@($payload.Tables|ForEach-Object{$table=$_; @($table.Records|ForEach-Object{[pscustomobject]@{table=$table.TableLogicalName;key=$_.Key;action='planned'}})})
    if($PreviewOnly){$items=$planned}else{
        foreach($required in @($EnvironmentUrl,$AccessToken,$SolutionUniqueName)){if([string]::IsNullOrWhiteSpace($required)){throw 'Synthetic-data apply requires explicit environment, token, and solution.'}}
        $invoke={param($method,$path,$body=$null) Invoke-WizardDataverseRequest -Method $method -Path $path -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -Body $body -RequestInvoker $RequestInvoker}
        $safeSolution=ConvertTo-WizardODataLiteral $SolutionUniqueName
        $solutions=@((&$invoke Get "solutions?`$select=solutionid&`$filter=uniquename eq '$safeSolution'").value); if($solutions.Count-ne 1){throw "Expected exactly one selected solution '$SolutionUniqueName'."}
        $items=[Collections.Generic.List[object]]::new(); $tableMetadata=@{}
        foreach($table in @($payload.Tables)){
            $metadata=&$invoke Get "EntityDefinitions(LogicalName='$($table.TableLogicalName)')?`$select=LogicalName,EntitySetName,PrimaryIdAttribute"
            if($null-eq $metadata-or [string]::IsNullOrWhiteSpace("$($metadata.EntitySetName)")){throw "Table '$($table.TableLogicalName)' is unavailable."}; $tableMetadata[$table.TableLogicalName]=$metadata
            foreach($record in @($table.Records)){
                $keyLiteral=ConvertTo-WizardFilterLiteral $record.Key; $safeTag=ConvertTo-WizardFilterLiteral $payload.SourceTag
                $matches=@((&$invoke Get "$($metadata.EntitySetName)?`$select=$($metadata.PrimaryIdAttribute),$($table.NaturalKey),$($payload.SourceTagField)&`$filter=$($table.NaturalKey) eq $keyLiteral").value)
                if($matches.Count-gt 1){throw "Duplicate natural key '$($record.Key)' in '$($table.TableLogicalName)'."}
                if($matches.Count-eq 1-and "$($matches[0].$($payload.SourceTagField))"-cne $payload.SourceTag){throw "Natural key '$($record.Key)' is not owned by scenario '$ScenarioSlug'."}
                $body=[ordered]@{}; foreach($property in $record.Values.PSObject.Properties){$body[$property.Name]=$property.Value}; $body[$table.NaturalKey]=$record.Key; $body[$payload.SourceTagField]=$payload.SourceTag
                $lookups = if ($record.PSObject.Properties.Name -contains 'Lookups') { @($record.Lookups) } else { @() }
                foreach($lookup in $lookups){
                    $targetMeta=if($tableMetadata.ContainsKey($lookup.TargetTable)){$tableMetadata[$lookup.TargetTable]}else{&$invoke Get "EntityDefinitions(LogicalName='$($lookup.TargetTable)')?`$select=LogicalName,EntitySetName,PrimaryIdAttribute"}
                    $targetLiteral=ConvertTo-WizardFilterLiteral $lookup.TargetValue
                    $targets=@((&$invoke Get "$($targetMeta.EntitySetName)?`$select=$($targetMeta.PrimaryIdAttribute),$($lookup.TargetKey),$($payload.SourceTagField)&`$filter=$($lookup.TargetKey) eq $targetLiteral and $($payload.SourceTagField) eq $safeTag").value)
                    if($targets.Count-ne 1){throw "Lookup target '$($lookup.TargetTable)/$($lookup.TargetValue)' must resolve exactly once; found $($targets.Count)."}
                    $body["$($lookup.Field)@odata.bind"]="/$($targetMeta.EntitySetName)($($targets[0].$($targetMeta.PrimaryIdAttribute)))"
                }
                if($matches.Count-eq 0){&$invoke Post $metadata.EntitySetName $body|Out-Null; $created=@((&$invoke Get "$($metadata.EntitySetName)?`$select=$($metadata.PrimaryIdAttribute),$($table.NaturalKey),$($payload.SourceTagField)&`$filter=$($table.NaturalKey) eq $keyLiteral and $($payload.SourceTagField) eq $safeTag").value); if($created.Count-ne 1){throw "Record '$($record.Key)' did not resolve exactly once after create."}; $id="$($created[0].$($metadata.PrimaryIdAttribute))"; $action='created'}else{$id="$($matches[0].$($metadata.PrimaryIdAttribute))"; &$invoke Patch "$($metadata.EntitySetName)($id)" $body|Out-Null; $action='updated'}
                if([string]::IsNullOrWhiteSpace($id)){throw "Record '$($record.Key)' has no stable ID."}; $items.Add([pscustomobject]@{table=$table.TableLogicalName;key=$record.Key;id=$id;action=$action})
            }
        }
        $items=@($items)
    }
    $evidencePath=Join-Path $RepoRoot ".wizard-metrics/artifacts/data/$ScenarioSlug.json"; New-Item -ItemType Directory -Path (Split-Path $evidencePath -Parent)-Force|Out-Null
    [ordered]@{scenarioSlug=$ScenarioSlug;preview=[bool]$PreviewOnly;sourceTag=$payload.SourceTag;records=@($items)}|ConvertTo-Json -Depth 10|Set-Content $evidencePath -Encoding UTF8
    return @($items)
}
if($env:WIZARD_DATA_SKIP_MAIN-ne'true'){if([string]::IsNullOrWhiteSpace($PayloadsFolder)){$PayloadsFolder=Join-Path $repoRoot "payloads/scenarios/$ScenarioSlug"}; Invoke-WizardSyntheticDataStage -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken -SolutionUniqueName $SolutionUniqueName -PreviewOnly:$PreviewOnly -RequestInvoker $RequestInvoker|Out-Null}