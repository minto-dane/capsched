# AI Handoff

Updated: 2026-07-01

Read this first when resuming the project.

## Current State

The workspace is `/media/nia/scsiusb/dev/linux-cap`.
The project-control Git repository is `/media/nia/scsiusb/dev/linux-cap/capsched`.

Private GitHub publication is now a superproject:

```text
superproject:
  https://github.com/minto-dane/linux-cap

project state/model repo:
  https://github.com/minto-dane/capsched

Linux patch queue repo:
  https://github.com/minto-dane/capsched-linux
```

ADR-0010 fixes the publication policy. `capsched-linux` is not a full Linux
history mirror. It stores upstream base metadata, the private CapSched Linux
patch series, and a recreate script. The local full Linux working tree remains
under `linux/`, but it is not committed into the superproject.

Recreate local Linux from the superproject with:

```sh
./linux-patches/scripts/recreate-capsched-linux-l0.sh ./linux
```

Upstream Linux has been fetched into sibling repository `linux/`. Slice 0A has
been committed in that Linux repository as inert `CONFIG_CAPSCHED` scaffolding.
Slice 0B has also been committed as type-only authority scaffolding in
`include/linux/capsched.h` and `kernel/sched/capsched.c`. No behavior-changing
scheduler patch points are accepted yet.

ADR-0007 fixes the N-series traceability policy. `N-*` remains a chronological
work ledger for past and future work. Semantic meaning, Linux anchors, drift
state, validation class, and claim limits live in overlay rows under
`capsched-models/traceability/`. Existing source-map artifacts are useful
topic-local Linux mappings, but there is not yet a complete central
N-to-artifact-to-Linux-to-claim drift ledger. Linux source anchors remain
non-authoritative by default:

```text
authority_claim=false
monitor_verified=false
protection_claim=false
```

ADR-0008 fixes the implementation posture. Every slice, including L0, is
designed backward from the long-horizon monitor-backed datacenter OS target.
Small Linux patches are still preferred for upstream tracking, but thin hooks
are a maintainability tactic, not a weakened security objective. A Linux-only
placeholder must not hide authority that belongs to future HyperTag Monitor
receipts, Domain epochs, MemoryViews, root budgets, IOMMU roots, queue leases,
or service-domain provenance.

Modern NIC QueueLease/service-work analysis has reached a model-supported but
not implementation-approved gate for Intel `ice`:

```text
validation/0051:
  runner: validation/run-ice-revoke-readiness.sh
  latest run: build/ice-revoke-readiness/20260630T002344Z
  tracepoint_rows=8, tracepoint_missing_rows=0
  source_anchor_rows=31, source_anchor_missing_rows=0
  obligation_readiness_rows=10, gap_rows=8
  observation_only=true, authority_claim=false, monitor_verified=false

hard gaps:
  no QueueTag / queue epoch root
  no typed SubmitLedger / DescriptorLedger / CompletionSettlement id
  no monitor-backed DMA/IOMMU/MemoryView invalidation receipt implementation
  no stale XSK/page-pool completion quarantine distinction
  no VF IRQ ownership proof for the synchronize_irq exception
  no lower QueueLease proof for representor revoke
  no typed service-work carrier implementation
  no service/caller budget charging rule
  no reset/rebuild replay reauthorization implementation
  no VF identity epoch, VSI generation, mailbox embargo, or service replay
    handoff implementation

latest completed risk:
  Modern NIC ServiceWork carrier and service/caller authority intersection
  for reset/PTP/DPLL/eswitch/LAG/firmware/maintenance work.

latest completed risk:
  VF mailbox QueueControl/DMA/IRQ/budget/FDIR carrier semantics.

latest completed risk:
  VF identity epoch and SR-IOV/VF reset/reassignment handoff so old vf_id, VSI,
  queue, IRQ, DMA, or FDIR state cannot carry authority into a new Domain.

latest completed risk:
  Modern NIC HyperTag Monitor interface and Linux service/driver Domain split
  for QueueLease/VF/DMA/IRQ/representor/offload/service-work authority.

latest completed risk:
  Modern NIC HyperTag implementation-readiness gate for observation-only
  probes, inert stubs, and no behavior-changing approval before gate
  satisfaction.

latest completed risk:
  Modern NIC HyperTag observation ledger and no-code source runner, with 37
  rows emitted, 36 available anchors, 1 expected LocalDomainDeviceLease gap, and
  0 safety-flag violations.

latest completed risk:
  LocalDomainDeviceLease external gap resolution. Analysis/0064 defines the
  root-management/local monitor compilation boundary, and formal/0042 plus
  validation/0063 model-check that ClusterLease text, scheduler placement,
  service-domain admission, Linux device registration, stale cluster epochs,
  wrong service/target Domains, queue receipt before local lease, and audit-only
  monitor calls cannot stand in for a monitor-minted LocalDomainDeviceLease.

latest completed risk:
  LocalDomainDeviceLease observation contract. Analysis/0065 defines 10
  pre-monitor rows from ClusterLease issue through local lease revoke, required
  fields, safety flags, dependency rules, and forbidden authority collapses.
  Validation/0064 executed the contract runner with row_count=10,
  dependency_rule_count=7, dependency_errors=0, safety_flag_violations=0, and
  forbidden_authority_collapse_count=9.

latest completed risk:
  LocalDomainDeviceLease admission protocol. Analysis/0066 maps happy path,
  terminal failure paths, service/target mismatch handling, and revoke ordering
  to the observation contract. Formal/0043 plus validation/0065 safe TLC passed
  with 29 generated states, 21 distinct states, and depth 14. Unsafe configs
  reject compile after failed cluster checks, compile with service mismatch,
  compile with target mismatch, receipt before local lease, new receipt during
  revoke, reuse before revoke completion, and audit-only acceptance.

latest completed risk:
  Direct-call workqueue adapter refinement. Analysis/0084 and formal/0060
  split the workqueue side of the N-126 async carrier sketch. Validation/0098
  safe TLC passed with 16 generated states, 15 distinct states, and depth 15.
  Seventeen unsafe configs reject side effect before validate, pending
  overwrite, second-caller leak, delayed retime receipt refresh,
  self-requeue receipt refresh, worker identity authority, cancel/flush as
  monitor revoke receipt, release freeing Linux work, double settlement,
  freeze after publication, service-only budget, rescuer bypass, pending clear
  as monitor revoke receipt, ABI approval, behavior change, monitor
  verification claim, and protection claim.

latest completed risk:
  Direct-call io_uring adapter refinement. Analysis/0085 and formal/0061 split
  the io_uring side into request/resource/io-wq/reissue/CQE/cancel/free states.
  Validation/0099 safe TLC passed with 26 generated states, 24 distinct states,
  and depth 15. Nineteen unsafe configs reject side effect before validate,
  immutable overwrite, io_kiocb authority, io_wq_work authority, req
  creds/tctx/SQPOLL authority, io_rsrc_node authority, reissue receipt refresh,
  CQE settlement proof, cancel as monitor revoke receipt, double settlement,
  release dropping Linux refs, stale execution after revoke, implicit
  linked-request authority, resource update mutating in-flight authority,
  uring_cmd without endpoint authority, ABI approval, behavior change, monitor
  verification claim, and protection claim.

latest completed risk:
  Combined async-adapter precondition gate. Implementation/0013 and formal/0062
  reconcile N-126, N-127, and N-128 before any candidate Linux async-carrier
  patch proposal. Validation/0100 safe TLC passed with 10 generated states, 9
  distinct states, and depth 9. Eleven unsafe configs reject candidate patch
  before workqueue refinement, candidate patch before io_uring refinement,
  broad N-126 model alone, shared core as generic async subsystem,
  cross-adapter lifecycle collapse, Linux object authority, missing evidence
  split, ABI approval, behavior change, monitor verification claim, and
  protection claim. JSON gate check confirms 10/10 rows with required
  preconditions, forbidden fallbacks, required evidence, and patch
  preconditions; all safety flags remain false.

latest completed risk:
  Linux async-carrier patch scope plan. Implementation/0014 and formal/0063
  define the only next Linux async-carrier work that may be considered.
  Validation/0101 safe TLC passed with 9 generated states, 8 distinct states,
  and depth 8. Twelve unsafe configs reject Linux patch approval, workqueue
  hook, io_uring hook, direct-call ABI, public tracepoint ABI, callable
  prototype, object layout, runtime state, workqueue/io_uring include
  dependency, behavior change, monitor verification claim, and protection
  claim. JSON plan check confirms 3/3 allowed patch classes are no-behavior,
  4/4 blocked patch classes remain blocked, 7 no-behavior review requirements,
  10 workqueue blocker requirements, 13 io_uring blocker requirements, and
  9/9 safety flags false.

latest completed risk:
  Linux upstream maintenance gate. Analysis/0086 and formal/0064 make N-131 a
  negative gate: do not add a new Linux async-carrier patch now, including
  no-behavior opaque names. Upstream was fetched to 665159e246749, 340 commits
  after the L0 base. Watched-path drift was only
  kernel/sched/cpufreq_schedutil.c, classified D1 nearby non-intersecting
  drift. merge-tree --write-tree upstream/master capsched-linux-l0 exited 0.
  Validation/0102 safe TLC passed with 8 generated states, 8 distinct states,
  and depth 8. Ten unsafe configs reject approval without need, fetch,
  watched-diff review, merge-tree cleanliness, behavior change, hook, ABI,
  object layout, runtime state, and protection claim. JSON gate check confirms
  12 future patch gate requirements, 5 drift classes, 11 unsafe patterns, and
  12/12 safety flags false.

latest completed risk:
  Linux source-drift freshness gate. Analysis/0087, the source-drift runner,
  formal/0065, and validation/0103 turn upstream-following into a reusable
  gate. The current runner observed 340 upstream commits since the L0 base, one
  watched change in kernel/sched/cpufreq_schedutil.c under the
  scheduler_nearby_non_intersecting group, zero model-refresh-required groups,
  clean merge-tree, model_freshness=fresh, concrete_consumer_need=0,
  candidate_no_behavior_patch_reviewable=false, and linux_patch_approved=false.
  Validation/0103 safe TLC passed with 8 generated states, 8 distinct states,
  and depth 8. Nine unsafe configs reject patch without observation, clean merge
  as freshness, stale model patch, missing watch map, new Linux names without
  consumer, behavior change, ABI, protection claim, and missing non-claims.
  The first TLC attempt exposed missing invariants for watch-map-required
  classification and non-claims-required freshness decision; the final model
  rejects both.

latest completed risk:
  Linux source-map refresh target selection. Analysis/0088, formal/0066, and
  validation/0104 select scheduler_authority_core as the next source-only
  refresh target. It is not a Linux patch target. JSON check confirms 9
  candidates, exactly 1 selected target, selected_target=scheduler_authority_core,
  selected_target_linux_patch_target=false, 20 current upstream anchors, 9/9
  safety flags false, gate_input_linux_patch_approved=false, and
  gate_input_model_freshness=fresh. Validation/0104 safe TLC passed with 6
  generated states, 6 distinct states, and depth 6. Seven unsafe configs reject
  selection without gate, stale patch target, nearby non-intersecting drift as
  primary target, Linux patch approval, runtime claim, protection claim, and
  async Linux name movement.

latest completed risk:
  Scheduler authority core source-only refresh. Analysis/0025, analysis/0026,
  analysis/0028, formal/0012 README, linux-scheduler-authority-core-refresh-v1.json,
  and validation/0105 now map current upstream scheduler anchors. JSON check
  confirms 25 anchors, 8 refreshed rules, 4 updated artifacts, and 12/12 safety
  flags false. Existing formal/0012 was rechecked: 126113 states generated,
  17344 distinct states, 0 states left on queue, depth 21, exit 0. Key refreshed
  rules: enqueue_task is assertion/not fail-capable hook; TASK_WAKING after
  state write needs lost-wakeup model; current wake is continuation, not RunCap
  mint; delayed reenqueue is not authority mint; sched_tick charges rq->donor;
  pick validation must cover fast path/retry/class iteration/sched_ext; switch
  activation needs fail-closed DomainTag model.

latest completed risk:
  Scheduler authority refinement gate. Analysis/0089, formal/0067,
  scheduler-authority-refinement-gate-v1.json, and validation/0106 now compose
  the N-134 source refresh into a blocking gate for TASK_WAKING freeze,
  donor/current/proxy budget subject separation, and selected-state settlement.
  Safe TLC passed with 18 generated states, 14 distinct states, 0 states left
  on queue, depth 7. Unsafe configs produced expected counterexamples for
  TASK_WAKING before freeze, current-only proxy budget, run after retry, and
  run without class settlement. JSON check confirms 17 source anchors, 4 unsafe
  cases, and 13/13 safety flags false. Assurance evidence E-SCHED-REFINE-001
  supports EXEC-001 and BUDGET-001 only as model evidence.

latest completed risk:
  Runtime charge subject gate. Analysis/0090, formal/0068,
  runtime-charge-subject-v1.json, and validation/0107 now model
  NoUnspecifiedRuntimeCharge across scheduler runtime surfaces. Safe TLC passed
  with 79 generated states, 48 distinct states, 0 states left on queue, depth
  4. Unsafe configs produced expected counterexamples for unspecified runtime
  charge, class runtime as root authority, proxy runtime without ticket, remote
  tick proxy authority, task_sched_runtime as authority, and CFS proxy without
  donor/cgroup charge. JSON check confirms 15 source anchors, 6 unsafe cases,
  and 12/12 safety flags false. Assurance evidence E-SCHED-RUNTIME-001 supports
  BUDGET-001 only as model evidence.

latest completed risk:
  Scheduler server-ticket gate. Analysis/0091, formal/0069,
  scheduler-server-ticket-v1.json, and validation/0108 now model fair/ext/DL
  server-borrow tickets, RT bandwidth and SCX slice non-authority, fresh server
  epochs, live server state, lower task authority, and monitor root budget.
  Safe TLC passed with 39 generated states, 24 distinct states, 0 states left
  on queue, depth 6. Unsafe configs produced expected counterexamples for
  server pick without ticket, server runtime as root authority, RT bandwidth as
  root authority, SCX slice as root authority, server replenish without epoch,
  server stop with live ticket, and lower task without authority. JSON check
  confirms 17 source anchors, 7 unsafe cases, and 12/12 safety flags false.
  Assurance evidence E-SCHED-SERVER-001 supports EXEC-001 and BUDGET-001 only
  as model evidence.

latest completed risk:
  Runtime coverage gate. Analysis/0092, formal/0070,
  runtime-coverage-gate-v1.json, and validation/0109 now define trace-only
  coverage acceptance criteria for current/donor/proxy/server runtime paths.
  Safe TLC passed with 49 generated states, 29 distinct states, 0 states left
  on queue, depth 6. Unsafe configs produced expected counterexamples for
  missing current, missing donor, missing proxy relation, missing server
  coverage, missing evidence class, sched_stat_runtime as authority, remote
  tick as proxy coverage, trace evidence as protection, server lifecycle-only
  coverage, and class runtime as root budget evidence. JSON check confirms 33
  source anchors, 12 coverage requirements, 10 unsafe cases, and 12/12 safety
  flags false. Assurance evidence E-SCHED-COVERAGE-001 supports BUDGET-001 and
  COMPAT-001 only as model evidence.

latest completed risk:
  Monitor root budget timer gate. Analysis/0093, formal/0071,
  monitor-root-budget-timer-v1.json, and validation/0110 now model the
  production CPU budget root as monitor-owned timer/deadline state, not Linux
  hrtick, sched_tick, hrtimer, NO_HZ, or runtime charge reports. Safe TLC
  passed with 78 generated states, 37 distinct states, 0 states left on queue,
  depth 7. Unsafe configs produced expected counterexamples for running without
  monitor timer, running without root budget, Linux timer as root authority,
  overrun after budget expiry, Linux charge as monitor charge, activation
  without sealed token, running after epoch revoke, running after monitor
  interrupt, NO_HZ stopping monitor timer, and protection claim without
  implementation. JSON check confirms 25 source anchors, 12 monitor event
  requirements, 10 unsafe cases, and 12/12 safety flags false. Assurance
  evidence E-MONITOR-TIMER-001 supports ACT-001 and BUDGET-001 only as model
  evidence.

latest completed risk:
  Server epoch relation gate. Analysis/0094, formal/0072,
  server-epoch-relation-v1.json, and validation/0111 now refine server-borrow
  authority across Linux DL/fair/ext server lifecycle changes. Safe TLC passed
  with 107 generated states, 32 distinct states, 0 states left on queue, depth
  6. Unsafe configs produced expected counterexamples for stale ticket after
  replenish, ticket surviving server swap, server-kind mismatch after swap,
  ticket surviving stop, pick without fresh ticket, lower task without
  authority, Linux runtime as authority, parameter update keeping a ticket, CPU
  teardown keeping a running ticket, and protection claim without
  implementation. JSON check confirms 44 source anchors, 13 server epoch
  boundaries, 8 fresh ticket requirements, 10 unsafe cases, and 13/13 safety
  flags false. Assurance evidence E-SCHED-SERVER-EPOCH-001 supports EXEC-001
  and BUDGET-001 only as model evidence.

next focused risk:
  Deadline CBS/GRUB compatibility source refresh before behavior hooks, F1
  admission-freeze data dependency refresh, monitor timer architecture
  substrate comparison for x86 VMX-root and arm64 EL2, and integration of the
  server epoch relation into the wider LinuxSchedulerAuthority model. Do
  not add direct-call stubs, ABI, tracepoints, workqueue integration, io_uring
  integration, async carrier Linux names, budget hooks, or behavior-changing
  patches.
```

