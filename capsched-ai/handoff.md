# AI Handoff

Updated: 2026-06-26

Read this first when resuming the project.

## Current State

The workspace is `/media/nia/scsiusb/dev/linux-cap`.
The project-control Git repository is `/media/nia/scsiusb/dev/linux-cap/capsched`.

Upstream Linux has been fetched into sibling repository `linux/`. Slice 0A has
been committed in that Linux repository as inert `CONFIG_CAPSCHED` scaffolding.
Slice 0B has also been committed as type-only authority scaffolding in
`include/linux/capsched.h` and `kernel/sched/capsched.c`. No behavior-changing
scheduler patch points are accepted yet.
The source-analysis pass has been expanded through policy front-ends, mutable
kernel state, dangerous surfaces, network/socket endpoints, io_uring registered
resources, BPF programmable policy boundaries, scheduler topology/cluster
partitions, and the first formal model selection. The Runnable Lease,
Endpoint Async Provenance, Broker BudgetTicket, and Domain Monitor Activation
TLA+ models have been written and checked with TLC in tiny finite models. A
candidate Linux L0 Runnable Lease
implementation plan now exists, derived from the first model and the upstream
scheduler maps. The first Linux patch slice has been narrowed to Slice 0A:
inert `CONFIG_CAPSCHED` build scaffolding with no task layout or scheduler
behavior changes. Slice 0A is now committed in the Linux repository. Build
validation passed under a systemd user service using rootless local build tools
extracted under `tools/apt-local/root`.
The Endpoint Async model has been mapped back to concrete Linux attachment
points. Key result: `io_kiocb` and `io_rsrc_node` are natural io_uring carriers,
generic workqueue/task_work need CapSched wrappers, and socket endpoint
enforcement must not rely only on LSM hooks because some sendmmsg paths can
reuse `sock_sendmsg_nosec()`.
The Broker BudgetTicket model has also been checked. Key result: service
authority alone is insufficient; broker/service execution requires a live
caller-reserved `BudgetTicket`, frozen caller endpoint authority, live caller and
service epochs, and service-side budget.
The Domain Monitor Activation model has also been checked without weakening the
hostile Linux shadow-tag assumption. Key result: mutable Linux `linuxTag` state
may be forged, but it cannot create active execution authority without a
monitor-owned `runToken`, `activeDomain`, and `activeMemView`.
Cluster Lease Compilation modeling has been decomposed. The full integration
TLC run was stopped after state explosion with no invariant error observed, and
is not a pass. The proof root moved to smaller semantic models:
`ClusterShadowForgery` and `ClusterEpochRevoke` both passed TLC. This preserves
the hostile assumptions while avoiding a giant integration run becoming the
project objective. Device/IOMMU/queue lease analysis has also been added. Key
result: VFIO/iommufd is a valuable Linux compatibility substrate, but its
Linux-owned objects cannot be the production authority root. Future L4 device
work should model typed QueueLease semantics first: queue tag, MemoryView IOMMU
map, interrupt route, epoch, and rate/budget must revoke together.
MM allocator/page-cache analysis has also been added. Key result: Linux
`struct page`, folio, memcg, SLUB, page allocator, and page-cache metadata are
valuable lifetime/accounting/reclaim substrates, but none is the production
Domain memory authority root. Hypervisor-grade memory separation requires
monitor-owned PageOwner and MemoryView mappings.
The first MemoryOwnership formal model set has been checked via decomposition:
`PageOwnerMemoryView`, `SlabObjGen`, and `MemoryWorkProvenance` all passed TLC.
The broad integrated model was stopped after growth and is not a pass. Remaining
memory risks before real L2 MM work then moved to direct-map visibility and TLB
shootdown ordering.
The DirectMapTLB model has now also been checked. Its first TLC run found a
useful stale-translation counterexample: a CPU could switch from one Domain to
another while carrying an old TLB entry. The model now requires Domain
activation to flush or retag translations, and page revoke cannot finish while
MemoryView, direct-map, or TLB translations remain. TLC then completed with no
invariant errors.
The PageCacheOverlay model has also been checked. Its first TLC run found a
useful stale-commit counterexample: two overlays could commit against the same
sealed base version, one could advance the base, and the other remained stale
committing. The model now requires base-level commit serialization or an
equivalent commit token. TLC then completed with no invariant errors.
The generic QueueLease model has also been checked with two TLC runs after
strengthening IRQ aliasing across non-free queues. Queue submit, DMA mapping,
IRQ delivery, epoch, and budget are treated as one lease boundary; Linux shadow
queue/IOMMU state is not authority. Both runs completed with no invariant
errors.
The current strategic gap has now been recorded in
`analysis/0018-protection-claim-evidence-map.md`: the project needs an explicit
assurance chain from the top-level hypervisor-replacement claim to models,
Linux evidence, monitor evidence, counterexamples, forbidden claims, and open
gaps. `plans/0005-assurance-driven-achievement-plan.md` chooses the next gate:
proceed with Slice 0B inert type-only scaffolding while building the assurance
case in parallel.
Slice 0B is now applied and build-validated:

```text
linux commit:
  7cf0b1e415bcead8a2079c8be94a9d41aad7d462
  sched/capsched: Add type-only authority scaffolding

validation:
  capsched/capsched-models/validation/0014-l0-slice0b-build-run.md
```

It adds only opaque authority names and comments. It does not add task layout,
scheduler hooks, endpoint hooks, monitor activation, user ABI, or any security
claim.

The assurance-case foundation now exists:

```text
capsched/capsched-models/assurance/index.md
capsched/capsched-models/assurance/0001-hypervisor-grade-domain-separation-case.md
capsched/capsched-models/assurance/claims.json
```

The top-level production claim is `TOP-001`: a Domain-local userspace and
Linux-kernel-context compromise should cross into another Domain only by
breaking the HyperTag Monitor or an explicitly exposed typed service endpoint.
The claim tree currently has no `Protection-evidenced` claim. All production
security claims remain open until monitor-backed evidence exists.

After the assurance gate, the next Linux-facing choice was narrowed by source
coverage rather than by writing code. Read:

```text
capsched/capsched-models/analysis/0019-wakeup-enqueue-runnable-coverage.md
```

Key result: `activate_task()` alone is not enough even for a future runnable
authority model. The next implementation record should be a strict Slice 0C
trace-only gate tied to `EXEC-001`, `COMPAT-001`, and assurance gate `G2`.
It should not reject wakeups, enqueue, pick, or context switches.

That Slice 0C gate is now:

```text
capsched/capsched-models/implementation/0006-slice0c-trace-observation-gate.md
```

Its current recommendation is still no Linux patch: prepare a no-code trace run
plan first, using existing scheduler tracepoints and dynamic ftrace. A Linux
patch is allowed only if existing tracing cannot answer the coverage question,
and would require a new gate.

## Recovery Path

Read in this order:

1. `capsched/capsched-ai/state/state.json`
2. `capsched/capsched-ai/handoff.md`
3. `capsched/capsched-ai/design/compact.md`
4. `capsched/capsched-ai/decisions/index.md`
5. `capsched/capsched-models/analysis/index.md`
6. Any referenced ADRs or current plans

Only read longer files when the current task requires them.

## Project Essence

CapSched-Linux is a Linux scheduler and kernel architecture project. The
long-term goal is not merely better containers. It is process-to-container-scale
Domain isolation with VM-like protection strength and datacenter OS efficiency.

The final architecture is:

```text
Domain-aware Linux kernel
+ typed capability/resource endpoints
+ per-Domain mutable kernel state
+ small HyperTag Monitor enforcing non-forgeable roots
```

The Linux-only L0 prototype is for integration, semantics, and performance. It
must not claim hypervisor-grade isolation.

## Design Memory

Use this as the mental model:

```text
Capability = scheduled authority
```

Execution activates an authority context. The scheduler should activate
`DomainTag + SchedContext + Thread` under a frozen execution lease.

Implementation must keep capability types separated:

- `RunCap`: enqueue/runnable submission only
- `SchedContext`: CPU time/budget/period/placement/co-tenancy
- `FrozenRunUse`: enqueue-time frozen execution lease
- `DomainTag`: active protection context
- `SpawnCap`: bounded creation authority
- `ThreadControlCap`: suspend/resume/terminate/inspect
- `SchedControlCap`: scheduling parameter changes
- `EndpointCap`, `QueueCap`, `MemoryCap`: resource-specific endpoint authority
- `BudgetTicket`: donated caller budget for broker/service execution

## Do Not Do Yet

- Do not choose exact Linux patch points before reading current upstream code.
- Do not implement before writing investigation notes and a semantic model.
- Do not merge Linux source and project state into one repository.
- Do not claim security properties for Linux-only prototypes.
- Do not treat BPF, sched_ext, cpuset, or sched domains as the production
  security root. They are compatibility and policy substrates.

## Next Likely Action

The first two formal semantic models have been selected and checked. Runnable
lease semantics are modeled in:

```text
capsched/capsched-models/formal/0002-runnable-lease-model/
```

TLC result:

```text
capsched/capsched-models/validation/0001-runnable-lease-tlc.md
```

Endpoint async provenance semantics are modeled in:

```text
capsched/capsched-models/formal/0003-endpoint-async-provenance-model/
```

TLC result:

```text
capsched/capsched-models/validation/0005-endpoint-async-tlc.md
```

Broker budget donation semantics are modeled in:

```text
capsched/capsched-models/formal/0004-broker-budget-ticket-model/
```

TLC result:

```text
capsched/capsched-models/validation/0006-broker-budget-ticket-tlc.md
```

Domain monitor activation semantics are modeled in:

```text
capsched/capsched-models/formal/0005-domain-monitor-activation-model/
```

TLC result:

```text
capsched/capsched-models/validation/0007-domain-monitor-activation-tlc.md
```

Cluster lease compilation semantics are modeled in:

```text
capsched/capsched-models/formal/0006-cluster-lease-compilation-model/
```

Full integration stress record:

```text
capsched/capsched-models/validation/0008-cluster-lease-full-systemd-tlc-run.md
```

