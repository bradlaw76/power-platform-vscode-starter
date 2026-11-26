<#
COMPONENT: Consolidated safe capability preflight | VERSION: 1.0
ARCHITECTURE: Source profile, parsed scripts/schemas and selected installed API.
SECURITY: No credentials, network, authentication, install or native approval.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$ScenarioFolder,
    [string]$PlanningWorkspaceRoot,
    [switch]$RequireCoverage,
    [switch]$RequireFunctionalCapability,
    [switch]$RequireFrameworkRuntime,
    [switch]$RequireNativeBuild,
    [switch]$RequireWindowsWorker,
    [string]$PythonExecutable = 'python',
    [string]$ExpectedRuntimeRoot
)
$ErrorActionPreference = 'Stop'
if ($RequireWindowsWorker -or $RequireFunctionalCapability) { $RequireFrameworkRuntime = $true }
$failures = [Collections.Generic.List[string]]::new()
$checked = [Collections.Generic.List[string]]::new()
$pythonSources = [Collections.Generic.List[string]]::new()
$runtime = @{ available = $false; status = 'not-requested' }
$coverage = @{ status = 'not-requested' }
$native = @{ validatorsAvailable = $false; buildIntegrationVerified = $false; status = 'not-requested' }
try {
    $profile = Get-Content -LiteralPath (Join-Path $RepoRoot 'wizard.profile.json') -Raw | ConvertFrom-Json -AsHashtable
    if ($profile.requirementsCoverage.schemaVersion -cne '1.0') { throw 'Profile coverage version unavailable.' }
    if ($PlanningWorkspaceRoot) {
        if (-not (Test-Path -LiteralPath (Join-Path $PlanningWorkspaceRoot 'payloads') -PathType Container)) {
            $failures.Add('Planning workspace payloads directory missing; restore the existing planning layout before intake.')
        }
        foreach ($name in @('wizard.profile.json', 'docs\wizard-contract-v1.md', 'docs\onboarding.md')) {
            if (-not (Test-Path -LiteralPath (Join-Path $PlanningWorkspaceRoot $name) -PathType Leaf)) {
                $failures.Add("Planning workspace capability missing: $name. Select a complete reviewed runtime/planning workspace; copied instructions are not runtime installation.")
            }
        }
        if ($failures.Count -eq 0) {
            $consumer = Get-Content -LiteralPath (Join-Path $PlanningWorkspaceRoot 'wizard.profile.json') -Raw | ConvertFrom-Json -AsHashtable
            if ($consumer.contractVersion -cne $profile.contractVersion -or $consumer.profileVersion -cne $profile.profileVersion) {
                $failures.Add('Selected planning profile differs from source contract; review compatibility rather than defaulting silently.')
            }
            if (-not $consumer.ContainsKey('requirementsCoverage') -or $consumer.requirementsCoverage.schemaVersion -cne '1.0') {
                $failures.Add('Selected planning profile lacks the source coverage capability contract; review compatibility explicitly.')
            }
        }
    }
    foreach ($name in $profile.capabilityPreflight.requiredSourceFiles) {
        $path = Join-Path $RepoRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing source capability: $name"); continue }
        if ($name.EndsWith('.ps1')) {
            $parseErrors = $null
            [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors)
            if ($parseErrors.Count) { $failures.Add("Invalid PowerShell capability: $name") }
        } elseif ($name.EndsWith('.json')) {
            [void](Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop)
        } elseif ($name.EndsWith('.py')) {
            $pythonSources.Add($path)
        }
        $checked.Add($name)
    }
    if ($failures.Count -eq 0) {
        . (Join-Path $RepoRoot 'scripts\bootstrap\helpers\requirements-coverage.ps1')
        . (Join-Path $RepoRoot 'scripts\bootstrap\helpers\dataverse-runtime.ps1')
        . (Join-Path $RepoRoot 'scripts\bootstrap\helpers\semantic-fields.ps1')
        . (Join-Path $RepoRoot 'scripts\bootstrap\helpers\reporting-plan.ps1')
        foreach ($command in @('Test-WizardRequirementsCoverage', 'Read-WizardSemanticPlan', 'Assert-WizardSemanticPayloads', 'Invoke-WizardDataverseRequest')) {
            if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { $failures.Add("Unavailable helper API: $command") }
        }
        $native.validatorsAvailable = [bool](Get-Command Read-WizardHtmlReportPlan -ErrorAction SilentlyContinue)
        foreach ($family in @('field-type-decisions', 'html-reports')) {
            $example = Get-Content -LiteralPath (Join-Path $RepoRoot "schemas\examples\$family.example.json") -Raw
            if (-not (Test-Json -Json $example -SchemaFile (Join-Path $RepoRoot "schemas\payloads\$family.schema.json"))) {
                $failures.Add("Native example/schema compatibility failed: $family")
            }
        }
        $native.status = 'validator-source-only'
        if ($RequireNativeBuild) {
            $failures.Add('Native build integration is unverified on this source lineage. Run approved Planning/Payload/Metadata and report gates through a reviewed compatible native executor; this preflight cannot authorize native build.')
        }
        if ($ScenarioFolder) {
            $coverage = Test-WizardRequirementsCoverage -ScenarioFolder $ScenarioFolder -RequireCoverage:$RequireCoverage
        } elseif ($RequireCoverage) { $failures.Add('Coverage requires an explicit scenario folder.') }
    }
    if ($failures.Count -eq 0) {
        $probe = Join-Path $RepoRoot 'scripts\bootstrap\helpers\wizard-capabilities.py'
        $probeArguments = @($probe)
        foreach ($source in $pythonSources) { $probeArguments += @('--source', $source) }
        if ($RequireFrameworkRuntime) { $probeArguments += '--runtime' }
        $output = & $PythonExecutable @probeArguments
        if ($LASTEXITCODE -ne 0) { throw 'Selected interpreter capability probe failed.' }
        $runtime = $output | ConvertFrom-Json -AsHashtable
        foreach ($error in $runtime.sourceErrors) { $failures.Add("Invalid Python source capability: $error") }
        if ($RequireFrameworkRuntime -and -not $runtime.available) { $failures.Add('Selected interpreter lacks compatible installed framework 0.2.1. Source/skill adoption is not installation.') }
        if ($RequireFrameworkRuntime -and ($RequireCoverage -or $RequireFunctionalCapability -or $coverage.status -eq 'covered') -and -not $runtime.coverage) { $failures.Add('Installed runtime lacks accepted-outcome functional verification/reconciliation capability.') }
        if ($RequireWindowsWorker -and -not $runtime.windowsSupervision) { $failures.Add('Installed Windows owned-worker supervision capability unavailable; guided execution remains independent.') }
        if ($RequireWindowsWorker -and $runtime.platform -ne 'win32') { $failures.Add('Selected interpreter is not native Windows; WSL interop is not owned-Job supervision proof.') }
        if ($ExpectedRuntimeRoot -and $runtime.origin) {
            $expected = [IO.Path]::GetFullPath($ExpectedRuntimeRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            if (-not $runtime.origin.StartsWith($expected, [StringComparison]::OrdinalIgnoreCase)) { $failures.Add('Selected interpreter package origin differs from expected runtime source.') }
        }
    }
} catch { $failures.Add($_.Exception.Message) }
@{
    status = $(if ($failures.Count) { 'BLOCKED' } else { 'SOURCE READY' })
    checked = @($checked.ToArray()); failures = @($failures.ToArray())
    runtime = $runtime; coverage = $coverage; native = $native; nativeApproval = $false; executionAuthorized = $false
} | ConvertTo-Json -Depth 20
if ($failures.Count) { exit 1 }
