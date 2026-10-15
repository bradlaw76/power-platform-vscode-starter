# ADR 0005: Live Read-Only Dataverse Preflight and Evidence Cache

**Status:** Accepted for FAST-003
**Date:** 2026-10-15

## Context

FAST-002 defined Level 2 environment preflight but had no authenticated
Dataverse transport. FAST-dependent generation must distinguish package
metadata from current environment evidence without adding a wizard stage or
granting mutation authority.

## Decision

Implement an explicitly invoked, read-only Dataverse inspector that reuses the
repository's authenticated environment file, access-token refresh, retry,
timeout, and error-redaction conventions.

The inspector uses only bounded metadata reads:

- environment identity and organization version;
- filtered installed solution and publisher metadata;
- batched required-table checks;
- grouped form, web resource, custom control, setting definition, attribute,
  and global Choice dependency checks.

Local evidence caching is keyed by environment URL, catalog snapshot, package
IDs, package hashes, selected versions, dependency identities, and dependency
versions. Cache entries contain no token and expire after a bounded validity
window. A fresh inspection records a metadata fingerprint; a changed
environment response replaces the prior evidence.

The reusable readiness evaluator requires exact selected solution versions and
publisher identity. It reports `ready`, `action-required`, `incompatible`, or
`unverified` and never predicts import success.

## Consequences

- Requirements and architecture planning remain available offline.
- Fully custom generation remains independent of FAST.
- Authentication, permissions, throttling, and timeouts fail closed without
  leaking credentials.
- Changing environment, snapshot, package hash/version, dependency version, or
  evidence age invalidates reuse.
- Cache freshness cannot detect an environment change before expiry without a
  new request; the build gate therefore requires unexpired evidence and
  supports forced refresh.
- No wizard stage, package import, or Dataverse mutation is introduced.

## Rejected alternatives

- **Query Dataverse during normal discovery:** adds mandatory latency and
  authentication to custom-only planning.
- **Cache by environment URL alone:** permits stale evidence after package or
  catalog changes.
- **Accept newer installed versions automatically:** package compatibility is
  unproven without an explicit compatibility policy.
- **Use package declarations as installed-component proof:** conflates static
  package evidence with live environment state.
