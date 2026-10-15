# FAST-003A GCC Environment Validation

**Validation date:** 2026-10-15
**Result:** Action required
**Mutation authority:** None

## Confirmed target

| Field | Evidence |
| --- | --- |
| Environment | Brad's - Power Platform VS Code Starter - GCC |
| Environment URL | `https://powerplatformvscodestarter.crm9.dynamics.com` |
| Cloud | Microsoft Government Community Cloud (GCC) |
| PAC cloud classification | `UsGov` |
| Authentication authority | `https://login.microsoftonline.com/<tenant>/` |
| Dataverse API root | `https://powerplatformvscodestarter.crm9.dynamics.com/api/data/v9.2/` |
| Organization version | `9.2.26091.167` |

The operator selected this environment explicitly from multiple authenticated
GCC profiles. It was not inferred from the active profile. The PAC
classification and `crm9.dynamics.com` endpoint identify GCC, not GCC High or
DoD. Tenant, user, object, and token identifiers are intentionally excluded.

## Authentication and permissions

The PAC profile was valid for GCC discovery. The first Dataverse attempt used
the generic `pac auth token` output and failed closed at `WhoAmI` with HTTP 401;
it read no environment metadata. The successful run followed the repository
convention and requested an Azure CLI token scoped to the exact Dataverse
environment URL.

The final run verified these read capabilities:

- environment identity and organization version;
- installed solution and publisher metadata;
- table metadata;
- forms, web resources, custom controls, setting definitions, attributes, and
  global Choice metadata.

No final-run authentication, permission, or API error remained.

## Catalog and package evidence

Catalog snapshot:
`sha256:777873ba1d2beedcb9fb5de2fe85d17c0f5bb20c6fafe5ce674d0de654be8348`

The live snapshot contains 32 catalog items, including 21 modules, 6 use cases,
and 3 personas. Its normalized release inventory contains one current release
record, so compatibility conclusions use the separately verified package
indexes rather than treating this snapshot as complete release-history proof.

| Module | Selected version | Package SHA-256 |
| --- | --- | --- |
| Core | `1.2.1.0` | `f813e8500b97db1fd74f938da28f22ba53c1c4593f6374b34e8a0f7d52e895b3` |
| Investigations | `1.2.1.0` | `131be1ade134e838e3d824777b6655331a7149eaf80ae14bc26583a4f1bb8391` |
| Training and Certification | `1.2.1.0` | `ee636bf278d1cb486ee4f2a22dbed6cd8fa7f3336b1bf336d3c8e0ca2f1a81d9` |

Core `1.2.1.0` is test evidence, not a permanent version requirement.

## Readiness result

| Check | Result |
| --- | --- |
| Readiness | `action-required` |
| Core assessment | `missing-prerequisites-potentially-available` |
| Installed FAST modules | 0 |
| Installed Core | No |
| Installed specialty modules | None detected |
| Satisfied dependencies | 8 |
| Missing dependencies | 184 |
| Unverified dependencies | 4 |
| Missing selected solutions | 3 |
| Incompatible components | 0 |
| Final inspection errors | 0 |

The four unverified dependencies are Training and Certification `Credential`
`Name` attributes whose parent table cannot be resolved uniquely from the
selected package metadata. They remain unverified rather than being treated as
present or absent.

Because `appbase_core` is not installed, this environment is not ready for
FAST-dependent generation. No installation was attempted.

## Execution and cache evidence

| Run | Cache | Dataverse requests | Duration |
| --- | --- | ---: | ---: |
| Corrected forced refresh | Miss/bypassed | 22 | 8,478 ms |
| Immediate cache reuse | Hit | 0 new requests | 754 ms |
| Forced refresh after cache | Bypassed | 22 | 7,836 ms |

The final acceptance sequence took 17,068 ms in total.

The cached report retains the original evidence request count of 22 and the
same metadata fingerprint:
`7654dbb8de75ccc321fa1959a1546a85016f63a8f3bfca3897c5c055e566ea64`.

Forced refresh bypassed the cache and reproduced the same environment
classification and metadata fingerprint.

## Live corrections

FAST-003A exposed and corrected three evidence-quality defects:

1. `GlobalOptionSetDefinitions` does not support `$filter`; the inspector now
   performs one unfiltered metadata request and matches required Choices
   locally.
2. A 404 for a dependency parent table is now explicit missing evidence rather
   than a permission or unsupported-metadata error.
3. Dependency identities now include component type, ID, parent identity, and
   package scope so repeated display names cannot overwrite one another.

Mocked regression coverage now protects each correction.

## Safety confirmation

- Every Dataverse request used HTTP GET.
- No solution was imported or installed.
- No rows, configuration, metadata, or environment settings were changed.
- No customizations were published.
- No production environment was selected.
- No token or credential was written to Git or the report.
- FAST remains disabled in the normal wizard.
- The feature branch remains separate from `main`.

This validation demonstrates read-only metadata compatibility only. It does not
establish that FAST is supported in GCC or guarantee that any future import
would succeed.
