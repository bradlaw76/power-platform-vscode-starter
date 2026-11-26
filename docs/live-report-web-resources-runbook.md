# Live Report Web Resources Runbook

Use this runbook when generating scenario-specific HTML report web resources that read live Dataverse data.

## Reporting choice and requirements gate

During the app wizard's reporting stage, choose **native**, **html**, **both**,
or **none**. Native means standard Dataverse charts/dashboard components; HTML
means tailored Dynamics-styled reports. Neither is mandatory. Demo Builder
keeps six business questions and incorporates this selection into its existing
confirmation; detailed modes ask it directly. The focused Dataverse Report
Wizard remains a native-only workflow for existing apps.
With explicitly enabled accelerator matching, append a reporting suffix to
that same architecture confirmation, such as `fully-custom+html` or
`hybrid+both`. Architecture approval never approves report definitions.

Before selecting a report, explain its audience, business decision, exact
metrics and calculations, record scope, app placement, limitations, and overlap
with other surfaces. Use both technologies only for complementary tasks.
Frontline/agent, supervisor, and leadership are reusable design patterns:
they are not an instruction to create three reports for every app.

Before stage 65 or 70:

1. Complete and approve scenario spec/plan/tasks and `report-mappings.md`.
2. Create `specs/<scenario-slug>/html-reports.json` using
   [the unapproved example](../schemas/examples/html-reports.example.json) and
   [schema](../schemas/payloads/html-reports.schema.json).
3. For each report define its stable key, persona level, business title,
   audience, purpose, target table, and placement. Its table/title/placement
   must match exactly one eight-column row in `report-mappings.md`.
4. Supply exact requirement excerpts from the scenario's current `spec.md`
   or `plan.md`. Do not invent requirements or copy another scenario's approval.
5. Define only documented metrics. Supported query shapes are total-record
   count (`__primaryid__`), grouped count (`__primaryid__` plus one exact mapped
   field), and recent-record list (`__primaryname__` plus `createdon` or
   `modifiedon`). These query shapes do not implement filtered counts,
   cross-table joins, currency sums, historical trends, or custom formulas.
   Do not label a total count "open", "mine", or "team" without implementing and
   validating that scope. Defer unsupported calculations explicitly.
6. Review definitions with the user and set `Approved: true` only after approval.
   Preview also requires that approval; no legacy HTML plan is auto-approved.
7. Run query preview and inspect the generated HTML, config, requirement
   references, and metadata validation before deployment.

The generator no longer assumes priority, owner, or age fields from a generic
scenario classification. Missing definitions, stale requirement excerpts,
unmapped tables/fields/placements, and duplicate keys fail explicitly.
Scenario definitions are rechecked by the orchestrator before build stages.
Dataverse field validation still occurs in stage 65.

HTML files live in the scenario's `webresources` folder; configs and validation
live in `report-artifacts`. Reruns upsert stable scenario/report-key resources.
Removing a definition does not delete previously deployed resources; review
removal separately. Adding a resource to the solution does **not** automatically
place it on a form or in the sitemap. Complete and validate the approved
placement handoff. Reports run under the signed-in user's Dataverse access;
persona labels do not grant or restrict permissions.

## Review reporting updates and trace the build

After confirming reporting choices, optionally record `html-reports` as enabled
or disabled in scenario `repo-update-context.json`. The
[repository update advisor](repository-updates.md) uses that explicit selection
to categorize relevant changed paths; missing selections stay review-needed.
It never approves `html-reports.json`, changes reporting choices or deploys a
web resource. Native/HTML selections and report-definition approval remain
separate gates.

```powershell
pwsh .\scripts\bootstrap\check-repository-updates.ps1 -ScenarioSlug <scenario-slug>
```

This uses cached metadata; network needs explicit `-Fetch`. For an orchestrated
build, retain `repositoryBaseline` from the run summary with your reporting
validation evidence. Only orchestrated Apply archives immutable source records.
Direct stage 65/70 preview or deployment does not create an orchestrated run
baseline. Never treat an advisory report or source fingerprint as proof of
live queries, permissions, report rendering or placement.

## Live report mode

Run:

```powershell
pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <scenario-slug> -ReportMode live
```

Behavior:
- Validates scenario-derived entities and fields against Dataverse.
- Generates HTML web resources plus local config, query preview, and validation artifacts.
- Fails the step if required report entities or fields are missing.

## Zero-data mode

Run:

```powershell
pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <scenario-slug> -ReportMode live-with-design-fallback
```

Behavior:
- Queries live Dataverse data at runtime when the report opens.
- If no operational records exist yet, renders zero-state KPI cards and keeps the layout intact.
- Does not fabricate business KPIs when the environment is empty.

## Design-summary fallback mode

Run:

```powershell
pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <scenario-slug> -ReportMode static -EnableLiveDataverseReports:$false
```

Behavior:
- Generates the same scenario-specific report shell.
- Skips live Dataverse runtime queries.
- Shows only clearly labeled design metadata.

## Query preview mode

Run:

```powershell
pwsh ./scripts/bootstrap/65-build-web-resources.ps1 -ScenarioSlug <scenario-slug> -PreviewReportQueriesOnly
```

Behavior:
- Writes HTML and JSON artifacts locally.
- Skips Dataverse upload.
- Emits intended query definitions to `specs/<scenario-slug>/report-artifacts/query-preview.json`.

## Troubleshooting missing entity or field validation

If generation fails:
- Open `specs/<scenario-slug>/report-artifacts/report-validation.json`.
- Review `MissingEntities` and `MissingFields` for the failing report.
- Confirm the scenario mapping in `specs/<scenario-slug>/spec.md` matches the intended Dataverse logical names.
- Confirm the environment actually contains those entities and fields.
- If you only want to inspect generated queries before resolving metadata gaps, rerun with `-PreviewReportQueriesOnly`.
