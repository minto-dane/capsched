# Implementation 0002: L0 Slice 0 Scaffolding Plan

Status: Selected candidate for the first Linux patch slice

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note narrows Implementation 0001 into the first no-behavior-change Linux
patch slice. The goal is to create a build-visible CapSched feature boundary
without changing scheduler behavior, `task_struct` layout, task lifecycle, or
runtime policy.

The first patch should be boring on purpose. It should make the tree ready for
future CapSched code review without yet asking reviewers to accept a scheduler
semantic change.

## Source Evidence

Relevant upstream shape:

```text
kernel/sched/Makefile:
  builds core.o, fair.o, build_policy.o, build_utility.o

kernel/sched/build_policy.c:
  includes idle.c, rt.c, cpudeadline.c, pelt.c, cputime.c, deadline.c,
  sched_ext sources, and syscalls.c into one translation unit

kernel/sched/build_utility.c:
  includes clock.c, cpuacct.c, cpufreq.c, debug.c, stats.c, loadavg.c,
  wait helpers, cpupri.c, stop_task.c, topology.c, core_sched.c, psi.c,
  membarrier.c, isolation.c, and autogroup.c

init/Kconfig:
  contains menu "Scheduler features" around line 882

include/linux/sched.h:
  task_struct starts around line 826; scheduler-critical randomized fields
  include on_rq, on_cpu, class entities, core scheduling, cgroup scheduling,
  uclamp, policy, and affinity masks

init/init_task.c:
  statically initializes init_task and must be considered before adding
  non-zero default CapSched task fields

kernel/fork.c and kernel/sched/core.c:
  fork_idle() and init_idle() create and install idle tasks through special
  paths that should not be accidentally subject to L0 RunCap enforcement
```

## Chosen First Slice: Slice 0A

The first patch should be:

```text
Slice 0A: inert build scaffolding
```

Allowed changes:

```text
add CONFIG_CAPSCHED under scheduler-related Kconfig
add include/linux/capsched.h with documented no-op inline helpers
add kernel/sched/capsched.c with no externally visible behavior
wire capsched.o into the scheduler build only when CONFIG_CAPSCHED=y
optionally add a tiny init-only pr_info_once() only if disabled by default or
  clearly acceptable; otherwise avoid runtime output
```

Disallowed changes in Slice 0A:

```text
do not add task_struct fields
do not modify enqueue, wakeup, pick, switch, tick, fork, exec, or exit logic
do not add syscalls, prctl operations, debugfs knobs, or user ABI
do not add LSM hooks
do not add policy decisions
do not add runtime denial, throttling, or grant validation
do not claim any security property
```

This is narrower than Implementation 0001's original Slice 0, which included
`include/linux/sched.h` as an expected file. The source reading suggests that
touching `task_struct` is better treated as Slice 0B, because it affects layout,
static initialization, idle tasks, and every architecture/config combination.

## Why Not Add task_struct Fields First?

Adding fields is technically simple, but not semantically free:

```text
task_struct layout changes affect cache behavior and randomized layout.
init_task needs correct static defaults.
idle tasks are created through special fork_idle/init_idle paths.
copy_process() duplicates task_struct before scheduler and cgroup setup.
CONFIG_CAPSCHED=n should have zero layout impact.
CONFIG_CAPSCHED=y with pointer fields but no initialized root Domain can create
  misleading NULL semantics before the actual model exists.
```

Therefore the first patch should establish:

```text
Kconfig boundary
build boundary
header namespace
documented no-op helper namespace
```

and stop there.

## Candidate File Touches

Preferred first patch files:

```text
include/linux/capsched.h
kernel/sched/capsched.c
kernel/sched/Makefile
init/Kconfig
```

Avoid in Slice 0A:

```text
include/linux/sched.h
kernel/sched/core.c
kernel/fork.c
fs/exec.c
kernel/exit.c
```

Reason:

```text
Slice 0A should prove that CapSched can exist as a disabled-by-default or
explicitly enabled scaffold without perturbing scheduler behavior.
```

## Kconfig Semantics

Candidate config:

```text
config CAPSCHED
        bool "Capability scheduler scaffolding"
        depends on EXPERT
        default n
        help
          Enable early CapSched-Linux scaffolding for modeling and prototype
          integration. This option does not provide a security boundary and
          does not provide hypervisor-grade isolation.
```

