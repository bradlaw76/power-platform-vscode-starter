<#
=============================================================================
COMPONENT:    Wizard Hardening Helper
FILE:         scripts/bootstrap/helpers/wizard-hardening.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-07-19
ENVIRONMENT:  PowerShell 7 | Build Contract Validation

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Provides shared hardening and build-contract validation logic used by bootstrap
scripts and tests to keep the wizard workflow safe.

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            helper module
- Inputs:          planning files, payload metadata, and scenario context
- Outputs:         validation results, contract context, and guardrail helpers
- Dependencies:    PowerShell runtime and repo workflow conventions
- Side Effects:    none beyond returned helper data

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. Load this helper from scripts that enforce workflow gates.
2. Provide scenario context consistent with repo artifact layout.

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ Complete planning context passes guardrail checks.
✔ Missing mappings or files produce explicit validation failures.

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
v0.1.0  2026-07-19  Added PowerShell-adapted SpeckKit component header.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Keep guardrail logic aligned with repo workflow contracts.
- Fail clearly on contract drift rather than masking it.
- Update this header when the helper contract materially changes.
=============================================================================
#>

Set-StrictMode -Version Latest

function Get-WizardOptionalPropertyValue {
    param(
        [object]$InputObject,
        [string]$PropertyName,
        $Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property) {
        return $Default
    }

    return $property.Value
}

function ConvertTo-WizardSafeSlug {
    param([string]$Value)

    $slug = ($Value ?? '').Trim().ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '-')
    $slug = $slug.Trim('-')
    return $slug
}

function Get-WizardScenarioContext {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug,
        [string]$PayloadsFolder
    )

    $specsRoot = Join-Path $RepoRoot 'specs'
    if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) {
        $scenarioDirs = @(Get-ChildItem -Path $specsRoot -Directory -ErrorAction SilentlyContinue)
        if ($scenarioDirs.Count -eq 1) {
            $ScenarioSlug = $scenarioDirs[0].Name
        }
    }

    $scenarioFolder = if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) { '' } else { Join-Path $specsRoot $ScenarioSlug }
    $resolvedPayloadsFolder = if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) { Join-Path $RepoRoot 'payloads' } else { $PayloadsFolder }
    $scenarioPayloadFolder = if ([string]::IsNullOrWhiteSpace($ScenarioSlug)) { $resolvedPayloadsFolder } else { Join-Path $resolvedPayloadsFolder (Join-Path 'scenarios' $ScenarioSlug) }

    return [pscustomobject]@{
        RepoRoot              = $RepoRoot
        ScenarioSlug          = $ScenarioSlug
        SpecsRoot             = $specsRoot
        ScenarioFolder        = $scenarioFolder
        AnswersPath           = if ($scenarioFolder) { Join-Path $scenarioFolder 'answers.md' } else { '' }
        SpecPath              = if ($scenarioFolder) { Join-Path $scenarioFolder 'spec.md' } else { '' }
        PlanPath              = if ($scenarioFolder) { Join-Path $scenarioFolder 'plan.md' } else { '' }
        TasksPath             = if ($scenarioFolder) { Join-Path $scenarioFolder 'tasks.md' } else { '' }
        PayloadsFolder        = $resolvedPayloadsFolder
        ScenarioPayloadFolder = $scenarioPayloadFolder
    }
}

function Read-WizardTextFile {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
        return ''
    }

    return Get-Content -Path $Path -Raw -Encoding UTF8
}

function Get-WizardMarkdownSection {
    param(
        [string]$Markdown,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Markdown) -or [string]::IsNullOrWhiteSpace($Heading)) {
        return ''
    }

    $pattern = '(?ims)^##\s+' + [regex]::Escape($Heading) + '\s*\r?\n(.*?)(?=^##\s+|\z)'
    $match = [regex]::Match($Markdown, $pattern)
    if (-not $match.Success) {
        return ''
    }

    return $match.Groups[1].Value.Trim()
}

function Get-WizardMarkdownSubsection {
    param(
        [string]$SectionText,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($SectionText) -or [string]::IsNullOrWhiteSpace($Heading)) {
        return ''
    }

    $pattern = '(?ims)^###\s+' + [regex]::Escape($Heading) + '\s*\r?\n(.*?)(?=^###\s+|\z)'
    $match = [regex]::Match($SectionText, $pattern)
    if (-not $match.Success) {
        return ''
    }

    return $match.Groups[1].Value.Trim()
}

function Get-WizardMarkdownBulletValues {
    param([string]$SectionText)

    $values = New-Object System.Collections.Generic.List[string]
    foreach ($line in (($SectionText ?? '') -split "`r?`n")) {
        $match = [regex]::Match($line, '^\s*[-*]\s+(.+?)\s*$')
        if ($match.Success) {
            $values.Add($match.Groups[1].Value.Trim()) | Out-Null
        }
    }

    return @($values.ToArray())
}

function Get-WizardMappingEntryNames {
    param([string[]]$Entries)

    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($Entries)) {
        $text = ($entry ?? '').Trim()
        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        $arrowMatch = [regex]::Match($text, '->\s*([a-z0-9_\.]+)\s*$')
        if ($arrowMatch.Success) {
            [void]$names.Add($arrowMatch.Groups[1].Value.Trim().ToLowerInvariant())
            continue
        }

        $parenMatch = [regex]::Match($text, '\((referencing|referenced)\)')
        if ($parenMatch.Success) {
            $entityMatches = [regex]::Matches($text, '\b[a-z][a-z0-9_]*\b')
            foreach ($entityMatch in $entityMatches) {
                $candidate = $entityMatch.Value.ToLowerInvariant()
                if (@('referencing', 'referenced') -contains $candidate) { continue }
                [void]$names.Add($candidate)
            }
            continue
        }

        $dotMatch = [regex]::Match($text, '\b([a-z][a-z0-9_]*)\.([a-z][a-z0-9_]*)\b')
        if ($dotMatch.Success) {
            [void]$names.Add($dotMatch.Groups[1].Value.Trim().ToLowerInvariant())
            continue
        }

        if ($text -match '\b([a-z][a-z0-9_]*)\b') {
            [void]$names.Add($Matches[1].Trim().ToLowerInvariant())
        }
    }

    return @($names | Sort-Object)
}

