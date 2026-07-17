# tasks.md

## Ordered Tasks

- [ ] Review 'answers.md' with stakeholder
- [ ] Finalize 'spec.md'
- [ ] Finalize 'plan.md'
- [ ] Identify tables requiring report surfaces (greenfield: from spec/tasks; retrofit: from existing solution inventory)
- [ ] Approve build environment and permissions
- [ ] Review standard table reference: 'docs/standard-dataverse-tables.md'
- [x] Complete explicit entity mapping in spec/plan (standard reused tables, custom tables to create, standard fields reused, custom fields to add, relationships)
- [x] Map standard names to logical names (for example: Case -> incident, Contact -> contact) before payload design
- [x] Confirm table payloads include only true custom tables
- [x] Confirm out-of-box fields are reused unless custom fields are explicitly required
- [ ] Define custom table schemas and payloads
- [ ] Define Dataverse tables and columns for: Case, Customer, Agent, Priority
- [ ] Define required app artifacts for: Case form, active cases view, supervisor dashboard
- [x] Decide demo data approach: scripted (5 agents, 10 cases, 3 priority levels)
- [ ] Confirm solution name 'ContosoCaseTracker' and publisher prefix 'cct' with stakeholder

## Build and Deployment Tasks

- [ ] Run 'pwsh ./scripts/bootstrap/00-prereq-check.ps1'
- [ ] Run 'pwsh ./scripts/bootstrap/10-auth-connect.ps1'  # validates solution + prefix via API
- [ ] Build tables with '20-build-tables.ps1'
- [ ] Build columns with '30-build-columns.ps1'
- [ ] Build relationships with '40-build-relationships.ps1'
- [ ] Add components to solution with '50-add-to-solution.ps1'
- [ ] Build starter forms/views with '60-build-forms-views.ps1'
- [ ] Build supervisor dashboard (model-driven app dashboard: open case count, cases by priority, cases by agent)
- [ ] **Optional: Build HTML report web resources** — Decide whether to include Agent Performance, Supervisor Oversight, and Executive KPI reports (three Dynamics-blue HTML reports). If yes, enable in wizard answers and run '65-build-web-resources.ps1'; if no, skip. Reports are optional design shells — not live data dashboards.
- [ ] Create and load demo data: 5 agents, 10 cases across 3 priority levels
- [ ] Export and unpack solution
- [ ] Commit changes to git
- [ ] Pack and import solution
- [ ] Run '80-post-build-analysis.ps1' and review output
- [ ] Update 'docs/build-log.md'

