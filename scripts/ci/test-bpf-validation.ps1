Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts/bootstrap/helpers/bpf-validation.ps1')

function New-TestScenario {
  param(
    [string]$Name,
    [scriptblock]$ProcessPayloadFactory
  )

  $root = Join-Path $repoRoot (".wizard-metrics/ci/bpf-test-" + [guid]::NewGuid().ToString('N'))
  $payloadFolder = Join-Path $root "payloads/scenarios/$Name"
  $specFolder = Join-Path $root "specs/$Name"
  New-Item -ItemType Directory -Path $payloadFolder -Force | Out-Null
  New-Item -ItemType Directory -Path $specFolder -Force | Out-Null

  @'
{
  "TableLogicalName": "incident",
  "Columns": [
    {
      "LogicalName": "cct_triagebucket"
    },
    {
      "LogicalName": "cct_decisionnotes"
    }
  ]
}
'@ | Set-Content -Path (Join-Path $payloadFolder 'columns-incident.json') -Encoding UTF8

  @'
{
  "EntityDefinition": {
    "SchemaName": "cct_reviewboard"
  }
}
'@ | Set-Content -Path (Join-Path $payloadFolder 'table-cct-reviewboard.json') -Encoding UTF8

  @'
{
  "TableLogicalName": "cct_reviewboard",
  "Columns": [
    {
      "LogicalName": "cct_reviewdecision"
    }
  ]
}
'@ | Set-Content -Path (Join-Path $payloadFolder 'columns-cct-reviewboard.json') -Encoding UTF8

  @'
{
  "Relationships": [
    {
      "SchemaName": "cct_incident_cct_reviewboard",
      "RelationshipDefinition": {
        "SchemaName": "cct_incident_cct_reviewboard",
        "ReferencedEntity": "cct_reviewboard",
        "ReferencingEntity": "incident"
      }
    }
  ]
}
'@ | Set-Content -Path (Join-Path $payloadFolder 'relationships-incident-reviewboard.json') -Encoding UTF8

  @'
# spec.md

## Explicit Entity Mapping (Required)

### Standard reused tables (display -> logical)
- Case -> incident

### Custom tables to create (input -> generated logical)
- Review Board -> cct_reviewboard

### Standard fields reused
- incident.title
- incident.statuscode

### Custom fields to add
- incident.cct_triagebucket
- incident.cct_decisionnotes

### Relationships to create
- incident (referencing) -> cct_reviewboard (referenced)
'@ | Set-Content -Path (Join-Path $specFolder 'spec.md') -Encoding UTF8

  @'
# plan.md

## Optional Business Process Flow Plan
- Enabled: yes
'@ | Set-Content -Path (Join-Path $specFolder 'plan.md') -Encoding UTF8

  & $ProcessPayloadFactory $payloadFolder

  return [pscustomobject]@{
    Root = $root
    PayloadFolder = $payloadFolder
    SpecFolder = $specFolder
  }
}

function Remove-TestScenario {
  param([string]$Path)

  if (Test-Path $Path) {
    for ($attempt = 1; $attempt -le 5; $attempt++) {
      try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        break
      } catch {
        if ($attempt -eq 5) { throw }
        Start-Sleep -Milliseconds (100 * $attempt)
      }
    }
  }
}

