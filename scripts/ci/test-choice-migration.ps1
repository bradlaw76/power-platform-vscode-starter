<#
=============================================================================
COMPONENT:    Choice Migration Offline Contract Tests
FILE:         scripts/ci/test-choice-migration.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-20
ENVIRONMENT:  PowerShell 7 | Credential-free injected transport only
NON-NEGOTIABLES: No network, live credentials, persisted row data or dependencies.
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'scripts/bootstrap/helpers/dataverse-runtime.ps1')
. (Join-Path $root 'scripts/bootstrap/helpers/choice-migration.ps1')
$folder = Join-Path $root 'payloads/scenarios/federal-foia-management'
$contract = Get-WizardChoiceContract $folder
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Throws([scriptblock]$Action, [string]$Pattern) {
    try { & $Action | Out-Null } catch { if ($_.Exception.Message -notmatch $Pattern) { throw }; return }
    throw "Expected failure: $Pattern"
}
function Get-Field([string]$Table, [string]$Source) { @($contract.Fields | Where-Object { $_.Table -eq $Table -and $_.Source -eq $Source })[0] }
Assert ($null -eq (ConvertTo-WizardChoiceValue (Get-Field foia_foiarequest foia_disposition) Open)) 'Open must mean null.'
Assert ((ConvertTo-WizardChoiceValue (Get-Field foia_reviewtask foia_disposition) 'Responsive') -eq 100000000) 'Review finding lost.'
Assert ((Get-Field foia_reviewtask foia_disposition).Choice -ne 'foia_disposition') 'Review findings conflated with request disposition.'
Assert ((ConvertTo-WizardChoiceValue (Get-Field contact foia_requesterclassification) Educational) -eq 100000001) 'Educational alias wrong.'
Assert ((ConvertTo-WizardChoiceValue (Get-Field foia_releasepackage foia_approvalstate) Assembling) -eq 100000007) 'Package Assembling value missing.'
Assert ((ConvertTo-WizardChoiceValue (Get-Field foia_releasepackage foia_approvalstate) Cancelled) -eq 100000008) 'Package Cancelled value missing.'
Assert-Throws { ConvertTo-WizardChoiceValue (Get-Field foia_foiarequest foia_disposition) Responsive } 'Unmapped'
Assert-Throws { ConvertTo-WizardChoiceValue (Get-Field foia_reviewtask foia_disposition) 'unrecognized private text' } 'Unmapped'
try { ConvertTo-WizardChoiceValue (Get-Field foia_reviewtask foia_disposition) 'unrecognized private text' | Out-Null } catch {
    Assert ($_.Exception.Message -notmatch 'unrecognized private text') 'Unmapped text leaked into diagnostics.'
}
Assert-Throws { Assert-WizardChoiceInteger '100000000' 4 } 'Invalid Choice'
Assert-Throws { Assert-WizardChoiceInteger 100000099 4 } 'Invalid Choice'
Assert-Throws { Assert-WizardChoiceInteger 100000000.0 4 } 'Invalid Choice'
Assert-Throws { Assert-WizardChoiceInteger $true 4 } 'Invalid Choice'

