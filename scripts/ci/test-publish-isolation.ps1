Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$bootstrapRoot = Join-Path $repoRoot 'scripts/bootstrap'
$violations = Get-ChildItem -LiteralPath $bootstrapRoot -File -Recurse -Filter '*.ps1' |
    Select-String -SimpleMatch 'PublishAllXml'

if (@($violations).Count -gt 0) {
    $locations = @($violations | ForEach-Object { "$($_.Path):$($_.LineNumber)" }) -join ', '
    throw "Normal bootstrap code must not call PublishAllXml when scoped publication is required. Found: $locations"
}

$formsViews = Get-Content -LiteralPath (Join-Path $bootstrapRoot '60-build-forms-views.ps1') -Raw -Encoding UTF8
$appModule = Get-Content -LiteralPath (Join-Path $bootstrapRoot '62-build-app-module.ps1') -Raw -Encoding UTF8
if ($formsViews -notmatch "New-WizardEntityPublishXml[\s\S]+Path 'PublishXml'") {
    throw 'Step 60 must publish only its resolved payload entities through PublishXml.'
}
if ($appModule -notmatch "New-WizardAppModulePublishXml[\s\S]+Path 'PublishXml'") {
    throw 'Step 62 must publish only its exact app module through PublishXml.'
}

Write-Host 'Scoped publication isolation checks passed.' -ForegroundColor Green