# Analysis 0041: Wider Endpoint Capability Semantics

Status: Draft endpoint model with TLC-backed design filter

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

`analysis/0034` established that Domain-derived work cannot safely enter
generic workqueue or kthread worker execution without a typed caller carrier.
`analysis/0035` treated shared futexes as endpoint authority rather than
execution authority.

This note widens that boundary to ordinary Linux resource operations:

```text
fd lookup
open/create
dup
SCM_RIGHTS receive
accept/connect/send/recv
read/write/readv/writev
ioctl and uring command paths
mmap
anonymous fd resources such as eventfd, timerfd, and epoll
io_uring fixed files and async workers
```

The core design question is:

```text
When does holding or receiving a Linux object reference become authority to
perform a Domain-attributed resource operation?
```

The CapSched answer must be:

```text
never by itself.
```

Linux object reachability is an input to capability derivation and validation,
not the final authority.

## Core Finding

The Linux fd/file/socket/resource machinery intentionally separates object
references from operation checks, and in several fast paths it can skip repeated
LSM checks after an earlier decision.

That is compatible with Linux semantics, but it is not enough for CapSched
security. CapSched must distinguish:

```text
EndpointBasis:
  a stable typed basis attached to an object or handle after open/create,
  accept, receive, registration, or service issuance

EndpointHandle:
  ordinary Linux reachability such as fd table slot, struct file ref, socket
  pointer, io_uring fixed-file table entry, epoll interest, or eventfd context

FrozenEndpointUse:
  an operation-specific, epoch-specific, Domain-specific authorization frozen
  before the file/socket/resource operation or before Domain-derived async
  execution leaves the caller context

DerivedEndpointCap:
  authority derived by dup, accept, SCM_RIGHTS receive, io_uring registration,
  mmap, epoll add, broker/service return, or explicit policy issue
```

`EndpointBasis` is not the same as `FrozenEndpointUse`.

Holding an fd or `struct file *` means the object is reachable. It does not mean
the current Domain can perform every operation supported by that object, nor
that a worker can later spend caller authority.

## Why Internal Redesign Alone Is Not Sufficient

Deeply redesigning Linux internal async execution is allowed and likely
required for production CapSched-H. The unsafe shortcut is not "redesigning
internals"; the unsafe shortcut is treating all internal work as if it carries a
single implicit caller authority.

The workqueue facts from `analysis/0034` matter here:

```text
queue_work() returns false when the same work_struct is already pending.
work execution enters worker->current_func(work) or work->func(work) in a
kworker/kthread context.
```

Therefore a single pending callback cannot safely store "the caller" unless the
subsystem defines explicit merge semantics. Updating a carrier on an already
pending `work_struct` can combine callers, overwrite tickets, or execute once
under ambiguous authority.

The safe long-term direction is:

```text
CapSched-owned async substrate:
  KernelCoreWork
  ServiceMaintenanceWork
  DomainRequestWork
  MergedDomainBatchWork
  InterruptDeferredWork
  ReclaimRescueWork
```

But this still requires typed carriers at the Domain boundary:

```text
DomainRequestWork:
  caller Domain, caller epoch, FrozenEndpointUse, BudgetTicket, service Domain,
  work generation, revoke epoch

MergedDomainBatchWork:
  explicit multi-caller merge, accounting, cancellation, and settlement rules

ServiceMaintenanceWork:
  service authority only, no caller-attributed endpoint effect

KernelCoreWork:
  audited internal exception, not a hidden caller path
```

So the production answer is:

```text
yes, redesign internal async execution deeply;
no, do not collapse typed caller provenance into ambient internal authority.
```

## Source Anchors

### fd install, lookup, and dup

```text
fs/file.c:679 fd_install()
fs/file.c:1093 __fget_files()
fs/file.c:1105 __fget()
fs/file.c:1166-1173 fget_light lifetime rules
fs/file.c:1481-1505 dup/f_dupfd paths installing the same file object
include/linux/file.h:221-233 fd_publish()
```

CapSched implication:

```text
fd table reachability is not authority.
```

`fd_install()` publishes a file pointer. `fget()` and `fget_light()` retrieve
one. `dup()` and related helpers create another fd pointing at the same
underlying file object. None of these operations by themselves say that a
different Domain can perform every endpoint operation.

### open and use-time checks

```text
fs/open.c:924 do_dentry_open() calls security_file_open()
fs/open.c:1047-1061 vfs_open()
fs/open.c:1359-1369 do_sys_openat2()
fs/read_write.c:453 rw_verify_area()
fs/read_write.c:554 vfs_read()
fs/read_write.c:667 vfs_write()
security/security.c:2372 security_file_permission()
```