That focused VF IRQ model is now checked:

```text
formal/0032 + validation/0052:
  safe TLC passed with 25 generated states, 22 distinct states, depth 6
  unsafe counterexamples:
    VF host-sync assumption
    stale completion after revoke
    reassignment without owner-specific IRQ quiescence
    host-owned reassignment without synchronize_irq()
    monitor-owned reassignment without monitor invalidation

design rule:
  ICE_VSI_VF synchronize_irq skip is not a QueueLease revoke proof.
  Host-owned, VF-owned, and monitor-owned IRQ quiescence must be separated.
  CapSched-H needs monitor-visible IRQ route invalidation or a separately
  modeled VF route handoff before queue reassignment.
```

The monitor IRQ route invalidation map/model is now checked:

```text
analysis/0054:
  maps ice, VFIO PCI, iommufd, PCI/MSI, generic MSI domain, and x86 Intel
  interrupt-remapping source anchors.

formal/0033 + validation/0053:
  safe TLC passed with 14 generated states, 12 distinct states, depth 8
  unsafe counterexamples:
    unsafe interrupt override / allow_unsafe_interrupts-style route
    VFIO eventfd delivery after revoke
    reassignment without invalidation receipt
    receipt without interrupt-entry-cache flush
    receipt with posted interrupt state
    receipt with eventfd still live

design rule:
  IRQ revoked is not eventfd detached, free_irq(), pci_free_irq_vectors(),
  irq_remapping_enabled, or IRTE clear alone. It needs a monitor-visible
  receipt covering isolated MSI, route tag/epoch, delivery endpoint quarantine,
  Linux IRQ/MSI teardown, IRTE/equivalent clear, IEC/equivalent flush, and
  posted interrupt teardown.
```

