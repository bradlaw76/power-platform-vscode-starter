# FAST Core 1.2.1.0 Package Verification

**Evidence tier:** Package verified  
**Verified:** 2026-10-15  
**Environment verification:** Not performed  
**Version policy:** This is a verified release reference, not a permanent
version requirement or upper version limit.

## Source and integrity

| Item | Value |
| --- | --- |
| Module page | [FAST Core](https://microsoft.github.io/industry-solutions/modules/core/#overview) |
| Release | [`core/v1.2.1.0`](https://github.com/microsoft/industry-apps/releases/tag/core%2Fv1.2.1.0) |
| Managed asset | [`App-Base-Core-Managed-v1.2.1.0.zip`](https://github.com/microsoft/industry-apps/releases/download/core%2Fv1.2.1.0/App-Base-Core-Managed-v1.2.1.0.zip) |
| Download result | HTTP download completed successfully |
| Size | 587,310 bytes |
| ZIP entries | 42 |
| SHA-256 | `f813e8500b97db1fd74f938da28f22ba53c1c4593f6374b34e8a0f7d52e895b3` |
| GitHub API digest | `sha256:f813e8500b97db1fd74f938da28f22ba53c1c4593f6374b34e8a0f7d52e895b3` |
| Digest comparison | Exact match |
| ZIP integrity | Passed through .NET ZIP central-directory enumeration and extraction |

The archive was inspected offline. It was not imported, executed, or deployed.
The complete machine-readable extraction is in
[`core-v1.2.1.0-package-metadata.json`](core-v1.2.1.0-package-metadata.json).

## Solution identity

| Property | Value |
| --- | --- |
| Unique name | `appbase_core` |
| Display name | `App Base - Core` |
| Version | `1.2.1.0` |
| Managed | `true` |
| Solution package version | `9.2` |
| Source organization version | `9.2.26035.200` |
| Publisher unique name | `appbase` |
| Publisher display name | `App Base` |
| Publisher description | `App Base Modules` |
| Customization prefix | `appbase` |
| Option value prefix | `14713` |

## Physical metadata summary

| Category | Count |
| --- | ---: |
| Root components | 164 |
| Table root components | 38 |
| Entity metadata definitions | 38 |
| Attributes represented in package entity metadata | 1,008 |
| Attributes marked custom | 341 |
| Relationships | 323 |
| Global option sets | 87 |
| Web resources | 36 |
| Sitemap components | 1 |
| Model-driven app modules | 1 |
| Canvas apps | 1 |
| Declared missing dependencies | 4 |

The attribute count includes system attributes represented in the solution
metadata. `account` is included as a root component but supplies no attribute
metadata in this package. `contact`, displayed as Person, includes one
represented attribute, which is marked custom.

## Tables and attributes

The full JSON evidence records every represented attribute with logical name,
physical name, type, required level, custom-field flag, and introduced version.

| Logical name | Display name | Attributes | Custom attributes |
| --- | --- | ---: | ---: |
| `account` | Account | 0 | 0 |
| `appbase_actionitem` | Action Item | 66 | 4 |
| `appbase_afteractionreport` | After Action Report | 31 | 14 |
| `appbase_agreement` | Agreement | 35 | 16 |
| `appbase_analysis` | Analysis | 28 | 11 |
| `appbase_clearancelevel` | Clearance Level | 21 | 4 |
| `appbase_competency` | Competency | 22 | 5 |
| `appbase_complianceframework` | Compliance Framework | 28 | 11 |
| `appbase_complianceframeworkcategory` | Compliance Framework Category | 21 | 4 |
| `appbase_compliancerequirement` | Compliance Requirement | 30 | 13 |
| `appbase_contenttemplate` | Content Template | 23 | 6 |
| `appbase_country` | Country | 19 | 2 |
| `appbase_credentialassignment` | Credential Assignment | 26 | 9 |
| `appbase_credentialtype` | Credential Type | 28 | 11 |
| `appbase_discussionitem` | Discussion Item | 29 | 12 |
| `appbase_document` | Document | 31 | 14 |
| `appbase_fiscalperiod` | Fiscal Period | 27 | 10 |
| `appbase_formaldecision` | Formal Decision | 29 | 12 |
| `appbase_graderank` | Grade-Rank | 24 | 7 |
| `appbase_impact` | Impact | 33 | 14 |
| `appbase_jobseries` | Job Series | 21 | 4 |
| `appbase_judicialdistrict` | Judicial District | 25 | 8 |
| `appbase_legalamendment` | Legal Amendment | 26 | 9 |
| `appbase_legalauthority` | Legal Authority | 35 | 18 |
| `appbase_legalcrossreference` | Legal Cross-Reference | 23 | 6 |
| `appbase_location` | Location | 30 | 13 |
| `appbase_organizationinitiative` | Organization Initiative | 33 | 14 |
| `appbase_organizationunit` | Organization Unit | 28 | 11 |
| `appbase_organizationunittype` | Organization Unit Type | 21 | 4 |
| `appbase_paygrade` | Pay Grade | 30 | 11 |
| `appbase_personalinformation` | Personal Information | 27 | 10 |
| `appbase_personalinformationtype` | Personal Information Type | 23 | 6 |
| `appbase_personneltype` | Personnel Type | 21 | 4 |
| `appbase_privacyconsent` | Privacy Consent | 29 | 12 |
| `appbase_product` | Product | 31 | 12 |
| `appbase_riskitem` | Risk Item | 33 | 16 |
| `appbase_stateorprovince` | State or Province | 20 | 3 |
| `contact` | Person | 1 | 1 |

## Relationships

The package contains 323 relationships. The machine-readable evidence records
the exact relationship name, type, referencing entity, referenced entity,
referencing attribute, introduced version, hierarchy flag, and cascade
behaviors for each relationship.

No relationship or attribute from this evidence may be emitted into a wizard
payload merely because it appears in the package. Reuse or extension decisions
still require selected-version planning and, before execution, authorized
environment verification.

## Root components

| Dataverse component type | Count | Interpretation |
| --- | ---: | --- |
| `1` | 38 | Entities/tables |
| `9` | 87 | Global option sets |
| `61` | 36 | Web resources |
| `62` | 1 | Sitemap |
| `80` | 1 | Model-driven app module |
| `300` | 1 | Canvas app |

All 164 exact root-component type/name/behavior entries are retained in the
machine-readable evidence.

## Declared missing dependencies

The solution manifest declares four dependencies that require target
environment resolution:

1. `Contact Quick Create`, component type `60`, from
   `msdynce_AppCommon (9.0.4.0066)` /
   `msdynce_AppCommonAnchor (9.0.26031.10002)`, required by the Core app module.
2. `msdyn_/Images/AppModule_Default_Icon.png`, component type `61`, from
   `AppModuleWebResources (2.5)`, required by the Core app module.
3. `MscrmControls.CardFeedContainer.CardFeedContainer`, component type `66`,
   from `BaseCustomControlsCore (9.0.2603.5012)`, required by the
   `Person - Core` form.
4. `AppChannel`, a Setting Definition from
   `msdyn_AppFrameworkInfraExtensions (1.0.0.16)` /
   `PowerAppsAppFramework_Anchor (1.0.0.25)`, required by the Core app setting.

These declarations prove that the managed package is available and inspectable,
not that it is compatible with every target environment. Environment
verification remains a separate approval gate.

## Current package inventory correction

Complete GitHub Releases API pagination returned:

- 70 releases containing ZIP assets;
- 22 module tag prefixes with packaged releases;
- 70 managed ZIP assets;
- 70 unmanaged ZIP assets;
- 140 ZIP assets total;
- an empty second page at `per_page=100`.

The 22 package-bearing module prefixes observed were:

`asset-management`, `core`, `court-case-management`,
`dispute-resolution`, `event-management`, `executive-coordination`,
`external-interaction`, `financial-management`, `gamification`,
`hr-administration`, `hr-benefits`, `hr-recruiting`, `investigations`,
`it-service-management`, `member-organizations`, `operational-excellence`,
`personnel-security`, `programs-and-services`, `project-tracking`,
`request-tracker`, `time-travel-expenses`, and
`training-and-certification`.

These are snapshot observations, not hardcoded catalog limits.
