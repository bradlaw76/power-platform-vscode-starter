<#
=============================================================================
COMPONENT:    Auth Connect
FILE:         scripts/bootstrap/10-auth-connect.ps1
VERSION:      0.2.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Azure CLI | Power Platform CLI | Dataverse Web API

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Connects the local session to the target Power Platform environment and
validates solution identity inputs before build steps mutate Dataverse.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          environment URL, auth context, solution identity details
- Outputs:         validated connection state and solution/prefix guidance
- Dependencies:    PAC CLI, Azure auth context, repo helper scripts
- Side Effects:    authenticates against environment services when needed

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Complete the local prerequisite check first.
2. Use the intended environment URL and solution identity values.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Valid environment access succeeds and prints connection guidance.
✔ Invalid or conflicting solution identity values are blocked clearly.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.
v0.2.0  2026-08-10  Added profile-aware reused-table capability discovery.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Do not proceed silently when environment or identity validation fails.
- Keep connection checks aligned with the planning artifacts.
- Update this header when the step contract materially changes.
=============================================================================
#>

<#
.SYNOPSIS
    Interactive sign-in helper. Authenticates to Azure and Power Platform,
    acquires a Dataverse bearer token, and saves environment values to a
    session env-vars file for use by the other bootstrap scripts.

.DESCRIPTION
    Prompts for all required values. Saves them to .env.ps1 in the repo root
    (git-ignored). All other bootstrap scripts dot-source .env.ps1 automatically
    so you only need to run this once per terminal session.

    Supports:
      - Interactive browser login (default)
      - Device code flow (headless / no browser)
      - Service principal login (CI/CD or tenant with MFA restrictions)

.EXAMPLE
    # Interactive (browser popup)
    pwsh ./scripts/bootstrap/10-auth-connect.ps1

    # Device code (no browser)
    pwsh ./scripts/bootstrap/10-auth-connect.ps1 -UseDeviceCode

    # Service principal
    pwsh ./scripts/bootstrap/10-auth-connect.ps1 -ServicePrincipal
#>

param(
    [switch]$UseDeviceCode,
    [switch]$ServicePrincipal,
    [string]$ScenarioSlug = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "10-auth-connect.ps1"
}

Write-Host ""
Write-Host "=== Auth Connect ===" -ForegroundColor Cyan
Write-Host "This script will sign you in and save your environment settings."
Write-Host "All values are stored locally only. Nothing is committed to source control."
Write-Host ""

# ── Collect environment details ────────────────────────────────────────────
$envUrl = Read-Host "Dataverse environment URL (e.g. https://your-org.crm.dynamics.com)"
$envUrl = $envUrl.TrimEnd("/")

$tenantId = Read-Host "Azure tenant ID or domain (leave blank to use default)"

Write-Host ""

# ── Azure sign-in ──────────────────────────────────────────────────────────
if ($ServicePrincipal) {
    Write-Host "Service principal login selected." -ForegroundColor Yellow
    $clientId     = Read-Host "Client (application) ID"
    $clientSecret = Read-Host "Client secret" -AsSecureString
    $plainSecret  = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecret))

    if ($tenantId) {
        az login --service-principal -u $clientId -p $plainSecret --tenant $tenantId | Out-Null
    } else {
        Write-Host "Tenant ID is required for service principal login." -ForegroundColor Red
        exit 1
    }
}
elseif ($UseDeviceCode) {
    Write-Host "Device code login: a code will be printed below." -ForegroundColor Yellow
    Write-Host "Visit https://microsoft.com/devicelogin and enter the code."
    if ($tenantId) {
        az login --use-device-code --tenant $tenantId | Out-Null
    } else {
        az login --use-device-code --allow-no-subscriptions | Out-Null
    }
}
else {
    Write-Host "Opening browser for interactive login..."
    if ($tenantId) {
        az login --tenant $tenantId | Out-Null
    } else {
        az login --allow-no-subscriptions | Out-Null
    }
}

