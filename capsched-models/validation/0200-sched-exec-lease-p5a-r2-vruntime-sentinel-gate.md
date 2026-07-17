# Validation 0200: SchedExecLease P5A-R2 Vruntime Sentinel Gate

Date: 2026-07-13

Status: passed for source/representation/formal gate. No Linux patch, hot
field, runtime behavior, or protection claim is approved.

## Scope

Validate the representation correction in analysis/0154 after the 0013 layout
and disabled-overhead baseline:

```text
analysis/0154-sched-exec-lease-p5a-r2-vruntime-sentinel-gate.md
analysis/sched-exec-lease-p5a-r2-vruntime-sentinel-gate-v1.json
formal/0121-p5a-r2-vruntime-sentinel-gate-model/
validation/run-sched-exec-lease-p5a-r2-vruntime-sentinel-gate.sh
```

## Run

Command:

```text
RUN_ID=20260713T-p5a-r2-vruntime-sentinel-gate \
  validation/run-sched-exec-lease-p5a-r2-vruntime-sentinel-gate.sh
```

Result:

```text
status: passed
linux_commit: 077c948be39432971e7273b16b728172251129aa
linux_tree: 7ef04bf73d26b2813b10016b7eb342a618a66570
source_anchor_count: 16
source_anchor_failures: 0
literal_u64max_signed_delta: -101
literal_u64max_is_vruntime_infinity: false
explicit_validity_plus_wrap_min_required: true
safe TLC: 7 generated states, 6 distinct states, depth 6
unsafe expected counterexamples: 18
```

Output:

```text
build/source-check/sched-exec-lease-p5a-r2-vruntime-sentinel-gate/
  20260713T-p5a-r2-vruntime-sentinel-gate/result.json
```

TLC used the official TLA+ command-line tools release v1.7.4 from the local,
ignored `build/tools/tla/tla2tools.jar` path.

## Source Counterexample

Linux CFS vruntime comparison uses a signed wrapping delta. The validator
mechanically checked:

```text
(s64)(U64_MAX - 100) = -101
vruntime_cmp(U64_MAX, ">", 100) = false
```

A literal `U64_MAX` value therefore cannot stand for numeric infinity inside
the current EEVDF augmentation or eligibility arithmetic. The provisional
literal in analysis/0151 is superseded for future implementation contracts.
The historical record remains unchanged.

## Validated Representation

The gate requires:

```text
explicit valid/invalid tag outside the vruntime number
numeric minimum meaningful only while valid
numeric member ignored while invalid
wrap-aware vruntime minimum while valid
validity and minimum used as an inseparable pair
picker guards validity before vruntime_eligible()
final reached-entity Fresh check
curr checked separately from the rb-tree aggregate
group entity projects a child tree-or-curr Fresh witness
ancestor propagation under runqueue locking
full invalidation closure rather than enqueue/dequeue-only refresh
```

The explicit validity tag does not regress to a boolean-only summary. The
minimum vruntime remains necessary for EEVDF pruning order.

## Reconstruction Compatibility

Before this gate, the recreated replay tree was also targeted-build validated
inside the Apple Container arm64 VM:

```text
run_id: 20260713T140445Z
architecture: arm64
compiler: GCC 13.3.0
CONFIG_SCHED_EXEC_LEASE=n fair.o/core.o: passed
CONFIG_SCHED_EXEC_LEASE=y fair.o/core.o/exec_lease.o: passed
normal off/on layout-probe object absent: true
explicit layout-probe object: passed
probe_symbol_count: 24
```

That is cross-architecture build compatibility evidence only. Object sizes and
hashes are architecture/build-path dependent and are not compared to the
prior x86_64 ledger as byte-identity evidence.

## Unsafe Counterexamples

The 18 rejected families cover:

```text
literal sentinel
missing validity tag
trusting invalid numeric storage
valid summary without a numeric minimum
ordinary unsigned minimum
picker skipping validity
boolean-only summary
curr/tree collapse
missing group projection
missing rq-lock ownership
enqueue/dequeue-only refresh
unchecked source basis
missing layout baseline
Linux patch approval at this gate
runtime claim
protection claim
monitor call in picker
cost claim
```

## Non-Claims

This validation does not approve:

```text
Linux code changes
new hot scheduler fields
runtime behavior changes
accepting 0009-0012 as production design
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
performance or cost efficiency
deployment readiness
datacenter readiness
```

## Next

Create the P5A-R2 summary update-closure source map. It must map rb-tree
augmentation, current transitions, group projection, lifecycle, budget,
placement, throttle/refill, and future monitor-revoke events to exact lock and
propagation obligations before any behavior patch is drafted.
