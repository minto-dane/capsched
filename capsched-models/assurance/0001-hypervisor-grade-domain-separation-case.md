# Assurance 0001: Hypervisor-Grade Domain Separation Case

Status: Active

Date: 2026-06-26

## Top-Level Production Claim

```text
TOP-001:
If an attacker controls all userspace inside a CapSched Domain and obtains
arbitrary Linux kernel-context execution scoped to that Domain, then crossing
into another Domain's memory, execution authority, device queue, DMA memory,
or control authority requires breaking the HyperTag Monitor or an explicitly
exposed typed service endpoint.
```

This is a production CapSched-H claim. It is not a Linux-only L0 claim.

## Claim Boundary

The claim is deliberately stronger than a container claim:

```text
process boundary escape ~= hypervisor escape
container boundary escape ~= hypervisor escape
service-domain escape ~= typed service endpoint break or monitor break
```

The claim is deliberately narrower than "Linux is magically safe":

```text
Linux may contain exploitable bugs.
Domain-local Linux kernel context may be compromised.
Linux-visible shadow tags, pointers, queues, and metadata may be forged.
```

The protection root must therefore sit below ordinary mutable Linux state.

## Status Legend

```text
Open:
  Required but not established.

Model-supported:
  Supported by small or decomposed semantic models.

Prototype-evidenced:
  Supported only for Linux compatibility/integration; not production security.

Protection-evidenced:
  Supported by monitor-backed production implementation and validation.

Forbidden-for-L0:
  Must not be claimed by Linux-only prototypes.
```

No current claim is `Protection-evidenced`.

## Subclaim Tree

### TOP-001: Cross-Domain Escape Requires Monitor or Typed Endpoint Break

Current status: Open

Required children:

```text
ACT-001    Non-forgeable Domain activation
EXEC-001   No CPU execution without runnable authority
BUDGET-001 CPU and service execution cannot exceed root budget
ENDP-001   Resource access requires typed endpoint authority
ASYNC-001  Async work preserves caller provenance and authority
MEM-001    Other Domain memory and mutable kernel state are unmapped
TLB-001    No stale direct-map or TLB translation crosses activation/revoke
PCACHE-001 Mutable page-cache state is per-Domain or service-mediated
DEV-001    Queue submit, DMA, IRQ, and rate/budget revoke as one lease
REVOKE-001 Epoch revoke invalidates all active and delayed authority
CLUSTER-001 Cluster leases compile into node-local authority before use
COMPAT-001 Linux ABI and existing policy substrates remain compatible
TCB-001    Service domains and monitor remain smaller than VM/VMM attack area
SIDE-001   Co-tenancy and side-channel policy is explicit
EVAL-001   Claims are tested against exploit and cost baselines
```

The top-level claim is blocked until at least ACT, EXEC, BUDGET, ENDP, ASYNC,
MEM, TLB, DEV, REVOKE, TCB, and EVAL have production evidence.

## Claim Details

### ACT-001: Non-Forgeable Domain Activation

Claim:

```text
Linux-visible Domain shadows do not create active authority. A Domain becomes
active only when the monitor validates a sealed RunToken, live epoch, CPU
placement, root budget, and MemoryView.
```

Current status: Model-supported

Current evidence:

- `formal/0005-domain-monitor-activation-model/`
- `validation/0007-domain-monitor-activation-tlc.md`
- Slice 0B type names: `capsched_run_token`, `capsched_memory_view`

Open gaps:

- no HyperTag Monitor implementation
- no arch-specific stage-2/EPT activation path
- no real token sealing
- no interrupt/exception entry policy
- no production evidence that Linux cannot mutate active Domain roots

Forbidden L0 claim:

```text
Do not claim active DomainTag security from Linux fields or trace state.
```

### EXEC-001: No CPU Execution Without Runnable Authority

Claim:

```text
A task cannot enter or remain in executable scheduler state without a live
RunCap-derived FrozenRunUse, SchedContext, epoch, generation, CPU placement,
and remaining budget.
```

Current status: Model-supported

Current evidence:

- `formal/0002-runnable-lease-model/`
- `validation/0001-runnable-lease-tlc.md`
- `formal/0067-scheduler-authority-refinement-gate-model/`
- `validation/0106-scheduler-authority-refinement-gate-tlc.md`
- `implementation/0001-l0-runnable-lease-implementation-plan.md`
- Slice 0B type names: `capsched_run_cap`, `capsched_sched_ctx`,
  `capsched_frozen_run_use`

