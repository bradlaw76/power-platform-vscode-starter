# spec.md

## Scenario Summary
Contoso Case Tracker is a Model-driven app for tracking customer support cases for Dynamics 365 Customer Service.

## Problem Statement
Track and resolve customer support cases from intake to closure

## Target Audience
Customer support agents and supervisors

## Users
Support agents, team leads, and admins

## Required Data Entities
Case, Customer, Agent, Priority

## Explicit Entity Mapping (Required)

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

## Required Experience and Artifacts
- **Case form**: fields for title, priority (lookup to cct_priority), assigned agent (lookup to cct_agent), customer (lookup to contact), and status
- **Active cases view**: filtered to open/in-progress cases; sortable by priority and assigned agent
- **Supervisor dashboard**: displays open case count, cases grouped by priority, and cases grouped by assigned agent

## Success Criteria
- Agent opens a case, fills in required fields (title, priority, assigned agent), and saves within 30 seconds
- Saved case appears immediately in the Active Cases view without manual refresh
- Supervisor dashboard displays: total open case count, case breakdown by priority level, and case breakdown by agent
- Demo data is loaded: minimum 5 agents, 10 cases spanning all 3 priority levels
- Solution exports cleanly, unpacks without errors, and reimports with all components intact

## Environment
https://contoso-dev.crm.dynamics.com

## Demo Data Requirement
Yes

## Solution Packaging Decision
Unmanaged

## Solution and Publisher
- Solution: ContosoCaseTracker (new)
- Publisher prefix: cct (new)

## Acceptance Criteria
- The scenario is clear and approved.
- Required entities and artifacts are identified.
- Success measures are specific enough to validate.
- The environment and solution type are agreed before implementation.
