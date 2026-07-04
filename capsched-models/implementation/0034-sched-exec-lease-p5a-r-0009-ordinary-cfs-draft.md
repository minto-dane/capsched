# Implementation 0034: SchedExecLease P5A-R 0009 Ordinary-CFS Draft

Date: 2026-07-03

Status: Linux patch `0009` drafted as an untrusted ordinary-CFS-only behavior
candidate. It is not accepted.

## Purpose

This record captures the first P5A-R Linux behavior-candidate patch:

```text
deny one ordinary CFS candidate before final CFS settlement, then let the
ordinary CFS picker try to find another supported ordinary CFS candidate
```

The patch is intentionally dormant. It introduces a disabled source shape for
review and validation, not a runtime security boundary.

## Linux Patch

```text
linux_branch=capsched-linux-l0
parent_commit=d812f83c033a9f9b3d533e667e7106a5734eb30b
linux_commit=7a402107fd63faf7063c2dea05e88e7f8a23f4bf
upstream_ref=upstream/master
upstream_commit=71dfdfb0209b43dfd6f494f84f5548e4cfd18cb5
patch_file=linux-patches/patches/capsched-linux-l0/0009-sched-fair-Draft-ordinary-CFS-exec-lease-candidate.patch
patch_sha256=21dd92416d8309b82a2da7ead8fa9998661cff645f845dcdd0066b6393cd2d25
series_sha256=7508a9c8e3759a72b9dec0851d03e9d52c99cd1a96795e7e951248f4c0c8ae6d
```

Touched files:

```text
kernel/sched/core.c
kernel/sched/fair.c
kernel/sched/sched.h
```

## Source Shape

The ordinary CFS fast path in `__pick_next_task()` now calls a dedicated
wrapper:

```text
pick_task_fair_sched_exec_lease()
```

The normal fair class picker remains:

```text
pick_task_fair()
```

`fair_server_pick_task()` and `.pick_task = pick_task_fair` continue to use the
normal picker, so the draft does not claim deadline fair-server or class-loop
settlement.

The draft adds a stack-local picker carrier:

```text
struct sched_exec_cfs_pick_state
```

It contains:

```text
denied task identity receipt capacity = 1
blocked group entity receipt capacity = 1
retry limit = 1
candidate CPU
attempt epoch
enabled flag
blocked-on-denied flag
```

It does not add denial fields to `task_struct`, `sched_entity`, `rq`, or
`cfs_rq`.

The draft makes `pick_eevdf()` consult
`sched_exec_cfs_entity_pickable()` at each existing candidate-return family:

```text
singleton
next buddy
protected current
leftmost eligible
heap candidate
current override
```

The leaf task is still validated after `task_of(se)`, but before
`task_throttle_setup_work()` and before `put_prev_set_next_task()` in the
ordinary CFS fast path.

## Cross-Path Predicate

The candidate path is active only if all of the following are true:

```text
static_branch_unlikely(&sched_exec_cfs_candidate_key)
!scx_enabled()
!sched_core_enabled(rq)
!sched_proxy_exec()
```

The static key has no enable site in this patch.

## Validation Status

Already executed:

```text
git diff --check HEAD^..HEAD
checkpatch --no-tree 0009 patch
patch queue replay to 7a402107fd63faf7063c2dea05e88e7f8a23f4bf
CONFIG_SCHED_EXEC_LEASE=off targeted scheduler object build
CONFIG_SCHED_EXEC_LEASE=on targeted scheduler object build
CONFIG_SCHED_EXEC_LEASE=off full vmlinux build
CONFIG_SCHED_EXEC_LEASE=on full vmlinux build
```

The initial targeted build attempt was blocked by a missing host dependency:

```text
missing /usr/include/gelf.h required by tools/objtool
```

After installing `libelf-dev`, validation/0173 reran the targeted build and
passed for both CONFIG states.

Object evidence:

```text
off fair.o size=164608 sha256=00d68ab37b06b4f84cf303949600666df5fc3376c0df28120c067fd3994b8dea
off core.o size=364448 sha256=82db4e1ee48088a9cc85fa2694efc24ce7416b68a704a0d534391c547a1a1f69
on fair.o size=166376 sha256=ef39d7414cf451770f093e1962d59cb766afecb06157a4f3b7942d1a9b5f512b
on core.o size=364448 sha256=d8a85d9edc8578c8a991ec928d5e953734965a7dcc2e18ec5365640f76128863
```

This is targeted scheduler object build evidence only, not full `vmlinux`
build acceptance.

Full build evidence:

```text
off vmlinux sha256=f76dbaed7fd47fe812475f26a10d43053911e0d4319a6eb4681db378ba26eb1f
on vmlinux sha256=367103fd9d3bb1bdebcb87d1cbcf9ac47fee4639b76b06bb7934f9f3c5cd8281
on exec_lease.o sha256=75e4085156ebb0610edbef3af9bf281bfc560edc1a59c2246a79c26f6807dd1e
off exec_lease.o absent
```

Object/layout evidence:

```text
validation=0175
off fair.o size=157712 sha256=9ef74eed7997d5898b16fb52117c29ca3ecd67423ee527399ab4bbc5ad1854aa
on fair.o size=159416 sha256=ae6605af1b0e133c3faf37f135ed7bf55cff94b2b761e27536c450addcf7e409
off core.o size=347744 sha256=b10d6f05c8be1fd5654ff0686235a4bb2e6c752873518a74d52c697fb189dd1b
on core.o size=347744 sha256=d48b9bd593ae53468b246bbaede0e92a95b1cd8c9598d945be4977936acb8aea
task_layout_probe=build/task-layout/sched-exec-lease-p5a-r-0009-20260704T034710Z
```

## Claims

Allowed claim:

```text
0009 is drafted as a dormant ordinary-CFS-only source candidate
```

Not claimed:

```text
0009 accepted
runtime denial correctness
CFS deny-and-repick correctness
broad move denial
runtime coverage
QEMU compatibility
object/layout overhead
production protection
hypervisor-grade isolation
cost-efficiency
datacenter readiness
monitor-backed enforcement
```

## Next

Run validation/0172. If it passes, `0009` remains only a source-gated draft.
Acceptance still requires the remaining matrix from implementation/0033,
including QEMU compatibility, negative denial tests, security diff review, and
final overclaim review.
