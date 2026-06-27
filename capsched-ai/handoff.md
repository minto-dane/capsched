# AI Handoff

Updated: 2026-06-27

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

The no-code trace plan and runner are:

```text
capsched/capsched-models/validation/0015-slice0c-no-code-trace-plan.md
capsched/capsched-models/validation/run-slice0c-no-code-trace.sh
```

The runner has not been executed. It needs root or tracefs write access and
captures existing scheduler tracepoints plus dynamic ftrace function entries.
Post-run interpretation is planned in:

```text
capsched/capsched-models/validation/0017-slice0c-trace-analysis-and-workloads.md
capsched/capsched-models/validation/analyze-slice0c-trace.sh
```

Important: function-entry tracing can be ambiguous. For example,
`try_to_wake_up` does not prove the self-current branch, `enqueue_task` does
not expose `ENQUEUE_DELAYED`, and `__pick_next_task` does not prove the fair
fast path.

A userspace-only workload helper now exists:

```text
capsched/capsched-models/validation/0018-slice0c-synthetic-workload-helper.md
capsched/capsched-models/validation/build-slice0c-workload.sh
capsched/capsched-models/validation/workloads/slice0c_sched_workload.c
```

It builds to `build/workloads/slice0c_sched_workload` and passed non-trace
smoke tests for `forkexec`, `futex`, `pressure`, and `affinity` modes.

Operator execution is captured in:

```text
capsched/capsched-models/validation/0019-slice0c-trace-execution-runbook.md
```

It includes build, trace, analyze, and result-record commands. The next result
file after a real trace run should be `validation/0020-slice0c-no-code-trace-result.md`.

Trace execution readiness was checked in:

```text
capsched/capsched-models/validation/0016-slice0c-trace-readiness-check.md
```

Current session result: user `nia` has uid 1000, tracefs is not writable, and
the running kernel is Ubuntu `6.17.0-35-generic`, not a recorded boot of the
CapSched worktree kernel. The runner was not executed.

The first CapSched worktree runtime observation has now moved to QEMU:

```text
capsched/capsched-models/validation/0020-slice0c-qemu-boot-validation-plan.md
capsched/capsched-models/validation/run-slice0c-qemu-boot-smoke.sh
capsched/capsched-models/validation/0021-slice0c-qemu-boot-smoke-result.md
```

Successful QEMU run:

```text
run directory:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/slice0c-boot-smoke/20260627T033853Z

serial log:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/slice0c-boot-smoke/20260627T033853Z/serial.log

counts:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/slice0c-boot-smoke/20260627T033853Z/counts.tsv

log:
  /media/nia/scsiusb/dev/linux-cap/build/logs/slice0c-qemu-boot-smoke-20260627T033853Z.log
```

Guest result:

```text
CONFIG_CAPSCHED=y
CONFIG_FUNCTION_TRACER=y
TRACEFS /sys/kernel/tracing
TRACER function
WORKLOAD_RET 0
CAPSCHED_QEMU_END workload_ret=0
qemu_status=0
```

Observed counts include `try_to_wake_up=190`, `ttwu_do_activate=294`,
`sched_ttwu_pending=222`, `wake_up_new_task=202`, `enqueue_task=253`,
`sched_switch=476`, and fork/exec/exit counts of 101 each.

Still unresolved: `ttwu_runnable`, remote wakelist functions, pick internals,
`__schedule` function entry, delayed fair requeue distinction, and core
scheduling branch distinction. Do not proceed to RunCap enforcement from this
evidence alone.

Broader QEMU workloads have also passed:

```text
capsched/capsched-models/validation/0022-slice0c-qemu-broader-workload-result.md
```

Successful runs:

```text
futex cross:
  build/qemu/slice0c-boot-smoke/20260627T054514Z

affinity:
  build/qemu/slice0c-boot-smoke/20260627T054559Z

pressure:
  build/qemu/slice0c-boot-smoke/20260627T054618Z

all:
  build/qemu/slice0c-boot-smoke/20260627T054636Z
```

