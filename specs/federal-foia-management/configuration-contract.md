# Federal FOIA Management Configuration Contract

**Contract ID:** `FOIA-CONFIG-1.0`
**Classification:** Non-secret design metadata
**Authorization status:** No environment resolution or connection is authorized

## Contract Rules

1. Source-controlled values are logical names, types, defaults, validation rules,
   and synthetic examples only.
2. Environment-specific values are resolved during an explicitly authorized
   deployment and recorded by hash or non-sensitive identifier in an instantiated
   manifest.
3. A missing required value is a hard stop. A missing optional value disables its
   feature and must not silently select another tenant, endpoint, or connection.
4. Feature flags are Boolean, default false unless explicitly marked core.
5. Every optional Azure flag defaults false. The solution must pass its full core
   test suite with all Azure flags false and with no Azure endpoints or connections.
6. Government-cloud endpoints are selected from platform metadata or approved
   environment configuration, never inferred by changing a public-cloud suffix.

## Dataverse Environment Variable Definitions

Use solution environment-variable definitions with schema names below. Current
values are never committed.

### Core Non-Secret Variables

| Schema name | Type | Default | Required before apply | Validation and use |
| --- | --- | --- | --- | --- |
| `foia_EnvironmentClassification` | Text choice | none | Yes | One of `FEDCIV_GCC`, `FEDCIV_GCCH`, `DOD_IL5`; controls compatibility validation, not access |
| `foia_DeploymentRing` | Text choice | `DEV` | Yes | `DEV`, `TEST`, `UAT`, `PROD`; production requires separate release approval |
| `foia_DefaultTimeZoneId` | Text | none | Yes | Approved Windows/Dataverse time-zone ID |
| `foia_DefaultCalendarVersion` | Text | none | Yes | Resolves one approved immutable calendar configuration |
| `foia_TrackingNumberPattern` | Text | `FOIA-{FY}-{SEQ:000000}` | Yes | Token allowlist only; server allocator validates uniqueness |
| `foia_ProgramOfficeCode` | Text | none | Yes | Approved non-secret office code used in routing/identifiers |
| `foia_MaxAttachmentBytes` | Decimal | none | Yes | Positive value within platform and agency limit |
| `foia_AllowedAttachmentExtensions` | JSON text | none | Yes | Lowercase explicit allowlist; no executable/script types |
| `foia_AllowedAttachmentMediaTypes` | JSON text | none | Yes | Must correspond to the approved extension allowlist |
| `foia_MalwareScanRequired` | Boolean | `true` | Yes | Cannot be false outside an approved synthetic local test profile |
| `foia_SharePointSiteKey` | Text | none | When documents enabled | Environment-neutral lookup key, not a URL |
| `foia_SharePointLibraryKey` | Text | none | When documents enabled | Environment-neutral approved library key |
| `foia_DocumentLocationPattern` | Text | `requests/{trackingNumber}` | Yes | Token allowlist; path traversal and personal data forbidden |
| `foia_AcknowledgmentTemplateKey` | Text | none | Yes | Resolves approved government-cloud template |
| `foia_ClarificationTemplateKey` | Text | none | Yes | Resolves approved template |
| `foia_FinalResponseTemplateKey` | Text | none | Yes | Resolves approved template |
| `foia_ReportDefinitionAnnualVersion` | Text | `FOIA-ANNUAL-1.0.0` | Yes | Must match `report-definitions.md` |
| `foia_ReportDefinitionQuarterlyVersion` | Text | `FOIA-QUARTERLY-1.0.0` | Yes | Must match `report-definitions.md` |
| `foia_ReportTimeZoneId` | Text | none | Yes | Used to convert instants before date-boundary evaluation |
| `foia_RecordsScheduleMappingVersion` | Text | none | Yes for release | Approved mapping for every `FOIA-RC-*` class |
| `foia_EvidenceRepositoryKey` | Text | none | Yes for test/release | Approved location key; never a credential-bearing URL |
| `foia_OperationalAlertRecipientKey` | Text | none | Yes for release | Resolves approved group, not a personal address in source |
| `foia_MaxRetryAttempts` | Integer | `5` | Yes | Range 1-8; bounded retries |
| `foia_RetryBaseDelaySeconds` | Integer | `2` | Yes | Range 1-30; honor valid server retry guidance |
| `foia_RetryMaximumDelaySeconds` | Integer | `120` | Yes | Range 10-300 |
| `foia_SharingMaximumDays` | Integer | `30` | Yes | Range 1-90; shorter policy may override |

