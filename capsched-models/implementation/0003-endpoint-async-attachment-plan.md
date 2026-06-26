# Implementation 0003: Endpoint Async Attachment Plan

Status: Candidate plan, not accepted patch points

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This note derives implementation pressure from:

```text
formal/0003-endpoint-async-provenance-model/
validation/0005-endpoint-async-tlc.md
analysis/0015-endpoint-async-linux-attachment-map.md
```

It does not approve behavior-changing Linux patch points. It defines the next
safe shape to explore after Slice 0A.

## Non-Negotiable Semantics

The model accepted these rules:

```text
No FrozenEndpointUse, no async endpoint execution.
Credential override does not change DomainTag.
Registered resource is not execution authority.
Worker service authority is not caller authority.
BudgetTicket is required for service/worker execution on caller behalf.
```

Any future Linux patch must preserve these separations.

## Carrier Strategy

### io_uring

Most natural carriers:

```text
io_rsrc_node:
  registered endpoint basis

io_kiocb:
  per-request FrozenEndpointUse
```

Reason:

```text
io_rsrc_node already represents registered fixed files and buffers.
io_kiocb already survives submission, async worker execution, task_work, and
completion paths.
```

Risk:

```text
Touching io_kiocb layout is high blast radius.
```

Open implementation choice:

```text
direct fields under CONFIG_CAPSCHED
vs
temporary side table keyed by io_kiocb/io_rsrc_node addresses
```

Side table may be safer for early trace-only L0 experiments, but direct fields
may be simpler and less error-prone once semantics are stable.

### Workqueue

Do not add CapSched authority to raw `struct work_struct`.

Preferred shape:

```c
struct capsched_work {
        struct work_struct work;
        struct capsched_work_ctx ctx;
};
```

Only Domain-derived work should use this wrapper. Pure kernel maintenance work
must be classified separately as service/root work.

### task_work

Do not add CapSched authority to raw `struct callback_head`.

Preferred shape:

```c
struct capsched_task_work {
        struct callback_head work;
        struct capsched_work_ctx ctx;
};
```

For io_uring, prefer using the request's `io_kiocb` frozen authority rather than
embedding authority into `callback_head`.

### Socket

Do not rely only on LSM hooks for endpoint enforcement.

Reason:

```text
net/socket.c sendmmsg can skip repeated LSM sendmsg checks through
sock_sendmsg_nosec().
```

Preferred shape:

```text
socket operation wrapper:
  freeze endpoint operation before LSM/no-LSM fast-path split
  validate operation-specific authority before protocol op
```

Accept should be modeled as endpoint derivation:

```text
listening endpoint + accept right -> new pending endpoint -> accepted endpoint
```

## Candidate Slice Sequence

### Slice 0B: Type-Only Endpoint Authority Scaffolding

Goal:

```text
Define CapSched endpoint/work authority types.
Do not attach them to Linux hot structs yet.
Do not change runtime behavior.
```

Possible files:

```text
include/linux/capsched.h
kernel/sched/capsched.c
```

Allowed:

```text
struct capsched_endpoint_use
struct capsched_work_ctx
struct capsched_budget_ticket
enum capsched_endpoint_op
inline no-op validators returning success only when CONFIG_CAPSCHED is disabled
```

Disallowed:

```text
no io_kiocb layout change
no work_struct or callback_head change
no socket behavior change
no scheduler behavior change
no user ABI
no denial
```

Validation:

```text
CONFIG_CAPSCHED=n build still inert
CONFIG_CAPSCHED=y vmlinux build
static check that no files outside include/linux/capsched.h and
kernel/sched/capsched.c changed
```

### Slice 0C: Trace-Only io_uring Attachment Observation

Goal:

```text
Observe io_uring request/resource/worker lifecycle without enforcement.
```

Possible files:

```text
io_uring/io_uring.c
io_uring/rsrc.c
io_uring/io-wq.c
include/linux/capsched.h
```

Allowed:

```text
trace-only capsched hooks at fixed resource registration
trace-only capsched hooks at request file assignment
trace-only capsched hooks at io_wq_submit_work()
no failure path introduced
```

Disallowed:

```text
no endpoint authority allocation under hot locks
no blocking lookup under io-wq execution
no behavior denial
no user ABI
```

Validation:

```text
build with CONFIG_IO_URING=y and CONFIG_CAPSCHED=y
run a minimal io_uring smoke test if available
prove disabled config compiles out or remains inert
record trace coverage only as observation, not security evidence
```

### Slice 0D: Socket Endpoint Operation Observation

Goal:

```text
Observe socket operation points before relying on LSM hooks.
```

Possible files:

```text
net/socket.c
include/linux/capsched.h
```

Required caution:

```text
sendmmsg nosec fast path must still be visible to CapSched observation.
```

Validation:

```text
socket syscall smoke tests
sendmmsg repeated-address path inspection or targeted test
CONFIG_CAPSCHED=n build remains behavior-compatible
```

## Do Not Do Yet

Do not enforce endpoint capabilities in Linux yet.

Reasons:

```text
No chosen carrier strategy for io_kiocb vs side table.
No runtime revocation design for resource generation updates.
No BudgetTicket accounting implementation.
No task Domain fields yet.
No monitor-backed non-forgeability.
```

## Decision Needed Before Behavior Patches

Before the first endpoint behavior patch, explicitly decide:

```text
1. Direct fields or side table for io_kiocb and io_rsrc_node?
2. Eager revocation or lazy execute-time rejection for registered resources?
3. How BudgetTicket is charged for io-wq and service Domain work?
4. How socket accept derives endpoint authority for the accepted socket?
5. Whether trace-only hooks live in scheduler CapSched code or endpoint-local
   helpers.
```

## Preliminary Recommendation

The next Linux patch, if one is taken, should be Slice 0B:

```text
type-only endpoint authority scaffolding
no Linux object attachment
no behavior change
```

This keeps momentum while avoiding premature io_uring or socket layout changes.
