# AI Handoff

Updated: 2026-07-14

Read this first when resuming the project.

Naming freeze:

```text
public umbrella name:
  DomainLease-Linux

legacy private modeling name:
  CapSched-Linux

scheduler core:
  SchedExecLease

Linux-facing scaffold:
  sched_exec_lease
```

N-156 keeps old names as historical aliases only. Claim IDs, evidence IDs,
counterexample IDs, and old TLA module/file names remain stable.

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
history mirror. It stores upstream base metadata, the private DomainLease Linux
patch series, and a recreate script. The local full Linux working tree remains
under `linux/`, but it is not committed into the superproject.

Recreate a fresh or disposable Linux tree from the patch queue with:

```sh
./linux-patches/scripts/recreate-capsched-linux-l0.sh ./linux-replay
```

Do not run this against the current `./linux` tree unless intentionally
normalizing it to the patch-queue replay commit. The current local Linux HEAD
and the patch-queue replay HEAD have the same tree but different commit IDs
because of commit-date normalization after `0011`.

Upstream Linux has been fetched into sibling repository `linux/`. Slice 0A and
Slice 0B were committed under the legacy `CONFIG_CAPSCHED` scaffold. N-156 is
renaming the inert Linux scaffold to `CONFIG_SCHED_EXEC_LEASE`,
`include/linux/sched_exec_lease.h`, and `kernel/sched/exec_lease.c`. No
behavior-changing scheduler patch points are accepted yet.

Current local Linux work branch `capsched-linux-l0` is at:

```text
bd71af5daeae808ac948cbd12af2663151936f22
```

That head includes P5A-R `0012`, the experimental forced-pickable-progress
draft. Validation/0186 passed only the synthetic ordinary-CFS test-only
negative QEMU workload. Validation/0187 keeps production acceptance blocked.

Patch queue recreation normalizes commit metadata and therefore ends at a
different commit ID with the same tree:

```text
patch_queue_replay_head:
  1b572a3fad95b78f4ee89061ba441f77cf24e297
tree:
  25dbe4e04baa112ab9a872a897f67bec094df209
local_linux_head:
  bd71af5daeae808ac948cbd12af2663151936f22
```

Validation/0188 records this distinction and the passing replay. `0009` through
`0012` remain experimental. No production runtime denial, complete CFS
deny-and-repick, runtime coverage, protection, cost, deployment, or datacenter
claim is accepted.

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

latest completed risk:
  Deadline CBS/GRUB compatibility gate. Analysis/0095, formal/0073,
  deadline-cbs-grub-compat-v1.json, and validation/0112 now model Linux
  SCHED_DEADLINE admission, CBS runtime/replenishment, GRUB reclaim, inactive
  timers, dynamic sched_getattr, and overrun notification as compatibility
  policy or observation surfaces rather than CapSched authority. Safe TLC
  passed with 70 generated states, 27 distinct states, 0 states left on queue,
  depth 10. Unsafe configs produced expected counterexamples for admission
  minting run authority, CBS replenish minting run authority, GRUB minting
  monitor budget, DL runtime as monitor budget, inactive timer authority,
  dynamic sched_getattr authority, overrun notification as enforcement, run
  without DL admission, run while CBS-throttled, and protection claim without
  implementation. JSON check confirms 48 source anchors, 11 compatibility
  obligations, 9 authority rejections, 10 unsafe cases, and 14/14 safety flags
  false. Assurance evidence E-SCHED-DL-COMPAT-001 supports EXEC-001,
  BUDGET-001, and COMPAT-001 only as model evidence.

latest completed risk:
  F1 admission-freeze refresh gate. Analysis/0096, formal/0074,
  f1-admission-freeze-refresh-v1.json, and validation/0113 refresh the Linux
  wake publication boundary against current upstream. Fail-capable RunCap and
  FrozenRunUse resolution must finish before TASK_WAKING, remote wake-list
  publication, or enqueue-visible state. After publication only cheap freshness
  validation or fail-closed handling without lost wakeup is allowed. Safe TLC
  passed with 44 generated states, 24 distinct states, 0 states left on queue,
  depth 7. Unsafe configs reject TASK_WAKING before freeze, wake_list before
  freeze, enqueue before freeze, running with missing generation, Domain epoch,
  SchedContext, placement, or root budget, raw cap after publication, heavy
  lookup after publication, late denial that loses wakeup, placement-as-authority,
  current continuation mint, fork ambient authority, and protection claim
  without implementation. JSON check confirms 20 anchors, 11 frozen tuple
  requirements, 5 publication boundaries, 8 path classifications, 15 authority
  rejections, 15 unsafe cases, and 14/14 safety flags false. Assurance evidence
  E-SCHED-F1-FREEZE-001 supports EXEC-001, BUDGET-001, and COMPAT-001 only as
  model evidence.

latest completed risk:
  Scheduler authority integration gate. Analysis/0097, formal/0075,
  scheduler-authority-integration-gate-v1.json, and validation/0114 compose F1
  frozen wake publication, selected-state settlement, server epoch tickets,
  deadline CBS/GRUB compatibility, and monitor root timer/budget/token/epoch
  into one execution edge. Safe TLC passed with 59 generated states, 38
  distinct states, 0 states left on queue, depth 6. Unsafe configs reject
  publication without frozen tuple, run without frozen tuple, run without
  selected settlement, missing server ticket, stale server epoch, missing lower
  task authority, missing DL admission, CBS-throttled run, missing monitor
  timer, Linux runtime authority, server runtime authority, deadline
  compatibility authority, placement authority, raw cap after publication,
  heavy lookup after publication, fail-closed running, and protection claim
  without implementation. JSON check confirms 23 anchors, 7 integrated
  subjects, 12 execution requirements, 17 authority rejections, 17 unsafe cases,
  and 15/15 safety flags false. Assurance evidence E-SCHED-INTEGRATION-001
  supports ACT-001, EXEC-001, BUDGET-001, and COMPAT-001 only as model evidence.

next focused risk:
  Monitor timer architecture substrate gate. Analysis/0098, formal/0076,
  monitor-timer-architecture-substrate-v1.json, and validation/0115 refine
  monitor root budget timing into architecture-substrate requirements for x86
  VMX-root and arm64 EL2. Safe TLC passed with 11 generated states, 9 distinct
  states, 0 states left on queue, depth 5. Unsafe configs reject missing
  monitor architecture substrate, wrong architecture substrate, Linux hrtimer
  root, Linux sched_tick root, KVM VMX guest timer root, KVM VMX hrtimer
  fallback root, arm64 KVM arch timer root, arm64 KVM soft hrtimer root, pKVM
  stage-2 as timer, pKVM plus Linux timer, missing monitor timer, missing
  sealed token, stale epoch, unprotected monitor state, missing root budget,
  missing MemoryView/CPU/activation-generation binding tuple, Linux/KVM/guest
  deadline retiming, expiry still running, NO_HZ control, unbounded overrun,
  Linux-minted receipt, receipt without monitor expiry, and protection claim
  without implementation. JSON check confirms 31 anchors, 9 substrates, 16
  requirements, 18 forbidden substitutions, 24 unsafe cases, and 16/16 safety
  flags false. Assurance evidence E-MONITOR-TIMER-ARCH-001 supports ACT-001
  and BUDGET-001 only as model evidence.

next focused risk:
  Placement/affinity/hotplug integration refresh after the N-143 execution gate
  and N-144 monitor-timer substrate gate. Do not add direct-call stubs, ABI,
  tracepoints, workqueue integration, io_uring integration, async carrier Linux
  names, budget hooks, scheduler hooks, architecture timer implementation, or
  behavior-changing patches.
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

Latest scheduler placement gate:

```text
N-145 completed:
  analysis/0099-placement-affinity-hotplug-integration-gate.md
  analysis/placement-affinity-hotplug-integration-gate-v1.json
  formal/0077-placement-affinity-hotplug-integration-gate-model/
  validation/0116-placement-affinity-hotplug-integration-gate-tlc.md

important correction:
  The first boolean draft was rejected by subagent review as too vacuous.
  The checked model now uses finite CPU sets, explicit Domain/SchedContext/
  RunCap grant provenance, derived frozenAllowed intersection, invalidation
  from Running, fail-closed empty-intersection behavior, and ordinary-Domain
  versus Linux-exception separation.

safe TLC:
  81 generated states
  39 distinct states
  depth 7

unsafe configs:
  20 expected counterexamples reject running without frozen placement, stale
  placement epoch, current Linux mask, active CPU, monitor CPU binding,
  MemoryView CPU binding, or no-pending-migration state, and reject selected
  CPU, placement refresh, fallback expansion, force affinity, cpuset fallback,
  class selection, sched_ext selection, core scheduling, sched_exec,
  migrate-disable, per-cpu kthread exception, no-intersection running, and
  protection overclaims as authority substitutes.

assurance:
  E-SCHED-PLACEMENT-INTEGRATION-001 supports ACT-001, EXEC-001, and COMPAT-001
  only as model evidence.

still not:
  Linux implementation, scheduler hook, task-field approval, ABI approval,
  runtime coverage, monitor implementation, monitor verification, behavior
  change, or production protection.

next:
  Runtime coverage execution planning or final run/move revalidation hook
  placement analysis. No behavior-changing Linux patch is approved.
```

Latest scheduler final run/move gate:

```text
N-146 completed:
  analysis/0100-final-run-move-revalidation-hook-placement-gate.md
  analysis/final-run-move-revalidation-hook-placement-gate-v1.json
  formal/0078-final-run-move-revalidation-hook-placement-gate-model/
  validation/0117-final-run-move-revalidation-hook-placement-gate-tlc.md

purpose:
  require final ordinary Domain run commitment and queued-task movement to
  consume fresh validation tuples. Earlier placement or selected state is not
  enough.

tuple fields:
  task generation
  Domain epoch
  SchedContext epoch
  RunCap epoch
  move sequence
  core scheduling sequence
  sched_ext DSQ/custody sequence
  edge kind
  run or destination CPU
  fresh allowed set
  pending migration state

safe TLC:
  750 generated states
  455 distinct states
  depth 21

unsafe:
  39 expected counterexamples.
  Rejected hazards include missing/stale/wrong run or move tuples, tuple kind
  and edge mismatch, stale task/domain/schedctx/runcap/move/core/scx state,
  run/move outside fresh set, pending migration, empty intersection, hook after
  rq->curr publication, Linux pick/move/balance/dispatch/hotplug/migration
  authority, Linux hook approval, behavior change, monitor verification, and
  protection overclaims.

implementation pressure:
  A conceptual final run revalidation point is near kernel/sched/core.c:7188,
  before rq->curr publication at core.c:7201. The shared queued move pressure
  point is move_queued_task() at kernel/sched/core.c:2546. These are not
  approved patch points. A veto-capable hook still needs retry/ineligibility,
  locking, static-branch overhead, and class-state rollback design.

assurance:
  E-SCHED-RUN-MOVE-REVALIDATION-001 supports ACT-001, EXEC-001, and COMPAT-001
  only as model evidence.

still not:
  Linux implementation, scheduler hook approval, task-field approval, ABI
  approval, runtime coverage, monitor implementation, monitor verification,
  budget enforcement evidence, behavior change, or production protection.

next:
  Design the retry/ineligibility semantics for a possible final run hook and
  shared move revalidation boundary, or run targeted runtime coverage planning.
```

Latest scheduler deny/retry gate:

```text
N-147 completed:
  analysis/0101-final-deny-retry-ineligibility-gate.md
  analysis/final-deny-retry-ineligibility-gate-v1.json
  formal/0079-final-deny-retry-ineligibility-gate-model/
  validation/0118-final-deny-retry-ineligibility-gate-tlc.md

purpose:
  define what a future final CapSched run-validation hook must do when it
  denies a selected ordinary Domain candidate.

required shape:
  deny before rq->curr publication
  record denial
  mark denied candidate ineligible for the retry epoch
  neutralize scheduler class state
  clear balance callbacks before retry/lock release
  retry with bounded progress
  commit only a different candidate with a fresh tuple
  or fail closed only when no eligible candidate remains

safe TLC:
  11 generated states
  9 distinct states
  depth 6

unsafe:
  17 expected counterexamples.
  Rejected hazards include running a denied candidate, retrying the same
  denied candidate, denying after rq->curr, denying without ineligibility,
  retrying without progress, failing closed with an eligible candidate, running
  after retry without a fresh tuple, silent drop, retry-budget bypass, class
  state authority, RETRY_TASK authority, idle fallback authority, sched_ext
  fallback authority, core cached pick authority, and non-claim overreach.

assurance:
  E-SCHED-DENY-RETRY-001 supports EXEC-001 and COMPAT-001 only as model
  evidence.

still not:
  Linux implementation, hook approval, retry implementation, task-field
  approval, class-state rollback approval, runtime coverage, ABI approval,
  monitor verification, behavior change, budget enforcement evidence, or
  production protection.

next:
  Model task lifetime/RCU/refcount/locking for frozen run tuples and denied
  candidates, or integrate fork/clone/exec/exit identity propagation into the
  scheduler authority model.
```

Latest task lifetime/locking gate:

```text
N-148 completed:
  analysis/0102-task-frozen-run-lifetime-locking-gate.md
  analysis/task-frozen-run-lifetime-locking-gate-v1.json
  formal/0080-task-frozen-run-lifetime-locking-gate-model/
  validation/0119-task-frozen-run-lifetime-locking-gate-tlc.md

purpose:
  define the minimum lifetime, generation, RCU, rq/pi locking, migration, and
  release-settlement semantics for FrozenRunUse, denied candidates, and future
  move validation records.

rule:
  Raw task_struct pointers, RCU visibility, and rq->curr publication are not
  CapSched authority. A frozen task identity can be consumed only while the
  task is live, generation-fresh, not migrating, not released, and stabilized
  by a task reference or scheduler locked context.

safe TLC:
  20 generated states
  12 distinct states
  depth 6

unsafe:
  16 expected counterexamples.
  Rejected hazards include run after free/exit invalidation, missing stable
  lifetime, RCU-only authority, raw pointer authority, run while migrating,
  stale generation, use after release, premature release, double release,
  ref/lock leak, move without rq lock, retry without stable candidate lifetime,
  ignored exit invalidation, and non-claim overreach.

assurance:
  E-SCHED-LIFETIME-LOCKING-001 supports EXEC-001 and COMPAT-001 only as model
  evidence.

still not:
  Linux implementation, hook approval, task-field approval, task storage-layout
  approval, refcount scheme approval, locking protocol approval, runtime
  coverage, ABI, monitor verification, behavior change, budget enforcement
  evidence, or production protection.

next:
  Continue model-only completion by integrating fork/clone/exec/exit identity
  propagation with the scheduler authority model, or close remaining runnable
  lifecycle gaps before implementation planning.
```

Latest lifecycle identity propagation integration gate:

