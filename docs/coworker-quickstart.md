# Coworker Quick Start

This path starts from a clean clone and uses your own synthetic scenario and Dataverse development environment. The included Contoso Case Tracker is synthetic sample content only; do not edit it into your solution identity.

## Local setup

1. Clone the repository or create a repository from its template, then open the repository root in VS Code.
2. Install the extensions recommended by VS Code.
3. From PowerShell 7, run:

```powershell
pwsh ./scripts/bootstrap/00-prereq-check.ps1
```

The check requires Git, VS Code, PowerShell 7 or later, Azure CLI, and Power Platform CLI (PAC CLI). It may write ignored telemetry under `.wizard-metrics/`; it does not authenticate or mutate Dataverse.

## Plan a new scenario

In Copilot Chat, enter:

```text
/power-platform-wizard-init
```

Use the natural-language equivalent `Start the Power Platform wizard in this repository.` if slash commands are unavailable. Choose a new scenario slug; do not reuse `contoso-case-tracker`. Complete architecture intent and discovery one question at a time. Review and approve the generated scenario files under `specs/<scenario-slug>/`, including `spec.md`, `plan.md`, `tasks.md`, and `report-mappings.md`.

Run a credential-free preview:

```powershell
pwsh ./scripts/bootstrap/90-run-build.ps1 -ScenarioSlug <scenario-slug> -Mode Preview
```

Preview must complete before authentication. It plans mutating stages and runs only supported read-only/local validation paths.

## Build in your environment

Use a non-production Dataverse development environment and a scenario-specific unmanaged solution.

```powershell
pwsh ./scripts/bootstrap/10-auth-connect.ps1
pwsh ./scripts/bootstrap/90-run-build.ps1 -ScenarioSlug <scenario-slug> -Mode Apply -StrictSolutionIsolation
```

The apply run stops on failed validation or solution membership. A Business Process Flow (BPF) definition must first be authored in the Power Apps designer from the generated handoff; the BPF script validates, activates, adds, and links that existing supported definition.

Verify the review app opens at the planned entry table/view and inspect `.wizard-metrics/artifacts/solution/solution-membership-report.md`. Export is allowed only when its gate passes. Then follow [onboarding.md](onboarding.md) for export, unpack, validation, explicit staging, review, commit approval, and separate push approval.

## Compatibility

| Tool | Supported baseline | Verification |
| --- | --- | --- |
| VS Code | Current supported release | `code --version` |
| PowerShell | 7 or later | `pwsh --version` |
| PAC CLI | Current Microsoft-supported release | `pac --version` |
| Azure CLI | Current supported release | `az --version` |
| Git | Current supported release | `git --version` |

The prerequisite check is authoritative for the local workstation. Dataverse integration remains environment-specific and must be verified in an authorized disposable development environment.
