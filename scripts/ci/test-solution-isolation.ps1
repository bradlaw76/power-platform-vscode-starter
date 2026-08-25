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

Write-Host 'Solution isolation checks passed.' -ForegroundColor Green
