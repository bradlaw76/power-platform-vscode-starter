Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts/bootstrap/helpers/solution-isolation.ps1')

$payloadFolder = Join-Path $repoRoot 'payloads/scenarios/mixed'
$expectedTables = @(Get-PayloadEntityNames -Folder $payloadFolder)

foreach ($requiredName in @('incident', 'cct_agent')) {
    if ($expectedTables -notcontains $requiredName) {
        throw "Expected payload discovery to include table: $requiredName"
    }
}

$solutionId = '00000000-0000-0000-0000-00000000abcd'
$metadataToLogical = @{
    '11111111-1111-1111-1111-111111111111' = 'incident'
    '22222222-2222-2222-2222-222222222222' = 'cct_agent'
    '33333333-3333-3333-3333-333333333333' = 'contact'
}

function New-MockDvGet {
    param([switch]$IncludeForeign)

    $localSolutionId = $solutionId
    $localMetadataToLogical = $metadataToLogical
    $components = @(
        [pscustomobject]@{
            solutioncomponentid = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
            objectid = '11111111-1111-1111-1111-111111111111'
            _solutionid_value = $localSolutionId
            componenttype = 1
        },
        [pscustomobject]@{
            solutioncomponentid = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
            objectid = '22222222-2222-2222-2222-222222222222'
            _solutionid_value = $localSolutionId
            componenttype = 1
        }
    )

    if ($IncludeForeign) {
        $components += [pscustomobject]@{
            solutioncomponentid = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
            objectid = '33333333-3333-3333-3333-333333333333'
            _solutionid_value = $localSolutionId
            componenttype = 1
        }
    }

    return {
        param($Path)

        if ($Path -like 'solutioncomponents?*') {
            return @{ value = $components }
        }

        if ($Path -match '^EntityDefinitions\(([^)]+)\)\?') {
            $metadataId = $Matches[1].ToLowerInvariant()
            if ($localMetadataToLogical.ContainsKey($metadataId)) {
                return [pscustomobject]@{
                    LogicalName = $localMetadataToLogical[$metadataId]
                    MetadataId = $metadataId
                }
            }
        }

        throw "Unexpected GET path: $Path"
    }.GetNewClosure()
}

$cleanReport = Get-SolutionTableIsolationReport -InvokeGet (New-MockDvGet) -SolutionId $solutionId -ExpectedEntityNames $expectedTables
if ($cleanReport.ForeignTables.Count -ne 0) {
    throw 'Clean solution should not report foreign tables.'
}

$contaminatedReport = Get-SolutionTableIsolationReport -InvokeGet (New-MockDvGet -IncludeForeign) -SolutionId $solutionId -ExpectedEntityNames $expectedTables
if ($contaminatedReport.ForeignTables.Count -ne 1) {
    throw 'Contaminated solution should report exactly one foreign table.'
}

if ($contaminatedReport.ForeignTables[0].LogicalName -ne 'contact') {
    throw 'Expected contact to be detected as the foreign table.'
}

$postCalls = New-Object 'System.Collections.Generic.List[string]'
$mockPost = {
    param($Path, $Body)
    [void]$postCalls.Add("$Path|$Body")
}.GetNewClosure()

$dryRun = Invoke-SolutionTableCleanup -InvokePost $mockPost -ForeignTables $contaminatedReport.ForeignTables -SolutionUniqueName 'ContosoSolution'
if ($dryRun.Count -ne 1 -or $dryRun[0].Status -ne 'WouldRemove') {
    throw 'Dry run cleanup should mark the foreign table as WouldRemove.'
}

if ($postCalls.Count -ne 0) {
    throw 'Dry run cleanup must not call RemoveSolutionComponent.'
}

$apply = Invoke-SolutionTableCleanup -InvokePost $mockPost -ForeignTables $contaminatedReport.ForeignTables -SolutionUniqueName 'ContosoSolution' -Apply
if ($apply.Count -ne 1 -or $apply[0].Status -ne 'Removed') {
    throw 'Apply cleanup should remove the foreign table.'
}

if ($postCalls.Count -ne 1) {
    throw 'Apply cleanup should call RemoveSolutionComponent exactly once.'
}

if ($postCalls[0] -notmatch 'RemoveSolutionComponent') {
    throw 'Cleanup should target the RemoveSolutionComponent action.'
}

if ($postCalls[0] -notmatch 'cccccccc-cccc-cccc-cccc-cccccccccccc') {
    throw 'Cleanup should remove only the foreign solution component id.'
}

if ($postCalls[0] -notmatch 'ContosoSolution') {
    throw 'Cleanup request body should include the target solution unique name.'
}