All reported `CONFIG_CAPSCHED=y`, `CONFIG_FUNCTION_TRACER=y`, `WORKLOAD_RET 0`,
and `qemu_status=0`. Coverage improved for cross-CPU wake/switch, queued
migration, scheduler pressure, and lifecycle events. Persistent missing targets
are now likely ftrace/symbol eligibility or branch/argument visibility issues,
not merely missing workload pressure.

Recommended next step: analyze the QEMU `vmlinux` and ftrace eligibility for
`ttwu_runnable`, `__ttwu_queue_wakelist`, `ttwu_queue`, `__pick_next_task`,
`pick_next_task`, and `__schedule` before writing any observation patch.

That symbol/ftrace analysis now exists:

```text
capsched/capsched-models/analysis/0020-qemu-ftrace-symbol-eligibility.md
```

Key result: `ttwu_runnable`, `__ttwu_queue_wakelist`, `ttwu_queue`,
`__pick_next_task`, and `pick_next_task` are absent from the QEMU
`vmlinux/System.map`; `__schedule` exists but is declared `notrace`, while
`CONFIG_KPROBE_EVENTS_ON_NOTRACE=n`. More workload pressure will not make these
function names visible to ftrace.

The guest-side kprobe observation pass now exists:

```text
capsched/capsched-models/validation/0023-slice0c-qemu-kprobe-observation-result.md
```

Successful kprobe runs:

```text
futex cross:
  build/qemu/slice0c-boot-smoke/20260627T055620Z

affinity:
  build/qemu/slice0c-boot-smoke/20260627T060342Z

additional affinity serial evidence:
  build/qemu/slice0c-boot-smoke/20260627T055746Z
```

Key result: kprobe argument capture can distinguish `enqueue_task()` flags,
including ordinary wake enqueue, migration-related enqueue, initial enqueue,
and rq-selected wake enqueue in the clean rerun. An earlier successful affinity
serial log also observed one `ENQUEUE_DELAYED | ENQUEUE_NOCLOCK` case, so treat
delayed enqueue as observed but workload-nondeterministic. The affinity run also
captured `move_queued_task(new_cpu)` with a 20/20 split across CPU0 and CPU1.
This is still observation-only and does not justify enforcement yet.

The Slice 0C synthesis now exists:

```text
capsched/capsched-models/analysis/0021-slice0c-observation-synthesis.md
```

Key result: the evidence supports a four-role hook-placement model
(`admission/freeze`, `enqueue assertion`, `pick validation`, `switch
activation`), but it does not yet justify enforcement. A pre-tagging critical
review then found that the first behavior tag ledger is not safe for mechanical
selection.

Read next:

```text
capsched/capsched-models/analysis/0022-behavior-tagging-methodology.md
capsched/capsched-models/analysis/0023-behavior-tagging-critical-review.md
capsched/capsched-models/analysis/behavior-tags/schema-v2-requirements.json
```

The methodology correction is now accepted:

```text
capsched/capsched-ai/decisions/ADR-0006-invariant-driven-design-and-tag-indexes.md
capsched/capsched-models/analysis/0024-invariant-driven-design-and-tag-role.md
```

Key result: CapSched design is invariant-driven. Tags are evidence and
constraint indexes. Tags may reject candidates and rank surviving candidates,
but they may not declare security or choose a hook by score.

The scheduler authority state-machine root now exists:

```text
capsched/capsched-models/analysis/0025-linux-scheduler-authority-state-machine.md
capsched/capsched-models/analysis/0026-scheduler-hook-proof-obligation-matrix.md
```

Current next step: derive schema v2 from `0025` and `0026`, then retag Slice 0C
behavior paths under the stricter schema before running any hook-placement
optimizer or adding any behavior-changing Linux patch.

That v2 derivation is now done for gap analysis:

```text
capsched/capsched-models/analysis/0027-schema-v2-derived-from-authority-model.md
capsched/capsched-models/analysis/behavior-tags/schema-v2.json
capsched/capsched-models/analysis/behavior-tags/slice0c-scheduler-behavior-tags-v2.json
```

