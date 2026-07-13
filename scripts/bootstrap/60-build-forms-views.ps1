<#
.SYNOPSIS
  Creates or updates a payload-driven Starter Main Form and Active view for
  every custom table in the table payload set. Publishes customizations when done.

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

function Get-FriendlyLabelFromLogicalName {
    param(
        [string]$LogicalName,
        [string]$Prefix
    )

    if ([string]::IsNullOrWhiteSpace($LogicalName)) { return "Field" }

    $value = $LogicalName.ToLower()
    if (-not [string]::IsNullOrWhiteSpace($Prefix)) {
        $normalized = $Prefix.ToLower() + "_"
        if ($value.StartsWith($normalized)) {
            $value = $value.Substring($normalized.Length)
        }
    }

    $value = $value -replace "_", " "
    $value = $value.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return "Field" }

    $culture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
    return $culture.TextInfo.ToTitleCase($value)
}

function Get-DisplayLabel {
    param(
        $DisplayName,
        [string]$LogicalName,
        [string]$Prefix
    )

    $labels = @($DisplayName.LocalizedLabels)
    if ($labels.Count -gt 0) {
        $en = @($labels | Where-Object { $_.LanguageCode -eq 1033 } | Select-Object -First 1)
        if ($en.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($en[0].Label)) {
            return $en[0].Label
        }

        $first = $labels | Select-Object -First 1
        if ($null -ne $first -and -not [string]::IsNullOrWhiteSpace($first.Label)) {
            return $first.Label
        }
    }

    return Get-FriendlyLabelFromLogicalName -LogicalName $LogicalName -Prefix $Prefix
}

function Get-PrimaryFieldLabel {
    param(
        [string]$TableLogical,
        [string]$PrimaryField,
        [string]$Prefix
    )

    try {
        $metadata = Invoke-Dv "Get" "EntityDefinitions(LogicalName='$TableLogical')/Attributes(LogicalName='$PrimaryField')?`$select=LogicalName&`$expand=DisplayName"
        return Get-DisplayLabel -DisplayName $metadata.DisplayName -LogicalName $PrimaryField -Prefix $Prefix
    } catch {
        return Get-FriendlyLabelFromLogicalName -LogicalName $PrimaryField -Prefix $Prefix
    }
}

function Get-PayloadFieldsForTable {
    param(
        [string]$Folder,
        [string]$TableLogical,
        [string]$Prefix
    )

    $results = New-Object System.Collections.Generic.List[object]
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $columnFiles = @(Get-ChildItem -Path $Folder -Filter "columns-*.json" -ErrorAction SilentlyContinue | Sort-Object Name)

    foreach ($file in $columnFiles) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $tableName = $doc.TableLogicalName
        if ([string]::IsNullOrWhiteSpace($tableName)) { continue }
        if ($tableName.ToLower() -ne $TableLogical.ToLower()) { continue }

        foreach ($col in @($doc.Columns)) {
            $logical = $col.LogicalName
            if ([string]::IsNullOrWhiteSpace($logical)) { $logical = $col.SchemaName }
            if ([string]::IsNullOrWhiteSpace($logical)) { continue }

            $logical = $logical.ToLower()
            if (-not $seen.Add($logical)) { continue }

            $label = Get-DisplayLabel -DisplayName $col.DisplayName -LogicalName $logical -Prefix $Prefix
            $results.Add([pscustomobject]@{
                LogicalName = $logical
                Label       = $label
            })
        }
    }

    return @($results)
}

function New-FieldCellXml {
    param(
        [string]$FieldLogicalName,
        [string]$FieldLabel,
        [int]$CellIndex
    )

    return "<cell id=\"{00000000-0000-0000-0000-$('{0:d12}' -f $CellIndex)}\"><labels><label description=\"$FieldLabel\" languagecode=\"1033\"/></labels><control id=\"$FieldLogicalName\" classid=\"{4273EDBD-AC1D-40d3-9FB2-095C621B552D}\" datafieldname=\"$FieldLogicalName\" disabled=\"false\"/></cell>"
}

