# Validation 0294: Dynamic Residency R7 Pre-IR Hostile Rejection

Status: exact R7 pre-IR architecture rejected; no IR or freeze credit

Date: 2026-08-09

Work record: `N-193`

Requirement: `RESIDENCY-DYN-001`

## Exact Input

```text
reviewed Analysis 0204 raw SHA-256:
  6d08ec4371c8832ff413626fcbb804eb157e3ebc555d7d4ef7d79fe45a97e8ec

canonical review synthesis:
  Analysis 0205
  dynamic-residency-r8-pre-ir-hostile-review-rejection-v1.json
```

The later status notice in Analysis 0204 changes the current file digest but
does not change the reviewed bytes. The exact reviewed digest above remains
the immutable negative-evidence target.

## Review Result

Four independent read-only hostile reviews returned `FREEZE_NO`. The machine
disposition contains 41 distinct finding IDs in five groups:

```text
authority and activation:            12
publication and failure:              8
time, transfer, and connectivity:     7
progress, scale, and cost:             6
formal semantic IR:                    8
total:                                41
```

The findings reject faithful IR encoding because an encoder would still need
to invent authority ordering, mutable-cell ownership, entry/revocation
linearization, crash outcomes, lost-effect policy, bounded recurrence,
progress ranks, or complete `Init`/`Next` semantics. Encoding R7 as written
would therefore formalize one implementer's unstated choices rather than the
reviewed architecture.

## Fixed Successor Boundary

Analysis 0205 fixes the minimum R8 direction without accepting R8:

```text
early staging transaction identity before any staging receipt
preexisting ActivationInputCore and exact receipt transcript
one constant-size physical EntryOutcomeCell as execution truth
one runtime stop generation and stop/acknowledge/settle handshake
sealed multi-scope enrollment and commit-visible CAS
generation-checked failure-root append and late-merge invalidation
replicated execution fence before physical entry for strong transfer safety
LOCAL_ONLY source loss only through ContinuityLost/new incarnation
ClosedPrefix plus bounded live/uncertain suffix
static DomainContextCapsule separated from per-use context snapshots
clean closed type/state/action/proof/claim registries before TLA+
```

These are successor requirements, not proof that the requirements are jointly
consistent or sufficient.

## Decision

R7 is retained as a rejected design and counterexample source. It may not be
used as the normative machine IR, TLA+ input, architecture freeze candidate,
or protection evidence. R8 must be written as a clean semantic architecture,
receive a fresh hostile review, and close every resulting blocker before IR
encoding begins.

```text
R7_candidate_rejected = true
R7_IR_encoding_ready = false
R8_architecture_reviewed = false
architecture_frozen = false
tla_authorized = false
model_supported = false
hypervisor_level_protection_evidenced = false
performance_or_cost_efficiency_evidenced = false
multi_cluster_correctness_evidenced = false
Linux_compatibility_evidenced = false
deployment_ready = false
```
