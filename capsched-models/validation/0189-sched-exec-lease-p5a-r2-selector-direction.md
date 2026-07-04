# Validation 0189: SchedExecLease P5A-R2 Selector Direction

Date: 2026-07-04

Status: source/design gate recorded. No Linux patch is approved.

## Scope

Validate that analysis/0146 follows from the current Linux source shape and
from the blockers recorded in validation/0187.

Artifacts:

```text
analysis/0146-sched-exec-lease-p5a-r2-selector-direction.md
analysis/sched-exec-lease-p5a-r2-selector-direction-v1.json
```

## Source Checks

The current CFS selector uses an augmented rb-tree:

```text
__min_vruntime_update:
  linux/kernel/sched/fair.c:1246

min_vruntime_update:
  linux/kernel/sched/fair.c:1277

RB_DECLARE_CALLBACKS:
  linux/kernel/sched/fair.c:1301

__enqueue_entity:
  linux/kernel/sched/fair.c:1307
```

The current EEVDF picker uses subtree metadata to prune eligible candidates:

```text
EEVDF comment:
  linux/kernel/sched/fair.c:1430

min_vruntime pruning:
  linux/kernel/sched/fair.c:1501
```

The current code therefore supports the design conclusion that production
lease eligibility must be picker-visible before selection, not a post-filter
scan.

## Design Validation

The recorded candidate matrix rejects:

```text
post-filter fallback as production root
unbounded rb-tree scanning
single synthetic comm-prefix authority
caller-dependent policy lookup in tree metadata
unmodeled hot-layout changes
claiming broad scheduler coverage from ordinary-CFS fast path evidence
```

The recommended next step is:

```text
P5A-R2 selector model gate:
  Candidate A, picker-visible lease eligibility summary, constrained by
  Candidate C, future Domain/SchedContext outer selector.
```

This is a design target only. It does not authorize Linux code.

## Non-Claims

This validation does not prove:

```text
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
object/layout safety
fairness or latency correctness
cost efficiency
monitor enforcement
production protection
deployment readiness
datacenter readiness
```

## Next

Before another Linux behavior patch, create the P5A-R2 selector model gate. It
must define:

```text
pre-pick lease-pickable state
invalidation events
group hierarchy summary semantics
current entity handling
fail-closed settlement
cross-path exclusion/settlement
layout/object evidence requirements
cost/fairness validation requirements
```
