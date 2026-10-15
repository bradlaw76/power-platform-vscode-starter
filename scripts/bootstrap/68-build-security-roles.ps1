<#
=============================================================================
COMPONENT:    Build Demo Security Roles
FILE:         scripts/bootstrap/68-build-security-roles.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Dataverse Web API

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
Creates or updates scenario-owned Dataverse security roles from a validated
security-roles-*.json payload. Preview is the default and never calls Dataverse.

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Apply requires explicit Mode Apply.
- Role assignment, user creation, field security, and SharePoint are out of scope.
- Existing same-name roles are adopted only when the scenario ownership marker
  and exact solution membership are present.
- ReplacePrivilegesRole sets the exact payload-defined privilege set.
=============================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ScenarioSlug,
    [string]$PayloadsFolder = '',
    [ValidateSet('Preview', 'Apply')] [string]$Mode = 'Preview',
    [switch]$PreviewOnly,
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [scriptblock]$RequestInvoker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'helpers/dataverse-runtime.ps1')
if ($PreviewOnly) { $Mode = 'Preview' }

function Get-WizardSecurityRolesPayload {
    param([Parameter(Mandatory)] [string]$Folder)

    $files = @(Get-ChildItem -LiteralPath $Folder -Filter 'security-roles-*.json' -File -ErrorAction SilentlyContinue)
    if ($files.Count -ne 1) {
        throw "Expected exactly one security-role payload; found $($files.Count)."
    }
    $schemaPath = Join-Path $repoRoot 'schemas/payloads/security-roles.schema.json'
    $json = Get-Content -LiteralPath $files[0].FullName -Raw -Encoding UTF8
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "Security-role payload '$($files[0].Name)' failed schema validation."
    }
    return $json | ConvertFrom-Json -Depth 20
}

function Get-WizardPrivilegeDepthValue {
    param([Parameter(Mandatory)] [string]$Depth)

    $values = @{ Basic = 0; Local = 1; Deep = 2; Global = 3 }
    if (-not $values.ContainsKey($Depth)) { throw "Unsupported privilege depth '$Depth'." }
    return [int]$values[$Depth]
}

function Get-WizardRolePrivilegePlan {
    param(
        [Parameter(Mandatory)] [object]$Role,
        [Parameter(Mandatory)] [string]$Depth
    )

    $depthValue = Get-WizardPrivilegeDepthValue -Depth $Depth
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($table in @($Role.TablePrivileges)) {
        foreach ($action in @($table.Actions)) {
            if ($action -in @('Delete', 'Share')) {
                throw "Role '$($Role.Name)' contains prohibited demo privilege '$action'."
            }
            [void]$items.Add([pscustomobject]@{
                TableLogicalName = "$($table.TableLogicalName)"
                Action = "$action"
                PrivilegeName = "prv$action$($table.PrivilegeStem)"
                Depth = $Depth
                DepthValue = $depthValue
            })
        }
    }

    $duplicates = @($items | Group-Object PrivilegeName | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) {
        throw "Role '$($Role.Name)' contains duplicate privilege '$($duplicates[0].Name)'."
    }
    return @($items | Sort-Object PrivilegeName)
}

function ConvertTo-WizardRolePrivilegeKey {
    param([Parameter(Mandatory)] [object]$Privilege)

    $id = "$($Privilege.PrivilegeId)".Trim().Trim('{', '}').ToLowerInvariant()
    $depth = "$($Privilege.Depth)"
    $depthValue = switch -Regex ($depth) {
        '^Basic$' { 0; break }
        '^Local$' { 1; break }
        '^Deep$' { 2; break }
        '^Global$' { 3; break }
        default { [int]$Privilege.Depth }
    }
    return "$id|$depthValue"
}

