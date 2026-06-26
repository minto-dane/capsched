# Implementation 0001: Linux L0 Runnable Lease Plan

Status: Candidate plan, not accepted patch points

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
subject: Merge tag 'bpf-fixes' of git://git.kernel.org/pub/scm/linux/kernel/git/bpf/bpf
```

## Purpose

This note derives the first Linux-only L0 implementation plan from:

```text
formal/0002-runnable-lease-model/
validation/0001-runnable-lease-tlc.md
analysis/0002-scheduler-execution-spine.md
analysis/0003-task-lifecycle-and-identity.md
analysis/0004-existing-resource-controls-and-compatibility.md
analysis/0014-scheduler-topology-cluster-partition-map.md
```

It deliberately does not approve Linux patch points. Its job is to preserve the
checked semantics while exposing the Linux compatibility pressure before the
first patch is written.

## L0 Claim Boundary

L0 is a Linux-only prototype. It may explore scheduler integration,
compatibility, overhead, tracing, and semantic invariants. It must not claim
hypervisor-grade isolation.

Allowed L0 claims:

```text
CapSched objects can be attached to Linux task lifecycle state.
Runnable submission can be mediated by a frozen execution lease.
Pick/switch/tick paths can validate cheap lease predicates.
CapSched CPU placement can refine Linux affinity and cpuset placement.
Domain switch instrumentation can estimate future monitor-transition cost.
```

Disallowed L0 claims:

```text
Compromised Linux kernel context is confined.
DomainTag, epoch, budget, MemoryView, or queue ownership are non-forgeable.
BPF, sched_ext, cgroup, cpuset, LSM, or Linux capabilities are security roots.
Process isolation is already hypervisor-equivalent.
```

## Existing Linux Strengths to Preserve

Linux already provides assets that CapSched should compose with, not bypass:

```text
TASK_NEW and wake_up_new_task() stage child execution.
enqueue/dequeue and on_rq state provide a central runnable-state spine.
sched_class callbacks give class-specific policy and accounting boundaries.
context_switch() already serializes mm/TLB, RCU, membarrier, and arch hooks.
sched_tick(), remote tick, hrtick, and class accounting provide time hooks.
cpuset, affinity, root_domain, sched_domain, housekeeping, and hotplug encode
  local placement and partition compatibility.
core scheduling already models limited SMT co-tenancy.
cgroup CPU, uclamp, RT/DL admission, and LSM checks are useful policy inputs.
sched_ext and BPF are strong policy/experiment surfaces.
```

The implementation posture should be conservative: CapSched refines existing
Linux controls into explicit authority objects, while preserving user-visible
Linux behavior unless a later, explicit security mode chooses fail-closed
semantics.

## Model-to-Linux Mapping

| Runnable Lease transition | Linux evidence | L0 implementation pressure |
| --- | --- | --- |
| `IssueRunCap` | Policy inputs are spread across cgroup, LSM, credentials, scheduler syscalls, BPF policy hooks | For L0, start with a synthetic default Domain and permissive RunCap issuance. Keep policy separate from execution authority so later LSM/BPF/cgroup policy can feed issuance without becoming the root. |
| `FreezeRunUse` | `ttwu_do_activate()` calls `activate_task()` at `kernel/sched/core.c:3804`; `wake_up_new_task()` calls `activate_task()` at `kernel/sched/core.c:4941`; `ttwu_runnable()` may call `enqueue_task(... ENQUEUE_DELAYED)` at `kernel/sched/core.c:3865` | A single hook in `activate_task()` is probably insufficient. The first patch must identify every path that can create or revive runnable queue authority, including delayed fair entities and new tasks. |
| `EnqueueTask` | `enqueue_task()` updates uclamp, class state, PSI, sched info, and core scheduling at `kernel/sched/core.c:2172` | Rejection after partial enqueue would corrupt accounting. If L0 enforces before enqueue, it must have all needed facts without slow lookup or allocation under scheduler locks. |
| `PickTask` | `__pick_next_task()` has a fair fast path at `kernel/sched/core.c:6123`; `pick_next_task()` core-sched path can reuse `core_pick` and force idle at `kernel/sched/core.c:6215` | Pick validation must cover fair fast path, class iteration, and core-sched cached picks. It cannot depend solely on per-class callbacks. |
| `ActivateDomain` | `__schedule()` picks `next`, updates `rq->curr`, traces, then calls `context_switch()` at `kernel/sched/core.c:7061` | Linux-only L0 should instrument Domain switch here or immediately adjacent to context switch. Production will later replace instrumentation with monitor activation. |
| `RunTick` / `BudgetExhaust` | `sched_tick()` charges `rq->donor` at `kernel/sched/core.c:5762`; NOHZ remote tick calls class `task_tick()` for `rq->curr` at `kernel/sched/core.c:5849` | CapSched budget must be class-crossing and proxy-aware. It cannot be "CFS bandwidth renamed". L0 should account separately and initially throttle/instrument conservatively. |
| `ExecTask` | `bprm_execve()` calls `sched_exec()` before binary execution at `fs/exec.c:1754`; `begin_new_exec()` reaches point-of-no-return and calls `exec_mmap()` at `fs/exec.c:1110`; `exec_mmap()` swaps `mm` at `fs/exec.c:842` | Exec must preserve Domain and SchedContext. It may bump process generation and force grant refresh. Endpoint models can later decide which resource caps survive exec. |
| `ExitTask` | `do_exit()` cancels io_uring files, sets `PF_EXITING`, tears down mm/files/ns/task_work, and ends in `do_task_dead()` at `kernel/exit.c:924` | Self-exit must not require RunCap. L0 should clear runnable grants and mark task generation dead before any path can requeue the exiting task. |
| `RevokeDomainEpoch` | Linux has no equivalent; tasks can be queued, selected, running, delayed, throttled, migrating, or remote-wake pending | The checked TLA model uses eager revocation. Linux L0 must either implement eager clear/dequeue under rq locks or deliberately weaken the model and add pick-time rejection. This must be an explicit decision. |
| `RefreshPlacement` | `__set_cpus_allowed_ptr_locked()` changes masks and migrates at `kernel/sched/core.c:3112`; `ttwu_queue_cond()` checks `p->cpus_ptr` at `kernel/sched/core.c:4005` | FrozenRunUse allowed CPU sets become stale when affinity/cpuset/hotplug constraints change. L0 needs a refresh or invalidation rule. |

## Candidate Object Layout

Do not treat this as an accepted patch. It is a shape to test against Linux
source constraints.

```text
CONFIG_CAPSCHED
  include/linux/capsched.h
  kernel/sched/capsched.c
  task_struct fields guarded by CONFIG_CAPSCHED
