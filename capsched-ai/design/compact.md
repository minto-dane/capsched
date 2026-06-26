# Compact Context

Updated: 2026-06-25

## Project

CapSched-Linux aims to introduce a capability-oriented execution and resource
authority model into Linux scheduler foundations. The long-term target is a
datacenter OS substrate where process-, service-, container-, tenant-, and
cluster-cell-scale domains can receive isolation strength comparable to VM
boundaries at lower operational cost.

Upstream Linux source has been fetched into sibling repository `linux/`.
The current work branch is `capsched-linux-l0` at commit
`4edcdefd4083ae04b1a5656f4be6cd83ae919ef4`. No implementation patch points are
decided yet. A first deep source-analysis pass now exists in
`capsched-models/analysis/0002` through `0014`. A candidate Linux L0
Runnable Lease implementation plan has been derived from the checked model, but
Linux source now contains the first Slice 0A commit. The first patch slice was
narrowed to inert `CONFIG_CAPSCHED` build scaffolding with no task layout or
scheduler behavior changes.

## Core Architecture

CapSched-Linux has two tracks:

- Linux-only CapSched L0: prototype for performance, integration, and semantic
  exploration. It must not claim hypervisor-grade isolation.
- Monitor-backed CapSched-H: production architecture with a small HyperTag
  Monitor below Linux. The monitor enforces DomainTag, epochs, MemoryViews,
  IOMMU/queue ownership, and root CPU budgets that Linux must not forge.

The high-level idea is:

```text
shared Linux ABI and mostly shared kernel text
+ per-Domain mutable kernel state
+ RunCap / SchedContext scheduler authority
+ typed resource endpoints
+ service/driver Domains
+ HyperTag Monitor-enforced MemoryViews and IOMMU
```

## Capability View

Top-level research idea:

```text
Capability = scheduled authority
```

Execution itself activates authority. The scheduler should not decide every VFS,
socket, GPU, or BPF semantic operation. Instead, it selects the active authority
context. Resource endpoints check resource-specific capabilities.

Implementation must keep types separated:

- `RunCap`: authority to submit a specific thread/task to become runnable.
- `SchedContext`: CPU time, period, remaining budget, allowed CPUs, priority,
  and co-tenancy constraints.
- `FrozenRunUse`: enqueue-time frozen execution lease; runqueues must not store
  raw capability handles as authority.
- `DomainTag`: active protection context selected at context switch.
- `ThreadControlCap`: suspend/resume/terminate/inspect.
- `SchedControlCap`: change budget, period, priority, affinity, co-tenancy.
- `SpawnCap`: create thread/process/domain with attenuated initial authority.
- `EndpointCap`/`QueueCap`/`MemoryCap`: resource endpoint authorities.
- `BudgetTicket`: bounded caller budget donated to broker/service execution.

## Accepted Invariants

```text
No RunCap, no enqueue.
No SchedContext, no execution.
No budget, no execution.
No FrozenRunUse, no runqueue entry.
No valid epoch/generation, no execution.
No DomainTag activation, no cross-Domain context switch.
No async work without provenance and frozen authority.
No caller budget, no broker/service execution on behalf of that caller.
No raw pointer or mutable kernel object authority across Domain boundaries.
Linux-only prototypes must not claim hypervisor-grade isolation.
```

## Threat Model

The eventual threat model is intentionally hostile. An attacker may control all
user space inside a Domain and may exploit reachable Linux kernel bugs. The
production goal is that even arbitrary code execution in that Domain's Linux
kernel context cannot reach:

- other Domain user memory
- other Domain mutable kernel state
- HyperTag Monitor memory/state
- global scheduling authority
- other Domain device queues or DMA memory
- root management Domain

This requires monitor-backed roots and per-Domain mutable kernel state. A single
shared mutable Linux kernel address space cannot support this claim.

## Datacenter and Cluster Direction

Domain should not mean only process or only container. It should be a schedulable
protection/resource/audit context that can represent:

```text
ClusterCell -> Tenant -> Service -> ContainerDomain -> ProcessDomain -> Thread
```

Cluster direction: do not make one monolithic distributed kernel. Prefer a
single capability/resource lease namespace where signed cluster leases compile
into local node SchedContexts and endpoint capabilities.

## Near-Term Sequence

1. Use `capsched-models/plans/0001-upstream-analysis-plan.md` and `0002` as
   the analysis record.
2. Read `capsched-models/analysis/0002` through `0007` before proposing patch
   points.
3. Draft the formal model-selection memo.
4. Model runnable lease semantics first.
5. Validate semantics with TLA+ or similar before prototype implementation.

Current first model target:

```text
Task + TaskGeneration + ProcessGeneration + Domain + DomainEpoch
+ RunCap + SchedContext + FrozenRunUse + RunqueueState + CPU + Budget
```

The first TLA+ Runnable Lease model exists and passed TLC invariant checking in
a tiny finite model:

```text
formal model:
  capsched-models/formal/0002-runnable-lease-model/

validation:
  capsched-models/validation/0001-runnable-lease-tlc.md

TLC summary:
  227201 states generated
  28450 distinct states
  no invariant error found
```

The next gate is not Linux behavior changes yet. Complete the out-of-tree
baseline and `CONFIG_CAPSCHED=n/y` build validation after installing missing
host build dependency `flex`.

Candidate implementation plan:

```text
capsched-models/implementation/0001-l0-runnable-lease-implementation-plan.md
capsched-models/implementation/0002-l0-slice0-scaffolding-plan.md
capsched-models/validation/0002-l0-slice0-build-validation-plan.md
capsched-models/validation/0003-l0-slice0-validation-attempt.md
```

Socket and io_uring analysis sharpened a follow-on rule:

```text
RunCap is not EndpointCap.
io_uring and socket operations need per-request or per-operation frozen
endpoint authority after the runnable lease model.
```

BPF and sched_ext analysis adds:

```text
BPF can be a policy and experimentation layer.
BPF/sched_ext must not be the production root for No RunCap, no run.
BPF tokens are useful analogies, but not DomainTag/epoch roots.
```

Topology and cluster analysis adds:

```text
CapSched CPU placement must refine Linux affinity, cpuset, sched-domain,
root-domain, housekeeping, and hotplug constraints.
Cluster leases should compile into local SchedContexts and EndpointCaps;
do not build a shared mutable distributed kernel as the first architecture.
```
