# FAST Environment Compatibility Contract

**Status:** FAST-003 live read-only preflight implemented; wizard integration not authorized
**Applies to:** Any future FAST-dependent Dataverse build
**Does not apply to:** Fully custom architecture

## Purpose

Catalog discovery and package inspection cannot prove that a FAST solution is
installed or compatible with a selected Dataverse environment. This contract
keeps package evidence, read-only environment evidence, and approved
installation outcomes separate.

Requirements analysis and specification generation may use an immutable
catalog snapshot without a Dataverse connection. FAST-dependent Dataverse
generation may not begin until the build gate described below passes.

## Level 1 - Catalog compatibility

Level 1 is credential-free and does not access Dataverse. It validates:

- managed solution ZIP integrity and SHA-256 provenance;
- selected solution names and versions;
- package-inspected component metadata;
- Core-first selection for specialty modules;
- every dependency declared by the selected packages.

Level 1 returns `ready`, `action-required`, `incompatible`, or `unverified`
with checks and limitations. A package with unresolved environment
dependencies returns `action-required`. Level 1 never claims an import will
succeed.

## Level 2 - Read-only environment preflight

Level 2 uses the standalone authenticated read-only inspector in
`scripts/accelerators/dataverse-environment-inspector.ps1`. The operator entry
point is `scripts/accelerators/invoke-fast-environment-preflight.ps1`. It
requires explicit `-EnableFast`, reuses the existing authenticated environment
file when credentials are not supplied directly, and remains disconnected from
wizard stages.

The future inspector must verify, where permissions permit:

1. selected environment ID, URL, tenant, and connection;
2. installed FAST Core solution and version;
3. installed specialty solutions and versions;
4. required installed Dataverse components and declared dependencies;
5. application prerequisites and version conflicts;
6. ability to read solution and metadata evidence;
7. evidence timestamp and stated limitations.

The result is:

- `ready` when current evidence satisfies all selected packages and declared
  dependencies;
- `action-required` when a required solution or dependency is missing;
- `incompatible` for blocking version conflicts or ambiguous evidence;
- `unverified` for stale evidence, unavailable permissions, offline access, or
  a user-declined read-only check.

Read-only preflight does not prove a future import will succeed. Transient
service health, capacity, policy, plugin, and undisclosed dependency conditions
may still block an approved installation.

### Read-only request plan

The inspector minimizes requests by using:

1. one `WhoAmI` identity request;
2. one organization-version request;
3. one filtered solution query with publisher expansion;
4. table metadata filters in bounded chunks;
5. dependency checks grouped by component kind and parent table.

Supported package dependency identities include forms, web resources, custom
controls, setting definitions, table attributes, and global Choice metadata.
Unknown dependency types remain `unverified`.

Requests have bounded timeout and retry limits. The shared Dataverse runtime
refreshes once after `401`, honors `Retry-After` for `429`, applies exponential
backoff to transient failures, and redacts token values from terminal errors.
No token is written to a report or cache.

### Versioned preflight report

Schema version `1.1` records:

- environment ID, URL, tenant evidence, and organization version;
- inspection and expiration timestamps;
- catalog snapshot ID;
- required package IDs, versions, and hashes;
- installed FAST modules and exact versions;
- dependency assessments;
- missing and incompatible components;
- readiness status, checks, evidence, limitations, and next action;
- metadata fingerprint, permissions, request count, and cache provenance.

Selected package versions must match installed versions exactly until a
separately reviewed compatibility policy exists.

### Evidence cache

Read-only evidence may be cached locally under `.wizard-metrics`. The cache key
binds:

- normalized environment URL;
- catalog snapshot ID;
- package IDs, selected versions, and hashes;
- dependency identities and declared dependency versions.

Entries expire after a bounded TTL and contain no access token. Environment
switches and catalog/package/dependency changes produce a different key.
Fresh inspection results carry a metadata fingerprint and replace cached
evidence when environment metadata changes. `-ForceRefresh` bypasses the cache.

## Level 3 - Approved installation verification

FAST-002 defines only the future workflow:

1. obtain explicit authorization for the exact development or sandbox
   environment modification;
2. revalidate the selected immutable snapshot and package hashes;
3. verify Core prerequisites;
4. import and verify Core;
5. import each separately approved specialty module in dependency order;
6. capture import outcome, installed versions, unresolved dependencies, and
   post-import component evidence;
7. persist fresh installation verification before opening the build gate.

Automated import is not implemented. Each environment modification requires
separate authorization.

## Mandatory FAST-dependent build gate

The gate permits:

- a fully custom architecture without FAST evidence; or
- FAST foundation/hybrid execution only with fresh `ready` Level 2 or Level 3
  evidence.

For FAST foundation or hybrid execution, evidence must match:

- the current catalog snapshot ID;
- the selected environment ID;
- every selected package ID and SHA-256 hash;
- the current evidence validity window.

Changing the environment, selected package/version/hash, or catalog snapshot,
or allowing evidence to expire, closes the gate and requires revalidation.
Offline, user-declined, or otherwise unverified environments remain available
for requirements analysis only.

## Mode presentation for future integration

- Demo Builder: concise compatibility status with no mandatory FAST question.
- Advanced Builder: full package, dependency, version, evidence, and limitation
  detail.
- Framework Acceptance: ready, missing-dependency, incompatible,
  stale-evidence, offline, and user-declined fixtures.

The three modes and existing build stages remain unchanged in FAST-003.

## FAST-003A GCC evidence

The first authorized live Level 2 run is recorded in
[`evidence/fast-003a-gcc-validation.md`](evidence/fast-003a-gcc-validation.md).
It validated a user-confirmed GCC `UsGov` environment through its
`crm9.dynamics.com` endpoint using a resource-scoped token. The run issued only
GET requests and found no installed FAST modules. Core was missing, so the
result was `action-required` and the FAST-dependent build gate remained closed.

This evidence does not assert FAST product support or importability in GCC.