```

Candidate in-memory objects:

```text
capsched_domain:
  domain id, epoch, allowed cpus, flags, refs

capsched_sched_ctx:
  owner domain, epoch, budget/period/remaining runtime, allowed cpus, flags

capsched_run_cap:
  issuer/caller domain, target task identity, sched context, epoch

capsched_frozen_run_use:
  task generation, process generation, domain epoch, sched context,
  frozen allowed cpus, validation flags
```

L0 can initially use a single built-in root Domain and a default SchedContext for
all existing tasks. That avoids creating a user ABI before the scheduler
integration is understood. The design must still keep the types separate so the
prototype does not grow ambient authority by accident.

## Placement Rule

The TLA model encoded placement as:

```text
effective_allowed_cpus(task)
  = task affinity
    intersect cpuset effective CPUs
    intersect SchedContext.allowed_cpus
    intersect Domain.allowed_cpus
    intersect MonitorAllowed(domain, epoch, cpu)
```

L0 has no real monitor, so `MonitorAllowed` is a stub. The compatibility rule
remains:

```text
CapSched must never expand p->cpus_ptr.
CapSched may only narrow or reject within existing Linux placement.
```

Open semantic pressure:

```text
Linux cpuset has fallback behavior to keep tasks runnable.
CapSched security semantics may need fail-closed behavior when no leased CPU
exists.
L0 should record this tension rather than silently picking one forever.
```

## Fast-Path Constraints

Scheduler locks make the split between resolution and validation mandatory.

Slow or blocking work:

```text
policy lookup
capability table traversal
memory allocation
cluster lease validation
LSM/BPF/cgroup policy consultation
```

Must not happen while holding hot scheduler locks.

Fast validation under scheduler locks:

```text
grant pointer exists
task generation matches
process generation matches if required
domain epoch matches
sched context pointer exists
budget is positive
cpu is in frozen allowed set and p->cpus_ptr
domain is not revoked
```

This is the practical reason to keep `FrozenRunUse`: it lets Linux fast paths
avoid turning every wakeup and pick into a global authority lookup.

## Compatibility Hazards

The first Linux patch must be reviewed against these hazards:

| Hazard | Why it matters |
| --- | --- |
| Already-runnable wake | `ttwu_runnable()` can complete wakeup without a normal activation and can re-enqueue delayed entities. |
| New-task wake | `wake_up_new_task()` is separate from normal wake and moves `TASK_NEW` to runnable. |
| Fair fast path | `__pick_next_task()` can call `pick_task_fair()` directly and return without class iteration. |
| Core scheduling | `pick_next_task()` may reuse `core_pick`, force idle, or reschedule siblings to satisfy cookies. |
| sched_ext fallback | sched_ext can abort, bypass, or fall back; it cannot be the enforcement root. |
| Proxy execution | Tick accounting may charge `rq->donor`, not a naive current task. |
| NOHZ remote tick | Budget enforcement cannot assume the local periodic tick always runs. |
| Affinity/cpuset changes | Frozen allowed CPU sets can become stale after mask updates or hotplug. |
| fork inheritance | Linux clone flags copy/share mm, files, cred, namespaces, io context, and worker state. |
| exec identity | exec changes program/mm/cred but must not mint a new DomainTag. |
| exit lifetime | A task can be non-executable while still referenced by wait, pid, ptrace, audit, or RCU. |
| async provenance | io_uring, workqueue, task_work, timers, softirq, and kthreads can execute after the caller changed or disappeared. |

## Minimal Slice Sequence

### Slice 0: Baseline and Feature Scaffolding

Goal:

```text
Add CONFIG_CAPSCHED, empty helpers, compile-time guards, and trace-only stubs.
No behavior change.
```

Expected files:

```text
include/linux/sched.h
include/linux/capsched.h
kernel/sched/core.c
kernel/sched/capsched.c
kernel/sched/Makefile
kernel/sched/Kconfig
```

Acceptance:

```text
CONFIG_CAPSCHED=n produces no meaningful codegen or behavior change.
CONFIG_CAPSCHED=y boots or builds with default permissive root Domain.
No scheduler fast path performs allocation or blocking policy lookup.
```

### Slice 1: Task Identity and Default Domain

Goal:

```text
Attach Domain/SchedContext/generation fields to tasks.
Initialize all tasks into a default L0 Domain and SchedContext.
Record fork, exec, exit, and switch tracepoints or debug counters.
```

No enforcement yet, except internal consistency assertions where safe.

### Slice 2: FrozenRunUse Preparation and Validation

Goal:

```text
Prepare a frozen run use before runnable insertion.
Validate frozen use again after pick and before Domain activation.
Keep policy permissive so compatibility regressions reveal hook mistakes,
not policy choices.
```

Required coverage:

```text
normal wake
new-task wake
already-runnable/delayed wake
migration or requeue paths that can create runnable authority
core scheduling cached picks
```

### Slice 3: Budget Accounting and Throttle Instrumentation

Goal:

```text
Track SchedContext remaining runtime independently from scheduler class policy.
Trigger reschedule or trace-only throttle when budget reaches zero.
```

The first implementation should avoid claiming security enforcement. It should
collect evidence on CFS, RT, deadline, sched_ext, proxy execution, hrtick, and
NOHZ behavior.

### Slice 4: Revocation Experiment

Goal:

```text
Add a debug-only Domain epoch bump path.
Compare eager runnable-state clearing against lazy pick-time rejection.
```

This slice must be model-driven. If the Linux implementation chooses lazy
revocation, fork the TLA model or weaken `NoQueuedWithoutFrozenUse` deliberately.

### Slice 5: Domain Switch Cost Instrumentation

Goal:

```text
Track prev/next Domain changes at schedule time.
Measure batching, locality, and future monitor transition pressure.
```

No monitor call exists in L0. This is performance evidence for CapSched-H.

## Validation Plan Before First Linux Behavior Change

Before enforcing any denial in the Linux scheduler:

```text
1. Build baseline upstream commit with a known config.
2. Add CONFIG_CAPSCHED=n scaffolding and confirm no behavior change.
3. Add CONFIG_CAPSCHED=y permissive mode and boot/build smoke test.
4. Add synthetic trace events or counters for all runnable entry paths.
5. Compare observed paths with the Runnable Lease transition map.
6. Re-run or extend TLA model for any semantic choice that differs from 0002.
```

Useful early checks:

```text
compile with CONFIG_SCHED_CORE on/off
compile with CONFIG_SCHED_CLASS_EXT on/off
compile with CONFIG_NO_HZ_FULL on/off if config permits
fork/exec/exit stress
sched_setaffinity and cpuset movement stress
sched_ext enabled and fallback scenarios, if practical
basic RT/deadline admission smoke tests
```

## Open Decisions Before Patching

These must be answered or explicitly scoped out before the first non-trivial
Linux patch:

1. Is the first patch pure scaffolding, or does it add task fields immediately?
2. Does `FrozenRunUse` live directly on `task_struct` in L0, or behind an RCU
   pointer with explicit lifetime handling?
3. Is L0 revocation eager, lazy, or initially trace-only?
4. What is the exact behavior when a task has no valid SchedContext in
   permissive mode?
5. How does L0 represent budgets across proxy execution and scheduler classes?
6. Which configs form the first compatibility build matrix?
7. What user-visible ABI, if any, is intentionally deferred until after
   scheduler integration is proven?

## Preliminary Conclusion

The checked Runnable Lease model maps cleanly to Linux only if CapSched is
introduced as a narrow, cheap validation layer around existing scheduler state,
not as a replacement scheduler class and not as a global policy interpreter.

The strongest first move is therefore:

```text
CONFIG_CAPSCHED scaffolding
+ task identity/default Domain/SchedContext
+ trace-only frozen-use preparation and post-pick validation
```

That preserves Linux compatibility while producing evidence about the real
places where runnable authority appears. Enforcement should come only after
those paths are measured and the TLA model is updated for any Linux-specific
semantic compromises.
