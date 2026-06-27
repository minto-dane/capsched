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
The current scheduler-authority refinement frontier is now:

```text
analysis/0030 + formal/0013:
  fail-capable admission freeze must happen before TASK_WAKING

analysis/0031 + formal/0014 + validation/0026:
  F1 is validation/freeze, not authority discovery
  required authority, generation, epoch, budget, placement, and FrozenRunUse
  storage must already be local/prepared under p->pi_lock constraints

analysis/0032 + formal/0015 + validation/0027:
  generic wake paths and wake_q do not carry typed authority
  resumable-run or endpoint-derived authority must be prepared before
  wake_q_add(), wake_up_q(), or F1

analysis/0033 + formal/0016 + validation/0028:
  ordinary task-local resumable-run state has a strict lifecycle
  dup_task_struct raw-copy must be reset before child preparation
  wake_up_new_task requires preprepared SpawnCap-derived state
  ordinary TASK_WAKING requires a frozen local use
  revoke clears frozen/selected/running uses
  dead tasks retain no CapSched authority

analysis/0034 + formal/0017 + validation/0029:
  Domain-derived worker execution needs a typed carrier
  generic workqueue and kthread_work do not carry caller authority
  worker task authority is not caller authority
  carrier must be prepared before queue_work()/kthread_queue_work()
  pending carrier overwrite is rejected unless merge semantics are explicit
  completed/canceled/revoked work releases authority refs

analysis/0035 + formal/0018 + validation/0030:
  shared/cross-Domain futex is a typed endpoint
  FutexWaitCap gates waiter enqueue
  FutexWakeCap gates endpoint signaling but does not grant target execution
  target execution still requires task-local resumable-run freeze
  requeue requires source and target endpoint authority
  endpoint revoke invalidates queued/wake/requeue use
  cap failure after queueing is unsafe without no-lost-wake rollback proof

analysis/0036 + formal/0019 + validation/0031:
  PI/RT/ww_mutex priority donation is dependency-derived ordering authority
  PriorityDonationCap is not RunCap or SchedControlCap
  donated priority cannot create FrozenRunUse or CPU budget
  scheduler proxy execution needs an explicit owner-budget or
  ProxyExecutionTicket policy
  ww_mutex wound/wait is endpoint deadlock-resolution authority, not
  ThreadControlCap

analysis/0037 + formal/0020 + validation/0032:
  placement selection is not authority
  p->cpus_ptr is a mutable Linux placement input, not the CapSched authority
  root
  FrozenRunUse.allowed_cpus plus fresh PlacementEpoch is the authority envelope
  cpuset/fallback/force-affinity can repair Linux placement but cannot expand
  CapSched authority
  stale selected/queued/migration-pending placement must refresh, migrate
  within envelope, or fail closed before ordinary Domain execution

analysis/0038 + formal/0021 + validation/0033:
  same-Domain fast path is not no-check
  monitor transition may be skipped only with local freshness proof for Domain
  epoch, MemoryView, root budget, SchedContext budget, side policy, and
  FrozenRunUse
  NO_HZ execution of a capped Domain requires monitor-owned or unsuppressible
  budget timer coverage
  selected-state budget staleness and same-task revoke must fail closed,
  preempt, refresh, or call the monitor before ordinary execution continues

analysis/0039 + formal/0022 + validation/0034:
  MonitorRootBudget is the production CPU authority root
  SchedContextBudget is required CapSched scheduler authority
  CFS/RT/DL/SCX runtime is Linux compatibility/policy/accounting substrate only
  existing class runtime may narrow execution but must never expand CapSched
  authority or replace monitor-owned root budget enforcement
  capped NO_HZ execution requires monitor-owned or equivalent unsuppressible
  budget timer coverage
  hrtick is not an exact root cap because it is Linux-owned and has a minimum
  delay floor
  remote NO_HZ tick is not root budget enforcement
  runtime replenishment or redistribution must refresh/invalidate budget epoch
  before selected/running use continues

analysis/0040 + formal/0023 + validation/0035:
  class pick is selection, not authority
  execution requires fresh FrozenRunUse and class-specific revalidation before
  execution commit
  core cached picks require fresh core/task sequence and related freshness at
  consumption time
  deadline-server borrowed execution requires a typed server ticket or
  equivalent budget rule
  sched_ext slice refill, local DSQ position, and infinite slice cannot create
  CapSched execution authority
  proxy execution requires a ProxyExecutionTicket or explicit owner-budget rule
  donor selected authority is not owner execution authority
  class state mutation after selection must refresh, revalidate, preempt, or
  fail closed

analysis/0041 + formal/0024 + validation/0036:
  object reachability is not endpoint authority
  fd lookup, struct file refs, socket refs, fixed-file table entries, and
  EndpointBasis are inputs to derivation, not operation authority
  endpoint effects require operation-specific FrozenEndpointUse
  Linux nosec socket fast paths must still consume fresh CapSched endpoint use
  transfer-like events such as dup, SCM_RIGHTS, accept, epoll add, io_uring
  registration, and service return require derived/attenuated receiver authority
  worker/rescuer/kthread/SQPOLL/io-wq context cannot perform caller-attributed
  endpoint effects by ambient worker authority
  internal async redesign is allowed and likely required, but Domain-derived
  work still needs typed carriers; service/kernel maintenance work must remain
  a separate audited class
  endpoint/domain/object revoke invalidates queued, registered, mapped, or
  pending uses before new endpoint effects
  mmap requires MmapCap and MemoryView consequences, not plain read/write cap
  ioctl and uring command paths require typed command authority

analysis/0042 + formal/0025 + validation/0037:
  successful exec does not automatically change CapSched Domain
  exec is a new ProgramGeneration boundary for endpoint, async, mmap,
  notification, and process-image-scoped authority
  a current task may continue after exec only through same-Domain
  ExecContinuation with live SchedContext and fresh ProgramGeneration
  old FrozenEndpointUse cannot authorize post-exec endpoint effects
  surviving non-CLOEXEC fd reachability must be derived or attenuated for the
  new ProgramGeneration before endpoint effects
  CLOEXEC endpoints must not leak usable authority into the new program image
  credential or LSM-domain changes cannot amplify inherited endpoints
  execfd handoff to an interpreter is a derived endpoint handoff
  old program-generation async work and mmap/page-fault authority cannot survive
  AT_EXECVE_CHECK is a policy check only and must not mutate generation or
  derive post-exec authority

analysis/0043 + formal/0026 + validation/0038:
  post-exec fd reachability is not endpoint authority
  regular files require operation masks; O_PATH is not read/write/mmap
  authority
  sockets require socket-state and operation-specific derivation
  anonymous fds require fops/private_data class policy
  epoll old readiness and watched endpoints cannot imply new ProgramGeneration
  authority
  eventfd signal/read/write authority must be re-derived
  timerfd old timer state may exist but read/arm/ioctl authority must be
  re-derived
  io_uring ring reachability cannot carry old registered resources or activity
  execfd handoff requires ExecfdGrant

analysis/0044 + validation/0039:
  trace-only coverage can show path visibility and blind spots, not endpoint
  authority derivation
  raw syscall tracing observes fd-level surfaces only
  sched_prepare_exec/sched_process_exec bracket ProgramGeneration change
  io_uring tracepoints expose create/register/file_get/submit/async/task_work
  and completion behavior
  workqueue tracepoints expose worker execution but no caller authority
  socket tracepoints expose state/send/recv effects but no CapSched derivation
  kprobes can observe many class anchors in the QEMU build, but missing
  symbols, inline functions, and insufficient argument capture must be recorded

validation/0040:
  QEMU post-exec resource trace executed with qemu_status=0 and workload_ret=0
  using existing QEMU bzImage without rebuilding the kernel
  observed classes: CLOEXEC, regular file, O_PATH, socket, anonymous fd
  creation, timerfd
  partially observed classes: eventfd read/write without kernel-held
  eventfd_signal_mask, epoll_wait readiness without ep_insert/ep_poll probes,
  io_uring ring/register/unregister/enter without fixed-file request
  consumption
  not observed: execfd handoff

analysis/0045:
  workqueue internal redesign is accepted as a production direction, but
  internal worker execution must not become ambient caller authority
  queue_work() pending coalescing means the same work_struct cannot safely
  have its caller BudgetTicket overwritten by later callers
  worker->current_func(work) / work->func(work) executes in worker/kthread
  context, so caller authority is not naturally preserved
  immediate rule remains: Domain-derived async work needs a typed carrier
  before it leaves caller context; kernel-internal work stays service/kernel
  classified until proved otherwise

analysis/0046 + validation/0041:
  workqueue origin taxonomy is now defined for PerInvocation, ExplicitMerge,
  ServiceOnly, KernelException, InterruptDeferred, ReclaimRescue, TaskLocal,
  and unknown_or_mixed
  machine-readable taxonomy: analysis/workqueue-origin-taxonomy-v1.json
  observation plan records required tracepoints, queue-site stack/source
  correlation, output TSV schema, and hard rule that tracepoint evidence alone
  cannot justify a generic workqueue enforcement hook

validation/0042:
  source inventory runner executed successfully at
  build/workqueue-origin-source-inventory/20260627T102126Z
  known source-inferred classification rows: 10
  gap rows: 49
  largest unknown groups: drivers/net, drivers/gpu, drivers/scsi, drivers/usb,
  sound/soc
  result remains observation-only; no generic workqueue enforcement hook is
  justified yet

analysis/0047 + validation/0043:
  drivers/net source inventory runner executed successfully at
  build/workqueue-origin-drivers-net-inventory/20260627T102701Z
  callsite rows: 1440; family rows: 164; API rows: 10; hotspot rows: 40;
  gap rows: 18
  largest groups: wireless/intel, ethernet/intel, ethernet/mellanox,
  ethernet/marvell, wireless/ath
  API counts: queue_work 486, schedule_work 380, schedule_delayed_work 284,
  queue_delayed_work 211, mod_delayed_work 57
  key rule: drivers/net is a QueueLease/DeviceService hotspot; no net driver
  hook is justified until callback/container/effect mapping is done

analysis/0048:
  representative usbnet source map completed
  machine-readable map: analysis/usbnet-workqueue-source-map-v1.json
  bh_work:
    INIT_WORK at usbnet.c:1781, callback usbnet_bh_work at usbnet.c:1644,
    drains dev->done, processes rx_done/tx_done/rx_cleanup, refills RX, wakes
    TX queue, and may self-resubmit while RX queue remains short
    classification: InterruptDeferred_or_ServiceOnly with ExplicitMerge via
    dev->done plus work pending bit
  kevent:
    INIT_WORK at usbnet.c:1782, scheduled by usbnet_defer_kevent at
    usbnet.c:472 through flags bitset plus schedule_work()
    handles TX/RX halt, RX memory recovery, link reset/change, and rx_mode
    classification: ExplicitMerge_or_ServiceOnly control-plane work
  key rule:
    usbnet demonstrates that caller-derived authority belongs at submit/request
    boundaries, not in merged completion/control work_struct callbacks. A single
    mutable caller BudgetTicket on bh_work or kevent is rejected.

analysis/0049:
  representative e1000e QueueLease source map completed
  machine-readable map: analysis/e1000e-queuelease-source-map-v1.json
  data-plane boundary:
    .ndo_start_xmit maps to e1000_xmit_frame; the QueueLease submit boundary is
    before DMA map, descriptor publication, and tail doorbell write
  completion boundary:
    e1000_clean_tx_irq and clean_rx/NAPI settle descriptors, DMA unmap, BQL,
    packet delivery, and queue wake; they do not mint caller authority
  service work:
    reset_task, watchdog_task, downshift_task, update_phy_task, print_hang_task,
    and tx_hwtstamp_work are service/control or special timestamp settlement
    paths, not generic per-caller work carriers
  key rule:
    Ethernet data-plane authority should be modeled as QueueLease submit,
    in-flight descriptor ledger, IRQ/NAPI ownership, DMA/IOMMU ownership, and
    completion settlement, not as a workqueue carrier.

analysis/0050 + formal/0027 + validation/0044:
  aggregate QueueLease settlement semantics modeled and checked
  safe model:
    PASS, 16 generated states, 11 distinct states, depth 7
  unsafe counterexamples:
    doorbell without live QueueLease
    submit without budget
    DMA without IOMMU/ledger
    completion without ledger
    completion without service budget
    delivery after revoke
    pending ledger overwrite
    ambient completion authority
    foreign completion
  key rule:
    submit authority belongs at QueueLease/DMA/doorbell boundaries; merged
    completion work performs aggregate settlement only. Do not start by changing
    generic workqueue semantics or attaching one mutable caller ticket to a
    shared callback object.

analysis/0051 + validation/0045:
  observation-only queue/descriptor ledger tag plan completed
  machine-readable schema:
    analysis/queue-descriptor-ledger-tags-v1.json
  readiness runner:
    validation/run-queue-descriptor-ledger-readiness.sh
  executed run:
    /media/nia/scsiusb/dev/linux-cap/build/queue-descriptor-ledger-readiness/20260627T110900Z
  outcome:
    tracepoint rows 14, missing 0
    source anchor rows 25, missing 0
    event readiness rows 12
    semantic gap rows 8
    readiness rows carry observation_only=true, authority_claim=false, and
    monitor_verified=false
  source evidence:
    existing netdev, NAPI, IRQ, SKB, IOMMU, and DMA tracepoints expose useful
    outer events, but do not reconstruct descriptor publish, tail doorbell,
    submit-ledger correlation, completion settlement, or revoke/drop outcomes
  high-severity gaps:
    SubmitLedger id, DMA-to-submit correlation, descriptor publish, tail
    doorbell, completion ledger, revoke semantics, and authority-root
  internal-redesign answer:
    deep Linux internal redesign is accepted and likely required, but it is a
    typed substrate, not the production authority root. Domain-derived async and
    device queue effects still require proof-visible carriers/ledgers, and
    production claims still require monitor-owned QueueTag/IOMMU/epoch/budget
    roots.
  key rule:
    queue/descriptor ledger tags are observation-only. They must not decide
    behavior, must not become a stable ABI claim, and missing tags are coverage
    gaps rather than fail-open policy.
    All observed state is Linux-mutable and monitor_verified=false, so this
    readiness output is not protection evidence.

analysis/0052:
  Intel ice modern NIC QueueLease source map completed
  machine-readable map:
    analysis/ice-modern-nic-queuelease-source-map-v1.json
  why ice:
    representative modern datacenter NIC complexity: multi-queue VSI/ring/
    q_vector binding, MSI-X style vectors, NAPI, XDP, AF_XDP zero-copy,
    page-pool/XSK memory, devlink controls, SR-IOV/SF/representors, tracepoints,
    and service/reset/PTP/DPLL/eswitch work
  data-plane boundaries:
    SKB TX enters ice_start_xmit, selects vsi->tx_rings[skb->queue_mapping],
    maps SKB/frags for DMA, publishes descriptors, advances next_to_use/
    next_to_watch, and writes the TX tail doorbell
    XDP and AF_XDP have distinct frame/page-pool/XSK descriptor paths and
    cannot be collapsed into ordinary SKB SubmitLedger semantics
  completion boundary:
    ice_napi_poll cleans Tx/Rx rings and settles DMA/SKB/page-pool/XSK state;
    completion is aggregate ring/q_vector settlement, not caller authority
  control-plane boundary:
    devlink rate/scheduler controls, MSI-X/local_fwd params, VF/SF/representor
    lifecycle, and representor forwarding are QueueControl/DeviceService or
    RepresentorForward authority, not RunCap
  service-work boundary:
    ice_service_task, reset, PTP, DPLL, GNSS, eswitch bridge, LAG, and DIM work
    are service/control work. They must not receive a last-caller BudgetTicket
    merely because queue_work() or kthread_work executes later.
  required class split:
    QueueBind, SubmitLedgerSKB, SubmitLedgerXDPFrame,
    SubmitLedgerXDPTxPagePool, SubmitLedgerAFXDP, DescriptorLedger,
    CompletionSettlement, QueueControl, RepresentorForward, and ServiceWork
  hard rule:
    driver tracepoints and Linux ring/q_vector/devlink objects improve
    observability, but they are Linux-mutable and cannot be production
    authority roots. No behavior-changing driver, queue, or workqueue
    enforcement follows from this source map.

formal/0028 + validation/0046:
  Modern NIC QueueLease class model checked
  model:
    formal/0028-modern-nic-queuelease-model/ModernNicQueueLease.tla
  validation:
    validation/0046-modern-nic-queuelease-tlc.md
  safe result:
    PASS, 1474 generated states, 701 distinct states, depth 12
  unsafe counterexamples:
    submit without QueueBind
    submit without budget
    SKB submit without IOMMU proof
    XDP submit using an SKB ledger/capability
    AF_XDP zero-copy submit without XSK/UMEM ownership
    representor forwarding without derived lower queue authority
    devlink queue-control through RunCap
    service/reset/PTP/DPLL work charged to the last submitter
    completion by ambient worker/service authority
    delivery after revoke
  key rule:
    modern NIC authority must preserve operation class. QueueBind,
    SubmitLedgerSKB, SubmitLedgerXDPFrame, SubmitLedgerXDPTxPagePool,
    SubmitLedgerAFXDP, DescriptorLedger, CompletionSettlement, QueueControl,
    RepresentorForward, and ServiceWork are related but not interchangeable.

validation/0047:
  ice modern NIC observation-only static readiness checker executed
  runner:
    validation/run-ice-modern-nic-readiness.sh
  run directory:
    /media/nia/scsiusb/dev/linux-cap/build/ice-modern-nic-readiness/20260627T113618Z
  outcome:
    tracepoint rows 19, missing 0
    source anchor rows 40, missing 0
    class readiness rows 11
    gap rows 12
    all readiness rows carry observation_only=true, authority_claim=false, and
    monitor_verified=false
  readiness classes:
    QueueBind partially_ready
    SubmitLedgerSKB partial_gap_recorded
    SubmitLedgerXDPFrame source_only_gap_recorded
    SubmitLedgerXDPTxPagePool source_only_gap_recorded
    SubmitLedgerAFXDP source_only_gap_recorded
    DescriptorLedger partial_gap_recorded
    CompletionSettlement partial_gap_recorded
    QueueControl source_only_gap_recorded
    RepresentorForward partial_gap_recorded
    ServiceWork source_only_gap_recorded
    RevokeSemantics not_ready_future_capsched
  high-severity gaps:
    authority-root, queue-tag, submit-ledger-skb, submit-ledger-xdp,
    page-pool-ownership, xsk-ownership, descriptor-ledger,
    completion-settlement, queue-control, representor-derivation,
    service-provenance, revoke-semantics
  key rule:
    ice has strong observability but no protection evidence. Existing driver
    tracepoints expose ring/desc/buf/skb/eswitch state, but all observed state
    is Linux-mutable and lacks monitor QueueTag, Domain epoch, typed ledger ids,
    QueueControlCap, RepresentorForward derivation, service BudgetTicket, and
    revoke epoch/quarantine outcome.

formal/0029 + validation/0048:
  XDP and AF_XDP memory ownership model checked
  model:
    formal/0029-xdp-afxdp-memory-ownership-model/XdpAfxdpMemoryOwnership.tla
  validation:
    validation/0048-xdp-afxdp-memory-ownership-tlc.md
  safe result:
    PASS, 19 generated states, 13 distinct states, depth 6
  unsafe counterexamples:
    XDP_TX submit without page-pool ownership
    AF_XDP submit without XSK/UMEM ownership
    DMA submit without live MemoryView
    ambient AF_XDP descriptor use without freeze
    cross-Domain DMA
    completion without typed ledger
    double return of packet memory
    return after revoke
    submit without budget
  key rule:
    XDP_TX page-pool reuse and AF_XDP zero-copy require explicit memory
    ownership authority. Queue reachability, SKB authority, generic XDP
    authority, or ambient driver state cannot authorize DMA-capable packet
    memory.

formal/0030 + validation/0049:
  QueueControl and RepresentorForward model checked
  model:
    formal/0030-queuecontrol-representor-model/QueueControlRepresentor.tla
  validation:
    validation/0049-queuecontrol-representor-tlc.md
  safe result:
    PASS, 7 generated states, 7 distinct states, depth 3
  unsafe counterexamples:
    devlink queue-control through RunCap
    devlink queue-control through plain netdev reachability
    representor forwarding without RepresentorForwardCap
    representor forwarding without lower QueueLease
    representor forwarding with stale lower queue epoch
    representor forwarding by plain netdev reachability
    representor forwarding without service budget
    queue control after revoke
    representor forwarding after revoke
  key rule:
    Devlink/rate/scheduler/VF/SF/representor lifecycle authority is
    QueueControl authority. Representor transmit requires
    RepresentorForwardCap plus a live lower QueueLease. Neither may be
    authorized by RunCap, plain netdev reachability, or Linux's ability to call
    dev_queue_xmit().
```

