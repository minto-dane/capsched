# Analysis 0084: Direct-Call Workqueue Adapter Refinement

Status: draft refinement model input, no Linux patch approved

Date: 2026-07-01

Related artifacts:

```text
analysis/0034-workqueue-kthread-budgetticket-carrier.md
analysis/0045-workqueue-internal-redesign-boundary.md
analysis/0046-workqueue-origin-taxonomy.md
analysis/0081-direct-call-async-workqueue-io-uring-source-map.md
analysis/0082-direct-call-async-carrier-lifetime-table.md
analysis/0083-direct-call-async-carrier-api-direction.md
formal/0058-direct-call-async-carrier-model/
formal/0059-direct-call-async-carrier-api-sketch-model/
implementation/0011-direct-call-async-carrier-gate.md
implementation/0012-direct-call-async-carrier-api-sketch.md
```

## Purpose

N-126 accepted a shared internal `capsched_async_carrier` semantic core with
separate subsystem adapters. This note refines only the workqueue adapter side.

It does not approve Linux code, behavior changes, public ABI, public
tracepoints, monitor verification, runtime coverage, or production protection.

## Source Pressure

Linux workqueue naturally carries:

```text
struct work_struct
pending state
pool/worker execution state
callback function pointer
worker task context
cancel/flush synchronization state
delayed-work timer state
```

It does not naturally carry:

```text
caller Domain epoch/generation
frozen caller authority
caller BudgetTicket
opaque monitor receipt
service/resource authority binding
carrier generation
settlement proof
monitor revoke proof
```

The important semantic fact is that `queue_work()` returns false when a work
item is already pending. A future CapSched adapter must therefore treat a second
Domain-originated submission as a separate caller candidate that must be
rejected, settled, released, or explicitly monitor-regenerated. It cannot
overwrite the already pending carrier.

## Required Adapter State

A workqueue adapter model must distinguish:

```text
first frozen caller tuple
first BudgetTicket
first monitor receipt or derived shadow
first carrier generation
service/resource binding
Linux work publication
pending/coalesced second-caller candidate
delayed-work retime state
self-requeue state
callback entry state
revoke_check state
validate state
side-effect state
settlement count
CapSched release state
Linux work object lifetime
```

The first carrier tuple is immutable after freeze. The callback may use the
carrier as input to CapSched validation, but neither `work_struct`, callback
identity, worker identity, nor pending state is authority.

## Required Safe Transitions

The adapter must support at least:

```text
create empty carrier storage
freeze caller tuple before publication
bind service/resource tuple
publish typed wrapper through queue_work()/queue_work_on()
handle queue_work false by preserving the first carrier
settle/release the rejected second-caller candidate
handle delayed-work retime without receipt refresh
enter callback in worker context without worker identity authority
perform revoke_check before validation
validate service/resource authority intersect caller authority
perform side effect only after validation
settle BudgetTicket and receipt exactly once
release CapSched refs without freeing or completing the Linux work object
```

## Required Unsafe Cases

A formal model should reject:

```text
side effect before revoke_check and validate
freezing authority from work_struct/callback/worker identity
pending work overwrite by a second caller
second-caller leak after queue_work false
delayed-work retime refreshing a monitor receipt
self-requeue refreshing a monitor receipt
cancel/flush treated as monitor revoke receipt
worker task identity treated as authority
release dropping Linux work references or freeing storage
double settlement
ABI approval claim
behavior change claim
monitor verification claim
production protection claim
```

## Linux Source Anchors

Current source anchors for future source-map drift checks:

```text
include/linux/workqueue.h
kernel/workqueue.c
queue_work()
queue_work_on()
__queue_work()
mod_delayed_work_on()
process_one_work()
worker->current_func(work)
work->func(work)
cancel_work_sync()
flush_work()
```

These anchors are not stable authority boundaries. They are source locations
where a future typed adapter must avoid confusing Linux lifecycle state with
CapSched authority.

## Non-Claims

This refinement does not claim:

```text
generic Linux workqueue is CapSched-aware
all kernel-internal work must carry Domain authority
Domain-originated work can use raw work_struct as authority
queue_work false is harmless without settlement
delayed-work retime is receipt renewal
self-requeue is receipt renewal
cancel or flush is monitor revoke
worker task identity is caller authority
Linux behavior has changed
monitor enforcement exists
production protection exists
```

## Next Pressure

The corresponding formal model should be deliberately small and adversarial:

```text
formal/0060-direct-call-workqueue-adapter-refinement-model/
```

It should prove only ordering and authority-separation pressure, not runtime
coverage or implementation correctness.
