<#
=============================================================================
COMPONENT:    Framework Repository Context Preflight
FILE:         scripts/bootstrap/framework-context-preflight.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-23
ENVIRONMENT:  PowerShell 7 | Git
OVERVIEW
Read-only, fail-closed verification of the approved maintenance checkout.
ARCHITECTURE
- Inputs: explicit repository root, maintenance branch, and approved HEAD SHA.
- Outputs: verified context including worktree status; no files or refs written.
- Dependencies: helpers/wizard-source-protection.ps1, Git.
TEST CASES
- Exact context passes; wrong root, remote, branch, or HEAD fails.
NON-NEGOTIABLES
- Never switch branches, infer approval, fetch, or repair repository identity.
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$FrameworkRoot,
    [Parameter(Mandatory)]
    [ValidatePattern('^framework-maintenance/[a-z0-9][a-z0-9._/-]*$')]
    [string]$ExpectedBranch,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-fA-F0-9]{40}$')]
    [string]$ExpectedHead
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'helpers/wizard-source-protection.ps1')

if ($ExpectedBranch -match '(^|/)\.\.?(/|$)') {
    throw 'Repository context preflight rejects traversal in the expected branch.'
}
if (-not (Test-Path -LiteralPath $FrameworkRoot -PathType Container)) {
    throw 'Repository context preflight requires an existing FrameworkRoot.'
}
$root = Resolve-WizardPhysicalPath -Path $FrameworkRoot
$identity = Get-WizardGitIdentity -RepositoryPath $root
if (-not $identity.Root.Equals($root, [StringComparison]::Ordinal)) {
    throw 'Repository context preflight requires the exact Git repository root, not a subdirectory.'
}
$inside = @(& git -C $root rev-parse --is-inside-work-tree 2>$null)
if ($LASTEXITCODE -ne 0 -or ($inside -join '').Trim() -cne 'true') {
    throw 'Repository context preflight requires a Git worktree, not an installed package or bare repository.'
}
if ($identity.Remotes.Count -ne 1 -or
    $identity.Remotes[0] -cne 'github.com/bradlaw76/power-platform-vscode-starter') {
    throw 'Repository context preflight requires the canonical framework repository and unambiguous fetch/push identity.'
}
$branch = (@(& git -C $root symbolic-ref --quiet --short HEAD 2>$null) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $branch -cne $ExpectedBranch) {
    throw "Repository context preflight branch mismatch: expected '$ExpectedBranch', found '$branch'. Do not switch branches automatically."
}
$head = (@(& git -C $root rev-parse --verify 'HEAD^{commit}' 2>$null) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $head -ine $ExpectedHead) {
    throw "Repository context preflight HEAD mismatch: expected '$ExpectedHead', found '$head'. Stop for a reviewed baseline."
}
$status = @(& git -C $root status --porcelain=v1 --untracked-files=all)
if ($LASTEXITCODE -ne 0) { throw 'Repository context preflight could not inspect the working tree.' }

[pscustomobject]@{
    FrameworkRoot = $root
    Repository = $identity.Remotes[0]
    Branch = $branch
    Head = $head
    WorkingTree = $status
    Clean = $status.Count -eq 0
    Verified = $true
}
