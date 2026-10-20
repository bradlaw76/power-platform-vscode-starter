<#
=============================================================================
COMPONENT:    Add To Solution
FILE:         scripts/bootstrap/50-add-to-solution.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Dataverse Web API | Power Platform Solution Model

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Adds approved components to the target solution so created or reused metadata
travels as a managed build unit.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            bootstrap step
- Inputs:          solution identity, payload-derived components, environment
- Outputs:         solution component membership updates and build artifacts
- Dependencies:    Dataverse Web API, solution helpers, planning artifacts
- Side Effects:    mutates solution composition in the target environment

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Solution identity must already be validated.
2. Required metadata components must already exist.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Required components are added to the intended solution.
✔ Reruns avoid duplicating solution membership where possible.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Do not add components outside the approved scenario scope.
- Keep solution composition rerunnable and reviewable.
- Update this header when the step contract materially changes.
=============================================================================
#>

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
    [string]$ScenarioSlug       = "",
    [bool]$FailIfSolutionHasForeignTables = $true,
    [bool]$EnableContaminationScan = $true,
    [bool]$EnableArtifactManifest = $true,
    [bool]$StrictMode = $true,
    [bool]$AllowContaminatedSolution = $false,
    [switch]$InventoryOnly,
    [switch]$EnforceExportGate,
    [switch]$PublishScoped
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$telemetryHelper = Join-Path $PSScriptRoot "helpers\wizard-telemetry.ps1"
if (Test-Path $telemetryHelper) {
    . $telemetryHelper
    Initialize-WizardStepTelemetry -RepoRoot $repoRoot -StepName "50-add-to-solution.ps1"
}

$solutionIsolationHelper = Join-Path $PSScriptRoot "helpers\solution-isolation.ps1"
if (-not (Test-Path $solutionIsolationHelper)) {
    Write-Host "Missing helper script: $solutionIsolationHelper" -ForegroundColor Red
    exit 1
}

. $solutionIsolationHelper

$hardeningHelper = Join-Path $PSScriptRoot "helpers\wizard-hardening.ps1"
if (Test-Path $hardeningHelper) {
    . $hardeningHelper
}

$dataverseRuntimeHelper = Join-Path $PSScriptRoot "helpers\dataverse-runtime.ps1"
if (-not (Test-Path -LiteralPath $dataverseRuntimeHelper -PathType Leaf)) {
    throw "Dataverse runtime helper not found: $dataverseRuntimeHelper"
}
. $dataverseRuntimeHelper

$envFile = Join-Path $repoRoot ".env.ps1"
if (Test-Path $envFile) {
    . $envFile
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
        $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        $AccessToken = $global:DV_TOKEN
    }
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
        $SolutionUniqueName = $global:DV_SOLUTION_NAME
    }
    if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) {
        $PublisherPrefix = $global:DV_PUBLISHER_PREFIX
    }
}

foreach ($v in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName)) {
    if ([string]::IsNullOrWhiteSpace($v)) {
        Write-Host "Missing required values. Run 10-auth-connect.ps1 first." -ForegroundColor Red
        exit 1
    }
}

if (-not [string]::IsNullOrWhiteSpace($ScenarioSlug) -and (Get-Command Get-WizardScenarioContext -ErrorAction SilentlyContinue)) {
    $scenarioContext = Get-WizardScenarioContext -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder
    $PayloadsFolder = $scenarioContext.ScenarioPayloadFolder
} elseif ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path $repoRoot "payloads"
}

if (-not (Test-Path $PayloadsFolder)) {
    Write-Host "Payload folder not found: $PayloadsFolder" -ForegroundColor Red
    Write-Host "Expected payload location is the repo root 'payloads/' folder." -ForegroundColor Yellow
    exit 1
}

if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
    $scenarioDirs = @(Get-ChildItem -Path (Join-Path $repoRoot "specs") -Directory -ErrorAction SilentlyContinue)
    if ($scenarioDirs.Count -eq 1) {
        $ScenarioSlug = $scenarioDirs[0].Name
    }
}