$calls = [Collections.Generic.List[object]]::new()
$mockGlobals = @{}
$mockAttributes = @{}
$mockMemberships = @{}
$rows = @{}
$badSourceType = $false
$badTargetType = $false
$unexpectedReadFailure = $false
$paginate = $false
$externalNext = $false
$loopNext = $false
$concurrencyFailure = $false
$patchState = @{ Count=0; FailAt=0 }
$invoker = {
    param($request)
    $path = ($request.Uri -split '/api/data/v9.2/')[1]
    $body = if ($request.Body) { $request.Body | ConvertFrom-Json -AsHashtable } else { $null }
    $calls.Add(@{ Method=$request.Method; Path=$path; Body=$body; Headers=$request.Headers })
    if ($path -like 'solutions?*') {
        return [pscustomobject]@{ value=@([pscustomobject]@{
            solutionid='11111111-1111-1111-1111-111111111111'; ismanaged=$false
            publisherid=[pscustomobject]@{ customizationprefix='foia' }
        }) }
    }
    if ($path -like 'solutioncomponents?*') {
        if ($path -match 'componenttype eq (2|9) and objectid eq ([a-f0-9-]+)') {
            $member = "$($Matches[1]):$($Matches[2])"
            return [pscustomobject]@{ value=$(if ($mockMemberships.ContainsKey($member)) { @([pscustomobject]@{objectid='member'}) } else { @() }) }
        }
        return [pscustomobject]@{ value=@([pscustomobject]@{objectid='member'}) }
    }
    if ($path -eq 'AddSolutionComponent') { $mockMemberships["$($body.ComponentType):$($body.ComponentId)"]=$true; return $null }
    if ($path -eq 'PublishXml') { return $null }
    if ($path -eq 'GlobalOptionSetDefinitions' -and $request.Method -eq 'Post') {
        $body.MetadataId = [guid]::NewGuid().ToString()
        $mockGlobals[$body.Name] = [pscustomobject]$body
        return $null
    }
    if ($path -match "^GlobalOptionSetDefinitions\(Name='([^']+)'\)$") {
        $name = $Matches[1]
        if ($mockGlobals.ContainsKey($name)) { return $mockGlobals[$name] }
        $errorObject = [Exception]::new($(if ($unexpectedReadFailure) { '403 simulated safe metadata error' } else { '404 missing metadata' }))
        $errorObject.Data['StatusCode'] = if ($unexpectedReadFailure) { 403 } else { 404 }
        throw $errorObject
    }
    if ($path -match "^EntityDefinitions\(LogicalName='([^']+)'\)/Attributes") {
        $table = $Matches[1]
        if ($request.Method -eq 'Post') {
            Assert ($body.ContainsKey('GlobalOptionSet@odata.bind') -and -not $body.ContainsKey('OptionSet')) 'Existing global Choice was not bound through its metadata navigation property.'
            $boundId = $body['GlobalOptionSet@odata.bind'] -replace '^/GlobalOptionSetDefinitions\(([^)]+)\)$','$1'
            $boundChoices = @($mockGlobals.Values | Where-Object MetadataId -eq $boundId)
            Assert ($boundChoices.Count -eq 1) 'Global Choice binding ID did not resolve.'
            $mockAttributes["$table.$($body.LogicalName)"] = [pscustomobject]@{
                AttributeType='Picklist'; OptionSet=$boundChoices[0]; MetadataId=[guid]::NewGuid().ToString()
            }
            return $null
        }
        if ($path -match "Attributes\(LogicalName='([^']+)'\)") {
            $name = $Matches[1]
            $field = @($contract.Fields | Where-Object { $_.Table -eq $table -and $_.Source -eq $name })
            if ($field.Count -eq 1) { return [pscustomobject]@{ AttributeType=$(if ($badSourceType) {'Integer'} else {'String'}) } }
            if ($mockAttributes.ContainsKey("$table.$name")) {
                if ($badTargetType) { return [pscustomobject]@{ AttributeType='String' } }
                return $mockAttributes["$table.$name"]
            }
            $errorObject = [Exception]::new('404 missing target')
            $errorObject.Data['StatusCode'] = 404
            throw $errorObject
        }
    }
    if ($path -match "^EntityDefinitions\(LogicalName='([^']+)'\)\?") {
        $table = $Matches[1]
        return [pscustomobject]@{
            MetadataId='22222222-2222-2222-2222-222222222222'
            LogicalName=$table; EntitySetName="${table}s"; PrimaryIdAttribute="${table}id"
            IsOptimisticConcurrencyEnabled=$true
        }
    }
    foreach ($table in $rows.Keys) {
        if ($request.Method -eq 'Get' -and $path -like "${table}s?*") {
            if ($externalNext) { return [pscustomobject]@{ value=@(); '@odata.nextLink'='https://untrusted.invalid/api/data/v9.2/rows' } }
            if ($loopNext) { return [pscustomobject]@{ value=@(); '@odata.nextLink'="https://offline.invalid/api/data/v9.2/${table}s?skiptoken=loop" } }
            if ($paginate -and $path -notlike '*skiptoken*') {
                return [pscustomobject]@{ value=@($rows[$table][0]); '@odata.nextLink'="https://offline.invalid/api/data/v9.2/${table}s?skiptoken=page2" }
            }
            return [pscustomobject]@{ value=$(if ($paginate) { @($rows[$table][1]) } else { @($rows[$table]) }) }
        }
        if ($request.Method -eq 'Patch' -and $path -like "${table}s(*)") {
            $patchState.Count++
            if ($patchState.FailAt -gt 0 -and $patchState.Count -eq $patchState.FailAt) { throw '412 simulated mid-run concurrency conflict' }
            if ($concurrencyFailure) { throw 'simulated 412' }
            Assert ($request.Headers['If-Match'] -eq 'W/"1"') 'Row concurrency missing.'
            foreach ($row in $rows[$table]) {
                if ($path -eq "${table}s($($row."${table}id"))") {
                    foreach ($key in $body.Keys) {
                        Assert ($key -in $contract.Fields.Target) 'Legacy write attempted.'
                        $row.$key = $body[$key]
                    }
                }
            }
            return $null
        }
    }
    if ($request.Method -eq 'Get' -and $path -like '*s?*') { return [pscustomobject]@{ value=@() } }
    throw "Unexpected offline request: $($request.Method) $path"
}
$migrationArgs = @{
    PayloadsFolder=$folder; ScenarioSlug='federal-foia-management'; SolutionUniqueName='FederalFOIAManagement'
    EnvironmentUrl='https://offline.invalid'; AccessToken='offline-placeholder'; RequestInvoker=$invoker; AcknowledgeWriteFreeze=$true
}
$preview = Invoke-WizardChoiceMigration @migrationArgs
Assert ($preview.Columns -eq $contract.Fields.Count) 'Incomplete metadata preview.'
Assert (@($calls | Where-Object Method -ne Get).Count -eq 0) 'Preview mutated metadata.'
$unexpectedReadFailure = $true
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs } 'metadata read failed'
$unexpectedReadFailure = $false
$calls.Clear()
Invoke-WizardChoiceMigration @migrationArgs -Apply | Out-Null
Assert ($mockGlobals.Count -eq $contract.Choices.Count -and $mockAttributes.Count -eq $contract.Fields.Count) 'Metadata creation incomplete.'
Assert (@($calls | Where-Object { $_.Path -eq 'AddSolutionComponent' -and $_.Body.ComponentType -eq 9 }).Count -eq $contract.Choices.Count) 'Global Choice sync missing.'
Assert (@($calls | Where-Object { $_.Path -eq 'PublishXml' -and $_.Body.ParameterXml -match '<optionsets>' }).Count -eq 1) 'Scoped publish missing.'
$calls.Clear()
Invoke-WizardChoiceMigration @migrationArgs -Apply | Out-Null
Assert (@($calls | Where-Object { $_.Method -eq 'Post' -and $_.Path -notin @('AddSolutionComponent','PublishXml') }).Count -eq 0) 'Metadata rerun recreated components.'
$badSourceType = $true
$calls.Clear()
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Apply } 'Legacy source type conflict'
Assert (@($calls | Where-Object Method -ne Get).Count -eq 0) 'Conflict wrote metadata.'
$badSourceType = $false
$badTargetType = $true
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Apply } 'Target Choice type conflict'
$badTargetType = $false
$original = $mockGlobals['foia_disposition'].Options[0].Value
$mockGlobals['foia_disposition'].Options[0].Value = 999
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Apply } 'numeric options conflict'
$mockGlobals['foia_disposition'].Options[0].Value = $original
$label = $mockGlobals['foia_disposition'].Options[0].Label.LocalizedLabels[0].Label
$mockGlobals['foia_disposition'].Options[0].Label.LocalizedLabels[0].Label = 'Conflicting label'
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Apply } 'label conflict'
$mockGlobals['foia_disposition'].Options[0].Label.LocalizedLabels[0].Label = $label
$originalBinding = $mockAttributes['foia_reviewtask.foia_dispositionchoice'].OptionSet
$mockAttributes['foia_reviewtask.foia_dispositionchoice'].OptionSet = $mockGlobals['foia_disposition']
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Apply } 'binding conflict'
$mockAttributes['foia_reviewtask.foia_dispositionchoice'].OptionSet = $originalBinding

