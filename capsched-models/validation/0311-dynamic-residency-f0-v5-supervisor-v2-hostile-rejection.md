# Dynamic Residency F0 v5 Supervisor v2 Hostile Rejection

## Result

Three fresh read-only local reviews reproduced Validation 0310 and rejected its
use as operational-LTS, semantic-verdict, Linux-refinement, or assurance evidence.
The exact classifier and 97 mutation cases remain reproducible, but their credit
is restricted to normalized truth-table and snapshot-drift regression.

## Blocking Validation Gaps

```text
executable Init/Next effects:             absent
reachable-state exploration:              absent
derived quiescence:                       absent
order-preserving trace execution:         absent
raw receipt normalization:                absent
producer/checker lifecycle separation:    absent
completion/quota linearization:            absent
evidence/decision/publication separation: absent
external owner and replay barrier:         absent
Linux refinement proof:                   absent
```

The reviews supplied concrete early-quiescence, wait-overwrite, quota-laundering,
ledger-after-seal, candidate-as-Success, cross-role, and publication-replay
counterexamples. Therefore `fresh_hostile_review_complete` must not be flipped
to true: the review was performed and its disposition is reject.

## Nonclaims

No v2 local pass issues `ValidationContextDigest`, closes the five-way taxonomy,
validates evaluator semantics, proves checker soundness, selects a Linux
mechanism, changes Linux behavior, accepts F0, completes G0, or supports a
protection claim.
