# Analysis 0110: Terminology Freeze and Rename Risk Review

Status: Public vocabulary locked; legacy aliases retained for traceability

Date: 2026-07-02

## Purpose

N-156 prevents a late public rename from splitting the project into two
incompatible vocabularies after publication.

The model-only goal is complete under the private historical name
`CapSched-Linux`. Before paper, RFC, or mainline-facing work, the public names
are frozen as:

```text
Umbrella project:
  DomainLease-Linux

Scheduler core:
  SchedExecLease

Linux scaffold:
  sched_exec_lease
```

The old names are retained as legacy aliases for historical artifacts. They are
not the forward public names.

## Rename Risk

A full mechanical rewrite of every historical artifact is unsafe because it
would disturb:

```text
N-series chronology
TLA module names
validation records
claim/evidence/counterexample references
Git history
Linux patch queue replay
old model logs
AI handoff continuity
```

The safe rule is:

```text
Rename public and forward-facing surfaces.
Preserve historical artifact identity.
Connect old and new vocabulary through an explicit alias appendix.
```

## Mechanical Inventory

The N-156 inventory counted old vocabulary across docs, JSON, TLA, cfg files,
AI state, assurance claims, Linux scaffold, and file names.

| Area | CapSched | CAPSCHED | capsched | RunCap | FrozenRunUse | SchedContext | DomainTag | HyperTag |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Markdown docs | 971 | 194 | 1459 | 247 | 226 | 237 | 122 | 153 |
| JSON/JSONL | 108 | 39 | 5880 | 54 | 37 | 32 | 19 | 27 |
| TLA modules | 5 | 0 | 27 | 137 | 51 | 9 | 0 | 0 |
| TLC cfg files | 4 | 0 | 0 | 19 | 2 | 4 | 0 | 0 |
| AI state/memory | 106 | 42 | 5987 | 61 | 46 | 48 | 25 | 40 |
| Assurance subset | 37 | 5 | 129 | 17 | 19 | 10 | 1 | 21 |
| Linux scaffold | 4 | 8 | 28 | 3 | 1 | 1 | 1 | 0 |
| File names | 2 | 2 | 2 | 5 | 2 | 2 | 0 | 29 |

This inventory proves that an unrestricted rename would be a semantic migration,
not a cosmetic cleanup.

## Public Vocabulary Lock

| Legacy term | Public/research term | Linux-facing term | Policy |
| --- | --- | --- | --- |
| CapSched-Linux | DomainLease-Linux | no direct symbol | New public umbrella name |
| CapSched-H | DomainLease-H | no direct symbol | New monitor-backed architecture name |
| scheduler capability model | SchedExecLease model | `sched_exec_lease` | Scheduler execution authority slice |
| `CONFIG_CAPSCHED` | SchedExecLease scaffold | `CONFIG_SCHED_EXEC_LEASE` | Linux no-behavior scaffold |
| `capsched_*` | DomainLease/SchedExecLease object | `sched_exec_*` or `sched_*` | No new Linux symbol may use `capsched_*` |
| RunCap | ExecutionGrant | `sched_exec_grant` | Execution submission grant |
| FrozenRunUse | ExecutionLease | `sched_exec_lease` | Frozen, bounded run-use record |
| SchedContext | CPU Budget Context | `sched_budget_ctx` | CPU-time budget and placement object |
| Domain | Lease Domain / Isolation Domain | `sched_exec_domain` when scheduler-local | Avoid collision with Linux `sched_domain` |
| DomainTag | Domain Activation | `domain_activation` | Active domain context, not authority alone |
| HyperTag Monitor | Domain Monitor | `domain_monitor`, `monitor_root` | Use mechanical names in kernel-facing text |
| RunToken | Sealed Execution Token | `sealed_exec_token` | Monitor-minted execution token |
| EndpointCap | EndpointGrant | no scheduler symbol | Endpoint authority remains non-scheduler |
| QueueLease | QueueLease | `queue_lease` | Keep: concrete and not Linux-capability-like |

## Claim ID Policy

Claim IDs remain unchanged:

```text
ACT-001
EXEC-001
BUDGET-001
ENDP-001
ASYNC-001
MEM-001
TLB-001
PCACHE-001
DEV-001
REVOKE-001
CLUSTER-001
COMPAT-001
TCB-001
SIDE-001
EVAL-001
TOP-001
```

These IDs are semantic anchors. Renaming them would damage traceability and
make old validation records harder to audit.

## Model and Documentation Policy

New documents, paper drafts, RFCs, and implementation plans must use the locked
public vocabulary. Historical documents may keep legacy names when they are
part of an old evidence record.

Allowed:

```text
DomainLease-Linux, formerly CapSched-Linux during private modeling.
ExecutionGrant, legacy RunCap.
ExecutionLease, legacy FrozenRunUse.
Domain Monitor, legacy HyperTag Monitor.
```

Forbidden in new public-facing text:

```text
Using CapSched as the primary project name.
Using RunCap or EndpointCap as Linux code symbols.
Using Domain without a qualifier in Linux scheduler text.
Using HyperTag Monitor as the kernel-facing monitor name.
Claiming that a rename changes security semantics.
```

## Linux Scaffold Rename

The Linux scaffold must be renamed as a no-behavior patch:

```text
CONFIG_CAPSCHED -> CONFIG_SCHED_EXEC_LEASE
include/linux/capsched.h -> include/linux/sched_exec_lease.h
kernel/sched/capsched.c -> kernel/sched/exec_lease.c
capsched_enabled() -> sched_exec_lease_enabled()
```

The scaffold remains inert:

```text
no scheduler hook
no task_struct field
no user ABI
no public tracepoint ABI
no monitor ABI
no runtime denial
no production protection claim
```

## Result

N-156 freezes the public vocabulary before publication and converts the Linux
scaffold to the mainline-facing execution-lease name. Historical artifacts keep
legacy names through an explicit alias policy.

Linux scaffold rename validation is recorded in:

```text
validation/0128-sched-exec-lease-rename-build-validation.md
```

It passed targeted scheduler-subtree build validation for both disabled and
enabled Kconfig states:

```text
SCHED_EXEC_LEASE = undef -> no exec_lease.o
SCHED_EXEC_LEASE = y     -> kernel/sched/exec_lease.o built
```

This is a terminology and no-behavior scaffold migration only. It is not model
revalidation, Linux enforcement, monitor implementation, runtime coverage, or
production protection.
