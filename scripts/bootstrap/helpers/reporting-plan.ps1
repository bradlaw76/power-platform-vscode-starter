<#
=============================================================================
COMPONENT:    Scenario Reporting Planning
FILE:         scripts/bootstrap/helpers/reporting-plan.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-23
ENVIRONMENT:  PowerShell 7 | Local scenario planning
OVERVIEW:     Resolves independent reporting choices and validates documented
              HTML report definitions before generation.
INPUTS:       Scenario answers, spec, plan, mappings, and html-reports.json
OUTPUTS:      Validated selection and report definitions; no Dataverse writes
TEST CASES:   Explicit opt-out blocks native payloads; HTML requires approved,
              schema-valid definitions with matching documentary evidence.
=============================================================================
#>

function Get-WizardReportingSelection {
    param([Parameter(Mandatory)][string]$ScenarioFolder)

    $answersPath = Join-Path $ScenarioFolder 'answers.md'
    $content = if (Test-Path -LiteralPath $answersPath) { Get-Content -LiteralPath $answersPath -Raw } else { '' }
    $sections = [regex]::Matches($content, '(?ms)^## Reporting Selection\s*\r?\n(.*?)(?=^## |\z)')
    if ($sections.Count -gt 1) { throw "Duplicate Reporting Selection sections in $answersPath." }
    $section = [regex]::Match($content, '(?ms)^## Reporting Selection\s*\r?\n(.*?)(?=^## |\z)')
    $native = $null
    $html = $false
    if ($section.Success) {
        foreach ($label in @('Native dashboards', 'HTML reports')) {
            $values = [regex]::Matches($section.Groups[1].Value, "(?im)^- $([regex]::Escape($label)):\s*(yes|no)\s*$")
            if ($values.Count -ne 1) { throw "Reporting Selection must contain exactly one '${label}: yes/no' decision in $answersPath." }
            if ($label -eq 'Native dashboards') { $native = $values[0].Groups[1].Value -ieq 'yes' }
            else { $html = $values[0].Groups[1].Value -ieq 'yes' }
        }
    } else {
        $legacy = [regex]::Match($content, '(?ms)^## Optional Report Web Resources\s*\r?\n(.*?)(?=^## |\z)')
        $html = $legacy.Success -and $legacy.Groups[1].Value -match '(?im)^- Enabled:\s*(yes|true|1)\s*$'
    }
    if ($section.Success) {
        foreach ($name in @('spec.md', 'plan.md', 'report-mappings.md')) {
            $documentPath = Join-Path $ScenarioFolder $name
            if (-not (Test-Path -LiteralPath $documentPath)) { continue }
            $document = Get-Content -LiteralPath $documentPath -Raw
            $documentSection = [regex]::Match($document, '(?ms)^## Reporting Selection\s*\r?\n(.*?)(?=^## |\z)')
            if ($documentSection.Success) {
                foreach ($decision in @(@{ Label = 'Native dashboards'; Enabled = $native }, @{ Label = 'HTML reports'; Enabled = $html })) {
                    $expected = if ($decision.Enabled) { 'yes' } else { 'no' }
                    if ($documentSection.Groups[1].Value -notmatch "(?im)^- $([regex]::Escape($decision.Label)):\s*$expected\s*$") {
                        throw "Reporting Selection in $name conflicts with answers.md. Align the approved planning artifacts."
                    }
                }
            }
        }
    }
    return [pscustomobject]@{ Explicit = $section.Success; NativeEnabled = $native; HtmlEnabled = $html }
}

function Assert-WizardNativeReportingChoice {
    param([string]$ScenarioFolder, [bool]$HasPayload)

    $selection = Get-WizardReportingSelection -ScenarioFolder $ScenarioFolder
    if ($selection.Explicit -and -not $selection.NativeEnabled -and $HasPayload) {
        throw 'Native dashboards were declined. Remove the unapproved reporting-*.json payload or review and approve a changed Reporting Selection before building.'
    }
    return $selection
}

