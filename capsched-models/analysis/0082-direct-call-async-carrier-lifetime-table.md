# Analysis 0082: Direct-Call Async Carrier Lifetime Table

Status: draft no-patch lifetime table, no Linux patch approved

Date: 2026-06-30

Related artifacts:

```text
formal/0058-direct-call-async-carrier-model/
validation/0091-direct-call-async-carrier-tlc.md
implementation/0011-direct-call-async-carrier-gate.md
analysis/0081-direct-call-async-workqueue-io-uring-source-map.md
analysis/direct-call-async-workqueue-source-map-v1.json
analysis/direct-call-async-io-uring-source-map-v1.json
direct-call-async-carrier-lifetime-table-v1.json
```

## Purpose

This table turns the N-120/N-121 async carrier rules and the N-122 source maps
into a lifecycle obligation list. It still does not choose a patch.

The core rule is:

```text
Domain-originated async work must not become authority merely because Linux
queued, executed, canceled, retried, completed, or freed a generic work item or
io_uring request.
```

## Workqueue Lifetime

The workqueue carrier must be a typed wrapper or container around
Domain-originated work. It cannot be raw `struct work_struct`, worker identity,
callback identity, or pending state.

Required lifecycle:

```text
allocate carrier
freeze caller authority
bind service authority
enqueue generic work
preserve first carrier on pending coalescing
protect pending carrier before callback execution
execute only after service/caller intersection
reject stale or revoked carrier before side effects
handle cancel/flush as synchronization only
handle retry/requeue without receipt refresh
complete/free after receipt and budget settlement
```

Special pressure:

```text
queue_work_on() false path:
  preserve first caller, first BudgetTicket, first monitor receipt, and first
  generation.

mod_delayed_work_on():
  must explicitly preserve, reject, or regenerate carrier state. It cannot
  silently merge a new caller into the existing pending work.
```

## io_uring Lifetime

io_uring has a natural request object, `struct io_kiocb`, and registered
resource nodes, `struct io_rsrc_node`. Those are useful future storage anchors,
but they are not authority unless a future patch adds typed carrier semantics.

Required lifecycle:

```text
allocate request carrier
freeze caller/request authority after SQE consumption
bind fixed file/buffer resource authority explicitly
validate before __io_issue_sqe() side effects
enqueue io-wq only after immutable carrier binding
reject stale/revoked carrier before io_wq_submit_work()
handle cancel as Linux matching plus CapSched generation invalidation
handle REQ_F_REISSUE without receipt refresh
complete CQE as result delivery only
release registered resource refs without treating ref drop as revoke receipt
free carrier after budget/receipt settlement
```

Special pressure:

```text
req->creds, req->tctx:
  Linux execution/request state, not caller Domain authority.

io_rsrc_node:
  registration liveness/refcount state, not EndpointCap authority.

IO_WQ_WORK_CANCEL and cancel_seq:
  cancellation state, not monitor revoke receipt.

CQE:
  result delivery, not monitor verification.
```

## Non-Claims

This table does not approve:

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

## Next Pressure

The next step should be a small formal refinement or implementation-facing
pre-patch design for a typed carrier API sketch, still no Linux behavior
change. The sketch should decide whether the first code slice is:

```text
workqueue-only typed carrier helper
io_uring-only request carrier helper
shared internal capsched_async_carrier type with per-subsystem adapters
```

The decision must be made from lifetime and upstream-maintenance pressure, not
from aesthetic unification.
