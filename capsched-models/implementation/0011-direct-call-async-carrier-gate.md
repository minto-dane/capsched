# Implementation 0011: Direct-Call Async Carrier Gate

Status: proposed implementation-facing gate, no Linux patch approved yet

Date: 2026-06-30

Related artifacts:

```text
formal/0058-direct-call-async-carrier-model/
validation/0091-direct-call-async-carrier-tlc.md
implementation/direct-call-async-carrier-gate-v1.json
implementation/0010-direct-call-receipt-consumer-placement-gate.md
analysis/0080-direct-call-receipt-consumer-source-map.md
analysis/direct-call-receipt-consumer-source-map-v1.json
```

## Purpose

This gate translates the N-120 async carrier model into preconditions for any
future workqueue or io_uring direct-call receipt carrier patch.

Passing this gate means:

```text
The patch proposal has made Domain-originated async authority an explicit typed
carrier with immutable caller identity, caller BudgetTicket, monitor receipt,
service authority, generation, revoke handling, and evidence-class limits.
```

It does not mean:

```text
generic workqueue is CapSched-aware
io_uring workers are CapSched-aware
direct-call stubs exist
ABI is approved
monitor verification occurred
production protection exists
```

## Gate Rows

### DCASYNC-001: Typed Carrier Identity

Required:

```text
Domain-originated async work must carry a typed CapSched carrier distinct from
raw work_struct, task_struct current identity, or io-wq worker identity.
```

Forbidden fallback:

```text
worker current, work_struct address, callback pointer, or generic queue
membership as caller Domain authority
```

### DCASYNC-002: Pending Coalescing Preservation

Required:

```text
if an already-pending work item coalesces a second submission, the first
carrier's caller identity, BudgetTicket, monitor receipt, and generation remain
unchanged.
```

Forbidden fallback:

```text
overwriting caller-specific authority in a reused work_struct after queue_work()
returns false
```

### DCASYNC-003: Caller BudgetTicket Ownership

Required:

```text
async execution on behalf of a caller must charge a caller-owned BudgetTicket or
an explicitly split child ticket derived before enqueue.
```

Forbidden fallback:

```text
service-only budget, worker kthread budget, cgroup CPU charge, or scheduler
runtime accounting as caller resource authority
```

### DCASYNC-004: Service and Caller Intersection

Required:

```text
effective authority is service authority intersected with caller frozen
authority.
```

Forbidden fallback:

```text
service Domain permission alone, caller permission alone, credential snapshot,
namespace membership, or LSM allow result as full async execution authority
```

### DCASYNC-005: Monitor Receipt Provenance

Required:

```text
async carrier may hold opaque monitor receipt references or derived shadows, but
Linux cannot mint receipt authority.
```

Forbidden fallback:

```text
Linux return code, pointer, cached shadow, timeout refresh, or helper success as
monitor receipt
```

### DCASYNC-006: Revoke and Stale Carrier Rejection

Required:

```text
revoked or stale pending carriers are rejected before worker execution, with
generation/epoch ordering recorded.
```

Forbidden fallback:

```text
worker receives stale carrier after revoke, local cleanup as revoke completion,
or retry as renewed receipt
```

### DCASYNC-007: Workqueue Patch Boundary

Required:

```text
generic kernel-internal work remains outside CapSched async authority unless
explicitly classified. Domain-originated work must use the typed carrier path.
```

Forbidden fallback:

```text
global workqueue hook that treats all work as Domain-originated or treats all
kernel-internal work as carrying caller authority
```

### DCASYNC-008: io_uring Patch Boundary

Required:

```text
io_uring requests, registered resources, and io-wq workers must preserve caller
provenance through typed request/resource carriers before any receipt
consumption.
```

Forbidden fallback:

```text
io-wq worker task identity, registered fd existence, or request completion as
caller receipt provenance
```

### DCASYNC-009: Evidence Class Split

Required:

```text
source-only maps, formal models, compile checks, trace observations,
monitor-backed runtime tests, and production protection evidence stay separate.
```

Forbidden fallback:

```text
TLC pass, source anchor, inert type, or trace plan as Linux behavior approval,
ABI approval, monitor verification, runtime coverage, or production protection
```

## Required Evidence Before Patch

Before any workqueue or io_uring direct-call receipt carrier patch:

```text
1. Gate rows DCASYNC-001 through DCASYNC-009 must be satisfied or explicitly
   carried as blockers.
2. The proposed carrier storage lifetime must be written down, including
   allocation, refcounting or ownership, enqueue, coalescing, execution,
   cancellation, revoke, and free.
3. Pending coalescing must state what happens when queue_work() returns false:
   no carrier overwrite, no accidental second-caller budget charge, and no
   hidden authority transfer.
4. Worker execution must name the exact typed-carrier retrieval path and must
   reject worker task identity as authority.
5. Service/caller authority intersection must be represented before endpoint
   side effects.
6. Budget accounting must name caller ticket, split child ticket, settlement,
   and overrun behavior.
7. Revoke ordering must cover queued, pending, executing, completed, canceled,
   retried, and freed carriers.
8. Workqueue and io_uring must have separate source maps before code review.
9. Non-claims for ABI, tracepoints, runtime coverage, monitor verification,
   behavior change, and production protection must remain explicit.
```

## Exit Rule

This gate can only permit a future candidate patch proposal. It cannot approve
a patch by itself, and it cannot turn generic async execution into a security
boundary without a typed carrier implementation and monitor-backed evidence.
