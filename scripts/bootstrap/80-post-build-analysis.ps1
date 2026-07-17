<#
.SYNOPSIS
    Generates a generic end-of-build analysis summary and optionally updates README markers.

.DESCRIPTION
    Reads scenario planning artifacts and payload files to produce a standard build
    summary for any wizard-driven build. Supports preview-only mode and explicit
    confirmations before README, commit, or push actions.

.PARAMETER ScenarioSlug
    Scenario folder under specs/. If omitted and there is exactly one scenario,
    that scenario is selected automatically.

.PARAMETER SpecPath
    Optional explicit path to spec markdown.

.PARAMETER PlanPath
    Optional explicit path to plan markdown.

.PARAMETER TasksPath
    Optional explicit path to tasks markdown.

.PARAMETER PayloadFolder
    Optional explicit payload root path. Defaults to payloads/ if present,
    otherwise scripts/payloads/.

.PARAMETER ReadmePath
    Optional explicit README path. Defaults to repository README.md.

.PARAMETER PreviewOnly
    Prints generated summary and exits without modifying README or running git.
#>

param(
    [string]$ScenarioSlug = "",
    [string]$SpecPath = "",
    [string]$PlanPath = "",
    [string]$TasksPath = "",
    [string]$PayloadFolder = "",
    [string]$ReadmePath = "",
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$specsRoot = Join-Path $repoRoot "specs"

function Read-YesNo {
    param([string]$Prompt)

    $raw = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $false
    }

    return @("y", "yes") -contains $raw.Trim().ToLower()
}

function Resolve-ExistingPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    try {
        return (Resolve-Path -Path $Path -ErrorAction Stop).Path
    } catch {
        return ""
    }
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

    return ""
}

function Get-MarkdownSection {
    param(
        [string]$Content,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return ""
    }

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

    if ([string]::IsNullOrWhiteSpace($PlanContent)) {
        return ""
    }

    $pattern = "(?im)^-\s+$([regex]::Escape($Label)):\s*(.+)$"
    $match = [regex]::Match($PlanContent, $pattern)
    if (-not $match.Success) {
        return ""
    }

    return $match.Groups[1].Value.Trim()
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

function Get-ItemOrNotAvailable {
    param([System.Collections.Generic.List[string]]$List)

    if ($List.Count -eq 0) {
        return @("Not available")
    }

    return @($List)
}

function Select-PayloadRoot {
    param(
        [string]$RequestedPath,
        [string]$RepoRootPath
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return (Resolve-ExistingPath -Path $RequestedPath)
    }

    $repoPayloadRoot = Join-Path $RepoRootPath "payloads"
    $scriptsPayloadRoot = Join-Path $RepoRootPath "scripts\payloads"

    if (Test-Path $repoPayloadRoot) {
        return (Resolve-Path $repoPayloadRoot).Path
    }
    if (Test-Path $scriptsPayloadRoot) {
        return (Resolve-Path $scriptsPayloadRoot).Path
    }

    return ""
}

function Get-AllPayloadFiles {
    param([string]$PayloadRoot)

    if ([string]::IsNullOrWhiteSpace($PayloadRoot) -or -not (Test-Path $PayloadRoot)) {
        return [pscustomobject]@{
            Tables = @()
            Columns = @()
            Relationships = @()
            WebResources = @()
        }
    }

    return [pscustomobject]@{
        Tables = @(Get-ChildItem -Path $PayloadRoot -Filter "table-*.json" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Unique)
        Columns = @(Get-ChildItem -Path $PayloadRoot -Filter "columns-*.json" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Unique)
        Relationships = @(Get-ChildItem -Path $PayloadRoot -Filter "relationships-*.json" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Unique)
        WebResources = @(Get-ChildItem -Path $PayloadRoot -Filter "webresource-*.json" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Unique)
    }
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
    param([string]$ExpectedRepoRoot)

    Write-Host ""
    Write-Host "Repository target safety check:" -ForegroundColor Cyan

    $top = (& git rev-parse --show-toplevel 2>$null)
    $branch = (& git branch --show-current 2>$null)
    $remote = (& git remote -v 2>$null)

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Unable to read git repository details. Skipping git actions." -ForegroundColor Yellow
        return $false
    }

    $topPath = ($top -join "`n").Trim()

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

    if (-not [string]::IsNullOrWhiteSpace($ExpectedRepoRoot)) {
        $expected = (Resolve-Path $ExpectedRepoRoot).Path
        if ($topPath -ne $expected) {
            Write-Host ""
            Write-Host "Git top-level does not match script repository root." -ForegroundColor Yellow
            Write-Host "Expected: $expected" -ForegroundColor DarkGray
            Write-Host "Actual:   $topPath" -ForegroundColor DarkGray
        }
    }

    return (Read-YesNo "Proceed with commit/push in this repository target? (y/N)")
}

Write-Host ""
Write-Host "=== End-of-Build Analysis ===" -ForegroundColor Cyan

