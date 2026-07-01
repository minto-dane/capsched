# Analysis 0085: Direct-Call io_uring Adapter Refinement

Status: draft refinement model input, no Linux patch approved

Date: 2026-07-01

Related artifacts:

```text
analysis/0012-io-uring-registered-resource-provenance.md
analysis/0081-direct-call-async-workqueue-io-uring-source-map.md
analysis/0082-direct-call-async-carrier-lifetime-table.md
analysis/0083-direct-call-async-carrier-api-direction.md
analysis/0084-direct-call-workqueue-adapter-refinement.md
formal/0058-direct-call-async-carrier-model/
formal/0059-direct-call-async-carrier-api-sketch-model/
formal/0060-direct-call-workqueue-adapter-refinement-model/
implementation/0012-direct-call-async-carrier-api-sketch.md
```

## Purpose

This note refines only the io_uring adapter side of the shared
`capsched_async_carrier` direction.

It does not approve Linux code, behavior changes, direct-call ABI, public
tracepoints, monitor verification, runtime coverage, or production protection.

## Source Pressure

io_uring has better request-local structure than generic workqueue, but that
does not make existing Linux request state authority.

Potential future storage anchors:

```text
struct io_kiocb
struct io_wq_work
struct io_rsrc_node
io_uring fixed file and fixed buffer tables
io-wq worker submission path
```

Non-authority Linux state:

```text
io_kiocb existence
io_wq_work existence
req->creds
req->tctx
SQPOLL credentials
REQ_F_REISSUE
REQ_F_FIXED_FILE
REQ_F_LINK
REQ_F_CQE_SKIP
io_rsrc_node liveness/refcount
cancel sequence or cancel flags
CQE delivery
request free/cache/ref drop
```

The safe adapter must freeze caller authority after SQE consumption and before
any side effect. It must bind fixed file/buffer resource authority separately
from `io_rsrc_node` liveness. It must validate again before inline issue or
io-wq worker issue.

## Required Adapter State

The io_uring adapter model must distinguish:

```text
request allocation
SQE consumption
caller tuple freeze
resource authority binding
resource generation snapshot
inline issue path
io-wq queued path
worker selection
REQ_F_REISSUE/retry handling
cancel matching
revoke/freshness state
validate state
side-effect state
CQE/result delivery state
BudgetTicket/receipt settlement count
CapSched release state
Linux request/resource refs and free state
linked request authority relation
uring_cmd endpoint authority
```

## Required Safe Transitions

The adapter must support at least:

```text
allocate request storage without authority
consume SQE fields
freeze caller tuple before issue or io-wq publication
bind fixed file/buffer authority explicitly
snapshot resource generation
prepare inline issue without side effects
queue io-wq only after immutable carrier binding
select io-wq worker without worker authority
handle reissue without receipt refresh
handle cancel without monitor revoke proof
revoke_check before validate
validate caller/resource authority intersection
perform side effects only after validation
post or skip CQE as result delivery only
settle BudgetTicket/receipt exactly once
release CapSched refs without owning Linux request/resource cleanup
```

## Required Unsafe Cases

A formal model should reject:

```text
side effect before revoke_check and validate
immutable carrier overwrite
io_kiocb as authority
io_wq_work as authority
req->creds, req->tctx, or SQPOLL creds as Domain authority
io_rsrc_node liveness/refcount as EndpointCap authority
REQ_F_REISSUE as monitor receipt refresh
CQE as settlement or monitor verification proof
cancel flag or cancel_seq as monitor revoke receipt
double settlement
release dropping Linux request/resource refs
stale carrier execution after revoke
linked request implicit authority inheritance
resource update mutating in-flight authority
uring_cmd without typed endpoint authority
ABI approval claim
behavior change claim
monitor verification claim
production protection claim
```

## Linux Source Anchors

Current source anchors for future source-map drift checks:

```text
include/linux/io_uring_types.h
io_uring/io_uring.c
io_uring/io-wq.c
io_uring/rsrc.c
io_uring/rsrc.h
io_uring/cancel.c
io_uring/rw.c
io_uring/register.c
io_uring/sqpoll.c
io_uring/uring_cmd.c
security/security.c
```

Important semantic edges:

```text
io_get_sqe()
io_init_req()
io_assign_file()
io_file_get_fixed()
io_find_buf_node()
__io_issue_sqe()
io_queue_iowq()
io_worker_handle_work()
io_wq_submit_work()
io_rw_should_reissue()
io_cancel_req_match()
io_wq_cancel_cb()
io_req_complete_post()
io_req_put_rsrc_nodes()
io_free_batch_list()
```

These anchors are source locations, not authority roots.

## Non-Claims

This refinement does not claim:

```text
Linux io_uring is CapSched-aware
io_uring workers carry Domain authority
registered resources are EndpointCaps
req->creds or SQPOLL creds are Domain authority
CQEs prove monitor settlement
cancel proves monitor revoke
Linux request free proves CapSched settlement
Linux code is approved
ABI is approved
runtime coverage occurred
monitor enforcement exists
production protection exists
```

## Next Pressure

The corresponding formal model should be:

```text
formal/0061-direct-call-io-uring-adapter-refinement-model/
```

It should prove ordering and authority-separation pressure only. It should not
claim implementation correctness or runtime coverage.
