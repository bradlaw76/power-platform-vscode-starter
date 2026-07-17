# plan.md

## Build Approach
- Platform area: Dynamics 365 Customer Service
- Environment: https://contoso-dev.crm.dynamics.com
- Solution type: Unmanaged
- Solution unique name: ContosoCaseTracker (new)
- Publisher prefix: cct (new)

## Proposed Workstreams
1. Discovery review and approval
2. Dataverse schema design
3. Forms/views/pages/app experience design
4. ~~Flow/copilot automation design~~ _(out of scope — no flows or copilot components are specified in spec.md)_
5. Demo data planning
6. Solution export/unpack/git workflow
7. Validation and handoff

## Risks to Resolve
- Confirm environment availability and permissions.
- Confirm entity scope and artifact count.
- ~~Confirm whether demo data must be scripted or manual.~~ _(Resolved: demo data required; scripted approach — see tasks.md)_

## Explicit Entity Mapping (Required Before Payloads)

### Standard reused tables (display -> logical)
- Case -> incident
- Contact -> contact

### Custom tables to create (input -> generated logical)
- Customer -> cct_customer
- Agent -> cct_agent
- Priority -> cct_priority

### Standard fields reused
- incident.title
- incident.statuscode
- contact.fullname

### Custom fields to add
- incident.cct_priority
- incident.cct_agent

### Relationships to create
- incident (referencing) -> contact (referenced)
- incident (referencing) -> cct_priority (referenced)
- incident (referencing) -> cct_agent (referenced)

### Payload Readiness Rule
- Do not generate payloads until this mapping is complete and approved.
- Table payloads must include only true custom entities.
- Column/relationship payloads may reference standard and custom entities.

## Validation Plan
- Verify artifacts in Maker portal.
- Verify solution export/unpack succeeds.
- Verify git changes are reviewable.
- Verify import into target environment succeeds.
