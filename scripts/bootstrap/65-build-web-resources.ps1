<#
.SYNOPSIS
    Generates optional scenario-driven HTML report web resources and adds them
    to the selected Dataverse solution.

.DESCRIPTION
    Reads scenario design artifacts from specs/<scenario-slug>/ and, when the
    wizard answer enables reports, builds three Dynamics-blue HTML reports:
      - Agent performance report
      - Supervisor oversight report
      - Executive summary KPI report

    The script writes local HTML files under specs/<scenario-slug>/webresources/
    and upserts Dataverse web resources (HTML type) with idempotent behavior.
    Each created/updated web resource is added to the target solution.

.PARAMETER ScenarioSlug
    Scenario folder under specs/. If omitted and there is exactly one scenario,
    that scenario is used automatically.

.PARAMETER EnvironmentUrl
    Dataverse environment URL. Defaults to $env:DV_ENVIRONMENT_URL.

.PARAMETER AccessToken
    Dataverse bearer token. Defaults to $env:DV_TOKEN.

.PARAMETER SolutionUniqueName
    Target solution unique name. Defaults to $env:DV_SOLUTION_NAME.

.PARAMETER PublisherPrefix
    Publisher prefix used for web resource naming. Defaults to $env:DV_PUBLISHER_PREFIX.

.EXAMPLE
    pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug contoso-case-tracker
#>

