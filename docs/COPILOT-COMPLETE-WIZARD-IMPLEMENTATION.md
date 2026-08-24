# Copilot Implementation Brief: Complete and Productize the Power Platform VS Code Wizard

**Repository:** `bradlaw76/power-platform-vscode-starter`  
**Target branch:** `main`  
**Baseline reviewed:** `8bc0acfe2394373b771b818a9c681f73dd42aaa2`  
**Scope:** Implement all missing advertised capabilities, reconcile documentation with executable behavior, and make the wizard safely reusable by coworkers through either a full repository/template workflow or a shared-skill-first workflow.

---

## 1. Mission

Turn this repository from an advanced prototype into a dependable, coworker-ready Power Platform accelerator.

A new user must be able to:

1. Clone or create a repository from this starter.
2. Open it in VS Code.
3. Invoke the shared Copilot skill.
4. Complete discovery and Spec Kit planning.
5. Authenticate to a selected development environment.
6. Validate the plan and payloads without changing Dataverse.
7. Build the planned Dataverse schema and user experience.
8. Create or update a usable model-driven review app.
9. Add only intended components to the intended solution.
10. Publish, verify, export, and hand off the result through source control.
11. Alternatively, install/copy the shared skill into another suitable repository and use it to bootstrap the same workflow there.

Do not solve this by weakening the README, deleting contract requirements, or marking unimplemented features optional. Implement the complete contract unless a Microsoft platform limitation makes a requirement impossible. Document any such limitation with evidence and implement the safest supported alternative.

---

## 2. Required working method

Before editing:

1. Read completely:
   - `README.md`
   - `MIGRATION.md`
   - `wizard.profile.json`
   - `docs/wizard-contract-v1.md`
   - `docs/onboarding.md`
   - `.github/copilot-instructions.md`
   - `.github/prompts/power-platform-demo-wizard.prompt.md`
   - `.github/skills/power-platform-wizard-init/SKILL.md`
   - `.claude/skills/power-platform-vscode-wizard/SKILL.md`
   - every file under `scripts/bootstrap/` and `scripts/ci/`
2. Inspect current Git status and preserve unrelated work.
3. Create a task list mapped to the numbered requirements in this document.
4. Work in small, reviewable commits. Do not combine documentation-only changes with large runtime changes when they can be separated.
5. Do not push, merge, rewrite history, delete branches, or alter a remote without explicit human approval.
6. Use official Microsoft Power Platform/Dataverse documentation for implementation decisions. Record important platform assumptions in the implementation notes.
7. Never use production data, hard-coded tenant identifiers, passwords, tokens, environment URLs, or customer information.
8. Prefer supported PAC CLI and Dataverse Web API operations. Do not automate unsupported maker-portal UI clicks.
9. Every mutating operation must have validation, clear output, actionable failure messages, and safe rerun behavior.

---

## 3. Current critical gaps

The executable repository does not currently contain several components required by the README and `wizard.profile.json`:

- `scripts/bootstrap/55-build-business-process-flows.ps1`
- `scripts/bootstrap/62-build-app-module.ps1`
- `scripts/bootstrap/55-prune-foreign-tables.ps1`
- `docs/solution-isolation-runbook.md`

The profile also declares mandatory behavior that is not yet fully implemented or enforced:

- solution inventory collection and synchronization
- solution membership reporting and export blocking
- model-driven app creation/update and sitemap validation
- entry-point and landing-view validation
- publishing and usability validation
- complete build-log/run-summary updates
- contract-to-filesystem consistency checks

Treat these as implementation defects, not merely documentation defects.

---

## 4. Deliverable A: contract integrity and CI

Create `scripts/ci/test-contract-integrity.ps1`.

It must load `wizard.profile.json` and fail when:

- any item in `execution.coreModules` does not exist under the configured bootstrap folder
- any enabled optional module references a missing script
- README, onboarding, skills, prompt, migration guide, or contract reference a missing local file or build script
- a mandatory post-build step has neither a script nor a documented implementing function
- a script number is duplicated ambiguously without an explicitly documented wrapper/implementation relationship
- profile versions and contract versions are inconsistent across canonical surfaces
- the configured payload, scenario, or bootstrap folder does not exist