$expectedByCategory = @{
    tables = @('cct_case')
    columns = @('cct_case.cct_priority')
    relationships = @('cct_case_contact')
    forms = @('cct_case|main')
    views = @('cct_case|active')
    'model-driven-apps' = @('cct_case_review')
    'sitemap-updates' = @('cct_case_review_sitemap')
    'web-resources' = @('cct_reports/build-progress.html')
    dashboards = @()
    charts = @()
    flows = @()
}
$currentInventory = @(
    [pscustomobject]@{ Category = 'table'; Name = 'cct_case'; ObjectId = 'table-id'; SolutionComponentId = 'sc-table'; ComponentType = 1; State = 'Added' },
    [pscustomobject]@{ Category = 'column'; Name = 'cct_case.cct_priority'; ObjectId = 'column-id'; SolutionComponentId = 'sc-column'; ComponentType = 2 },
    [pscustomobject]@{ Category = 'relationship'; Name = 'cct_case_contact'; ObjectId = 'relationship-id'; SolutionComponentId = 'sc-relationship'; ComponentType = 10 },
    [pscustomobject]@{ Category = 'form'; Name = 'cct_case|main'; ObjectId = 'form-id'; SolutionComponentId = 'sc-form'; ComponentType = 60 },
    [pscustomobject]@{ Category = 'view'; Name = 'cct_case|active'; ObjectId = 'view-id'; SolutionComponentId = 'sc-view'; ComponentType = 26 },
    [pscustomobject]@{ Category = 'appmodule'; Name = 'cct_case_review'; ObjectId = 'app-id'; SolutionComponentId = 'sc-app'; ComponentType = 80 },
    [pscustomobject]@{ Category = 'sitemap'; Name = 'cct_case_review_sitemap'; ObjectId = 'sitemap-id'; SolutionComponentId = 'sc-sitemap'; ComponentType = 62 },
    [pscustomobject]@{ Category = 'webresource'; Name = 'cct_reports/build-progress.html'; ObjectId = 'webresource-id'; SolutionComponentId = 'sc-webresource'; ComponentType = 61 }
)

$membership = New-SolutionMembershipReport -ExpectedByCategory $expectedByCategory -CurrentInventory $currentInventory -Strict
if (-not $membership.ExportAllowed) {
    throw 'Complete strict inventory should allow export.'
}
$membershipRerun = New-SolutionMembershipReport -ExpectedByCategory $expectedByCategory -CurrentInventory $currentInventory -Strict
$firstStableResult = @($membership.Items | Sort-Object Category, Name | Select-Object Category, Name, ObjectId, SolutionComponentId, ComponentType, State, Required) | ConvertTo-Json -Depth 5 -Compress
$secondStableResult = @($membershipRerun.Items | Sort-Object Category, Name | Select-Object Category, Name, ObjectId, SolutionComponentId, ComponentType, State, Required) | ConvertTo-Json -Depth 5 -Compress
if ($firstStableResult -ne $secondStableResult -or $membership.ExportAllowed -ne $membershipRerun.ExportAllowed) {
    throw 'Repeated inventory collection should preserve identities, states, and export-gate verdict without duplicates.'
}
if ($membership.Categories.Count -ne 11) {
    throw 'Membership report should always include all mandatory and optional categories.'
}
$addedTable = @($membership.Items | Where-Object { $_.Category -eq 'tables' -and $_.Name -eq 'cct_case' })
if ($addedTable.Count -ne 1 -or $addedTable[0].State -ne 'Added' -or $addedTable[0].ObjectId -ne 'table-id' -or $addedTable[0].SolutionComponentId -ne 'sc-table') {
    throw 'Membership report should preserve Added state and Dataverse object/component IDs.'
}

$missingInventory = @($currentInventory | Where-Object Name -ne 'cct_case_review_sitemap')
$blockedMissing = New-SolutionMembershipReport -ExpectedByCategory $expectedByCategory -CurrentInventory $missingInventory
if ($blockedMissing.ExportAllowed -or @($blockedMissing.BlockingItems | Where-Object State -eq 'Missing').Count -ne 1) {
    throw 'Missing mandatory inventory must block export even outside strict isolation mode.'
}

$withUnauthorized = @($currentInventory) + [pscustomobject]@{ Category = 'chart'; Name = 'foreign_chart'; ObjectId = 'chart-id'; SolutionComponentId = 'sc-chart'; ComponentType = 59 }
$blockedUnauthorized = New-SolutionMembershipReport -ExpectedByCategory $expectedByCategory -CurrentInventory $withUnauthorized -Strict
if ($blockedUnauthorized.ExportAllowed -or @($blockedUnauthorized.BlockingItems | Where-Object State -eq 'Unauthorized').Count -ne 1) {
    throw 'Strict inventory must block export when unauthorized components remain.'
}

Write-Host 'Solution isolation checks passed.' -ForegroundColor Green
