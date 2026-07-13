<#
.SYNOPSIS
    Creates a starter Main form and Active view for every custom table that
    does not already have one. Publishes all customizations when done.

.PARAMETER EnvironmentUrl   Defaults to $env:DV_ENVIRONMENT_URL.
.PARAMETER AccessToken      Defaults to $env:DV_TOKEN.
.PARAMETER PublisherPrefix  Defaults to $env:DV_PUBLISHER_PREFIX.

.EXAMPLE
    pwsh ./scripts/bootstrap/60-build-forms-views.ps1
#>

param(
    [string]$EnvironmentUrl  = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken     = $env:DV_TOKEN,
  [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
  [string]$PayloadsFolder  = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl  = $global:DV_ENVIRONMENT_URL
    $AccessToken     = $global:DV_TOKEN
    $PublisherPrefix = $PublisherPrefix -ne "" ? $PublisherPrefix : $global:DV_PUBLISHER_PREFIX
}

foreach ($v in @($EnvironmentUrl, $AccessToken, $PublisherPrefix)) {
    if ([string]::IsNullOrWhiteSpace($v)) {
        Write-Host "Missing required values. Run 10-auth-connect.ps1 first." -ForegroundColor Red; exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
  $PayloadsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "payloads"
}

$normalizedPrefix = $PublisherPrefix.ToLower()

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "") {
    $h = @{ "Authorization"="Bearer $AccessToken"; "Content-Type"="application/json";
            "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Accept"="application/json" }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
}

  function Get-CustomEntitiesFromTablePayloads {
    param(
      [string]$Folder,
      [string]$Prefix
    )

    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $tableFiles = @(Get-ChildItem -Path $Folder -Filter "table-*.json" -ErrorAction SilentlyContinue)

    foreach ($file in $tableFiles) {
      $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
      $schemaName = ($doc.EntityDefinition.SchemaName ?? $doc.SchemaName)
      if ([string]::IsNullOrWhiteSpace($schemaName)) { continue }
      $logicalName = $schemaName.ToLower()

      if ($logicalName -like "$Prefix`_*") {
        [void]$names.Add($logicalName)
      }
    }

    return @($names)
  }

function New-StarterFormXml([string]$PrimaryField) {
    return @"
<form>
  <tabs>
    <tab name="general" id="{00000000-0000-0000-0000-000000000001}" labelid="" showlabel="true" expanded="true">
      <labels><label description="General" languagecode="1033"/></labels>
      <columns>
        <column width="100%">
          <sections>
            <section name="general_section" showlabel="false" showbar="false">
              <labels><label description="General" languagecode="1033"/></labels>
              <rows>
                <row><cell id="{00000000-0000-0000-0000-000000000002}"><labels><label description="$PrimaryField" languagecode="1033"/></labels><control id="$PrimaryField" classid="{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" datafieldname="$PrimaryField" disabled="false"/></cell></row>
              </rows>
            </section>
          </sections>
        </column>
      </columns>
    </tab>
  </tabs>
</form>
"@
}

function New-StarterViewFetchXml([string]$TableLogical, [string]$PrimaryField) {
    return @"
<fetch version="1.0" output-format="xml-platform" mapping="logical" distinct="false">
  <entity name="$TableLogical">
    <attribute name="$PrimaryField" />
    <attribute name="createdon" />
    <attribute name="modifiedon" />
    <order attribute="$PrimaryField" descending="false" />
    <filter type="and">
      <condition attribute="statecode" operator="eq" value="0" />
    </filter>
  </entity>
</fetch>
"@
}

function New-StarterViewLayoutXml([string]$PrimaryField) {
    return @"
<grid name="resultset" object="1" jump="$PrimaryField" select="1" icon="1" preview="1">
  <row name="result" id="$($PrimaryField)id">
    <cell name="$PrimaryField" width="300" />
    <cell name="createdon" width="150" />
    <cell name="modifiedon" width="150" />
  </row>
</grid>
"@
}

Write-Host ""
Write-Host "=== Build Forms and Views ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Prefix:      $normalizedPrefix"
Write-Host "  Payloads:    $PayloadsFolder"
Write-Host ""

$payloadCustomEntities = @(Get-CustomEntitiesFromTablePayloads -Folder $PayloadsFolder -Prefix $normalizedPrefix)
if ($payloadCustomEntities.Count -eq 0) {
  Write-Host "  No custom entities found in table payloads. Nothing to generate." -ForegroundColor Yellow
  exit 0
}

$tables = @()
foreach ($logicalName in $payloadCustomEntities | Sort-Object) {
  try {
    $entity = Invoke-Dv "Get" "EntityDefinitions(LogicalName='$logicalName')?`$select=LogicalName,PrimaryNameAttribute,MetadataId,IsCustomEntity"
    if ($entity.IsCustomEntity) {
      $tables += $entity
    }
  } catch {
    Write-Host "  $logicalName (not found — skipped)" -ForegroundColor Yellow
  }
}

Write-Host "  Custom tables found: $($tables.Count)"
Write-Host ""

$formsCreated = 0; $viewsCreated = 0; $failed = 0

foreach ($t in $tables) {
    $logical  = $t.LogicalName
    $primary  = $t.PrimaryNameAttribute
    Write-Host "  $logical" -ForegroundColor Cyan

    # ── Form ──────────────────────────────────────────────────────────────
    $existingForms = @((Invoke-Dv "Get" "systemforms?`$select=name,type&`$filter=objecttypecode eq '$logical' and type eq 2").value)
    $hasMain = $existingForms | Where-Object { $_.type -eq 2 -and $_.name -like "*Main*" }
    if ($hasMain) {
        Write-Host "    Form (exists — skipped)" -ForegroundColor DarkGray
    } else {
        try {
            $formXml = New-StarterFormXml $primary
            $formBody = @{
                name            = "Starter Main Form"
                objecttypecode  = $logical
                type            = 2
                formxml         = $formXml
            } | ConvertTo-Json -Compress
            Invoke-Dv "Post" "systemforms" $formBody | Out-Null
            Write-Host "    Form (created)" -ForegroundColor Green
            $formsCreated++
        } catch {
            Write-Host "    Form (FAILED: $($_.Exception.Message))" -ForegroundColor Red
            $failed++
        }
    }

    # ── View ──────────────────────────────────────────────────────────────
    $existingViews = @((Invoke-Dv "Get" "savedqueries?`$select=name&`$filter=returnedtypecode eq '$logical' and querytype eq 0").value)
    $hasActive = $existingViews | Where-Object { $_.name -like "Active*" }
    if ($hasActive) {
        Write-Host "    View  (exists — skipped)" -ForegroundColor DarkGray
    } else {
        try {
            $fetchXml  = New-StarterViewFetchXml $logical $primary
            $layoutXml = New-StarterViewLayoutXml $primary
            $viewBody = @{
                name               = "Active Records"
                returnedtypecode   = $logical
                querytype          = 0
                fetchxml           = $fetchXml
                layoutxml          = $layoutXml
                iscustomizable     = @{ Value = $true }
            } | ConvertTo-Json -Compress
            Invoke-Dv "Post" "savedqueries" $viewBody | Out-Null
            Write-Host "    View  (created)" -ForegroundColor Green
            $viewsCreated++
        } catch {
            Write-Host "    View  (FAILED: $($_.Exception.Message))" -ForegroundColor Red
            $failed++
        }
    }
}

# ── Publish all ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Publishing all customizations..." -NoNewline
try {
    Invoke-Dv "Post" "PublishAllXml" "{}" | Out-Null
    Write-Host " done." -ForegroundColor Green
} catch {
    Write-Host " WARNING: publish failed. Publish manually in maker portal. $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Forms created: $formsCreated  Views created: $viewsCreated  Failures: $failed"
if ($failed -gt 0) { exit 1 }
Write-Host ""
Write-Host "Build complete. Verify in Power Apps Maker at:"
Write-Host "  https://make.powerapps.com"

