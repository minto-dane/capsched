# Compact Context

Updated: 2026-06-27

## Project

CapSched-Linux aims to introduce a capability-oriented execution and resource
authority model into Linux scheduler foundations. The long-term target is a
datacenter OS substrate where process-, service-, container-, tenant-, and
cluster-cell-scale domains can receive isolation strength comparable to VM
boundaries at lower operational cost.

Upstream Linux source has been fetched into sibling repository `linux/`.
The current work branch is `capsched-linux-l0` at commit
`7cf0b1e415bcead8a2079c8be94a9d41aad7d462`. No behavior-changing implementation
patch points are accepted yet. A first deep source-analysis pass now exists in
`capsched-models/analysis/0002` through `0031`. A candidate Linux L0 Runnable
Lease implementation plan has been derived from the checked model. Linux source
now contains Slice 0A inert `CONFIG_CAPSCHED` scaffolding and Slice 0B
type-only authority scaffolding, both with no task layout or scheduler behavior
changes.

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

## Current Scheduler Refinement

Current source/model frontier:

```text
analysis/0030 + formal/0013 + validation/0025
  TASK_WAKING failability boundary:
  fail-capable runnable admission must happen before TASK_WAKING.

analysis/0031 + formal/0014 + validation/0026
  F1 admission data-readiness boundary:
  F1 is validation/freeze, not authority discovery.

analysis/0032 + formal/0015 + validation/0027
  Wake authority preparation boundary:
  generic wake paths and wake_q carry task/state, not typed authority.
```

F1 must not allocate, sleep, walk policy, call the monitor, acquire remote
cluster authority, or discover endpoint authority through a slow global lookup
while `p->pi_lock` is held. Required authority, generation, epoch, budget,
placement, and FrozenRunUse storage must already be local/prepared. If required
data is missing, reject before `TASK_WAKING`.

Generic wake paths must not become authority-discovery interfaces. Ordinary
sleep should use task-local resumable-run state. Endpoint/shared futex waits
need endpoint-specific carriers. Workqueue and kthread_work need work item
carriers, not ambient worker authority.

Next near-term sequence:

```text
1. Map ordinary task-local resumable-run storage lifecycle.
2. Model workqueue/kthread_work caller BudgetTicket carrier semantics.
3. Model shared futex cross-Domain endpoint semantics.
4. Model PI/RT/ww_mutex priority donation separately from RunCap.
5. Model placement refresh across affinity, cpuset, and CPU hotplug.
6. Only then consider a behavior-changing L0 runnable admission slice.
```

## Assurance Root

The assurance-case foundation is now:

```text
capsched-models/assurance/index.md
capsched-models/assurance/0001-hypervisor-grade-domain-separation-case.md
capsched-models/assurance/claims.json
```

Top-level production claim:

```text
TOP-001:
  Domain-local userspace plus Domain-local Linux kernel-context compromise
  cannot cross into another Domain except by breaking the HyperTag Monitor or
  an explicitly exposed typed service endpoint.
```

Current status:

```text
No claim is Protection-evidenced.
Linux-only L0 evidence is prototype or compatibility evidence only.
Every future Linux patch must name the assurance claim and gate it supports.
```

After the assurance gate, the next Linux-facing choice was source coverage
first, not an immediate trace patch. The active note is:

```text
capsched-models/analysis/0019-wakeup-enqueue-runnable-coverage.md
```

Key result:

```text
activate_task() is not complete runnable-state coverage.
try_to_wake_up(), ttwu_runnable(), remote wakelists, wake_up_new_task(),
move_queued_task(), affinity changes, pick/core scheduling, __schedule(),
sched_class contracts, and sched_ext custody all matter.
```

Next intended gate:

```text
Slice 0C trace-only implementation gate
  claims: EXEC-001, COMPAT-001
  assurance gate: G2
  no behavior change
```

The gate now exists:

```text
capsched-models/implementation/0006-slice0c-trace-observation-gate.md
```

Current recommendation:

```text
Do not patch Linux yet.
Prepare a no-code trace run plan with existing scheduler tracepoints and
dynamic ftrace first.
```

The no-code trace plan now exists:

```text
capsched-models/validation/0015-slice0c-no-code-trace-plan.md
capsched-models/validation/run-slice0c-no-code-trace.sh
capsched-models/validation/0017-slice0c-trace-analysis-and-workloads.md
capsched-models/validation/analyze-slice0c-trace.sh
capsched-models/validation/0018-slice0c-synthetic-workload-helper.md
capsched-models/validation/0019-slice0c-trace-execution-runbook.md
```

It has not been executed. It requires root or tracefs write access.
Future trace results must distinguish observed, ambiguous, not observed, and
not inferable categories. Function-entry tracing alone does not expose all
branch or flag semantics.

