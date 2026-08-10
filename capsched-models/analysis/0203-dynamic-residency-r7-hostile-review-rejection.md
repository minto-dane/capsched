# Analysis 0203: Dynamic Residency R7 Hostile Review Rejection

Status: exact R6 v2 successor rejected; `FREEZE_NO`; R7 semantic IR required

Date: 2026-08-09

Work record: `N-191`

Requirement: `RESIDENCY-DYN-001`

Machine disposition:
`analysis/dynamic-residency-r7-hostile-review-rejection-v1.json`

## Reviewed Snapshot

Four independent read-only reviews examined runtime authority, distributed
failure and transfer, formal readiness, and datacenter composition. Their
common verdict is `FREEZE_NO`.

```text
human R6 draft:
  fef2d146331e549ab052a57710fae207eba456b2c2d346092df3dc0155c89449
R6 semantic overlay:
  468cd739f64a44b1887c6f40eebb6bf8f466542d498e72457254e8dbe753bda1
materialized R6 v2 contract:
  24887ac27772dc131b91a7f87ff57203ab71cf883ff2769fc0df40bb941fa62d
assurance v3:
  702b6cf2d69a1c61586ae298362d79fc794a8bf48ae57dd60f059a1185aa75f6
```

The R6 materializer remains reproducible. That fact does not rehabilitate the
semantics. After a proof-node rename, strict validation correctly fails because
the recursive merge retained the old ledger key; the mutation suite therefore
cannot establish a passing baseline either.

## Why R6 Fails

The decisive defect is that prose field references and the hand-authored
authority DAG disagree. `NormalizedAuthorityHorizonVector` names the later
`RequiredActivationReceiptSet`, while a connectivity certificate in the vector
is bound to a later use cell. Adding the real field dependencies creates two
cycles. The same pattern appears in `ActivationIntent`, which names a future
`ExecutionContextCore` while the DAG places the intent first.

The initial-entry predicate is also contradictory: `TokenExecutable` is
post-entry, yet one clause requires it for initial entry while the intended
rule consumes only `PreEntryPermit`. Attempt ordinals lack an allocation CAS,
DecisionCell/RunToken binding does not distinguish stable cell identity from a
mutable version, and prepare/entry crash cuts can leave orphaned or dirty state.

Distributed protocols remain assertions rather than complete state machines.
Publication enrollment does not linearize with close, commit does not share a
decision cell with closure-forced abort, high-water permits holes, two failures
can discover each other only after closing different gates, and restart does
not reconstruct the new closure state. Transfer lacks exact unknown-suffix
objects and a consumed-predecessor cell, while connectivity consumption is not
atomic with the bound operation.

The proof DAG has the right broad order but not the information needed for a
faithful TLA+ translation. Its rows do not instantiate the declared variable,
owner, action, formula, read/write, crash, rank, refinement, and claim schema.
No executable `Init`/`Next` precursor exists. Consequently, translating now
would invent semantics rather than formalize a frozen design.

## Closure Scopes

The machine disposition separates two obligations deliberately:

```text
R7 local semantic IR:
  must close authority, activation, publication, failure, transfer,
  connectivity, lifecycle, liveness, proof-ledger, and validator blockers

system-completion successors:
  must refine physical ENTRY/CODE/STATE/device truth, mutable-state closure,
  process-to-container granularity, cluster/quorum/time producers, Monitor TCB,
  steady-state metadata, cost vectors, Linux behavior, and restart blast radius
```

The second set may remain typed external interfaces while R7 closes B2b, but it
may not be counted as hypervisor-level protection, datacenter cost efficiency,
multi-cluster correctness, or complete model support.

## R7 Construction Rule

R7 must introduce an executable semantic IR before TLA+:

1. Exact object schemas generate every immutable dependency edge; generated
   edges must equal the declared acyclic construction graph.
2. Every mutable field has one writer authority. Every action has exact reads,
   writes, guard, update, atomic group, crash class, abstraction action, and
   rank delta.
3. Attempt allocation is a durable DecisionCell CAS. At most one nonterminal
   attempt and one bound use cell exist for an attempt.
4. Pre-entry source cores are separated from post-install receipts. A final
   entry horizon is derived only after exact receipts without feeding an
   ancestor object.
5. Prepare and entry use explicit non-executable transactions and one protected
   commit gate. Every crash cut either recovers the same identity or reaches a
   typed safe abort/stop without minting authority or budget.
6. Publication enrollment and scope close share a linearization relation;
   commit and abort share one outcome cell; reverse-log closure requires a
   durable no-hole terminal prefix; overlapping failures deterministically
   merge or order.
7. Calendar, LeaseClock, and destination time are distinct typed domains. Only
   an exact direct current relation permits arithmetic across them.
8. Transfer consumes one predecessor decision cell, defines activation plus
   settlement unknown suffix exactly, and maps every safe-gap nonservice result
   to an authenticated claim-excluded external withdrawal or records an
   internal liveness violation.
9. Concrete lifecycle abstraction is a total executable function. Every lower
   action simulates one abstract action or a named stutter.
10. Protected work reservations name exact work items and finite rank changes;
    internal stuttering and unexplained fail-stop cannot discharge liveness.
11. Every validator obligation has a stable ID, representation and behavioral
    mutants, plus validator-gate mutants that must be killed.

## Claim Boundary

```text
R6_v2_accepted = false
R6_witness_accepted = false
R7_semantic_IR_written = false
architecture_frozen = false
tla_authorized = false
tla_written = false
model_supported = false
hypervisor_level_protection_evidenced = false
performance_or_cost_efficiency_evidenced = false
multi_cluster_correctness_evidenced = false
deployment_ready = false
```
