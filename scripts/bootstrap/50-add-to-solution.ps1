<#
.SYNOPSIS
    Adds entities referenced by payload files to the target solution.
    Safe to rerun — adding an already-included component is a no-op.

.PARAMETER EnvironmentUrl     Defaults to $env:DV_ENVIRONMENT_URL.
.PARAMETER AccessToken        Defaults to $env:DV_TOKEN.
.PARAMETER SolutionUniqueName Defaults to $env:DV_SOLUTION_NAME.
.PARAMETER PayloadsFolder     Folder containing table/column/relationship payloads. Defaults to ../../payloads.

.EXAMPLE
    pwsh ./scripts/bootstrap/50-add-to-solution.ps1
    pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -SolutionUniqueName "MyApp"
#>

param(
    [string]$EnvironmentUrl     = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken        = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix    = $env:DV_PUBLISHER_PREFIX,
    [string]$PayloadsFolder     = "",
    [string]$ScenarioSlug       = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl     = $global:DV_ENVIRONMENT_URL
    $AccessToken        = $global:DV_TOKEN
    $SolutionUniqueName = $SolutionUniqueName -ne "" ? $SolutionUniqueName : $global:DV_SOLUTION_NAME
    $PublisherPrefix    = $PublisherPrefix    -ne "" ? $PublisherPrefix    : $global:DV_PUBLISHER_PREFIX
}

foreach ($v in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName)) {
    if ([string]::IsNullOrWhiteSpace($v)) {
        Write-Host "Missing required values. Run 10-auth-connect.ps1 first." -ForegroundColor Red
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "payloads"
}

if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    $scenarioDirs = @(Get-ChildItem -Path (Join-Path $repoRoot "specs") -Directory -ErrorAction SilentlyContinue)
    if ($scenarioDirs.Count -eq 1) {
        $ScenarioSlug = $scenarioDirs[0].Name
    }
}

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "") {
    $h = @{ "Authorization"="Bearer $AccessToken"; "Content-Type"="application/json";
            "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Accept"="application/json" }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
}

function Add-EntityName {
    param(
        [System.Collections.Generic.HashSet[string]]$Set,
        [string]$Name
    )

    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        [void]$Set.Add($Name.ToLower())
    }
}

function Get-PayloadEntityNames {
    param([string]$Folder)

    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    $tableFiles = @(Get-ChildItem -Path $Folder -Filter "table-*.json" -ErrorAction SilentlyContinue)
    foreach ($file in $tableFiles) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $schemaName = $doc.EntityDefinition.SchemaName ?? $doc.SchemaName
        Add-EntityName -Set $names -Name $schemaName
    }

    $columnFiles = @(Get-ChildItem -Path $Folder -Filter "columns-*.json" -ErrorAction SilentlyContinue)
    foreach ($file in $columnFiles) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        Add-EntityName -Set $names -Name $doc.TableLogicalName
    }

    $relationshipFiles = @(Get-ChildItem -Path $Folder -Filter "relationships-*.json" -ErrorAction SilentlyContinue)
    foreach ($file in $relationshipFiles) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $rels = @($doc.Relationships ?? $doc)
        foreach ($rel in $rels) {
            Add-EntityName -Set $names -Name ($rel.ReferencedEntity ?? $rel.RelationshipDefinition.ReferencedEntity)
            Add-EntityName -Set $names -Name ($rel.ReferencingEntity ?? $rel.RelationshipDefinition.ReferencingEntity)
            Add-EntityName -Set $names -Name ($rel.Entity1LogicalName ?? $rel.RelationshipDefinition.Entity1LogicalName)
            Add-EntityName -Set $names -Name ($rel.Entity2LogicalName ?? $rel.RelationshipDefinition.Entity2LogicalName)
        }
    }

    return @($names)
}

function Get-EntityDefinitionByLogicalName {
    param([string]$LogicalName)

    try {
        return Invoke-Dv "Get" "EntityDefinitions(LogicalName='$LogicalName')?`$select=LogicalName,MetadataId"
    } catch {
        return $null
    }
}

function Test-TruthyValue {
    param([string]$Value)

    $normalized = ($Value ?? "").Trim().ToLower()
    return @("yes", "y", "true", "1") -contains $normalized
}

