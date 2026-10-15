# FAST Catalog and Decision Contracts

**Status:** FAST-001 conceptual contract  
**Implementation:** FAST-002 catalog contracts, FAST-003 preflight report, and
FAST-004 requirements analysis

## Design rules

1. External source data is untrusted and inert.
2. All identities are provider-scoped and stable across snapshots where
   possible.
3. Every normalized claim retains source provenance.
4. Snapshot content is immutable after promotion.
5. Documentation claims never become executable schema without stronger
   verification.
6. Missing or inaccessible evidence is represented explicitly.

## Provider health

```text
providerId
enabled
availability: healthy | degraded | unavailable | retired
maintenanceState: active | archived | unknown
lastCheckedAtUtc
lastSuccessfulSyncAtUtc
promotedSnapshotId
message
sourceStatuses[]
```

For the current FAST source, `maintenanceState` is `archived`.

## Source record

```text
sourceRecordId
providerId
canonicalUrl
sourceKind
repository
repositoryArchived
commitSha | etag
retrievedAtUtc
contentType
contentLength
contentHash
license
status
error
```

Raw bodies must be bounded by retention, licensing, and size policy. A hash and
source anchor are mandatory even when only a legal extract is retained.

## Catalog snapshot

```text
snapshotId
providerId
catalogSchemaVersion
createdAtUtc
sourceCutoffAtUtc
contentHash
status: candidate | validated | promoted | rejected | retired
maintenanceState
previousPromotedSnapshotId
sourceManifest[]
coverage
validationResults[]
items[]
dependencyEdges[]
releases[]
```

### Coverage

Coverage reconciles independent inventories:

```text
sourceDirectories
documentedItems
statisticsItems
releasedItems
useCases
personas
agents
portals
missingDocumentation[]
missingSource[]
missingStatistics[]
missingPackages[]
exceptions[]
```

Counts are observations within a snapshot, not constants in code.

## Catalog item

```text
itemId
providerId
itemType: module | use-case | persona | agent | portal | data-model
slug
name
description
publishedState
maintenanceState
tags[]
capabilities[]
workflows[]
actors[]
relatedItemIds[]
dependencyIds[]
latestDocumentedVersion
packageAvailability
availabilityStates:
  documented
  sourceAvailable
  packageVerified
  environmentVerified
sourceEvidence[]
```

Availability states are independent and evidence-based. A module may be
documented and source-available without a verified package, or package-verified
without environment verification. No state implies a later state.

## Capability evidence

```text
evidenceId
claimType
claim
subjectItemId
componentIdentity
tier: conceptual | package-verified | environment-verified
verificationState: verified | unverified | contradicted | unavailable
sourceRecordId
sourceUrl
sourceAnchor
sourceVersion
observedAtUtc
confidence
notes
```

Contradictory evidence remains visible. Package or environment evidence can
supersede a claim for a specific decision without deleting its history.

## Package release

```text
releaseId
moduleId
documentedVersion
documentedReleaseUrls[]
releaseVersion
releaseUrl
tag
publishedAtUtc
assets[]
managedPackageAvailable
unmanagedPackageAvailable
packageHash
signatureState
verificationState
sourceEvidence[]
physicalMetadataEvidenceId
```

`documentedVersion` and `releaseVersion` are separate because current FAST
documentation and GitHub Releases diverge.

## Dependency edge

```text
edgeId
fromModuleId
toModuleId
dependencyType: required-module | required-data-model | solution-dependency
versionConstraint
evidenceTier
verificationState
sourceEvidence[]
```

The graph must reject self-dependencies, cycles, unresolved required nodes, and
incompatible constraints before deployment planning. Conceptual matching may
continue with unresolved edges clearly surfaced.

## Normalized requirement

```text
requirementId
scenarioSlug
statement
acceptanceCriteria[]
actors[]
entities[]
integrations[]
requiredCapabilities[]
priority
uncertainties[]
normalizedTerms[]
```

Requirements remain local to the scenario and are not uploaded to FAST sources.

## Requirement decision

```text
requirementId
dispositions[]: REUSE | EXTEND | BUILD | INTEGRATE | VERIFY
candidateModuleId
candidateVersion
candidates[]
fitExplanation
evidenceLevel
gaps[]
proposedSchemaChanges
integrations[]
dependencies[]
effortAssumptions[]
risks[]
unresolvedQuestions[]
acceptanceCriteria[]
taskReferences[]
```

Functional fit and environment readiness are evaluated separately. Ordinal,
explainable evidence bands replace arbitrary numeric confidence scores. A
relevant archived reference module may have architectural value while its
source or deployment readiness remains blocked.

## Requirements analysis

The version `1.0` requirements-analysis document binds normalized requirements
to a provider and immutable snapshot. It contains:

```text
analysisId
providerId
snapshotId
scenarioSlug
requirementsHash
requirements[]
coverageMatrix[]
componentDeltaAnalysis[]
schemaPlan
dependencyManifest
environmentReadiness
architectureOptions[]
recommendedOption
finalChoiceRequired: true
acceptanceTraceability[]
limitations[]
```

The analysis ID excludes evaluation-time noise and is reproducible for the
same normalized requirements, catalog snapshot, package metadata, and
environment-reference inputs. Environment evidence is optional and never
causes a live request.

## Accelerator decision

```text
decisionId
scenarioSlug
providerId
snapshotId
evaluatedAtUtc
requirementsHash
alternatives[]
selectedAlternative: fast-foundation | hybrid | fully-custom
selectedModules[]
requirementDecisions[]
unverifiedAssumptions[]
deploymentBlockers[]
userRationale
approvedBy
approvedAtUtc
```

The decision is planning evidence only. It contains no deployment credential
and grants no mutation authorization.

## Environment preflight report

```text
schemaVersion: 1.1
providerId
scenarioSlug
level: environment-preflight
status | readinessStatus
validatedAtUtc
expiresAtUtc
catalogSnapshotId
environment:
  environmentId
  environmentUrl
  tenantId
  organizationVersion
requiredModules[]
installedModules[]
dependencyAssessment[]
missingComponents[]
incompatibleComponents[]
checks[]
evidence:
  evidenceType
  coreAssessment
  metadataFingerprint
  permissions[]
  inspectionErrors[]
  cache
limitations[]
recommendedNextAction
```

The report contains no token. A fresh report is bound to the environment,
catalog snapshot, package identities/hashes/versions, dependency versions, and
evidence validity window. It never guarantees future import success.

## Snapshot promotion invariants

- Every source record has canonical URL, timestamp, and content hash.
- Coverage reconciliation is complete or contains approved exceptions.
- No required identity is duplicated.
- All dependency references resolve or are explicitly unavailable.
- The dependency graph is acyclic for deployable modules.
- Candidate schema and content hash are valid.
- Source maintenance/archive state is recorded.
- Promotion never mutates an existing snapshot.
- Matching never reads an unpromoted candidate.
- Rollback changes only the promoted pointer.