Decomposed cluster authority validation:

```text
capsched/capsched-models/formal/0007-cluster-authority-decomposition-model/
capsched/capsched-models/validation/0009-cluster-authority-decomposition-tlc.md
```

The current Slice 0B readiness gate is:

```text
capsched/capsched-models/implementation/0004-slice0b-readiness-gate.md
```

It says Slice 0B must remain type-only, no hot struct attachment, no behavior
change, and no collapsed capability type. Re-read it with the decomposed
cluster authority validation in mind before applying more Linux patches. It has
already been updated so Slice 0B is no longer blocked on full ClusterLease TLC
completion, but remains limited to inert type-only scaffolding.

Do not jump to scheduler behavior patches. Slice 0A is validated, the async
endpoint model, broker budget model, and domain monitor activation model are
checked, the Linux attachment map exists, and decomposed cluster authority,
MemoryOwnership, DirectMapTLB, PageCacheOverlay, and QueueLease models are
checked. The next gate is chosen: Slice 0B type-only endpoint/broker/domain
authority scaffolding is done; the assurance-case subclaim tree is now the
current project-control root. Any next Linux slice must name which assurance
claim and gate it supports. Device-specific QueueLease endpoint models remain
future L4 gates.

Endpoint attachment records:

```text
capsched/capsched-models/analysis/0015-endpoint-async-linux-attachment-map.md
capsched/capsched-models/implementation/0003-endpoint-async-attachment-plan.md
capsched/capsched-models/formal/0004-broker-budget-ticket-model/notes.md
capsched/capsched-models/formal/0005-domain-monitor-activation-model/notes.md
capsched/capsched-models/formal/0006-cluster-lease-compilation-model/notes.md
capsched/capsched-models/implementation/0004-slice0b-readiness-gate.md
capsched/capsched-models/analysis/0016-device-iommu-queue-lease-map.md
capsched/capsched-models/analysis/0017-mm-allocator-page-cache-domain-state-map.md
capsched/capsched-models/formal/0008-memory-ownership-model/notes.md
capsched/capsched-models/validation/0010-memory-ownership-tlc.md
capsched/capsched-models/formal/0009-direct-map-tlb-model/notes.md
capsched/capsched-models/validation/0011-direct-map-tlb-tlc.md
capsched/capsched-models/formal/0010-page-cache-overlay-model/notes.md
capsched/capsched-models/validation/0012-page-cache-overlay-tlc.md
capsched/capsched-models/formal/0011-queue-lease-model/notes.md
capsched/capsched-models/validation/0013-queue-lease-tlc.md
capsched/capsched-models/analysis/0018-protection-claim-evidence-map.md
capsched/capsched-models/plans/0005-assurance-driven-achievement-plan.md
capsched/capsched-models/implementation/0005-l0-slice0b-type-scaffolding.md
capsched/capsched-models/validation/0014-l0-slice0b-build-run.md
capsched/capsched-models/assurance/0001-hypervisor-grade-domain-separation-case.md
capsched/capsched-models/assurance/claims.json
capsched/capsched-models/analysis/0019-wakeup-enqueue-runnable-coverage.md
capsched/capsched-models/implementation/0006-slice0c-trace-observation-gate.md
```

Stopped full integration run identity:

```text
unit: capsched-cluster-lease-full-tlc.service
invocation ID: 82c3deeb88f142efbf66cab25d3f7fd4
log: /media/nia/scsiusb/dev/linux-cap/build/logs/cluster-lease-full-20260626T034303Z.log
metadir: /media/nia/scsiusb/dev/linux-cap/build/tlc/cluster-lease-full-20260626T034303Z
last observed: 17127406139 states generated, 550525279 distinct states,
512945750 states left on queue, no invariant error before stop
```

Current validation runner:

```text
script: /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-l0-slice0-build-validation.sh
log: /media/nia/scsiusb/dev/linux-cap/build/logs/l0-slice0-build-20260626T011458Z.log
result: passed
```

Validation evidence:

```text
baseline vmlinux built
CONFIG_CAPSCHED=n vmlinux built with no capsched.o
CONFIG_CAPSCHED=y vmlinux built with kernel/sched/capsched.o
```

Candidate implementation plan:

```text
capsched/capsched-models/implementation/0001-l0-runnable-lease-implementation-plan.md
capsched/capsched-models/implementation/0002-l0-slice0-scaffolding-plan.md
capsched/capsched-models/implementation/0003-endpoint-async-attachment-plan.md
capsched/capsched-models/validation/0002-l0-slice0-build-validation-plan.md
```

Additional source-analysis anchors:

```text
capsched/capsched-models/analysis/0013-bpf-programmable-policy-boundary.md
capsched/capsched-models/analysis/0014-scheduler-topology-cluster-partition-map.md
capsched/capsched-models/analysis/0015-endpoint-async-linux-attachment-map.md
```

Current Linux source state:

```text
repo: ../linux
remote: upstream = https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
branch: capsched-linux-l0
base: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
current commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
current subject: sched/capsched: Add type-only authority scaffolding
```
