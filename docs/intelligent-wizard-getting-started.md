# Intelligent wizard: install and start

## What is available

These are reviewed-source **candidates**, not an official release or a trusted
automatic upgrade. Starter has no release version/publisher policy; its contract
is `1.10.0`, profile `1.6`. Automation package `0.2.1` and selectable guidance
`0.2.4` are separate identities, not new product releases.
Use independently reviewed full commits from [Starter #19](https://github.com/bradlaw76/power-platform-vscode-starter/pull/19)
and [bradlaw76/Power-Platform-vs-code-starter-automation-pipeline#27](https://github.com/bradlaw76/Power-Platform-vs-code-starter-automation-pipeline/pull/27).
Those PRs are not mainline integration. Standards mappings in
[bradlaw76/Work-items-standards-#5](https://github.com/bradlaw76/Work-items-standards-/pull/5)
remain proposals; they do not allocate work IDs.

## Install or discover

**Already installed?** Run these from the confirmed Starter runtime:

```powershell
pwsh .\scripts\bootstrap\05-start-wizard.ps1 -VersionOnly
pwsh .\scripts\bootstrap\04-check-wizard-update.ps1 -Action Status -AsJson
pwsh .\scripts\bootstrap\04-check-wizard-update.ps1 -Action Check -Offline -AsJson
```

`offline-unknown` is not current/released. Official Apply is unavailable without
approved publisher policy. Do not pull over customized instructions. Use the
existing [instruction migration, backup and recovery](wizard-updates.md#local-instruction-inheritance-and-migration)
transaction; review exact changes, preserve custom security text and retain its
backup. Runtime replacement and instruction migration are different operations.

**New evaluation:** clone the full Starter and, optionally, authorized Automation
source into separate **new** folders, then detach each at its independently
reviewed full commit. Verify `git rev-parse HEAD` before executing source.
Replace the uppercase SHA placeholders below; choose unused destination folders:

```powershell
git clone --no-checkout https://github.com/bradlaw76/power-platform-vscode-starter.git C:\Wizard\starter
git -C C:\Wizard\starter checkout --detach REVIEWED_STARTER_SHA
git clone --no-checkout https://github.com/bradlaw76/Power-Platform-vs-code-starter-automation-pipeline.git C:\Wizard\automation
git -C C:\Wizard\automation checkout --detach REVIEWED_AUTOMATION_SHA
```

The second clone is optional and requires authorized repository access.
Follow [distribution/provenance checks](skill-distribution.md); copying a skill
alone is not runtime installation. Do not install protection hooks implicitly.
Use VS Code's recommended extensions, PowerShell 7, Git, PAC CLI (Power Platform
command-line tools) and Azure CLI; `00-prereq-check.ps1` reports missing tools.

For optional Automation, use Python 3.11+ and an isolated environment. From the
reviewed Automation checkout on Windows:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install .
.\.venv\Scripts\python.exe -m demo_builder --version
.\.venv\Scripts\python.exe -m demo_builder browser setup
```

If setup reports missing Playwright/Chromium, explicitly run the same environment's
`python -m demo_builder browser setup --install`; respect approved proxy and
certificate settings. Never copy browser profiles, cookies or credentials.

## Describe the objective, then inspect an early slice

1. Open the reviewed Starter in VS Code. Invoke `/power-platform-wizard-init`.
   Say **build**, **enhance** or **repair**, your objective and delivery goal.
   Existing work should be discovered/adopted, not recreated.
2. Answer only unresolved material questions; confirm the consolidated design.
   Dataverse is the application's data platform; a solution groups its components.
   Prefer standard tables and native forms. Choose single-operator, multi-persona
   or production-oriented fidelity without weakening actual security requirements.
3. Keep the required scenario `spec.md`, `plan.md`, `tasks.md` concise and aligned.
   Before bootstrap changes, follow [onboarding](onboarding.md), including semantic
   field decisions and actual environment authorization. No build-before-planning.
4. With optional Automation installed, use the existing
   [handoff](framework-handoff.md#adaptive-discovery-q31) to discover, deliver the
   first functional slice and apply accepted feedback to the same queue.
   Tasks, journals and checkpoints resume work; no second scheduler is installed.

Guided Windows use needs no WSL or native worker supervisor. Autonomous workers
need Linux/macOS/WSL with Python 3.11+, process groups/signals, the reviewed package
and an explicitly configured local worker. On Windows check `wsl --list --quiet`
and `wsl --exec python3 --version`; if unavailable, install WSL/Ubuntu through
approved Windows tooling or continue guided Windows execution. Activate the
POSIX environment's `bin/activate`, not Windows `Scripts`; Windows-only tools or
paths do not automatically become POSIX worker prerequisites.

## Capability boundaries and browser setup

| Capability | Candidate status |
| --- | --- |
| Queue generation, existing-app adoption, targeted repair, recovery, feedback | Available for supported contracts/recipes; synthetic acceptance passed. Actual live effects require exact target/scope authority. |
| Installation, custom instruction migration and rollback | Isolated package replacement and guidance 0.2.3/0.2.4 rollback tested; not an official upgrade channel. Preserve exact source pins because package version alone is insufficient. |
| Hosted PR dependencies | Optional Automation CLI `git-review --root <local-root> --repository owner/repo --pull-request 1 --pull-request 2`; explicit read-only GitHub queries using existing `gh` authentication. No Git fetch/merge/close. Missing local objects remain partial (exit 3); unselected/cross-repository dependencies are not inferred. Starter's manifest handoff remains offline. |
| Playwright authentication/inspection | Implemented, dependencies available in campaign checks. Select the authorized exact app/principal/tenant/environment and approved browser session, or complete interactive Microsoft sign-in/MFA yourself. See [browser setup](framework-handoff.md#playwright-diagnostics-q29). |
| Actual native application/agent acceptance | **Blocked**: Q36 did not obtain a shared authenticated app page or verified exact target. No native, keyboard, accessibility or actual agent-conversation pass is claimed. |
| Official release/trusted automatic updater | **Unavailable**: no published release or approved publisher policy observed. |

Browser diagnostics default read-only. Diagnostic heuristics are not accessibility
certification; arbitrary keyboard traversal remains unverified. A fresh interactive
session may need human sign-in. Existing-session reuse requires an explicitly
selected supported endpoint/session, never port scanning or profile extraction.
If browser sharing is refused, stop that access path. State-changing scenarios,
agent tool effects and repairs need applicable explicit scope; protect accepted
demo records and excluded components. Synthetic Chromium evidence is never live
native acceptance. Use existing scoped backup/publish/readback/retest workflows,
not broad publication or destructive recreation.
