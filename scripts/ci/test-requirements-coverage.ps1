<#
COMPONENT: Coverage and capability regressions | VERSION: 1.0
ARCHITECTURE: Generic scenario fixtures and real local validators.
SECURITY: Synthetic confirmation only; no credentials or native execution.
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'scripts\bootstrap\helpers\requirements-coverage.ps1')
$testRoot = Join-Path $root ".wizard-metrics\coverage-$([guid]::NewGuid().ToString('N'))"
$folder = Join-Path $testRoot 'generic-work'
$checks = 0
function Assert-Result($Condition, $Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Assert-Blocked([scriptblock]$Action, [string]$Pattern) {
    $message = ''
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-Result ($message -match $Pattern) "Expected $Pattern; received $message"
}
function Copy-Contract($Value) { $Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable }
function Write-Contract($Value) { $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $folder 'requirements-coverage.json') }
try {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $source = Join-Path $folder 'confirmed.json'
    '{"confirmed":true,"kind":"simulation","outcome":"Create and resolve a record, preserve bindings and chronology, calculate metrics, cancel safely and prevent concurrent overwrite."}' | Set-Content $source
    $excerpt = 'Create and resolve a record, preserve bindings and chronology, calculate metrics, cancel safely and prevent concurrent overwrite.'
    $taskExcerpt = '- [ ] T001 Implement accepted operations with persisted functional readback.'
    $excerpt | Set-Content (Join-Path $folder 'spec.md')
    'Implementation uses scoped mutation handlers and independent functional tests.' | Set-Content (Join-Path $folder 'plan.md')
    $taskExcerpt | Set-Content (Join-Path $folder 'tasks.md')
    $operations = @('create', 'update', 'assign', 'inspect', 'read', 'delete', 'binding', 'resolve', 'lifecycle', 'chronology', 'metrics', 'cancellation', 'concurrency')
    $families = @{
        crud = @('create', 'update', 'assign', 'inspect', 'read', 'delete'); binding = @('binding')
        lifecycle = @('resolve', 'lifecycle'); chronology = @('chronology'); metrics = @('metrics')
        cancellation = @('cancellation'); concurrency = @('concurrency')
    }
    $criteria = @($families.Keys | Sort-Object | ForEach-Object {
        @{ id = "criterion-$_"; operations = @($families[$_]); checkFamily = $_; taskIds = @('task-001')
           surface = 'Record editor and retained record readback'; assertion = "Independent $_ functional assertions against exact expected effects." }
    })
    $contract = @{
        schemaVersion = '1.0'; scenarioSlug = 'generic-work'
        provenance = @{ kind = 'simulation'; confirmed = $true; sourcePath = 'confirmed.json'; sourceSha256 = (Get-FileHash $source).Hash.ToLowerInvariant() }
        outcomes = @(@{ id = 'outcome-001'; document = 'spec.md'; excerpt = $excerpt; operations = $operations; taskIds = @('task-001'); criterionIds = @($criteria.id) })
        tasks = @(@{ id = 'task-001'; excerpt = $taskExcerpt; operations = $operations; criterionIds = @($criteria.id) })
        criteria = $criteria
    }
    $inputPath = Join-Path $testRoot 'input.json'
    $contract | ConvertTo-Json -Depth 30 | Set-Content $inputPath
    $result = Write-WizardRequirementsCoverage -InputPath $inputPath -ScenarioFolder $folder
    Assert-Result ($result.status -eq 'covered' -and $result.checkFamilies.Count -eq 7 -and -not $result.nativeApproval) 'Expected proportional generic operation coverage, not native acceptance.'
    $valid = Get-Content (Join-Path $folder 'requirements-coverage.json') -Raw | ConvertFrom-Json -AsHashtable
    $bad = Copy-Contract $valid
    $bad.tasks[0].operations = @('read')
    Write-Contract $bad
    Assert-Blocked { Test-WizardRequirementsCoverage $folder } 'absent from linked task'
    $bad = Copy-Contract $valid
    $bad.outcomes[0].criterionIds = @('criterion-binding')
    Write-Contract $bad
    Assert-Blocked { Test-WizardRequirementsCoverage $folder } 'Uncovered accepted operation'
    $bad = Copy-Contract $valid
    $bad.criteria[0].checkFamily = 'metrics'
    Write-Contract $bad
    Assert-Blocked { Test-WizardRequirementsCoverage $folder } 'family mismatch'
    $bad = Copy-Contract $valid
    $bad.tasks[0].excerpt = 'No real implementation task'
    Write-Contract $bad
    Assert-Blocked { Test-WizardRequirementsCoverage $folder } 'excerpt missing'
    Write-Contract $valid
    Add-Content (Join-Path $folder 'plan.md') 'changed'
    Assert-Blocked { Test-WizardRequirementsCoverage $folder } 'documentary drift'
    'Implementation uses scoped mutation handlers and independent functional tests.' | Set-Content (Join-Path $folder 'plan.md')
    Add-Content $source 'changed'
    Assert-Blocked { Test-WizardRequirementsCoverage $folder } 'confirmation source drift'
    '{"confirmed":true,"kind":"simulation","outcome":"Create and resolve a record, preserve bindings and chronology, calculate metrics, cancel safely and prevent concurrent overwrite."}' | Set-Content $source
    $quoted = Copy-Contract $valid
    $quotedExcerpt = 'Create the "Review" record and update its café description.'
    $quoted.outcomes[0].excerpt = $quotedExcerpt
    @{ outcome = $quotedExcerpt } | ConvertTo-Json | Set-Content $source
    $quotedExcerpt | Set-Content (Join-Path $folder 'spec.md')
    $quoted.provenance.sourceSha256 = (Get-FileHash $source).Hash.ToLowerInvariant()
    $quoted.documents = @('spec.md', 'plan.md', 'tasks.md') | ForEach-Object {
        @{ path = $_; sha256 = (Get-FileHash (Join-Path $folder $_)).Hash.ToLowerInvariant() }
    }
    Write-Contract $quoted
    Assert-Result ((Test-WizardRequirementsCoverage $folder).status -eq 'covered') 'JSON string encoding must preserve exact quoted/Unicode documentary meaning with original byte hashes.'
    '{"confirmed":true,"kind":"simulation","outcome":"Create and resolve a record, preserve bindings and chronology, calculate metrics, cancel safely and prevent concurrent overwrite."}' | Set-Content $source
    $excerpt | Set-Content (Join-Path $folder 'spec.md')
    $readonly = Copy-Contract $valid
    $readonly.outcomes[0].operations = @('read')
    $readonly.outcomes[0].criterionIds = @('criterion-crud')
    $readonly.tasks[0].operations = @('read')
    $readonly.tasks[0].criterionIds = @('criterion-crud')
    $readonly.criteria = @($readonly.criteria | Where-Object checkFamily -eq 'crud')
    $readonly.criteria[0].operations = @('read')
    Write-Contract $readonly
    Assert-Blocked { Test-WizardRequirementsCoverage $folder } 'Documented accepted operation omitted'
    $readExcerpt = 'Read existing records; do not create, update, assign, inspect, resolve or delete. No reporting.'
    @{ outcome = $readExcerpt } | ConvertTo-Json | Set-Content $source
    $readExcerpt | Set-Content (Join-Path $folder 'spec.md')
    $readonly.provenance.sourceSha256 = (Get-FileHash $source).Hash.ToLowerInvariant()
    $readonly.outcomes[0].excerpt = $readExcerpt
    $readonly.documents = @('spec.md', 'plan.md', 'tasks.md') | ForEach-Object {
        @{ path = $_; sha256 = (Get-FileHash (Join-Path $folder $_)).Hash.ToLowerInvariant() }
    }
    Write-Contract $readonly
    Assert-Result ((Test-WizardRequirementsCoverage $folder).checkFamilies.Count -eq 1) 'Explicit read-only/no-report operation selection must remain supported.'
    Remove-Item (Join-Path $folder 'requirements-coverage.json')
    Assert-Result ((Test-WizardRequirementsCoverage $folder).status -eq 'legacy-not-applicable') 'Legacy without applicable outcomes must remain supported.'
    Assert-Blocked { Test-WizardRequirementsCoverage $folder -RequireCoverage } 'require requirements-coverage'
    Add-Content (Join-Path $folder 'spec.md') "`n## Accepted Outcome Coverage`n"
    Assert-Blocked { Test-WizardRequirementsCoverage $folder } 'require requirements-coverage'
    $output = & (Join-Path $root 'scripts\bootstrap\12-check-wizard-capabilities.ps1') -RepoRoot $root
    $preflight = $output | ConvertFrom-Json
    Assert-Result ($preflight.status -eq 'SOURCE READY' -and -not $preflight.nativeApproval) 'Consolidated source capability preflight must execute safely.'
    $partial = Join-Path $testRoot 'partial'
    New-Item -ItemType Directory -Path $partial | Out-Null
    Copy-Item (Join-Path $root 'wizard.profile.json') $partial
    $output = & pwsh -NoProfile -File (Join-Path $root 'scripts\bootstrap\12-check-wizard-capabilities.ps1') -RepoRoot $partial
    $preflight = $output | ConvertFrom-Json
    Assert-Result ($LASTEXITCODE -eq 1 -and $preflight.status -eq 'BLOCKED') 'Instruction-only incomplete source must block capability preflight.'
    $fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures\requirements-coverage.fixture.json') -Raw | ConvertFrom-Json -AsHashtable
    $fixtureFolder = Join-Path $testRoot $fixture.scenarioSlug
    New-Item -ItemType Directory -Path $fixtureFolder | Out-Null
    Copy-Item (Join-Path $PSScriptRoot 'fixtures\requirements-confirmation.fixture.json') (Join-Path $fixtureFolder 'confirmed.json')
    $fixture.provenance.sourceSha256 = (Get-FileHash (Join-Path $fixtureFolder 'confirmed.json')).Hash.ToLowerInvariant()
    $fixture.outcomes[0].excerpt | Set-Content (Join-Path $fixtureFolder 'spec.md')
    'Generic scoped operations and independent functional verification.' | Set-Content (Join-Path $fixtureFolder 'plan.md')
    $fixture.tasks[0].excerpt | Set-Content (Join-Path $fixtureFolder 'tasks.md')
    $fixtureInput = Join-Path $testRoot 'fixture-input.json'
    $fixture | ConvertTo-Json -Depth 30 | Set-Content $fixtureInput
    $output = & (Join-Path $root 'scripts\bootstrap\13-validate-requirements-coverage.ps1') -ScenarioFolder $fixtureFolder -CoverageInputPath $fixtureInput
    Assert-Result (($output | ConvertFrom-Json).status -eq 'covered') 'Public generator CLI must bind and validate the reusable fixture.'
    $output = & pwsh -NoProfile -File (Join-Path $root 'scripts\bootstrap\12-check-wizard-capabilities.ps1') -RepoRoot $root -RequireNativeBuild
    Assert-Result ($LASTEXITCODE -eq 1 -and ($output | ConvertFrom-Json).native.status -eq 'validator-source-only') 'Native integration must remain explicitly unverified, never source approval.'
    Write-Host "Requirements coverage and safe preflight checks passed: $checks"
} finally {
    if (Test-Path $testRoot) { Remove-Item $testRoot -Recurse -Force }
}