$ScenarioSlug = Get-ScenarioSlug -RequestedSlug $ScenarioSlug -SpecsRootPath $specsRoot
$scenarioPath = if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) { "" } else { Join-Path $specsRoot $ScenarioSlug }

if ([string]::IsNullOrWhiteSpace($SpecPath)) {
    if (-not [string]::IsNullOrWhiteSpace($scenarioPath)) {
        $SpecPath = Join-Path $scenarioPath "spec.md"
    }
}
if ([string]::IsNullOrWhiteSpace($PlanPath)) {
    if (-not [string]::IsNullOrWhiteSpace($scenarioPath)) {
        $PlanPath = Join-Path $scenarioPath "plan.md"
    }
}
if ([string]::IsNullOrWhiteSpace($TasksPath)) {
    if (-not [string]::IsNullOrWhiteSpace($scenarioPath)) {
        $TasksPath = Join-Path $scenarioPath "tasks.md"
    }
}
if ([string]::IsNullOrWhiteSpace($ReadmePath)) {
    $ReadmePath = Join-Path $repoRoot "README.md"
}

$resolvedSpecPath = Resolve-ExistingPath -Path $SpecPath
$resolvedPlanPath = Resolve-ExistingPath -Path $PlanPath
$resolvedTasksPath = Resolve-ExistingPath -Path $TasksPath
$resolvedReadmePath = Resolve-ExistingPath -Path $ReadmePath
$resolvedPayloadRoot = Select-PayloadRoot -RequestedPath $PayloadFolder -RepoRootPath $repoRoot

$spec = if ([string]::IsNullOrWhiteSpace($resolvedSpecPath)) { "" } else { Get-Content $resolvedSpecPath -Raw }
$plan = if ([string]::IsNullOrWhiteSpace($resolvedPlanPath)) { "" } else { Get-Content $resolvedPlanPath -Raw }
$tasks = if ([string]::IsNullOrWhiteSpace($resolvedTasksPath)) { "" } else { Get-Content $resolvedTasksPath -Raw }
$payload = Get-AllPayloadFiles -PayloadRoot $resolvedPayloadRoot

$standardReuseBlock = Get-MarkdownSection -Content $spec -Heading "Standard reused tables (display -> logical)"
$customTablesBlock = Get-MarkdownSection -Content $spec -Heading "Custom tables to create (input -> generated logical)"
$relationshipMappingBlock = Get-MarkdownSection -Content $spec -Heading "Relationships to create"
$experienceLineMatch = [regex]::Match($spec, "(?im)^##\s+Required Experience and Artifacts\s*\r?\n(.+)$")
$experienceLine = if ($experienceLineMatch.Success) { $experienceLineMatch.Groups[1].Value.Trim() } else { "" }