```text
N-149 completed:
  analysis/0103-lifecycle-identity-propagation-integration-gate.md
  analysis/lifecycle-identity-propagation-integration-gate-v1.json
  formal/0081-lifecycle-identity-propagation-integration-gate-model/
  validation/0120-lifecycle-identity-propagation-integration-gate-tlc.md

purpose:
  integrate fork/clone, exec, and exit identity propagation with the recent
  scheduler authority gates.

rule:
  child run requires SpawnCap-derived fresh identity before wake publication.
  new Domain spawn requires monitor token.
  RunCap, FrozenRunUse, and RunToken are not ambiently inherited.
  successful exec requires ExecContinuation.
  check-only exec does not mutate generations.
  old FrozenRunUse is not reused after exec.
  exit invalidates stale task authority.
  PID/TGID reuse, clone flags, sched_exec placement, task release,
  RCU-visible dead tasks, and trace observations are not authority.

safe TLC:
  19 generated states
  13 distinct states
  depth 4

unsafe:
  20 expected counterexamples.
  Rejected hazards include child run without SpawnCap or fresh identity,
  ambient RunCap/FrozenRunUse/RunToken inheritance, wake before identity
  preparation, new Domain without token, clone flags as Domain authority,
  exec Domain change without token, post-exec run without ExecContinuation,
  check-only mutation, old FrozenRunUse after exec, run after exit, PID/TGID
  reuse, release authority, and non-claim overreach.

assurance:
  E-SCHED-LIFECYCLE-IDENTITY-001 supports EXEC-001 and COMPAT-001 only.
  Existing validation/0037 and validation/0038 are now registered as
  E-EXEC-GEN-001 and E-POST-EXEC-RESOURCE-001.

still not:
  Linux implementation, fork/exec/exit hook approval, scheduler hook approval,
  task-field approval, ABI, runtime coverage, monitor verification, behavior
  change, budget enforcement evidence, or production protection.

N-150 completed:
  analysis/0104-exit-revoke-pending-authority-drain-gate.md
  analysis/exit-revoke-pending-authority-drain-gate-v1.json
  formal/0082-exit-revoke-pending-authority-drain-gate-model/
  validation/0121-exit-revoke-pending-authority-drain-gate-tlc.md

purpose:
  define the global exit/revoke completion predicate across scheduler, async,
  endpoint, monitor admission, device, budget, server, root execution, and
  unknown carrier families.

rule:
  exit/revoke completion requires old-epoch authority embargo, complete
  pending-authority inventory, drain/reject/quarantine/settlement of all known
  carrier families, derived receipt/shadow revoke, exact-once budget/root
  settlement, and fail-closed handling for unknown carrier kinds.
  Linux cancel, flush, pending-bit clear, task_work_add failure, io_uring
  cancel/free/CQE, timer delete, rcu_barrier, audit/trace rows, timeouts,
  PID/TGID reuse, raw task pointers, and RCU visibility are not global drain
  receipts or authority.

safe TLC:
  13 generated states
  11 distinct states
  depth 10

unsafe:
  28 expected counterexamples.
  Rejected hazards include remote wake or queued FrozenRunUse surviving
  completion, early release, PID reuse, pending workqueue/io_uring/endpoint/
  direct-call/ring/device carriers, stale derived receipts, premature budget
  refund, surviving server ticket or root RunToken, audit/Linux cleanup as
  drain proof, unknown carrier default drain, budget leak/double settlement,
  RCU visibility authority, and non-claim overreach.

assurance:
  E-SCHED-EXIT-REVOKE-DRAIN-001 supports EXEC-001, BUDGET-001, ENDP-001,
  ASYNC-001, DEV-001, REVOKE-001, and COMPAT-001 as model evidence only.

still not:
  Linux implementation, hook approval, task fields, carrier structs,
  endpoint/device/budget implementation, ABI, runtime coverage, monitor
  verification, behavior change, or production protection.

next:
  N-151 has now constructed the model-completeness ledger and found the
  model-only goal is not complete yet.

N-151 completed:
  analysis/0105-model-completeness-ledger-gate.md
  analysis/model-completeness-ledger-gate-v1.json
  formal/0083-model-completeness-ledger-gate-model/
  validation/0122-model-completeness-ledger-gate-tlc.md

purpose:
  prevent premature completion of the model-only goal.

current audit:
  11 top-level children are model-supported:
    ACT, EXEC, BUDGET, ENDP, ASYNC, MEM, TLB, PCACHE, DEV, REVOKE, CLUSTER.
  1 top-level child is prototype/compatibility-classified:
    COMPAT.
  3 top-level children remain open model blockers:
    TCB, SIDE, EVAL.

safe TLC:
  5 generated states
  3 distinct states
  depth 2

unsafe:
  7 expected counterexamples for model completion while TCB/SIDE/EVAL are open,
  completion without compatibility classification, ignored open blocker,
  production claim from model-only evidence, and prototype evidence as
  protection.

rule:
  Do not mark the goal complete until TCB-001, SIDE-001, and EVAL-001 have
  model-supported artifacts. Even then, model-only completion is not production
  protection.

next:
  N-153 has now closed SIDE-001 at model level. Close EVAL-001 with an
  evaluation contract model.

N-152 completed:
  analysis/0106-tcb-boundary-gate.md
  analysis/tcb-boundary-gate-v1.json
  formal/0084-tcb-boundary-gate-model/
  validation/0123-tcb-boundary-gate-tlc.md

purpose:
  close TCB-001 as a model-supported boundary without claiming implementation
  or measured TCB size.

rule:
  HyperTag Monitor owns only non-forgeable roots and typed/sealed transitions.
  Monitor TCB excludes drivers, parsers, policy engines, Linux scheduler
  policy, cgroup/namespace/LSM policy logic, and Linux mutable metadata.
  Service Domains enter through typed endpoints, use least authority, intersect
  service authority with caller frozen authority, and expose no raw monitor or
  device handles. A TCB budget and VM/VMM comparison envelope are required.

safe TLC:
  3 generated states
  2 distinct states
  depth 2

unsafe:
  11 expected counterexamples for unbounded monitor core, untyped monitor
  interface, monitor policy/driver/parser inclusion, Linux mutable trusted root,
  service ambient authority, raw handle exposure, missing TCB budget, missing
  VM/VMM comparison envelope, and implementation/protection/cost overclaims.

assurance:
  E-TCB-BOUNDARY-001 supports TCB-001 as model evidence only.

still not:
  monitor implementation, service-domain implementation, line/interface count,
  runtime coverage, monitor verification, production protection, or cost
  efficiency.

N-153 completed:
  analysis/0107-side-channel-cotenancy-policy-gate.md
  analysis/side-channel-cotenancy-policy-gate-v1.json
  formal/0085-side-channel-cotenancy-policy-gate-model/
  validation/0124-side-channel-cotenancy-policy-gate-tlc.md

purpose:
  close SIDE-001 as a model-supported co-tenancy and side-channel policy
  boundary.

rule:
  co-tenancy requires known policy, leakage classification, and explicit policy
  for SMT, core, cache, NUMA, device queue, and cluster placement sharing.
  Performance optimization cannot override hard Monitor-backed boundaries.
  Scheduler placement must respect side policy. Side policy is not execution,
  memory, endpoint, queue, or budget authority.

safe TLC:
  3 generated states
  2 distinct states
  depth 2

unsafe:
  15 expected counterexamples for unknown policy default allow, sharing without
  explicit policy, performance override, hard-boundary weakening, scheduler
  bypass, missing monitor binding, missing leakage classification, side policy
  as authority root, and protection/cost overclaims.

assurance:
  E-SIDE-COTENANCY-001 supports SIDE-001 as model evidence only.

still not:
  scheduler implementation, side-channel mitigation implementation, runtime
  side-channel evidence, performance evidence, monitor verification, production
  protection, or cost efficiency.

N-154 completed:
  analysis/0108-evaluation-contract-gate.md
  analysis/evaluation-contract-gate-v1.json
  formal/0086-evaluation-contract-gate-model/
  validation/0125-evaluation-contract-gate-tlc.md

purpose:
  close EVAL-001 at model level by specifying the evaluation contract required
  before any future hypervisor-comparable protection or cost-efficiency claim.

rule:
  future evaluation claims require exploit-containment, cross-Domain memory,
  DMA, control-authority, and monitor-escape tests; KVM, Firecracker, and
  container/Linux baselines; workload envelope; throughput, tail-latency,
  density, and operational-cost metrics; pass/fail criteria; and negative
  result policy. Microbench-only evaluation is not sufficient.

safe TLC:
  3 generated states
  2 distinct states
  depth 2

unsafe:
  20 expected counterexamples for missing security/cost contract items,
  microbench-only evaluation, and protection/cost/result claims from the
  contract alone.

assurance:
  E-EVAL-CONTRACT-001 supports EVAL-001 as model evidence only.

still not:
  evaluation execution, benchmark evidence, exploit-containment success,
  monitor verification, production protection, or cost efficiency.

next:
  All N-151 model-only blockers are now closed. Add a final model-completeness
  ledger before marking the model-only goal complete.
```

N-155 completed:
  analysis/0109-final-model-completeness-ledger.md
  analysis/final-model-completeness-ledger-v1.json
  formal/0087-final-model-completeness-ledger-model/
  validation/0126-final-model-completeness-ledger-tlc.md

purpose:
  close the current model-only goal after TCB-001, SIDE-001, and EVAL-001 were
  closed at model level.

result:
  model-only goal complete. Production protection remains unclaimed.

current audit:
  14 top-level children are model-supported:
    ACT, EXEC, BUDGET, ENDP, ASYNC, MEM, TLB, PCACHE, DEV, REVOKE, CLUSTER,
    TCB, SIDE, EVAL.
  1 top-level child is prototype/compatibility-classified:
    COMPAT.
  0 model-only blockers remain open.

safe TLC:
  3 generated states
  2 distinct states
  depth 2

unsafe:
  14 expected counterexamples for missing model children, missing COMPAT
  classification, open DEV subclaims, missing TCB/SIDE/EVAL model support,
  ignored blockers, missing forbidden-claim records, and production, cost,
  runtime, implementation, prototype-as-protection, or TOP completion claims
  from model-only evidence.

assurance:
  E-FINAL-MODEL-COMPLETION-001 supports closing the current model-only goal
  only. It supports no production subclaim.

still not:
  Linux implementation, hook approval, ABI approval, runtime coverage, monitor
  implementation, monitor verification, exploit-containment success, benchmark
  evidence, production protection, cost efficiency, or datacenter deployment
  readiness.

N-156 completed:
  analysis/0110-terminology-freeze-rename-risk-review.md
  analysis/terminology-freeze-rename-risk-review-v1.json
  traceability/0002-terminology-alias-appendix.md
  implementation/0015-mainline-naming-and-scope-review.md
  validation/0127-terminology-rename-inventory.md
  validation/0128-sched-exec-lease-rename-build-validation.md

purpose:
  freeze public vocabulary before publication and avoid later paper/RFC/Linux
  confusion.

public names:
  DomainLease-Linux = umbrella project.
  DomainLease-H = monitor-backed architecture.
  SchedExecLease = scheduler core.
  sched_exec_lease = Linux-facing scaffold.

legacy aliases:
  CapSched-Linux, CapSched-H, RunCap, FrozenRunUse, SchedContext, DomainTag,
  and HyperTag Monitor remain historical aliases in old artifacts.

policy:
  do not rename claim IDs, evidence IDs, counterexample IDs, or old TLA module
  paths. New public docs must use the locked vocabulary. Linux symbols must not
  use `capsched_*` or `RunCap`.

linux result:
  commit 3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c
  sched/exec_lease: Rename inert scheduler lease scaffold

  renamed:
    CONFIG_CAPSCHED -> CONFIG_SCHED_EXEC_LEASE
    include/linux/capsched.h -> include/linux/sched_exec_lease.h
    kernel/sched/capsched.c -> kernel/sched/exec_lease.c

  patch queue:
    linux-patches/patches/capsched-linux-l0/0003-sched-exec-lease-Rename-inert-scheduler-lease-scaffold.patch

validation:
  targeted scheduler-subtree build passed.

  log:
    /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-rename-build-20260702T014802Z.log

  off:
    SCHED_EXEC_LEASE = undef
    kernel/sched/built-in.a built
    kernel/sched/exec_lease.o absent

  on:
    SCHED_EXEC_LEASE = y
    kernel/sched/built-in.a built
    kernel/sched/exec_lease.o present

still not:
  full vmlinux validation for this rename, model revalidation, behavior-changing
  Linux implementation, user ABI, public tracepoint ABI, monitor ABI, monitor
  verification, production protection, or cost efficiency.

N-157 completed:
  validation/0129-patch-queue-replay-and-freshness.md

purpose:
  prove the private Linux patch queue is replayable after N-156 before moving
  toward implementation design.

result:
  fresh replay of linux-patches series 0001..0003 produced:
    3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c

  replay tree:
    /media/nia/scsiusb/dev/linux-cap/build/replay/n157-capsched-linux-l0-20260702T024618Z

  source-drift gate:
    /media/nia/scsiusb/dev/linux-cap/build/source-drift/linux-source-drift-gate/20260702T024618Z
    model_freshness=fresh
    merge_tree_clean=true
    linux_patch_approved=false

  targeted build log:
    /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-rename-build-20260702T024654Z.log

script fixes:
  linux-patches/scripts/recreate-capsched-linux-l0.sh now rejects dirty
  targets, supports reference clones and non-origin remotes, checks patch
  existence, uses deterministic committer date/identity, and verifies final
  HEAD against upstream/base.txt work_commit.

still not:
  full vmlinux validation, QEMU boot validation, runtime coverage, behavior
  change, ABI approval, monitor verification, production protection, or cost
  efficiency.

N-158 in progress:
  analysis/0111-sched-exec-lease-l0-readiness-and-design-review.md
  implementation/0016-sched-exec-lease-l0-implementation-readiness-gate.md
  implementation/0017-sched-exec-lease-l0-vertical-slice-design.md
  implementation/0018-sched-exec-lease-l0-p1-p4-blueprint.md
  implementation/0019-sched-exec-lease-p1-no-behavior-patch-plan.md
  implementation/sched-exec-lease-l0-implementation-readiness-gate-v1.json
  implementation/sched-exec-lease-l0-p1-p4-blueprint-v1.json
  implementation/sched-exec-lease-p1-no-behavior-patch-plan-v1.json

verdict:
  ready for implementation design and no-behavior preparation patches.
  behavior-changing runtime enforcement remains blocked.

P1-P4 blueprint:
  P1: internal object skeleton only, no task fields and no runtime state.
  P2: task lifecycle identity shadow only if raw-copy inheritance is reset
      after dup_task_struct(), child identity is prepared in copy_process()
      before wake_up_new_task(), sched_exec() remains placement-only, exec
      mutation is after point-of-no-return, and do_exit()/PF_EXITING invalidates.
  P3: placement-only scheduler touch points, all allow/no-op.
  P4: allow-all final revalidation skeleton only.

preferred P4 hook classes:
  final run at __schedule() keep_resched join after pick/proxy resolution and
    before rq->curr publication.
  common queued move at move_queued_task() before deactivate_task()/set_task_cpu().
  double-rq queued move at move_queued_task_locked() before mutation.
  fair load-balance move at fair detach_task() before its direct
    deactivate_task()/set_task_cpu().

explicit P5 gates added by subagent review:
  sched_ext support/disable/fail-closed decision.
  core cached-pick revalidation or invalidation.
  proxy donor/current/executor authority and budget tests.
  kthread/workqueue root/internal/service-domain classification.
  negative denial tests for SCX, core cached picks, proxy split, and kworker
    paths after denial exists.

P1 patch plan:
  implementation/0019 narrows the first possible implementation patch to
  include/linux/sched_exec_lease.h and kernel/sched/exec_lease.c only.
  P1 may add private/opaque allow-all scaffolding and authority-separation
  comments only. It may not add task_struct fields, rq fields, scheduler hooks,
  lifecycle hooks, ABI, monitor calls, allocation, runtime denial, budget
  charging, generation mutation, or behavior changes.

allowed next patch classes:
  no-behavior internal helper skeleton
  no-behavior identity preparation skeleton
  no-behavior scheduler touch-point comments/static inline hooks
  KUnit-only or build-only validation without ABI

blocked patch classes:
  runtime denial, public user handles, public tracepoint ABI, monitor ABI,
  exported symbols, endpoint/device/memory authority, hypervisor-grade or
  production protection claims.

N-159 in progress:
  validation/0130-sched-exec-lease-full-vmlinux-build.md
  validation/0131-sched-exec-lease-qemu-boot-smoke.md
  validation/run-sched-exec-lease-full-build-validation.sh
  validation/run-sched-exec-lease-qemu-boot-smoke.sh

full vmlinux result:
  passed for disabled and enabled configurations.

  log:
    /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260702T030457Z.log

  off:
    SCHED_EXEC_LEASE = undef
    vmlinux present
    kernel/sched/exec_lease.o absent

  on:
    SCHED_EXEC_LEASE = y
    vmlinux present
    kernel/sched/exec_lease.o present

QEMU status:
  validation/0131 records QEMU boot/workload smoke pass for off/on.

  off artifacts:
    build/qemu/sched-exec-lease-boot-smoke/20260702T031917Z-off/serial.log
    build/qemu/sched-exec-lease-boot-smoke/20260702T031917Z-off/counts.tsv
    build/qemu/sched-exec-lease-boot-smoke/20260702T031917Z-off/run-summary.txt

  on artifacts:
    build/qemu/sched-exec-lease-boot-smoke/20260702T033357Z-on/serial.log
    build/qemu/sched-exec-lease-boot-smoke/20260702T033357Z-on/counts.tsv
    build/qemu/sched-exec-lease-boot-smoke/20260702T033357Z-on/run-summary.txt

  result:
    off qemu_status=0, WORKLOAD_RET 0
    on qemu_status=0, WORKLOAD_RET 0
    on CONFIG_SCHED_EXEC_LEASE=y

  coverage limit:
    pick_next_task and __schedule were function-missing, and
    dlease_pick_next_task kprobe failed/missing. This is boot/workload smoke,
    not final hook coverage.

  log:
    /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-qemu-after-full-build-20260702T0320Z.log

still not:
  runtime coverage, hook approval, behavior change, ABI approval, monitor
  verification, production protection, or cost efficiency.

N-162 P1 no-behavior implementation:
  implementation/0020-sched-exec-lease-p1-no-behavior-implementation.md
  implementation/sched-exec-lease-p1-no-behavior-implementation-v1.json
  validation/0132-sched-exec-lease-p1-full-build.md

Linux:
  branch:
    capsched-linux-l0

  work commit:
    95b8c509043d755ad77801315beec94c09059777
    sched/exec_lease: Add private no-behavior object vocabulary

  changed source:
    kernel/sched/exec_lease.c

  added private vocabulary:
    enum sched_exec_validation_result
    struct sched_exec_domain
    struct sched_exec_grant
    struct sched_budget_ctx
    struct sched_exec_lease
    sched_exec_allow_all_validation()

  unchanged/absent:
    no task_struct fields, rq fields, scheduler hooks, lifecycle hooks,
    allocation, runtime state mutation, runtime denial, budget charging,
    generation mutation, policy frontend calls, ABI, exported symbols,
    tracepoints, monitor calls, or user-visible handles.

Patch queue:
  linux-patches/patches/capsched-linux-l0/0004-sched-exec-lease-Add-private-no-behavior-object-vocabulary.patch
  linux-patches/patches/capsched-linux-l0/series
  linux-patches/upstream/base.txt