function New-RequestRow([string]$Value, [string]$Id) {
    $row = @{ foia_foiarequestid=$Id; '@odata.etag'='W/"1"'; foia_syntheticsourcetag='federal-foia-synthetic-v1' }
    foreach ($field in @($contract.Fields | Where-Object Table -eq foia_foiarequest)) { $row[$field.Source]=$null; $row[$field.Target]=$null }
    $row.foia_disposition = $Value
    return [pscustomobject]$row
}
$rows.foia_foiarequest = @(
    (New-RequestRow 'Full Grant' '33333333-3333-3333-3333-333333333333'),
    (New-RequestRow 'unknown-private' '44444444-4444-4444-4444-444444444444')
)
$calls.Clear()
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -Apply -ApproveBackfill } 'Unmapped'
Assert (@($calls | Where-Object Method -ne Get).Count -eq 0) 'Bad late row allowed an early write.'
$rows.foia_foiarequest[1].foia_disposition = 'Partial Grant'
$rows.foia_foiarequest[1].foia_dispositionchoice = 100000000
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -Apply -ApproveBackfill } 'Conflicting target'
$rows.foia_foiarequest[1].foia_dispositionchoice = $null
$rows.foia_foiarequest[1].foia_syntheticsourcetag = 'another-scenario'
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -Apply -ApproveBackfill } 'outside approved scenario'
$rows.foia_foiarequest[1].foia_syntheticsourcetag = 'federal-foia-synthetic-v1'
$rows.foia_foiarequest[1].'@odata.etag' = '*'
$calls.Clear()
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -Apply -ApproveBackfill } 'concurrency token'
Assert (@($calls | Where-Object Method -ne Get).Count -eq 0) 'Missing late ETag allowed an early write.'
$rows.foia_foiarequest[1].'@odata.etag' = 'W/"1"'
$withoutFreeze = $migrationArgs.Clone()
$withoutFreeze.AcknowledgeWriteFreeze = $false
$calls.Clear()
Assert-Throws { Invoke-WizardChoiceMigration @withoutFreeze -Mode Backfill -Apply -ApproveBackfill } 'Write freeze acknowledgement'
Assert-Throws { Invoke-WizardChoiceMigration @withoutFreeze -Mode Validate } 'Write freeze acknowledgement'
Assert ($calls.Count -eq 0) 'Missing write-freeze acknowledgement performed transport calls.'
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -Apply } 'separate approval'
$paginate = $true
$calls.Clear()
$preview = Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -PageSize 1
Assert ($preview.Pending -eq 2 -and $preview.Rows -eq 2) 'Paged preview incorrect.'
Assert (@($calls | Where-Object Method -ne Get).Count -eq 0) 'Preview wrote rows.'
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -MaxRows 1 -Apply -ApproveBackfill } 'row bound exceeded'
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Validate } 'cutover blocked'
$externalNext = $true
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill } 'Unsafe Choice continuation'
$externalNext = $false
$loopNext = $true
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill } 'continuation loop'
$loopNext = $false
$concurrencyFailure = $true
$calls.Clear()
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -Apply -ApproveBackfill } 'row update failed'
Assert (@($calls | Where-Object Method -eq Patch).Count -eq 1) 'Concurrency failure retried a PATCH.'
$concurrencyFailure = $false
$patchState.Count = 0
$patchState.FailAt = 2
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -Apply -ApproveBackfill } 'Earlier rows may be migrated'
Assert ($rows.foia_foiarequest[0].foia_dispositionchoice -eq 100000000 -and
    $null -eq $rows.foia_foiarequest[1].foia_dispositionchoice) 'Partial non-destructive backfill not preserved.'
