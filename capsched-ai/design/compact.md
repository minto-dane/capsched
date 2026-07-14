# Compact Context

Updated: 2026-07-13

## Project

DomainLease-Linux, formerly CapSched-Linux during private modeling, aims to
introduce a capability-disciplined execution and resource lease model into
Linux scheduler foundations. The long-term target is a
datacenter OS substrate where process-, service-, container-, tenant-, and
cluster-cell-scale domains can receive isolation strength comparable to VM
boundaries at lower operational cost.

N-156 naming freeze:

```text
public umbrella:
  DomainLease-Linux
legacy alias:
  CapSched-Linux
scheduler core:
  SchedExecLease
Linux scaffold:
  sched_exec_lease / CONFIG_SCHED_EXEC_LEASE
monitor-backed architecture:
  DomainLease-H
legacy monitor name:
  HyperTag Monitor
```

Old claim IDs, evidence IDs, counterexample IDs, TLA modules, and historical
file paths remain stable for traceability.

Upstream Linux source has been fetched into sibling repository `linux/`.
The current local work branch is `capsched-linux-l0` at commit
`bd71af5daeae808ac948cbd12af2663151936f22` after P5A-R `0012`, an
experimental forced-pickable-progress draft. Patch queue recreation normalizes
commit metadata and now ends at replay commit
`1b572a3fad95b78f4ee89061ba441f77cf24e297`; local and replay trees are both
`25dbe4e04baa112ab9a872a897f67bec094df209`.

Validation/0186 passed only the synthetic ordinary-CFS test-only negative QEMU
workload. Validation/0187 keeps production acceptance blocked. Validation/0188
records the patch-queue replay repair. `0009` through `0012` remain
experimental; there is no accepted production runtime denial, complete CFS
deny-and-repick, runtime coverage, monitor call, budget charging, protection,
cost, deployment, or datacenter claim.
Latest fetched upstream/master is
`71dfdfb0209b43dfd6f494f84f5548e4cfd18cb5`.

Private GitHub publication uses a superproject:

```text
minto-dane/linux-cap:
  private superproject

minto-dane/capsched:
  private project-control/model/state repo

minto-dane/capsched-linux:
  private Linux patch queue, not a full Linux history mirror
```

ADR-0010 records this. The local full Linux tree stays under `linux/`; it is
recreated from `linux-patches/` when cloning the superproject.

Recreate the patch queue in a fresh or disposable target, not over the current
`./linux` tree unless intentionally normalizing commit IDs:

```sh
./linux-patches/scripts/recreate-capsched-linux-l0.sh ./linux-replay
```

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
  Direct-call workqueue adapter refinement. Analysis/0084 and formal/0060 model
  queue_work false, pending preservation, delayed retime, self-requeue, worker
  callback, cancel/flush, rescuer bypass, caller budget settlement, and
  release-vs-Linux-lifetime separation. Validation/0098 safe TLC passed with 16
  generated states, 15 distinct states, and depth 15; 17 unsafe configs
  produced expected counterexamples.

latest completed focused risk:
  Direct-call io_uring adapter refinement. Analysis/0085 and formal/0061 model
  SQE consumption, request freeze, resource generation snapshot, inline issue,
  io-wq punt, reissue, cancel, CQE, settlement, release, linked request, and
  uring_cmd endpoint hazards. Validation/0099 safe TLC passed with 26 generated
  states, 24 distinct states, and depth 15; 19 unsafe configs produced expected
  counterexamples.

latest completed focused risk:
  Combined async-adapter precondition gate. Implementation/0013 and formal/0062
  reconcile the broad N-126 async-carrier sketch with N-127 workqueue and
  N-128 io_uring refinements. Validation/0100 safe TLC passed with 10 generated
  states, 9 distinct states, and depth 9; 11 unsafe configs produced expected
  counterexamples. JSON gate check confirmed 10/10 rows complete and all 10
  safety flags false.

latest completed focused risk:
  Linux async-carrier patch scope plan. Implementation/0014 and formal/0063
  keep the next Linux-facing work at plan/no-behavior scope. Validation/0101
  safe TLC passed with 9 generated states, 8 distinct states, and depth 8; 12
  unsafe configs produced expected counterexamples. JSON plan check confirmed
  3 no-behavior allowed classes, 4 blocked classes, and 9/9 safety flags false.

latest completed focused risk:
  Linux upstream maintenance gate. Analysis/0086 and formal/0064 make N-131 a
  negative gate: no new Linux async-carrier patch is approved now, including
  no-behavior opaque names. Fetched upstream/master to 665159e246749, observed
  340 commits since L0 base, watched-path drift only in
  kernel/sched/cpufreq_schedutil.c, and clean merge-tree. Validation/0102 safe
  TLC passed with 8 generated states, 8 distinct states, and depth 8; 10 unsafe
  configs produced expected counterexamples. JSON gate check confirmed 12
  future patch gate requirements, 5 drift classes, 11 unsafe patterns, and
  12/12 safety flags false.

latest completed focused risk:
  Linux source-drift freshness gate. Analysis/0087, the source-drift runner,
  formal/0065, and validation/0103 make upstream-following reusable. Current
  runner result: 340 upstream commits since L0 base, one D1 non-stale watched
  change in kernel/sched/cpufreq_schedutil.c, zero model-refresh-required
  groups, clean merge-tree, model_freshness=fresh, no concrete consumer, and no
  Linux patch approval. Safe TLC passed with 8 generated states, 8 distinct
  states, and depth 8; 9 unsafe configs produced expected counterexamples. The
  first TLC attempt exposed missing watch-map/non-claim invariants; the final
  model rejects both.

latest completed focused risk:
  Linux source-map refresh target selection. Analysis/0088, formal/0066, and
  validation/0104 select scheduler_authority_core as the next source-only
  refresh target, not a Linux patch target. JSON check confirms 9 candidates,
  exactly 1 selected target, 20 current upstream anchors, and 9/9 safety flags
  false. Safe TLC passed with 6 generated states, 6 distinct states, and depth
  6; 7 unsafe configs produced expected counterexamples.

latest completed focused risk:
  Scheduler authority core source-only refresh. Analysis/0025, analysis/0026,
  analysis/0028, formal/0012 README, JSON refresh contract, and validation/0105
  now map current upstream scheduler anchors. JSON check: 25 anchors, 8
  refreshed rules, 4 updated artifacts, 12/12 safety flags false. formal/0012
  recheck: 126113 generated states, 17344 distinct states, depth 21, exit 0.

latest completed focused risk:
  Scheduler authority refinement gate. Analysis/0089, formal/0067, JSON gate,
  and validation/0106 compose TASK_WAKING freeze, donor/current/proxy budget,
  and selected-state settlement. Safe TLC: 18 generated states, 14 distinct,
  depth 7. Unsafe configs reject TASK_WAKING before freeze, current-only proxy
  budget, run after retry, and run without class settlement. JSON: 17 anchors,
  4 unsafe cases, 13/13 safety flags false.

latest completed focused risk:
  Runtime charge subject gate. Analysis/0090, formal/0068, JSON gate, and
  validation/0107 model NoUnspecifiedRuntimeCharge. Safe TLC: 79 generated
  states, 48 distinct, depth 4. Unsafe configs reject unspecified runtime
  charge, class runtime as root authority, proxy without ticket, remote-tick
  proxy authority, task_sched_runtime authority, and CFS proxy without
  donor/cgroup charge. JSON: 15 anchors, 6 unsafe cases, 12/12 safety flags
  false.

latest completed focused risk:
  Scheduler server-ticket gate. Analysis/0091, formal/0069, JSON gate, and
  validation/0108 model fair/ext/DL server-borrow tickets, RT bandwidth and SCX
  slice non-authority, fresh server epochs, live server state, lower task
  authority, and monitor root budget. Safe TLC: 39 generated states, 24
  distinct, depth 6. Unsafe configs reject server pick without ticket, server
  runtime as root authority, RT bandwidth as root, SCX slice as authority,
  stale server epoch, stopped server with live run, and lower task without
  authority. JSON: 17 anchors, 7 unsafe cases, 12/12 safety flags false.

latest completed focused risk:
  Runtime coverage gate. Analysis/0092, formal/0070, JSON gate, and
  validation/0109 define trace-only current/donor/proxy/server runtime coverage
  acceptance. Safe TLC: 49 generated states, 29 distinct, depth 6. Unsafe
  configs reject missing current, missing donor, missing proxy relation,
  missing server coverage, missing evidence class, sched_stat_runtime authority,
  remote tick proxy coverage, trace protection claim, server lifecycle-only
  coverage, and class runtime as root evidence. JSON: 33 anchors, 12 coverage
  requirements, 10 unsafe cases, 12/12 safety flags false.

latest completed focused risk:
  Monitor root budget timer gate. Analysis/0093, formal/0071, JSON gate, and
  validation/0110 model monitor-owned root CPU budget timer/deadline semantics.
  Linux hrtick, sched_tick, hrtimer, NO_HZ, and runtime charge reports remain
  non-authority. Safe TLC: 78 generated states, 37 distinct, depth 7. Unsafe
  configs reject no monitor timer, no root budget, Linux timer root, overrun
  after expiry, Linux charge root, unsealed activation, epoch-revoked run,
  run after monitor interrupt, NO_HZ stopping monitor timer, and protection
  claim. JSON: 25 anchors, 12 monitor event requirements, 10 unsafe cases,
  12/12 safety flags false.

latest completed focused risk:
  Server epoch relation gate. Analysis/0094, formal/0072, JSON gate, and
  validation/0111 model server-kind/server-epoch freshness across DL/fair/ext
  server start, stop, replenish, parameter update, attach, detach, swap, and
  CPU teardown. Safe TLC: 107 generated states, 32 distinct, depth 6. Unsafe
  configs reject stale ticket after replenish, ticket surviving server swap,
  server-kind mismatch after swap, ticket surviving stop, pick without fresh
  ticket, lower task without authority, Linux runtime authority, parameter
  update keeping a ticket, CPU teardown keeping a running ticket, and
  protection claim. JSON: 44 anchors, 13 epoch boundaries, 8 fresh ticket
  requirements, 10 unsafe cases, 13/13 safety flags false.

latest completed focused risk:
  Deadline CBS/GRUB compatibility gate. Analysis/0095, formal/0073, JSON gate,
  and validation/0112 model Linux SCHED_DEADLINE admission, CBS
  runtime/replenishment, GRUB reclaim, inactive timers, dynamic sched_getattr,
  and overrun notification as compatibility/observation, not authority. Safe
  TLC: 70 generated states, 27 distinct, depth 10. Unsafe configs reject
  admission minting run authority, CBS replenish minting run authority, GRUB
  minting monitor budget, DL runtime as monitor budget, inactive timer
  authority, dynamic sched_getattr authority, overrun notification as
  enforcement, run without DL admission, run while CBS-throttled, and
  protection claim. JSON: 48 anchors, 11 compatibility obligations, 9
  authority rejections, 10 unsafe cases, 14/14 safety flags false.

latest completed focused risk:
  F1 admission-freeze refresh gate. Analysis/0096, formal/0074, JSON gate, and
  validation/0113 refresh the wake publication boundary. RunCap/FrozenRunUse
  resolution must finish before TASK_WAKING, remote wake-list publication, or
  enqueue-visible state; after publication only cheap validation or fail-closed
  handling without lost wakeup is allowed. Safe TLC: 44 generated states, 24
  distinct, depth 7. Unsafe configs reject TASK_WAKING/wake_list/enqueue before
  freeze, running with incomplete frozen tuple, raw cap after publication, heavy
  post-publication lookup, late lost-wakeup denial, placement authority, current
  continuation mint, fork ambient authority, and protection claim. JSON: 20
  anchors, 11 frozen tuple requirements, 5 publication boundaries, 8 path
  classes, 15 authority rejections, 15 unsafe cases, 14/14 safety flags false.

latest completed focused risk:
  Scheduler authority integration gate. Analysis/0097, formal/0075, JSON gate,
  and validation/0114 compose F1 frozen wake publication, selected settlement,
  server tickets, deadline compatibility, and monitor root activation into one
  execution edge. Safe TLC: 59 generated states, 38 distinct, depth 6. Unsafe
  configs reject publication/run without required authority layers, Linux
  runtime/server runtime/deadline compatibility/placement as authority, raw cap
  and heavy lookup after publication, fail-closed running, and protection claim.
  JSON: 23 anchors, 7 integrated subjects, 12 execution requirements, 17
  authority rejections, 17 unsafe cases, 15/15 safety flags false.

next focused risk:
  Monitor timer architecture substrate comparison, and placement/affinity/hotplug
  integration refresh after the N-143 integration gate.

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
  build/traceability-project-drift/20260630T235533Z

