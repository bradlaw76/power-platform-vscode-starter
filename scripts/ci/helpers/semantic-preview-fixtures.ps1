<#
=============================================================================
COMPONENT:    Synthetic Semantic Preview Fixtures
FILE:         scripts/ci/helpers/semantic-preview-fixtures.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Credential-free CI
OVERVIEW:     Copies legacy test scenarios into isolated synthetic workspaces.
ARCHITECTURE: Test-only compatibility fixtures, never production plan upgrades.
TEST CASES:   Existing Preview and run-state coverage with explicit test designs.
NON-NEGOTIABLES: No source edits, credentials, real approvals or live execution.
=============================================================================
#>
function New-SemanticPreviewWorkspace {
    param([string]$SourceRoot, [string]$TargetRoot, [string[]]$ScenarioSlugs)
    New-Item -ItemType Directory -Path (Join-Path $TargetRoot 'scripts') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $SourceRoot 'scripts\bootstrap') -Destination (Join-Path $TargetRoot 'scripts') -Recurse
    foreach ($folder in @('schemas', 'docs')) { Copy-Item -LiteralPath (Join-Path $SourceRoot $folder) -Destination $TargetRoot -Recurse }
    foreach ($file in @('wizard.profile.json', 'README.md', 'repository-updates.json')) { Copy-Item -LiteralPath (Join-Path $SourceRoot $file) -Destination $TargetRoot }
    $example = Get-Content -LiteralPath (Join-Path $SourceRoot 'schemas\examples\field-type-decisions.example.json') -Raw | ConvertFrom-Json -AsHashtable
    foreach ($slug in $ScenarioSlugs) {
        $scenarioParent = Join-Path $TargetRoot 'specs'
        $payloadParent = Join-Path $TargetRoot 'payloads\scenarios'
        New-Item -ItemType Directory -Path $scenarioParent, $payloadParent -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $SourceRoot "specs\$slug") -Destination $scenarioParent -Recurse
        Copy-Item -LiteralPath (Join-Path $SourceRoot "payloads\scenarios\$slug") -Destination $payloadParent -Recurse
        $payloadFolder = Join-Path $payloadParent $slug
        $fields = [Collections.Generic.List[object]]::new()
        $seedDocs = @(Get-ChildItem -LiteralPath $payloadFolder -Filter 'data-*.json' -File | ForEach-Object {
            @{ path = $_.FullName; data = (Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json -AsHashtable) }
        })
        foreach ($file in @(Get-ChildItem -LiteralPath $payloadFolder -Filter 'columns-*.json' -File)) {
            $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
            foreach ($column in $doc.Columns) {
                $category = 'free-text'
                $config = @{}
                $choice = $null
                if ($column['@odata.type'] -eq 'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata') {
                    $category = 'date-time'
                    $column.DateTimeBehavior = @{ Value = $(if ($column.Format -eq 'DateOnly') { 'DateOnly' } else { 'UserLocal' }) }
                    $config = @{ precision = 'Synthetic fixture date precision'; integrationTimezone = 'Synthetic fixture UTC contract' }
                } elseif ($column.SchemaName -ceq 'ppvs_lifecyclestage') {
                    $category = 'choice'
                    $labels = [Collections.Generic.List[string]]::new()
                    $labels.Add('Requested')
                    foreach ($seed in $seedDocs) {
                        foreach ($table in $seed.data.Tables) {
                            if ($table.TableLogicalName -cne $doc.TableLogicalName) { continue }
                            foreach ($record in $table.Records) {
                                if ($record.Values.Contains('ppvs_lifecyclestage') -and $record.Values.ppvs_lifecyclestage -notin $labels) { $labels.Add($record.Values.ppvs_lifecyclestage) }
                            }
                        }
                    }
                    $options = @()
                    for ($i = 0; $i -lt $labels.Count; $i++) {
                        $options += @{ value = 100000000 + $i; labels = @{ LocalizedLabels = @(@{ Label = $labels[$i]; LanguageCode = 1033 }) }; meaning = "Synthetic fixture state $($labels[$i])" }
                    }
                    $choice = @{
                        scope = 'local'; name = $column.SchemaName; default = 100000000
                        localization = 'Synthetic English test labels'
                        options = $options
                        mappings = @{
                            sample = @{ applicable = $true; reason = 'Synthetic source-label mapping'; entries = @($options | ForEach-Object { @{ source = $_.labels.LocalizedLabels[0].Label; value = $_.value } }) }
                            integration = @{ applicable = $false; reason = 'No test integration'; entries = @() }
                            retrofit = @{ applicable = $false; reason = 'No live retrofit'; entries = @() }
                        }
                    }
                    $column.Remove('MaxLength')
                    $column['@odata.type'] = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'
                    $column.DefaultFormValue = 100000000
                    $column.OptionSet = @{ IsGlobal = $false; Options = @($options | ForEach-Object { @{ Value = $_.value; Label = $_.labels } }) }
                    foreach ($seed in $seedDocs) {
                        foreach ($table in $seed.data.Tables) {
                            if ($table.TableLogicalName -cne $doc.TableLogicalName) { continue }
                            foreach ($record in $table.Records) {
                                if ($record.Values.Contains('ppvs_lifecyclestage')) {
                                    $record.Values.ppvs_lifecyclestage = @($choice.mappings.sample.entries | Where-Object { $_.source -ceq $record.Values.ppvs_lifecyclestage })[0].value
                                }
                            }
                        }
                    }
                }
                $field = @{
                    table = $doc.TableLogicalName; field = $column.SchemaName.ToLowerInvariant()
                    semanticCategory = $category; disposition = 'create-column'; expectedMetadata = $column; typeConfig = $config
                }
                if ($null -ne $choice) { $field.choice = $choice }
                $fields.Add($field)
            }
            $doc | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $file.FullName
        }
        foreach ($seed in $seedDocs) { $seed.data | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $seed.path }
        foreach ($file in @(Get-ChildItem -LiteralPath $payloadFolder -Filter 'table-*.json' -File)) {
            $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
            $table = $doc.EntityDefinition.SchemaName.ToLowerInvariant()
            $name = "$($table.Split('_', 2)[0])_name"
            $fields.Add(@{
                table = $table; field = $name; semanticCategory = 'free-text'; disposition = 'table-primary'; typeConfig = @{}
                expectedMetadata = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'; SchemaName = $name; MaxLength = 100; RequiredLevel = @{ Value = 'ApplicationRequired' }; DisplayName = @{ LocalizedLabels = @(@{ Label = 'Name'; LanguageCode = 1033 }) } }
            })
        }
        foreach ($file in @(Get-ChildItem -LiteralPath $payloadFolder -Filter 'relationships-*.json' -File)) {
            $doc = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
            foreach ($item in $doc.Relationships) {
                $rel = if ($item.Contains('RelationshipDefinition')) { $item.RelationshipDefinition } else { $item }
                $lookup = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'; SchemaName = $rel.ReferencingAttribute; RequiredLevel = @{ Value = 'None' }; DisplayName = @{ LocalizedLabels = @(@{ Label = 'Related record'; LanguageCode = 1033 }) } }
                $rel.Lookup = $lookup
                $fields.Add(@{
                    table = $rel.ReferencingEntity; field = $rel.ReferencingAttribute
                    semanticCategory = 'lookup'; disposition = 'create-relationship'; expectedMetadata = $lookup
                    typeConfig = @{ cardinality = 'Many to one'; requiredness = 'Optional'; existingOrNew = 'Synthetic fixture new'; supportingTask = 'Synthetic relationship navigation' }
                    relationship = @{ SchemaName = $rel.SchemaName; ReferencedEntity = $rel.ReferencedEntity; ReferencingEntity = $rel.ReferencingEntity; ReferencingAttribute = $rel.ReferencingAttribute; CascadeConfiguration = $rel.CascadeConfiguration }
                })
            }
            $doc | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $file.FullName
        }
        $plan = @{ schemaVersion = '1.0'; scenarioSlug = $slug; approval = $example.approval; fields = @($fields.ToArray()); surfaces = $example.surfaces }
        $rows = "`n## Synthetic semantic test decisions`nfield-type-decisions.json`n| Decision | Table | Field | Business meaning | Semantic category | Bounded values? | Dataverse type | Scope or target | Rationale |`n| --- | --- | --- | --- | --- | --- | --- | --- | --- |`n"
        $exceptionNotes = ''
        for ($i = 0; $i -lt $fields.Count; $i++) {
            $field = $fields[$i]
            $field.decisionId = "FIELD-fixture-$i"
            $field.businessMeaning = 'Synthetic compatibility fixture value; not a production semantic decision'
            $field.rationale = 'Isolated Preview compatibility test only'
            $field.selectionFactors = $example.fields[0].selectionFactors
            $field.dependencies = @('Synthetic Preview surface')
            $field.boundedValues = $field.semanticCategory -eq 'choice'
            $field.categoricalCandidate = $field.boundedValues
            $scope = if ($field.Contains('choice')) { "$($field.choice.scope):$($field.choice.name)" } elseif ($field.Contains('relationship')) { $field.relationship.ReferencedEntity } else { '-' }
            $class = $field.expectedMetadata['@odata.type'].Split('.')[-1].Replace('AttributeMetadata', '')
            $rows += "| $($field.decisionId) | $($field.table) | $($field.field) | $($field.businessMeaning) | $($field.semanticCategory) | $($field.boundedValues.ToString().ToLowerInvariant()) | $class | $scope | $($field.rationale) |`n"
            if ($field.semanticCategory -eq 'free-text') {
                $field.textException = @{
                    approval = $example.approval
                    reason = 'Synthetic compatibility fixture preserves text metadata; not an actual business approval'
                    alternativeConsidered = 'Production Choice/Lookup decisions require separate human planning'
                    consequences = @{ reporting = 'Synthetic report contract'; filtering = 'Synthetic filter contract'; automation = 'No automation execution'; integration = 'No integration execution'; dataQuality = 'Synthetic values only' }
                }
                $exceptionNotes += "`n$($field.textException.reason)`n$($field.textException.alternativeConsidered)`n$($field.textException.consequences.Values -join "`n")`n"
            }
            $rows += $exceptionNotes
        }
        $folder = Join-Path $scenarioParent $slug
        foreach ($file in @('spec.md', 'plan.md', 'tasks.md')) { Add-Content -LiteralPath (Join-Path $folder $file) -Value $rows }
        $plan | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath (Join-Path $folder 'field-type-decisions.json')
    }
}