Notes:

```text
depends on EXPERT keeps accidental distro/user enablement unlikely.
default n keeps baseline behavior stable.
help text must explicitly deny security-boundary claims for L0.
```

Placement candidates:

```text
init/Kconfig menu "Scheduler features":
  good because CapSched is a scheduler architecture feature, not a preemption
  model.

kernel/Kconfig.preempt:
  less attractive because CapSched is broader than preemption, although that
  file contains SCHED_CORE and SCHED_CLASS_EXT.
```

Current recommendation: place `CONFIG_CAPSCHED` in `init/Kconfig` under
`menu "Scheduler features"`, near other scheduler feature toggles, with
`depends on EXPERT` and `default n`.

## Build Integration

The scheduler currently builds large aggregate units for efficiency. CapSched
has two options:

```text
Option A:
  obj-$(CONFIG_CAPSCHED) += capsched.o

Option B:
  include "capsched.c" from build_utility.c or build_policy.c
```

Current recommendation: use Option A for Slice 0A.

Reason:

```text
An independent capsched.o keeps the first scaffold isolated.
It avoids increasing the scheduler aggregate translation units before there is
real integration logic.
It makes CONFIG_CAPSCHED=n straightforward.
```

If later helpers become static and hot-path-only, the build strategy can be
revisited.

## Header Boundary

`include/linux/capsched.h` should begin as an inert interface:

```text
#ifdef CONFIG_CAPSCHED
void capsched_init(void);
#else
static inline void capsched_init(void) { }
#endif
```

However, even `capsched_init()` needs a caller. Slice 0A should avoid adding a
caller unless the call is known to be harmless and placed in a non-hot init
path. A stricter first patch can provide only declarations and comments, with no
call sites.

Preferred strict form:

```text
CONFIG_CAPSCHED=y builds capsched.o.
capsched.o contains only inert symbols or internal self-description.
No existing code calls into CapSched yet.
```

## Review Invariants for Slice 0A

The patch must satisfy:

```text
CONFIG_CAPSCHED=n:
  no new object is built
  no task_struct layout change
  no scheduler source code path change
  no user-visible ABI change

CONFIG_CAPSCHED=y:
  tree builds
  no scheduler behavior change
  no security claim
  no runtime denial
  no capability object reachable from tasks
```

## What Slice 0A Enables

After Slice 0A, the project can add narrow follow-on patches:

```text
Slice 0B:
  task_struct fields behind CONFIG_CAPSCHED plus init_task defaults, still no
  enforcement.

Slice 0C:
  default Domain/SchedContext objects and init/fork/idle initialization, still
  permissive.

Slice 0D:
  trace-only lifecycle and switch instrumentation.

Slice 1:
  FrozenRunUse preparation and validation in permissive/diagnostic mode.
```

This sequence keeps review pressure small and prevents "one giant scheduler
semantic patch" from becoming the first Linux modification.

## Open Items Before Applying Slice 0A

1. Decide whether `capsched.c` should export any symbol in Slice 0A or remain
   entirely self-contained.
2. Decide whether a Kconfig help text should say "experimental" or avoid the
   word because Linux already has conventions around experimental features.
3. Decide whether the first build should use only `x86_64_defconfig` or also
   include `tiny.config` and a scheduler-heavy config.
4. Decide whether a short `Documentation/scheduler/capsched.rst` should be
   introduced in Slice 0A or deferred until the first real semantic object.

Current recommendation:

```text
No exported symbols.
Kconfig help says "prototype scaffolding" and "not a security boundary".
No Documentation/ file yet.
Use out-of-tree x86_64_defconfig baseline builds first.
```

## Preliminary Conclusion

The first Linux patch should be smaller than "add CapSched task fields". The
safe first patch is an inert, disabled-by-default build scaffold:

```text
CONFIG_CAPSCHED
+ include/linux/capsched.h
+ kernel/sched/capsched.c
+ kernel/sched/Makefile wiring
```

No behavior, no task layout, no scheduler path changes. This gives the project
a real kernel namespace while preserving compatibility and making the next
semantic patch reviewable.
