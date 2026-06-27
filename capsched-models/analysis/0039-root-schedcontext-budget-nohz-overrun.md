# Analysis 0039: Root Budget, SchedContext Budget, and NO_HZ Overrun Boundary

Status: Draft source map with TLC-backed design filter, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

CapSched needs budget enforcement, but Linux already has several runtime-like
mechanisms:

```text
CFS bandwidth runtime
RT group runtime
SCHED_DEADLINE runtime/deadline/replenishment
sched_ext slice
ordinary scheduler tick
hrtick
NO_HZ_FULL remote tick
```

This note separates compatibility substrate from production authority. The
design rule is:

```text
Linux class runtime is useful policy/accounting state.
It is not the hypervisor-grade root CPU authority.
```

## Budget Layers

CapSched should model at least three distinct budget layers.

### MonitorRootBudget

The monitor-owned Domain CPU limit:

```text
owner: HyperTag Monitor
scope: Domain or monitor-issued root scheduling container
purpose: absolute upper bound against compromised Linux
forgeable by Linux: no
may be enforced by ordinary Linux tick only: no
```

If this reaches zero, Domain execution must stop even if Linux class runtime
still says the task may run.

### SchedContextBudget

The Linux-visible CapSched scheduling context budget:

```text
owner: CapSched kernel object, backed by monitor root budget in production
scope: task/thread/scheduling context
purpose: admission, fairness, latency, prototype policy
forgeable by compromised Linux in L0: yes
production authority root: no
```

This is still required for CapSched semantics. `RunCap` allows submission of a
task to a runqueue, but `SchedContext` determines the time envelope in which the
run use is valid.

### ClassRuntimeBudget

Existing Linux scheduler-class runtime:

```text
CFS cgroup bandwidth runtime_remaining
RT rt_time / rt_runtime
Deadline dl runtime and replenishment
sched_ext p->scx.slice
```

This layer preserves Linux behavior and should be integrated carefully. It must
not be allowed to mint CapSched authority, replenish monitor root budget, or
override a revoked `FrozenRunUse`.

## Source Anchors

### Ordinary scheduler tick

`kernel/sched/core.c:sched_tick()`:

```text
updates rq clock
calls donor->sched_class->task_tick(rq, donor, 0)
calls sched_core_tick()
calls scx_tick()
calls wq_worker_tick() for workqueue workers
```

Important detail:

```text
accounting goes to rq->donor, not necessarily rq->curr under proxy execution.
```

CapSched consequence:

```text
budget charging must define whether owner, donor, proxy, service Domain, or
caller BudgetTicket is charged. The default Linux donor accounting is not
automatically CapSched root-budget semantics.
```

### hrtick

`kernel/sched/core.c:hrtick()` runs from hardirq context and calls:

```text
rq->donor->sched_class->task_tick(rq, rq->donor, 1)
```

`hrtick_start()` clamps the requested delay:

```text
delay = max(delay, 10000ns)
```

CapSched consequence:

```text
hrtick is useful for L0 measurement and Linux-visible preemption precision.
It cannot prove zero-overrun absolute caps for budgets smaller than, or close
to, the hrtick floor.
```

### NO_HZ_FULL remote tick

`kernel/sched/core.c:sched_tick_remote()` says the remote tick is approximate:

```text
missing a tick or having one too much is no big deal because scheduler tick
updates statistics and checks timeslices in a time-independent way
```

It also runs roughly once per second:

```text
queue_delayed_work(system_dfl_wq, dwork, HZ)
```

CapSched consequence:

```text
remote tick is not a root-budget enforcement mechanism.
A capped Domain in NO_HZ mode needs a monitor-owned or otherwise unsuppressible
budget timer, or must be prevented from entering capped tickless execution.
```

### CFS bandwidth

`kernel/sched/core.c:sched_can_stop_tick()` refuses to stop the tick for a
single running CFS task when CFS runtime bandwidth constraints require checks.

`kernel/sched/fair.c:update_curr()`:

```text
delta_exec = update_se(rq, curr)
curr->vruntime += calc_delta_fair(delta_exec, curr)
account_cfs_rq_runtime(cfs_rq, delta_exec)
```

`kernel/sched/fair.c:__account_cfs_rq_runtime()`:

```text
cfs_rq->runtime_remaining -= delta_exec
if runtime_remaining <= 0:
  throttle_cfs_rq(cfs_rq)
```

The enqueue path has an explicit overrun guard:

```text
When a group wakes up ... otherwise it may be allowed to steal additional
ticks of runtime as update_curr() throttling can not trigger until it's on-rq.
```

CapSched consequence:

```text
CFS bandwidth is a valuable compatibility signal and L0 prototype substrate.
It is not the monitor root budget. It is Linux-owned mutable state and its
throttling naturally happens after observed execution deltas.
```

### RT runtime

`kernel/sched/rt.c:update_curr_rt()`:

```text
delta_exec = update_curr_common(rq)
rt_rq->rt_time += delta_exec
if sched_rt_runtime_exceeded(rt_rq):
  resched_curr(rq)
```

`sched_rt_runtime_exceeded()` can share runtime and may throttle by dequeuing
the RT runqueue. It also has boosting exceptions.

