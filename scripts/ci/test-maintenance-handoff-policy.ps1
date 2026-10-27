<#
=============================================================================
COMPONENT:    Framework Maintenance Handoff Policy Check
FILE:         scripts/ci/test-maintenance-handoff-policy.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-27
ENVIRONMENT:  PowerShell 7
-----------------------------------------------------------------------------
OVERVIEW
Validates canonical governance and Copilot/Claude instruction references.
-----------------------------------------------------------------------------
ARCHITECTURE
- Role:         standalone CI contract check
- Inputs:       repository policy, instructions, and handoff presence
- Outputs:      pass message or terminating error
- Dependencies: PowerShell 7
- Side Effects: none; repository files are read-only inputs
=============================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$spec = Get-Content (Join-Path $repoRoot 'SPEC.md') -Raw
$heading = '## Framework Maintenance Handoff and Approvals'
if (-not $spec.Contains($heading)) {
  throw 'SPEC.md is missing the canonical maintenance policy.'
}
$policy = ($spec -split [regex]::Escape($heading), 2)[1] -split '## Success Criteria', 2 |
  Select-Object -First 1

$requirements = @(
  'docs/audits/chatgpt-review-handoff.md',
  'dated handoff update for every change',
  'milestone', 'partial completion', 'failure or exception', 'blocker',
  'pause', 'interruption', 'another agent', 'Git operations',
  'Preserve historical entries', 'COMPLETE, PARTIAL, FAILED, or BLOCKED',
  'exact operation attempted', 'Error message or failure evidence',
  'Repository identity, branch, and full HEAD SHA', 'Files modified',
  'tests completed, failed, skipped, or not run', 'Working-tree status',
  'Work successfully completed', 'Unresolved issues', 'Recovery actions',
  'Exact next actions for ChatGPT and the owner', 'Publication status',
  'Modification, commit, push, and merge each require explicit, separate approval',
  'Approval for one never authorizes another', 'ambiguous acknowledgement',
  'Do not switch', 'read-only', 'copying it',
  'actual side effects', 'commits or pushes',
  'Never bypass a failed preflight or repository protection check',
  'HANDOFF NOT WRITTEN — BLOCKED', 'exact intended document path',
  'complete transferable Markdown', 'Never claim the file was updated',
  'Do not automatically commit', 'cannot guarantee agent compliance'
)
$normalizedPolicy = $policy -replace '\s+', ' '
foreach ($requirement in $requirements) {
  if (-not $normalizedPolicy.Contains($requirement)) {
    throw "Canonical maintenance policy is missing: $requirement"
  }
}

$instructionLinks = @{
  '.github/copilot-instructions.md' = '../SPEC.md#framework-maintenance-handoff-and-approvals'
  'CLAUDE.md' = 'SPEC.md#framework-maintenance-handoff-and-approvals'
}
foreach ($path in $instructionLinks.Keys) {
  $content = Get-Content (Join-Path $repoRoot $path) -Raw
  foreach ($requiredText in @(
    $instructionLinks[$path],
    'docs/audits/chatgpt-review-handoff.md',
    'COMPLETE, PARTIAL, FAILED, or BLOCKED',
    'HANDOFF NOT WRITTEN — BLOCKED',
    'explicit, separate approvals',
    'Never bypass repository protection'
  )) {
    if (-not $content.Contains($requiredText)) {
      throw "$path is missing maintenance guidance: $requiredText"
    }
  }
}

$handoffPath = Join-Path $repoRoot 'docs/audits/chatgpt-review-handoff.md'
if (-not (Test-Path -LiteralPath $handoffPath -PathType Leaf)) {
  throw 'The authoritative ChatGPT handoff is missing.'
}
Write-Host 'Framework maintenance handoff policy and agent references passed.'
