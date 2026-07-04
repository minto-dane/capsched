# Analysis Index

Updated: 2026-07-04

## Current Analysis Notes

| ID | Status | Title |
| --- | --- | --- |
| 0001 | Draft | Initial Linux Source Map |
| 0002 | Draft | Scheduler Execution Spine |
| 0003 | Draft | Task Lifecycle and Identity |
| 0004 | Draft | Existing Resource Controls and Compatibility |
| 0005 | Draft | Async Provenance Risk Map |
| 0006 | Draft | Cluster Domain Capability Mapping |
| 0007 | Draft | Capability Invariant Matrix |
| 0008 | Draft | Policy Front-Ends and Capability Issuance |
| 0009 | Draft | Mutable Kernel State Boundary Map |
| 0010 | Draft | Dangerous Surfaces and Service Domains |
| 0011 | Draft | Network Socket Endpoint Map |
| 0012 | Draft | io_uring Registered Resource Provenance |
| 0013 | Draft | BPF Programmable Policy Boundary |
| 0014 | Draft | Scheduler Topology and Cluster Partition Map |
| 0015 | Draft | Endpoint Async Linux Attachment Map |
| 0016 | Updated | Device IOMMU and Queue Lease Map |
| 0017 | Draft | MM Allocator and Page Cache Domain State Map |
| 0018 | Draft | Protection Claim Evidence Map |
| 0019 | Draft | Wakeup, Enqueue, and Runnable-State Coverage |
| 0020 | Completed | QEMU ftrace and Symbol Eligibility for Slice 0C |
| 0021 | Draft synthesis | Slice 0C Observation Synthesis and Hook-Placement Constraints |
| 0022 | Draft methodology, revised after critical review | Behavior Tagging Methodology for Mechanical Design Selection |
| 0023 | Review complete, schema v2 required | Critical Review of Behavior Tagging Before Schema Finalization |
| 0024 | Accepted analysis direction | Invariant-Driven Design and the Role of Tags |
| 0025 | Draft state machine, source-only refresh applied | Linux Scheduler Authority State Machine |
| 0026 | Draft obligation matrix, source-only refresh applied | Scheduler Hook Proof Obligation Matrix |
| 0027 | Draft schema and v2 retagging complete for gap analysis | Schema v2 Derived from the Scheduler Authority Model |
| 0028 | Draft source map, source-only refresh applied | Tick and Runtime Budget Source Map |
| 0029 | Draft source map | Fork, Clone, Exec, and Exit Identity Propagation Map |
| 0030 | Draft boundary map | TASK_WAKING Failability Boundary Map |
| 0031 | Draft dependency map with TLC-backed design filter | F1 Admission-Freeze Data Dependencies |
| 0032 | Draft source map with TLC-backed design filter | Block, Wait, and Register Authority Preparation |
| 0033 | Draft lifecycle map with TLC-backed design filter | Task-Local Resumable-Run Lifecycle |
| 0034 | Draft carrier map with TLC-backed design filter | Workqueue and kthread_work BudgetTicket Carrier |
| 0035 | Draft endpoint map with TLC-backed design filter | Shared Futex Endpoint Authority |
| 0036 | Draft dependency-authority map with TLC-backed design filter | PI, RT, and ww_mutex Priority Donation Authority |
| 0037 | Draft placement map with TLC-backed design filter | Placement Refresh, Affinity, cpuset, Hotplug Authority |
| 0038 | Draft monitor-fast-path map with TLC-backed design filter | Same-Domain Monitor Fast Path and Budget Freshness |
| 0039 | Draft budget map with TLC-backed design filter | Root Budget, SchedContext Budget, and NO_HZ Overrun Boundary |
| 0040 | Draft selected-state map with TLC-backed design filter | Class-Specific Selected-State Boundary |
| 0041 | Draft endpoint semantics map with TLC-backed design filter | Wider Endpoint Capability Semantics |
| 0042 | Draft exec boundary map with TLC-backed design filter | Exec Generation and Inherited Endpoint Semantics |
| 0043 | Draft inheritance-class map with TLC-backed design filter | Post-Exec Resource Inheritance Classes |
| 0044 | Draft trace-only coverage map | Post-Exec Resource Trace-Only Coverage Map |
| 0045 | Draft design boundary | Workqueue Internal Redesign Boundary |
| 0046 | Draft taxonomy | Workqueue Origin Taxonomy |
| 0047 | Draft source-inventory map | drivers/net Workqueue Origin Map |
| 0048 | Draft representative source map | usbnet Workqueue Source Map |
| 0049 | Draft representative Ethernet source map | e1000e QueueLease Source Map |
| 0050 | Draft settlement semantics with TLC-backed design filter | Aggregate QueueLease Settlement Semantics |
| 0051 | Draft observation-only plan | Linux Queue/Descriptor Ledger Observation Plan |
| 0052 | Draft modern NIC source map | Intel ice Modern NIC QueueLease Source Map |
| 0053 | Draft revoke source map | Intel ice Modern NIC Revoke Source Map |
| 0054 | Draft source map with model gate | Monitor IRQ Route Invalidation Source Map |
| 0055 | Draft source map with model gate | Monitor DMA/IOMMU and MemoryView Invalidation Source Map |
| 0056 | Draft source map with model gate | XSK and Page-Pool Quarantine Source Map |
| 0057 | Draft source map with model gate | Representor Lower QueueLease Source Map |
| 0058 | Draft source map with model gate | ICE ServiceWork Carrier Source Map |
| 0059 | Draft source map with model gate | ICE VF Mailbox Queue Carrier Source Map |
| 0060 | Draft source map with model gate | ICE VF Epoch and Handoff Source Map |
| 0061 | Draft architecture map with model gate | Modern NIC HyperTag Interface and Service Domain Split |
| 0062 | Draft implementation-readiness map with model gate | Modern NIC HyperTag Readiness Probe Map |
| 0063 | Draft observation ledger | Modern NIC HyperTag Observation Ledger |
| 0064 | Draft external-gap map with model gate | Local Domain Device Lease Compilation |
| 0065 | Draft observation contract | Local Domain Device Lease Observation Contract |
| 0066 | Draft admission protocol with model gate | Local Domain Device Lease Admission Protocol |
| 0067 | Draft interface boundary with model gate | Local Monitor Admission Interface Boundary |
| 0068 | Draft choice gate with model | Local Monitor Admission Carrier and Receipt Storage |
| 0069 | Draft semantic ABI candidate with model gate | Local Monitor Admission ABI Semantics Candidate |
| 0070 | Draft implementation-facing sketch comparison with model gate | Local Monitor Admission Carrier Sketch Comparison |
| 0071 | Draft reference ABI sketch with model gate | Direct-Call Reference ABI Sketch |
| 0072 | Draft throughput refinement sketch with model gate | Monitor-Owned Ring Refinement Sketch |
| 0073 | Draft combined carrier plan with model gate | Combined Direct-Call and Ring Admission Carrier Plan |
| 0074 | Draft implementation-facing carrier requirements with model gate | Direct-Call Carrier Requirements Gate |
| 0075 | Draft semantic schema candidate with model gate | Direct-Call Semantic Schema and Compatibility |
| 0076 | Draft no-code attachment/readiness map with model gate | Direct-Call Attachment Readiness Map |
| 0077 | Draft no-code inventory contract with model gate | Direct-Call Trace/Source Inventory Contract |
| 0078 | Draft direct-call gap closure design with model gate | Direct-Call Gap Closure Design |
| 0079 | Draft monitor-owned receipt schema with model gate | Direct-Call Monitor Receipt Schema |
| 0080 | Draft source-only map | Direct-Call Receipt Consumer Source Map |
| 0081 | Draft source-only async carrier map | Direct-Call Async Workqueue and io_uring Source Map |
| 0082 | Draft no-patch lifetime table | Direct-Call Async Carrier Lifetime Table |
| 0083 | Accepted no-behavior API direction | Direct-Call Async Carrier API Direction |
| 0084 | Draft refinement model input | Direct-Call Workqueue Adapter Refinement |
| 0085 | Draft refinement model input | Direct-Call io_uring Adapter Refinement |
| 0086 | Current-source review complete; no new Linux patch recommended | Linux Upstream Drift and Maintenance Review |
| 0087 | Automation contract drafted and executed | Linux Source-Drift Automation and Model-Freshness Gate |
| 0088 | Target selected for source-only refresh | Linux Source-Map Refresh Target Selection |
| 0089 | Draft model gate with TLC-backed design filter | Scheduler Authority Refinement Gate |
| 0090 | Draft model gate with TLC-backed design filter | Runtime Charge Subject Map |
| 0091 | Draft model gate with TLC-backed design filter | Scheduler Server Ticket Map |
| 0092 | Draft trace-only coverage gate with TLC-backed design filter | Runtime Coverage Gate |
| 0093 | Draft monitor-root budget event model with TLC-backed design filter | Monitor Root Budget Timer |
| 0094 | Draft model gate with TLC-backed design filter | Server Epoch Relation |
| 0095 | Draft model gate with TLC-backed design filter | Deadline CBS/GRUB Compatibility |
| 0096 | Draft model gate with TLC-backed design filter | F1 Admission-Freeze Refresh |
| 0097 | Draft integration model gate with TLC-backed design filter | Scheduler Authority Integration Gate |
| 0098 | Draft architecture-substrate model gate with TLC-backed design filter | Monitor Timer Architecture Substrate |
| 0099 | Draft integration model gate with TLC-backed design filter | Placement, Affinity, and Hotplug Integration Gate |
| 0100 | Draft hook-placement model gate with TLC-backed design filter | Final Run/Move Revalidation Hook Placement Gate |
| 0101 | Draft model gate with TLC-backed design filter | Final Deny Retry and Ineligibility Gate |
| 0102 | Draft model gate with TLC-backed design filter | Task FrozenRun Lifetime and Locking Gate |
| 0103 | Draft integration model gate with TLC-backed design filter | Lifecycle Identity Propagation Integration Gate |
| 0104 | Draft integration model gate with TLC-backed design filter | Exit/Revoke Pending Authority Drain Gate |
| 0105 | Draft completion gate with TLC-backed design filter | Model Completeness Ledger Gate |
| 0106 | Draft model gate with TLC-backed design filter | TCB Boundary Gate |
| 0107 | Draft model gate with TLC-backed design filter | Side-Channel and Co-Tenancy Policy Gate |
| 0108 | Draft model gate with TLC-backed design filter | Evaluation Contract Gate |
| 0109 | Final model-only completion gate | Final Model Completeness Ledger |
| 0110 | Accepted terminology gate | Terminology Freeze and Rename Risk Review |
| 0111 | Covered by implementation gate | SchedExecLease L0 Readiness and Vertical Slice Design |
| 0112 | Design-only source verification | SchedExecLease P3/P4 Source-Verified Design Boundary |
| 0113 | Design-readiness audit; not complete | Implementation-Ready Completion Audit |
| 0114 | Source-verified design boundary | sched_ext, Core Scheduling, and Proxy Coverage Boundary |
| 0115 | Source-verified B2 design constraint | Bounded Retry and Ineligibility Source Design |
| 0116 | Design-only negative validation plan | Negative Denial Validation Plan |
| 0117 | Design-only path classification with TLC-backed gate | Scheduler Path Classification for P5 |
| 0118 | Design-only claim ledger gate with TLC-backed overclaim rejection | Implementation Claim Ledger Gate |
| 0119 | Design-only implementation-reopen drift gate with fresh upstream observation | Implementation Reopen Upstream Drift Gate |
| 0120 | Final design-ready audit passed; implementation unapproved | Final Implementation-Ready Audit |
| 0121 | P3 overclaim review passed; only placement-only no-behavior compatibility may be claimed | SchedExecLease P3 Overclaim Review |
| 0122 | P4 pre-entry gate passed for allow-all/no-denial scope; P5 denial remains blocked | SchedExecLease P4 Pre-Entry Risk Gate |
| 0123 | P4 paused pending scoped drift closure and anchor evidence hardening | SchedExecLease P4 Pre-Implementation Critical Audit |
| 0124 | P4 candidate-scoped drift blocker closed; implementation still paused pending anchors | Candidate-Scoped Drift Closure Gate |
| 0125 | P4 anchor manifest complete; implementation still paused pending observability and helper proof | SchedExecLease P4 Anchor Manifest |
| 0126 | Static final-run anchor observability complete; runtime coverage remains unproven | SchedExecLease P4 Static Final-Run Observability |
| 0127 | P4 allow-all/no-denial helper proof complete; P4 implementation still not applied | SchedExecLease P4 Allow-All Helper Proof |
| 0128 | P4 allow-only compatibility slice closed after final overclaim/security review; P5 remains blocked | SchedExecLease P4 Final Overclaim and Security Review |
| 0129 | P5 readiness refreshed after P4; denial remains blocked | SchedExecLease P5 Readiness Refresh After P4 |
| 0130 | P5A scope decomposed; no Linux implementation approved | SchedExecLease P5A Scope Proposal |
| 0131 | P5A0 no-behavior infrastructure proposal recorded; no Linux patch approved | SchedExecLease P5A0 No-Behavior Infrastructure Proposal |
| 0132 | P5A0.E prepatch evidence recorded; no Linux patch approved | SchedExecLease P5A0.E Prepatch Evidence |
| 0133 | P5A0.P1 patch plan recorded; no Linux patch approved | SchedExecLease P5A0.P1 No-Behavior Patch Plan |
| 0134 | Subagent-assisted audit; P5A-R/M remain blocked and P5A0.P1 full acceptance evidence is enumerated | SchedExecLease P5A-R/M and P5A0.P1 Acceptance Audit |
| 0135 | Source-map validated; P5A-R remains blocked pending picker-visible CFS ineligibility | SchedExecLease P5A-R CFS Picker Eligibility Source Map |
| 0136 | Formal gate recorded; P5A-R behavior remains unapproved pending source-shape and hierarchy settlement | SchedExecLease P5A-R Picker Ineligibility Gate |
| 0137 | Source-shape gate recorded; EEVDF return dominance checked but hierarchy settlement remains open | SchedExecLease P5A-R EEVDF Return Dominance |
| 0138 | Source/formal gate recorded; group hierarchy settlement checked at pre-code level | SchedExecLease P5A-R Group Hierarchy Settlement |
| 0139 | Source/formal gate recorded; ordinary-CFS-only cross-path exclusion/settlement checked | SchedExecLease P5A-R Cross-Path Exclusion/Settlement |
| 0140 | Source/formal gate recorded; P5A-R overhead/layout constraints checked | SchedExecLease P5A-R Overhead and Layout Gate |
| 0141 | Source/formal validation-plan gate recorded; future P5A-R negative tests enumerated | SchedExecLease P5A-R Negative Validation Plan |
| 0142 | Final audit passed for ordinary-CFS-only patch drafting; behavior remains unaccepted | SchedExecLease P5A-R Implementation-Ready Audit |
| 0143 | Upstream/source-shape refresh passed; P5A-R direct scheduler shape fresh for 0009 draft | SchedExecLease P5A-R Upstream Drift Source-Shape Refresh |
| 0144 | Test-only negative runtime harness design recorded; no Linux patch approved | SchedExecLease P5A-R 0009 Negative Runtime Harness |
| 0145 | 0012 boundary review recorded; synthetic QEMU claim only, production acceptance blocked | SchedExecLease P5A-R 0012 Acceptance Boundary |
| 0146 | P5A-R2 selector direction recorded; production path moves away from post-filter fallback | SchedExecLease P5A-R2 Selector Direction |

