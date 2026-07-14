# Demo Walkthrough: Contoso Case Tracker

## Purpose
This walkthrough is for the engineer/operator running the demo. It is derived from scenario files and should stay aligned to the implemented solution.

## Scenario Source
- Derived from: answers.md, spec.md, plan.md, and tasks.md in specs/contoso-case-tracker/
- Scenario name: Contoso Case Tracker
- Platform area: Dynamics 365 Customer Service
- Environment: https://contoso-dev.crm.dynamics.com

## Scenario Requirements Snapshot
- Business problem: Track and resolve customer support cases from intake to closure
- Success criteria: Agent opens a case, fills the form, case appears in active view
- Required entities: Case, Customer, Agent, Priority
- Required artifacts: Case form, active cases view, supervisor dashboard

### Explicit Entity Mapping
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

### Validation Plan
- Verify artifacts in Maker portal.
- Verify solution export/unpack succeeds.
- Verify git changes are reviewable.
- Verify import into target environment succeeds.

## Engineer Runbook
### Pre-demo Setup
- Confirm environment access and app load in https://contoso-dev.crm.dynamics.com.
- Validate demo data availability mode: Use prepared sample data where helpful, but show at least one live change.
- Open the hero record area for: Case
- Confirm demo scope artifacts are available: Case form, active cases view, supervisor dashboard

### Implementation Walkthrough Checklist
- [ ] Review 'answers.md' with stakeholder
- [ ] Finalize 'spec.md'
- [ ] Finalize 'plan.md'
- [ ] Approve build environment and permissions
- [ ] Review standard table reference: 'docs/standard-dataverse-tables.md'
- [ ] Complete explicit entity mapping in spec/plan (standard reused tables, custom tables to create, standard fields reused, custom fields to add, relationships)
- [ ] Map standard names to logical names (for example: Case -> incident, Contact -> contact) before payload design
- [ ] Confirm table payloads include only true custom tables
- [ ] Confirm out-of-box fields are reused unless custom fields are explicitly required
- [ ] Define custom table schemas and payloads

### What To Show (Implementation-Oriented)
- Show where the hero record (Case) is managed.
- Demonstrate how configured entities/artifacts support: Run the end-to-end Contoso Case Tracker story from intake through closure, using Case, Customer, Agent, Priority and proving 'Agent opens a case, fills the f...
- Show one verification signal tied to success criteria.

### Risk Mitigation During Demo
- If live data is missing, pivot to nearest prepared record and narrate expected outcome.
- If automation is delayed, show artifact evidence and explain eventual state.
- If a screen/view is unavailable, use the closest form/view that still proves the scenario.

## Review Gate
- [ ] Walkthrough reflects current spec/plan/tasks.
- [ ] Mapping section matches implemented standard/custom model.
- [ ] Success criteria can be demonstrated in under 5 minutes.
