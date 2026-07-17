<#
.SYNOPSIS
    Generates a concise end-of-build analysis and optionally updates README markers.

.DESCRIPTION
    Reads scenario planning artifacts and payload files to produce a standard build
    summary. Supports preview-only mode and explicit user confirmations before any
    README, commit, or push action.

.PARAMETER ScenarioSlug
    Scenario folder under specs/. If omitted and there is exactly one scenario,
    that scenario is selected automatically.

.PARAMETER PreviewOnly
    Prints generated summary and exits without modifying README or running git.
#>

param(
    [string]$ScenarioSlug = "",
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$specsRoot = Join-Path $repoRoot "specs"
$readmePath = Join-Path $repoRoot "README.md"

function Read-YesNo {
    param([string]$Prompt)

    $raw = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $false
    }

    return @("y", "yes") -contains $raw.Trim().ToLower()
}

function Get-ScenarioSlug {
    param(
        [string]$RequestedSlug,
        [string]$SpecsRootPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedSlug)) {
        return $RequestedSlug.Trim()
    }

    $scenarioDirs = @(Get-ChildItem -Path $SpecsRootPath -Directory -ErrorAction SilentlyContinue)
    if ($scenarioDirs.Count -eq 1) {
        return $scenarioDirs[0].Name
    }

    throw "ScenarioSlug is required when specs/ contains zero or multiple scenarios."
}

function Get-MarkdownSection {
    param(
        [string]$Content,
        [string]$Heading
    )

    $pattern = "(?ms)^###\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^###\s+|^##\s+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim()
}

function Get-BulletListValues {
    param([string]$Block)

    if ([string]::IsNullOrWhiteSpace($Block)) {
        return @()
    }

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Block -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match "^-\s+(.+)$") {
            $items.Add($matches[1].Trim())
        }
    }

    return @($items)
}

function Get-PlanMetadataValue {
    param(
        [string]$PlanContent,
        [string]$Label
    )

    $pattern = "(?im)^-\s+$([regex]::Escape($Label)):\s*(.+)$"
    $match = [regex]::Match($PlanContent, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim()
}

function Get-AllPayloadFiles {
    param([string]$RepoRootPath)

    $roots = New-Object System.Collections.Generic.List[string]
    $scriptsPayloadRoot = Join-Path $RepoRootPath "scripts\payloads"
    $repoPayloadRoot = Join-Path $RepoRootPath "payloads"

    if (Test-Path $scriptsPayloadRoot) {
        $roots.Add($scriptsPayloadRoot)
    }
    if (Test-Path $repoPayloadRoot) {
        $roots.Add($repoPayloadRoot)
    }

    $tableFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $columnFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $relationshipFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $webresourceFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]

    foreach ($root in $roots) {
        foreach ($f in @(Get-ChildItem -Path $root -Filter "table-*.json" -File -Recurse -ErrorAction SilentlyContinue)) {
            $tableFiles.Add($f)
        }
        foreach ($f in @(Get-ChildItem -Path $root -Filter "columns-*.json" -File -Recurse -ErrorAction SilentlyContinue)) {
            $columnFiles.Add($f)
        }
        foreach ($f in @(Get-ChildItem -Path $root -Filter "relationships-*.json" -File -Recurse -ErrorAction SilentlyContinue)) {
            $relationshipFiles.Add($f)
        }
        foreach ($f in @(Get-ChildItem -Path $root -Filter "webresource-*.json" -File -Recurse -ErrorAction SilentlyContinue)) {
            $webresourceFiles.Add($f)
        }
    }

    return [pscustomobject]@{
        Tables = @($tableFiles | Sort-Object FullName -Unique)
        Columns = @($columnFiles | Sort-Object FullName -Unique)
        Relationships = @($relationshipFiles | Sort-Object FullName -Unique)
        WebResources = @($webresourceFiles | Sort-Object FullName -Unique)
    }
}

function Get-Json {
    param([string]$Path)

    return Get-Content $Path -Raw | ConvertFrom-Json
}

