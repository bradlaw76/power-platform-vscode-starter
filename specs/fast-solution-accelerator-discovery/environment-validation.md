# FAST Environment Compatibility Contract

**Status:** FAST-002 implemented; runtime integration not authorized
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

Level 2 accepts evidence from an injected read-only environment inspector. The
FAST-002 implementation is transport-neutral and uses fixtures; it is not
wired to authentication or the wizard runtime.

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

The three modes and existing build stages remain unchanged in FAST-002.
