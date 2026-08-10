# Validation 0296: Dynamic Residency R9 Hostile Review Rejection

Status: exact R9 architecture rejected; no machine-IR, freeze, or proof credit

Date: 2026-08-09

Work record: `N-197`

Requirement: `RESIDENCY-DYN-001`

## Exact Input

```text
reviewed Analysis 0208 raw SHA-256:
  f7e9f3df695af3015681da99a48bffcc44fe916588da66230fff82be5b411362

canonical review synthesis:
  Analysis 0209
  dynamic-residency-r10-pre-ir-hostile-review-rejection-v1.json
```

## Independent Review Result

All four read-only reviewers verified the exact target and returned both
`IR_ENCODING_READY=NO` and `FREEZE_NO`:

```text
authority and activation:             20 raw findings
distributed failure and transfer:     15 raw findings
formal semantics and IR readiness:    34 raw findings
system goal and composition:           9 raw findings
total:                                78 raw findings
normalized R9-local blockers:         42
```

The machine disposition preserves all 78 raw IDs and maps each one to one or
more of the 42 canonical blockers. It also verifies group cardinality:

```text
closed machine boundary:                         14
authority, lifecycle, scheduling, and execution: 17
publication, failure, transfer, time, and GC:    11
total:                                           42
```

## Why R9 Is Not A Closed Model

R9 improved the architectural vocabulary and exposed many of the correct
objects, but its exact reviewed bytes are still a design inventory rather than
a transition system. The action rows list cell kinds instead of concrete
locations and omit guards and effects. The immutable schema names omit fields
and object existence. Provider relies and invariants are prose rather than
typed formulas. Several causal and ownership contradictions are structural:

```text
DispatchSnapshot refers to RootSlotClaimID before allocation
attempt allocation has two competing roots
Ready Consumed is both derived and mutable
writer declarations disagree with action writers
Vacant transaction slots are indistinguishable from started transactions
five crash cuts retain multiple recovery successors
root-frame recurrence has no start transition
publication and admission do not have complete sealed lifecycles
```

These cannot be repaired by an encoder without choosing new behavior. The
formal model must validate a frozen architecture, not silently complete it.

## Successor Acceptance Boundary

R10 must make a typed machine IR the normative source and generate review
documentation from it. At minimum it must pass all of the following before a
new hostile freeze review:

```text
strict schema and duplicate-key rejection
finite typed state universe and exact Init
complete immutable-object and reference-edge registry
location-level unique writer and single-shard checks
fully expanded action guards/effects/frames
deterministic transaction and crash recovery checks
causal identity-allocation checks
authority, budget, and service-carry conservation checks
provider-formula typing and finite joint witness
invariant/action coverage and proof-DAG checks
negative mutations for every closure family
```

The architecture decisions in Analysis 0209 are successor requirements, not
evidence that R10 already exists or is correct.

## Decision

```text
R9_candidate_rejected = true
R9_IR_encoding_ready = false
R9_architecture_frozen = false
R10_machine_architecture_written = false
R10_machine_IR_validated = false
tla_authorized = false
model_supported = false
hypervisor_level_protection_evidenced = false
performance_or_cost_efficiency_evidenced = false
multi_cluster_correctness_evidenced = false
Linux_compatibility_evidenced = false
deployment_ready = false
```