Validation:
  patch queue replay passed:
    final HEAD 95b8c509043d755ad77801315beec94c09059777

  full vmlinux build passed:
    log:
      /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260702T035916Z.log

    off:
      build/linux-l0-sched-exec-lease-off-p1-n162-current-x86_64
      SCHED_EXEC_LEASE=undef
      vmlinux present
      kernel/sched/exec_lease.o absent

    on:
      build/linux-l0-sched-exec-lease-on-p1-n162-current-x86_64
      SCHED_EXEC_LEASE=y
      vmlinux present
      kernel/sched/exec_lease.o present

QEMU:
  not rerun for N-162 because P1 adds no runtime call site, hook, task layout,
  lifecycle path, or behavior path. Fresh QEMU is required before any later
  runtime call-site patch.

still blocked:
  behavior-changing runtime enforcement, runtime denial, ABI, monitor calls,
  hook approval, runtime coverage, production protection, and cost-efficiency
  claims.

N-163 P2 task identity shadow plan:
  implementation/0021-sched-exec-lease-p2-task-identity-shadow-plan.md
  implementation/sched-exec-lease-p2-task-identity-shadow-plan-v1.json

status:
  draft patch plan, implementation not applied.

allowed P2 surface:
  include/linux/sched.h
  include/linux/sched_exec_lease.h
  kernel/fork.c
  fs/exec.c
  kernel/exit.c
  kernel/sched/exec_lease.c

required anchors:
  dup_task_struct:
    reset/sanitize sched_exec shadow after arch_dup_task_struct raw copy,
    preferably after RCU_INIT_POINTER(tsk->exec_state, NULL) and before
    setup_thread_stack(tsk, orig).

  copy_process:
    prepare nofail child identity after worker/kthread flags and copy_creds,
    before the "No more failure paths" boundary and before any
    wake_up_new_task path. create_io_thread is covered by copy_process because
    it returns an inactive child to be woken later.

  exec:
    sched_exec remains placement-only. Any exec shadow mutation belongs in
    begin_new_exec after point-of-no-return, with the exact anchor chosen and
    justified by whether the generation means fatal commit, de_thread success,
    or new-mm visibility.

  exit:
    invalidate in do_exit immediately after exit_signals(tsk) sets PF_EXITING;
    release_task/free_task are too late for authority invalidation.

forbidden:
  scheduler hooks, rq fields, runtime denial, budget charging, blocking
  generation checks, tracepoints, ABI, exports, monitor calls, MemoryView/IOMMU
  changes, workqueue/io_uring authority propagation, and protection claims.

N-164 P2 task identity shadow implementation and validation:
  implementation/0022-sched-exec-lease-p2-task-identity-shadow-implementation.md
  implementation/sched-exec-lease-p2-task-identity-shadow-implementation-v1.json
  validation/0133-sched-exec-lease-p2-full-build-and-layout.md
  validation/0134-sched-exec-lease-p2-qemu-boot-smoke.md
  validation/run-sched-exec-lease-task-layout-probe.sh

Linux:
  branch:
    capsched-linux-l0

  work commit:
    a0f2676adda634391983e74f29fcba577a9c919e
    sched/exec_lease: Add task identity shadow

  changed source:
    include/linux/sched.h
    include/linux/sched_exec_lease.h
    kernel/fork.c
    fs/exec.c
    kernel/exit.c
    kernel/sched/exec_lease.c

Patch queue:
  linux-patches/patches/capsched-linux-l0/0005-sched-exec-lease-Add-task-identity-shadow.patch
  linux-patches/patches/capsched-linux-l0/series
  linux-patches/upstream/base.txt

Validation:
  replay passed to exact final HEAD:
    a0f2676adda634391983e74f29fcba577a9c919e

  full vmlinux off/on passed with BUILD_TAG=p2-n164-current.
  task layout probe passed:
    off: sched_exec field absent, task_struct size 0xcc0
    on: sched_exec field size 0x28, offset+1 0x591, task_struct size 0xd00

  QEMU off/on boot/workload smoke passed:
    off run:
      build/qemu/sched-exec-lease-p2-boot-smoke/20260702T045650Z-off
      qemu_status=0, WORKLOAD_RET 0

    on run:
      build/qemu/sched-exec-lease-p2-boot-smoke/20260702T050601Z-on
      CONFIG_SCHED_EXEC_LEASE=y, qemu_status=0, WORKLOAD_RET 0
      sched_process_fork/exec/exit counts: 101/101/101

  coverage limit preserved:
    pick_next_task and __schedule remain function-missing in the current smoke.
    dlease_pick_next_task kprobe failed/missing. This is not a P2 blocker
    because P2 has no scheduler hook or denial path.

still blocked:
  behavior-changing runtime enforcement, scheduler hook approval, runtime
  denial, ABI, monitor calls, budget charging, runtime coverage, negative
  denial tests, production protection, and cost-efficiency claims.

N-165/N-166 design-readiness audit:
  artifacts:
    capsched-models/analysis/0113-implementation-ready-completion-audit.md
    capsched-models/analysis/implementation-ready-completion-audit-v1.json
    capsched-models/analysis/0114-sched-ext-core-proxy-coverage-boundary.md
    capsched-models/analysis/sched-ext-core-proxy-coverage-boundary-v1.json

  current verdict:
    implementation-ready design is not complete yet at N-165/N-166.
    Later superseded by N-173 final implementation-ready audit.

  reason:
    P2 is validated, and ADR-0011 keeps new Linux implementation out of scope,
    but sched_ext DSQ custody/fallback, core scheduling cached picks/cookie
    steal, and proxy donor/current/executor splits remain uncovered until
    explicitly classified as supported, disabled, or excluded.

  default claim rule:
    uncovered until explicitly proved covered.

  next:
    design-only bounded retry and ineligibility source shape, then negative
    denial validation design, then claim-ledger gate, then upstream-drift
    recheck before any implementation scope is reopened.

N-167 bounded retry and ineligibility source design:
  artifacts:
    capsched-models/analysis/0115-bounded-retry-ineligibility-source-design.md
    capsched-models/analysis/bounded-retry-ineligibility-source-design-v1.json

  key finding:
    pre-rq->curr is not automatically pre-commit. In the current Linux source,
    pick_next_task() often returns only after put_prev_set_next_task() has
    already settled scheduler-class state.

  consequence:
    P4 allow-all final revalidation is useful as source skeleton, but P5 denial
    must not be created by simply turning that hook into a denying hook.

  required P5 shape:
    pre-settle candidate validation, or a source-proved per-class rollback.
    Shape B rollback is not ready.

  open next:
    refresh the final-deny model and negative tests around pre-settle
    validation, class-picker ineligibility visibility, same-candidate repick,
    sched_ext DSQ livelock, core cached-pick invalidation, and proxy
    donor/executor subject split.

N-168/N-169 final-deny model refresh and negative validation plan:
  artifacts:
    capsched-models/formal/0088-final-deny-source-shape-gate-model/
    capsched-models/validation/0135-final-deny-source-shape-gate-tlc.md
    capsched-models/analysis/0116-negative-denial-validation-plan.md
    capsched-models/analysis/negative-denial-validation-plan-v1.json

  TLC:
    safe passed with 10 generated states, 8 distinct states, depth 5.
    15 unsafe configs produced expected counterexamples.

  rejected:
    post-settle denial without rollback, invisible class-picker ineligibility,
    same-candidate repick, sched_ext local DSQ head livelock, core cached-pick
    bypass, proxy donor/executor mismatch, fail closed while eligible,
    RETRY_TASK/idle/sched_ext fallback authority, and overclaims.

  still blocked:
    no Linux implementation or runtime denial is approved. Next design gate is
    explicit scheduler path classification: supported, disabled, or excluded
    for CFS/RT/DL/sched_ext/core/proxy/workqueue/kthread surfaces.

N-170 scheduler path classification for P5:
  artifacts:
    capsched-models/analysis/0117-scheduler-path-classification-for-p5.md
    capsched-models/analysis/scheduler-path-classification-for-p5-v1.json
    capsched-models/formal/0089-scheduler-path-classification-gate-model/
    capsched-models/validation/0136-scheduler-path-classification-gate-tlc.md

  TLC:
    safe passed with 2 generated states, 1 distinct state, depth 1.
    10 unsafe configs produced expected counterexamples.

  initial P5 supported paths:
    ordinary CFS final run in non-core, non-proxy, non-sched_ext configuration.
    common queued move through move_queued_task() / move_queued_task_locked().

  initial P5 disabled paths:
    sched_ext, core scheduling, proxy execution.

  initial P5 excluded paths:
    fair direct load balance, RT, deadline, idle exception,
    stopper/hotplug/migration kernel threads, generic kthreads/workqueues,
    io_uring workers.

  rejected:
    open paths, supported-without-evidence, runtime coverage over excluded
    paths, disabled path execution, fallback authority, workqueue or internal
    kthread identity as caller authority, implementation approval, production
    protection, and cost-efficiency claims.

  next:
    implementation claim-ledger gate was later closed at design level by N-171.
    The remaining next work is upstream-drift recheck plan for reopening
    implementation scope, then final implementation-ready audit.

N-171 implementation claim-ledger gate:
  artifacts:
    capsched-models/analysis/0118-implementation-claim-ledger-gate.md
    capsched-models/analysis/implementation-claim-ledger-gate-v1.json
    capsched-models/formal/0090-implementation-claim-ledger-gate-model/
    capsched-models/validation/0137-implementation-claim-ledger-gate-tlc.md

  TLC:
    safe passed with 2 generated states, 1 distinct state, depth 1.
    13 unsafe configs produced expected counterexamples.

  rule:
    every future implementation proposal must carry a machine-readable claim
    ledger row naming evidence classes, supported claims, forbidden claims,
    open gaps, validation-before-review, validation-before-acceptance,
    upstream drift freshness, and safety flags.

  rejected:
    missing ledger row, implementation approval without reopened scope,
    implementation approval with stale drift, behavior change without P5
    evidence, runtime denial without denied-candidate trace evidence, runtime
    coverage without runtime trace coverage, monitor verification without
    monitor roots, production/hypervisor-grade overclaims, cost-efficiency
    overclaim, public ABI overclaim, model-only production claim, and
    compatibility evidence as protection.

  next:
    upstream-drift recheck was later closed at design level by N-172. The
    remaining next work is final implementation-ready audit.

N-172 implementation reopen upstream drift gate:
  artifacts:
    capsched-models/analysis/0119-implementation-reopen-upstream-drift-gate.md
    capsched-models/analysis/implementation-reopen-upstream-drift-gate-v1.json
    capsched-models/formal/0091-implementation-reopen-drift-gate-model/
    capsched-models/validation/0138-implementation-reopen-drift-gate-tlc.md

  upstream:
    fetched upstream/master from 665159e246749578d4e4bfe106ee3b74edcdab18 to
    4a50a141f05a8d1737661b19ee22ff8455b94409.

  source-drift run:
    build/source-drift/linux-source-drift-gate/20260702T063331Z-b5-recheck
    base_to_upstream_commit_count=342
    watched_changed_count=1
    changed_path=kernel/sched/cpufreq_schedutil.c
    drift_class=D1_nearby_non_intersecting_drift
    model_refresh_required_count=0
    merge_tree_clean=true
    model_freshness=fresh
    linux_patch_approved=false

  TLC:
    safe passed with 2 generated states, 1 distinct state, depth 1.
    15 unsafe configs produced expected counterexamples.

  rejected:
    reopen without fetch/source-drift run/group classification, clean merge as
    semantic freshness, stale model or touched group, missing claim ledger,
    P5 missing path classification or negative plan, and behavior/coverage/ABI/
    monitor/protection/cost claims from drift freshness.

  next:
    final implementation-ready audit.

N-173 final implementation-ready audit:
  artifacts:
    capsched-models/analysis/0120-final-implementation-ready-audit.md
    capsched-models/analysis/final-implementation-ready-audit-v1.json
    capsched-models/formal/0092-final-implementation-ready-audit-model/
    capsched-models/validation/0139-final-implementation-ready-audit-tlc.md

  verdict:
    implementation-ready design is complete for implementation-scope reopening
    review, but implementation remains unapproved.

  next reviewable candidate:
    P3 placement-only/no-denial/no-ABI scheduler touchpoints, only after
    explicit scope reopening and a proposal row with claim ledger, fresh drift
    row, patch replay plan, build/QEMU plan, and non-claims.

  sequential gates:
    P4 depends on P3 implementation validation.
    P5 depends on P3/P4 validation and remains off-by-default test-only denial
    for the classified support set.

  TLC:
    safe passed with 2 generated states, 1 distinct state, depth 1.
    12 unsafe configs produced expected counterexamples.

  non-claims remain false:
    linux_patch_approved, behavior_change, runtime_denial, runtime_coverage,
    ABI, monitor_verification, production_protection, hypervisor_grade,
    cost_efficiency, deployment_readiness.

Current implementation state, 2026-07-02:

N-165 P3 placement-only Linux patch:
  linux commit:
    d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3

  status:
    applied and validated as no-denial/no-ABI/no-monitor compatibility only.
    Patch queue 0006 replays to exact P3 HEAD. validation/0140 records full
    off/on vmlinux builds and QEMU forkexec off/on smoke. analysis/0121 limits
    claims to placement-only no-behavior compatibility.

N-166 P4 pre-entry gate:
  artifacts:
    capsched-models/analysis/0122-sched-exec-lease-p4-pre-entry-risk-gate.md
    capsched-models/analysis/sched-exec-lease-p4-pre-entry-risk-gate-v1.json
    capsched-models/validation/0141-sched-exec-lease-p4-pre-entry-validation.md

  verdict:
    P4 may proceed only as an allow-all final run/move revalidation skeleton.
    P4 code is not applied yet. Runtime denial, ABI, monitor calls, budget
    enforcement, runtime coverage, production protection, hypervisor-grade
    isolation, cost efficiency, and deployment readiness remain false.

  validation:
    patch queue replay exact to P3 HEAD.
    upstream drift fresh; only D1 nearby non-intersecting drift in
    kernel/sched/cpufreq_schedutil.c.
    git diff/security review passed for P4 pre-entry scope.
    Codex Security diff-scan preflight was ready; full canonical scan was not
    launched because P3 adds no ABI/parser/allocator/credential/monitor surface.
    broader QEMU off/on all-workload matrix passed with kprobes enabled.

  important caveats:
    P2-vs-P3 core.o is not byte-identical. Section sizes and relocations match;
    reviewed disassembly differences are semantically equivalent instruction
    ordering/operand-order noise. Do not claim byte identity.
    checkpatch reports missing commit description and Signed-off-by in patch
    queue 0006. This is an upstream-readiness blocker before RFC/mainline-style
    series, not a P4 semantic blocker.

  next:
    If implementing P4, keep it allow-all/no-denial/no-ABI/no-monitor. P5
    remains blocked by pre-settle/rollback proof, negative denial tests,
    path-classification limits, runtime trace evidence, and claim-ledger rows.

N-167 P4 pre-implementation critical audit:
  artifacts:
    capsched-models/analysis/0123-sched-exec-lease-p4-pre-implementation-critical-audit.md
    capsched-models/analysis/sched-exec-lease-p4-pre-implementation-critical-audit-v1.json
    capsched-models/validation/0142-sched-exec-lease-p4-pre-implementation-critical-audit-validation.md

  verdict:
    P4 implementation is paused. N-166 remains historical evidence for the
    then-fetched upstream ref, but it is no longer sufficient as an
    implementation-go decision.

  validation hardening:
    linux-source-drift-model-freshness-gate now watches
    kernel/sched/ext/ext.c, not the nonexistent kernel/sched/ext.c.
    run-linux-source-drift-gate.sh now fails if a watched path exists in none
    of base/upstream/work and requires l0_footprint to match the actual
    base..work Linux diff.

  fresh remote:
    upstream/master:
      87320be9f0d24fce67631b7eef919f0b79c3e45c
    base_to_upstream_commit_count:
      422
    merge-tree:
      clean

  drift result:
    scheduler/lifecycle/async/policy/mm direct P4 groups are fresh.
    device_queue_iommu is D4 stale from 61 net changes, so the global
    all-angles model_freshness=stale and candidate_no_behavior_patch_reviewable=false.

  next:
    Either add candidate-scoped drift closure for scheduler-only P4 with
    explicit non-claims, or refresh the stale D4 device/QueueLease source maps.
    Add a P4 anchor manifest and runtime/static final-run anchor observability.
    P4 must remain allow-all/no-denial/no-ABI/no-monitor. P5 remains blocked.

N-168 candidate-scoped drift closure gate:
  artifacts:
    capsched-models/analysis/0124-candidate-scoped-drift-closure-gate.md
    capsched-models/analysis/candidate-scoped-drift-closure-gate-v1.json
    capsched-models/formal/0093-candidate-scoped-drift-closure-gate-model/
    capsched-models/validation/0143-candidate-scoped-drift-closure-gate-tlc.md

  verdict:
    P4SchedulerAllowAll candidate-scoped drift is closed for the groups it
    touches or claims:
      l0_footprint
      scheduler_authority_core
      task_lifecycle_identity

    device_queue_iommu remains D4 stale and is explicitly non-candidate. It
    cannot support device, QueueLease, IOMMU, datacenter, global freshness,
    protection, or cost claims.

  TLC:
    safe passed with 2 generated states, 1 distinct state, depth 1.
    14 unsafe configs produced expected counterexamples:
      unknown scope
      no fresh fetch
      no source run
      no watched-path existence check
      footprint mismatch
      candidate-scope stale group
      missing non-candidate stale record
      global freshness from scoped closure
      P4 implementation without anchors
      runtime denial from P4 scoped drift
      runtime coverage claim
      monitor verification claim
      protection/hypervisor-grade claim
      cost/deployment claim

  next:
    P4 implementation is still not approved. Build a P4 anchor manifest and
    runtime/static final-run anchor observability. Keep P4 allow-all only.
    P5 remains blocked.

