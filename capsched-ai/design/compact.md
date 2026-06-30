# Compact Context

Updated: 2026-06-30

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
`capsched-models/analysis/0002` through `0044`. A candidate Linux L0 Runnable
Lease implementation plan has been derived from the checked model. Linux source
now contains Slice 0A inert `CONFIG_CAPSCHED` scaffolding and Slice 0B
type-only authority scaffolding, both with no task layout or scheduler behavior
changes.

ADR-0007 adds a project-wide traceability rule: `N-*` ids are only
chronological work records, for both N-001 through N-105 and N-106 onward.
Semantic interpretation is an overlay under `capsched-models/traceability/`.
Linux anchors must record checked commits and default to no authority, no
monitor verification, and no protection claim. Existing source maps are
topic-local; a central drift-aware N/artifact/Linux/claim ledger remains a
pending traceability build-out.

ADR-0008 adds the long-horizon-first implementation rule. L0 and all later
slices are designed backward from the final monitor-backed CapSched-H target.
Small Linux hooks remain desirable for upstream tracking, but they must preserve
the shape of HyperTag Monitor authority, Domain epochs, MemoryViews, root CPU
budgets, IOMMU/queue ownership, async provenance, and service-domain boundaries.

Modern NIC QueueLease/revoke status:

```text
formal/0031 + validation/0050:
  queue revoke/drain/quarantine model checked.

analysis/0053 + validation/0051:
  Intel ice revoke anchors are source-observed and readiness-checked only.
  latest readiness run:
    build/ice-revoke-readiness/20260630T002344Z
  result:
    tracepoint_rows=8, source_anchor_rows=31,
    obligation_readiness_rows=10, gap_rows=8
  every row:
    observation_only=true
    authority_claim=false
    monitor_verified=false

do not claim:
  netdev down/reset, Linux ring cleanup, DMA unmap, NAPI disable, devlink
  reload, representor stop, or service work cancellation as QueueLease revoke
  authority.

latest completed focused risk:
  Modern NIC ServiceWork carrier and service/caller authority intersection
  for reset/PTP/DPLL/eswitch/LAG/firmware/maintenance work.

latest completed focused risk:
  VF mailbox QueueControl/DMA/IRQ/budget/FDIR carrier semantics.

latest completed focused risk:
  VF identity epoch and SR-IOV/VF reset/reassignment handoff so old vf_id, VSI,
  queue, IRQ, DMA, or FDIR state cannot carry authority into a new Domain.

latest completed focused risk:
  Modern NIC HyperTag Monitor interface and Linux service/driver Domain split
  for QueueLease/VF/DMA/IRQ/representor/offload/service-work authority.

latest completed focused risk:
  Modern NIC HyperTag implementation-readiness gate for observation-only
  probes, inert stubs, and no behavior-changing approval before gate
  satisfaction.

latest completed focused risk:
  Modern NIC HyperTag observation ledger and no-code source runner, with 37
  rows emitted, 36 available anchors, 1 expected LocalDomainDeviceLease gap, and
  0 safety-flag violations.

latest completed focused risk:
  LocalDomainDeviceLease external gap resolution. Analysis/0064 and formal/0042
  treat it as root-management/local monitor compilation, not a Linux source
  anchor. Validation/0063 safe TLC passed with 10 generated states, 9 distinct
  states, and depth 9. Unsafe configs reject ClusterLease direct use, scheduler
  placement authority, service admission minting, Linux device registration
  authority, stale epochs, wrong service/target Domains, queue receipt before
  local lease, and audit-only compile.

latest completed focused risk:
  LocalDomainDeviceLease observation contract. Analysis/0065 defines the
  pre-monitor row shape and dependency rules. Validation/0064 ran the validator:
  10 rows, 7 dependency rules, 0 dependency errors, 0 safety-flag violations,
  and 9 forbidden authority collapses.

latest completed focused risk:
  LocalDomainDeviceLease admission protocol. Analysis/0066 and formal/0043 add
  terminal failure paths and revoke ordering. Validation/0065 safe TLC passed
  with 29 generated states, 21 distinct states, and depth 14; unsafe configs
  reject bad-cluster compile, service/target mismatch compile, receipt before
  compile, receipt during revoke, reuse before revoke completion, and audit-only
  acceptance.

latest completed focused risk:
  Direct-call overlay drift checker. Validation/0079 executed
  check-direct-call-overlay-drift.sh against the N-106 overlay seed. Run
  20260630T230822Z emitted 41 anchor rows, with 34 ok rows, 7 expected gap/plan
  rows, 0 path changes, 0 missing patterns, 0 semantic recheck-required rows,
  and 0 safety-flag violations. The run remained source-only: no Linux
  modification, no root requirement, no tracefs writes, no probe attachment, no
  public tracepoint ABI, no authority claim, no monitor verification claim, and
  no protection claim.

next focused risk:
  Generalize direct-call drift checking into a project-level traceability
  ledger/checker for older source-map families while preserving ADR-0007/0008.

formal/0032 + validation/0052:
  VF IRQ ownership model checked.
  safe TLC:
    25 generated states, 22 distinct states, depth 6
  unsafe counterexamples:
    VF path assumes host synchronize_irq()
    stale completion after revoke
    reassignment without owner-specific IRQ quiescence
    host-owned reassignment without synchronize_irq()
    monitor-owned reassignment without monitor invalidation
  design rule:
    ICE_VSI_VF synchronize_irq skip is not QueueLease revoke safety. It must be
    covered by monitor-visible IRQ route invalidation or a separately modeled
    VF-owned route protocol.

analysis/0054 + formal/0033 + validation/0053:
  monitor IRQ route invalidation substrate mapped and modeled.
  source substrate:
    ice IRQ mask/free paths
    VFIO eventfd/request_irq/free_irq paths
    iommufd isolated-MSI and allow_unsafe_interrupts paths
    PCI/MSI allocation/free paths
    generic MSI domain deactivate/free
    Intel IRTE clear + qi_flush_iec
  safe TLC:
    14 generated states, 12 distinct states, depth 8
  unsafe counterexamples:
    unsafe interrupt override
    eventfd delivery after revoke
    reassignment without receipt
    receipt without IEC flush
    receipt with posted interrupt state
    receipt with eventfd still live
  design rule:
    IRQ revoke is a monitor-visible receipt, not any one Linux teardown call.

analysis/0055 + formal/0034 + validation/0054:
  monitor DMA/IOMMU/MemoryView invalidation substrate mapped and modeled.
  source substrate:
    ice ring cleanup, XSK DMA map/unmap, and per-queue disable paths
    ice wait=false Rx disable hazard vs all-Rx flush/wait path
    DMA API and dma-iommu unmap/queued-flush paths
    IOMMU core default-vs-blocking domain ownership behavior
    iommufd access-user notify/unmap/unpin paths
    VFIO type1 unmap/unpin callbacks and batched sync paths
    arch-IOMMU invalidation backends
  safe TLC:
    17 generated states, 17 distinct states, depth 17
  unsafe counterexamples:
    IRQ-only reassignment
    driver-unmap-only receipt
    IOMMU unmap without IOTLB sync
    queued flush as receipt
    PageOwner transfer with DMA in flight
    new MemoryView before old unmap
    completion after revoke
    packet return before receipt
  design rule:
    DMA revoke is a monitor-visible receipt, not IRQ revoke, ring cleanup,
    dma_unmap, XSK unmap, iommufd/VFIO unmap, iommu_unmap_fast, queued flush,
    page unpin, or refcount release.

analysis/0056 + formal/0035 + validation/0055:
  XSK/page-pool stale completion quarantine substrate mapped and modeled.
  source substrate:
    ice AF_XDP xsk_tx_completed and xsk_buff_free paths
    AF_XDP CQ reservation/submission and free-list return
    page_pool recycle/return/dma-sync/scrub paths
  safe TLC:
    11 generated states, 11 distinct states, depth 11
  unsafe counterexamples:
    XSK CQ submit after revoke
    XSK free-list return after revoke
    page-pool recycle after revoke
    packet return before DMA receipt
    PageOwner transfer before quarantine
    packet return without generation reset
    double return
    queue reassignment before settlement
  design rule:
    packet memory return is a quarantine/generation-reset settlement, not
    xsk_tx_completed(), xsk_buff_free(), page_pool recycle, or DMA receipt
    alone.

analysis/0057 + formal/0036 + validation/0056:
  representor lower QueueLease derivation substrate mapped and modeled.
  source substrate:
    ice representor xmit retargets skb->dev to metadata lower_dev
    dev_queue_xmit, TC/BPF redirect, bridge/FDB/VLAN/switchdev paths
    ice TC flower offload and hardware switch rule install/delete
    LAG lower_dev update and representor Tx queue stop
  safe TLC:
    14 generated states, 8 distinct states, depth 4
  unsafe counterexamples:
    representor netdev-only lower forwarding
    bridge FDB/VLAN as lower lease
    TC/offload without control authority or with stale destination
    stale LAG lower_dev forwarding
    forwarding after revoke
    representor stop as lower QueueLease revoke
  design rule:
    lower queue submit is not representor netdev reachability, metadata_dst,
    bridge FDB/VLAN success, TC redirect target, switchdev mark, LAG rewrite,
    or representor queue stop. It needs a frozen RepresentorForward-to-lower
    QueueLease carrier; hardware offload needs QueueControl/Offload authority
    and stale-rule invalidation on revoke.

analysis/0058 + formal/0037 + validation/0057:
  ICE ServiceWork carrier substrate mapped and modeled.
  source substrate:
    ice service-task coalescing via ICE_SERVICE_SCHED and queue_work()
    reset/AdminQ/MailboxQ/SidebandQ firmware event handling
    VF virtchnl queue-control, queue DMA address, IRQ map, bandwidth/quanta,
      and FDIR-like paths
    PTP/DPLL deferred control and maintenance workers
    bridge/eswitch/LAG/GNSS service work and reset/rebuild replay
  safe TLC:
    29 generated states, 18 distinct states, depth 5
  unsafe counterexamples:
    service-worker ambient queue effect
    VF mailbox effect without a carrier
    coalesced loop last-caller authority
    PTP control without a carrier
    DPLL control without a carrier
    bridge/offload effect without policy/control authority
    LAG rebind without fresh lower QueueLease
    reset/rebuild replay after revoke without fresh authorization
  design rule:
    service worker execution is service authority, not caller authority. A
    caller-derived effect needs a typed carrier, effect-specific cap, fresh
    epochs, QueueLease/QueueControl/Offload/PTP/DPLL/DMA/IRQ/lower-lease
    authority as applicable, and service or caller-charged budget.

analysis/0059 + formal/0038 + validation/0058:
  ICE VF mailbox carrier substrate mapped and modeled.
  source substrate:
    virtchnl validation and opcode allowlists in ice_vc_process_vf_msg()
    VF-provided tx/rx dma_ring_addr copied in ice_vc_cfg_qs_msg()
    ring->dma packed into Tx/Rx hardware queue context in ice_base.c
    VF vector-to-queue IRQ mapping in ice_vc_cfg_irq_map_msg()
    queue bandwidth/quanta programming in ice_vc_cfg_q_bw()/cfg_q_quanta()
    FDIR add/delete and ctx_irq/ctx_done async completion
  safe TLC:
    42 generated states, 23 distinct states, depth 7
  unsafe counterexamples:
    virtchnl validation/opcode allowlist as authority
    DMA ring base without MemoryView/IOMMU authority
    queue enable without frozen queue config
    IRQ map without route authority
    queue budget/quanta without budget authority
    FDIR write without OffloadCap
    FDIR completion without frozen context
    effects after revoke
  design rule:
    VF mailbox validity is not authority. Queue config, DMA ring base, queue
    enable, IRQ map, queue budget/quanta, FDIR write, and FDIR async completion
    each need an explicit carrier and fresh epoch.

analysis/0060 + formal/0039 + validation/0059:
  ICE VF epoch handoff substrate mapped and modeled.
  source substrate:
    vf_id lookup and ice_vf lifetime through RCU/kref
    vf->cfg_lock, ICE_VF_STATE_ACTIVE/DIS, and virtchnl allowlists
    reset/rebuild/free/VFLR paths, VSI reuse, and ctrl VSI release/reinit
    VPINT/VPLAN/GLINT vector and queue mapping clear/reprogram paths
    VF-provided DMA ring base, queue/IRQ config, FDIR ctx_irq/ctx_done, and
      service replay
  safe TLC:
    9 generated states, 9 distinct states, depth 9
  unsafe counterexamples:
    visible vf_id reuse without fresh VF epoch
    VSI reuse without generation bump
    queue reassignment before DMA/IOMMU revoke
    IRQ route reassignment before stale route revoke
    FDIR completion surviving reset
    mailbox acceptance during reset embargo
    allowlist/capability state surviving reset as authority
    service replay under the old epoch
  design rule:
    VF handoff requires mailbox embargo, queue quiescence, DMA/IRQ revoke
    receipts, FDIR context clear or epoch-tag, VF epoch bump, VSI/QueueLease
    generation bump, fresh Domain binding, and fresh service replay authority.
    vf_id equality, ice_vf reachability, cfg_lock, ACTIVE/DIS state, stable VSI,
    queue/vector id, allowlist state, reset completion, or VPINT/VPLAN writes
    are not authority.

analysis/0061 + formal/0040 + validation/0060:
  Modern NIC HyperTag Monitor interface and service/driver Domain split mapped
  and modeled.
  architecture split:
    Monitor owns Domain epochs, MemoryViews/PageOwner roots, DMA roots,
    QueueTag/QueueLease epochs, IRQ route tags, VF/SF binding epochs, root
    budgets, sealed receipt keys, and immutable audit roots.
    Linux service/driver Domain owns virtchnl/devlink/TC/switchdev policy, PF
    driver sequencing, netdev/NAPI/ring/q_vector lifecycle, reset/rebuild,
    PTP/DPLL/GNSS workers, and hardware programming substrate.
    target Domains receive typed endpoints only.
  safe TLC:
    10 generated states, 10 distinct states, depth 10
  unsafe counterexamples:
    service Domain receipt minting
    Linux DMA as receipt
    Linux IRQ as receipt
    raw endpoint exposure
    queue activation without DMA/IRQ/ledger roots
    service replay under old epoch
    remote cluster lease used directly
    audit-only monitor calls
    per-packet monitor traps
  design rule:
    service policy, Linux state, mailbox validity, DMA/IRQ teardown, queue/VSI
    ids, reset completion, remote lease text, and audit logs are not monitor
    authority. Monitor entry is for bind, config, revoke, epoch, budget, and
    ownership changes, not ordinary packet submission.

analysis/0062 + implementation/0007 + formal/0041 + validation/0061:
  Modern NIC HyperTag implementation-readiness gate mapped and modeled.
  gate rule:
    every required receipt/carrier row maps to observation-only probes or inert
    stubs with observation_only=true, authority_claim=false,
    monitor_verified=false, behavior_change=false, and protection_claim=false.
  safe TLC:
    8 generated states, 7 distinct states, depth 7
  unsafe counterexamples:
    behavior approval before gate satisfaction
    probe-as-authority
    non-inert stub
    missing receipt/carrier coverage
    raw endpoint stub
    protection claim from readiness evidence
  design rule:
    readiness may scope a future observation patch; it is not a monitor receipt,
    authority, implementation, or production protection claim.

analysis/0063 + validation/0062:
  Modern NIC HyperTag observation ledger and no-code source runner emitted.
  latest run:
    build/modern-nic-hypertag-observation-ledger/20260630T044602Z
  result:
    ledger_rows=37
    available_rows=36
    missing_rows=1
    gap_rows=1
    safety_flag_violations=0
  flags:
    observation_only=true
    authority_claim=false
    monitor_verified=false
    behavior_change=false
    protection_claim=false
  only missing row:
    LocalDomainDeviceLease is external to upstream Linux; root-management and
    local monitor compilation observation remains a high-severity gap.
```

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

