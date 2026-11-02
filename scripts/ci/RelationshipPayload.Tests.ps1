<#
=============================================================================
COMPONENT:    Relationship Payload Tests
FILE:         scripts/ci/RelationshipPayload.Tests.ps1
VERSION:      0.1.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-06
ENVIRONMENT:  PowerShell 7 | Pester | Credential-Free CI

Validates reusable 1:N/N:N relationship schemas, preview non-mutation,
supported metadata requests, and exact-identity idempotency.
=============================================================================
#>

Describe 'Dataverse relationship payload support' {
    BeforeAll {
        $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $script:relationshipScript = Join-Path $repoRoot 'scripts/bootstrap/40-build-relationships.ps1'
        $script:scenarioPayload = Join-Path $repoRoot 'payloads/scenarios/federal-foia-management/relationships-federal-foia-management.json'
        $script:schemaPath = Join-Path $repoRoot 'schemas/payloads/relationships.schema.json'
        $script:originalTargetRoot = $env:WIZARD_TARGET_PROJECT_ROOT
        $script:targetRoot = Join-Path ([IO.Path]::GetTempPath()) "relationship-ci-$([guid]::NewGuid().ToString('N'))"
        $script:scratchRoot = Join-Path $targetRoot 'scratch'
        New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
        & git -C $targetRoot init -b test-relationship-target | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the relationship test target repository.' }
        & git -C $targetRoot remote add origin 'https://github.com/example/relationship-target.git'
        if ($LASTEXITCODE -ne 0) { throw 'Could not configure the relationship test target identity.' }
        $env:WIZARD_TARGET_PROJECT_ROOT = $targetRoot
        if (Test-Path -LiteralPath $scratchRoot) { Remove-Item -LiteralPath $scratchRoot -Recurse -Force }
        New-Item -ItemType Directory -Path $scratchRoot | Out-Null
    }

    AfterAll {
        $env:WIZARD_TARGET_PROJECT_ROOT = $originalTargetRoot
        if (Test-Path -LiteralPath $targetRoot) { Remove-Item -LiteralPath $targetRoot -Recurse -Force }
    }

    It 'validates existing 1:N and the Federal FOIA N:N payload with the shared schema' {
        $existingOneToMany = Join-Path $repoRoot 'payloads/scenarios/contoso-case-tracker/relationships-incident-agent.json'
        (Get-Content -LiteralPath $existingOneToMany -Raw | Test-Json -SchemaFile $schemaPath) | Should -BeTrue
        (Get-Content -LiteralPath $scenarioPayload -Raw | Test-Json -SchemaFile $schemaPath) | Should -BeTrue
    }

    It 'declares the exact Release Package to Responsive Record N:N identity without cascade semantics' {
        $payload = Get-Content -LiteralPath $scenarioPayload -Raw | ConvertFrom-Json
        $relationship = @($payload.Relationships | Where-Object SchemaName -eq 'foia_releasepackage_responsiverecord')
        $relationship.Count | Should -Be 1
        $definition = $relationship[0].RelationshipDefinition
        $definition.'@odata.type' | Should -Be 'Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata'
        $definition.Entity1LogicalName | Should -Be 'foia_releasepackage'
        $definition.Entity2LogicalName | Should -Be 'foia_responsiverecord'
        $definition.IntersectEntityName | Should -Be 'foia_releasepackage_responsiverecord'
        $definition.PSObject.Properties.Name | Should -Not -Contain 'CascadeConfiguration'
    }

    It 'previews N:N creation without credentials or transport calls' {
        Copy-Item -LiteralPath $scenarioPayload -Destination (Join-Path $scratchRoot 'relationships-preview.json')
        $global:relationshipTransportCalls = 0
        & $relationshipScript -PayloadsFolder $scratchRoot -PreviewOnly -RequestInvoker {
            param($request)
            $global:relationshipTransportCalls++
            throw 'Preview must not invoke transport.'
        }
        $global:relationshipTransportCalls | Should -Be 0
    }

    It 'posts supported ManyToManyRelationshipMetadata in apply mode' {
        $payloadFolder = Join-Path $scratchRoot 'apply'
        New-Item -ItemType Directory -Path $payloadFolder | Out-Null
        @'
{"Relationships":[{"SchemaName":"foia_releasepackage_responsiverecord","RelationshipDefinition":{"@odata.type":"Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata","SchemaName":"foia_releasepackage_responsiverecord","Entity1LogicalName":"foia_releasepackage","Entity2LogicalName":"foia_responsiverecord","IntersectEntityName":"foia_releasepackage_responsiverecord"}}]}
'@ | Set-Content -LiteralPath (Join-Path $payloadFolder 'relationships-nn.json') -Encoding UTF8
        $global:relationshipRequests = @()
        & $relationshipScript -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'test-token' -RequestInvoker {
            param($request)
            $global:relationshipRequests += $request
            if ($request.Method -eq 'Get') { return @{ value = @() } }
            return @{}
        }
        $global:relationshipRequests.Count | Should -Be 2
        $global:relationshipRequests[1].Uri | Should -Match '/RelationshipDefinitions$'
        $body = $global:relationshipRequests[1].Body | ConvertFrom-Json
        $body.'@odata.type' | Should -Be 'Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata'
        $body.PSObject.Properties.Name | Should -Not -Contain 'CascadeConfiguration'
    }

    It 'skips an exact existing identity and rejects a conflicting identity' {
        $payloadFolder = Join-Path $scratchRoot 'identity'
        New-Item -ItemType Directory -Path $payloadFolder | Out-Null
        @'
{"Relationships":[{"SchemaName":"test_a_b","RelationshipDefinition":{"@odata.type":"Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata","SchemaName":"test_a_b","Entity1LogicalName":"test_a","Entity2LogicalName":"test_b","IntersectEntityName":"test_a_b"}}]}
'@ | Set-Content -LiteralPath (Join-Path $payloadFolder 'relationships-identity.json') -Encoding UTF8
        $global:relationshipPostCalls = 0
        & $relationshipScript -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'test-token' -RequestInvoker {
            param($request)
            if ($request.Method -eq 'Post') { $global:relationshipPostCalls++ }
            return @{ value = @(@{ '@odata.type' = '#Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata'; SchemaName = 'test_a_b'; Entity1LogicalName = 'test_a'; Entity2LogicalName = 'test_b'; IntersectEntityName = 'test_a_b' }) }
        }
        $global:relationshipPostCalls | Should -Be 0

        {
            & $relationshipScript -PayloadsFolder $payloadFolder -EnvironmentUrl 'https://example.crm.dynamics.com' -AccessToken 'test-token' -RequestInvoker {
                param($request)
                return @{ value = @(@{ '@odata.type' = '#Microsoft.Dynamics.CRM.ManyToManyRelationshipMetadata'; SchemaName = 'test_a_b'; Entity1LogicalName = 'test_a'; Entity2LogicalName = 'wrong_table'; IntersectEntityName = 'test_a_b' }) }
            }
        } | Should -Throw '*conflicting Entity2LogicalName*'
    }
}
