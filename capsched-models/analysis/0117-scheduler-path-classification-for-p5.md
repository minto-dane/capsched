# Analysis 0117: Scheduler Path Classification for P5

Status: Design-only path classification; no implementation approved

Date: 2026-07-02

## Purpose

Close the design part of the P5 scheduler path classification blocker from
analysis/0113.

The classification is not a protection claim. It exists to prevent the first
test-only denial slice from accidentally implying that all Linux scheduler
paths are covered.

## Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

Related evidence:

```text
analysis/0114 sched_ext/core/proxy coverage boundary
analysis/0115 bounded retry and ineligibility source design
formal/0088 final deny source shape model
validation/0135 final deny source shape TLC
analysis/0116 negative denial validation plan
```

## Classification Vocabulary

```text
supported:
  The future P5 design may implement test-only denial for this path, but only
  with required negative tests and no production claim.

disabled:
  Test-only denial mode must refuse, disable, or fail setup for this path.
  The path is not covered and cannot support runtime/protection claims.

excluded:
  The path is outside first-P5 denial scope. It may still be valid Linux
  behavior, but no runtime coverage claim may include it.

future-support-required:
  The path must eventually be designed and validated before broad scheduler or
  production claims are possible.
```

## Initial P5 Classification

| Path | Initial P5 Classification | Reason | Required Before Support |
| --- | --- | --- | --- |
| Ordinary CFS final run, non-core, non-proxy, non-sched_ext | supported | Smallest ordinary Domain run path where pre-settle denial can be designed without class rollback | Pre-settle validation, class-picker ineligibility, same-candidate negative test |
| Common queued move through `move_queued_task()` / `move_queued_task_locked()` | supported | Source has visible pre-detach/pre-CPU-mutation edge | Move tuple, destination validation, denied-move negative test |
| Fair direct load-balance detach/attach paths | excluded | Not covered by common move helper guarantee | Dedicated fair load-balance move model and tests |
| RT final run and RT push/pull | excluded | Priority, pushable state, PI interactions, and class settlement need dedicated proof | RT class-state and priority donation denial model |
| Deadline final run, CBS/GRUB, DL server, push/pull | excluded | Server lending and deadline runtime state cannot inherit CFS assumptions | DL server/GRUB denial model and tests |
| sched_ext | disabled for initial P5 test denial | DSQ custody, bypass/global/local/direct dispatch, server pick, and BPF fallback are not authority | DSQ consume/pick/direct/bypass/server negative tests |
| Core scheduling | disabled for initial P5 test denial | Sibling cached picks and cookie steal can bypass local ineligibility | core_pick invalidation/revalidation and cookie-steal tests |
| Proxy execution | disabled for initial P5 test denial | Donor/executor split and blocked_donor handoff need separate subject rules | donor/executor tuple and budget-subject tests |
| Idle | excluded as Linux exception | Idle can be fail-closed result, not authority for ordinary Domain execution | fail-closed evidence only |
| Stopper/hotplug/migration kernel threads | excluded as Linux exception | Infrastructure liveness, not ordinary Domain execution | exception ledger and non-ordinary classification |
| Generic kthreads and workqueues | excluded | kworker identity is not caller authority | typed async carrier integration and negative tests |
| io_uring workers | excluded | request/resource provenance is outside P5 scheduler-only denial | io_uring carrier integration and negative tests |

## Claim Scope

The initial P5 support set is:

```text
ordinary CFS final run in a non-core, non-proxy, non-sched_ext configuration
common queued move through shared move helpers
```

This support set allows only:

```text
test-only denial experiment
off-by-default behavior-changing patch after explicit scope reopening
negative evidence for the supported paths
```

It does not allow:

```text
runtime coverage claim for all scheduler paths
production protection claim
hypervisor-grade claim
cost-efficiency claim
claim that sched_ext/core/proxy/RT/DL/workqueue/io_uring are protected
```

## Why This Is Not Weakening

The classification deliberately separates:

```text
first test-only denial slice:
  narrow enough to be testable and fail closed without pretending broad
  coverage.

final DomainLease scheduler:
  must eventually cover or consciously prohibit RT, DL, sched_ext, core,
  proxy, async, and service-domain paths before broad claims.
```

This is not a reduction of the final goal. It is a claim-scope control that
prevents an unsafe broad assertion from a narrow test implementation.

## Future Full-Support Requirements

Before any broad runtime coverage claim, these must move from disabled/excluded
to supported with evidence:

```text
RT push/pull and priority donation
deadline server/CBS/GRUB
sched_ext DSQ/direct/bypass/server paths
core scheduling cached-pick and cookie-steal paths
proxy donor/executor/current split
typed workqueue and io_uring async carriers
hotplug/stopper exception ledger
```

## Implementation-Ready Consequence

P5 implementation scope must carry this classification table. A patch that
touches an excluded or disabled path without first updating the classification,
model, and validation plan is not reviewable.

## Non-Claims

This note does not approve Linux code, scheduler hooks, test instrumentation,
runtime denial, runtime coverage, class support, sched_ext support, core
scheduling support, proxy support, public ABI, monitor ABI, monitor
verification, production protection, or cost-efficiency claims.