function Get-PropertyValue {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-ItemOrNone {
    param([System.Collections.Generic.List[string]]$List)

    if ($List.Count -eq 0) {
        return @("(none detected)")
    }

    return @($List)
}

function Set-ReadmeGeneratedSummary {
    param(
        [string]$ReadmeFile,
        [string]$Summary
    )

    $beginMarker = "BEGIN GENERATED BUILD SUMMARY"
    $endMarker = "END GENERATED BUILD SUMMARY"

    $readme = Get-Content $ReadmeFile -Raw
    if ($readme -notmatch [regex]::Escape($beginMarker) -or $readme -notmatch [regex]::Escape($endMarker)) {
        throw "README markers are missing. Ensure BEGIN/END GENERATED BUILD SUMMARY markers exist."
    }

    $replacement = "$beginMarker`r`n$Summary`r`n$endMarker"
    $updated = [regex]::Replace(
        $readme,
        "(?ms)^$([regex]::Escape($beginMarker))\s*$.*?^$([regex]::Escape($endMarker))\s*$",
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }
    )

    Set-Content -Path $ReadmeFile -Value $updated -Encoding UTF8
}

function Show-RepoTargetDetails {
    Write-Host ""
    Write-Host "Repository target safety check:" -ForegroundColor Cyan

    $top = (& git rev-parse --show-toplevel 2>$null)
    $branch = (& git branch --show-current 2>$null)
    $remote = (& git remote -v 2>$null)

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Unable to read git repository details. Skipping git actions." -ForegroundColor Yellow
        return $false
    }

    Write-Host "  git rev-parse --show-toplevel"
    Write-Host "  $($top -join "`n")" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  git remote -v"
    foreach ($line in @($remote)) {
        Write-Host "  $line" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  git branch --show-current"
    Write-Host "  $($branch -join "`n")" -ForegroundColor DarkGray

    return (Read-YesNo "Proceed with commit/push in this repository target? (y/N)")
}

Write-Host ""
Write-Host "=== End-of-Build Analysis ===" -ForegroundColor Cyan

$ScenarioSlug = Get-ScenarioSlug -RequestedSlug $ScenarioSlug -SpecsRootPath $specsRoot
$scenarioPath = Join-Path $specsRoot $ScenarioSlug

$specPath = Join-Path $scenarioPath "spec.md"
$planPath = Join-Path $scenarioPath "plan.md"
$tasksPath = Join-Path $scenarioPath "tasks.md"
$talkTrackPath = Join-Path $scenarioPath "demo-talk-track.md"

foreach ($required in @($specPath, $planPath, $tasksPath, $readmePath)) {
    if (-not (Test-Path $required)) {
        throw "Required source file not found: $required"
    }
}

$spec = Get-Content $specPath -Raw
$plan = Get-Content $planPath -Raw
$tasks = Get-Content $tasksPath -Raw
$payload = Get-AllPayloadFiles -RepoRootPath $repoRoot

$standardReuseBlock = Get-MarkdownSection -Content $spec -Heading "Standard reused tables (display -> logical)"
$customTablesBlock = Get-MarkdownSection -Content $spec -Heading "Custom tables to create (input -> generated logical)"
$relationshipMappingBlock = Get-MarkdownSection -Content $spec -Heading "Relationships to create"
$experienceLine = [regex]::Match($spec, "(?im)^##\s+Required Experience and Artifacts\s*\r?\n(.+)$").Groups[1].Value.Trim()

$customTablesFromSpec = @(Get-BulletListValues -Block $customTablesBlock)
$relationshipMappings = @(Get-BulletListValues -Block $relationshipMappingBlock)

$customTableNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($file in $payload.Tables) {
    try {
        $doc = Get-Json -Path $file.FullName
        $entityDefinition = Get-PropertyValue -Object $doc -Name "EntityDefinition"
        $schemaName = (Get-PropertyValue -Object $entityDefinition -Name "SchemaName")
        if ([string]::IsNullOrWhiteSpace($schemaName)) {
            $schemaName = Get-PropertyValue -Object $doc -Name "SchemaName"
        }
        if (-not [string]::IsNullOrWhiteSpace($schemaName)) {
            [void]$customTableNames.Add($schemaName.ToLower())
        }
    } catch {
        Write-Host "Warning: unable to parse table payload $($file.FullName)" -ForegroundColor Yellow
    }
}