function Get-WizardJsonFiles {
    param(
        [string]$Folder,
        [string]$Filter
    )

    if ([string]::IsNullOrWhiteSpace($Folder) -or -not (Test-Path $Folder)) {
        return @()
    }

    return @(Get-ChildItem -Path $Folder -Filter $Filter -File -ErrorAction SilentlyContinue | Sort-Object Name)
}

function Get-WizardPayloadSummary {
    param([string]$PayloadsFolder)

    $summary = [ordered]@{
        Tables = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        TableFiles = @()
        ColumnTables = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        Columns = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        ColumnReferences = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        RelationshipEntities = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        Relationships = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        ProcessNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        ParseErrors = New-Object System.Collections.Generic.List[string]
    }

    foreach ($file in Get-WizardJsonFiles -Folder $PayloadsFolder -Filter 'table-*.json') {
        try {
            $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $entity = Get-WizardOptionalPropertyValue -InputObject $doc -PropertyName 'EntityDefinition'
            $logicalName = (Get-WizardOptionalPropertyValue -InputObject $entity -PropertyName 'LogicalName') ??
                (Get-WizardOptionalPropertyValue -InputObject $entity -PropertyName 'SchemaName') ??
                (Get-WizardOptionalPropertyValue -InputObject $doc -PropertyName 'LogicalName') ??
                (Get-WizardOptionalPropertyValue -InputObject $doc -PropertyName 'SchemaName')
            if (-not [string]::IsNullOrWhiteSpace($logicalName)) {
                [void]$summary.Tables.Add($logicalName.Trim().ToLowerInvariant())
            }
            $summary.TableFiles += $file.FullName
        } catch {
            $summary.ParseErrors.Add("[$($file.Name)] $($_.Exception.Message)") | Out-Null
        }
    }

    foreach ($file in Get-WizardJsonFiles -Folder $PayloadsFolder -Filter 'columns-*.json') {
        try {
            $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $table = Get-WizardOptionalPropertyValue -InputObject $doc -PropertyName 'TableLogicalName'
            if (-not [string]::IsNullOrWhiteSpace($table)) {
                [void]$summary.ColumnTables.Add($table.Trim().ToLowerInvariant())
            }
            foreach ($column in @((Get-WizardOptionalPropertyValue -InputObject $doc -PropertyName 'Columns' -Default @()))) {
                $logicalName = (Get-WizardOptionalPropertyValue -InputObject $column -PropertyName 'LogicalName') ??
                    (Get-WizardOptionalPropertyValue -InputObject $column -PropertyName 'SchemaName')
                if (-not [string]::IsNullOrWhiteSpace($logicalName)) {
                    [void]$summary.Columns.Add($logicalName.Trim().ToLowerInvariant())
                    if (-not [string]::IsNullOrWhiteSpace($table)) {
                        [void]$summary.ColumnReferences.Add("$($table.Trim().ToLowerInvariant()).$($logicalName.Trim().ToLowerInvariant())")
                    }
                }
            }
        } catch {
            $summary.ParseErrors.Add("[$($file.Name)] $($_.Exception.Message)") | Out-Null
        }
    }

    foreach ($file in Get-WizardJsonFiles -Folder $PayloadsFolder -Filter 'relationships-*.json') {
        try {
            $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $relationships = @((Get-WizardOptionalPropertyValue -InputObject $doc -PropertyName 'Relationships' -Default @($doc)))
            foreach ($relationship in $relationships) {
                $definition = Get-WizardOptionalPropertyValue -InputObject $relationship -PropertyName 'RelationshipDefinition'
                $schemaName = (Get-WizardOptionalPropertyValue -InputObject $relationship -PropertyName 'SchemaName') ??
                    (Get-WizardOptionalPropertyValue -InputObject $definition -PropertyName 'SchemaName')
                if (-not [string]::IsNullOrWhiteSpace($schemaName)) {
                    [void]$summary.Relationships.Add($schemaName.Trim().ToLowerInvariant())
                }

                foreach ($propertyName in @('ReferencedEntity', 'ReferencingEntity', 'Entity1LogicalName', 'Entity2LogicalName')) {
                    $candidate = (Get-WizardOptionalPropertyValue -InputObject $relationship -PropertyName $propertyName) ??
                        (Get-WizardOptionalPropertyValue -InputObject $definition -PropertyName $propertyName)
                    if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                        [void]$summary.RelationshipEntities.Add($candidate.Trim().ToLowerInvariant())
                    }
                }
            }
        } catch {
            $summary.ParseErrors.Add("[$($file.Name)] $($_.Exception.Message)") | Out-Null
        }
    }

    foreach ($file in Get-WizardJsonFiles -Folder $PayloadsFolder -Filter 'process-*.json') {
        try {
            $doc = Get-Content -Path $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $processName = Get-WizardOptionalPropertyValue -InputObject $doc -PropertyName 'BusinessProcessFlowName'
            if (-not [string]::IsNullOrWhiteSpace($processName)) {
                [void]$summary.ProcessNames.Add($processName.Trim())
            }
        } catch {
            $summary.ParseErrors.Add("[$($file.Name)] $($_.Exception.Message)") | Out-Null
        }
    }

    return [pscustomobject]@{
        Tables               = @($summary.Tables | Sort-Object)
        TableFiles           = @($summary.TableFiles)
        ColumnTables         = @($summary.ColumnTables | Sort-Object)
        Columns              = @($summary.Columns | Sort-Object)
        ColumnReferences     = @($summary.ColumnReferences | Sort-Object)
        RelationshipEntities = @($summary.RelationshipEntities | Sort-Object)
        Relationships        = @($summary.Relationships | Sort-Object)
        ProcessNames         = @($summary.ProcessNames | Sort-Object)
        ParseErrors          = @($summary.ParseErrors.ToArray())
    }
}

