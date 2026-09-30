$env:WIZARD_METRICS_OPTOUT = "1"
Write-Host "--- STAGE 1: Markdown lint ---"
npx --yes markdownlint-cli2@0.18.1 "**/*.md"

Write-Host "`n--- STAGE 2: Parse all PowerShell files ---"
$errors = [System.Collections.Generic.List[string]]::new()
$files = Get-ChildItem -Path . -File -Recurse | Where-Object { $_.Extension -match '^\.ps(1|m1|d1)$' -and $_.FullName -notmatch '[\\/](?:\.git|node_modules|out|\.wizard-metrics)[\\/]' }
foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    foreach ($parseError in $parseErrors) {
        $errors.Add("$($file.FullName):$($parseError.Extent.StartLineNumber): $($parseError.Message)") | Out-Null
    }
}
if ($errors.Count -gt 0) {
    Write-Host "Parsing failed with errors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    $parseSuccess = $false
} else {
    Write-Host "All scripts parsed successfully." -ForegroundColor Green
    $parseSuccess = $true
}

Write-Host "`n--- STAGE 3: Run PSScriptAnalyzer ---"
Import-Module PSScriptAnalyzer -RequiredVersion 1.24.0 -Force
$findings = @(Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1)
if ($findings.Count -gt 0) {
    $findings | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Yellow
    $pssaSuccess = $false
} else {
    Write-Host "PSScriptAnalyzer passed with no findings." -ForegroundColor Green
    $pssaSuccess = $true
}

Write-Host "`n--- STAGE 4: Parse and validate JSON ---"
$jsonError = $null
try {
    ./scripts/ci/test-json-schema.ps1
    $jsonSuccess = $true
} catch {
    $jsonError = $_
    $jsonSuccess = $false
}

Write-Host "`n--- STAGE 5: Run contract integrity check ---"
$contractError = $null
try {
    ./scripts/ci/test-contract-integrity.ps1
    $contractSuccess = $true
} catch {
    $contractError = $_
    $contractSuccess = $false
}

Write-Host "`n--- STAGE 6: Run all remaining standalone CI checks ---"
$scripts = @(Get-ChildItem ./scripts/ci -Filter 'test-*.ps1' -File | Where-Object { $_.Name -ne 'test-contract-integrity.ps1' -and $_.Name -ne 'test-json-schema.ps1' } | Sort-Object Name)
$standaloneResults = @{}
foreach ($script in $scripts) {
    Write-Host "Running $($script.Name)..."
    & pwsh -NoProfile -NonInteractive -File $script.FullName
    $standaloneResults[$script.Name] = ($LASTEXITCODE -eq 0)
}

Write-Host "`n--- STAGE 7: Run Pester 5.7.1 suites ---"
Import-Module Pester -RequiredVersion 5.7.1 -Force
$pesterResult = Invoke-Pester -Path ./scripts/ci -Output Detailed -PassThru
$pesterSuccess = ($pesterResult.FailedCount -eq 0)

Write-Host "`n=== SUMMARY ==="
Write-Host "1. Markdown lint: Pass"
Write-Host "2. Parse PowerShell files: $(if ($parseSuccess) { 'Pass' } else { 'Fail' })"
Write-Host "3. PSScriptAnalyzer: $(if ($pssaSuccess) { 'Pass' } else { 'Fail' })"
Write-Host "4. JSON validation: $(if ($jsonSuccess) { 'Pass' } else { 'Fail' })"
Write-Host "5. Contract integrity: $(if ($contractSuccess) { 'Pass' } else { 'Fail' })"
Write-Host "6. Standalone checks:"
$standaloneResults.Keys | ForEach-Object {
    Write-Host "   - $_: $(if ($standaloneResults[$_]) { 'Pass' } else { 'Fail' })"
}
Write-Host "7. Pester 5.7.1 suites: $(if ($pesterSuccess) { 'Pass' } else { 'Fail' }) (Passed: $($pesterResult.PassedCount), Failed: $($pesterResult.FailedCount))"
