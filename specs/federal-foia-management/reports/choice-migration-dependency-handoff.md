<!--
Component: Federal FOIA Choice Migration Dependency Handoff
Purpose: Define the exact removal and restoration boundary for live dependencies that block same-name Choice column reconstruction.
Owner: Federal FOIA Management scenario
Version: 0.1.0
Status: Operator handoff; not authorization to mutate Dataverse
-->

# Choice Migration Dependency Handoff

This handoff covers the live dependencies reported by stage 35 before the 29
categorical String columns can be recreated as Choice columns. It does not
authorize dependency removal, column deletion, or stage 36 Apply.

## Resolved Scope

- Environment: `https://usfedfoia.crm9.dynamics.com`
- Solution: `FederalFOIAManagement`
- Blocking references: 60
- Unique components: 37
- Saved views: 16 references across 13 components
- Business process flows: 4 references across 2 components
- Charts: 7 references across 7 components
- System forms: 33 references across 15 components
- BPF backing forms: 2 of the 15 system forms

The two `Information` forms are generated backing forms for the two BPFs. Treat
each BPF and its backing form as one designer-owned boundary. Do not edit or
delete either backing form independently.

## Supported Removal And Restoration

| Component type | Removal method | Restoration method |
|---|---|---|
| Saved views | Use a reviewed migration-safe stage 60 payload/definition that removes only the listed columns from FetchXML and layout XML, then publish. | Restore the approved scenario view payload and rerun stage 60, then verify the original component IDs and columns. |
| Forms | Use a reviewed migration-safe stage 60 payload/definition that removes only the listed controls, cells, and sections made empty by that removal, then publish. | Restore the approved scenario form payload and rerun stage 60, then verify the original component IDs, labels, order, and controls. |
| Charts | Use a reviewed migration-safe stage 64 definition that removes or temporarily replaces the listed category/series field, then publish. | Restore the approved reporting payload and rerun stage 64, then verify the original component IDs and rendering. |
| BPFs and BPF backing forms | Deactivate the BPF if required, remove the listed data steps in the Power Apps BPF designer, validate, activate, and publish. Do not directly rewrite workflow XAML or the backing `Information` form. | Re-add the data steps in the Power Apps BPF designer after Choice creation, validate, activate, publish, and rerun stage 55 verification. |

Do not delete a view, form, chart, BPF, or BPF backing form to clear a
dependency. The migration must preserve each component ID.

## Saved Views

| View | Table | Object ID | Impacted fields |
|---|---|---|---|
| FOIA Requesters | `contact` | `a1d4e0dd-61c6-f111-aaae-001dd80bb94c` | `contact.foia_requesterclassification` |
| Active AI Assistance Records | `foia_aiassistancerecord` | `3f6d7a12-fd09-403d-9a27-28487a2afdb7` | `foia_aiassistancerecord.foia_operationalstatus` |
| Active Appeals | `foia_appeal` | `6f678b18-2400-49d0-b437-5baa5fd4d8d2` | `foia_appeal.foia_stage` |
| Active Audit Events | `foia_auditevent` | `662a7644-4168-4c2d-b7f4-6dc9f8c9170f` | `foia_auditevent.foia_eventtype` |
| Active Clock Events | `foia_clockevent` | `4facefe8-84dd-4597-897f-e5c4a104ddbb` | `foia_clockevent.foia_clocktype`; `foia_clockevent.foia_eventtype` |
| Active Exemption Decisions | `foia_exemptiondecision` | `a982275c-26aa-46d3-b394-6cef51b4b61a` | `foia_exemptiondecision.foia_approvalstate` |
| Active FOIA Requests | `foia_foiarequest` | `3e922e74-957e-43c3-8595-683ce84d643d` | `foia_foiarequest.foia_lifecyclestage` |
| Active Redaction Decisions | `foia_redactiondecision` | `d4c06148-5167-4f97-b6ea-d943cff420ce` | `foia_redactiondecision.foia_finalstate` |
| Active Release Packages | `foia_releasepackage` | `b6347d45-740b-4764-9ccc-fed6e6ec014a` | `foia_releasepackage.foia_approvalstate` |
| Active Responsive Records | `foia_responsiverecord` | `016cd4f6-9aa7-4b36-b526-feef5b71a896` | `foia_responsiverecord.foia_classification`; `foia_responsiverecord.foia_reviewstate` |
| Active Review Tasks | `foia_reviewtask` | `0d7864b2-cc6c-4c8a-9aa1-09a57a11b6b2` | `foia_reviewtask.foia_reviewtype`; `foia_reviewtask.foia_status` |
| Active Search Tasks | `foia_searchtask` | `c9803fe4-54e9-4a31-822e-a024b9983f1b` | `foia_searchtask.foia_status` |
| Active FOIA Case Work | `incident` | `fc5e5e9a-62c6-f111-aaae-001dd80753e2` | `incident.foia_caseworktype` |

