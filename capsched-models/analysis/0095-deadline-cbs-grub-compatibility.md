# Analysis 0095: Deadline CBS/GRUB Compatibility

Status: Draft model gate with TLC-backed design filter; no implementation
approved

Date: 2026-07-01

## Purpose

This note refines the scheduler budget model around Linux `SCHED_DEADLINE`.

The compatibility rule is:

```text
Linux CBS/GRUB is a scheduler compatibility constraint, not CapSched authority.
```

Linux deadline scheduling has precise runtime, deadline, replenishment,
inactive-utilization, bandwidth-admission, reclaim, and overload behavior.
CapSched must preserve those constraints when it uses deadline policy or
deadline servers. It must not treat those mutable Linux states as RunCap,
SchedContext root budget, monitor budget, Domain authority, or revoke evidence.

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
upstream freshness: `git fetch upstream master` on 2026-07-01 observed 0 commits after this ref
```

Key source anchors:

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| Deadline class purpose | `kernel/sched/deadline.c:5` | EDF + CBS is existing Linux policy |
| sched_attr DL fields | `include/uapi/linux/sched/types.h:110` through `:113` | userspace-visible runtime/deadline/period ABI |
| DL reclaim flag | `include/uapi/linux/sched.h:140` | reclaim is ABI policy input, not CapSched budget mint |
| DL flag mask | `kernel/sched/sched.h:287` | DL-specific flags include reclaim/overrun/sugov |
| sched_dl_entity static params | `include/linux/sched.h:648` through `:656` | static DL params are Linux scheduling params |
| sched_dl_entity dynamic params | `include/linux/sched.h:659` through `:665` | remaining runtime/deadline are mutable Linux state |
| DL throttle/non-contending flags | `include/linux/sched.h:670` through `:721` | mutable state narrows scheduling but is not authority |
| DL bandwidth root-domain object | `kernel/sched/sched.h:330` through `:352` | admission accounting, not monitor root budget |
| DL rq GRUB fields | `kernel/sched/sched.h:907` through `:929` | running_bw/this_bw/extra_bw/max_bw are reclaim inputs |
| DL bandwidth capacity | `kernel/sched/deadline.c:153` | root-domain/capacity admission surface |
| DL overflow check | `kernel/sched/deadline.c:207` | admission overflow check |
| running_bw add/sub | `kernel/sched/deadline.c:214` and `:227` | active utilization accounting |
| active utilization diagram | `kernel/sched/deadline.c:348` through `:400` | GRUB active/non-contending/inactive states |
| task_non_contending | `kernel/sched/deadline.c:402` | inactive timer setup or immediate running_bw drop |
| inactive timer arm | `kernel/sched/deadline.c:459` and `:463` | timer changes active utilization, not authority |
| task_contending | `kernel/sched/deadline.c:466` | wakeup restores active utilization if needed |
| DL rq init | `kernel/sched/deadline.c:519` | running_bw/this_bw initialize to zero |
| offline migration bandwidth move | `kernel/sched/deadline.c:680` through `:705` | bandwidth accounting follows migration |
| CBS overflow equation | `kernel/sched/deadline.c:920` | residual runtime/deadline reuse rule |
| revised CBS wakeup | `kernel/sched/deadline.c:968` | constrained-deadline runtime reduction |
| update_dl_entity | `kernel/sched/deadline.c:1013` | wakeup may replenish or reduce runtime |
| runtime exceeded | `kernel/sched/deadline.c:1346` | local DL runtime exhaustion |
| GRUB reclaim | `kernel/sched/deadline.c:1368` | runtime consumption scaling, not root budget mint |
| GRUB-PA / capacity scaling | `kernel/sched/deadline.c:1388` | local runtime scaling and frequency policy |
| update_curr_dl_se | `kernel/sched/deadline.c:1416` | DL runtime depletion and throttling |
| runtime decrement | `kernel/sched/deadline.c:1437` | mutable DL runtime is decremented |
| deferred server background depletion | `kernel/sched/deadline.c:1450` | DL server can deplete while throttled |
| throttle path | `kernel/sched/deadline.c:1501` | runtime exhaustion throttles/dequeues local entity |
| overrun notification | `kernel/sched/deadline.c:1506` | `dl_overrun` is notification, not enforcement root |
| update_curr_dl donor | `kernel/sched/deadline.c:2128` through `:2146` | donor DL runtime accounting |
| inactive_task_timer | `kernel/sched/deadline.c:2149` | timer drops active utilization after 0-lag |
| enqueue constrained check | `kernel/sched/deadline.c:2388` through `:2395` | constrained-deadline activation rule |
| enqueue throttled return | `kernel/sched/deadline.c:2404` through `:2420` | throttled entity may remain non-runnable |
| enqueue wakeup/update/replenish | `kernel/sched/deadline.c:2428` through `:2432` | wakeup/replenish is Linux DL state transition |
| enqueue timer gate | `kernel/sched/deadline.c:2443` | DL timer can delay enqueue |
| dequeue GRUB sleep handling | `kernel/sched/deadline.c:2472` through `:2482` | sleep/exit move to non-contending/inactive |
| switched_from_dl | `kernel/sched/deadline.c:3507` | leaving DL may arm inactive handling |
| switched_to_dl | `kernel/sched/deadline.c:3561` | entering DL cancels inactive timer |
| sched_dl_overflow | `kernel/sched/deadline.c:3776` | admission-control update |
| sched_dl_overflow update | `kernel/sched/deadline.c:3802` through `:3819` | total bandwidth and utilization update |
| leave-DL delayed decrease | `kernel/sched/deadline.c:3821` through `:3827` | 0-lag delayed bandwidth decrease |
| __setparam_dl | `kernel/sched/deadline.c:3842` | DL params copied from sched_attr |
| dynamic sched_getattr | `kernel/sched/deadline.c:3861` through `:3869` | read-side runtime/deadline, not authority |
| __checkparam_dl | `kernel/sched/deadline.c:3889` | parameter validity gate |
| sched_setattr affinity/bw gate | `kernel/sched/syscalls.c:622` through `:635` | root-domain affinity/bandwidth compatibility gate |
| sched_setattr overflow gate | `kernel/sched/syscalls.c:648` through `:655` | admission failure returns `-EBUSY` |

## Required Subject Split

Use these distinct subjects:

```text
CapSchedRunUse:
  RunCap-derived FrozenRunUse/SchedContext/Domain epoch/generation