summary:
  15 machine-readable source-map/ledger artifacts scanned
  515 extracted anchors
  501 path/pattern/symbol-ok rows
  14 gap rows preserved as gaps
  0 symbol-missing rows
  0 descriptive pattern-missing rows
  0 line-only semantic-recheck rows
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
  build/traceability-overlay/20260630T235558Z

summary:
  515 overlay rows
  501 ok source path/pattern/symbol rows
  14 preserved gap rows
  0 needs_semantic_recheck rows
  explicit match_kind and next_action fields
  semantic_validation=false
  n_series_rewrite=false

next:
  N-110 completed semantic recheck workflow for non-ok/non-gap rows.
  N-112 completed the active line-only recheck.
```

Latest semantic recheck queue:

```text
N-110 completed:
  semantic-recheck-workflow-v1.md
  build-semantic-recheck-queue.sh

run:
  build/semantic-recheck/20260630T235623Z

summary:
  0 semantic recheck items
  14 gap-preservation items
  0 line-only anchors
  semantic_validation=false

next:
  N-111 completed first semantic recheck batch.
  N-112 completed line-only anchor recheck.
  N-113 completed preserved gap/plan classification.
  N-114 completed direct-call gap-closure design/model.
  N-115 completed the implementation-facing closure gate.
  N-116 completed monitor-owned receipt schema/model.
  N-117 completed receipt-consumer source mapping.
  N-118 should model receipt-consumer placement/exclusion constraints.
```

Latest project gap classification:

```text
N-113 completed:
  classify-project-gaps.sh

run:
  build/traceability-gap-classification/20260701T000823Z

summary:
  14 preserved gap rows
  7 semantic direct-call gap groups
  5 high-severity future Linux/internal anchor groups
  1 test-only failure-injection group
  1 trace-only observation group
  0 unknown gaps
  semantic_validation=false
  implementation_approval=false

next:
  N-114 completed direct-call gap-closure design/model.
```

Latest direct-call gap closure model:

```text
N-114 completed:
  analysis/0078
  formal/0055 DirectCallGapClosure
  validation/0086

safe TLC:
  6 generated states
  5 distinct states
  depth 5

unsafe counterexamples:
  12 expected violations covering pre-closure stubs, Linux-as-authority
  shortcuts, trace/test overclaims, ABI/behavior approval, monitor verification,
  and protection claims.

next:
  N-115 completed implementation-facing closure gate.
```

Latest direct-call implementation gate:

```text
N-115 completed:
  implementation/0009
  implementation/direct-call-gap-closure-gate-v1.json

gate rows:
  DCGATE-004..008 high-severity direct-call closure rows
  DCGATE-009 test-only side gate
  DCGATE-010 trace-only side gate

next:
  N-116 completed monitor-owned receipt schema/model.
```

Latest direct-call receipt schema:

```text
N-116 completed:
  analysis/0079
  formal/0056 DirectCallReceiptSchema
  validation/0087

safe TLC:
  10 generated states
  9 distinct states
  depth 9

next:
  N-117 completed receipt-consumer source mapping.
```

Latest direct-call receipt-consumer source map:

```text
N-117 completed:
  analysis/0080
  direct-call-receipt-consumer-source-map-v1.json
  validation/0088

latest drift:
  542 anchors
  521 ok rows
  21 gap rows
  0 safety violations

next:
  N-118 completed receipt-consumer placement model.
```

Latest direct-call receipt-consumer placement model:

```text
N-118 completed:
  formal/0057
  validation/0089

safe TLC:
  10 generated states
  9 distinct states

next:
  N-119 completed implementation-facing no-patch placement gate.
```

Latest direct-call receipt-consumer placement gate:

```text
N-119 completed:
  implementation/0010
  direct-call-receipt-consumer-placement-gate-v1.json
  validation/0090

gate rows:
  provenance
  hot path
  policy/lifecycle
  async exclusion
  future gaps
  revoke/shadow
  evidence split

next:
  N-120 typed async carrier model.
```

Latest direct-call async carrier model:

```text
N-120 completed:
  formal/0058
  validation/0091

critical fix before commit:
  subagent found pending coalescing and revoke handling were too flag-like.
  final model tracks caller/ticket/receipt/generation identity and rejects
  stale revoked pending carriers before worker execution.

safe TLC:
  15 generated states
  13 distinct states
  depth 12

unsafe:
  15 expected counterexamples, including PendingCarrierPreserved and
  NoStaleCarrierExecution.

next:
  N-121 no-patch async-carrier implementation gate.
```

Latest direct-call async-carrier gate:

```text
N-121 completed:
  implementation/0011
  direct-call-async-carrier-gate-v1.json
  validation/0092

rows:
  typed carrier identity
  pending coalescing preservation
  caller BudgetTicket ownership
  service/caller intersection
  monitor receipt provenance
  revoke/stale-carrier rejection
  workqueue boundary
  io_uring boundary
  evidence split

non-claim:
  still no Linux code, ABI approval, runtime coverage, behavior change,
  monitor verification, or production protection.

next:
  N-122 workqueue/io_uring source maps before code.
```

Latest direct-call async source maps:

```text
N-122 completed:
  analysis/0081
  workqueue source map: 19 anchors
  io_uring source map: 18 anchors
  validation/0093

drift:
  579 anchors
  558 ok
  21 preserved gaps
  0 semantic recheck
  0 safety violations

key rule:
  workqueue generic state is not authority.
  io_uring request/resource state is not authority unless future typed carrier
  fields make it so.

next:
  N-123 carrier lifetime table before code.
```

Latest direct-call async carrier lifetime table:

```text
N-123 completed:
  analysis/0082
  lifetime-table-v1
  validation/0094

shape:
  22 rows
  workqueue: 11 stages
  io_uring: 11 stages

validated:
  all rows have source refs, forbidden collapses, patch preconditions, and
  non-claim flags.

rule:
  Linux queue/worker/cancel/retry/completion/free state is not authority.

N-124 completed:
  ADR-0009
  analysis/0083
  api-direction-v1
  validation/0095

decision:
  shared internal capsched_async_carrier semantic core
  plus separate workqueue and io_uring adapters.

core:
  CapSched authority state only:
    frozen caller authority
    caller BudgetTicket
    monitor receipt reference or shadow
    generation/epoch/revoke state
    service/resource binding
    settlement/release state

adapters:
  workqueue covers queue_work false, delayed work, self-requeue, cancel/flush,
  callback entry, and free.
  io_uring covers SQE/request/resource storage, fixed resources, io-wq punt,
  links, REQ_F_REISSUE, cancel, CQE, ref release, and free.

still not:
  Linux implementation, ABI, runtime coverage, monitor verification,
  behavior change, or production protection.

N-125 completed:
  implementation/0012
  api-sketch-v1
  validation/0096

sketch:
  internal opaque capsched_async_carrier core
  ops: freeze, bind, validate, revoke_check, settle, release
  single-assignment frozen/bind tuples
  core owns only CapSched refs; adapters own Linux lifetime.
  settlement is exactly once.
  workqueue/io_uring remain separate adapters.

validated shape:
  8 authority fields
  18 adapter steps
  15 invariants
  18 forbidden authority sources
  5 required future models
  all safety flags false

N-126 completed:
  formal/0059
  validation/0097

TLC:
  safe passed: 25 generated, 23 distinct, depth 12.
  14 unsafe configs produced expected counterexamples.

unsafe themes:
  side effect before validate, immutable overwrite, second-caller leak, pending
  overwrite, double settlement, release dropping Linux refs, CQE settlement
  proof, reissue refresh, bad authority intersection, Linux object authority,
  ABI/behavior/monitor/protection overclaims.

still not:
  Linux implementation, ABI, runtime coverage, monitor verification,
  behavior change, or production protection.

next:
  N-127 split io_uring/workqueue refinement models.

N-144 completed:
  analysis/0098
  monitor-timer-architecture-substrate-v1.json
  formal/0076
  validation/0115

purpose:
  refine monitor root budget timer into architecture-substrate requirements.
  x86 VMX-root and arm64 EL2 are candidate substrate classes only when the
  Monitor owns timer/deadline state, root budget ledger, expiry trap, token,
  epoch, MemoryView, CPU id, activation generation, and receipt minting.

safe TLC:
  11 generated states
  9 distinct states
  depth 5

unsafe configs:
  24 expected counterexamples reject missing/wrong monitor substrate, Linux
  hrtimer/sched_tick roots, KVM VMX guest timer and hrtimer fallback roots,
  arm64 KVM arch timer and soft hrtimer roots, pKVM stage-2 as timer, pKVM
  plus Linux timer, missing token/epoch/MemoryView/CPU/generation/budget
  binding, Linux/KVM/guest deadline retiming, expiry still running, NO_HZ
  control, unbounded overrun, Linux-minted receipt, receipt without monitor
  expiry, and protection overclaims.

assurance:
  E-MONITOR-TIMER-ARCH-001 supports ACT-001 and BUDGET-001 only as model
  evidence.

still not:
  Linux implementation, scheduler hook, budget hook, ABI approval, monitor
  implementation, x86 VMX-root implementation, arm64 EL2 implementation, KVM
  or pKVM modification, runtime coverage, behavior change, monitor
  verification, or production protection.

next:
  placement/affinity/hotplug integration refresh.
```

N-145 completed:

```text
artifacts:
  analysis/0099
  placement-affinity-hotplug-integration-gate-v1.json
  formal/0077
  validation/0116

purpose:
  integrate Linux placement, affinity, cpuset, hotplug, class selection,
  sched_ext, core scheduling, and Linux exception paths with the scheduler
  authority gate.

critical correction:
  A first boolean draft was rejected by subagent review as too weak.
  The accepted model uses CPU sets and derives:

    frozenAllowed =
      capEnvelope ∩ linuxMask ∩ activeMask ∩ monitorCpuSet ∩ memoryViewCpuSet

  Run authority is separated from placement and requires Domain/SchedContext/
  RunCap grant provenance.

safe TLC:
  81 generated states
  39 distinct states
  depth 7

unsafe:
  20 expected counterexamples.
  Rejected authority substitutes include selected CPU, class selection,
  sched_ext selection/dispatch, core scheduling, sched_exec, cpuset fallback,
  force affinity, fallback rq, migrate-disable, per-cpu kthread exception, and
  protection overclaims.

assurance:
  E-SCHED-PLACEMENT-INTEGRATION-001 supports ACT-001, EXEC-001, and COMPAT-001
  as model evidence only.

still not:
  Linux implementation, hook approval, ABI approval, runtime coverage, monitor
  implementation, monitor verification, behavior change, or production
  protection.

next:
  runtime coverage execution planning or final run/move revalidation hook
  placement analysis.
```

N-146 completed:

```text
artifacts:
  analysis/0100
  final-run-move-revalidation-hook-placement-gate-v1.json
  formal/0078
  validation/0117

purpose:
  make final run/move authority a tuple-consumption boundary.

rule:
  CommitRun consumes a fresh Run tuple.
  CommitMove consumes a fresh Move tuple.
  A move tuple cannot run a task.
  A run tuple cannot move a task.
  The consumed tuple must match current task generation, Domain epoch,
  SchedContext epoch, RunCap epoch, move sequence, core sequence, sched_ext
  sequence, edge kind, CPU, fresh allowed set, and no-pending-migration state.

safe TLC:
  750 generated states
  455 distinct states
  depth 21

unsafe:
  39 expected counterexamples.
  Rejected authority substitutes include pick_next_task, set_task_cpu,
  move_queued_task, attach/detach, fair/RT/DL balancing, sched_ext DSQ
  custody, core cached picks, proxy migration, hotplug push, migration stop,
  Linux exceptions for ordinary Domain tasks, hook-after-rq->curr placement,
  and non-claim overreach.

implementation pressure:
  conceptual run anchor: kernel/sched/core.c:7188 before rq->curr
  conceptual move anchor: kernel/sched/core.c:2546 move_queued_task()
  no hook is approved yet; veto/retry semantics remain open.

assurance:
  E-SCHED-RUN-MOVE-REVALIDATION-001 supports ACT-001, EXEC-001, and COMPAT-001
  as model evidence only.

still not:
  Linux implementation, hook approval, ABI approval, runtime coverage, monitor
  implementation, monitor verification, budget enforcement evidence, behavior
  change, or production protection.
```

N-147 completed:

```text
artifacts:
  analysis/0101
  final-deny-retry-ineligibility-gate-v1.json
  formal/0079
  validation/0118

purpose:
  final run validation denial must be explicit, bounded, progress-making, and
  fail-closed.

rule:
  A denied candidate cannot run.
  A denied candidate cannot be immediately retried in the same retry epoch.
  Denial must happen before rq->curr publication.
  Denial requires ineligibility plus scheduler class-state neutralization.
  Retry must advance a count and be bounded.
  Fail-closed is valid only with no eligible candidate.
  A successful retry still needs a fresh tuple.