param(
    [string]$ScenarioSlug = "",
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-RequiredValue {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    while ($true) {
        $value = if ([string]::IsNullOrWhiteSpace($Default)) {
            Read-Host $Prompt
        }
        else {
            Read-Host "$Prompt [$Default]"
        }

        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = $Default
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        Write-Host "A value is required." -ForegroundColor Yellow
    }
}

function Get-MarkdownSectionValue {
    param(
        [string]$Content,
        [string]$Heading
    )

    $pattern = "(?ms)^##\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim()
}

function Get-ListValue {
    param(
        [string]$Block,
        [string]$Label
    )

    $pattern = "(?m)^-\s+$([regex]::Escape($Label)):\s*(.+)$"
    $match = [regex]::Match($Block, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim()
}

function Split-Items {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return @($Value -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function ConvertTo-HtmlSafeText {
    param([string]$Value)

    if ($null -eq $Value) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

function ConvertTo-ODataSafeString {
    param([string]$Value)

    if ($null -eq $Value) { return "" }
    return $Value.Replace("'", "''")
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = "",
        [string]$Prefer = ""
    )

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
        "OData-Version" = "4.0"
        "OData-MaxVersion" = "4.0"
        "Accept" = "application/json"
    }

    if (-not [string]::IsNullOrWhiteSpace($Prefer)) {
        $headers["Prefer"] = $Prefer
    }

    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body
    }

    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

function Get-WebResourceComponentType {
    try {
        $meta = Invoke-Dv "Get" "EntityDefinitions(LogicalName='solutioncomponent')/Attributes(LogicalName='componenttype')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName&`$expand=OptionSet"
        foreach ($opt in @($meta.OptionSet.Options)) {
            $label = $opt.Label.UserLocalizedLabel.Label
            if ($label -eq "Web Resource" -or $label -eq "WebResource") {
                return [int]$opt.Value
            }
        }
    } catch {
        Write-Host "Warning: unable to resolve Web Resource component type dynamically. Using fallback 61." -ForegroundColor Yellow
    }

    return 61
}

function New-IconSvg {
    param([string]$Kind)

    switch ($Kind) {
        "agent" {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="8" r="4" fill="currentColor"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
        }
        "supervisor" {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="14" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M7 14l3-3 2 2 4-4" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
        }
        default {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20V10" stroke="currentColor" stroke-width="2"/><path d="M10 20V6" stroke="currentColor" stroke-width="2"/><path d="M16 20V13" stroke="currentColor" stroke-width="2"/><path d="M22 20V4" stroke="currentColor" stroke-width="2"/></svg>'
        }
    }
}

function New-ReportHtml {
    param(
        [string]$ScenarioName,
        [string]$ReportTitle,
        [string]$Subtitle,
        [string]$ProblemStatement,
        [string]$SuccessCriteria,
        [string[]]$Entities,
        [string[]]$Artifacts,
        [string]$IconKind
    )

    $safeScenario = ConvertTo-HtmlSafeText $ScenarioName
    $safeTitle = ConvertTo-HtmlSafeText $ReportTitle
    $safeSubtitle = ConvertTo-HtmlSafeText $Subtitle
    $safeProblem = ConvertTo-HtmlSafeText $ProblemStatement
    $safeSuccess = ConvertTo-HtmlSafeText $SuccessCriteria

    $entityChips = if ($Entities.Count -gt 0) {
        ($Entities | ForEach-Object { '<span class="chip">' + (ConvertTo-HtmlSafeText $_) + '</span>' }) -join "`n"
    } else {
        '<span class="chip">No entities listed</span>'
    }

    $artifactChips = if ($Artifacts.Count -gt 0) {
        ($Artifacts | ForEach-Object { '<span class="chip">' + (ConvertTo-HtmlSafeText $_) + '</span>' }) -join "`n"
    } else {
        '<span class="chip">No artifacts listed</span>'
    }

    $generated = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm 'UTC'")
    $iconSvg = New-IconSvg -Kind $IconKind

    return @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>$safeTitle</title>
  <style>
    :root {
      --dyn-primary: #0078d4;
      --dyn-primary-strong: #005a9e;
      --dyn-accent: #50e6ff;
      --dyn-bg: #f3f9fd;
      --dyn-surface: #ffffff;
      --dyn-border: #d0e6f8;
      --dyn-text: #1f2937;
      --dyn-muted: #5f6b7a;
      --dyn-good: #0f766e;
      --dyn-warning: #b45309;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Segoe UI", "Segoe UI Variable", Tahoma, sans-serif;
      color: var(--dyn-text);
      background:
        radial-gradient(circle at 80% -10%, rgba(80,230,255,.24), transparent 45%),
        radial-gradient(circle at -20% 120%, rgba(0,120,212,.14), transparent 38%),
        var(--dyn-bg);
    }
    .page {
      max-width: 1200px;
      margin: 0 auto;
      padding: 28px;
      display: grid;
      gap: 16px;
    }
    .hero {
      background: linear-gradient(130deg, var(--dyn-primary-strong), var(--dyn-primary));
      color: white;
      border-radius: 16px;
      padding: 18px 20px;
      box-shadow: 0 12px 28px rgba(0,90,158,.25);
      display: grid;
      gap: 8px;
    }
    .hero h1 { margin: 0; font-size: 28px; letter-spacing: .2px; }
    .hero p { margin: 0; opacity: .95; }
    .meta { display: flex; gap: 12px; flex-wrap: wrap; font-size: 13px; opacity: .92; }
    .grid {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 12px;
    }
    .card {
      background: var(--dyn-surface);
      border: 1px solid var(--dyn-border);
      border-radius: 14px;
      padding: 14px;
      box-shadow: 0 6px 16px rgba(0,120,212,.08);
    }
    .card h2 {
      margin: 0 0 8px;
      font-size: 15px;
      color: var(--dyn-primary-strong);
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .icon {
      width: 18px;
      height: 18px;
      display: inline-flex;
      color: var(--dyn-primary);
    }
    .kpi {
      font-size: 30px;
      font-weight: 700;
      color: var(--dyn-primary-strong);
      line-height: 1;
      margin: 8px 0 4px;
    }
    .kpi-sub { color: var(--dyn-muted); font-size: 12px; }
    .chips { display: flex; gap: 8px; flex-wrap: wrap; }
    .chip {
      border: 1px solid var(--dyn-border);
      background: #eef7ff;
      border-radius: 999px;
      padding: 4px 10px;
      font-size: 12px;
      color: var(--dyn-primary-strong);
    }
    .status-row {
      margin-top: 10px;
      display: flex;
      justify-content: space-between;
      gap: 8px;
      font-size: 13px;
      color: var(--dyn-muted);
    }
    .status-good { color: var(--dyn-good); font-weight: 600; }
    .status-warn { color: var(--dyn-warning); font-weight: 600; }
    @media (max-width: 960px) {
      .grid { grid-template-columns: 1fr; }
      .hero h1 { font-size: 24px; }
    }
  </style>
</head>
<body>
  <main class="page">
    <section class="hero">
      <h1>$safeTitle</h1>
      <p>$safeSubtitle</p>
      <div class="meta">
        <span>Scenario: $safeScenario</span>
        <span>Generated: $generated</span>
      </div>
    </section>

    <section class="grid">
      <article class="card">
        <h2><span class="icon">$iconSvg</span>Business Focus</h2>
        <div class="kpi">$safeScenario</div>
        <div class="kpi-sub">Design-aligned summary</div>
        <p>$safeProblem</p>
      </article>

      <article class="card">
        <h2><span class="icon">$iconSvg</span>Success Signal</h2>
        <div class="kpi">KPI</div>
        <p>$safeSuccess</p>
        <div class="status-row">
          <span>Assessment</span>
          <span class="status-good">On Track</span>
        </div>
      </article>

      <article class="card">
        <h2><span class="icon">$iconSvg</span>Execution Health</h2>
        <div class="kpi">Ready</div>
        <div class="kpi-sub">Based on scenario design completion</div>
        <div class="status-row">
          <span>Risk</span>
          <span class="status-warn">Monitor Dependencies</span>
        </div>
      </article>
    </section>

    <section class="card">
      <h2><span class="icon">$iconSvg</span>Data Elements</h2>
      <div class="chips">
$entityChips
      </div>
    </section>

    <section class="card">
      <h2><span class="icon">$iconSvg</span>Experience Artifacts</h2>
      <div class="chips">
$artifactChips
      </div>
    </section>
  </main>
</body>
</html>
"@
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$specsRoot = Join-Path $repoRoot "specs"

$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "65-build-web-resources.ps1"
}

$envFile = Join-Path $repoRoot ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    $AccessToken = $global:DV_TOKEN
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { $SolutionUniqueName = $global:DV_SOLUTION_NAME }
    if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) { $PublisherPrefix = $global:DV_PUBLISHER_PREFIX }
}

foreach ($v in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName, $PublisherPrefix)) {
    if ([string]::IsNullOrWhiteSpace($v)) {
        Write-Host "Missing required values. Run 10-auth-connect.ps1 first." -ForegroundColor Red
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    $scenarioFolders = @(Get-ChildItem -Path $specsRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($scenarioFolders.Count -eq 1) {
        $ScenarioSlug = $scenarioFolders[0].Name
    } elseif ($scenarioFolders.Count -gt 1) {
        Write-Host "Available scenarios:" -ForegroundColor Cyan
        $scenarioFolders | ForEach-Object { Write-Host "  - $($_.Name)" }
        $ScenarioSlug = Read-RequiredValue "Scenario folder slug"
    } else {
        throw "No scenario folders found under '$specsRoot'."
    }
}

$scenarioFolder = Join-Path $specsRoot $ScenarioSlug
$answersPath = Join-Path $scenarioFolder "answers.md"
$specPath = Join-Path $scenarioFolder "spec.md"
$outputFolder = Join-Path $scenarioFolder "webresources"

if (-not (Test-Path $answersPath)) { throw "Missing scenario answers file: $answersPath" }
if (-not (Test-Path $specPath)) { throw "Missing scenario spec file: $specPath" }

$answersContent = Get-Content -Path $answersPath -Raw -Encoding UTF8
$specContent = Get-Content -Path $specPath -Raw -Encoding UTF8

$scenarioBlock = Get-MarkdownSectionValue -Content $answersContent -Heading "Scenario"
$wizardBlock = Get-MarkdownSectionValue -Content $answersContent -Heading "Wizard Answers"

$scenarioName = Get-ListValue -Block $scenarioBlock -Label "Name"
if ([string]::IsNullOrWhiteSpace($scenarioName)) { $scenarioName = $ScenarioSlug }

$problemStatement = Get-MarkdownSectionValue -Content $specContent -Heading "Problem Statement"
$requiredEntitiesText = Get-MarkdownSectionValue -Content $specContent -Heading "Required Data Entities"
$artifactsText = Get-MarkdownSectionValue -Content $specContent -Heading "Required Experience and Artifacts"
$successCriteria = Get-MarkdownSectionValue -Content $specContent -Heading "Success Criteria"

$includeReports = [regex]::Match($wizardBlock, '(?im)^19\.\s*Create optional HTML report web resources.*:\s*(.+)$').Groups[1].Value.Trim().ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($includeReports)) {
    $optionalBlock = Get-MarkdownSectionValue -Content $answersContent -Heading "Optional Report Web Resources"
    $includeReports = (Get-ListValue -Block $optionalBlock -Label "Enabled").Trim().ToLowerInvariant()
}

if ($includeReports -ne "yes" -and $includeReports -ne "y" -and $includeReports -ne "true") {
    Write-Host ""
    Write-Host "=== Build Report Web Resources ===" -ForegroundColor Cyan
    Write-Host "Scenario '$ScenarioSlug' has optional reports disabled. Nothing to generate." -ForegroundColor Yellow
    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message "Optional report web resources disabled for scenario."
    }
    exit 0
}

$entities = Split-Items -Value $requiredEntitiesText
$artifacts = Split-Items -Value $artifactsText

$reportDefinitions = @(
    [pscustomobject]@{
        Key = "agent"
        Title = "$scenarioName - Agent Performance Report"
        Subtitle = "Frontline activity, priorities, and execution confidence for day-to-day operations."
        IconKind = "agent"
    },
    [pscustomobject]@{
        Key = "supervisor"
        Title = "$scenarioName - Supervisor Oversight Report"
        Subtitle = "Team-level performance, bottlenecks, and escalation visibility for operational leadership."
        IconKind = "supervisor"
    },
    [pscustomobject]@{
        Key = "executive-kpi"
        Title = "$scenarioName - Executive Summary KPI Report"
        Subtitle = "Outcome-focused KPI view for leadership decision support and investment tracking."
        IconKind = "executive"
    }
)

Write-Host ""
Write-Host "=== Build Report Web Resources ===" -ForegroundColor Cyan
Write-Host "  Scenario:   $ScenarioSlug"
Write-Host "  Environment:$EnvironmentUrl"
Write-Host "  Solution:   $SolutionUniqueName"
Write-Host ""

if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

$webResourceComponentType = Get-WebResourceComponentType

$sol = (Invoke-Dv "Get" "solutions?`$filter=uniquename eq '$SolutionUniqueName'&`$select=solutionid,uniquename").value | Select-Object -First 1
if ($null -eq $sol) {
    throw "Solution '$SolutionUniqueName' was not found in this environment."
}

$created = 0
$updated = 0
$addedToSolution = 0
$skippedSolution = 0
$failed = 0

foreach ($report in $reportDefinitions) {
    try {
        $html = New-ReportHtml -ScenarioName $scenarioName -ReportTitle $report.Title -Subtitle $report.Subtitle -ProblemStatement $problemStatement -SuccessCriteria $successCriteria -Entities $entities -Artifacts $artifacts -IconKind $report.IconKind
        $fileName = "$ScenarioSlug-$($report.Key)-report.html"
        $filePath = Join-Path $outputFolder $fileName
        Set-Content -Path $filePath -Value $html -Encoding UTF8

        $webResourceName = "$($PublisherPrefix.ToLower())_reports/$fileName"
        $displayName = $report.Title
        $description = "Generated by 65-build-web-resources.ps1 for scenario '$ScenarioSlug'."
        $contentBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($html))

        $safeName = ConvertTo-ODataSafeString $webResourceName
        $existing = (Invoke-Dv "Get" "webresourceset?`$select=webresourceid,name&`$filter=name eq '$safeName'").value | Select-Object -First 1

        $bodyObj = [ordered]@{
            name = $webResourceName
            displayname = $displayName
            description = $description
            webresourcetype = 1
            content = $contentBase64
        }
        $body = $bodyObj | ConvertTo-Json -Compress

        $webResourceId = ""
        if ($null -eq $existing) {
            Invoke-Dv "Post" "webresourceset" $body | Out-Null
            $created++
            $existingNow = (Invoke-Dv "Get" "webresourceset?`$select=webresourceid,name&`$filter=name eq '$safeName'").value | Select-Object -First 1
            $webResourceId = $existingNow.webresourceid
            Write-Host "  $webResourceName (created)" -ForegroundColor Green
        } else {
            $webResourceId = $existing.webresourceid
            Invoke-Dv "Patch" "webresourceset($webResourceId)" $body | Out-Null
            $updated++
            Write-Host "  $webResourceName (updated)" -ForegroundColor DarkGray
        }

        if (-not [string]::IsNullOrWhiteSpace($webResourceId)) {
            try {
                $addBody = @{ ComponentId = $webResourceId; ComponentType = $webResourceComponentType; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $true } | ConvertTo-Json -Compress
                Invoke-Dv "Post" "AddSolutionComponent" $addBody | Out-Null
                $addedToSolution++
            } catch {
                if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
                    $skippedSolution++
                } else {
                    throw
                }
            }
        }
    } catch {
        $failed++
        Write-Host "  $($report.Key) (FAILED: $($_.Exception.Message))" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Reports generated — created: $created  updated: $updated  failed: $failed"
Write-Host "Solution components — added: $addedToSolution  skipped: $skippedSolution"
Write-Host "Output folder: $outputFolder"

if ($failed -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Web resource build failed for one or more reports."
    }
    exit 1
}
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Web resource build completed."
}
exit 0
