# Analysis 0015: Endpoint Async Linux Attachment Map

Status: Draft

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This note maps the checked Endpoint Async Provenance model onto concrete Linux
objects. It does not accept behavior-changing patch points. It records where
CapSched authority could be attached without confusing:

```text
registered resource authority
per-request frozen endpoint authority
worker/service authority
Linux credential override
caller budget donation
```

The model pressure is:

```text
No FrozenEndpointUse, no async endpoint execution.
Linux credential override must not change CapSched DomainTag.
```

## Model-to-Linux Map

| Model object | Linux object candidates | Reading |
| --- | --- | --- |
| `RegisteredEndpoint` | `struct io_rsrc_node`, socket file binding | io_uring fixed files and buffers are already represented by `io_rsrc_node` in `io_uring/rsrc.h:15-24`. Socket endpoints are bound to files in `sock_alloc_file()` at `net/socket.c:525-549`. |
| `FrozenEndpointUse` | `struct io_kiocb`, socket operation wrapper, CapSched work wrapper | `struct io_kiocb` already carries opcode, file, ctx, tctx, file_node, buf_node, creds, task_work, and io-wq work at `include/linux/io_uring_types.h:737-817`. It is the strongest per-request carrier. |
| `WorkerServiceAuthority` | `struct io_worker`, `struct io_wq`, workqueue worker, service Domain wrapper | io-wq workers carry worker task, owning wq, account, and current work at `io_uring/io-wq.c:48-70`; generic workqueue workers expose current work/function/pwq around `kernel/workqueue.c:3220-3295`. |
| `BudgetTicket` | no direct Linux equivalent | A new CapSched object is needed. It should be attached to request/work context, not inferred from Linux credentials, cgroup, or worker identity. |
| `CredentialOverride` | `REQ_F_CREDS`, `req->creds`, io_uring personalities | io_uring stores custom credentials in `io_kiocb` and overrides around issue at `io_uring/io_uring.c:1385-1403`; personality setup stores `REQ_F_CREDS` at `io_uring/io_uring.c:1826-1840`. This must remain a policy input, not a DomainTag switch. |

## io_uring

### Existing Attachment Points

`io_kiocb` is the natural request carrier:

```text
include/linux/io_uring_types.h:737-817
```

It already contains:

```text
file / cmd
opcode
ctx
tctx
buf_node
file_node
io_task_work
creds
work
```

`io_rsrc_node` is the natural registered resource carrier:

```text
io_uring/rsrc.h:15-24
```

Files are registered or updated through `fget(fd)` and node installation:

```text
io_uring/rsrc.c:335-360
io_uring/rsrc.c:616-674
```

Fixed files are attached to requests through `io_file_get_fixed()`:

```text
io_uring/io_uring.c:1571-1588
```

Request issue funnels through:

```text
io_uring/io_uring.c:1361-1373   io_assign_file()
io_uring/io_uring.c:1377-1408   __io_issue_sqe()
io_uring/io_uring.c:1410-1436   io_issue_sqe()
io_uring/io_uring.c:1475-1569   io_wq_submit_work()
```

io-wq worker execution funnels through:

```text
io_uring/io-wq.c:598-652
```

Task-work completion and fallback execution use:

```text
io_uring/tw.h:40-50
io_uring/tw.c:31-56
io_uring/tw.c:63-125
io_uring/tw.c:221-230
```

### Candidate CapSched Shape

The first credible design is:

```text
io_rsrc_node:
  optional registered endpoint basis
  endpoint id/generation
  registering Domain/epoch
  resource type: file or buffer

io_kiocb:
  optional FrozenEndpointUse
  operation type derived from opcode and file/socket/device type
  caller Domain/epoch
  resource generation snapshot
  service Domain
  BudgetTicket pointer or id
```

Do not treat `ctx->submitter_task`, `req->creds`, or `io_wq->task` as the
authority root. They are useful identity or policy facts, but the model says
the worker must execute against the request's frozen authority.

### Validation Gates for Future Patches

Any io_uring CapSched patch should prove:

```text
fixed file registration freezes or records endpoint basis
each request derives FrozenEndpointUse before it can reach io-wq execution
io_wq_submit_work() rejects or cancels missing/stale FrozenEndpointUse
REQ_F_CREDS does not change frozen Domain/epoch
resource update/unregister invalidates or cancels affected requests
uring_cmd gets typed endpoint authority, not generic file authority
```

`IORING_OP_URING_CMD` is a high-risk typed endpoint. It checks
`security_uring_cmd()` before calling `file->f_op->uring_cmd()` at:

```text
io_uring/uring_cmd.c:239-271
```

Network uring commands route into socket option and timestamp operations:

```text
io_uring/cmd_net.c:171-191
```

Therefore `uring_cmd` needs operation-specific endpoint authority. A broad
"registered file may be used" grant is too weak.

## Generic Workqueue

`struct work_struct` is intentionally tiny and encodes state in `data` bits:

```text
include/linux/workqueue.h:20-80
```

Queueing and execution central points:

```text
kernel/workqueue.c:2275-2411   __queue_work()
kernel/workqueue.c:2442-2458   queue_work_on()
kernel/workqueue.c:3220-3295   process_one_work()
kernel/workqueue.c:3431-3487   worker_thread()
```

Reading:

