# Analysis 0083: Direct-Call Async Carrier API Direction

Status: accepted no-behavior API direction, no Linux patch approved

Date: 2026-07-01

Related artifacts:

```text
capsched-ai/decisions/ADR-0009-async-carrier-api-direction.md
formal/0058-direct-call-async-carrier-model/
validation/0091-direct-call-async-carrier-tlc.md
implementation/0011-direct-call-async-carrier-gate.md
analysis/0081-direct-call-async-workqueue-io-uring-source-map.md
analysis/0082-direct-call-async-carrier-lifetime-table.md
validation/0094-direct-call-async-lifetime-table-result.md
analysis/direct-call-async-carrier-api-direction-v1.json
```

## Purpose

This note chooses the direction for the next no-behavior API sketch.

It chooses:

```text
shared internal capsched_async_carrier semantic core
+
per-subsystem adapters
```

It does not approve:

```text
Linux code
workqueue integration
io_uring integration
direct-call ABI
public tracepoints
runtime coverage
monitor verification
behavior changes
production protection
```

## Decision Pressure

The N-123 lifetime table shows a split that must be preserved:

```text
shared invariant:
  caller authority must be frozen
  caller BudgetTicket must be preserved
  monitor receipt reference must be opaque and non-Linux-minted
  generation/epoch/revoke state must be checked before side effects
  service/resource authority must intersect caller frozen authority
  cleanup/free/cancel/retry/completion are not revoke or receipt proofs

different mechanics:
  workqueue has pending coalescing and delayed-work retiming hazards
  io_uring has request/resource/reissue/CQE/refcount hazards
```

Therefore the core should unify only the invariant. The adapters should carry
Linux subsystem-specific lifetime obligations.

## Option Review

### Workqueue-Only Helper

Strength:

```text
small first surface
directly addresses queue_work() false and worker-identity hazards
```

Risk:

```text
bakes workqueue pending/coalescing semantics into the authority vocabulary
duplicates the common carrier semantics later for io_uring
does not naturally represent registered resources, request reissue, links, or
CQE delivery
```

Decision:

```text
reject as main direction
keep as a required adapter
```

### io_uring-Only Request Carrier

Strength:

```text
natural request object
clear request/resource lifecycle pressure
important high-risk async syscall surface
```

Risk:

```text
overfits to io_kiocb, SQE, CQE, io-wq, and resource-ref lifetimes
tempts false authority from req->creds, req->tctx, io_rsrc_node, CQE, cancel,
or retry state
leaves generic service-domain workqueue provenance unresolved
```

Decision:

```text
reject as main direction
keep as a required adapter
```

### Shared Internal Carrier With Adapters

Strength:

```text
keeps one CapSched authority vocabulary
reduces long-term dialect drift
keeps Linux patch churn local to adapters
lets workqueue and io_uring lifetimes remain separate
matches the long-horizon thin-waist rule
```

Risk:

```text
dangerous if shared means generic Linux async execution authority
dangerous if the core hides coalescing, retry, reissue, or completion hazards
dangerous if adapters treat existing Linux state as a receipt
```

Decision:

```text
accept as next no-behavior API sketch direction
```

## Required Core Contract

The core carries only CapSched authority state:

```text
caller Domain/epoch/generation
frozen caller authority reference
caller BudgetTicket or split child ticket
opaque monitor receipt reference or derived shadow
service/resource authority binding
carrier generation
revoke/freshness state
settlement/release state
```

The core operations should be neutral:

```text
freeze
bind
validate
revoke_check
settle
release
```

The core should not use subsystem verbs such as:

```text
enqueue
dispatch
issue_sqe
queue_work
complete_cqe
finish_work
```

Those belong in adapters.

## Adapter Contracts

Workqueue adapter must cover:

```text
typed wrapper/container around struct work_struct
freeze before queue_work_on()
queue_work_on() == false preserves first carrier
mod_delayed_work_on() preserves, rejects, or monitor-regenerates carrier state
self-requeue does not refresh receipt
cancel/flush is synchronization only
callback entry validates carrier before service side effects
free happens only after settlement/release ownership is clear
```

io_uring adapter must cover:

```text
carrier attached to explicit request/resource storage
freeze after SQE consumption and before side effects
fixed file/buffer authority separated from io_rsrc_node liveness
validate before __io_issue_sqe()
validate before io_wq_submit_work()
linked requests have explicit carrier relationship
REQ_F_REISSUE does not refresh receipt
cancel state is not monitor revoke receipt
CQE is result delivery only
ref drop/free is not settlement proof
```

## Hard Rejections

The next sketch must reject:

```text
work_struct as authority
callback pointer as authority
worker task identity as authority
io_wq_work as authority
io_kiocb existence as authority
req->creds or req->tctx as caller Domain authority
io_rsrc_node liveness as EndpointCap authority
CQE as monitor verification
cancel flags as monitor revoke receipt
retry or reissue as receipt refresh
Linux cleanup/free/ref-drop as settlement proof
```

## Upstream Churn Posture

This direction is intentionally long-term maintainable:

```text
stable core:
  CapSched authority fields and neutral operations

churn-facing adapters:
  workqueue placement, pending semantics, delayed work, callback entry, free
  io_uring request fields, resource refs, io-wq punt, reissue, completion
```

If upstream changes workqueue or io_uring internals, the adapter source maps
and placement rows should update first. The shared core should change only if
the CapSched authority invariant changes.

## Non-Claims

This decision is a design direction only. It does not approve any Linux code,
direct-call ABI, public tracepoint ABI, behavior change, monitor verification,
runtime coverage, or production protection.

