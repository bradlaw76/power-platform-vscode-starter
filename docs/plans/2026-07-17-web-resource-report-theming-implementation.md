# Web Resource Report Theming Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the hardcoded Dynamics-blue styling in the generated report web resources with a three-tier theme (repo config file > live Dataverse app theme > hardcoded default), split shared CSS into its own web resource, give each report card its own icon, let a scenario pick which reports to build, and drive report/theme selection through real wizard questions instead of hardcoded answer values.

**Architecture:** All new logic lives in `scripts/bootstrap/65-build-web-resources.ps1` as small pure(ish) functions (`Get-DefaultThemeTokens`, `Get-ThemeConfigFileTokens`, `Get-LiveAppThemeTokens`, `Resolve-ThemeTokens`, `New-ReportCss`) plus a shared upsert helper (`Set-DataverseWebResource`) that both the new CSS web resource and the existing HTML reports call. `scripts/bootstrap/05-start-wizard.ps1` gets two new conditional prompts that replace two previously-hardcoded answer values.

**Tech Stack:** PowerShell 7+ (`pwsh`), Dataverse Web API (OData v4.0). This repo has no test framework (no Pester, no `tests/` folder) — verification throughout this plan uses `[System.Management.Automation.Language.Parser]::ParseFile` for syntax validation (catches heredoc/brace errors without needing live Dataverse credentials) plus scratch-extracted function tests for pure logic that doesn't call `Invoke-Dv`. Anything that requires a live Dataverse call (the `themes` API query, the `webresourceset` upsert) is flagged for manual verification against a real environment before merging, matching how the rest of this script already works.

---

## Reference: current file locations

- `scripts/bootstrap/65-build-web-resources.ps1` — report generator (full current content already read; line numbers below refer to the pre-change file).
- `scripts/bootstrap/05-start-wizard.ps1` — interactive wizard that writes `answers.md`/`spec.md`.
- `docs/plans/2026-07-17-web-resource-theming-design.md` — approved design this plan implements.

A reusable syntax-check snippet, used after every PowerShell edit in this plan:

```powershell
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile("scripts/bootstrap/65-build-web-resources.ps1", [ref]$null, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -gt 0) { $parseErrors | ForEach-Object { Write-Host $_ }; throw "Parse errors found" } else { Write-Host "PASS: no parse errors" }
```//adjust the path per file being checked

---

### Task 1: Default theme config file

**Files:**
- Create: `config/web-resource-theme.json`

**Step 1: Write the file**

```json
{
  "primary": "#0078d4",
  "primaryStrong": "#005a9e",
  "accent": "#50e6ff",
  "background": "#f3f9fd",
  "surface": "#ffffff",
  "border": "#d0e6f8",
  "text": "#1f2937",
  "muted": "#5f6b7a",
  "good": "#0f766e",
  "warning": "#b45309",
  "fontFamily": "'Segoe UI','Segoe UI Variable',Tahoma,sans-serif"
}
```

These are exactly today's hardcoded `--dyn-*` values, so generated output is unchanged until someone edits this file.

**Step 2: Verify it's valid JSON**

Run: `pwsh -NoProfile -Command "Get-Content config/web-resource-theme.json -Raw | ConvertFrom-Json | Out-Null; Write-Host PASS"`
Expected: `PASS`

**Step 3: Commit**

```bash
git add config/web-resource-theme.json
git commit -m "feat: add default web resource theme config"
```

---

### Task 2: Theme token resolution — file/default layers

**Files:**
- Modify: `scripts/bootstrap/65-build-web-resources.ps1:170-171` (insert after `Get-WebResourceComponentType`, before `New-IconSvg`)

**Step 1: Insert the two functions**

Insert immediately after the closing `}` of `Get-WebResourceComponentType` (currently ends at line 170) and before `function New-IconSvg`:

```powershell
function Get-DefaultThemeTokens {
    return @{
        primary       = "#0078d4"
        primaryStrong = "#005a9e"
        accent        = "#50e6ff"
        background    = "#f3f9fd"
        surface       = "#ffffff"
        border        = "#d0e6f8"
        text          = "#1f2937"
        muted         = "#5f6b7a"
        good          = "#0f766e"
        warning       = "#b45309"
        fontFamily    = "'Segoe UI','Segoe UI Variable',Tahoma,sans-serif"
    }
}

function Get-ThemeConfigFileTokens {
    param([string]$RepoRoot)

    $configPath = Join-Path $RepoRoot "config/web-resource-theme.json"
    if (-not (Test-Path $configPath)) {
        return @{}
    }

    $raw = Get-Content -Path $configPath -Raw -Encoding UTF8
    $parsed = $raw | ConvertFrom-Json -ErrorAction Stop

    $tokens = @{}
    foreach ($prop in $parsed.PSObject.Properties) {
        if (-not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
            $tokens[$prop.Name] = [string]$prop.Value
        }
    }
    return $tokens
}
```