function Get-WizardFeatureConfig {
    param([string]$AnswersText)

    $reportSection = Get-WizardMarkdownSection -Markdown $AnswersText -Heading 'Optional Report Web Resources'
    $profileSection = Get-WizardMarkdownSection -Markdown $AnswersText -Heading 'Application Profile'
    $appSection = Get-WizardMarkdownSection -Markdown $AnswersText -Heading 'App Module'

    $reportEnabledLine = [regex]::Match($reportSection, '(?im)^-\s*Enabled:\s*(.+)$').Groups[1].Value.Trim()
    $selectedReportsLine = [regex]::Match($reportSection, '(?im)^-\s*Selected Reports:\s*(.+)$').Groups[1].Value.Trim()
    $appEnabledLine = [regex]::Match($appSection, '(?im)^-\s*Enabled:\s*(.+)$').Groups[1].Value.Trim()
    $appNameLine = [regex]::Match($appSection, '(?im)^-\s*App Name:\s*(.+)$').Groups[1].Value.Trim()
    $appUniqueNameLine = [regex]::Match($appSection, '(?im)^-\s*Unique Name:\s*(.+)$').Groups[1].Value.Trim()
    $navigationLine = [regex]::Match($appSection, '(?im)^-\s*Navigation Group:\s*(.+)$').Groups[1].Value.Trim()
    $applicationProfileLine = [regex]::Match($profileSection, '(?im)^-\s*Profile:\s*(.+)$').Groups[1].Value.Trim()
    $tableStrategyLine = [regex]::Match($profileSection, '(?im)^-\s*Table Strategy:\s*(.+)$').Groups[1].Value.Trim()
    $formStrategyLine = [regex]::Match($profileSection, '(?im)^-\s*Form Strategy:\s*(.+)$').Groups[1].Value.Trim()
    $entryPointTableLine = [regex]::Match($profileSection, '(?im)^-\s*Entry Point Table:\s*(.+)$').Groups[1].Value.Trim()
    $landingViewLine = [regex]::Match($profileSection, '(?im)^-\s*Landing View:\s*(.+)$').Groups[1].Value.Trim()
    $reviewAppModeLine = [regex]::Match($profileSection, '(?im)^-\s*Review App Mode:\s*(.+)$').Groups[1].Value.Trim()
    $requiredAppArtifactsLine = [regex]::Match($profileSection, '(?im)^-\s*Required App Artifacts:\s*(.+)$').Groups[1].Value.Trim()

    $selectedReports = @()
    if (-not [string]::IsNullOrWhiteSpace($selectedReportsLine)) {
        $selectedReports = @($selectedReportsLine.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    return [pscustomobject]@{
        ReportSectionPresent = -not [string]::IsNullOrWhiteSpace($reportSection)
        ReportEnabled = @('yes', 'y', 'true', '1') -contains $reportEnabledLine.ToLowerInvariant()
        SelectedReports = @($selectedReports)
        ProfileSectionPresent = -not [string]::IsNullOrWhiteSpace($profileSection)
        ApplicationProfile = $applicationProfileLine.ToLowerInvariant()
        TableStrategy = $tableStrategyLine.ToLowerInvariant()
        FormStrategy = $formStrategyLine.ToLowerInvariant()
        EntryPointTable = $entryPointTableLine.ToLowerInvariant()
        LandingView = $landingViewLine
        ReviewAppMode = $reviewAppModeLine.ToLowerInvariant()
        RequiredAppArtifacts = $requiredAppArtifactsLine
        AppSectionPresent = -not [string]::IsNullOrWhiteSpace($appSection)
        AppEnabled = @('yes', 'y', 'true', '1') -contains $appEnabledLine.ToLowerInvariant()
        AppName = $appNameLine
        AppUniqueName = $appUniqueNameLine
        NavigationGroup = $navigationLine
    }
}

function Get-WizardSolutionIdentity {
    param(
        [string]$AnswersText,
        [string]$PlanText,
        [string]$EnvText
    )

    $solutionName = [regex]::Match($PlanText, '(?im)^-\s*Solution unique name:\s*(.+)$').Groups[1].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($solutionName)) {
        $solutionName = [regex]::Match($AnswersText, '(?im)^12\.\s*Solution \(new/existing\):\s*.+?--\s*(.+)$').Groups[1].Value.Trim()
    }
    if ([string]::IsNullOrWhiteSpace($solutionName)) {
        $solutionName = [regex]::Match($EnvText, 'DV_SOLUTION_NAME\s*=\s*"([^"]+)"').Groups[1].Value.Trim()
    }

    $publisherPrefix = [regex]::Match($PlanText, '(?im)^-\s*Publisher prefix:\s*(.+)$').Groups[1].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($publisherPrefix)) {
        $publisherPrefix = [regex]::Match($AnswersText, '(?im)^13\.\s*Publisher prefix \(new/existing\):\s*.+?--\s*(.+)$').Groups[1].Value.Trim()
    }
    if ([string]::IsNullOrWhiteSpace($publisherPrefix)) {
        $publisherPrefix = [regex]::Match($EnvText, 'DV_PUBLISHER_PREFIX\s*=\s*"([^"]+)"').Groups[1].Value.Trim()
    }

    if ($solutionName -match '^.+?--\s*(.+)$') {
        $solutionName = $Matches[1].Trim()
    }
    if ($publisherPrefix -match '^.+?--\s*(.+)$') {
        $publisherPrefix = $Matches[1].Trim()
    }
    $solutionName = ($solutionName -replace '\s*\((new|existing)\)\s*$', '').Trim()
    $publisherPrefix = ($publisherPrefix -replace '\s*\((new|existing)\)\s*$', '').Trim()

    return [pscustomobject]@{
        SolutionName = $solutionName
        PublisherPrefix = $publisherPrefix.ToLowerInvariant()
    }
}

