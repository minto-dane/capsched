# Architecture Memory

Updated: 2026-06-25

## Central Claim

CapSched is not merely a scheduler patch. It is a path toward:

```text
single-image, multi-context, monitor-backed Linux
```

The goal is to move VM-like protection boundaries inside the OS, allowing
process- to container-granularity Domains to be isolated with hypervisor-level
strength when backed by a small monitor.

## Layering

```text
Domain processes/services
  Linux syscall ABI
CapSched-Linux
  Domain-aware scheduler
  RunCap / SchedContext / FrozenRunUse
  typed resource endpoints
  per-Domain mutable kernel state
  LSM/MAC/namespaces/cgroups as policy inputs
  service Domains for drivers and dangerous code
HyperTag Monitor
  Domain registry and epochs
  stage-2/EPT MemoryViews
  root CPU budgets and sealed RunToken validation
  IOMMU and device queue ownership
  immutable audit roots
Hardware
```

## Prototype vs Production

Linux-only CapSched:

- explores integration and performance
- can model semantics
- can benchmark scheduling and DomainTag instrumentation
- cannot claim hypervisor-grade isolation

Monitor-backed CapSched-H:

- aims to confine arbitrary Domain-local kernel-context execution
- must rely on monitor-enforced DomainTag, epoch, MemoryView, IOMMU, queue, and
  root budget ownership

## Scheduler Role

Traditional view:

```text
scheduler selects task for CPU
```

CapSched view:

```text
scheduler activates DomainTag + SchedContext + thread under a frozen execution lease
```

The scheduler is the root of temporal and execution authority. Resource
endpoints remain the roots of resource-specific semantic authority.

## Two-Level Scheduling

Long-term structure:

```text
Root CapScheduler:
  selects Domain/SchedContext and enforces root budget, placement, co-tenancy

Domain-local scheduler:
  selects thread/work inside the Domain's granted budget
```

This enables Domain-specific policies such as EDF, gang scheduling, latency-first
serverless scheduling, or throughput-first batch scheduling without moving all
policy into the trusted root scheduler.

## Dangerous Areas

Async execution is a first-class risk:

- workqueue
- task_work
- io_uring workers
- kthreads
- timers
- softirq
- RCU callbacks
- block and network completions

Every Domain-derived async item must carry caller Domain, epoch, frozen
authority, and budget source. Generic untagged async work creates confused
deputy paths.

Global mutable Linux state is the deepest obstacle:

- allocator metadata
- fd/cred/mm/VMA state
- page cache and pipe buffers
- socket/net namespace state
- BPF maps/programs
- device and driver state

Hypervisor-grade claims require these to become Domain-local, service-mediated,
or monitor/core-owned.

## Design Warnings

Do not:

- put kill/suspend/priority/budget/spawn/mint authority into RunCap
- store raw cap handles in runqueue entries as authority
- let spawn inherit ambient authority
- let broker/service execute with unbounded service authority
- let async work lose caller provenance
- use sched_ext as the security root
- claim hypervisor replacement while all mutable kernel memory remains shared

