# Analysis 0006: Cluster Domain Capability Mapping

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note maps the datacenter and "one OS across clusters" goal to concrete
Linux concepts and CapSched capability objects. It avoids choosing implementation
patches. Its job is to keep the long-term architecture from contaminating the
L0 Linux-only prototype with a fake global scheduler.

## Existing Linux Topology

Evidence:

- `include/linux/sched/topology.h` around lines 91-173 defines
  `struct sched_domain`: parent/child topology, groups, flags, balance
  intervals, stats, and span.
- `include/linux/sched/topology.h` around lines 195-205 declares partitioning
  helpers and CPU resource-sharing queries.
- `kernel/sched/sched.h` around lines 1001-1061 defines `struct root_domain`
  with span, online CPUs, overload/overutilization, and RT/deadline structures.
- `kernel/sched/sched.h` around lines 2229-2247 defines `struct sched_group`.
- `kernel/sched/topology.c` around lines 675-739 maintains per-CPU LLC,
  cluster, and NUMA topology state.
- `kernel/sched/topology.c` around lines 1430-1455 explains sched-domain and
  sched-group traversal.
- `kernel/sched/topology.c` around lines 2037-2107 defines SMT, cluster, MC,
  and package topology levels.
- `build_sched_domains()` around lines 3081-3225 builds local scheduling
  domains for a CPU map.
- `partition_sched_domains_locked()` around lines 3360-3504 rebuilds or reuses
  scheduler partitions and falls back to online housekeeping CPUs.
- `kernel/sched/fair.c` around lines 8557-8575, 8913-8924, and 9333-9340
  contains cluster-aware idle CPU and energy decisions.

CapSched reading:

Linux already has node-local topology and partition machinery. It is not a
distributed OS scheduler, but it gives CapSched a local compilation target for
cluster-level leases.

## Domain Hierarchy

CapSched should support different domain granularities:

```text
ClusterCell
Tenant
Service
ContainerDomain
ProcessDomain
Thread
```

These are not all Linux task groups. They are authority scopes. A Domain can be
small enough for one process or large enough for a service/container. The
scheduler sees runnable tasks, but CapSched sees active authority contexts.

## Cluster Lease Model

Do not make a single global runqueue for the datacenter. Instead:

```text
cluster control plane
  issues signed ClusterLease

node admission path
  validates lease
  creates or updates local Domain epoch
  binds local SchedContext and EndpointCaps

node Linux scheduler
  performs ordinary fast-path dispatch under local constraints

node HyperTag Monitor
  enforces non-forgeable CPU, MemoryView, IOMMU, queue, and epoch roots
```

Candidate object:

```c
struct capsched_cluster_lease {
        u64 tenant_id;
        u64 service_id;
        u64 lease_epoch;
        u64 valid_not_before_ns;
        u64 valid_until_ns;
        u64 cpu_budget_ns;
        u64 cpu_period_ns;
        u64 max_nodes;
        u64 placement_class;
        u64 endpoint_scope_hash;
        u64 revocation_epoch;
        u8  signature[];
};
```

This is an abstract model object, not a proposed Linux struct.

## Local Compilation

A cluster lease can compile into local objects:

| Cluster concept | Local Linux/CapSched result |
| --- | --- |
| Tenant lease | `capsched_domain` root or tenant Domain epoch |
| CPU allocation | one or more `SchedContext` objects |
| Placement class | cpuset/topology/root_domain constraint input |
| Co-tenancy rule | Domain side policy plus core scheduling input |
| Service endpoint | `EndpointCap` for local or remote broker |
| Queue lease | IOMMU/device queue ownership request to Monitor |
| Revocation | Domain epoch bump plus lazy grant invalidation |
| Accounting | local audit entries linked to lease epoch |

## What "One OS Across Clusters" Should Mean

It should mean:

- one Linux-compatible ABI and control plane style
- one capability namespace for resource authority
- one audit and lease model
- per-node local enforcement
- explicit remote endpoints instead of raw shared kernel pointers
- cluster resource movement through leases and epochs

It should not mean:

- one global mutable Linux kernel heap
- one global runqueue
- one scheduler lock across machines
- remote task migration that preserves raw kernel object authority
- treating network partitions as ordinary scheduler delay

## Scheduler Objective Extension

CapSched scheduler policy has more goals than fairness:

```text
fairness within allowed authority
deadline/latency when permitted
root budget enforcement
Domain switch reduction
MemoryView switch reduction
cache and cluster locality
co-tenancy policy
service-domain IPC cost
cluster lease renewal and revocation cost
```

sched_ext can help explore these heuristics in L0 and L1. Production security
enforcement still belongs in kernel-native and monitor-backed mechanisms.

## Failure Modes to Avoid

1. Global scheduler illusion:
   pretending a datacenter can be scheduled as one local rq.

2. Capability namespace without local enforcement:
   signing leases but letting local Linux mutate root authority freely.

3. Remote endpoint as raw pointer:
   crossing node or Domain boundaries with object references instead of typed
   endpoint capabilities.

4. Revocation without epochs:
   old leases and work items remain usable after global policy changes.

5. Cluster clock trust:
   lease times and budgets need local monitor interpretation and renewal rules.

6. Compatibility breakage:
   existing Linux users expect local sched, cgroup, cpuset, affinity, and
   namespace behavior. Cluster authority must constrain and compose with those,
   not make every task operation a remote control-plane transaction.

## Preliminary Conclusion

The cluster goal is compatible with Linux only if CapSched uses a two-level
model: cluster-wide leases for authority and node-local scheduling for dispatch.
This matches the broader HyperTag architecture: policy can be distributed, but
non-forgeable execution roots must be local, small, and enforceable below Linux
in the production track.
