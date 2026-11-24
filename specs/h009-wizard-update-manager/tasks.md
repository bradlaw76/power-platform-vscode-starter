# H009 canonical implementation tasks

These stable task IDs describe this source batch, not a second controller.

- H009-T01: reconcile issue/design/main/ownership; claim isolated branch.
- H009-T02: implement nullable distribution contract and offline startup display.
  Depends on T01.
- H009-T03: implement stable trusted discovery and topology reporting.
  Depends on T02.
- H009-T04: implement exact ownership-aware preview, explicit choice and
  fail-closed transaction/recovery. Depends on T03.
- H009-T05: align terminal, Copilot, Claude, contract and adoption documentation.
  Depends on T02 and T04.
- H009-T06: run U01-U19 Windows/Linux and complete required CI; repair bounded
  defects, preserve fixtures/evidence. Depends on T04 and T05.
- H009-T07: scoped commit/push, linked implementation PR and exact-head evidence;
  no merge under latest continuation instruction. Depends on T06.

Final completion states and command evidence are recorded in issue #14 and the
H009 report; source merge is not a distributed release.

## H009-09 through H009-12 follow-up

- H009-T08: finalize proposed release identity/attestation, registration,
  rotation/revocation and activation gates without enabling official Apply.
- H009-T09: explicit candidate distribution policy, exact Git-blob hash
  inventory/schema and negative tests. Depends on T08.
- H009-T10: reconcile each original requirement and record synthetic versus
  production, independently verified versus pending boundaries. Depends on T08.
- H009-T11: signed actual shared-command lifecycle, final exact-source Windows/
  Linux CI, inventory verification and serialized publication to existing PR16.
  Depends on T09 and T10. Preserve Q15 path fix and its separate evidence.

See `docs/wizard-release-readiness.md`, issue #14 and PR #16 for the single
follow-up closeout. No release, tag, merge, production activation or consumer
mutation is authorized.
