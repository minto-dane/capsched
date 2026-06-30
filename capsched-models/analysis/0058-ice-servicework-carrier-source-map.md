# Analysis 0058: ICE ServiceWork Carrier Source Map

Status: Draft source map with model gate

Date: 2026-06-30

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related artifacts:

```text
analysis/0034-workqueue-kthread-budgetticket-carrier.md
analysis/0045-workqueue-internal-redesign-boundary.md
analysis/0047-drivers-net-workqueue-origin-map.md
analysis/0052-ice-modern-nic-queuelease-source-map.md
analysis/0053-ice-modern-nic-revoke-source-map.md
analysis/0057-representor-lower-queuelease-source-map.md
formal/0017-workqueue-budgetticket-carrier-model/
formal/0036-representor-lower-queuelease-model/
```

## Purpose

N-085 maps the authority boundary for Intel `ice` service work:

```text
reset
AdminQ / MailboxQ / SidebandQ processing
VF virtchnl queue and control requests
PTP and timestamp maintenance
DPLL / SyncE control work
eswitch bridge offload work
LAG event work
GNSS polling work
firmware and health maintenance work
```

The question is not whether Linux should use workqueues. The question is what
authority a deferred driver callback may exercise under a hostile-Domain
threat model.

## Core Rule

For CapSched-H:

```text
service work authority != caller authority
service work authority != QueueLease authority
service work authority != QueueControl authority
service work authority != lower QueueLease rebind authority
```

The safe shape is:

```text
effective authority =
  live service Domain authority
  intersect live caller/request carrier when the effect is caller-derived
  intersect live QueueLease / QueueControl / Offload / PTP / DPLL endpoint cap
  intersect fresh queue, policy, and device epochs
  intersect service budget or an explicit service charging rule
```

For purely internal maintenance:

```text
effective authority =
  live service Domain authority
  intersect service budget
  intersect allowed maintenance class
```

Pure service maintenance must not perform caller-attributed queue, DMA, IRQ,
offload, or control effects without a separate carrier.

## Work Classes

### ServiceMaintenanceWork

Examples:

```text
periodic health/watchdog work
PTP cached PHC update
DPLL periodic state acquisition
GNSS polling reads
firmware/AdminQ housekeeping that does not apply a caller request
```

Authority:

```text
service Domain authority
service budget
maintenance class allowlist
device epoch freshness
```

It may observe and maintain the service Domain's device state. It may not mint
caller authority.

### VFMailboxRequestWork

Examples:

```text
VIRTCHNL_OP_CONFIG_VSI_QUEUES
VIRTCHNL_OP_ENABLE_QUEUES
VIRTCHNL_OP_DISABLE_QUEUES
VIRTCHNL_OP_CONFIG_IRQ_MAP
VIRTCHNL_OP_CONFIG_QUEUE_BW
VIRTCHNL_OP_CONFIG_QUANTA
VIRTCHNL_OP_ADD_FDIR_FILTER
VIRTCHNL_OP_DEL_FDIR_FILTER
```

Authority:

```text
service Domain authority
VF/Domain request carrier
VF epoch
QueueControl or QueueLease endpoint authority
DMA MemoryView/IOMMU authority for queue ring addresses
IRQ route authority for vector mappings
budget/rate authority for queue shaping
```

The existing virtchnl allowlist and Linux validation are useful policy inputs,
not non-forgeable authority roots.

### DomainRequestControlWork

Examples:

```text
PTP settime / adjtime / perout / extts / hwtstamp control
DPLL pin state changes and TX reference clock switch requests
ethtool/netlink/devlink-derived device configuration that defers work
```

Authority:

```text
caller control carrier
service Domain authority
endpoint-specific control cap
fresh caller and service epochs
service budget or caller-charged service budget
```

If a callback queues later work, the later worker must not run on service
authority alone when it applies the caller-requested control effect.

### ExternalPolicyEventWork

Examples:

```text
switchdev FDB add/delete events
bridge aging update work
netdev LAG events
representor lower_dev rebinding
TC/switchdev offload replay
```

Authority:

```text
fresh policy event generation
offload/control authority
lower QueueLease binding for lower queue effects
revoke-time stale rule invalidation or rebind proof
```

Bridge FDB, VLAN, switchdev, and LAG events are policy facts. They do not mint
lower QueueLease authority.

### MergedServiceLoop

The primary `ice` service task is a merged loop. A single callback may process
many pending bits and firmware events.

Authority:

```text
service authority for the loop itself
per-effect authority checks before each queue/control/offload effect
explicit merge semantics if multiple caller-derived requests are coalesced
```

The loop must not choose "the last caller" or overwrite a carrier when work has
already been scheduled. The correct rule is per-effect classification and
per-effect intersection.

## Source Anchors

### Primary service task coalescing

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_main.c:
  ice_service_task_schedule() line 1667
  ICE_SERVICE_DIS check line 1669
  ICE_SERVICE_SCHED test_and_set line 1670
  queue_work(ice_wq, &pf->serv_task) line 1672
  ice_service_task_complete() lines 1679-1685
  ice_service_task_stop() lines 1695-1706
  ice_service_timer() lines 1726-1731
  ice_service_task() lines 2292-2378
```

Interpretation:

```text
pf->serv_task is a merged service loop. ICE_SERVICE_SCHED coalesces repeated
scheduling into one callback. The callback runs in worker context and handles
reset, AdminQ, MailboxQ, SidebandQ, MDD, VFLR, filters, aRFS, FDir, watchdog,
and aux-device events.
```

Forbidden shortcut:

```text
Do not attach one mutable "current caller" to pf->serv_task. The same work item
is deliberately coalesced.
```

### Reset, AdminQ, MailboxQ, and firmware events

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_main.c:
  ice_prepare_for_reset() lines 535-621
  ice_reset_subtask() lines 674-743
  __ice_clean_ctrlq() lines 1418-1564
  ice_clean_adminq_subtask() lines 1586-1606
  ice_clean_mailboxq_subtask() lines 1613-1628
  ice_clean_sbq_subtask() lines 1635-1658
  ice_misc_intr() lines 3097-3222
```

Interpretation:

```text
OICR and control queue events set pending bits, and the service task drains
firmware/AdminQ/MailboxQ/SBQ events. Some events are pure service facts. Some
contain VF/caller requests that later mutate queues, filters, bandwidth, IRQ
maps, or firmware state.
```

Forbidden shortcut:

```text
Do not treat firmware or interrupt event delivery as caller authority. Event
facts can trigger service processing, but caller-derived effects still need a
carrier or typed endpoint authority.
```

### VF mailbox and virtchnl queue/control operations

Useful anchors:

```text
drivers/net/ethernet/intel/ice/virt/virtchnl.c:
  ice_vc_process_vf_msg() lines 2736-2935
  VF lookup and cfg_lock lines 2750-2757
  virtchnl message validation lines 2771-2787
  ice_vc_is_opcode_allowed() line 2789
  queue/config/IRQ/bandwidth/PTP opcode dispatch lines 2816-2914

drivers/net/ethernet/intel/ice/virt/allowlist.c:
  default allowlist lines 26-29
  working queue/IRQ allowlist lines 31-37
  VLAN/RSS/FDIR/PTP/TC allowlists lines 50-95

drivers/net/ethernet/intel/ice/virt/queues.c:
  ice_vc_ena_qs_msg() lines 234-312
  ice_vf_vsi_dis_single_txq() lines 325-351
  ice_vc_dis_qs_msg() lines 361-451
  ice_vc_cfg_irq_map_msg() lines 513-581
  ice_vc_cfg_q_bw() lines 593-665
  ice_vc_cfg_q_quanta() lines 677-739
  ice_vc_cfg_qs_msg() lines 749-914
```