function Test-WizardBuildContract {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug = '',
        [string]$PayloadsFolder = '',
        [bool]$EnableBuildContractValidation = $true,
        [bool]$StrictMode = $true,
        [bool]$EnableAppModuleWiring = $true
    )

    $context = Get-WizardScenarioContext -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder
    $answersText = Read-WizardTextFile -Path $context.AnswersPath
    $specText = Read-WizardTextFile -Path $context.SpecPath
    $planText = Read-WizardTextFile -Path $context.PlanPath
    $tasksText = Read-WizardTextFile -Path $context.TasksPath
    $envText = Read-WizardTextFile -Path (Join-Path $RepoRoot '.env.ps1')

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $passes = New-Object System.Collections.Generic.List[string]

    if (-not $EnableBuildContractValidation) {
        $passes.Add('Build contract validation disabled by operator control.') | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($context.ScenarioSlug)) {
        $errors.Add('Unable to resolve scenario slug from specs/.') | Out-Null
    }

    foreach ($artifact in @(
        [pscustomobject]@{ Name = 'answers.md'; Path = $context.AnswersPath },
        [pscustomobject]@{ Name = 'spec.md'; Path = $context.SpecPath },
        [pscustomobject]@{ Name = 'plan.md'; Path = $context.PlanPath },
        [pscustomobject]@{ Name = 'tasks.md'; Path = $context.TasksPath }
    )) {
        if ([string]::IsNullOrWhiteSpace($artifact.Path) -or -not (Test-Path $artifact.Path)) {
            $errors.Add("Missing required planning artifact: $($artifact.Name)") | Out-Null
        } else {
            $passes.Add("Found $($artifact.Name).") | Out-Null
        }
    }

    $mappingSpec = Get-WizardMarkdownSection -Markdown $specText -Heading 'Explicit Entity Mapping (Required)'
    if ([string]::IsNullOrWhiteSpace($mappingSpec)) {
        $mappingSpec = Get-WizardMarkdownSection -Markdown $specText -Heading 'Explicit Entity Mapping'
    }
    $mappingPlan = Get-WizardMarkdownSection -Markdown $planText -Heading 'Explicit Entity Mapping (Required Before Payloads)'
    if ([string]::IsNullOrWhiteSpace($mappingPlan)) {
        $mappingPlan = Get-WizardMarkdownSection -Markdown $planText -Heading 'Explicit Entity Mapping (Required)'
    }

    if ([string]::IsNullOrWhiteSpace($mappingSpec) -or [string]::IsNullOrWhiteSpace($mappingPlan)) {
        $errors.Add('Explicit entity mapping is required in both spec.md and plan.md before payload execution.') | Out-Null
    } else {
        $passes.Add('Explicit entity mapping present in spec.md and plan.md.') | Out-Null
    }

    $identity = Get-WizardSolutionIdentity -AnswersText $answersText -PlanText $planText -EnvText $envText
    if ([string]::IsNullOrWhiteSpace($identity.SolutionName)) {
        $errors.Add('Solution identity is incomplete: solution unique name is missing.') | Out-Null
    } else {
        $passes.Add("Solution unique name resolved: $($identity.SolutionName)") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($identity.PublisherPrefix)) {
        $errors.Add('Solution identity is incomplete: publisher prefix is missing.') | Out-Null
    } else {
        $passes.Add("Publisher prefix resolved: $($identity.PublisherPrefix)") | Out-Null
    }

    $payloadSummary = Get-WizardPayloadSummary -PayloadsFolder $context.PayloadsFolder
    foreach ($parseError in @($payloadSummary.ParseErrors)) {
        $errors.Add("Payload parse error: $parseError") | Out-Null
    }

    $standardEntries = @(Get-WizardMarkdownBulletValues -SectionText (Get-WizardMarkdownSubsection -SectionText $mappingPlan -Heading 'Standard reused tables (display -> logical)'))
    $customEntries = @(Get-WizardMarkdownBulletValues -SectionText (Get-WizardMarkdownSubsection -SectionText $mappingPlan -Heading 'Custom tables to create (input -> generated logical)'))
    $fieldEntries = @(Get-WizardMarkdownBulletValues -SectionText (Get-WizardMarkdownSubsection -SectionText $mappingPlan -Heading 'Custom fields to add'))
    $relationshipEntries = @(Get-WizardMarkdownBulletValues -SectionText (Get-WizardMarkdownSubsection -SectionText $mappingPlan -Heading 'Relationships to create'))

    $standardLogicalNames = @(Get-WizardMappingEntryNames -Entries $standardEntries)
    $customLogicalNames = @(Get-WizardMappingEntryNames -Entries $customEntries)
    $fieldTableNames = @(Get-WizardMappingEntryNames -Entries $fieldEntries)
    $relationshipEntityNames = @(Get-WizardMappingEntryNames -Entries $relationshipEntries)

    if (@($customLogicalNames).Count -eq 0 -and @($payloadSummary.Tables).Count -gt 0) {
        $warnings.Add('No custom table mapping entries were found even though table payloads exist.') | Out-Null
    }

    foreach ($table in @($payloadSummary.Tables)) {
        if ($customLogicalNames -notcontains $table) {
            $errors.Add("Custom table payload '$table' is not declared in the explicit entity mapping.") | Out-Null
        }
    }

    foreach ($table in @($payloadSummary.ColumnTables + $payloadSummary.RelationshipEntities | Sort-Object -Unique)) {
        if (($customLogicalNames -notcontains $table) -and ($standardLogicalNames -notcontains $table)) {
            $errors.Add("Payload references table '$table' that is not declared in explicit entity mapping.") | Out-Null
        }
    }

    foreach ($table in @($fieldTableNames + $relationshipEntityNames | Sort-Object -Unique)) {
        if (($customLogicalNames -notcontains $table) -and ($standardLogicalNames -notcontains $table)) {
            $warnings.Add("Explicit mapping references '$table' outside the current payload-discovered entity set.") | Out-Null
        }
    }

    $featureConfig = Get-WizardFeatureConfig -AnswersText $answersText
    if ($featureConfig.ReportEnabled) {
        if ($featureConfig.SelectedReports.Count -eq 0) {
            $errors.Add('Optional reporting is enabled, but no Selected Reports were declared in answers.md.') | Out-Null
        } else {
            $passes.Add('Optional reporting inputs are present.') | Out-Null
        }
    } elseif ($featureConfig.ReportSectionPresent) {
        $passes.Add('Optional reporting inputs present and disabled.') | Out-Null
    }

    if ($payloadSummary.ProcessNames.Count -gt 0) {
        $passes.Add('Optional BPF payloads detected.') | Out-Null
    } elseif ($planText -match '(?i)business process flow') {
        $warnings.Add('Plan references a Business Process Flow, but no process-*.json payload exists yet.') | Out-Null
    }

    if ($EnableAppModuleWiring -and $featureConfig.AppSectionPresent) {
        if ($featureConfig.AppEnabled) {
            if ([string]::IsNullOrWhiteSpace($featureConfig.AppName)) {
                $errors.Add('App module wiring is enabled, but App Name is missing from answers.md.') | Out-Null
            }
            if ([string]::IsNullOrWhiteSpace($featureConfig.AppUniqueName)) {
                $errors.Add('App module wiring is enabled, but Unique Name is missing from answers.md.') | Out-Null
            }
            if ([string]::IsNullOrWhiteSpace($featureConfig.NavigationGroup)) {
                $warnings.Add('App module wiring is enabled, but Navigation Group is not specified. Default navigation will be used.') | Out-Null
            }
        } else {
            $passes.Add('App module section present and disabled.') | Out-Null
        }
    }

    $status = if ($errors.Count -gt 0) { 'failed' } elseif ($warnings.Count -gt 0) { 'warning' } else { 'passed' }
    if (-not $StrictMode -and $status -eq 'failed') {
        $status = 'warning'
    }

    return [pscustomobject]@{
        Status = $status
        StrictMode = $StrictMode
        ScenarioSlug = $context.ScenarioSlug
        SolutionName = $identity.SolutionName
        PublisherPrefix = $identity.PublisherPrefix
        FeatureConfig = $featureConfig
        PayloadSummary = $payloadSummary
        Errors = @($errors.ToArray())
        Warnings = @($warnings.ToArray())
        Passes = @($passes.ToArray())
    }
}