safe TLC:
  11 generated states
  9 distinct states
  depth 6

unsafe:
  17 expected counterexamples.
  Rejected authority substitutes include class state, RETRY_TASK, idle
  fallback, sched_ext fallback, core cached pick, silent drop, and non-claim
  overreach.

assurance:
  E-SCHED-DENY-RETRY-001 supports EXEC-001 and COMPAT-001 only as model
  evidence.

still not:
  Linux implementation, hook approval, retry implementation, class-state
  rollback approval, runtime coverage, ABI, monitor verification, behavior
  change, budget enforcement evidence, or production protection.
```

N-148 completed:

```text
artifacts:
  analysis/0102
  task-frozen-run-lifetime-locking-gate-v1.json
  formal/0080
  validation/0119

purpose:
  fix task identity lifetime and locking semantics for FrozenRunUse, denied
  candidates, and future move validation records.

rule:
  task identity consumption requires live task, fresh generation, no migration,
  unreleased frozen record, and stabilization by a task ref or scheduler locked
  context. Raw task_struct pointer, RCU visibility, and rq->curr publication
  are not authority.

safe TLC:
  20 generated states
  12 distinct states
  depth 6

unsafe:
  16 expected counterexamples for run after free, missing stable lifetime,
  RCU-only/raw-pointer authority, run while migrating, stale generation, use
  after release, premature release, double release, ref/lock leak, move without
  rq lock, retry without stable candidate lifetime, ignored exit invalidation,
  and non-claim overreach.

assurance:
  E-SCHED-LIFETIME-LOCKING-001 supports EXEC-001 and COMPAT-001 only.

still not:
  Linux implementation, hook approval, task-field/storage-layout/refcount/
  locking-protocol approval, runtime coverage, ABI, monitor verification,
  behavior change, budget enforcement evidence, or production protection.
```

N-149 completed:

```text
artifacts:
  analysis/0103
  lifecycle-identity-propagation-integration-gate-v1.json
  formal/0081
  validation/0120

purpose:
  integrate fork/clone, exec, and exit identity propagation with scheduler
  runnable authority.

rule:
  child run requires SpawnCap-derived fresh identity before wake publication;
  RunCap/FrozenRunUse/RunToken are not inherited; new Domain spawn needs a
  monitor token; successful exec requires ExecContinuation; check-only exec is
  non-mutating; old FrozenRunUse is not reused after exec; exit invalidates
  stale task authority. PID/TGID, clone flags, sched_exec placement, release
  state, RCU-visible dead tasks, and traces are not authority.

safe TLC:
  19 generated states
  13 distinct states
  depth 4

unsafe:
  20 expected counterexamples for missing SpawnCap/fresh identity,
  ambient inheritance, wake-before-identity, new Domain without token, clone
  flags authority, exec Domain change, exec run without continuation,
  check-only mutation, old FrozenRunUse after exec, run after exit, PID/TGID
  reuse, release authority, and overclaims.

assurance:
  E-SCHED-LIFECYCLE-IDENTITY-001 supports EXEC-001 and COMPAT-001 only.
  Existing exec/post-exec models are registered as E-EXEC-GEN-001 and
  E-POST-EXEC-RESOURCE-001.

still not:
  Linux implementation, hook approval, task-field approval, runtime coverage,
  ABI, monitor verification, behavior change, budget evidence, or protection.
```

N-150 completed:

```text
artifacts:
  analysis/0104
  exit-revoke-pending-authority-drain-gate-v1.json
  formal/0082
  validation/0121

purpose:
  define global exit/revoke completion across scheduler, async, endpoint,
  monitor admission, device, budget, server, root execution, and unknown
  carrier families.

rule:
  completion requires old-epoch embargo, complete pending-authority inventory,
  drain/reject/quarantine/settle for every known carrier family, derived
  receipt/shadow revoke, exact-once budget/root settlement, and fail-closed
  unknown carriers. Linux cancel/flush/pending clear/task_work_add failure/
  io_uring cancel/free/CQE/timer delete/rcu_barrier/audit/trace/timeout/PID
  reuse/RCU visibility are not drain receipts or authority.

safe TLC:
  13 generated states
  11 distinct states
  depth 10

unsafe:
  28 expected counterexamples for remote wake or queued FrozenRunUse surviving
  completion, early release, PID reuse, pending workqueue/io_uring/endpoint/
  direct-call/ring/device carriers, stale derived receipts, premature budget
  refund, surviving server ticket or root RunToken, audit/Linux cleanup as
  drain proof, unknown carrier default drain, budget leak/double settlement,
  RCU visibility authority, and overclaims.

assurance:
  E-SCHED-EXIT-REVOKE-DRAIN-001 supports EXEC, BUDGET, ENDP, ASYNC, DEV,
  REVOKE, and COMPAT only as model evidence.

still not:
  Linux implementation, hook approval, carrier structs, runtime coverage, ABI,
  monitor verification, behavior change, or production protection.
```

N-151 completed:

```text
artifacts:
  analysis/0105
  model-completeness-ledger-gate-v1.json
  formal/0083
  validation/0122

purpose:
  audit whether the model-only goal can be marked complete.

result:
  not complete yet.

current audit:
  11 TOP children model-supported:
    ACT, EXEC, BUDGET, ENDP, ASYNC, MEM, TLB, PCACHE, DEV, REVOKE, CLUSTER.
  1 TOP child prototype/compat-classified:
    COMPAT.
  3 open model blockers:
    TCB, SIDE, EVAL.

safe TLC:
  5 generated states
  3 distinct states
  depth 2

unsafe:
  7 expected counterexamples for completion with TCB/SIDE/EVAL open, missing
  compatibility classification, ignored blocker, production claim from
  model-only evidence, and prototype as protection.

next:
  model TCB-001, SIDE-001, and EVAL-001 before marking the goal complete.
```

N-152 completed:

```text
artifacts:
  analysis/0106
  tcb-boundary-gate-v1.json
  formal/0084
  validation/0123

purpose:
  close TCB-001 at model level.

rule:
  Monitor owns only typed/sealed roots and transitions. Drivers, parsers,
  policy engines, Linux scheduler/cgroup/namespace/LSM policy, and Linux
  mutable metadata are not Monitor TCB roots. Service Domains require typed
  endpoints, least authority, caller-frozen authority intersection, and no raw
  handle exposure. A TCB budget and VM/VMM comparison envelope are required.

safe TLC:
  3 generated states
  2 distinct states
  depth 2

unsafe:
  11 expected counterexamples for unbounded/untyped Monitor, monitor driver/
  parser/policy inclusion, Linux trusted root, service ambient authority, raw
  handle exposure, missing TCB budget/comparison envelope, and overclaims.

assurance:
  E-TCB-BOUNDARY-001 supports TCB-001 only as model evidence.

remaining model blockers:
  SIDE-001
  EVAL-001
```

N-153 completed:

```text
artifacts:
  analysis/0107
  side-channel-cotenancy-policy-gate-v1.json
  formal/0085
  validation/0124

purpose:
  close SIDE-001 at model level.

rule:
  co-tenancy needs known policy, leakage classification, and explicit policy
  for SMT/core/cache/NUMA/device queue/cluster sharing. Performance optimizer
  cannot override hard Monitor-backed boundaries. Scheduler must respect side
  policy. Side policy is not an authority root.

safe TLC:
  3 generated states
  2 distinct states
  depth 2

unsafe:
  15 expected counterexamples.

assurance:
  E-SIDE-COTENANCY-001 supports SIDE-001 only as model evidence.

remaining model blocker:
  EVAL-001
```

N-154 completed:

```text
artifacts:
  analysis/0108
  evaluation-contract-gate-v1.json
  formal/0086
  validation/0125

purpose:
  close EVAL-001 at model level.

rule:
  future protection/cost claims require an explicit security and cost
  evaluation contract: exploit-containment, cross-Domain memory/DMA/control,
  monitor escape, KVM/Firecracker/container baselines, workload envelope,
  throughput, tail latency, density, operational cost, pass/fail criteria, and
  negative-result policy. Microbench-only evaluation is rejected.

safe TLC:
  3 generated states
  2 distinct states
  depth 2

unsafe:
  20 expected counterexamples.

assurance:
  E-EVAL-CONTRACT-001 supports EVAL-001 only as model evidence.

remaining model blockers:
  none known from N-151; run final completeness ledger next.
```

N-155 completed:

```text
artifacts:
  analysis/0109
  final-model-completeness-ledger-v1.json
  formal/0087
  validation/0126

purpose:
  final audit for the current model-only goal.

result:
  model-only goal complete.
  production protection not claimed.

current audit:
  14 TOP children model-supported:
    ACT, EXEC, BUDGET, ENDP, ASYNC, MEM, TLB, PCACHE, DEV, REVOKE, CLUSTER,
    TCB, SIDE, EVAL.
  1 TOP child prototype/compatibility-classified:
    COMPAT.
  0 model-only blockers remain open.

safe TLC:
  3 generated states
  2 distinct states
  depth 2

unsafe:
  14 expected counterexamples.

assurance:
  E-FINAL-MODEL-COMPLETION-001 supports only model-only goal completion.

still not:
  Linux implementation, runtime coverage, monitor verification, production
  protection, cost efficiency, or deployment readiness.
```

N-156 completed:

```text
artifacts:
  analysis/0110
  terminology-freeze-rename-risk-review-v1.json
  traceability/0002
  implementation/0015
  validation/0127
  validation/0128

decision:
  public vocabulary is DomainLease-Linux / DomainLease-H / SchedExecLease /
  sched_exec_lease.

legacy:
  CapSched-Linux, CapSched-H, RunCap, FrozenRunUse, SchedContext, DomainTag,
  and HyperTag Monitor remain aliases for historical evidence.

linux rename target:
  CONFIG_SCHED_EXEC_LEASE
  include/linux/sched_exec_lease.h
  kernel/sched/exec_lease.c

linux result:
  commit 3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c
  patch queue 0003-sched-exec-lease-Rename-inert-scheduler-lease-scaffold.patch

validation:
  targeted scheduler-subtree build passed.
  off state: SCHED_EXEC_LEASE = undef, no exec_lease.o.
  on state: SCHED_EXEC_LEASE = y, exec_lease.o built.

still not:
  full vmlinux validation for this rename, behavior change, ABI, monitor
  implementation, runtime coverage, production protection, or cost evidence.
```

N-157 completed:

```text
artifact:
  validation/0129

result:
  patch queue series 0001..0003 fresh replay reproduces work_commit
  3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c.

replay tree:
  build/replay/n157-capsched-linux-l0-20260702T024618Z

source drift:
  build/source-drift/linux-source-drift-gate/20260702T024618Z
  model_freshness=fresh
  merge_tree_clean=true

targeted replay build:
  build/logs/sched-exec-lease-rename-build-20260702T024654Z.log
  off: SCHED_EXEC_LEASE undef, no exec_lease.o
  on: SCHED_EXEC_LEASE y, exec_lease.o built

still not:
  full vmlinux, QEMU boot, runtime coverage, behavior change, ABI, monitor
  verification, production protection, or cost evidence.
```

N-158 in progress:

```text
artifacts:
  analysis/0111
  implementation/0016
  implementation/0017
  sched-exec-lease-l0-implementation-readiness-gate-v1.json

verdict:
  ready for implementation design and no-behavior preparation patches.
  behavior-changing runtime enforcement remains unapproved.

blocked until later:
  runtime denial
  public ABI or public tracepoint ABI
  monitor ABI
  exported symbols
  endpoint/device/memory authority
  protection or cost-efficiency claims

next safe patch classes:
  no-behavior internal helper skeleton
  no-behavior lifecycle identity skeleton
  no-behavior scheduler touch-point static inline hooks/comments
  KUnit/build-only validation without ABI
```

N-159 in progress:

```text
full vmlinux:
  validation/0130 records a pass for CONFIG_SCHED_EXEC_LEASE=off and
  CONFIG_SCHED_EXEC_LEASE=on.

  off:
    SCHED_EXEC_LEASE=undef
    vmlinux present
    exec_lease.o absent

  on:
    SCHED_EXEC_LEASE=y
    vmlinux present
    exec_lease.o present

QEMU:
  systemd unit capsched-n159-qemu-after-full-build-20260702T0320Z.service
  completed. validation/0131 records off/on QEMU boot/workload smoke pass.
  off artifacts are under
  build/qemu/sched-exec-lease-boot-smoke/20260702T031917Z-off/.
  on artifacts are under
  build/qemu/sched-exec-lease-boot-smoke/20260702T033357Z-on/.
  on CONFIG_SCHED_EXEC_LEASE=y, qemu_status=0, WORKLOAD_RET 0.
  Hook coverage remains incomplete: pick_next_task and __schedule were missing
  from function/kprobe observation.