Assert-Throws { Invoke-WizardChoiceMigration @migrationArgs -Mode Validate } 'cutover blocked'
$resume = Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill
Assert ($resume.Pending -eq 1) 'Preview did not identify only the remaining row.'
$patchState.FailAt = 0
$calls.Clear()
$result = Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -Apply -ApproveBackfill
Assert ($result.Updated -eq 1) 'Backfill did not resume only the remaining row.'
$rerun = Invoke-WizardChoiceMigration @migrationArgs -Mode Validate
Assert ($rerun.Pending -eq 0) 'Backfill not idempotent.'
$calls.Clear()
Assert-Throws { Assert-WizardChoiceCutover @migrationArgs -ChoiceMaxRows 1 } 'row bound exceeded'
Assert-WizardChoiceCutover @migrationArgs -ChoiceMaxRows 25000
Assert (@($calls | Where-Object { $_.Path -like 'foia_foiarequests?*' -and $_.Path.Contains('$top=25001') }).Count -gt 0) 'Cutover wrapper discarded an explicit bound above 10,000.'
$calls.Clear()
Assert-WizardChoiceCutover @migrationArgs
Assert (@($calls | Where-Object { $_.Path -like 'foia_foiarequests?*' -and $_.Path.Contains('$top=10001') }).Count -gt 0) 'Cutover default bound changed.'
Assert-Throws { Assert-WizardChoiceCutover @migrationArgs -ChoiceMaxRows 0 } 'ChoiceMaxRows'
Assert-Throws { Assert-WizardChoiceCutover @migrationArgs -ChoiceMaxRows 100001 } 'ChoiceMaxRows'
Assert (@($calls | Where-Object Method -eq Delete).Count -eq 0) 'Destructive request attempted.'
$history = @{ foia_clockeventid='66666666-6666-6666-6666-666666666666'; foia_syntheticsourcetag='federal-foia-synthetic-v1'; '@odata.etag'='W/"1"' }
foreach ($field in @($contract.Fields | Where-Object Table -eq foia_clockevent)) { $history[$field.Source]=$null; $history[$field.Target]=$null }
$history.foia_eventtype = 'Receipt'
$rows.foia_clockevent = @([pscustomobject]$history)
$auditHistory = @{ foia_auditeventid='77777777-7777-7777-7777-777777777777'; foia_syntheticsourcetag='historical'; '@odata.etag'='W/"1"' }
foreach ($field in @($contract.Fields | Where-Object Table -eq foia_auditevent)) { $auditHistory[$field.Source]='historical unmapped evidence'; $auditHistory[$field.Target]=$null }
$rows.foia_auditevent = @([pscustomobject]$auditHistory)
$paginate = $false
$calls.Clear()
$historyResult = Invoke-WizardChoiceMigration @migrationArgs -Mode Backfill -Apply -ApproveBackfill
Assert ($historyResult.Updated -eq 0 -and $historyResult.Pending -eq 0) 'Historical evidence entered automatic backfill.'
Assert (@($calls | Where-Object { $_.Path -like 'foia_clockevents*' -or $_.Path -like 'foia_auditevents*' }).Count -eq 0) 'Historical evidence rows were read or mutated by backfill.'
Assert ($null -eq $rows.foia_clockevent[0].foia_eventtypechoice -and $rows.foia_clockevent[0].foia_eventtype -eq 'Receipt') 'Legacy immutable evidence changed.'
Invoke-WizardChoiceMigration @migrationArgs -Mode Validate | Out-Null
Assert (@($calls | Where-Object { $_.Path -like 'foia_clockevents*' -or $_.Path -like 'foia_auditevents*' }).Count -eq 0) 'Cutover validation read immutable evidence rows.'