## Business Process Flows

| BPF | Object ID | Impacted fields |
|---|---|---|
| Federal FOIA Appeal Lifecycle | `96729c94-56c6-f111-aaae-001dd80753e2` | `foia_appeal.foia_outcome` |
| Federal FOIA Request Lifecycle | `33123dd4-53c6-f111-aaae-001dd80bb94c` | `foia_foiarequest.foia_disposition`; `foia_foiarequest.foia_intakechannel`; `foia_foiarequest.foia_validationstate` |

## Charts

| Chart | Table | Object ID | Impacted fields |
|---|---|---|---|
| Appeals by Outcome | `foia_appeal` | `a1c61a95-6ec6-f111-aaae-001dd80753e2` | `foia_appeal.foia_outcome` |
| Clock Events by Type | `foia_clockevent` | `ebdcc7ab-6ec6-f111-aaae-001dd80bb94c` | `foia_clockevent.foia_eventtype` |
| Approved Exemptions by Authority | `foia_exemptiondecision` | `422dca9d-6ec6-f111-aaae-001dd80816e7` | `foia_exemptiondecision.foia_approvalstate` |
| Active Requests by Lifecycle Stage | `foia_foiarequest` | `fd5bd876-6ec6-f111-aaae-001dd80bb94c` | `foia_foiarequest.foia_lifecyclestage` |
| Expedited Requests by Decision | `foia_foiarequest` | `e220bb81-6ec6-f111-aaae-001dd80753e2` | `foia_foiarequest.foia_expediteddecision` |
| Release Packages by Approval State | `foia_releasepackage` | `97a1e1bd-6ec6-f111-aaae-001dd80753e2` | `foia_releasepackage.foia_approvalstate` |
| Open Reviews by Type | `foia_reviewtask` | `178499b5-6ec6-f111-aaae-001dd80753e2` | `foia_reviewtask.foia_reviewtype` |

## Forms