still not:
  runtime coverage, hook approval, behavior change, ABI approval, monitor
  verification, production protection, or cost evidence.
```

N-160 implementation blueprint:

```text
artifacts:
  implementation/0018-sched-exec-lease-l0-p1-p4-blueprint.md
  implementation/sched-exec-lease-l0-p1-p4-blueprint-v1.json

status:
  P1-P4 no-denial implementation blueprint drafted.
  P5 runtime denial remains blocked.

P1:
  internal object skeleton only.

P2:
  task lifecycle identity shadow only with reset after dup_task_struct raw copy,
  child identity in copy_process before wake_up_new_task, sched_exec placement
  only, begin_new_exec point-of-no-return staging, and do_exit/PF_EXITING
  invalidation.

P3:
  placement-only scheduler touch points.

P4:
  allow-all final revalidation skeleton. Preferred hook classes are final run
  at __schedule keep_resched before rq->curr publication, queued moves before
  move_queued_task()/move_queued_task_locked() mutation, and fair detach_task()
  before direct deactivate_task()/set_task_cpu().

hard P5 gates:
  sched_ext support/disable/fail-closed, core cached-pick freshness, proxy
  donor/current/executor authority and budget tests, kthread/workqueue
  classification, fork/exec/exit validation, negative denial tests, and claim
  ledger overclaim guard.
```

N-161 P1 patch plan:

```text
artifacts:
  implementation/0019-sched-exec-lease-p1-no-behavior-patch-plan.md
  implementation/sched-exec-lease-p1-no-behavior-patch-plan-v1.json

status:
  draft patch plan, implementation not applied.

allowed P1 surface:
  include/linux/sched_exec_lease.h
  kernel/sched/exec_lease.c

forbidden in P1:
  task_struct fields, rq fields, scheduler hooks, lifecycle hooks, allocation,
  runtime denial, budget charging, generation mutation, ABI, monitor calls,
  exported symbols, tracepoints, and behavior changes.
```

N-162 P1 no-behavior implementation:

```text
artifacts:
  implementation/0020-sched-exec-lease-p1-no-behavior-implementation.md
  implementation/sched-exec-lease-p1-no-behavior-implementation-v1.json
  validation/0132-sched-exec-lease-p1-full-build.md

linux:
  commit 95b8c509043d755ad77801315beec94c09059777
  subject sched/exec_lease: Add private no-behavior object vocabulary
  changed kernel/sched/exec_lease.c only

patch queue:
  added 0004-sched-exec-lease-Add-private-no-behavior-object-vocabulary.patch
  work_commit updated to 95b8c509043d755ad77801315beec94c09059777
  replay passed to exact final HEAD

validation:
  full vmlinux off/on passed with BUILD_TAG=p1-n162-current.
  off: SCHED_EXEC_LEASE=undef, vmlinux present, exec_lease.o absent.
  on: SCHED_EXEC_LEASE=y, vmlinux present, exec_lease.o present.
  log: build/logs/sched-exec-lease-full-build-20260702T035916Z.log

still not:
  behavior change, runtime denial, hook approval, ABI, monitor verification,
  runtime coverage, production protection, or cost evidence.
```

N-163 P2 task identity shadow plan:

```text
artifacts:
  implementation/0021-sched-exec-lease-p2-task-identity-shadow-plan.md
  implementation/sched-exec-lease-p2-task-identity-shadow-plan-v1.json

status:
  draft plan, implementation not applied.

allowed surface:
  include/linux/sched.h
  include/linux/sched_exec_lease.h
  kernel/fork.c
  fs/exec.c
  kernel/exit.c
  kernel/sched/exec_lease.c

hard lifecycle requirements:
  dup_task_struct: sanitize after arch_dup_task_struct raw copy.
  copy_process: prepare child identity before publication/wake paths.
  create_io_thread: covered because it returns inactive copy_process child.
  sched_exec: placement-only, no identity mutation.
  begin_new_exec: only point-of-no-return exec shadow mutation.
  do_exit: invalidate immediately after exit_signals/PF_EXITING.
  release_task/free_task: storage cleanup only, not revoke proof.

still not:
  behavior change, scheduler hooks, runtime denial, ABI, monitor call,
  runtime coverage, or protection claim.
```

N-164 P2 task identity shadow implementation:

```text
artifacts:
  implementation/0022-sched-exec-lease-p2-task-identity-shadow-implementation.md
  implementation/sched-exec-lease-p2-task-identity-shadow-implementation-v1.json
  validation/0133-sched-exec-lease-p2-full-build-and-layout.md
  validation/0134-sched-exec-lease-p2-qemu-boot-smoke.md
  validation/run-sched-exec-lease-task-layout-probe.sh

linux:
  commit a0f2676adda634391983e74f29fcba577a9c919e
  subject sched/exec_lease: Add task identity shadow

changed source:
  include/linux/sched.h
  include/linux/sched_exec_lease.h
  kernel/fork.c
  fs/exec.c
  kernel/exit.c
  kernel/sched/exec_lease.c

patch queue:
  added 0005-sched-exec-lease-Add-task-identity-shadow.patch
  work_commit updated to a0f2676adda634391983e74f29fcba577a9c919e
  replay passed to exact final HEAD

validation:
  full vmlinux off/on passed with BUILD_TAG=p2-n164-current.
  task layout probe passed:
    off: sched_exec field absent, task_struct size 0xcc0.
    on: sched_exec field size 0x28, offset+1 0x591, task_struct size 0xd00.
  QEMU off/on passed:
    off: qemu_status=0, WORKLOAD_RET 0.
    on: CONFIG_SCHED_EXEC_LEASE=y, qemu_status=0, WORKLOAD_RET 0.
    fork/exec/exit counts: 101/101/101 in both runs.

coverage limit:
  pick_next_task and __schedule remain function-missing in the smoke; the
  dlease_pick_next_task kprobe failed/missing. This is recorded as a P3/P4/P5
  design/validation issue, not a P2 blocker.

still not:
  scheduler hook approval, runtime denial, behavior change, ABI, monitor call,
  budget charging, runtime coverage, production protection, or cost evidence.

N-165/N-166 design-readiness audit:

```text
artifacts:
  analysis/0113-implementation-ready-completion-audit.md
  analysis/implementation-ready-completion-audit-v1.json
  analysis/0114-sched-ext-core-proxy-coverage-boundary.md
  analysis/sched-ext-core-proxy-coverage-boundary-v1.json

verdict:
  implementation-ready design is not complete yet at N-165/N-166.
  Later superseded by N-173 final implementation-ready audit.

default runtime-coverage rule:
  uncovered until explicitly proved covered.

open coverage boundary:
  sched_ext DSQ custody/direct dispatch/bypass/fallback/server pick.
  core scheduling cached picks, core sequence freshness, cookie steal moves.
  proxy donor/current/executor split, donor-aware budget, proxy migration.

next:
  bounded retry and ineligibility source design. Later closed at design level
  by N-167.
  negative denial validation plan. Later closed at design level by N-168/N-169.
  implementation claim-ledger gate. Later closed at design level by N-171.
  upstream-drift recheck before implementation scope is reopened.
```

N-167 bounded retry and ineligibility source design:

```text
artifacts:
  analysis/0115-bounded-retry-ineligibility-source-design.md
  analysis/bounded-retry-ineligibility-source-design-v1.json

key finding:
  pre-rq->curr is not automatically pre-commit.
  pick_next_task() may already have called put_prev_set_next_task().

P5 consequence:
  do not turn the P4 allow-all final hook into a denial hook.
  denial needs pre-settle validation or a source-proved rollback.

default until modeled:
  post-settle denial forbidden without rollback proof.
  sched_ext/core/proxy disabled or excluded for test denial.

next:
  refresh final-deny model and negative validation plan.
```

N-168/N-169 final-deny model refresh and negative validation plan:

```text
artifacts:
  formal/0088-final-deny-source-shape-gate-model/
  validation/0135-final-deny-source-shape-gate-tlc.md
  analysis/0116-negative-denial-validation-plan.md
  analysis/negative-denial-validation-plan-v1.json

TLC:
  safe passed: 10 generated, 8 distinct, depth 5.
  unsafe expected counterexamples: 15/15.

rejects:
  post-settle denial without rollback.
  invisible ineligibility and same-candidate repick.
  SCX head livelock and fallback authority.
  core cached-pick bypass.
  proxy donor/executor mismatch.
  fail closed while eligible.
  runtime/protection/cost overclaims.

next:
  classify scheduler paths as supported, disabled, or excluded for P5.
```

N-170 scheduler path classification for P5:

```text
artifacts:
  analysis/0117-scheduler-path-classification-for-p5.md
  analysis/scheduler-path-classification-for-p5-v1.json
  formal/0089-scheduler-path-classification-gate-model/
  validation/0136-scheduler-path-classification-gate-tlc.md

TLC:
  safe passed: 2 generated, 1 distinct, depth 1.
  unsafe expected counterexamples: 10/10.

initial P5 supported:
  ordinary CFS final run, non-core, non-proxy, non-sched_ext.
  common queued move through move_queued_task() / move_queued_task_locked().

initial P5 disabled:
  sched_ext.
  core scheduling.
  proxy execution.

initial P5 excluded:
  fair direct load balance.
  RT and deadline.
  idle exception.
  stopper/hotplug/migration kernel threads.
  generic kthreads/workqueues.
  io_uring workers.

rejects:
  open paths.
  supported-without-evidence.
  runtime coverage over excluded paths.
  disabled path execution.
  fallback authority.
  workqueue/kthread caller-authority collapse.
  implementation/protection/cost overclaims.

next:
  implementation claim-ledger gate. Later closed at design level by N-171.
  upstream-drift recheck plan for reopening implementation scope.
  final implementation-ready audit.
```

N-171 implementation claim-ledger gate:

```text
artifacts:
  analysis/0118-implementation-claim-ledger-gate.md
  analysis/implementation-claim-ledger-gate-v1.json
  formal/0090-implementation-claim-ledger-gate-model/
  validation/0137-implementation-claim-ledger-gate-tlc.md

TLC:
  safe passed: 2 generated, 1 distinct, depth 1.
  unsafe expected counterexamples: 13/13.

required future implementation proposal row:
  proposal id.
  slice id.
  Linux base/work commit.
  patch scope and behavior mode.
  evidence classes present.
  supported claims.
  forbidden claims.
  open gaps.
  validation before review and acceptance.
  upstream drift freshness.
  safety flags.

rejects:
  missing ledger row.
  implementation approval without reopened scope or fresh drift.
  behavior change without P5 negative evidence.
  runtime denial without denied-candidate trace evidence.
  runtime coverage without runtime trace coverage.
  monitor verification without monitor roots.
  production/hypervisor-grade/cost overclaims.
  public ABI overclaim.
  model-only or compatibility-only production claim.

next:
  upstream-drift recheck plan for reopening implementation scope. Later closed
  at design level by N-172.
  final implementation-ready audit.
```

N-172 implementation reopen upstream drift gate:

```text
artifacts:
  analysis/0119-implementation-reopen-upstream-drift-gate.md
  analysis/implementation-reopen-upstream-drift-gate-v1.json
  formal/0091-implementation-reopen-drift-gate-model/
  validation/0138-implementation-reopen-drift-gate-tlc.md

fresh upstream:
  before: 665159e246749578d4e4bfe106ee3b74edcdab18
  after:  4a50a141f05a8d1737661b19ee22ff8455b94409

source-drift run:
  run_dir: build/source-drift/linux-source-drift-gate/20260702T063331Z-b5-recheck
  base_to_upstream_commit_count: 342
  watched_changed_count: 1
  changed path: kernel/sched/cpufreq_schedutil.c
  drift class: D1 nearby non-intersecting
  model_refresh_required_count: 0
  merge_tree_clean: true
  model_freshness: fresh
  linux_patch_approved: false

TLC:
  safe passed: 2 generated, 1 distinct, depth 1.
  unsafe expected counterexamples: 15/15.

rejects:
  reopen without fresh fetch/source-drift run/group classification.
  clean merge as semantic freshness.
  reopen with stale model or touched group.
  reopen without claim ledger.
  P5 reopen without path classification or negative plan.
  behavior/coverage/ABI/monitor/protection/cost claims from drift freshness.

next:
  final implementation-ready audit.
```

N-173 final implementation-ready audit:

```text
artifacts:
  analysis/0120-final-implementation-ready-audit.md
  analysis/final-implementation-ready-audit-v1.json
  formal/0092-final-implementation-ready-audit-model/
  validation/0139-final-implementation-ready-audit-tlc.md

verdict:
  implementation-ready design complete for scope-reopening review.
  implementation scope reopened: false.
  Linux patch approved: false.
  behavior change approved: false.
  runtime denial approved: false.
  runtime coverage: false.
  monitor verified: false.
  production protection: false.
  cost efficiency: false.

next reviewable candidate:
  P3 placement-only/no-denial/no-ABI scheduler touchpoints, only after explicit
  implementation-scope reopening and a proposal row.

sequential candidates:
  P4 only after P3 implementation validation.
  P5 only after P3/P4 validation, and only as off-by-default test-only denial
  for the classified support set.

TLC:
  safe passed: 2 generated, 1 distinct, depth 1.
  unsafe expected counterexamples: 12/12.
```

Current implementation state, 2026-07-02:

```text
N-165:
  P3 placement-only scheduler touchpoint patch is applied at Linux commit
  d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3 and validated in validation/0140.
  It is no-denial/no-ABI/no-monitor compatibility evidence only.

N-166:
  P4 pre-entry gate was complete for the then-fetched upstream ref:
    analysis/0122-sched-exec-lease-p4-pre-entry-risk-gate.md
    validation/0141-sched-exec-lease-p4-pre-entry-validation.md

  N-167 supersedes this as an implementation-go decision.

  Evidence:
    exact patch queue replay to P3 HEAD.
    upstream drift fresh at that time; only D1 nearby cpufreq_schedutil.c drift.
    git diff/security review for P3 diff.
    Codex Security preflight ready; no full canonical scan launched.
    generated-code review found no marker symbols and identical section sizes/
    relocations, but not byte identity.
    QEMU off/on all-workload matrix passed with kprobes enabled.

  Caveats:
    no byte-identity claim.
    no runtime coverage claim.
    checkpatch metadata issues remain before RFC/mainline-style series:
      missing commit description.
      missing Signed-off-by.

N-167:
  P4 pre-implementation critical audit is complete:
    analysis/0123-sched-exec-lease-p4-pre-implementation-critical-audit.md
    validation/0142-sched-exec-lease-p4-pre-implementation-critical-audit-validation.md

  Verdict:
    P4 implementation is paused. The drift runner now fails on nonexistent
    watched paths and requires l0_footprint to match the actual base..work
    Linux diff. Fresh fetch moved upstream/master to
    87320be9f0d24fce67631b7eef919f0b79c3e45c. Scheduler/lifecycle/async/policy
    direct P4 groups are fresh, but device_queue_iommu is D4 stale from current
    net changes, so global model_freshness=stale and
    candidate_no_behavior_patch_reviewable=false.

  Next:
    create candidate-scoped drift closure or refresh the stale D4
    device/QueueLease source maps; add P4 anchor manifest and runtime/static
    final-run anchor observability. P4 remains allow-all only. P5 remains
    blocked.

N-168:
  Candidate-scoped drift closure gate is complete:
    analysis/0124-candidate-scoped-drift-closure-gate.md
    formal/0093-candidate-scoped-drift-closure-gate-model/
    validation/0143-candidate-scoped-drift-closure-gate-tlc.md

  Verdict:
    P4SchedulerAllowAll candidate-scoped drift is closed for
    l0_footprint, scheduler_authority_core, and task_lifecycle_identity
    against upstream 87320be9f0d24fce67631b7eef919f0b79c3e45c.
    Global all-angles freshness remains false because device_queue_iommu is
    still D4 stale and cannot support device, QueueLease, datacenter, or broad
    architecture claims.

  TLC:
    safe passed; 14 unsafe configs produced expected counterexamples.

  Next:
    P4 implementation is still paused until final-run anchor manifest,
    queued-move anchor manifest, and runtime/static anchor observability exist.
    P4 remains allow-all only. P5 remains blocked.

N-169:
  P4 anchor manifest is complete:
    analysis/0125-sched-exec-lease-p4-anchor-manifest.md
    analysis/sched-exec-lease-p4-anchor-manifest-v1.json
    formal/0094-p4-anchor-manifest-gate-model/
    validation/0144-sched-exec-lease-p4-anchor-manifest-validation.md

  Source checker:
    validation/run-sched-exec-lease-p4-anchor-manifest-check.sh
    found 3 anchors against Linux commit d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3.

  Anchors:
    A1 final-run allow-all join in __schedule between
      rq->last_seen_need_resched_ns = 0;
      and is_switch = prev != next;
      before rq->curr publication and context_switch.
      This is explicitly not P5-denial-safe.
    A2 common queued move before deactivate_task/set_task_cpu in
      move_queued_task.
    A3 double-rq locked move before deactivate_task/set_task_cpu in
      move_queued_task_locked.

  TLC:
    safe passed; 12 unsafe configs produced expected counterexamples.

  Next:
    P4 implementation is still not approved. Remaining pre-P4 blockers:
    runtime/static final-run anchor observability, allow-all helper proof, and
    no reachable denial path proof.

N-170:
  Static final-run observability is complete:
    analysis/0126-sched-exec-lease-p4-static-final-run-observability.md
    analysis/sched-exec-lease-p4-static-final-run-observability-v1.json
    formal/0095-static-final-run-observability-gate-model/
    validation/0145-sched-exec-lease-p4-static-final-run-observability-validation.md
    validation/run-sched-exec-lease-p4-static-final-run-observability.sh

  Source checker:
    window_start=7065
    window_end=7249
    insert_after=7196
    insert_before=7198
    rq_curr_line=7205
    trace_sched_switch_line=7235
    p3_note_switch_line=7237
    context_switch_line=7239

  Meaning:
    The future P4 allow-all final-run helper interval is statically observable
    before rq->curr publication. Existing P3 note_switch is after rq->curr and
    is not a precommit anchor or runtime coverage.

  TLC:
    safe passed; 9 unsafe configs produced expected counterexamples.

  Next:
    P4 implementation is still not approved. Remaining pre-P4 blockers:
    allow-all helper proof and no reachable denial path proof.

P4 allow-all helper proof / validation 0146:
  Prepatch allow-all/no-reachable-denial helper proof is complete:
    analysis/0127-sched-exec-lease-p4-allow-all-helper-proof.md
    analysis/sched-exec-lease-p4-allow-all-helper-proof-v1.json
    formal/0096-p4-allow-all-helper-gate-model/
    validation/0146-sched-exec-lease-p4-allow-all-helper-proof-validation.md
    validation/run-sched-exec-lease-p4-allow-all-helper-proof.sh

  Source checker:
    passed against Linux work commit d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3.
    sched_exec_allow_all_validation() returns only
    SCHED_EXEC_VALIDATION_ALLOW.
    no RETRY/INELIGIBLE/QUARANTINE return is currently present.
    no P4 validate-run/move helper is currently present.
    scheduler code does not branch on SchedExecLease validation results.

  TLC:
    safe passed; 15 unsafe configs produced expected counterexamples.

  Next:
    Actual P4 allow-all skeleton patch is now the next reviewable step, but it
    still requires generated-code/object review, CONFIG off/on build, QEMU
    compatibility, and overclaim/security-diff validation before acceptance.
    P5 denial remains blocked.

P4 allow-only skeleton implementation:
  Linux commit:
    a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
    sched/exec_lease: Add allow-only validation skeleton

  Patch queue:
    0007-sched-exec-lease-Add-allow-only-validation-skel.patch
    replayed to exact HEAD.

  Added:
    three static inline helpers returning only SCHED_EXEC_VALIDATION_ALLOW.
    three callsites:
      final-run before is_switch/rq->curr/context_switch.
      common queued move before deactivate_task/set_task_cpu.
      locked queued move before deactivate_task/set_task_cpu.

  Validation 0147:
    checkpatch clean.
    targeted CONFIG off/on scheduler build passed.
    source/object checker passed:
      helper_count=3.
      callsite_count=3.
      non_allow_returns_found=false.
      scheduler_branches_on_validation_result=false.
      validation_symbols_emitted=false.
      core_o_file_size_equal=true.
    formal/0097 safe passed; 12 unsafe configs produced expected
    counterexamples.

  Validation 0148:
    full vmlinux off/on build passed.
    off config undef, vmlinux present, exec_lease.o absent.
    on config y, vmlinux present, exec_lease.o present.

  Validation 0149:
    QEMU off/on boot/workload smoke passed.
    off run:
      build/qemu/sched-exec-lease-p4-allow-only-matrix/20260702T220800Z-off
    on run:
      build/qemu/sched-exec-lease-p4-allow-only-matrix/20260702T221639Z-on
    both qemu_status=0 and WORKLOAD_RET 0.

  Analysis 0128 / validation 0150:
    final overclaim/security review passed.
    findings_reported=0.
    P4 allow-only compatibility slice closed.

  Non-claims:
    no runtime denial, runtime coverage, budget enforcement, monitor
    verification, production protection, hypervisor-grade isolation,
    cost-efficiency, deployment readiness, or P5 denial approval.

P5 readiness after P4:
  analysis/0129, formal/0098, and validation/0151 refresh P5 against actual P4
  code at Linux commit a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8.

  Source checker:
    run-sched-exec-lease-p5-readiness-after-p4.sh passed.
    run_hook_before_rq_curr=true.
    run_hook_before_context_switch=true.
    run_hook_after_pick_next_task=true.
    known_class_settlement_before_run_hook_source=true.
    run_hook_p5_deny_ready=false.
    common/locked move hooks before local mutation=true.
    common_move_returns_status=false.
    locked_move_returns_status=false.

  TLC:
    formal/0098 safe passed.
    9 unsafe configs produced expected counterexamples.

  Current rule:
    P5 remains blocked. The P4 run hook is pre-rq->curr but not
    pre-class-settle. Move hooks are pre-mutation but caller-unsafe without
    status plumbing. Do not branch on non-ALLOW until run denial is pre-settle
    or rollback-proved, move denial has status plumbing, negative tests exist,
    path classification is enforced, and runtime/protection/cost claims remain
    false.

P5A scope:
  analysis/0130, implementation/0028, formal/0099, and validation/0152 record
  P5A scope only. No Linux implementation is approved.

  Split:
    P5A0 = no-behavior infrastructure proposal.
    P5A-R = run-denial design.
    P5A-M = move status-plumbing design.
    P5A-V = validation and claim ledger.

  Hardened conclusions:
    deny-one-CFS-and-pick-next requires fair-picker eligibility integration.
    broad common move denial requires status settlement across migration,
    affinity, swap, push, and core-cookie-steal paths.
    first patch may not change behavior.

  Validation:
    run-sched-exec-lease-p5a-scope-gate.sh passed.
    formal/0099 safe passed.
    10 unsafe configs produced expected counterexamples.

  Next:
    P5A0 no-behavior infrastructure proposal only.

P5A0 no-behavior gate:
  analysis/0131, implementation/0029, formal/0100, and validation/0153 record
  and validate P5A0 as proposal only. No Linux patch is approved.

  Allowed shape:
    future status plumbing shape, internal test harness observability,
    setup-time path-disable boundaries, and claim ledger rows.

  Forbidden by gate:
    behavior change, non-ALLOW branch, runtime denial, retry, fail-closed,
    quarantine, public ABI, monitor call, layout/object impact, runtime
    coverage claim, monitor verification claim, protection claim,
    cost-efficiency claim, datacenter claim, and deployment-readiness claim.

  Validation:
    strengthened run-sched-exec-lease-p5a0-no-behavior-gate.sh passed against
    a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8.
    formal/0100 safe passed.
    14 unsafe configs produced expected counterexamples.

  Next:
    P5A0.E prepatch evidence package.

P5A0.E prepatch evidence:
  analysis/0132, implementation/0030, formal/0101, and validation/0154 record
  and validate P5A0.E as evidence only. No Linux patch is approved.

  Naming:
    P5A0.E = evidence only.
    P5A0.P1 = future first no-behavior Linux patch proposal.
    P5A0.P2 = future move-status plumbing proposal.

  Drift:
    l0_footprint and scheduler_authority_core are fresh in run
    20260702T-p5a0-1-drift.
    device_queue_iommu remains D4 stale and barred from broad/device/
    datacenter/protection/cost claims.
    global_model_freshness=false.

  Source facts:
    helpers ALLOW-only.
    validation callsites=3.
    no scheduler branch on validation.
    no fair-picker ineligibility.
    run hook is not P5 deny-ready.
    move hooks are pre-mutation but not status-capable.

  Validation:
    run-sched-exec-lease-p5a0-e-prepatch-evidence.sh passed.
    formal/0101 safe passed.
    14 unsafe configs produced expected counterexamples.

  Next:
    P5A0.P1 patch plan only, limited by default to
    include/linux/sched_exec_lease.h and kernel/sched/exec_lease.c.

P5A0.P1 patch-plan gate:
  analysis/0133, implementation/0031, formal/0102, and validation/0155 record
  and validate P5A0.P1 as a patch-plan/reviewability gate only. No Linux patch
  or `0008` patch is approved.

  Required future shape:
    per-0008 delta footprint, not full queue footprint.
    file allowlist: include/linux/sched_exec_lease.h and
    kernel/sched/exec_lease.c.
    hot-path helper bodies frozen.
    exec_lease.c lifecycle helper behavior frozen because fork/exec/exit call
    those helpers.
    no behavior, denial, ABI, monitor call, runtime coverage, protection,
    cost, datacenter, or global freshness claim.

  Validation:
    run-sched-exec-lease-p5a0-p1-patch-plan-gate.sh passed.
    formal/0102 safe passed with PlanRecordedEventually.
    20 unsafe configs produced expected counterexamples.

  Next:
    Future P5A0.P1 no-behavior Linux patch draft under the gate. P5A-R and
    P5A-M remain blocked by fair-picker eligibility and move-status settlement.

P5A0.P1 concrete 0008 source/full-build/object-layout/upstream/QEMU gate:
  implementation/0032, formal/0103, validation/0156, validation/0157,
  validation/0158, validation/0159, and validation/0160 record the concrete
  `0008` Linux patch at d812f83c033a9f9b3d533e667e7106a5734eb30b.

  Shape:
    comment-only delta.
    files: include/linux/sched_exec_lease.h and kernel/sched/exec_lease.c.
    21 inserted comment lines.
    no helper body, lifecycle body, task layout, scheduler branch, ABI,
    monitor, allocation, locking, refcount, runtime-denial, or claim change.

  Validation:
    run-sched-exec-lease-p5a0-p1-0008-source-check.sh passed.
    patch queue replay matched exact Linux head and tree.
    formal/0103 safe passed.
    11 unsafe configs produced expected counterexamples.
    full CONFIG_SCHED_EXEC_LEASE=off/on vmlinux builds passed.
    off build has exec_lease.o absent; on build has exec_lease.o present.
    object/layout checker passed:
      core.o function-size tables match off/on.
      validation helpers emit no symbols.
      exec_lease.o has expected lifecycle symbols.
      task layout remains the existing P2 config-gated shape.
    upstream checker passed:
      candidate_anchor_drift_count=0.
      merge_tree_clean=true.
      strict checkpatch clean.
      get_maintainer rows=12.
    QEMU off/on boot/workload smoke passed:
      workload_mode=all.
      qemu_status=0.
      workload_ret=0.

  Acceptance:
    validation/0161 final overclaim/security review passed.
    Codex Security diff scan reported 0 findings with complete diff-scoped
    coverage.
    P5A0.P1 is accepted only as a no-behavior source-contract slice.

  Next:
    P5A-R fair-picker eligibility integration before CFS deny-one-pick-next.
    P5A-M status settlement before broad common move denial.

P5A-R CFS picker source map:
  analysis/0135 and validation/0162 record source-map evidence only.

  Findings:
    P4 run-edge validation is after pick_next_task and put_prev_set_next_task
    settlement.
    pick_task_fair descends CFS group hierarchy through pick_next_entity and
    pick_eevdf.
    sched_delayed is not lease denial.
    RETRY_TASK alone can spin unless denied candidates are picker-visible.
    Core scheduling caches core_pick and has core-cookie replacement paths.
    DL servers can nest fair picks.
    Proxy execution splits donor and executor.
    sched_ext switched-all paths bypass CFS.

  Next:
    P5A-R picker ineligibility gate with attempt-local denied-candidate
    carrier, bounded retry, hierarchy settlement, core/DL/proxy/SCX exclusion
    or settlement, and accounting separation.

P5A-R picker ineligibility gate:
  analysis/0136, formal/0104, and validation/0163 are complete as a pre-code
  gate only.

  Validation:
    source anchors 15/15
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe TLC: 28 expected counterexamples

  The gate rejects:
    late denial, sched_delayed reuse, RETRY_TASK-only denial, idle fallback,
    linear candidate search, unbounded retry, hot persistent denial fields,
    wakeup-preempt bleed, stale generation/epoch, unsettled cgroup mutation,
    uncovered pick_eevdf returns, DL-server retry leakage, delayed-dequeue or
    throttle lifetime aliasing, core sequence/hotplug leakage, Linux-local
    authority forgery, and unsupported core/proxy/SCX/DL-server claims.

  Next:
    source-shape checker for EEVDF return dominance, then hierarchy settlement.

P5A-R EEVDF return dominance:
  analysis/0137, formal/0105, and validation/0164 are complete as a source-
  shape gate only.

  Validation:
    run 20260703T085043Z
    source anchors 17/17, line drift 0
    pick_eevdf direct returns 4
    semantic candidate families 6
    forbidden scan count 0
    safe TLC: 13 generated states, 7 distinct states, depth 2
    unsafe TLC: 11 expected counterexamples

  Result:
    Current pick_eevdf source shape is known: singleton, next buddy, protected
    current, leftmost eligible, heap search, and final current override must all
    be dominated by any future denial/funnel design.

  Still open:
    group hierarchy settlement. Do not approve CFS deny-and-repick before
    LeafDenied/PathDenied/ChildCfsRqExhausted/ParentSkipJustified/ParentOverDenied
    are modeled and validated.

P5A-R group hierarchy settlement:
  analysis/0138, formal/0106, and validation/0165 are complete as a pre-code
  source/formal gate only.

  Validation:
    run 20260703T214938Z
    source anchors 21/21, line drift 0
    semantic hierarchy source shape ok
    safe TLC: 9 generated states, 7 distinct states, depth 5
    unsafe TLC: 13 expected counterexamples

  Result:
    LeafDenied does not imply parent group skip. ParentSkipJustified requires
    ChildCfsRqExhausted. ParentOverDenied is an explicit unsafe state.
    Accounting aliases are not child exhaustion proof.

P5A-R cross-path exclusion/settlement:
  analysis/0139, formal/0107, and validation/0166 are complete as a pre-code
  source/formal gate only.

  Validation:
    run 20260703T220432Z
    source anchors 34/34, line drift 0
    semantic cross-path source shape ok
    safe TLC: 5 generated states, 4 distinct states, depth 4
    unsafe TLC: 18 expected counterexamples

  Result:
    Ordinary-CFS-only denial semantics may not be claimed unless core
    scheduling, DL servers, proxy execution, sched_ext, and class-loop non-fair
    paths are excluded or separately settled. RETRY_TASK is not denial proof.

  Follow-up:
    overhead/layout gate is recorded below; current remaining work is negative
    validation plan and implementation patch plan.

P5A-R overhead/layout gate:
  analysis/0140, formal/0108, and validation/0167 are complete as a pre-code
  source/formal gate only.

  Validation:
    run 20260703T221311Z
    source anchors 22/22, line drift 0
    allow returns 3, non-allow returns 0
    scheduler branch on validation result 0
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe TLC: 18 expected counterexamples

  Result:
    P5A-R may not use linear rb-tree scans, full hierarchy scans, unbounded
    retry, persistent hot denial fields, picker allocation/sleep/monitor/policy
    lookup, or disabled/hot-layout overhead without object/layout evidence.

  Follow-up:
    negative validation plan is recorded below; current remaining work is the
    implementation patch plan.

P5A-R negative validation plan:
  analysis/0141, formal/0109, and validation/0168 are complete as a pre-code
  validation-plan gate only.

  Validation:
    run 20260703T222038Z
    source anchors 5/5, prior gates present
    negative test families 14, required observables 19
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe TLC: 17 expected counterexamples

  Result:
    Future P5A-R tests must reject late denial, denied execution publication,
    same-candidate repick, retry-only denial, parent over-denial, child
    exhaustion aliases, EEVDF/cross-path/stale identity/wakeup/newidle/overhead
    failures, and claim overreach.

  Still open:
    implementation patch plan.
```