Next work remains modeling-first: consolidate the modern NIC QueueLease
evidence into an assurance subclaim map before any behavior-changing device
hook. The older post-exec gaps also remain: eventfd kernel signal provenance,
epoll delivery/watched-endpoint correlation, io_uring fixed-file consumption,
and execfd handoff before behavior-changing endpoint hooks.
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

Schema v2 was derived from `0025` and `0026`, then Slice 0C behavior paths were
retagged under the stricter schema before any hook-placement optimizer or
behavior-changing Linux patch.

That v2 derivation is now done for gap analysis:

```text
capsched/capsched-models/analysis/0027-schema-v2-derived-from-authority-model.md
capsched/capsched-models/analysis/behavior-tags/schema-v2.json
capsched/capsched-models/analysis/behavior-tags/slice0c-scheduler-behavior-tags-v2.json
```

Important boundary: the v2 Slice 0C ledger is only for gap analysis and hard
reject. It is not hook-selection eligible and provides no enforcement or
production security claim.

The LinuxSchedulerAuthority formal model and the two remaining source maps are
now present:

```text
capsched/capsched-models/formal/0012-linux-scheduler-authority-model/
capsched/capsched-models/validation/0024-linux-scheduler-authority-tlc.md
capsched/capsched-models/analysis/0028-tick-runtime-budget-source-map.md
capsched/capsched-models/analysis/0029-fork-exec-exit-identity-propagation-map.md
```

