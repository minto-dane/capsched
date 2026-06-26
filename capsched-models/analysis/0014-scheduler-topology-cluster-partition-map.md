# Analysis 0014: Scheduler Topology and Cluster Partition Map

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note maps Linux cpuset partitions, scheduler domains, root domains,
housekeeping CPU masks, CPU isolation, and NUMA topology to the CapSched goal of
"one OS stretched across multiple clusters" without turning Linux into a
monolithic distributed kernel.

The design target is:

```text
single Linux ABI and shared control plane
+ node-local monitor-enforced Domain roots
+ cluster-wide capability/resource lease namespace
+ local sched domains and cpusets as compatibility placement machinery
```

## Existing Linux Shape

Evidence:

- `kernel/cgroup/cpuset.c` around lines 176-205 defines partition root states:
  member, partition root, isolated partition root, and invalid variants. It
  distinguishes local and remote partitions.
- `kernel/cgroup/cpuset.c` around lines 773-914 builds partial CPU partitions
  and passes them to `partition_sched_domains()`.
- `kernel/cgroup/cpuset.c` around lines 982-1015 rebuilds scheduler domains
  while checking that generated domains do not include offline CPUs.
- `kernel/cgroup/cpuset.c` around lines 1200-1365 updates isolated CPU masks,
  checks housekeeping conflicts, rebuilds sched domains, and updates
  housekeeping without holding cpuset locks.
- `kernel/cgroup/cpuset.c` around lines 1473-1530 enables remote partitions by
  taking exclusive CPUs directly from the top cpuset, with `CAP_SYS_ADMIN`,
  exclusivity, active CPU, and housekeeping checks.
- `kernel/cgroup/cpuset.c` around lines 1655-1775 updates parent effective CPU
  masks when enabling, disabling, updating, or invalidating partition roots.
- `kernel/sched/sched.h` around lines 993-1061 defines `struct root_domain`.
  The comment explicitly says exclusive cpusets create "island" root domains.
- `kernel/sched/topology.c` around lines 474-522 attaches runqueues to root
  domains and handles old root-domain lifetime.
- `kernel/sched/topology.c` around lines 3081-3175 builds scheduler domains for
  a cpumask and topology levels.
- `kernel/sched/topology.c` around lines 3374-3503 partitions scheduler domains,
  rebuilds new domains, builds perf domains, updates sched cache state, and
  rebuilds deadline root-domain accounting.
- `kernel/sched/isolation.c` around lines 1-163 manages housekeeping CPUs for
  routine work such as unbound workqueues, timers, kthreads, and offloadable
  work.
- `include/linux/sched/topology.h` around lines 91-221 defines sched domains,
  topology levels, and span masks.

CapSched reading:

Linux already has a deep CPU partitioning vocabulary. CapSched should not
invent a parallel CPU topology system for L0. It should refine and constrain the
existing machinery.

## What Linux Already Does Well

Useful existing pieces:

```text
cpuset:
  user-visible CPU and memory placement hierarchy

cpuset partition root:
  exclusive CPU island integrated with scheduler domains

isolated partition:
  partition without load balancing, tied to housekeeping constraints

remote partition:
  CPU lease from top cpuset to a non-parent partition branch

sched_domain:
  load-balancing topology over CPUs

root_domain:
  per-island RT/deadline/overload/perf-domain accounting

housekeeping:
  keeps timers, workqueues, kthreads, and kernel noise off isolated CPUs

NUMA topology:
  distance-aware masks and placement helpers
```

These are compatibility assets. CapSched should preserve them, because
datacenter users already rely on cpuset, cgroup, affinity, RT/deadline
accounting, hotplug, isolation, and NUMA behavior.

## What These Mechanisms Do Not Provide

They are not a hypervisor-level Domain boundary:

```text
cpuset controls placement, not authority.
sched_domain controls load balancing, not memory ownership.
root_domain contains scheduler accounting, not protection state.
housekeeping isolates kernel noise, not malicious kernel execution.
remote partition is a CPU allocation pattern, not a remote-machine lease.
CAP_SYS_ADMIN gates management, but does not create non-forgeable DomainTag.
```

If a compromised Domain obtains arbitrary Linux kernel execution, cpuset and
sched domains alone cannot stop access to other mutable kernel state.

## CapSched Cluster Mapping

Proposed vocabulary:

```text
ClusterCell:
  schedulable resource island on one node or one hardware locality group

CellEpoch:
  revocation/version for CPU, memory, queue, and endpoint leases in a cell

ClusterLease:
  signed or monitor-issued lease that compiles to local SchedContext and
  EndpointCap objects

DomainPlacementCap:
  authority to place a Domain or SchedContext into a ClusterCell

SchedContext.allowed_cpus:
  must be a subset of the effective cpuset partition, CPU affinity, and monitor
  CPU lease

HousekeepingCap:
  explicit authority for service Domains that may run housekeeping or kernel
  maintenance work for other Domains
```

Mapping to Linux:

| Linux object | CapSched reading | Compatibility rule |
| --- | --- | --- |
| cpuset hierarchy | placement and resource policy input | do not bypass |
| partition root | local ClusterCell candidate | refine with DomainTag/epoch |
| isolated partition | low-noise/hard placement cell | still not security boundary |
| remote partition | useful CPU lease pattern | not distributed kernel semantics |
| root_domain | scheduler accounting island | attach CapSched accounting carefully |
| sched_domain | balancing topology | preserve rebuild/hotplug semantics |
| housekeeping mask | kernel-service placement constraint | service Domains must respect it |
| NUMA masks | locality information | scheduler objective input |

## Compatibility Invariants

CapSched should preserve these before any L0 patch is accepted:

```text
effective_run_cpus(task)
  <= task cpus_ptr
  <= cpuset effective CPUs
  <= online/active CPU masks
```

For a CapSched task:

```text
effective_run_cpus(task)
  = task affinity
    intersect cpuset effective CPUs
    intersect SchedContext.allowed_cpus
    intersect Domain allowed CPUs
    intersect monitor CPU lease if present
```

CapSched must not:

```text
run a task outside cpuset/affinity constraints
bypass partition_sched_domains()
break root_domain RT/deadline accounting
allow isolated partitions to lose housekeeping CPUs
invent a second scheduler topology that races CPU hotplug
pretend remote partition means remote-node security
```

## Multi-Cluster Direction

The DragonFlyBSD-like ambition should be interpreted carefully. CapSched should
not start by building one shared mutable distributed kernel. The safer model is:

```text
cluster control plane:
  issues leases and policy

per-node Linux:
  executes local Domains under local sched domains and cpusets

per-node HyperTag Monitor:
  enforces non-forgeable DomainTag, MemoryView, queue ownership, and root budget

service Domains:
  bridge storage, network, discovery, migration, and remote endpoint invocation
```

Cluster-wide execution becomes lease translation:

```text
ClusterLease(domain, cell, cpu_budget, endpoint_scope, epoch)
  -> local DomainTag
  -> local SchedContext
  -> local EndpointCap/QueueCap
  -> monitor-owned MemoryView/QueueTag
```

Migration is not a Linux scheduler migration across machines. It is a controlled
Domain transfer:

```text
freeze source Domain
revoke or close source epoch
transfer sealed state through service endpoint
issue destination CellEpoch and local SchedContext
activate destination DomainTag
```

## Scheduler Objective Implication

CapSched's scheduler objective is broader than fairness:

```text
fairness and latency
+ budget enforcement
+ DomainTag switch minimization
+ MemoryView switch minimization
+ service Domain locality
+ NUMA and cache locality
+ cluster-cell lease efficiency
+ co-tenancy constraints
```

Linux topology already provides locality and balancing facts. CapSched should
add authority and cost semantics without erasing those facts.

## Formal Implication

The Runnable Lease model should initially abstract topology as finite sets:

```text
CPU
ClusterCell
AllowedByAffinity(task)
AllowedByCpuset(task)
AllowedBySchedContext(ctx)
AllowedByDomain(domain)
AllowedByMonitor(domain, epoch)
```

Safety properties:

```text
No task runs outside the intersection of all allowed CPU sets.
No Domain can consume CPU outside its SchedContext budget.
No ClusterLease remains usable after CellEpoch revocation.
No service/housekeeping task runs on a Domain-isolated CPU unless explicitly
authorized.
```

The model does not need to reproduce all Linux topology, but it must make clear
that CapSched placement is a refinement of existing Linux placement, not a
replacement.

## Preliminary Conclusion

Linux cpuset partitions and sched domains are among the best existing anchors
for CapSched's datacenter and cluster ambitions. They give us CPU partitioning,
load-balancing islands, root-domain accounting, hotplug integration, and
housekeeping constraints. They do not give us security boundaries. CapSched
should use them as compatibility placement substrate while DomainTag, epochs,
MemoryView, budgets, and queue ownership come from CapSched/Monitor authority.