Add this test to `.github/workflows/wizard-quality.yml`.

Also strengthen CI to:

- parse every PowerShell file
- run PSScriptAnalyzer with a checked-in settings file
- validate all JSON files
- validate payload files against checked-in JSON Schemas
- run Pester unit tests
- retain existing source-control acceptance and post-build tests
- use least-privilege workflow permissions
- pin third-party GitHub Actions to immutable commit SHAs where practical

Do not require live Dataverse credentials for pull-request CI. Live integration testing must be a separate, manually triggered or protected-environment workflow.

---

## 5. Deliverable B: shared runtime foundation

Refactor repeated PowerShell behavior into narrowly scoped helpers under `scripts/bootstrap/helpers/`. At minimum provide reusable support for:

- loading and validating `.env.ps1`
- obtaining and refreshing access tokens
- invoking Dataverse requests
- retrying transient failures and honoring `Retry-After` for HTTP 429
- one refresh-and-retry path for HTTP 401
- structured error extraction from Dataverse responses
- URL and OData escaping
- preview/dry-run behavior
- telemetry calls
- run artifact creation
- solution component lookup
- polling asynchronous operations with a timeout
- publish operations
- resolving scenario and payload paths

Add Pester coverage with mocked HTTP responses for success, conflict/already-exists, 401, 403, 404, 409, 429, 5xx, timeout, and malformed response cases.

Secrets and access tokens must never appear in telemetry, reports, exceptions, or committed files.

---

## 6. Deliverable C: Business Process Flow builder

Implement `scripts/bootstrap/55-build-business-process-flows.ps1`.

Requirements:

- Accept `-ScenarioSlug`, explicit path overrides where consistent with other scripts, and a preview/dry-run mode.
- Read scenario-scoped `process-*.json` definitions.
- Add a JSON Schema and examples for the process payload.
- Validate referenced tables, columns, relationships, stages, ordering, required steps, and solution identity before mutation.
- Skip cleanly—with an explanatory report—when the scenario contains no justified staged business process.
- Create or update only wizard-managed BPF artifacts.
- Never overwrite an unrelated existing process with the same display name.
- Add created/updated components to the selected solution.
- Activate only after successful validation.
- Publish and verify the resulting process.
- Produce a machine-readable and human-readable result artifact.
- Be rerunnable without creating duplicate processes, stages, or steps.
- Include mocked Pester tests and a live integration-test path.

If supported BPF creation requires solution XML or another supported deployment method rather than a simple Web API operation, use the supported method and document the rationale.

---

## 7. Deliverable D: model-driven app and sitemap builder

Implement `scripts/bootstrap/62-build-app-module.ps1`.

Requirements:

- Accept `-ScenarioSlug` and preview/dry-run options.
- Use architecture intent from the scenario plan/profile:
  - entry-point table
  - entry-point landing view
  - review-app create/update decision
  - selected tables/forms/views
- Create or update one wizard-managed model-driven app per scenario.
- Generate deterministic unique names based on the approved solution identity.
- Include every intended run artifact and exclude unrelated solution components.
- Create or update sitemap navigation with sensible groups and subareas.
- Set and verify the intended first navigation target and landing view.
- Preserve manual/unrelated app content unless the scenario explicitly authorizes replacement.
- Add the app and sitemap components to the selected solution.
- Publish and poll until the app is available.
- Validate component membership, navigation targets, app URL availability, and basic usability metadata.
- Produce JSON and Markdown verification artifacts.
- Be rerunnable without duplicate apps, groups, or subareas.
- Include mocked Pester tests and a live integration-test path.

A build is not complete merely because tables exist. The resulting app must be openable and navigable.

---

## 8. Deliverable E: solution isolation, inventory, pruning, and export gate

Implement the complete solution-isolation contract.