function Get-WizardArtifactPaths {
    param([string]$RepoRoot)

    $artifactRoot = Join-Path $RepoRoot '.wizard-metrics\artifacts'
    $manifestFolder = Join-Path $artifactRoot 'manifest'
    return [pscustomobject]@{
        ArtifactRoot = $artifactRoot
        ContractFolder = Join-Path $artifactRoot 'validation'
        ContaminationFolder = Join-Path $artifactRoot 'solution'
        ManifestFolder = $manifestFolder
        ContractJsonPath = Join-Path (Join-Path $artifactRoot 'validation') 'build-contract-validation.json'
        ContractMarkdownPath = Join-Path (Join-Path $artifactRoot 'validation') 'build-contract-validation.md'
        ContaminationJsonPath = Join-Path (Join-Path $artifactRoot 'solution') 'contamination-scan.json'
        ContaminationMarkdownPath = Join-Path (Join-Path $artifactRoot 'solution') 'contamination-scan.md'
        ManifestJsonPath = Join-Path $manifestFolder 'generated-artifact-manifest.json'
        ManifestMarkdownPath = Join-Path $manifestFolder 'generated-artifact-manifest.md'
    }
}

function Write-WizardBuildContractArtifacts {
    param(
        [string]$RepoRoot,
        [object]$ValidationResult
    )

    $paths = Get-WizardArtifactPaths -RepoRoot $RepoRoot
    New-Item -ItemType Directory -Path $paths.ContractFolder -Force | Out-Null
    $ValidationResult | ConvertTo-Json -Depth 12 | Set-Content -Path $paths.ContractJsonPath -Encoding UTF8

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Build Contract Validation') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Status: $($ValidationResult.Status)") | Out-Null
    $lines.Add("- Scenario: $($ValidationResult.ScenarioSlug)") | Out-Null
    $lines.Add("- Solution: $($ValidationResult.SolutionName)") | Out-Null
    $lines.Add("- Publisher Prefix: $($ValidationResult.PublisherPrefix)") | Out-Null

    foreach ($section in @(
        [pscustomobject]@{ Title = 'Pass'; Items = $ValidationResult.Passes },
        [pscustomobject]@{ Title = 'Warning'; Items = $ValidationResult.Warnings },
        [pscustomobject]@{ Title = 'Error'; Items = $ValidationResult.Errors }
    )) {
        $lines.Add('') | Out-Null
        $lines.Add("## $($section.Title)s") | Out-Null
        foreach ($item in @($section.Items)) {
            $lines.Add("- $item") | Out-Null
        }
        if (@($section.Items).Count -eq 0) {
            $lines.Add('- none') | Out-Null
        }
    }

    Set-Content -Path $paths.ContractMarkdownPath -Value ($lines -join "`r`n") -Encoding UTF8
    return $paths
}