Note: `Get-ThemeConfigFileTokens` deliberately does **not** catch a JSON parse error — a malformed `config/web-resource-theme.json` should fail the script loudly (it already runs under `$ErrorActionPreference = "Stop"`), not silently fall back.

**Step 2: Verify with a scratch extraction test**

Since the full script requires live Dataverse params and calls `exit` when they're missing, dot-sourcing the whole file isn't viable. Extract just the two new functions into a scratch file and exercise them directly:

```powershell
$src = Get-Content scripts/bootstrap/65-build-web-resources.ps1 -Raw
$funcs = [regex]::Matches($src, '(?ms)^function (Get-DefaultThemeTokens|Get-ThemeConfigFileTokens) \{.*?\n\}\r?\n')
$scratch = Join-Path ([IO.Path]::GetTempPath()) "theme-scratch.ps1"
Set-Content -Path $scratch -Value (($funcs | ForEach-Object { $_.Value }) -join "`n")
. $scratch

# default tokens present and correct
$defaults = Get-DefaultThemeTokens
if ($defaults.primary -ne "#0078d4") { throw "FAIL: default primary token wrong" }

# missing config file -> empty hashtable
$empty = Get-ThemeConfigFileTokens -RepoRoot (Join-Path ([IO.Path]::GetTempPath()) "no-such-repo-$(Get-Random)")
if ($empty.Count -ne 0) { throw "FAIL: expected empty hashtable for missing config file" }

# real repo config file -> non-empty, matches file content
$fromRepo = Get-ThemeConfigFileTokens -RepoRoot (Get-Location)
if ($fromRepo.primary -ne "#0078d4") { throw "FAIL: config file token not read correctly" }

Write-Host "PASS: theme token file/default layer tests"
Remove-Item $scratch
```

Run this via the PowerShell tool. Expected: `PASS: theme token file/default layer tests`

**Step 3: Commit**

```bash
git add scripts/bootstrap/65-build-web-resources.ps1
git commit -m "feat: add theme token file and default resolution layers"
```

---

### Task 3: Theme token resolution — live app theme layer + merge

**Files:**
- Modify: `scripts/bootstrap/65-build-web-resources.ps1` (append after the functions added in Task 2)

**Step 1: Insert the live-theme and merge functions**

```powershell
function Get-LiveAppThemeTokens {
    $columnMap = @{
        primary       = "maincolor"
        primaryStrong = "headercolor"
        accent        = "accentcolor"
        border        = "controlborder"
        good          = "processcontrolcolor"
        background    = "pageheaderbackgroundcolor"
    }

    try {
        $select = ($columnMap.Values -join ",")
        $result = Invoke-Dv "Get" "themes?`$filter=isdefaulttheme eq true&`$select=$select"
        $theme = $result.value | Select-Object -First 1
        if ($null -eq $theme) { return @{} }

        $tokens = @{}
        foreach ($tokenName in $columnMap.Keys) {
            $value = $theme.($columnMap[$tokenName])
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $tokens[$tokenName] = $value
            }
        }
        return $tokens
    } catch {
        Write-Host "Warning: unable to read live app theme. Falling back to config/default tokens. ($($_.Exception.Message))" -ForegroundColor Yellow
        return @{}
    }
}

function Resolve-ThemeTokens {
    param(
        [string]$ThemeSource,
        [string]$RepoRoot
    )

    $resolved = Get-DefaultThemeTokens
    $source = if ([string]::IsNullOrWhiteSpace($ThemeSource)) { "auto" } else { $ThemeSource.Trim().ToLowerInvariant() }

    if ($source -eq "auto" -or $source -eq "live") {
        $liveTokens = Get-LiveAppThemeTokens
        foreach ($key in $liveTokens.Keys) { $resolved[$key] = $liveTokens[$key] }
    }

    if ($source -eq "auto" -or $source -eq "config") {
        $configTokens = Get-ThemeConfigFileTokens -RepoRoot $RepoRoot
        foreach ($key in $configTokens.Keys) { $resolved[$key] = $configTokens[$key] }
    }

    return $resolved
}
```

Column mapping is per the confirmed `theme` table schema (see design doc section 2). Tokens not covered by the theme table (`surface`, `text`, `muted`, `warning`, `fontFamily`) simply never appear in `Get-LiveAppThemeTokens`'s output, so they always fall through to config/default.

Precedence check: `$resolved` starts as hardcoded defaults, live tokens overwrite matching keys, then config tokens overwrite matching keys again — so config always wins over live, live always wins over default, exactly per the approved design.

**Step 2: Verify merge precedence (source="default" and source="config" paths — these don't require a live Dataverse call)**

```powershell
$src = Get-Content scripts/bootstrap/65-build-web-resources.ps1 -Raw
$names = "Get-DefaultThemeTokens", "Get-ThemeConfigFileTokens", "Get-LiveAppThemeTokens", "Resolve-ThemeTokens"
$pattern = '(?ms)^function (' + ($names -join "|") + ') \{.*?\n\}\r?\n'
$funcs = [regex]::Matches($src, $pattern)
$scratch = Join-Path ([IO.Path]::GetTempPath()) "theme-scratch2.ps1"
Set-Content -Path $scratch -Value (($funcs | ForEach-Object { $_.Value }) -join "`n")
. $scratch

