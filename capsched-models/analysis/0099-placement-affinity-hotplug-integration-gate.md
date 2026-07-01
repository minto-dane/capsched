# Analysis 0099: Placement, Affinity, and Hotplug Integration Gate

Status: Draft integration model gate with TLC-backed design filter; no
implementation approved

Date: 2026-07-01

## Purpose

This note integrates the earlier placement-refresh authority work with the
N-143 scheduler execution gate and the N-144 monitor-timer architecture gate.

The rule is:

```text
Linux placement chooses where execution might occur.
CapSched authority decides whether execution may occur there.
```

Linux placement state is compatibility and liveness machinery. It includes
`p->cpus_ptr`, cpuset effective masks, class `select_task_rq()` decisions,
RT/DL/fair balancing, sched_ext `selected_cpu`, core scheduling picks,
hotplug evacuation, and forced affinity fallback. None of these can mint,
refresh, or widen a RunCap-derived execution grant.

For ordinary Domain tasks, execution requires the intersection:

```text
FrozenAllowed =
  RunCap/SchedContext CPU envelope
  ∩ current Linux effective mask
  ∩ active CPU policy
  ∩ monitor CPU binding
  ∩ MemoryView CPU binding
```

If the intersection is empty, the only safe result is fail-closed non-running
state until a new authority-bearing freeze occurs. Linux fallback may keep a
task administratively placeable, but it cannot expand the CapSched envelope.

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
upstream freshness: `git fetch upstream master` on 2026-07-01 observed 0 commits after this ref
```

The current CapSched Linux integration remains inert:

```text
linux/kernel/sched/capsched.c
  no scheduler hook
  no endpoint hook
  no monitor activation
  no task layout change
  no ABI