function Get-ReportWebResourceNames {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug,
        [string]$PublisherPrefix
    )

    if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
        return @()
    }

    $scenarioFolder = Join-Path (Join-Path $RepoRoot "specs") $ScenarioSlug
    $answersPath = Join-Path $scenarioFolder "answers.md"
    $webResourceFolder = Join-Path $scenarioFolder "webresources"
    if (-not (Test-Path $answersPath) -or -not (Test-Path $webResourceFolder)) {
        return @()
    }

    $answersText = Get-Content $answersPath -Raw
    $matchLine = [regex]::Match($answersText, '(?im)^19\.\s*Create optional HTML report web resources.*:\s*(.+)$')
    $enabledRaw = if ($matchLine.Success) {
        $matchLine.Groups[1].Value.Trim()
    } else {
        $optionalBlock = [regex]::Match($answersText, '(?ims)^##\s+Optional Report Web Resources\s*\r?\n(.*?)(?=^##\s+|\z)')
        if ($optionalBlock.Success) {
            [regex]::Match($optionalBlock.Groups[1].Value, '(?im)^-\s*Enabled:\s*(.+)$').Groups[1].Value.Trim()
        } else {
            ""
        }
    }

    if (-not (Test-TruthyValue -Value $enabledRaw)) {
        return @()
    }

    $normalizedPrefix = ($PublisherPrefix ?? "").Trim().ToLower()
    if ([string]::IsNullOrWhiteSpace($normalizedPrefix)) {
        return @()
    }

    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $htmlFiles = @(Get-ChildItem -Path $webResourceFolder -Filter "*.html" -ErrorAction SilentlyContinue | Sort-Object Name)
    foreach ($file in $htmlFiles) {
        [void]$names.Add("$normalizedPrefix`_reports/$($file.Name)")
    }

    return @($names)
}

function Get-WebResourceByName {
    param([string]$Name)

    $safeName = $Name.Replace("'", "''")
    $resp = Invoke-Dv "Get" "webresourceset?`$select=webresourceid,name&`$filter=name eq '$safeName'"
    return @($resp.value | Select-Object -First 1)
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

Write-Host ""
Write-Host "=== Add to Solution ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Solution:    $SolutionUniqueName"
Write-Host "  Payloads:    $PayloadsFolder"
Write-Host ""

# Verify solution exists
$sol = (Invoke-Dv "Get" "solutions?`$filter=uniquename eq '$SolutionUniqueName'&`$select=solutionid,uniquename").value | Select-Object -First 1
if ($null -eq $sol) {
    Write-Host "Solution '$SolutionUniqueName' not found in this environment." -ForegroundColor Red
    Write-Host "Create it first in the Power Platform Maker portal or with: pac solution create"
    exit 1
}
Write-Host "  Solution ID: $($sol.solutionid)" -ForegroundColor DarkGray

$entityNames = @(Get-PayloadEntityNames -Folder $PayloadsFolder)
$reportWebResourceNames = @(Get-ReportWebResourceNames -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PublisherPrefix $PublisherPrefix)

if ($entityNames.Count -eq 0 -and $reportWebResourceNames.Count -eq 0) {
    Write-Host "No payload entity references or report web resources were discovered." -ForegroundColor Yellow
    Write-Host "Add table/column/relationship payloads or generate report web resources first, then rerun."
    exit 0
}

Write-Host "  Payload-referenced entities found: $($entityNames.Count)"
Write-Host "  Report web resources found:      $($reportWebResourceNames.Count)"
Write-Host ""

$added = 0; $skipped = 0; $failed = 0
# ComponentType 1 = Entity
foreach ($logicalName in $entityNames | Sort-Object) {
    Write-Host "  $logicalName " -NoNewline

    $entity = Get-EntityDefinitionByLogicalName -LogicalName $logicalName
    if ($null -eq $entity -or [string]::IsNullOrWhiteSpace($entity.MetadataId)) {
        Write-Host "(not found — skipped)" -ForegroundColor Yellow
        $skipped++
        continue
    }

    try {
        $body = @{ ComponentId = $entity.MetadataId; ComponentType = 1; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $true } | ConvertTo-Json -Compress
        Invoke-Dv "Post" "AddSolutionComponent" $body | Out-Null
        Write-Host "(added)" -ForegroundColor Green
        $added++
    } catch {
        if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
            Write-Host "(already in solution)" -ForegroundColor DarkGray; $skipped++
        } else {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red; $failed++
        }
    }
}

if ($reportWebResourceNames.Count -gt 0) {
    $webResourceComponentType = Get-WebResourceComponentType
    Write-Host ""
    Write-Host "Adding report web resources (ComponentType $webResourceComponentType)..." -ForegroundColor Cyan

    foreach ($name in $reportWebResourceNames) {
        Write-Host "  $name " -NoNewline
        $wr = @(Get-WebResourceByName -Name $name)
        if ($wr.Count -eq 0 -or [string]::IsNullOrWhiteSpace($wr[0].webresourceid)) {
            Write-Host "(not found — run 65-build-web-resources first)" -ForegroundColor Yellow
            $skipped++
            continue
        }

        try {
            $body = @{ ComponentId = $wr[0].webresourceid; ComponentType = $webResourceComponentType; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $true } | ConvertTo-Json -Compress
            Invoke-Dv "Post" "AddSolutionComponent" $body | Out-Null
            Write-Host "(added)" -ForegroundColor Green
            $added++
        } catch {
            if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
                Write-Host "(already in solution)" -ForegroundColor DarkGray
                $skipped++
            } else {
                Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
                $failed++
            }
        }
    }
}

Write-Host ""
Write-Host "Solution components — added: $added  skipped: $skipped  failed: $failed"
if ($failed -gt 0) { exit 1 }
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/60-build-forms-views.ps1"

