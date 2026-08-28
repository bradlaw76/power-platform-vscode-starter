# Exact Mutation Inventory

Every item below is planned and unauthorized. No mutation has run.

| Order | Category | Exact identity | Intended action | Cleanup policy |
| ---: | --- | --- | --- | --- |
| 1 | Publisher | `PowerPlatformVSCodeStarter` / prefix `ppvs` | Create once if absent | Permanent; never delete |
| 2 | Solution | `LabEquipmentCheckoutAcceptance20260826` | Create unmanaged under permanent publisher | Retain after verification |
| 3 | Table | `ppvs_labasset` | Create | Retain after verification |
| 4 | Table | `ppvs_checkoutrequest` | Create | Retain after verification |
| 5 | Columns | 5 on `ppvs_labasset` | Create primary name plus four payload columns | Retain after verification |
| 6 | Columns | 10 on `ppvs_checkoutrequest` | Create primary name, eight payload columns, and relationship lookup | Retain after verification |
| 7 | Relationship | `ppvs_labasset_ppvs_checkoutrequest` | Create required N:1 with Restrict delete | Retain after verification |
| 8 | Forms | Lab Asset Main; Checkout Request Main | Create or update wizard-managed main forms | Retain after verification |
| 9 | Views | Available Lab Assets; Active Checkout Requests | Create Available Lab Assets; adopt only the verified generated Active/default Checkout Requests view | Retain after verification |
| 10 | BPF | `ppvs_lab_equipment_checkout_lifecycle` | Author initial definition in Power Apps designer; later validate/link | Retain after verification |
| 11 | Charts | Requests by Lifecycle Stage; Assets by Availability | Create through supported maker/solution tooling | Retain after verification |
| 12 | Dashboard | Lab Equipment Lifecycle and Availability | Create through supported maker/solution tooling | Retain after verification |
| 13 | App | `ppvs_lab_equipment_checkout_acceptance_20260826` | Create or update | Retain after verification |
| 14 | Sitemap | `ppvs_lab_equipment_checkout_acceptance_20260826_sitemap` | Create or update | Retain after verification |
| 15 | Solution membership | All 28 proposed component rows | Add and verify | Not a cleanup operation |
| 16 | Synthetic data | 3 assets and 5 requests | Deterministic upsert with approved source tag | No cleanup authorized |
| 17 | Publish | Targeted customizations and app | Publish after approved metadata phases | Not applicable |

The permanent publisher is outside every current and future acceptance cleanup scope. Any later cleanup authorization may target only explicitly listed acceptance-owned components or records and never implies publisher deletion.
