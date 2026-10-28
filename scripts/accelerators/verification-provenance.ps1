<#
=============================================================================
COMPONENT:    Verification Evidence Provenance
FILE:         scripts/accelerators/verification-provenance.ps1
VERSION:      1.0.0
AUTHOR:       Power Platform VS Code Starter
LAST UPDATED: 2026-10-19
ENVIRONMENT:  PowerShell 7 | X509 | RSA SHA-256
-----------------------------------------------------------------------------
OVERVIEW
Signs collection evidence and validates it against independent certificate trust.
NON-NEGOTIABLES
No certificate generation, embedded-key trust, credentials, or authorization.
=============================================================================
#>

function Get-VerificationPrivilegeRequirements {
    param([Parameter(Mandatory)] [object]$Plan)
    $capabilities = [ordered]@{}
    if (@($Plan.componentPlans | Where-Object action -In @('CREATE', 'EXTEND')).Count -gt 0) {
        $privileges = @('prvPublishCustomization')
        if (@($Plan.componentPlans | Where-Object { $_.componentKind -eq 'table' -and $_.action -eq 'CREATE' }).Count -gt 0) {
            $privileges += @('prvCreateEntity', 'prvWriteEntity')
        }
        if (@($Plan.componentPlans | Where-Object { $_.componentKind -eq 'column' -or $_.action -eq 'EXTEND' }).Count -gt 0) {
            $privileges += @('prvCreateAttribute', 'prvWriteAttribute')
        }
        $capabilities.customize = @($privileges | Sort-Object -Unique)
        $capabilities.'write-solution' = @('prvReadSolution', 'prvWriteSolution', 'prvReadPublisher')
    }
    return $capabilities
}

function Get-VerificationCertificateHash {
    param([Parameter(Mandatory)] [Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Certificate.RawData)).ToLowerInvariant()
}

function Test-VerificationCheckScope {
    param([Parameter(Mandatory)] [object]$Envelope, [Parameter(Mandatory)] [object]$Plan,
        [AllowEmptyCollection()] [object[]]$PackageMetadata = @())
    $requirements = [Collections.Generic.List[object]]::new()
    $origin = $Envelope.payload.evidence.environment.url
    foreach ($id in @('authenticated-connection', 'environment-identity')) {
        $requirements.Add([pscustomobject]@{ id = $id; target = $origin }) | Out-Null
    }
    $requirements.Add([pscustomobject]@{ id = 'authenticated-context-stable'; target = $Envelope.payload.evidence.security.principalId }) | Out-Null
    $publisherChecks = @($Envelope.payload.checks | Where-Object id -CEQ 'extension-publisher')
    if ($publisherChecks.Count -ne 1 -or -not $publisherChecks[0].requiredForReadiness -or $publisherChecks[0].state -cne 'verified') { return $false }
    if (@($Envelope.payload.checks | Group-Object id, target | Where-Object Count -GT 1).Count -gt 0) { return $false }
    foreach ($task in $Plan.componentPlans) {
        $requirements.Add([pscustomobject]@{ id = 'component-cardinality'; target = $task.taskId }) | Out-Null
        $components = @($Envelope.payload.evidence.components | Where-Object taskId -CEQ $task.taskId)
        if ($components.Count -ne 1) { return $false }
        if ($components[0].exists) {
            foreach ($id in @('managed-property', 'component-owner')) {
                $requirements.Add([pscustomobject]@{ id = $id; target = $task.taskId }) | Out-Null
            }
            if ($task.action -eq 'EXTEND') { $requirements.Add([pscustomobject]@{ id = 'customization'; target = $task.taskId }) | Out-Null }
        }
        if ($task.componentKind -eq 'column' -and $task.action -in @('CREATE', 'EXTEND')) {
            $requirements.Add([pscustomobject]@{ id = 'parent-customization'; target = $task.taskId }) | Out-Null
        }
    }
    foreach ($package in $Envelope.payload.evidence.packages) {
        $requirements.Add([pscustomobject]@{ id = 'installed-solution'; target = $package.solutionUniqueName }) | Out-Null
        if ($package.installed) {
            foreach ($id in @('package-version', 'package-publisher')) {
                $requirements.Add([pscustomobject]@{ id = $id; target = $package.solutionUniqueName }) | Out-Null
            }
            foreach ($package in $PackageMetadata) {
                foreach ($table in $package.tables) {
                    $requirements.Add([pscustomobject]@{ id = 'package-table'; target = "$($package.moduleId):$($table.logicalName)" }) | Out-Null
                }
                foreach ($dependency in $package.declaredDependencies) {
                    $requirements.Add([pscustomobject]@{ id = 'package-component'; target = "$($package.packageId):$(Get-FastDependencyKey -Dependency $dependency)" }) | Out-Null
                }
            }
        }
    }
    $capabilities = Get-VerificationPrivilegeRequirements -Plan $Plan
    foreach ($name in @($capabilities.Values | ForEach-Object { $_ } | Sort-Object -Unique)) {
        $requirements.Add([pscustomobject]@{ id = 'privilege'; target = $name }) | Out-Null
    }
    foreach ($requirement in $requirements) {
        $matches = @($Envelope.payload.checks | Where-Object { $_.id -ceq $requirement.id -and $_.target -ceq $requirement.target })
        if ($matches.Count -ne 1 -or -not $matches[0].requiredForReadiness -or $matches[0].state -cne 'verified') { return $false }
    }
    return $true
}

