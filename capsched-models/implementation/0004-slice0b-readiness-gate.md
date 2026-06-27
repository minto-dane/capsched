# Implementation 0004: Slice 0B Readiness Gate

Status: Draft gate, not an accepted Linux patch

Date: 2026-06-26

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 0b685979f27b3d42ee620ced5f707ee391a2a27f
```

## Purpose

This note collects the implementation pressure from the checked formal models
and the decomposed cluster authority validation before choosing the next Linux
patch.

Slice 0A is already applied and build-validated as inert scaffolding. The next
temptation is to add many CapSched types at once. That is dangerous unless the
types preserve the semantic separations proven or pressured by the models.

The next Linux patch, if accepted, should still be boring:

```text
Slice 0B:
  type-only authority scaffolding
  no hot struct attachment
  no scheduler behavior change
  no endpoint behavior change
  no user ABI
```

## Current Formal Inputs

Checked:

```text
RunnableLease:
  RunCap -> FrozenRunUse -> SchedContext -> CPU execution

EndpointAsync:
  EndpointCap -> FrozenEndpointUse -> async endpoint execution

BrokerBudget:
  BudgetTicket + FrozenBrokerUse + service authority -> broker execution

DomainMonitor:
  monitor RunToken -> active DomainTag/MemoryView
```

Checked after decomposition:

```text
ClusterShadowForgery:
  forged local shadow claims do not create execution or endpoint authority

ClusterEpochRevoke:
  revoked or stale lease epochs do not remain executable

MemoryOwnership:
  PageOwner, MemoryView, slab generation, and memory work provenance are
  distinct from Linux shadow page/slab/page-cache metadata
```

Stress only:

```text
ClusterLease full:
  broad integration TLC was stopped after state explosion without invariant
  errors observed before interruption
```

Use `validation/0009` as the current cluster authority evidence. Do not treat
the stopped full run in `validation/0008` as a pass.

Checked after counterexample-driven fixes:

```text
DirectMapTLB:
  Domain activation must flush or retag stale translations, and page revoke
  cannot finish while MemoryView, direct-map, or TLB translations remain

PageCacheOverlay:
  mutable page-cache overlay state is per-Domain or service-mediated, and
  overlay commit requires current base version plus base-level serialization
```

Checked with two TLC runs:

```text
QueueLease:
  queue submit, DMA mapping, IRQ delivery, epoch, and budget are one lease
  boundary; Linux shadow queue/IOMMU state is not authority
```

## Slice 0B Must Not Collapse Types

The major risk in Slice 0B is not code volume. The risk is naming or type design
that silently collapses distinct authority concepts.

Do not introduce one generic object that means all of:

```text
Domain label
Run permission
CPU budget
Endpoint permission
Broker donated budget
Monitor token
Cluster lease
```

A convenient universal `struct capsched_cap` would be attractive, but it would
make the kernel API lie too early. The models say these objects are different
because they are checked at different times, consumed differently, revoked
differently, and eventually protected by different roots.

## Candidate Type Groups

Slice 0B may define opaque or small documentation-oriented types for the
following groups.

### Domain Identity

Candidate names:

```c
typedef u64 capsched_domain_id_t;
typedef u64 capsched_epoch_t;
```

Allowed meaning:

```text
Stable identifiers used by CapSched-owned objects.
```

Disallowed meaning:

```text
Not proof that a task is allowed to run.
Not a monitor-backed active DomainTag.
Not a MemoryView.
```

### Runnable Authority

Candidate forward declarations:

```c
struct capsched_run_cap;
struct capsched_sched_ctx;
struct capsched_frozen_run_use;
```

Allowed meaning:

```text
RunCap:
  authority to submit a target task for runnable execution.

SchedContext:
  CPU time, period, placement, and co-tenancy resource object.

FrozenRunUse:
  enqueue-time lease derived from RunCap and SchedContext.
```

Disallowed meaning:

```text
RunCap must not contain kill/suspend/priority/spawn/endpoint authority.
SchedContext must not imply endpoint or object access.
FrozenRunUse must not be a user-visible handle.
```

### Endpoint Authority

Candidate declarations:

```c
enum capsched_endpoint_op;
struct capsched_endpoint_cap;
struct capsched_frozen_endpoint_use;
```

Allowed meaning:

```text
EndpointCap:
  resource-specific operation authority.

FrozenEndpointUse:
  per-operation or per-request frozen endpoint use.