Create the missing `scripts/bootstrap/55-prune-foreign-tables.ps1`, or renumber it if necessary to avoid collision with the BPF stage. If renumbered, update every contract surface consistently.

The cleanup tool must:

- default to report-only mode
- distinguish expected scenario components, wizard-managed foreign components, and manual/legacy components
- require explicit confirmation and exact target selection before removal
- refuse destructive cleanup in a managed solution
- never delete a Dataverse table merely because it is removed from a solution
- generate before/after inventory artifacts

Create or complete reusable inventory commands that capture logical names, component types, object IDs, solution membership, source payload, and wizard ownership markers for:

- tables
- columns
- relationships
- forms
- views
- BPFs
- model-driven apps
- sitemap entries
- web resources
- optional dashboards, charts, and flows when present

Generate a solution-membership report and block export when mandatory intended components are missing or unauthorized foreign components remain under strict mode.

Add `docs/solution-isolation-runbook.md` covering clean build, retrofit, detection, intentional reuse, safe cleanup, recovery, and export gating.

---

## 9. Deliverable F: end-to-end orchestration

Add a supported top-level orchestration command, preferably `scripts/bootstrap/90-run-build.ps1`, that:

- discovers the selected scenario
- shows the planned environment, solution, publisher, and component scope
- defaults to validation/preview before mutation
- runs applicable stages in contract order
- skips optional stages only when the scenario explicitly disables them
- stops immediately on a failed gate
- supports safe resume after a failed stage
- records run ID, stage status, timing, and artifact paths
- produces a final run summary
- never commits or pushes automatically
- never silently chooses an environment or existing solution

Keep individual stage scripts usable independently.

---

## 10. Deliverable G: coworker distribution — full repository/template path

Make the repository suitable for another coworker to clone or use as a GitHub template.

Required onboarding outcome:

1. Clone/use template.
2. Open in VS Code.
3. Install recommended extensions.
4. Run a single prerequisite check.
5. Invoke `/power-platform-wizard-init`.
6. Create a new scenario without modifying the Contoso sample.
7. Complete planning and preview.
8. Authenticate to the coworker’s own environment.
9. Run the orchestrated build.
10. Verify the app and solution.
11. Export and hand off through Git.

Add or update:

