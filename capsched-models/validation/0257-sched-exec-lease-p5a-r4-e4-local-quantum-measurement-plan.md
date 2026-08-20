# Validation 0257: SchedExecLease P5A-R4 E4 Local-Quantum Measurement Plan

Date: 2026-07-18

Status: passed twice with normalized identity for the exact disposable R4-E4
two-file measurement source draft only. Measurement launch, E4 acceptance, R4
behavior source, and every runtime, production, and cluster claim remain
blocked.

## Scope

Validation binds analysis/0176 and formal/0139 to the exact post-N-135 gate,
candidate `da9ce915...`, primary and patch-queue identities, refreshed
Torvalds touched-path evidence, mandatory claim-ledger row, separate N-136
boundary, complete 682-cell matrix, fixed rejection limits, negative-evidence
classification, and explicit non-claims.

The runner is:

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r4-e4-local-quantum-measurement-plan.sh
```

Runner SHA-256:
`01e6e9b2c7ea8a2d34a4b935678889419f0185f692d217b31fef5e6ec4bfdf55`.

## Immutable Inputs

```text
plan JSON:                 63ba7b17c3d08ea1ee0cdd4b420cc3a08b21932e9f6c2fb3f31754147e5b1667
plan Markdown:             2475726afacd716db4bab475d16a5f5db9680f0dd5bb88e14dc23da3636ed347
formal manifest:           43d2252ed4ba3311ac598533934ec4af00fa608dfa85ccc616e47e5d288f07f4
post-N-135 gate JSON:      99d055aa02429c510f564fd02bb8f864f42a0603fc7e0a73e09fc13fc9532203
authorization r7:          160efd76ed083df880747685a861a1b920e5fa9a265a4946749f87da44e09d37
authorization r8:          d736b698cc056bea41d671c61b5c5a9a98024327642ff79c19f6dfb42f60f905
authorization normalized:  541d72676f97741c40ed3a50b4f524c63a9530fc9984bfc88ed6675415d1fb4f
candidate commit:          da9ce9159b3450c28c8faf8dceac671fb7bfeba2
candidate tree:            58c6510c6f517004e37107786d006bb8333b79b8
candidate diff:            096d99b527bd1b433ecd07165696830f9316d07cc67484687d95cd2c2a846f08
```

Every mutable file input was copied into a fresh non-symlink run directory,
verified against its exact hash, made read-only, and consumed from the
snapshot. The exact candidate files were materialized from the immutable Git
object rather than the working tree. Formal files were independently
manifested before and after snapshotting.

## Freshness

Torvalds master advanced from the post-N-135 observation
`1229e2e57a5c...` to `f2ec6312bf71...` by 22 descendant commits. The exact
candidate paths, `init/Kconfig` and `kernel/sched/exec_lease.c`, have zero
changes over that interval and zero changes from candidate merge base
`4edcdefd4083...`; the private source remains absent upstream. Candidate plus
refreshed upstream merge cleanly at tree `6c5fff5aaf6b...`.

This is a touched-path freshness result only. It does not claim that every
project source map is globally current.

## Canonical Results

Two independent serial runs used the final runner:

```text
run r2: 20260718T-p5a-r4-e4-local-quantum-plan-r2
result: 2cbfb567cda9f2588dfedb414a9f0e0ebf5f80b1bab341c783ff59eded91918b

run r3: 20260718T-p5a-r4-e4-local-quantum-plan-r3
result: 8f74506caec82d4984b91fdf066a4fe69253b189c20eecb749aa9b583bdfbe21

normalized after removing only run_id:
c6efaab079f90adda105ba781295a49e46f720a3366f26e16d1a03146b93a662
```

The normalized JSON documents are byte-identical. A preliminary r1 passed the
same contract before final ShellCheck cleanup changed the runner bytes; it is
not credited as canonical evidence.

## Contract Results

```text
source anchors:                  31, failures 0
future-source absence checks:     6, failures 0
preserved E3 case families:      36
mandatory claim-ledger fields:   14/14 exact keys
safe TLC:                         5 generated, 4 distinct, depth 4
unsafe expected counterexamples: 43/43
total future measurement cells: 682
measured pairs per cell:         10,000
total future measured pairs:     6,820,000
```

The exact future matrix is:

```text
publication critical section: 288 cells
picker mismatch + irq kick:    144 cells
hard-IRQ work dispatch:          9 cells
one-projection recovery:       144 cells
one notifier quantum:           48 cells
current request/observation:     24 cells
offline lock/drain:              25 cells
```

Fixed rejection gates are:

```text
local quanta:       p99 5,000; p99.9 25,000; max 50,000 ns
offline lock phase: p99 25,000; p99.9 40,000; max 50,000 ns
async calibration:  p99 10,000,000; max 100,000,000 ns
base-slice marker:  700,000 ns, never a budget or deadline
```

There is deliberately no publication-to-last-settlement wall-clock gate and
no global fanout benchmark. Recovery and notifier retain per-invocation work
counts of one projection; final notifier work remains the logical `2*A`
bound.

## Focused Regression and Static Checks

The test runner accepted the exact config and rejected each independently
mutated fixture:

```text
local p99 relaxed from 5,000 to 5,001 ns
publication matrix reduced from 288 to 287 cells
measurement launch permitted before source gate
global settlement wall-clock gate restored
config replaced by a symlink
```

`bash -n`, JSON parsing, normalized-result comparison, and ShellCheck for both
runner and test script pass. TLC was executed serially in the Apple Container
machine to avoid shared temporary-file interference.

## Authorization Boundary

Validation/0257 authorizes only creation of:

```text
parent:   da9ce9159b3450c28c8faf8dceac671fb7bfeba2
branch:   codex/p5a-r4-e4-local-quantum-measurement
files:    init/Kconfig, kernel/sched/exec_lease.c
config:   CONFIG_SCHED_EXEC_LEASE_R4_MEASURE_KUNIT_TEST, default n
suite:    sched_exec_lease_r4_measure
```

The draft must pass a separate source and six-profile E3 regression gate
before any timing build or QEMU measurement starts.

This pass does not accept E4 measurement, authorize R4 behavior source, attach
to a real scheduler, complete N-136, change primary Linux or the patch queue,
or establish runtime behavior/denial/coverage, monitor enforcement,
bare-metal correctness or bounded latency, performance/cost, production
protection, deployment, multi-node, multi-cluster, or datacenter readiness.