P5A-R ordinary-CFS patch plan:
  implementation/0033, formal/0110, and validation/0169 are complete as a
  source/formal patch-plan gate only.

  Validation:
    run 20260703T230145Z
    source anchors 10/10, prior gates present
    pre_settle_window_ok=true
    p4_late_for_p5ar_ok=true
    cross_path_anchors_ok=true
    acceptance validation obligations 22
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe TLC: 16 expected counterexamples

  Result:
    Linux patch `0009` may now be drafted as an ordinary-CFS-only behavior
    candidate. It is not accepted. The future patch must keep denial
    pre-settle/picker-visible, bounded and attempt-local, hierarchy-aware,
    cross-path excluded or settled, private to scheduler internals, and free of
    O(n) scans or persistent hot denial layout.

  Still open:
    actual Linux 0009 draft and full acceptance validation. Runtime denial,
    CFS deny-and-repick correctness, runtime coverage, protection, cost,
    deployment, and datacenter claims remain false.

P5A-R implementation-ready audit:
  analysis/0142, formal/0111, and validation/0170 complete the pre-code
  implementation-ready goal for drafting only.

  Validation:
    run 20260703T231125Z
    required validations 7/7, missing 0
    required models 7/7, missing 0
    linux_0009_may_be_drafted=true
    linux_0009_exists=false
    linux_0009_accepted=false
    runtime_denial_approved=false
    cfs_deny_and_repick_approved=false
    safe TLC: 5 generated states, 4 distinct states, depth 4
    unsafe TLC: 10 expected counterexamples

  Result:
    Next step may be Linux patch `0009` draft under implementation/0033.
    Acceptance and all runtime/protection/cost/datacenter claims remain open.

P5A-R upstream drift/source-shape refresh:
  analysis/0143, formal/0112, and validation/0171 complete the explicit
  upstream/source-shape gate after upstream/master advanced.

  Validation:
    run 20260703T233452Z
    upstream 87320be9f0d24 -> 71dfdfb0209b4
    direct P5A-R scheduler source-shape drift 0
    lifecycle drift 2: fs/exec.c and kernel/fork.c
    merge_tree_clean=true
    ordinary_cfs_0009_draft_reviewable=true
    safe TLC: 5 generated states, 4 distinct states, depth 4
    unsafe TLC: 9 expected counterexamples

  Final audit refresh:
    validation/0170 rerun 20260703T234210Z now requires 8 validations and 8
    models, includes upstream 71dfdfb0209b4, and still allows only drafting
    Linux `0009`. No runtime/protection/cost/datacenter claim is approved.

P5A-R Linux 0009 source gate:
  Linux patch `0009` is drafted at commit
  7a402107fd63faf7063c2dea05e88e7f8a23f4bf and recorded in patch queue
  `0009-sched-fair-Draft-ordinary-CFS-exec-lease-candidate.patch`.

  Shape:
    ordinary CFS fast path uses `pick_task_fair_sched_exec_lease()`.
    normal class picker and DL fair-server picker still use `pick_task_fair()`.
    static key is false and has no enable site.
    active predicate excludes sched_ext, core scheduling, and proxy execution.
    carrier is attempt-local with one denied task receipt, one blocked group
    receipt, and retry limit 1.

  Validation:
    validation/0172 run 20260703T-p5ar-0009-source passed.
    patch queue replay reached exact HEAD.
    checkpatch and diff-check passed.
    formal/0113 safe TLC passed with 5 generated states, 4 distinct states,
    depth 4; 10 unsafe configs produced expected counterexamples.
    validation/0173 run 20260704T-p5ar-0009-targeted-build passed targeted
    CONFIG off/on builds for `kernel/sched/fair.o` and `kernel/sched/core.o`.

  Still false:
    accepted 0009, runtime denial correctness, CFS deny-and-repick correctness,
    runtime coverage, production protection, cost, deployment, datacenter
    readiness.

P5A-R Linux 0009 full build:
  validation/0174 passed under systemd user unit
  `capsched-p5a-r-0009-full-build.service`.

  Log:
    /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260704T032455Z.log

  Evidence:
    off vmlinux sha256=f76dbaed7fd47fe812475f26a10d43053911e0d4319a6eb4681db378ba26eb1f
    on vmlinux sha256=367103fd9d3bb1bdebcb87d1cbcf9ac47fee4639b76b06bb7934f9f3c5cd8281
    on exec_lease.o sha256=75e4085156ebb0610edbef3af9bf281bfc560edc1a59c2246a79c26f6807dd1e

  Still false:
    accepted 0009, runtime denial correctness, CFS deny-and-repick correctness,
    runtime coverage, production protection, cost, deployment, datacenter
    readiness.

P5A-R Linux 0009 object/layout:
  validation/0175 passed.

  Evidence:
    off fair.o size=157712; on fair.o size=159416.
    off/on core.o size=347744.
    on exec_lease.o size=2304.
    task layout probe root:
    build/task-layout/sched-exec-lease-p5a-r-0009-20260704T034710Z.

  Still false:
    accepted 0009, runtime denial correctness, CFS deny-and-repick correctness,
    runtime coverage, production protection, cost, deployment, datacenter
    readiness.

