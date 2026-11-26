<#
COMPONENT: Accepted outcome coverage | VERSION: 1.0
ARCHITECTURE: Scenario documentary links and proportional functional criteria.
SECURITY: Local validation only; confirmation is not native approval or authority.
#>
Set-StrictMode -Version Latest

function Get-WizardDocumentaryOperations {
    param([string]$Excerpt)
    $verbs = @{
        create = 'creat(?:e|es|ed|ing)'; update = 'updat(?:e|es|ed|ing)'
        assign = 'assign(?:s|ed|ing)?'; inspect = 'inspect(?:s|ed|ing)?'
        resolve = 'resolv(?:e|es|ed|ing)'; delete = 'delet(?:e|es|ed|ing)'
        binding = 'bindings?'; chronology = 'chronology'; metrics = 'metrics?'
        cancellation = 'cancellations?'; concurrency = 'concurrency'
    }

    $verbPattern = '(?:' + ($verbs.Values -join '|') + ')'
    $affirmative = [regex]::Replace($Excerpt, "(?i)\b(?:do not|must not|cannot|never|without|no)\s+$verbPattern(?:\s*(?:,|/|or|and|nor|&)\s*$verbPattern)*", '')
    foreach ($operation in $verbs.Keys) {
        if ($operation -eq 'inspect' -and $Excerpt -match '(?i)\bread[- ]only\b') { continue }
        if ($affirmative -match "(?i)\b$($verbs[$operation])\b") { $operation }
    }
}

function Test-WizardExcerptInValue {
    param($Value, [string]$Excerpt)
    if ($Value -is [string]) { return $Value.Contains($Excerpt, [StringComparison]::Ordinal) }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($item in $Value.Values) { if (Test-WizardExcerptInValue $item $Excerpt) { return $true } }
    } elseif ($Value -is [array]) {
        foreach ($item in $Value) { if (Test-WizardExcerptInValue $item $Excerpt) { return $true } }
    }
    return $false
}

