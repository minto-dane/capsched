# Implementation 0005: L0 Slice 0B Type-Only Scaffolding

Status: Applied and build-validated

Date: 2026-06-26

## Linux Commit

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

## Purpose

Slice 0B adds names for distinct CapSched authority concepts without changing
Linux behavior.

The purpose is vocabulary discipline:

```text
RunCap is not EndpointCap.
EndpointCap is not BudgetTicket.
BudgetTicket is not MemoryView.
MemoryView is not QueueLease.
ClusterLease is not directly executable.
Linux shadow names are not monitor-backed authority.
```

## Changed Linux Files

```text
include/linux/capsched.h
kernel/sched/capsched.c
```

No other Linux file was changed.

## Added Type Names

Scalar identifiers:

```c
typedef u64 capsched_domain_id_t;
typedef u64 capsched_epoch_t;
typedef u64 capsched_generation_t;
typedef u32 capsched_endpoint_op_t;
typedef u64 capsched_budget_amount_t;
typedef u64 capsched_queue_tag_t;
```

Opaque authority groups:

```c
struct capsched_domain;
struct capsched_run_cap;
struct capsched_sched_ctx;
struct capsched_frozen_run_use;
struct capsched_endpoint_cap;
struct capsched_frozen_endpoint_use;
struct capsched_work_ctx;
struct capsched_budget_ticket;
struct capsched_frozen_broker_use;
struct capsched_spawn_cap;
struct capsched_thread_control_cap;
struct capsched_sched_control_cap;
struct capsched_run_token;
struct capsched_memory_view;
struct capsched_page_owner;
struct capsched_cluster_lease;
struct capsched_local_lease_ctx;
struct capsched_queue_lease;
```

Helper:

```c
static inline bool capsched_enabled(void);
```

The helper only reports the compile-time Kconfig state. No existing Linux code
calls it in this slice.

## Explicit Non-Claims

Slice 0B does not:

```text
add task_struct fields
change enqueue, pick, tick, fork, exec, or exit behavior
touch workqueue, io_uring, socket, VFS, MM, IOMMU, or drivers
create user ABI
perform authority checks
activate DomainTag
provide monitor-backed RunToken or MemoryView
provide hypervisor-grade isolation
```

## Validation

Validation record:

```text
capsched/capsched-models/validation/0014-l0-slice0b-build-run.md
```

Summary:

```text
git diff --check passed
changed Linux files limited to include/linux/capsched.h and kernel/sched/capsched.c
CONFIG_CAPSCHED=n vmlinux built
CONFIG_CAPSCHED=n did not produce kernel/sched/capsched.o
CONFIG_CAPSCHED=y vmlinux built
CONFIG_CAPSCHED=y produced kernel/sched/capsched.o
```

## Next

The next project-control gate is the assurance-case subclaim tree. The next
Linux gate should still avoid enforcement and favor trace-only observation or
a narrower wakeup/enqueue coverage analysis.