```

This gate therefore records semantic requirements before any placement hook is
approved.

## Linux Placement Surfaces

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| CPU allowed predicate | `kernel/sched/core.c:2497 is_cpu_allowed()` | final Linux active/online compatibility predicate, not authority |
| cpus pointer predicate | `kernel/sched/sched.h:2874 task_allowed_on_cpu()` | checks `p->cpus_ptr`; mutable Linux mask |
| migration stop | `kernel/sched/core.c:2606 migration_cpu_stop()` | affinity repair and pending migration; must invalidate stale frozen placement |
| common cpus allowed update | `kernel/sched/core.c:2774 set_cpus_allowed_common()` | mutates `p->cpus_ptr`, `cpus_mask`, user mask |
| forced affinity | `kernel/sched/core.c:2803 set_cpus_allowed_force()` | liveness/fallback repair, not CapSched envelope expansion |
| affine move | `kernel/sched/core.c:2883 affine_move_task()` | handles concurrent affinity move, `TASK_WAKING`, migrate-disable, and pending migration |
| locked cpus allowed update | `kernel/sched/core.c:3112 __set_cpus_allowed_ptr_locked()` | computes valid masks and destination CPU |
| affinity syscall | `kernel/sched/syscalls.c:1136 sched_setaffinity()` | userspace mask mutation intersects cpuset and can race; requires revalidation |
| fallback runqueue | `kernel/sched/core.c:3545 select_fallback_rq()` | fallback placement cannot widen capability authority |
| select task rq | `kernel/sched/core.c:3614 select_task_rq()` | placement hint under `p->pi_lock`, not authority |
| wake placement | `kernel/sched/core.c:4215 try_to_wake_up()` | wake path uses selected CPU before queueing |
| new task placement | `kernel/sched/core.c:4934 wake_up_new_task()` | fork/new-task placement races CPU hotplug |
| exec placement | `kernel/sched/core.c:5623 sched_exec()` | exec migration opportunity checks `cpu_active()`, not CapSched authority |
| final schedule | `kernel/sched/core.c:7061 __schedule()` | final run boundary needs authority revalidation, not only earlier placement |
| context switch | `kernel/sched/core.c:7572 context_switch()` | monitor CPU/MemoryView activation must match selected Domain |
| hotplug push stop | `kernel/sched/core.c:8403 __balance_push_cpu_stop()` | pushes tasks off outgoing CPUs; must not run stale grants |
| hotplug balance push | `kernel/sched/core.c:8439 balance_push()` | per-cpu and migrate-disable exceptions require narrow task-kind rules |
| CPU activate | `kernel/sched/core.c:8661 sched_cpu_activate()` | active mask changes invalidate frozen placement |
| CPU deactivate | `kernel/sched/core.c:8699 sched_cpu_deactivate()` | active mask removal invalidates frozen placement |
| cpuset task update | `kernel/cgroup/cpuset.c:1060 cpuset_update_tasks_cpumask()` | cgroup policy mutation changes Linux mask |
| cpuset attach | `kernel/cgroup/cpuset.c:3114 cpuset_attach_task()` | attach installs new allowed mask |
| cpuset fork | `kernel/cgroup/cpuset.c:3632 cpuset_fork()` | inherited Linux mask is not inherited CapSched authority |
| cpuset allowed | `kernel/cgroup/cpuset.c:4020 cpuset_cpus_allowed()` | returns non-empty active subset where possible |
| cpuset fallback | `kernel/cgroup/cpuset.c:4093 cpuset_cpus_allowed_fallback()` | may temporarily set wrong mask; not capability widening |
| fair select | `kernel/sched/fair.c:9544 select_task_rq_fair()` | fair placement heuristic over `p->cpus_ptr` |
| fair active balance | `kernel/sched/fair.c:10710` | runnable tasks can move outside wake path |
| fair load balance | `kernel/sched/fair.c:13606` | balancing is placement, not execution authority |
| active balance callback | `kernel/sched/core.c:8347 active_load_balance_cpu_stop()` | stop-machine movement requires revalidation |
| RT select | `kernel/sched/rt.c:1504 select_task_rq_rt()` | priority placement is not authority |
| RT push/pull | `kernel/sched/rt.c:1774`, `:1959`, `:2260` | class-specific movement must preserve frozen envelope |
| DL admission/root domain | `kernel/sched/deadline.c:648`, `:3321` | DL admission and bandwidth movement are compatibility policy |
| DL select/push/pull | `kernel/sched/deadline.c:2606`, `:2930`, `:3135` | deadline placement cannot mint CapSched authority |
| sched_ext select | `kernel/sched/ext/ext.c:3296 select_task_rq_scx()` | BPF `select_cpu` is a hint and must be final-checked |
| sched_ext dispatch | `kernel/sched/ext/ext.c:2293`, `:2870`, `:2950`, `:3148` | DSQ dispatch/consume is a separate placement surface |
| sched_ext cpus update | `kernel/sched/ext/ext.c:3357 set_cpus_allowed_scx()` | BPF scheduler observes mutable effective mask |
| core scheduling find | `kernel/sched/core.c:360 sched_core_find()` | cached core pick must be revalidated |
| core scheduling steal | `kernel/sched/core.c:6455 try_steal_cookie()` | cookie-compatible stealing moves queued tasks |
| core pick | `kernel/sched/core.c:6215`, `:6344`, `:6566` | cached sibling/core selection is not authority |
| migrate-disable helpers | `include/linux/sched.h:1802`, `:1838`, `:2432` | explicit Linux exception, not ordinary Domain authority |

## Required Semantics

For ordinary Domain execution:

```text
Run authority provenance:
  Domain grant
  SchedContext grant
  RunCap grant

Frozen placement:
  placement epoch = current Domain/placement epoch
  frozenAllowed = capability CPU envelope ∩ Linux mask ∩ active mask
                  ∩ monitor CPU set ∩ MemoryView CPU set
  frozenAllowed is non-empty

Selection:
  Linux may select a CPU only within frozenAllowed.
  selected CPU is not authority.

Run commitment:
  runCpu = selectedCpu
  runCpu ∈ frozenAllowed
  runCpu ∈ current Linux mask
  runCpu ∈ active CPU mask
  runCpu ∈ monitor CPU set
  runCpu ∈ MemoryView CPU set
  no migration is pending
  no fallback or class selection flag is acting as authority