Endpoint refinement adds:

```text
object reachability is not endpoint authority.
fd lookup, struct file/socket refs, fixed files, and EndpointBasis are not
operation authority.
endpoint effects require operation-specific FrozenEndpointUse.
transfer/register/accept/SCM_RIGHTS/epoll/service return require derived or
attenuated receiver authority.
async worker/service execution needs caller frozen authority plus BudgetTicket;
ambient worker authority is not enough.
internal async redesign is permitted, but it must preserve typed DomainRequest
work carriers and keep service/kernel maintenance as separate audited classes.
mmap needs MmapCap and MemoryView consequences.
ioctl/uring commands need typed command authority.
```

Exec refinement adds:

```text
ordinary exec does not automatically change CapSched Domain.
successful exec increments ProgramGeneration for endpoint, async, mmap,
notification, and process-image-scoped authority.
the current task may continue only through same-Domain ExecContinuation with
live SchedContext and fresh ProgramGeneration.
surviving non-CLOEXEC fds are reachability, not post-exec authority; derive or
attenuate before endpoint effects.
CLOEXEC, old FrozenEndpointUse, old async use, old mmap/page-fault authority,
and old credential-derived endpoint authority must not leak across exec.
execfd is a derived endpoint handoff to an interpreter.
AT_EXECVE_CHECK is check-only and must not mutate generation.
```