The userspace helper builds and smoke-tests locally:

```text
build/workloads/slice0c_sched_workload
modes: forkexec, futex, affinity, pressure, all
```

QEMU runtime observation now exists:

```text
capsched-models/validation/0020-slice0c-qemu-boot-validation-plan.md
capsched-models/validation/0021-slice0c-qemu-boot-smoke-result.md
capsched-models/validation/run-slice0c-qemu-boot-smoke.sh
```

Successful run:

```text
build/qemu/slice0c-boot-smoke/20260627T033853Z
CONFIG_CAPSCHED=y
CONFIG_FUNCTION_TRACER=y
WORKLOAD_RET 0
qemu_status=0
```

Broader QEMU workload results:

```text
capsched-models/validation/0022-slice0c-qemu-broader-workload-result.md
futex cross: build/qemu/slice0c-boot-smoke/20260627T054514Z
affinity:    build/qemu/slice0c-boot-smoke/20260627T054559Z
pressure:    build/qemu/slice0c-boot-smoke/20260627T054618Z
all:         build/qemu/slice0c-boot-smoke/20260627T054636Z
```

All passed with `WORKLOAD_RET 0` and `qemu_status=0`. This is reproducible
CapSched worktree kernel boot/trace evidence, still observation only. Coverage
gaps remain around already-runnable wake, remote wakelist, pick internals,
`__schedule`, delayed fair requeue, and core scheduling branches. Because the
same function targets stayed missing across workloads, next inspect vmlinux and
ftrace eligibility before any Linux observation patch.

Symbol/ftrace analysis:

```text
capsched-models/analysis/0020-qemu-ftrace-symbol-eligibility.md
```

Key result: `ttwu_runnable`, `__ttwu_queue_wakelist`, `ttwu_queue`,
`__pick_next_task`, and `pick_next_task` are absent from the QEMU symbol table;
`__schedule` exists but is `notrace` and kprobes-on-notrace is disabled.

Guest-side kprobe observation now exists:

```text
capsched-models/validation/0023-slice0c-qemu-kprobe-observation-result.md
futex cross: build/qemu/slice0c-boot-smoke/20260627T055620Z
affinity:    build/qemu/slice0c-boot-smoke/20260627T060342Z
```

Key result: `enqueue_task()` argument capture distinguishes ordinary wake
enqueue, migration-related enqueue, initial enqueue, and rq-selected wake
enqueue in clean reruns. One `ENQUEUE_DELAYED | ENQUEUE_NOCLOCK` case was
observed in the earlier successful affinity serial log
`20260627T055746Z`, but not in the latest clean counts run, so delayed enqueue
is workload-nondeterministic in this harness. `move_queued_task(new_cpu)` was
observed under the affinity workload with a CPU0/CPU1 split. This is
observation-only evidence.

Slice 0C synthesis and tag review:

```text
analysis/0021:
  observation synthesis is done; hook roles are admission/freeze, enqueue
  assertion, pick validation, and switch activation.

analysis/0022:
  behavior tagging methodology is hard constraints first, then Pareto/scenario
  optimization.

analysis/0023:
  critical review rejected the v1 tag ledger for solver use.

ADR-0006 / analysis/0024:
  design is invariant-driven; tags are evidence and constraint indexes, not a
  design engine.

analysis/0025:
  Linux scheduler authority state machine maps wake, enqueue, migration, pick,
  switch, budget, and exit to CapSched authority transitions.

analysis/0026:
  hook proof-obligation matrix maps roles to invariants, failability, evidence,
  and required models.

analysis/0027 + behavior-tags/schema-v2.json:
  schema v2 is derived from the state machine and obligation matrix.

behavior-tags/slice0c-scheduler-behavior-tags-v2.json:
  Slice 0C is retagged for gap analysis and hard reject only; it is not
  hook-selection eligible.

behavior-tags/schema-v2-requirements.json:
  critical-review requirement source kept as a check against schema v2.
```

The LinuxSchedulerAuthority model and the two source maps now exist:

```text
formal:
  capsched-models/formal/0012-linux-scheduler-authority-model/

validation:
  capsched-models/validation/0024-linux-scheduler-authority-tlc.md

analysis:
  capsched-models/analysis/0028-tick-runtime-budget-source-map.md
  capsched-models/analysis/0029-fork-exec-exit-identity-propagation-map.md
```

TLC checked the tiny finite model:

```text
126113 states generated
17344 distinct states
depth 21
no invariant error found
```

The `TASK_WAKING` failability refinement now exists:

```text
analysis:
  capsched-models/analysis/0030-task-waking-failability-boundary-map.md

formal:
  capsched-models/formal/0013-scheduler-admission-failure-model/

validation:
  capsched-models/validation/0025-scheduler-admission-failure-tlc.md
```