N-169 P4 anchor manifest:
  artifacts:
    capsched-models/analysis/0125-sched-exec-lease-p4-anchor-manifest.md
    capsched-models/analysis/sched-exec-lease-p4-anchor-manifest-v1.json
    capsched-models/formal/0094-p4-anchor-manifest-gate-model/
    capsched-models/validation/0144-sched-exec-lease-p4-anchor-manifest-validation.md
    capsched-models/validation/run-sched-exec-lease-p4-anchor-manifest-check.sh

  verdict:
    P4 anchor-manifest blocker is closed, but P4 implementation is not
    approved.

  source checker:
    run_dir:
      build/source-check/sched-exec-lease-p4-anchors/20260702T210555Z-n169-p4-anchor
    work_commit:
      d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
    anchor_count:
      3

  anchors:
    A1 final-run allow-all join:
      kernel/sched/core.c __schedule
      insert interval lines 7196..7198 in current source
      after rq->last_seen_need_resched_ns = 0
      before is_switch = prev != next
      before rq->curr publication and context_switch
      not P5-denial-safe

    A2 common queued move:
      kernel/sched/core.c move_queued_task
      insert interval lines 2552..2553
      before deactivate_task and set_task_cpu

    A3 double-rq queued move:
      kernel/sched/sched.h move_queued_task_locked
      insert interval lines 4125..4126
      before deactivate_task and set_task_cpu

  TLC:
    safe passed with 2 generated states, 1 distinct state, depth 1.
    12 unsafe configs produced expected counterexamples for missing anchors,
    final run after rq->curr, move after detach/CPU mutation, missing
    non-coverage, implementation approval from manifest, runtime denial,
    runtime coverage, protection, and cost/deployment claims.

  next:
    Build runtime/static final-run anchor observability, allow-all helper proof,
    and no reachable denial path proof before any P4 patch. Keep P4 allow-all
    only. P5 remains blocked.

N-170 static final-run observability:
  artifacts:
    capsched-models/analysis/0126-sched-exec-lease-p4-static-final-run-observability.md
    capsched-models/analysis/sched-exec-lease-p4-static-final-run-observability-v1.json
    capsched-models/formal/0095-static-final-run-observability-gate-model/
    capsched-models/validation/0145-sched-exec-lease-p4-static-final-run-observability-validation.md
    capsched-models/validation/run-sched-exec-lease-p4-static-final-run-observability.sh

  verdict:
    Static final-run observability blocker is closed. Runtime final-run
    coverage remains unproven.

  source checker:
    run_dir:
      build/source-check/sched-exec-lease-p4-final-run-observability/20260702T211219Z-n170-static-final-run
    work_commit:
      d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
    window_start/window_end:
      7065/7249
    insert_after/insert_before:
      7196/7198
    rq_curr_line:
      7205
    trace_sched_switch_line:
      7235
    p3_note_switch_line:
      7237
    context_switch_line:
      7239

  important negative:
    Existing P3 sched_exec_lease_note_switch(prev, next) is after rq->curr
    publication, so it is not a P4 precommit anchor and not runtime coverage
    evidence.

  TLC:
    safe passed with 2 generated states, 1 distinct state, depth 1.
    9 unsafe configs produced expected counterexamples for missing source
    check, missing static anchor, anchor after rq->curr, P3 marker as
    precommit, runtime coverage from static source, implementation approval,
    runtime denial, protection, and cost/deployment claims.

  next:
    Build allow-all helper proof and no reachable denial path proof before any
    P4 patch. Keep P4 allow-all only. P5 remains blocked.

P4 allow-all helper proof / validation 0146:
  status:
    The prepatch allow-all/no-reachable-denial helper proof is closed. No Linux
    P4 patch has been applied or approved by this proof.

  artifacts:
    capsched-models/analysis/0127-sched-exec-lease-p4-allow-all-helper-proof.md
    capsched-models/analysis/sched-exec-lease-p4-allow-all-helper-proof-v1.json
    capsched-models/formal/0096-p4-allow-all-helper-gate-model/
    capsched-models/validation/0146-sched-exec-lease-p4-allow-all-helper-proof-validation.md
    capsched-models/validation/run-sched-exec-lease-p4-allow-all-helper-proof.sh

  source checker:
    run_dir:
      build/source-check/sched-exec-lease-p4-allow-all-helper/20260702T211836Z-n171-allow-all
    work_commit:
      d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
    allow_helper_line:
      80
    allow_return_line:
      82

  meaning:
    Current sched_exec_allow_all_validation() returns only
    SCHED_EXEC_VALIDATION_ALLOW. No current return statement returns RETRY,
    INELIGIBLE, or QUARANTINE. No P4 validate-run/move helpers exist yet, and
    scheduler code does not branch on SchedExecLease validation results.

  TLC:
    safe passed with 2 generated states, 1 distinct state, depth 1.
    15 unsafe configs produced expected counterexamples for missing source
    check, helper returning non-allow, non-allow reachability, scheduler
    branching, retry/quarantine/monitor/budget/ABI behavior, implementation
    approval, runtime coverage, protection, and cost/deployment overclaims.

  next:
    The next reviewable step is the actual P4 allow-all skeleton patch. It must
    still pass generated-code/object review, CONFIG off/on build validation,
    QEMU compatibility validation, and overclaim/security-diff review before
    acceptance. P5 denial remains blocked.

P4 allow-only skeleton implementation / validation 0147:
  status:
    Applied to Linux and partially validated. Full vmlinux off/on validation is
    complete in validation/0148. QEMU off/on boot/workload validation is
    complete in validation/0149. Final overclaim/security review is complete
    in analysis/0128 and validation/0150. P4 allow-only compatibility slice is
    closed.

  Linux:
    commit:
      a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
    subject:
      sched/exec_lease: Add allow-only validation skeleton
    patch queue:
      linux-patches/patches/capsched-linux-l0/0007-sched-exec-lease-Add-allow-only-validation-skel.patch

  implementation artifacts:
    capsched-models/implementation/0027-sched-exec-lease-p4-allow-only-validation-skeleton-implementation.md
    capsched-models/implementation/sched-exec-lease-p4-allow-only-validation-skeleton-implementation-v1.json
    capsched-models/formal/0097-p4-allow-only-skeleton-gate-model/
    capsched-models/validation/0147-sched-exec-lease-p4-allow-only-skeleton-validation.md
    capsched-models/validation/run-sched-exec-lease-p4-allow-only-skeleton-check.sh

  patch content:
    Moves SCHED_EXEC_VALIDATION_* enum to include/linux/sched_exec_lease.h.
    Adds static inline validate helpers:
      sched_exec_lease_validate_run_edge()
      sched_exec_lease_validate_move_edge()
      sched_exec_lease_validate_move_edge_locked()
    Adds three callsites:
      __schedule() before is_switch/rq->curr/context_switch
      move_queued_task() before deactivate_task/set_task_cpu
      move_queued_task_locked() before deactivate_task/set_task_cpu

  validation passed:
    patch queue replay to exact HEAD a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8.
    checkpatch: 0 errors, 0 warnings.
    targeted CONFIG_SCHED_EXEC_LEASE off/on scheduler build passed.
    source/object checker run:
      build/source-check/sched-exec-lease-p4-allow-only-skeleton/20260702T2136Z-p4-allow-only
    helper_count=3, callsite_count=3.
    non_allow_returns_found=false.
    scheduler_branches_on_validation_result=false.
    validation_symbols_emitted=false.
    core_o_file_size_equal=true, 347728/347728.
    formal/0097 safe passed; 12 unsafe configs produced expected
    counterexamples.
    full vmlinux off/on build passed in validation/0148:
      off config undef, vmlinux present, exec_lease.o absent.
      on config y, vmlinux present, exec_lease.o present.
      log: build/logs/sched-exec-lease-full-build-20260702T214346Z.log
    QEMU off/on boot/workload smoke passed in validation/0149:
      off run: build/qemu/sched-exec-lease-p4-allow-only-matrix/20260702T220800Z-off
      on run: build/qemu/sched-exec-lease-p4-allow-only-matrix/20260702T221639Z-on
      both qemu_status=0 and WORKLOAD_RET 0.

  important negative:
    core.o byte identity is not claimed.
    QEMU does not prove runtime coverage: pick_next_task and __schedule remain
    function-missing/kprobe-unavailable in this runner.
    runtime denial, runtime coverage, budget enforcement, monitor verification,
    production protection, hypervisor-grade isolation, cost-efficiency,
    deployment readiness, and P5 denial remain false.

  next:
    P5 readiness has now been reopened and refreshed in analysis/0129,
    formal/0098, and validation/0151. Keep P5 denial blocked until the
    preconditions below are implemented and validated.

P5 readiness after P4 / validation 0151:
  status:
    Refreshed against actual P4 Linux commit
    a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8. P5 remains blocked.

  artifacts:
    capsched-models/analysis/0129-sched-exec-lease-p5-readiness-refresh-after-p4.md
    capsched-models/analysis/sched-exec-lease-p5-readiness-refresh-after-p4-v1.json
    capsched-models/formal/0098-p5-readiness-after-p4-gate-model/
    capsched-models/validation/0151-sched-exec-lease-p5-readiness-after-p4.md
    capsched-models/validation/run-sched-exec-lease-p5-readiness-after-p4.sh

  source checker:
    run_dir:
      build/source-check/sched-exec-lease-p5-readiness-after-p4/20260702T-p5-readiness-after-p4
    result:
      run_hook_before_rq_curr=true.
      run_hook_before_context_switch=true.
      run_hook_after_pick_next_task=true.
      known_class_settlement_before_run_hook_source=true.
      run_hook_p5_deny_ready=false.
      common_move_hook_before_mutation=true.
      locked_move_hook_before_mutation=true.
      common_move_returns_status=false.
      locked_move_returns_status=false.
      p5_approved=false.

  TLC:
    formal/0098 safe passed.
    9 unsafe configs produced expected counterexamples.

  key finding:
    The P4 run hook is pre-rq->curr but not pre-class-settle. It must not be
    turned into a denying hook without moving validation before class
    settlement or proving rollback. Move hooks are locally pre-mutation but
    callers assume success, so P5 move denial needs status plumbing first.

  next:
    Design-only next step is a P5 implementation-scope proposal, not Linux
    code. It must define pre-settle run denial or rollback, move status
    plumbing, negative tests, path classification enforcement, and claim ledger
    constraints before any behavior-changing patch.

P5A scope gate / validation 0152:
  status:
    Recorded P5A scope only. No Linux implementation, behavior change, or
    runtime denial is approved.

  artifacts:
    capsched-models/analysis/0130-sched-exec-lease-p5a-scope-proposal.md
    capsched-models/analysis/sched-exec-lease-p5a-scope-proposal-v1.json
    capsched-models/implementation/0028-sched-exec-lease-p5a-scope-proposal.md
    capsched-models/implementation/sched-exec-lease-p5a-scope-proposal-v1.json
    capsched-models/formal/0099-p5a-scope-gate-model/
    capsched-models/validation/0152-sched-exec-lease-p5a-scope-gate.md
    capsched-models/validation/run-sched-exec-lease-p5a-scope-gate.sh

  decomposition:
    P5A0:
      no-behavior infrastructure proposal.
    P5A-R:
      run-denial design only; deny-one-CFS-and-pick-next requires fair-picker
      eligibility integration.
    P5A-M:
      move status-plumbing design only; broad common move denial is rejected
      until caller status settlement covers migration, affinity, swap, push,
      and core-cookie-steal paths.
    P5A-V:
      validation and claim ledger.

  validation:
    Source/JSON gate run 20260702T-p5a-scope passed.
    formal/0099 safe passed.
    10 unsafe configs produced expected counterexamples.

  next:
    The next reviewable work is P5A0 no-behavior infrastructure proposal:
    fresh drift row, patch queue plan, source checker plan, build/QEMU
    disabled-behavior plan, negative-test harness plan, claim ledger row, and
    explicit non-claims.

P5A0 no-behavior gate / validation 0153:
  status:
    Recorded and validated P5A0 proposal only. No Linux patch, behavior
    change, runtime denial, retry, fail-closed path, quarantine, public ABI,
    monitor call, production protection claim, or cost-efficiency claim is
    approved.

  artifacts:
    capsched-models/analysis/0131-sched-exec-lease-p5a0-no-behavior-infrastructure-proposal.md
    capsched-models/analysis/sched-exec-lease-p5a0-no-behavior-infrastructure-proposal-v1.json
    capsched-models/implementation/0029-sched-exec-lease-p5a0-no-behavior-infrastructure-proposal.md
    capsched-models/implementation/sched-exec-lease-p5a0-no-behavior-infrastructure-proposal-v1.json
    capsched-models/formal/0100-p5a0-no-behavior-gate-model/
    capsched-models/validation/0153-sched-exec-lease-p5a0-no-behavior-gate.md
    capsched-models/validation/run-sched-exec-lease-p5a0-no-behavior-gate.sh

  validation:
    Strengthened JSON gate run 20260702T-p5a0-regate2 passed against Linux commit
    a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8.
    formal/0100 safe passed.
    14 unsafe configs produced expected counterexamples.

  next:
    P5A0.E prepatch evidence package. P5A-R CFS deny and P5A-M broad move
    denial remain later design work.

P5A0.E prepatch evidence / validation 0154:
  status:
    Recorded and validated evidence package only. No Linux patch, behavior
    change, runtime denial, runtime coverage, monitor verification,
    protection, cost, deployment, datacenter, or global freshness claim is
    approved.

  naming:
    P5A0.E is evidence only.
    P5A0.P1 is the future first no-behavior Linux patch proposal.
    P5A0.P2 is future move-status plumbing.

  artifacts:
    capsched-models/analysis/0132-sched-exec-lease-p5a0-e-prepatch-evidence.md
    capsched-models/analysis/sched-exec-lease-p5a0-e-prepatch-evidence-v1.json
    capsched-models/implementation/0030-sched-exec-lease-p5a0-e-prepatch-evidence.md
    capsched-models/implementation/sched-exec-lease-p5a0-e-prepatch-evidence-v1.json
    capsched-models/formal/0101-p5a0-e-prepatch-evidence-gate-model/
    capsched-models/validation/0154-sched-exec-lease-p5a0-e-prepatch-evidence.md
    capsched-models/validation/run-sched-exec-lease-p5a0-e-prepatch-evidence.sh

  validation:
    Fresh drift run 20260702T-p5a0-1-drift has l0_footprint and
    scheduler_authority_core fresh; device_queue_iommu remains D4 stale and
    barred from broad claims.
    Source/JSON gate run 20260702T-p5a0-e-prepatch passed.
    formal/0101 safe passed.
    14 unsafe configs produced expected counterexamples.

  next:
    P5A0.P1 no-behavior patch plan, limited by default to
    include/linux/sched_exec_lease.h and kernel/sched/exec_lease.c. Touching
    scheduler control-flow files reopens scope.

P5A0.P1 patch-plan gate / validation 0155:
  status:
    Recorded and validated patch plan only. No Linux patch, `0008` patch,
    behavior change, runtime denial, runtime coverage, ABI, monitor call,
    production protection, cost, datacenter, or global freshness claim is
    approved.

  artifacts:
    capsched-models/analysis/0133-sched-exec-lease-p5a0-p1-no-behavior-patch-plan.md
    capsched-models/analysis/sched-exec-lease-p5a0-p1-no-behavior-patch-plan-v1.json
    capsched-models/implementation/0031-sched-exec-lease-p5a0-p1-no-behavior-patch-plan.md
    capsched-models/implementation/sched-exec-lease-p5a0-p1-no-behavior-patch-plan-v1.json
    capsched-models/formal/0102-p5a0-p1-patch-plan-gate-model/
    capsched-models/validation/0155-sched-exec-lease-p5a0-p1-patch-plan.md
    capsched-models/validation/run-sched-exec-lease-p5a0-p1-patch-plan-gate.sh

  validation:
    Source/JSON gate run 20260702T-p5a0-p1-plan passed.
    formal/0102 safe passed and requires PlanRecordedEventually.
    20 unsafe configs produced expected counterexamples.

  key constraints:
    Future P5A0.P1 must be measured as the `0008` delta, not as the full
    existing queue footprint.
    Default file allowlist is only include/linux/sched_exec_lease.h and
    kernel/sched/exec_lease.c.
    Hot-path helper bodies are frozen.
    exec_lease.c lifecycle helper behavior is frozen because fork/exec/exit
    already call those helpers.
    Future acceptance requires replay, upstream replay, merge-tree, source
    checker, off/on full builds, QEMU denial-disabled smoke,
    object/symbol/disassembly, section-size and hot-function growth review,
    layout review, and overclaim/security review.

  next:
    Future P5A0.P1 no-behavior Linux patch draft under this gate. P5A-R CFS
    denial and P5A-M broad move denial remain blocked.