function Read-WizardHtmlReportPlan {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ScenarioFolder,
        [string[]]$AllowedTables = @()
    )

    $path = Join-Path $ScenarioFolder 'html-reports.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "HTML reporting requires reviewed html-reports.json based on spec.md, plan.md, and report-mappings.md. Missing: $path"
    }
    $json = Get-Content -LiteralPath $path -Raw
    $schemaPath = Join-Path $RepoRoot 'schemas\payloads\html-reports.schema.json'
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "Invalid HTML report definition: $path"
    }
    $plan = $json | ConvertFrom-Json -Depth 30
    if (-not $plan.Approved) { throw "HTML report definitions require explicit review and approval: $path" }
    if ($AllowedTables.Count -eq 0) {
        $specPath = Join-Path $ScenarioFolder 'spec.md'
        if (-not (Test-Path -LiteralPath $specPath)) { throw "Missing scenario spec: $specPath" }
        $spec = Get-Content -LiteralPath $specPath -Raw
        $AllowedTables = @([regex]::Matches($spec, '(?m)^-\s+.+\s+->\s+([a-z][a-z0-9_]*)\s*$') | ForEach-Object { $_.Groups[1].Value })
    }
    $mappingPath = Join-Path $ScenarioFolder 'report-mappings.md'
    if (-not (Test-Path -LiteralPath $mappingPath -PathType Leaf)) { throw "Missing approved report mappings: $mappingPath" }
    $mappings = Get-Content -LiteralPath $mappingPath -Raw
    if ($mappings -match '(?im)^- Status:\s*pending-review\s*$') { throw "Report mappings are pending review: $mappingPath" }

    $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($report in $plan.Reports) {
        if (-not $keys.Add($report.Key)) { throw "Duplicate HTML report key '$($report.Key)'." }
        if ($AllowedTables -notcontains $report.TableLogicalName) { throw "Report '$($report.Key)' uses table '$($report.TableLogicalName)' outside the scenario's documented entity mapping." }
        $matchingRows = @($mappings -split '\r?\n' | Where-Object {
            $cells = @($_.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim().Trim('`') })
            $cells.Count -eq 8 -and $cells[0] -eq $report.TableLogicalName -and $cells[1] -eq $report.Title -and $cells[3] -eq $report.Placement
        })
        if ($matchingRows.Count -ne 1) { throw "Report '$($report.Key)' needs exactly one matching table/title/placement row in report-mappings.md." }
        $mappedFields = @($matchingRows[0].Trim().Trim('|') -split '\|')[4]
        foreach ($reference in $report.Requirements) {
            $documentPath = Join-Path $ScenarioFolder $reference.Document
            if (-not (Test-Path -LiteralPath $documentPath -PathType Leaf)) { throw "Missing report requirement source: $documentPath" }
            $document = Get-Content -LiteralPath $documentPath -Raw
            if (-not $document.Contains($reference.Excerpt)) { throw "Report '$($report.Key)' requirement excerpt does not match $($reference.Document). Review the report against the current scenario documentation." }
        }
        $metricKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($metric in $report.Metrics) {
            if (-not $metricKeys.Add($metric.Key)) { throw "Duplicate metric key '$($metric.Key)' in '$($report.Key)'." }
            $fields = @($metric.RequiredFields)
            $validShape = switch ($metric.Kind) {
                'aggregate-count' { $fields.Count -eq 1 -and $fields[0] -eq '__primaryid__' }
                'aggregate-group' { $fields.Count -eq 2 -and $fields[0] -eq '__primaryid__' -and $fields[1] -notlike '__*' }
                'list' { $fields.Count -eq 2 -and $fields[0] -eq '__primaryname__' -and $fields[1] -in @('createdon', 'modifiedon') }
            }
            if (-not $validShape) { throw "Unsupported field shape for metric '$($metric.Key)' in '$($report.Key)'." }
            foreach ($field in $fields | Where-Object { $_ -notlike '__*' }) {
                if (@($mappedFields -split ',' | ForEach-Object { $_.Trim().Trim('`') }) -notcontains $field) {
                    throw "Metric '$($metric.Key)' field '$field' is missing from the approved report mapping."
                }
            }
        }
    }
    return $plan
}
