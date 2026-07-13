# tasks.md

## Ordered Tasks
- [ ] Review nswers.md with stakeholder
- [ ] Finalize spec.md
- [ ] Finalize plan.md
- [ ] Approve build environment and permissions
- [ ] Define Dataverse tables and columns for: Case, Customer, Agent, Priority
- [ ] Define required app artifacts for: Case form, active cases view, supervisor dashboard
- [ ] Decide demo data approach: Yes
- [ ] Confirm solution name 'ContosoCaseTracker' and publisher prefix 'cct' with stakeholder
- [ ] Run pwsh ./scripts/bootstrap/00-prereq-check.ps1
- [ ] Run pwsh ./scripts/bootstrap/10-auth-connect.ps1  # validates solution + prefix via API
- [ ] Build tables with 20-build-tables.ps1
- [ ] Build columns with 30-build-columns.ps1
- [ ] Build relationships with 40-build-relationships.ps1
- [ ] Add components to solution with 50-add-to-solution.ps1
- [ ] Build starter forms/views with 60-build-forms-views.ps1
- [ ] Export and unpack solution
- [ ] Commit changes to git
- [ ] Pack and import solution
- [ ] Update docs/build-log.md
