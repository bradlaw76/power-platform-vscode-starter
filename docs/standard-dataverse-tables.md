# Standard Dataverse Tables

This document lists the most commonly used **out-of-box (system) tables** in Dataverse that should be reused rather than recreated. These are installed by default or with Dynamics 365 modules.

## Common Tables by Module

### Sales & CRM (Always Available)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `contact` | Contact | Store customer/person data | ❌ Out-of-box |
| `account` | Account | Store organization/company data | ❌ Out-of-box |
| `opportunity` | Opportunity | Track sales pipeline | ❌ Out-of-box |
| `lead` | Lead | Capture prospective customers | ❌ Out-of-box |
| `competitor` | Competitor | Competitive tracking | ❌ Out-of-box |
| `invoice` | Invoice | Sales invoices | ❌ Out-of-box |
| `order` | Order (Sales Order) | Customer orders | ❌ Out-of-box |
| `quote` | Quote | Sales quotes | ❌ Out-of-box |

### Customer Service (Dynamics 365 Customer Service)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `incident` | Case | Support cases/tickets | ❌ Out-of-box |
| `knowledgearticle` | Knowledge Article | FAQ/help content | ❌ Out-of-box |
| `entitlement` | Entitlement | Support entitlements | ❌ Out-of-box |
| `sla` | SLA (Service Level Agreement) | Support SLAs | ❌ Out-of-box |

### Field Service (Dynamics 365 Field Service)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `msdyn_workorder` | Work Order | Field service jobs | ❌ Out-of-box |
| `msdyn_serviceappointment` | Service Appointment | Scheduled appointments | ❌ Out-of-box |
| `msdyn_customerasset` | Customer Asset | Equipment tracking | ❌ Out-of-box |

### Activity & Common (Always Available)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `task` | Task | Work items/to-dos | ❌ Out-of-box |
| `activitypointer` | Activity | Base activity type | ❌ Out-of-box |
| `email` | Email | Email messages | ❌ Out-of-box |
| `phonecall` | Phone Call | Call logs | ❌ Out-of-box |
| `appointment` | Appointment | Calendar events | ❌ Out-of-box |
| `fax` | Fax | Fax messages | ❌ Out-of-box |
| `letter` | Letter | Letter correspondence | ❌ Out-of-box |
| `socialactivity` | Social Activity | Social media posts | ❌ Out-of-box |

### Products & Pricing (Always Available)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `product` | Product | Catalog of products/services | ❌ Out-of-box |
| `pricelevel` | Price List | Pricing tiers | ❌ Out-of-box |
| `productpricelevel` | Product Price List Item | Product-price mapping | ❌ Out-of-box |
| `uom` | Unit | Unit of measurement | ❌ Out-of-box |
| `uomschedule` | Unit Group | Unit grouping | ❌ Out-of-box |

### Marketing & Campaigns (Dynamics 365 Marketing or Sales)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `campaign` | Campaign | Marketing campaigns | ❌ Out-of-box |
| `campaignresponse` | Campaign Response | Campaign participation tracking | ❌ Out-of-box |
| `list` | Marketing List | Segmented contact lists | ❌ Out-of-box |

### Organization & Admin (Always Available)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `systemuser` | User | System users | ❌ Out-of-box |
| `team` | Team | User teams/groups | ❌ Out-of-box |
| `businessunit` | Business Unit | Organizational divisions | ❌ Out-of-box |
| `organization` | Organization | Tenant info | ❌ Out-of-box |
| `queue` | Queue | Work queues/routing | ❌ Out-of-box |
| `role` | Security Role | Permission roles | ❌ Out-of-box |
| `territory` | Territory | Geographic regions | ❌ Out-of-box |

### Relationships & Connections (Always Available)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `connection` | Connection | Relationships between records | ❌ Out-of-box |
| `connectionrole` | Connection Role | Connection role types | ❌ Out-of-box |
| `relationship` | Relationship | Metadata about relationships | ❌ Out-of-box |

### Notes, Attachments & Documents (Always Available)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `annotation` | Note | Text notes on records | ❌ Out-of-box |
| `activitymimeattachment` | Activity Mime Attachment | Email/activity attachments | ❌ Out-of-box |

### Project Operations & Professional Services (Dynamics 365 Project Operations)

| Logical Name | Display Name | Use Case | Custom? |
|--------------|--------------|----------|---------|
| `msdyn_project` | Project | Project tracking | ❌ Out-of-box |
| `msdyn_projecttask` | Project Task | Project tasks | ❌ Out-of-box |
| `msdyn_resource` | Bookable Resource | Resource scheduling | ❌ Out-of-box |
| `msdyn_resourcebooking` | Resource Booking | Booking reservations | ❌ Out-of-box |

---

## When to Use Out-of-Box Tables

✅ **Reuse** if:
- The table matches your business entity (Contact for people, Account for companies, Case for support tickets)
- You only need to add a few custom columns
- The table is already enabled for activities, notes, attachments if you need those
- Standard Dynamics workflows/integrations rely on that table

❌ **Create a custom table** if:
- No standard table matches your domain (e.g., "Inspection", "WorkOrder" variant, "Equipment")
- You need complete control over the table schema
- You want to isolate your app's data from standard CRM data
- You need a managed solution without modifying standard tables (some orgs restrict this)

---

## Example Decision Matrix

| Scenario | Use Out-of-Box | Create Custom |
|----------|----------------|---------------|
| Track customer inquiries → use Case `incident` | ✅ Use `incident` | ❌ Don't create CustomCase |
| Track special inspection type → likely no match | ❌ `incident` ≠ Inspection | ✅ Create `cct_inspection` |
| Track equipment → might use `msdyn_customerasset` (FS) or create custom | ⚠️ Evaluate | ⚠️ Decide case-by-case |
| Track internal staff → use User `systemuser` | ✅ Use `systemuser` | ❌ Don't create CustomStaff |
| Track projects → no standard table → create custom | ❌ No match | ✅ Create `cct_project` |

---

## How the Wizard Handles This

When you run the wizard and answer **"What data tables or entities are needed?"**, the updated wizard will:

1. Ask: **"Do you want to use standard Dataverse tables (Contact, Account, Case, etc.) or create new custom tables?"**
2. If you choose **standard tables**: list them and ask which ones you'll use
3. If you choose **custom tables**: ask what custom tables you need (will be created with your publisher prefix)
4. If **both**: list which are standard (will be skipped in build) and which are custom (will be created in solution)

**Example dialog**:
```
What data tables or entities are needed?: Contact, Case, CustomInspection
Do you want to use standard tables where available? (standard/custom/both) [both]: both

Standard tables detected in your list:
  - Contact (out-of-box) — will not be created
  - Case (out-of-box) — will not be created

Custom tables to create in your solution:
  - CustomInspection → cct_custominspection (using prefix 'cct')

Proceed? (y/N): y
```

Then script 20 (`20-build-tables.ps1`) will:
- **Skip** Contact and Case (already exist)
- **Create** only `cct_custominspection` in your solution

---

## Reference: Full Standard Table List (Partial)

For a complete reference, see Microsoft Docs:
- [Dynamics 365 Sales Tables](https://learn.microsoft.com/en-us/dynamics365/customer-engagement/schema/entities/account)
- [Dynamics 365 Customer Service Tables](https://learn.microsoft.com/en-us/dynamics365/customer-service/develop/reference/entities)
- [Dynamics 365 Field Service Tables](https://learn.microsoft.com/en-us/dynamics365/field-service/developer/reference/entities)
- [Common Dataverse Tables](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/about-entity-reference)