Interpretation:

```text
The service task processes VF mailbox messages and can configure queue DMA
addresses, ring sizes, queue enable state, IRQ mappings, queue bandwidth,
quanta profiles, RSS/VLAN/FDIR state, and PTP VF requests.
```

Important data-plane-adjacent hazard:

```text
ice_vc_cfg_qs_msg() copies VF-provided DMA ring addresses into
vsi->tx_rings[q]->dma and vsi->rx_rings[q]->dma before configuring queues.
For CapSched-H this requires a DMA MemoryView/IOMMU-authorized queue-control
carrier, not just virtchnl validation.
```

Forbidden shortcut:

```text
Do not treat virtchnl opcode allowlists, VF active bits, or queue id range
checks as QueueLease, IRQ route, DMA MemoryView, or budget authority.
```

### PTP and timestamp control work

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_ptp.c:
  ice_ptp_reset_cached_phctime() lines 976-1004
  kthread_queue_delayed_work(... ptp.work ...) lines 993-995
  ice_ptp_wait_for_offsets() lines 1133-1163
  ice_ptp_port_phy_restart() lines 1213-1255
  ice_ptp_gpio_enable() lines 1828-1864
  ice_ptp_settime64() lines 1897-1939
  ice_ptp_adjtime() lines 1966-1997
  ice_ptp_hwtstamp_get() lines 2209-2219
  ice_ptp_hwtstamp_set() lines 2279-2296
  ice_ptp_set_caps() lines 2540-2556
  ice_ptp_periodic_work() lines 2852-2867
  ice_ptp_queue_work() lines 2877-2881
  ice_ptp_init_work() lines 3212-3230
  ice_ptp_release() lines 3391-3423

drivers/net/ethernet/intel/ice/ice_main.c:
  ndo_hwtstamp_get / ndo_hwtstamp_set lines 9813-9814
```

Interpretation:

```text
PTP mixes periodic service maintenance, IRQ-assisted timestamp processing, and
user-visible PHC/timestamp configuration. Delayed kthread work is correct for
latency and locking, but the deferred worker must not erase the distinction
between service maintenance and caller-requested control effects.
```

Forbidden shortcut:

```text
Do not treat the PTP kworker or ptp_clock_info callback reachability as a
caller control cap. PTP settime, adjtime, perout, extts, and hwtstamp changes
need endpoint-specific control authority.
```

### DPLL and SyncE control work

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_dpll.c:
  ice_dpll_txclk_work() lines 2637-2691
  ice_dpll_txclk_state_on_dpll_set() lines 2709-2754
  queue_work(pf->dplls.wq, &pf->dplls.txclk_work) line 2751
  ice_dpll_periodic_work() reschedule lines 3178-3182
  ice_dpll_pin_notify callback work allocation lines 3646-3654
  ice_dpll_init_fwnode_pins() creates ice_dpll_wq line 3935
  ice_dpll_init_worker() lines 4248-4261
  ice_dpll_deinit_worker() lines 4229-4234
  ice_dpll_deinit() txclk_work cancel line 4850

drivers/net/ethernet/intel/ice/ice_dpll.h:
  struct ice_dplls worker/work/wq fields lines 171-175
```

Interpretation:

```text
DPLL has both periodic maintenance and netlink/DPLL-subsystem callback-driven
control. TX reference clock state changes are queued into a workqueue and
later applied by firmware/hardware operations.
```

Forbidden shortcut:

```text
Do not treat pf->dplls.wq reachability or ICE_FLAG_DPLL as control authority.
They are lifecycle guards, not caller authorization.
```

### Eswitch bridge offload work

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_eswitch_br.c:
  ice_eswitch_br_fdb_event_work() lines 475-505
  ice_eswitch_br_fdb_work_alloc() lines 508-534
  queue_work(br_offloads->wq, &work->work) line 577
  ice_eswitch_br_update_work() lines 1276-1285
  alloc_ordered_workqueue("ice_bridge_wq") line 1303
  INIT_DELAYED_WORK(update_work) lines 1336-1338
