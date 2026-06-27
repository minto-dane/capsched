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
| 0014 | Checked with safe pass and expected unsafe counterexamples | F1 Admission Data Model |

## Planned

1. Block/wait/register authority preparation model for wake_q and generic wake
   readiness.
2. Placement-refresh model for affinity, cpuset, and CPU hotplug interactions.
3. Wider endpoint capability model for fd/file/socket/resource operations.
4. Same-Domain monitor fast-path freshness and selected-state stale budget
   decompositions.
5. Driver-specific QueueLease endpoint models for NIC, NVMe, GPU, or VFIO
   compatibility paths before L4 implementation work.