if ($EnableArtifactManifest -and (Get-Command Initialize-WizardArtifactManifest -ErrorAction SilentlyContinue)) {
    Initialize-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix | Out-Null
}

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "") {
    $h = @{ "Authorization"="Bearer $AccessToken"; "Content-Type"="application/json";
            "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Accept"="application/json" }
    $requestBody = if ([string]::IsNullOrWhiteSpace($Body)) { $null } else { $Body }
    return Invoke-WizardDataverseRequest -Method $Method -Path $Path -EnvironmentUrl $EnvironmentUrl `
        -AccessToken $AccessToken -Body $requestBody
}

function Test-SolutionComponentMembership {
    param(
        [string]$SolutionId,
        [string]$ObjectId,
        [int]$ComponentType
    )

    $response = Invoke-Dv "Get" "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $SolutionId and objectid eq $ObjectId and componenttype eq $ComponentType"
    return @($response.value).Count -gt 0
}

function Add-SolutionComponentManifestItem {
    param(
        [string]$Name,
        [string]$ComponentKind,
        [string]$Status,
        [string]$Reason = ""
    )

    if (-not $EnableArtifactManifest -or -not (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
        return
    }
    $details = @{ componentKind = $ComponentKind }
    if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        $details.reason = $Reason
    }
    Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName `
        -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $Name -Status $Status `
        -Step '50-add-to-solution.ps1' -Details $details | Out-Null
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

function Get-SolutionComponentTypeMap {
    $map = @{}
    $meta = Invoke-Dv "Get" "EntityDefinitions(LogicalName='solutioncomponent')/Attributes(LogicalName='componenttype')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName&`$expand=OptionSet"
    foreach ($opt in @($meta.OptionSet.Options)) {
        $label = $opt.Label.UserLocalizedLabel.Label
        if (-not [string]::IsNullOrWhiteSpace($label)) {
            $map[$label] = [int]$opt.Value
        }
    }
    return $map
}

function Get-ComponentTypeValue {
    param(
        [hashtable]$Map,
        [string[]]$Labels,
        [int]$Fallback = -1
    )

    foreach ($label in @($Labels)) {
        if ($Map.ContainsKey($label)) {
            return [int]$Map[$label]
        }
    }

    return $Fallback
}

