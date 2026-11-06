---
description: "Keep application-specific development out of the reusable Power Platform starter."
applyTo: "**"
---

# Repository Ownership

This repository owns reusable skills, framework code, templates, installers,
generic tooling, and non-application-specific tests. Federal FOIA application
code, architecture, configurations, integrations, tests, and documentation belong
only in `https://github.com/bradlaw76/FOIA`.

- Verify the Git root, branch, and origin fetch/push URLs before source-control
  operations. Do not repoint a starter checkout to move application work.
- Follow [repository ownership](../../docs/repository-ownership.md) and run
  `pwsh -NoProfile -File .\scripts\ci\test-framework-ownership.ps1`.
- Preserve the frozen historical FOIA baseline pending a separately approved
  cleanup. Do not add or update FOIA application artifacts in this repository.
- Do not delete branches/files, change visibility, rewrite history, or merge a
  pull request without the appropriate separate approval.
- Preserve generic dependencies and other scenarios; never remove a shared
  helper merely because the dedicated FOIA application also uses it.
