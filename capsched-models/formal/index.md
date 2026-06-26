# Formal Models Index

Updated: 2026-06-26

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

## Planned

1. Epoch/generation revocation model across runqueues and CPUs, if the first
   Runnable Lease model is too strict or too eager.
2. Wider endpoint capability model for fd/file/socket/resource operations.
3. Direct-map visibility, TLB shootdown, or page-cache overlay conflict model
   before L2 MM work.
4. QueueLease model for IOMMU mappings, queue ownership, interrupt routes,
   epochs, and rate budgets before L4 device work.