$columnByTable = @{}
foreach ($file in $payload.Columns) {
    try {
        $doc = Get-Json -Path $file.FullName
        $tableName = (Get-PropertyValue -Object $doc -Name "TableLogicalName")
        if ($null -eq $tableName) {
            $tableName = ""
        }
        $tableName = $tableName.ToLower()
        if ([string]::IsNullOrWhiteSpace($tableName)) {
            continue
        }

        if (-not $columnByTable.ContainsKey($tableName)) {
            $columnByTable[$tableName] = New-Object System.Collections.Generic.List[string]
        }

        foreach ($column in @($doc.Columns)) {
            $logical = Get-PropertyValue -Object $column -Name "LogicalName"
            if ([string]::IsNullOrWhiteSpace($logical)) {
                $logical = Get-PropertyValue -Object $column -Name "SchemaName"
            }
            if (-not [string]::IsNullOrWhiteSpace($logical)) {
                $columnByTable[$tableName].Add($logical.ToLower())
            }
        }
    } catch {
        Write-Host "Warning: unable to parse column payload $($file.FullName)" -ForegroundColor Yellow
    }
}

$standardExtensions = New-Object System.Collections.Generic.List[string]
foreach ($key in $columnByTable.Keys | Sort-Object) {
    if (-not $customTableNames.Contains($key)) {
        $cols = @($columnByTable[$key] | Sort-Object -Unique)
        $standardExtensions.Add("$key (columns: $($cols -join ', '))")
    }
}

$relationshipLines = New-Object System.Collections.Generic.List[string]
foreach ($file in $payload.Relationships) {
    try {
        $doc = Get-Json -Path $file.FullName
        $rels = @()
        $rootRelationships = Get-PropertyValue -Object $doc -Name "Relationships"
        if ($null -ne $rootRelationships) {
            $rels = @($rootRelationships)
        }
        if ($rels.Count -eq 0) {
            $rels = @($doc)
        }

        foreach ($rel in $rels) {
            $relDef = Get-PropertyValue -Object $rel -Name "RelationshipDefinition"
            $schema = Get-PropertyValue -Object $rel -Name "SchemaName"
            if ([string]::IsNullOrWhiteSpace($schema)) {
                $schema = Get-PropertyValue -Object $relDef -Name "SchemaName"
            }
            $referencingEntity = Get-PropertyValue -Object $rel -Name "ReferencingEntity"
            if ([string]::IsNullOrWhiteSpace($referencingEntity)) {
                $referencingEntity = Get-PropertyValue -Object $relDef -Name "ReferencingEntity"
            }
            $referencingAttribute = Get-PropertyValue -Object $rel -Name "ReferencingAttribute"
            if ([string]::IsNullOrWhiteSpace($referencingAttribute)) {
                $referencingAttribute = Get-PropertyValue -Object $relDef -Name "ReferencingAttribute"
            }
            $referencedEntity = Get-PropertyValue -Object $rel -Name "ReferencedEntity"
            if ([string]::IsNullOrWhiteSpace($referencedEntity)) {
                $referencedEntity = Get-PropertyValue -Object $relDef -Name "ReferencedEntity"
            }

            if ([string]::IsNullOrWhiteSpace($schema)) {
                $schema = "(schema missing)"
            }

            if ([string]::IsNullOrWhiteSpace($referencingEntity) -or [string]::IsNullOrWhiteSpace($referencedEntity)) {
                $relationshipLines.Add("$schema")
            } else {
                $left = if ([string]::IsNullOrWhiteSpace($referencingAttribute)) { $referencingEntity } else { "$referencingEntity.$referencingAttribute" }
                $relationshipLines.Add("$left -> $referencedEntity ($schema)")
            }
        }
    } catch {
        Write-Host "Warning: unable to parse relationship payload $($file.FullName)" -ForegroundColor Yellow
    }
}

