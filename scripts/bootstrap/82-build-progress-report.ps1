<#
.SYNOPSIS
    Builds an HTML dashboard from wizard telemetry analytics.

.DESCRIPTION
    Uses 81-build-progress-matrix.ps1 (JSON mode) as the analytics source,
    writes a local JSON snapshot, and renders a self-contained HTML report.

.PARAMETER RepoRoot
    Optional repository root path.

.PARAMETER EventsPath
    Optional explicit events.jsonl path.

.PARAMETER OutputPath
    Optional HTML output path. Defaults to .wizard-metrics/build-progress-report.html.

.PARAMETER DataJsonPath
    Optional JSON snapshot path. Defaults to .wizard-metrics/build-progress-data.json.

.PARAMETER SkipRefresh
    If set, reuse existing DataJsonPath instead of rebuilding analytics JSON.

.EXAMPLE
    pwsh ./scripts/bootstrap/82-build-progress-report.ps1
#>

param(
    [string]$RepoRoot = '',
    [string]$EventsPath = '',
    [string]$OutputPath = '',
    [string]$DataJsonPath = '',
    [switch]$SkipRefresh
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$metricsRoot = Join-Path $RepoRoot '.wizard-metrics'
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $metricsRoot 'build-progress-report.html'
}
if ([string]::IsNullOrWhiteSpace($DataJsonPath)) {
    $DataJsonPath = Join-Path $metricsRoot 'build-progress-data.json'
}
if ([string]::IsNullOrWhiteSpace($EventsPath)) {
    $EventsPath = Join-Path $metricsRoot 'events.jsonl'
}

New-Item -ItemType Directory -Path $metricsRoot -Force | Out-Null

if (-not $SkipRefresh) {
    $matrixScript = Join-Path $PSScriptRoot '81-build-progress-matrix.ps1'
    if (-not (Test-Path $matrixScript)) {
        throw "Missing dependency: $matrixScript"
    }

    $json = & $matrixScript -RepoRoot $RepoRoot -EventsPath $EventsPath -Format Json
    if ([string]::IsNullOrWhiteSpace(($json -join '').Trim())) {
      throw 'Failed to generate analytics JSON from 81-build-progress-matrix.ps1'
    }

    $json | Set-Content -Path $DataJsonPath -Encoding UTF8
}

if (-not (Test-Path $DataJsonPath)) {
    throw "Analytics JSON not found: $DataJsonPath"
}

$jsonPayload = Get-Content -Path $DataJsonPath -Raw -Encoding UTF8
$generatedUtc = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')

