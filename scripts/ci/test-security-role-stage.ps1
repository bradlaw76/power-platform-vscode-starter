<#
=============================================================================
COMPONENT:    Security Role Stage Tests
FILE:         scripts/ci/test-security-role-stage.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-15
ENVIRONMENT:  PowerShell 7 | Credential-free CI
=============================================================================
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$scenario = 'federal-foia-management'
$payloadFolder = Join-Path $repoRoot "payloads/scenarios/$scenario"
$payloadPath = Join-Path $payloadFolder "security-roles-$scenario.json"
$schemaPath = Join-Path $repoRoot 'schemas/payloads/security-roles.schema.json'
$scriptPath = Join-Path $repoRoot 'scripts/bootstrap/68-build-security-roles.ps1'

$json = Get-Content -LiteralPath $payloadPath -Raw -Encoding UTF8
if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw 'Federal FOIA security-role payload failed schema validation.'
}
$payload = $json | ConvertFrom-Json -Depth 20
$expectedRoleNames = @('FOIA Demo Approver', 'FOIA Demo Processor', 'FOIA Demo Release Officer')
if ((@($payload.Roles.Name | Sort-Object) -join '|') -cne ($expectedRoleNames -join '|')) {
    throw 'Security-role payload must contain exactly the three approved demo roles.'
}
if ($payload.BusinessUnitScope -cne 'Local' -or $payload.DeleteAllowed -or $payload.ShareAllowed) {
    throw 'Security-role payload must use Business Unit scope without Delete or Share.'
}
foreach ($role in @($payload.Roles)) {
    if (@($role.TablePrivileges).Count -ne 13) {
        throw "Role '$($role.Name)' must explicitly classify all 13 demo tables."
    }
    $forbidden = @($role.TablePrivileges.Actions | Where-Object { $_ -in @('Delete', 'Share') })
    if ($forbidden.Count -gt 0) { throw "Role '$($role.Name)' contains a prohibited privilege." }
}

$env:WIZARD_SECURITY_ROLES_SKIP_MAIN = 'true'
. $scriptPath -ScenarioSlug $scenario

