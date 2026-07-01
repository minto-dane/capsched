# Analysis Index

Updated: 2026-07-01

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
| 0025 | Draft state machine | Linux Scheduler Authority State Machine |
| 0026 | Draft obligation matrix | Scheduler Hook Proof Obligation Matrix |
| 0027 | Draft schema and v2 retagging complete for gap analysis | Schema v2 Derived from the Scheduler Authority Model |
| 0028 | Draft source map | Tick and Runtime Budget Source Map |
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