Write-Host ""
Write-Host "Verifying Azure session..." -ForegroundColor Cyan
$account = az account show | ConvertFrom-Json
Write-Host "  Signed in as: $($account.user.name)"
Write-Host "  Tenant:       $($account.tenantId)"
Write-Host "  Subscription: $($account.name)"
Write-Host ""

# ── Get bearer token ───────────────────────────────────────────────────────
Write-Host "Acquiring Dataverse bearer token..."
$tokenResource = "$envUrl/"
$token = az account get-access-token --resource $tokenResource --query accessToken -o tsv
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "Failed to acquire token. Verify the environment URL matches exactly." -ForegroundColor Red
    exit 1
}
Write-Host "Token acquired." -ForegroundColor Green

# ── Power Platform CLI auth profile ────────────────────────────────────────
Write-Host ""
Write-Host "Creating Power Platform CLI auth profile..."
pac auth create --url $envUrl | Out-Null
pac auth list

# ── Load any planning values written by 05-start-wizard.ps1 ─────────────────
$_planEnvFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
$plannedSolution = ""
$plannedPrefix   = ""
if (Test-Path $_planEnvFile) {
    . $_planEnvFile
    $plannedSolution = if ($env:DV_SOLUTION_NAME)    { $env:DV_SOLUTION_NAME }    else { "" }
    $plannedPrefix   = if ($env:DV_PUBLISHER_PREFIX) { $env:DV_PUBLISHER_PREFIX } else { "" }
}

function Invoke-DvGet([string]$Path) {
    $h = @{ "Authorization"="Bearer $token"; "Accept"="application/json"; "OData-Version"="4.0"; "OData-MaxVersion"="4.0" }
    return Invoke-RestMethod -Method Get -Uri "$($envUrl.TrimEnd('/'))/api/data/v9.2/$Path" -Headers $h
}

function Get-ReusedScenarioTables {
    param(
        [string]$RepositoryRoot,
        [string]$Slug
    )

    if ([string]::IsNullOrWhiteSpace($Slug)) { return @() }
    $answersPath = Join-Path $RepositoryRoot "specs/$Slug/answers.md"
    if (-not (Test-Path $answersPath)) { return @() }

    $answersText = Get-Content $answersPath -Raw
    $tableStrategy = [regex]::Match($answersText, '(?im)^-\s*Table Strategy:\s*(.+)$').Groups[1].Value.Trim().ToLowerInvariant()
    if (@('oob-only', 'hybrid') -notcontains $tableStrategy) { return @() }

    $payloadRoot = Join-Path $RepositoryRoot 'payloads'
    $createdTables = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($file in @(Get-ChildItem $payloadRoot -Filter 'table-*.json' -ErrorAction SilentlyContinue)) {
        $document = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $schemaName = if ($null -ne $document.EntityDefinition) { $document.EntityDefinition.SchemaName } else { $document.SchemaName }
        if (-not [string]::IsNullOrWhiteSpace($schemaName)) { [void]$createdTables.Add($schemaName.ToLowerInvariant()) }
    }

    $reusedTables = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($file in @(Get-ChildItem $payloadRoot -Filter 'columns-*.json' -ErrorAction SilentlyContinue)) {
        $document = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $tableName = [string]$document.TableLogicalName
        if (-not [string]::IsNullOrWhiteSpace($tableName) -and -not $createdTables.Contains($tableName)) {
            [void]$reusedTables.Add($tableName.ToLowerInvariant())
        }
    }
    return @($reusedTables | Sort-Object)
}

