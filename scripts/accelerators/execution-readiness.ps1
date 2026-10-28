<#
=============================================================================
COMPONENT:    Provider-Neutral Execution Readiness
FILE:         scripts/accelerators/execution-readiness.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Local evidence only
-----------------------------------------------------------------------------
OVERVIEW
Validates immutable planning and prerequisite evidence for human review only.
NON-NEGOTIABLES
No network, build stages, authorization issuance, or platform mutations.
=============================================================================
#>

. (Join-Path $PSScriptRoot 'build-planning-adapter.ps1')
. (Join-Path $PSScriptRoot 'verification-provenance.ps1')
. (Join-Path $PSScriptRoot 'environment-compatibility.ps1')

function Get-ExecutionPlanningPaths {
    param([string]$WorkspaceRoot, [string]$ScenarioSlug)
    $scenario = Join-Path $WorkspaceRoot "specs\$ScenarioSlug"
    $accelerator = Join-Path $scenario 'accelerator'
    return [ordered]@{
        decision = Join-Path $accelerator 'accelerator-decision.json'
        analysisManifest = Join-Path $accelerator 'accelerator-analysis-manifest.json'
        coverage = Join-Path $accelerator 'requirements-coverage-matrix.json'
        componentDelta = Join-Path $accelerator 'component-delta-analysis.json'
        schemaPlan = Join-Path $accelerator 'schema-reuse-extension-plan.json'
        dependencies = Join-Path $accelerator 'dependency-manifest.json'
        environment = Join-Path $accelerator 'environment-readiness-reference.json'
        traceability = Join-Path $accelerator 'acceptance-traceability.json'
        spec = Join-Path $scenario 'spec.md'
    }
}

function Get-ExecutionPlanIdentity {
    param([Parameter(Mandatory)] [object]$Plan)

    $basis = [ordered]@{}
    foreach ($name in @('scenarioSlug', 'decisionId', 'architecture', 'inputFingerprints',
        'environment', 'componentPlans', 'dependencyGraph', 'blockedActions',
        'remediationChecklist', 'authorizationRequirements', 'rollbackRecovery', 'traceability')) {
        $basis[$name] = $Plan.$name
    }
    return "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $basis))"
}

function Test-ExecutionSchema {
    param([object]$Value, [string]$SchemaName)

    $schemaPath = Join-Path $adapterRoot "schemas\accelerators\$SchemaName.schema.json"
    return Test-Json -Json (ConvertTo-Json -InputObject $Value -Depth 100) -SchemaFile $schemaPath -ErrorAction SilentlyContinue
}

function Resolve-ExecutionInputPath {
    param([string]$WorkspaceRoot, [string]$Path)

    $root = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\', '/')
    $candidate = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $root $Path }))
    if (-not $candidate.StartsWith("$root$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::OrdinalIgnoreCase)) {
        throw "Execution evidence input must be inside the workspace: $Path"
    }
    return $candidate
}

function Read-ExecutionArtifact {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ valid = $false; value = [pscustomobject]@{}; sha256 = $null; error = "Required local artifact is missing: $Path" }
    }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $text = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xfeff)
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    if (-not (Test-Json -Json $text -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{ valid = $false; value = [pscustomobject]@{}; sha256 = $hash; error = "Required local artifact is not valid JSON: $Path" }
    }
    return [pscustomobject]@{ valid = $true; value = ($text | ConvertFrom-Json -DateKind String); sha256 = $hash; error = '' }
}

