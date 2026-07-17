# Web resource report theming — design

Date: 2026-07-17
Status: Approved, ready for implementation planning

## Problem

`scripts/bootstrap/65-build-web-resources.ps1` generates three HTML "report" web
resources (agent performance, supervisor oversight, executive KPI) with an
entire `<style>` block hardcoded and duplicated in each file — Dynamics blue
colors baked directly into the PowerShell heredoc. Since this repo is meant to
be forked/referenced by other repos the way a skill is, there is currently no
seam for a consuming repo to rebrand these reports without editing the
generator script itself. There's also no way to build only a subset of the
three reports, and the wizard already writes a "Visual theme" / "Report set"
line into `answers.md` that is hardcoded rather than actually asked.

## Design

### 1. Theme token resolution (per-token, three-tier fallback)

For each color/font token, resolve in this order — first source that defines
the token wins:

1. `config/web-resource-theme.json` (repo-root, committed with today's
   defaults) — explicit override, no API call needed.
2. Live Dataverse app theme — `GET {env}/api/data/v9.0/themes?$filter=isdefaulttheme eq true&$select=...`
   — auto-detected branding already published in the target environment.
3. Hardcoded default in the script (today's Dynamics blue values) — last
   resort, keeps the script working standalone with zero configuration.

This is a per-token merge, not all-or-nothing: a config file may override just
one or two tokens and let the rest fall through to live theme / hardcoded
default.

`config/web-resource-theme.json` shape:

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

### 2. Live app theme → token mapping

Confirmed against the Dataverse `theme` table schema
(https://learn.microsoft.com/en-us/power-apps/developer/model-driven-apps/query-and-edit-an-organization-theme):

| Our token | Dataverse theme column | Notes |
|---|---|---|
| `primary` | `MainColor` | UCI primary command bar/button color |
| `primaryStrong` | `HeaderColor` | Header text emphasis color |
| `accent` | `AccentColor` | Named match |
| `border` | `ControlBorder` | Named match |
| `good` | `ProcessControlColor` | Green by default — matches "on track" status semantics |
| `background` | `PageHeaderBackgroundColor` | Closest available column; approximation |
| `surface`, `text`, `muted`, `warning`, `fontFamily` | *(none)* | Not covered by the theme table — always fall through to config/hardcoded default |

Query: `GET {env}/api/data/v9.0/themes?$filter=isdefaulttheme eq true&$select=maincolor,headercolor,accentcolor,controlborder,processcontrolcolor,pageheaderbackgroundcolor`

If the call fails (older org, missing privilege, no published custom theme),
catch and fall through to hardcoded defaults for every token — same
fail-soft pattern already used in `Get-WebResourceComponentType`
([65-build-web-resources.ps1:156-170](../../scripts/bootstrap/65-build-web-resources.ps1#L156-L170)).

### 3. Wizard prompts (`05-start-wizard.ps1`)

Today, when `IncludeHtmlReports` is answered yes, the script writes two
hardcoded lines with no actual question asked
([05-start-wizard.ps1:317-318](../../scripts/bootstrap/05-start-wizard.ps1#L317-L318)):

```powershell
$answers["ReportTheme"] = "Dynamics blue"
$answers["ReportSet"] = "Agent performance report; Supervisor oversight report; Executive summary KPI report"
```

Replace with two real follow-up prompts (same `Read-RequiredValue` pattern
used throughout the file), asked only when reports are enabled:

1. **Report set** — *"Which reports do you want? (agent, supervisor,
   executive-kpi, or 'all')"* — default `all`.
2. **Theme source** — print the three-tier chain as advisory text, then
   prompt: *"Theme source — auto / config / live / default"* — default
   `auto`. `auto` runs the full per-token chain from section 1; `config`,
   `live`, and `default` force one specific source and skip the others
   (`default` skips both the config-file read and the Dataverse theme API
   call).

Both answers are written into the existing `## Optional Report Web Resources`
block in `answers.md` (`Selected Reports`, `Theme Source`), replacing the two
hardcoded lines.

### 4. Shared CSS web resource

`65-build-web-resources.ps1` renders the resolved tokens into one CSS
document, writes it locally to `specs/<scenario>/webresources/shared.css`,
and upserts it as a Dataverse web resource named `<prefix>_reports/shared.css`
(`webresourcetype` 2 = CSS). It is **not** scenario-prefixed — one shared
stylesheet reused across scenarios and reruns. It's created/updated before the
selected HTML reports in the loop and added to the solution alongside them.

Each report HTML drops its inline `<style>` block and instead gets
`<link rel="stylesheet" href="shared.css" />` in `<head>` — relative
resolution works because both web resources live in the same
`<prefix>_reports/` virtual folder.

### 5. Section-specific icons

`New-IconSvg` is re-keyed from report role (agent/supervisor/executive) to
card section (business, success, health, data, artifacts) — five small inline
SVGs, one per card type, reused identically across whichever reports are
generated. The report-role icon concept is removed since it added no visual
distinction once sections have their own icons.

### 6. Report selection

`65-build-web-resources.ps1` reads `Selected Reports` from `answers.md`
(comma list of keys, or `all`) and only generates/upserts/adds-to-solution the
chosen subset. Blank/omitted/`all` means all 3 — no behavior change for
existing scenarios that predate this field.

## Error handling

- Malformed `config/web-resource-theme.json` (exists but invalid JSON) fails
  loudly — the script already runs under `Set-StrictMode -Version Latest` and
  `$ErrorActionPreference = "Stop"`. A broken theme file should be visible,
  not silently swallowed.
- A failed live-theme API call is caught and treated as "this source has no
  data" — falls through to the next tier, does not abort the script.

## Backward compatibility

- No new required params on `65-build-web-resources.ps1` or the `70-` wrapper.
- Existing deployed HTML web resources get regenerated with the `<link>` tag
  and section icons on next run (script is already idempotent/upsert).
- Existing `answers.md` files without `Selected Reports` / `Theme Source`
  default to "all reports" / "auto theme" — identical output to today's
  hardcoded Dynamics blue, three-report behavior.