Linux already has open-time and use-time checks. CapSched should build on that
separation:

```text
open/create:
  creates EndpointBasis or a derived endpoint basis

read/write/readv/writev/splice/copy paths:
  require operation-specific FrozenEndpointUse before the operation effect
```

The `struct file *` is an object reference. The operation-specific frozen use is
the authority.

### ioctl and command-specific operations

```text
fs/ioctl.c:34-56 vfs_ioctl()
fs/ioctl.c:492-580 do_vfs_ioctl()
fs/ioctl.c:583-600 sys_ioctl()
security/security.c:2498 security_file_ioctl()
```

`ioctl` is not a single resource operation. It is a command namespace containing
driver-specific control-plane authority, sometimes with pointer arguments.

CapSched implication:

```text
Generic fd authority cannot authorize ioctl.
```

Future endpoint policy needs typed command classes:

```text
IoctlCommandCap:
  endpoint object id
  command class or exact command
  direction and pointer/data policy
  service Domain
  epoch/generation
  budget or rate where relevant
```

The same rule applies to `io_uring` command paths and device queue submissions.

### mmap

```text
mm/mmap.c:1143 security_mmap_file()
security/security.c:2568-2592 mmap-specific security hooks
```

`mmap` creates a continuing memory mapping, not a one-shot read. A read cap does
not imply mmap authority. A writable shared mapping can become a long-lived
cross-Domain communication or mutation endpoint.

CapSched implication:

```text
MmapCap must be distinct from ReadCap and WriteCap.
```

Monitor-backed CapSched-H eventually also needs MemoryView consequences:

```text
mapping ownership
page-fault authority
shared-buffer lease
revocation and shootdown epoch
dirty/writeback attribution
```

### sockets and nosec fast paths

```text
net/socket.c:773 sock_sendmsg_nosec()
net/socket.c:785 __sock_sendmsg()
net/socket.c:1123 sock_recvmsg_nosec()
net/socket.c:2627 ____sys_sendmsg()
net/socket.c:2681 sendmmsg repeated-address fast path uses sock_sendmsg_nosec()
net/socket.c:2878 ____sys_recvmsg()
net/socket.c:2902 recv path may call sock_recvmsg_nosec()
security/security.c:4302 security_socket_sendmsg()
security/security.c:4331 security_socket_recvmsg()
```

The `nosec` paths are normal Linux optimizations. They are not security bugs in
Linux because earlier checks and socket semantics define when reuse is allowed.

CapSched implication:

```text
CapSched endpoint checks cannot rely only on LSM hooks that nosec paths skip.
```

The common CapSched rule must be attached to the frozen endpoint operation or a
lower wrapper that every effect path consumes. Reusing a prior address/security
decision must not reuse stale Domain authority after endpoint revoke, Domain
epoch change, BudgetTicket expiration, or socket ownership transfer.

### SCM_RIGHTS and received files

```text
security/security.c:2711 security_file_receive()
fs/file.c:1385 receive_fd()
fs/file.c:1413 receive_fd_replace()
net/core/scm.c:69 scm_fp_copy()
net/core/scm.c:354 scm_detach_fds()
net/core/scm.c:406 scm_fp_dup()
```

Receiving an fd over IPC is not the same as inheriting the sender's ambient
authority. It creates a receiver-visible handle for the same file object.

CapSched implication:

```text
SCM_RIGHTS must derive receiver authority.
```

The receiver needs an attenuated `DerivedEndpointCap` based on:

```text
sender authority to transfer
receiver Domain and epoch
endpoint object generation
operation mask
service policy
revocation epoch
budget/rate limits where relevant
```

Without this derivation, fd passing becomes a capability amplification path.

### anonymous fd resources

```text
fs/anon_inodes.c anon_inode_getfile(), anon_inode_create_getfile(),
  anon_inode_getfd()
fs/eventfd.c eventfd_ctx, eventfd_signal_mask(), eventfd_read(),
  eventfd_write()
fs/eventpoll.c epoll file private_data, epoll_ctl add/delete/modify,
  eventpoll_release_file()
```

Anonymous fd resources are first-class endpoints. Path-based policy is not
enough because the object may not have a pathname.

Examples:

```text
eventfd:
  signal, read, write, poll, kernel-signal rights

timerfd:
  arm, disarm, read expiration, clock/source policy

epoll:
  observe readiness, register interest, wake waiter, retain references to
  watched endpoints
```

`epoll_ctl(ADD)` is especially important because it derives an observation and
wake endpoint from another endpoint. It must not become a way to keep stale
readiness or wake authority after endpoint revoke.

