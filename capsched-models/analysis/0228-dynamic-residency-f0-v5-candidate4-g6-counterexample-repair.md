# Dynamic Residency F0 Candidate-4 G6 Counterexample Repair

## Status

The first Candidate-4 run that reached candidate execution finalized
fail-closed as `RAW_CAPTURE_INCOMPLETE`.  The root capture mechanism behaved as
designed; the child semantic model rejected an internally inconsistent action
effect declaration.  The exact rejected input remains preserved by Validation
0316.  The successor input set repairs the declaration, adds the reachable
counterexample to the fast regression, and requires a new G6 capture.

This does not close G6, enable G7, or change F0/R11/K0/protection status.

## Counterexample

The failing action was:

```text
F05-SPV3-ACTION-EFFECT:
OBS-032-DESCENDANTS-EXIT:hidden_work
```

The full graph reached an interleaving that the pre-full traces did not:

```text
leader exits
  -> a surviving descendant opens a new async reference
  -> hidden_work becomes ACTIVE
  -> the descendant exits
  -> OBS-032 moves hidden_work from ACTIVE to PENDING
```

`_action_semantics_wf()` and `next_states()` already required this transition.
`ACTION_WRITE_FIELDS` omitted `hidden_work`, so `_edge()` correctly rejected
the reachable edge.  Adding `hidden_work` to the action's permitted effect set
does not invent a transition or weaken a guard.  It makes the explicit effect
policy agree with the existing state transformer and exact action semantics.

The child fast regression now constructs this order directly and requires all
of the following:

- post-exit descendant-created async work is `ACTIVE`;
- descendant drain reaches `EXITED`;
- hidden work returns to `PENDING`;
- `OBS-032-DESCENDANTS-EXIT` explicitly declares the `hidden_work` write.

The successor child suite therefore reports 275 cases.  The historical 274
case checkpoint and its exact digests remain unchanged as predecessor evidence.

## State-Consistency Root Cause

The project state had a second, independent defect: schema constants, shell
checks, handoff prose, and planned-track text all repeated the same stale
`NOT_RUN`/clean-install-next assumption.  They agreed with one another but not
with the durable G6 result.  Syntactic freshness alone could not detect that
semantic drift.

The repair keeps the existing `check-current-state.sh` as the sole public entry
point and adds one semantic layer beneath it.  The new layer:

1. separates the immutable historical 274-case checkpoint from the current
   repaired 275-case input set;
2. records G6 attempts as typed outcomes instead of an ambiguous boolean;
3. derives the G1-G7 partition from the capture contract;
4. cross-checks final-plan claim statuses against the assurance register;
5. binds the current exact-input and G6-observation files by SHA-256;
6. enforces G6/install/G7 phase implications;
7. compares a structured handoff projection exactly with `state.json`;
8. runs hostile self-mutations for the previously observed drift classes.

README, index, and plan files no longer duplicate volatile campaign facts.
They point to the canonical state and handoff projection.  Historical analysis,
validation, and event records retain the facts true at their publication time.

## Boundaries

The repaired fast path is local EC0 regression evidence only.  A bounded prefix
smoke can show that the old immediate exception is gone, but only a new
authority-disjoint complete capture can close G6.  G7 remains blocked until
such a capture has a durable complete commit marker.  No Linux behavior,
Monitor behavior, performance path, or production protection claim changes.