| Form | Table or process backing table | Object ID | Impacted fields |
|---|---|---|---|
| Starter Main Form | `contact` | `40657ef3-62c6-f111-aaae-001dd80753e2` | `contact.foia_requesterclassification` |
| Starter Main Form | `foia_aiassistancerecord` | `2a2ffa01-63c6-f111-aaae-001dd80753e2` | `foia_aiassistancerecord.foia_operationalstatus`; `foia_aiassistancerecord.foia_operationclassification`; `foia_aiassistancerecord.foia_reviewerdisposition` |
| FOIA Appeal Main | `foia_appeal` | `18ec340b-63c6-f111-aaae-001dd80753e2` | `foia_appeal.foia_outcome`; `foia_appeal.foia_stage` |
| Starter Main Form | `foia_auditevent` | `d95dc51a-63c6-f111-aaae-001dd80753e2` | `foia_auditevent.foia_eventtype` |
| Starter Main Form | `foia_clockevent` | `c2ea372e-63c6-f111-aaae-001dd80753e2` | `foia_clockevent.foia_clocktype`; `foia_clockevent.foia_eventtype` |
| Starter Main Form | `foia_exemptiondecision` | `2366d437-63c6-f111-aaae-001dd80753e2` | `foia_exemptiondecision.foia_approvalstate` |
| Information (BPF backing form; do not edit directly) | `foia_federal_foia_appeal_lifecycle` | `87681368-0d62-40cf-816e-44edbcb9c802` | `foia_appeal.foia_outcome` |
| Information (BPF backing form; do not edit directly) | `foia_federal_foia_request_lifecycle` | `ec028c26-be50-4819-b7a1-b1c398f006aa` | `foia_foiarequest.foia_disposition`; `foia_foiarequest.foia_intakechannel`; `foia_foiarequest.foia_validationstate` |
| FOIA Request Main | `foia_foiarequest` | `7f4a2b4a-63c6-f111-aaae-001dd80753e2` | `foia_foiarequest.foia_disposition`; `foia_foiarequest.foia_expediteddecision`; `foia_foiarequest.foia_feecategory`; `foia_foiarequest.foia_intakechannel`; `foia_foiarequest.foia_lifecyclestage`; `foia_foiarequest.foia_validationstate` |
| Starter Main Form | `foia_redactiondecision` | `26c0f760-63c6-f111-aaae-001dd80bb94c` | `foia_redactiondecision.foia_finalstate` |
| Starter Main Form | `foia_releasepackage` | `e5897874-63c6-f111-aaae-001dd80bb94c` | `foia_releasepackage.foia_approvalstate`; `foia_releasepackage.foia_releasemethod` |
| Starter Main Form | `foia_responsiverecord` | `76546381-63c6-f111-aaae-001dd80816e7` | `foia_responsiverecord.foia_accessstate`; `foia_responsiverecord.foia_classification`; `foia_responsiverecord.foia_repository`; `foia_responsiverecord.foia_reviewstate` |
| Starter Main Form | `foia_reviewtask` | `09e6828f-63c6-f111-aaae-001dd80bb94c` | `foia_reviewtask.foia_disposition`; `foia_reviewtask.foia_reviewtype`; `foia_reviewtask.foia_status` |
| Starter Main Form | `foia_searchtask` | `edbdd59e-63c6-f111-aaae-001dd80753e2` | `foia_searchtask.foia_collectionsourcesystem`; `foia_searchtask.foia_status` |
| Starter Main Form | `incident` | `af4ab8af-63c6-f111-aaae-001dd80753e2` | `incident.foia_caseworktype` |

## Operator Sequence

1. Run a fresh stage 35 Preview and confirm the evidence still resolves to
   exactly 60 references and the 37 component IDs in this handoff.
2. Run stage 95 for a fresh unmanaged backup and local unpack inspection.
3. Generate and review migration-safe stage 60 and stage 64 definitions. They
   must target only the component IDs and fields listed here.
4. Apply the temporary view, form, and chart definitions; publish the scoped
   components.
5. Update both BPFs in the Power Apps designer. Remove only the listed data
   steps, validate, activate, and publish.
6. Rerun stage 35 Preview. Stop unless dependency count is exactly zero and
   synthetic ownership and value mappings still pass.
7. Run stage 36 Snapshot. Review the snapshot identity and 97 mapped values.
8. Obtain explicit destructive approval with an authorization reference.
9. Run stage 36 Apply and Verify.
10. Restore the approved stage 60 and stage 64 definitions, restore the BPF
    data steps in the designer, publish, and verify all 37 original component
    IDs.
11. Rerun strict solution membership, stage 85, stage 95, metadata validation,
    and the authenticated app rehearsal.

## Stop Conditions

Stop before live mutation if any of these conditions occur:

- A component ID differs from this handoff.
- Stage 35 reports a component outside this list or a count other than 60.
- A populated value is foreign, unmapped, or lacks the approved synthetic
  source tag.
- A removal action would delete and recreate a dependent component.
- Either BPF cannot be validated, activated, or published after its temporary
  designer change.
- Stage 35 reports any dependency immediately before stage 36 Snapshot or
  Apply.
- The fresh unmanaged backup, snapshot, or destructive authorization reference
  is missing.
