# Analysis 0004: Existing Resource Controls and Compatibility

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note classifies existing Linux scheduler and resource controls as
compatibility inputs, policy front-ends, or partial enforcement mechanisms. It
does not treat them as non-forgeable CapSched roots.

## Existing Strengths

Linux already has a rich scheduling control surface:

- Per-task priority, policy, nice, RT priority, deadline attributes.
- Per-task CPU affinity and migration controls.
- cgroup CPU controller with weight, bandwidth, and uclamp.
- cpuset with effective CPU and memory constraints.
- scheduler topology with domains, groups, root domains, and cluster awareness.
- core scheduling for SMT co-tenancy control.
- LSM hooks around scheduler policy changes.
- sched_ext for policy experimentation.

This is valuable. CapSched should preserve these ABIs and compose them into a
more explicit authority model.

## Scheduler Syscall Controls

Evidence:

- `kernel/sched/syscalls.c` around lines 65-95 implements `set_user_nice()`.
- `can_nice()` around lines 118-121 uses `RLIMIT_NICE` or `CAP_SYS_NICE`.
- Permission logic for scheduler changes appears around lines 435-491,
  including owner checks, `CAP_SYS_NICE`, RT limits, deadline privilege, and
  LSM checks.
- `__sched_setscheduler()` around lines 493-723 validates policy, priority,
  flags, uclamp, deadline bandwidth, RT group runtime, sched_ext constraints,
  and PI interactions.
- `__sched_setaffinity()` around lines 1136-1195 intersects user masks with
  cpuset constraints and handles deadline checks.
- `sched_setaffinity()` permission logic around lines 1197-1276 uses ownership,
  `CAP_SYS_NICE`, `PF_NO_SETAFFINITY`, and LSM.

CapSched reading:

These syscalls are compatibility interfaces. In L0, CapSched should not break
them. In the eventual architecture, they can become policy requests:

```text
user syscall or cgroup operation
  -> existing Linux permission and LSM policy
  -> CapSched SchedControlCap or SchedContext mutation request
  -> monitor-backed lease validation in production
```

## Affinity and Cpuset

Evidence:

- `set_cpus_allowed_common()` in `kernel/sched/core.c` around lines 2774-2790
  updates masks and mm CPU tracking.
- `__set_cpus_allowed_ptr()` and related functions around lines 2883-3223 have
  detailed migration and concurrency handling.
- `kernel/cgroup/cpuset.c` around lines 2973-3070 checks cpuset attach,
  including nonempty effective masks and LSM `security_task_setscheduler()`.
- `cpuset_attach_task()` around lines 3114-3188 calls
  `set_cpus_allowed_ptr()`.
- `cpuset_can_fork()` and fork handling around lines 3573-3658 integrate
  cpuset constraints into child creation.
- `cpuset_cpus_allowed()` around lines 4018-4077 computes an allowed mask with
  fallback behavior.

CapSched reading:

CPU placement must be an intersection, not a replacement:

```text
effective_allowed_cpus =
  user affinity
  ∩ cpuset effective CPUs
  ∩ scheduler topology / housekeeping constraints
  ∩ SchedContext allowed CPUs
  ∩ monitor CPU lease, when present
```

Compatibility hazard:

Linux cpuset has fallback behavior to keep tasks runnable. CapSched must decide
whether a fallback mask can only shrink within the SchedContext lease or whether
it should fail closed when no permitted CPU exists. That is a security semantics
question, not just placement.

## cgroup CPU, uclamp, and Bandwidth

Evidence:

- `kernel/sched/core.c` around lines 9604-9724 updates active uclamp state for
  cgroups.
- `kernel/sched/core.c` around lines 10386-10530 exposes cgroup CPU files such
  as `cpu.weight` and `cpu.max`.
- `kernel/sched/fair.c` around lines 6506-6559 accounts CFS bandwidth and can
  throttle CFS runqueues.