```text
Generic workqueue is a poor place to store CapSched authority directly.
Many subsystems embed work_struct in their own objects.
The data word is already overloaded with workqueue state.
Security semantics would be ambiguous if all work_struct users were treated as
Domain-derived caller work.
```

Preferred design:

```c
struct capsched_work {
        struct work_struct work;
        struct capsched_work_ctx ctx;
};
```

Only Domain-derived async work should be required to use the wrapper. Pure
kernel maintenance work should be explicitly classified as service/root work,
not accidentally attributed to the current user task.

Generic workqueue hooks are still useful for:

```text
debug assertion
trace coverage
detecting unwrapped Domain-derived work
service Domain accounting
```

They should not be the only security root.

## task_work

`callback_head` is also tiny:

```text
include/linux/types.h:252-255
```

`task_work_add()` queues a callback onto a target task:

```text
kernel/task_work.c:59-104
```

`task_work_run()` executes callbacks under `current`:

```text
kernel/task_work.c:200-238
```

Reading:

```text
task_work has target-task identity, but not necessarily queuer authority.
It is LIFO, callbacks may add more work, and callbacks execute under current.
```

Preferred design:

```text
self task_work:
  may use target task Domain if queuer == executor and operation is self-scoped

cross-task task_work:
  requires ThreadControlCap or typed EndpointCap

io_uring task_work:
  should use the io_kiocb FrozenEndpointUse rather than callback_head itself
```

Do not add ambient authority to `callback_head`.

## Socket Endpoints

Sockets have operation-specific methods:

```text
include/linux/net.h:137-149    struct socket
include/linux/net.h:181-237    struct proto_ops
```

Socket file binding:

```text
net/socket.c:525-549           sock_alloc_file()
net/socket.c:579-585           sock_from_file()
```

Operation hooks:

```text
net/socket.c:1580-1694         __sock_create()
net/socket.c:1912-1951         bind
net/socket.c:1964-1989         listen
net/socket.c:1997-2035         accept
net/socket.c:2118-2137         connect
net/socket.c:785-790           sendmsg LSM then protocol op
net/socket.c:1144-1148         recvmsg LSM then protocol op
net/socket.c:2335-2355         setsockopt
security/security.c:4180-4405  socket LSM hooks
```

Important finding:

```text
CapSched must not rely only on LSM socket hooks.
```

Reason:

`____sys_sendmsg()` can skip `__sock_sendmsg()` and call
`sock_sendmsg_nosec()` when `sendmmsg()` reuses the same destination address:

```text
net/socket.c:2677-2684
```

That optimization is valid for existing LSM semantics, but a CapSched endpoint
check placed only in `security_socket_sendmsg()` would be skipped on that path.
CapSched either needs:

```text
a socket operation wrapper before this nosec fast path
or
a deliberately reused FrozenEndpointUse that is validated outside the LSM hook
```

Accept is also a capability derivation event:

```text
listen endpoint + accept right + peer policy
  -> new accepted socket endpoint
```

The code allocates `newsock` and `newfile` before the security hook and protocol
accept:

```text
net/socket.c:2011-2035
```

Future CapSched design should decide whether the accepted endpoint capability is
derived before protocol accept, after successful accept, or in a two-phase
pending endpoint state.

## LSM and Policy Front-Ends

Existing LSM hooks are excellent policy inputs:

```text
security_socket_bind()
security_socket_connect()
security_socket_listen()
security_socket_accept()
security_socket_sendmsg()
security_socket_recvmsg()
security_uring_override_creds()
security_uring_cmd()
```

But policy approval is not the frozen capability itself. The CapSched object
must encode:

```text
caller Domain/epoch
endpoint identity/generation
operation
resource generation
service Domain
budget ticket
```

This mirrors the Runnable Lease split:

```text
policy input -> capability issuance -> frozen use -> execution validation
```

## Recommended Next Implementation Thought

The next implementation planning step should not be a security-enforcing patch.
It should derive a narrow Slice 0B or 0C that adds typed carrier definitions and
trace-only attachment probes while preserving behavior.

Candidate low-risk sequence:

```text
Slice 0B:
  define inert capsched endpoint/work structs in include/linux/capsched.h
  no task_struct/io_kiocb/work_struct layout changes
  no behavior change
  no user ABI

Slice 0C:
  trace-only or debug-only request lifecycle observation for io_uring issue and
  io-wq execution
  no denial
  no authority lookup

Slice 0D:
  default root Domain task fields and generation counters for task lifecycle
  still no endpoint enforcement
```

Open question:

```text
Should L0 attach endpoint frozen-use fields directly to io_kiocb under
CONFIG_CAPSCHED, or first use side tables keyed by request/resource addresses
for lower layout risk?
```

This question should be answered before touching io_uring structs.

## Preliminary Conclusion

The Endpoint Async model maps cleanly onto io_uring's request/resource split.
It maps poorly onto generic workqueue and task_work without wrappers. Socket
operations must be treated as typed endpoints and cannot depend solely on LSM
hooks because some socket send paths intentionally bypass repeated LSM checks.

The safest near-term direction is:

```text
io_uring:
  per-request FrozenEndpointUse on or beside io_kiocb

registered resources:
  endpoint basis on or beside io_rsrc_node

generic workqueue/task_work:
  CapSched wrapper for Domain-derived work

socket:
  typed operation wrapper that sits outside LSM-only fast paths
```