P5A0.P1 concrete 0008 source/full-build/object-layout/upstream/QEMU gate /
validations 0156-0161:
  status:
    Concrete `0008` exists and is accepted as source-contract/no-behavior
    evidence only. Full `vmlinux` build passed for
    `CONFIG_SCHED_EXEC_LEASE=off/on`. Object/symbol/section-size, hot
    scheduler function-size, build-only task layout checks, and
    candidate-scoped upstream maintenance checks, and QEMU off/on boot/workload
    smoke passed. Final overclaim/security review passed in validation/0161.

  linux:
    parent: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
    head:   d812f83c033a9f9b3d533e667e7106a5734eb30b
    patch:  linux-patches/patches/capsched-linux-l0/0008-sched-exec_lease-Document-P5A0.P1-no-behavior-bounda.patch

  artifacts:
    capsched-models/implementation/0032-sched-exec-lease-p5a0-p1-no-behavior-implementation.md
    capsched-models/implementation/sched-exec-lease-p5a0-p1-no-behavior-implementation-v1.json
    capsched-models/formal/0103-p5a0-p1-0008-source-gate-model/
    capsched-models/validation/0156-sched-exec-lease-p5a0-p1-0008-source.md
    capsched-models/validation/0157-sched-exec-lease-p5a0-p1-full-build.md
    capsched-models/validation/0158-sched-exec-lease-p5a0-p1-object-layout.md
    capsched-models/validation/0159-sched-exec-lease-p5a0-p1-upstream-maintenance.md
    capsched-models/validation/0160-sched-exec-lease-p5a0-p1-qemu-boot-smoke.md
    capsched-models/validation/0161-sched-exec-lease-p5a0-p1-final-overclaim-security-review.md
    capsched-models/validation/run-sched-exec-lease-p5a0-p1-0008-source-check.sh
    capsched-models/validation/run-sched-exec-lease-p5a0-p1-0008-object-check.sh
    capsched-models/validation/run-sched-exec-lease-p5a0-p1-0008-upstream-check.sh

  validation:
    Source gate run 20260702T-p5a0-p1-0008-source passed.
    Patch queue replay matched exact Linux head and tree.
    formal/0103 safe passed.
    11 unsafe configs produced expected counterexamples.
    Systemd unit capsched-p5a0-p1-0008-full-build.service passed.
    CONFIG_SCHED_EXEC_LEASE=off full vmlinux built with exec_lease.o absent.
    CONFIG_SCHED_EXEC_LEASE=on full vmlinux built with exec_lease.o present.
    Object checker run 20260703T-p5a0-p1-0008-object passed.
    Task layout probe run 20260703T005619Z passed.
    core.o function-size tables match off/on; validation helpers emit no
    symbols; exec_lease.o has expected lifecycle symbols.
    Upstream checker run 20260703T-p5a0-p1-0008-upstream passed.
    candidate_anchor_drift_count=0, merge_tree_clean=true.
    strict checkpatch passed with 0 errors and 0 warnings.
    get_maintainer emitted 12 rows.
    QEMU matrix run 20260703T010812Z passed off/on.
    workload_mode=all, qemu_status=0, workload_ret=0 for both modes.
    Codex Security diff scan reported 0 findings with complete diff-scoped
    coverage for include/linux/sched_exec_lease.h and kernel/sched/exec_lease.c.

  non-claims:
    No behavior change, runtime denial, fair-picker ineligibility, broad move
    denial, runtime coverage, ABI, monitor call, monitor verification,
    production protection, hypervisor-grade isolation, cost, deployment, or
    datacenter claim is approved.

  next:
    P5A-R must start with fair-picker eligibility integration. P5A-M must
    start with status settlement for migration, affinity, swap/push/pull,
    hotplug, and core-cookie-steal.

P5A-R CFS picker source map / validation 0162:
  status:
    Recorded and source-map validated only. No Linux behavior patch, runtime
    denial, CFS deny-and-repick, runtime coverage, monitor verification,
    protection, cost, deployment, or datacenter claim is approved.

  artifacts:
    capsched-models/analysis/0135-sched-exec-lease-p5a-r-cfs-picker-eligibility-source-map.md
    capsched-models/analysis/sched-exec-lease-p5a-r-cfs-picker-eligibility-source-map-v1.json
    capsched-models/validation/0162-sched-exec-lease-p5a-r-cfs-picker-source-map.md

  source findings:
    P4 run-edge validation is after pick_next_task and put_prev_set_next_task
    settlement, so it is too late for deny-and-repick without rollback.
    pick_task_fair descends CFS group hierarchy through pick_next_entity and
    pick_eevdf.
    sched_delayed is delayed dequeue, not lease denial.
    RETRY_TASK alone can spin unless denied candidates are picker-visible.
    Core scheduling can cache core_pick and replace picks through cookie search.
    DL servers can nest fair picks.
    Proxy execution splits donor and executor.
    sched_ext switched-all paths bypass CFS.

  next:
    P5A-R picker ineligibility gate: attempt-local denied-candidate carrier,
    bounded retry, hierarchy settlement, core/DL/proxy/SCX exclusion or
    settlement, and accounting separation.

P5A-R picker ineligibility gate / validation 0163:
  status:
    Recorded and validated as a pre-code formal/source gate only. No Linux
    behavior patch, runtime denial, CFS deny-and-repick, runtime coverage,
    monitor verification, protection, cost, deployment, or datacenter claim is
    approved.

  artifacts:
    capsched-models/analysis/0136-sched-exec-lease-p5a-r-picker-ineligibility-gate.md
    capsched-models/analysis/sched-exec-lease-p5a-r-picker-ineligibility-gate-v1.json
    capsched-models/formal/0104-p5a-r-picker-ineligibility-gate-model/
    capsched-models/validation/0163-sched-exec-lease-p5a-r-picker-ineligibility-gate.md
    capsched-models/validation/run-sched-exec-lease-p5a-r-picker-ineligibility-gate.sh

  validation:
    Source anchors passed with anchor_count=15.
    TLC safe passed with 6 generated states, 5 distinct states, depth 5.
    28 unsafe configs produced expected counterexamples.

  constraints now enforced by the gate:
    attempt-local rq-locked denied-candidate carrier
    bounded retry and picker-visible ineligibility
    pre-class-state and pre-rq-curr validation
    no linear search or unbounded retry
    no hot persistent denial layout in the first candidate
    no wakeup-preempt bleed
    task/exec/domain/grant generation freshness
    hierarchy and cgroup mutation settlement
    all pick_eevdf return paths covered
    core/DL/proxy/SCX settlement or exclusion
    no delayed-dequeue/throttle lifetime alias
    no Linux-local authority forgery

  next:
    Build a source-shape checker for EEVDF return dominance, then a group
    hierarchy settlement model. P5A-M move settlement remains separate.

P5A-R EEVDF return dominance / validation 0164:
  status:
    Executable source-shape checker passed. No Linux behavior patch, runtime
    denial, CFS deny-and-repick, group hierarchy settlement, runtime coverage,
    monitor verification, protection, cost, deployment, or datacenter claim is
    approved.

  artifacts:
    capsched-models/analysis/0137-sched-exec-lease-p5a-r-eevdf-return-dominance.md
    capsched-models/analysis/sched-exec-lease-p5a-r-eevdf-return-dominance-v1.json
    capsched-models/formal/0105-p5a-r-eevdf-return-dominance-model/
    capsched-models/validation/0164-sched-exec-lease-p5a-r-eevdf-return-dominance.md
    capsched-models/validation/run-sched-exec-lease-p5a-r-eevdf-return-dominance.sh

  validation:
    Run 20260703T085043Z passed.
    source anchors 17/17, missing 0, line drift 0.
    pick_eevdf direct return count 4.
    semantic candidate families 6.
    forbidden scan count 0.
    safe TLC: 13 generated states, 7 distinct states, depth 2.
    unsafe TLC: 11 expected counterexamples.

  source-shape result:
    Current pick_eevdf has four syntactic direct returns but six semantic
    candidate families: singleton, next buddy, protected current, leftmost
    eligible, heap search, and final current override. Any future denial must
    dominate all six. Passing this checker proves only the recorded source
    shape, not group hierarchy settlement.

  next:
    P5A-R group hierarchy settlement gate: LeafDenied, PathDenied,
    ChildCfsRqExhausted, ParentSkipJustified, and ParentOverDenied unsafe case.

P5A-R group hierarchy settlement / validation 0165:
  status:
    Source/formal gate passed. No Linux behavior patch, runtime denial, CFS
    deny-and-repick, group hierarchy implementation, runtime coverage, monitor
    verification, protection, cost, deployment, or datacenter claim is approved.

  artifacts:
    capsched-models/analysis/0138-sched-exec-lease-p5a-r-group-hierarchy-settlement.md
    capsched-models/analysis/sched-exec-lease-p5a-r-group-hierarchy-settlement-v1.json
    capsched-models/formal/0106-p5a-r-group-hierarchy-settlement-model/
    capsched-models/validation/0165-sched-exec-lease-p5a-r-group-hierarchy-settlement.md
    capsched-models/validation/run-sched-exec-lease-p5a-r-group-hierarchy-settlement.sh

  validation:
    Run 20260703T214938Z passed.
    source anchors 21/21, missing 0, line drift 0.
    semantic hierarchy source shape ok.
    safe TLC: 9 generated states, 7 distinct states, depth 5.
    unsafe TLC: 13 expected counterexamples.

  result:
    LeafDenied, PathDenied, ChildCfsRqExhausted, ParentSkipJustified, and
    ParentOverDenied are now separated at pre-code design level. Parent skip
    requires explicit child exhaustion, and allowed sibling descendants must
    remain pickable. Linux accounting aliases such as nr_queued, sleep,
    throttle, delayed dequeue, yield, or EEVDF lag cannot prove exhaustion.

  next:
    P5A-R core/DL/proxy/SCX exclusion-or-settlement gate.

P5A-R cross-path exclusion/settlement / validation 0166:
  status:
    Source/formal gate passed. No Linux behavior patch, runtime denial, CFS
    deny-and-repick, core/DL/proxy/SCX implementation, runtime coverage, monitor
    verification, protection, cost, deployment, or datacenter claim is approved.

  artifacts:
    capsched-models/analysis/0139-sched-exec-lease-p5a-r-cross-path-exclusion-settlement.md
    capsched-models/analysis/sched-exec-lease-p5a-r-cross-path-exclusion-settlement-v1.json
    capsched-models/formal/0107-p5a-r-cross-path-exclusion-settlement-model/
    capsched-models/validation/0166-sched-exec-lease-p5a-r-cross-path-exclusion-settlement.md
    capsched-models/validation/run-sched-exec-lease-p5a-r-cross-path-exclusion-settlement.sh

  validation:
    Run 20260703T220432Z passed.
    source anchors 34/34, missing 0, line drift 0.
    semantic cross-path source shape ok.
    safe TLC: 5 generated states, 4 distinct states, depth 4.
    unsafe TLC: 18 expected counterexamples.

  result:
    P5A-R ordinary-CFS-only behavior must exclude or separately settle core
    scheduling cached/sibling/cookie paths, DL fair/ext servers, proxy
    donor/executor rewriting, sched_ext/switched-all, and class-loop non-fair
    selection before deny-one-pick-next semantics are claimed.

  next:
    overhead/layout gate is recorded below; current remaining work is negative
    validation plan and implementation patch plan.

P5A-R overhead/layout gate / validation 0167:
  status:
    Source/formal gate passed. No Linux behavior patch, runtime denial, CFS
    deny-and-repick, hot layout change, disabled-overhead change, runtime
    coverage, benchmark, monitor verification, protection, cost, deployment, or
    datacenter claim is approved.

  artifacts:
    capsched-models/analysis/0140-sched-exec-lease-p5a-r-overhead-layout-gate.md
    capsched-models/analysis/sched-exec-lease-p5a-r-overhead-layout-gate-v1.json
    capsched-models/formal/0108-p5a-r-overhead-layout-gate-model/
    capsched-models/validation/0167-sched-exec-lease-p5a-r-overhead-layout-gate.md
    capsched-models/validation/run-sched-exec-lease-p5a-r-overhead-layout-gate.sh

  validation:
    Run 20260703T221311Z passed.
    source anchors 22/22, missing 0, line drift 0.
    allow_return_count=3, non_allow_return_count=0.
    branch_on_validation_count=0.
    safe TLC: 6 generated states, 5 distinct states, depth 5.
    unsafe TLC: 18 expected counterexamples.

  result:
    P5A-R first behavior candidate must remain attempt-local, bounded,
    pre-frozen, candidate-identity-only, and free of unbounded scans or
    persistent hot denial layout. Disabled overhead and hot layout/function
    changes require separate object/layout evidence.

  next:
    negative validation plan is recorded below; current remaining work is the
    implementation patch plan.

P5A-R negative validation plan / validation 0168:
  status:
    Source/formal validation-plan gate passed. No Linux behavior patch, test
    instrumentation, runtime denial, CFS deny-and-repick, runtime coverage,
    benchmark, monitor verification, protection, cost, deployment, or
    datacenter claim is approved.

  artifacts:
    capsched-models/analysis/0141-sched-exec-lease-p5a-r-negative-validation-plan.md
    capsched-models/analysis/sched-exec-lease-p5a-r-negative-validation-plan-v1.json
    capsched-models/formal/0109-p5a-r-negative-validation-plan-model/
    capsched-models/validation/0168-sched-exec-lease-p5a-r-negative-validation-plan.md
    capsched-models/validation/run-sched-exec-lease-p5a-r-negative-validation-plan.sh

  validation:
    Run 20260703T222038Z passed.
    source anchors 5/5, prior_missing_count=0.
    negative_test_family_count=14.
    required_observable_count=19.
    safe TLC: 6 generated states, 5 distinct states, depth 5.
    unsafe TLC: 17 expected counterexamples.

  result:
    Future P5A-R behavior tests must prove denied candidates do not reach
    rq->curr or sched_switch, cannot be repicked in the same attempt, do not
    over-deny parents, do not bypass EEVDF/cross-path gates, and do not
    introduce O(n)/hot-layout or claim-overreach regressions.

  next:
    implementation patch plan.

P5A-R ordinary-CFS patch plan / validation 0169:
  status:
    Source/formal patch-plan gate passed. Linux `0009` may now be drafted as
    an ordinary-CFS-only behavior candidate, but the patch is not accepted and
    runtime denial/CFS deny-and-repick correctness remains unapproved.

  artifacts:
    capsched-models/implementation/0033-sched-exec-lease-p5a-r-ordinary-cfs-patch-plan.md
    capsched-models/implementation/sched-exec-lease-p5a-r-ordinary-cfs-patch-plan-v1.json
    capsched-models/formal/0110-p5a-r-ordinary-cfs-patch-plan-model/
    capsched-models/validation/0169-sched-exec-lease-p5a-r-ordinary-cfs-patch-plan.md
    capsched-models/validation/run-sched-exec-lease-p5a-r-ordinary-cfs-patch-plan.sh

  validation:
    Run 20260703T230145Z passed.
    source anchors 10/10, prior gates present.
    pre_settle_window_ok=true.
    p4_late_for_p5ar_ok=true.
    cross_path_anchors_ok=true.
    acceptance_validation_count=22.
    safe TLC: 6 generated states, 5 distinct states, depth 5.
    unsafe TLC: 16 expected counterexamples.

  result:
    Next Linux patch slot is `0009`. It may be drafted only as an
    ordinary-CFS-only behavior candidate with pre-settle picker-visible denial,
    bounded attempt-local carrier, hierarchy and cross-path settlement or
    exclusion, no O(n) scan, no persistent hot denial layout, and no public
    ABI/trace ABI/monitor call/exported symbol.

  still required before accepting 0009:
    patch replay, upstream replay or merge-tree, strict checkpatch and
    get_maintainer, source-shape checks, full off/on builds, object/layout
    evidence, QEMU denial-disabled smoke, QEMU negative denial tests, security
    diff review, and final overclaim review.

P5A-R implementation-ready audit / validation 0170:
  status:
    Final audit passed for patch drafting only. This completes the P5A-R
    pre-code implementation-ready goal: the future Linux `0009` patch may be
    drafted, but remains unaccepted.

  artifacts:
    capsched-models/analysis/0142-sched-exec-lease-p5a-r-implementation-ready-audit.md
    capsched-models/analysis/sched-exec-lease-p5a-r-implementation-ready-audit-v1.json
    capsched-models/formal/0111-p5a-r-implementation-ready-audit-model/
    capsched-models/validation/0170-sched-exec-lease-p5a-r-implementation-ready-audit.md
    capsched-models/validation/run-sched-exec-lease-p5a-r-implementation-ready-audit.sh

  validation:
    Run 20260703T231125Z passed.
    required validations 7/7, missing 0.
    required models 7/7, missing 0.
    linux_0009_may_be_drafted=true.
    linux_0009_exists=false.
    linux_0009_accepted=false.
    runtime_denial_approved=false.
    cfs_deny_and_repick_approved=false.
    safe TLC: 5 generated states, 4 distinct states, depth 4.
    unsafe TLC: 10 expected counterexamples.

  next:
    Draft Linux patch `0009` under implementation/0033, then validate it as an
    untrusted candidate. Do not claim runtime correctness, runtime coverage,
    production protection, cost-efficiency, deployment, or datacenter readiness
    until direct acceptance evidence exists.

