<#
=============================================================================
COMPONENT:    Wizard Run State Persistence
FILE:         scripts/bootstrap/helpers/wizard-run-state.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-08-31
ENVIRONMENT:  PowerShell 7 | Local filesystem
=============================================================================
#>
Set-StrictMode -Version Latest

function Write-WizardAtomicJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [object]$InputObject,
        [ValidateRange(1, 100)] [int]$Depth = 20,
        [ValidateRange(1, 20)] [int]$RetryCount = 8,
        [ValidateRange(1, 2000)] [int]$InitialRetryDelayMilliseconds = 25
    )

    $directory = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($directory)) { throw "Atomic JSON path must include a parent directory: $Path" }
    [IO.Directory]::CreateDirectory($directory) | Out-Null

    $tempPath = Join-Path $directory ".$([IO.Path]::GetFileName($Path)).$([guid]::NewGuid().ToString('N')).tmp"
    $json = $InputObject | ConvertTo-Json -Depth $Depth
    $utf8NoBom = [Text.UTF8Encoding]::new($false)
    try {
        $stream = $null
        $writer = $null
        try {
            $stream = [IO.FileStream]::new($tempPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            $writer = [IO.StreamWriter]::new($stream, $utf8NoBom)
            $writer.Write($json)
            $writer.Flush()
            $stream.Flush($true)
        } finally {
            if ($null -ne $writer) { $writer.Dispose() }
            elseif ($null -ne $stream) { $stream.Dispose() }
        }

        for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
            try {
                [IO.File]::Move($tempPath, $Path, $true)
                return
            } catch {
                $fileSystemException = $_.Exception.GetBaseException()
                if ($fileSystemException -isnot [IO.IOException] -and $fileSystemException -isnot [UnauthorizedAccessException]) { throw }
                if ($attempt -eq $RetryCount) { throw $fileSystemException }
                $delay = [Math]::Min($InitialRetryDelayMilliseconds * [Math]::Pow(2, $attempt - 1), 2000)
                [Threading.Thread]::Sleep([int]$delay)
            }
        }
    } finally {
        if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
    }
}

function Read-WizardJsonFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$Path)

    $json = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    return $json | ConvertFrom-Json
}