function Get-ExecutionReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$WorkspaceRoot,
        [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9]+(?:-[a-z0-9]+)*$')] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [string]$EvidencePath,
        [Parameter(Mandatory)] [ValidatePattern('^https://[A-Za-z0-9.-]+(?::443)?/?$')] [string]$EnvironmentUrl,
        [Parameter(Mandatory)] [guid]$EnvironmentId,
        [Parameter(Mandatory)] [guid]$TenantId,
        [ValidateSet('Authenticated', 'RecordedTest', 'LocalPlanning')] [string]$EvidenceTrustPolicy = 'Authenticated',
        [Security.Cryptography.X509Certificates.X509Certificate2]$TrustedCertificate,
        [DateTimeOffset]$EvaluationTimeUtc = [DateTimeOffset]::UtcNow
    )

    $scenario = Join-Path $WorkspaceRoot "specs\$ScenarioSlug"
    $accelerator = Join-Path $scenario 'accelerator'
    $decisionPath = Join-Path $accelerator 'accelerator-decision.json'
    $planPath = Join-Path $accelerator 'build-plan\build-plan-manifest.json'
    $evidenceFile = Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $EvidencePath
    $decisionArtifact = Read-ExecutionArtifact -Path $decisionPath
    $planArtifact = Read-ExecutionArtifact -Path $planPath
    $evidenceArtifact = Read-ExecutionArtifact -Path $evidenceFile
    $decision = $decisionArtifact.value; $plan = $planArtifact.value; $evidence = $evidenceArtifact.value
    $envelope = $null
    $evidenceTrust = 'unverified'
    $provenance = $null
    if ($evidenceArtifact.valid -and
        (Get-BuildPlanningValue -InputObject $evidence -Name 'artifactType' -DefaultValue '') -ceq 'trusted-environment-verification') {
        $envelope = $evidence
        $provenance = Test-EnvironmentVerificationProvenance -Envelope $envelope -TrustedCertificate $TrustedCertificate `
            -EvidenceTrustPolicy $EvidenceTrustPolicy -EvaluationTimeUtc $EvaluationTimeUtc
        if (Test-ExecutionSchema -Value $envelope -SchemaName 'trusted-environment-verification') { $evidence = $envelope.payload.evidence }
        $evidenceTrust = $provenance.classification
    } elseif ($EvidenceTrustPolicy -eq 'LocalPlanning') { $evidenceTrust = 'local-planning' }
    $planHash = $planArtifact.sha256; $decisionHash = $decisionArtifact.sha256; $evidenceHash = $evidenceArtifact.sha256
    $findings = [Collections.Generic.List[object]]::new()
    $securityRequirements = [Collections.Generic.List[object]]::new()
    $verificationPackages = [Collections.Generic.List[object]]::new()
    $actualFingerprints = [ordered]@{}
    $dependencyOrder = @()
    $packageDependencyOrder = @()

    function Add-ReadinessFinding {
        param([string]$Status, [string]$Code, [string]$Message, [string]$Remediation, [string]$TaskId = '')
        $findings.Add([pscustomobject][ordered]@{
            status = $Status; code = $Code; taskId = $TaskId
            message = $Message; remediation = $Remediation
        }) | Out-Null
    }

    foreach ($artifact in @($decisionArtifact, $planArtifact, $evidenceArtifact)) {
        if (-not $artifact.valid) {
            Add-ReadinessFinding BLOCKED_EVIDENCE ARTIFACT_UNAVAILABLE $artifact.error 'Restore the exact approved local input and rerun preflight.'
        }
        if ($null -ne $provenance -and -not $provenance.valid) {
            Add-ReadinessFinding BLOCKED_EVIDENCE VERIFICATION_PROVENANCE $provenance.message 'Collect complete signed evidence and configure an independently trusted certificate.'
        } elseif ($null -eq $envelope -and $EvidenceTrustPolicy -ne 'LocalPlanning') {
            Add-ReadinessFinding BLOCKED_EVIDENCE SIGNED_EVIDENCE_REQUIRED 'Unsigned local assertions are not authenticated environment verification.' 'Run the explicitly enabled GET-only verifier; use LocalPlanning only for unverified diagnostics.'
        }
        if ($null -ne $provenance -and $provenance.valid) {
            foreach ($check in @($envelope.payload.checks | Where-Object { $_.requiredForReadiness -and -not $_.satisfied })) {
                Add-ReadinessFinding $check.blockingStatus "VERIFICATION_$($check.id)" $check.message 'Resolve the verified prerequisite or restriction and collect fresh evidence.'
            }
        }
    }
    $decisionValid = Test-ExecutionSchema -Value $decision -SchemaName 'architecture-decision'
    $planValid = Test-ExecutionSchema -Value $plan -SchemaName 'build-plan'
    $evidenceValid = Test-ExecutionSchema -Value $evidence -SchemaName 'execution-evidence'
    if (-not $decisionValid) {
        Add-ReadinessFinding BLOCKED_DECISION_CHANGE DECISION_SCHEMA 'Architecture approval is missing or malformed.' 'Obtain an explicit, schema-valid architecture approval.'
    }
    if (-not $planValid) {
        Add-ReadinessFinding BLOCKED_EVIDENCE PLAN_SCHEMA 'Build plan violates its versioned contract.' 'Regenerate and review the FAST-006 plan.'
    }
    if (-not $evidenceValid) {
        Add-ReadinessFinding BLOCKED_EVIDENCE EVIDENCE_SCHEMA 'Prerequisite evidence violates its versioned contract.' 'Supply complete version-1 evidence; do not infer missing values.'
    }

    if ($decisionValid -and $planValid -and $evidenceValid) {
        $basis = [ordered]@{
            scenarioSlug = $decision.scenarioSlug; mode = $decision.wizardMode
            evaluationStatus = $decision.evaluationStatus; analysisId = $decision.analysisId
            snapshotId = $decision.catalogSnapshotId; recommendedOption = $decision.recommendedOption
            selectedOption = $decision.selectedOption; selectedPackages = @($decision.selectedPackages)
            rationale = $decision.rationale
        }
        $expectedDecisionId = "sha256:$(Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $basis))"
        if ($decision.decisionId -cne $expectedDecisionId -or $decision.scenarioSlug -cne $ScenarioSlug -or
            $plan.scenarioSlug -cne $ScenarioSlug -or $plan.decisionId -cne $decision.decisionId -or
            $plan.architecture -cne $decision.selectedOption -or $evidence.decisionId -cne $decision.decisionId) {
            Add-ReadinessFinding BLOCKED_DECISION_CHANGE DECISION_IDENTITY 'Approved decision identity or architecture changed.' 'Reapprove the architecture and regenerate all dependent planning/evidence.'
        }
        if ($plan.planId -cne (Get-ExecutionPlanIdentity -Plan $plan) -or
            $evidence.planId -cne $plan.planId -or $evidence.planSha256 -cne $planHash) {
            Add-ReadinessFinding BLOCKED_DECISION_CHANGE PLAN_IDENTITY 'Build-plan ID or exact SHA-256 differs from the evidence binding.' 'Review the changed plan and collect newly bound evidence.'
        }
        $expectedEnvironment = [ordered]@{
            environmentId = $EnvironmentId.ToString(); tenantId = $TenantId.ToString()
            url = $EnvironmentUrl.TrimEnd('/').ToLowerInvariant()
        }
        if ($evidence.environment.environmentId -ine $expectedEnvironment.environmentId -or
            $evidence.environment.tenantId -ine $expectedEnvironment.tenantId -or
            $evidence.environment.url.TrimEnd('/').ToLowerInvariant() -cne $expectedEnvironment.url -or
            ($plan.architecture -ne 'fully-custom' -and
             $plan.environment.environmentUrl.TrimEnd('/').ToLowerInvariant() -cne $expectedEnvironment.url)) {
            Add-ReadinessFinding BLOCKED_DECISION_CHANGE ENVIRONMENT_IDENTITY 'Target environment or tenant differs from prerequisite evidence or plan.' 'Confirm the exact target and regenerate bound planning/evidence.'
        }
        if ($EnvironmentId -eq [guid]::Empty -or $TenantId -eq [guid]::Empty) {
            Add-ReadinessFinding BLOCKED_EVIDENCE EMPTY_ENVIRONMENT 'Target environment and tenant identities must not be empty GUIDs.' 'Supply independently confirmed target environment and tenant identifiers.'
        }
        if ([guid]$evidence.security.principalId -eq [guid]::Empty) {
            Add-ReadinessFinding BLOCKED_SECURITY EMPTY_PRINCIPAL 'Security evidence has no identified principal.' 'Collect permission evidence for the actual execution principal.'
        }
        $observed = [DateTimeOffset]::Parse($evidence.observedAtUtc)
        $expires = [DateTimeOffset]::Parse($evidence.expiresAtUtc)
        if ($observed -gt $EvaluationTimeUtc -or $expires -le $EvaluationTimeUtc -or
            $expires -le $observed -or ($expires - $observed).TotalHours -gt 24 -or
            ($EvaluationTimeUtc - $observed).TotalHours -gt 24) {
            Add-ReadinessFinding BLOCKED_EVIDENCE EVIDENCE_FRESHNESS 'Evidence is future-dated, expired, or exceeds the 24-hour maximum lifetime.' 'Collect fresh target-specific evidence with an expiry no more than 24 hours after observation.'
        }

        $knownPaths = Get-ExecutionPlanningPaths -WorkspaceRoot $WorkspaceRoot -ScenarioSlug $ScenarioSlug
        $inputPaths = @{}
        foreach ($key in @($knownPaths.Keys) + @($plan.inputFingerprints.PSObject.Properties.Name) | Sort-Object -Unique) {
            $entries = @($evidence.inputArtifacts | Where-Object key -CEQ $key)
            $fingerprint = Get-BuildPlanningValue -InputObject $plan.inputFingerprints -Name $key -DefaultValue ''
            if ($entries.Count -ne 1 -or "$fingerprint" -cnotmatch '^[a-f0-9]{64}$') {
                Add-ReadinessFinding BLOCKED_EVIDENCE INPUT_MISSING "Missing or duplicate pinned input '$key'." 'Supply every original FAST-006 input exactly once.'
                continue
            }
            $path = Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $entries[0].path
            if (($knownPaths.Contains($key) -and $path -ine $knownPaths[$key]) -or
                -not (Test-Path -LiteralPath $path -PathType Leaf)) {
                Add-ReadinessFinding BLOCKED_EVIDENCE INPUT_PATH "Pinned input '$key' is missing or at an unexpected path." 'Restore the scenario-local input; do not substitute another scenario.'
                continue
            }
            $actualFingerprints[$key] = Get-BuildPlanningFileHash -Path $path
            $inputPaths[$key] = $path
            if ($actualFingerprints[$key] -cne $fingerprint) {
                Add-ReadinessFinding BLOCKED_DECISION_CHANGE INPUT_CHANGED "Pinned planning input '$key' changed." 'Replan and obtain renewed approval eligibility for the changed input.'
            }
        }
        if (@($evidence.inputArtifacts).Count -ne @($plan.inputFingerprints.PSObject.Properties).Count) {
            Add-ReadinessFinding BLOCKED_EVIDENCE INPUT_SCOPE 'Evidence input scope differs from the build plan.' 'List only and all pinned planning inputs.'
        }

        $tasks = @($plan.componentPlans)
        $taskIds = @($tasks.taskId)
        $graphValid = $true
        foreach ($group in @($tasks | Group-Object taskId | Where-Object Count -gt 1)) {
            $graphValid = $false
            Add-ReadinessFinding BLOCKED_COMPATIBILITY DUPLICATE_TASK "Duplicate task '$($group.Name)'." 'Regenerate a plan with unique immutable task identities.' $group.Name
        }
        foreach ($group in @($tasks | Group-Object { "$($_.componentKind)|$($_.componentIdentity)" } | Where-Object Count -gt 1)) {
            foreach ($task in $group.Group) {
                Add-ReadinessFinding BLOCKED_COMPATIBILITY COMPONENT_CONFLICT "Multiple operations target '$($group.Name)'." 'Resolve overlapping component operations explicitly.' $task.taskId
            }
        }
        $remaining = @($tasks | Sort-Object taskId)
        while ($graphValid -and $remaining.Count -gt 0) {
            $ready = @($remaining | Where-Object {
                @($_.dependencies | Where-Object { $dependencyOrder -cnotcontains $_ }).Count -eq 0
            })
            if ($ready.Count -eq 0) {
                $graphValid = $false
                Add-ReadinessFinding BLOCKED_COMPATIBILITY DEPENDENCY_GRAPH 'Dependency graph has a cycle or unresolved task.' 'Resolve missing dependencies and cycles before review.'
                break
            }
            $dependencyOrder += @($ready.taskId)
            $remaining = @($remaining | Where-Object { $dependencyOrder -cnotcontains $_.taskId })
        }
        $expectedEdges = @(
            foreach ($task in $tasks) {
                foreach ($dependency in $task.dependencies) { "$dependency|$($task.taskId)" }
            }
        ) | Sort-Object
        $actualEdges = @($plan.dependencyGraph.edges | ForEach-Object { "$($_.from)|$($_.to)" } | Sort-Object)
        if (($expectedEdges -join "`n") -cne ($actualEdges -join "`n") -or
            (@($taskIds | Sort-Object) -join "`n") -cne (@($plan.dependencyGraph.nodes | Sort-Object) -join "`n") -or
            ($dependencyOrder -join "`n") -cne (@($plan.dependencyGraph.orderedTaskIds) -join "`n")) {
            Add-ReadinessFinding BLOCKED_COMPATIBILITY GRAPH_PROJECTION 'Dependency graph does not match component prerequisites and deterministic ordering.' 'Regenerate the dependency graph from the component tasks.'
        }

        $coverage = if ($inputPaths.ContainsKey('coverage')) { @(Read-BuildPlanningJson -Path $inputPaths.coverage) } else { @() }
        $acceptance = if ($inputPaths.ContainsKey('traceability')) { @(Read-BuildPlanningJson -Path $inputPaths.traceability) } else { @() }
        if ($coverage.Count -eq 0 -or $acceptance.Count -eq 0 -or $tasks.Count -eq 0) {
            Add-ReadinessFinding BLOCKED_EVIDENCE TRACEABILITY_EMPTY 'Requirements, acceptance evidence or component plan is empty.' 'Provide complete requirement-to-component acceptance traceability.'
        }
        $requirementIds = @($coverage | ForEach-Object { "$($_.requirementId)" })
        foreach ($id in $requirementIds) {
            $traces = @($plan.traceability | Where-Object requirementId -CEQ $id)
            $criteria = @($acceptance | Where-Object requirementId -CEQ $id)
            $coveredTasks = @($tasks | Where-Object { $_.requirementIds -ccontains $id } | ForEach-Object taskId | Sort-Object)
            if ($traces.Count -ne 1 -or $criteria.Count -ne 1 -or $coveredTasks.Count -eq 0 -or
                @($traces[0].acceptanceCriteria).Count -eq 0 -or
                @($traces[0].acceptanceCriteria | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or
                $traces[0].decisionId -cne $decision.decisionId -or
                (@($traces[0].taskIds | Sort-Object) -join "`n") -cne ($coveredTasks -join "`n") -or
                (@($traces[0].acceptanceCriteria | Sort-Object) -join "`n") -cne (@($criteria[0].acceptanceCriteria | Sort-Object) -join "`n") -or
                (@($coverage | Where-Object requirementId -CEQ $id | ForEach-Object acceptanceCriteria | Sort-Object) -join "`n") -cne
                (@($traces[0].acceptanceCriteria | Sort-Object) -join "`n")) {
                Add-ReadinessFinding BLOCKED_EVIDENCE TRACEABILITY_GAP "Requirement '$id' has incomplete or inconsistent acceptance/task coverage." 'Restore exact bidirectional requirement, task and acceptance mappings.'
            }
        }
        if (@($requirementIds | Sort-Object -Unique).Count -ne $requirementIds.Count -or
            @($plan.traceability).Count -ne $requirementIds.Count) {
            Add-ReadinessFinding BLOCKED_EVIDENCE TRACEABILITY_SCOPE 'Duplicate or extraneous requirement mappings exist.' 'Use one acceptance mapping per approved requirement.'
        }

        foreach ($task in $tasks) {
            $permissions = @('read-metadata')
            if ($task.action -in @('CREATE', 'EXTEND')) { $permissions += 'customize'; $permissions += 'write-solution' }
            if ($task.action -eq 'INTEGRATE') { $permissions += 'configure-integration' }
            foreach ($permission in $permissions) {
                $granted = $evidence.security.grantedPermissions -ccontains $permission
                $securityRequirements.Add([pscustomobject][ordered]@{
                    taskId = $task.taskId; permission = $permission
                    principalId = $evidence.security.principalId; satisfied = $granted
                }) | Out-Null
                if (-not $granted) {
                    Add-ReadinessFinding BLOCKED_SECURITY PERMISSION_MISSING "Principal lacks '$permission' for '$($task.taskId)'." 'Have an authorized administrator verify the required scoped permission; preflight grants nothing.' $task.taskId
                }
            }
            if (@($task.requirementIds).Count -eq 0 -or
                @($task.requirementIds | Where-Object { $requirementIds -cnotcontains $_ }).Count -gt 0) {
                Add-ReadinessFinding BLOCKED_EVIDENCE TASK_TRACEABILITY "Task '$($task.taskId)' lacks approved requirement coverage." 'Associate every task with approved requirement IDs.' $task.taskId
            }
            $component = @($evidence.components | Where-Object taskId -CEQ $task.taskId)
            if ($component.Count -ne 1) {
                Add-ReadinessFinding BLOCKED_EVIDENCE COMPONENT_EVIDENCE "Missing or duplicate ownership evidence for '$($task.taskId)'." 'Collect component identity, existence, ownership and managed-property evidence.' $task.taskId
                continue
            }
            $component = $component[0]
            if ($component.componentKind -cne $task.componentKind -or $component.componentIdentity -ine $task.componentIdentity -or
                $component.ownership -cne $task.ownership -or $component.managed -ne $task.managed -or
                $task.ownership -eq 'unresolved') {
                Add-ReadinessFinding BLOCKED_COMPATIBILITY OWNERSHIP_CONFLICT "Ownership or component identity conflicts for '$($task.componentIdentity)'." 'Resolve actual component ownership without recreating managed components.' $task.taskId
            }
            if ($task.status -ne 'planned' -or $task.action -eq 'DEFER' -or
                $component.allowedActions -cnotcontains $task.action -or
                ($task.managed -and ($task.directModificationAllowed -or $task.action -notin @('REUSE', 'EXTEND'))) -or
                ($task.action -eq 'CREATE' -and $component.exists) -or
                ($task.action -in @('REUSE', 'EXTEND') -and -not $component.exists) -or
                ($task.action -eq 'EXTEND' -and (-not $component.customizable -or $task.directModificationAllowed)) -or
                ($task.action -eq 'CREATE' -and $task.ownership -ne 'solution-owned')) {
                Add-ReadinessFinding BLOCKED_COMPATIBILITY OPERATION_RESTRICTED "Unsupported, conflicting, destructive or restricted operation '$($task.action)' on '$($task.componentIdentity)'." 'Use verified separate extensions; never overwrite managed definitions or infer customization rights.' $task.taskId
            }
        }
        if (@($evidence.components).Count -ne $tasks.Count) {
            Add-ReadinessFinding BLOCKED_EVIDENCE COMPONENT_SCOPE 'Component evidence scope differs from the plan.' 'Collect exactly one evidence entry per planned task.'
        }

        if ($plan.status -eq 'blocked' -or @($plan.blockedActions).Count -gt 0) {
            Add-ReadinessFinding BLOCKED_PREREQUISITES PLAN_BLOCKED 'The immutable build plan retains blocked operations.' 'Resolve every blocked action and regenerate the plan before human review.'
        }
        if ($plan.architecture -eq 'fully-custom') {
            if (@($decision.selectedPackages).Count -gt 0 -or @($evidence.packages).Count -gt 0 -or
                $plan.environment.requiredForArchitecture -or @($tasks | Where-Object ownership -EQ 'accelerator-managed').Count -gt 0) {
                Add-ReadinessFinding BLOCKED_COMPATIBILITY CUSTOM_ISOLATION 'Fully Custom inherited accelerator prerequisites or ownership.' 'Remove accelerator dependencies and regenerate a genuinely Fully Custom plan.'
            }
        } else {
            $packageGraphValid = $true
            $packageDependencies = @{}
            foreach ($group in @($evidence.packages | Group-Object solutionUniqueName | Where-Object Count -gt 1)) {
                $packageGraphValid = $false
                Add-ReadinessFinding BLOCKED_COMPATIBILITY DUPLICATE_PACKAGE "Duplicate solution dependency '$($group.Name)'." 'Supply one unambiguous identity/version for every required solution.'
            }
            foreach ($package in $evidence.packages) {
                $packageDependencies[$package.solutionUniqueName] = @($package.dependencies)
                foreach ($dependency in $package.dependencies) {
                    $found = @($evidence.packages | Where-Object solutionUniqueName -CEQ $dependency)
                    if ($found.Count -ne 1 -or -not $found[0].installed) {
                        Add-ReadinessFinding BLOCKED_PREREQUISITES TRANSITIVE_DEPENDENCY "Dependency '$dependency' required by '$($package.solutionUniqueName)' is unavailable." 'Collect all transitive dependency identities and installation evidence.'
                    }
                }
            }
            if (-not $plan.environment.gateOpen) {
                Add-ReadinessFinding BLOCKED_PREREQUISITES PLAN_PREREQUISITES 'The approved plan retains unresolved environment prerequisites.' 'Resolve prerequisites and regenerate the plan; do not bypass its gate.'
            }
            if (@($decision.selectedPackages).Count -eq 0 -or -not $inputPaths.ContainsKey('packageManifest')) {
                Add-ReadinessFinding BLOCKED_EVIDENCE PACKAGE_MANIFEST 'Accelerator architecture lacks pinned package metadata.' 'Provide the original package input manifest and verified metadata.'
            } else {
                $manifest = Read-BuildPlanningJson -Path $inputPaths.packageManifest
                if (-not (Test-ExecutionSchema -Value $manifest -SchemaName 'package-input-manifest')) {
                    Add-ReadinessFinding BLOCKED_EVIDENCE PACKAGE_SCHEMA 'Package input manifest is malformed.' 'Restore the versioned package manifest.'
                } else {
                    $packagesToCheck = [Collections.Generic.List[object]]::new()
                    foreach ($selected in $decision.selectedPackages) { $packagesToCheck.Add($selected) | Out-Null }
                    foreach ($package in $evidence.packages) {
                        if (@($packagesToCheck | Where-Object { $_.moduleId -ceq $package.moduleId -and $_.packageId -ceq $package.packageId }).Count -eq 0) {
                            $entries = @($manifest.packages | Where-Object { $_.moduleId -ceq $package.moduleId -and $_.packageId -ceq $package.packageId })
                            if ($entries.Count -ne 1) {
                                Add-ReadinessFinding BLOCKED_EVIDENCE DEPENDENCY_METADATA "Dependency '$($package.solutionUniqueName)' lacks pinned package metadata." 'Include every transitive package identity and metadata in the reviewed build-plan inputs.'
                            } else { $packagesToCheck.Add($entries[0]) | Out-Null }
                        }
                    }
                    foreach ($selected in $packagesToCheck) {
                        $entries = @($manifest.packages | Where-Object { $_.moduleId -ceq $selected.moduleId -and $_.packageId -ceq $selected.packageId })
                        $installed = @($evidence.packages | Where-Object { $_.moduleId -ceq $selected.moduleId -and $_.packageId -ceq $selected.packageId })
                        if ($entries.Count -ne 1 -or $installed.Count -ne 1) {
                            Add-ReadinessFinding BLOCKED_PREREQUISITES PACKAGE_MISSING "Required package '$($selected.moduleId)' is missing or ambiguous." 'Supply exact package metadata and installed solution evidence.'
                            continue
                        }
                        $entry = $entries[0]; $installed = $installed[0]
                        $metadataReference = if ([IO.Path]::IsPathRooted($entry.path)) { $entry.path } else {
                            Join-Path (Split-Path $inputPaths.packageManifest -Parent) $entry.path
                        }
                        $metadataPath = Resolve-ExecutionInputPath -WorkspaceRoot $WorkspaceRoot -Path $metadataReference
                        $metadata = Read-BuildPlanningJson -Path $metadataPath
                        $actualFingerprints["package:$($selected.moduleId)"] = Get-BuildPlanningFileHash -Path $metadataPath
                        if (-not (Test-ExecutionSchema -Value $metadata -SchemaName 'package-metadata')) {
                            Add-ReadinessFinding BLOCKED_EVIDENCE PACKAGE_METADATA 'Package metadata is malformed.' 'Restore package-verified metadata.'
                            continue
                        }
                        $verificationPackages.Add($metadata) | Out-Null
                        if ($metadata.moduleId -cne $selected.moduleId -or $metadata.packageId -cne $selected.packageId -or
                            $metadata.sha256 -cne $selected.sha256 -or $entry.sha256 -cne $selected.sha256 -or
                            $metadata.solution.version -cne $selected.version -or $entry.version -cne $selected.version -or
                            $installed.sha256 -cne $selected.sha256 -or $installed.version -cne $selected.version -or
                            $installed.solutionUniqueName -cne $metadata.solution.uniqueName) {
                            Add-ReadinessFinding BLOCKED_DECISION_CHANGE PACKAGE_IDENTITY "Package identity/version/hash changed for '$($selected.moduleId)'." 'Reapprove changed package identities and recollect evidence.'
                        }
                        if (-not $installed.installed) {
                            Add-ReadinessFinding BLOCKED_PREREQUISITES SOLUTION_NOT_INSTALLED "Required solution '$($installed.solutionUniqueName)' is not installed." 'Arrange separately authorized prerequisite provisioning; preflight installs nothing.'
                        }
                        $requiredSolutions = @($installed.dependencies)
                        foreach ($declared in $metadata.declaredDependencies) {
                            $required = Get-BuildPlanningValue -InputObject $declared -Name 'required'
                            $solution = "$(Get-BuildPlanningValue -InputObject $required -Name 'solution' -DefaultValue '')"
                            if ($solution -match '^([A-Za-z0-9_]+) \(([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\)$') {
                                $name = $Matches[1]; $minimum = [version]$Matches[2]
                                $requiredSolutions += $name
                                $packageDependencies[$installed.solutionUniqueName] += $name
                                $matches = @($evidence.packages | Where-Object solutionUniqueName -CEQ $name)
                                if ($matches.Count -ne 1 -or -not $matches[0].installed -or [version]$matches[0].version -lt $minimum) {
                                    Add-ReadinessFinding BLOCKED_PREREQUISITES DECLARED_DEPENDENCY "Declared solution dependency '$solution' is unavailable." 'Supply installed dependency evidence meeting the package minimum version.'
                                }
                            } else {
                                Add-ReadinessFinding BLOCKED_EVIDENCE UNRESOLVED_DEPENDENCY 'A declared package dependency cannot be resolved to a solution and version.' 'Resolve component/platform dependencies explicitly; never assume compatibility.'
                            }
                        }
                        foreach ($name in @($requiredSolutions | Sort-Object -Unique)) {
                            $matches = @($evidence.packages | Where-Object solutionUniqueName -CEQ $name)
                            if ($matches.Count -ne 1 -or -not $matches[0].installed) {
                                Add-ReadinessFinding BLOCKED_PREREQUISITES PACKAGE_DEPENDENCY "Required dependency '$name' is missing or ambiguous." 'Collect installed dependency identity and version evidence.'
                            }
                        }
                    }
                    $pendingPackages = @($evidence.packages | Sort-Object solutionUniqueName)
                    while ($packageGraphValid -and $pendingPackages.Count -gt 0) {
                        $readyPackages = @($pendingPackages | Where-Object {
                            @($packageDependencies[$_.solutionUniqueName] | Where-Object { $packageDependencyOrder -cnotcontains $_ }).Count -eq 0
                        })
                        if ($readyPackages.Count -eq 0) {
                            Add-ReadinessFinding BLOCKED_COMPATIBILITY PACKAGE_CYCLE 'Package dependencies contain a cycle or unresolved solution.' 'Resolve the package dependency graph before human review.'
                            break
                        }
                        $packageDependencyOrder += @($readyPackages.solutionUniqueName)
                        $pendingPackages = @($pendingPackages | Where-Object { $packageDependencyOrder -cnotcontains $_.solutionUniqueName })
                    }
                }
            }
        }
    }

    if ($null -ne $envelope -and $null -ne $provenance -and $provenance.valid -and $decisionValid -and $planValid) {
        if ($envelope.payload.decisionSha256 -cne $decisionHash -or
            $envelope.payload.catalogSnapshotId -cne $decision.catalogSnapshotId -or
            $envelope.payload.dependencyManifestSha256 -cne (Get-BuildPlanningValue -InputObject $plan.inputFingerprints -Name 'dependencies') -or
            (ConvertTo-AcceleratorCanonicalJson -InputObject $envelope.payload.selectedPackages) -cne
                (ConvertTo-AcceleratorCanonicalJson -InputObject $decision.selectedPackages) -or
            (ConvertTo-AcceleratorCanonicalJson -InputObject $envelope.payload.inputFingerprints) -cne
                (ConvertTo-AcceleratorCanonicalJson -InputObject $actualFingerprints) -or
            $envelope.payload.authenticatedIdentity.principalId -cne $evidence.security.principalId) {
            Add-ReadinessFinding BLOCKED_DECISION_CHANGE VERIFICATION_BINDING 'Signed verification no longer matches the exact planning, packages, catalog, dependencies or authenticated principal.' 'Recollect evidence for the current approved artifacts and environment.'
        }
    }
    if ($null -ne $envelope -and $planValid -and $evidenceValid -and
        (Test-ExecutionSchema -Value $envelope -SchemaName 'trusted-environment-verification') -and
        -not (Test-VerificationCheckScope -Envelope $envelope -Plan $plan -PackageMetadata $verificationPackages.ToArray())) {
        Add-ReadinessFinding BLOCKED_EVIDENCE VERIFICATION_SCOPE 'Signed observations omit, duplicate or downgrade checks required by the exact operation scope.' 'Recollect every required identity, component, ownership and effective privilege observation.'
    }
    $sortedFindings = @($findings | Sort-Object status, code, taskId, message -Unique)
    $status = 'READY_FOR_APPROVAL'
    foreach ($candidate in @('BLOCKED_DECISION_CHANGE', 'BLOCKED_EVIDENCE', 'BLOCKED_COMPATIBILITY', 'BLOCKED_SECURITY', 'BLOCKED_PREREQUISITES')) {
        if (@($sortedFindings | Where-Object status -EQ $candidate).Count -gt 0) { $status = $candidate; break }
    }
    $target = [ordered]@{ environmentId = $EnvironmentId.ToString(); tenantId = $TenantId.ToString(); url = $EnvironmentUrl.TrimEnd('/').ToLowerInvariant() }
    $scope = [ordered]@{
        decisionSha256 = $decisionHash; planSha256 = $planHash; evidenceSha256 = $evidenceHash
        environment = $target; inputFingerprints = $actualFingerprints; evidenceTrustPolicy = $EvidenceTrustPolicy
    }
    $report = [pscustomobject][ordered]@{
        schemaVersion = '1.1'; scenarioSlug = $ScenarioSlug; status = $status
        eligibleForHumanApproval = $status -eq 'READY_FOR_APPROVAL'; executionAuthorized = $false
        evidenceTrust = $evidenceTrust
        verifiedForHumanReview = $status -eq 'READY_FOR_APPROVAL' -and $evidenceTrust -eq 'authenticated'
        evaluatedAtUtc = $EvaluationTimeUtc.ToUniversalTime().ToString('o')
        decisionId = "$(Get-BuildPlanningValue -InputObject $decision -Name 'decisionId' -DefaultValue '')"
        planId = "$(Get-BuildPlanningValue -InputObject $plan -Name 'planId' -DefaultValue '')"
        planSha256 = $planHash; decisionSha256 = $decisionHash; evidenceSha256 = $evidenceHash
        scopeSha256 = Get-AcceleratorStringSha256 -Value (ConvertTo-AcceleratorCanonicalJson -InputObject $scope)
        environment = [pscustomobject]$target; authorizedOperationCategories = @()
        findings = $sortedFindings
        blockedOperations = @(if ($status -eq 'READY_FOR_APPROVAL') { } elseif ($planValid) { $plan.componentPlans.taskId | Sort-Object -Unique } else { '*' })
        dependencyOrder = @($dependencyOrder)
        packageDependencyOrder = @($packageDependencyOrder)
        componentOwnership = @(if ($planValid) {
            foreach ($task in $plan.componentPlans) {
                $ownership = $task | Select-Object taskId, componentKind, componentIdentity, action, ownership, managed, directModificationAllowed
                $observed = @(if ($evidenceValid) { $evidence.components | Where-Object taskId -CEQ $task.taskId })
                $ownership | Add-Member -NotePropertyName evidence -NotePropertyValue $observed
                $ownership
            }
        })
        securityRequirements = @($securityRequirements | Sort-Object taskId, permission)
        acceptanceTraceability = @(if ($planValid) { $plan.traceability | Sort-Object requirementId })
    }
    if (-not (Test-Json -Json ($report | ConvertTo-Json -Depth 100) `
        -SchemaFile (Join-Path $adapterRoot 'schemas\accelerators\execution-readiness.schema.json') -ErrorAction Stop)) {
        throw 'Execution-readiness output failed schema validation.'
    }
    return $report
}