P5A-R upstream drift/source-shape refresh / validation 0171:
  status:
    Passed after fetching upstream/master to
    71dfdfb0209b43dfd6f494f84f5548e4cfd18cb5. P5A-R direct scheduler
    source-shape drift is zero; fork/exec lifecycle drift is recorded and not
    claimed fresh.

  validation:
    Run 20260703T233452Z passed.
    previous_upstream=87320be9f0d24fce67631b7eef919f0b79c3e45c.
    current_upstream=71dfdfb0209b43dfd6f494f84f5548e4cfd18cb5.
    direct_source_shape_changed_count=0.
    lifecycle_changed_count=2.
    merge_tree_clean=true.
    ordinary_cfs_0009_draft_reviewable=true.
    safe TLC: 5 generated states, 4 distinct states, depth 4.
    unsafe TLC: 9 expected counterexamples.

  final audit refresh:
    validation/0170 was rerun after this refresh with run
    20260703T234210Z. It now requires 8 validations and 8 models, includes
    upstream/master 71dfdfb0209b43dfd6f494f84f5548e4cfd18cb5, and still
    concludes only that Linux `0009` may be drafted. Runtime/protection/cost
    claims remain false.

P5A-R Linux 0009 source gate / validation 0172:
  status:
    Linux patch `0009` has been drafted and source-gated as an untrusted,
    dormant ordinary-CFS-only behavior candidate. It is not accepted.

  Linux / patch queue:
    parent: d812f83c033a9f9b3d533e667e7106a5734eb30b
    commit: 7a402107fd63faf7063c2dea05e88e7f8a23f4bf
    subject: sched/fair: Draft ordinary CFS exec lease candidate
    patch: linux-patches/patches/capsched-linux-l0/0009-sched-fair-Draft-ordinary-CFS-exec-lease-candidate.patch
    patch sha256: 21dd92416d8309b82a2da7ead8fa9998661cff645f845dcdd0066b6393cd2d25
    replay: build/replay/capsched-linux-l0-0009-20260703T231733Z
    replay final HEAD: 7a402107fd63faf7063c2dea05e88e7f8a23f4bf

  validation:
    Run 20260703T-p5ar-0009-source passed.
    checkpatch_clean=true.
    diff_check_clean=true.
    delta_files_exact_allowlist=true.
    ordinary_cfs_wrapper_before_settlement=true.
    static_key_dormant=true.
    cross_path_predicate_present=true.
    attempt_local_carrier_present=true.
    pick_eevdf_pickable_checks=6.
    safe TLC: 5 generated states, 4 distinct states, depth 4.
    unsafe TLC: 10 expected counterexamples.

  build note:
    The initial targeted scheduler object build was blocked because the host
    lacked `/usr/include/gelf.h`, required by objtool. After installing
    `libelf-dev`, validation/0173 passed targeted CONFIG off/on builds.

  targeted build / validation 0173:
    Run 20260704T-p5ar-0009-targeted-build passed.
    off fair.o size=164608 sha256=00d68ab37b06b4f84cf303949600666df5fc3376c0df28120c067fd3994b8dea.
    off core.o size=364448 sha256=82db4e1ee48088a9cc85fa2694efc24ce7416b68a704a0d534391c547a1a1f69.
    on fair.o size=166376 sha256=ef39d7414cf451770f093e1962d59cb766afecb06157a4f3b7942d1a9b5f512b.
    on core.o size=364448 sha256=d8a85d9edc8578c8a991ec928d5e953734965a7dcc2e18ec5365640f76128863.

  non-claims:
    `0009` is not accepted. Runtime denial correctness, CFS deny-and-repick
    correctness, runtime coverage, production protection, cost, deployment, and
    datacenter claims remain false.

  next:
    Acceptance evidence still requires negative ordinary CFS denial tests,
    security diff review, and final overclaim review.

P5A-R Linux 0009 full build / validation 0174:
  status:
    Passed for full CONFIG off/on `vmlinux` build. This is build
    compatibility evidence only; `0009` is not accepted.

  unit:
    capsched-p5a-r-0009-full-build.service
    invocation_id=f9b4db8339574e9fb88a90056ce6d989

  command:
    systemd-run --user --unit=capsched-p5a-r-0009-full-build --collect
    --property=WorkingDirectory=/media/nia/scsiusb/dev/linux-cap
    /usr/bin/env BUILD_TAG=p5a-r-0009 JOBS=8
    /media/nia/scsiusb/dev/linux-cap/capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh

  log:
    /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-full-build-20260704T032455Z.log

  result:
    Result=success
    ExecMainStatus=0
    off completed at 2026-07-03T23:33:07-04:00
    on completed at 2026-07-03T23:41:13-04:00

  outputs:
    off vmlinux sha256=f76dbaed7fd47fe812475f26a10d43053911e0d4319a6eb4681db378ba26eb1f
    on vmlinux sha256=367103fd9d3bb1bdebcb87d1cbcf9ac47fee4639b76b06bb7934f9f3c5cd8281
    on exec_lease.o sha256=75e4085156ebb0610edbef3af9bf281bfc560edc1a59c2246a79c26f6807dd1e
    off exec_lease.o absent

  non-claims:
    Runtime denial correctness, CFS deny-and-repick correctness,
    runtime coverage, protection, cost, deployment, and datacenter claims
    remain false.

P5A-R Linux 0009 object/layout / validation 0175:
  status:
    Passed for object/function-size and task layout evidence. This is not
    runtime behavior evidence and `0009` remains unaccepted.

  validation:
    Run 20260704T-p5ar-0009-object-layout passed.
    off fair.o size=157712 sha256=9ef74eed7997d5898b16fb52117c29ca3ecd67423ee527399ab4bbc5ad1854aa.
    on fair.o size=159416 sha256=ae6605af1b0e133c3faf37f135ed7bf55cff94b2b761e27536c450addcf7e409.
    off core.o size=347744 sha256=b10d6f05c8be1fd5654ff0686235a4bb2e6c752873518a74d52c697fb189dd1b.
    on core.o size=347744 sha256=d48b9bd593ae53468b246bbaede0e92a95b1cd8c9598d945be4977936acb8aea.
    on exec_lease.o size=2304 sha256=75e4085156ebb0610edbef3af9bf281bfc560edc1a59c2246a79c26f6807dd1e.
    task layout probe root: build/task-layout/sched-exec-lease-p5a-r-0009-20260704T034710Z.

  next:
    Negative ordinary-CFS denial tests, then security diff review and final
    overclaim review.

P5A-R Linux 0009 QEMU boot smoke / validation 0176:
  status:
    Passed for QEMU off/on boot/workload smoke.

  unit:
    capsched-p5a-r-0009-qemu-matrix.service

  invocation:
    ea20a9d013034ee886e89ecfced9104e

  log:
    /media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0009-qemu-matrix-20260704T035139Z.log

  output root:
    /media/nia/scsiusb/dev/linux-cap/build/qemu/sched-exec-lease-p5a-r-0009-matrix

  result:
    systemd Result=success, ExecMainStatus=0.
    off run: 20260704T035139Z-off, qemu_status=0, workload_ret=0.
    on run: 20260704T035938Z-on, CONFIG_SCHED_EXEC_LEASE=y,
    qemu_status=0, workload_ret=0.
    off serial sha256=7428f3b851010dacfb739b1d91091947776dd33e3894e402cfcec15245af514d.
    on serial sha256=603aa90b3f3c3af0ef629c7e4a05075540c60604d37040a95a27acba6c0e96a9.

  coverage limitation:
    pick_next_task and __schedule function observation unavailable in both
    guests, dlease_pick_next_task kprobe failed/missing, and
    sched_process_exec count was 0.

  non-claims:
    Accepted 0009, runtime denial correctness, CFS deny-and-repick correctness,
    runtime coverage, protection, cost, deployment, and datacenter claims
    remain false.

P5A-R 0009 negative runtime harness / analysis 0144 + implementation 0035:
  status:
    Design and implementation plan recorded; no Linux patch approved by these
    records.

  reason:
    Linux `0009` has no enable site for `sched_exec_cfs_candidate_key`, so
    normal builds cannot exercise the deny path. Negative runtime tests require
    a separate test-only harness overlay.

  planned patch:
    `0010`, default-off `CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST`, limited to
    `init/Kconfig` and `kernel/sched/fair.c`.

  synthetic test predicate:
    Under the test config only, enable the existing static key and deny
    ordinary CFS tasks whose `task->comm` begins with `seldeny`.

  QEMU negative workload shape:
    `seldenyA` synthetic denied child and `selallowB` allowed sibling child,
    both ordinary CFS and pinned to the same CPU after trace reset.

  allowed partial closure:
    ND-P5AR-002, ND-P5AR-003, and ND-P5AR-005 mechanics only.

  non-claims:
    This is not real capability semantics, not production runtime denial
    correctness, not runtime coverage beyond the observed synthetic path, and
    not protection/cost/datacenter evidence.

P5A-R 0010 negative harness implementation:
  status:
    Concrete test-only Linux patch drafted and source/targeted-build checked;
    not accepted as production policy or protection.

  Linux:
    commit `9f2b3996688849eb0ddc13531f735cc4eb16b63d`
    (`sched/fair: Add test-only CFS exec lease denial harness`).
    Patch queue file:
    `linux-patches/patches/capsched-linux-l0/0010-sched-fair-Add-test-only-CFS-exec-lease-denial-harne.patch`.

  behavior:
    Adds default-off `CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST`, depending on
    `SCHED_EXEC_LEASE && DEBUG_KERNEL`. When enabled, it enables the existing
    ordinary-CFS candidate static key at late init and denies tasks whose
    `task->comm` begins with `seldeny`.

  validation:
    validation/0177 records workload host compile, runner `bash -n`,
    `diff --check`, `CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y` olddefconfig,
    and targeted `kernel/sched/fair.o` build success.

  next:
    Run QEMU negative runtime validation:
    `capsched/capsched-models/validation/run-sched-exec-lease-p5a-r-0010-negative-qemu.sh`.
    This should be started under systemd if it becomes long-running.

  started run:
    `capsched-p5a-r-0010-negative-qemu-20260704T043512Z.service`
    with log
    `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-20260704T043512Z.log`.
    Completed as timeout/failure with `qemu_status=124`.

  attempt 1 result:
    validation/0178 records that the guest reached
    `CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y`, then failed in the workload with
    `tracefs reset: Bad file descriptor`. This is a validation harness failure,
    not a Linux deny-path verdict.

  harness fix:
    `trace_marker` is now optional. Required reset steps are only
    `tracing_on=0`, trace clear, and `tracing_on=1`.
    Updated workload sha256:
    `90e58321cb1204844fed6400993d88179f9ed39dbac9517202eff009d8f3d0b6`.

  next:
    Rerun QEMU negative runtime validation under systemd and record the result
    as the next validation entry.

  rerun started:
    `capsched-p5a-r-0010-negative-qemu-rerun-20260704T045417Z.service`
    with log
    `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-rerun-20260704T045417Z.log`.
    Completed as timeout/failure with `qemu_status=124`.

  rerun result:
    validation/0179 records that the guest reached
    `NEGATIVE_CHILDREN_READY`, then timed out before
    `NEGATIVE_CHILDREN_RELEASED`. The workload released the denied child,
    yielded/slept, and only then would release the allowed child, so the
    intended allowed-sibling property was not actually measured.

  release-order fix:
    workload now writes denied and allowed start pipes before yielding and
    prints `NEGATIVE_CHILDREN_RELEASED`.
    Updated workload sha256:
    `9739a225d7022dfed37359094d5e9247e172a16b8320a95dbcbe5e7babd4cb0b`.

  next:
    Rerun QEMU negative runtime validation again under systemd and record the
    result as the next validation entry.

  release-order-fixed run started:
    `capsched-p5a-r-0010-negative-qemu-releasefix-20260704T050521Z.service`
    with log
    `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-releasefix-20260704T050521Z.log`.
    First marker to check is `NEGATIVE_CHILDREN_RELEASED`.

  release-fix run result:
    validation/0180 records that the run was manually stopped after reaching
    `NEGATIVE_CHILDREN_READY` but not `NEGATIVE_CHILDREN_RELEASED`. This showed
    that waking denied first can preempt the parent before allowed is released.

  allowed-first fix:
    workload now writes allowed_start first, prints `NEGATIVE_ALLOWED_RELEASED`,
    then writes denied_start and prints `NEGATIVE_CHILDREN_RELEASED`.
    Updated workload sha256:
    `21e7baafcb56ec5a92d6ee1b1e49b2aa4ad246d71ab420b17851e5825d994739`.

  next:
    Rerun QEMU negative runtime validation again. The first expected marker is
    `NEGATIVE_ALLOWED_RELEASED`.

  allowed-first run started:
    `capsched-p5a-r-0010-negative-qemu-allowedfirst-20260704T051039Z.service`
    with log
    `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-allowedfirst-20260704T051039Z.log`.
    First expected markers are `NEGATIVE_ALLOWED_RELEASED` and then
    `NEGATIVE_CHILDREN_RELEASED`.

  allowed-first result:
    validation/0181 records that the run reached `NEGATIVE_ALLOWED_RELEASED`
    and then produced an RCU stall with CPU 0 in `pick_eevdf()`, called from
    `__pick_task_fair()` and `pick_task_fair_sched_exec_lease()`. This is
    strong negative evidence against accepting the current `0009/0010` draft
    path.

  equal-priority fix:
    workload now gives both children `nice -20`, removing the low-priority
    allowed-child skew from the next test.
    Updated workload sha256:
    `5989c84eefa1ca10600642baf015edad11e848189e517187d80b590913a00934`.

  equal-priority run started:
    `capsched-p5a-r-0010-negative-qemu-equalprio-20260704T051528Z.service`
    with log
    `build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-equalprio-20260704T051528Z.log`.
    Check whether it reaches `NEGATIVE_CHILDREN_RELEASED`,
    `NEGATIVE_ALLOWED_STARTED`, and `NEGATIVE_RESULT`.

  equal-priority result:
    validation/0182 records timeout with `qemu_status=124` after
    `NEGATIVE_ALLOWED_STARTED`, `NEGATIVE_ALLOWED_RELEASED`, and
    `NEGATIVE_CHILDREN_RELEASED`, but without `NEGATIVE_ALLOWED_DONE` or
    `NEGATIVE_RESULT`. This removes the priority-skew ambiguity and confirms a
    draft CFS deny-and-repick forward-progress bug rather than a primary host
    environment issue.

P5A-R 0011 denied repick progress corrective patch:
  status:
    Corrective draft Linux patch applied and targeted-build checked; not
    accepted as production policy or protection.

  Linux:
    commit `38340eceafa88119ba3e0bcdc10f309bfff6462b`
    (`sched/fair: Fix exec lease denied CFS repick progress`).
    Patch queue file:
    `linux-patches/patches/capsched-linux-l0/0011-sched-fair-Fix-exec-lease-denied-CFS-repick-progress.patch`.
    Patch sha256:
    `a2e93e499321e85e4c886ed2e3c7436fe1c1b59e1faa439e2ffa0e1cdd0eafd5`.

  diagnosis:
    Upstream CFS could treat `pick_next_entity()` returning NULL while queued
    as delayed-entity dequeue. SchedExecLease denial filtering introduced a
    new NULL reason: denied-candidate blockage. That made
    `__pick_task_fair()` retry/newidle around the same blocked state.

  behavior:
    Adds a denial-only `sched_exec_cfs_pickable_fallback()` that scans the
    current CFS runqueue for the next eligible and pickable entity only after
    denied blockage has already been observed. It also clears stale denied
    blockage when an allowed delayed entity is dequeued and avoids newidle
    retry loops when blocked only by a denied candidate.

  validation:
    validation/0183 records strict checkpatch clean plus targeted CONFIG
    off/on builds for `kernel/sched/fair.o` and `kernel/sched/core.o`.
    Object hashes:
    off fair `80b826bcc394177419dc9a2d2c19a4074957d5aa02e1ca19022c47681dc6a9cb`,
    on fair `ee5d2d5b5655368731884826d6b21ab312c96864c384a33f3d94551802b79961`.

  design caveat:
    This fallback repairs the immediate draft-path forward-progress bug, but it
    is not the final production picker data structure. A production-quality
    design still needs pickability-aware scheduler selection or a separately
    modeled bounded search with explicit cost/fairness evidence.

  next:
    validation/0184 records that QEMU negative runtime against `0011` timed
    out after `NEGATIVE_ALLOWED_STARTED`, `NEGATIVE_ALLOWED_RELEASED`, and
    `NEGATIVE_CHILDREN_RELEASED`, without `NEGATIVE_ALLOWED_DONE` or
    `NEGATIVE_RESULT`.