P5A-R Linux 0009 QEMU boot smoke:
  validation/0176 passed for denial-disabled QEMU off/on boot/workload smoke.
  Systemd unit `capsched-p5a-r-0009-qemu-matrix.service`, invocation
  `ea20a9d013034ee886e89ecfced9104e`, completed with Result=success and
  ExecMainStatus=0.

  Log:
    /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0009-qemu-matrix-20260704T035139Z.log

  Output root:
    /media/nia/scsiusb/dev/linux-cap/build/qemu/sched-exec-lease-p5a-r-0009-matrix

  Results:
    off run 20260704T035139Z-off: qemu_status=0, workload_ret=0.
    on run 20260704T035938Z-on: CONFIG_SCHED_EXEC_LEASE=y, qemu_status=0,
    workload_ret=0.

  Limitation:
    pick_next_task and __schedule function observation were unavailable,
    dlease_pick_next_task kprobe failed/missing, and sched_process_exec count
    was 0. This is compatibility evidence only. It cannot accept 0009 or prove
    runtime denial, CFS deny-and-repick correctness, runtime coverage,
    protection, cost, deployment, or datacenter readiness.

P5A-R 0009 negative runtime harness:
  analysis/0144 and implementation/0035 record the next boundary. `0009` is
  dormant because `sched_exec_cfs_candidate_key` has no enable site, so
  negative runtime tests need a separate test-only `0010` overlay.

  Planned shape:
    default-off `CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST`, limited to
    `init/Kconfig` and `kernel/sched/fair.c`, with no syscall ABI, tracepoint
    ABI, debugfs/sysctl/proc control, monitor call, LSM/cgroup interface, or
    persistent hot denial field.

  Synthetic predicate:
    under the test config only, enable the existing static key and deny
    ordinary CFS tasks whose `task->comm` starts with `seldeny`.

  QEMU workload:
    `seldenyA` denied child and `selallowB` allowed sibling child, both pinned
    to the same CPU after trace reset.

  Claim limit:
    this can only test deny-and-repick mechanics for a synthetic ordinary-CFS
    path. It does not prove capability semantics, monitor enforcement,
    production runtime denial correctness, runtime coverage, protection, cost,
    deployment, or datacenter readiness.

P5A-R 0010 negative harness:
  Concrete test-only patch drafted at Linux commit
  `9f2b3996688849eb0ddc13531f735cc4eb16b63d`.

  Patch:
    `sched/fair: Add test-only CFS exec lease denial harness`
    adds default-off `CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST`.

  Test behavior:
    under that config only, enable `sched_exec_cfs_candidate_key` at late init
    and make `task->comm` prefix `seldeny` return
    `SCHED_EXEC_VALIDATION_INELIGIBLE`.

  Validation so far:
    validation/0177 passed for workload compile, runner syntax,
    whitespace checks, config resolution, and targeted `fair.o` build.

  Pending:
    QEMU negative runtime result, security diff review, final overclaim review.

  Started QEMU:
    `capsched-p5a-r-0010-negative-qemu-20260704T043512Z.service`, log
    `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-20260704T043512Z.log`.

  Attempt 1:
    validation/0178 records failure with `qemu_status=124` after
    `tracefs reset: Bad file descriptor`. The guest reached
    `CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y`, so this is a workload trace reset
    issue, not a deny-path verdict.

  Harness fix:
    `trace_marker` is optional now; trace clear remains the machine boundary.

  Rerun:
    `capsched-p5a-r-0010-negative-qemu-rerun-20260704T045417Z.service`, log
    `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-rerun-20260704T045417Z.log`.

  Rerun result:
    validation/0179 records `qemu_status=124` after
    `NEGATIVE_CHILDREN_READY`. The workload had released denied before allowed
    and yielded in between, so the intended "denied plus allowed sibling"
    condition was not established.

  Release-order fix:
    release denied and allowed before yielding, then expect
    `NEGATIVE_CHILDREN_RELEASED`.

  Release-fix run:
    `capsched-p5a-r-0010-negative-qemu-releasefix-20260704T050521Z.service`,
    log `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-releasefix-20260704T050521Z.log`.

  Release-fix result:
    validation/0180 records manual stop after `NEGATIVE_CHILDREN_READY` without
    `NEGATIVE_CHILDREN_RELEASED`. Denied-first wakeup can preempt parent before
    allowed is released.

  Allowed-first fix:
    release allowed first, print `NEGATIVE_ALLOWED_RELEASED`, then release
    denied.

  Allowed-first run:
    `capsched-p5a-r-0010-negative-qemu-allowedfirst-20260704T051039Z.service`,
    log `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-allowedfirst-20260704T051039Z.log`.

  Allowed-first result:
    validation/0181 records RCU stall in `pick_eevdf()` after
    `NEGATIVE_ALLOWED_RELEASED`. This is negative evidence against accepting
    the draft path.

  Equal-priority fix:
    both children now use `nice -20`.

  Equal-priority run:
    `capsched-p5a-r-0010-negative-qemu-equalprio-20260704T051528Z.service`,
    log `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-equalprio-20260704T051528Z.log`.

  Equal-priority result:
    validation/0182 records timeout with `qemu_status=124` after
    `NEGATIVE_ALLOWED_STARTED`, `NEGATIVE_ALLOWED_RELEASED`, and
    `NEGATIVE_CHILDREN_RELEASED`, but without `NEGATIVE_ALLOWED_DONE` or
    `NEGATIVE_RESULT`. This confirms the draft CFS deny-and-repick
    forward-progress bug without relying on the earlier priority-skewed run.

P5A-R 0011 denied repick progress:
  Corrective draft Linux patch:
    commit `38340eceafa88119ba3e0bcdc10f309bfff6462b`
    (`sched/fair: Fix exec lease denied CFS repick progress`).

  Patch queue:
    `linux-patches/patches/capsched-linux-l0/0011-sched-fair-Fix-exec-lease-denied-CFS-repick-progress.patch`.

  Fix shape:
    denial-only pickable fallback after denied blockage has already been
    observed, stale blockage clear for delayed allowed dequeue, and no newidle
    retry loop when blocked only by a denied candidate.

  Validation:
    validation/0183 records strict checkpatch clean plus targeted CONFIG off/on
    `kernel/sched/fair.o` and `kernel/sched/core.o` builds.

  Caveat:
    this repairs the immediate draft-path forward-progress bug, but it is not
    the final production picker structure. Future production work still needs
    pickability-aware selection or a separately modeled bounded search with
    cost/fairness evidence.

  Next:
    validation/0184 records QEMU negative runtime against `0011` timing out
    after the allowed child started.

P5A-R 0012 forced pickable progress:
  Corrective draft Linux patch:
    commit `bd71af5daeae808ac948cbd12af2663151936f22`
    (`sched/fair: Force exec lease pickable CFS progress`).

  Patch queue:
    `linux-patches/patches/capsched-linux-l0/0012-sched-fair-Force-exec-lease-pickable-CFS-progress.patch`.

  Fix shape:
    after denied blockage, scan first for eligible pickable entities; if none
    exist, prefer any pickable runnable entity over idle. Known denied
    candidates still cannot run.

  Validation:
    validation/0185 records strict checkpatch clean plus targeted CONFIG off/on
    `kernel/sched/fair.o` and `kernel/sched/core.o` builds.

  Next:
    validation/0186 records QEMU negative runtime against `0012` passing:
    `NEGATIVE_ALLOWED_NEXT 770`, `NEGATIVE_DENIED_NEXT 0`,
    `NEGATIVE_RESULT PASS`, `qemu_status=0`.
    Security diff review and final overclaim review remain next.

  Non-claims:
    still no accepted production runtime denial correctness, complete CFS
    deny-and-repick correctness, runtime coverage, production protection, cost,
    deployment, or datacenter claim.

P5A-R 0012 boundary review:
  Validation/0187 records the security/overclaim review. The narrow 0186 QEMU
  result is accepted only as synthetic ordinary-CFS test-path evidence.

  No immediate memory-safety issue was identified in the reviewed diff, but
  production acceptance is blocked by: unbounded rb-tree fallback scan under
  denial blockage, forced progress over ordinary CFS eligibility, single-denial
  receipt/retry capacity, ordinary-CFS-only coverage, synthetic `task->comm`
  denial rather than real authority, and patch queue metadata/style cleanup.

  Next design direction:
    move away from post-filter fallback as the production root; analyze
    picker-visible lease eligibility, domain/lease partitioning before CFS
    pick, or another bounded structure with explicit fairness/latency/cost
    proof.

P5A-R 0012 patch queue replay:
  Validation/0188 records the replay metadata repair. `linux-patches` now
  expects replay-normalized HEAD
  `1b572a3fad95b78f4ee89061ba441f77cf24e297`, while the local Linux HEAD is
  `bd71af5daeae808ac948cbd12af2663151936f22`. Both have tree
  `25dbe4e04baa112ab9a872a897f67bec094df209`.

P5A-R2 selector direction:
  Analysis/0146 and validation/0189 record the next direction. Do not keep
  extending the 0012 post-filter fallback as production design.

  Immediate source/model target:
    Candidate A, picker-visible lease eligibility summary in/near the existing
    CFS augmented tree, but only for frozen task-local admission state with a
    modeled invalidation path.

  Long-horizon constraint:
    Candidate C, selecting Domain/SchedContext/ExecutionGrant buckets before
    ordinary CFS, remains the best fit for HyperTag, MemoryView switch cost,
    root budgets, and datacenter single-OS goals.

  Rejected for production:
    unbounded scans, bounded-window completeness claims, synthetic comm-prefix
    authority, and pick-time policy lookup.

P5A-R2 selector model gate:
  Validation/0190 passed. Analysis/0147 and formal/0114 define the gate.

  Result:
    16 source anchors checked with 0 failures; safe TLC passed with 6 generated
    states, 5 distinct states, depth 5; 21 unsafe configs produced expected
    counterexamples.

  Core rule:
    Candidate A is a local cache of frozen task-local admission state, not
    authority. The CFS summary must be EEVDF-compatible
    (`min_pickable_vruntime`-style sentinel or equivalent proof), not a
    boolean-only subtree marker.

  Next:
    P5A-R2 invalidation source map before any new Linux selector patch.

P5A-R2 invalidation source map:
  Validation/0191 passed. Analysis/0148 and formal/0115 define the map.

  Result:
    41 source anchors checked with 0 failures; safe TLC passed with 7 generated
    states, 6 distinct states, depth 6; 17 unsafe configs produced expected
    counterexamples.

  Core rule:
    future P5A-R2 summary freshness cannot depend only on enqueue/dequeue.
    Lifecycle, affinity, queued move, `set_task_cpu`, fair migration, cgroup,
    cpuset, budget/throttle/refill, current entity, group summary, and future
    monitor receipt events must update affected summaries or mark them stale.

  Next:
    P5A-R2 invalidation semantics gate before any new Linux selector patch.

P5A-R2 invalidation semantics gate:
  Validation/0192 passed. Analysis/0149 and formal/0116 define the semantics.

  Result:
    safe TLC passed with 6 generated states, 5 distinct states, depth 5; 23
    unsafe configs produced expected counterexamples.

  Core rule:
    only Fresh summaries are picker proof. Stale, Refreshing, and Blocked
    states fail closed. Refresh requires frozen authority plus generation,
    epoch, budget, affinity, current/group, and future monitor receipt checks.

  Rejected:
    in-place stale-to-fresh, enqueue-only refresh, group false positives,
    silent group false negatives, current/tree collapse, policy lookup in
    picker, monitor call in picker, and production/cost/datacenter claims.

  Next:
    P5A-R2 selector patch plan as source/design gate.

P5A-R2 selector patch plan:
  Validation/0193 passed. Analysis/0150 and formal/0117 define the patch-plan
  gate.

  Result:
    21 source anchors checked with 0 missing and 0 line drift; prior
    validations 0187, 0188, 0189, 0190, 0191, and 0192 were present. Safe TLC
    passed with 6 generated states, 5 distinct states, depth 5; 30 unsafe
    configs produced expected counterexamples.

  Core rule:
    production P5A-R2 must not extend the experimental `0012` post-filter
    fallback or unbounded rb-tree scan. It must move toward an
    EEVDF-compatible fresh-summary proof (`min_pickable_vruntime` style or
    equivalent), preserve the outer Domain/SchedContext selector, and require
    object/layout, disabled-overhead, negative runtime, QEMU, security, and
    upstream replay evidence before any behavior patch can be accepted.

  Next:
    minimal source sketch for the fresh-summary placement and invalidation
    plumbing. Linux patch approval remains false.

