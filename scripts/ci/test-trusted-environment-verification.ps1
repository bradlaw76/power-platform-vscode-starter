<#
=============================================================================
COMPONENT:    FAST-008A Authenticated Verification Acceptance
FILE:         scripts/ci/test-trusted-environment-verification.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | Synthetic responses and ephemeral test certificates
-----------------------------------------------------------------------------
OVERVIEW
Tests read-only collection, provenance and cross-domain readiness without login.
NON-NEGOTIABLES
No live transport, persistent private keys, deployment approval or authorization.
=============================================================================
#>
[CmdletBinding()]
param([string]$SampleOutputFolder = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'test-execution-readiness.ps1') -SampleOutputFolder $SampleOutputFolder -DefineFixturesOnly
. (Join-Path $repoRoot 'scripts\accelerators\trusted-environment-verification.ps1')
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "fast008a-$([guid]::NewGuid().ToString('N'))"
$verificationAssertions = 0
$verificationFailures = [Collections.Generic.List[string]]::new()
$testCertificate = $null; $publicCertificate = $null; $otherCertificate = $null; $cliCertificate = $null
$rsa = [Security.Cryptography.RSA]::Create(2048)
$otherRsa = [Security.Cryptography.RSA]::Create(2048)

function Assert-Verification {
    param([bool]$Condition, [string]$Message)
    $script:verificationAssertions++
    if (-not $Condition) { $verificationFailures.Add($Message) | Out-Null }
}

function New-VerificationHttpError {
    param([int]$Status)
    $exception = [Exception]::new("Synthetic HTTP $Status")
    $exception | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{ StatusCode = $Status; Headers = @{} })
    return [Management.Automation.ErrorRecord]::new($exception, "Http$Status", 'InvalidOperation', $null)
}

function New-VerificationFixture {
    param([string]$Slug, [switch]$Hybrid, [switch]$Extend, [switch]$Column)
    $fixture = New-ReadinessFixture -Slug $Slug -Hybrid:$Hybrid
    $task = New-BuildPlanningTask -Action $(if ($Extend) { 'EXTEND' } elseif ($Hybrid) { 'REUSE' } else { 'CREATE' }) `
        -ComponentKind $(if ($Column) { 'column' } else { 'table' }) -ComponentIdentity $(if ($Column) { 'tst_record.tst_detail' } else { 'tst_record' }) -DisplayName "$Slug record" `
        -Ownership $(if ($Hybrid) { 'accelerator-managed' } else { 'solution-owned' }) -Managed ([bool]$Hybrid) `
        -RequirementIds @('REQ-001') -ExpectedOutputs @('A concrete application table.') `
        -AcceptanceChecks @('Users can complete the primary task.') -Reason 'Synthetic concrete metadata identity.'
    $fixture.plan.componentPlans = @($task)
    $fixture.plan.dependencyGraph = [pscustomobject]@{ nodes = @($task.taskId); edges = @(); orderedTaskIds = @($task.taskId) }
    $fixture.plan.traceability[0].taskIds = @($task.taskId)
    $fixture.plan.planId = Get-ExecutionPlanIdentity $fixture.plan
    Write-FixtureJson $fixture.planPath $fixture.plan
    $script:verificationFixture = $fixture
    $script:verificationState = [ordered]@{
        missingPackage = $false; wrongVersion = $false; missingPrivilege = $false
        denyPermissions = $false; restricted = $false; missingManagedProperty = $false
        authenticationFailure = $false; mismatch = $false; malformedCollection = $false
        crossOriginPagination = $false; credentialsUnavailable = $false; throttle = $false; throttled = $false
        privilegeDepth = 'Global'; badMembership = $false; principalChanged = $false; whoAmICount = 0; missingParentProperty = $false; tenantMismatch = $false; includeDependency = $false; missingPublisherMetadata = $false
    }
    $script:verificationRequests = [Collections.Generic.List[object]]::new()
    return $fixture
}

