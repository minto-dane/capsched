# Dynamic Residency F0 v5 Supervisor v3 Draft-0 Hostile Rejection

## Status

The exact executable supervisor v3 draft-0 is locally rejected. It is retained
only as negative design evidence showing that adding guarded transitions and BFS
does not by itself establish containment, evidence authenticity, external
ownership, or semantic credit.

Reviewed bytes:

```text
capsched-models/validation/f0_supervisor_lts_v3_draft0_rejected.py
4249abd9942f158e5daba52d0f9166ca17e56b2029b4d427f938400f5683a6f8
```

The machine-readable disposition is
`dynamic-residency-f0-v5-supervisor-v3-draft0-hostile-rejection-v1.json`.

## Reproduced Reachability Result

For each of the `PRODUCER` and `CHECKER` roles, the exact snapshot reaches:

```text
states:                         10,648
edges:                          10,647
terminal states:                2,118
nonterminal deadlocks:             273
states with no path to terminal:   686
```

The 273 deadlocks collapse to four semantic shapes after receipt-history fields
are projected away. Resolution is permitted only while the leader is `EXITED`,
but reap, counter capture, and scope teardown can happen first. This makes normal
EOF/reap interleavings permanently lose their decision path.

The graph also enumerates trace prefixes rather than a quotient semantic state
space: receipt history gives every noninitial state one predecessor. No diamond,
confluence, or order-independence property follows from these counts.

## Independent Review

| Axis | Session | Disposition |
| --- | --- | --- |
| transition-system soundness | `019feb89-a286-7763-b147-717e82d24d18` | local advisory reject |
| hostile Linux containment | `019feb89-bdc3-7853-8873-27b6ded4ff9d` | local advisory reject |
| assurance ownership | `019feb89-d5b8-7ab2-8816-04d7a94d26a3` | local advisory reject |

All reviews were read-only and used the exact SHA-256 above. Agreement remains
local advisory evidence and is not an external R11/G0 review.

## Decisive Findings

1. Leader reap is treated as containment-subtree drain. Descendants, attach
   authority, hidden exit work, nested cgroups, and attachment races are absent.
2. `OFFLINED` is self-declared and conflates visible emptiness, no future attach,
   successful removal, hidden-work drain, CSS offline, and final release.
3. `SANDBOX_READY` assumes hostile code cannot run between charged creation and
   release, but no trusted-bootstrap boundary establishes that property.
4. quota is a supervisor-selected enum and `WAIT_QUOTA` is not a faithful Linux
   wait event or causal resource receipt.
5. receipt well-formedness checks only a string prefix. Unknown kinds, forged
   issuers, missing receipts, and unbound payloads can satisfy `type_ok`.
6. evidence has no immutable root, decision is not bound to a root, and issuer
   names are content rather than authority.
7. a fixed winner can be overwritten; ambiguity can be chosen without a causal
   conflict; raw observations and arbitration are not separated.
8. hostile receipt injections are helper functions outside `Next` and receive no
   reachable-state coverage.
9. the same orchestrator creates its own `EXTERNALLY_ISSUED` context, owner
   receipt, producer result, checker result, durable state, and publication.
10. producer and checker outcomes are unrelated enums. There are no distinct
    child RunIds, producer-root/checker-input binding, or child evidence roots.
11. owner and guardian failures are absent after context import, and publication
    has no external generation, anti-replay, rollback, or recovery semantics.
12. all 23 registry entries are shortened prefixes and exactly zero equal the 23
    reachable transition identifiers.

## Successor Obligations

The successor must not patch these defects with labels alone. It requires:

```text
actor-separated EnvNext, SupervisorNext, AdversaryNext, and StoreNext
externally issued parent RunGrant with epoch, nonce, policy/profile/context roots
distinct derived producer/checker RunIds and exact checker-input binding
typed hash-chained receipts with issuer authority and run/scope/subject binding
EvidenceWF and InstanceWF over directly constructed as well as reachable states
raw observations separated from an immutable arbitration winner
leader, subtree, attach closure, hidden-work drain, CSS offline, and release states
trusted bootstrap separated from hostile payload release
baseline/final resource values and explicit causal-attribution status
hostile and crash/recovery transitions included in the explored relation
one evidence seal, a bound decision capsule, and an external durable publication log
semantic projection, ordered history, commuting-diamond, and terminal-reachability checks
explicit unresolved Linux-only and monitor-backed refinement obligations
```

## Nonclaims

This rejection does not establish Linux containment, kernel-compromise
resistance, resource causality, checker soundness, external assurance, F0, G0,
semantic freeze, model support, or a protection claim. No Linux behavior changed.