- a concise README quick start
- `docs/onboarding.md` with a first-time-user path tested from a clean clone
- `docs/coworker-quickstart.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- a suitable `LICENSE`, but do not guess the owner’s licensing intent—flag it for explicit approval if no license decision is recorded
- GitHub issue/PR templates where useful
- repository template guidance and sample-reset instructions
- a PAC CLI/PowerShell/VS Code compatibility matrix

The Contoso scenario must be explicitly labeled as synthetic sample content and must not become the default identity of a coworker’s generated solution.

---

## 11. Deliverable H: coworker distribution — shared-skill-first path

Make `.github/skills/power-platform-wizard-init/SKILL.md` portable enough to copy into another compatible repository.

The skill must:

- perform a non-mutating compatibility/preflight assessment first
- explain which required starter files are present or missing
- offer an approved bootstrap path for missing files
- never overwrite existing instructions, skills, scripts, specs, or payloads without review
- distinguish “skill installed” from “wizard runtime installed”
- direct the user to the canonical contract and supported scripts
- collect the complete required architecture and discovery intake
- generate scenario-scoped artifacts
- route to preview/validation before Dataverse mutation
- explain environment and solution safety
- preserve explicit human approval for Git commit/push operations
- work without dependence on Brad’s machine paths, tenant, solution names, sample scenario, or Claude installation

Create `docs/skill-distribution.md` documenting:

- copy/install options
- minimum runtime files
- version compatibility
- updating an installed skill
- uninstalling it
- verifying checksums or release provenance
- the difference between GitHub Copilot shared skills and the Claude Code skill
- how to run a clean coworker acceptance test

If a skill-only installation cannot truthfully provide the complete runtime, package or bootstrap the required runtime explicitly. Do not imply that copying one Markdown file supplies scripts that are not present.

Keep both skill implementations behaviorally aligned. Add a CI comparison/contract test so the Copilot and Claude skills cannot silently diverge on gates, script names, or required stages.

---

## 12. Deliverable I: documentation reconciliation

Refactor the README so it is a product landing page and quick start, not the sole operator manual.

The README must state only capabilities that are implemented and tested. Move detailed material to focused documents and link them.

At minimum reconcile:

- README
- onboarding
- wizard contract
- migration guide
- Copilot instructions
- Copilot prompt
- both skills
- profile
- script reference
- solution-isolation runbook
- coworker quick start
- skill distribution guide

Remove or relocate stale generated build output from the README, including suspicious or unexplained sample logical names. Keep generated sample results in an explicitly labeled example artifact.

Add a documentation link checker and command-reference checker to CI.

---

## 13. Deliverable J: schemas, fixtures, tests, and acceptance

Add JSON Schemas for every supported payload type and reference them from examples where practical.

Maintain fixtures for:

- standard-table-only scenario
- custom-table-only scenario
- hybrid scenario
- scenario with BPF
- scenario without BPF
- report-enabled and report-disabled scenarios
- new solution and approved existing-solution reuse
- contaminated solution inventory
- retrofit mode
- malformed payloads

Required automated coverage:

- static PowerShell parsing
- PSScriptAnalyzer
- Pester unit tests
- documentation/contract integrity
- JSON and schema validation
- source-control non-mutation
- preview-mode non-mutation
- deterministic naming
- rerun/idempotency behavior through mocks
- inventory classification
- strict export gate
- skill contract parity

Create a manually triggered integration workflow for an authorized disposable Dataverse development environment. It must:

1. Build a uniquely named test scenario.
2. Capture inventory.
3. Run the same build a second time.
4. Prove no duplicate components were created.
5. Validate the app, navigation, forms, views, BPF when enabled, solution membership, and publish state.
6. Export the unmanaged solution.
7. Clean up only components created by that test run.
8. Upload sanitized test reports as workflow artifacts.

Never run destructive cleanup against an environment unless it is explicitly marked and approved as disposable.

---

## 14. Security and public-repository review

Review all committed files, especially `requirements/*.pdf`, for customer information, personal information, credentials, internal-only content, or licensing restrictions.

Do not delete questionable files automatically. Produce a review report identifying:

- file
- concern
- confidence
- recommended owner decision

Add secret scanning guidance, dependency/update automation where appropriate, and a documented vulnerability-reporting path.

---

## 15. Definition of done

Do not mark this effort complete until all of the following are true:

- Every enabled module in `wizard.profile.json` exists and is tested.
- Every command in README and onboarding resolves to a real file and supported invocation.
- The complete build produces an openable model-driven app, not only metadata fragments.
- BPF behavior works when explicitly planned and skips safely otherwise.
- Solution inventory and strict export gating work.
- Preview mode produces no Dataverse or Git mutations.
- A second build creates no duplicate wizard-managed artifacts.
- CI detects missing scripts and documentation drift.
- A coworker can complete the clean-clone quick start without Brad-specific knowledge.
- A coworker can install the shared skill into another compatible repo and receive an honest compatibility/bootstrap assessment.
- Copilot and Claude skill contracts remain aligned.
- Documentation accurately describes the tested behavior.
- All tests pass.
- The final report lists changed files, test evidence, unresolved platform limitations, security-review findings, and any decisions requiring the repository owner.

---

## 16. Final Copilot response format

When finished, report:

1. Outcome and whether the complete definition of done was met.
2. Commits created.
3. Files added, changed, and intentionally not changed.
4. Test commands run and exact results.
5. Live Dataverse integration evidence, or a clear statement that it remains unverified.
6. Coworker clean-clone acceptance result.
7. Shared-skill-first acceptance result.
8. Security/public-file review findings.
9. Remaining risks or owner decisions.
10. Recommended pull-request and release/versioning steps.

Do not describe an untested capability as complete.