$standardTablesFromSpec = @(Get-BulletListValues -Block $standardReuseBlock)
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
foreach ($line in @($standardTablesFromSpec | Sort-Object -Unique)) {
    $standardExtensions.Add($line)
}
foreach ($key in $columnByTable.Keys | Sort-Object) {
    if (-not $customTableNames.Contains($key)) {
        $cols = @($columnByTable[$key] | Sort-Object -Unique)
        $standardExtensions.Add("$key (columns: $($cols -join ', '))")
    }
}
$uniqueStandardExtensions = @($standardExtensions | Sort-Object -Unique)
$standardExtensions = New-Object System.Collections.Generic.List[string]
foreach ($line in $uniqueStandardExtensions) {
    $standardExtensions.Add($line)
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
if (-not [string]::IsNullOrWhiteSpace($scenarioPath)) {
    $scenarioWebFolder = Join-Path $scenarioPath "webresources"
    if (Test-Path $scenarioWebFolder) {
        foreach ($file in @(Get-ChildItem -Path $scenarioWebFolder -File -Filter "*.html" -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $webResourceNames.Add($file.Name)
        }
    }
}
$uniqueWebResources = @($webResourceNames | Sort-Object -Unique)
$webResourceNames = New-Object System.Collections.Generic.List[string]
foreach ($name in $uniqueWebResources) {
    $webResourceNames.Add($name)
}

$talkTrackPath = if ([string]::IsNullOrWhiteSpace($scenarioPath)) { "" } else { Join-Path $scenarioPath "demo-talk-track.md" }
$demoTalkTrackSummary = "Not available"
if (-not [string]::IsNullOrWhiteSpace($talkTrackPath) -and (Test-Path $talkTrackPath)) {
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
        if ($taskLine -match "(?i)report|automation|demo data|validate|build-log|pack|import|export|unpack") {
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
$summaryLines.Add("- Scenario slug: $(if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) { 'Not available' } else { $ScenarioSlug })")
$summaryLines.Add("- Scenario summary: $(if ([string]::IsNullOrWhiteSpace($scenarioSummary)) { 'Not available' } else { $scenarioSummary })")
$summaryLines.Add("- Environment: $(if ([string]::IsNullOrWhiteSpace($environment)) { 'Not available' } else { $environment })")
$summaryLines.Add("- Solution type: $(if ([string]::IsNullOrWhiteSpace($solutionType)) { 'Not available' } else { $solutionType })")
$summaryLines.Add("- Solution unique name: $(if ([string]::IsNullOrWhiteSpace($solutionUniqueName)) { 'Not available' } else { $solutionUniqueName })")
$summaryLines.Add("- Publisher prefix: $(if ([string]::IsNullOrWhiteSpace($publisherPrefix)) { 'Not available' } else { $publisherPrefix })")
$summaryLines.Add("")

$summaryLines.Add("### Tables built (standard table extensions and custom tables)")
$summaryLines.Add("- Standard table extensions:")
foreach ($line in (Get-ItemOrNotAvailable -List $standardExtensions)) {
    $summaryLines.Add("  - $line")
}
$summaryLines.Add("- Custom tables:")
$customTableLines = New-Object System.Collections.Generic.List[string]
foreach ($line in $customTablesFromSpec) {
    $customTableLines.Add($line)
}
foreach ($line in @($customTableNames | Sort-Object)) {
    $customTableLines.Add($line)
}
$uniqueCustomTables = @($customTableLines | Sort-Object -Unique)
$customTableLines = New-Object System.Collections.Generic.List[string]
foreach ($line in $uniqueCustomTables) {
    $customTableLines.Add($line)
}
foreach ($line in (Get-ItemOrNotAvailable -List $customTableLines)) {
    $summaryLines.Add("  - $line")
}
$summaryLines.Add("")

$summaryLines.Add("### Relationship map")
$relationshipOut = New-Object System.Collections.Generic.List[string]
foreach ($line in $relationshipMappings) {
    $relationshipOut.Add($line)
}
foreach ($line in @($relationshipLines | Sort-Object -Unique)) {
    $relationshipOut.Add($line)
}
$uniqueRelationships = @($relationshipOut | Sort-Object -Unique)
$relationshipOut = New-Object System.Collections.Generic.List[string]
foreach ($line in $uniqueRelationships) {
    $relationshipOut.Add($line)
}
foreach ($line in (Get-ItemOrNotAvailable -List $relationshipOut)) {
    $summaryLines.Add("- $line")
}
$summaryLines.Add("")

$summaryLines.Add("### Forms and views created or updated")
foreach ($line in (Get-ItemOrNotAvailable -List $formsViews)) {
    $summaryLines.Add("- $line")
}
$summaryLines.Add("")

$summaryLines.Add("### Web resources created or updated")
foreach ($line in (Get-ItemOrNotAvailable -List $webResourceNames)) {
    $summaryLines.Add("- $line")
}
$summaryLines.Add("")

$summaryLines.Add("### Demo talk track")
$summaryLines.Add("- $demoTalkTrackSummary")
$summaryLines.Add("")

$summaryLines.Add("### Recommended next enhancements")
foreach ($line in @($enhancements | Select-Object -First 6)) {
    $summaryLines.Add("- $line")
}

$summary = $summaryLines -join "`r`n"

Write-Host ""
Write-Host "--- Generated Build Summary Preview ---" -ForegroundColor Cyan
Write-Host $summary
Write-Host "--- End Preview ---" -ForegroundColor Cyan

if ($PreviewOnly) {
    Write-Host "PreviewOnly mode: README and git actions were skipped." -ForegroundColor Yellow
    exit 0
}

if ([string]::IsNullOrWhiteSpace($resolvedReadmePath)) {
    Write-Host "README not found. Skipping README and git actions." -ForegroundColor Yellow
    exit 0
}

$updateReadme = Read-YesNo "Update README generated summary section now? (y/N)"
if ($updateReadme) {
    Set-ReadmeGeneratedSummary -ReadmeFile $resolvedReadmePath -Summary $summary
    Write-Host "README generated summary section updated." -ForegroundColor Green

    $commitReadme = Read-YesNo "Stage and commit README update now? (y/N)"
    if ($commitReadme) {
        if (Show-RepoTargetDetails -ExpectedRepoRoot $repoRoot) {
            Push-Location $repoRoot
            try {
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

                    $currentBranch = (& git branch --show-current 2>$null)
                    $branchName = ($currentBranch -join "").Trim()
                    if ([string]::IsNullOrWhiteSpace($branchName)) {
                        $branchName = "main"
                    }

                    $pushThisBranch = Read-YesNo "Push to origin/$branchName now? (y/N)"
                    if ($pushThisBranch) {
                        & git push origin $branchName
                        if ($LASTEXITCODE -ne 0) {
                            throw "git push origin $branchName failed."
                        }
                        Write-Host "Pushed to origin/$branchName." -ForegroundColor Green
                    } else {
                        Write-Host "Push skipped by user." -ForegroundColor Yellow
                    }
                }
            } finally {
                Pop-Location
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
