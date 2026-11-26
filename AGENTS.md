<!--
COMPONENT: Wizard project instruction loader
FILE: AGENTS.md
VERSION: 1.0.0 (instruction standard, not a distribution release)
ENVIRONMENT: Local wizard/project workspace; no execution permission granted
-->
# Wizard execution instructions

Read the local [canonical execution policy](docs/policies/authorization-and-execution.md)
before acting. If it is missing or has not actually been loaded, do not claim
policy inheritance or execute the affected operation. This file is a loader,
not a second policy. Preserve project-specific requirements and stricter
security policies, including custom instructions outside framework-owned text.
Load applicable existing project instructions, including CLAUDE.md and custom
Copilot instruction files when present; this loader cannot supersede them.

Routine authorized nonproduction corrections reuse accepted requirements:
Build -> Deploy only within actual scope -> Verify -> Correct -> Continue ->
Document. Do not regenerate complete planning packages. Significant new features,
security and architecture changes retain affected planning and safety gates.

Use scenario-level Spec Kit artifacts and the applicable
[onboarding contract](docs/onboarding.md). For authorized independent work, use
[existing queued delivery](docs/QUEUED_AUTONOMOUS_DELIVERY.md).
Instruction adoption is not runtime installation, release verification,
deployment permission or native acceptance.