function New-StarterFormXml {
    param(
        [array]$Fields
    )

    $rows = New-Object System.Collections.Generic.List[string]
    $cellIndex = 2
    for ($i = 0; $i -lt $Fields.Count; $i += 2) {
        $left = New-FieldCellXml -FieldLogicalName $Fields[$i].LogicalName -FieldLabel $Fields[$i].Label -CellIndex $cellIndex
        $cellIndex++

        if ($i + 1 -lt $Fields.Count) {
            $right = New-FieldCellXml -FieldLogicalName $Fields[$i + 1].LogicalName -FieldLabel $Fields[$i + 1].Label -CellIndex $cellIndex
            $cellIndex++
        } else {
            $right = "<cell id=\"{00000000-0000-0000-0000-$('{0:d12}' -f $cellIndex)}\" />"
            $cellIndex++
        }

        $rows.Add("<row>$left$right</row>")
    }

    $rowsXml = $rows -join "`n"

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
                $rowsXml
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

$formsCreated = 0; $formsUpdated = 0; $formsSkipped = 0; $viewsCreated = 0; $failed = 0

foreach ($t in $tables) {
    $logical  = $t.LogicalName
    $primary  = $t.PrimaryNameAttribute
    Write-Host "  $logical" -ForegroundColor Cyan

    # ── Form (payload-driven) ─────────────────────────────────────────────
    try {
      $primaryLabel = Get-PrimaryFieldLabel -TableLogical $logical -PrimaryField $primary -Prefix $normalizedPrefix
      $payloadFields = @(Get-PayloadFieldsForTable -Folder $PayloadsFolder -TableLogical $logical -Prefix $normalizedPrefix)

      $orderedFields = New-Object System.Collections.Generic.List[object]
      $orderedFields.Add([pscustomobject]@{ LogicalName = $primary; Label = $primaryLabel })
      foreach ($f in $payloadFields) {
        if ($f.LogicalName -ne $primary) {
          $orderedFields.Add($f)
        }
      }

      $formXml = New-StarterFormXml -Fields @($orderedFields)

      $existingForms = @((Invoke-Dv "Get" "systemforms?`$select=systemformid,name,type,formxml&`$filter=objecttypecode eq '$logical' and type eq 2").value)
      $starterMainForm = @($existingForms | Where-Object { $_.name -eq "Starter Main Form" } | Select-Object -First 1)
      $nonStarterMainForms = @($existingForms | Where-Object { $_.name -ne "Starter Main Form" })

      if ($starterMainForm.Count -gt 0) {
        $starter = $starterMainForm[0]
        if ($starter.formxml -ne $formXml) {
          $patchBody = @{ formxml = $formXml } | ConvertTo-Json -Compress
          Invoke-Dv "Patch" "systemforms($($starter.systemformid))" $patchBody | Out-Null
          Write-Host "    Form (updated Starter Main Form)" -ForegroundColor Green
          $formsUpdated++
        } else {
          Write-Host "    Form (Starter Main Form already up to date — skipped)" -ForegroundColor DarkGray
          $formsSkipped++
        }
      } elseif ($nonStarterMainForms.Count -gt 0) {
        Write-Host "    Form (non-starter Main form exists — skipped)" -ForegroundColor DarkGray
        $formsSkipped++
      } else {
        $formBody = @{
          name            = "Starter Main Form"
          objecttypecode  = $logical
          type            = 2
          formxml         = $formXml
        } | ConvertTo-Json -Compress
        Invoke-Dv "Post" "systemforms" $formBody | Out-Null
        Write-Host "    Form (created)" -ForegroundColor Green
        $formsCreated++
      }
    } catch {
      Write-Host "    Form (FAILED: $($_.Exception.Message))" -ForegroundColor Red
      $failed++
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
Write-Host "Forms created: $formsCreated  Forms updated: $formsUpdated  Forms skipped: $formsSkipped  Views created: $viewsCreated  Failures: $failed"
if ($failed -gt 0) { exit 1 }
Write-Host ""
Write-Host "Build complete. Verify in Power Apps Maker at:"
Write-Host "  https://make.powerapps.com"