function New-WizardExpectedArtifacts {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug = '',
        [string]$PayloadsFolder = '',
        [string]$PublisherPrefix = ''
    )

    $context = Get-WizardScenarioContext -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder
    $answersText = Read-WizardTextFile -Path $context.AnswersPath
    $payloadSummary = Get-WizardPayloadSummary -PayloadsFolder $context.PayloadsFolder
    $featureConfig = Get-WizardFeatureConfig -AnswersText $answersText
    $prefix = ($PublisherPrefix ?? '').Trim().ToLowerInvariant()

    $reportWebResources = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($reportName in @($featureConfig.SelectedReports)) {
        $slug = ConvertTo-WizardSafeSlug -Value $reportName
        if (-not [string]::IsNullOrWhiteSpace($prefix) -and -not [string]::IsNullOrWhiteSpace($slug)) {
            [void]$reportWebResources.Add("$prefix`_reports/$slug.html")
        }
    }
    if ($reportWebResources.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($prefix)) {
        [void]$reportWebResources.Add("$prefix`_reports/shared.css")
    }

    return [pscustomobject]@{
        Tables = @($payloadSummary.Tables)
        Columns = @($payloadSummary.ColumnReferences)
        Relationships = @($payloadSummary.Relationships)
        Bpfs = @($payloadSummary.ProcessNames)
        WebResources = @($reportWebResources | Sort-Object)
        Forms = @($payloadSummary.Tables | ForEach-Object { "$($_)|main" })
        Views = @($payloadSummary.Tables | ForEach-Object { "$($_)|active" })
        Dashboards = @()
        Charts = @()
        Flows = @()
        AppModules = if ($featureConfig.AppEnabled -and -not [string]::IsNullOrWhiteSpace($featureConfig.AppUniqueName)) { @($featureConfig.AppUniqueName) } else { @() }
        SiteMaps = if ($featureConfig.AppEnabled -and -not [string]::IsNullOrWhiteSpace($featureConfig.AppUniqueName)) { @("$([regex]::Replace($featureConfig.AppUniqueName.ToLowerInvariant(), '[^a-z0-9]+', '_').Trim('_'))_sitemap") } else { @() }
        FeatureConfig = $featureConfig
    }
}

function New-WizardContaminationVerdict {
    param(
        [object[]]$CurrentComponents,
        [object]$ExpectedArtifacts,
        [string]$PublisherPrefix = ''
    )

    $expected = @{
        table = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        column = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        relationship = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        webresource = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        form = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        view = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        dashboard = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        appmodule = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        sitemap = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        chart = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        flow = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        bpf = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    }

    foreach ($name in @($ExpectedArtifacts.Tables)) { [void]$expected.table.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.Columns)) { [void]$expected.column.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.Relationships)) { [void]$expected.relationship.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.WebResources)) { [void]$expected.webresource.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.Forms)) { [void]$expected.form.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.Views)) { [void]$expected.view.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.Dashboards)) { [void]$expected.dashboard.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.AppModules)) { [void]$expected.appmodule.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.SiteMaps)) { [void]$expected.sitemap.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.Charts)) { [void]$expected.chart.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.Flows)) { [void]$expected.flow.Add(($name ?? '').Trim().ToLowerInvariant()) }
    foreach ($name in @($ExpectedArtifacts.Bpfs)) { [void]$expected.bpf.Add(($name ?? '').Trim().ToLowerInvariant()) }

    $prefix = ($PublisherPrefix ?? '').Trim().ToLowerInvariant()
    $expectedItems = New-Object System.Collections.Generic.List[object]
    $wizardOther = New-Object System.Collections.Generic.List[object]
    $manualLegacy = New-Object System.Collections.Generic.List[object]

    foreach ($component in @($CurrentComponents)) {
        $kind = (($component.Kind ?? '') + '').Trim().ToLowerInvariant()
        $name = (($component.Name ?? '') + '').Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($kind) -or [string]::IsNullOrWhiteSpace($name)) { continue }

        $isExpected = $false
        if ($expected.ContainsKey($kind)) {
            $isExpected = $expected[$kind].Contains($name)
        }

        if ($isExpected) {
            $expectedItems.Add($component) | Out-Null
            continue
        }

        $looksWizardManaged = $false
        if (-not [string]::IsNullOrWhiteSpace($prefix)) {
            if (($kind -eq 'table' -or $kind -eq 'column' -or $kind -eq 'relationship' -or $kind -eq 'appmodule') -and $name -like "$prefix`_*") {
                $looksWizardManaged = $true
            }
            if ($kind -eq 'webresource' -and $name -like "$prefix`_reports/*") {
                $looksWizardManaged = $true
            }
        }
        if (($kind -eq 'bpf') -and $name -like 'wizard_*') {
            $looksWizardManaged = $true
        }

        if ($looksWizardManaged) {
            $wizardOther.Add($component) | Out-Null
        } else {
            $manualLegacy.Add($component) | Out-Null
        }
    }

    $verdict = if (($wizardOther.Count -eq 0) -and ($manualLegacy.Count -eq 0)) {
        'clean'
    } elseif ($manualLegacy.Count -gt 0) {
        'contaminated'
    } else {
        'warning'
    }

    return [pscustomobject]@{
        Verdict = $verdict
        Expected = @($expectedItems.ToArray())
        WizardOtherScenario = @($wizardOther.ToArray())
        ManualOrLegacy = @($manualLegacy.ToArray())
    }
}