Open gaps:

- no task fields
- no enqueue/pick/tick enforcement
- no scheduler class coverage
- no wakeup/migration/remote wake coverage
- no deadline/RT/CFS/core-scheduling interaction evidence
- no trace/runtime coverage for current, donor, and proxy execution paths
- no root budget monitor timer

Forbidden L0 claim:

```text
Do not claim "No RunCap, no run" until all runnable paths and tick/preemption
paths are covered.
```

### BUDGET-001: CPU and Service Execution Stay Within Root Budget

Claim:

```text
Domain CPU use and service execution on behalf of a caller are bounded by
non-forgeable budget roots and caller-reserved BudgetTickets.
```

Current status: Model-supported

Current evidence:

- `formal/0004-broker-budget-ticket-model/`
- `validation/0006-broker-budget-ticket-tlc.md`
- `formal/0067-scheduler-authority-refinement-gate-model/`
- `validation/0106-scheduler-authority-refinement-gate-tlc.md`
- Slice 0B type name: `capsched_budget_ticket`

Open gaps:

- no monitor root budget timer
- no Linux accounting integration
- no exact current/donor/proxy runtime charge equation across CFS, RT,
  deadline, sched_ext, hrtick, cgroup CPU time, and proxy execution
- no service-domain budget debit/refund policy
- no overload/DoS measurement

### ENDP-001: Resource Access Requires Typed Endpoint Authority

Claim:

```text
VFS, socket, broker, device, and remote operations require resource-specific
EndpointCap-derived frozen use. Scheduler RunCap is not resource authority.
```

Current status: Model-supported

Current evidence:

- `formal/0003-endpoint-async-provenance-model/`
- `validation/0005-endpoint-async-tlc.md`
- `analysis/0015-endpoint-async-linux-attachment-map.md`
- Slice 0B type names: `capsched_endpoint_cap`,
  `capsched_frozen_endpoint_use`

Open gaps:

- no VFS/socket endpoint implementation
- no fd acquisition/survival/revocation semantics
- no io_uring registered-resource enforcement
- no object-generation model for all endpoint families

Forbidden L0 claim:

```text
Do not treat LSM approval, fd possession, or credentials as frozen endpoint
authority.
```

### ASYNC-001: Async Work Preserves Caller Provenance

Claim:

```text
Domain-derived workqueue, task_work, io_uring, timer, RCU, completion, and
service-domain work execute with caller provenance and frozen caller authority.
```

Current status: Model-supported

Current evidence:

- `formal/0003-endpoint-async-provenance-model/`
- `analysis/0005-async-provenance-risk-map.md`
- `analysis/0015-endpoint-async-linux-attachment-map.md`
- Slice 0B type name: `capsched_work_ctx`

Open gaps:

- no CapSched work wrapper
- no io_uring carrier implementation
- no timer/RCU/softirq provenance policy
- no confused-deputy tests

### MEM-001: Other Domain Memory and Mutable Kernel State Are Unmapped

Claim:

```text
Domain-private user pages and Domain-private mutable kernel pages are mapped
only in the owning Domain MemoryView or through explicit shared/service buffers.
Linux page, slab, memcg, and cache metadata are not memory authority.
```

Current status: Model-supported

Current evidence:

- `analysis/0017-mm-allocator-page-cache-domain-state-map.md`
- `formal/0008-memory-ownership-model/`
- `validation/0010-memory-ownership-tlc.md`
- Slice 0B type names: `capsched_memory_view`, `capsched_page_owner`

Open gaps:

- no monitor PageOwner
- no MemoryView implementation
- no direct-map split/removal implementation
- no per-Domain slab/kernel-state allocation
- no exploit containment evidence

Forbidden L0 claim:

```text
Do not claim hypervisor-grade memory separation while Linux has one shared
mutable kernel MemoryView.
```

### TLB-001: No Stale Translation Crosses Activation or Revoke

Claim:

```text
Domain activation and page revoke leave no usable stale direct-map, stage-2/EPT,
ASID/PCID/VMID, IOMMU, or CPU TLB translation into another Domain's memory.
```

Current status: Model-supported

Current evidence:

- `formal/0009-direct-map-tlb-model/`
- `validation/0011-direct-map-tlb-tlc.md`

Counterexample incorporated:

```text
The first DirectMapTLB run found stale TLB-on-Domain-switch. The model now
requires flush or retag on activation and blocks page revoke completion while
translations remain.
```

Open gaps:

- no arch implementation
- no shootdown ordering proof
- no IOMMU TLB invalidation ordering
- no interrupt/entry path coverage

### PCACHE-001: Mutable Page Cache Is Domain-Owned or Service-Mediated

Claim:

```text
Sealed immutable base content may be shared, but mutable page-cache overlays
are Domain-owned and commits are serialized through a service endpoint or
equivalent commit token.
```

Current status: Model-supported

Current evidence:

- `formal/0010-page-cache-overlay-model/`
- `validation/0012-page-cache-overlay-tlc.md`

Counterexample incorporated:

```text
The first PageCacheOverlay run found stale overlay commit. The model now
requires current base version plus base-level commit serialization.
```

Open gaps:

- no filesystem-specific implementation
- no writeback/reclaim integration
- no crash-consistency policy
- no service-domain storage TCB evidence

### DEV-001: Queue Submit, DMA, IRQ, and Rate Revoke as One Lease

Claim:

```text
Device queue ownership, allowed DMA memory, interrupt route, epoch, and
queue-specific budget/rate limit are one monitor-owned QueueLease boundary.
```

Current status: Model-supported

Current evidence:

- `analysis/0016-device-iommu-queue-lease-map.md`
- `formal/0011-queue-lease-model/`
- `validation/0013-queue-lease-tlc.md`
- Slice 0B type name: `capsched_queue_lease`
- `analysis/0052-ice-modern-nic-queuelease-source-map.md`
- `analysis/0053-ice-modern-nic-revoke-source-map.md`
- `formal/0028-modern-nic-queuelease-model/`
- `validation/0046-modern-nic-queuelease-tlc.md`
- `validation/0047-ice-modern-nic-readiness-result.md`
- `formal/0029-xdp-afxdp-memory-ownership-model/`
- `validation/0048-xdp-afxdp-memory-ownership-tlc.md`
- `formal/0030-queuecontrol-representor-model/`
- `validation/0049-queuecontrol-representor-tlc.md`
- `formal/0031-modern-nic-queue-revoke-model/`
- `validation/0050-modern-nic-queue-revoke-tlc.md`
- `assurance/0002-modern-nic-queuelease-assurance-map.md`

Modern NIC subclaims:

```text
DEV-NIC-001 Queue identity and binding
DEV-NIC-002 Typed submit classes
DEV-NIC-003 Descriptor publication and doorbell ledger
DEV-NIC-004 DMA packet memory ownership
DEV-NIC-005 Completion settlement
DEV-NIC-006 QueueControl
DEV-NIC-007 RepresentorForward
DEV-NIC-008 ServiceWork and async provenance
DEV-NIC-009 Queue revoke semantics
DEV-NIC-010 Linux substrate compatibility
```

Important limitation:

```text
The modern NIC evidence is model-supported and source-observed, not
protection-evidenced. ice readiness is observation-only; all rows remain
authority_claim=false and monitor_verified=false.
```

Open gaps:

- no behavior-changing QueueLease implementation
- no IOMMU implementation
- no IRQ remapping implementation
- no VFIO/iommufd integration plan
- no monitor-backed QueueTag, QueueControlCap, RepresentorForwardCap, typed
  SubmitLedger, or DescriptorLedger
- no queue revoke/drain/quarantine implementation
- no DMA attack tests

Forbidden L0 claim:

```text
Do not treat Linux VFIO/iommufd objects as the production authority root.
Do not treat Linux netdev, ring, q_vector, devlink, representor, tracepoint, or
workqueue state as modern NIC QueueLease authority.
```

### REVOKE-001: Epoch Revoke Invalidates All Authority Paths

Claim:

```text
Domain, process, object, queue, endpoint, and cluster epoch revocation
invalidates active, queued, delayed, async, remote, and cached authority before
authority can be reused by another Domain.
```

Current status: Model-supported

Current evidence:

- `formal/0002-runnable-lease-model/`
- `formal/0007-cluster-authority-decomposition-model/`
- `formal/0008-memory-ownership-model/`
- `formal/0011-queue-lease-model/`
- related validations: `0001`, `0009`, `0010`, `0013`

Open gaps:

- no Linux lazy-vs-eager revoke decision
- no queue drain policy
- no async cancellation policy
- no object generation policy for all endpoint families

### CLUSTER-001: Cluster Leases Compile Local Before Use

Claim:

```text
Cluster-wide authority is not directly executable. It compiles into node-local
Domain epoch, SchedContext, EndpointCap, BudgetTicket, and QueueLease state
before local execution or endpoint use.
```

