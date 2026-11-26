<#
=============================================================================
COMPONENT:    H009 Local Wizard Version
FILE:         scripts/bootstrap/helpers/wizard-version.ps1
VERSION:      0.1.1
AUTHOR:       Power Platform VS Code Starter
ENVIRONMENT:  PowerShell 7 | Windows | Linux
OVERVIEW:     Read-only, offline startup identity; descriptors are not provenance.
INPUTS:       Explicit runtime root; no consuming-project discovery or network.
OUTPUTS:      Version/status object or shared terminal/agent banner.
NON-NEGOTIABLES: No writes, installs, release inference, or discovery blocking.
=============================================================================
#>

function Get-WizardVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RuntimeRoot)

    $RuntimeRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RuntimeRoot)
    $result = [ordered]@{
        product = 'power-platform-vscode-starter'
        installedRelease = $null
        releaseDisplay = 'release unknown - development checkout'
        sourceRevision = $null
        contractVersion = 'unknown'
        profileVersion = 'unknown'
        updateState = 'offline-unknown'
        message = 'No network check; official publisher policy unavailable.'
        diagnostics = @()
    }
    $profilePath = Join-Path $RuntimeRoot 'wizard.profile.json'
    if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
        try {
            $profile = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
            if ($profile.ContainsKey('contractVersion')) { $result.contractVersion = [string]$profile.contractVersion }
            if ($profile.ContainsKey('profileVersion')) { $result.profileVersion = [string]$profile.profileVersion }
        } catch {
            $result.diagnostics += "Cannot inspect profile: $($_.Exception.Message)"
        }
    } else {
        $result.diagnostics += 'Runtime profile missing; copied skill is not a runtime installation.'
    }
    $descriptor = Join-Path $RuntimeRoot 'wizard.release.json'
    if (Test-Path -LiteralPath $descriptor -PathType Leaf) {
        try {
            $data = Get-Content -LiteralPath $descriptor -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
            if ($data.schemaVersion -ne '1.0' -or $data.product -ne $result.product) {
                throw 'Unsupported distribution descriptor.'
            }
            if ($null -ne $data.releaseVersion) {
                $result.updateState = 'unverified'
                $result.message = 'Descriptor claims a release but independent installed provenance is unavailable.'
            }
        } catch {
            $result.updateState = 'unverified'
            $result.diagnostics += "Cannot verify descriptor: $($_.Exception.Message)"
        }
    }
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitRoot = & git -C $RuntimeRoot rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and [IO.Path]::GetFullPath($gitRoot) -eq [IO.Path]::GetFullPath($RuntimeRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)) {
            $revision = & git -C $RuntimeRoot rev-parse --verify HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and $revision -match '^[0-9a-f]{40}$') { $result.sourceRevision = [string]$revision }
        }
    }
    [pscustomobject]$result
}

function Show-WizardVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RuntimeRoot)
    $version = Get-WizardVersion -RuntimeRoot $RuntimeRoot
    Write-Host "Installed wizard: $($version.releaseDisplay)"
    Write-Host "Source: $($version.sourceRevision) | Contract: $($version.contractVersion) | Profile: $($version.profileVersion)"
    Write-Host "Update check: $($version.updateState) - $($version.message)"
    Write-Host 'Choices: Review changes | Update wizard | Skip for now (continue unchanged)'
    foreach ($diagnostic in $version.diagnostics) { Write-Warning $diagnostic }
}