- RT and deadline have separate runtime and admission behavior in
  `kernel/sched/rt.c` and `kernel/sched/deadline.c`.

CapSched reading:

cgroup CPU controls are excellent policy and resource-management inputs. They
are not enough for CapSched's hostile threat model because a compromised kernel
context can mutate normal kernel state unless a monitor protects roots.

Possible layering:

```text
cgroup CPU / uclamp / CFS bandwidth:
  Linux compatibility and local policy

SchedContext:
  explicit execution resource object

HyperTag Monitor root budget:
  non-forgeable upper bound in production
```

## Core Scheduling

Evidence:

- `task_struct::core_cookie` appears in `include/linux/sched.h`.
- `kernel/sched/core_sched.c` around lines 1-31 allocates and refcounts core
  cookies.
- `sched_core_update_cookie()` around lines 55-99 updates cookie state under
  scheduler locking.
- PR_SCHED_CORE behavior around lines 130-237 uses ptrace-style access and can
  share cookies with a thread, thread group, or process group.
- `pick_next_task()` with core scheduling in `kernel/sched/core.c` around lines
  6172-6677 can force idle to satisfy cookie constraints.

CapSched reading:

Core scheduling is directly relevant to co-tenancy policy:

```text
core_cookie:
  useful compatibility co-tenancy input

DomainTag side policy:
  stronger, explicit domain-level co-tenancy constraint

Monitor:
  final root for cross-domain side-policy enforcement, where hardware allows
```

Compatibility hazard:

Core scheduling may pick idle even when runnable tasks exist. A CapSched budget
or fairness model that assumes "runnable implies chosen soon" will be wrong.

## sched_ext

Evidence:

- `Documentation/scheduler/sched-ext.rst` describes sched_ext as BPF-defined
  scheduler policy.
- The documentation states that internal errors, runnable task stalls, or SysRq
  operations can abort sched_ext and revert tasks to the normal scheduler.
- `kernel/sched/ext/ext.c` includes enqueue, dequeue, pick, tick, bypass, and
  watchdog logic.

CapSched reading:

sched_ext is a strong policy laboratory for:

- domain clustering and batching
- MemoryView switch reduction
- queueing policy
- cluster-aware dispatch heuristics
- benchmarking CapSched scheduling objectives

It is not the production security boundary because fallback and bypass are
features of sched_ext availability. `No RunCap, no run` cannot depend only on a
BPF scheduler.

## Classification Table

| Linux mechanism | Keep as ABI? | CapSched role | Not sufficient because |
| --- | --- | --- | --- |
| `sched_setattr()` / `sched_setscheduler()` | Yes | Policy request for SchedControlCap or SchedContext mutation | Uses ambient Linux permission and mutable kernel state. |
| `sched_setaffinity()` | Yes | Requested placement mask, intersected with SchedContext | Affinity is not ownership of CPUs. |
| `nice` / RT limits / `CAP_SYS_NICE` | Yes | Compatibility policy input | Linux capability is not a sealed execution lease. |
| cgroup CPU | Yes | Tenant/service policy and accounting input | cgroup state is mutable by privileged kernel context. |
| cpuset | Yes | Placement and partition policy input | Has fallback and administrative semantics, not non-forgeable authority. |
| uclamp | Yes | Performance hint and policy input | It does not express run permission. |
| core scheduling | Yes | Co-tenancy input | Cookie access control is not DomainTag isolation. |
| LSM hooks | Yes | Policy front-end for capability issuance | LSM checks are not lower than compromised Linux. |
| sched_ext | Yes | Policy experimentation and heuristics | Can fall back or bypass. |

## Preliminary Conclusion

Existing Linux resource controls are a major asset. CapSched should not bulldoze
them. The right compatibility stance is to let Linux controls continue to define
user-visible policy while CapSched adds explicit, frozen, and eventually
monitor-backed authority below the policy layer.