The monitor DMA/IOMMU/MemoryView invalidation map/model is now checked:

```text
analysis/0055:
  maps ice, DMA API, IOMMU core, iommufd, VFIO type1, and arch-IOMMU
  invalidation substrate.
  key source hazards:
    ice_qp_dis() uses one-Rx-ring disable with wait=false before ring cleanup
    IOMMU group core-domain return is blocking only while an owner exists;
      otherwise default DMA domain can be restored
    dma-iommu may split unmap from IOTLB sync through queued flush
    iommufd/VFIO distinguish access-user invalidation, unmap, unpin, and page
      release

formal/0034 + validation/0054:
  safe TLC passed with 17 generated states, 17 distinct states, depth 17
  unsafe counterexamples:
    IRQ-only queue reassignment
    driver-unmap-only receipt
    IOMMU unmap without IOTLB sync
    queued flush treated as receipt
    PageOwner transfer with DMA in flight
    new MemoryView before old unmap
    normal completion after revoke
    packet page return before receipt

design rule:
  DMA revoked is not IRQ revoked, ring cleanup, dma_unmap_*(), XSK pool unmap,
  VFIO/iommufd unmap, iommu_unmap_fast(), queued flush, page unpin, or refcount
  release. It needs a monitor-visible receipt covering monitor-owned DMA root,
  new-work embargo, hardware queue quiescence, HW descriptor drain, access-user
  release, IOMMU translation removal, completed IOTLB invalidation, old
  device-domain/PASID fence, outstanding DMA drain, stale completion
  quarantine, and old MemoryView unmap.

analysis/0056 + formal/0035 + validation/0055:
  XSK/page-pool stale completion quarantine substrate mapped and modeled.
  source substrate:
    ice AF_XDP Tx completion and cleanup xsk_tx_completed() paths
    ice xsk_buff_free() cleanup paths
    AF_XDP CQ reservation/submission and XSK free-list return
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
    packet memory return is not xsk_tx_completed(), xsk_buff_free(),
    page_pool recycle, or DMA receipt alone. It needs stale completion
    classification, XSK/page-pool quarantine or explicit policy delivery,
    generation reset/retag, and a single settlement path.

analysis/0057 + formal/0036 + validation/0056:
  Representor lower QueueLease derivation substrate mapped and modeled.
  source substrate:
    ice representor ndo_start_xmit and ice_eswitch_port_start_xmit()
    metadata_dst port_id and lower_dev binding
    dev_queue_xmit(), TC/BPF redirect, bridge/FDB/VLAN/switchdev paths
    ice TC flower redirect/mirror offload and hardware rule install/delete
    LAG lower_dev update and representor Tx queue stop
  safe TLC:
    14 generated states, 8 distinct states, depth 4
  unsafe counterexamples:
    representor netdev-only lower forwarding
    bridge FDB as lower lease
    VLAN as lower lease
    TC/offload rule install without control authority
    TC/offload stale destination
    LAG stale lower_dev forwarding
    forwarding after revoke
    representor stop as lower QueueLease revoke
  design rule:
    lower queue authority is not representor netdev reachability, metadata_dst,
    bridge FDB/VLAN success, TC redirect target, switchdev mark, LAG rewrite,
    or representor queue stop. It needs a frozen RepresentorForward-to-lower
    QueueLease carrier, and TC/switchdev offload needs QueueControl/Offload
    authority plus stale-rule invalidation on revoke.

analysis/0058 + formal/0037 + validation/0057:
  Modern NIC ServiceWork carrier substrate mapped and modeled.
  source substrate:
    ice_service_task_schedule() coalesces pf->serv_task through
    ICE_SERVICE_SCHED
    ice_service_task() processes reset, AdminQ, MailboxQ, SidebandQ, MDD,
    VFLR, filters, FDir, watchdog, and aux-device events
    VF virtchnl queue-control handlers configure queue DMA addresses, IRQ
    maps, queue bandwidth/quanta, and FDIR-like effects
    PTP/DPLL deferred workers and bridge/eswitch/LAG work apply service or
    caller-visible control/offload effects
  safe TLC:
    29 generated states, 18 distinct states, depth 5
  unsafe counterexamples:
    service-worker ambient queue effects
    VF mailbox effect without a carrier
    coalesced service loop using last-caller authority
    PTP control without a carrier
    DPLL control without a carrier
    bridge/offload effect without policy and control authority
    LAG rebind without fresh lower QueueLease
    reset/rebuild replay after revoke without fresh authorization
  design rule:
    worker identity, ICE_SERVICE_SCHED, virtchnl opcode allowlists, PTP/DPLL
    callback reachability, bridge/FDB events, LAG lower_dev rewrites, and reset
    replay are not caller, queue, control, offload, DMA, IRQ, or lower
    QueueLease authority. Authority is per-effect service/caller intersection
    plus fresh epochs and budget.

next focused risk:
  VF mailbox QueueControl/DMA/IRQ carrier semantics. The highest-risk source
  anchor is ice_vc_cfg_qs_msg() copying VF-provided DMA ring addresses into
  queue state before queue enable/configuration.

analysis/0059 + formal/0038 + validation/0058:
  VF mailbox queue/DMA/IRQ/budget/FDIR carrier substrate mapped and modeled.
  source substrate:
    ice_vc_process_vf_msg() validates virtchnl messages and opcode allowlists
    ice_vc_cfg_qs_msg() copies VF-provided tx/rx dma_ring_addr into ring state
    ice_setup_tx_ctx() and ice_setup_rx_ctx() put ring->dma into HW queue base
    ice_vc_cfg_irq_map_msg() maps VF vectors to queue interrupts
    ice_vc_cfg_q_bw() and ice_vc_cfg_q_quanta() program queue shaping
    ice_vc_add_fdir_fltr()/del plus ctx_irq/ctx_done complete asynchronously
  safe TLC:
    42 generated states, 23 distinct states, depth 7
  unsafe counterexamples:
    virtchnl validation/opcode allowlist as queue authority
    DMA ring base without MemoryView/IOMMU authority
    queue enable without frozen queue config
    IRQ map without route authority
    queue budget/quanta without budget authority
    FDIR write without OffloadCap
    FDIR completion without frozen context
    queue/FDIR effects after revoke
  design rule:
    VF mailbox effects need VFRequestCarrier plus effect-specific
    QueueConfig, QueueEnable, IrqRoute, QueueBudget, or FdirOffload carrier.
    virtchnl validation, opcode allowlist, dma_ring_addr, queue/vector checks,
    QoS caps, and FDIR ctx_done are not authority.

analysis/0060 + formal/0039 + validation/0059:
  ICE VF epoch handoff substrate mapped and modeled.
  source substrate:
    ice_get_vf_by_id() and ice_vf lifetime through RCU/kref
    vf->cfg_lock and ICE_VF_STATE_ACTIVE/DIS as Linux protocol state
    ice_reset_vf(), ice_reset_all_vfs(), ice_free_vfs(), and VFLR processing
    lan_vsi_idx/ctrl_vsi_idx reuse and FDIR ctrl VSI release/reinit
    VPINT/VPLAN/GLINT vector and queue mapping clear/reprogram paths
    VF-provided DMA ring base and queue/IRQ configuration
    FDIR ctx_irq/ctx_done timer/IRQ/service completion
    mailbox dispatch and reset/rebuild service replay
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
    VF handoff is not vf_id equality, ice_vf pointer reachability, cfg_lock,
    ACTIVE/DIS state, stable VSI index, queue id, vector id, allowlist state,
    VPINT/VPLAN programming, or reset completion. It requires mailbox embargo,
    queue quiescence, DMA/IRQ revoke receipts, FDIR context clear or epoch-tag,
    VF epoch bump, VSI/QueueLease generation bump, fresh Domain binding, and
    fresh service replay authority.

analysis/0061 + formal/0040 + validation/0060:
  Modern NIC HyperTag Monitor interface and service/driver Domain split mapped
  and modeled.
  architecture split:
    HyperTag Monitor owns Domain epochs, MemoryViews/PageOwner roots, device DMA
    roots, QueueTag/QueueLease epochs, IRQ route tags, VF/SF binding epochs,
    root budgets, sealed receipt keys, and immutable audit roots.
    Linux service/driver Domain owns virtchnl/devlink/TC/switchdev policy,
    PF driver sequencing, netdev/NAPI/ring/q_vector lifecycle, reset/rebuild,
    PTP/DPLL/GNSS workers, and hardware programming substrate.
    target Domains receive typed endpoints only: QueueSubmit, DescriptorLedger,
    Completion, VFMailbox, QueueConfig/Enable/Budget, IrqRoute, QueueControl,
    RepresentorForward, Offload, PTP, and DPLL as granted.
  safe TLC:
    10 generated states, 10 distinct states, depth 10
  unsafe counterexamples:
    service Domain mints monitor roots
    Linux DMA state used as DMA receipt
    Linux IRQ state used as IRQ receipt
    raw PF/VF/IOMMU/MSI/devlink endpoint exposed to target Domain
    queue activation without DMA, IRQ, and ledger receipts
    service replay under an old epoch
    remote cluster lease used directly without local monitor compilation
    audit-only monitor calls
    per-packet monitor traps on ordinary data-plane submission
  design rule:
    service policy, Linux driver state, VF mailbox validity, DMA API/IOMMU
    teardown, IRQ teardown, queue/VSI/vector ids, reset completion, remote lease
    text, and audit logs are not monitor authority. Ordinary packet submission
    must be fast-path local after bind; monitor entry is for bind, config,
    revoke, epoch, budget, and ownership changes.

analysis/0062 + implementation/0007 + formal/0041 + validation/0061:
  Modern NIC HyperTag implementation-readiness gate mapped and modeled.
  gate rule:
    every required LocalDomainDeviceLease, DeviceRootReceipt, VfEpochReceipt,
    QueueLeaseReceipt, DmaMemoryViewReceipt, IrqRouteReceipt, LedgerRootReceipt,
    typed endpoint carrier, and revoke/handoff receipt must map to observation-
    only Linux probes or inert stubs.
    each row must preserve:
      observation_only=true
      authority_claim=false
      monitor_verified=false
      behavior_change=false
      protection_claim=false
  safe TLC:
    8 generated states, 7 distinct states, depth 7
  unsafe counterexamples:
    behavior-changing approval before gate satisfaction
    probe treated as authority
    stub changes behavior
    missing receipt/carrier coverage
    raw endpoint exposed by stub
    readiness evidence described as protection evidence
  design rule:
    a probe or stub may help find future receipt consumption points, but cannot
    be a receipt, authority, monitor verification, or protection claim.

analysis/0063 + validation/0062:
  Modern NIC HyperTag observation ledger and no-code source runner added.
  runner:
    validation/run-modern-nic-hypertag-observation-ledger.sh
  latest run:
    build/modern-nic-hypertag-observation-ledger/20260630T044602Z
  result:
    ledger_rows=37
    available_rows=36
    missing_rows=1
    gap_rows=1
    safety_flag_violations=0
    observation_only=true
    authority_claim=false
    monitor_verified=false
    behavior_change=false
    protection_claim=false
  only missing row:
    LocalDomainDeviceLease is outside upstream Linux and remains a high-severity
    external root-management/local monitor compilation gap.

next focused risk:
  Resolve the LocalDomainDeviceLease external gap and choose whether the next
  step is a privileged no-code tracefs run, an inert Linux probe/stub proposal,
  or a root-management/local monitor admission model. No behavior-changing Linux
  patch is approved.
```
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

