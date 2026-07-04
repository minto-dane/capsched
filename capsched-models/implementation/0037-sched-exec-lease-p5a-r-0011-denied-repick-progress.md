# Implementation 0037: SchedExecLease P5A-R 0011 Denied Repick Progress

Date: 2026-07-04

Status: corrective draft Linux patch applied after QEMU negative validation
exposed a CFS deny-and-repick forward-progress bug. This is not accepted as
production denial policy or protection.

## Purpose

Validations/0181 and 0182 showed that the current `0009/0010` draft path can
stall or time out after a synthetic denied ordinary-CFS task becomes the visible
best candidate.

The root cause is semantic, not a host PC speed issue:

```text
upstream CFS:
  pick_next_entity() returning NULL while entities are queued is usually a
  delayed-entity dequeue signal.

SchedExecLease draft:
  denied-candidate filtering adds a new NULL reason.

bug:
  __pick_task_fair() can retry/newidle-balance around the same denied/blocked
  state without making progress.
```

## Linux Patch

```text
linux_commit=38340eceafa88119ba3e0bcdc10f309bfff6462b
linux_subject=sched/fair: Fix exec lease denied CFS repick progress
patch_queue_file=linux-patches/patches/capsched-linux-l0/0011-sched-fair-Fix-exec-lease-denied-CFS-repick-progress.patch
patch_queue_sha256=a2e93e499321e85e4c886ed2e3c7436fe1c1b59e1faa439e2ffa0e1cdd0eafd5
series_sha256=b1589e42886b374af8f1288f6e2608f4a1341070b07e0704c73745ee6b0b503a
```

Touched Linux files:

```text
kernel/sched/fair.c
```

## Change Shape

The patch adds:

```text
sched_exec_cfs_pickable_fallback()
```

This fallback is used only when the SchedExecLease attempt-local state has
already observed denied-candidate blockage. It scans the current CFS runqueue
for the next entity that is both:

```text
entity_eligible(cfs_rq, se)
sched_exec_cfs_entity_pickable(pick, se)
```

The patch also:

```text
- clears stale denied blockage when an allowed delayed entity is dequeued
- avoids newidle retry loops when the only known blocker is a denied candidate
```

## Design Caveat

This fallback repairs the immediate draft-path forward-progress bug, but it is
not the final production data structure.

Production-quality SchedExecLease should not rely on unstructured dynamic
filtering after ordinary EEVDF has already selected a denied candidate. The
long-term design should make pickability part of the scheduler-visible
selection structure, or otherwise provide a source-proved bounded search whose
cost and fairness effects are explicitly modeled.

## Fast Evidence

Patch style:

```text
checkpatch_strict=clean
```

Targeted build:

```text
run_id=20260704T-p5ar-0011-targeted-build
out_dir=build/source-check/sched-exec-lease-p5a-r-0011-targeted-build/20260704T-p5ar-0011-targeted-build
```

Objects:

```text
off_fair_o_size=164608
off_fair_o_sha256=80b826bcc394177419dc9a2d2c19a4074957d5aa02e1ca19022c47681dc6a9cb
off_core_o_size=364448
off_core_o_sha256=82db4e1ee48088a9cc85fa2694efc24ce7416b68a704a0d534391c547a1a1f69
on_fair_o_size=167416
on_fair_o_sha256=ee5d2d5b5655368731884826d6b21ab312c96864c384a33f3d94551802b79961
on_core_o_size=364448
on_core_o_sha256=d8a85d9edc8578c8a991ec928d5e953734965a7dcc2e18ec5365640f76128863
```

## Required Next Validation

Rerun the P5A-R QEMU negative workload against `0011`:

```text
capsched/capsched-models/validation/run-sched-exec-lease-p5a-r-0010-negative-qemu.sh
```

Expected minimal markers:

```text
NEGATIVE_ALLOWED_STARTED
NEGATIVE_CHILDREN_RELEASED
NEGATIVE_ALLOWED_DONE
NEGATIVE_ALLOWED_NEXT > 0
NEGATIVE_DENIED_NEXT == 0
NEGATIVE_RESULT PASS
```

## Non-Claims

This patch does not approve:

```text
accepted production execution lease policy
capability semantics
public ABI
public tracepoint ABI
debugfs/sysctl/proc control
LSM/cgroup/namespace policy hook
monitor call
runtime denial correctness
CFS deny-and-repick correctness
runtime coverage
protection
cost efficiency
deployment readiness
datacenter readiness
```