JSON text values must be parsed and schema validated during preflight. Configuration
changes create an Audit Event with definition name, old/new value hashes, actor,
purpose, approval, and correlation ID; secrets are never hashed into that event
because secrets are not environment-variable values.

### Core Feature Flags

| Schema name | Default | Dependency | Behavior when false |
| --- | --- | --- | --- |
| `foia_EnableSharePointDocuments` | `true` | SharePoint connection reference and permission manifest | Document operations blocked explicitly; metadata-only local tests may run, but release gate fails |
| `foia_EnableCoreNotifications` | `true` | Office 365 connection reference | Notifications show `Disabled`; statutory state remains authoritative and usable |
| `foia_EnableFOIAGovIntake` | `false` | Approved custom/HTTP connector | No endpoint calls; other intake channels remain available |
| `foia_EnablePublicPortalIntake` | `false` | Approved portal contract | No portal ingestion; manual/staff intake remains available |
| `foia_EnableAgencyPortalIntake` | `false` | Approved portal contract | No agency-portal ingestion |
| `foia_EnableInboundEmailIntake` | `false` | Office 365 connection and mailbox key | No mailbox polling; manual intake remains available |
| `foia_EnableAPIIntake` | `false` | Approved API gateway/custom connector | API disabled with explicit status |
| `foia_EnableHTMLReportWebResources` | `false` | Separately approved gap and payload | Native views/charts/dashboards remain authoritative |

Core notifications may be disabled for resilience testing; request processing,
clock calculations, approvals, release, and reporting must continue. SharePoint is
the planned production document store, so a production release cannot disable it,
but Azure is never required for it.

### Optional Azure Feature Flags

| Schema name | Default | Optional adapter |
| --- | --- | --- |
| `foia_AzFunctionsEnabled` | `false` | Workflow/orchestration adapter |
| `foia_AzOpenAIEnabled` | `false` | Summarization, classification, relevance, and draft adapter |
| `foia_AzAISearchEnabled` | `false` | Full-text, semantic, and vector search adapter |
| `foia_AzDocumentIntelligenceEnabled` | `false` | OCR and metadata-extraction adapter |
| `foia_AzStorageEnabled` | `false` | Optional transient adapter storage; never core document authority |

For each flag:

- false means no connection lookup, DNS/network call, credential request, resource
  validation, health probe, or deployment action;
- true requires a separately approved adapter configuration block, connection or
  managed identity, data-boundary assessment, GCC High/IL5 service availability
  proof, threat review, and test evidence;
- `Disabled`, `Unavailable`, and `Failed` are explicit results and cannot be mapped
  to `Succeeded` or substituted with synthetic output.

No Azure endpoint variable is defined in the initial contract. An endpoint may be
added only with a new configuration-contract version and portability review.

## Connection Reference Contract

Logical names are stable; resolved connection IDs and credentials are
environment-specific and untracked.

