# Assurance Case Index

Updated: 2026-06-30

## Purpose

This directory tracks the assurance case for CapSched-Linux.

The assurance case is the bridge from local work products to the final
datacenter OS claim:

```text
Process-scale, service-scale, container-scale, tenant-scale, and cluster-cell
Domains should cross each other's hard boundary only by breaking the HyperTag
Monitor or an explicitly exposed typed service endpoint.
```

Linux-only L0 evidence is useful, but it is not production protection evidence.

## Files

| File | Role |
| --- | --- |
| `0001-hypervisor-grade-domain-separation-case.md` | Human-readable top-level claim tree, gaps, forbidden claims, and gate criteria. |
| `0002-modern-nic-queuelease-assurance-map.md` | Human-readable DEV-001 subclaim map for modern NIC QueueLease evidence, gaps, and forbidden claims. |
| `claims.json` | Machine-readable claim, evidence, counterexample, and gate register for AI/state recovery. |
| `modern-nic-queuelease-subclaims-v1.json` | Machine-readable DEV-001 modern NIC subclaim map and evidence classification. |

## Status Legend

```text
Open:
  Claim is required for the final goal but is not yet established.

Model-supported:
  A small or decomposed formal model supports part of the claim.

Prototype-evidenced:
  Linux-only code/build/trace evidence supports compatibility or integration,
  not production isolation.

Protection-evidenced:
  Monitor-backed or equivalent production evidence exists. No current claim has
  this status yet.

Forbidden-for-L0:
  Claim must not be made by Linux-only prototypes.
```

## Current Summary

The current project state has strong semantic atoms, but no production
protection claim yet.

Model-supported areas:

- runnable lease authority
- endpoint async provenance
- broker budget tickets
- monitor activation
- decomposed cluster authority
- memory ownership
- direct-map and TLB revocation pressure
- page-cache overlay conflict handling
- queue lease and IOMMU/IRQ boundary
- modern NIC QueueLease authority-class separation
- XDP and AF_XDP memory ownership
- QueueControl and RepresentorForward separation
- modern NIC queue revoke/drain/quarantine semantics
- VF IRQ revoke ownership and synchronization-exception semantics
- monitor IRQ route invalidation receipt semantics
- monitor DMA/IOMMU/MemoryView invalidation receipt semantics
- stale XSK/page-pool completion quarantine semantics
- representor-to-lower QueueLease derivation semantics
- modern NIC service-work carrier and service/caller authority intersection
  semantics
- VF mailbox queue/DMA/IRQ/budget/FDIR carrier semantics
- VF epoch handoff, reset/reassignment, stale VSI/queue/IRQ/DMA/FDIR/mailbox,
  and service replay freshness semantics
- modern NIC HyperTag Monitor, Linux service/driver Domain, target endpoint,
  and receipt-minting split semantics
- modern NIC HyperTag implementation-readiness gate semantics, explicitly
  limited to observation-only probes and inert stubs
- modern NIC HyperTag observation-ledger source-anchor emission with readiness
  safety flags preserved
- LocalDomainDeviceLease root-management/local monitor compilation semantics,
  explicitly rejecting remote lease direct use, scheduler placement as
  authority, service admission minting, Linux device registration as authority,
  stale cluster epochs, wrong service/target Domains, queue receipt before
  local lease, and audit-only compile
- LocalDomainDeviceLease observation-contract row shape, dependency checks, and
  readiness safety flags for future root-management/local monitor admission
  evidence
- LocalDomainDeviceLease admission protocol failure and revoke ordering
  semantics, including terminal rejection, mismatch handling, receipt embargo,
  and no reuse before revoke completion
- local monitor admission interface boundary semantics, including request-only
  Linux service Domain carriage, monitor-only response minting, replay
  rejection, failure termination, receipt-gated endpoint delivery, revoke
  completion ordering, and raw-handle non-exposure
- direct-call attachment/readiness semantics, including no-code Linux/monitor
  attachment rows, observation-only status, inert stub constraints, failure
  injection containment, schema/ledger/shadow/ring references, and explicit
  rejection of authority, monitor verification, ABI, behavior-change, and
  protection claims
