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
    [switch]$ServicePrincipal
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

# ── Collect build config ───────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Build Configuration ===" -ForegroundColor Cyan

# Solution
Write-Host ""
$_solutionHint  = if ($plannedSolution) { " [$plannedSolution from wizard]" } else { "" }
$solutionChoice = Read-Host "New solution or existing?$_solutionHint (new/existing)"
if ([string]::IsNullOrWhiteSpace($solutionChoice)) { $solutionChoice = if ($plannedSolution) { "existing" } else { "new" } }

if ($solutionChoice -ieq "existing") {
    $solutionName = Read-Host "Existing solution unique name$(if ($plannedSolution) { \" [$plannedSolution]\" } else { \"\" })"
    if ([string]::IsNullOrWhiteSpace($solutionName)) { $solutionName = $plannedSolution }
    Write-Host "  Verifying solution '$solutionName'..." -NoNewline
    $solCheck = Invoke-DvGet "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid,uniquename"
    if ($solCheck.value.Count -eq 0) {
        Write-Host " NOT FOUND" -ForegroundColor Red
        Write-Host "Solution '$solutionName' does not exist in this environment." -ForegroundColor Red
        Write-Host "Create it in Power Platform Maker portal first, then rerun this script." -ForegroundColor Yellow
        exit 1
    }
    Write-Host " OK" -ForegroundColor Green
} else {
    $promptDefault = if ($plannedSolution) { " [$plannedSolution]" } else { "" }
    $solutionName = Read-Host "New solution unique name (letters/numbers only, e.g. ContosoHRApp)$promptDefault"
    if ([string]::IsNullOrWhiteSpace($solutionName)) { $solutionName = $plannedSolution }
    $solCheck = Invoke-DvGet "solutions?`$filter=uniquename eq '$solutionName'&`$select=solutionid,uniquename"
    if ($solCheck.value.Count -gt 0) {
        Write-Host "  Warning: solution '$solutionName' already exists in this environment." -ForegroundColor Yellow
        $cont = Read-Host "  Add components to the existing solution? (y/N)"
        if ($cont -notmatch '^(y|yes)$') { exit 1 }
    }
}
$solutionDisplay = Read-Host "Solution display name (e.g. Contoso HR Application)"

# Publisher prefix
Write-Host ""
$_prefixHint   = if ($plannedPrefix) { " [$plannedPrefix from wizard]" } else { "" }
$prefixChoice  = Read-Host "New publisher prefix or existing?$_prefixHint (new/existing)"
if ([string]::IsNullOrWhiteSpace($prefixChoice)) { $prefixChoice = if ($plannedPrefix) { "existing" } else { "new" } }

if ($prefixChoice -ieq "existing") {
    $publisherPrefix = Read-Host "Existing prefix (e.g. vafe, contoso)$(if ($plannedPrefix) { \" [$plannedPrefix]\" } else { \"\" })"
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

