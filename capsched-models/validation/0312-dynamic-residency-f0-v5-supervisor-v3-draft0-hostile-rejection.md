# Dynamic Residency F0 v5 Supervisor v3 Draft-0 Hostile Rejection

## Result

The exact draft-0 SHA-256
`4249abd9942f158e5daba52d0f9166ca17e56b2029b4d427f938400f5683a6f8`
compiles and executes, but fails its own reachable-state obligations and all
three independent local hostile-review axes.

```text
per-role reachable states:             10,648
per-role reachable edges:              10,647
per-role nonterminal deadlocks:           273
per-role states without terminal path:    686
declared/reachable exact action IDs:       0/23
```

## Disposition

The snapshot is retained as
`f0_supervisor_lts_v3_draft0_rejected.py`. Its only positive credit is that it
makes the previously missing guarded/effectful relation executable enough to
expose concrete counterexamples. It provides no containment, evidence,
ownership, liveness, Linux-refinement, semantic-verdict, F0, or G0 credit.

The successor must include actor-separated external events, typed run-bound
receipts, evidence and decision roots, immutable arbitration, decomposed scope
closure, hostile/crash actions in `Next`, child-run composition, durable external
publication, and exact action-registry coverage before another candidate review.
