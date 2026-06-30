# Analysis Index

Updated: 2026-06-29

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

## Planned Analysis Notes

1. BPF verifier/JIT TCB sub-map if BPF becomes a policy front-end.
2. Broker BudgetTicket and service Domain charging map.
3. Modern NIC queue revoke/drain/quarantine source map against formal/0031.
4. Workqueue origin QEMU stack-trace observation runner.
5. Slice 0C trace-only observation patch map only if schema/modeling requires it.
6. Queue/descriptor trace-only patch map only if readiness gaps require it.

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