CapSched consequence:

```text
RT runtime is class-specific policy, not global Domain root authority.
Priority donation, boosting, and runtime sharing must not create CapSched CPU
budget or bypass Domain budget exhaustion.
```

### SCHED_DEADLINE runtime

`kernel/sched/deadline.c:update_curr_dl_se()`:

```text
dl_se->runtime -= scaled_delta_exec
if dl_runtime_exceeded() or yielded:
  dl_se->dl_throttled = 1
  dequeue_dl_entity()
```

`start_hrtick_dl()` arms hrtick using remaining deadline runtime.

CapSched consequence:

```text
Deadline runtime is deadline/admission semantics. It may inform or constrain a
SchedContext, but it cannot replenish or replace the monitor root budget.
```

### sched_ext slice

`include/linux/sched/ext.h`:

```text
SCX_SLICE_INF = U64_MAX, /* infinite, implies nohz */
```

`kernel/sched/ext/ext.c:update_curr_scx()`:

```text
if curr->scx.slice != SCX_SLICE_INF:
  curr->scx.slice -= min(slice, delta_exec)
```

`task_tick_scx()` updates the slice and can call BPF `tick`.

The BPF dispatch comment says that if `%SCX_SLICE_INF` is used, the task never
expires and the BPF scheduler must kick the CPU.

CapSched consequence:

```text
sched_ext is useful for policy experimentation, but a BPF scheduler's slice
decision must not be the CapSched security boundary. Infinite slices cannot be
allowed to bypass a monitor root budget.
```

## Required Invariants

### No class runtime as root authority

```text
ClassRuntimeBudget positive
  does not imply
MonitorRootBudget positive
```

Running a Domain task requires:

```text
MonitorRootBudget > 0
SchedContextBudget > 0
fresh budget epoch
fresh FrozenRunUse
fresh placement envelope
```

### No tickless capped execution without budget timer

If a Domain has an active cap and ordinary scheduler tick is stopped:

```text
running && nohz_tick_stopped
  implies
monitor_budget_timer_armed || equivalent unsuppressible timer coverage
```

The `sched_tick_remote()` offload is not enough for this invariant.

### hrtick is not an exact root cap

For L0:

```text
hrtick can approximate budget preemption
```

For production:

```text
hrtick cannot be the root of absolute CPU enforcement because it is Linux-owned
and has a minimum delay floor.
```

### Budget replenishment changes epoch

Any event that changes budget availability must invalidate selected/frozen use
unless the change is part of an explicitly modeled refresh:

```text
period replenishment
quota change
class runtime redistribution
root-budget refill
SchedContext migration or donation
monitor epoch revoke
```

CapSched consequence:

```text
selected tasks must either revalidate budget epoch, refresh FrozenRunUse,
preempt, or fail closed before ordinary Domain execution continues.
```

## Design Boundary

The Linux-only prototype may do this:

```text
use sched_tick(), hrtick(), and class runtime to measure behavior
integrate with CFS/RT/DL/SCX without changing user-visible semantics
fail closed at CapSched hook points when SchedContext budget is exhausted
record budget overrun and nohz interactions as trace evidence
```

It must not claim:

```text
hypervisor-grade CPU budget isolation
Linux-owned class runtime as unforgeable authority
NO_HZ_FULL safety without unsuppressible timer coverage
protection against arbitrary Linux kernel write in the same Domain
```

The monitor-backed production design must add:

```text
monitor-owned root budget
monitor-owned or unsuppressible budget timer
budget epoch bound into RunToken/FrozenRunUse
fail-closed selected-state revalidation
explicit owner/proxy/service charging rules
```

## Implementation Consequences

For future L0 patches:

```text
1. Add SchedContext accounting separately from existing class runtime.
2. Treat CFS/RT/DL/SCX runtime as compatibility constraints, not authority.
3. Never let class runtime replenishment make a stale FrozenRunUse runnable.
4. Record nohz/hrtick state before claiming any budget enforcement result.
5. For sched_ext, disallow using BPF policy as the security root.
```

For future monitor-backed work:

```text
1. Domain activation must install or refresh root budget timer coverage.
2. Same-Domain fast paths must prove root-budget freshness.
3. NO_HZ execution of capped Domains must be guarded by monitor timer state.
4. Linux budget state may be stale, forged, or maliciously extended.
5. Class runtime may only narrow execution; it may not expand CapSched
   authority.
```

## Open Questions

```text
Q1. Should L0 disable capped-Domain NO_HZ until a monitor timer exists, or
    allow it only for measurement with explicit "not security" tagging?

Q2. Should SchedContext budget be charged to rq->donor, rq->curr, or an
    explicit proxy/service BudgetTicket when proxy execution is active?

Q3. How should cgroup CPU controller runtime interact with SchedContext:
    intersection, hierarchy projection, or policy front-end issuing budget
    caps?

Q4. How should sched_ext infinite slices be restricted once CapSched security
    checks exist?
```

## Model Link

The design filter for these invariants is:

```text
capsched/capsched-models/formal/0022-budget-split-overrun-model/
```