function Write-WizardContaminationArtifacts {
    param(
        [string]$RepoRoot,
        [object]$ScanResult
    )

    $paths = Get-WizardArtifactPaths -RepoRoot $RepoRoot
    New-Item -ItemType Directory -Path $paths.ContaminationFolder -Force | Out-Null
    $ScanResult | ConvertTo-Json -Depth 12 | Set-Content -Path $paths.ContaminationJsonPath -Encoding UTF8

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Contamination Scan') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Verdict: $($ScanResult.Verdict)") | Out-Null

    foreach ($section in @(
        [pscustomobject]@{ Title = 'Expected'; Items = $ScanResult.Expected },
        [pscustomobject]@{ Title = 'Wizard Other Scenario'; Items = $ScanResult.WizardOtherScenario },
        [pscustomobject]@{ Title = 'Manual Or Legacy'; Items = $ScanResult.ManualOrLegacy }
    )) {
        $lines.Add('') | Out-Null
        $lines.Add("## $($section.Title)") | Out-Null
        foreach ($item in @($section.Items)) {
            $lines.Add("- [$($item.Kind)] $($item.Name)") | Out-Null
        }
        if (@($section.Items).Count -eq 0) {
            $lines.Add('- none') | Out-Null
        }
    }

    Set-Content -Path $paths.ContaminationMarkdownPath -Value ($lines -join "`r`n") -Encoding UTF8
    return $paths
}

function Get-WizardRunId {
    param([string]$RepoRoot)

    $currentRunPath = Join-Path (Join-Path $RepoRoot '.wizard-metrics') 'current-run.json'
    if (Test-Path $currentRunPath) {
        try {
            $state = Get-Content -Path $currentRunPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $runId = Get-WizardOptionalPropertyValue -InputObject $state -PropertyName 'RunId'
            if (-not [string]::IsNullOrWhiteSpace($runId)) {
                return $runId
            }
        } catch {
        }
    }

    return [guid]::NewGuid().ToString()
}

function Initialize-WizardArtifactManifest {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug,
        [string]$SolutionName,
        [string]$PublisherPrefix
    )

    $paths = Get-WizardArtifactPaths -RepoRoot $RepoRoot
    New-Item -ItemType Directory -Path $paths.ManifestFolder -Force | Out-Null

    if (-not (Test-Path $paths.ManifestJsonPath)) {
        $manifest = [ordered]@{
            scenarioSlug = $ScenarioSlug
            solutionName = $SolutionName
            publisherPrefix = $PublisherPrefix
            runId = Get-WizardRunId -RepoRoot $RepoRoot
            generatedAtUtc = [DateTime]::UtcNow.ToString('o')
            updatedAtUtc = [DateTime]::UtcNow.ToString('o')
            items = @()
        }
        $manifest | ConvertTo-Json -Depth 20 | Set-Content -Path $paths.ManifestJsonPath -Encoding UTF8
    }

    return $paths.ManifestJsonPath
}

function Add-WizardArtifactManifestItem {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug,
        [string]$SolutionName,
        [string]$PublisherPrefix,
        [string]$Kind,
        [string]$Name,
        [string]$Status,
        [string]$Step,
        [hashtable]$Details = $null
    )

    $manifestPath = Initialize-WizardArtifactManifest -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -SolutionName $SolutionName -PublisherPrefix $PublisherPrefix
    $manifest = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($manifest.items)) {
        $items.Add($item) | Out-Null
    }

    $normalizedKind = ($Kind ?? '').Trim().ToLowerInvariant()
    $normalizedName = ($Name ?? '').Trim()
    $updated = $false
    for ($index = 0; $index -lt $items.Count; $index++) {
        if ((($items[$index].kind ?? '') + '').Trim().ToLowerInvariant() -eq $normalizedKind -and (($items[$index].name ?? '') + '').Trim() -eq $normalizedName) {
            $items[$index] = [pscustomobject]@{
                kind = $normalizedKind
                name = $normalizedName
                status = $Status
                step = $Step
                updatedAtUtc = [DateTime]::UtcNow.ToString('o')
                details = if ($null -eq $Details) { @{} } else { $Details }
            }
            $updated = $true
            break
        }
    }

    if (-not $updated) {
        $items.Add([pscustomobject]@{
            kind = $normalizedKind
            name = $normalizedName
            status = $Status
            step = $Step
            updatedAtUtc = [DateTime]::UtcNow.ToString('o')
            details = if ($null -eq $Details) { @{} } else { $Details }
        }) | Out-Null
    }

    $manifest.items = @($items.ToArray())
    $manifest.updatedAtUtc = [DateTime]::UtcNow.ToString('o')
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -Path $manifestPath -Encoding UTF8

    Write-WizardArtifactManifestSummary -RepoRoot $RepoRoot | Out-Null
    return $manifestPath
}

function Write-WizardArtifactManifestSummary {
    param([string]$RepoRoot)

    $paths = Get-WizardArtifactPaths -RepoRoot $RepoRoot
    if (-not (Test-Path $paths.ManifestJsonPath)) {
        return ''
    }

    $manifest = Get-Content -Path $paths.ManifestJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Generated Artifact Manifest') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add("- Scenario: $($manifest.scenarioSlug)") | Out-Null
    $lines.Add("- Solution: $($manifest.solutionName)") | Out-Null
    $lines.Add("- Publisher Prefix: $($manifest.publisherPrefix)") | Out-Null
    $lines.Add("- Run Id: $($manifest.runId)") | Out-Null

    $grouped = @($manifest.items | Group-Object kind | Sort-Object Name)
    foreach ($group in $grouped) {
        $lines.Add('') | Out-Null
        $lines.Add("## $($group.Name)") | Out-Null
        foreach ($item in @($group.Group | Sort-Object name)) {
            $lines.Add("- $($item.name): $($item.status) [$($item.step)]") | Out-Null
        }
    }

    Set-Content -Path $paths.ManifestMarkdownPath -Value ($lines -join "`r`n") -Encoding UTF8
    return $paths.ManifestMarkdownPath
}