Post-exec resource refinement adds:

```text
post-exec fd reachability is not endpoint authority.
regular files, sockets, anon fds, eventfd, timerfd, epoll, io_uring, and
execfd each require class-specific derivation or attenuation.
epoll readiness/watched endpoints, eventfd kernel signal, timerfd old timer
state, io_uring registered resources, and execfd handoff are high-risk.
```

Trace-only refinement adds:

```text
trace coverage can show path visibility and blind spots, not authority
derivation.
raw syscall tracing sees fd-level surfaces only.
sched exec tracepoints bracket ProgramGeneration change.
io_uring/workqueue/socket tracepoints expose useful effects but not CapSched
caller authority.
missing kprobe symbols, inline functions, and insufficient argument capture are
evidence gaps, not failures to ignore.
```

First post-exec resource QEMU trace result:

```text
validation/0040 completed with qemu_status=0 and workload_ret=0.
observed: CLOEXEC, regular file, O_PATH, socket, anonfd creation, timerfd.
partially observed: eventfd, epoll, io_uring.
not observed: execfd.
remaining gaps must be refined with more observation, not enforcement.
```

Workqueue redesign answer:

```text
Yes, production CapSched-H may need a deeply redesigned internal async
substrate.
No, internal-only trust is not sufficient.
The proof-visible boundary must still preserve caller Domain, epoch,
FrozenEndpointUse, BudgetTicket, service Domain, work generation, and merge or
per-invocation semantics.
```