P5A-R2 minimal source sketch:
  Validation/0194 passed. Analysis/0151 and formal/0118 define the source
  sketch.

  Result:
    36 source anchors checked with 0 missing and 0 line drift. Safe TLC passed
    with 6 generated states, 5 distinct states, depth 5; 32 unsafe configs
    produced expected counterexamples.

  Core rule:
    future P5A-R2 should piggyback the existing EEVDF augmented rb-tree with a
    `min_pickable_vruntime`-style Fresh summary and U64_MAX-style sentinel.
    Task entities expose their `vruntime` only when Fresh and allowed; group
    entities expose their `vruntime` only when their child `cfs_rq` has a Fresh
    pickable descendant; `curr` is checked separately.

  Rejected:
    separate eligible tree, boolean-only summary, extending `0012`, unbounded
    rb_next scan, pick-time policy lookup, monitor calls in picker, and
    synthetic task->comm authority.

  Next:
    object/layout and disabled-overhead evidence plan before any hot field or
    Linux behavior patch.

P5A-R2 layout/overhead evidence plan:
  Validation/0195 passed. Analysis/0152 and formal/0119 define the evidence
  contract.

  Result:
    40 source anchors checked with 0 missing and 0 line drift. Future P5A-R2
    hot summary fields are absent in the current Linux tree. Safe TLC passed
    with 6 generated states, 5 distinct states, depth 5; 36 unsafe configs
    produced expected counterexamples.

  Core rule:
    future P5A-R2 work must separate CONFIG=n, CONFIG=y selector-disabled,
    CONFIG=y candidate-enabled, runtime negative, benchmark/perf, security,
    QEMU, and upstream replay evidence. Build/object/layout evidence cannot
    support runtime protection, cost, deployment, or datacenter claims.

  Next:
    no-behavior layout probe plan or patch before any hot field or behavior
    patch. Linux patch approval remains false.

P5A-R2 layout probe patch plan:
  Validation/0196 passed. Analysis/0153 and formal/0120 reserve `0013` for a
  no-behavior layout probe patch only.

  Result:
    32 source anchors checked with 0 missing and 0 line drift. Absence checks
    found no layout-probe config/object and no P5A-R2 summary field in the
    current Linux tree. Safe TLC passed with 6 generated states, 5 distinct
    states, depth 5; 31 unsafe configs produced expected counterexamples.

  Core rule:
    `0013` may be drafted as default-off build-only probe infrastructure. It
    must not be selected by normal `CONFIG_SCHED_EXEC_LEASE`, must not add
    runtime call sites, and must not create ABI/exported-symbol/monitor/policy
    surfaces.

  Next:
    draft `0013` within this probe-only scope. Behavior patch approval remains
    false.

P5A-R2 0013 layout probe:
  Validation/0197 passed. Implementation/0039 records the concrete no-behavior
  probe patch.

  Result:
    local Linux commit `0b79e307dc9536d38557141cfd650f2be9a2af57`;
    replay commit `077c948be39432971e7273b16b728172251129aa`;
    matching tree `7ef04bf73d26b2813b10016b7eb342a618a66570`.
    Patch queue 0013 sha256
    `cc1fe1754e64bfaa23e8214445b748d0287e7961500d0aa2a7d6f995a295fb38`.
    Normal CONFIG off/on builds do not emit `exec_lease_layout_probe.o`.
    Probe CONFIG on builds the object, size 2464, sha256
    `d688b67c55e9cfb0fdd8d5c0e6978be548d69edaa7d7b6c738baba8c6ae6d4cc`,
    with 24 probe symbols.

  Core rule:
    0013 is layout measurement infrastructure only. It does not authorize hot
    summary fields, behavior changes, runtime denial correctness, monitor
    enforcement, protection, cost, deployment, or datacenter claims.

  Next:
    convert probe symbols into a structured layout table and disabled-overhead
    evidence before any P5A-R2 selector behavior patch.

P5A-R2 0013 layout table:
  Validation/0198 passed. The 0013 probe symbols are now a structured table.

  Baseline:
    `sched_entity` 320; `run_node` 16/24; `min_vruntime` 48/8;
    `vruntime` 120/8.
    `cfs_rq` 384; `tasks_timeline` 64/16; `curr` 80/8; `next` 88/8.
    `rq` 3392; `nr_running` 0/4; `curr` 16/8; `cfs` 128/384.
    `task_struct` 3328; `sched_exec` 1424/40.

  Result:
    14 entries, 4 structs, 10 fields, all fields within containing structures.
    Layout TSV sha256
    `466349c5b78cf23d7cc996649372fa003fa82fbeaf89b7fd222ef244a9ae5523`;
    layout JSON sha256
    `06bf37fdb4a1ef823f21887f1b61b1df14749dfcf1c7b63a11f52fc2994b97e7`.

  Core rule:
    this is a baseline, not approval for hot fields or behavior. Next evidence
    should compare disabled-overhead for normal CONFIG off/on builds.

P5A-R2 0013 disabled-overhead boundary:
  Validation/0199 passed.

  Result:
    0013 changes only `init/Kconfig`, `kernel/sched/Makefile`, and
    `kernel/sched/exec_lease_layout_probe.c`. It touches no existing hot
    scheduler or lifecycle file. `CONFIG_SCHED_EXEC_LEASE_LAYOUT_PROBE` is
    default n and not selected by normal `CONFIG_SCHED_EXEC_LEASE`. Normal
    CONFIG off/on targeted scheduler object builds do not emit
    `exec_lease_layout_probe.o` and contain no `sched_exec_lp_*` symbols.

  Core rule:
    this is source/build-graph evidence, not a performance benchmark and not
    an object byte-identity claim. Performance/cost/protection claims remain
    false.

P5A-R2 vruntime sentinel gate:
  Analysis/0154, formal/0121, and validation/0200 reject literal `U64_MAX` as
  an EEVDF vruntime infinity. Linux compares vruntime with a signed wrapping
  delta, and the gate mechanically observes
  `(s64)(U64_MAX - 100) = -101`.

  Future summary contract:
    use explicit validity plus a wrap-aware numeric minimum as an inseparable
    pair. Invalid means the numeric member is ignored; valid means at least one
    Fresh/pickable descendant witnesses the minimum. The picker guards
    validity before `vruntime_eligible()`. `curr` is checked separately from
    the rb-tree aggregate. Group entities project a child tree-or-curr witness,
    and ancestor updates cover the full invalidation closure under rq locking.

  Gate result:
    16 source anchors with 0 failures; safe TLC 7 generated states, 6 distinct
    states, depth 6; 18 expected counterexamples. No Linux patch, hot field,
    runtime behavior, protection, performance, cost, deployment, or datacenter
    claim is approved.

  Next:
    map every summary update and invalidation source before proposing a
    selector patch.

P5A-R2 summary update closure:
  Analysis/0155, formal/0122, and validation/0201 map ten invalidation event
  families to the current Linux source and rq-lock boundary.

  Core update rule:
    recompute the changed node or separate-current witness under `rq->lock`,
    project the child combined witness through its parent group entity, and
    continue to the root before unlock. Migration removes old-rq validity
    before unlock and publishes destination validity only after locked
    activation. Final task-local Fresh validation remains mandatory.

  Gate result:
    32 source anchors with 0 failures; 4 expected absence checks with 0
    failures; safe TLC 71 generated states, 61 distinct states, depth 7; 24
    expected counterexamples.

  Blocker:
    task-local closure is mapped, but shared domain/grant epoch, budget,
    monitor-revoke, and outer-selector changes have no runtime authority
    publication, runnable index, per-rq receipt generation, or fanout protocol.
    A hot-field/picker patch is not reviewable until a versioned shared
    invalidation contract closes this gap.

P5A-R2 versioned global invalidation fence:
  Analysis/0156, formal/0123, and validation/0202 select a conservative L0
  answer to the shared invalidation gap.

  Publication and trust:
    write frozen shared state, release-publish a non-reused global projection
    generation, and queue work for every online rq. The picker acquire-loads
    the generation and trusts a summary only when its state is Fresh and its
    built generation matches. A mismatch blocks trust before fanout arrives.

  Rebuild:
    under the owning rq lock, revalidate every leaf, rebuild rb aggregates,
    separate current, and group projections, then recheck generation. A raced
    or partial rebuild remains Stale/Blocked. Final task revalidation remains
    mandatory; picker scan, repair, policy, and monitor calls are forbidden.

  Boundary:
    this global baseline avoids an unproven domain index but creates explicit
    false negatives and potentially O(n) rq-lock hold time. It is not yet a
    production performance design and does not implement the outer Candidate C
    selector.

P5A-R2 global-fence layout/rebuild evidence plan:
  Analysis/0157, formal/0124, and validation/0203 passed an evidence-plan gate
  with 24 source anchors, 6 future-absence checks, safe TLC 6/5/depth 5, and
  32 expected counterexamples.

  Candidate rejection envelope:
    per architecture, `sched_entity` growth <= 8 bytes, `cfs_rq` growth = 0,
    `rq` growth <= 32 bytes, and `task_struct` growth = 0, with specified hot
    offsets unchanged. Full rq-locked rebuild is rejected above 25000 ns p99
    or 50000 ns raw maximum additional irq-disabled lock hold, at one base
    slice, or on any locking/RCU/lockup warning.

  Boundary:
    this is a plan, not a layout candidate, rebuild prototype, correctness
    proof, performance result, or protection claim.

P5A-R2 arm64 0013 layout table:
  Validation/0204 mechanically structured the existing arm64 probe evidence:
  24 symbols became 14 entries, all within containing structures, at exact
  Linux commit/tree `077c948be394`/`7ef04bf73d26`.

  Baseline:
    `sched_entity` 320, `cfs_rq` 384, `rq` 3520, `task_struct` 4160, and
    `task_struct.sched_exec` 1232/40. This is architecture-local; it does not
    claim x86_64 byte identity.

  Next:
    expanded default-off build-only probe patch plan. Behavior and hot-field
    approval remain false.

P5A-R2 expanded E1 probe:
  Analysis/0158/formal/0125/validation/0205 passed the 0014 patch-plan gate:
  one probe file, 24 existing plus 27 new symbols, per-architecture cacheline
  derivation, no candidate fields, and no behavior. Evidence was 25 anchors,
  zero absence failures, safe TLC 5/4/depth 4, and 20 counterexamples.

  Implementation/0040 records local commit `5e1ca3037e348`, replay commit
  `6537a57d3d4b`, and common tree `54f685aad94f`. Strict checkpatch is clean.
  Validation/0206 passed fresh arm64 off/on/probe targets, normal-build probe
  absence, preservation of all 24 existing symbols, 27 additions, exactly 51
  total symbols, and a 23-field cacheline table. The first run completed all
  builds and exposed the corrected 49-to-51 ledger error.

  Boundary:
    E1 is complete. A disposable E2 layout-only candidate requires a separate
    gate. Hot fields, selector/rebuild behavior, runtime correctness,
    protection, performance, and cost remain unapproved.

P5A-R2 E2 disposable arm64 candidate:
  Analysis/0159/formal/0126/validation/0207 passed a disposable-worktree-only
  gate with 20 anchors, 6 absence checks, safe TLC 5/4/depth 4, and 30 expected
  counterexamples. Primary Linux stays at E1 and the patch queue at 0014.

  Candidate commit `162d16640634` adds a default-off probe-dependent valid
  byte/u64 minimum to sched_entity alignment gaps and byte state/u64 generation
  to the rq tail gap. It changes four files and no runtime callsite. Initial
  append placements caused forbidden 64-byte growth and were discarded.

  Corrected run `20260713T-p5a-r2-e2-layout` passed the authoritative arm64
  off/on/candidate build and 51+8=59 symbol, 27-field, structure/offset
  comparison. All four structure deltas are zero and protected offsets remain
  fixed.

  The first attempt exited before compilation on a harness false negative:
  Kconfig validly omitted the dependency-hidden disabled candidate, but the
  harness required a not-set comment. The corrected runner rejects only `=y`;
  the exact disposable candidate and frozen primary boundaries are unchanged.

  Boundary:
    arm64 E2 layout evidence passed. x86_64 E2 is separate and next; accepted
    hot fields, E3, behavior, denial correctness, protection, performance, and
    cost are false.

P5A-R2 E2 x86_64 plan:
  Analysis/0160/formal/0127/validation/0209 passed 18 anchors, 4 absence
  checks, safe TLC 5/4/depth 4, and 24 expected counterexamples. The next
  evidence is a fresh same-toolchain x86_64 E1 plus candidate off/on/probe
  cross-build. It must preserve all 51 E1 values, add 8 symbols, emit 27
  fields, and satisfy x86_64-local size/field gates. No runtime inference,
  source acceptance, E3, protection, performance, or cost claim exists.

  External job `p5a-r2-e2-x86_64-build` owns validation/0210's fresh E1 and
  candidate off/on/probe cross-build. Passing evidence remains pending its
  exact result.json.