Current status: Model-supported

Current evidence:

- `formal/0006-cluster-lease-compilation-model/`
- `validation/0008-cluster-lease-full-systemd-tlc-run.md`
- `formal/0007-cluster-authority-decomposition-model/`
- `validation/0009-cluster-authority-decomposition-tlc.md`

Important limitation:

```text
The full ClusterLease integration run was stopped after state explosion and is
not a pass. Decomposed models are the current proof root.
```

Open gaps:

- no cluster control plane
- no signed lease format
- no node admission path
- no migration/rebalancing policy
- no failure-domain model

### COMPAT-001: Linux Compatibility Is Preserved

Claim:

```text
CapSched refines Linux scheduler, cgroup, cpuset, namespace, cred, LSM,
rlimit, hotplug, and topology constraints without silently bypassing them or
breaking Linux ABI compatibility.
```

Current status: Prototype-evidenced

Current evidence:

- source analyses `0001` through `0018`
- Slice 0A build validation `validation/0004-l0-slice0-systemd-build-run.md`
- Slice 0B build validation `validation/0014-l0-slice0b-build-run.md`

Open gaps:

- no boot/runtime evidence
- no workload compatibility matrix
- no cgroup/cpuset/sched-class behavior patch
- no user ABI compatibility test suite

### TCB-001: Monitor and Service Domains Stay Smaller Than VM/VMM Attack Area

Claim:

```text
The production TCB is small enough that replacing per-VM guest kernels with
shared Linux plus monitor-backed Domains improves or preserves attack surface
while reducing cost.
```

Current status: Open

Current evidence:

- architectural intent only
- service-domain risk analysis in `analysis/0010-dangerous-surfaces-and-service-domains.md`

Open gaps:

- no monitor code
- no TCB line count or interface count
- no service-domain split design
- no comparison to KVM, Firecracker, or container stacks

### SIDE-001: Co-Tenancy and Side-Channel Policy Is Explicit

Claim:

```text
CPU core, SMT, cache, NUMA, device, and queue co-tenancy decisions are explicit
Domain policy and do not accidentally weaken hard boundaries.
```

Current status: Open

Current evidence:

- scheduler topology analysis `analysis/0014-scheduler-topology-cluster-partition-map.md`

Open gaps:

- no side-channel threat partition
- no core scheduling integration
- no cache/NUMA isolation policy
- no performance/security tradeoff matrix

### EVAL-001: Exploit and Cost Baselines Are Tested

Claim:

```text
CapSched-H provides cross-Domain protection comparable to VM boundaries and
better cost efficiency for selected datacenter workloads.
```

Current status: Open

Current evidence:

- no direct production evidence yet

Open gaps:

- no kernel-exploit containment test
- no cross-Domain read/write/DMA test
- no monitor escape test
- no KVM/Firecracker cost comparison
- no tail-latency and throughput benchmarks

## Evidence Index

| Evidence ID | Kind | Record | Supports |
| --- | --- | --- | --- |
| E-RUN-001 | TLA validation | `validation/0001-runnable-lease-tlc.md` | EXEC, REVOKE |
| E-L0-001 | Linux build validation | `validation/0004-l0-slice0-systemd-build-run.md` | COMPAT |
| E-ENDP-001 | TLA validation | `validation/0005-endpoint-async-tlc.md` | ENDP, ASYNC |
| E-BUD-001 | TLA validation | `validation/0006-broker-budget-ticket-tlc.md` | BUDGET |
| E-SCHED-REFINE-001 | TLA validation | `validation/0106-scheduler-authority-refinement-gate-tlc.md` | EXEC, BUDGET |
| E-ACT-001 | TLA validation | `validation/0007-domain-monitor-activation-tlc.md` | ACT |
| E-CLUSTER-001 | Negative/stress record | `validation/0008-cluster-lease-full-systemd-tlc-run.md` | CLUSTER limitation |
| E-CLUSTER-002 | TLA validation | `validation/0009-cluster-authority-decomposition-tlc.md` | CLUSTER, REVOKE |
| E-MEM-001 | TLA validation | `validation/0010-memory-ownership-tlc.md` | MEM, REVOKE |
| E-TLB-001 | Counterexample-driven TLA | `validation/0011-direct-map-tlb-tlc.md` | TLB |
| E-PCACHE-001 | Counterexample-driven TLA | `validation/0012-page-cache-overlay-tlc.md` | PCACHE |
| E-DEV-001 | TLA validation | `validation/0013-queue-lease-tlc.md` | DEV, REVOKE |
| E-L0-002 | Linux build validation | `validation/0014-l0-slice0b-build-run.md` | COMPAT |
| E-MAP-001 | Analysis | `analysis/0018-protection-claim-evidence-map.md` | TOP mapping |