$htmlTemplate = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Wizard Progress Report</title>
  <style>
    :root {
      --bg: #f4f7fb;
      --panel: #ffffff;
      --text: #152238;
      --muted: #5b6b83;
      --line: #d7e0ee;
      --accent: #0a6ed1;
      --accent-soft: #d9ebff;
      --warn: #b26a00;
      --good: #1e7d3a;
      --bad: #b42318;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
      color: var(--text);
      background: radial-gradient(circle at 10% 0%, #ffffff 0%, var(--bg) 45%, #edf2fb 100%);
    }
    .wrap {
      max-width: 1200px;
      margin: 0 auto;
      padding: 24px;
    }
    .hero {
      display: flex;
      align-items: end;
      justify-content: space-between;
      gap: 16px;
      margin-bottom: 16px;
    }
    h1 {
      margin: 0;
      font-size: 28px;
      letter-spacing: 0.2px;
    }
    .meta {
      color: var(--muted);
      font-size: 13px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 12px;
      margin-bottom: 16px;
    }
    .card {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 12px;
    }
    .card h3 {
      margin: 0 0 8px 0;
      font-size: 12px;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.6px;
    }
    .card .v {
      font-size: 24px;
      font-weight: 650;
      line-height: 1.2;
    }
    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 14px;
      margin-bottom: 14px;
    }
    .panel h2 {
      margin: 0 0 10px 0;
      font-size: 16px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      text-align: left;
      padding: 7px 8px;
      vertical-align: top;
    }
    th {
      color: var(--muted);
      font-weight: 600;
      background: #fafcff;
      position: sticky;
      top: 0;
    }
    .scroll { overflow: auto; max-height: 380px; }
    .pill {
      display: inline-block;
      border-radius: 999px;
      padding: 2px 8px;
      font-size: 12px;
      line-height: 18px;
    }
    .ok { background: #e9f7ef; color: var(--good); }
    .warn { background: #fff3e0; color: var(--warn); }
    .bad { background: #fee4e2; color: var(--bad); }
    .bars {
      display: grid;
      gap: 8px;
    }
    .bar-row {
      display: grid;
      grid-template-columns: 120px 1fr 42px;
      align-items: center;
      gap: 10px;
      font-size: 13px;
    }
    .track {
      background: #eef3fb;
      border-radius: 6px;
      overflow: hidden;
      height: 12px;
    }
    .fill {
      background: linear-gradient(90deg, #3d8ef4 0%, var(--accent) 100%);
      height: 100%;
      width: 0;
    }
    .two {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 14px;
    }
    @media (max-width: 960px) {
      .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
      .two { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hero">
      <div>
        <h1>Wizard Progress Report</h1>
        <div class="meta">Local report from .wizard-metrics (non-identifying telemetry).</div>
      </div>
      <div class="meta">Generated UTC: __GENERATED_UTC__</div>
    </div>

    <div class="grid" id="kpi"></div>

    <div class="two">
      <div class="panel">
        <h2>Drop-Off Steps</h2>
        <div class="bars" id="dropoff-bars"></div>
      </div>
      <div class="panel">
        <h2>Error Categories</h2>
        <div class="bars" id="error-bars"></div>
      </div>
    </div>

    <div class="two">
      <div class="panel">
        <h2>Step Durations (Median / P90 seconds)</h2>
        <div class="scroll"><table id="durations"></table></div>
      </div>
      <div class="panel">
        <h2>Completion by Day</h2>
        <div class="scroll"><table id="by-day"></table></div>
      </div>
    </div>

    <div class="panel">
      <h2>Runs</h2>
      <div class="scroll"><table id="runs"></table></div>
    </div>
  </div>

  <script id="report-data" type="application/json">__JSON_PAYLOAD__</script>
  <script>
    const data = JSON.parse(document.getElementById('report-data').textContent || '{}');
    const runs = Array.isArray(data.runs) ? data.runs : [];
    const dropOff = data.dropOffCounts || {};
    const errors = data.errorCategoryCounts || {};
    const completionByDay = data.completionByDay || {};
    const stepDurationStats = Array.isArray(data.stepDurationStats) ? data.stepDurationStats : [];

    const toNum = (v) => {
      const n = Number(v);
      return Number.isFinite(n) ? n : 0;
    };

    const countWhere = (arr, pred) => arr.reduce((a, x) => a + (pred(x) ? 1 : 0), 0);

    const runCount = runs.length;
    const buildComplete = countWhere(runs, r => r.CompletionStatus === 'BuildComplete' || r.CompletionStatus === 'WorkflowComplete');
    const workflowComplete = countWhere(runs, r => r.CompletionStatus === 'WorkflowComplete');
    const savedMin = runs.reduce((a, r) => a + toNum(r.EstimatedSavedMin), 0);
    const retries = runs.reduce((a, r) => a + toNum(r.RetryCount), 0);

    const pct = (num, den) => den > 0 ? (100 * num / den).toFixed(1) + '%' : '0%';

    const kpis = [
      ['Runs', runCount],
      ['Build Completion', pct(buildComplete, runCount)],
      ['Workflow Completion', pct(workflowComplete, runCount)],
      ['Estimated Time Saved', savedMin.toFixed(1) + ' min'],
      ['Estimated Time Saved (h)', (savedMin / 60).toFixed(2)],
      ['Total Retries', retries],
      ['Avg Retry / Run', runCount > 0 ? (retries / runCount).toFixed(2) : '0.00'],
      ['Core+Optional Runs', countWhere(runs, r => (r.OptionalModulesUsed || '-') !== '-')]
    ];

    const kpiHost = document.getElementById('kpi');
    for (const [label, value] of kpis) {
      const el = document.createElement('div');
      el.className = 'card';
      el.innerHTML = `<h3>${label}</h3><div class="v">${value}</div>`;
      kpiHost.appendChild(el);
    }

    function renderBars(hostId, obj) {
      const host = document.getElementById(hostId);
      const entries = Object.entries(obj).sort((a, b) => b[1] - a[1]);
      if (entries.length === 0) {
        host.innerHTML = '<div class="meta">No data.</div>';
        return;
      }
      const max = Math.max(...entries.map(x => toNum(x[1])), 1);
      for (const [label, valueRaw] of entries) {
        const value = toNum(valueRaw);
        const pct = Math.round((value / max) * 100);
        const row = document.createElement('div');
        row.className = 'bar-row';
        row.innerHTML = `
          <div>${label}</div>
          <div class="track"><div class="fill" style="width:${pct}%"></div></div>
          <div>${value}</div>
        `;
        host.appendChild(row);
      }
    }

    renderBars('dropoff-bars', dropOff);
    renderBars('error-bars', errors);

    function renderTable(hostId, headers, rows) {
      const host = document.getElementById(hostId);
      const thead = `<thead><tr>${headers.map(h => `<th>${h}</th>`).join('')}</tr></thead>`;
      const tbody = `<tbody>${rows.map(r => `<tr>${r.map(c => `<td>${c}</td>`).join('')}</tr>`).join('')}</tbody>`;
      host.innerHTML = thead + tbody;
    }

    const durationRows = stepDurationStats.map(s => [
      s.StepCode ?? '-',
      toNum(s.Samples),
      toNum(s.MedianSeconds),
      toNum(s.P90Seconds)
    ]);
    renderTable('durations', ['Step', 'Samples', 'Median', 'P90'], durationRows);

    const dayRows = Object.entries(completionByDay)
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([date, v]) => {
        const runs = toNum(v.Runs);
        const build = toNum(v.BuildComplete);
        const wf = toNum(v.WorkflowComplete);
        const buildRate = runs > 0 ? ((100 * build / runs).toFixed(1) + '%') : '0%';
        const wfRate = runs > 0 ? ((100 * wf / runs).toFixed(1) + '%') : '0%';
        return [date, runs, build, wf, buildRate, wfRate];
      });
    renderTable('by-day', ['Date', 'Runs', 'BuildComplete', 'WorkflowComplete', 'BuildRate', 'WorkflowRate'], dayRows);

    const runHeaders = [
      'RunId', 'StartedDate', 'StartedUtc', 'CompletionStatus', 'DropOffStep',
      'RunDurationMin', 'ActiveMinutes', 'WaitingMinutes', 'EstimatedSavedMin',
      'RetryCount', 'ErrorCategories', 'OptionalModulesUsed', 'HighestCompleted'
    ];

    const pill = (txt) => {
      if (txt === 'WorkflowComplete') return `<span class="pill ok">${txt}</span>`;
      if (txt === 'BuildComplete') return `<span class="pill ok">${txt}</span>`;
      if (txt === 'Failed') return `<span class="pill bad">${txt}</span>`;
      return `<span class="pill warn">${txt}</span>`;
    };

    const runRows = runs
      .sort((a, b) => String(b.StartedUtc || '').localeCompare(String(a.StartedUtc || '')))
      .map(r => [
        r.RunId || '-',
        r.StartedDate || '-',
        r.StartedUtc || '-',
        pill(r.CompletionStatus || '-'),
        r.DropOffStep || '-',
        r.RunDurationMin ?? '-',
        r.ActiveMinutes ?? '-',
        r.WaitingMinutes ?? '-',
        r.EstimatedSavedMin ?? '-',
        r.RetryCount ?? '-',
        r.ErrorCategories || '-',
        r.OptionalModulesUsed || '-',
        r.HighestCompleted || '-'
      ]);

    const runHost = document.getElementById('runs');
    const runHead = `<thead><tr>${runHeaders.map(h => `<th>${h}</th>`).join('')}</tr></thead>`;
    const runBody = `<tbody>${runRows.map(r => `<tr>${r.map(c => `<td>${c}</td>`).join('')}</tr>`).join('')}</tbody>`;
    runHost.innerHTML = runHead + runBody;
  </script>
</body>
</html>
'@

$html = $htmlTemplate.Replace('__GENERATED_UTC__', $generatedUtc).Replace('__JSON_PAYLOAD__', $jsonPayload)

Set-Content -Path $OutputPath -Value $html -Encoding UTF8
Write-Host "Report written to: $OutputPath" -ForegroundColor Green
Write-Host "Data JSON written to: $DataJsonPath" -ForegroundColor Green