function Test-ReusedScenarioTables {
    param(
        [string]$RepositoryRoot,
        [string]$Slug
    )

    $tables = @(Get-ReusedScenarioTables -RepositoryRoot $RepositoryRoot -Slug $Slug)
    if ($tables.Count -eq 0) { return }

    Write-Host ""
    Write-Host "Verifying reused Dataverse tables for scenario '$Slug'..." -ForegroundColor Cyan
    $results = foreach ($table in $tables) {
        try {
            $safeTable = $table.Replace("'", "''")
            $metadata = Invoke-DvGet "EntityDefinitions(LogicalName='$safeTable')?`$select=LogicalName,DisplayName,IsCustomEntity"
            Write-Host "  ${table}: available" -ForegroundColor Green
            [pscustomobject]@{ logicalName = $table; available = $true; isCustomEntity = [bool]$metadata.IsCustomEntity; error = '' }
        } catch {
            Write-Host "  ${table}: unavailable" -ForegroundColor Red
            [pscustomobject]@{ logicalName = $table; available = $false; isCustomEntity = $null; error = $_.Exception.Message }
        }
    }

    $reportRoot = Join-Path $RepositoryRoot '.wizard-metrics/artifacts/environment'
    New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
    [ordered]@{ scenarioSlug = $Slug; checkedAtUtc = [DateTime]::UtcNow.ToString('o'); reusedTables = @($results) } |
        ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $reportRoot 'table-capabilities.json') -Encoding UTF8

    $missing = @($results | Where-Object { -not $_.available })
    if ($missing.Count -gt 0) {
        throw "The environment is missing required reused table(s): $(@($missing.logicalName) -join ', '). Install the required Dynamics app or revise the table strategy before build."
    }
}

Test-ReusedScenarioTables -RepositoryRoot $repoRoot -Slug $ScenarioSlug

function Read-ChoiceValue {
    param(
        [string]$Prompt,
        [string]$Default
    )

    $value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    return $value.Trim().ToLowerInvariant()
}

# ── Collect build config ───────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Build Configuration ===" -ForegroundColor Cyan

# Solution
Write-Host ""
$plannedSolutionHint = if ($plannedSolution) { " (planned unique name: $plannedSolution)" } else { "" }
$solutionChoice = Read-ChoiceValue -Prompt "New solution or existing?$plannedSolutionHint (new/existing)" -Default "new"
if (@('new', 'existing') -notcontains $solutionChoice) {
    Write-Host "Choose 'new' or 'existing'. Existing reuse is allowed only when you explicitly choose 'existing'." -ForegroundColor Red
    exit 1
}