$seed = Get-Content (Join-Path $folder 'data-federal-foia-management.json') -Raw | ConvertFrom-Json
Assert-WizardChoiceSeedPayload $seed $folder
$requestSeed = @($seed.Tables | Where-Object TableLogicalName -eq foia_foiarequest)[0].Records[0].Values
$requestSeed.foia_dispositionchoice = '100000000'
Assert-Throws { Assert-WizardChoiceSeedPayload $seed $folder } 'Invalid Choice integer'
$requestSeed.foia_dispositionchoice = $null
$requestSeed | Add-Member -NotePropertyName foia_disposition -NotePropertyValue 'Open'
Assert-Throws { Assert-WizardChoiceSeedPayload $seed $folder } 'Legacy categorical seed'
$requestSeed.PSObject.Properties.Remove('foia_disposition')
foreach ($field in $contract.Fields) {
    $columns = Get-Content (Join-Path $folder "columns-$($field.Table).json") -Raw | ConvertFrom-Json
    $legacy = @($columns.Columns | Where-Object LogicalName -eq $field.Source)
    Assert ($legacy.Count -eq 1 -and $legacy[0].'@odata.type' -eq 'Microsoft.Dynamics.CRM.StringAttributeMetadata') 'Legacy column payload was converted.'
    Assert (@($columns.Columns | Where-Object LogicalName -eq $field.Target).Count -eq 0) 'Dedicated additive metadata must not be duplicated in legacy payloads.'
}
$views = Get-Content (Join-Path $folder 'views-federal-foia-management.json') -Raw | ConvertFrom-Json
foreach ($view in $views.Views) {
    $fields = @($contract.Fields | Where-Object Table -eq $view.TableLogicalName)
    if ($view.TableLogicalName -in @('foia_clockevent','foia_auditevent')) {
        foreach ($field in $fields) {
            Assert ($field.Source -in $view.Columns -and $field.Target -in $view.Columns) 'Immutable evidence view hid legacy values or future Choices.'
        }
    } else {
        foreach ($column in $view.Columns) { Assert ($column -notin @($fields | ForEach-Object Source)) 'View still exposes legacy categorical column.' }
    }
}
foreach ($processFile in Get-ChildItem $folder -Filter 'process-*.json') {
    $process = Get-Content $processFile.FullName -Raw | ConvertFrom-Json
    foreach ($stage in $process.StageDefinitions) {
        $fields = @($contract.Fields | Where-Object Table -eq $stage.EntityLogicalName)
        foreach ($column in $stage.RequiredFields) { Assert ($column -notin @($fields | ForEach-Object Source)) 'BPF still uses legacy categorical column.' }
    }
    $appealProcess = Get-Content (Join-Path $folder 'process-02-appeal.json') -Raw | ConvertFrom-Json
    $appealStages = @('Appeal Intake','Validation','Reconsideration and Legal Review','Appeal Decision','Response','Closure')
    $appealFields = @(
        'foia_appealnumber,foia_receiveddate,foia_challengeddetermination',
        'foia_duedate',
        'foia_challengeddetermination',
        'foia_decision,foia_outcomechoice',
        'foia_outcomechoice',
        'foia_outcomechoice,foia_closeddate'
    )
    Assert ($appealProcess.StageDefinitions.Count -eq 6) 'Appeal BPF must have six stages.'
    for ($i=0; $i -lt 6; $i++) {
        $stage = $appealProcess.StageDefinitions[$i]
        Assert ($stage.Order -eq $i+1 -and $stage.StageName -ceq $appealStages[$i]) 'Appeal BPF stage order/display name changed.'
        Assert (($stage.RequiredFields -join ',') -ceq $appealFields[$i]) 'Appeal BPF field mapping changed.'
        Assert ((ConvertTo-WizardChoiceValue (Get-Field foia_appeal foia_stage) $stage.StageName) -eq (100000000+$i)) 'Appeal display-stage alias does not match canonical lifecycle.'
    }
    Assert ($null -eq (ConvertTo-WizardChoiceValue (Get-Field foia_appeal foia_outcome) Open)) 'Open appeal must have no final outcome.'
    Assert-Throws { ConvertTo-WizardChoiceValue (Get-Field foia_appeal foia_outcome) 'Appeal Decision' } 'Unmapped'
}
$reports = Get-Content (Join-Path $folder 'reporting-federal-foia-management.json') -Raw | ConvertFrom-Json
foreach ($chart in $reports.Charts) {
    $fields = @($contract.Fields | Where-Object Table -eq $chart.TableLogicalName)
    if ($chart.TableLogicalName -eq 'foia_clockevent') {
        Assert ($chart.CategoryField -eq 'foia_eventtype') 'Historical clock chart must retain legacy evidence grouping.'
    } else {
        Assert ($chart.CategoryField -notin @($fields | ForEach-Object Source)) 'Chart category still uses legacy categorical column.'
    }
    if ($chart.PSObject.Properties.Name -contains 'Filters') {
        foreach ($filter in $chart.Filters) {
            if ($chart.TableLogicalName -ne 'foia_clockevent') {
                Assert ($filter.Field -notin @($fields | ForEach-Object Source)) 'Chart filter still uses legacy categorical column.'
            } else {
                Assert ($filter.Field -eq 'foia_eventtype' -and $filter.Operator -eq 'not-null') 'Historical chart includes blank future evidence.'
            }
            $field = @($fields | Where-Object Target -eq $filter.Field)
            if ($field.Count -eq 1 -and $filter.PSObject.Properties.Name -contains 'Value') {
                Assert-WizardChoiceInteger $filter.Value $contract.Choices[$field[0].Choice].Count
            }
        }
    }
}
$design = Get-Content (Join-Path $root 'specs/federal-foia-management/detailed-design.md') -Raw
$shared = ($design -split '### Shared Choices')[1] -split '## Business Process Stage'
$choiceName = ''
$stableDesignLines = [Collections.Generic.List[string]]::new()
foreach ($line in ($shared[0] -split "`n")) {
    if ($line -match '^\|\s*(?:`(?<name>foia_[a-z0-9_]+)`)?\s*\|\s*(?<value>100000\d+)\s*\|\s*(?<label>[^|]+)\|') {
        if ($Matches.ContainsKey('name')) { $choiceName = $Matches.name }
        $stableDesignLines.Add("$choiceName|$($Matches.value)|$($Matches.label.Trim())")
        Assert ($contract.Choices[$choiceName][([int]$Matches.value - 100000000)] -ceq $Matches.label.Trim()) 'Stable shared Choice value drift.'
    }
}
Assert ($stableDesignLines.Count -eq 78) 'Stable design regression did not inspect all 78 published options.'
# Freeze the pre-existing design independently so coordinated payload/design drift cannot pass.
$stableDesignHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($stableDesignLines -join "`n"))).ToLowerInvariant()
Assert ($stableDesignHash -ceq '0e20ae9b7ca64d14301747008ac9fc0393916fb2e3c656be15458a83a1abf784') 'Pre-existing stable Choice design values/labels changed; independent review required.'