## Counterexample and Negative Evidence Log

| ID | Source | Meaning |
| --- | --- | --- |
| CEX-TLB-001 | `validation/0011` | Domain switch without flush/retag leaves stale TLB authority. |
| CEX-PCACHE-001 | `validation/0012` | Per-overlay commit without base serialization permits stale commit. |
| CEX-DEV-001 | `validation/0013` | IRQ aliasing across non-free queues must be forbidden. |
| CEX-SCHED-REFINE-001 | `validation/0106` | TASK_WAKING before freeze, current-only proxy budget, run after retry, and run without class settlement are rejected. |
| NEG-CLUSTER-001 | `validation/0008` | Full ClusterLease integration TLC did not finish and is not a pass. |
| HAZ-ENDP-001 | `analysis/0015` | Socket endpoint checks cannot rely only on LSM because some paths reuse `sock_sendmsg_nosec()`. |

## Forbidden Claims

Do not claim:

```text
Linux-only L0 provides hypervisor-grade isolation.
task_struct Domain pointers create a hard security boundary.
RunCap is resource endpoint authority.
EndpointCap is CPU execution authority.
SchedContext budget is monitor root budget.
Linux page/slab/memcg/page-cache metadata is memory authority.
VFIO/iommufd Linux objects are production queue authority roots.
BPF or sched_ext is the production root for No RunCap, no run.
Cluster-wide leases are directly executable.
TLC completion alone proves the datacenter OS goal.
```

## Gate Criteria

### G0: Vocabulary and Build Compatibility

Status: Completed

Evidence:

- Slice 0A Linux commit `0b685979f27b3d42ee620ced5f707ee391a2a27f`
- Slice 0B Linux commit `7cf0b1e415bcead8a2079c8be94a9d41aad7d462`
- validations `0004` and `0014`

Allowed claim:

```text
CONFIG_CAPSCHED scaffolding and type-only vocabulary build without changing
Linux scheduler behavior.
```

### G1: Assurance Case Foundation

Status: This document

Exit criteria:

```text
top-level claim exists
subclaim tree exists
current evidence is mapped
counterexamples are visible
forbidden L0 claims are visible
next Linux slice must name which claim it supports
```

### G2: Trace-Only Linux Observation

Status: Candidate

Allowed:

```text
Domain shadow identity trace or debug counters
context-switch observation
wakeup/enqueue coverage measurement
no scheduling decision changes
no user ABI unless debug/test-only and explicitly gated
```

Required evidence:

```text
build validation
runtime trace sanity
disabled-config no-impact check
explicit no-security-claim review
```

### G3: Runnable Lease Prototype

Status: Blocked until G2 or narrower source coverage gate

Required before implementation:

```text
wakeup path coverage
already-runnable task policy
migration and remote wake policy
class-specific runtime accounting
fork/exec/exit generation policy
lazy/eager revoke decision
```

### G4: Async and Endpoint Prototype

Status: Blocked

Required before implementation:

```text
workqueue/task_work/io_uring carrier design
socket/VFS/fd endpoint semantics
credential override behavior
object generation and revoke policy
```

### G5: Monitor and Memory Prototype

Status: Blocked

Required before implementation:

```text
monitor TCB design
stage-2/EPT MemoryView plan
direct-map strategy
TLB and IOMMU invalidation ordering
per-Domain mutable kernel-state split map
```

### G6: Queue Lease Prototype

Status: Blocked

Required before implementation:

```text
device-specific queue model
IOMMU map ownership
IRQ remap ownership
queue drain/revoke policy
rate/budget semantics
```

### G7: Hypervisor-Replacement Evaluation

Status: Blocked

Required:

```text
Domain-local kernel exploit containment tests
cross-Domain memory and DMA attempts
monitor attack surface review
KVM/Firecracker/container comparison
cost, tail latency, throughput, and density measurement
```

## Next Decision

The next Linux-facing choice is not enforcement. It is one of:

```text
Slice 0C:
  trace-only Domain shadow identity and transition observation

or

source-analysis gate:
  wakeup/enqueue/runnable-state coverage map before any trace patch
```

The safer default is the source-analysis gate if any scheduler path coverage
question remains unclear.