assurance/0002:
  Modern NIC QueueLease assurance map completed
  human-readable map:
    assurance/0002-modern-nic-queuelease-assurance-map.md
  machine-readable map:
    assurance/modern-nic-queuelease-subclaims-v1.json
  claims registry:
    assurance/claims.json now records DEV-NIC-001 through DEV-NIC-010
  subclaims:
    QueueBind; typed SKB/XDP/XDP_TX/AF_XDP submit classes; DescriptorLedger;
    DMA packet memory ownership; CompletionSettlement; QueueControl;
    RepresentorForward; ServiceWork/async provenance; RevokeSemantics; Linux
    substrate compatibility
  gate result:
    authority-class separation is model-supported; Intel ice anchors are
    source-observed; trace/readiness evidence is observation-only; production
    protection is not evidenced; implementation is not approved.
  forbidden:
    do not treat netdev/ring/q_vector/devlink/representor/tracepoint/workqueue
    state as modern NIC QueueLease authority; do not collapse SKB, XDP,
    AF_XDP, control, representor, and service classes into one capability.

formal/0031 + validation/0050:
  Modern NIC queue revoke model checked
  model:
    formal/0031-modern-nic-queue-revoke-model/ModernNicQueueRevoke.tla
  validation:
    validation/0050-modern-nic-queue-revoke-tlc.md
  safe result:
    PASS, 7 generated states, 7 distinct states, depth 5
  unsafe counterexamples:
    submit after revoke
    completion delivery after revoke
    QueueControl after revoke
    RepresentorForward after revoke
    service work after revoke
    ledger clear before DMA drain
    queue reassignment before drain/quarantine
    queue reassignment without IOMMU/IRQ invalidation
    quarantined delivery
  key rule:
    revoke is not netdev down/reset. Revoke means block new submit, bump queue
    epoch, mask IRQ, drain or quarantine typed outstanding state, invalidate
    IOMMU/DMA reachability, prevent stale completion/control/representor/service
    effects, and only then reassign under a new epoch.

