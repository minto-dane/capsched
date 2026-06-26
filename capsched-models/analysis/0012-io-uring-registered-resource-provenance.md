# Analysis 0012: io_uring Registered Resource Provenance

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note maps io_uring registered files, buffers, personalities, restrictions,
task_work, and io-wq workers to CapSched provenance and EndpointCap design.
io_uring is a boundary where capability checks must distinguish registration,
submission, execution, completion, and cancellation.

## Existing Linux Shape

Evidence:

- `include/linux/io_uring_types.h` around lines 128-180 defines
  `struct io_uring_task`, including task pointer, io-wq, registered rings,
  xarray, inflight counters, fallback work, and task_work queue.
- `include/linux/io_uring_types.h` around lines 315-470 defines
  `struct io_ring_ctx`, including submitter task, rings, restrictions,
  fixed file table, buffer table, submit state, cancel table, personalities,
  sqpoll credentials, and task_work state.
- `include/linux/io_uring_types.h` around lines 737-820 defines
  `struct io_kiocb`, including file, opcode, flags, ctx, tctx, buf_node,
  file_node, task_work, custom credentials, io-wq work, and links.

CapSched reading:

io_uring already has a request object that can carry frozen state:

```text
io_kiocb:
  request identity
  file pointer or fixed file node
  fixed buffer node
  credentials
  work item
  completion state
```

For CapSched, the analogous object is:

```text
FrozenEndpointUse:
  caller_domain
  caller_epoch
  task_generation
  endpoint object
  operation
  resource generation
  budget ticket
  service domain
```

## Registered Files

Evidence:

- `io_uring/rsrc.h` around lines 15-31 defines `struct io_rsrc_node`, with
  type, refs, tag, and file or buffer pointer.
- `io_uring/filetable.c` around lines 46-90 allocates file tables and installs
  fixed files into resource nodes.
- `io_uring/rsrc.c` around lines 300-420 updates fixed files by `fget(fd)`,
  allocates `io_rsrc_node`, installs it into the ctx file table, and sets tags.
- `io_uring/rsrc.c` around lines 469-710 registers file and buffer resources,
  unregisters files, and frees nodes.
- `io_uring/io_uring.c` around lines 1571-1590 obtains fixed or normal files:
  fixed files increment resource node refs and attach `req->file_node`.

CapSched reading:

Registered files are exactly the kind of capability hazard CapSched cares about:

```text
registration-time fd authority
  may differ from
submission-time task authority
  may differ from
worker execution authority
```

Rule candidate:

```text
fixed file registration freezes an EndpointCap basis
each SQE derives a FrozenEndpointUse for the specific operation
worker execution validates the frozen use, not current worker ambient authority
revocation invalidates registered resource nodes by epoch/generation
```

## Registered Buffers

Evidence:

- `io_uring/rsrc.h` around lines 32-47 defines `struct io_mapped_ubuf`, with
  user buffer address, length, refs, direction, release callback, private data,
  and bio_vec array.
- `io_uring/rsrc.c` updates and registers buffers through the same resource
  table structure used for files.

CapSched reading:

Registered buffers are a MemoryCap boundary:

```text
buffer registration pins or maps user memory
later operations use it asynchronously
registered buffer lifetime may outlive original syscall
```

Monitor-backed CapSched must eventually bind registered buffers to MemoryView
ownership and Domain epoch. L0 should not claim memory isolation here.

## Personalities and Credential Override

Evidence:

- `io_uring/register.c` around lines 90-110 registers a personality by storing
  `get_current_cred()` in `ctx->personalities`.
- `io_uring/io_uring.c` around lines 1818-1842 loads `sqe->personality`,
  obtains stored creds, calls `security_uring_override_creds()`, and sets
  `REQ_F_CREDS`.
- `io_uring/io_uring.c` around lines 1375-1405 overrides current credentials
  during request issue if `REQ_F_CREDS` is set.
- `security/security.c` around lines 5658-5706 provides io_uring LSM hooks for
  credential override, SQPOLL, uring_cmd, and setup permission.
- SELinux and AppArmor implement io_uring-specific checks in their hooks.

CapSched reading:

Credential override is not Domain override. A request may run with stored Linux
credentials, but it must not silently switch DomainTag, SchedContext, or
EndpointCap root.

Rule candidate:

```text
REQ_F_CREDS changes Linux subjective credential for the operation
Capsched frozen authority remains tied to caller Domain/epoch/request
Domain changes require explicit Domain transfer or service endpoint
```

## Restrictions and BPF Filters

Evidence:

- `io_uring/register.c` around lines 90-185 parses restrictions for register
  operations, SQE operations, and SQE flags.
- `io_uring/register.c` around lines 167-285 allows restrictions only for
  disabled rings, or task-level restrictions under no_new_privs or privilege.
- `io_uring/register.c` around lines 843-967 applies restrictions and BPF
  filters to ring registration operations.

CapSched reading:

io_uring restrictions are useful policy references. They are not enough for
CapSched because they constrain allowed opcodes and flags, not provenance,
Domain epoch, resource ownership, or service budget.

Potential use:

```text
io_uring restrictions
  -> policy input for allowed EndpointOps

CapSched frozen use
  -> per-request non-ambient authority binding
```

## SQPOLL and io-wq Workers

Evidence:

- `io_uring/sqpoll.c` around lines 210-240 overrides `ctx->sq_creds` while
  SQPOLL submits work.
- `io_uring/sqpoll.c` around lines 450-475 stores `ctx->sq_creds` during SQPOLL
  setup after `security_uring_sqpoll()`.
- `io_uring/tctx.c` around lines 16-44 creates io-wq offload state with
  `data.task = task`.
- `io_uring/tctx.c` around lines 77-110 allocates `io_uring_task`, creates
  io-wq, initializes fallback work and task_work.
- `io_uring/io-wq.c` around lines 598-682 handles work and calls
  `io_wq_submit_work()`.
- `io_uring/io_uring.c` around lines 1361-1605 assigns files, issues SQEs, and
  submits work from io-wq.

CapSched reading:

The execution context can be:

```text
submitter task
SQPOLL thread
io-wq worker
task_work on submitter/target task
fallback work
```

CapSched must not charge all of these to the worker or service ambiently. The
request needs a frozen authority tuple and budget.

## uring_cmd

Evidence:

- `io_uring/uring_cmd.c` around lines 230-260 checks `security_uring_cmd()`
  before calling file operation `uring_cmd`.
- SELinux's io_uring hook checks the command against the target file's inode
  label.

CapSched reading:

`IORING_OP_URING_CMD` is a dangerous typed endpoint boundary. It can reach
device/file-specific operations, much like ioctl. It should require a
resource-specific EndpointCap or service Domain authority in any security track.

## Risk Matrix

| Path | Current Linux object | CapSched risk | Model object |
| --- | --- | --- | --- |
| register fixed file | `io_rsrc_node` with `struct file` | fd authority persists after registration | RegisteredEndpoint |
| update fixed file | `fget(fd)` then replace node | capability replacement race/revocation | ResourceGeneration |
| fixed buffer | `io_mapped_ubuf` | pinned memory crosses time/context | MemoryCap |
| personality | stored `cred` | cred override mistaken for Domain override | CredPolicy only |
| SQE submission | `io_kiocb` | operation may lack per-request frozen authority | FrozenEndpointUse |
| io-wq | worker task | worker ambient authority confused deputy | ServiceWorker + BudgetTicket |
| SQPOLL | polling thread with sq_creds | stored creds and submitter identity differ | SubmitterDomain + RingAuthority |
| uring_cmd | file operation command | device/file control-plane access | Typed EndpointCap |

## Formal Implication

The async provenance model should include io_uring early. Minimal objects:

```text
Ring
RegisteredResource
Request
SubmitterTask
WorkerTask
FrozenEndpointUse
BudgetTicket
Completion
DomainEpoch
ResourceGeneration
```

Safety properties:

```text
No request executes using a registered resource without FrozenEndpointUse.
Credential override does not change DomainTag.
Revoked DomainEpoch invalidates pending requests.
Worker execution is bounded by caller budget or explicit service budget.
uring_cmd requires typed endpoint authority.
```

## Preliminary Conclusion

io_uring confirms that CapSched cannot stop at scheduler RunCap. The request
path already separates registration, submission, execution, and completion.
CapSched should mirror that separation: RunCap for task execution,
EndpointCap/FrozenEndpointUse for registered resources, BudgetTicket for worker
execution, and explicit Domain provenance for every async path.