$complete = New-TestScenario -Name 'complete' -ProcessPayloadFactory {
  param($payloadFolder)
  @'
{
  "Enabled": true,
  "BusinessProcessFlowName": "Case Resolution Process",
  "PrimaryProcessEntity": "incident",
  "FailIfBpfDefinitionIncomplete": true,
  "PreferUpdateExistingBpf": true,
  "CrossTableProgression": true,
  "FormIntegration": {
    "TargetFormName": "Information",
    "RequireMainForm": true
  },
  "StageDefinitions": [
    {
      "Order": 1,
      "StageName": "Intake",
      "EntityLogicalName": "incident",
      "RequiredFields": ["title", "cct_triagebucket"],
      "EntryCriteria": "Case is created",
      "ExitCriteria": "Triage bucket assigned",
      "RelationshipLogicalName": ""
    },
    {
      "Order": 2,
      "StageName": "Review",
      "EntityLogicalName": "cct_reviewboard",
      "RequiredFields": ["cct_reviewdecision"],
      "EntryCriteria": "Case is ready for review",
      "ExitCriteria": "Review board decision logged",
      "RelationshipLogicalName": "cct_incident_cct_reviewboard"
    }
  ]
}
'@ | Set-Content -Path (Join-Path $payloadFolder 'process-complete.json') -Encoding UTF8
}

try {
  $artifactText = Get-PlanningArtifactContent -Paths @((Join-Path $complete.SpecFolder 'spec.md'), (Join-Path $complete.SpecFolder 'plan.md'))
  $definition = (Get-BpfDefinitions -PayloadFolder $complete.PayloadFolder)[0]
  $validation = Test-BpfDefinition -Definition $definition -ArtifactText $artifactText -PayloadFolder $complete.PayloadFolder
  if ($validation.Status -ne 'passed') {
    throw "Expected complete BPF definition to pass, but status was '$($validation.Status)'."
  }
} finally {
  Remove-TestScenario -Path $complete.Root
}

$incomplete = New-TestScenario -Name 'incomplete' -ProcessPayloadFactory {
  param($payloadFolder)
  @'
{
  "Enabled": true,
  "BusinessProcessFlowName": "Incomplete Process",
  "PrimaryProcessEntity": "incident",
  "FailIfBpfDefinitionIncomplete": true,
  "PreferUpdateExistingBpf": true,
  "CrossTableProgression": false,
  "FormIntegration": {
    "TargetFormName": "Information",
    "RequireMainForm": true
  },
  "StageDefinitions": [
    {
      "Order": 1,
      "StageName": "Intake",
      "EntityLogicalName": "incident",
      "RequiredFields": [],
      "EntryCriteria": "Case is created",
      "ExitCriteria": "",
      "RelationshipLogicalName": ""
    },
    {
      "Order": 2,
      "StageName": "Decision",
      "EntityLogicalName": "incident",
      "RequiredFields": ["statuscode"],
      "EntryCriteria": "Ready for decision",
      "ExitCriteria": "Approved",
      "RelationshipLogicalName": ""
    }
  ]
}
'@ | Set-Content -Path (Join-Path $payloadFolder 'process-incomplete.json') -Encoding UTF8
}

try {
  $artifactText = Get-PlanningArtifactContent -Paths @((Join-Path $incomplete.SpecFolder 'spec.md'), (Join-Path $incomplete.SpecFolder 'plan.md'))
  $definition = (Get-BpfDefinitions -PayloadFolder $incomplete.PayloadFolder)[0]
  $validation = Test-BpfDefinition -Definition $definition -ArtifactText $artifactText -PayloadFolder $incomplete.PayloadFolder
  if ($validation.Status -ne 'failed') {
    throw "Expected incomplete BPF definition to fail, but status was '$($validation.Status)'."
  }
  if ($validation.Failed.Count -lt 1) {
    throw 'Expected incomplete BPF validation to report at least one failure.'
  }
} finally {
  Remove-TestScenario -Path $incomplete.Root
}

$multi = New-TestScenario -Name 'multi' -ProcessPayloadFactory {
  param($payloadFolder)
  foreach ($fileName in @('process-02-second.json', 'process-01-first.json')) {
    @'
{
  "Enabled": true,
  "BusinessProcessFlowName": "Ordered Process",
  "PrimaryProcessEntity": "incident",
  "FormIntegration": { "TargetFormName": "Information" },
  "StageDefinitions": [
    { "Order": 1, "StageName": "Intake", "EntityLogicalName": "incident", "RequiredFields": ["title"], "EntryCriteria": "Created", "ExitCriteria": "Ready" },
    { "Order": 2, "StageName": "Decision", "EntityLogicalName": "incident", "RequiredFields": ["statuscode"], "EntryCriteria": "Ready", "ExitCriteria": "Decided" }
  ]
}
'@ | Set-Content -LiteralPath (Join-Path $payloadFolder $fileName) -Encoding UTF8
  }
  '{ invalid json' | Set-Content -LiteralPath (Join-Path $payloadFolder 'process-03-invalid.json') -Encoding UTF8
}