$mockTransport = {
    param($request)
    if ($request.Method -cne 'Get' -or $null -ne $request.Body) { throw 'Mutation attempted in verification.' }
    $uri = [Uri]$request.Uri
    if ($uri.Host -cne 'synthetic.example.test') { throw 'A synthetic request escaped its explicit origin.' }
    $path = [Uri]::UnescapeDataString($uri.PathAndQuery.Substring('/api/data/v9.2/'.Length))
    $script:verificationRequests.Add([pscustomobject]@{ method = $request.Method; path = $path }) | Out-Null
    if ($script:verificationState.authenticationFailure) { throw (New-VerificationHttpError 401) }
    if ($script:verificationState.throttle -and -not $script:verificationState.throttled) {
        $script:verificationState.throttled = $true; throw (New-VerificationHttpError 429)
    }
    if ($path -eq 'WhoAmI') {
        $script:verificationState.whoAmICount++
        if ($script:verificationState.principalChanged -and $script:verificationState.whoAmICount -gt 1) {
            return [pscustomobject]@{ OrganizationId = '99999999-9999-4999-8999-999999999999'; UserId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' }
        }
        return [pscustomobject]@{ OrganizationId = '99999999-9999-4999-8999-999999999999'; UserId = '33333333-3333-4333-8333-333333333333' }
    }
    if ($path -eq 'RetrieveVersion()') { return [pscustomobject]@{ Version = '9.2.26000.100' } }
    if ($path.StartsWith('RetrieveCurrentOrganization(')) {
        return [pscustomobject]@{ Detail = [pscustomobject]@{
            OrganizationId = '99999999-9999-4999-8999-999999999999'
            EnvironmentId = if ($script:verificationState.mismatch) { 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' } else { $environmentId.ToString() }
            TenantId = if ($script:verificationState.tenantMismatch) { 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' } else { $tenantId.ToString() }
        } }
    }
    if ($path.StartsWith('solutions?')) {
        if ($path.Contains("uniquename eq 'extension_solution'")) {
            if ($script:verificationState.missingPublisherMetadata) {
                return [pscustomobject]@{ value = @([pscustomobject]@{
                    solutionid = '44444444-4444-4444-8444-444444444444'; uniquename = 'extension_solution'; version = '1.0.0.0'; ismanaged = $false
                }) }
            }
            return [pscustomobject]@{ value = @([pscustomobject]@{
                solutionid = '44444444-4444-4444-8444-444444444444'; uniquename = 'extension_solution'; version = '1.0.0.0'
                ismanaged = $false; _publisherid_value = '77777777-7777-4777-8777-777777777777'
                publisherid = [pscustomobject]@{ publisherid = '77777777-7777-4777-8777-777777777777'; uniquename = 'test'; customizationprefix = 'tst' }
            }) }
        }
        if ($script:verificationState.missingPackage) { return [pscustomobject]@{ value = @() } }
        $solutions = @([pscustomobject]@{
            solutionid = '55555555-5555-4555-8555-555555555555'; uniquename = 'synthetic_records'; friendlyname = 'Synthetic'
            version = if ($script:verificationState.wrongVersion) { '2.0.0.0' } else { '1.0.0.0' }
            ismanaged = $true; _publisherid_value = '66666666-6666-4666-8666-666666666666'
            publisherid = [pscustomobject]@{ publisherid = '66666666-6666-4666-8666-666666666666'; uniquename = 'synthetic'; customizationprefix = 'tst' }
        })
        if ($script:verificationState.includeDependency) {
            $solutions += [pscustomobject]@{
                solutionid = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'; uniquename = 'dependency_solution'; friendlyname = 'Synthetic dependency'
                version = '1.0.0.0'; ismanaged = $true; _publisherid_value = '66666666-6666-4666-8666-666666666666'
                publisherid = [pscustomobject]@{ publisherid = '66666666-6666-4666-8666-666666666666'; uniquename = 'synthetic'; customizationprefix = 'tst' }
            }
        }
        return [pscustomobject]@{ value = $solutions }
    }
    if ($path.StartsWith('EntityDefinitions?')) {
        if ($script:verificationFixture.plan.componentPlans[0].componentKind -eq 'column') {
            $parent = [pscustomobject]@{ LogicalName = 'tst_record'; IsCustomizable = [pscustomobject]@{ Value = -not $script:verificationState.restricted }; CanCreateAttributes = [pscustomobject]@{ Value = -not $script:verificationState.restricted } }
            if ($script:verificationState.missingParentProperty) { $parent.PSObject.Properties.Remove('CanCreateAttributes') }
            return [pscustomobject]@{ value = @($parent) }
        }
        if ($script:verificationState.malformedCollection) { return [pscustomobject]@{ incomplete = $true } }
        if ($script:verificationState.crossOriginPagination) {
            return [pscustomobject]@{ value = @(); '@odata.nextLink' = 'https://wrong.example.test/api/data/v9.2/EntityDefinitions?$skiptoken=next' }
        }
        if ($script:verificationFixture.plan.architecture -eq 'fully-custom') { return [pscustomobject]@{ value = @() } }
        $record = [pscustomobject]@{
            MetadataId = '88888888-8888-4888-8888-888888888888'; LogicalName = 'tst_record'; SchemaName = 'tst_Record'
            IsManaged = $true; IsCustomizable = [pscustomobject]@{ Value = -not $script:verificationState.restricted }
            CanCreateAttributes = [pscustomobject]@{ Value = -not $script:verificationState.restricted }
        }
        if ($script:verificationState.missingManagedProperty) { $record.PSObject.Properties.Remove('IsManaged') }
        return [pscustomobject]@{ value = @($record) }
    }
    if ($path.StartsWith("EntityDefinitions(LogicalName='tst_record')/Attributes?")) { return [pscustomobject]@{ value = @() } }
    if ($path.StartsWith('webresourceset?')) {
        return [pscustomobject]@{ value = @([pscustomobject]@{ webresourceid = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'; name = 'tst_dependency' }) }
    }
    if ($path.StartsWith('solutioncomponents?')) {
        return [pscustomobject]@{ value = @([pscustomobject]@{
            objectid = if ($script:verificationState.badMembership) { 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' } else { '88888888-8888-4888-8888-888888888888' }
            componenttype = 1; _solutionid_value = '55555555-5555-4555-8555-555555555555'
        }) }
    }
    if ($path.StartsWith('systemusers?')) {
        return [pscustomobject]@{ value = @([pscustomobject]@{
            systemuserid = '33333333-3333-4333-8333-333333333333'; azureactivedirectoryobjectid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
        }) }
    }
    if ($path.Contains('RetrieveUserPrivilegeByPrivilegeName')) {
        if ($script:verificationState.denyPermissions) { throw (New-VerificationHttpError 403) }
        if ($path -notmatch "PrivilegeName='(?<name>[A-Za-z]+)'") { throw 'Unexpected privilege query.' }
        if ($script:verificationState.missingPrivilege -and $Matches.name -eq 'prvWriteEntity') {
            return [pscustomobject]@{ RolePrivileges = @() }
        }
        return [pscustomobject]@{ RolePrivileges = @([pscustomobject]@{
            PrivilegeName = $Matches.name; PrivilegeId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; Depth = $script:verificationState.privilegeDepth
        }) }
    }
    throw "Unexpected synthetic GET path: $path"
}

function Collect-VerificationFixture {
    param([object]$Fixture)
    $manifestPath = if ($Fixture.plan.architecture -ne 'fully-custom') {
        Join-Path (Split-Path $Fixture.evidencePath -Parent) 'package-input-manifest.json'
    } else { '' }
    return Invoke-TrustedEnvironmentVerification -EnableAuthenticatedVerification -ConfirmReadOnlyScope `
        -WorkspaceRoot $Fixture.root -ScenarioSlug $Fixture.slug -EnvironmentUrl 'https://synthetic.example.test' `
        -EnvironmentId $environmentId -TenantId $tenantId -SolutionUniqueName 'extension_solution' `
        -SigningCertificate $testCertificate -CollectionMode Mock -AccessToken $(if ($script:verificationState.credentialsUnavailable) { '' } else { 'synthetic-memory-only-token' }) `
        -TokenProvider { throw 'Synthetic credentials expired or unavailable.' } -RequestInvoker $mockTransport -SleepAction {} `
        -PackageManifestPath $manifestPath -NowUtc $clock
}

function Evaluate-VerificationFixture {
    param([object]$Fixture, [object]$Envelope, [string]$Policy = 'RecordedTest',
        [Security.Cryptography.X509Certificates.X509Certificate2]$Certificate = $publicCertificate,
        [DateTimeOffset]$Time = $clock)
    $file = Join-Path (Split-Path $Fixture.evidencePath -Parent) 'trusted-environment-verification.json'
    Write-FixtureJson $file $Envelope
    return Get-ExecutionReadiness -WorkspaceRoot $Fixture.root -ScenarioSlug $Fixture.slug -EvidencePath $file `
        -EnvironmentUrl 'https://synthetic.example.test' -EnvironmentId $environmentId -TenantId $tenantId `
        -EvidenceTrustPolicy $Policy -TrustedCertificate $Certificate -EvaluationTimeUtc $Time
}

function Save-VerificationSample {
    param([string]$Name, [object]$Envelope, [object]$Report)
    if (-not [string]::IsNullOrWhiteSpace($SampleOutputFolder)) {
        Write-FixtureJson (Join-Path $SampleOutputFolder "$Name\trusted-environment-verification.json") $Envelope
        Write-FixtureJson (Join-Path $SampleOutputFolder "$Name\execution-readiness.json") $Report
    }
}

try {
    $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=FAST-008A Ephemeral Mock Evidence',
        $rsa, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $testCertificate = $request.CreateSelfSigned($clock.AddDays(-1), $clock.AddDays(1))
    $publicCertificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($testCertificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert))
    $otherRequest = [Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=Untrusted Test Signer',
        $otherRsa, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $otherCertificate = $otherRequest.CreateSelfSigned($clock.AddDays(-1), $clock.AddDays(1))
    foreach ($slug in @('equipment-maintenance', 'event-registration', 'employee-onboarding', 'library-circulation')) {
        $fixture = New-VerificationFixture $slug -Hybrid:($slug -eq 'library-circulation')
        $envelope = Collect-VerificationFixture $fixture
        $repeatEnvelope = Collect-VerificationFixture $fixture
        Assert-Verification ((ConvertTo-AcceleratorCanonicalJson $envelope) -ceq (ConvertTo-AcceleratorCanonicalJson $repeatEnvelope)) "$slug collection was not deterministic for identical time, key, inputs and responses."
        $report = Evaluate-VerificationFixture $fixture $envelope
        Assert-Verification ($report.status -eq 'READY_FOR_APPROVAL') "${slug}: $($report.findings | ConvertTo-Json -Compress)"
        Assert-Verification ($report.evidenceTrust -eq 'recorded-test' -and -not $report.verifiedForHumanReview -and -not $report.executionAuthorized) "$slug claimed live or execution eligibility."
        Assert-Verification ($envelope.payload.evidence.environment.environmentId -cne $envelope.payload.authenticatedIdentity.organizationId) "$slug confused organization ID with environment ID."
        Assert-Verification (@($script:verificationRequests | Where-Object method -CNE 'Get').Count -eq 0) "$slug sent a non-GET request."
        Assert-Verification (($envelope | ConvertTo-Json -Depth 100) -notmatch 'synthetic-memory-only-token|Authorization|Bearer|client_secret') "$slug persisted sensitive authentication material."
        Assert-Verification ($fixture.plan.architecture -ne 'fully-custom' -or $envelope.payload.evidence.packages.Count -eq 0) 'Fully Custom acquired FAST prerequisites.'
        $defaultReport = Evaluate-VerificationFixture $fixture $envelope -Policy Authenticated
        Assert-Verification ($defaultReport.status -eq 'BLOCKED_EVIDENCE' -and -not $defaultReport.verifiedForHumanReview) 'Mock provenance was accepted as live authenticated evidence.'
        Save-VerificationSample $slug $envelope $report
    }
    $cases = @(
        @{ name = 'missing-accelerator'; hybrid = $true; extend = $false; status = 'BLOCKED_COMPATIBILITY'; change = { $script:verificationState.missingPackage = $true } },
        @{ name = 'incorrect-version'; hybrid = $true; extend = $false; status = 'BLOCKED_DECISION_CHANGE'; change = { $script:verificationState.wrongVersion = $true } },
        @{ name = 'environment-mismatch'; hybrid = $false; extend = $false; status = 'BLOCKED_DECISION_CHANGE'; change = { $script:verificationState.mismatch = $true } },
        @{ name = 'tenant-mismatch'; hybrid = $false; extend = $false; status = 'BLOCKED_DECISION_CHANGE'; change = { $script:verificationState.tenantMismatch = $true } },
        @{ name = 'missing-permissions'; hybrid = $false; extend = $false; status = 'BLOCKED_SECURITY'; change = { $script:verificationState.missingPrivilege = $true } },
        @{ name = 'inaccessible-permissions'; hybrid = $false; extend = $false; status = 'BLOCKED_EVIDENCE'; change = { $script:verificationState.denyPermissions = $true } },
        @{ name = 'managed-restrictions'; hybrid = $true; extend = $true; status = 'BLOCKED_COMPATIBILITY'; change = { $script:verificationState.restricted = $true } },
        @{ name = 'unknown-managed-state'; hybrid = $true; extend = $false; status = 'BLOCKED_EVIDENCE'; change = { $script:verificationState.missingManagedProperty = $true } },
        @{ name = 'unknown-extension-publisher'; hybrid = $false; extend = $false; status = 'BLOCKED_EVIDENCE'; change = { $script:verificationState.missingPublisherMetadata = $true } },
        @{ name = 'expired-credentials'; hybrid = $false; extend = $false; status = 'BLOCKED_DECISION_CHANGE'; change = { $script:verificationState.authenticationFailure = $true } },
        @{ name = 'unavailable-credentials'; hybrid = $false; extend = $false; status = 'BLOCKED_DECISION_CHANGE'; change = { $script:verificationState.credentialsUnavailable = $true } },
        @{ name = 'incomplete-inspection'; hybrid = $false; extend = $false; status = 'BLOCKED_EVIDENCE'; change = { $script:verificationState.malformedCollection = $true } },
        @{ name = 'cross-origin-pagination'; hybrid = $false; extend = $false; status = 'BLOCKED_EVIDENCE'; change = { $script:verificationState.crossOriginPagination = $true } },
        @{ name = 'basic-permission-depth'; hybrid = $false; extend = $false; status = 'BLOCKED_SECURITY'; change = { $script:verificationState.privilegeDepth = 'Basic' } },
        @{ name = 'filtered-permission-depth'; hybrid = $false; extend = $false; status = 'BLOCKED_SECURITY'; change = { $script:verificationState.privilegeDepth = 'RecordFilter' } },
        @{ name = 'substituted-membership'; hybrid = $true; extend = $false; status = 'BLOCKED_COMPATIBILITY'; change = { $script:verificationState.badMembership = $true } },
        @{ name = 'principal-changed'; hybrid = $false; extend = $false; status = 'BLOCKED_SECURITY'; change = { $script:verificationState.principalChanged = $true } }
    )
    foreach ($case in $cases) {
        $fixture = New-VerificationFixture $case.name -Hybrid:$case.hybrid -Extend:$case.extend
        & $case.change
        $envelope = Collect-VerificationFixture $fixture
        $report = Evaluate-VerificationFixture $fixture $envelope
        Assert-Verification ($report.status -eq $case.status) "$($case.name) expected $($case.status), got $($report.status): $($report.findings | ConvertTo-Json -Compress)"
        Assert-Verification (-not $report.executionAuthorized -and -not $report.eligibleForHumanApproval -and -not $report.verifiedForHumanReview) "$($case.name) claimed readiness."
        if ($case.name -in @('missing-accelerator', 'missing-permissions', 'managed-restrictions')) { Save-VerificationSample $case.name $envelope $report }
    }
    foreach ($restriction in @('none', 'restricted', 'unsupported')) {
        $fixture = New-VerificationFixture "column-parent-$restriction" -Column
        $script:verificationState.restricted = $restriction -eq 'restricted'
        $script:verificationState.missingParentProperty = $restriction -eq 'unsupported'
        $columnEnvelope = Collect-VerificationFixture $fixture
        $columnReport = Evaluate-VerificationFixture $fixture $columnEnvelope
        $expected = switch ($restriction) { none { 'READY_FOR_APPROVAL' }; restricted { 'BLOCKED_COMPATIBILITY' }; unsupported { 'BLOCKED_EVIDENCE' } }
        Assert-Verification ($columnReport.status -eq $expected) "Column parent $restriction expected $expected, got $($columnReport.status)."
        Assert-Verification (-not $columnReport.executionAuthorized -and -not $columnReport.verifiedForHumanReview) 'Column planning acquired execution or live verification.'
    }
    $fixture = New-VerificationFixture 'tampered-evidence'
    $envelope = Collect-VerificationFixture $fixture
    $untrusted = Evaluate-VerificationFixture $fixture $envelope -Certificate $otherCertificate
    Assert-Verification ($untrusted.status -eq 'BLOCKED_EVIDENCE') 'An untrusted signing certificate was accepted.'
    $unsigned = Get-ExecutionReadiness -WorkspaceRoot $fixture.root -ScenarioSlug $fixture.slug -EvidencePath $fixture.evidencePath `
        -EnvironmentUrl 'https://synthetic.example.test' -EnvironmentId $environmentId -TenantId $tenantId -EvaluationTimeUtc $clock
    Assert-Verification (@($unsigned.findings | Where-Object code -EQ 'SIGNED_EVIDENCE_REQUIRED').Count -eq 1 -and -not $unsigned.eligibleForHumanApproval) 'Unsigned FAST-007 assertions bypassed the default authenticated policy.'
    $stale = Evaluate-VerificationFixture $fixture $envelope -Time $clock.AddMinutes(16)
    Assert-Verification ($stale.status -eq 'BLOCKED_EVIDENCE') 'Expired signed evidence was accepted.'
    $envelope.payload.evidence.security.grantedPermissions += 'invented-permission'
    $tampered = Evaluate-VerificationFixture $fixture $envelope
    Assert-Verification ($tampered.status -eq 'BLOCKED_EVIDENCE') 'Tampered signed evidence was accepted.'
    $fixture = New-VerificationFixture 'binding-change' -Hybrid
    $envelope = Collect-VerificationFixture $fixture
    $packagePath = Join-Path (Split-Path $fixture.evidencePath -Parent) 'package.json'
    $metadata = Read-BuildPlanningJson $packagePath; $metadata.publisher.displayName = 'Changed artifact bytes'
    Write-FixtureJson $packagePath $metadata
    $binding = Evaluate-VerificationFixture $fixture $envelope
    Assert-Verification ($binding.status -eq 'BLOCKED_DECISION_CHANGE') 'A changed package metadata artifact retained verification eligibility.'
    $fixture = New-VerificationFixture 'incomplete-dependencies' -Hybrid
    $packagePath = Join-Path (Split-Path $fixture.evidencePath -Parent) 'package.json'
    $metadata = Read-BuildPlanningJson $packagePath
    $metadata.declaredDependencies = @([pscustomobject]@{ required = [pscustomobject]@{
        type = 'unsupported'; id = ''; solution = ''; package = ''; schemaName = ''; uniqueName = ''; parentDisplayName = ''; displayName = 'Synthetic unresolved dependency'
        packageAppName = ''; packageVersion = ''
    } })
    Write-FixtureJson $packagePath $metadata
    $envelope = Collect-VerificationFixture $fixture
    $incomplete = Evaluate-VerificationFixture $fixture $envelope
    Assert-Verification ($incomplete.status -eq 'BLOCKED_EVIDENCE' -and -not $envelope.payload.complete) 'An incomplete dependency graph was treated as verified.'
    $fixture = New-VerificationFixture 'bounded-retry'
    $script:verificationState.throttle = $true
    $retry = Collect-VerificationFixture $fixture
    Assert-Verification ($retry.payload.complete -and $script:verificationState.throttled) 'Shared bounded 429 retry behavior was not reused.'
    $withoutPrivileges = $retry.payload | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $withoutPrivileges.checks = @($withoutPrivileges.checks | Where-Object id -CNE privilege)
    $scopeEnvelope = New-SignedEnvironmentVerification -Payload $withoutPrivileges -SigningCertificate $testCertificate
    $scopeReport = Evaluate-VerificationFixture $fixture $scopeEnvelope
    Assert-Verification ($scopeReport.status -eq 'BLOCKED_EVIDENCE' -and @($scopeReport.findings | Where-Object code -EQ 'VERIFICATION_SCOPE').Count -eq 1) 'A complete signed envelope omitted required effective-privilege checks.'
    $downgraded = $retry.payload | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $downgraded.checks | Where-Object id -CEQ privilege | ForEach-Object { $_.requiredForReadiness = $false }
    $downgradedReport = Evaluate-VerificationFixture $fixture (New-SignedEnvironmentVerification -Payload $downgraded -SigningCertificate $testCertificate)
    Assert-Verification ($downgradedReport.status -eq 'BLOCKED_EVIDENCE') 'A signer downgraded mandatory checks into optional observations.'
    $overlong = $retry.payload | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $overlong.evidence.expiresAtUtc = $clock.AddHours(2).ToString('o')
    $overlongReport = Evaluate-VerificationFixture $fixture (New-SignedEnvironmentVerification -Payload $overlong -SigningCertificate $testCertificate)
    Assert-Verification ($overlongReport.status -eq 'BLOCKED_EVIDENCE') 'Signed evidence exceeded the one-hour maximum lifetime.'
    $expiredCertificateReport = Evaluate-VerificationFixture $fixture $retry -Time $clock.AddDays(2)
    Assert-Verification (@($expiredCertificateReport.findings | Where-Object { $_.code -eq 'VERIFICATION_PROVENANCE' -and $_.message -match 'certificate is expired' }).Count -eq 1) 'Expired signer trust did not block readiness.'
    $fixture = New-VerificationFixture 'unselected-package-scope' -Hybrid
    $metadata = Read-BuildPlanningJson (Join-Path (Split-Path $fixture.evidencePath -Parent) 'package.json')
    $metadata.moduleId = 'unrelated-module'; $metadata.packageId = 'unrelated-package'; $metadata.solution.uniqueName = 'unrelated_solution'
    Write-FixtureJson (Join-Path (Split-Path $fixture.evidencePath -Parent) 'unrelated.json') $metadata
    $manifestPath = Join-Path (Split-Path $fixture.evidencePath -Parent) 'package-input-manifest.json'
    $manifest = Read-BuildPlanningJson $manifestPath
    $manifest.packages += [pscustomobject]@{ moduleId = $metadata.moduleId; packageId = $metadata.packageId; path = 'unrelated.json'; sha256 = $metadata.sha256; version = $metadata.solution.version }
    Write-FixtureJson $manifestPath $manifest
    $fixture.plan.inputFingerprints.packageManifest = Get-BuildPlanningFileHash $manifestPath
    $fixture.plan.planId = Get-ExecutionPlanIdentity $fixture.plan; Write-FixtureJson $fixture.planPath $fixture.plan
    $scoped = Collect-VerificationFixture $fixture
    $scopedReport = Evaluate-VerificationFixture $fixture $scoped
    Assert-Verification ($scopedReport.status -eq 'READY_FOR_APPROVAL' -and $scoped.payload.evidence.packages.Count -eq 1) 'Unselected manifest packages leaked into verification scope or fingerprint binding.'
    Assert-Verification (@($script:verificationRequests | Where-Object { $_.path -match 'unrelated_solution' }).Count -eq 0) 'Collector queried an unrelated manifest module.'
    $fixture = New-VerificationFixture 'transitive-dependency' -Hybrid
    $packageFolder = Split-Path $fixture.evidencePath -Parent
    $metadata = Read-BuildPlanningJson (Join-Path $packageFolder 'package.json')
    $metadata.tables = @([pscustomobject]@{ schemaName = 'tst_Record'; logicalName = 'tst_record'; displayName = 'Synthetic Record'; attributes = @() })
    $metadata.declaredDependencies = @([pscustomobject]@{ required = [pscustomobject]@{
        type = '61'; id = ''; solution = 'dependency_solution (1.0.0.0)'; package = ''; schemaName = 'tst_dependency'
        uniqueName = ''; parentDisplayName = ''; displayName = 'Synthetic dependency'; packageAppName = ''; packageVersion = ''
    } })
    Write-FixtureJson (Join-Path $packageFolder 'package.json') $metadata
    $dependencyMetadata = $metadata | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $dependencyMetadata.moduleId = 'synthetic-dependency'; $dependencyMetadata.packageId = 'synthetic-dependency-v1'
    $dependencyMetadata.solution.uniqueName = 'dependency_solution'; $dependencyMetadata.sha256 = 'd' * 64
    $dependencyMetadata.tables = @(); $dependencyMetadata.declaredDependencies = @()
    Write-FixtureJson (Join-Path $packageFolder 'dependency.json') $dependencyMetadata
    $manifestPath = Join-Path $packageFolder 'package-input-manifest.json'
    $manifest = Read-BuildPlanningJson $manifestPath
    $manifest.packages += [pscustomobject]@{ moduleId = $dependencyMetadata.moduleId; packageId = $dependencyMetadata.packageId; path = 'dependency.json'; sha256 = $dependencyMetadata.sha256; version = $dependencyMetadata.solution.version }
    Write-FixtureJson $manifestPath $manifest
    $fixture.plan.inputFingerprints.packageManifest = Get-BuildPlanningFileHash $manifestPath
    $fixture.plan.planId = Get-ExecutionPlanIdentity $fixture.plan; Write-FixtureJson $fixture.planPath $fixture.plan
    $script:verificationState.includeDependency = $true
    $dependencyEnvelope = Collect-VerificationFixture $fixture
    $dependencyReport = Evaluate-VerificationFixture $fixture $dependencyEnvelope
    Assert-Verification ($dependencyReport.status -eq 'READY_FOR_APPROVAL' -and $dependencyEnvelope.payload.evidence.packages.Count -eq 2) "Pinned installed transitive dependency did not pass: $($dependencyReport.findings | Select-Object code | ConvertTo-Json -Compress)"
    Assert-Verification (($dependencyReport.packageDependencyOrder -join ',') -ceq 'dependency_solution,synthetic_records') 'Transitive dependencies were not ordered before their dependent solution.'
    foreach ($id in @('package-table', 'package-component')) {
        $missingScope = $dependencyEnvelope.payload | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        $missingScope.checks = @($missingScope.checks | Where-Object id -CNE $id)
        $missingScopeReport = Evaluate-VerificationFixture $fixture (New-SignedEnvironmentVerification -Payload $missingScope -SigningCertificate $testCertificate)
        Assert-Verification ($missingScopeReport.status -eq 'BLOCKED_EVIDENCE') "Signed evidence omitted required $id observations."
    }
    $fixture = New-VerificationFixture 'unauthorized-architecture'
    $fixture.decision.explicitApproval = $false
    $decisionPath = Join-Path $fixture.root "specs\$($fixture.slug)\accelerator\accelerator-decision.json"
    Write-FixtureJson $decisionPath $fixture.decision
    $fixture.plan.inputFingerprints.decision = Get-BuildPlanningFileHash $decisionPath
    $fixture.plan.planId = Get-ExecutionPlanIdentity $fixture.plan; Write-FixtureJson $fixture.planPath $fixture.plan
    try { Collect-VerificationFixture $fixture; Assert-Verification $false 'Unapproved architecture reached collection.' }
    catch { Assert-Verification ($_.Exception.Message -match '(not explicitly approved|approved, unchanged)' -and $script:verificationRequests.Count -eq 0) 'Unapproved architecture was not rejected before all requests.' }
    foreach ($case in @(
        @{ name = 'query-scope'; message = 'outside the original query scope'; pages = 2; records = 10; transport = { [pscustomobject]@{ value = @(); '@odata.nextLink' = 'https://synthetic.example.test/api/data/v9.2/systemusers?$select=LogicalName&$skiptoken=next' } } },
        @{ name = 'page-bound'; message = 'page bound'; pages = 1; records = 10; transport = { [pscustomobject]@{ value = @(); '@odata.nextLink' = 'https://synthetic.example.test/api/data/v9.2/EntityDefinitions?$select=LogicalName&$skiptoken=next' } } },
        @{ name = 'record-bound'; message = 'record bound'; pages = 2; records = 1; transport = { [pscustomobject]@{ value = @([pscustomobject]@{ LogicalName = 'one' }, [pscustomobject]@{ LogicalName = 'two' }) } } },
        @{ name = 'cycle'; message = 'pagination cycle'; pages = 2; records = 10; transport = { [pscustomobject]@{ value = @(); '@odata.nextLink' = 'https://synthetic.example.test/api/data/v9.2/EntityDefinitions?$select=LogicalName' } } },
        @{ name = 'null-collection'; message = 'non-array collection'; pages = 2; records = 10; transport = { [pscustomobject]@{ value = $null } } }
    )) {
        try {
            Invoke-FastDataverseGet -EnvironmentUrl 'https://synthetic.example.test' -Path 'EntityDefinitions?$select=LogicalName' `
                -AccessToken 'synthetic-memory-only-token' -RequireComplete -RequestInvoker $case.transport -MaximumPages $case.pages -MaximumRecords $case.records
            Assert-Verification $false "$($case.name) was accepted."
        } catch { Assert-Verification ($_.Exception.Message -match $case.message) "$($case.name) did not fail for its exact safety boundary." }
    }
    $pagination = Invoke-FastDataverseGet -EnvironmentUrl 'https://synthetic.example.test' -Path 'EntityDefinitions?$select=LogicalName' `
        -AccessToken 'synthetic-memory-only-token' -RequireComplete -RequestInvoker {
            param($request)
            if ($request.Uri.Contains('skiptoken')) { return [pscustomobject]@{ value = @([pscustomobject]@{ LogicalName = 'second' }) } }
            return [pscustomobject]@{ value = @([pscustomobject]@{ LogicalName = 'first' }); '@odata.nextLink' = 'https://synthetic.example.test/api/data/v9.2/EntityDefinitions?$select=LogicalName&$skiptoken=next' }
        }
    Assert-Verification ($pagination.value.Count -eq 2) 'Complete same-query pagination was not collected.'
    $fixture = New-VerificationFixture 'cli-verification'
    $cliClock = [DateTimeOffset]::UtcNow
    $cliCertificate = $request.CreateSelfSigned($cliClock.AddDays(-1), $cliClock.AddDays(1))
    $cliEnvelope = & (Join-Path $repoRoot 'scripts\accelerators\invoke-trusted-environment-verification.ps1') `
        -EnableAuthenticatedVerification -ConfirmReadOnlyScope -WorkspaceRoot $fixture.root -ScenarioSlug $fixture.slug `
        -EnvironmentUrl 'https://synthetic.example.test' -EnvironmentId $environmentId -TenantId $tenantId -SolutionUniqueName 'extension_solution' `
        -SigningCertificate $cliCertificate -CollectionMode Mock -TokenProvider { 'synthetic-memory-only-token' } -RequestInvoker ($mockTransport.GetNewClosure())
    $certificateFile = Join-Path $fixture.root 'independently-supplied-test-certificate.cer'
    [IO.File]::WriteAllBytes($certificateFile, $cliCertificate.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert))
    $cliEvidencePath = Join-Path $fixture.root "specs\$($fixture.slug)\accelerator\verification\trusted-environment-verification.json"
    $cliReport = & (Join-Path $repoRoot 'scripts\accelerators\invoke-execution-readiness.ps1') -EnableExecutionReadiness `
        -WorkspaceRoot $fixture.root -ScenarioSlug $fixture.slug -EvidencePath $cliEvidencePath -EnvironmentUrl 'https://synthetic.example.test' `
        -EnvironmentId $environmentId -TenantId $tenantId -EvidenceTrustPolicy RecordedTest -TrustedCertificatePath $certificateFile
    Assert-Verification ($cliEnvelope.payload.complete -and $cliReport.status -eq 'READY_FOR_APPROVAL') "Explicit collection/readiness commands did not preserve the signed contract: $($cliEnvelope.payload.checks | Where-Object { $_.requiredForReadiness -and $_.state -ne 'verified' } | Select-Object id,target | ConvertTo-Json -Compress)"
    Assert-Verification ([DateTimeOffset]::Parse($cliEnvelope.payload.evidence.observedAtUtc) -ge $cliClock) 'CLI collection used the historical fixture clock instead of the actual collection time.'
    Assert-Verification (-not $cliReport.executionAuthorized -and -not $cliReport.verifiedForHumanReview) 'Command integration claimed execution/live verification.'
    foreach ($mode in @('Live', 'Mock')) {
        try {
            Invoke-TrustedEnvironmentVerification -WorkspaceRoot $fixture.root -ScenarioSlug $fixture.slug -EnvironmentUrl 'https://synthetic.example.test' `
                -EnvironmentId $environmentId -TenantId $tenantId -SolutionUniqueName 'extension_solution' -SigningCertificate $testCertificate -CollectionMode $mode
            Assert-Verification $false 'Verification ran without feature/scope opt-in.'
        } catch { Assert-Verification ($_.Exception.Message -match 'disabled by default') 'Feature/scope guard failed for the wrong reason.' }
    }
    try {
        Invoke-TrustedEnvironmentVerification -EnableAuthenticatedVerification -ConfirmReadOnlyScope -WorkspaceRoot $fixture.root `
            -ScenarioSlug $fixture.slug -EnvironmentUrl 'https://synthetic.example.test' -EnvironmentId $environmentId -TenantId $tenantId `
            -SolutionUniqueName 'extension_solution' -SigningCertificate $testCertificate -CollectionMode Live -RequestInvoker $mockTransport
        Assert-Verification $false 'Mock transport could label a collection Live.'
    } catch { Assert-Verification ($_.Exception.Message -match 'rejects injected transports') 'Live transport guard failed for the wrong reason.' }
    Assert-Verification (@(Get-ChildItem -LiteralPath $tempRoot -Recurse -Filter 'build-authorization.json' -File).Count -eq 0) 'Verification generated deployment authorization.'
    if (-not [string]::IsNullOrWhiteSpace($SampleOutputFolder)) {
        Assert-Verification (@(Get-ChildItem -LiteralPath $SampleOutputFolder -Recurse -Filter execution-readiness.json -File).Count -eq 7) 'Expected seven persisted cross-domain readiness reports.'
        Assert-Verification (@(Get-ChildItem -LiteralPath $SampleOutputFolder -Recurse -Filter trusted-environment-verification.json -File).Count -eq 7) 'Expected seven matching persisted signed evidence envelopes.'
    }
} finally {
    foreach ($certificate in @($testCertificate, $publicCertificate, $otherCertificate, $cliCertificate)) { if ($null -ne $certificate) { $certificate.Dispose() } }
    $rsa.Dispose(); $otherRsa.Dispose()
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
if ($verificationFailures.Count -gt 0) { throw "FAST-008A failed ($($verificationFailures.Count)/$verificationAssertions):`n - $($verificationFailures -join "`n - ")" }
Write-Host "FAST-008A trusted verification passed: $verificationAssertions assertions; 4 unrelated applications; mocked authenticated GET-only collection. No live environment queried." -ForegroundColor Green