```

Interpretation:

```text
FDB add/delete events are per-event allocated work and can carry a policy-event
generation. Bridge aging update work is delayed service/merge work. Both can
lead to hardware offload changes and stale rule cleanup.
```

Forbidden shortcut:

```text
Do not treat switchdev FDB notification or bridge aging as OffloadCap or lower
QueueLease authority.
```

### LAG event work and lower_dev rebinding

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_lag.c:
  ice_lag_config_eswitch() lines 116-125
  ice_lag_process_event() lines 2209-2278
  ice_lag_event_handler() lines 2287-2363
  queue_work(ice_lag_wq, &lag_work->lag_task) line 2361

drivers/net/ethernet/intel/ice/ice_main.c:
  ice_lag_wq allocated lines 5873-5877
```

Interpretation:

```text
LAG netdev events are copied into allocated work and later processed. A key
side effect is representor lower_dev rebinding through ice_lag_config_eswitch().
This invalidates the representor-to-lower QueueLease binding unless a fresh
lower lease rebind is produced.
```

Forbidden shortcut:

```text
Do not treat a netdev notifier event, LAG active-port choice, or lower_dev
rewrite as proof that existing representor forwarding carriers still target a
fresh lower QueueLease.
```

### GNSS service work

Useful anchors:

```text
drivers/net/ethernet/intel/ice/ice_gnss.c:
  ice_gnss_read() requeues read_work line 156
  ice_gnss_struct_init() initializes read_work and kworker lines 171-185
  ice_gnss_open() queues read_work line 221
  ice_gnss_close() cancels read_work line 244
  ice_gnss_exit() cancels/destroys worker lines 366-375
```

Interpretation:

```text
GNSS polling is mostly service maintenance plus a user-visible character-like
endpoint. It is not queue authority, but it still needs endpoint-specific
service accounting and provenance if Domain policy exposes it.
```

## Compatibility Implication

The compatible direction is not "convert every workqueue item into one caller
operation."

Instead:

```text
1. keep service loops and coalescing where Linux relies on them;
2. classify each effect inside the loop;
3. require a typed carrier only for caller-derived queue/control/offload
   effects;
4. preserve service-only maintenance paths as service authority with service
   budget;
5. define explicit merge semantics before coalescing multiple caller-derived
   operations;
6. invalidate stale service replay after revoke unless fresh reauthorization
   exists.
```

## Required Invariants

```text
No service-only worker may produce queue, DMA, IRQ, offload, or caller control
effects.

No VF mailbox request may configure queues, DMA ring addresses, IRQ maps,
bandwidth, quanta, RSS/VLAN/FDIR, or PTP state without a VF/Domain request
carrier and endpoint-specific authority.

No merged service loop may authorize effects by a single mutable "last caller".

No PTP or DPLL deferred worker may apply a caller-requested control change
without a live caller control carrier.

No bridge/switchdev event may install or replay hardware rules without
OffloadCap, policy generation, and lower QueueLease binding where needed.

No LAG lower_dev rewrite may preserve representor lower QueueLease authority
without a fresh lower rebind.

No reset/rebuild/service replay after revoke may restore old queue/offload/PTP
state without fresh epoch and endpoint reauthorization.
```

## Design Consequence

`ServiceWork` should become a typed CapSched concept, not an ambient exception:

```text
struct capsched_service_work_use {
        service_domain
        service_epoch
        work_class
        effect_class
        caller_domain optional
        caller_epoch optional
        endpoint_cap optional
        queue_lease optional
        offload_cap optional
        policy_generation optional
        service_budget
        merge_semantics
};
```

The structure above is not an implementation decision. It is a semantic
requirement: every future hook placement must be able to explain where these
facts come from or why a path is service-only and unable to perform
caller-attributed effects.
