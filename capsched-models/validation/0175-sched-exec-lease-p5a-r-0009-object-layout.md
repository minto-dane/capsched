# Validation 0175: SchedExecLease P5A-R 0009 Object and Layout

Date: 2026-07-04

Status: passed for object/function-size and task layout evidence. Linux patch
`0009` remains unaccepted.

## Scope

This validation checks generated-object and build-layout evidence for the
concrete `0009` draft at Linux commit:

```text
7a402107fd63faf7063c2dea05e88e7f8a23f4bf
```

It uses the full build outputs from validation/0174:

```text
build/linux-l0-sched-exec-lease-off-p5a-r-0009-x86_64
build/linux-l0-sched-exec-lease-on-p5a-r-0009-x86_64
```

This is not runtime denial, CFS deny-and-repick, QEMU, protection, or cost
evidence.

## Runner

```text
validation/run-sched-exec-lease-p5a-r-0009-object-layout.sh
```

Run output:

```text
build/source-check/sched-exec-lease-p5a-r-0009-object-layout/20260704T-p5ar-0009-object-layout/
```

## Checks

Object evidence:

```text
off fair.o size=157712 sha256=9ef74eed7997d5898b16fb52117c29ca3ecd67423ee527399ab4bbc5ad1854aa
on fair.o size=159416 sha256=ae6605af1b0e133c3faf37f135ed7bf55cff94b2b761e27536c450addcf7e409
off core.o size=347744 sha256=b10d6f05c8be1fd5654ff0686235a4bb2e6c752873518a74d52c697fb189dd1b
on core.o size=347744 sha256=d48b9bd593ae53468b246bbaede0e92a95b1cd8c9598d945be4977936acb8aea
on exec_lease.o size=2304 sha256=75e4085156ebb0610edbef3af9bf281bfc560edc1a59c2246a79c26f6807dd1e
```

Function table counts:

```text
off fair.o defined function count=118
on fair.o defined function count=118
off core.o defined function count=396
on core.o defined function count=396
```

Relevant symbol checks:

```text
pick_task_fair_sched_exec_lease present in off fair.o=true
pick_task_fair_sched_exec_lease present in on fair.o=true
sched_exec_cfs_candidate_key present in off fair.o=false
sched_exec_cfs_candidate_key present in on fair.o=true
```

Task layout probe:

```text
build/task-layout/sched-exec-lease-p5a-r-0009-20260704T034710Z
```

The task layout probe confirmed:

```text
CONFIG off:
  sched_exec field absent
  sizeof(struct task_struct)=0xcc0

CONFIG on:
  sched_exec field present
  sizeof(task_struct.sched_exec)=0x28
  offsetof(task_struct, sched_exec)+1=0x591
  sizeof(struct task_struct)=0xd00
```

The runner also checked that the `0009` delta does not touch
`include/linux/sched.h` and does not add persistent `rq`, `cfs_rq`, or
`sched_entity` layout in `kernel/sched/sched.h`.

## Interpretation

This closes the object/layout evidence part of the `0009` draft acceptance
matrix:

```text
object_function_size_evidence=true
layout_evidence=true
```

It also records that `CONFIG_SCHED_EXEC_LEASE=y` emits the dormant static-key
storage for the candidate path and that CONFIG off does not.

## Non-Claims

This validation does not approve:

```text
accepting 0009
runtime denial correctness
CFS deny-and-repick correctness
runtime coverage
QEMU compatibility
negative denial behavior
monitor verification
production protection
hypervisor-grade isolation
cost-efficiency
deployment readiness
datacenter readiness
```

## Next

The next acceptance step is QEMU denial-disabled boot/workload compatibility,
followed by ordinary-CFS negative denial tests, security diff review, and final
overclaim review.