MonitorRootBudget:
  production root CPU budget below Linux

LinuxDLAdmission:
  root-domain bandwidth and sched_attr compatibility check

CBSRuntime:
  Linux mutable remaining runtime/deadline and replenishment/throttle state

GRUBAccounting:
  Linux active/inactive utilization and reclaim scaling

DLObservation:
  sched_getattr dynamic runtime, tracepoints, overrun notification
```

## Gate Rule

A future scheduler authority implementation is blocked unless:

```text
DL execution requires CapSchedRunUse and MonitorRootBudget.
DL execution that uses SCHED_DEADLINE also respects LinuxDLAdmission and
CBSRuntime availability.
LinuxDLAdmission, CBSRuntime, GRUBAccounting, inactive timers, dynamic
sched_getattr, and overrun notification never mint or refresh CapSchedRunUse.
GRUB reclaim never increases MonitorRootBudget.
CBS replenish can restore Linux DL runtime but cannot restore revoked or stale
CapSched authority.
DL throttling may stop or delay execution but cannot be the sole proof of
monitor-enforced budget exhaustion.
```

## Compatibility Obligations

CapSched must preserve:

```text
sched_attr runtime/deadline/period ABI interpretation
SCHED_FLAG_RECLAIM semantics as Linux DL reclaim policy
root-domain bandwidth admission and affinity restrictions
CBS wakeup and revised CBS constrained-deadline behavior
throttle and replenishment timing
GRUB active/non-contending/inactive utilization accounting
inactive timer delayed running_bw updates
DL migration/root-domain bandwidth accounting
special SUGOV exclusion from ordinary DL parameter accounting
```

## Model

New model:

```text
formal/0073-deadline-cbs-grub-compat-model/
```

Checked invariants:

```text
NoRunWithoutCapSchedRunUse
NoRunWithoutMonitorRootBudget
NoRunWithoutDLAdmission
NoRunWithoutCBSRuntime
NoLinuxAdmissionAsAuthority
NoCBSReplenishAsAuthority
NoGRUBAsMonitorBudget
NoDLRuntimeAsMonitorBudget
NoInactiveTimerAsAuthority
NoDynamicGetattrAsAuthority
NoOverrunNotificationAsEnforcement
NoProtectionClaim
```

## Hard Rejections

Reject:

```text
sched_dl_overflow() success treated as RunCap mint
CBS replenish treated as RunCap refresh
DL runtime/deadline fields treated as monitor budget
GRUB reclaim treated as extra monitor root budget
inactive timer callback treated as Domain revoke or refresh receipt
sched_getattr dynamic runtime treated as authority evidence
dl_overrun notification treated as enforcement
DL throttling treated as monitor-root budget proof
SCHED_FLAG_RECLAIM treated as permission to exceed CapSched root budget
trace or successful TLC treated as production protection
```

## Non-Claims

This note does not approve scheduler hooks, budget hooks, task fields,
tracepoints, public ABI changes, monitor implementation, runtime coverage,
behavior change, or production protection.