TLC completed the tiny finite LinuxSchedulerAuthority model with no invariant
errors:

```text
126113 states generated
17344 distinct states
depth 21
```

Important boundary: this is semantic evidence only. It does not make Linux L0
an enforcement boundary and does not prove CapSched-H production isolation.

Current next step: refine the scheduler authority model before hook selection.
The `TASK_WAKING` failability refinement is now done:

```text
capsched/capsched-models/analysis/0030-task-waking-failability-boundary-map.md
capsched/capsched-models/formal/0013-scheduler-admission-failure-model/
capsched/capsched-models/validation/0025-scheduler-admission-failure-tlc.md
```

Result:

```text
Safe pre-TASK_WAKING rejection model passed.
Unsafe delayed-freeze model violated NoTaskWakingWithoutFrozenUse.
Unsafe rollback model violated NoLostWakeAfterCondition.
```

Current rule: fail-capable admission freeze must happen before
`TASK_WAKING`. Post-`TASK_WAKING` checks are nofail assertions, fail-closed
stops, or separately proven rollback/quarantine paths.

Historical note: F1 data dependencies, same-Domain fast-path freshness,
root-vs-SchedContext budget split, and class selected-state behavior have now
been modeled. The current open refinement is wider endpoint capability models
for fd/file/socket/resource operations, followed by exec process-generation
semantics.

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

The current next action is refinement of the LinuxSchedulerAuthority model and
related source maps, not Linux behavior-changing code. The records below are
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
capsched/capsched-models/analysis/0028-tick-runtime-budget-source-map.md
capsched/capsched-models/analysis/0029-fork-exec-exit-identity-propagation-map.md
capsched/capsched-models/analysis/0030-task-waking-failability-boundary-map.md
capsched/capsched-models/analysis/0031-f1-admission-freeze-data-dependencies.md
capsched/capsched-models/analysis/0032-block-wait-register-authority-preparation.md
capsched/capsched-models/formal/0012-linux-scheduler-authority-model/
capsched/capsched-models/validation/0024-linux-scheduler-authority-tlc.md
capsched/capsched-models/formal/0013-scheduler-admission-failure-model/
capsched/capsched-models/validation/0025-scheduler-admission-failure-tlc.md
capsched/capsched-models/formal/0014-f1-admission-data-model/
capsched/capsched-models/validation/0026-f1-admission-data-tlc.md
capsched/capsched-models/formal/0015-wake-authority-preparation-model/
capsched/capsched-models/validation/0027-wake-authority-preparation-tlc.md
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