# source=default -> pure hardcoded values, no file/live lookup
$defaultOnly = Resolve-ThemeTokens -ThemeSource "default" -RepoRoot (Get-Location)
if ($defaultOnly.primary -ne "#0078d4") { throw "FAIL: default source did not return hardcoded primary" }

# source=config -> repo's config/web-resource-theme.json wins for tokens it defines
$configOnly = Resolve-ThemeTokens -ThemeSource "config" -RepoRoot (Get-Location)
if ($configOnly.primary -ne "#0078d4") { throw "FAIL: config source did not read repo config file" }

Write-Host "PASS: theme resolution precedence (default/config sources)"
Remove-Item $scratch
```

Run via the PowerShell tool. Expected: `PASS: theme resolution precedence (default/config sources)`

Note: `source="auto"` and `source="live"` paths call `Get-LiveAppThemeTokens`, which calls `Invoke-Dv` against a real Dataverse environment — not testable without live credentials. **Manually verify** these two paths against a real dev environment with a published custom theme before merging (confirm `Resolve-ThemeTokens -ThemeSource "live" -RepoRoot ...` returns colors matching what's set in Power Apps Maker → Themes).

**Step 3: Commit**

```bash
git add scripts/bootstrap/65-build-web-resources.ps1
git commit -m "feat: add live app theme lookup and token resolution precedence"
```

---

### Task 4: Shared Dataverse upsert helper (DRY refactor)

**Files:**
- Modify: `scripts/bootstrap/65-build-web-resources.ps1` (insert after the functions added in Task 3, before `New-IconSvg`)

This extracts the create-or-update-then-add-to-solution logic that's currently inlined in the report loop (original lines 515–553) into a function so both the new shared CSS web resource and the existing HTML reports can call it — avoiding a second copy of the same upsert logic.

**Step 1: Insert the helper**

```powershell
function Set-DataverseWebResource {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$Description,
        [string]$Content,
        [int]$WebResourceType,
        [int]$ComponentType,
        [string]$SolutionUniqueName
    )

    $contentBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Content))
    $safeName = ConvertTo-ODataSafeString $Name
    $existing = (Invoke-Dv "Get" "webresourceset?`$select=webresourceid,name&`$filter=name eq '$safeName'").value | Select-Object -First 1

    $bodyObj = [ordered]@{
        name = $Name
        displayname = $DisplayName
        description = $Description
        webresourcetype = $WebResourceType
        content = $contentBase64
    }
    $body = $bodyObj | ConvertTo-Json -Compress

    $webResourceId = ""
    $action = ""
    if ($null -eq $existing) {
        Invoke-Dv "Post" "webresourceset" $body | Out-Null
        $action = "created"
        $existingNow = (Invoke-Dv "Get" "webresourceset?`$select=webresourceid,name&`$filter=name eq '$safeName'").value | Select-Object -First 1
        $webResourceId = $existingNow.webresourceid
    } else {
        $webResourceId = $existing.webresourceid
        Invoke-Dv "Patch" "webresourceset($webResourceId)" $body | Out-Null
        $action = "updated"
    }

    $solutionResult = "added"
    if (-not [string]::IsNullOrWhiteSpace($webResourceId)) {
        try {
            $addBody = @{ ComponentId = $webResourceId; ComponentType = $ComponentType; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $true } | ConvertTo-Json -Compress
            Invoke-Dv "Post" "AddSolutionComponent" $addBody | Out-Null
        } catch {
            if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
                $solutionResult = "skipped"
            } else {
                throw
            }
        }
    }

    return [pscustomobject]@{
        WebResourceId = $webResourceId
        Action = $action
        SolutionResult = $solutionResult
    }
}
```

This is a byte-for-byte behavioral match of the existing inline logic (same OData calls, same duplicate-detection heuristic on the `AddSolutionComponent` error message) — just parameterized by web resource type so it can create CSS (`webresourcetype = 2`) as well as HTML (`webresourcetype = 1`).

**Step 2: Syntax check**

Run the reusable parse-check snippet from the Reference section against `scripts/bootstrap/65-build-web-resources.ps1`.
Expected: `PASS: no parse errors`

**Step 3: Commit**

```bash
git add scripts/bootstrap/65-build-web-resources.ps1
git commit -m "refactor: extract shared Dataverse web resource upsert helper"
```

---

### Task 5: Shared CSS generator, remove inline `<style>` from HTML template

**Files:**
- Modify: `scripts/bootstrap/65-build-web-resources.ps1:172-386` (the existing `New-IconSvg` / `New-ReportHtml` region)

**Step 1: Add `New-ReportCss`**

Insert before `New-IconSvg`:

```powershell
function New-ReportCss {
    param([hashtable]$Tokens)

    return @"
:root {
  --dyn-primary: $($Tokens.primary);
  --dyn-primary-strong: $($Tokens.primaryStrong);
  --dyn-accent: $($Tokens.accent);
  --dyn-bg: $($Tokens.background);
  --dyn-surface: $($Tokens.surface);
  --dyn-border: $($Tokens.border);
  --dyn-text: $($Tokens.text);
  --dyn-muted: $($Tokens.muted);
  --dyn-good: $($Tokens.good);
  --dyn-warning: $($Tokens.warning);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: $($Tokens.fontFamily);
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
"@
}
```

This is the existing `<style>` block content unchanged, except the `:root` values and `font-family` are now token-driven instead of hardcoded, and the surrounding `<style>...</style>` tags are dropped (this text becomes the whole content of `shared.css`, not an inline block).

**Step 2: Verify token substitution**

```powershell
$src = Get-Content scripts/bootstrap/65-build-web-resources.ps1 -Raw
$match = [regex]::Match($src, '(?ms)^function New-ReportCss \{.*?\n\}\r?\n')
$scratch = Join-Path ([IO.Path]::GetTempPath()) "css-scratch.ps1"
Set-Content -Path $scratch -Value $match.Value
. $scratch

$css = New-ReportCss -Tokens @{ primary = "#123456"; primaryStrong = "#abcdef"; accent = "#111111"; background = "#f0f0f0"; surface = "#fff"; border = "#ccc"; text = "#000"; muted = "#777"; good = "#0a0"; warning = "#a00"; fontFamily = "Arial" }
if ($css -notmatch [regex]::Escape("--dyn-primary: #123456;")) { throw "FAIL: primary token not substituted" }
if ($css -match "<style") { throw "FAIL: CSS text should not contain style tags" }

Write-Host "PASS: New-ReportCss token substitution"
Remove-Item $scratch
```

Expected: `PASS: New-ReportCss token substitution`

**Step 3: Commit**

```bash
git add scripts/bootstrap/65-build-web-resources.ps1
git commit -m "feat: add token-driven shared CSS generator"
```

---

### Task 6: Section-specific icons and updated HTML template

**Files:**
- Modify: `scripts/bootstrap/65-build-web-resources.ps1` (`New-IconSvg` and `New-ReportHtml`, originally lines 172-386)

**Step 1: Replace `New-IconSvg`**

Replace the existing report-role-keyed function with a section-keyed one:

```powershell
function New-IconSvg {
    param([string]$Section)

    switch ($Section) {
        "business" {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 21V10l8-6 8 6v11" fill="none" stroke="currentColor" stroke-width="2"/><path d="M9 21v-6h6v6" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
        }
        "success" {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M8 12l3 3 5-6" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
        }
        "health" {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12h4l2-6 4 12 2-6h6" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
        }
        "data" {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><ellipse cx="12" cy="5" rx="8" ry="3" fill="none" stroke="currentColor" stroke-width="2"/><path d="M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
        }
        "artifacts" {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20V10" stroke="currentColor" stroke-width="2"/><path d="M10 20V6" stroke="currentColor" stroke-width="2"/><path d="M16 20V13" stroke="currentColor" stroke-width="2"/><path d="M22 20V4" stroke="currentColor" stroke-width="2"/></svg>'
        }
        default {
            return '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/></svg>'
        }
    }
}
```

**Step 2: Replace `New-ReportHtml`**

Drop the `$IconKind` param, remove the inline `<style>` block in favor of `<link rel="stylesheet" href="shared.css" />`, and call `New-IconSvg` per-section at each card header:

```powershell
function New-ReportHtml {
    param(
        [string]$ScenarioName,
        [string]$ReportTitle,
        [string]$Subtitle,
        [string]$ProblemStatement,
        [string]$SuccessCriteria,
        [string[]]$Entities,
        [string[]]$Artifacts
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

    return @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>$safeTitle</title>
  <link rel="stylesheet" href="shared.css" />
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
        <h2><span class="icon">$(New-IconSvg -Section "business")</span>Business Focus</h2>
        <div class="kpi">$safeScenario</div>
        <div class="kpi-sub">Design-aligned summary</div>
        <p>$safeProblem</p>
      </article>

      <article class="card">
        <h2><span class="icon">$(New-IconSvg -Section "success")</span>Success Signal</h2>
        <div class="kpi">KPI</div>
        <p>$safeSuccess</p>
        <div class="status-row">
          <span>Assessment</span>
          <span class="status-good">On Track</span>
        </div>
      </article>

      <article class="card">
        <h2><span class="icon">$(New-IconSvg -Section "health")</span>Execution Health</h2>
        <div class="kpi">Ready</div>
        <div class="kpi-sub">Based on scenario design completion</div>
        <div class="status-row">
          <span>Risk</span>
          <span class="status-warn">Monitor Dependencies</span>
        </div>
      </article>
    </section>

    <section class="card">
      <h2><span class="icon">$(New-IconSvg -Section "data")</span>Data Elements</h2>
      <div class="chips">
$entityChips
      </div>
    </section>

    <section class="card">
      <h2><span class="icon">$(New-IconSvg -Section "artifacts")</span>Experience Artifacts</h2>
      <div class="chips">
$artifactChips
      </div>
    </section>
  </main>
</body>
</html>
"@
}
```

**Step 3: Verify — HTML no longer contains an inline `<style>` block and references shared.css**

```powershell
$src = Get-Content scripts/bootstrap/65-build-web-resources.ps1 -Raw
$names = "New-IconSvg", "New-ReportHtml", "ConvertTo-HtmlSafeText"
$pattern = '(?ms)^function (' + ($names -join "|") + ') \{.*?\n\}\r?\n'
$funcs = [regex]::Matches($src, $pattern)
$scratch = Join-Path ([IO.Path]::GetTempPath()) "html-scratch.ps1"
Set-Content -Path $scratch -Value (($funcs | ForEach-Object { $_.Value }) -join "`n")
. $scratch

$html = New-ReportHtml -ScenarioName "Test Co" -ReportTitle "Test Report" -Subtitle "Sub" -ProblemStatement "Problem" -SuccessCriteria "Success" -Entities @("Case") -Artifacts @("Form")
if ($html -match "<style") { throw "FAIL: inline style block should be gone" }
if ($html -notmatch [regex]::Escape('<link rel="stylesheet" href="shared.css" />')) { throw "FAIL: missing shared.css link" }
if (($html | Select-String -Pattern "<svg" -AllMatches).Matches.Count -ne 5) { throw "FAIL: expected 5 distinct icon renders (one per section)" }

Write-Host "PASS: New-ReportHtml uses shared.css and per-section icons"
Remove-Item $scratch
```

Expected: `PASS: New-ReportHtml uses shared.css and per-section icons`

**Step 4: Commit**

```bash
git add scripts/bootstrap/65-build-web-resources.ps1
git commit -m "feat: section-specific icons and shared.css link in report template"
```

---

### Task 7: Wire report selection, theme resolution, and shared CSS into the main flow

**Files:**
- Modify: `scripts/bootstrap/65-build-web-resources.ps1:388-567` (everything from `$repoRoot = ...` to end of file)

**Step 1: Replace the whole tail of the script**

Replace from `$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent` (line 388) through the final `exit 0` (line 567) with:

```powershell
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$specsRoot = Join-Path $repoRoot "specs"

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
$optionalBlock = Get-MarkdownSectionValue -Content $answersContent -Heading "Optional Report Web Resources"

$scenarioName = Get-ListValue -Block $scenarioBlock -Label "Name"
if ([string]::IsNullOrWhiteSpace($scenarioName)) { $scenarioName = $ScenarioSlug }

$problemStatement = Get-MarkdownSectionValue -Content $specContent -Heading "Problem Statement"
$requiredEntitiesText = Get-MarkdownSectionValue -Content $specContent -Heading "Required Data Entities"
$artifactsText = Get-MarkdownSectionValue -Content $specContent -Heading "Required Experience and Artifacts"
$successCriteria = Get-MarkdownSectionValue -Content $specContent -Heading "Success Criteria"

$includeReports = [regex]::Match($wizardBlock, '(?im)^19\.\s*Create optional HTML report web resources.*:\s*(.+)$').Groups[1].Value.Trim().ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($includeReports)) {
    $includeReports = (Get-ListValue -Block $optionalBlock -Label "Enabled").Trim().ToLowerInvariant()
}

if ($includeReports -ne "yes" -and $includeReports -ne "y" -and $includeReports -ne "true") {
    Write-Host ""
    Write-Host "=== Build Report Web Resources ===" -ForegroundColor Cyan
    Write-Host "Scenario '$ScenarioSlug' has optional reports disabled. Nothing to generate." -ForegroundColor Yellow
    exit 0
}

$entities = Split-Items -Value $requiredEntitiesText
$artifacts = Split-Items -Value $artifactsText

$selectedReportKeys = Split-Items -Value ((Get-ListValue -Block $optionalBlock -Label "Selected Reports").ToLowerInvariant())
$themeSourceRaw = (Get-ListValue -Block $optionalBlock -Label "Theme Source").Trim().ToLowerInvariant()
$themeSource = if ([string]::IsNullOrWhiteSpace($themeSourceRaw)) { "auto" } else { $themeSourceRaw }

$reportDefinitions = @(
    [pscustomobject]@{
        Key = "agent"
        Title = "$scenarioName - Agent Performance Report"
        Subtitle = "Frontline activity, priorities, and execution confidence for day-to-day operations."
    },
    [pscustomobject]@{
        Key = "supervisor"
        Title = "$scenarioName - Supervisor Oversight Report"
        Subtitle = "Team-level performance, bottlenecks, and escalation visibility for operational leadership."
    },
    [pscustomobject]@{
        Key = "executive-kpi"
        Title = "$scenarioName - Executive Summary KPI Report"
        Subtitle = "Outcome-focused KPI view for leadership decision support and investment tracking."
    }
)

$selectedReports = if ($selectedReportKeys.Count -eq 0 -or $selectedReportKeys -contains "all") {
    $reportDefinitions
} else {
    @($reportDefinitions | Where-Object { $selectedReportKeys -contains $_.Key })
}
if ($selectedReports.Count -eq 0) {
    Write-Host "Warning: 'Selected Reports' matched none of agent/supervisor/executive-kpi. Generating all reports." -ForegroundColor Yellow
    $selectedReports = $reportDefinitions
}

Write-Host ""
Write-Host "=== Build Report Web Resources ===" -ForegroundColor Cyan
Write-Host "  Scenario:   $ScenarioSlug"
Write-Host "  Environment:$EnvironmentUrl"
Write-Host "  Solution:   $SolutionUniqueName"
Write-Host "  Reports:    $(($selectedReports | ForEach-Object { $_.Key }) -join ', ')"
Write-Host "  Theme:      $themeSource"
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

$themeTokens = Resolve-ThemeTokens -ThemeSource $themeSource -RepoRoot $repoRoot

try {
    $sharedCss = New-ReportCss -Tokens $themeTokens
    Set-Content -Path (Join-Path $outputFolder "shared.css") -Value $sharedCss -Encoding UTF8

    $cssResourceName = "$($PublisherPrefix.ToLower())_reports/shared.css"
    $cssResult = Set-DataverseWebResource -Name $cssResourceName -DisplayName "Report Shared Styles" -Description "Generated by 65-build-web-resources.ps1. Shared stylesheet for scenario report web resources." -Content $sharedCss -WebResourceType 2 -ComponentType $webResourceComponentType -SolutionUniqueName $SolutionUniqueName

    if ($cssResult.Action -eq "created") { $created++ } else { $updated++ }
    if ($cssResult.SolutionResult -eq "added") { $addedToSolution++ } else { $skippedSolution++ }
    Write-Host "  $cssResourceName ($($cssResult.Action))" -ForegroundColor Green
} catch {
    $failed++
    Write-Host "  shared.css (FAILED: $($_.Exception.Message))" -ForegroundColor Red
}

foreach ($report in $selectedReports) {
    try {
        $html = New-ReportHtml -ScenarioName $scenarioName -ReportTitle $report.Title -Subtitle $report.Subtitle -ProblemStatement $problemStatement -SuccessCriteria $successCriteria -Entities $entities -Artifacts $artifacts
        $fileName = "$ScenarioSlug-$($report.Key)-report.html"
        $filePath = Join-Path $outputFolder $fileName
        Set-Content -Path $filePath -Value $html -Encoding UTF8

        $webResourceName = "$($PublisherPrefix.ToLower())_reports/$fileName"
        $result = Set-DataverseWebResource -Name $webResourceName -DisplayName $report.Title -Description "Generated by 65-build-web-resources.ps1 for scenario '$ScenarioSlug'." -Content $html -WebResourceType 1 -ComponentType $webResourceComponentType -SolutionUniqueName $SolutionUniqueName

        if ($result.Action -eq "created") { $created++ } else { $updated++ }
        if ($result.SolutionResult -eq "added") { $addedToSolution++ } else { $skippedSolution++ }
        Write-Host "  $webResourceName ($($result.Action))" -ForegroundColor Green
    } catch {
        $failed++
        Write-Host "  $($report.Key) (FAILED: $($_.Exception.Message))" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Reports generated — created: $created  updated: $updated  failed: $failed"
Write-Host "Solution components — added: $addedToSolution  skipped: $skippedSolution"
Write-Host "Output folder: $outputFolder"

if ($failed -gt 0) { exit 1 }
exit 0
```

**Step 2: Syntax check**

Run the reusable parse-check snippet against `scripts/bootstrap/65-build-web-resources.ps1`.
Expected: `PASS: no parse errors`

**Step 3: Verify report-selection filter logic in isolation**

```powershell
$reportDefinitions = @(
    [pscustomobject]@{ Key = "agent" }, [pscustomobject]@{ Key = "supervisor" }, [pscustomobject]@{ Key = "executive-kpi" }
)

function Test-Selection([string[]]$keys) {
    $selected = if ($keys.Count -eq 0 -or $keys -contains "all") { $reportDefinitions } else { @($reportDefinitions | Where-Object { $keys -contains $_.Key }) }
    if ($selected.Count -eq 0) { $selected = $reportDefinitions }
    return ($selected | ForEach-Object { $_.Key }) -join ","
}

if ((Test-Selection @()) -ne "agent,supervisor,executive-kpi") { throw "FAIL: empty selection should mean all" }
if ((Test-Selection @("all")) -ne "agent,supervisor,executive-kpi") { throw "FAIL: 'all' should mean all" }
if ((Test-Selection @("agent","executive-kpi")) -ne "agent,executive-kpi") { throw "FAIL: subset selection wrong" }
if ((Test-Selection @("bogus")) -ne "agent,supervisor,executive-kpi") { throw "FAIL: no-match should fall back to all" }

Write-Host "PASS: report selection filter logic"
```

Expected: `PASS: report selection filter logic`

**Manual verification required** (needs live Dataverse credentials, not runnable in this environment): run `pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <slug>` against a real dev environment and confirm in Power Apps Maker that `<prefix>_reports/shared.css` and the selected HTML reports all appear as web resources in the target solution, and that opening an HTML report shows the styled page (not unstyled/broken due to a bad relative link).

**Step 4: Commit**

```bash
git add scripts/bootstrap/65-build-web-resources.ps1
git commit -m "feat: wire report selection and theme resolution into web resource build"
```

---

### Task 8: Wizard prompts for report selection and theme source

**Files:**
- Modify: `scripts/bootstrap/05-start-wizard.ps1:317-318`

**Step 1: Replace the hardcoded assignment**

Replace:

```powershell
$answers["ReportTheme"] = "Dynamics blue"
$answers["ReportSet"] = "Agent performance report; Supervisor oversight report; Executive summary KPI report"
```

with:

```powershell
$includeReportsAnswer = $answers["IncludeHtmlReports"].Trim().ToLowerInvariant()
if ($includeReportsAnswer -eq "yes" -or $includeReportsAnswer -eq "y" -or $includeReportsAnswer -eq "true") {
    Write-Host ""
    Write-Host "Report generation is enabled. A couple more questions about the reports:" -ForegroundColor Cyan
    $answers["ReportSet"] = Read-RequiredValue "E-reporting. Which reports do you want? (agent, supervisor, executive-kpi, or 'all')" "all"
    Write-Host "Reports can pull colors from: (1) your repo's config/web-resource-theme.json if present, (2) this environment's current published app theme, (3) the built-in Dynamics blue default. 'auto' tries them in that order." -ForegroundColor DarkGray
    $answers["ThemeSource"] = Read-RequiredValue "E-reporting. Theme source (auto/config/live/default)" "auto"
} else {
    $answers["ReportSet"] = "all"
    $answers["ThemeSource"] = "auto"
}
```

**Step 2: Update both `## Optional Report Web Resources` blocks**

In the `$answersContent` heredoc (originally lines 384-388), replace:

```
## Optional Report Web Resources
- Enabled: $($answers["IncludeHtmlReports"])
- Report set: $($answers["ReportSet"])
- Visual theme: $($answers["ReportTheme"])
- Integration: Create HTML web resources and add them to the selected solution.
```

with:

```
## Optional Report Web Resources
- Enabled: $($answers["IncludeHtmlReports"])
- Selected Reports: $($answers["ReportSet"])
- Theme Source: $($answers["ThemeSource"])
- Integration: Create HTML web resources and add them to the selected solution.
```

In the `$specContent` heredoc (originally lines 455-459), replace:

```
## Optional Report Web Resources
- Enabled: $($answers["IncludeHtmlReports"])
- Report set: $($answers["ReportSet"])
- Visual style: $($answers["ReportTheme"]) tokens with icon-backed KPI cards.
- Integration scope: Create HTML web resources and add them to solution (no automatic form-tab insertion).
```

with:

```
## Optional Report Web Resources
- Enabled: $($answers["IncludeHtmlReports"])
- Selected Reports: $($answers["ReportSet"])
- Theme Source: $($answers["ThemeSource"])
- Integration scope: Create HTML web resources and add them to solution (no automatic form-tab insertion).
```

Field names now match exactly what `65-build-web-resources.ps1`'s `Get-ListValue -Label "Selected Reports"` / `-Label "Theme Source"` expect (Task 7).

**Step 3: Syntax check**

```powershell
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile("scripts/bootstrap/05-start-wizard.ps1", [ref]$null, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -gt 0) { $parseErrors | ForEach-Object { Write-Host $_ }; throw "Parse errors found" } else { Write-Host "PASS: no parse errors" }
```

Expected: `PASS: no parse errors`

**Step 4: Verify backward compatibility — existing answers.md files without the new fields**

`specs/contoso-case-tracker/answers.md` predates this feature and has no `## Optional Report Web Resources` section at all. Confirm `65-build-web-resources.ps1`'s existing early-exit path (`$includeReports` empty → "Nothing to generate") still triggers cleanly for it — this doesn't need code changes, just confirms Task 7's `Get-MarkdownSectionValue` call returns an empty block gracefully rather than throwing:

```powershell
pwsh -NoProfile -Command "
  . { function Get-MarkdownSectionValue { param(\$Content,\$Heading) \$p='(?ms)^##\s+'+[regex]::Escape(\$Heading)+'\s*\r?\n(.*?)(?=^##\s+|\z)'; \$m=[regex]::Match(\$Content,\$p); if(-not \$m.Success){return ''}; return \$m.Groups[1].Value.Trim() } }
  \$content = Get-Content 'specs/contoso-case-tracker/answers.md' -Raw
  \$block = Get-MarkdownSectionValue -Content \$content -Heading 'Optional Report Web Resources'
  if (\$block -ne '') { throw 'FAIL: expected empty block for scenario without this section' }
  Write-Host 'PASS: missing section handled gracefully'
"
```

Expected: `PASS: missing section handled gracefully`

**Step 5: Commit**

```bash
git add scripts/bootstrap/05-start-wizard.ps1
git commit -m "feat: ask report selection and theme source in wizard instead of hardcoding"
```

---

### Task 9: Documentation updates

**Files:**
- Modify: `README.md` (script table entry and "Optional report web resources" bullets — see grep hits at lines ~343-348 and ~515 in the pre-change file; exact line numbers will have shifted from other recent README edits, search for the text below instead of trusting line numbers)

**Step 1: Update the "Optional report web resources" bullet list**

Find the block starting with `Optional report web resources:` and add one bullet documenting the new config file and selection/theme wizard questions:

```markdown
Optional report web resources:

- `05-start-wizard.ps1` captures a yes/no decision for optional reporting module scope (when enabled in `wizard.profile.json`), plus which reports to build and which theme source to use.
- `70-build-web-resources.ps1` is the canonical optional module entrypoint.
- `65-build-web-resources.ps1` remains the implementation script called by `70-build-web-resources.ps1`.
- The script upserts Dataverse HTML web resources and adds them to the selected solution.
- Report styling comes from `config/web-resource-theme.json` if present, otherwise the environment's published app theme, otherwise a built-in default — see `docs/plans/2026-07-17-web-resource-theming-design.md`.
```

**Step 2: Update the script table row for `65-build-web-resources.ps1`**

Find:

```
| `65-build-web-resources.ps1` | Generate optional scenario-driven HTML report web resources (agent, supervisor, executive KPI) and add them to solution | Yes | Yes |
```

Replace with:

```
| `65-build-web-resources.ps1` | Generate optional scenario-driven HTML report web resources (agent, supervisor, executive KPI, selectable), themed via config file / live app theme / default, and add them to solution | Yes | Yes |
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document web resource theming and report selection"
```

---

### Task 10: Final full verification pass

**Step 1: Syntax-check both modified scripts**

```powershell
foreach ($file in @("scripts/bootstrap/65-build-web-resources.ps1", "scripts/bootstrap/05-start-wizard.ps1")) {
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) { $parseErrors | ForEach-Object { Write-Host $_ }; throw "Parse errors in $file" }
    Write-Host "PASS: $file"
}
```

Expected: `PASS` for both files.

**Step 2: Confirm `config/web-resource-theme.json` still round-trips through the full resolution chain**

```powershell
$src = Get-Content scripts/bootstrap/65-build-web-resources.ps1 -Raw
$names = "Get-DefaultThemeTokens", "Get-ThemeConfigFileTokens", "Get-LiveAppThemeTokens", "Resolve-ThemeTokens", "New-ReportCss"
$pattern = '(?ms)^function (' + ($names -join "|") + ') \{.*?\n\}\r?\n'
$funcs = [regex]::Matches($src, $pattern)
$scratch = Join-Path ([IO.Path]::GetTempPath()) "final-scratch.ps1"
Set-Content -Path $scratch -Value (($funcs | ForEach-Object { $_.Value }) -join "`n")
. $scratch

$tokens = Resolve-ThemeTokens -ThemeSource "config" -RepoRoot (Get-Location)
$css = New-ReportCss -Tokens $tokens
if ($css -notmatch [regex]::Escape("--dyn-primary: #0078d4;")) { throw "FAIL: end-to-end token resolution + CSS generation broke" }
Write-Host "PASS: end-to-end config-file theme resolution"
Remove-Item $scratch
```

Expected: `PASS: end-to-end config-file theme resolution`

**Step 3: List remaining manual verification items for the user before merging**

Print/report this checklist (cannot be automated without live Dataverse credentials):
- [ ] Run `65-build-web-resources.ps1` against a real dev environment with `Theme Source: auto` and a published custom app theme — confirm colors match the app theme.
- [ ] Confirm `<prefix>_reports/shared.css` is created and both it and the selected HTML reports appear in the target solution in Power Apps Maker.
- [ ] Open a generated HTML report web resource directly and confirm styling renders (relative `href="shared.css"` resolves correctly).
- [ ] Run `05-start-wizard.ps1` interactively once, answer "yes" to reports, and confirm the two new prompts appear and `answers.md`/`spec.md` get the new `Selected Reports` / `Theme Source` lines.

No commit for this task — it's verification only.