function Get-SolutionComponentInventory {
    param(
        [scriptblock]$InvokeGet,
        [string]$SolutionId
    )

    $typeMap = Get-SolutionComponentTypeMap
    $entityType = Get-ComponentTypeValue -Map $typeMap -Labels @('Entity') -Fallback 1
    $attributeType = Get-ComponentTypeValue -Map $typeMap -Labels @('Attribute') -Fallback 2
    $globalChoiceType = Get-ComponentTypeValue -Map $typeMap -Labels @('Option Set', 'OptionSet', 'Global Choice') -Fallback 9
    $relationshipTypes = @(
        Get-ComponentTypeValue -Map $typeMap -Labels @('Entity Relationship', 'Relationship') -Fallback 10
        Get-ComponentTypeValue -Map $typeMap -Labels @('Entity Relationship Role', 'Relationship Role') -Fallback 11
    ) | Select-Object -Unique
    $webResourceType = Get-ComponentTypeValue -Map $typeMap -Labels @('Web Resource', 'WebResource') -Fallback 61
    $systemFormType = Get-ComponentTypeValue -Map $typeMap -Labels @('System Form', 'SystemForm') -Fallback 60
    $savedQueryType = Get-ComponentTypeValue -Map $typeMap -Labels @('Saved Query', 'SavedQuery') -Fallback 26
    $processType = Get-ComponentTypeValue -Map $typeMap -Labels @('Process') -Fallback 29
    $appModuleType = Get-ComponentTypeValue -Map $typeMap -Labels @('App Module', 'Model-driven App') -Fallback 80
    $siteMapType = Get-ComponentTypeValue -Map $typeMap -Labels @('Site Map', 'SiteMap') -Fallback 62
    $chartType = Get-ComponentTypeValue -Map $typeMap -Labels @('Saved Query Visualization', 'SavedQueryVisualization') -Fallback 59
    $roleType = Get-ComponentTypeValue -Map $typeMap -Labels @('Role', 'Security Role') -Fallback 20

    $items = New-Object System.Collections.Generic.List[object]
    $components = @(Invoke-SolutionIsolationPagedGet -InvokeGet $InvokeGet -Path "solutioncomponents?`$select=solutioncomponentid,objectid,_solutionid_value,componenttype,rootcomponentbehavior")
    foreach ($component in $components) {
        if (("$($component._solutionid_value)").Trim().ToLowerInvariant() -ne $SolutionId.Trim().ToLowerInvariant()) {
            continue
        }

        $componentType = [int]$component.componenttype
        $objectId = ("$($component.objectid)").Trim()

        if ($componentType -eq $entityType) {
            $entity = Get-EntityDefinitionByMetadataId -InvokeGet $InvokeGet -MetadataId $objectId
            if ($null -ne $entity) {
                $items.Add([pscustomobject]@{ Kind = 'table'; Category = 'tables'; Name = $entity.LogicalName; ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType; RootComponentBehavior = $component.rootcomponentbehavior }) | Out-Null
            }
            continue
        }

        if ($componentType -eq $globalChoiceType) {
            $choice = & $InvokeGet "GlobalOptionSetDefinitions($objectId)?`$select=Name,MetadataId"
            if ($null -eq $choice -or [string]::IsNullOrWhiteSpace("$($choice.Name)") -or
                ([guid]$choice.MetadataId) -ne ([guid]$objectId)) { throw 'Global Choice inventory identity could not be verified.' }
            $items.Add([pscustomobject]@{
                Kind='global-choice'; Category='global-choices'; Name=$choice.Name; ObjectId=$objectId
                SolutionComponentId="$($component.solutioncomponentid)"; ComponentType=$componentType
            }) | Out-Null
            continue
        }
        if ($componentType -eq $attributeType) {
            try {
                $entities = Invoke-Dv "Get" "EntityDefinitions?`$select=LogicalName&`$expand=Attributes(`$select=LogicalName,MetadataId;`$filter=MetadataId eq $objectId)"
                $owner = @($entities.value | Where-Object { @($_.Attributes).Count -gt 0 } | Select-Object -First 1)
                if ($owner.Count -gt 0) {
                    $items.Add([pscustomobject]@{ Kind = 'column'; Category = 'columns'; Name = "$($owner[0].LogicalName).$($owner[0].Attributes[0].LogicalName)"; ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
                }
            } catch {}
            continue
        }

        if ($componentType -in $relationshipTypes) {
            try {
                $relationship = Invoke-Dv "Get" "RelationshipDefinitions($objectId)?`$select=SchemaName,MetadataId"
                $items.Add([pscustomobject]@{ Kind = 'relationship'; Category = 'relationships'; Name = $relationship.SchemaName; ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
            } catch {}
            continue
        }

        if ($componentType -eq $webResourceType) {
            try {
                $wr = Invoke-Dv "Get" "webresourceset($objectId)?`$select=name"
                $items.Add([pscustomobject]@{ Kind = 'webresource'; Category = 'web-resources'; Name = $wr.name; ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
            } catch {}
            continue
        }

        if ($componentType -eq $savedQueryType) {
            try {
                $view = Invoke-Dv "Get" "savedqueries($objectId)?`$select=name,returnedtypecode"
                $normalizedName = if (("$($view.name)") -like 'Active*') { "$($view.returnedtypecode)|active" } else { "$($view.returnedtypecode)|$($view.name)" }
                $items.Add([pscustomobject]@{ Kind = 'view'; Category = 'views'; Name = $normalizedName; ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
            } catch {}
            continue
        }

        if ($componentType -eq $systemFormType) {
            try {
                $form = Invoke-Dv "Get" "systemforms($objectId)?`$select=name,objecttypecode,type"
                $kind = if ([int]$form.type -eq 2) { 'form' } else { 'dashboard' }
                $normalizedName = if ($kind -eq 'form') { "$($form.objecttypecode)|main" } else { "$($form.name)" }
                $category = if ($kind -eq 'form') { 'forms' } else { 'dashboards' }
                $items.Add([pscustomobject]@{ Kind = $kind; Category = $category; Name = $normalizedName; ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
            } catch {}
            continue
        }

        if ($componentType -eq $processType) {
            try {
                $workflow = Invoke-Dv "Get" "workflows($objectId)?`$select=name,uniquename,category"
                $kind = if ([int]$workflow.category -eq 4) { 'bpf' } else { 'flow' }
                $items.Add([pscustomobject]@{ Kind = $kind; Category = 'flows'; Name = ($workflow.uniquename ?? $workflow.name); ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
            } catch {}
            continue
        }

        if ($componentType -eq $appModuleType) {
            try {
                $app = Invoke-Dv "Get" "appmodules($objectId)?`$select=name,uniquename"
                $items.Add([pscustomobject]@{ Kind = 'appmodule'; Category = 'model-driven-apps'; Name = ($app.uniquename ?? $app.name); ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
            } catch {}
            continue
        }

        if ($componentType -eq $siteMapType) {
            try {
                $siteMap = Invoke-Dv "Get" "sitemaps($objectId)?`$select=sitemapnameunique,sitemapname"
                $items.Add([pscustomobject]@{ Kind = 'sitemap'; Category = 'sitemap-updates'; Name = ($siteMap.sitemapnameunique ?? $siteMap.sitemapname); ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
            } catch {}
            continue
        }

        if ($componentType -eq $chartType) {
            try {
                $chart = Invoke-Dv "Get" "savedqueryvisualizations($objectId)?`$select=name,primaryentitytypecode"
                $items.Add([pscustomobject]@{ Kind = 'chart'; Category = 'charts'; Name = "$($chart.primaryentitytypecode)|$($chart.name)"; ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
            } catch {}
            continue
        }

        if ($componentType -eq $roleType) {
            try {
                $role = Invoke-Dv "Get" "roles($objectId)?`$select=name"
                $items.Add([pscustomobject]@{ Kind = 'role'; Category = 'security-roles'; Name = "$($role.name)"; ObjectId = $objectId; SolutionComponentId = "$($component.solutioncomponentid)"; ComponentType = $componentType }) | Out-Null
            } catch {}
        }
    }

    return @($items.ToArray())
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
    Write-Host "Create it first in the Power Platform Maker portal or through an approved Dataverse Web API workflow; the installed PAC CLI does not provide an online solution-create command."
    exit 1
}
Write-Host "  Solution ID: $($sol.solutionid)" -ForegroundColor DarkGray

$invokeDvGet = { param($path) Invoke-Dv "Get" $path }
$allEntityNames = @(Get-PayloadEntityNames -Folder $PayloadsFolder)
$expectedArtifacts = New-WizardExpectedArtifacts -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder -PublisherPrefix $PublisherPrefix
$entityNames = @($expectedArtifacts.Tables)
$solutionEntityNames = @(@($expectedArtifacts.Tables) + @($expectedArtifacts.DependencyTables) | Sort-Object -Unique)
$reportWebResourceNames = @(Get-ReportWebResourceNames -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PublisherPrefix $PublisherPrefix)
$tableIsolationReport = Get-SolutionTableIsolationReport -InvokeGet $invokeDvGet -SolutionId "$($sol.solutionid)" -ExpectedEntityNames $solutionEntityNames

if ($InventoryOnly) {
    if (-not (Get-Command New-WizardExpectedArtifacts -ErrorAction SilentlyContinue)) {
        throw 'Inventory-only mode requires scripts/bootstrap/helpers/wizard-hardening.ps1.'
    }

    $expectedByCategory = ConvertTo-SolutionExpectedCategoryMap -ExpectedArtifacts $expectedArtifacts
    $inventory = @(Get-SolutionComponentInventory -InvokeGet $invokeDvGet -SolutionId "$($sol.solutionid)")
    $relationshipTables = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'relationships-*.json' -File -ErrorAction SilentlyContinue)) {
        $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($relationship in @($document.Relationships)) {
            $definition = Get-WizardOptionalPropertyValue -InputObject $relationship -PropertyName 'RelationshipDefinition'
            $schemaName = (Get-WizardOptionalPropertyValue -InputObject $relationship -PropertyName 'SchemaName') ??
                (Get-WizardOptionalPropertyValue -InputObject $definition -PropertyName 'SchemaName')
            if ([string]::IsNullOrWhiteSpace($schemaName)) { continue }
            $relationshipEntities = [System.Collections.Generic.List[string]]::new()
            foreach ($propertyName in @('ReferencedEntity', 'ReferencingEntity', 'Entity1LogicalName', 'Entity2LogicalName')) {
                $entityName = (Get-WizardOptionalPropertyValue -InputObject $relationship -PropertyName $propertyName) ??
                    (Get-WizardOptionalPropertyValue -InputObject $definition -PropertyName $propertyName)
                if (-not [string]::IsNullOrWhiteSpace($entityName)) {
                    [void]$relationshipEntities.Add($entityName)
                }
            }
            $relationshipTables[$schemaName] = @($relationshipEntities.ToArray())
        }
    }
    $inventory = @(Expand-SolutionInheritedInventory -ExpectedByCategory $expectedByCategory -CurrentInventory $inventory -RelationshipTables $relationshipTables)
    $failedArtifacts = @()
    $artifactPaths = Get-WizardArtifactPaths -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug
    if (Test-Path -LiteralPath $artifactPaths.ManifestJsonPath) {
        $manifest = Get-WizardArtifactManifest -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix
        $failedArtifacts = @($manifest.items | Where-Object status -eq 'failed' | ForEach-Object {
            [pscustomobject]@{
                Kind = $_.kind
                Name = $_.name
                Reason = $_.details.error ?? $_.details.reason ?? 'artifact build failed'
            }
        })
    }
    $membershipReport = New-SolutionMembershipReport -ExpectedByCategory $expectedByCategory -CurrentInventory $inventory -FailedArtifacts $failedArtifacts -Strict:$StrictMode
    $membershipFolder = Join-Path $artifactPaths.ArtifactRoot "contamination/$(ConvertTo-WizardManifestScenarioSlug -ScenarioSlug $ScenarioSlug)"
    $membershipJsonPath = Join-Path $membershipFolder 'solution-membership-report.json'
    $membershipMarkdownPath = Join-Path $membershipFolder 'solution-membership-report.md'
    $writtenReport = Write-SolutionMembershipReport -Report $membershipReport -JsonPath $membershipJsonPath -MarkdownPath $membershipMarkdownPath

    Write-Host "  Membership JSON:     $($writtenReport.JsonPath)" -ForegroundColor DarkGray
    Write-Host "  Membership Markdown: $($writtenReport.MarkdownPath)" -ForegroundColor DarkGray
    Write-Host "  Export allowed:       $($membershipReport.ExportAllowed)" -ForegroundColor $(if ($membershipReport.ExportAllowed) { 'Green' } else { 'Red' })
    if ($EnforceExportGate -and -not $membershipReport.ExportAllowed) {
        foreach ($item in @($membershipReport.BlockingItems)) {
            Write-Host "  BLOCKED [$($item.State)] [$($item.Category)] $($item.Name)" -ForegroundColor Red
        }
        throw 'Solution membership gate failed. Export is blocked until mandatory artifacts are present and strict isolation findings are resolved.'
    }
    exit 0
}

if ($EnableContaminationScan -and (Get-Command New-WizardExpectedArtifacts -ErrorAction SilentlyContinue)) {
    $expectedArtifacts = New-WizardExpectedArtifacts -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder -PublisherPrefix $PublisherPrefix
    $inventory = @(Get-SolutionComponentInventory -InvokeGet $invokeDvGet -SolutionId "$($sol.solutionid)")
    $scanResult = New-WizardContaminationVerdict -CurrentComponents $inventory -ExpectedArtifacts $expectedArtifacts -PublisherPrefix $PublisherPrefix
    $scanArtifact = [pscustomobject]@{
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        scenarioSlug = $ScenarioSlug
        solutionName = $SolutionUniqueName
        verdict = $scanResult.Verdict
        expected = @($scanResult.Expected)
        wizardOtherScenario = @($scanResult.WizardOtherScenario)
        manualOrLegacy = @($scanResult.ManualOrLegacy)
        unsupported = @('flows')
    }
    $artifactPaths = Write-WizardContaminationArtifacts -RepoRoot $repoRoot -ScanResult $scanArtifact

    Write-Host "  Contamination verdict: $($scanArtifact.verdict)" -ForegroundColor $(if ($scanArtifact.verdict -eq 'clean') { 'Green' } elseif ($scanArtifact.verdict -eq 'warning') { 'Yellow' } else { 'Red' })
    Write-Host "  Contamination JSON: $($artifactPaths.ContaminationJsonPath)" -ForegroundColor DarkGray

    if ($StrictMode -and -not $AllowContaminatedSolution -and ($scanArtifact.verdict -eq 'contaminated')) {
        Write-Host "Strict contamination mode blocked add-to-solution. Remediate the target solution or rerun with -AllowContaminatedSolution:`$true when reuse is intentional." -ForegroundColor Red
        if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
            Register-WizardStepFailure -Message 'Contamination scan found manual or legacy foreign artifacts in the target solution.'
        }
        exit 1
    }
}

if ($tableIsolationReport.ForeignTables.Count -gt 0) {
    Write-Host ""
    Write-Host "Foreign table components detected in solution '$SolutionUniqueName':" -ForegroundColor Yellow
    foreach ($table in $tableIsolationReport.ForeignTables) {
        Write-Host "  - $($table.LogicalName)" -ForegroundColor Yellow
    }
    Write-Host ""

    if ($FailIfSolutionHasForeignTables) {
        Write-Host "Strict table isolation is enabled. Stop and remediate this solution before adding components." -ForegroundColor Red
        Write-Host "Run a dry cleanup review with: pwsh ./scripts/bootstrap/57-prune-foreign-tables.ps1 -SolutionUniqueName \"$SolutionUniqueName\"" -ForegroundColor Yellow
        Write-Host "If reuse is intentional for this one run, override with: pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -FailIfSolutionHasForeignTables:`$false" -ForegroundColor Yellow
        if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
            Register-WizardStepFailure -Message "Foreign table components detected in target solution."
        }
        exit 1
    }

    Write-Host "Continuing because -FailIfSolutionHasForeignTables:`$false was supplied." -ForegroundColor Yellow
} else {
    Write-Host "  Solution table isolation: OK" -ForegroundColor Green
}

if ($entityNames.Count -eq 0 -and $reportWebResourceNames.Count -eq 0) {
    Write-Host "No payload entity references or report web resources were discovered." -ForegroundColor Yellow
    Write-Host "Add table/column/relationship payloads or generate report web resources first, then rerun."
    if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
        Complete-WizardStepTelemetry -Message "No payload-defined entities or report web resources found."
    }
    exit 0
}

Write-Host "  Payload-referenced entities found: $($entityNames.Count)"
Write-Host "  Referenced dependency entities:   $($allEntityNames.Count)"
Write-Host "  Report web resources found:      $($reportWebResourceNames.Count)"
Write-Host ""

$added = 0; $skipped = 0; $failed = 0
$componentTypeMap = Get-SolutionComponentTypeMap
$attributeComponentType = Get-ComponentTypeValue -Map $componentTypeMap -Labels @('Attribute') -Fallback 2
$relationshipComponentType = Get-ComponentTypeValue -Map $componentTypeMap -Labels @('Entity Relationship', 'Relationship') -Fallback 10
# ComponentType 1 = Entity
foreach ($logicalName in $entityNames | Sort-Object) {
    Write-Host "  $logicalName " -NoNewline

    $entity = Get-EntityDefinitionByLogicalName -InvokeGet $invokeDvGet -LogicalName $logicalName
    if ($null -eq $entity -or [string]::IsNullOrWhiteSpace($entity.MetadataId)) {
        Write-Host "(not found — skipped)" -ForegroundColor Yellow
        if ($EnableArtifactManifest -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $logicalName -Status 'skipped' -Step '50-add-to-solution.ps1' -Details @{ componentKind = 'table'; reason = 'entity not found' } | Out-Null
        }
        $skipped++
        continue
    }

    try {
        if (Test-SolutionComponentMembership -SolutionId "$($sol.solutionid)" -ObjectId "$($entity.MetadataId)" -ComponentType 1) {
            Write-Host "(already in solution)" -ForegroundColor DarkGray
            if ($EnableArtifactManifest -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $logicalName -Status 'skipped' -Step '50-add-to-solution.ps1' -Details @{ componentKind = 'table'; reason = 'already in solution' } | Out-Null
            }
            $skipped++
            continue
        }
        $body = @{ ComponentId = $entity.MetadataId; ComponentType = 1; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $false } | ConvertTo-Json -Compress
        Invoke-Dv "Post" "AddSolutionComponent" $body | Out-Null
        Write-Host "(added)" -ForegroundColor Green
        if ($EnableArtifactManifest -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
            Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $logicalName -Status 'created' -Step '50-add-to-solution.ps1' -Details @{ componentKind = 'table' } | Out-Null
        }
        $added++
    } catch {
        if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
            Write-Host "(already in solution)" -ForegroundColor DarkGray
            if ($EnableArtifactManifest -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $logicalName -Status 'skipped' -Step '50-add-to-solution.ps1' -Details @{ componentKind = 'table'; reason = 'already in solution' } | Out-Null
            }
            $skipped++
        } else {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
            if ($EnableArtifactManifest -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $logicalName -Status 'failed' -Step '50-add-to-solution.ps1' -Details @{ componentKind = 'table'; error = $_.Exception.Message } | Out-Null
            }
            $failed++
        }
    }
}

$columnPayloads = @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'columns-*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
foreach ($file in $columnPayloads) {
    $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $table = "$($document.TableLogicalName)".Trim().ToLowerInvariant()
    $escapedTable = ConvertTo-WizardODataLiteral -Value $table
    foreach ($column in @($document.Columns)) {
        $logicalName = "$($column.LogicalName)".Trim().ToLowerInvariant()
        $componentName = "$table.$logicalName"
        Write-Host "  $componentName " -NoNewline
        try {
            $escapedColumn = ConvertTo-WizardODataLiteral -Value $logicalName
            $metadata = Invoke-Dv "Get" "EntityDefinitions(LogicalName='$escapedTable')/Attributes(LogicalName='$escapedColumn')?`$select=LogicalName,MetadataId"
            if ([string]::IsNullOrWhiteSpace("$($metadata.MetadataId)")) {
                throw "Column metadata ID was not returned."
            }
            if (Test-SolutionComponentMembership -SolutionId "$($sol.solutionid)" -ObjectId "$($metadata.MetadataId)" -ComponentType $attributeComponentType) {
                Write-Host "(already in solution)" -ForegroundColor DarkGray
                Add-SolutionComponentManifestItem -Name $componentName -ComponentKind 'column' -Status 'skipped' -Reason 'already in solution'
                $skipped++
                continue
            }
            $body = @{ ComponentId = $metadata.MetadataId; ComponentType = $attributeComponentType; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $false } | ConvertTo-Json -Compress
            Invoke-Dv "Post" "AddSolutionComponent" $body | Out-Null
            Write-Host "(added)" -ForegroundColor Green
            Add-SolutionComponentManifestItem -Name $componentName -ComponentKind 'column' -Status 'created'
            $added++
        } catch {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
            Add-SolutionComponentManifestItem -Name $componentName -ComponentKind 'column' -Status 'failed' -Reason $_.Exception.Message
            $failed++
        }
    }
}

$relationshipPayloads = @(Get-ChildItem -LiteralPath $PayloadsFolder -Filter 'relationships-*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
foreach ($file in $relationshipPayloads) {
    $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($relationship in @($document.Relationships ?? $document)) {
        $definition = $relationship.RelationshipDefinition ?? $relationship
        $schemaName = "$($definition.SchemaName)".Trim()
        Write-Host "  $schemaName " -NoNewline
        try {
            $escapedSchema = ConvertTo-WizardODataLiteral -Value $schemaName
            $response = Invoke-Dv "Get" "RelationshipDefinitions?`$select=SchemaName,MetadataId&`$filter=SchemaName eq '$escapedSchema'"
            $matches = @($response.value | Where-Object { "$($_.SchemaName)" -ieq $schemaName })
            if ($matches.Count -ne 1) {
                throw "Relationship metadata did not resolve uniquely."
            }
            $metadataId = "$($matches[0].MetadataId)"
            if (Test-SolutionComponentMembership -SolutionId "$($sol.solutionid)" -ObjectId $metadataId -ComponentType $relationshipComponentType) {
                Write-Host "(already in solution)" -ForegroundColor DarkGray
                Add-SolutionComponentManifestItem -Name $schemaName -ComponentKind 'relationship' -Status 'skipped' -Reason 'already in solution'
                $skipped++
                continue
            }
            $body = @{ ComponentId = $metadataId; ComponentType = $relationshipComponentType; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $false } | ConvertTo-Json -Compress
            Invoke-Dv "Post" "AddSolutionComponent" $body | Out-Null
            Write-Host "(added)" -ForegroundColor Green
            Add-SolutionComponentManifestItem -Name $schemaName -ComponentKind 'relationship' -Status 'created'
            $added++
        } catch {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
            Add-SolutionComponentManifestItem -Name $schemaName -ComponentKind 'relationship' -Status 'failed' -Reason $_.Exception.Message
            $failed++
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
            if ($EnableArtifactManifest -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $name -Status 'skipped' -Step '50-add-to-solution.ps1' -Details @{ componentKind = 'webresource'; reason = 'web resource not found' } | Out-Null
            }
            $skipped++
            continue
        }

        try {
            $body = @{ ComponentId = $wr[0].webresourceid; ComponentType = $webResourceComponentType; SolutionUniqueName = $SolutionUniqueName; AddRequiredComponents = $true } | ConvertTo-Json -Compress
            Invoke-Dv "Post" "AddSolutionComponent" $body | Out-Null
            Write-Host "(added)" -ForegroundColor Green
            if ($EnableArtifactManifest -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
                Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $name -Status 'created' -Step '50-add-to-solution.ps1' -Details @{ componentKind = 'webresource' } | Out-Null
            }
            $added++
        } catch {
            if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
                Write-Host "(already in solution)" -ForegroundColor DarkGray
                if ($EnableArtifactManifest -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
                    Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $name -Status 'skipped' -Step '50-add-to-solution.ps1' -Details @{ componentKind = 'webresource'; reason = 'already in solution' } | Out-Null
                }
                $skipped++
            } else {
                Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
                if ($EnableArtifactManifest -and (Get-Command Add-WizardArtifactManifestItem -ErrorAction SilentlyContinue)) {
                    Add-WizardArtifactManifestItem -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionUniqueName -PublisherPrefix $PublisherPrefix -Kind 'appcomponent' -Name $name -Status 'failed' -Step '50-add-to-solution.ps1' -Details @{ componentKind = 'webresource'; error = $_.Exception.Message } | Out-Null
                }
                $failed++
            }
        }
    }
}

Write-Host ""
Write-Host "Solution components — added: $added  skipped: $skipped  failed: $failed"
if ($failed -gt 0) {
    if (Get-Command Register-WizardStepFailure -ErrorAction SilentlyContinue) {
        Register-WizardStepFailure -Message "Add-to-solution failed for one or more components."
    }
    exit 1
}
if ($PublishScoped) {
    $entityXml = @($allEntityNames | Sort-Object -Unique | ForEach-Object {
        "<entity>$([System.Security.SecurityElement]::Escape($_))</entity>"
    }) -join ""
    $parameterXml = "<importexportxml><entities>$entityXml</entities></importexportxml>"
    $publishBody = @{ ParameterXml = $parameterXml } | ConvertTo-Json -Compress
    Invoke-Dv "Post" "PublishXml" $publishBody | Out-Null
    Write-Host "Scoped publish completed for $(@($allEntityNames | Sort-Object -Unique).Count) entities." -ForegroundColor Green
}
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/60-build-forms-views.ps1"
if (Get-Command Complete-WizardStepTelemetry -ErrorAction SilentlyContinue) {
    Complete-WizardStepTelemetry -Message "Solution component add completed."
}
