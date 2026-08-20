# Dynamic Residency F0 v5 Supervisor v2 Hostile Rejection

## Status

The exact supervisor v2 snapshot is locally rejected as an operational protocol
or semantic-verdict boundary. Its finite truth table and mutation regression are
retained as limited negative-design input. This disposition does not grant an
external review role, F0, G0, Linux refinement, or protection credit.

The machine-readable disposition is
`dynamic-residency-f0-v5-supervisor-v2-hostile-rejection-v1.json`.

## Exact Reviewed Snapshot

```text
0223-dynamic-residency-f0-v5-supervised-evaluation-protocol-v2.md
  992e9877b3a0f63025017041e95b82cd3d593510f07d11abacfa704d70b5583b

dynamic-residency-f0-v5-supervised-evaluation-protocol-v2.json
  b92b3bb1794555366f5e89283a54fd33611dff742de095c14f861a360e90d695

validate-f0-supervisor-protocol-v2.py
  5d689ad5711f423d2c47136ed833f407a9c2ba0cdb8aed55bcca83ab093f9e9d

test-f0-supervisor-protocol-v2-mutations.py
  fd4ce236acb2c1140dc1bb8e3c462eee48aecc3cc753d3d2e4179b2e16625209
```

The reviewed bytes remain unchanged. Validation 0310 therefore remains an exact
record of what passed locally, while this record limits the meaning of that pass.

## Review Provenance

| Axis | Session | Result |
| --- | --- | --- |
| executable LTS, reachability, and ordering | `019feb74-9d2c-73b1-838b-e09c08afb9cc` | local advisory reject |
| Linux containment and causal receipts | `019feb74-dc7f-7180-b03f-6118a81857ac` | local advisory reject |
| external ownership and semantic credit | `019feb75-11d1-70a1-b3d7-c94a1e50dd09` | local advisory reject |

Each review was read-only. All three reproduced the exact v2 hashes, the 82,944
classifier products, and the 97/97 mutation result. Agreement is still local
advisory evidence, not F3 external assurance.

## Decisive Rejection

The 21 transition rows are not an LTS. They contain no guards or effects for
worker, scope, stream, wait, quota, counters, fault, receipt ledger, decision, or
publication. The validator compares rows to a duplicate constant and enumerates
an unconstrained final-coordinate Cartesian product. It never computes
`Reachable(Init,Next)`.

Consequently, v2 does not exclude:

```text
QUIESCENT with worker RUNNING or scope POPULATED
PUBLISHED with decision NONE
ABANDONED with publication PUBLISHED
two different wait or quota observations overwriting one another
GENESIS_BOUND -> OBSERVATIONS_CLOSED -> QUIESCENT without cleanup evidence
```

The observation-order check converts both traces to sets before reducing them.
It assumes the commutativity under test. It also derives a valid typed receipt
and supported checkpoint from a frame-candidate event without a checker event.

## Semantic-Credit Error

The prose says a transport-valid frame is only a candidate. The classifier
nevertheless returns semantic `SUCCESS` from a candidate frame, Boolean typed
receipt, and checkpoint. No proof bytes, theorem/scope/premise digests, checker
soundness statement, externally issued validation context, or owner acceptance
is present. Candidate disposition and externally credited verdict must be
different types and different state machines.

Producer and independent checker also lack separate scopes, quotas, streams,
child RunIds, and lifecycle receipts. The current model either lets the producer
validate itself or leaves the checker unsupervised.

## Evidence and Linearization Errors

The evidence ledger is declared sealed before classification, but two transitions
issue seal receipts and later transitions append classification and publication
receipts to the same inventory. v3 must use:

```text
immutable evidence-prefix ledger, sealed once
decision capsule, binding that sealed evidence root
monotone publication log, binding the decision capsule
```

Quota classification also remains noncausal. A complete Success, Reject, or
Internal frame followed by quota stop becomes Resource, and contradictory frame
and checkpoint pairs can be Resource. The protocol needs one explicit
linearization winner and a normalization function that makes contradictory raw
receipts a sticky fault before classification.

RunId, guardian, policy, and issuer strings are content fields, not authority.
There is no externally owned namespace, rollback-resistant issuance, per-receipt
issuer matrix, authenticity relation, used-RunId set, consumer challenge, or
publication rollback protection. Replaying a complete old capsule preserves its
hash chain.

## Linux Refinement Corrections

An empty cgroup is not necessarily closed to future attachment. The abstract
scope needs a separate `OFFLINED` or no-longer-attachable state. On the inspected
kernel, successful cgroup removal is a possible refinement candidate because it
marks the cgroup dead and prevents new migration or child creation, but no such
mechanism is selected or proved here.

`CLONE_INTO_CGROUP` is a useful charged-launch candidate, while pidfd, `cpu.max`,
`memory.max`, OOM counters, populated-zero, and seccomp each provide only part of
the abstract contract. Exact kernel revision/configuration, hierarchy ownership,
scheduler class, syscall filter, executable/loader/module closure, and causal
counter interpretation remain validation-context inputs and proof obligations.

## v3 Gate

The successor must provide:

1. executable `Init`, guarded/effectful `Next`, `TypeOK`, and reachable-state
   exploration over every state coordinate;
2. raw typed receipt schemas, issuer matrix, complete RunId/context binding, and
   deterministic normalization to sticky evidence state;
3. separate producer and checker child runs under one externally issued parent
   run namespace;
4. separate candidate transport disposition and semantic-credit verdict types;
5. a completion-versus-quota linearization winner and contradiction predicate;
6. derived quiescence requiring leader reap, stream EOF, final counters, scope
   drain, and scope offlining;
7. immutable evidence, decision, and publication chains with one seal each;
8. an outer lifecycle owner, guardian/supervisor crash transitions, and
   `PREPARED -> DURABLE -> PUBLISHED` recovery semantics;
9. order-preserving interleaving exploration rather than set reduction;
10. precise labels: classifier Cartesian enumeration and drift mutations, not
    generic machine exploration or semantic validation.
