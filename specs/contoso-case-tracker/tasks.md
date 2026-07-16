# tasks.md

## Ordered Tasks

- [ ] Review 'answers.md' with stakeholder
- [ ] Finalize 'spec.md'
- [ ] Finalize 'plan.md'
- [ ] Identify tables requiring report surfaces (greenfield: from spec/tasks; retrofit: from existing solution inventory)
- [ ] Approve build environment and permissions
- [ ] Review standard table reference: 'docs/standard-dataverse-tables.md'
- [ ] Complete explicit entity mapping in spec/plan (standard reused tables, custom tables to create, standard fields reused, custom fields to add, relationships)
- [ ] Map standard names to logical names (for example: Case -> incident, Contact -> contact) before payload design
- [ ] Confirm table payloads include only true custom tables
- [ ] Confirm out-of-box fields are reused unless custom fields are explicitly required
- [ ] Define custom table schemas and payloads
- [ ] Define Dataverse tables and columns for: Case, Customer, Agent, Priority
- [ ] Define required app artifacts for: Case form, active cases view, supervisor dashboard
- [ ] Decide demo data approach: Yes
- [ ] Confirm solution name 'ContosoCaseTracker' and publisher prefix 'cct' with stakeholder

## Report Scoping Tasks

- [ ] Create Report Mapping Table in 'report-mappings.md' with one row per report (table logical name, report surface name, report type, target placement, required fields, Dataverse owner)
- [ ] For each table marked critical: confirm explicit report type decision (form web resource, dashboard KPI, or queue/view summary)
- [ ] For each report, document decision that report supports (e.g., case escalation, agent performance, SLA risk)
- [ ] Map required fields to table schema (status fields, risk fields, recommendation fields, date/SLA fields)
- [ ] Define report-level placement (form iframe, dashboard tile, view footer, or ribbon notification)
- [ ] Assign Dataverse record owner (persona or team responsible for report definition/validation)
- [ ] Validation gate: all critical tables have approved report decision; all reports have placement and field mapping
- [ ] Stakeholder sign-off on Report Mapping Table

## Build and Deployment Tasks

- [ ] Run 'pwsh ./scripts/bootstrap/00-prereq-check.ps1'
- [ ] Run 'pwsh ./scripts/bootstrap/10-auth-connect.ps1'  # validates solution + prefix via API
- [ ] Build tables with '20-build-tables.ps1'
- [ ] Build columns with '30-build-columns.ps1'
- [ ] Build relationships with '40-build-relationships.ps1'
- [ ] Add components to solution with '50-add-to-solution.ps1'
- [ ] Build starter forms/views with '60-build-forms-views.ps1'
- [ ] Export and unpack solution
- [ ] Commit changes to git
- [ ] Pack and import solution
- [ ] Update 'docs/build-log.md'

