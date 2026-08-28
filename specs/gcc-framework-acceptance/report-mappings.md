# Report Mappings

## Approved Report Decision

- Reports enabled: yes, as native model-driven dashboard/view/chart components
- Optional HTML report web resources: no
- Critical tables: `ppvs_checkoutrequest`, `ppvs_labasset`

| Table | Surface | Type | Placement | Required fields | Decision supported | Owner | Validation checklist |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `ppvs_checkoutrequest` | Active Checkout Requests | View (`adopt-generated-active`) | Review app entry point and dashboard drill-through | `ppvs_requestnumber`, `ppvs_labassetid`, `ppvs_lifecyclestage`, `ppvs_expectedreturndate` | Which requests require action? | Lab operations owner | Generated Active/default identity and scenario table ownership resolve; active rows display; record drill-through works |
| `ppvs_checkoutrequest` | Requests by Lifecycle Stage | Chart | Lab Equipment Lifecycle and Availability dashboard | `ppvs_lifecyclestage`, `ppvs_requestnumber` | Where are requests in the lifecycle? | Lab operations owner | Counts reconcile to the active view; stage labels are readable |
| `ppvs_labasset` | Available Lab Assets | View (`create-custom`) | Review app and dashboard drill-through | `ppvs_assettag`, `ppvs_category`, `ppvs_availabilitystatus` | Which assets can be issued? | Lab operations owner | Available filter works; asset drill-through opens the main form |
| `ppvs_labasset` | Assets by Availability | Chart | Lab Equipment Lifecycle and Availability dashboard | `ppvs_availabilitystatus`, `ppvs_assettag` | How many assets are available or issued? | Lab operations owner | Counts reconcile to the asset view; availability labels are readable |

## Dashboard

- Display name: Lab Equipment Lifecycle and Availability
- Purpose: Give lab supervisors one surface for active-request lifecycle and asset availability.
- Membership: Proposed for `LabEquipmentCheckoutAcceptance20260826`; historically observed absent/uncreated and not rechecked during revised preview.
- Authoring boundary: Use supported maker/solution tooling. Do not fabricate unsupported dashboard or chart payloads.
