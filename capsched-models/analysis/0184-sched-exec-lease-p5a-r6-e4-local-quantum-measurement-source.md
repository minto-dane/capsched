# Analysis 0184: SchedExecLease P5A-R6 E4 Measurement Source

Date: 2026-07-29

Status: exact disposable source candidate. Source acceptance remains blocked on
the source gate and the full R6-E3 four-profile regression.

## Exact source identity

The candidate is the required direct child of the accepted R6-E3 source:

```text
parent:  99287291f1c8e0d6c1b3ea86d121508c5547f424
commit:  d51ebdc657a1040e423735584775e66399f321f9
tree:    0847c408be82e6c9077c2edd2d00f44ccfbe18fc
branch:  codex/p5a-r6-e4-local-quantum-measurement

changed files:
  init/Kconfig
  kernel/sched/exec_lease.c
```

The binary diff SHA-256 is
`fcc00bcf8dabf4ee8d921a454b7ee871e907da5accefaab10f320f08ff4283d9`.
The candidate is signed off and published only as a disposable fork branch.
Primary Linux and the patch queue remain unchanged.

## Configuration and attachment boundary

`CONFIG_SCHED_EXEC_LEASE_R6_MEASURE_KUNIT_TEST` is default-off, depends on the
default-off R6 correctness suite and `KUNIT=y`, and registers only the private
same-translation-unit `sched_exec_lease_r6_measure` suite. Ordinary lease
support, the layout probe, the E3 suite, and `KUNIT_ALL_TESTS` do not enable
it.

The source adds no public header, exported symbol, live scheduler caller,
`pick_eevdf()` change, scheduler hook, CPU-hotplug registration, tracepoint,
filesystem surface, netlink family, device, userspace ABI, monitor call,
policy decision, admission, or denial path. With E4 disabled, its symbols,
relocations, strings, initcalls, timestamp calls, raw rows, and result rows
must all be absent.

## Shared E3 operation boundary

The measurement suite invokes the same E3 aggregate, candidate, leaf-to-root,
reconciliation, final-task, current-observation, and offline-drain operations.
It does not introduce cheaper timing substitutes. To make lock and operation
counting exact, the candidate factors locked portions out of the existing
reconciliation, current, and offline helpers and adds counted descriptor/task
validation. E3 callers continue to use those helpers.

Because shared helpers changed, all four E3 diagnostic profiles and their 55
cases, 220 receipts, 4,096 stress repetitions, cleanup equations, and
independent oracle checks must pass again before E4 source acceptance.

## Measurement evidence implementation

The nine KUnit cases generate the exact Cartesian matrix:

| Family | Cells |
| --- | ---: |
| descriptor publication | 135 |
| leaf plus six ancestors | 80 |
| aggregate | 45 |
| candidate | 180 |
| complete query | 45 |
| mask reconciliation | 120 |
| selected-slot handoff and final task check | 96 |
| revoked-current request and observation | 54 |
| offline visibility and drain | 100 |
| **Total** | **855** |

Each cell uses 256 warm-up pairs and 10,000 recorded alternating
treatment/control pairs. Both sides use the same raw-lock, IRQ, timestamp, and
compiler-barrier shell. The treatment operation count must equal its untimed
preflight result; the control count must be zero. Clock regression, observed
vCPU migration, state mismatch, missing availability observation, or operation
count mismatch is a harness failure.

The suite emits every exact
`control_ns,treatment_ns,additional_ns,availability_ns` row before sorting.
The additional value is `max(treatment-control, 0)`. Summary statistics use
documented nearest-rank minimum, p50, p95, p99, p99.9, and maximum. Printing,
sorting, assertions, rescheduling, preparation, cache perturbation, RCU grace
periods, and cleanup remain outside local measured intervals.

Ordinary `pick_eevdf()` is unchanged baseline work outside the R6 interval.
The selected-slot case measures only the final constant-shape
initialized/accepting/selected-slot/descriptor/generation/domain/root/mask/CPU
check.

## Preliminary compiler evidence

Before freezing this record, fresh arm64 and x86_64 E4-enabled W=1 object
builds completed with no compiler diagnostic. A separate arm64
E3-enabled/E4-disabled build contained zero E4 symbols or strings. Strict
checkpatch reported 0 errors, 0 warnings, and 0 checks.

These checks are development evidence only. The canonical source gate must
rebuild all disabled, enabled, and release profiles from fresh output
directories, retain the object/config/compiler evidence, and reject any
diagnostic.

## Refreshed upstream boundary

Torvalds upstream advanced 48 commits from
`f5098b6bae761e346ebcd9da7f95622c04733cff` to
`fc02acf6ac0ccde0c805c2daa9148683cdd01ba8`. Neither candidate path changed in
that interval. The merge base remains
`4edcdefd4083ae04b1a5656f4be6cd83ae919ef4`.

This is exact two-path drift classification, not a global freshness claim.

## Claim boundary

This candidate is not a measurement result. It does not establish R6
correctness, latency compatibility, runtime denial, runtime coverage,
bare-metal behavior, monitor delivery, async/service behavior, MemoryView/TLB
behavior, DMA/IOMMU behavior, cluster authority, performance, cost,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness.

The only next activity is the exact source gate. A passed source/build gate may
authorize only the full E3 four-profile regression against this same source.
Measurement remains blocked until both gates pass and are independently
closed.
