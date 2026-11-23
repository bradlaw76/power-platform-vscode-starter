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
