# Paused Framework Acceptance Answers

Status: Paused for explicit mutation authorization after revised credential-free preview

This record preserves the completed discovery decisions for a future GCC acceptance run. It is planning evidence only. It does not authorize Dataverse access or mutation.

## Run Mode

- Mode: Framework Acceptance
- Selection: Explicit acceptance-engineering run
- Scenario: Lab Equipment Checkout
- Environment: Power Platform VS Code Starter - GCC
- Environment URL: `[APPROVED_GCC_ENVIRONMENT_URL]`
- Environment authorization: Authorized for this isolated Framework Acceptance run
- Environment lifecycle: Permanent; must not be reset or deleted
- Execution constraint: Follow preview-first and explicit-approval gates before applying changes or performing cleanup
- Solution unique name: `LabEquipmentCheckoutAcceptance20260826`
- Solution display name: Lab Equipment Checkout Acceptance — 2026-08-26
- Solution isolation: Separate from the permanent framework-validation solution
- Publisher prefix: `ppvs`
- Publisher unique name: `PowerPlatformVSCodeStarter`
- Publisher display name: Power Platform VS Code Starter
- Publisher strategy: Create once as a permanent framework publisher, then create the acceptance solution under it
- Publisher cleanup boundary: Never delete or include the permanent publisher in any cleanup scope
- Source tag: `ppvs-acceptance-20260826`
- Source tag purpose: Identify acceptance-owned synthetic records for inventory, validation, deterministic rerun testing, and any future separately approved targeted cleanup
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
- BPF acceptance boundary: Generate and validate the supported Power Apps designer handoff only; do not fabricate, activate, add, publish, or link workflow metadata
- Reporting: Lifecycle and availability report with drill-through to active requests

## Synthetic Acceptance Data

- Lab Asset records: 3
- Checkout Request records: 5
- Hero record: `LECA-20260826-001 — Full Review-to-Return Journey`
- Hero record purpose: Demonstrate the complete Review-to-Return lifecycle
- Coverage: Request lifecycle states, asset availability states, and related-record behavior
- Privacy: Synthetic data only; no personal, customer, or production data
- Rerun behavior: Deterministic and idempotent using source tag `ppvs-acceptance-20260826`
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

All Framework Acceptance intake values are resolved. Local preview and GET-only schema provenance reconstruction are complete. The consolidated remaining build and export require explicit authorization; retention changes and cleanup remain outside this record.