$formsViews = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrWhiteSpace($experienceLine)) {
    foreach ($part in @($experienceLine -split ",")) {
        $token = $part.Trim()
        if ($token -match "(?i)form|view") {
            $formsViews.Add($token)
        }
    }
}
if ($formsViews.Count -eq 0 -and $customTableNames.Count -gt 0) {
    $formsViews.Add("Starter Main Form created/updated for custom tables in payloads")
    $formsViews.Add("Active view created for custom tables in payloads")
}

$webResourceNames = New-Object System.Collections.Generic.List[string]
foreach ($file in $payload.WebResources) {
    $webResourceNames.Add($file.Name)
}
$scenarioWebFolder = Join-Path $scenarioPath "webresources"
if (Test-Path $scenarioWebFolder) {
    foreach ($file in @(Get-ChildItem -Path $scenarioWebFolder -File -Filter "*.html" -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $webResourceNames.Add($file.Name)
    }
}
$uniqueWebResources = @($webResourceNames | Sort-Object -Unique)
$webResourceNames = New-Object System.Collections.Generic.List[string]
foreach ($name in $uniqueWebResources) {
    $webResourceNames.Add($name)
}

$demoTalkTrackSummary = "(demo-talk-track.md not found)"
if (Test-Path $talkTrackPath) {
    $talkTrack = Get-Content $talkTrackPath -Raw
    $title = [regex]::Match($talkTrack, "(?m)^#\s+(.+)$").Groups[1].Value.Trim()
    $workflow = [regex]::Match($talkTrack, "(?im)^-\s+Core workflow:\s*(.+)$").Groups[1].Value.Trim()

    if (-not [string]::IsNullOrWhiteSpace($title) -and -not [string]::IsNullOrWhiteSpace($workflow)) {
        $demoTalkTrackSummary = "$title - $workflow"
    } elseif (-not [string]::IsNullOrWhiteSpace($title)) {
        $demoTalkTrackSummary = $title
    }
}

$enhancements = New-Object System.Collections.Generic.List[string]
foreach ($line in ($tasks -split "`r?`n")) {
    if ($line -match "^-\s+\[\s\]\s+(.+)$") {
        $taskLine = $matches[1].Trim()
        if ($taskLine -match "(?i)report|automation|demo data|validate|update 'docs/build-log.md'|pack and import|export and unpack") {
            $enhancements.Add($taskLine)
        }
    }
}
if ($enhancements.Count -eq 0) {
    $enhancements.Add("Validate artifacts in Maker portal and close remaining tasks in tasks.md")
}

$scenarioSummary = [regex]::Match($spec, "(?im)^##\s+Scenario Summary\s*\r?\n(.+)$").Groups[1].Value.Trim()
$solutionType = Get-PlanMetadataValue -PlanContent $plan -Label "Solution type"
$solutionUniqueName = Get-PlanMetadataValue -PlanContent $plan -Label "Solution unique name"
$publisherPrefix = Get-PlanMetadataValue -PlanContent $plan -Label "Publisher prefix"
$environment = Get-PlanMetadataValue -PlanContent $plan -Label "Environment"

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add("### Scenario and solution metadata")
$summaryLines.Add("- Scenario slug: $ScenarioSlug")
if (-not [string]::IsNullOrWhiteSpace($scenarioSummary)) { $summaryLines.Add("- Scenario summary: $scenarioSummary") }
if (-not [string]::IsNullOrWhiteSpace($environment)) { $summaryLines.Add("- Environment: $environment") }
if (-not [string]::IsNullOrWhiteSpace($solutionType)) { $summaryLines.Add("- Solution type: $solutionType") }
if (-not [string]::IsNullOrWhiteSpace($solutionUniqueName)) { $summaryLines.Add("- Solution unique name: $solutionUniqueName") }
if (-not [string]::IsNullOrWhiteSpace($publisherPrefix)) { $summaryLines.Add("- Publisher prefix: $publisherPrefix") }
$summaryLines.Add("")

$summaryLines.Add("### Tables built (standard table extensions and custom tables)")
$summaryLines.Add("- Standard table extensions:")
foreach ($line in (Get-ItemOrNone -List $standardExtensions)) { $summaryLines.Add("  - $line") }
$summaryLines.Add("- Custom tables:")
$customTableLines = New-Object System.Collections.Generic.List[string]
foreach ($line in $customTablesFromSpec) { $customTableLines.Add($line) }
foreach ($line in @($customTableNames | Sort-Object)) { $customTableLines.Add($line) }
$uniqueCustomTables = @($customTableLines | Sort-Object -Unique)
$customTableLines = New-Object System.Collections.Generic.List[string]
foreach ($line in $uniqueCustomTables) {
    $customTableLines.Add($line)
}
foreach ($line in (Get-ItemOrNone -List $customTableLines)) { $summaryLines.Add("  - $line") }
$summaryLines.Add("")

$summaryLines.Add("### Relationship map")
$relationshipOut = New-Object System.Collections.Generic.List[string]
foreach ($line in $relationshipMappings) { $relationshipOut.Add($line) }
foreach ($line in @($relationshipLines | Sort-Object -Unique)) { $relationshipOut.Add($line) }
$uniqueRelationships = @($relationshipOut | Sort-Object -Unique)
$relationshipOut = New-Object System.Collections.Generic.List[string]
foreach ($line in $uniqueRelationships) {
    $relationshipOut.Add($line)
}
foreach ($line in (Get-ItemOrNone -List $relationshipOut)) { $summaryLines.Add("- $line") }
$summaryLines.Add("")

$summaryLines.Add("### Forms and views created or updated")
foreach ($line in (Get-ItemOrNone -List $formsViews)) { $summaryLines.Add("- $line") }
$summaryLines.Add("")

$summaryLines.Add("### Web resources created or updated")
foreach ($line in (Get-ItemOrNone -List $webResourceNames)) { $summaryLines.Add("- $line") }
$summaryLines.Add("")

$summaryLines.Add("### Demo talk track")
$summaryLines.Add("- $demoTalkTrackSummary")
$summaryLines.Add("")

$summaryLines.Add("### Recommended next enhancements")
foreach ($line in @($enhancements | Select-Object -First 6)) { $summaryLines.Add("- $line") }

$summary = $summaryLines -join "`r`n"

Write-Host ""
Write-Host "--- Generated Build Summary Preview ---" -ForegroundColor Cyan
Write-Host $summary
Write-Host "--- End Preview ---" -ForegroundColor Cyan

if ($PreviewOnly) {
    Write-Host "PreviewOnly mode: README and git actions were skipped." -ForegroundColor Yellow
    exit 0
}

$updateReadme = Read-YesNo "Update README generated summary section now? (y/N)"
if ($updateReadme) {
    Set-ReadmeGeneratedSummary -ReadmeFile $readmePath -Summary $summary
    Write-Host "README generated summary section updated." -ForegroundColor Green

    $commitReadme = Read-YesNo "Stage and commit README update now? (y/N)"
    if ($commitReadme) {
        if (Show-RepoTargetDetails) {
            & git add README.md
            if ($LASTEXITCODE -ne 0) {
                throw "git add README.md failed."
            }

            $status = & git status --porcelain README.md
            if ([string]::IsNullOrWhiteSpace(($status -join "").Trim())) {
                Write-Host "No README changes to commit." -ForegroundColor Yellow
            } else {
                & git commit -m "docs: refresh generated build summary in README"
                if ($LASTEXITCODE -ne 0) {
                    throw "git commit failed."
                }
                Write-Host "README commit created." -ForegroundColor Green

                $pushMain = Read-YesNo "Push to origin/main now? (y/N)"
                if ($pushMain) {
                    & git push origin main
                    if ($LASTEXITCODE -ne 0) {
                        throw "git push origin main failed."
                    }
                    Write-Host "Pushed to origin/main." -ForegroundColor Green
                } else {
                    Write-Host "Push skipped by user." -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "Commit/push skipped by user after repository target check." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Commit step skipped by user." -ForegroundColor Yellow
    }
} else {
    Write-Host "README update skipped by user." -ForegroundColor Yellow
}

exit 0