| Logical name | Connector class | Required condition | Least-privilege purpose |
| --- | --- | --- | --- |
| `foia_shared_commondataserviceforapps` | Microsoft Dataverse | Core flows enabled | Read/write only approved FOIA tables/actions in current environment |
| `foia_shared_sharepointonline` | SharePoint Online | `foia_EnableSharePointDocuments=true` | Approved site/library and permission operations only |
| `foia_shared_office365` | Office 365 Outlook | Core notifications or inbound email enabled | Approved shared mailbox/template send/read operations only |
| `foia_foiagov_custom` | Approved custom connector | `foia_EnableFOIAGovIntake=true` | Approved FOIA.gov operations only |
| `foia_agencyapi_custom` | Approved custom connector | `foia_EnableAPIIntake=true` | Approved inbound API contract only |
| `foia_az_orchestration_custom` | Optional custom connector | `foia_AzFunctionsEnabled=true` | Approved orchestration operation only |
| `foia_az_ai_custom` | Optional custom connector | `foia_AzOpenAIEnabled=true` | Approved assistive operation only |
| `foia_az_search_custom` | Optional custom connector | `foia_AzAISearchEnabled=true` | Approved search operation only |
| `foia_az_document_custom` | Optional custom connector | `foia_AzDocumentIntelligenceEnabled=true` | Approved OCR/metadata operation only |
| `foia_az_storage_custom` | Optional custom connector | `foia_AzStorageEnabled=true` | Approved transient object operation only |

Preflight verifies that each enabled feature has exactly one connected reference
in the target environment, the connector is permitted by DLP policy, ownership is
approved, and no flow embeds a direct connection ID. Ambiguous or disconnected
references block apply.

## Adapter Result Contract

Every optional adapter returns:

```json
{
  "contractVersion": "1.0",
  "operation": "synthetic-operation",
  "status": "Disabled",
  "correlationId": "synthetic-correlation-id",
  "startedAtUtc": "2030-01-15T12:00:00Z",
  "completedAtUtc": "2030-01-15T12:00:00Z",
  "resultReference": null,
  "errorCode": null,
  "safeMessage": "Feature is disabled."
}
```

Allowed statuses are `Disabled`, `Ready`, `Running`, `Succeeded`, `Unavailable`,
and `Failed`. Only `Succeeded` may carry a result reference. The contract never
contains credentials, raw prompts with personal data, or document content.

## Secret Handling Contract

### Prohibited Locations

Secrets must not appear in:

- Git files, Markdown, JSON templates, payloads, test fixtures, screenshots, logs,
  telemetry, evidence indexes, solution environment-variable defaults, flow
  definitions, command histories, package names, or correlation IDs;
- the deployment manifest, even encrypted or hashed;
- Dataverse text fields or SharePoint metadata used as configuration.

### Approved Resolution

- Prefer managed identity when supported and approved in the target cloud.
- Otherwise use Power Platform connection objects, approved government-cloud
  secret stores, pipeline secret variables, or separately governed certificates.
- Record only `secretReferenceKind`, logical reference name, owner, rotation policy,
  and validation status. Never record the secret or secret-bearing URI.
- Redact authorization headers, query signatures, tokens, cookies, keys, and
  credential-bearing connection strings at the logging boundary.

### Lifecycle

1. A named owner provisions the secret outside source control.
2. Deployment resolves the logical secret/connection reference at runtime.
3. Preflight tests authentication without echoing sensitive values.
4. Rotation is tested with overlap where supported and recorded by non-secret
   version label/time.
5. Revocation is immediate on suspected exposure.
6. If exposure occurs, assume compromise, revoke/rotate, remove from active source,
   assess history remediation, and document the incident in the approved system.

## Configuration Preflight

- Confirm planning and approval gates without authenticating during design.
- Validate environment classification against the target cloud when access is later
  authorized.
- Resolve every required non-secret variable; reject placeholder values.
- Parse JSON variables and validate types/ranges/token allowlists.
- Confirm all optional Azure flags are false for the mandatory baseline run.
- Resolve only connection references required by enabled features.
- Verify DLP compatibility and least-privilege ownership.
- Verify report/calendar/records-schedule versions exist and are approved.
- Run secret and hard-coded-endpoint scans.
- Write only sanitized resolution status and hashes to the deployment manifest.

This document defines configuration; it does not authorize authentication,
connection creation, resource discovery, or mutation.
