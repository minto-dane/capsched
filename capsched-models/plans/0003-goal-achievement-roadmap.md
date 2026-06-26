# Plan 0003: Roadmap Toward Monitor-Backed CapSched

Status: Draft

Date: 2026-06-25

## Purpose

This plan describes how to move from the current analysis state toward the
long-term goal: a datacenter OS substrate where process-to-container-scale
Domains gain hypervisor-like isolation properties at lower cost than running a
separate guest kernel per Domain.

## Strategic Thesis

The project should proceed in layers:

```text
1. Make execution authority explicit.
2. Prove the authority story in a small model.
3. Prototype only the minimal Linux scheduler integration.
4. Add provenance for async work.
5. Split or wrap dangerous resource endpoints.
6. Introduce monitor-backed roots.
7. Evaluate against VM/hypervisor threat models.
```

The scheduler is the root of "who may run", not the root of all resource
security. Resource authority must live at typed endpoints. Physical ownership
must live below Linux in the production track.

## Phase G0: Current State

Already done:

- upstream Linux fetched
- project-control repo separated
- scheduler execution analysis
- task lifecycle analysis
- compatibility/resource-control analysis
- async provenance risk analysis
- cluster-domain mapping
- policy front-end analysis
- mutable kernel state boundary map
- first formal model selected

Still not done:

- TLA+ or equivalent runnable lease model
- L0 implementation plan
- any Linux source changes
- validation harness

## Phase G1: Formal Before Patch

Deliverable:

```text
capsched-models/formal/0002-runnable-lease-model/
```

Required properties:

- no queued task without FrozenRunUse
- no selected task without SchedContext
- no execution with exhausted budget
- no stale task generation
- no stale Domain epoch
- no cross-Domain execution without activation placeholder

Exit gate:

The model has been run with a checker or manually validated with a documented
limitation if tooling is not installed yet.

## Phase G2: L0 Linux-Only Prototype

Goal:

Measure integration and overhead while making no hypervisor-grade claim.

Likely objects:

```text
CONFIG_CAPSCHED
struct capsched_domain
struct capsched_sched_ctx
struct capsched_run_grant
task_struct pointers or compact task extension
tracepoints for DomainTag transition
debugfs or test-only issuer
```

Likely implementation constraints:

- frozen validation must be cheap
- no sleeping allocation in scheduler fast path
- compose with cgroup/cpuset/affinity/uclamp
- no ABI breakage
- disabled config should compile to no behavior change
- L0 issuer may be deliberately simple and test-only

Exit gate:

- bootable kernel
- scheduler smoke tests
- fork/exec/exit smoke tests
- cgroup/cpuset/affinity sanity tests
- benchmark of overhead
- explicit statement of non-security claims

## Phase G3: Async Provenance

Goal:

Prevent confused-deputy execution through workqueue, task_work, io_uring,
kthreads, timers, and softirq-derived work.

Deliverables:

- `capsched_work_ctx` model
- io_uring registration/submission authority map
- per-Domain or service-domain workqueue prototype
- audit events for provenance loss

Exit gate:

Async model covers at least workqueue and io_uring worker execution.

## Phase G4: Endpoint Capabilities

Goal:

Move resource authority out of the scheduler and into typed endpoints.

Priority endpoints:

1. file descriptor open/use inheritance
2. socket endpoint
3. ioctl classification
4. io_uring registered resource
5. BPF object and attachment authority

Design rule:

```text
RunCap says task may run.
EndpointCap says resource operation may happen.
BudgetTicket says service may spend caller-bounded work.
```

Exit gate:

At least one resource endpoint has a formal model and a Linux prototype.

## Phase G5: Mutable State Reduction

Goal:

Shrink the blast radius of Domain-local kernel compromise.

Workstreams:

- per-Domain async queues
- per-Domain metadata tags and audits
- page-cache overlay design
- service Domains for storage/network/drivers
- BPF/ioctl dangerous-surface containment

Exit gate:

Clear separation between state that remains shared, state that becomes
Domain-tagged, and state that moves to service Domains.

## Phase G6: HyperTag Monitor

Goal:

Make DomainTag, epoch, MemoryView, CPU root budget, IOMMU mapping, and queue
ownership non-forgeable by Linux.

Minimum monitor objects:

```text
Domain registry
Domain epoch
sealed RunToken
MemoryView
root CPU budget
page ownership table
IOMMU/queue ownership table
audit root
```

Exit gate:

A compromised Domain-local Linux context cannot forge another Domain's
MemoryView, CPU budget, Domain epoch, or queue ownership in the model and in
targeted tests.

## Phase G7: Datacenter and Cluster Control Plane

Goal:

Support a cluster-wide capability/resource lease namespace while keeping
dispatch node-local.

Rule:

```text
cluster control plane issues leases
node-local Linux scheduler dispatches
node-local monitor enforces roots
remote resources are endpoints, not raw kernel objects
```

Exit gate:

ClusterLease compiles into local DomainEpoch, SchedContext, EndpointCaps, and
audit state.

## Measurement and Comparison

CapSched must eventually be compared against:

- ordinary Linux process isolation
- containers
- KVM
- Firecracker or similar microVM setups
- protected virtualization mechanisms where applicable

Metrics:

- context-switch overhead
- Domain switch overhead
- syscall overhead within same Domain
- TLB and MemoryView switch cost
- async work overhead
- service-domain IPC cost
- I/O path latency and bandwidth
- exploit containment tests
- administrative complexity

## Current Next Step

Create the runnable lease formal model, then use it to derive the smallest L0
Linux patch slice. Do not patch Linux before that.