Important boundary: the v2 Slice 0C ledger is only for gap analysis and hard
reject. It is not hook-selection eligible and provides no enforcement or
production security claim.

Current next step: build the LinuxSchedulerAuthority formal model and map the
remaining source gaps for tick/runtime budget and fork/clone/exec/exit identity
propagation.

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

## Modeling Anchors And Historical Gates

The current next action is a LinuxSchedulerAuthority formal model and source
maps for budget and identity propagation, not Linux code. The records below are
still important anchors for implementation safety.

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
checked. Slice 0B type-only endpoint/broker/domain authority scaffolding is
done, and the assurance-case subclaim tree is now the project-control root.
Slice 0C observation synthesis is also done. ADR-0006 now says the design is
invariant-driven and tags are evidence/constraint indexes, not the design
engine. Schema v2 and the Slice 0C v2 ledger now exist for gap analysis and
hard reject only. v1 tags are exploratory only and must not be used as solver
input, enforcement evidence, or production security evidence. v2 tags are not
hook-selection eligible until the open proof obligations are modeled. Any next
Linux slice must name which assurance claim and gate it supports.
Device-specific QueueLease endpoint models remain future L4 gates.

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
capsched/capsched-models/analysis/0020-qemu-ftrace-symbol-eligibility.md
capsched/capsched-models/analysis/0021-slice0c-observation-synthesis.md
capsched/capsched-models/analysis/0022-behavior-tagging-methodology.md
capsched/capsched-models/analysis/0023-behavior-tagging-critical-review.md
capsched/capsched-models/analysis/0024-invariant-driven-design-and-tag-role.md
capsched/capsched-models/analysis/0025-linux-scheduler-authority-state-machine.md
capsched/capsched-models/analysis/0026-scheduler-hook-proof-obligation-matrix.md
capsched/capsched-models/analysis/0027-schema-v2-derived-from-authority-model.md
capsched/capsched-models/analysis/behavior-tags/schema-v2-requirements.json
capsched/capsched-models/analysis/behavior-tags/schema-v2.json
capsched/capsched-models/analysis/behavior-tags/slice0c-scheduler-behavior-tags.json
capsched/capsched-models/analysis/behavior-tags/slice0c-scheduler-behavior-tags-v2.json
capsched/capsched-ai/decisions/ADR-0006-invariant-driven-design-and-tag-indexes.md
capsched/capsched-models/implementation/0005-l0-slice0b-type-scaffolding.md
capsched/capsched-models/validation/0014-l0-slice0b-build-run.md
capsched/capsched-models/assurance/0001-hypervisor-grade-domain-separation-case.md
capsched/capsched-models/assurance/claims.json
capsched/capsched-models/analysis/0019-wakeup-enqueue-runnable-coverage.md
capsched/capsched-models/implementation/0006-slice0c-trace-observation-gate.md
capsched/capsched-models/validation/0015-slice0c-no-code-trace-plan.md
capsched/capsched-models/validation/0016-slice0c-trace-readiness-check.md
capsched/capsched-models/validation/0017-slice0c-trace-analysis-and-workloads.md
capsched/capsched-models/validation/0018-slice0c-synthetic-workload-helper.md
capsched/capsched-models/validation/0019-slice0c-trace-execution-runbook.md
capsched/capsched-models/validation/0020-slice0c-qemu-boot-validation-plan.md
capsched/capsched-models/validation/0021-slice0c-qemu-boot-smoke-result.md
capsched/capsched-models/validation/0022-slice0c-qemu-broader-workload-result.md
capsched/capsched-models/validation/0023-slice0c-qemu-kprobe-observation-result.md
capsched/capsched-models/validation/run-slice0c-no-code-trace.sh
capsched/capsched-models/validation/run-slice0c-qemu-boot-smoke.sh
capsched/capsched-models/validation/analyze-slice0c-trace.sh
capsched/capsched-models/validation/build-slice0c-workload.sh
capsched/capsched-models/validation/workloads/slice0c_sched_workload.c
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
