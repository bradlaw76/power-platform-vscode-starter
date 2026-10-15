# FAST Disable, Retirement, and Rollback Strategy

**Status:** FAST-001 architecture decision input  
**Last updated:** 2026-10-15

## Objectives

FAST must remain an optional accelerator provider. The original wizard must
continue operating when FAST is disabled, unavailable, retired, removed, or
rolled back. Disabling FAST is not authorization to remove managed solutions or
customer data from Dataverse.

## Operational disable

The planned central capability flag is `FAST_ENABLED`.

| Value | Required behavior |
| --- | --- |
| Absent or `false` | Do not load the FAST provider, schedule synchronization, make FAST network calls, match requirements, show FAST choices, or generate FAST-dependent plans. Continue through the unchanged custom-only wizard. |
| `true` | Register the FAST provider, but use only a promoted, validated catalog snapshot for recommendation or generation planning. |

The flag belongs at the provider-registration boundary, not inside each
consumer. No discovery, planning, or build script may directly import the FAST
implementation. A future dynamic configuration mechanism may avoid process
restart; until one exists, changing the environment or profile flag requires a
new wizard invocation and must be documented as such.

## Source outage

1. Synchronization writes to a candidate snapshot, never the promoted snapshot.
2. A partial or invalid candidate is rejected.
3. If a promoted snapshot exists, matching may continue only when policy allows
   offline use and the user sees its age and source state.
4. If no valid snapshot exists, the provider reports unavailable and the
   wizard continues custom-only without an extra mandatory question.
5. Existing runs remain pinned to their recorded snapshot and are never
   silently upgraded.

## Provider removal or source retirement

- The provider registry can omit FAST without changing requirements parsing,
  architecture comparison, or custom generation.
- Historic decision records, source attributions, manifests, and snapshot IDs
  remain readable.
- Synchronization is disabled and retirement is surfaced as provider health,
  not as an empty catalog.
- Existing generated custom solutions are not rewritten.
- Removing FAST code never uninstalls FAST Core or specialty managed solutions.

## Code rollback

The known-good recovery point is:

```text
Tag: pre-fast-20261015
Commit: 17bebe3fb2322c2ad07c05dec8ef0c64dba6df28
Remote backup: backup/pre-fast-20261015
```

For a new recovery branch:

```powershell
git fetch origin --tags
git switch -c recovery/pre-fast-20261015 pre-fast-20261015
```

Normal review and deployment controls still apply. Do not force-reset a shared
branch. Revert FAST commits or deploy a reviewed recovery branch according to
the repository's pull-request policy.

## Catalog rollback

- Promoted snapshots are immutable and content-addressed.
- Promotion records the previous promoted snapshot.
- Rollback changes the provider's promoted snapshot pointer only after review.
- Candidate, rejected, and retired snapshots remain auditable.
- A snapshot rollback does not mutate scenario decisions already pinned to
  another snapshot.

## Dataverse recovery boundary

Feature disable, code rollback, and catalog rollback do not remove Dataverse
components. Any uninstall of FAST managed solutions is a separate destructive
operation requiring:

- an authorized nonproduction rehearsal;
- dependency and data-loss analysis;
- explicit environment-owner approval;
- normal organizational change control;
- a separately tested backup and recovery procedure.

FAST automation must never perform managed-solution uninstall as a rollback
side effect.

## Required regression matrix

| Condition | Expected result |
| --- | --- |
| FAST disabled | All three current wizard modes and custom-only planning pass with no FAST calls or prompts |
| Provider assembly absent | Base wizard starts and runs without import/load failure |
| FAST source unreachable, promoted snapshot allowed | Matching uses the pinned snapshot and displays freshness |
| FAST source unreachable, no snapshot | Provider unavailable; custom-only flow continues |
| Candidate catalog invalid | Candidate rejected; last known-good snapshot remains promoted |
| FAST source retired | Sync disabled; historic evidence retained; custom-only flow continues |
| FAST selection rejected | ADR records custom-only decision; no FAST-dependent generation |
| FAST code reverted | Baseline mode, idempotency, and export tests remain equivalent |