### io_uring registered resources

`analysis/0012` and `analysis/0015` already identify the natural carriers:

```text
io_rsrc_node:
  registration-time endpoint basis

io_kiocb:
  per-request FrozenEndpointUse and BudgetTicket

io-wq/SQPOLL/task_work:
  worker/service contexts that must intersect service authority with caller
  frozen authority
```

Registration must not become permanent authority. Each SQE that performs a
resource operation needs a fresh or still-valid operation-specific frozen use.

## Endpoint Object Semantics

### EndpointBasis

Conceptual fields:

```c
struct capsched_endpoint_basis {
        u64 endpoint_id;
        u64 endpoint_generation;
        u64 endpoint_epoch;
        u64 object_cookie;
        u32 object_kind;
        u32 basis_rights;
        u64 service_domain;
        u64 policy_issuer;
};
```

This is a semantic shape, not an approved C layout.

Basis creation points include:

```text
open/create
socket creation
accept
SCM_RIGHTS receive
anon inode creation
io_uring resource registration
broker/service endpoint return
device queue lease issuance
```

### FrozenEndpointUse

Conceptual fields:

```c
struct capsched_frozen_endpoint_use {
        u64 caller_domain;
        u64 caller_epoch;
        u64 endpoint_id;
        u64 endpoint_generation;
        u64 endpoint_epoch;
        u64 object_generation;
        u64 operation_class;
        u64 service_domain;
        u64 budget_ticket_id;
        u64 revoke_epoch;
        unsigned long flags;
};
```

This is also a semantic shape only.

Frozen use points include:

```text
before vfs_read/vfs_write effects
before ioctl command dispatch
before mmap installation
before socket send/recv effect
before epoll observation registration
before eventfd/timerfd signal or read/write effect
before io_uring SQE leaves caller attribution
before worker/service Domain executes caller-attributed work
```

## Required Invariants

```text
NoOperationWithoutFrozenEndpointUse:
  endpoint effects require operation-specific FrozenEndpointUse.

NoFdLookupAsAuthority:
  fd lookup, struct file refs, socket refs, and fixed-file table entries are
  reachability, not authority.

NoOpenBasisAsAllOperations:
  EndpointBasis cannot authorize every future operation on its own.

NoNoSecBypass:
  Linux nosec fast paths must still consume a fresh CapSched FrozenEndpointUse.

NoTransferWithoutDerivation:
  dup, SCM_RIGHTS, accept, epoll add, mmap, registration, or broker return must
  derive receiver/consumer authority instead of copying ambient authority.

NoWorkerAmbientEndpointExec:
  worker task, rescuer task, kthread worker, SQPOLL, and io-wq authority alone
  cannot perform caller-attributed endpoint effects.

NoRevokedEndpointUse:
  endpoint/domain/object revocation invalidates queued, registered, mapped, and
  pending operation uses unless a bounded already-running rule exists.

NoMmapFromReadWriteOnly:
  mmap needs its own authority and MemoryView consequences.

NoIoctlFromGenericFd:
  ioctl and uring command paths need typed command authority.
```

## Design Consequences

Future implementation should not begin with a global hook that says:

```text
if current has a Domain and current has an fd, allow the operation
```

That would recreate process-local ambient authority.

A safer implementation sequence is:

```text
1. Add inert endpoint-basis and frozen-use type names.
2. Attach basis metadata to selected object classes without changing behavior.
3. Add trace-only freeze points for read/write/socket/ioctl/mmap/io_uring.
4. Model and validate derivation rules for dup, SCM_RIGHTS, accept, epoll, and
   registration.
5. Only then make selected operation classes fail closed under CONFIG_CAPSCHED.
```

The long-term production form may replace large parts of Linux internal async
execution with a CapSched-owned substrate, but that replacement must preserve
the same typed boundary:

```text
object reachability != resource authority
service execution != caller authority
open basis != operation use
transfer != authority amplification
async merge != carrier overwrite
```

## Open Questions

```text
1. Should EndpointBasis live in struct file/socket/anon object metadata, in a
   side table keyed by object cookie, or both?

2. How should inherited Unix process fd semantics be represented without
   silently amplifying authority across fork/exec?

3. Which operations should be command-exact, command-class, or object-class
   authority in the first enforced slice?

4. Which anonymous fd objects are dangerous enough to require early typed
   endpoint modeling: eventfd, epoll, timerfd, pidfd, userfaultfd, signalfd,
   memfd, bpf fd, perf fd?

5. What is the smallest trace-only slice that shows freeze/derive/consume
   coverage without changing Linux behavior?
```