$previewCalls = [System.Collections.Generic.List[object]]::new()
$previewInvoker = {
    param($request)
    [void]$previewCalls.Add($request)
    throw 'Preview must not invoke Dataverse.'
}.GetNewClosure()
$preview = @(Invoke-WizardSecurityRoleStage -RepoRoot $repoRoot -ScenarioSlug $scenario `
    -PayloadsFolder $payloadFolder -Mode Preview -RequestInvoker $previewInvoker)
if ($preview.Count -ne 3 -or @($preview | Where-Object action -ne 'planned').Count -gt 0) {
    throw 'Preview must plan exactly three roles.'
}
if ($previewCalls.Count -ne 0) { throw 'Preview invoked Dataverse transport.' }

function New-TestStableGuid {
    param([string]$Value)
    $bytes = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))
    return [Guid]::new([byte[]]$bytes[0..15]).ToString()
}

$solutionId = New-TestStableGuid 'solution'
$businessUnitId = New-TestStableGuid 'root-business-unit'
$rolesByName = @{}
$privilegesByRole = @{}
$memberships = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$calls = [System.Collections.Generic.List[object]]::new()
$requestInvoker = {
    param($request)
    $path = [Uri]::UnescapeDataString(($request.Uri -split '/api/data/v9.2/')[1])
    $body = if ($null -eq $request.Body) { $null } else { $request.Body | ConvertFrom-Json -Depth 30 }
    [void]$calls.Add([pscustomobject]@{ Method = "$($request.Method)"; Path = $path; Body = $body })

    if ($path -like 'solutions?*') {
        return [pscustomobject]@{ value = @([pscustomobject]@{ solutionid = $solutionId }) }
    }
    if ($path -like 'businessunits?*') {
        return [pscustomobject]@{ value = @([pscustomobject]@{
            businessunitid = $businessUnitId
            name = 'Root Business Unit'
            _parentbusinessunitid_value = $null
        }) }
    }
    if ($request.Method -eq 'Get' -and $path -like 'roles?*') {
        if ($path -notmatch "name eq '(?<name>(?:''|[^'])*)'") { throw "Role query did not contain a name: $path" }
        $name = $Matches.name.Replace("''", "'")
        $role = $rolesByName[$name]
        return [pscustomobject]@{ value = if ($null -eq $role) { @() } else { @($role) } }
    }
    if ($request.Method -eq 'Post' -and $path -eq 'roles') {
        $roleId = New-TestStableGuid "role|$($body.name)"
        $rolesByName["$($body.name)"] = [pscustomobject]@{
            roleid = $roleId
            name = "$($body.name)"
            description = "$($body.description)"
            _businessunitid_value = $businessUnitId
        }
        $privilegesByRole[$roleId] = @()
        return [pscustomobject]@{}
    }
    if ($request.Method -eq 'Get' -and $path -like 'privileges?*') {
        if ($path -notmatch "name eq '(?<name>(?:''|[^'])*)'") { throw "Privilege query did not contain a name: $path" }
        $name = $Matches.name.Replace("''", "'")
        return [pscustomobject]@{ value = @([pscustomobject]@{
            privilegeid = New-TestStableGuid "privilege|$name"
            name = $name
            canbelocal = $true
        }) }
    }
    if ($request.Method -eq 'Get' -and $path -match '^RetrieveRolePrivilegesRole\(RoleId=(?<id>[^)]+)\)$') {
        return [pscustomobject]@{ RolePrivileges = @($privilegesByRole[$Matches.id]) }
    }
    if ($request.Method -eq 'Post' -and $path -match '^roles\((?<id>[^)]+)\)/Microsoft\.Dynamics\.CRM\.ReplacePrivilegesRole$') {
        $privilegesByRole[$Matches.id] = @($body.Privileges)
        return [pscustomobject]@{}
    }
    if ($request.Method -eq 'Get' -and $path -like 'solutioncomponents?*') {
        if ($path -notmatch 'objectid eq (?<id>[0-9a-f-]+)') { throw "Membership query did not contain an object ID: $path" }
        $id = $Matches.id
        return [pscustomobject]@{ value = if ($memberships.Contains($id)) {
            @([pscustomobject]@{ solutioncomponentid = New-TestStableGuid "component|$id" })
        } else {
            @()
        } }
    }
    if ($request.Method -eq 'Post' -and $path -eq 'AddSolutionComponent') {
        [void]$memberships.Add("$($body.ComponentId)")
        return [pscustomobject]@{}
    }
    throw "Unexpected Dataverse request: $($request.Method) $path"
}.GetNewClosure()

$firstPass = @(Invoke-WizardSecurityRoleStage -RepoRoot $repoRoot -ScenarioSlug $scenario `
    -PayloadsFolder $payloadFolder -Mode Apply -EnvironmentUrl 'https://unit.test' `
    -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -RequestInvoker $requestInvoker)
if ($firstPass.Count -ne 3 -or @($firstPass | Where-Object action -ne 'created').Count -gt 0) {
    throw 'First apply must create exactly three roles.'
}
if (@($calls | Where-Object { $_.Method -eq 'Post' -and $_.Path -like '*ReplacePrivilegesRole' }).Count -ne 3) {
    throw 'First apply must replace each role with its exact privilege set.'
}

$firstPassCallCount = $calls.Count
$secondPass = @(Invoke-WizardSecurityRoleStage -RepoRoot $repoRoot -ScenarioSlug $scenario `
    -PayloadsFolder $payloadFolder -Mode Apply -EnvironmentUrl 'https://unit.test' `
    -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -RequestInvoker $requestInvoker)
$secondPassCalls = @($calls | Select-Object -Skip $firstPassCallCount)
if ($secondPass.Count -ne 3 -or @($secondPass | Where-Object action -ne 'skipped').Count -gt 0) {
    throw 'Second apply must skip all three stable roles.'
}
if (@($secondPassCalls | Where-Object Method -eq 'Post').Count -ne 0) {
    throw 'Second apply must not issue any mutating request.'
}

$foreignRoles = @{}
foreach ($role in @($rolesByName.Values)) {
    $foreignRoles[$role.name] = $role
}
$foreignRoles['FOIA Demo Processor'].description = 'Foreign role'
try {
    Invoke-WizardSecurityRoleStage -RepoRoot $repoRoot -ScenarioSlug $scenario `
        -PayloadsFolder $payloadFolder -Mode Apply -EnvironmentUrl 'https://unit.test' `
        -AccessToken 'token' -SolutionUniqueName 'UnitSolution' -RequestInvoker $requestInvoker | Out-Null
    throw 'Expected ownership collision failure.'
} catch {
    if ($_.Exception.Message -notmatch 'not owned by scenario') { throw }
}

Remove-Item Env:WIZARD_SECURITY_ROLES_SKIP_MAIN -ErrorAction SilentlyContinue
Write-Host 'Security role stage tests passed.' -ForegroundColor Green