Workqueue origin classification:

```text
PerInvocation: one caller/resource operation.
ExplicitMerge: coalesced pending work with explicit merge/accounting rules.
ServiceOnly: service maintenance, no caller endpoint effect.
KernelException: audited core liveness/infrastructure only.
InterruptDeferred: IRQ/BH/irq_work handoff, no slow authority discovery.
ReclaimRescue: WQ_MEM_RECLAIM liveness, not authority bypass.
TaskLocal: runs in target task, but task identity is not endpoint authority.
unknown_or_mixed: no enforcement; observe or instrument first.
```

First workqueue origin source inventory:

```text
validation/0042 completed as observation-only source inventory.
known source-inferred classifications: 10.
gap rows: 49.
largest unknown groups: drivers/net, drivers/gpu, drivers/scsi, drivers/usb,
sound/soc.
generic enforcement remains forbidden from this evidence alone.
```

First drivers/net workqueue inventory:

```text
validation/0043 decomposed drivers/net from one bulk unknown:
1440 callsites, 164 family/subfamily rows, 10 API rows, 40 hotspot rows.
largest groups: wireless/intel, ethernet/intel, ethernet/mellanox,
ethernet/marvell, wireless/ath.
candidate distribution:
  852 PerInvocation_or_ServiceOnly_or_ExplicitMerge
  553 ExplicitMerge_or_ServiceOnly
  20 InterruptDeferred
  15 InterruptDeferred_or_ServiceOnly
No net driver hook is justified yet; callback/container/effect mapping is next.
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

analysis/0033 + formal/0016 + validation/0028
  Task-local resumable-run lifecycle:
  fork raw-copy must be reset, initial child run state must be prepared before
  wake_up_new_task(), ordinary TASK_WAKING requires frozen local use, revoke
  clears frozen/selected/running use, and dead tasks retain no authority.

analysis/0034 + formal/0017 + validation/0029
  Workqueue/kthread_work carrier boundary:
  Domain-derived async worker execution needs a typed carrier with
  FrozenEndpointUse and BudgetTicket before queueing; generic worker authority
  is not caller authority, and pending carrier overwrite is rejected unless
  explicit merge semantics exist.

analysis/0045
  Workqueue internal redesign boundary:
  deep internal async redesign is accepted and likely necessary for
  production, but internal worker execution must not become ambient caller
  authority. DomainRequestWork needs typed carriers; MergedDomainBatchWork
  needs explicit merge/accounting/revocation semantics; ServiceMaintenanceWork
  and KernelCoreWork cannot perform caller-attributed endpoint effects without
  a separate DomainRequestWork.

analysis/0046 + validation/0041
  Workqueue origin taxonomy and observation plan:
  async work must be classified as PerInvocation, ExplicitMerge, ServiceOnly,
  KernelException, InterruptDeferred, ReclaimRescue, TaskLocal, or
  unknown_or_mixed before any generic workqueue enforcement hook. Tracepoints
  expose work pointer, callback, queue name, and kthread work events, but
  source correlation and queue-site stacks are required before making authority
  claims.

validation/0042
  Workqueue origin source inventory:
  source-inferred seed classifications were emitted for AIO fsync, AIO poll,
  blk zoned plug work, timerfd resume, io_uring exit, workqueue idle cull,
  irq_work, bio rescue, task_work fput, and VFIO virqfd injection. Bulk gaps
  remain explicit and large; no generic workqueue enforcement follows from
  this result.

analysis/0047 + validation/0043
  drivers/net workqueue origin map:
  drivers/net has been decomposed into family, API, hotspot, and candidate
  taxonomy inventories. It is a QueueLease/DeviceService hotspot, not a generic
  worker-authority problem. Network work mixes link maintenance, reset, stats,
  firmware, PTP, TX/RX cleanup, BH handoff, and queue control; endpoint effect
  and callback/container mapping are mandatory before enforcement.

analysis/0048
  usbnet representative workqueue source map:
  bh_work is initialized at usbnet.c:1781, callback usbnet_bh_work at
  usbnet.c:1644, and drains dev->done/refills RX/wakes TX through usbnet_bh.
  kevent is initialized at usbnet.c:1782, scheduled through flags bit merging
  in usbnet_defer_kevent at usbnet.c:472, and handles halt, RX memory, link,
  and rx-mode control-plane events. Both are merged device/service work, not
  per-caller work. Caller-derived Network EndpointCap or QueueLease authority
  belongs at submit/request boundaries such as usbnet_start_xmit, not in a
  single mutable BudgetTicket attached to shared work_struct callbacks.

analysis/0049
  e1000e representative QueueLease source map:
  e1000e shows that a real Ethernet data path is ring/IRQ/NAPI based, not
  workqueue based. .ndo_start_xmit -> e1000_xmit_frame maps SKBs into DMA,
  publishes descriptors, and writes the TX tail doorbell; this is the natural
  QueueLease submit boundary. e1000_clean_tx_irq, clean_rx, and e1000e_poll
  are completion/settlement paths. reset/watchdog/downshift/update_phy/
  print_hang/tx_hwtstamp work items are service/control or special timestamp
  settlement, not generic caller work carriers.

analysis/0050 + formal/0027 + validation/0044
  aggregate QueueLease settlement model:
  safe TLC passed with 16 generated states and 11 distinct states. Unsafe
  models produced expected counterexamples for doorbell without lease, submit
  without budget, DMA without IOMMU/ledger, completion without ledger/service
  budget, delivery after revoke, ledger overwrite, ambient completion authority,
  and foreign completion. Rule: submit authority belongs at
  QueueLease/DMA/doorbell boundaries; merged completion work settles against
  ledger/service state and must not use one overwritten caller ticket on a
  shared callback object.

analysis/0051 + validation/0045
  observation-only queue/descriptor ledger plan and readiness run:
  existing tracepoints cover useful outer netdev, NAPI, IRQ, SKB, IOMMU, and
  DMA events, but not descriptor publish, tail doorbell, submit-ledger
  correlation, completion settlement, or CapSched revoke/drop semantics. Deep
  internal redesign is allowed and likely required, but it is only the typed
  Linux substrate; proof-visible ledgers/carriers and monitor-owned QueueTag,
  IOMMU, epoch, and budget roots remain required for production claims. Missing
  tags are coverage gaps, not fail-open policy. The static readiness run found
  14 tracepoints and 25 e1000e source anchors with no missing rows, but recorded
  8 semantic gaps, including authority-root: all observed state is Linux-mutable
  and monitor_verified=false.

analysis/0052
  Intel ice modern NIC QueueLease source map:
  ice adds the modern datacenter NIC cases missing from e1000e: VSI/ring/
  q_vector/IRQ/NAPI binding, SKB TX, XDP frame and XDP_TX page-pool paths,
  AF_XDP zero-copy descriptor batches, page-pool/XSK memory, driver tracepoints,
  devlink rate/scheduler controls, SR-IOV/SF/representor forwarding, and
  service/reset/PTP/DPLL/eswitch work.
  Required class split:
    QueueBind, SubmitLedgerSKB, SubmitLedgerXDPFrame,
    SubmitLedgerXDPTxPagePool, SubmitLedgerAFXDP, DescriptorLedger,
    CompletionSettlement, QueueControl, RepresentorForward, ServiceWork.
  Rule:
    modern NIC authority is not netdev identity or a workqueue callback.
    Submit authority belongs before DMA map, descriptor publication, and
    doorbell; completion is aggregate settlement; devlink/representor/SF/VF
    paths are control-plane authority; service work must not be charged to the
    last submitter. Driver tracepoints improve observability but remain
    Linux-mutable and non-authoritative.

formal/0028 + validation/0046
  Modern NIC QueueLease class model:
  safe TLC passed with 1474 generated states, 701 distinct states, and depth 12.
  Unsafe configs produced expected counterexamples for:
    submit without QueueBind; submit without budget; SKB without IOMMU;
    XDP using an SKB ledger; AF_XDP without XSK ownership; representor
    forwarding without derivation; devlink via RunCap; service work charged to
    the last submitter; ambient completion authority; delivery after revoke.
  Rule:
    Queue-adjacent actions are not one authority. SKB, XDP frame, XDP_TX
    page-pool, AF_XDP, QueueControl, RepresentorForward, and ServiceWork must
    remain typed through submit, descriptor, completion, control, service, and
    revoke paths.

validation/0047
  ice modern NIC readiness checker:
  runner executed with 19 tracepoint rows, 0 missing; 40 source anchors, 0
  missing; 11 class readiness rows; 12 high-severity semantic gaps. All rows
  are observation_only=true, authority_claim=false, monitor_verified=false.
  Key result:
    ice has useful generic and driver tracepoints for SKB xmit, TX/RX clean,
    NAPI, IRQ, eswitch, DMA/IOMMU outer events, plus strong source anchors for
    XDP, AF_XDP, devlink, representor, and service work. None provides
    monitor QueueTag, Domain epoch, typed SubmitLedger/DescriptorLedger,
    QueueControlCap, lower QueueLease derivation, service BudgetTicket, or
    revoke epoch/quarantine outcome.
  Next modeling targets:
    XDP page-pool / AF_XDP XSK ownership.
    QueueControl / RepresentorForward derivation.

formal/0029 + validation/0048
  XDP and AF_XDP memory ownership model:
  safe TLC passed with 19 generated states, 13 distinct states, and depth 6.
  Unsafe configs produced expected counterexamples for:
    XDP_TX without page-pool ownership; AF_XDP without XSK/UMEM ownership;
    DMA without MemoryView; ambient AF_XDP descriptor use; cross-Domain DMA;
    completion without typed ledger; double memory return; return after revoke;
    submit without budget.
  Rule:
    XDP_TX page-pool reuse and AF_XDP zero-copy submit are memory ownership
    problems as much as queue submit problems. Queue reachability, SKB
    authority, generic XDP authority, or ambient driver state must not authorize
    DMA-capable packet memory.

formal/0030 + validation/0049
  QueueControl and RepresentorForward model:
  safe TLC passed with 7 generated states, 7 distinct states, and depth 3.
  Unsafe configs produced expected counterexamples for:
    devlink via RunCap; devlink via netdev reachability; representor without
    cap; representor without lower QueueLease; stale lower queue epoch;
    representor via netdev reachability; forwarding without service budget;
    control after revoke; forwarding after revoke.
  Rule:
    devlink/rate/scheduler/VF/SF/representor lifecycle authority is
    QueueControl. Representor transmit requires RepresentorForwardCap plus a
    live lower QueueLease. Neither is authorized by RunCap, plain netdev
    reachability, or Linux's ability to call dev_queue_xmit().

assurance/0002
  Modern NIC QueueLease assurance map:
  DEV-001 now has ten subclaims: QueueBind, typed submit classes,
  DescriptorLedger, DMA packet memory ownership, CompletionSettlement,
  QueueControl, RepresentorForward, ServiceWork/async provenance,
  RevokeSemantics, and Linux substrate compatibility.
  Gate result:
    model-supported authority-class separation; source-observed Intel ice
    anchors; observation-only readiness; no production protection evidence; no
    implementation approval.
  Rule:
    netdev/ring/q_vector/devlink/representor/tracepoint/workqueue state is
    Linux-mutable substrate, not modern NIC QueueLease authority. Do not collapse
    SKB, XDP, XDP_TX, AF_XDP, QueueControl, RepresentorForward, and ServiceWork
    into one capability.

formal/0031 + validation/0050
  Modern NIC queue revoke model:
  safe TLC passed with 7 generated states, 7 distinct states, and depth 5.
  Unsafe configs produced expected counterexamples for submit after revoke,
  completion after revoke, QueueControl after revoke, RepresentorForward after
  revoke, service work after revoke, ledger clear before DMA drain, reassignment
  before drain/quarantine, reassignment without IOMMU/IRQ invalidation, and
  quarantined delivery.
  Rule:
    revoke is not netdev down/reset. Revoke means block new submit, bump queue
    epoch, mask IRQ, drain or quarantine typed outstanding state, invalidate
    IOMMU/DMA reachability, block stale completion/control/representor/service
    effects, and only then reassign under a new epoch.

analysis/0053
  Intel ice revoke source map:
  useful anchors include ice_down, ice_vsi_dis_irq, ice_napi_disable_all,
  ring stop/clean, XSK clean, ice_qp_dis/ena, prepare_for_reset,
  service_task_stop, representor queue stop, and devlink reload. Verdict:
  source-observed only. Hard gaps remain for QueueTag/epoch, typed ledgers,
  monitor DMA/IOMMU/MemoryView receipt implementation, stale XSK/page-pool
  quarantine, VF IRQ ownership, RepresentorForward lower-QueueLease revoke,
  typed service-work carrier implementation, service/caller budget charging,
  reset/rebuild replay reauthorization, and old/new epoch reassignment proof.

analysis/0035 + formal/0018 + validation/0030
  Shared futex endpoint boundary:
  cross-Domain/shared futex wait needs FutexWaitCap, wake needs FutexWakeCap,
  wake does not grant target execution, requeue needs source and target endpoint
  rights, and cap failure after queueing is unsafe without no-lost-wake proof.

analysis/0036 + formal/0019 + validation/0031
  Priority donation authority boundary:
  PI/RT/ww_mutex donation is dependency-derived ordering authority, not RunCap,
  not SchedControlCap, not ThreadControlCap, and not free CPU budget. Proxy
  execution needs an explicit owner-budget or ProxyExecutionTicket policy.

analysis/0037 + formal/0020 + validation/0032
  Placement refresh authority boundary:
  selected CPU is a hint; p->cpus_ptr is mutable Linux placement input;
  FrozenRunUse.allowed_cpus plus fresh PlacementEpoch is the authority envelope.
  cpuset/hotplug fallback cannot expand CapSched authority.

analysis/0038 + formal/0021 + validation/0033
  Same-Domain fast path boundary:
  skipping monitor transition is safe only with local freshness proof for
  Domain epoch, MemoryView, root/SchedContext budget, side policy, and
  FrozenRunUse. NO_HZ capped execution needs monitor or unsuppressible timer
  coverage.

analysis/0039 + formal/0022 + validation/0034
  Budget split and overrun boundary:
  MonitorRootBudget is the production root, SchedContextBudget is required
  scheduler authority, and CFS/RT/DL/SCX runtime is compatibility/policy state
  only. Capped NO_HZ execution requires monitor or unsuppressible budget timer
  coverage, hrtick is not an exact root cap, remote NO_HZ tick is not root
  enforcement, and budget replenishment must refresh or invalidate epoch before
  selected/running use continues.

analysis/0040 + formal/0023 + validation/0035
  Class selected-state boundary:
  class pick is selection, not authority. Execution requires fresh FrozenRunUse
  and class-specific revalidation after put_prev/set_next, core cached pick
  consumption, deadline-server borrowing, sched_ext slice refill/infinite slice,
  proxy donor/owner resolution, and class state mutation.
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

Next project-wide sequence:

```text
1. Use analysis/0059 + formal/0038 as the VF mailbox carrier gate.
2. Map and model VF identity epoch and reset/reassignment handoff in ice.
3. Keep all NIC work analysis/model-only until monitor-backed roots and typed
   carriers exist.
