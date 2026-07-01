# Formal 0067: Scheduler Authority Refinement Gate Model

Status: Checked with safe pass and expected unsafe counterexamples

Date: 2026-07-01

## Purpose

This model ties the refreshed Linux scheduler authority source map back to
three proof obligations that must remain blocking before any behavior-changing
scheduler authority patch:

```text
1. fail-capable admission must freeze authority before TASK_WAKING
2. runtime/budget accounting must distinguish donor from current/executor
3. selected class state must be settled after retry/class/core/proxy movement
```

It refines the direction established by:

```text
analysis/0025-linux-scheduler-authority-state-machine.md
analysis/0026-scheduler-hook-proof-obligation-matrix.md
analysis/0028-tick-runtime-budget-source-map.md
analysis/0030-task-waking-failability-boundary-map.md
analysis/0039-root-schedcontext-budget-nohz-overrun.md
analysis/0040-class-selected-state-boundary.md
formal/0012-linux-scheduler-authority-model/
formal/0013-scheduler-admission-failure-model/
formal/0022-budget-split-overrun-model/
formal/0023-class-selected-state-model/
```

## Source Facts Being Modeled

Current upstream source map:

```text
upstream/master=665159e246749578d4e4bfe106ee3b74edcdab18
```

Key facts:

```text
try_to_wake_up() writes TASK_WAKING before placement and enqueue.
sched_tick() accounts to rq->donor, not blindly to rq->curr.
task_sched_runtime() refreshes update_curr only for task_current_donor().
__pick_next_task() may retry and runs put_prev_set_next_task().
__schedule() may set rq->donor before finding a proxy execution task.
```

## Safe Shape

The safe model allows execution only after:

```text
FrozenRunUse exists before TASK_WAKING.
The task reaches selected state.
Class/proxy/core retry-sensitive state is settled.
Donor budget remains fresh.
Executor authority remains fresh.
Proxy execution has an explicit proxy ticket when donor != current.
```

## Unsafe Shapes

The model includes unsafe specs for:

```text
TASK_WAKING before freeze
current/executor-only budget under proxy execution
running after RETRY_TASK or retry-equivalent invalidation
running from selected state without class settlement
```

## Claim Boundary

Allowed claim after TLC:

```text
This small model supports the refinement gate that scheduler authority core
cannot collapse admission freeze, selected state, donor budget, and executor
authority into one current-task check.
```

Forbidden claim:

```text
Linux scheduler enforcement is implemented.
The full scheduler has been proven.
Any concrete hook point is approved.
Monitor-backed protection exists.
```