$env:WIZARD_FORMS_VIEWS_SKIP_MAIN = 'true'
. (Join-Path $root 'scripts/bootstrap/60-build-forms-views.ps1')
Remove-Item Env:WIZARD_FORMS_VIEWS_SKIP_MAIN
$script:ChoiceContract = $contract
$script:ChoiceAttributeTypes['foia_dispositionchoice'] = 'Picklist'
$formFields = @(Get-PayloadFieldsForTable -Folder $folder -TableLogical foia_foiarequest -Prefix foia)
Assert ('foia_dispositionchoice' -in $formFields.LogicalName -and 'foia_disposition' -notin $formFields.LogicalName) 'Form payload did not substitute new Choice field.'
$desired = @([pscustomobject]@{ LogicalName='foia_dispositionchoice'; Label='Disposition' })
$oldXml = '<form><tabs><tab><columns><column><sections><section><rows><row><cell><control datafieldname="foia_disposition"/></cell></row></rows></section></sections></column></columns></tab></tabs></form>'
$merged = Merge-FieldsIntoFormXml -ExistingFormXml $oldXml -DesiredFields $desired -LegacyFields @('foia_disposition')
$xml = [xml]$merged.FormXml
Assert ($null -eq $xml.SelectSingleNode('//control[@datafieldname="foia_disposition"]')) 'Legacy control was not removed.'
Assert ($xml.SelectSingleNode('//control[@datafieldname="foia_dispositionchoice"]').classid -eq '{3EF39988-22BB-4F0B-BBBE-64B5A3748AEE}') 'Choice control is not a Picklist.'
$textCell = New-FieldCellNode -Document ([xml]'<form/>') -FieldLogicalName foia_trackingnumber -FieldLabel 'Tracking Number' -CellIndex 1
Assert ($textCell.SelectSingleNode('control').classid -eq '{4273EDBD-AC1D-40d3-9FB2-095C621B552D}') 'Non-Choice control behavior changed.'
$again = Merge-FieldsIntoFormXml -ExistingFormXml $merged.FormXml -DesiredFields $desired -LegacyFields @('foia_disposition')
Assert ($again.FormXml -ceq $merged.FormXml) 'Choice form cutover not idempotent.'
function Invoke-Dv {
    param($Method,$Path,$Body)
    $table = $Path -replace "^EntityDefinitions\(LogicalName='([^']+)'\).*",'$1'
    $attributes = @(foreach ($field in @($contract.Fields | Where-Object Table -eq $table)) {
        [pscustomobject]@{LogicalName=$field.Source; AttributeType='String'; DisplayName=(New-WizardChoiceLabel $field.Label)}
        [pscustomobject]@{LogicalName=$field.Target; AttributeType='Picklist'; DisplayName=(New-WizardChoiceLabel $field.Label)}
    })
    return [pscustomobject]@{value=$attributes}
}
foreach ($historyTable in @('foia_clockevent','foia_auditevent')) {
    $historyFields = @($contract.Fields | Where-Object Table -eq $historyTable)
    $historyPayloadFields = @(Get-PayloadFieldsForTable -Folder $folder -TableLogical $historyTable -Prefix foia)
    $historyAttributes = @(Get-TableAttributesMetadata -TableLogical $historyTable -Prefix foia)
    foreach ($field in $historyFields) {
        Assert ($field.Source -in $historyPayloadFields.LogicalName -and $field.Target -in $historyPayloadFields.LogicalName) 'Immutable form payload hid historical source or future Choice.'
        Assert (@($historyAttributes | Where-Object { $_.LogicalName -eq $field.Source -and $_.Label -like '*Legacy evidence*' }).Count -eq 1) 'Immutable metadata excluded or mislabeled legacy evidence.'
    }
    $historyDesired = @($historyAttributes | ForEach-Object { [pscustomobject]@{LogicalName=$_.LogicalName;Label=$_.Label} })
    $historyXml = "<form><tabs><tab><columns><column><sections><section><rows><row><cell><control datafieldname='$($historyFields[0].Source)' disabled='false'/></cell></row></rows></section></sections></column></columns></tab></tabs></form>"
    $historyMerge = Merge-FieldsIntoFormXml -ExistingFormXml $historyXml -DesiredFields $historyDesired -LegacyEvidenceFields @($historyFields.Source)
    $historyDocument = [xml]$historyMerge.FormXml
    foreach ($field in $historyFields) {
        $legacyControl = $historyDocument.SelectSingleNode("//control[@datafieldname='$($field.Source)']")
        Assert ($null -ne $legacyControl -and $legacyControl.GetAttribute('disabled') -eq 'true') 'Immutable evidence control is missing or editable.'
        Assert ($legacyControl.ParentNode.SelectSingleNode('labels/label').GetAttribute('description') -like '*Legacy evidence*') 'Immutable evidence control lacks clear legacy label.'
        Assert ($historyDocument.SelectSingleNode("//control[@datafieldname='$($field.Target)']").GetAttribute('classid') -eq '{3EF39988-22BB-4F0B-BBBE-64B5A3748AEE}') 'Future immutable Choice lacks Picklist control.'
    }
    $historyAgain = Merge-FieldsIntoFormXml -ExistingFormXml $historyMerge.FormXml -DesiredFields $historyDesired -LegacyEvidenceFields @($historyFields.Source)
    Assert ($historyAgain.FormXml -ceq $historyMerge.FormXml) 'Immutable read-only form exception is not idempotent.'
}
. (Join-Path $root 'scripts/bootstrap/helpers/bpf-validation.ps1')
$index = Get-PayloadEntityAndFieldIndex -PayloadFolder $folder -ArtifactText ''
Assert ($index.FieldsByEntity['foia_foiarequest'].Contains('foia_dispositionchoice')) 'BPF index cannot resolve additive Choice field.'
. (Join-Path $root 'scripts/bootstrap/helpers/wizard-hardening.ps1')
. (Join-Path $root 'scripts/bootstrap/helpers/solution-isolation.ps1')
$expected = New-WizardExpectedArtifacts -RepoRoot $root -ScenarioSlug federal-foia-management -PayloadsFolder $folder -PublisherPrefix foia
Assert ($expected.GlobalChoices.Count -eq $contract.Choices.Count) 'Global Choices absent from expected inventory.'
foreach ($field in $contract.Fields) { Assert ("$($field.Table).$($field.Target)" -in $expected.Columns) 'Additive Choice absent from expected columns.' }
$choiceInventory = @([pscustomobject]@{
    Kind='global-choice'; Category='global-choices'; Name='foia_intakechannel'
    ObjectId='55555555-5555-5555-5555-555555555555'; SolutionComponentId='choice-member'; ComponentType=9
})
$verdict = New-WizardContaminationVerdict -CurrentComponents $choiceInventory -ExpectedArtifacts $expected -PublisherPrefix foia
Assert ($verdict.Verdict -eq 'clean') 'Expected Choice falsely marked contaminated.'
$categoryMap = ConvertTo-SolutionExpectedCategoryMap $expected
Assert ($categoryMap['global-choices'].Count -eq $contract.Choices.Count) 'Membership category map lost Choices.'
$membership = New-SolutionMembershipReport -ExpectedByCategory @{'global-choices'=@('foia_intakechannel')} -CurrentInventory $choiceInventory -Strict
Assert ($membership.ExportAllowed) 'Expected global Choice blocks export.'
$missingChoice = New-SolutionMembershipReport -ExpectedByCategory @{'global-choices'=@('foia_intakechannel')} -CurrentInventory @() -Strict
Assert (-not $missingChoice.ExportAllowed) 'Missing global Choice allowed export.'
$extraChoice = New-SolutionMembershipReport -ExpectedByCategory @{'global-choices'=@()} -CurrentInventory $choiceInventory -Strict
Assert (-not $extraChoice.ExportAllowed) 'Unauthorized global Choice allowed export.'

$inventoryAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'scripts/bootstrap/50-add-to-solution.ps1'), [ref]$null, [ref]$null)
$inventoryFunction = $inventoryAst.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-SolutionComponentInventory' }, $true)
. ([scriptblock]::Create($inventoryFunction.Extent.Text))
function Get-SolutionComponentTypeMap { return @{} }
function Get-ComponentTypeValue { param($Map, $Labels, $Fallback) return $Fallback }
$inventoryGet = {
    param($path)
    if ($path -like 'solutioncomponents?*') {
        return [pscustomobject]@{value=@([pscustomobject]@{
            solutioncomponentid='choice-member'; objectid='55555555-5555-5555-5555-555555555555'
            _solutionid_value='11111111-1111-1111-1111-111111111111'; componenttype=9; rootcomponentbehavior=0
        })}
    }
    if ($path -like 'GlobalOptionSetDefinitions(*)*') {
        return [pscustomobject]@{Name='foia_intakechannel'; MetadataId='55555555-5555-5555-5555-555555555555'}
    }
    throw 'Unexpected inventory request.'
}
$discovered = @(Get-SolutionComponentInventory -InvokeGet $inventoryGet -SolutionId '11111111-1111-1111-1111-111111111111')
Assert ($discovered.Count -eq 1 -and $discovered[0].Category -eq 'global-choices' -and $discovered[0].Name -eq 'foia_intakechannel') 'Stage 50 lost component type 9.'
$boundStages = @('55-build-business-process-flows.ps1','60-build-forms-views.ps1','64-build-charts-dashboard.ps1','66-seed-synthetic-data.ps1','90-run-build.ps1')
foreach ($stageFile in $boundStages) {
    $stageAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root "scripts/bootstrap/$stageFile"), [ref]$null, [ref]$null)
    $boundParameter = @($stageAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'ChoiceMaxRows' })
    Assert ($boundParameter.Count -eq 1 -and $boundParameter[0].DefaultValue.Extent.Text -eq '10000') "$stageFile lacks the default Choice bound."
    $range = @($boundParameter[0].Attributes | Where-Object { $_.TypeName.Name -eq 'ValidateRange' })
    Assert ($range.Count -eq 1 -and ($range[0].PositionalArguments.Extent.Text -join ',') -eq '1,100000') "$stageFile lost Choice bound range validation."
    $gateCalls = @($stageAst.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Assert-WizardChoiceCutover' }, $true))
    Assert ($gateCalls.Count -eq 1) "$stageFile must freshly validate cutover."
    $elements = @($gateCalls[0].CommandElements)
    $boundIndex = -1
    for ($i=0; $i -lt $elements.Count; $i++) {
        if ($elements[$i] -is [Management.Automation.Language.CommandParameterAst] -and $elements[$i].ParameterName -eq 'ChoiceMaxRows') { $boundIndex=$i }
    }
    Assert ($boundIndex -ge 0 -and $elements[$boundIndex+1].Extent.Text -ceq '$ChoiceMaxRows') "$stageFile did not forward its explicit bound to the gate."
    if ($stageFile -eq '90-run-build.ps1') {
        $propagation = @($stageAst.FindAll({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq '$stage.Arguments.ChoiceMaxRows' }, $true))
        Assert ($propagation.Count -eq 1 -and $propagation[0].Right.Extent.Text -ceq '$ChoiceMaxRows') 'Orchestrator did not forward the bound to affected children/reruns.'
        $forwardLoop = $stageAst.Find({ param($node) $node -is [Management.Automation.Language.ForEachStatementAst] -and $node.Extent.Text.Contains('$stage.Arguments.ChoiceMaxRows') }, $true)
        foreach ($child in $boundStages[0..3]) { Assert ($forwardLoop.Extent.Text.Contains($child)) "Orchestrator does not propagate the bound to $child." }
    }
}
$env:WIZARD_REPORTING_SKIP_MAIN = 'true'
. (Join-Path $root 'scripts/bootstrap/64-build-charts-dashboard.ps1') -ScenarioSlug ignored
Remove-Item Env:WIZARD_REPORTING_SKIP_MAIN
function Get-WizardSinglePayload { param($Folder,$Pattern) return [pscustomobject]@{Enabled=$false} }
$calls.Clear()
Invoke-WizardReportingStage -RepoRoot $root -ScenarioSlug federal-foia-management -PayloadsFolder $folder `
    -EnvironmentUrl https://offline.invalid -AccessToken offline-placeholder -SolutionUniqueName FederalFOIAManagement `
    -PublisherPrefix foia -AcknowledgeWriteFreeze -ChoiceMaxRows 25000 -RequestInvoker $invoker | Out-Null
