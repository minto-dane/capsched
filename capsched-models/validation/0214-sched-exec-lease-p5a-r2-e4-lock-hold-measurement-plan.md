# Validation 0214: SchedExecLease P5A-R2 E4 Lock-Hold Measurement Plan

Date: 2026-07-14

Status: passed for creating the exact disposable E4 two-file measurement
source draft only. E4 measurement and every production/performance claim
remain unaccepted.

## Scope

Validate analysis/0163 and formal/0130 against the exact hashed E3 pass,
primary/E2/E3/patch-queue identities, current scheduler clock/locking/test
primitives, the immutable 35-cell/10,000-sample matrix and 25/50 microsecond
rejection gate, negative-evidence preservation, two-architecture identity, and
explicit production/performance non-claims.

## Runner

```text
capsched-models/validation/
  run-sched-exec-lease-p5a-r2-e4-lock-hold-measurement-plan.sh
```

## Result

Run `20260714T-p5a-r2-e4-lock-hold-plan` passed:

```text
source anchors:                  24, failures 0
future/source absence checks:   4, failures 0
safe TLC:                       6 generated, 5 distinct, depth 5
unsafe expected counterexamples: 28/28
matrix:                         35 cells
measured pairs per cell:        10,000
additional p99/max limits:      25,000 / 50,000 ns
base slice:                     700,000 ns
```

Result:
`build/source-check/sched-exec-lease-p5a-r2-e4-lock-hold-measurement-plan/20260714T-p5a-r2-e4-lock-hold-plan/result.json`.

Result SHA-256:
`fff0fc959baebb7a7be4565ee164a8ad7ebad231149413c4f2368ea55a7795fc`.

The runner executed in the Apple Container machine because the host macOS
environment has no Java runtime. OpenJDK 21 checked the safe model and all 28
independent unsafe configurations; this environment choice changes no model
or source contract.

## Authorization Boundary

The exact branch `codex/p5a-r2-e4-lock-hold` may now be created as a direct
child of E3 commit `d1d5e78da8484c91eae70f22399c6901da680ea0`, changing
only `init/Kconfig` and `kernel/sched/fair.c`.

This pass does not authorize launching E4 before a separate source gate,
accept E4 measurement, approve the full locked rebuild, change primary Linux
or patch queue 0014, or claim production layout, live behavior, bounded
latency, performance, cost, protection, deployment, or datacenter readiness.