P5A-R 0012 forced pickable progress corrective patch:
  status:
    Corrective draft Linux patch applied and targeted-build checked; not
    accepted as production policy, production fairness policy, cost evidence,
    or protection.

  Linux:
    commit `bd71af5daeae808ac948cbd12af2663151936f22`
    (`sched/fair: Force exec lease pickable CFS progress`).
    Patch queue file:
    `linux-patches/patches/capsched-linux-l0/0012-sched-fair-Force-exec-lease-pickable-CFS-progress.patch`.
    Patch sha256:
    `f306bbfb16265df5a02632f8b2551b5f3e5a8420180ea13d6a59d4291fd2fa35`.

  diagnosis:
    `0011` remained too conservative. If denial hides the only eligible CFS
    entity while an allowed runnable entity is temporarily ineligible, returning
    NULL can idle the CPU instead of making allowed progress.

  behavior:
    After denied blockage has already been observed, first scan for eligible
    pickable entities. If none exist, scan for any pickable runnable entity and
    prefer it over idle. Known denied candidates still cannot run.

  validation:
    validation/0185 records strict checkpatch clean plus targeted CONFIG
    off/on builds for `kernel/sched/fair.o` and `kernel/sched/core.o`.

  next:
    validation/0186 records QEMU negative runtime against `0012` passing with
    `qemu_status=0`, `NEGATIVE_ALLOWED_NEXT 770`,
    `NEGATIVE_DENIED_NEXT 0`, `NEGATIVE_RESULT PASS`, and `WORKLOAD_RET 0`.
    Next work is security diff review and final overclaim review before any
    acceptance decision.

  non-claims:
    0009 through 0012 remain unaccepted for production. Production runtime
    denial correctness, complete CFS deny-and-repick correctness, runtime
    coverage, capability semantics, monitor enforcement, protection, cost,
    deployment, and datacenter claims remain false.

P5A-R 0012 security/overclaim boundary:
  Validation/0187 is complete. It accepts only the narrow 0186 result:
  synthetic ordinary-CFS negative QEMU workload completed, allowed sibling ran,
  denied synthetic sibling was not observed as `next_comm`.

  It does not accept `0012` as production policy. Blockers:
    - `sched_exec_cfs_pickable_scan()` is an rb-tree scan when denial blockage
      is active.
    - the second pass can prefer allowed runnable progress over ordinary CFS
      eligibility.
    - denial receipts and retry are intentionally bounded to one, so complete
      CFS deny-and-repick is not proven.
    - coverage is ordinary-CFS-only; core scheduling, proxy execution,
      sched_ext, DL fair-server nesting, RT/deadline/idle/class-loop paths are
      not covered.
    - the test predicate is `task->comm` prefix `seldeny`, not real authority;
      it is also race-prone as a task-name predicate and only acceptable as a
      synthetic harness.
    - patch queue 0010 has missing Signed-off-by and an overlong commit
      description line; 0009 has a strict checkpatch style CHECK.

  Next:
    treat 0009-0012 as experimental evidence. Before production acceptance,
    design picker-visible lease eligibility or another bounded selection
    structure with fairness/latency/cost proof. Patch queue metadata cleanup
    should be a separate maintenance operation because it changes hashes and
    possibly recreated commit IDs.

P5A-R 0012 patch queue replay:
  Validation/0188 repairs the `linux-patches/upstream/base.txt` expected
  `work_commit` and confirms `recreate-capsched-linux-l0.sh` passes.

  Result:
    local Linux HEAD:
      `bd71af5daeae808ac948cbd12af2663151936f22`
    replay-normalized HEAD:
      `1b572a3fad95b78f4ee89061ba441f77cf24e297`
    shared tree:
      `25dbe4e04baa112ab9a872a897f67bec094df209`

  Reason:
    the original 0011 local commit had a committer date later than its author
    date. The recreate script uses `git am --committer-date-is-author-date`, so
    0011 and descendants replay to normalized commit IDs while preserving the
    exact tree.

P5A-R2 selector direction:
  Analysis/0146 and validation/0189 are complete. They record that production
  should not continue extending the 0012 post-filter fallback.

  Source facts:
    current CFS/EEVDF already uses an augmented rb-tree with `min_vruntime` for
    picker-visible eligibility pruning. The next production-shaped SchedExec
    direction must make lease eligibility similarly visible before selection,
    or select a Domain/SchedContext bucket before CFS.

  Candidate matrix:
    A. augment existing CFS tree with lease-pickable subtree metadata:
       immediate P5A-R2 source/model target only if eligibility is frozen
       before enqueue and invalidation is modeled.
    B. separate eligible timeline:
       semantically clean but too invasive for next upstream-shaped L0 slice.
    C. lease bucket before CFS:
       best long-horizon datacenter/HyperTag direction.
    D. bounded candidate window:
       experimental only, not production.
    E. block/quarantine before pick:
       required settlement state, not sufficient picker mechanism.

  Next:
    create the P5A-R2 selector model gate before another Linux behavior patch.
    It must define pre-pick lease-pickable state, invalidation events, group
    hierarchy summaries, current entity handling, fail-closed settlement,
    cross-path exclusions, object/layout evidence, and fairness/cost evidence.

P5A-R2 selector model gate:
  Analysis/0147, formal/0114, and validation/0190 are complete.

  Validation result:
    RUN_ID `20260704T-p5a-r2-selector-model-gate`
    Linux commit `bd71af5daeae808ac948cbd12af2663151936f22`
    source anchors: 16 checked, 0 failures
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe configs: 21 expected counterexamples

  Key invariant:
    Candidate A is only a local cache/projection of frozen admission state. It
    is not authority. The summary must be EEVDF-compatible, meaning a
    `min_pickable_vruntime`-style infinite-sentinel summary or equivalent
    proof. A boolean-only "subtree has pickable work" marker is rejected.

  Required invalidations:
    task generation, exec generation, domain/grant epoch, budget
    exhaustion/refill, affinity/cpuset, migration, group movement, monitor
    receipt revoke, task exit.

  Long-horizon constraint:
    Candidate C remains the architecture: an outer Domain/SchedContext/
    ExecutionGrant selector before ordinary CFS, preserving HyperTag,
    MemoryView switch batching, root budgets, and datacenter single-OS goals.

  Still false:
    Linux patch approval, 0009-0012 acceptance, runtime denial correctness,
    complete CFS deny-and-repick correctness, runtime coverage, hot layout
    approval, monitor enforcement, production protection, cost efficiency,
    deployment readiness, datacenter readiness.

  Next:
    create the P5A-R2 invalidation source map tying each required invalidation
    event to concrete Linux source surfaces before drafting another selector
    patch.

P5A-R2 invalidation source map:
  Analysis/0148, formal/0115, and validation/0191 are complete.

  Validation result:
    RUN_ID `20260704T-p5a-r2-invalidation-source-map`
    Linux commit `bd71af5daeae808ac948cbd12af2663151936f22`
    source anchors: 41 checked, 0 failures
    safe TLC: 7 generated states, 6 distinct states, depth 6
    unsafe configs: 17 expected counterexamples

  Key result:
    A future picker-visible lease summary cannot be updated only on
    enqueue/dequeue. The source map requires invalidation or refresh for:
    lifecycle reset, fork generation, exec generation, exit, affinity mask
    changes, queued moves, `set_task_cpu`, fair migration, cgroup movement,
    cpuset effective-cpumask updates, budget charge, CFS throttle,
    unthrottle/refill, current entity handling, group summary handling, future
    monitor receipt revoke, and lock-boundary ownership.

  Still false:
    Linux patch approval, 0009-0012 acceptance, runtime denial correctness,
    complete CFS deny-and-repick correctness, runtime coverage, hot layout
    approval, monitor enforcement, production protection, cost efficiency,
    deployment readiness, datacenter readiness.

  Next:
    create the P5A-R2 invalidation semantics gate: stale versus refreshed
    summary states, affected leaf/current/group propagation, lock ownership per
    invalidation family, and future monitor receipt revoke integration.

P5A-R2 invalidation semantics gate:
  Analysis/0149, formal/0116, and validation/0192 are complete.

  Validation result:
    RUN_ID `20260704T-p5a-r2-invalidation-semantics-gate`
    Linux commit `bd71af5daeae808ac948cbd12af2663151936f22`
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe configs: 23 expected counterexamples

  Core rule:
    only Fresh summary state can be picker proof. Stale, Refreshing, and
    Blocked fail closed.

  Refresh rule:
    refresh is not a bit flip. It must recheck frozen authority,
    generation/epoch, budget, affinity, affected current/group membership, and
    future monitor receipt freshness. In-place stale-to-fresh, enqueue-only
    refresh, Linux policy lookup in picker, and monitor call in picker are
    rejected.

  Propagation rule:
    leaf/current/group/monitor-revoke propagation and lock ownership are
    required. Group summary false positives and silent false negatives are
    both rejected; current entity remains separate from rb-tree summary.

  Still false:
    Linux patch approval, 0009-0012 acceptance, runtime denial correctness,
    complete CFS deny-and-repick correctness, runtime coverage, hot layout
    approval, monitor enforcement, production protection, cost efficiency,
    deployment readiness, datacenter readiness.

  Next:
    P5A-R2 selector patch plan as a source/design gate. It should define
    object/layout/cost evidence and negative runtime validation requirements
    before any Linux behavior patch.

P5A-R2 selector patch plan:
  Analysis/0150, formal/0117, and validation/0193 are complete.

  Validation result:
    RUN_ID `20260704T-p5a-r2-selector-patch-plan-r2`
    Linux commit `bd71af5daeae808ac948cbd12af2663151936f22`
    Linux tree `25dbe4e04baa112ab9a872a897f67bec094df209`
    prior validations present: 6/6
    source anchors: 21 checked, 0 missing, 0 line drift
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe configs: 30 expected counterexamples

  Core rule:
    do not extend the experimental `0012` post-filter fallback as production
    design. Future P5A-R2 work must use an EEVDF-compatible
    `min_pickable_vruntime`-style fresh summary or equivalent proof, preserve
    Candidate C as the outer Domain/SchedContext selector, and keep local CFS
    state as a projection of frozen authority.

  Existing blockers recorded:
    `sched_exec_cfs_pickable_scan()` and
    `sched_exec_cfs_pickable_fallback()` are negative evidence and replacement
    targets, not accepted production foundations.

  Still false:
    Linux patch approval, 0009-0012 acceptance, runtime denial correctness,
    complete CFS deny-and-repick correctness, runtime coverage, hot layout
    approval, monitor enforcement, production protection, cost efficiency,
    deployment readiness, datacenter readiness.

  Next:
    minimal P5A-R2 source sketch plus object/layout, disabled-overhead, and
    negative stale-summary runtime validation requirements.

P5A-R2 minimal source sketch:
  Analysis/0151, formal/0118, and validation/0194 are complete.

  Validation result:
    RUN_ID `20260704T-p5a-r2-minimal-source-sketch-r2`
    Linux commit `bd71af5daeae808ac948cbd12af2663151936f22`
    Linux tree `25dbe4e04baa112ab9a872a897f67bec094df209`
    source anchors: 36 checked, 0 missing, 0 line drift
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe configs: 32 expected counterexamples

  Core sketch:
    future P5A-R2 should piggyback existing EEVDF rb-tree augmentation and add
    a `min_pickable_vruntime`-style Fresh summary with a U64_MAX-style sentinel.
    Task entities expose `se->vruntime` only when Fresh and allowed. Group
    entities expose their `se->vruntime` only when their child `cfs_rq` has a
    Fresh pickable descendant. `curr` remains outside the rb-tree summary and
    needs a separate Fresh check.

  Rejected:
    separate eligible tree, boolean-only summary, extending the `0012`
    post-filter fallback, unbounded rb_next scan, pick-time policy lookup,
    monitor call in picker, synthetic task->comm authority, group parent
    pickable without child Fresh descendant, stale curr shortcut.

  Still false:
    Linux patch approval, new hot fields, 0009-0012 acceptance, runtime denial
    correctness, complete CFS deny-and-repick correctness, runtime coverage,
    monitor enforcement, production protection, cost efficiency, deployment
    readiness, datacenter readiness.

  Next:
    P5A-R2 object/layout and disabled-overhead evidence plan for possible
    `sched_entity` / `cfs_rq` summary fields and affected hot functions.

P5A-R2 layout/overhead evidence plan:
  Analysis/0152, formal/0119, and validation/0195 are complete.

  Validation result:
    RUN_ID `20260704T-p5a-r2-layout-overhead-evidence-plan`
    Linux commit `bd71af5daeae808ac948cbd12af2663151936f22`
    Linux tree `25dbe4e04baa112ab9a872a897f67bec094df209`
    source anchors: 40 checked, 0 missing, 0 line drift
    future P5A-R2 fields absent: true
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe configs: 36 expected counterexamples

  Core rule:
    before any P5A-R2 hot summary field or CFS/EEVDF behavior patch, evidence
    must be split across CONFIG=n, CONFIG=y selector-disabled,
    CONFIG=y candidate-enabled, runtime negative tests, benchmark/perf claims,
    security review, QEMU coverage, and upstream replay. Object/layout evidence
    is not runtime or protection evidence.

  Rejected:
    accepting 0009-0012 as production, extending the 0012 fallback, unbounded
    rb_next scanning, public ABI/trace ABI/exported symbols, monitor calls or
    policy lookup in the picker, and production/cost/datacenter claims from
    build evidence.

  Still false:
    Linux patch approval, new hot fields, runtime denial correctness, complete
    CFS deny-and-repick correctness, runtime coverage, monitor enforcement,
    production protection, cost efficiency, deployment readiness, datacenter
    readiness.

  Next:
    no-behavior layout probe plan or patch for `sched_entity`, `cfs_rq`, `rq`,
    and `task_struct` measurement before any behavior patch.

P5A-R2 layout probe patch plan:
  Analysis/0153, formal/0120, and validation/0196 are complete.

  Validation result:
    RUN_ID `20260705T-p5a-r2-layout-probe-patch-plan`
    Linux commit `bd71af5daeae808ac948cbd12af2663151936f22`
    Linux tree `25dbe4e04baa112ab9a872a897f67bec094df209`
    source anchors: 32 checked, 0 missing, 0 line drift
    absence failures: 0
    patch_slot_free: true
    internal_probe_need_observed: true
    safe TLC: 6 generated states, 5 distinct states, depth 5
    unsafe configs: 31 expected counterexamples

  Core rule:
    Future patch `0013` may be drafted only as no-behavior build-only layout
    probe infrastructure. It must default off, must not be selected by
    `CONFIG_SCHED_EXEC_LEASE`, must not build the probe object in normal
    CONFIG off/on builds, and must not add runtime call sites, public ABI, trace
    ABI, exported symbols, monitor calls, or policy lookup.

  Key design fact:
    `task_struct` can be measured by the existing external module probe, but
    `struct cfs_rq` and `struct rq` are scheduler-internal types in
    `kernel/sched/sched.h`. A future full layout probe therefore needs a
    scheduler-internal build-only object or equivalent in-tree build probe.

  Still false:
    behavior patch approval, new hot fields, runtime denial correctness,
    complete CFS deny-and-repick correctness, runtime coverage, monitor
    enforcement, production protection, cost efficiency, deployment readiness,
    datacenter readiness.

  Next:
    draft Linux patch `0013` within the no-behavior layout probe scope, then run
    replay, CONFIG off/on normal-build absence checks, probe-on build, symbol
    extraction, source-shape checks, security review, and upstream replay.

P5A-R2 0013 layout probe:
  Implementation/0039 and validation/0197 are complete.

  Linux patch:
    local commit `0b79e307dc9536d38557141cfd650f2be9a2af57`
    subject `sched/exec_lease: Add build-only layout probe`
    replay commit `077c948be39432971e7273b16b728172251129aa`
    matching tree `7ef04bf73d26b2813b10016b7eb342a618a66570`

  Patch queue:
    `linux-patches/patches/capsched-linux-l0/0013-sched-exec_lease-Add-build-only-layout-probe.patch`
    patch sha256 `cc1fe1754e64bfaa23e8214445b748d0287e7961500d0aa2a7d6f995a295fb38`
    series sha256 `8f7c96605f816f9ec34015d7c6d8d1e1dbbe2936e60b86f8bc70dc4e1727270e`

  Validation:
    RUN_ID `20260705T-p5a-r2-0013-layout-probe-r2`
    replay passed; local/replay trees match
    checkpatch: 0 errors, 1 expected MAINTAINERS new-file warning
    normal CONFIG off/on: `exec_lease_layout_probe.o` absent
    probe CONFIG on: build passed
    probe object size: 2464
    probe object sha256 `d688b67c55e9cfb0fdd8d5c0e6978be548d69edaa7d7b6c738baba8c6ae6d4cc`
    probe symbols: 24

  Scope:
    default-off build-only scheduler-internal layout probe for `sched_entity`,
    `cfs_rq`, `rq`, and `task_struct` SchedExecLease fields. This is needed
    because `cfs_rq` and `rq` are scheduler-internal and cannot be measured by
    an external module probe alone.

  Still false:
    behavior patch approval, new hot scheduler runtime fields, runtime denial
    correctness, complete CFS deny-and-repick correctness, runtime coverage,
    monitor enforcement, production protection, cost efficiency, deployment
    readiness, datacenter readiness.

  Next:
    extract the 0013 probe symbols into a structured layout table and compare
    CONFIG off/on/probe object evidence before any P5A-R2 hot-field or behavior
    patch.

