# H009 - Wizard Version and Update Manager

Authority: issue #14, design PR #15 at
`5098769d2786fbf366b8e2e8ecb7fd8912bd84ce`, Q14 execution authorization.
Base: merged main `57f54fbf6b2c88e391100c001ba0b3f8834e190b`.

## Accepted requirements

- H009-VERSION: distribution identity separate from profile, contract and script;
  unreleased checkout reports unknown release without blocking discovery.
- H009-DISCOVERY: offline by default, explicit bounded stable-only online lookup;
  unavailable trust is unverified, never a claimed official update.
- H009-CHOICE: shared Review changes / Update wizard / Skip for now actions;
  Skip is session-only and continues unchanged.
- H009-SCOPE: classify runtime clone, application, copied/installed skill and
  mixed/unknown; exact allowlisted ownership, never application/secret/instruction
  overwrites, automatic removals or arbitrary release scripts.
- H009-RECOVERY: exact plan approval, exclusive writer, durable backups/journal,
  selective writes, byte verification, fail-closed interruption recovery.
- H009-TRUST: official Apply stays disabled without approved independent
  publisher policy. Offline fixtures exercise the transaction, not deployment.
- H009-EVIDENCE: U01-U19 functional/negative checks on Windows and Linux where
  supported, actual terminal/shared agent command demonstrations, exact-head CI.

## Non-goals

No public version/tag/release, H-number, controller, service, tenant write,
security-setting change, H008 acceptance replay or legacy owner integration.
Do not change canonical audit status HANDOFF NOT WRITTEN - BLOCKED.