TLC result:

```text
safe pre-TASK_WAKING rejection:
  passed, 8 states generated, 7 distinct states

unsafe delayed-freeze:
  expected counterexample to NoTaskWakingWithoutFrozenUse

unsafe rollback:
  expected counterexample to NoLostWakeAfterCondition
```

Current rule: fail-capable admission freeze must happen before `TASK_WAKING`.
Post-`TASK_WAKING` checks are nofail assertions, fail-closed stops, or
separately proven rollback/quarantine paths.

Next executable step: map F1 admission-freeze data dependencies under
`p->pi_lock`, then continue same-Domain monitor fast-path freshness,
root-vs-SchedContext budget split, NO_HZ/hrtick overrun, class-specific
selected-state behavior, and exec process-generation semantics. Do not use the
v1 ledger as solver input, enforcement evidence, or production security
evidence. Do not use the v2 ledger for hook selection yet.

Readiness check:

```text
capsched-models/validation/0016-slice0c-trace-readiness-check.md
```

Current session cannot execute it:

```text
uid 1000 user nia
tracefs_writable=no
running kernel: Ubuntu 6.17.0-35-generic
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

The Endpoint Async Provenance model also exists and passed TLC invariant
checking in a tiny finite model:

```text
formal model:
  capsched-models/formal/0003-endpoint-async-provenance-model/

validation:
  capsched-models/validation/0005-endpoint-async-tlc.md

TLC summary:
  291297 states generated
  37392 distinct states
  no invariant error found
```

The Broker BudgetTicket model also exists and passed TLC invariant checking in a
tiny finite model:

```text
formal model:
  capsched-models/formal/0004-broker-budget-ticket-model/

validation:
  capsched-models/validation/0006-broker-budget-ticket-tlc.md

TLC summary:
  129777 states generated
  25008 distinct states
  no invariant error found
```

The Domain Monitor Activation model also exists and passed TLC invariant
checking in a tiny finite model without weakening the hostile Linux shadow-tag
assumption:

```text
formal model:
  capsched-models/formal/0005-domain-monitor-activation-model/

validation:
  capsched-models/validation/0007-domain-monitor-activation-tlc.md

TLC summary:
  primary run:
    82993249 states generated
    1916784 distinct states
    no invariant error found
  second run:
    same state graph size, 8 workers, different fingerprint index
    no invariant error found
```

Cluster Lease Compilation modeling has been decomposed:

```text
formal model:
  capsched-models/formal/0006-cluster-lease-compilation-model/

full integration model:
  ClusterLease.tla

auxiliary split models:
  ClusterBudget.tla
  ClusterEndpoint.tla

current validation:
  capsched-models/validation/0008-cluster-lease-full-systemd-tlc-run.md

decomposed authority validation:
  capsched-models/formal/0007-cluster-authority-decomposition-model/
  capsched-models/validation/0009-cluster-authority-decomposition-tlc.md
```

The full integration model was intentionally not weakened, but its systemd TLC
run was stopped after state explosion:

```text
17127406139 states generated
550525279 distinct states
512945750 states left on queue
no invariant error observed before interruption
```

This is not a pass. The validation strategy now treats the full model as broad
stress/regression evidence and uses smaller semantic models as proof roots.
`ClusterShadowForgery` and `ClusterEpochRevoke` passed TLC.

MM allocator/page-cache analysis now records:

```text
Linux page/folio/memcg/slab/page-cache metadata:
  lifetime, accounting, reclaim, and performance substrate

Production Domain memory authority:
  monitor-owned PageOwner and MemoryView mappings
```

The first MemoryOwnership model set has now been checked via decomposition:

```text
PageOwnerMemoryView:
  monitor PageOwner and MemoryView mapping rules

SlabObjGen:
  slab object generation and page-owner validation

MemoryWorkProvenance:
  reclaim/writeback/service memory work provenance and tickets
```

The broad integrated `MemoryOwnership.tla` run was stopped after growth and is
not a pass. memcg can mirror/account Domain budgets, but cannot be the security
root.

The DirectMapTLB model then checked the next memory hazard: stale direct-map or
TLB translations can bypass a correct PageOwner story. The first run found a
real counterexample where a CPU switched Domains while carrying an old TLB
entry. The model now requires Domain activation to flush or retag translations,
and page revoke cannot finish while MemoryView, direct-map, or TLB translations
remain.

```text
formal model:
  capsched-models/formal/0009-direct-map-tlb-model/

validation:
  capsched-models/validation/0011-direct-map-tlb-tlc.md

TLC summary:
  8224001 states generated
  386784 distinct states
  no invariant error found after the activation fix
