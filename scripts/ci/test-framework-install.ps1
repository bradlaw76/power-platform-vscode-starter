Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$installer = Join-Path $repoRoot 'scripts/bootstrap/install-framework.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "wizard-install-test-$([guid]::NewGuid().ToString('N'))"
$packageRoot = Join-Path $testRoot 'package'
$commit = '0123456789abcdef0123456789abcdef01234567'
$expectedDestination = if ($IsWindows) {
    Join-Path (Join-Path $env:ProgramFiles 'Power Platform Wizard') $commit
} elseif ($IsMacOS) {
    Join-Path '/Library/Application Support/Power Platform Wizard' $commit
} else {
    Join-Path '/opt/power-platform-vscode-starter' $commit
}

try {
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $packageRoot 'runtime.txt') -Value 'verified fixture'
    @{
        repositoryUrl = 'https://github.com/bradlaw76/power-platform-vscode-starter'
        version = 'test'
        commit = $commit
        readOnlyDistribution = $true
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packageRoot 'wizard-framework-install.json') -Encoding utf8

    $package = Join-Path $testRoot 'framework.zip'
    Get-ChildItem -LiteralPath $packageRoot -Force | Compress-Archive -DestinationPath $package
    $digest = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash

    $output = @(& pwsh -NoProfile -NonInteractive -File $installer `
        -PackagePath $package -ExpectedSha256 $digest -ExpectedCommit $commit `
        -DestinationRoot $expectedDestination -WhatIf 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Verified package preflight failed: $($output -join "`n")" }
    if (Test-Path -LiteralPath $expectedDestination) { throw 'WhatIf created an installation directory.' }

    $badHashOutput = @(& pwsh -NoProfile -NonInteractive -File $installer `
        -PackagePath $package -ExpectedSha256 ('0' * 64) -ExpectedCommit $commit `
        -DestinationRoot $expectedDestination -WhatIf 2>&1)
    if ($LASTEXITCODE -eq 0 -or ($badHashOutput -join "`n") -notmatch 'checksum mismatch') {
        throw 'Installer did not reject an invalid package checksum.'
    }

    Write-Host 'Framework distribution installer tests passed.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