function Get-WizardAppModuleConfig {
    param(
        [string]$RepoRoot,
        [string]$ScenarioSlug = '',
        [string]$PayloadsFolder = '',
        [string]$PublisherPrefix = ''
    )

    $context = Get-WizardScenarioContext -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder
    $answersText = Read-WizardTextFile -Path $context.AnswersPath
    $planText = Read-WizardTextFile -Path $context.PlanPath
    $featureConfig = Get-WizardFeatureConfig -AnswersText $answersText
    $identity = Get-WizardSolutionIdentity -AnswersText $answersText -PlanText $planText -EnvText (Read-WizardTextFile -Path (Join-Path $RepoRoot '.env.ps1'))
    $expected = New-WizardExpectedArtifacts -RepoRoot $RepoRoot -ScenarioSlug $ScenarioSlug -PayloadsFolder $PayloadsFolder -PublisherPrefix $PublisherPrefix

    $scenarioName = [regex]::Match($answersText, '(?im)^-\s*Name:\s*(.+)$').Groups[1].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($scenarioName)) {
        $scenarioName = $context.ScenarioSlug
    }

    $appName = if (-not [string]::IsNullOrWhiteSpace($featureConfig.AppName)) { $featureConfig.AppName } else { $scenarioName }
    $appUniqueName = if (-not [string]::IsNullOrWhiteSpace($featureConfig.AppUniqueName)) {
        $featureConfig.AppUniqueName
    } elseif (-not [string]::IsNullOrWhiteSpace($identity.PublisherPrefix) -and -not [string]::IsNullOrWhiteSpace($scenarioName)) {
        "$($identity.PublisherPrefix)_$(ConvertTo-WizardSafeSlug -Value $scenarioName -replace '-', '_')"
    } else {
        ''
    }

    $navigationGroup = if (-not [string]::IsNullOrWhiteSpace($featureConfig.NavigationGroup)) { $featureConfig.NavigationGroup } else { 'Core Records' }

    $validationErrors = New-Object System.Collections.Generic.List[string]
    if ($featureConfig.AppEnabled) {
        if ([string]::IsNullOrWhiteSpace($appName)) {
            $validationErrors.Add('App module name could not be resolved.') | Out-Null
        }
        if ([string]::IsNullOrWhiteSpace($appUniqueName)) {
            $validationErrors.Add('App module unique name could not be resolved.') | Out-Null
        }
        if ($expected.Tables.Count -eq 0) {
            $validationErrors.Add('App module wiring requires at least one expected table.') | Out-Null
        }
        if ($featureConfig.ProfileSectionPresent) {
            if (@('standalone-model-driven', 'dynamics-sales-extension', 'dynamics-customer-service-extension', 'dynamics-field-service-extension', 'generic-dataverse-solution') -notcontains $featureConfig.ApplicationProfile) {
                $validationErrors.Add("Unsupported application profile '$($featureConfig.ApplicationProfile)'.") | Out-Null
            }
            if (@('oob-only', 'custom-only', 'hybrid') -notcontains $featureConfig.TableStrategy) {
                $validationErrors.Add("Unsupported table strategy '$($featureConfig.TableStrategy)'.") | Out-Null
            }
            if (@('create-new-forms', 'update-in-place') -notcontains $featureConfig.FormStrategy) {
                $validationErrors.Add("Unsupported form strategy '$($featureConfig.FormStrategy)'.") | Out-Null
            }
            if ($featureConfig.ReviewAppMode -ne 'create-or-update') {
                $validationErrors.Add("Application profiles require review app mode 'create-or-update'.") | Out-Null
            }
            if ($featureConfig.ReviewAppMode -eq 'create-or-update' -and [string]::IsNullOrWhiteSpace($featureConfig.RequiredAppArtifacts)) {
                $validationErrors.Add('Review app mode create-or-update requires the visible artifact scope.') | Out-Null
            }
            if ([string]::IsNullOrWhiteSpace($featureConfig.EntryPointTable)) {
                $validationErrors.Add('Application profile requires an entry-point table.') | Out-Null
            } elseif ($expected.Tables -notcontains $featureConfig.EntryPointTable) {
                $validationErrors.Add("Entry-point table '$($featureConfig.EntryPointTable)' is not in the expected app tables.") | Out-Null
            }
            if ([string]::IsNullOrWhiteSpace($featureConfig.LandingView)) {
                $validationErrors.Add('Application profile requires a landing view.') | Out-Null
            }
        }
    }

    return [pscustomobject]@{
        Enabled = $featureConfig.AppEnabled
        AppName = $appName
        UniqueName = $appUniqueName
        NavigationGroup = $navigationGroup
        ApplicationProfile = $featureConfig.ApplicationProfile
        TableStrategy = $featureConfig.TableStrategy
        FormStrategy = $featureConfig.FormStrategy
        EntryPointTable = $featureConfig.EntryPointTable
        LandingView = $featureConfig.LandingView
        ReviewAppMode = $featureConfig.ReviewAppMode
        RequiredAppArtifacts = $featureConfig.RequiredAppArtifacts
        ScenarioSlug = $context.ScenarioSlug
        SolutionName = $identity.SolutionName
        PublisherPrefix = $identity.PublisherPrefix
        Tables = @($expected.Tables)
        Forms = @($expected.Forms)
        Views = @($expected.Views)
        Dashboards = @($expected.Dashboards)
        Bpfs = @($expected.Bpfs)
        ValidationErrors = @($validationErrors.ToArray())
        ValidationPassed = $validationErrors.Count -eq 0
    }
}

function Get-WizardUpsertAction {
    param([object[]]$ExistingItems = @())

    if (@($ExistingItems).Count -gt 0) {
        return 'update'
    }
    return 'create'
}