$_existingSolutionDisplay = ""
if ($solutionChoice -ieq "existing") {
    $plannedSolutionDefault = if ($plannedSolution) { " [$plannedSolution]" } else { "" }
    $solutionName = Read-Host "Existing solution unique name$plannedSolutionDefault"
    if ([string]::IsNullOrWhiteSpace($solutionName)) { $solutionName = $plannedSolution }
    if ([string]::IsNullOrWhiteSpace($solutionName)) {
        Write-Host "An existing solution unique name is required." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Verifying solution '$solutionName'..." -NoNewline
    $solCheck = Invoke-DvGet "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid,uniquename,friendlyname"
    if ($solCheck.value.Count -eq 0) {
        Write-Host " NOT FOUND" -ForegroundColor Red
        Write-Host "Solution '$solutionName' does not exist in this environment." -ForegroundColor Red
        Write-Host "Create it in Power Platform Maker portal first, then rerun this script." -ForegroundColor Yellow
        exit 1
    }
    Write-Host " OK" -ForegroundColor Green
    $_existingSolutionDisplay = "$($solCheck.value[0].friendlyname)"
} else {
    $promptDefault = if ($plannedSolution) { " [$plannedSolution]" } else { "" }
    $solutionName = Read-Host "New solution unique name (letters/numbers only, e.g. ContosoHRApp)$promptDefault"
    if ([string]::IsNullOrWhiteSpace($solutionName)) { $solutionName = $plannedSolution }
    if ([string]::IsNullOrWhiteSpace($solutionName)) {
        Write-Host "A new solution unique name is required." -ForegroundColor Red
        exit 1
    }
    $solCheck = Invoke-DvGet "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid,uniquename"
    if ($solCheck.value.Count -gt 0) {
        Write-Host "  ERROR: solution '$solutionName' already exists in this environment." -ForegroundColor Red
        Write-Host "Choose a unique name for a new solution, or rerun this script and explicitly select 'existing' if reuse is intentional." -ForegroundColor Yellow
        exit 1
    }
}
$solutionDisplayPrompt = if ([string]::IsNullOrWhiteSpace($_existingSolutionDisplay)) {
    "Solution display name (e.g. Contoso HR Application)"
} else {
    "Solution display name (e.g. Contoso HR Application) [$_existingSolutionDisplay]"
}
$solutionDisplay = Read-Host $solutionDisplayPrompt
if ([string]::IsNullOrWhiteSpace($solutionDisplay)) {
    $solutionDisplay = $_existingSolutionDisplay
}

# Publisher prefix
Write-Host ""
$_prefixHint   = if ($plannedPrefix) { " [$plannedPrefix from wizard]" } else { "" }
$prefixChoice  = Read-Host "New publisher prefix or existing?$_prefixHint (new/existing)"
if ([string]::IsNullOrWhiteSpace($prefixChoice)) { $prefixChoice = if ($plannedPrefix) { "existing" } else { "new" } }

if ($prefixChoice -ieq "existing") {
    $plannedPrefixDefault = if ($plannedPrefix) { " [$plannedPrefix]" } else { "" }
    $publisherPrefix = Read-Host "Existing prefix (e.g. cct, fabrikam)$plannedPrefixDefault"
    if ([string]::IsNullOrWhiteSpace($publisherPrefix)) { $publisherPrefix = $plannedPrefix }
    Write-Host "  Verifying publisher prefix '$publisherPrefix'..." -NoNewline
    $pubCheck = Invoke-DvGet "publishers?`$filter=customizationprefix eq '$publisherPrefix'&`$select=publisherid,uniquename,friendlyname,customizationprefix"
    if ($pubCheck.value.Count -eq 0) {
        Write-Host " NOT FOUND" -ForegroundColor Red
        Write-Host "Publisher with prefix '$publisherPrefix' does not exist in this environment." -ForegroundColor Red
        Write-Host "Create the publisher in Power Platform Maker portal first, then rerun this script." -ForegroundColor Yellow
        exit 1
    }
    Write-Host " OK" -ForegroundColor Green
    $publisherName = if ($pubCheck.value[0].friendlyname) { $pubCheck.value[0].friendlyname } else { $publisherPrefix }
} else {
    $prefixPromptDefault = if ($plannedPrefix) { " [$plannedPrefix]" } else { "" }
    $publisherPrefix = Read-Host "New prefix (3-8 lowercase letters, e.g. cto, demo)$prefixPromptDefault"
    if ([string]::IsNullOrWhiteSpace($publisherPrefix)) { $publisherPrefix = $plannedPrefix }
    $publisherName = Read-Host "Publisher name (e.g. Contoso)"
}

# ── Write session env file ─────────────────────────────────────────────────
$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"

$content = @"
# Auto-generated by 10-auth-connect.ps1 — do not commit this file.
`$env:DV_ENVIRONMENT_URL    = "$envUrl"
`$env:DV_TOKEN              = "$token"
`$env:DV_PUBLISHER_NAME     = "$publisherName"
`$env:DV_PUBLISHER_PREFIX   = "$publisherPrefix"
`$env:DV_SOLUTION_NAME      = "$solutionName"
`$env:DV_SOLUTION_DISPLAY   = "$solutionDisplay"
`$global:DV_ENVIRONMENT_URL = "`$env:DV_ENVIRONMENT_URL"
`$global:DV_TOKEN           = "`$env:DV_TOKEN"
`$global:DV_PUBLISHER_NAME  = "`$env:DV_PUBLISHER_NAME"
`$global:DV_PUBLISHER_PREFIX= "`$env:DV_PUBLISHER_PREFIX"
`$global:DV_SOLUTION_NAME   = "`$env:DV_SOLUTION_NAME"
`$global:DV_SOLUTION_DISPLAY= "`$env:DV_SOLUTION_DISPLAY"
"@

Set-Content -Path $envFile -Value $content -Encoding UTF8
Write-Host ""
Write-Host "Session config saved to: $envFile" -ForegroundColor Green
Write-Host "All bootstrap scripts will load this automatically."
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/20-build-tables.ps1"
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Authentication and environment configuration saved."
}