analysis/0053:
  Intel ice modern NIC revoke source map completed
  machine-readable map:
    analysis/ice-modern-nic-revoke-source-map-v1.json
  useful anchors:
    ice_down(), ice_vsi_dis_irq(), ice_napi_disable_all(),
    ice_vsi_stop_lan_tx_rings(), ice_vsi_stop_xdp_tx_rings(),
    ice_vsi_stop_all_rx_rings(), ice_clean_tx_ring(), ice_clean_rx_ring(),
    ice_xsk_clean_rx_ring(), ice_xsk_clean_xdp_ring(), ice_qp_dis(),
    ice_qp_ena(), ice_prepare_for_reset(), ice_service_task_stop(),
    ice_eswitch_stop_all_tx_queues(), ice_repr_stop_tx_queues(), and devlink
    reload down/up.
  hard gaps:
    no QueueTag or queue epoch root; no typed SubmitLedger, DescriptorLedger,
    or CompletionSettlement id; no monitor-owned IOMMU/MemoryView invalidation;
    no stale XSK/page-pool completion quarantine distinction; no VF IRQ
    ownership proof for the synchronize_irq exception; no
    RepresentorForward-to-lower-QueueLease revoke proof; no typed service-work
    carrier implementation; no service/caller budget charging rule; no
    reset/rebuild replay reauthorization implementation; no old/new epoch
    reassignment proof.
```

Next work remains analysis-first: map and model VF mailbox QueueControl,
DMA ring-address, IRQ-route, queue-budget, and FDIR/offload carrier semantics
before any behavior-changing driver or workqueue hook. The older post-exec gaps
also remain: eventfd kernel signal provenance, epoll delivery/watched-endpoint
correlation, io_uring fixed-file consumption, and execfd handoff before
behavior-changing endpoint hooks.
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

Latest traceability work:

```text
N-108 completed:
  capsched-models/traceability/check-project-source-map-drift.sh

latest run:
  build/traceability-project-drift/20260630T235533Z

result:
  json_artifacts_scanned=15
  anchor_rows=515
  ok_rows=501
  gap_rows=14
  symbol_missing_rows=0
  pattern_missing_rows=0
  semantic_recheck_required_rows=0
  unsupported_extraction_rows=3
  safety_flag_violations=0
  content_source=git_HEAD_objects
  source_path_pattern_only=true
  semantic_validation=false

resolved by N-111:
  ice_alloc_vfs was replaced with ice_create_vf_entries.
  inert translation unit was replaced with literal source pattern
  This translation unit is intentionally inert.

resolved by N-112:
  all remaining line-only anchors in e1000e, ice, and usbnet source maps were
  replaced with symbol-bearing anchors or corrected symbol-bearing line
  anchors.

important caution:
  bare line-only anchors are semantic_recheck_required, not ok merely because
  the file exists.

next:
  N-109 completed central overlay ledger normalization.
```

Do not read N-108 `ok_rows` as semantic validation, monitor verification, or
protection evidence. It is path/pattern drift triage only.

Latest overlay ledger normalization:

```text
N-109 completed:
  capsched-models/traceability/build-project-overlay-ledger.sh

latest run:
  build/traceability-overlay/20260630T235558Z

result:
  overlay_rows=515
  ok_rows=501
  gap_rows=14
  needs_semantic_recheck_rows=0
  line_only_rows=0
  symbol_rows=397
  pattern_rows=37
  n_series_rewrite=false
  semantic_validation=false

