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
Case form, active cases view, supervisor dashboard

## Success Criteria
Agent opens a case, fills the form, case appears in active view

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