function Test-VerificationCertificateTime {
    param(
        [Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [DateTimeOffset]$TimeUtc
    )
    if ($TimeUtc.UtcDateTime -lt $Certificate.NotBefore.ToUniversalTime() -or
        $TimeUtc.UtcDateTime -ge $Certificate.NotAfter.ToUniversalTime()) { return $false }
    foreach ($extension in $Certificate.Extensions) {
        if ($extension -is [Security.Cryptography.X509Certificates.X509KeyUsageExtension] -and
            ($extension.KeyUsages -band [Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature) -eq 0) {
            return $false
        }
    }
    return $true
}

function New-SignedEnvironmentVerification {
    param(
        [Parameter(Mandatory)] [object]$Payload,
        [Parameter(Mandatory)] [Security.Cryptography.X509Certificates.X509Certificate2]$SigningCertificate
    )

    if (-not $SigningCertificate.HasPrivateKey -or
        -not (Test-VerificationCertificateTime -Certificate $SigningCertificate -TimeUtc ([DateTimeOffset]::Parse($Payload.evidence.observedAtUtc)))) {
        throw 'A valid operator-provided signing certificate with a private key is required.'
    }
    $key = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($SigningCertificate)
    if ($null -eq $key) { throw 'The evidence signing certificate must use RSA.' }
    try {
        if ($key.KeySize -lt 2048) { throw 'Evidence signing requires RSA with at least 2048 bits.' }
        $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-AcceleratorCanonicalJson -InputObject $Payload))
        $signature = $key.SignData($bytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    } finally { $key.Dispose() }
    return [pscustomobject][ordered]@{
        schemaVersion = '1.0'; artifactType = 'trusted-environment-verification'; payload = $Payload
        signature = [pscustomobject][ordered]@{
            algorithm = 'RS256'; certificateSha256 = Get-VerificationCertificateHash -Certificate $SigningCertificate
            value = [Convert]::ToBase64String($signature)
        }
    }
}

function Test-EnvironmentVerificationProvenance {
    param(
        [Parameter(Mandatory)] [object]$Envelope,
        [AllowNull()] [Security.Cryptography.X509Certificates.X509Certificate2]$TrustedCertificate,
        [ValidateSet('Authenticated', 'RecordedTest', 'LocalPlanning')] [string]$EvidenceTrustPolicy = 'Authenticated',
        [DateTimeOffset]$EvaluationTimeUtc = [DateTimeOffset]::UtcNow
    )

    $result = [pscustomobject]@{ valid = $false; classification = 'unverified'; message = 'An independently trusted evidence certificate is required.' }
    if (-not (Test-ExecutionSchema -Value $Envelope -SchemaName 'trusted-environment-verification')) {
        $result.message = 'The signed evidence envelope violates its versioned schema.'
        return $result
    }
    if ($null -eq $TrustedCertificate) { return $result }
    if ($Envelope.signature.certificateSha256 -cne (Get-VerificationCertificateHash -Certificate $TrustedCertificate)) {
        $result.message = 'Evidence signer does not match the independently provisioned trusted certificate.'
        return $result
    }
    if (-not (Test-ExecutionSchema -Value $Envelope.payload.evidence -SchemaName 'execution-evidence')) {
        $result.message = 'Signed prerequisite evidence violates the execution-evidence schema.'
        return $result
    }
    $observed = [DateTimeOffset]::Parse($Envelope.payload.evidence.observedAtUtc)
    $expires = [DateTimeOffset]::Parse($Envelope.payload.evidence.expiresAtUtc)
    if ($expires -le $observed -or ($expires - $observed).TotalSeconds -gt 3600) {
        $result.message = 'Trusted verification evidence must expire within one hour of collection.'
        return $result
    }
    if (-not (Test-VerificationCertificateTime -Certificate $TrustedCertificate -TimeUtc $observed) -or
        -not (Test-VerificationCertificateTime -Certificate $TrustedCertificate -TimeUtc $EvaluationTimeUtc)) {
        $result.message = 'The trusted signing certificate is expired, not yet valid, or not permitted for digital signatures.'
        return $result
    }
    $key = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($TrustedCertificate)
    if ($null -eq $key) { $result.message = 'The trusted certificate does not contain an RSA public key.'; return $result }
    try {
        try { $signature = [Convert]::FromBase64String($Envelope.signature.value) }
        catch [FormatException] { $result.message = 'The evidence signature encoding is invalid.'; return $result }
        $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-AcceleratorCanonicalJson -InputObject $Envelope.payload))
        if ($key.KeySize -lt 2048 -or -not $key.VerifyData($bytes, $signature,
            [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)) {
            $result.message = 'Evidence signature validation failed; the payload or signature was changed.'
            return $result
        }
    } catch [Security.Cryptography.CryptographicException] {
        $result.message = 'Evidence signature validation failed cryptographically.'
        return $result
    } finally { $key.Dispose() }
    if ($EvidenceTrustPolicy -eq 'Authenticated' -and
        ($Envelope.payload.collectionMode -ne 'Live' -or
         [Math]::Abs(($EvaluationTimeUtc - [DateTimeOffset]::UtcNow).TotalMinutes) -gt 5)) {
        $result.message = 'Authenticated readiness requires live provenance and a current evaluation clock, not mock or historical simulation.'
        return $result
    }
    if ($EvidenceTrustPolicy -eq 'RecordedTest' -and $Envelope.payload.collectionMode -ne 'Mock') {
        $result.message = 'RecordedTest policy accepts only explicitly labelled mock collection.'
        return $result
    }
    if (-not $Envelope.payload.complete -or
        @($Envelope.payload.checks | Where-Object { $_.requiredForReadiness -and $_.state -ne 'verified' }).Count -gt 0) {
        $result.message = 'The signed inspection is incomplete, inaccessible or unsupported; a signature cannot fill evidence gaps.'
        return $result
    }
    $result.valid = $true
    $result.classification = if ($EvidenceTrustPolicy -eq 'Authenticated') { 'authenticated' } elseif ($EvidenceTrustPolicy -eq 'RecordedTest') { 'recorded-test' } else { 'local-planning' }
    $result.message = 'Signature, external trust anchor, collection mode and inspection completeness validated; no execution is authorized.'
    return $result
}
