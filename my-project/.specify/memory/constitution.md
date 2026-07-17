# Contoso Case Tracker — Constitution

## Core Principles

### I. Spec-First (NON-NEGOTIABLE)
No build scripts (`20-*` through `80-*`) may run until `spec.md`, `plan.md`, and `tasks.md` are complete, reviewed, and approved. Discovery answers in `answers.md` must be finalized before spec is written. Implementation must follow the approved task list in order.

### II. Standard-Before-Custom
Reuse standard Dataverse tables and fields before creating custom ones. Custom tables and columns require explicit justification in `spec.md`. The custom publisher prefix (`cct`) MUST be used for all custom components — no exceptions.

### III. PAC CLI Mandatory
All Dataverse schema operations (table creation, column creation, relationship creation, solution management) MUST use the PAC CLI bootstrap scripts. Direct portal edits during the build phase are prohibited unless the script path is unavailable. Any portal-only changes must be documented in `docs/build-log.md`.

### IV. Unmanaged in Dev, Managed for Production
Development environments use unmanaged solutions only. Managed solutions are reserved for target/production environment imports. Solution unique name (`ContosoCaseTracker`) and publisher prefix (`cct`) are fixed once set and must not be changed mid-build.

### V. Git-Tracked Artefacts
All solution exports MUST be unpacked (`pac solution unpack`) and committed to git before deployment or handoff. The `docs/build-log.md` MUST be updated after each major build step. No deployment without a clean, committed git state.

## Quality Gates

- Spec Kit planning artifacts approved before build scripts run
- Entity mapping reviewed and locked in `spec.md` and `plan.md` before payloads are generated
- Solution export/unpack verified and committed before import
- Import into target environment validated post-deployment
- Demo data loaded and verified in Maker portal before handoff

## Governance

This constitution supersedes all other practices for this project. Amendments require an explicit update to this file with rationale. All tasks and implementation decisions must be traceable to a requirement in `spec.md`.

**Version**: 1.0.0 | **Ratified**: 2026-07-17 | **Last Amended**: 2026-07-17
