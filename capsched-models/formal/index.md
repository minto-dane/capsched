# Formal Models Index

Updated: 2026-06-27

## Current Formal Records

| ID | Status | Title |
| --- | --- | --- |
| 0001 | Draft | Model Selection |
| 0002 | Checked | Runnable Lease Model |
| 0003 | Checked | Endpoint Async Provenance Model |
| 0004 | Checked | Broker BudgetTicket Model |
| 0005 | Checked | Domain Monitor Activation Model |
| 0006 | Full stress run stopped before completion | Cluster Lease Compilation Model |
| 0007 | Checked | Cluster Authority Decomposition Model |
| 0008 | Checked via decomposed models | Memory Ownership Model |
| 0009 | Checked after counterexample-driven fix | Direct Map and TLB Revocation Model |
| 0010 | Checked after counterexample-driven fix | Page Cache Overlay Conflict Model |
| 0011 | Checked with two TLC runs | Queue Lease and IOMMU Boundary Model |
| 0012 | Checked for tiny finite model | Linux Scheduler Authority Model |
| 0013 | Checked with safe pass and expected unsafe counterexamples | Scheduler Admission Failure Model |

## Planned

1. F1 admission-freeze data dependency model for `p->pi_lock` constraints.
2. Wider endpoint capability model for fd/file/socket/resource operations.
3. Same-Domain monitor fast-path freshness and selected-state stale budget
   decompositions.
4. Driver-specific QueueLease endpoint models for NIC, NVMe, GPU, or VFIO
   compatibility paths before L4 implementation work.