Assert (@($calls | Where-Object { $_.Path -like 'foia_foiarequests?*' -and $_.Path.Contains('$top=25001') }).Count -gt 0) 'Reporting stage lost the explicit Choice bound.'
$env:WIZARD_DATA_SKIP_MAIN = 'true'
. (Join-Path $root 'scripts/bootstrap/66-seed-synthetic-data.ps1') -ScenarioSlug ignored
Remove-Item Env:WIZARD_DATA_SKIP_MAIN
$immutableSeedFixture = [pscustomobject]@{
    Enabled=$true; SourceTag='federal-foia-synthetic-v1'; SourceTagField='foia_syntheticsourcetag'
    Tables=@([pscustomobject]@{
        TableLogicalName='foia_clockevent'; NaturalKey='foia_eventidentifier'
        Records=@([pscustomobject]@{Key='CI-HISTORICAL'; Values=[pscustomobject]@{foia_eventtypechoice=100000000}})
    })
}
function Get-WizardDataPayload { param($Folder) return $immutableSeedFixture }
$seedState = @{ Creates=0; FutureRow=$null }
$seedInvoker = {
    param($request)
    $path = ($request.Uri -split '/api/data/v9.2/')[1]
    if ($path -like 'foia_clockevents*') {
        if ($request.Method -eq 'Patch') { throw 'Attempted immutable evidence update.' }
        if ($request.Method -eq 'Post') {
            $body = $request.Body | ConvertFrom-Json
            Assert ($body.foia_eventtypechoice -is [int] -or $body.foia_eventtypechoice -is [long]) 'Future immutable Choice seed is not an integer.'
            Assert ($body.PSObject.Properties.Name -notcontains 'foia_eventtype') 'Future seed wrote legacy categorical text.'
            $seedState.Creates++
            $seedState.FutureRow = [pscustomobject]@{
                foia_clockeventid='88888888-8888-8888-8888-888888888888'
                foia_eventidentifier='CI-FUTURE'; foia_syntheticsourcetag='federal-foia-synthetic-v1'
            }
            return $null
        }
        if ($path -like '*CI-HISTORICAL*') {
            return [pscustomobject]@{value=@([pscustomobject]@{
                foia_clockeventid='66666666-6666-6666-6666-666666666666'
                foia_eventidentifier='CI-HISTORICAL'; foia_syntheticsourcetag='federal-foia-synthetic-v1'
            })}
        }
        return [pscustomobject]@{value=$(if ($null -eq $seedState.FutureRow) { @() } else { @($seedState.FutureRow) })}
    }
    return & $invoker $request
}
$seedWorkspace = Join-Path $root ".ci-choice-seed-$([guid]::NewGuid().ToString('N'))"
try {
    $seedArgs = @{
        RepoRoot=$seedWorkspace; ScenarioSlug='federal-foia-management'; PayloadsFolder=$folder
        EnvironmentUrl='https://offline.invalid'; AccessToken='offline-placeholder'; SolutionUniqueName='FederalFOIAManagement'
        RequestInvoker=$seedInvoker; AcknowledgeWriteFreeze=$true; ChoiceMaxRows=25000
    }
    $calls.Clear()
    $oldSeed = @(Invoke-WizardSyntheticDataStage @seedArgs)
    Assert (@($calls | Where-Object { $_.Path -like 'foia_foiarequests?*' -and $_.Path.Contains('$top=25001') }).Count -gt 0) 'Synthetic-data stage lost the explicit Choice bound.'
    Assert ($oldSeed.Count -eq 1 -and $oldSeed[0].action -eq 'skipped' -and $seedState.Creates -eq 0) 'Existing immutable seed was modified.'
    $immutableSeedFixture.Tables[0].Records[0].Key = 'CI-FUTURE'
    $futureSeed = @(Invoke-WizardSyntheticDataStage @seedArgs)
    Assert ($futureSeed[0].action -eq 'created' -and $seedState.Creates -eq 1) 'Future synthetic Choice row was not created exactly once.'
    $futureRerun = @(Invoke-WizardSyntheticDataStage @seedArgs)
    Assert ($futureRerun[0].action -eq 'skipped' -and $seedState.Creates -eq 1) 'Future immutable seed rerun was not a no-op.'
} finally {
    if (Test-Path -LiteralPath $seedWorkspace) { Remove-Item -LiteralPath $seedWorkspace -Recurse -Force }
}
Write-Host 'PASS: Choice mappings, metadata, paged backfill, preview safety, conflicts, concurrency, seed types, stable values, references, Picklist forms and reruns.'