P5A-R2 0013 layout table:
  Validation/0198 is complete.

  Run:
    `20260705T-p5a-r2-0013-layout-table`

  Structured result:
    entries: 14
    structs: 4
    fields: 10
    fields within containing structures: true
    layout TSV sha256 `466349c5b78cf23d7cc996649372fa003fa82fbeaf89b7fd222ef244a9ae5523`
    layout JSON sha256 `06bf37fdb4a1ef823f21887f1b61b1df14749dfcf1c7b63a11f52fc2994b97e7`

  Baseline:
    `sched_entity` size 320
    `sched_entity.run_node` 16/24
    `sched_entity.min_vruntime` 48/8
    `sched_entity.vruntime` 120/8
    `cfs_rq` size 384
    `cfs_rq.tasks_timeline` 64/16
    `cfs_rq.curr` 80/8
    `cfs_rq.next` 88/8
    `rq` size 3392
    `rq.nr_running` 0/4
    `rq.curr` 16/8
    `rq.cfs` 128/384
    `task_struct` size 3328
    `task_struct.sched_exec` 1424/40

  Still false:
    hot-field approval, behavior patch approval, runtime denial correctness,
    complete CFS deny-and-repick correctness, runtime coverage, monitor
    enforcement, production protection, cost efficiency, deployment readiness,
    datacenter readiness.

  Next:
    disabled-overhead comparison for normal CONFIG off/on builds. Keep it
    separate from the explicit probe build.

P5A-R2 0013 disabled-overhead boundary:
  Validation/0199 is complete.

  Run:
    `20260705T-p5a-r2-0013-disabled-overhead`

  Result:
    changed_files_only_probe_boundary: true
    touched_existing_hot_or_lifecycle_file: false
    layout_probe_default_n: true
    layout_probe_selected_by_normal_config: false
    normal_config_off_probe_object_absent: true
    normal_config_on_probe_object_absent: true
    normal_objects_with_probe_symbols: false
    normal_object_count: 5
    normal_object_ledger_sha256 `9e3b71bc4ac6d4db7095c3fde5db5cbe143595e8adc8b82418ee88f20ce5569a`

  Boundary:
    this is source/build-graph evidence, not a global performance benchmark and
    not an object byte-identity claim. The reason is deliberate: object bytes
    can vary with build paths and debug metadata, while the safety question for
    0013 is whether the explicit probe enters normal scheduler builds. It does
    not.

  Still false:
    performance improvement, hot-field approval, behavior patch approval,
    runtime denial correctness, complete CFS deny-and-repick correctness,
    runtime coverage, monitor enforcement, production protection, cost
    efficiency, deployment readiness, datacenter readiness.

  Next:
    choose between one more evidence-only audit, or return to P5A-R2
    source/model design for a future Fresh-summary selector patch.

P5A-R2 vruntime sentinel gate:
  Validation/0200 passed. Analysis/0154 supersedes the provisional literal
  `U64_MAX` sentinel from analysis/0151 for future implementation contracts.

  Mechanical counterexample:
    `(s64)(U64_MAX - 100) = -101`, so the current signed wrapping vruntime
    comparison does not treat literal `U64_MAX` as numeric infinity.

  Required representation:
    explicit validity plus a wrap-aware numeric minimum as one inseparable
    summary; ignore the numeric member while invalid; keep `curr` separate
    from the rb-tree aggregate; project child tree-or-curr Fresh witnesses
    through group entities; propagate the full invalidation closure while
    holding the runqueue lock.

  Evidence:
    16 source anchors, 0 failures; safe TLC 7 generated states, 6 distinct
    states, depth 6; 18 unsafe configurations produced expected
    counterexamples. The recreated arm64 tree also passed targeted CONFIG
    off/on scheduler builds and the explicit layout-probe build.

  Still false:
    Linux patch or hot-field approval, runtime behavior or denial correctness,
    runtime coverage, monitor enforcement, production protection,
    performance/cost, deployment, and datacenter readiness.

  Next:
    create the P5A-R2 summary update-closure source map covering rb-tree
    augmentation, current transitions, group projection, lifecycle, budget,
    placement, throttle/refill, and future monitor revoke events.

P5A-R2 summary update closure:
  Validation/0201 passed with the Linux behavior patch still blocked.

  Evidence:
    32 source anchors, 0 failures; 4 expected future-absence checks, 0
    failures; safe TLC 71 generated states, 61 distinct states, depth 7; 24
    unsafe configurations produced expected counterexamples.

  Closed task-local contract:
    on-rq changes are owned by `rq->lock`; `curr` remains separate from the
    rb-tree; child tree-or-current witnesses propagate through every parent
    group; old-rq validity is removed before migration unlock; destination
    validity is published only after locked activation; the reached task is
    revalidated.

  Discovered blocker:
    the scaffold has no runtime authority publication, domain-to-runnable
    index, per-rq receipt generation, shared budget fanout, monitor revoke
    fanout, or selector-generation protocol. Task-local augmentation alone
    cannot keep shared invalidation coherent.

  Still false:
    Linux behavior or hot-field approval, runtime denial correctness, runtime
    coverage, monitor enforcement, production protection, performance/cost,
    deployment, and datacenter readiness.

  Next:
    define the versioned shared invalidation and fanout contract before any
    selector patch.

P5A-R2 versioned global invalidation fence:
  Validation/0202 passed as a conservative architecture gate.

  Selected baseline:
    locally publish frozen shared state, then release-publish a non-reused
    global projection generation. Every picker acquire-checks that generation
    against its rq built generation before trusting Fresh. Generation mismatch
    blocks trust before asynchronous fanout arrives. Work then rebuilds every
    online rq under its rq lock and rechecks generation before Fresh publish.

  Evidence:
    15 source anchors, 0 failures; 4 expected future-absence checks, 0
    failures; safe TLC 12 generated states, 10 distinct states, depth 8; 24
    unsafe configurations produced expected counterexamples. Stable rebuild
    and publication-raced rebuild paths are both modeled.

  Tradeoff:
    the baseline rejects targeted fanout and can invalidate unrelated domains.
    Full rebuild can be O(n) while holding each rq lock. This is a safety
    baseline, not a latency/performance design.

  Still false:
    Linux behavior/hot-field approval, bounded rebuild latency, runtime denial
    correctness, runtime coverage, monitor delivery/enforcement, production
    protection, performance/cost, deployment, and datacenter readiness.

  Next:
    create the global-fence data-layout and rebuild evidence plan.

P5A-R2 global-fence layout/rebuild evidence plan:
  Validation/0203 passed for implementation-evidence planning only.

  Evidence:
    24 source anchors and 6 future-absence checks passed with zero failures.
    Safe TLC explored 6 generated states, 5 distinct states, depth 5; 32
    unsafe configurations produced expected counterexamples.

  Layout envelope:
    future per-architecture candidates may grow `sched_entity` by at most 8
    bytes and `rq` by at most 32 bytes; `cfs_rq` and `task_struct` must have
    zero growth. Named hot offsets must remain unchanged.

  Rebuild rejection gate:
    reject full rq-locked rebuild if p99 additional irq-disabled lock hold
    exceeds 25000 ns, raw maximum exceeds 50000 ns, any sample reaches the
    current 700000 ns base slice, or lockdep/irqsoff/RCU/lockup warnings occur.

  Still false:
    Linux patch/hot-field approval, rebuild correctness or bounded latency,
    runtime denial correctness, protection, performance/cost, deployment, and
    datacenter readiness.

P5A-R2 arm64 0013 layout table:
  Validation/0204 passed against the completed 20260713T140445Z arm64 build.

  Evidence:
    exact Linux commit `077c948be39432971e7273b16b728172251129aa` and tree
    `7ef04bf73d26b2813b10016b7eb342a618a66570`; 24 probe symbols; 14 table
    entries comprising 4 structures and 10 fields; all fields within their
    containing structures.

  arm64 baseline:
    `sched_entity` 320; `run_node` 16/24; `min_vruntime` 48/8;
    `vruntime` 120/8.
    `cfs_rq` 384; `tasks_timeline` 64/16; `curr` 80/8; `next` 88/8.
    `rq` 3520; `nr_running` 0/4; `curr` 24/8; `cfs` 128/384.
    `task_struct` 4160; `sched_exec` 1232/40.

  Boundary:
    compare arm64 candidates with this arm64 baseline and x86_64 candidates
    with validation/0198. No cross-architecture byte identity is claimed.

  Next:
    define the expanded default-off build-only probe patch plan. No behavior
    patch or hot-field approval exists yet.

P5A-R2 expanded layout probe patch plan:
  Analysis/0158, formal/0125, and validation/0205 passed.

  Gate result:
    25 source anchors and 3 absence checks passed with zero failures; safe TLC
    explored 5 generated states, 4 distinct states, depth 4; 20 unsafe
    configurations produced expected counterexamples.

  Boundary:
    0014 may change only `kernel/sched/exec_lease_layout_probe.c`, preserve the
    existing 24 symbols, and add 27 object-local measurements. Kconfig,
    Makefile, scheduler structures, callsites, candidate fields, ABI, and
    behavior are frozen.

P5A-R2 0014 expanded layout probe:
  Source and deterministic patch replay are complete.

  Identity:
    local commit `5e1ca3037e34823d1ba0cdd1dc04161fac170280`;
    replay commit `6537a57d3d4bcf61d92b0081275081d69c5ff2fd`;
    matching tree `54f685aad94f28f0027cbba18cf5e29aadce234a`;
    patch queue commit `2a022dce54679ce5ecb86581bf55199dc28c868b`.
    Strict checkpatch passes with 0 errors and 0 warnings.

  Arm64 validation:
    validation/0206 passed fresh normal-off/on and explicit-probe targeted
    builds. Normal builds omit the probe object. The explicit build preserved
    24 existing symbols, added 27, omitted none, extracted exactly 51 total,
    and emitted a 23-field cacheline table.

  Boundary:
    the first run completed compilation and produced 51 symbols, exposing the
    erroneous 49-symbol ledger. The corrected `24 + 27 = 51` gate passed
    without changing the Linux tree. E1 is complete; the next evidence stage
    is a separately gated disposable E2 layout-only candidate. No hot field,
    behavior, runtime denial, protection, performance, or cost claim exists.

P5A-R2 E2 disposable arm64 layout candidate:
  Analysis/0159, formal/0126, and validation/0207 passed the pre-implementation
  gate: 20 anchors, 6 absence checks, safe TLC 5/4/depth 4, and 30 expected
  unsafe counterexamples. Primary Linux and patch queue 0014 are frozen.

  Disposable identity:
    case-sensitive worktree
    `build/DomainLeaseLinux.volume/worktrees/p5a-r2-e2-layout`;
    branch `codex/p5a-r2-e2-layout`;
    commit `162d16640634637a6f7604b90bf2275bea47ec63`;
    tree `a435a65f1b1ae5e4c10d09e5753fc0871f1381d1`;
    four files, 42 additions, strict checkpatch 0/0.

  Candidate:
    default-off probe-dependent config; sched_entity valid byte in the flag
    hole and u64 minimum in the pre-avg alignment gap; rq byte state and u64
    generation in the tail alignment gap. No cfs_rq/task field, callback,
    runtime callsite, ABI, or behavior exists.

  Arm64 validation:
    corrected run `20260713T-p5a-r2-e2-layout` passed fresh arm64 off/on/
    candidate builds, preserved all 51 E1 symbol values, added eight for 59
    total, emitted the 27-field table, and preserved protected offsets. All
    measured structure deltas are zero: sched_entity 320, cfs_rq 384, rq 3520,
    task_struct 4160. Result SHA-256 is
    `360f98bd71ed641ba410205925cdec00d55cfbaa990e2dee361798e6afb945f1`.

  First-attempt correction:
    run start `2026-07-14T02:14:58Z` exited at `02:16:33Z`, before target
    compilation. `olddefconfig` validly omitted the dependency-hidden candidate
    symbol, while the harness required the alternative not-set comment. The
    runner now fails only if the disabled candidate is unexpectedly `=y` and
    the same external job owns the retry. Candidate, primary Linux, and patch
    queue identities did not change. The corrected retry passed.

  Boundary:
    exploratory append placements grew cacheline-aligned structures by 64
    bytes and were rejected. The corrected gap-consuming placement preserved
    all four E1 structure sizes, now confirmed by authoritative arm64 evidence.
    x86_64 E2 is the next separate architecture-local gate. Accepted hot
    fields, E3 rebuild, behavior, denial correctness, protection, performance,
    and cost are false.

P5A-R2 E2 x86_64 layout evidence plan:
  Analysis/0160, formal/0127, and validation/0209 passed the detached-build
  launch gate. Run `20260714T-p5a-r2-e2-x86_64-layout-plan` passed 18 anchors,
  4 absence checks, safe TLC 5/4/depth 4, and 24 expected counterexamples.
  It requires fresh same-toolchain x86_64 E1 and candidate off/on/probe builds
  using `ARCH=x86_64` and `CROSS_COMPILE=x86_64-linux-gnu-`, 51 E1 values
  preserved, 8 additions, 59 total symbols, 27 fields, x86_64-local growth
  envelopes, and candidate field bounds. Cross-built layout is not runtime
  evidence. Source change, candidate acceptance, E3, behavior, protection,
  performance, cost, deployment, and datacenter claims remain false.

  Monitored build:
    validation/0210 and external job `p5a-r2-e2-x86_64-build` own cross-
    compiler installation if absent and the fresh E1/off/on/candidate matrix.
    Monitor with
    `./tools/long-job.sh watch p5a-r2-e2-x86_64-build 30`. No x86_64 pass is
    recorded until its exact result.json passes.

  First-attempt correction:
    cross-compiler installation passed, then the runner stopped before target
    compilation because x86_64 defconfig disables `EXPERT`, which hides the
    lease and probe. The common config procedure now enables this declared
    dependency before every mode. Source identities and claims are unchanged.

  Result:
    corrected validation/0210 run `20260714T-p5a-r2-e2-x86_64-layout`
    passed with GCC 13.3.0, fresh E1 plus off/on/candidate builds, 51 E1 values
    preserved, 8 additions, 59 total symbols, 27 fields, and zero growth in
    all four x86_64 structures (320/384/3392/3328). Candidate offsets are
    sched_entity 92/200 and rq 3380/3384. Together with arm64 validation/0208,
    both required architecture-local E2 comparisons pass. The exact candidate
    remains unaccepted pending a separate E2 acceptance gate; production hot
    fields, primary promotion, E3, runtime, protection, performance, and cost
    remain false.

P5A-R2 E2 evidence closure:
  Analysis/0161, formal/0128, and validation/0211 passed. Run
  `20260714T-p5a-r2-e2-layout-closure` verified the exact hashed arm64 and
  x86_64 results, immutable candidate/source boundaries, 51+8=59 symbols and
  27 fields per architecture, zero growth, protected measurements, field
  bounds, and architecture-local offsets. Safe TLC was 5/4/depth 4 and all 24
  unsafe configurations were rejected. Candidate `162d16640634` is frozen
  only as E3 planning input. E3 plan drafting is allowed; E3 worktree/source,
  primary promotion, production layout/hot fields, runtime, protection,
  performance, and cost remain false.

P5A-R2 E3 disposable rebuild prototype:
  Analysis/0162/formal/0129/validation/0212 authorized an exact two-file
  descendant of E2. Implementation/0042 records commit `d1d5e78da848`, tree
  `aa6a5a384841`, and diff SHA-256 `a5351bbdd7a6`; primary Linux and patch queue
  0014 remain frozen.

  Validation/0213 run `20260714T-p5a-r2-e3-rebuild` passed the fresh parent,
  lease-off, layout-on-test-off, and KUnit-on arm64 build matrix plus the full
  KUnit Image. QEMU ran `sched_exec_lease_rebuild`: 12/12 cases passed, with
  zero failures and zero skips. Result SHA-256 is
  `fd4ea3fdf283d3d6251c7ac3a685a9d602a1b3dc50ba53779348ac3886d236cc`;
  normalized KTAP SHA-256 is
  `f1ec72888ab6a4cc5c30fd192355bc33a0082f4375811c57b0710c60db1a3d05`.

  The first QEMU attempt exposed environmental harness faults: the minimal
  guest lacked the default virtio EFI ROM and QEMU 8.2.2 asserted under its
  broad `max` CPU model. The accepted runner uses `-nic none`, `cortex-a57`,
  and normalized current KTAP spelling; E3 Linux source did not change.

  Boundary:
    E3 correctness is accepted only for synthetic fixtures. Production fields,
    live scheduler integration, bounded irq-disabled rq-lock hold, runtime
    denial, monitor enforcement, protection, performance/cost, deployment,
    and datacenter readiness remain false.

  Next:
    define and formally gate the E4 live lock-hold measurement protocol before
    adding any E4 source.

P5A-R2 E4 lock-hold measurement plan:
  Analysis/0163/formal/0130/validation/0214 passed the pre-source gate. Run
  `20260714T-p5a-r2-e4-lock-hold-plan` passed 24 anchors, 4 absence checks,
  safe TLC 6/5/depth 5, and 28 expected counterexamples. Result SHA-256 is
  `fff0fc959baebb7a7be4565ee164a8ad7ebad231149413c4f2368ea55a7795fc`.

  Fixed experiment:
    35 cells from 0/1/8/64/256/1024/4096 leaves and depths 0/1/4/16/64;
    10,000 paired empty-control/rebuild samples per cell; real irq-disabled
    rq locking; O(1) fixture callback; statistics outside the measured
    interval; 25 us p99, 50 us max, and 700 us base-slice rejection gates.

  Boundary:
    only a direct E3 child changing `init/Kconfig` and `kernel/sched/fair.c`
    may now be drafted. Measurement launch needs a separate source gate.