next:
  N-110 completed semantic recheck queue/workflow.
```

Latest semantic recheck queue:

```text
N-110 completed:
  capsched-models/traceability/semantic-recheck-workflow-v1.md
  capsched-models/traceability/build-semantic-recheck-queue.sh

latest run:
  build/semantic-recheck/20260630T235623Z

result:
  semantic_recheck_items=0
  gap_items=14
  line_only_anchor_items=0
  symbol_missing_items=0
  pattern_missing_items=0
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
  capsched-models/traceability/classify-project-gaps.sh

latest run:
  build/traceability-gap-classification/20260701T000823Z

result:
  gap_rows=14
  semantic_gap_groups=7
  duplicate_groups=7
  future_linux_anchor_groups=5
  future_test_anchor_groups=1
  trace_plan_groups=1
  unknown_gap_rows=0
  safety_flag_violations=0
  semantic_validation=false
  implementation_approval=false

next:
  N-114 completed direct-call gap-closure design/model.
```

Latest direct-call gap closure model:

```text
N-114 completed:
  analysis/0078-direct-call-gap-closure-design.md
  formal/0055-direct-call-gap-closure-model/DirectCallGapClosure.tla

validation:
  validation/0086-direct-call-gap-closure-tlc.md

logs:
  build/tlc/direct-call-gap-closure-20260701T001620Z

safe TLC:
  6 generated states
  5 distinct states
  depth 5

unsafe counterexamples:
  stub before gap closure
  Linux canonical envelope
  entry without monitor schema
  Linux schema decision
  timeout shadow refresh
  control revoke bypass
  trace plan as coverage
  test hook live effect
  ABI approval
  behavior change
  monitor verification claim
  protection claim

next:
  N-115 completed implementation-facing direct-call closure gate.
```

Latest direct-call implementation gate:

```text
N-115 completed:
  implementation/0009-direct-call-gap-closure-gate.md
  implementation/direct-call-gap-closure-gate-v1.json

gate rows:
  DCGATE-004 request envelope
  DCGATE-005 direct-call entry/backend
  DCGATE-006 schema negotiation
  DCGATE-007 response shadow
  DCGATE-008 control revoke lane

side gates:
  DCGATE-009 test-only failure injection
  DCGATE-010 trace-only observation

next:
  N-116 completed monitor-owned receipt schema/model.
```

Latest direct-call receipt schema:

```text
N-116 completed:
  analysis/0079-direct-call-monitor-receipt-schema.md
  analysis/direct-call-monitor-receipt-schema-v1.json
  formal/0056-direct-call-receipt-schema-model/DirectCallReceiptSchema.tla
  validation/0087-direct-call-receipt-schema-tlc.md

safe TLC:
  10 generated states
  9 distinct states
  depth 9

receipt families:
  RequestImageReceipt
  SchemaReceipt
  EntryResultReceipt
  ResponseHandleReceipt
  RevokeReceipt

next:
  N-117 completed receipt-consumer source mapping.
```

Latest direct-call receipt-consumer source map:

```text
N-117 completed:
  analysis/0080-direct-call-receipt-consumer-source-map.md
  analysis/direct-call-receipt-consumer-source-map-v1.json
  validation/0088-direct-call-receipt-consumer-source-map-result.md

row shape:
  27 total rows
  20 current source anchors
  7 preserved future gap/plan rows

latest project drift:
  build/traceability-project-drift/20260701T020900Z
  542 anchors
  521 ok rows
  21 gap rows
  0 missing symbols or patterns
  0 safety violations

latest gap classification:
  build/traceability-gap-classification/20260701T020955Z
  21 gap rows -> 7 semantic direct-call gap groups

next:
  N-118 completed receipt-consumer placement model.
```

Latest direct-call receipt-consumer placement model:

```text
N-118 completed:
  formal/0057-direct-call-receipt-consumer-placement-model/
  validation/0089-direct-call-receipt-consumer-placement-tlc.md

safe TLC:
  10 generated states
  9 distinct states
  0 states left on queue

unsafe counterexamples:
  Linux-minted receipt
  Linux shadow authority
  hot-path direct call
  policy schema authority
  generic async consume
  future gap implemented
  stale consume after revoke
  trace coverage claim
  ABI approval
  behavior change
  monitor verification claim
  protection claim

next:
  N-119 completed implementation-facing no-patch placement gate.
```

Latest direct-call receipt-consumer placement gate:

```text
N-119 completed:
  implementation/0010-direct-call-receipt-consumer-placement-gate.md
  implementation/direct-call-receipt-consumer-placement-gate-v1.json
  validation/0090-direct-call-receipt-consumer-placement-gate-result.md

gate rows:
  DCPGATE-001 receipt provenance root
  DCPGATE-002 hot-path bounded consumption
  DCPGATE-003 policy and lifecycle separation
  DCPGATE-004 generic async exclusion
  DCPGATE-005 future gap preservation
  DCPGATE-006 revoke and shadow invalidation
  DCPGATE-007 evidence class split

next:
  N-120 typed async carrier model for workqueue/io_uring receipt safety.
```

Latest direct-call async carrier model:

```text
N-120 completed:
  formal/0058 DirectCallAsyncCarrier
  validation/0091

subagent review fix:
  first draft was too flag-like for pending coalescing and revoke handling.
  final model has explicit callerA/callerB, ticketA/ticketB, receiptA/receiptB,
  carrier generation preservation, coalesced-second-caller rejection, and a
  revoked-pending-carrier terminal rejection path.

safe TLC:
  build/tlc/direct-call-async-carrier-20260701T023933Z
  15 generated states
  13 distinct states
  depth 12

unsafe counterexamples:
  15 expected violations, including PendingCarrierPreserved for pending carrier
  replacement and NoStaleCarrierExecution for stale revoked execution.

still not:
  Linux implementation
  ABI approval
  runtime coverage
  behavior change
  monitor verification
  production protection

next:
  N-121 implementation-facing no-patch async-carrier gate.
```

Latest direct-call async-carrier gate:

```text
N-121 completed:
  implementation/0011-direct-call-async-carrier-gate.md
  implementation/direct-call-async-carrier-gate-v1.json
  validation/0092-direct-call-async-carrier-gate-result.md

