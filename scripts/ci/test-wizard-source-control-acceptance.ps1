<#
=============================================================================
COMPONENT:    Wizard Source-Control Acceptance Test
FILE:         scripts/ci/test-wizard-source-control-acceptance.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-09
ENVIRONMENT:  PowerShell 7 | Git

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Runs the real intake wizard with scripted answers in a temporary Git repository
and verifies generated source-control guidance without Git mutation.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Source-control decisions appear in answers.md, plan.md, and tasks.md.
✔ Intake does not switch branches, commit, stage files, or push remote changes.
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$wizardPath = Join-Path $repoRoot 'scripts/bootstrap/05-start-wizard.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wizard-source-control-test-" + [guid]::NewGuid().ToString('N'))
$workspaceRoot = Join-Path $testRoot 'workspace'
$remoteRoot = Join-Path $testRoot 'remote.git'
$answersFile = Join-Path $testRoot 'answers.json'
$scenarioSlug = 'source-control-acceptance'

function Invoke-Git {
    param(
        [string[]]$Arguments,
        [switch]$AllowOutput
    )

    $output = @(& git @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed:`n$($output -join "`n")"
    }

    if ($AllowOutput) {
        return (($output -join "`n").Trim())
    }
}

function Assert-Contains {
    param(
        [string]$Path,
        [string[]]$ExpectedValues
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Expected generated file was not found: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    foreach ($expectedValue in $ExpectedValues) {
        if (-not $content.Contains($expectedValue)) {
            throw "Expected '$expectedValue' in $Path."
        }
    }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $workspaceRoot 'docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workspaceRoot 'payloads') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'wizard.profile.json') -Destination $workspaceRoot
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/wizard-contract-v1.md') -Destination (Join-Path $workspaceRoot 'docs')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/onboarding.md') -Destination (Join-Path $workspaceRoot 'docs')

    Invoke-Git -Arguments @('init', '--bare', $remoteRoot)
    Invoke-Git -Arguments @('-C', $workspaceRoot, 'init', '-b', 'main')
    Invoke-Git -Arguments @('-C', $workspaceRoot, 'config', 'user.name', 'Wizard Acceptance Test')
    Invoke-Git -Arguments @('-C', $workspaceRoot, 'config', 'user.email', 'wizard-test@example.invalid')
    Invoke-Git -Arguments @('-C', $workspaceRoot, 'add', 'wizard.profile.json', 'docs/wizard-contract-v1.md', 'docs/onboarding.md')
    Invoke-Git -Arguments @('-C', $workspaceRoot, 'commit', '-m', 'test: initialize acceptance fixture')
    Invoke-Git -Arguments @('-C', $workspaceRoot, 'remote', 'add', 'origin', $remoteRoot)
    Invoke-Git -Arguments @('-C', $workspaceRoot, 'push', '-u', 'origin', 'main')

    $scriptedAnswers = @(
        'Source Control Acceptance',
        $scenarioSlug,
        'standalone-model-driven',
        'hybrid',
        'create-new-forms',
        'incident',
        'Active Cases',
        'all run-created tables, forms, views, processes, and reports',
        'Operations',
        'feature/source-control-acceptance',
        'specs/source-control-acceptance',
        'checkpoints',
        'docs consistency, script smoke',
        'yes',
        'squash',
        'Model-driven app',
        'Power Apps',
        'Operations managers',
        'Track service requests',
        'Agents and supervisors',
        'Case, Review',
        'Main form, active cases view, review app',
        'A user can create and review a case',
        'Development',
        'Yes',
        'Unmanaged',
        'new',
        'SourceControlAcceptance',
        'new',
        'sca',
        'Case',
        'Review',
        'incident.title',
        'Review.sca_outcome',
        'Review -> Case',
        'yes',
        'no',
        'Agent | create case | daily | Case/Active Cases | case is ready for review; Supervisor | review case | daily | Review/Pending Reviews | decision is recorded',
        'create case | App maker | agent can save a valid case; review case | App maker | supervisor can record a decision',
        'Review -> Case | N:1 | required | new | restrict delete | supervisor review form',
        'incident, sca_review',
        'incident | Case risk summary | form | Case Starter Main Form Summary tab | title,statuscode,prioritycode | case escalation | Supervisor | renders current record and priority; sca_review | Review workload | dashboard | Operations dashboard | sca_outcome,statuscode,createdon | review backlog | Operations manager | totals match active view',
        'selected',
        'Case, Review',
        'Case=create',
        'Case=10; Review=20',
        'new, escalated, approved, and rejected cases',
        'Case | 2 | executive demo and escalation walkthrough',
        'Case=10; Review=1-3 per Case',
        'yes',
        'Case',
        'latest',
        '10',
        'createdon desc',
        '1',
        'scripted'
    )
    $scriptedAnswers | ConvertTo-Json | Set-Content -LiteralPath $answersFile -Encoding UTF8

    $beforeBranch = Invoke-Git -Arguments @('-C', $workspaceRoot, 'branch', '--show-current') -AllowOutput
    $beforeHead = Invoke-Git -Arguments @('-C', $workspaceRoot, 'rev-parse', 'HEAD') -AllowOutput
    $beforeBranches = Invoke-Git -Arguments @('-C', $workspaceRoot, 'for-each-ref', '--format=%(refname)', 'refs/heads') -AllowOutput
    $beforeRemoteHead = Invoke-Git -Arguments @('--git-dir', $remoteRoot, 'rev-parse', 'refs/heads/main') -AllowOutput

    $env:WIZARD_METRICS_OPTOUT = '1'
    $wizardOutput = @(& pwsh -NoProfile -File $wizardPath -Mode advanced-builder -Force -AnswersFile $answersFile -WorkspaceRoot $workspaceRoot 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Wizard acceptance run failed:`n$($wizardOutput -join "`n")"
    }

    $scenarioFolder = Join-Path $workspaceRoot "specs/$scenarioSlug"
    Assert-Contains -Path (Join-Path $scenarioFolder 'answers.md') -ExpectedValues @(
        '## Application Profile',
        '- Wizard mode: advanced-builder',
        '- Profile: standalone-model-driven',
        '- Entry Point Table: incident',
        '- Landing View: Active Cases',
        '- Entry Point Validation: approved',
        '- Landing View Plan: explicit-decision-required',
        '## App Module',
        '- App Name: Source Control Acceptance Review App',
        '## Source Control Plan',
        '- Scenario branch: feature/source-control-acceptance',
        '- Commit strategy: checkpoints',
        '- Pull request handoff: yes',
        '- Merge strategy: squash',
        '## User Task Plan',
        'Review -> Case | N:1 | required | new | restrict delete | supervisor review form',
        '- Record counts: Case=10; Review=20',
        '- Hero records: Case | 2 | executive demo and escalation walkthrough',
        '- Task scope and source-record limit: latest -- 10'
    )
    Assert-Contains -Path (Join-Path $scenarioFolder 'spec.md') -ExpectedValues @(
        '## Application Architecture',
        '- Profile: standalone-model-driven',
        '- Entry point: incident',
        '## User Tasks',
        '## Demo Data Requirements',
        '- Scope and target tables: selected -- Case, Review',
        '- Standard reused table strategy: Case=create',
        '- Relationship distribution: Case=10; Review=1-3 per Case',
        '- Task activity generation: yes -- latest 10 records per table, ordered by createdon desc'
    )
    Assert-Contains -Path (Join-Path $scenarioFolder 'plan.md') -ExpectedValues @(
        '## Model-Driven App Plan',
        '- Default landing view: Active Cases',
        '- Entry-point validation: approved',
        '- Landing-view action: explicit-decision-required',
        '## Source Control Plan',
        '- Required validation/CI: docs consistency, script smoke',
        '- Keep remote operations human-approved and verify the remote commit after push.',
        '## User Task Implementation Plan',
        '## Demo Data Implementation Plan',
        '- Rerun behavior: upsert',
        '- Source tag: source-control-acceptance'
    )
    Assert-Contains -Path (Join-Path $scenarioFolder 'tasks.md') -ExpectedValues @(
        "Confirm application profile 'standalone-model-driven' and architecture intent",
        "Confirm entry point 'incident' opens with 'Active Cases'",
        "Execute landing-view action 'explicit-decision-required' for 'Active Cases' on 'incident' before app assembly",
        "Verify the named landing view resolves to a saved query before running '62-build-app-module.ps1'",
        "Create or switch to scenario branch 'feature/source-control-acceptance' before implementation",
        'stage explicit files',
        'Push only after approval, verify the remote branch contains the local commit',
        'Validate relationship cardinality, requiredness, existing/new status, cascade behavior',
        'Approve demo data table scope and record counts: Case, Review -- Case=10; Review=20',
        'Approve hero records: Case | 2 | executive demo and escalation walkthrough',
        'Approve bounded Task activity generation: yes -- parents Case, scope latest, limit 10, order createdon desc, tasks per record 1',
        'Review and approve report-mappings.md; every critical table must have an explicit report decision'
    )
    Assert-Contains -Path (Join-Path $scenarioFolder 'report-mappings.md') -ExpectedValues @(
        '# Report Mappings',
        '- Status: approved',
        '- Critical or high-frequency tables: incident, sca_review',
        '| incident | Case risk summary | form | Case Starter Main Form Summary tab | title,statuscode,prioritycode | case escalation | Supervisor | renders current record and priority |',
        '| sca_review | Review workload | dashboard | Operations dashboard | sca_outcome,statuscode,createdon | review backlog | Operations manager | totals match active view |',
        'Build scripts remain blocked until this mapping is reviewed'
    )
    $standardViews = Get-Content -LiteralPath (Join-Path $scenarioFolder 'views.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($standardViews.Views[0].Disposition -ne 'explicit-decision-required') {
        throw 'A standard or hybrid-standard entry table must never receive automatic generated-view adoption.'
    }
    $demoDataPlan = Get-Content -LiteralPath (Join-Path $scenarioFolder 'demo-data-plan.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($demoDataPlan.Tables).Count -ne 2 -or $demoDataPlan.Tables -notcontains 'Case' -or $demoDataPlan.Tables -notcontains 'Review') {
        throw 'Expected demo-data-plan.json to contain the selected Case and Review tables.'
    }
    if ($demoDataPlan.StandardTableStrategy -ne 'Case=create' -or $demoDataPlan.RerunBehavior -ne 'upsert' -or $demoDataPlan.GenerateCleanup) {
        throw 'Expected demo-data-plan.json to preserve rerun and cleanup decisions.'
    }
    if ($demoDataPlan.HeroRecords -ne 'Case | 2 | executive demo and escalation walkthrough' -or
        -not $demoDataPlan.TaskGeneration.Enabled -or
        $demoDataPlan.TaskGeneration.Scope -ne 'latest' -or
        $demoDataPlan.TaskGeneration.SourceRecordLimit -ne 10 -or
        $demoDataPlan.TaskGeneration.OrderBy -ne 'createdon desc' -or
        $demoDataPlan.TaskGeneration.TasksPerRecord -ne 1) {
        throw 'Expected demo-data-plan.json to preserve hero-record and bounded Task activity decisions.'
    }

    $incompleteReportAnswers = @($scriptedAnswers)
    $criticalTablesIndex = [Array]::IndexOf($incompleteReportAnswers, 'incident, sca_review')
    if ($criticalTablesIndex -lt 0) {
        throw 'Could not locate the critical report table answer in the acceptance fixture.'
    }
    $incompleteReportAnswers[$criticalTablesIndex] = 'incident, sca_review, account'
    $incompleteReportAnswers | ConvertTo-Json | Set-Content -LiteralPath $answersFile -Encoding UTF8

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $blockedOutput = @(& pwsh -NoProfile -File $wizardPath -Mode advanced-builder -Force -AnswersFile $answersFile -WorkspaceRoot $workspaceRoot 2>&1)
    $blockedExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($blockedExitCode -eq 0) {
        throw 'Wizard did not block an unmapped critical report table.'
    }
    $blockedText = $blockedOutput | Out-String
    if ($blockedText -notmatch 'Report scoping is incomplete' -or $blockedText -notmatch 'account') {
        throw "Wizard failed for an unexpected reason:`n$($blockedOutput -join "`n")"
    }

    $invalidEntryAnswers = @($scriptedAnswers)
    $entryPointIndex = [Array]::IndexOf($invalidEntryAnswers, 'incident')
    if ($entryPointIndex -lt 0) {
        throw 'Could not locate the entry-point table answer in the acceptance fixture.'
    }
    $invalidEntryAnswers[$entryPointIndex] = 'account'
    $invalidEntryAnswers | ConvertTo-Json | Set-Content -LiteralPath $answersFile -Encoding UTF8

    $ErrorActionPreference = 'Continue'
    $invalidEntryOutput = @(& pwsh -NoProfile -File $wizardPath -Mode advanced-builder -Force -AnswersFile $answersFile -WorkspaceRoot $workspaceRoot 2>&1)
    $invalidEntryExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($invalidEntryExitCode -eq 0) {
        throw 'Wizard did not block an entry-point table outside the explicit table plan.'
    }
    $invalidEntryText = $invalidEntryOutput | Out-String
    if ($invalidEntryText -notmatch 'is not present in the explicit table plan' -or $invalidEntryText -notmatch 'account') {
        throw "Wizard failed for an unexpected entry-point reason:`n$($invalidEntryOutput -join "`n")"
    }

    $customEntryAnswers = @($scriptedAnswers)
    $customEntryAnswers[$entryPointIndex] = 'sca_review'
    $landingViewIndex = [Array]::IndexOf($customEntryAnswers, 'Active Cases')
    if ($landingViewIndex -lt 0) {
        throw 'Could not locate the landing-view answer in the acceptance fixture.'
    }
    $customEntryAnswers[$landingViewIndex] = 'Active Reviews'
    $customEntryAnswers | ConvertTo-Json | Set-Content -LiteralPath $answersFile -Encoding UTF8
    $customEntryOutput = @(& pwsh -NoProfile -File $wizardPath -Mode advanced-builder -Force -AnswersFile $answersFile -WorkspaceRoot $workspaceRoot 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Custom entry-point wizard run failed:`n$($customEntryOutput -join "`n")"
    }
    Assert-Contains -Path (Join-Path $scenarioFolder 'answers.md') -ExpectedValues @(
        '- Entry Point Table: sca_review',
        '- Entry Point Validation: approved',
        '- Landing View: Active Reviews',
        '- Landing View Plan: adopt-generated-active'
    )
    $customViews = Get-Content -LiteralPath (Join-Path $scenarioFolder 'views.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($customViews.Views[0].Disposition -ne 'adopt-generated-active') {
        throw 'Advanced Builder must plan adoption for an exact generated Active-view collision on a newly planned custom table.'
    }

    $retrofitSlug = 'retrofit-entry-acceptance'
    @(
        'Retrofit Entry Acceptance',
        $retrofitSlug,
        'standalone-model-driven',
        'custom-only',
        'ret_request',
        'Active Requests',
        'all existing and remaining tables, forms, and views',
        'Operations',
        'feature/retrofit-entry-acceptance',
        'specs/retrofit-entry-acceptance',
        'final-only',
        'docs consistency',
        'no',
        'squash',
        'Model-driven request app',
        'Power Apps',
        'Operations coordinators',
        'Track internal requests',
        'Coordinators and managers',
        'ret_request, ret_note',
        'Request form and Active Requests view',
        'Existing requests remain usable and remaining work is planned',
        'Development',
        'No',
        'Unmanaged',
        'ExistingRequestSolution',
        'ret',
        'none',
        'none',
        'none',
        'none',
        'none',
        'none',
        'none',
        'none',
        'no',
        'no',
        'Coordinator | review request | daily | Request/Active Requests | request is triaged',
        'review request | App owner | coordinator can open and triage an existing request'
    ) | ConvertTo-Json | Set-Content -LiteralPath $answersFile -Encoding UTF8

    $retrofitOutput = @(& pwsh -NoProfile -File $wizardPath -Mode advanced-builder -Retrofit -Force -AnswersFile $answersFile -WorkspaceRoot $workspaceRoot 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Retrofit wizard acceptance run failed:`n$($retrofitOutput -join "`n")"
    }
    $retrofitFolder = Join-Path $workspaceRoot "specs/$retrofitSlug"
    Assert-Contains -Path (Join-Path $retrofitFolder 'answers.md') -ExpectedValues @(
        '- Entry Point Table: ret_request',
        '- Entry Point Validation: approved',
        '- Landing View Plan: explicit-decision-required',
        '- retrofit: enabled'
    )
    $retrofitViews = Get-Content -LiteralPath (Join-Path $retrofitFolder 'views.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($retrofitViews.Views[0].Disposition -ne 'explicit-decision-required') {
        throw 'A retrofit or preexisting table must never receive automatic generated-view adoption.'
    }

    $afterBranch = Invoke-Git -Arguments @('-C', $workspaceRoot, 'branch', '--show-current') -AllowOutput
    $afterHead = Invoke-Git -Arguments @('-C', $workspaceRoot, 'rev-parse', 'HEAD') -AllowOutput
    $afterBranches = Invoke-Git -Arguments @('-C', $workspaceRoot, 'for-each-ref', '--format=%(refname)', 'refs/heads') -AllowOutput
    $afterRemoteHead = Invoke-Git -Arguments @('--git-dir', $remoteRoot, 'rev-parse', 'refs/heads/main') -AllowOutput
    $stagedFiles = Invoke-Git -Arguments @('-C', $workspaceRoot, 'diff', '--cached', '--name-only') -AllowOutput

    if ($afterBranch -ne $beforeBranch) { throw 'Wizard changed the current Git branch.' }
    if ($afterHead -ne $beforeHead) { throw 'Wizard created or moved a local commit.' }
    if ($afterBranches -ne $beforeBranches) { throw 'Wizard created or deleted a local branch.' }
    if ($afterRemoteHead -ne $beforeRemoteHead) { throw 'Wizard pushed a remote change.' }
    if (-not [string]::IsNullOrWhiteSpace($stagedFiles)) { throw "Wizard staged files: $stagedFiles" }
}
finally {
    Remove-Item Env:WIZARD_METRICS_OPTOUT -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host 'Wizard source-control acceptance checks passed.' -ForegroundColor Green