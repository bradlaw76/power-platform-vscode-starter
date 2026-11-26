<#
Component: Framework Repository Ownership Check
Purpose: Contain historical application artifacts and reject new FOIA development.
Owner: Power Platform VS Code Starter
Version: 1.0.0
#>
[CmdletBinding()]
param(
    [string]$RemoteName = 'origin',
    [string]$RemoteUrl = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$baselineFile = Join-Path $root '.github\policies\framework-ownership-baseline.json'
$baseline = Get-Content -LiteralPath $baselineFile -Raw | ConvertFrom-Json
if ($RemoteName -cne 'origin') { throw 'Framework publication must use the reviewed origin.' }
if ($RemoteUrl -and $RemoteUrl -notmatch '^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)bradlaw76/power-platform-vscode-starter(?:\.git)?/?$') {
    throw 'Framework ownership check rejected the actual push destination.'
}
if ($baseline.SourceCommit -cne '4c9d2bfac675812a8fbe100b94c05ebe4c4bed1e' -or
    @($baseline.Files).Count -ne 71) {
    throw 'Framework ownership baseline must preserve the reviewed 71-file historical boundary.'
}
foreach ($arguments in @(@('remote', 'get-url', '--all', 'origin'), @('remote', 'get-url', '--push', '--all', 'origin'))) {
    $urls = @(& git -C $root @arguments)
    if ($LASTEXITCODE -ne 0 -or $urls.Count -eq 0) { throw 'Framework origin could not be verified.' }
    foreach ($url in $urls) {
        if ($url -notmatch '^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)bradlaw76/power-platform-vscode-starter(?:\.git)?/?$') {
            throw 'Framework ownership check rejected a non-framework origin URL.'
        }
    }
}

function Test-ApplicationPath {
    param([string]$Path)
    return $Path -match '(?i)(^|[/_. -])(?:federal[-_ ]?)?foia'
}

foreach ($path in @('payloads/scenarios/federal-foia-new/table-foia_request.json', 'src/foia/request.ts', 'solutions/FederalFOIAManagement/solution.xml', 'scripts/ci/test-foia-new.ps1')) {
    if (-not (Test-ApplicationPath $path)) { throw "Ownership detector missed an application path: $path" }
}
foreach ($path in @('scripts/bootstrap/helpers/dataverse.ps1', 'specs/contoso-case-tracker/spec.md', 'docs/repository-ownership.md')) {
    if (Test-ApplicationPath $path) { throw "Ownership detector rejected a reusable path: $path" }
}

$allowed = @{}
foreach ($file in $baseline.Files) {
    if ($allowed.ContainsKey($file.Path)) { throw 'Duplicate framework ownership baseline path.' }
    $allowed[$file.Path] = $file.Blob
    $path = Join-Path $root $file.Path.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Historical FOIA file removed without cleanup review: $($file.Path)" }
    $hash = & git -C $root hash-object -- $path
    if ($LASTEXITCODE -ne 0 -or $hash -cne $file.Blob) {
        throw "Historical FOIA file changed; application development belongs in bradlaw76/FOIA: $($file.Path)"
    }
}
$paths = @(& git -C $root -c core.quotepath=false ls-files --cached --others --exclude-standard)
if ($LASTEXITCODE -ne 0) { throw 'Framework file inventory could not be read.' }
foreach ($path in $paths) {
    if ($allowed.ContainsKey($path)) { continue }
    if (Test-ApplicationPath $path) { throw "New FOIA-specific path is not allowed in the framework: $path" }
    if ($path -match '^(?:payloads|solutions|src|apps)/' -and $path -match '\.(?:json|xml|ya?ml|tsx?|jsx?|cs|bicep|tf|ps1)$') {
        $text = Get-Content -LiteralPath (Join-Path $root $path.Replace('/', '\')) -Raw
        if ($text -match '(?i)\bfoia_|FederalFOIAManagement|federal-foia-management') {
            throw "FOIA application definition is outside the frozen historical baseline: $path"
        }
    }
}
Write-Output 'Framework ownership passed: exact framework origin, 71 unchanged historical FOIA files, no new FOIA application paths/definitions.'