- direct-call trace/source inventory contract semantics, including source-only
  default mode, complete output rows, missing future anchors as gaps, tracefs
  entries as future-plan suggestions, and explicit rejection of Linux
  modification, root requirement, tracefs writes, probe attachment, public
  tracepoint ABI, authority, monitor verification, behavior change, raw handle
  exposure, and protection claims

Prototype-evidenced areas:

- inert `CONFIG_CAPSCHED` build scaffolding
- type-only authority names in Linux
- build compatibility for `CONFIG_CAPSCHED=n` and `CONFIG_CAPSCHED=y`
- source-only direct-call inventory runner output with no Linux modification,
  no root requirement, no tracefs writes, no probe attachment, no public
  tracepoint ABI, and no authority/protection claims
- source-only direct-call inventory expansion with 19 existing trace event
  declaration rows, 12 symbol candidate rows, and 41 overlay seed rows, still
  with no Linux modification, root requirement, tracefs write, probe
  attachment, public tracepoint ABI, runtime coverage, authority claim, monitor
  verification, or protection claim
- source-only direct-call overlay drift checker output with 34 ok rows, 7
  expected gap/plan rows, 0 path changes, 0 missing patterns, 0 semantic
  recheck-required rows, and no authority/protection claims
- source-only project source-map drift checker output with 515 extracted anchor
  rows, 501 path/pattern/symbol-ok rows, 14 preserved gap rows, 0 missing
  symbols, 0 missing patterns, 0 line-only semantic-recheck rows, 3 unsupported
  extractions, recursive boolean safety-field scan, `content_source=git_HEAD_objects`,
  and explicit `semantic_validation=false`
- source-only project overlay ledger normalization output with 515 overlay rows,
  explicit match predicates, 0 rows needing semantic recheck, 14 preserved
  gaps, `n_series_rewrite=false`, and no authority/protection claims
- source-only semantic recheck queue output with 0 semantic recheck items, 14
  gap-preservation items, explicit review classes/actions, and no production
  semantic validation or protection claims
- source-only semantic recheck batch 1 removed the one missing symbol and one
  missing descriptive pattern from the active queue
- source-only semantic recheck line-only batch removed the remaining 19
  line-only anchors from the active queue
- source-only project gap classification output grouped the 14 preserved
  gap/plan rows into 7 semantic direct-call gap groups: 5 high-severity future
  Linux/internal anchors, 1 test-only failure-injection surface, and 1
  trace-only observation plan
- DirectCallGapClosure model support for the rule that high-severity
  direct-call gaps close only through monitor-owned request schema, replay,
  response handle, epoch, and revoke-ordering semantics, and not through Linux
  helpers, wrapper returns, schema queries, timeouts, trace plans, or test hooks
- implementation-facing direct-call gap closure gate with machine-readable
  DCGATE rows for request envelope, direct-call entry/backend, schema
  negotiation, response shadow, and control revoke lane; still no Linux patch
  approved
- DirectCallReceiptSchema model support for the rule that Linux-visible shadows
  are derived cache records only, while monitor-owned receipts are required for
  request image, schema acceptance, entry result, response handle, and revoke
  completion
- source-only direct-call receipt-consumer map with 27 rows: 20 current Linux
  source anchors for inert namespace, scheduler hot-path candidates,
  policy/lifecycle candidates, and async exclusion anchors, plus 7 preserved
  future gap/plan rows. The refreshed project drift run has 542 anchor rows,
  521 ok rows, 21 gap rows, 0 missing symbols/patterns, and no
  authority/protection claims. Gap classification still collapses those 21 rows
  into the same 7 semantic direct-call gap groups, so the added view does not
  resolve any production obligation.
- DirectCallReceiptConsumerPlacement model support for the rule that hot-path
  receipt consumers are bounded shadow checks only, policy/lifecycle paths
  cannot become schema or receipt authority, generic async workers remain
  excluded without typed carriers, future gaps stay gaps, and trace/ABI/runtime/
  monitor/protection overclaims are rejected.
