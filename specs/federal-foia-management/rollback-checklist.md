# Federal FOIA Management Rollback Checklist

**Checklist ID:** `FOIA-ROLLBACK-1.0`
**Use:** Separately authorized deployment backout only
**Non-authorization:** This checklist does not authorize authentication, mutation,
deployment, package import, deletion, or records disposition.

## Current Development Checkpoint

This checkpoint is evidence for comparison and forward-fix planning; it does not
authorize rollback or import.

- Branch: `feature/federal-foia-management`
- Known local commits: `49cc130`, `3e2c430`, and `bbef403`
- Solution: unmanaged `FederalFOIAManagement`
- Strict membership baseline: 232 already in solution; zero failed, missing, or
  unauthorized
- Idempotency baseline: 673 stable identities; zero failures and duplicate
  candidates
- Unmanaged package inspection: 24 of 24 expected root components matched; zero
  missing or unrelated components
- Synthetic-data baseline: 41 source-tagged records; rerun updates the same
  identities
- Runtime evidence locations are listed in `evidence-index.md`
- No managed release, import, push, pull request, or production deployment is
  represented by this checkpoint

## Non-Negotiable Preservation Rules

- Never delete, overwrite, deactivate, or truncate Clock Events, Audit Events,
  released package versions/manifests, release correspondence evidence, certified
  report runs, approval evidence, legal-hold records, or records under an approved
  retention schedule.
- Never “restore” a prior due date or decision by editing history. Append an
  authorized compensating event linked to the affected event.
- Never roll back SharePoint content or permissions based only on Dataverse state.
- Never remove a field/table while retained records, dependencies, or legal/audit
  evidence use it.
- A solution uninstall is not a general rollback strategy. Destructive operations
  require Records Officer, legal, security, and platform approval.
- Stop if the proposed action would shorten retention, break chain of custody,
  orphan a document reference, or obscure who performed an action.

## Rollback Trigger And Authority

- [ ] Record incident/change ID, UTC detection time, reporter, and correlation IDs.
- [ ] Classify trigger: failed import, metadata defect, security exposure,
      automation defect, performance regression, data-integrity issue, reporting
      defect, or document-permission error.
- [ ] Identify deployed solution version, prior known-good version, manifest ID,
      package hashes, and exact affected component scope.
- [ ] Confirm rollback is safer than forward fix; document the decision.
- [ ] Obtain Release Manager and Platform Owner approval.
- [ ] Add Security Officer approval for access, role, field-security, connector, or
      secret impacts.
- [ ] Add Records Officer/Legal approval for retained, released, appealed, held, or
      potentially responsive records.
- [ ] Confirm the operator is authorized for the named environment and action.

## Immediate Containment

- [ ] Preserve logs, Audit Events, Clock Events, flow run IDs, plug-in traces,
      package hashes, permission manifests, and certified report evidence.
- [ ] Create a non-secret incident evidence index and hash captured artifacts.
- [ ] Disable only the affected entry point, flow, plug-in step, routing rule, SLA,
      connector, app module, or feature flag needed to stop harm.
- [ ] Set every optional Azure flag false when an optional adapter is implicated.
- [ ] Do not disable the authoritative clock plug-in without an approved continuity
      procedure for recording queued clock commands.
- [ ] Revoke or rotate exposed credentials outside source control; do not place the
      replacement value in evidence or the manifest.
- [ ] Freeze package release and bulk export when integrity or authorization is in
      question; record the freeze as an Audit Event.
- [ ] Communicate a safe manual procedure and owner for time-critical FOIA work.

## Pre-Change Snapshot

- [ ] Export current solution component inventory and IDs.
- [ ] Capture solution membership and unauthorized/foreign component scan.
- [ ] Capture active flow, plug-in-step, SLA, queue, routing, and feature-flag state.
- [ ] Capture environment-variable values through an approved protected channel;
      store only hashes/status in the deployment manifest.
- [ ] Export SharePoint permission manifest, inheritance state, item versions, and
      affected document hashes without copying protected content into source.
- [ ] Capture counts/high-water marks for Requests, Cases, Tasks, Decisions,
      Packages, Appeals, Clock Events, Audit Events, AI records, and certified runs.
- [ ] Confirm platform backup/restore evidence for the authorized recovery point.
- [ ] Confirm legal holds and retention classes for every affected record set.

## Component Backout Order

Perform only approved items, in dependency-safe order.

### 1. Traffic And Optional Features

- [ ] Disable affected inbound API, FOIA.gov, portal, email, and optional Azure
      feature flags.
- [ ] Disable or redirect affected flows after preserving in-flight run evidence.
- [ ] Stop new assignments through affected queues/routing rules.
- [ ] Keep manual/staff intake and core processing available where safe.

### 2. App And Presentation

- [ ] Remove or hide only newly defective sitemap entries, dashboards, charts,
      views, forms, or web resources from the app.
