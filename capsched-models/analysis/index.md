# Analysis Index

Updated: 2026-06-27

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

## Planned Analysis Notes

1. BPF verifier/JIT TCB sub-map if BPF becomes a policy front-end.
2. Broker BudgetTicket and service Domain charging map.
3. Model workqueue/kthread_work caller BudgetTicket carrier semantics.
4. Model shared futex cross-Domain endpoint semantics.
5. Model PI/RT/ww_mutex priority donation separately from RunCap.
6. Model placement-refresh interaction with affinity, cpuset, and CPU hotplug
   so `p->cpus_ptr` cannot exceed FrozenRunUse authority.
7. Decide exec process-generation semantics jointly with endpoint/object
   capability modeling.
8. Refine same-Domain monitor fast-path freshness, selected-state stale budget,
   and class-specific CFS/RT/deadline/sched_ext/core/proxy behavior.
9. Slice 0C trace-only observation patch map only if schema/modeling requires it.

## Behavior Tag Artifacts

| Path | Status | Purpose |
| --- | --- | --- |
| `behavior-tags/slice0c-scheduler-behavior-tags.json` | Draft v1, not solver-eligible | Exploratory Slice 0C behavior tag ledger |
| `behavior-tags/schema-v2-requirements.json` | Requirements only | Mandatory fields and hard reject rules for schema v2 |
| `behavior-tags/schema-v2.json` | Draft contract | Machine-readable schema v2 contract for gap analysis and hard reject |
| `behavior-tags/slice0c-scheduler-behavior-tags-v2.json` | Draft v2, gap-analysis only | Slice 0C behavior paths retagged under schema v2 |