```

Disallowed meaning:

```text
No io_kiocb, io_rsrc_node, work_struct, callback_head, socket, or file layout
attachment in Slice 0B.
No endpoint enforcement in Slice 0B.
No LSM-only assumption for socket enforcement.
```

### Async and Broker Authority

Candidate declarations:

```c
struct capsched_work_ctx;
struct capsched_budget_ticket;
struct capsched_frozen_broker_use;
```

Allowed meaning:

```text
work_ctx:
  caller provenance plus frozen authority for Domain-derived async work.

budget_ticket:
  caller-reserved budget for service/broker execution.

frozen_broker_use:
  caller endpoint operation, service Domain, and epochs frozen for one request.
```

Disallowed meaning:

```text
A generic work item must not become authority.
Service Domain authority alone must not run caller work.
BudgetTicket must not be represented as ordinary Linux cgroup accounting only.
```

### Monitor and Cluster Placeholders

Candidate declarations:

```c
struct capsched_run_token;
struct capsched_memory_view;
struct capsched_cluster_lease;
struct capsched_local_lease_ctx;
```

Allowed meaning:

```text
Documentation and future integration placeholders.
```

Disallowed meaning:

```text
No Linux-only field may be called monitor-backed authority.
No Linux-only prototype may claim RunToken, MemoryView, or hypervisor-grade
isolation.
ClusterLease is not directly executable; it compiles into local authority.
```

## Candidate Helper Shape

Slice 0B may add helper names only if they cannot be mistaken for enforcement.

Allowed:

```c
static inline bool capsched_enabled(void);
```

Possibly allowed if clearly documented as non-authoritative placeholders:

```c
static inline void capsched_authority_types_are_inert(void) { }
```

Avoid:

```c
capsched_check_run()
capsched_check_endpoint()
capsched_activate_domain()
capsched_charge_budget()
```

Reason:

Those names imply behavior and validation before the implementation has any
object lifetime, locking, revocation, or monitor root.

## File Scope for Slice 0B

Allowed files:

```text
include/linux/capsched.h
kernel/sched/capsched.c
```

Possibly allowed:

```text
kernel/sched/Makefile
init/Kconfig
```

Only if build wiring or help text needs clarification.

Disallowed files:

```text
include/linux/sched.h
kernel/sched/core.c
kernel/sched/sched.h
kernel/fork.c
fs/exec.c
kernel/exit.c
kernel/workqueue.c
io_uring/
net/socket.c
security/
mm/
drivers/
```

## Acceptance Conditions Before Applying Slice 0B

Before touching Linux for Slice 0B, confirm:

1. `validation/0008` records the stopped full `ClusterLease` stress run as not
   passed, and `validation/0009` records the decomposed cluster authority TLC
   checks as passed.
2. `CONFIG_CAPSCHED=n` must still avoid building `capsched.o`.
3. `CONFIG_CAPSCHED=y` must still build without changing runtime behavior.
4. No existing Linux code may call a CapSched validation or activation helper.
5. No task, io_uring, workqueue, socket, file, mm, cgroup, or scheduler class
   structure may receive a CapSched field in Slice 0B.
6. Documentation comments must explicitly deny Linux-only security claims.
7. Any cluster names must remain opaque placeholders only; no cluster-local
   compilation semantics may enter Linux code in Slice 0B.

## Validation Plan for Slice 0B

Minimum validation:

```text
git diff --check
CONFIG_CAPSCHED=n vmlinux build
CONFIG_CAPSCHED=y vmlinux build
static file-scope check:
  only include/linux/capsched.h and kernel/sched/capsched.c changed
```

Semantic validation:

```text
The patch should be reviewed against:
  RunnableLease
  EndpointAsync
  BrokerBudget
  DomainMonitor
  ClusterShadowForgery
  ClusterEpochRevoke
  MemoryOwnership
  DirectMapTLB
  PageCacheOverlay
  QueueLease
```

Evidence required:

```text
No new behavior path.
No new authority claim.
No collapsed capability type.
No Linux-only monitor/security claim.
```

## Recommendation

Slice 0B can be considered ready for user review only as inert type scaffolding.
It is not yet an accepted patch.

The accepted shape must be:

```text
opaque type names
comments denying Linux-only security claims
no cluster-local compilation semantics
no authority checks
no activation helpers
no hot struct fields
```

Once accepted, Slice 0B should be a small Linux commit that adds only typed
names and comments. The first meaningful behavior should still wait for a later
trace-only or diagnostic slice.

Do not use Slice 0B to begin MM, page-cache, IOMMU, queue, or driver work.
Those tracks now have generic semantic models, but still need separate
implementation plans and, for devices, endpoint-specific QueueLease models
before L4 code.
