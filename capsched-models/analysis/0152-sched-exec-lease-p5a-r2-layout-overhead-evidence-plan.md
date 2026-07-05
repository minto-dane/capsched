# Analysis 0152: SchedExecLease P5A-R2 Layout and Overhead Evidence Plan

Date: 2026-07-04

Status: evidence-plan gate. No Linux patch is approved.

## Purpose

Analysis/0151 sketches a future `min_pickable_vruntime`-style Fresh summary.
That sketch is production-shaped, but it points directly at hot scheduler
layout:

```text
struct sched_entity
struct cfs_rq
struct rq
struct task_struct
pick_eevdf()
min_vruntime_update()
__enqueue_entity()
__dequeue_entity()
pick_next_entity()
__pick_task_fair()
```

This note defines the evidence contract that must exist before a P5A-R2 Linux
behavior patch can add summary fields or alter the picker path.

## Evidence Classes

The future patch must produce separate evidence for four cases:

```text
CONFIG_SCHED_EXEC_LEASE=n:
  no new fields, symbols, branches, objects, or hot function growth.

CONFIG_SCHED_EXEC_LEASE=y, selector disabled:
  static-key / feature-disabled path measured separately from CONFIG=n.

CONFIG_SCHED_EXEC_LEASE=y, selector candidate enabled:
  hot path object/function growth measured and bounded.

runtime tests:
  only runtime tests can support runtime behavior claims.
```

Object evidence is not runtime evidence. A clean object diff cannot claim
runtime denial correctness, protection, cost efficiency, or datacenter
readiness.

## Layout Probe Requirements

A future P5A-R2 candidate that touches hot layout must add build-only probes
for:

```text
sizeof(struct sched_entity)
offset/size of run_node
offset/size of min_vruntime
offset/size of future sched_exec_min_pickable_vruntime
sizeof(struct cfs_rq)
offset/size of tasks_timeline
offset/size of curr / next
sizeof(struct rq)
selected hot offsets near nr_running and cfs
sizeof(struct task_struct)
offset/size of task_struct.sched_exec baseline
```

The probe must work for CONFIG off and CONFIG on build directories. CONFIG off
must not emit future P5A-R2 field symbols.

## Object and Function Requirements

The object evidence must compare at least:

```text
kernel/sched/fair.o
kernel/sched/core.o
kernel/sched/exec_lease.o
vmlinux
```

The function-size table must include:

```text
pick_eevdf
min_vruntime_update
__enqueue_entity
__dequeue_entity
pick_next_entity
__pick_task_fair
put_prev_entity
```

The candidate must record exact before/after sizes and hashes, not just "build
passed".

## Threshold Policy

No generic "small enough" threshold is accepted for hot structures.

```text
CONFIG=n:
  expected delta is zero for future P5A-R2 layout and object symbols.

hot layout:
  any non-zero delta must have explicit review text and evidence.

hot function growth:
  any growth in picker/update callbacks must be listed by function.

cost claim:
  requires benchmark/perf evidence, not model or object evidence.
```

## Required Negative Checks

The evidence plan must fail if a future patch:

```text
adds a public ABI or trace ABI
exports new symbols
calls a monitor from the picker
does policy lookup from the picker
extends the 0012 post-filter fallback
uses unbounded rb_next() scan
adds a separate eligible tree without a new design gate
uses synthetic task->comm authority
claims runtime protection or cost efficiency from build evidence
```

## Non-Claims

This plan does not approve:

```text
Linux code changes
new hot fields
accepting 0009-0012
runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage
monitor enforcement
production protection
cost efficiency
deployment readiness
datacenter readiness
```

## Next

If this gate validates, the next reviewable work is a concrete P5A-R2 object
probe plan or a no-behavior probe patch. A behavior patch should still wait
until the layout probe and disabled-overhead evidence exist.
