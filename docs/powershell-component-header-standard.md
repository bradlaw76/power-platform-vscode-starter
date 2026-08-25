# PowerShell Component Header Standard

**Status:** Draft
**Version:** 0.1.0
**Last Updated:** 2026-07-19

## Purpose

Adapt the SpeckKit `component-header-block` standard for PowerShell scripts in this repository.

## When To Use

- Use on repo-owned PowerShell scripts that implement a discrete workflow, helper, validation step, or test.
- Place the block at the top of the script before any executable statements.
- Keep existing PowerShell comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`) when it already exists.

## Template

```powershell
<#
=============================================================================
COMPONENT:    [Script or Helper Name]
FILE:         [repo-relative path]
VERSION:      X.Y.Z
AUTHOR:       [Owner or Team]
LAST UPDATED: YYYY-MM-DD
ENVIRONMENT:  PowerShell 7 | PAC CLI | Dataverse Web API | VS Code

-----------------------------------------------------------------------------
OVERVIEW
-----------------------------------------------------------------------------
[1-2 sentence description of what the script does and why it exists.]

-----------------------------------------------------------------------------
ARCHITECTURE
-----------------------------------------------------------------------------
- Role:            [bootstrap step | helper module | validation | CI test]
- Inputs:          [main parameters, files, or environment assumptions]
- Outputs:         [artifacts, state changes, console output]
- Dependencies:    [other scripts, modules, tools]
- Side Effects:    [files written, external APIs called, auth required]

-----------------------------------------------------------------------------
PREREQUISITES
-----------------------------------------------------------------------------
1. [Required tool, file, environment variable, or authentication precondition]
2. [Additional prerequisite]

-----------------------------------------------------------------------------
TEST CASES
-----------------------------------------------------------------------------
✔ [Most important expected success path]
✔ [Important safety or idempotency check]

-----------------------------------------------------------------------------
CHANGELOG
-----------------------------------------------------------------------------
vX.Y.Z  YYYY-MM-DD  [Short, precise description of change]

-----------------------------------------------------------------------------
NON-NEGOTIABLES
-----------------------------------------------------------------------------
- Do not bypass repo workflow gates captured in docs/onboarding.md.
- Keep script behavior idempotent where the step is designed to be rerunnable.
- Update this header when the script's contract materially changes.
=============================================================================
#>
```

## Repo Guidance

- Prefer concise, accurate entries over exhaustive prose.
- If a script already has strong inline help, the SpeckKit block should summarize contract and behavior, not duplicate every detail.
- Use this standard for PowerShell scripts in `scripts/bootstrap`, `scripts/bootstrap/helpers`, and other repo-owned automation surfaces when the header adds durable context.
