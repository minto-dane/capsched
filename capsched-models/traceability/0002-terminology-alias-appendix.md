# Terminology Alias Appendix

Status: Accepted alias policy for N-156 and later work

Date: 2026-07-02

## Purpose

This appendix maps the private modeling vocabulary to the public vocabulary
locked in N-156. It exists so old evidence remains readable without forcing a
dangerous rewrite of historical artifacts.

## Alias Rules

1. New public-facing documents use the public term.
2. Historical artifacts may keep the legacy term.
3. A new document may mention the legacy term only as an alias.
4. Claim IDs, evidence IDs, counterexample IDs, and old TLA module names remain
   stable.
5. Linux code symbols use Linux-facing terms, not legacy terms.

## Mapping

| Legacy term | Public term | Linux-facing term | Notes |
| --- | --- | --- | --- |
| CapSched-Linux | DomainLease-Linux | none | Umbrella project name |
| CapSched-H | DomainLease-H | none | Monitor-backed architecture |
| Capability scheduler | SchedExecLease | `sched_exec_lease` | Scheduler execution authority slice |
| RunCap | ExecutionGrant | `sched_exec_grant` | Permission to submit a task for execution |
| FrozenRunUse | ExecutionLease | `sched_exec_lease` | Frozen, bounded use of execution authority |
| SchedContext | CPU Budget Context | `sched_budget_ctx` | CPU budget, period, placement, and co-tenancy context |
| Domain | Lease Domain / Isolation Domain | `sched_exec_domain` when scheduler-local | Must not be confused with Linux `sched_domain` |
| DomainTag | Domain Activation | `domain_activation` | Active domain context, not authority by itself |
| HyperTag Monitor | Domain Monitor | `domain_monitor`, `monitor_root` | Small monitor root for sealed state and transitions |
| RunToken | Sealed Execution Token | `sealed_exec_token` | Monitor-issued execution token |
| EndpointCap | EndpointGrant | none in scheduler | Endpoint authority remains resource-specific |
| QueueLease | QueueLease | `queue_lease` | Name retained |

## Non-Claims

This alias appendix is not a model change, validation result, implementation
approval, runtime coverage result, monitor verification, or production
protection claim.
