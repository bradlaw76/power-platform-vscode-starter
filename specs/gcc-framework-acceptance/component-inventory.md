# Proposed Component Inventory And Membership

## Identity

- Solution unique name: `LabEquipmentCheckoutAcceptance20260826`
- Solution display name: Lab Equipment Checkout Acceptance — 2026-08-26
- Publisher unique name: `PowerPlatformVSCodeStarter`
- Publisher prefix: `ppvs`
- Membership state: absent/uncreated based on the stopped prior GET-only observation; not rechecked during revised preview

The publisher is a permanent prerequisite, not a solution component and never a cleanup target. The unmanaged solution is created under that publisher before component creation.

## Complete Proposed Inventory

| Category | Component | Unique/logical identity | Planned membership |
| --- | --- | --- | --- |
| Table | Lab Asset | `ppvs_labasset` | Required |
| Table | Checkout Request | `ppvs_checkoutrequest` | Required |
| Column | Lab Asset primary name | `ppvs_labasset.ppvs_name` | Required with table |
| Column | Asset Tag | `ppvs_labasset.ppvs_assettag` | Required |
| Column | Category | `ppvs_labasset.ppvs_category` | Required |
| Column | Availability Status | `ppvs_labasset.ppvs_availabilitystatus` | Required |
| Column | Acceptance Source Tag | `ppvs_labasset.ppvs_acceptancesourcetag` | Required |
| Column | Checkout Request primary name | `ppvs_checkoutrequest.ppvs_name` | Required with table |
| Column | Request Number | `ppvs_checkoutrequest.ppvs_requestnumber` | Required |
| Column | Requester Name | `ppvs_checkoutrequest.ppvs_requestername` | Required |
| Column | Requested On | `ppvs_checkoutrequest.ppvs_requestedon` | Required |
| Column | Expected Return Date | `ppvs_checkoutrequest.ppvs_expectedreturndate` | Required |
| Column | Actual Return Date | `ppvs_checkoutrequest.ppvs_actualreturndate` | Required |
| Column | Lifecycle Stage | `ppvs_checkoutrequest.ppvs_lifecyclestage` | Required |
| Column | Approval Decision | `ppvs_checkoutrequest.ppvs_approvaldecision` | Required |
| Column | Acceptance Source Tag | `ppvs_checkoutrequest.ppvs_acceptancesourcetag` | Required |
| Lookup column | Lab Asset | `ppvs_checkoutrequest.ppvs_labassetid` | Required with relationship |
| Relationship | Lab Asset to Checkout Request | `ppvs_labasset_ppvs_checkoutrequest` | Required |
| Main form | Lab Asset Main | `ppvs_labasset\|main` | Required |
| Main form | Checkout Request Main | `ppvs_checkoutrequest\|main` | Required |
| View | Available Lab Assets | `ppvs_labasset\|active` | Required; `create-custom` |
| View | Active Checkout Requests | `ppvs_checkoutrequest\|active` | Required; app landing view; `adopt-generated-active` |
| BPF | Lab Equipment Checkout Lifecycle | `ppvs_lab_equipment_checkout_lifecycle` | Required after designer authoring |
| Chart | Requests by Lifecycle Stage | proposed maker-authored chart | Required |
| Chart | Assets by Availability | proposed maker-authored chart | Required |
| Dashboard | Lab Equipment Lifecycle and Availability | proposed maker-authored dashboard | Required |
| Model-driven app | Lab Equipment Checkout Acceptance — 2026-08-26 | `ppvs_lab_equipment_checkout_acceptance_20260826` | Required |
| Sitemap | Review app sitemap | `ppvs_lab_equipment_checkout_acceptance_20260826_sitemap` | Required with app |

## Membership Gate

- Every listed component must be added to `LabEquipmentCheckoutAcceptance20260826`.
- The inventory/sync step must report Added, Already in solution, Failed with reason, or Missing after sync for each component.
- Export is prohibited until every required component is confirmed present.
- Existing Contoso components are excluded and must remain unchanged.
- No component currently has target-solution membership because the publisher and solution are uncreated.
- The absence statement is historical; the revised preview made no Dataverse request.