4. Return to wider endpoint capability models and exec/resource inheritance
   before any behavior-changing L0 runnable admission slice.
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

Historical note: F1 data dependencies, same-Domain fast-path freshness,
root-vs-SchedContext budget split, and class selected-state behavior have now
been modeled. The current executable refinement is wider endpoint capability
semantics for fd/file/socket/resource operations. Do not use the v1 ledger as
solver input, enforcement evidence, or production security evidence. Do not use
the v2 ledger for hook selection yet.

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

Latest traceability state:

```text
N-108 completed:
  project source-map drift checker

checker:
  capsched-models/traceability/check-project-source-map-drift.sh

run:
  build/traceability-project-drift/20260630T234623Z

summary:
  15 machine-readable source-map/ledger artifacts scanned
  515 extracted anchors
  482 path/pattern-ok rows
  14 gap rows preserved as gaps
  1 symbol-missing row requiring semantic recheck
  1 descriptive pattern-missing row
  19 line-only semantic-recheck rows
  3 unsupported extractions preserved as unsupported
  recursive boolean safety-field scan with 0 violations
  content_source=git_HEAD_objects
  source_path_pattern_only=true
  semantic_validation=false

next:
  N-109 completed central overlay ledger normalization.
```

Do not treat project source-map drift `ok_rows` as semantic validation,
monitor verification, or production protection evidence.

Latest overlay ledger normalization:

```text
N-109 completed:
  build-project-overlay-ledger.sh

run:
  build/traceability-overlay/20260630T234640Z

summary:
  515 overlay rows
  482 ok source path/pattern rows
  14 preserved gap rows
  19 needs_semantic_recheck rows
  explicit match_kind and next_action fields
  semantic_validation=false
  n_series_rewrite=false

next:
  N-110 completed semantic recheck workflow for non-ok/non-gap rows.
```

Latest semantic recheck queue:

```text
N-110 completed:
  semantic-recheck-workflow-v1.md
  build-semantic-recheck-queue.sh

run:
  build/semantic-recheck/20260630T234640Z

summary:
  19 semantic recheck items
  14 gap-preservation items
  19 line-only anchors
  semantic_validation=false

next:
  N-111 completed first semantic recheck batch.
  N-112 line-only anchor recheck for remaining rows.
```