## Planned Analysis Notes

1. BPF verifier/JIT TCB sub-map if BPF becomes a policy front-end.
2. Broker BudgetTicket and service Domain charging map.
3. Workqueue origin QEMU stack-trace observation runner.
4. Slice 0C trace-only observation patch map only if schema/modeling requires it.
5. Queue/descriptor trace-only patch map only if readiness gaps require it.

## Behavior Tag Artifacts

| Path | Status | Purpose |
| --- | --- | --- |
| `behavior-tags/slice0c-scheduler-behavior-tags.json` | Draft v1, not solver-eligible | Exploratory Slice 0C behavior tag ledger |
| `behavior-tags/schema-v2-requirements.json` | Requirements only | Mandatory fields and hard reject rules for schema v2 |
| `behavior-tags/schema-v2.json` | Draft contract | Machine-readable schema v2 contract for gap analysis and hard reject |
| `behavior-tags/slice0c-scheduler-behavior-tags-v2.json` | Draft v2, gap-analysis only | Slice 0C behavior paths retagged under schema v2 |
| `workqueue-origin-taxonomy-v1.json` | Draft contract | Machine-readable workqueue origin taxonomy for async source tagging |
| `usbnet-workqueue-source-map-v1.json` | Draft source map | Machine-readable representative usbnet workqueue/container/effect mapping |
| `e1000e-queuelease-source-map-v1.json` | Draft source map | Machine-readable representative Ethernet ring/IRQ/NAPI/QueueLease mapping |
| `queue-descriptor-ledger-tags-v1.json` | Draft observation schema | Machine-readable observation-only queue/descriptor ledger event and tag contract |
| `ice-modern-nic-queuelease-source-map-v1.json` | Draft source map | Machine-readable modern NIC QueueLease mapping for ice SKB/XDP/AF_XDP/devlink/representor paths |
| `ice-modern-nic-revoke-source-map-v1.json` | Draft source map | Machine-readable modern NIC revoke/drain/quarantine source map for ice paths |
| `monitor-irq-route-invalidation-source-map-v1.json` | Draft source map | Machine-readable IRQ route invalidation mapping across ice, VFIO, iommufd, MSI/MSI-X, and interrupt remapping |
| `monitor-dma-iommu-memoryview-invalidation-source-map-v1.json` | Draft source map | Machine-readable DMA/IOMMU/MemoryView invalidation mapping across ice, DMA API, IOMMU core, iommufd, VFIO, and arch IOMMU backends |
| `xsk-pagepool-quarantine-source-map-v1.json` | Draft source map | Machine-readable stale XSK/page-pool completion quarantine and packet memory return map |
| `representor-lower-queuelease-source-map-v1.json` | Draft source map | Machine-readable representor forwarding, bridge/FDB/VLAN/TC offload, and lower QueueLease derivation map |
| `ice-servicework-carrier-source-map-v1.json` | Draft source map | Machine-readable ICE service-work carrier, coalescing, VF mailbox, PTP/DPLL, eswitch, LAG, and reset/rebuild authority map |
| `ice-vf-mailbox-carrier-source-map-v1.json` | Draft source map | Machine-readable ICE VF mailbox queue/DMA/IRQ/budget/FDIR carrier authority map |
| `ice-vf-epoch-handoff-source-map-v1.json` | Draft source map | Machine-readable ICE VF reset/reassignment, VF epoch, VSI generation, queue/IRQ/DMA, FDIR, mailbox, and service replay handoff map |
| `modern-nic-hypertag-interface-map-v1.json` | Draft architecture map | Machine-readable HyperTag Monitor, Linux service/driver Domain, target endpoint, and modern NIC receipt split map |
| `modern-nic-hypertag-readiness-probe-map-v1.json` | Draft readiness map | Machine-readable observation-only probe and inert-stub mapping for modern NIC HyperTag receipts/carriers |
| `modern-nic-hypertag-observation-ledger-v1.json` | Draft observation ledger seed | Machine-readable source-anchor seed for the modern NIC HyperTag observation ledger runner |
| `local-domain-device-lease-compilation-v1.json` | Draft external-gap map | Machine-readable root-management/local monitor compilation boundary for LocalDomainDeviceLease |
| `local-domain-device-lease-observation-contract-v1.json` | Draft observation contract | Machine-readable LocalDomainDeviceLease row contract, dependency rules, safety flags, and forbidden authority collapses |
| `local-domain-device-lease-admission-protocol-v1.json` | Draft admission protocol | Machine-readable root-management/local monitor admission path, failure modes, revoke ordering, and invariant list |
| `local-monitor-admission-interface-boundary-v1.json` | Draft interface boundary | Machine-readable local monitor request/response object boundary, freshness fields, attachment points, and forbidden exposures |
| `local-monitor-admission-carrier-storage-v1.json` | Draft choice gate | Machine-readable local monitor carrier/storage choice gate and authority-collapse rejection map |
| `local-monitor-admission-abi-semantics-v0.json` | Draft semantic ABI candidate | Machine-readable LocalMonitorAdmissionABI-v0 request/response, ledger, replay, shadow, failure, and revoke semantics |
| `local-monitor-admission-carrier-sketch-comparison-v1.json` | Draft sketch comparison | Machine-readable direct-call-first versus monitor-owned-ring-first carrier sketch comparison |
| `direct-call-reference-abi-sketch-v1.json` | Draft reference ABI sketch | Machine-readable direct-call reference semantics for monitor entry, request copy, replay, ledger, response handle, shadow refresh, and revoke |
| `monitor-owned-ring-refinement-sketch-v1.json` | Draft throughput refinement sketch | Machine-readable monitor-owned ring refinement semantics for slot claim, slot epochs, batch boundaries, response publication, drain, and DoS accounting |
| `combined-admission-carriers-plan-v1.json` | Draft combined carrier plan | Machine-readable direct-call plus monitor-owned-ring admission carrier semantics for shared attempt, replay, ledger, shadow, fallback, and revoke ordering |
| `direct-call-carrier-requirements-v1.json` | Draft implementation-facing requirements | Machine-readable direct-call carrier requirements for request envelopes, bounded copy, replay keys, ledger rows, response handles, errors, shadow generation, control lane, and future ring compatibility |
| `direct-call-schema-compatibility-v1.json` | Draft semantic schema candidate | Machine-readable direct-call schema compatibility rules for schema negotiation, field criticality, downgrade rejection, response/ledger/error schemas, and ring-compatible namespaces |
| `direct-call-attachment-readiness-v1.json` | Draft no-code attachment/readiness map | Machine-readable direct-call Linux/monitor attachment rows, safety flags, monitor responsibilities, inert stub constraints, failure-injection boundaries, and ring compatibility requirements |
| `direct-call-trace-source-inventory-contract-v1.json` | Draft no-code inventory contract | Machine-readable source-only direct-call inventory runner contract, seed rows, output schema, safety flags, stop conditions, and optional tracefs-plan boundary |
| `direct-call-monitor-receipt-schema-v1.json` | Draft monitor-owned receipt schema | Machine-readable direct-call receipt families for request image, schema, entry result, response handle, and revoke completion |
| `direct-call-receipt-consumer-source-map-v1.json` | Draft source map | Machine-readable Linux-facing receipt-consumer candidate/exclusion map for N-117, with 20 current source anchors and 7 preserved future gap/plan rows |
| `direct-call-async-workqueue-source-map-v1.json` | Draft source map | Machine-readable generic workqueue async-carrier exclusion and typed-wrapper source map for N-122 |
| `direct-call-async-io-uring-source-map-v1.json` | Draft source map | Machine-readable io_uring request/resource/io-wq async-carrier source map for N-122 |
| `direct-call-async-carrier-lifetime-table-v1.json` | Draft lifetime table | Machine-readable workqueue/io_uring async carrier lifetime obligations for N-123 |
| `direct-call-async-carrier-api-direction-v1.json` | Accepted no-behavior API direction | Machine-readable workqueue-only vs io_uring-only vs shared internal carrier choice for N-124 |
| `direct-call-workqueue-adapter-refinement-v1.json` | Draft refinement model input | Machine-readable workqueue adapter state, transition, unsafe-case, and non-claim contract for N-127 |
| `direct-call-io-uring-adapter-refinement-v1.json` | Draft refinement model input | Machine-readable io_uring adapter request/resource/worker/completion state, unsafe-case, and non-claim contract for N-128 |
| `linux-upstream-drift-maintenance-review-v1.json` | Current-source maintenance gate | Machine-readable upstream drift, merge-tree, no-patch decision, future no-behavior patch gate, drift classes, unsafe patterns, and safety flags for N-131 |
| `linux-source-drift-model-freshness-gate-v1.json` | Automation contract | Machine-readable watch groups, affected artifacts, stale-if-changed rules, blocked patch classes, and non-claim constraints for N-132 |
| `linux-source-map-refresh-target-selection-v1.json` | Target selection | Machine-readable candidate comparison and source-only scheduler_authority_core refresh target selection for N-133 |
| `linux-scheduler-authority-core-refresh-v1.json` | Source-only refresh contract | Machine-readable scheduler authority anchors, refreshed rules, updated artifacts, and safety flags for N-134 |
| `scheduler-authority-refinement-gate-v1.json` | Draft model gate | Machine-readable TASK_WAKING, donor/current/proxy budget, and selected-state refinement gate for N-135 |
| `runtime-charge-subject-v1.json` | Draft model gate | Machine-readable runtime charge subject map for N-136 |
| `implementation-ready-completion-audit-v1.json` | Design-readiness audit | Machine-readable implementation-ready completion status, blockers, and next design order |
| `sched-ext-core-proxy-coverage-boundary-v1.json` | Source-verified coverage boundary | Machine-readable sched_ext/core/proxy open classifications, source surfaces, required decisions, and forbidden assumptions |
| `bounded-retry-ineligibility-source-design-v1.json` | Source-verified B2 design constraint | Machine-readable bounded retry/ineligibility source shape, allowed shapes, forbidden shapes, and future model refresh requirements |
| `negative-denial-validation-plan-v1.json` | Design-only negative validation plan | Machine-readable negative denial test obligations, future observables, path classification requirements, and non-claim safety flags |
| `scheduler-path-classification-for-p5-v1.json` | Design-only path classification | Machine-readable P5 supported/disabled/excluded scheduler path classification and claim-scope guard |
| `implementation-claim-ledger-gate-v1.json` | Design-only claim ledger gate | Machine-readable evidence-class to claim-class rules and mandatory non-claim safety flags for future implementation proposals |
| `implementation-reopen-upstream-drift-gate-v1.json` | Design-only implementation-reopen drift gate | Machine-readable fresh upstream observation, touched-group freshness rules, slice reopen requirements, and non-claim safety flags |
| `final-implementation-ready-audit-v1.json` | Final design-ready audit | Machine-readable final implementation-ready design verdict, slice readiness, future patch requirements, and safety flags |
| `scheduler-server-ticket-v1.json` | Draft model gate | Machine-readable scheduler server-ticket source map and model contract for N-137 |
| `runtime-coverage-gate-v1.json` | Draft trace-only coverage gate | Machine-readable current/donor/proxy/server runtime coverage contract for N-138 |
| `monitor-root-budget-timer-v1.json` | Draft monitor-root budget event model | Machine-readable monitor-owned root budget timer contract for N-139 |
| `server-epoch-relation-v1.json` | Draft model gate | Machine-readable server-kind/server-epoch freshness contract for N-140 |
| `deadline-cbs-grub-compat-v1.json` | Draft model gate | Machine-readable Linux SCHED_DEADLINE CBS/GRUB compatibility and authority-separation contract for N-141 |
| `f1-admission-freeze-refresh-v1.json` | Draft model gate | Machine-readable F1 wake publication and FrozenRunUse boundary contract for N-142 |
| `scheduler-authority-integration-gate-v1.json` | Draft integration model gate | Machine-readable integrated scheduler execution gate for N-143 |
| `monitor-timer-architecture-substrate-v1.json` | Draft architecture-substrate model gate | Machine-readable x86 VMX-root, arm64 EL2, KVM guest timer, Linux timer, and pKVM stage-2 substitution rejection contract for N-144 |
| `placement-affinity-hotplug-integration-gate-v1.json` | Draft integration model gate | Machine-readable placement, affinity, cpuset, hotplug, class-selection, sched_ext, core-scheduling, and Linux-exception integration gate for N-145 |
| `final-run-move-revalidation-hook-placement-gate-v1.json` | Draft hook-placement model gate | Machine-readable final run/move tuple-consumption boundary, stale tuple rejection, and Linux selected/move non-authority contract for N-146 |
| `final-deny-retry-ineligibility-gate-v1.json` | Draft model gate | Machine-readable final run denial retry, ineligibility, fail-closed, and non-authority contract for N-147 |
| `task-frozen-run-lifetime-locking-gate-v1.json` | Draft model gate | Machine-readable task lifetime, generation, RCU-only rejection, rq/pi locking, migration, release, and denied-candidate settlement contract for N-148 |
| `lifecycle-identity-propagation-integration-gate-v1.json` | Draft integration model gate | Machine-readable fork/clone, exec, and exit identity propagation contract for N-149 |
| `exit-revoke-pending-authority-drain-gate-v1.json` | Draft integration model gate | Machine-readable global exit/revoke pending-authority inventory, drain, receipt, settlement, and non-claim contract for N-150 |
| `model-completeness-ledger-gate-v1.json` | Negative completion gate | Machine-readable current model-completeness audit and remaining model-only blockers for N-151 |
| `tcb-boundary-gate-v1.json` | Draft model gate | Machine-readable HyperTag Monitor and service-domain TCB boundary contract for N-152 |
| `side-channel-cotenancy-policy-gate-v1.json` | Draft model gate | Machine-readable explicit co-tenancy and side-channel policy contract for N-153 |
| `evaluation-contract-gate-v1.json` | Draft model gate | Machine-readable production protection and cost-efficiency evaluation contract for N-154 |
| `final-model-completeness-ledger-v1.json` | Final completion ledger | Machine-readable final model-only completion audit for N-155 |
| `terminology-freeze-rename-risk-review-v1.json` | Public vocabulary lock | Machine-readable N-156 terminology freeze, inventory, and alias policy |
| `sched-exec-lease-p4-pre-entry-risk-gate-v1.json` | P4 pre-entry gate | Machine-readable P4 allow-all/no-denial pre-entry evidence, generated-code review, QEMU matrix, drift, security-diff preflight, and non-claim constraints |
| `sched-exec-lease-p4-pre-implementation-critical-audit-v1.json` | P4 pause gate | Machine-readable P4 pre-implementation multi-axis audit, hardened fresh drift result, stale global D4 finding, axis verdicts, and reopen criteria |
| `candidate-scoped-drift-closure-gate-v1.json` | Candidate-scope gate | Machine-readable P4 candidate-scoped drift closure, non-candidate stale containment, formal result summary, remaining P4 blockers, and non-claims |
| `sched-exec-lease-p4-anchor-manifest-v1.json` | P4 anchor manifest | Machine-readable P4 final-run/common-move/locked-move anchor windows, source-order constraints, explicit non-coverage, remaining blockers, and non-claims |
| `sched-exec-lease-p4-static-final-run-observability-v1.json` | Static final-run observability | Machine-readable P4 final-run static pre-rq-curr observability, P3 marker negative observation, remaining blockers, and non-claims |
| `sched-exec-lease-p4-allow-all-helper-proof-v1.json` | P4 allow-all helper proof | Machine-readable P4 allow-only/no-denial helper contract, current-tree source check, remaining patch acceptance requirements, and non-claims |
| `sched-exec-lease-p4-final-overclaim-security-review-v1.json` | P4 final review | Machine-readable P4 final overclaim/security review, accepted compatibility evidence, zero finding result, allowed claim, forbidden claims, and next gate |
| `sched-exec-lease-p5-readiness-refresh-after-p4-v1.json` | P5 blocked refresh | Machine-readable post-P4 P5 readiness refresh, run/move denial blockers, source facts, preconditions, and non-claims |
| `sched-exec-lease-p5a-scope-proposal-v1.json` | P5A scope proposal | Machine-readable P5A0/P5A-R/P5A-M/P5A-V decomposition, narrowed run/move blockers, forbidden claims, and review order |
| `sched-exec-lease-p5a0-no-behavior-infrastructure-proposal-v1.json` | P5A0 proposal | Machine-readable no-behavior infrastructure proposal, future patch constraints, move/run/test/setup shapes, required validation, and non-claims |
| `sched-exec-lease-p5a0-e-prepatch-evidence-v1.json` | P5A0.E evidence | Machine-readable prepatch evidence package, candidate-scoped drift, future patch identity, source observations, low-overhead constraints, and non-claims |
| `sched-exec-lease-p5a0-p1-no-behavior-patch-plan-v1.json` | P5A0.P1 patch plan | Machine-readable no-behavior patch-plan gate, per-0008 delta rule, lifecycle freeze, no-overhead acceptance evidence, and non-claims |
| `sched-exec-lease-p5a-r-m-and-p5a0-p1-acceptance-audit-v1.json` | P5A blockers and acceptance audit | Machine-readable P5A-R picker blocker, P5A-M move settlement blocker, P5A0.P1 full-acceptance evidence gap, and forbidden claims |
| `sched-exec-lease-p5a-r-cfs-picker-eligibility-source-map-v1.json` | P5A-R CFS picker source map | Machine-readable CFS picker eligibility anchors, denied-candidate blockers, bounded-retry requirements, cross-path exclusions, and non-claims |
| `sched-exec-lease-p5a-r-picker-ineligibility-gate-v1.json` | P5A-R formal gate | Machine-readable attempt-local ineligibility, bounded retry, cost/layout, EEVDF return coverage, cross-path settlement, and non-claim gate |
| `sched-exec-lease-p5a-r-eevdf-return-dominance-v1.json` | P5A-R source-shape gate | Machine-readable EEVDF return-site dominance, semantic candidate families, source-shape outputs, drift handling, and non-claim gate |
| `sched-exec-lease-p5a-r-group-hierarchy-settlement-v1.json` | P5A-R hierarchy gate | Machine-readable leaf/path/child-exhaustion/parent-skip distinctions, source anchors, formal results, and non-claim gate |
| `sched-exec-lease-p5a-r-cross-path-exclusion-settlement-v1.json` | P5A-R cross-path gate | Machine-readable ordinary-CFS-only cross-path exclusion/settlement contract for core, DL server, proxy, sched_ext, class-loop, source anchors, formal results, and non-claim gate |
| `sched-exec-lease-p5a-r-overhead-layout-gate-v1.json` | P5A-R overhead/layout gate | Machine-readable no-O(n), no-hot-layout, disabled-overhead, source-shape, formal-result, and non-claim gate |
| `sched-exec-lease-p5a-r-negative-validation-plan-v1.json` | P5A-R negative validation plan | Machine-readable negative test families, required observables, validation layers, formal result, and non-claim gate |
| `sched-exec-lease-p5a-r-0009-negative-runtime-harness-v1.json` | P5A-R 0009 negative harness design | Machine-readable test-only CFS denial harness boundary, synthetic denial predicate, targeted negative families, and non-claim gate |
| `sched-exec-lease-p5a-r-0012-acceptance-boundary-v1.json` | P5A-R 0012 boundary review | Machine-readable accepted/blocked claim set and production design blockers after validation/0186 |
| `sched-exec-lease-p5a-r2-selector-direction-v1.json` | P5A-R2 selector direction | Machine-readable candidate matrix for picker-visible lease eligibility, separate eligible timeline, lease bucket before CFS, bounded window, and explicit quarantine settlement |
