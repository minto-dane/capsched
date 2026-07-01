# Analysis 0081: Direct-Call Async Workqueue and io_uring Source Map

Status: draft source-only async carrier map, no patch approved

Date: 2026-06-30

## Purpose

N-120 modeled the typed async carrier required before Domain-originated
direct-call receipts can cross workqueue or io_uring worker execution. N-121
turned that model into the DCASYNC implementation-facing gate. This analysis
maps current upstream Linux source anchors for DCASYNC-007 and DCASYNC-008
without choosing a patch.

Machine-readable artifacts:

```text
direct-call-async-workqueue-source-map-v1.json
direct-call-async-io-uring-source-map-v1.json
```

## Workqueue Result

Generic workqueue carries `struct work_struct *`, pending bits, queue/pool
state, callback identity, and worker/kthread execution context. It does not
carry CapSched Domain authority, BudgetTicket identity, monitor receipt
identity, or carrier generation.

Therefore a future CapSched workqueue path must be a typed wrapper for
Domain-originated work. Generic `queue_work()`, `__queue_work()`, and
`process_one_work()` cannot be treated as authority gates for all kernel work.

Important source facts:

```text
queue_work() -> queue_work_on()
queue_work_on() sets WORK_STRUCT_PENDING and returns false if already pending
process_one_work() eventually calls worker->current_func(work)
worker current/current_func/current_work/work_busy are execution/debug facts
flush/cancel synchronize work, but are not monitor revoke receipts
mod_delayed_work_on() can modify pending delayed work timing and must not
silently replace caller-specific carrier state
```

## io_uring Result

io_uring has better per-request structure than generic workqueue, but the
current source still only carries Linux request/task/cred/resource state.

Natural future storage anchors are:

```text
struct io_kiocb:
  per-request typed carrier state

struct io_rsrc_node:
  registered file/buffer frozen-resource metadata
```

However, current `req->creds`, `req->tctx`, registered fd/buffer liveness,
`IO_WQ_WORK_CANCEL`, `cancel_seq`, CQE posting, and request completion are not
CapSched authority or monitor receipt proof.

Important source facts:

```text
io_init_req() binds request state after SQE consumption
__io_issue_sqe() and def->issue() are side-effect boundaries
io_queue_iowq() enqueues &req->work for worker execution
io_worker_handle_work() selects work and calls io_wq_submit_work()
io_wq_submit_work() converts io_wq_work back to io_kiocb
io_rsrc_node lookup/refcounting proves registration liveness, not authority
cancel and retry paths do not encode monitor generation or receipt validity
REQ_F_REISSUE can re-enter paths and must be covered by carrier lifetime rules
```

## Shared Non-Claims

These source maps do not claim:

```text
Linux workqueue is CapSched-aware
io_uring workers are CapSched-aware
direct-call stubs exist
direct-call ABI is approved
public tracepoint ABI is approved
runtime coverage occurred
monitor verification occurred
behavior-changing Linux patches are approved
production protection exists
```

## Next Pressure

Before code, the next design step should turn these source maps into a carrier
lifetime table:

```text
allocate -> freeze -> enqueue -> pending coalesce -> execute -> cancel ->
revoke -> retry/reissue -> complete -> free
```

That table must remain split between generic workqueue and io_uring because
their coalescing, request lifetime, registered-resource, and retry semantics are
not the same.