- implementation-facing direct-call receipt-consumer placement gate with 7
  machine-readable DCPGATE rows covering receipt provenance root, hot-path
  bounded consumption, policy/lifecycle separation, generic async exclusion,
  future gap preservation, revoke/shadow invalidation, and evidence class split;
  still no Linux patch approved.
- DirectCallAsyncCarrier model support for the rule that Domain-originated
  async receipt consumption requires a typed carrier carrying caller frozen
  authority, service authority, caller budget ticket, and monitor receipt;
  generic workqueue authority, pending work overwrite, worker identity
  authority, service-only authority, Linux-minted receipt, consume-after-revoke,
  and trace/ABI/runtime/monitor/protection overclaims are rejected.
- implementation-facing direct-call async-carrier gate with 9 machine-readable
  DCASYNC rows covering typed carrier identity, pending coalescing preservation,
  caller BudgetTicket ownership, service/caller intersection, monitor receipt
  provenance, revoke/stale-carrier rejection, workqueue boundary, io_uring
  boundary, and evidence class split; still no Linux patch approved.
- source-only direct-call async source maps for workqueue and io_uring with 37
  current Linux anchors. Project drift run `20260701T025605Z` has 579 total
  anchors, 558 ok rows, 21 preserved gap rows, 0 missing symbols/patterns, 0
  semantic recheck rows, and 0 safety violations. The new async maps do not
  approve Linux code or convert generic async state into authority.
- direct-call async carrier lifetime table with 22 no-patch obligation rows:
  11 workqueue stages and 11 io_uring stages from allocation through free. It
  preserves the rule that Linux queue, worker, cancel, retry, completion, ref
  drop, and free state are not authority without typed carrier semantics.

Open production gaps:

- actual HyperTag Monitor
- real MemoryView/PageOwner enforcement
- per-Domain mutable kernel state
- real scheduler enforcement across all runnable paths
- async provenance implementation
- real IOMMU, IRQ, and queue revocation
- monitor-backed QueueTag, QueueControlCap, RepresentorForwardCap, and typed
  queue ledger roots
- privileged modern NIC HyperTag no-code tracefs run or observation-only Linux
  probe/stub patch
- service-domain TCB reduction
- exploit-containment and cost-efficiency evaluation

Current modern NIC QueueLease summary:

```text
Model-supported:
  SKB/XDP/AF_XDP/control/representor/service authority classes are separated.

Source-observed:
  Intel ice contains usable queue, descriptor, DMA, completion, devlink,
  representor, and service anchors.

Observation-only:
  ice readiness found 19 tracepoint rows, 40 source anchors, and 12
  high-severity gaps. Every row remains authority_claim=false and
  monitor_verified=false.
  ice revoke readiness found 8 tracepoint rows, 31 source anchors, 10
  obligation readiness rows, and 8 high-severity gaps. Every row remains
  observation_only=true, authority_claim=false, and monitor_verified=false.

VF IRQ revoke model:
  safe TLC passed with 25 generated states and 22 distinct states. Unsafe
  configs produced expected counterexamples for VF host-sync assumption, stale
  completion after revoke, reassignment without owner-specific IRQ quiescence,
  host-owned reassignment without synchronize_irq(), and monitor-owned
  reassignment without monitor invalidation.

Monitor IRQ route invalidation model:
  safe TLC passed with 14 generated states and 12 distinct states. Unsafe
  configs produced expected counterexamples for unsafe interrupt override,
  stale eventfd delivery, reassignment without receipt, receipt without IEC
  flush, receipt with posted state, and receipt with eventfd still live.

Monitor DMA/IOMMU invalidation model:
  safe TLC passed with 17 generated states and 17 distinct states. Unsafe
  configs produced expected counterexamples for IRQ-only reassignment,
  driver-unmap-only receipt, IOMMU unmap without IOTLB sync, queued-flush
  receipt, PageOwner transfer with DMA in flight, new MemoryView before old
  unmap, completion after revoke, and packet return before receipt. The
  receipt now also requires monitor-owned DMA root, new-work embargo,
  hardware queue quiescence, HW-owned descriptor drain, access-user release,
  and old device-domain/PASID fence.

XSK and page-pool quarantine model:
  safe TLC passed with 11 generated states and 11 distinct states. Unsafe
  configs produced expected counterexamples for XSK CQ submit after revoke,
  XSK free-list return after revoke, page-pool recycle after revoke, packet
  return before DMA receipt, PageOwner transfer before quarantine, packet
  return without generation reset, double return, and queue reassignment before
  settlement.

Representor lower QueueLease model:
  safe TLC passed with 14 generated states and 8 distinct states. Unsafe
  configs produced expected counterexamples for representor netdev-only lower
  forwarding, bridge FDB as lower lease, VLAN as lower lease, TC/offload rule
  install without control authority, TC/offload stale destination after LAG
  lower_dev change, forwarding with stale lower_dev, forwarding after revoke,
  and representor stop as lower QueueLease revoke.

Modern NIC ServiceWork carrier model:
  safe TLC passed with 29 generated states and 18 distinct states. Unsafe
  configs produced expected counterexamples for service-worker ambient queue
  effects, VF mailbox effects without a carrier, coalesced-loop last-caller
  authority, PTP control without a carrier, DPLL control without a carrier,
  bridge/offload effects without policy and control authority, LAG rebind
  without fresh lower QueueLease, and reset/rebuild replay after revoke without
  fresh authorization.

VF mailbox carrier model:
  safe TLC passed with 42 generated states and 23 distinct states. Unsafe
  configs produced expected counterexamples for virtchnl validation as queue
  authority, DMA ring base programming without MemoryView/IOMMU authority,
  queue enable without frozen queue configuration, IRQ map without route
  authority, queue budget/quanta programming without budget authority, FDIR
  write without OffloadCap, FDIR completion without frozen context, and effects
  after revoke.

VF epoch handoff model:
  safe TLC passed with 9 generated states and 9 distinct states. Unsafe configs
  produced expected counterexamples for visible vf_id reuse without a fresh VF
  epoch, VSI reuse without generation bump, queue reassignment before stale
  DMA/IOMMU revoke, IRQ route reassignment before stale route revoke, FDIR
  completion surviving reset, mailbox processing during reset embargo,
  allowlist/capability state surviving reset as authority, and service replay
  under the old epoch.

Modern NIC HyperTag split model:
  safe TLC passed with 10 generated states and 10 distinct states. Unsafe
  configs produced expected counterexamples for service Domain minting monitor
  roots, Linux DMA state as DMA receipt, Linux IRQ state as IRQ receipt, raw
  PF/VF/IOMMU/MSI/devlink endpoint exposure, queue activation without DMA/IRQ
  receipts, service replay under old epoch, remote cluster lease use without
  local monitor compilation, audit-only monitor calls after Linux side effects,
  and per-packet monitor traps on the ordinary data path.

Modern NIC HyperTag readiness gate model:
  safe TLC passed with 8 generated states and 7 distinct states. Unsafe configs
  produced expected counterexamples for behavior-changing approval before gate
  satisfaction, probe-as-authority, non-inert stubs, missing receipt/carrier
  coverage, raw endpoint exposure through stubs, and protection claims from
  readiness evidence.

Modern NIC HyperTag observation ledger:
  validation/0062 emitted 37 observation-ledger rows from the current Linux
  source tree, with 36 available anchors, 1 expected missing row, and 0 safety
  flag violations. The only missing row is LocalDomainDeviceLease, which is
  outside upstream Linux and remains a high-severity root-management/local
  monitor compilation gap.

LocalDomainDeviceLease compilation model:
  analysis/0064 and validation/0063 resolve the N-090 missing row as an
  external design boundary, not as a Linux source-anchor gap. Safe TLC passed
  with 10 generated states, 9 distinct states, and depth 9. Unsafe configs
  produced expected counterexamples for remote ClusterLease direct use,
  scheduler placement as authority, service admission minting, Linux device
  registration as authority, stale cluster epoch, wrong service Domain, wrong
  target Domain, queue receipt before local lease, and audit-only compile. This
  is model-supported semantics only, not monitor implementation or protection
  evidence.

LocalDomainDeviceLease observation contract:
  analysis/0065 and validation/0064 define and validate the pre-monitor row
  contract for root-management/local monitor admission evidence. The runner
  emitted 10 rows, checked 7 dependency rules, found 0 dependency errors, found
  0 safety-flag violations, and preserved 9 forbidden authority collapses. This
  is observation-contract readiness only, not monitor implementation or
  protection evidence.

LocalDomainDeviceLease admission protocol:
  analysis/0066 and validation/0065 map the root-management/local monitor
  admission protocol to the observation contract. Safe TLC passed with 29
  generated states, 21 distinct states, and depth 14. Unsafe configs produced
  expected counterexamples for compile after failed cluster checks, compile
  with service mismatch, compile with target mismatch, receipt before local
  lease, new receipt during revoke, local lease reuse before revoke completion,
  and audit-only admission/revoke acceptance. This is model-supported semantics
  only, not root-management, monitor, or protection evidence.

Local monitor admission interface boundary:
  analysis/0067 and validation/0066 define and check the pre-ABI request/
  response boundary. Safe TLC passed with 14 generated states, 12 distinct
  states, and depth 11. Unsafe configs produced expected counterexamples for
  Linux-minted monitor responses, replayed admission response acceptance,
  failure-then-compile, receipt without monitor local lease response, endpoint
  without receipts, revoke complete with live derived receipts, and raw service
  handle exposure. This is model-supported semantics only, not ABI,
  implementation, or protection evidence.

Monitor admission carrier/storage choice gate:
  analysis/0068 and validation/0067 compare direct monitor calls,
  monitor-owned shared rings, Linux service-domain queues, monitor receipt
  ledgers, Linux-visible shadows, audit-only logs, and raw driver handles. Safe
  TLC passed with 11 generated states, 9 distinct states, and depth 7. Unsafe
  configs produced expected counterexamples for Linux-owned response authority,
  service-domain queue authority, Linux shadow authority, replayed ring slots,
  tampered receipt ledgers, request-as-receipt, audit-as-authority, and raw
  handle endpoint delivery. This is model-supported semantics only, not ABI,
  implementation, or protection evidence.

Local monitor admission ABI semantic candidate:
  analysis/0069 and validation/0068 define and check `LocalMonitorAdmissionABI-
  v0` semantics before choosing a carrier or binary ABI. Safe TLC passed with
  24 generated states, 20 distinct states, and depth 12. Unsafe configs
  produced expected counterexamples for unknown request-class acceptance,
  response without request, replay acceptance, failure-then-receipt,
  Linux-owned ledger writes, endpoint before receipt, Linux shadow authority,
  missing shadow invalidation before revoke complete, new receipt during
  revoke, and revoke complete before derived receipt revoke. This is
  model-supported semantics only, not ABI layout, implementation, or protection
  evidence.

Monitor admission carrier sketch comparison:
  analysis/0070 and validation/0069 compare direct-call-first reference
  semantics with monitor-owned-ring-first throughput refinement. Safe TLC
  passed with 18 generated states, 16 distinct states, and depth 9. Unsafe
  configs produced expected counterexamples for Linux direct response authority,
  direct response without replay check, ring slot authority, ring response
  before monitor claim, batch epoch crossing, shadow refresh from carrier,
  revoke complete with pending ring responses, and performance cost as security
  authority. This is model-supported semantics only, not ABI layout,
  implementation, performance, or protection evidence.

Direct-call reference ABI sketch:
  analysis/0071 and validation/0070 define and check the direct-call reference
  semantics for `LocalMonitorAdmissionABI-v0`. Safe TLC passed with 23
  generated states, 21 distinct states, and depth 20. Unsafe configs produced
  expected counterexamples for validating Linux mutable request memory, success
  without monitor entry, ledger write without copied-request validation, ledger
  before replay consume, Linux ledger writes, response handle without ledger,
  shadow refresh from request, shadow authority, receipt after terminal
  failure, revoke complete without embargo, revoke complete with in-flight
  direct calls, and revoke complete before derived receipt revoke plus shadow
  invalidation. This is model-supported reference semantics only, not ABI
  layout, implementation, performance, or protection evidence.

Monitor-owned ring refinement sketch:
  analysis/0072 and validation/0071 define and check the monitor-owned ring
  throughput refinement against the direct-call reference semantics. Safe TLC
  passed with 21 generated states, 19 distinct states, and depth 18. Unsafe
  configs produced expected counterexamples for Linux slot authority, response
  before monitor claim, post-claim mutation affecting validation, slot reuse
  without monitor generation advance, batch epoch crossing, ledger write before
  replay consume, Linux response publication, shadow refresh from ring state,
  revoke complete with pending claimed slot, revoke complete with pending
  response, and ring-full/drop accounting as success authority. This is
  model-supported refinement semantics only, not ABI layout, implementation,
  performance, or protection evidence.

Combined admission carrier plan:
  analysis/0073 and validation/0072 define and check the combined direct-call
  plus monitor-owned-ring carrier semantics. Safe TLC passed with 52 generated
  states, 46 distinct states, and depth 17. Unsafe configs produced expected
  counterexamples for carrier-local attempt ids, carrier-local ledgers,
  carrier-local shadow generation, duplicate direct/ring fallback success,
  carrier/ledger epoch split, response without shared ledger, revoke stopping
  only one carrier, revoke complete with direct in-flight calls, revoke
  complete with ring pending state, ring-full accounting as monitor failure,
  and separate carrier-local replay. This is model-supported carrier-join
  semantics only, not ABI layout, implementation, performance, liveness, or
  protection evidence.

Direct-call carrier requirements gate:
  analysis/0074 and validation/0073 define and check implementation-facing
  requirements for using direct-call as the first concrete local monitor
  admission carrier. Safe TLC passed with 26 generated states, 22 distinct
  states, and depth 20. Unsafe configs produced expected counterexamples for
  carrier selection as approval, carrier sequence as replay authority, control
  priority bypass, direct-only replay/ledger/shadow namespaces, ledger before
  replay, response without ledger, same-nonce different-digest success, shadow
  refresh without shared generation, success without canonical attempt, Linux
  timeout as monitor failure, transport observation as receipt, and validation
  before bounded copy/freeze. This is model-supported implementation-facing
  requirements only, not binary ABI layout, C struct definition, Linux stub,
  monitor implementation, performance, liveness, or protection evidence.

Direct-call schema compatibility gate:
  analysis/0075 and validation/0074 define and check the direct-call semantic
  schema compatibility candidate. Safe TLC passed with 37 generated states, 28
  distinct states, and depth 14. Unsafe configs produced expected
  counterexamples for caller minimum downgrade, unknown critical optional field
  ignore, direct-only schema namespace, ignored optional field authority,
  missing required features, monitor minimum downgrade, stripped required
  safety features, incompatible response/ledger schemas, shadow refresh from
  unsupported response interpretation, transport observation as receipt,
  unknown mandatory accept, unknown success code authority, and unsupported
  semantic schema accept. This is model-supported schema negotiation semantics
  only, not numeric schema-id assignment, binary encoding, C struct layout,
  Linux stub, monitor implementation, performance, liveness, or protection
  evidence.

Direct-call attachment readiness gate:
  analysis/0076 and validation/0075 define and check the no-code Linux/monitor
  attachment-readiness boundary for direct-call carrier work. Safe TLC passed
  with 11 generated states, 10 distinct states, and depth 10. Unsafe configs
  produced expected counterexamples for missing row coverage, authority claims,
  monitor verification claims, behavior changes, user ABI, public tracepoint
  ABI, protection claims, authorizing or behavior-changing stubs, probes as
  authority, Linux ledger/response minting, shadow refresh from timeout or
  return code, live fault-injection effects, raw handle exposure, and
  direct-only ring-incompatible namespaces. This is no-code readiness evidence
  only, not a Linux patch, monitor implementation, binary ABI, user ABI, public
  tracepoint ABI, performance, liveness, or protection evidence.

Direct-call trace/source inventory contract:
  analysis/0077 and validation/0076 define and check the no-code source-only
  inventory contract for existing Linux source/tracing anchors. Safe TLC passed
  with 6 generated states, 5 distinct states, and depth 5. Unsafe configs
  produced expected counterexamples for source anchors as authority, behavior
  change, Linux modification, missing anchor as no obligation, monitor
  verification, incomplete outputs, probe attachment, protection claim, public
  tracepoint ABI, raw handle exposure, source-only root requirement, runtime
  observation claim, missing safety flags, trace plan as authority, and tracefs
  writes. This is runner-contract evidence only, not a runner implementation,
  Linux patch, tracefs execution, QEMU run, ABI, performance, liveness, or
  protection evidence.

Direct-call source-only inventory runner:
  validation/0077 executed the N-104 runner contract against the current Linux
  source tree. The run emitted 10 ledger rows: 3 current anchors, 6 future gaps,
  1 trace-plan row, 7 total gap rows, and 0 safety-flag violations. The result
  preserved source_only=true, requires_privilege=false, writes_tracefs=false,
  attaches_probes=false, modifies_linux=false, public_tracepoint_abi=false,
  authority_claim=false, monitor_verified=false, and protection_claim=false.
  This is source-only prototype evidence, not tracefs runtime coverage,
  monitor verification, ABI approval, or protection evidence.

Project source-map drift checker:
  validation/0080 executed the project-level source-map drift checker against
  legacy machine-readable source maps and the latest direct-call overlay seed.
  The latest run emitted 515 anchor rows: 501 path/pattern/symbol-ok rows,
  14 preserved gaps, 0 missing symbols, 0 missing patterns, 0 line-only rows,
  and 3 unsupported extractions. It used
  `git HEAD` objects rather than mutable worktree contents and preserved
  source_only=true, source path/pattern only, semantic_validation=false,
  authority_claim=false,
  monitor_verified=false, and protection_claim=false. This is upstream drift
  triage evidence only, not semantic validation, runtime coverage, monitor
  verification, ABI approval, or protection evidence.

Project overlay ledger normalizer:
  validation/0081 normalized the project drift rows into 515 central overlay
  rows with explicit source artifact, source context, Linux anchor id, match
  kind, drift status, evidence class, unsupported claims, and next action. It
  produced 0 `needs_semantic_recheck` rows and 14 preserved gap rows. The run
  preserved source_only=true, semantic_validation=false, n_series_rewrite=false,
  authority_claim=false, monitor_verified=false, and protection_claim=false.
  This is traceability normalization evidence only, not implementation approval
  or protection evidence.

Semantic recheck queue:
  validation/0082 built a queue from the central overlay ledger: 0 semantic
  recheck items and 14 gap-preservation items after N-112.
  The queue records recommended review actions and forbidden claims. This is
  workflow preparation only, not production semantic validation or protection
  evidence.

Semantic recheck batch 1:
  validation/0083 rechecked the high-priority missing symbol and descriptive
  pattern rows. `ice_alloc_vfs` was updated to `ice_create_vf_entries`, and
  `inert translation unit` was replaced with the literal source pattern
  `This translation unit is intentionally inert`. validation/0084 then
  rechecked the remaining line-only anchors. The active semantic recheck queue
  is now empty, with 14 preserved gap/plan rows remaining. This is source-anchor
  cleanup, not runtime coverage, monitor verification, or protection evidence.

Project gap classification:
  validation/0085 classified the 14 preserved gap/plan rows into 7 semantic
  direct-call gap groups. Five are high-severity future Linux/internal anchors
  that still require monitor-owned direct-call semantics before implementation:
  request envelope, direct-call entry/backend, schema negotiation,
  response-handle shadow refresh, and control revoke lane. One is test-only
  failure injection, and one is trace-only observation. This is gap
  classification, not gap resolution, implementation approval, runtime
  coverage, monitor verification, or protection evidence.

Direct-call gap closure model:
  validation/0086 checked formal/0055 DirectCallGapClosure. The safe model
  passed with 6 generated states, 5 distinct states, and depth 5. Unsafe
  configs produced expected counterexamples for stub before gap closure,
  Linux-built canonical envelope, entry without monitor schema, Linux schema
  decision, timeout shadow refresh, control revoke bypass, trace plan as
  coverage, test hook live effect, ABI approval, behavior change, monitor
  verification claim, and protection claim. This is a design gate, not a Linux
  implementation or production protection evidence.

Direct-call gap closure implementation gate:
  implementation/0009 and direct-call-gap-closure-gate-v1.json translate the
  DirectCallGapClosure model into five pre-patch DCGATE rows. Each row names the
  Linux-facing candidate surface, monitor-owned requirements, required receipts,
  forbidden fallbacks, and patch preconditions. This is an implementation-facing
  checklist, not patch approval, ABI approval, monitor verification, runtime
  coverage, or protection evidence.

Direct-call receipt schema model:
  analysis/0079 and formal/0056 define RequestImageReceipt, SchemaReceipt,
  EntryResultReceipt, ResponseHandleReceipt, and RevokeReceipt as monitor-owned
  receipt families. validation/0087 safe TLC passed with 10 generated states,
  9 distinct states, and depth 9. Unsafe configs produced expected
  counterexamples for Linux-minted receipt, Linux schema acceptance, wrapper
  return as receipt, timeout shadow refresh, Linux shadow authority, response
  during revoke, revoke completion with in-flight response, trace plan as
  coverage, ABI approval, behavior change, monitor verification claim, and
  protection claim. This is a receipt-schema gate, not implementation evidence.

Forbidden:
  Do not treat netdev/ring/q_vector/devlink/workqueue state as production
  authority. Do not treat netdev down/reset, ring cleanup, NAPI disable,
  Linux-owned DMA unmap, queued IOMMU flush, iommufd IOAS unmap, VFIO unmap
  callback, xsk_tx_completed(), xsk_buff_free(), page-pool recycle,
  representor stop, bridge FDB/VLAN success, TC redirect target, metadata_dst,
  devlink reload, worker identity, ICE_SERVICE_SCHED, virtchnl allowlists,
  PTP/DPLL callback reachability, LAG lower_dev rewrites, or reset/rebuild
  replay, VF-provided dma_ring_addr, queue id checks, vector id checks, QoS
  caps, FDIR ctx_done, vf_id equality, ice_vf pointer reachability, vf->cfg_lock,
  ICE_VF_STATE_ACTIVE/DIS, stable lan_vsi_idx/ctrl_vsi_idx, MSI-X vector id, or
  VPLAN/VPINT programming success, service Domain policy, Linux DMA/IRQ state,
  signed cluster lease text, audit-only monitor logging, or raw PF/VF/IOMMU/MSI/
  devlink handle exposure as QueueLease authority, Domain ownership, receipt
  minting, or revoke authority. Do not treat an observation probe, inert stub,
  readiness ledger, or successful readiness TLC run as production protection.
  Do not treat root-management ClusterLease text, scheduler placement,
  service-domain admission, Linux PCI/devlink/IOMMU registration, or tracefs
  observation as a LocalDomainDeviceLease.
  Do not treat direct-call attachment rows, probes, inert stubs, trace runners,
  Linux timeouts, Linux-visible shadows, or schema coverage as monitor
  authority, behavior approval, ABI selection, or protection evidence.
  Do not treat a source-only inventory contract as tracefs execution, runtime
  coverage, monitor verification, or permission to add public tracepoint ABI.
  Do not treat project source-map drift `ok_rows` as semantic validation or
  production protection evidence.
  Do not treat an empty semantic recheck queue as production semantic review or
  as resolution of preserved gap/plan rows.
  Do not treat project gap classification as gap resolution, direct-call ABI
  approval, monitor verification, or permission to add behavior-changing
  direct-call stubs.
  Do not treat the DirectCallGapClosure TLC pass as direct-call stub
  implementation, ABI approval, monitor verification, runtime coverage, or
  production protection.
  Do not treat implementation/0009 or direct-call-gap-closure-gate-v1.json as
  approval to add direct-call stubs, ABI, public tracepoints, or behavior
  changes.
  Do not treat the DirectCallReceiptSchema TLC pass as monitor implementation,
  Linux direct-call implementation, ABI approval, runtime coverage, monitor
  verification, or production protection.
  Do not implement behavior-changing QueueLease enforcement from this evidence
  alone.
```
