# Delivery target, deadline and optional automation

The optional [installed H008 handoff](framework-handoff.md) reuses canonical
tasks, lessons and synchronization after accepted planning. Native Windows
guided use does not require consumer Git or WSL; worker supervision remains
POSIX-only and does not authorize an unattended scheduler or live deployment.

This reusable starter serves first-time builders and experienced implementers. A demo, pilot and production release have different delivery needs, but a deadline never authorizes skipping a required platform or security check. The delivery context applies to Demo Builder, Advanced Builder and Framework Acceptance, for greenfield and existing-project adoption.

## Two plain-language questions

1. **What are you delivering?** Choose `prototype`, `presentation-demo`, `connected-demo`, `pilot`, or `production`.
2. **When must it be ready?** Supply a date or timeframe, or `no fixed deadline`. This is a target, not a software-generated promise or authorization.

The guided terminal wizard asks both questions. Users with an existing scripted answers file can provide `-DeliveryGoal` and `-DeliveryTimeframe` without changing legacy ordered answer files. Without these values, a scripted run retains `unconfirmed` and must resolve the delivery goal before release. Chat and agent entry points ask the same two questions, honoring answers already given.

The terminal timeframe must be a single line. Line breaks are rejected so a supplied deadline cannot introduce headings or tasks into generated planning contracts.

## Validation proportional to delivery purpose

| Goal | Initial verification emphasis | Required evidence and non-waivable gates |
| --- | --- | --- |
| Prototype | Small, focused changed-behavior checks | Accurate status; no production claims, unsafe operations or unchecked data changes |
| Presentation demo | Rehearse the named journey and check changed components | Distinguish prepared scenes from live actions; real saves need read-back and role context |
| Connected demo | Focused component/integration tests and linked-record checks | Exact application, form, relationships, selected record, role, save/reopen and real data |
| Pilot | Integration, negative cases, permissions and operational readiness | Authorized environment, representative users and acceptance evidence |
| Production | Full applicable CI, security, operational, data and integration validation | Formal deployment authorization, recovery and production acceptance remain mandatory |
| Unconfirmed | Conservative applicable verification | Resolve the owner's delivery intent before release; no silent downgrade |

These are **planning profiles**, not executable bypass switches. Existing CI requirements, environment authorization, safety, security, exact-identity, backup and deployment checks still apply. Nightly full regressions are optional only where an actual runner/scheduler exists and the task warrants it; no scheduler is installed by these instructions.

The independently selected build verification profile is described in
[release operating modes](release-consolidation.md). `Legacy` is the default;
`Demo` explicitly skips optional rerun/export deliverables, with independent
opt-ins and unchanged mandatory gates. `Acceptance` retains existing
payload-dependent verification. Do not translate a delivery goal into a runtime
profile without the existing consolidated confirmation.

## Beginner-safe tool discovery

- Check what is already installed and authorized before recommending setup. Explain missing tools in plain language.
- `pwsh` is needed for the provided *terminal* wizard. Chat guidance, an existing source checkout and other supported project workflows do not automatically imply a WSL requirement.
- Git is useful for source control and backups, but users can have a folder-only or environment-only starting point.
- PAC CLI, Dataverse authentication and permissions are needed only for operations that actually touch those resources. Read-only discovery is not a deployment authorization.
- **WSL is optional**. Consider it only for a separately selected local supervised-worker profile on a compatible Windows host. Prefer a guided/native supported path when WSL is missing or setup would cost more time than it saves.
- Tool presence is not proof of working authentication, tenancy, provider entitlement or a functioning runtime. Never install tools, alter security policy or enable a scheduler by implication.

## Automation is a measured option

Start in **guided** execution. Propose automation only when the following are demonstrated:

1. Repeated or independent work is substantial enough for automation to matter.
2. Required runtime, credentials, hosted/local execution rights, ownership locks and restart recovery already exist or can be configured within the real deadline.
3. The estimated time saved by reuse/retries/parallel work exceeds setup, maintenance, validation and recovery overhead.
4. The user explicitly selects the automation path after reviewing the scope, cost, and its actual permissions.

A missing WSL instance, no configured runner, one small task or a short deadline generally favors guided execution. Do not start overnight work, turn on hosted inference, schedule tasks, create pull requests or write to a tenant merely because the delivery goal is urgent.

For a substantial multi-workstream build, automation can be valuable only after task boundaries, existing writers, dependency locks and evidence obligations are known. The installed automation framework may provide compatible capabilities, but an unmerged implementation or a README link does not establish that a worker is active.

## Spec Kit continuity

Record the delivery goal and timeframe in `answers.md`, `spec.md`, `plan.md` and actionable `tasks.md` checks. For later changes, update the affected files **from accepted requirement decisions and actual source/deployment/verification evidence**; never overwrite human-authored intent based on an inferred status. A change in scenario, deadline, live-versus-prepared fidelity or production status requires impact reconciliation before generating new implementation tasks.

Apply the proportional [scenario change impact gate](scenario-change-impact-gate.md). Minor maintenance retains accepted planning and uses focused checks without regenerating the full matrix. A timeframe-only update changes delivery context, not unrelated schema or tasks; a changed delivery goal revisits applicable acceptance without waiving mandatory gates.

This increment updates intake and generated planning artifacts. It **does not** implement an autonomous Spec Kit updater, activate CI, relax existing execution gates, validate a live tenant, change another project or implement an unattended worker.
