# FAST Catalog and Decision Contracts

**Status:** FAST-001 conceptual contract  
**Implementation:** Deferred to FAST-002 and later

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
workflows[]
entities[]
relationships[]
integrations[]
securityConstraints[]
nonfunctionalConstraints[]
priority
```

Requirements remain local to the scenario and are not uploaded to FAST sources.

## Requirement decision

```text
requirementId
decision: reuse | extend | build-new | integrate | verify | not-applicable
candidateItemId
candidateComponentIdentity
evidenceIds[]
evidenceTier
confidence
functionalFit
deployability
gaps[]
constraints[]
dependencyImplications[]
customizationClass
rationale
```

Functional fit and deployability are scored separately. A relevant archived
reference module may have strong functional fit but blocked deployability.

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
