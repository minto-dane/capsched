# Analysis 0009: Mutable Kernel State Boundary Map

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note maps shared mutable Linux state that blocks a hypervisor-equivalent
claim unless it is made Domain-local, moved behind typed endpoints, or protected
by a monitor. It focuses on MM, fd tables, VFS objects, page cache, and file
references.

## Core Problem

Linux is powerful because it shares rich kernel objects across tasks and
subsystems:

```text
mm_struct
files_struct and fdtable
struct file
inode, dentry, super_block
address_space and page cache
network namespace and socket state
io_uring state
workqueues and kernel workers
driver state
allocator metadata
```

This is also the reason a Linux-only CapSched prototype cannot claim
hypervisor-grade isolation. If arbitrary Domain-local kernel code can reach
shared mutable state, it can often bypass scheduler-level authority.

## mm_struct

Evidence:

- `include/linux/mm_types.h` around lines 1160-1385 defines `struct mm_struct`.
- It contains `mm_count`, `mm_users`, maple tree VMAs, `pgd`, `mmap_lock`,
  page table locks, RSS counters, `exe_file`, MMU notifier subscriptions, NUMA
  state, AIO state, memcg owner, IOMMU MM data, and async put work.
- Comments near `mmap_lock` warn about cacheline layout and contention.
- `task_struct` points to `mm` and `active_mm`, while kernel threads may have
  no user mm.

CapSched interpretation:

`mm_struct` is already a user address-space boundary, but it is not enough:

- threads share it with `CLONE_VM`
- io workers may share process resources
- kernel metadata for the mm remains mutable in the shared kernel
- page tables and MMU notifiers are global kernel mechanisms
- monitor-backed production needs MemoryView ownership below Linux

Candidate layering:

```text
L0:
  record task DomainTag and SchedContext, no memory isolation claim

L2:
  classify mm metadata and per-Domain kernel state

L3:
  monitor enforces page ownership and MemoryView
```

## fdtable and files_struct

Evidence:

- `include/linux/fdtable.h` around lines 26-48 defines `struct fdtable` and
  `struct files_struct`.
- `fdtable` holds RCU-protected `struct file **fd`, close-on-exec bits, and
  open-fd bitmaps.
- `files_struct` has a refcount, RCU fdtable pointer, spinlock, next fd, and
  embedded default fd array.
- `copy_files()` in `kernel/fork.c` can share file tables with `CLONE_FILES` or
  duplicate them with `dup_fd()`.

CapSched interpretation:

fdtable is a natural EndpointCap boundary because a file descriptor already
acts like an object handle. The problem is that Linux fd authority is mostly
ambient after the fd exists.

Rule candidate:

```text
fd lookup returns a kernel object reference
EndpointCap should describe which operations may be performed through it
frozen endpoint use should bind fd/file generation, Domain epoch, and operation
```

Compatibility hazard:

Fork and `CLONE_FILES` can share fd authority. CapSched must not silently turn
all inherited fds into full endpoint capabilities unless the inheritance policy
allows that.

## struct file

Evidence:

- `include/linux/fs.h` around lines 1228-1320 defines `struct file`.
- It contains file operations, mapping, inode, flags, stashed opener
  credentials `f_cred`, owner, path, position lock, LSM security context,
  task_work/list entry union, readahead state, and refcount.
- `fs/open.c` around lines 885-987 implements `do_dentry_open()`: it sets
  inode, mapping, file ops, calls `security_file_open()`, fsnotify, break lease,
  filesystem open callback, mode bits, and readahead state.
- `fs/open.c` around lines 1045-1120 includes `dentry_open()` and
  `kernel_file_open()`.

CapSched interpretation:

`struct file` already has two capability-like features:

- it is a refcounted object handle
- it stores `f_cred`, the opener credential

Landlock strengthens this by recording allowed access at open time. CapSched can
learn from that pattern.

But `struct file` is not itself a safe cross-Domain capability root because:

- `private_data` may point to arbitrary driver or filesystem state
- `f_op` can dispatch into a broad subsystem
- ioctl can carry driver-specific semantics
- the underlying inode/address_space/page cache may be shared
- opener credentials are not DomainTag or monitor-sealed authority

## RCU File Lookup

Evidence:

- `fs/file.c` around lines 926-990 implements `get_file_rcu()`, carefully
  verifying that a file pointer has not been reused under
  `SLAB_TYPESAFE_BY_RCU`.
- `fs/file.c` around lines 1017-1120 implements fd lookup under RCU and checks
  that the fdtable entry still refers to the same file.

CapSched interpretation:

Linux already solves a hard lifetime problem: safe lookup of object references
under RCU and refcounting. CapSched should reuse this style. It should not put
raw pointer authority into capabilities without generation or epoch checks.

Formal model implication:

```text
ObjectRefValid(file, generation)
DomainEpochValid(domain, epoch)
OperationAllowed(endpoint, op)
```

The model must distinguish "pointer lifetime is safe" from "operation authority
is allowed".

## address_space, inode, and Page Cache

Evidence:

- `include/linux/fs.h` around lines 454-505 defines `struct address_space`,
  which owns cached pages through `i_pages`, invalidation locking, mapping
  trees, writeback state, operations, and private locks.
- `include/linux/fs.h` around lines 760-870 defines `struct inode`, including
  ownership, operations, superblock, mapping, security pointer, locks, LRU,
  writeback state, dentry links, and embedded `i_data`.
- `mm/filemap.c` around lines 2765-2895 implements `filemap_read()`, which reads
  through the page cache, readahead, folios, inode size checks, and mapping
  state.

CapSched interpretation:

The page cache is one of the clearest boundaries between "strong container" and
"hypervisor-equivalent Domain isolation". A shared `address_space` and shared
page cache can be correct and fast for normal Linux, but a compromised
Domain-local kernel context must not be able to read or corrupt another
Domain's mutable kernel objects or private data.

Candidate future strategies:

```text
sealed shared base:
  read-only verified kernel text and immutable shared filesystem pages

per-Domain overlay:
  mutable page-cache state, writeback metadata, and object metadata by Domain

service Domain:
  filesystem parser and storage control plane behind typed endpoints

monitor ownership:
  physical page ownership and MemoryView mapping
```

## Boundary Classification

| State | Linux strength | CapSched problem | Possible target |
| --- | --- | --- | --- |
| `mm_struct` | Mature per-process address-space model | kernel metadata still shared and mutable | MemoryView plus per-Domain mm metadata policy |
| `files_struct` | fd handle table with RCU and locks | fd inheritance is ambient | EndpointCap inheritance rules |
| `struct file` | refcounted handle with opener cred and LSM blob | `private_data` and `f_op` expose broad subsystem authority | frozen endpoint use |
| `inode`/`dentry` | VFS sharing, cache, lookup performance | cross-Domain mutable metadata | service Domain or Domain-tagged metadata |
| `address_space` | page cache and mapping performance | shared mutable cache can leak/corrupt | sealed base plus overlays |
| page cache folios | fast cached I/O | physical ownership not monitor-protected | Monitor page ownership |
| kernel worker state | async progress | provenance loss | `capsched_work_ctx` |
| driver state | hardware access | ioctls and DMA can exceed Domain | service/driver Domain plus IOMMU lease |

## Preliminary Conclusion

Scheduler capability is necessary but not sufficient. The source confirms that
Linux's object model is built around shared mutable state with careful lifetime
management. CapSched should reuse the lifetime machinery but add explicit
operation authority and eventually monitor-enforced ownership. Without that
second part, a Linux-only implementation remains a capability-aware scheduler,
not a hypervisor replacement.