```

Invalidation must occur when any of these changes:

```text
cpus_ptr / affinity
cpuset effective mask
active CPU mask / hotplug state
monitor CPU binding
MemoryView CPU binding
placement epoch
runqueue move with pending migration
```

Running is not immune. If affinity, cpuset, hotplug, monitor CPU binding, or
MemoryView binding changes while a task is running, the model requires
non-running invalidation before another ordinary Domain execution edge.

## Linux Exceptions

`migrate_disable()` and per-cpu kthreads are real Linux compatibility
exceptions. They are not a license to treat Linux masks as CapSched authority.

The rule is:

```text
Ordinary Domain tasks:
  require active CPU, fresh frozen placement, monitor CPU binding, and
  MemoryView CPU binding.

Service/per-cpu kernel tasks:
  require a separate task-kind and service authority model before they can
  represent work on behalf of a Domain.
```

N-145 only checks the ordinary Domain rule and rejects using migrate-disable or
per-cpu kthread exceptions as ordinary Domain authority.

## Subagent Critical Review Incorporated

The first N-145 draft model was rejected before being recorded as a completed
gate. It used booleans for CPU membership, created run authority in the same
action that froze placement, treated running as terminal, and let refresh
repair placement by fiat.

The checked model fixes that by:

```text
using finite CPU sets
separating Domain/SchedContext/RunCap grants from placement freeze
deriving frozenAllowed from actual set intersection
allowing invalidation from Running
requiring fail-closed when the intersection is empty
splitting ordinary Domain tasks from Linux exception concepts
```

This correction is part of the evidence: the gate is not just a pass, it is a
counterexample-driven tightening of the design boundary.

## Model

New model:

```text
formal/0077-placement-affinity-hotplug-integration-gate-model/
```

Checked invariants:

```text
NoRunWithoutGrantAuthority
NoRunWithoutFrozenPlacement
NoRunWithStalePlacement
FrozenAllowedIsDerived
NoRunCpuMismatch
NoRunOutsideFrozenCpu
NoRunOutsideLinuxCurrentMask
NoRunOnInactiveCpu
NoRunWithoutMonitorCpuBinding
NoRunWithoutMemoryViewBinding
NoRunWhileMigrationPending
NoNoIntersectionRun
NoSelectionAsAuthority
NoFallbackAsAuthority
NoLinuxExceptionAsDomainAuthority
NoPlacementMintedAuthority
NoProtectionClaim
```

## Hard Rejections

Reject:

```text
running without Domain/SchedContext/RunCap grant provenance
running without frozen placement
running with stale placement epoch
running when frozenAllowed is not the actual intersection
running on a CPU outside the frozen envelope
running on a CPU outside current Linux mask
running on an inactive CPU
running without monitor CPU binding
running without MemoryView CPU binding
running while migration is pending
selected_cpu as authority
class select_task_rq as authority
sched_ext selected_cpu or DSQ dispatch as authority
core scheduling pick/steal as authority
sched_exec placement as authority
cpuset fallback as authority
force affinity as authority
fallback rq as authority
migrate_disable as ordinary Domain authority
per-cpu kthread exception as ordinary Domain authority
protection claim without implementation
```

## Implementation Consequence

When Linux code is eventually proposed, CapSched needs a final run/move
revalidation layer that is not limited to wake/new/exec placement.

Candidate integration surfaces must be evaluated against:

```text
affinity mutation
cpuset mutation and fallback
hotplug evacuation
fair load balance / NUMA / active balance
RT push and pull
DL push, pull, root-domain bandwidth movement, and DL server paths
sched_ext select/dispatch/consume
core scheduling cached picks and cookie stealing
class changes, PI/proxy execution, and final context switch
migrate-disable and per-cpu kthread exceptions
```

No hook is approved by this note. It only says which semantic obligations any
future hook set must satisfy.

## Non-Claims

This analysis does not approve Linux code, task fields, scheduler hooks,
budget hooks, public ABI, monitor ABI, runtime coverage, behavior change,
monitor implementation, monitor verification, or production protection.