```

The PageCacheOverlay model then checked the remaining L2 page-cache conflict
hazard. The first run found a real counterexample where two overlays entered
`committing` for the same sealed base version; after one advanced the base, the
other remained stale committing. The model now requires base-level commit
serialization or an equivalent commit token.

```text
formal model:
  capsched-models/formal/0010-page-cache-overlay-model/

validation:
  capsched-models/validation/0012-page-cache-overlay-tlc.md

TLC summary:
  7370677 states generated
  524808 distinct states
  no invariant error found after the serialization fix
```

The generic QueueLease model then checked the L4 device/I/O boundary. It treats
queue submit, DMA mapping, IRQ delivery, epoch, and budget as one lease
boundary. Linux shadow queue and IOMMU state are explicitly modeled as
forgeable non-authority state.

```text
formal model:
  capsched-models/formal/0011-queue-lease-model/

validation:
  capsched-models/validation/0013-queue-lease-tlc.md

TLC summary:
  primary and second runs:
    97882849 states generated
    6465312 distinct states
    no invariant error found
```

The current strategic gap is now explicit: these models are useful semantic
evidence, but the project needs an assurance case that maps top-level
hypervisor-replacement claims to models, Linux evidence, monitor evidence,
counterexamples, forbidden claims, and missing gates.

```text
analysis:
  capsched-models/analysis/0018-protection-claim-evidence-map.md

plan:
  capsched-models/plans/0005-assurance-driven-achievement-plan.md

next gate:
  Slice 0B inert type-only scaffolding
  assurance-case subclaim tree in parallel
```

Slice 0B is now applied in Linux and build-validated:

```text
linux commit:
  7cf0b1e415bcead8a2079c8be94a9d41aad7d462
  sched/capsched: Add type-only authority scaffolding

changed files:
  include/linux/capsched.h
  kernel/sched/capsched.c

validation:
  capsched-models/validation/0014-l0-slice0b-build-run.md
```

It is still inert: no scheduler hooks, no endpoint hooks, no monitor
activation, no task layout changes, no user ABI, and no security claim.

The Endpoint Async model has been mapped back to Linux source in:

```text
analysis:
  capsched-models/analysis/0015-endpoint-async-linux-attachment-map.md

candidate plan:
  capsched-models/implementation/0003-endpoint-async-attachment-plan.md
```

Key result:

```text
io_uring:
  io_kiocb and io_rsrc_node are natural carriers.

generic workqueue/task_work:
  use CapSched wrappers for Domain-derived work, not raw work_struct or
  callback_head authority.

socket:
  do not rely only on LSM hooks because sendmmsg can reuse sock_sendmsg_nosec().
```

Device/IOMMU/queue lease analysis has been added in:

```text
capsched-models/analysis/0016-device-iommu-queue-lease-map.md
```

Key result:

```text
VFIO/iommufd:
  good compatibility substrate and object vocabulary.

production authority:
  must be monitor-owned QueueTag + MemoryView/IOMMU map + interrupt route +
  queue epoch + rate/budget.

future L4:
  generic QueueLease is checked; device-specific NIC/NVMe/GPU/VFIO endpoint
  models remain before touching VFIO, iommufd, IOMMU, or drivers.

future L2:
  direct-map/TLB revocation and page-cache overlay conflict semantics are
  checked before touching L2 MM/page-cache implementation.
```

The next gate is not Linux behavior changes yet. The out-of-tree baseline and
`CONFIG_CAPSCHED=n/y` build validation passed for Slice 0A and Slice 0B. Slice
0C observation synthesis is done, and the methodology has been corrected to
invariant-driven design with tag-indexed evidence. Schema v2 and Slice 0C v2
retagging now exist for gap analysis/hard reject. The next gate is formal and
source-analysis coverage, not hook-placement optimization or enforcement
patches.

Current validation runner:

```text
script: capsched-models/validation/run-l0-slice0-build-validation.sh
latest log:
  /media/nia/scsiusb/dev/linux-cap/build/logs/l0-slice0-build-20260627T005252Z.log
latest result:
  passed for Slice 0B
```

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
No FrozenEndpointUse, no async endpoint execution.
Linux credential override must not change CapSched DomainTag.
```

Current next decision:

```text
Review:
  capsched-models/implementation/0004-slice0b-readiness-gate.md
using:
  capsched-models/validation/0009-cluster-authority-decomposition-tlc.md

Slice 0B, if accepted, should be type-only authority scaffolding in
include/linux/capsched.h and kernel/sched/capsched.c with no hot struct
attachment, no behavior change, no user ABI, and no collapsed capability type.
The gate has been updated for decomposed cluster authority validation; it is not
an accepted Linux patch yet.

Future alternate gate:
  model a device-specific QueueLease endpoint before L4 device work
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