function Invoke-WizardSecurityRoleStage {
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$ScenarioSlug,
        [Parameter(Mandatory)] [string]$PayloadsFolder,
        [ValidateSet('Preview', 'Apply')] [string]$Mode = 'Preview',
        [string]$EnvironmentUrl,
        [string]$AccessToken,
        [string]$SolutionUniqueName,
        [scriptblock]$RequestInvoker
    )

    $payload = Get-WizardSecurityRolesPayload -Folder $PayloadsFolder
    if (-not $payload.Enabled) { return @() }
    if ($payload.AssignmentsEnabled -or $payload.FieldSecurityProfilesEnabled -or
        $payload.SharePointProvisioningEnabled -or $payload.DeleteAllowed -or $payload.ShareAllowed) {
        throw 'The demo security-role stage cannot enable assignments, field security, SharePoint, Delete, or Share.'
    }

    $marker = "Wizard scenario=$ScenarioSlug; stage=68-build-security-roles.ps1"
    $plans = @($payload.Roles | ForEach-Object {
        $role = $_
        $privileges = @(Get-WizardRolePrivilegePlan -Role $role -Depth $payload.BusinessUnitScope)
        [pscustomobject]@{
            Name = "$($role.Name)"
            Description = "$($role.Description)"
            Privileges = $privileges
        }
    })
    $duplicateRoles = @($plans | Group-Object Name | Where-Object Count -gt 1)
    if ($duplicateRoles.Count -gt 0) { throw "Duplicate security role '$($duplicateRoles[0].Name)'." }

    $evidence = [System.Collections.Generic.List[object]]::new()
    if ($Mode -eq 'Preview') {
        foreach ($plan in $plans) {
            [void]$evidence.Add([pscustomobject]@{
                name = $plan.Name
                action = 'planned'
                privilegeDepth = "$($payload.BusinessUnitScope)"
                privilegeCount = @($plan.Privileges).Count
                privileges = @($plan.Privileges)
            })
        }
    } else {
        foreach ($required in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName)) {
            if ([string]::IsNullOrWhiteSpace($required)) {
                throw 'Security-role apply requires explicit environment, token, and solution.'
            }
        }
        $invoke = {
            param($method, $path, $body = $null)
            Invoke-WizardDataverseRequest -Method $method -Path $path `
                -EnvironmentUrl $EnvironmentUrl -AccessToken $AccessToken `
                -Body $body -RequestInvoker $RequestInvoker
        }
        $safeSolution = ConvertTo-WizardODataLiteral $SolutionUniqueName
        $solutions = @((& $invoke Get "solutions?`$select=solutionid&`$filter=uniquename eq '$safeSolution'").value)
        if ($solutions.Count -ne 1) {
            throw "Expected exactly one selected solution '$SolutionUniqueName'; found $($solutions.Count)."
        }
        $solutionId = "$($solutions[0].solutionid)"
        $businessUnits = @((& $invoke Get 'businessunits?$select=businessunitid,name,_parentbusinessunitid_value&$filter=_parentbusinessunitid_value eq null').value)
        if ($businessUnits.Count -ne 1) {
            throw "Expected exactly one root business unit; found $($businessUnits.Count)."
        }
        $businessUnitId = "$($businessUnits[0].businessunitid)"

        foreach ($plan in $plans) {
            $safeRoleName = ConvertTo-WizardODataLiteral $plan.Name
            $rolePath = "roles?`$select=roleid,name,description,_businessunitid_value&`$filter=name eq '$safeRoleName' and _businessunitid_value eq $businessUnitId"
            $matches = @((& $invoke Get $rolePath).value)
            if ($matches.Count -gt 1) { throw "Security role '$($plan.Name)' resolved more than once in the root business unit." }

            $created = $false
            if ($matches.Count -eq 0) {
                & $invoke Post 'roles' @{
                    name = $plan.Name
                    description = "$($plan.Description) $marker"
                    'businessunitid@odata.bind' = "/businessunits($businessUnitId)"
                } | Out-Null
                $matches = @((& $invoke Get $rolePath).value)
                if ($matches.Count -ne 1) { throw "Security role '$($plan.Name)' did not resolve exactly once after create." }
                $created = $true
            } elseif ("$($matches[0].description)" -notlike "*$marker*") {
                throw "Security role '$($plan.Name)' exists but is not owned by scenario '$ScenarioSlug'."
            }

            $roleId = "$($matches[0].roleid)"
            if ([string]::IsNullOrWhiteSpace($roleId)) { throw "Security role '$($plan.Name)' has no stable ID." }

            $resolvedPrivileges = [System.Collections.Generic.List[object]]::new()
            foreach ($privilegePlan in @($plan.Privileges)) {
                $safePrivilegeName = ConvertTo-WizardODataLiteral $privilegePlan.PrivilegeName
                $privilegeMatches = @((& $invoke Get "privileges?`$select=privilegeid,name,canbelocal&`$filter=name eq '$safePrivilegeName'").value)
                if ($privilegeMatches.Count -ne 1) {
                    throw "Privilege '$($privilegePlan.PrivilegeName)' for role '$($plan.Name)' must resolve exactly once; found $($privilegeMatches.Count)."
                }
                if ($payload.BusinessUnitScope -eq 'Local' -and -not [bool]$privilegeMatches[0].canbelocal) {
                    throw "Privilege '$($privilegePlan.PrivilegeName)' does not support Business Unit depth."
                }
                [void]$resolvedPrivileges.Add([pscustomobject]@{
                    PrivilegeId = "$($privilegeMatches[0].privilegeid)"
                    Depth = [int]$privilegePlan.DepthValue
                })
            }

            $currentResponse = & $invoke Get "RetrieveRolePrivilegesRole(RoleId=$roleId)"
            $currentPrivileges = if ($null -ne $currentResponse.PSObject.Properties['RolePrivileges']) {
                @($currentResponse.RolePrivileges)
            } else {
                @()
            }
            $desiredKeys = @($resolvedPrivileges | ForEach-Object { ConvertTo-WizardRolePrivilegeKey -Privilege $_ } | Sort-Object)
            $currentKeys = @($currentPrivileges | ForEach-Object { ConvertTo-WizardRolePrivilegeKey -Privilege $_ } | Sort-Object)
            $privilegesChanged = ($desiredKeys -join ',') -cne ($currentKeys -join ',')
            if ($privilegesChanged) {
                & $invoke Post "roles($roleId)/Microsoft.Dynamics.CRM.ReplacePrivilegesRole" @{
                    Privileges = @($resolvedPrivileges)
                } | Out-Null
                $verifiedResponse = & $invoke Get "RetrieveRolePrivilegesRole(RoleId=$roleId)"
                $verifiedKeys = @($verifiedResponse.RolePrivileges | ForEach-Object {
                    ConvertTo-WizardRolePrivilegeKey -Privilege $_
                } | Sort-Object)
                if (($desiredKeys -join ',') -cne ($verifiedKeys -join ',')) {
                    throw "Security role '$($plan.Name)' did not retain the exact planned privilege set."
                }
            }

            $membershipPath = "solutioncomponents?`$select=solutioncomponentid&`$filter=_solutionid_value eq $solutionId and objectid eq $roleId and componenttype eq 20"
            $membership = @((& $invoke Get $membershipPath).value)
            if ($membership.Count -eq 0) {
                & $invoke Post 'AddSolutionComponent' @{
                    ComponentId = $roleId
                    ComponentType = 20
                    SolutionUniqueName = $SolutionUniqueName
                    AddRequiredComponents = $false
                } | Out-Null
                $membership = @((& $invoke Get $membershipPath).value)
            }
            if ($membership.Count -ne 1) {
                throw "Security role '$($plan.Name)' does not have exact solution membership."
            }

            $action = if ($created) { 'created' } elseif ($privilegesChanged) { 'updated' } else { 'skipped' }
            [void]$evidence.Add([pscustomobject]@{
                name = $plan.Name
                id = $roleId
                action = $action
                privilegeDepth = "$($payload.BusinessUnitScope)"
                privilegeCount = $desiredKeys.Count
                solutionMembership = 'explicit'
            })
        }
    }

    $evidencePath = Join-Path $RepoRoot ".wizard-metrics/artifacts/security-roles/$ScenarioSlug.json"
    New-Item -ItemType Directory -Path (Split-Path $evidencePath -Parent) -Force | Out-Null
    [ordered]@{
        scenarioSlug = $ScenarioSlug
        mode = $Mode
        assignmentsEnabled = $false
        fieldSecurityProfilesEnabled = $false
        sharePointProvisioningEnabled = $false
        requiresBasicUserRole = [bool]$payload.RequiresBasicUserRole
        roles = @($evidence)
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    return @($evidence)
}

if ($env:WIZARD_SECURITY_ROLES_SKIP_MAIN -ne 'true') {
    if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
        $PayloadsFolder = Join-Path $repoRoot "payloads/scenarios/$ScenarioSlug"
    }
    if ($Mode -eq 'Apply' -and (Test-Path -LiteralPath (Join-Path $repoRoot '.env.ps1')) -and
        [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
        $environment = Import-WizardEnvironment -RepoRoot $repoRoot
        $EnvironmentUrl = $environment.EnvironmentUrl
        $AccessToken = $environment.AccessToken
        if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
            $SolutionUniqueName = $environment.SolutionUniqueName
        }
    }
    Invoke-WizardSecurityRoleStage -RepoRoot $repoRoot -ScenarioSlug $ScenarioSlug `
        -PayloadsFolder $PayloadsFolder -Mode $Mode -EnvironmentUrl $EnvironmentUrl `
        -AccessToken $AccessToken -SolutionUniqueName $SolutionUniqueName `
        -RequestInvoker $RequestInvoker | Out-Null
}