- [ ] Restore the prior known-good app module/version through the approved pipeline.
- [ ] Publish only affected app/metadata scope and verify navigation.
- [ ] Do not remove access to records required for statutory work or audit.

### 3. Automation And Server Logic

- [ ] Deactivate the defective flow or plug-in step; preserve its definition and
      execution evidence.
- [ ] Reactivate the prior known-good step/flow version with its prior secure
      connection references.
- [ ] Drain or reconcile in-flight messages by idempotency key and correlation ID.
- [ ] Never replay an acknowledgment, release, export, or approval without checking
      the immutable action ledger.
- [ ] Apply compensating Clock/Audit Events for authorized corrections; never edit
      original events.

### 4. Security And SharePoint

- [ ] Restore the last approved Dataverse role/field-security/team configuration.
- [ ] Restore SharePoint permissions from the separately reviewed permission
      manifest; verify inheritance and group membership independently.
- [ ] Remove unintended access before restoring convenience access.
- [ ] Audit every permission change and test positive/negative access.
- [ ] Verify application identities still cannot approve or release.

### 5. Configuration And Connections

- [ ] Restore prior non-secret environment-variable values by approved version.
- [ ] Rebind named connection references; never embed a direct connection ID.
- [ ] Validate DLP, owner, status, and least-privilege scope.
- [ ] Keep unavailable optional adapters explicitly Disabled/Unavailable.
- [ ] Publish configuration-dependent components and run smoke tests.

### 6. Schema And Data

- [ ] Prefer additive forward correction, field hiding, or component deprecation.
- [ ] Do not delete tables, columns, relationships, choices, keys, or choice values
      containing or interpreting retained data.
- [ ] Do not reuse a published numeric choice value.
- [ ] If a bad field value was written, identify affected rows and use an approved,
      idempotent compensating script with before/after evidence and dry-run output.
- [ ] If a released package is wrong, create a controlled correction package
      version; preserve the released original.
- [ ] If report facts are wrong, create a new report-definition/run version linked
      to the prior certified run; never replace prior evidence.
- [ ] A point-in-time environment restore requires incident-specific approval and
      reconciliation of all immutable events/actions after the recovery point.

## Package Strategy

- [ ] Verify prior package SHA-256 and source commit/tag against the approved
      deployment manifest.
- [ ] For managed release rollback, use only the approved release pipeline and a
      supported upgrade/update strategy validated for the solution topology.
- [ ] Do not import an unmanaged development package into production as rollback.
- [ ] Do not import the framework-acceptance package.
- [ ] Analyze dependency and data-loss impact before any delete-and-import action.
- [ ] Block package action if final membership, security, or preservation checks fail.

## Post-Rollback Validation

- [ ] Component inventory matches the intended known-good scope.
- [ ] Required components are present in `FederalFOIAManagement`; missing/failed
      membership is zero.
- [ ] Scoped publish completed and post-publish metadata is readable.
- [ ] Review app opens on FOIA Request / Active FOIA Requests.
- [ ] Synthetic intake-to-closure and appeal smoke journeys pass.
- [ ] Tracking uniqueness and request-to-multiple-Case relationship pass.
- [ ] Clock replay reaches the projected due date; immutable-event mutation fails.
- [ ] Self-approval, automation approval, unauthorized release, and secured-field
      export attempts fail.
- [ ] Dataverse and SharePoint positive/negative access tests pass independently.
- [ ] Released package hashes/versions and certified report runs are unchanged.
- [ ] Core suite passes with all optional Azure flags false.
- [ ] No production data, credentials, or sensitive evidence entered source control.

## Reconciliation

- [ ] Compare pre/post counts and high-water marks for all operational and immutable
      tables; explain every difference.
- [ ] Reconcile in-flight acknowledgments, notifications, searches, reviews,
      approvals, exports, packages, and releases by idempotency/correlation ID.
- [ ] Reconcile SharePoint item versions/hashes and permissions to Dataverse
      references without exposing document content.
- [ ] Re-run affected annual/quarterly calculations as a new uncertified comparison
      run; retain both outputs.
- [ ] Record unresolved items, owner, severity, safe workaround, and due date.

## Closeout

- [ ] Update the instantiated deployment manifest with rollback approvals, actions,
      evidence IDs, package hashes, publish results, and final status.
- [ ] Record created/updated/skipped/failed counts by component category.
- [ ] Link the incident, root-cause analysis, corrective backlog, and prevention test.
- [ ] Obtain FOIA Product Owner, Release Manager, Security Officer, Records Officer,
      and Test Lead sign-off as applicable.
- [ ] Re-enable contained features only through a new approved deployment gate.
- [ ] Retain rollback evidence under its approved class and legal holds.

## Stop Conditions

Stop and escalate when authorization is absent, scope is ambiguous, the known-good
artifact/hash cannot be verified, a required backup is unavailable, legal hold or
retention impact is unclear, immutable evidence would be lost, SharePoint access
cannot be independently verified, or the rollback would require a secret to be
placed in source-controlled material.
