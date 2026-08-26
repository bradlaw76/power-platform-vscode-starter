# Paused Framework Acceptance Answers

Status: Paused before authentication, preview, apply, export, or cleanup

This record preserves the completed discovery decisions for a future GCC acceptance run. It is planning evidence only. It does not authorize Dataverse access or mutation.

## Run Mode

- Mode: Framework Acceptance
- Selection: Explicit acceptance-engineering run
- Scenario: Lab Equipment Checkout
- Environment: Unresolved; must be explicitly confirmed before authentication
- Environment authorization: Unresolved; no disposable-environment assertion has been made
- Solution unique name: Unresolved; use a timestamped acceptance-only name after approval
- Publisher prefix: Unresolved
- Source tag: Unresolved; use a run-specific synthetic-data tag after approval
- Retention: Retain acceptance artifacts after verification
- Cleanup: Never run automatically; requires separate explicit approval

## Architecture

- Table strategy: Custom tables only
- Primary entry point: Checkout Request
- Default landing view: Active Checkout Requests
- Review app: Create or update an acceptance-only model-driven review app
- Review app contents: Lab Asset and Checkout Request tables, their forms and views, the lifecycle process, and the approved report surface
- Primary persona: Lab coordinator
- Primary journey: Review a checkout request, approve it, issue the asset, and record its return

## Data Model

- Lab Asset: Custom table representing equipment available for checkout
- Checkout Request: Custom table representing a request and its lifecycle
- Relationship: Lab Asset 1:N Checkout Request
- Relationship requiredness: Required from Checkout Request to Lab Asset
- Delete behavior: Restrict deletion of a Lab Asset while related Checkout Requests exist
- Relationship purpose: Preserve request history and support asset availability and active-request drill-through

## Experience

- Entry form: Checkout Request main form
- Entry view: Active Checkout Requests
- Navigation: Checkout Request is the first workflow entry; Lab Asset remains reachable in the review app
- Business process flow: Enabled with stages Review, Approve, Issue, Return
- BPF creation: Use the supported Power Apps designer handoff for the initial definition; automation may validate, activate, add, publish, and link the existing process only
- Reporting: Lifecycle and availability report with drill-through to active requests

## Synthetic Acceptance Data

- Lab Asset records: 3
- Checkout Request records: 5
- Hero record: One request demonstrating the full Review-to-Return journey; exact label unresolved
- Coverage: Request lifecycle states, asset availability states, and related-record behavior
- Privacy: Synthetic data only; no personal, customer, or production data
- Rerun behavior: Deterministic and idempotent using the unresolved run-specific source tag
- Existing standard tables: Do not seed implicitly

## Acceptance Checks

- The review app opens at Checkout Request using Active Checkout Requests.
- Both custom tables are available in app navigation.
- The required Lab Asset relationship is enforced on Checkout Request.
- Restrict-delete behavior protects assets with related requests.
- Lifecycle changes are represented across Review, Approve, Issue, and Return.
- Asset availability reflects active and completed checkout activity.
- The lifecycle and availability report drills through to active requests.
- Rerunning the approved acceptance flow does not create uncontrolled duplicates.
- Existing isolated Contoso test components remain unchanged.

## Resume Gate

Before resuming, explicitly select Framework Acceptance mode and resolve all unresolved values above. Then review generated `spec.md`, `plan.md`, `tasks.md`, payloads, and the acceptance execution plan. Authentication, Dataverse preview, apply, export, retention changes, and cleanup each remain outside this paused record and require the approvals defined by the framework.