function Test-WizardRequirementsCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ScenarioFolder,
        [string]$SchemaPath = (Join-Path $PSScriptRoot '..\..\..\schemas\requirements-coverage.schema.json'),
        [switch]$RequireCoverage
    )
    $path = Join-Path $ScenarioFolder 'requirements-coverage.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        foreach ($name in @('spec.md', 'plan.md', 'tasks.md')) {
            $document = Join-Path $ScenarioFolder $name
            if ((Test-Path -LiteralPath $document -PathType Leaf) -and
                (Get-Content -LiteralPath $document -Raw) -match '(?m)^## Accepted Outcome Coverage\s*$') {
                $RequireCoverage = $true
            }
        }
        if ($RequireCoverage) { throw 'Accepted outcomes require requirements-coverage.json; mapping-only completion is not functional delivery.' }
        return @{ status = 'legacy-not-applicable'; criterionIds = @(); checkFamilies = @(); nativeApproval = $false }
    }
    $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if (-not (Test-Json -Json $json -SchemaFile $SchemaPath -ErrorAction Stop)) { throw 'Invalid requirements coverage contract.' }
    $contract = $json | ConvertFrom-Json -AsHashtable
    if ((Split-Path $ScenarioFolder -Leaf) -cne $contract.scenarioSlug) { throw 'Coverage scenario identity mismatch.' }
    $sourcePath = Join-Path $ScenarioFolder $contract.provenance.sourcePath
    $source = Get-Item -LiteralPath $sourcePath -ErrorAction Stop
    if ($source.Attributes -band [IO.FileAttributes]::ReparsePoint -or
        (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $contract.provenance.sourceSha256) {
        throw 'Accepted outcome confirmation source drift.'
    }
    $sourceText = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
    $sourceValue = if ([IO.Path]::GetExtension($sourcePath) -eq '.json') { $sourceText | ConvertFrom-Json -AsHashtable } else { $sourceText }
    $texts = @{}
    foreach ($document in $contract.documents) {
        $documentPath = Join-Path $ScenarioFolder $document.path
        $item = Get-Item -LiteralPath $documentPath -ErrorAction Stop
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Coverage documents must not be links.' }
        if ((Get-FileHash -LiteralPath $documentPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $document.sha256) {
            throw "Coverage documentary drift: $($document.path). Reconcile only affected requirements."
        }
        if ($texts.ContainsKey($document.path)) { throw 'Duplicate coverage document.' }
        $texts[$document.path] = Get-Content -LiteralPath $documentPath -Raw -Encoding UTF8
    }
    foreach ($name in @('spec.md', 'plan.md', 'tasks.md')) {
        if (-not $texts.ContainsKey($name)) { throw "Missing coverage document: $name" }
    }
    $tasks = @{}
    $criteria = @{}
    $outcomes = @{}
    foreach ($pair in @(@($contract.tasks, $tasks), @($contract.criteria, $criteria), @($contract.outcomes, $outcomes))) {
        foreach ($entry in $pair[0]) {
            if ($pair[1].ContainsKey($entry.id)) { throw "Duplicate coverage identity: $($entry.id)" }
            $pair[1][$entry.id] = $entry
        }
    }
    $family = @{
        binding = 'binding'; read = 'crud'; create = 'crud'; update = 'crud'; delete = 'crud'
        assign = 'crud'; inspect = 'crud'; resolve = 'lifecycle'; lifecycle = 'lifecycle'
        chronology = 'chronology'; metrics = 'metrics'; cancellation = 'cancellation'; concurrency = 'concurrency'
    }
    foreach ($criterion in $contract.criteria) {
        foreach ($operation in $criterion.operations) {
            if ($family[$operation] -cne $criterion.checkFamily) { throw "Criterion family mismatch: $($criterion.id)/$operation" }
        }
        foreach ($taskId in $criterion.taskIds) {
            if (-not $tasks.ContainsKey($taskId) -or $tasks[$taskId].criterionIds -notcontains $criterion.id) {
                throw "Unlinked functional criterion: $($criterion.id)/$taskId"
            }
            foreach ($operation in $criterion.operations) {
                if ($tasks[$taskId].operations -notcontains $operation) { throw "Criterion operation absent from linked task: $taskId/$operation" }
            }
        }
    }
    foreach ($task in $contract.tasks) {
        if (-not $texts['tasks.md'].Contains($task.excerpt, [StringComparison]::Ordinal)) { throw "Implementation task excerpt missing: $($task.id)" }
    }
    foreach ($entry in @($contract.tasks) + @($contract.outcomes)) {
        if ($entry.ContainsKey('document') -and -not $texts[$entry.document].Contains($entry.excerpt, [StringComparison]::Ordinal)) {
            throw "Accepted outcome excerpt missing: $($entry.id)"
        }
        if ($entry.ContainsKey('document')) {
            if (-not (Test-WizardExcerptInValue $sourceValue $entry.excerpt)) { throw "Outcome excerpt absent from original confirmation: $($entry.id)" }
            foreach ($operation in @(Get-WizardDocumentaryOperations $entry.excerpt)) {
                if ($entry.operations -notcontains $operation) { throw "Documented accepted operation omitted from coverage: $($entry.id)/$operation" }
            }
        }
        foreach ($criterionId in $entry.criterionIds) {
            if (-not $criteria.ContainsKey($criterionId)) { throw "Missing functional criterion: $criterionId" }
            if (-not $entry.ContainsKey('taskIds') -and $criteria[$criterionId].taskIds -notcontains $entry.id) {
                throw "Task criterion is not bound back to its task: $($entry.id)/$criterionId"
            }
        }
        foreach ($operation in $entry.operations) {
            $matches = @($entry.criterionIds | Where-Object {
                $criteria[$_].operations -contains $operation -and $criteria[$_].checkFamily -ceq $family[$operation]
            })
            if ($matches.Count -eq 0) { throw "Uncovered accepted operation: $($entry.id)/$operation; read-only/mapping coverage cannot replace mutations." }
        }
        if ($entry.ContainsKey('taskIds')) {
            foreach ($taskId in $entry.taskIds) {
                if (-not $tasks.ContainsKey($taskId)) { throw "Missing implementation task: $taskId" }
            }
            foreach ($operation in $entry.operations) {
                if (@($entry.taskIds | Where-Object { $tasks[$_].operations -contains $operation }).Count -eq 0) {
                    throw "Accepted operation absent from implementation tasks: $($entry.id)/$operation"
                }
            }
            foreach ($criterionId in $entry.criterionIds) {
                if (@($criteria[$criterionId].taskIds | Where-Object { $entry.taskIds -contains $_ }).Count -eq 0) {
                    throw "Outcome criterion is not bound to its implementation task: $($entry.id)/$criterionId"
                }
            }
        }
    }
    foreach ($task in $contract.tasks) {
        if (@($contract.outcomes | Where-Object { $_.taskIds -contains $task.id }).Count -eq 0) { throw "Orphan implementation task: $($task.id)" }
    }
    foreach ($criterion in $contract.criteria) {
        if (@($contract.outcomes | Where-Object { $_.criterionIds -contains $criterion.id }).Count -eq 0) { throw "Orphan functional criterion: $($criterion.id)" }
    }
    return @{
        status = 'covered'; scenarioSlug = $contract.scenarioSlug
        coverageSha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        criterionIds = @($contract.criteria.id); checkFamilies = @($contract.criteria.checkFamily | Sort-Object -Unique)
        provenance = $contract.provenance; nativeApproval = $false; executionAuthorized = $false
    }
}

function Write-WizardRequirementsCoverage {
    param([Parameter(Mandatory)] [string]$InputPath, [Parameter(Mandatory)] [string]$ScenarioFolder)
    $contract = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    $contract.documents = @('spec.md', 'plan.md', 'tasks.md') | ForEach-Object {
        @{ path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $ScenarioFolder $_) -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $output = Join-Path $ScenarioFolder 'requirements-coverage.json'
    $previous = if (Test-Path -LiteralPath $output) { [IO.File]::ReadAllBytes($output) } else { $null }
    try {
        $contract | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $output -Encoding UTF8
        Test-WizardRequirementsCoverage -ScenarioFolder $ScenarioFolder -RequireCoverage
    } catch {
        if ($null -ne $previous) { [IO.File]::WriteAllBytes($output, $previous) } else { Remove-Item -LiteralPath $output -Force }
        throw
    }
}
