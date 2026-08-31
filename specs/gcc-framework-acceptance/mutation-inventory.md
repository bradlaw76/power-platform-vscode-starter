# Exact Mutation Inventory

Publisher, solution, and schema rows are completed historical mutations with reconstructed provenance. Remaining metadata, data, publishing, and export operations are planned and unauthorized.

| Order | Category | Exact identity | Intended action | Cleanup policy |
| ---: | --- | --- | --- | --- |
| 1 | Publisher | `PowerPlatformVSCodeStarter` / prefix `ppvs` | Existing and verified | Permanent; never delete |
| 2 | Solution | `LabEquipmentCheckoutAcceptance20260826` | Existing unmanaged solution; verified | Retain after verification |
| 3 | Table | `ppvs_labasset` | Created; provenance reconstructed | Retain after verification |
| 4 | Table | `ppvs_checkoutrequest` | Created; provenance reconstructed | Retain after verification |
| 5 | Columns | 5 on `ppvs_labasset` | Created; provenance reconstructed | Retain after verification |
| 6 | Columns | 10 on `ppvs_checkoutrequest` | Created; provenance reconstructed | Retain after verification |
| 7 | Relationship | `ppvs_labasset_ppvs_checkoutrequest` | Created; provenance reconstructed | Retain after verification |
| 8 | Forms | `ppvs_labasset / Lab Asset Main / type=2`; `ppvs_checkoutrequest / Checkout Request Main / type=2` | Create or update only scenario-owned main forms | Retain after verification |
| 9 | Views | `ppvs_labasset / Available Lab Assets / create-custom`; `ppvs_checkoutrequest / Active Checkout Requests / adopt-generated-active` | Create the asset view; adopt only the verified generated Active/default request view | Retain after verification |
| 10 | BPF designer handoff | `ppvs_lab_equipment_checkout_lifecycle` | Generate and validate local handoff only | Not a solution component |
| 11 | Charts | `ppvs_checkoutrequest / Requests by Lifecycle Stage`; `ppvs_labasset / Assets by Availability` | Script 64 payload-driven create/update | Retain after verification |
| 12 | Dashboard | `Lab Equipment Lifecycle and Availability / systemform type=0` | Script 64 payload-driven create/update | Retain after verification |
| 13 | App | `ppvs_lab_equipment_checkout_acceptance_20260826` | Create or update | Retain after verification |
| 14 | Sitemap | `ppvs_lab_equipment_checkout_acceptance_20260826_sitemap` | Create or update | Retain after verification |
| 15 | Solution membership | All 27 required solution-component rows | Add and verify | Not a cleanup operation |
| 16 | Synthetic data | Assets `LECA-ASSET-001`..`003`; requests `LECA-20260826-001`..`005` | Script 66 deterministic upsert; exactly eight rows, all tagged `ppvs-acceptance-20260826` | No cleanup authorized |
| 17 | Publish | Tables `ppvs_labasset`, `ppvs_checkoutrequest`; exact app-module ID | Component-scoped `PublishXml` only; `PublishAllXml` prohibited | Not applicable |
| 18 | Second-pass proof | All component identities and eight natural-key records | Script 85 stable-ID and zero-duplicate verification | Local evidence only |
| 19 | Export inspection | `LabEquipmentCheckoutAcceptance20260826` unmanaged package | Script 95 export and local unpack/inspection; never import | Retain local evidence |

Every update requires one exact identity match, the scenario ownership marker where supported, exact target-solution membership, and matching contract metadata. A same-name mismatch or duplicate is a hard stop. The second run must create zero components and zero records and retain exactly one of each identity above. The permanent publisher is outside every current and future acceptance cleanup scope. Any later cleanup authorization may target only explicitly listed acceptance-owned components or records and never implies publisher deletion.