try {
  $definitions = @(Get-BpfDefinitions -PayloadFolder $multi.PayloadFolder)
  if ($definitions.Count -ne 3) {
    throw "Expected every process payload to be discovered; found $($definitions.Count)."
  }
  if (@($definitions | ForEach-Object { [IO.Path]::GetFileName($_.__SourceFile) }) -join ',' -ne 'process-01-first.json,process-02-second.json,process-03-invalid.json') {
    throw 'Process payload discovery order is not deterministic.'
  }
  if ((Get-BpfArtifactKey -SourceFile $definitions[0].__SourceFile) -ne '01-first') {
    throw 'Process artifact key is not stable.'
  }
  $validResult = Test-BpfDefinition -Definition $definitions[0] -ArtifactText (Get-PlanningArtifactContent -Paths @((Join-Path $multi.SpecFolder 'spec.md'))) -PayloadFolder $multi.PayloadFolder
  $invalidResult = Test-BpfDefinition -Definition $definitions[2] -ArtifactText '' -PayloadFolder $multi.PayloadFolder
  if ($validResult.Status -ne 'passed' -or $invalidResult.Status -ne 'failed' -or $invalidResult.Failed.Count -eq 0) {
    throw 'A malformed process payload must fail without hiding successful process validation.'
  }
} finally {
  Remove-TestScenario -Path $multi.Root
}

if ((Get-BpfDesiredAction -ExistingProcess $null -PreferUpdateExistingBpf:$true) -ne 'designer-handoff-required') {
  throw 'Expected a missing process to require a supported designer handoff.'
}

if ((Get-BpfDesiredAction -ExistingProcess ([pscustomobject]@{ workflowid = [guid]::NewGuid().Guid }) -PreferUpdateExistingBpf:$true) -ne 'validate-existing') {
  throw 'Expected an existing process to be validated without metadata rewriting.'
}

$bpfScript = Get-Content -Path (Join-Path $repoRoot 'scripts/bootstrap/55-build-business-process-flows.ps1') -Raw
if ($bpfScript -match "Invoke-DvWithRetry\s+-Method\s+'(?:Post|Patch)'\s+-Path\s+'workflows'") {
  throw 'BPF stage must not directly create or patch workflow definition metadata.'
}
if ($bpfScript -match 'clientdata\s*=|uidata\s*=') {
  throw 'BPF stage must not fabricate clientdata or uidata process definitions.'
}
if ($bpfScript -notmatch 'PreviewOnly' -or $bpfScript -notmatch 'designer-handoff-required') {
  throw 'BPF stage must expose preview mode and the supported designer handoff.'
}
if ($bpfScript -notmatch 'ConvertTo-WorkflowUniqueName\s+-Value\s+[^\r\n]+\s+-PublisherPrefix\s+\$PublisherPrefix' -or
    $bpfScript -notmatch 'return\s+"\$\{prefix\}_\$slug"') {
  throw 'BPF designer handoff and lookup must derive workflow unique names from the configured publisher prefix.'
}
foreach ($required in @('foreach ($definition in $processDefinitions)', 'business-process-flow-$key-report.json', 'ProcessCount', 'FailedCount')) {
  if (-not $bpfScript.Contains($required)) {
    throw "BPF stage is missing multi-process contract text: $required"
  }
}

Write-Host 'BPF validation checks passed.' -ForegroundColor Green