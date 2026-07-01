# Validation 0119: Task FrozenRun Lifetime and Locking Gate TLC

Status: Safe model passed; unsafe models produced expected counterexamples

Date: 2026-07-01

## Scope

This validation checks:

```text
formal/0080-task-frozen-run-lifetime-locking-gate-model/
```

The model is a semantic design gate for task identity lifetime and locking
around `FrozenRunUse`, denied candidates, and future move validation records.

## Commands

Safe run:

```sh
java -cp /home/nia/tools/tla/tla2tools.jar \
  tlc2.TLC \
  -metadir build/tlc/task-frozen-run-lifetime-locking-gate-20260701T231139Z/safe \
  -config TaskFrozenRunLifetimeLockingGateSafe.cfg \
  TaskFrozenRunLifetimeLockingGate.tla
```

Unsafe configs:

```text
TaskFrozenRunLifetimeLockingGateUnsafe*.cfg
```

## Result

Safe TLC:

```text
20 generated states
12 distinct states
0 states left on queue
depth 6
```

Unsafe TLC:

```text
16 expected counterexamples
```

JSON contract:

```text
19 source anchors
14 state subjects
4 safe paths
12 requirements
13 forbidden substitutions
16 unsafe cases
16/16 safety flags false
```

Rejected hazards:

```text
running after task free/exit invalidation
running without stable task lifetime
RCU-only authority
raw pointer authority
running while migrating
stale generation run
use after release
release before deny/retry/fail-closed settlement
double release
terminal ref/lock leak
move without rq lock
retry without stable candidate lifetime
ignored exit invalidation
behavior-change overclaim
monitor-verification overclaim
protection overclaim
```

## Evidence

This validation adds:

```text
E-SCHED-LIFETIME-LOCKING-001
```

It supports:

```text
EXEC-001
COMPAT-001
```

only as model evidence.

## Non-Claims

This is not Linux implementation, hook approval, task-field approval, task
storage-layout approval, refcount-scheme approval, locking-protocol approval,
ABI approval, runtime coverage, monitor verification, behavior change, budget
enforcement evidence, or production protection.