gate rows:
  DCASYNC-001 typed carrier identity
  DCASYNC-002 pending coalescing preservation
  DCASYNC-003 caller BudgetTicket ownership
  DCASYNC-004 service/caller intersection
  DCASYNC-005 monitor receipt provenance
  DCASYNC-006 revoke/stale-carrier rejection
  DCASYNC-007 workqueue patch boundary
  DCASYNC-008 io_uring patch boundary
  DCASYNC-009 evidence class split

validation:
  9/9 rows have required preconditions, forbidden fallbacks, and patch
  preconditions.

still not:
  Linux implementation
  workqueue integration
  io_uring integration
  ABI approval
  runtime coverage
  behavior change
  monitor verification
  production protection

next:
  N-122 source-map workqueue and io_uring separately before code.
```

Latest direct-call async source maps:

```text
N-122 completed:
  analysis/0081-direct-call-async-workqueue-io-uring-source-map.md
  analysis/direct-call-async-workqueue-source-map-v1.json
  analysis/direct-call-async-io-uring-source-map-v1.json
  validation/0093-direct-call-async-source-map-result.md

rows:
  workqueue: 19 current Linux anchors
  io_uring: 18 current Linux anchors

drift:
  build/traceability-project-drift/20260701T025605Z
  579 total anchors
  558 ok rows
  21 preserved gap rows
  0 missing symbols/patterns
  0 semantic recheck rows
  0 safety violations

meaning:
  generic work_struct/pending/callback/worker/flush/cancel state is not
  authority.
  io_kiocb and io_rsrc_node are plausible future storage anchors, but current
  req->creds, req->tctx, io_wq_work, registered-resource liveness, cancel flags,
  CQEs, completion, and retry are not monitor receipt authority.

still not:
  Linux implementation
  workqueue integration
  io_uring integration
  ABI approval
  runtime coverage
  behavior change
  monitor verification
  production protection

next:
  N-123 carrier lifetime table before async carrier code.
```

Latest direct-call async carrier lifetime table:

```text
N-123 completed:
  analysis/0082-direct-call-async-carrier-lifetime-table.md
  analysis/direct-call-async-carrier-lifetime-table-v1.json
  validation/0094-direct-call-async-lifetime-table-result.md

rows:
  22 total obligation rows
  11 workqueue stages
  11 io_uring stages

stages:
  allocate
  freeze
  bind_service_or_resource
  enqueue
  coalesce_or_link
  pending_protect
  execute
  cancel_or_revoke
  retry_or_reissue
  complete
  free

validation:
  22/22 rows have known stages, source-map refs, forbidden collapses,
  patch preconditions, and non-claim safety flags.

still not:
  Linux implementation
  workqueue integration
  io_uring integration
  ABI approval
  runtime coverage
  behavior change
  monitor verification
  production protection

N-124 completed:
  ADR-0009-async-carrier-api-direction.md
  analysis/0083-direct-call-async-carrier-api-direction.md
  analysis/direct-call-async-carrier-api-direction-v1.json
  validation/0095-direct-call-async-carrier-api-direction-result.md

decision:
  choose shared internal capsched_async_carrier semantic core
  with per-subsystem workqueue and io_uring adapters.

shared core:
  frozen caller authority
  caller BudgetTicket or split child ticket
  opaque monitor receipt reference or derived shadow
  caller Domain/epoch/generation
  service or resource authority binding
  carrier generation
  revoke/freshness state
  settlement/release state

not shared:
  workqueue pending/coalescing/delayed-work/callback/free mechanics
  io_uring SQE/request/resource/io-wq/reissue/CQE/refcount mechanics

hard guardrail:
  shared core must not become generic async execution authority.

still not:
  Linux implementation
  workqueue integration
  io_uring integration
  ABI approval
  runtime coverage
  behavior change
  monitor verification
  production protection

N-125 completed:
  implementation/0012-direct-call-async-carrier-api-sketch.md
  implementation/direct-call-async-carrier-api-sketch-v1.json
  validation/0096-direct-call-async-carrier-api-sketch-result.md

sketch:
  internal opaque capsched_async_carrier core
  operations: freeze, bind, validate, revoke_check, settle, release
  8 authority fields
  single-assignment frozen and bind tuples
  core/adapter ownership boundary
  exactly-once BudgetTicket/receipt settlement pressure
  separate workqueue and io_uring adapter contracts

added after subagent review:
  release drops CapSched refs only, not Linux object lifetime.
  rejected second-caller carrier must be settled/released exactly once.
  effective authority must be modeled as set intersection.
  io_uring obligations still need a dedicated refinement model.

validation:
  8 authority fields
  6 core operations
  2 adapter contracts
  18 adapter steps
  15 invariants
  18 forbidden authority sources
  14 patch preconditions
  5 required future models
  12/12 safety flags false

still not:
  Linux implementation
  workqueue integration
  io_uring integration
  ABI approval
  runtime coverage
  behavior change
  monitor verification
  production protection

N-126 completed:
  formal/0059-direct-call-async-carrier-api-sketch-model/
  validation/0097-direct-call-async-carrier-api-sketch-tlc.md

safe TLC:
  25 generated states
  23 distinct states
  depth 12

safe paths:
  workqueue:
    create, freeze, bind, publish, coalescing handled, revoke_check, validate,
    side effect, settle, release, accept.
  io_uring:
    create, freeze, bind, request prepared, reissue handled, revoke_check,
    validate, side effect, settle, release, accept.

unsafe counterexamples:
  side effect before validate
  immutable overwrite
  second-caller leak
  pending overwrite
  double settlement
  release dropping Linux refs
  CQE settlement proof
  reissue receipt refresh
  bad authority intersection
  Linux object authority
  ABI approval
  behavior change
  monitor verification claim
  protection claim

still not:
  Linux implementation
  workqueue integration
  io_uring integration
  ABI approval
  runtime coverage
  behavior change
  monitor verification
  production protection

next:
  N-127 split io_uring and workqueue refinements before any Linux code proposal.
```
