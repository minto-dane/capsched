# SchedExecLease P5A-R6 E1 Domain-Forest Evidence Plan

Date: 2026-07-25

## Decision

The source-free R6-E1 evidence plan passes. It authorizes only a disposable,
default-off R6-E2 layout candidate that changes exactly `init/Kconfig` and
`kernel/sched/exec_lease.c` and adds no behavior.

It does not authorize the selector, scheduler or cgroup hooks, task binding,
migration behavior, runtime denial, primary-Linux or patch-queue promotion,
E3 correctness work, timing work, or production use.

## Exact Input

The gate revalidates R6 architecture result SHA-256
`82f9c5dd5f6793934e18ded895501a363527df144a3874a427437cef1ffe0bd6`.
R6 retains the immutable sealed authority descriptor selected by
validation/0275 and keeps all EEVDF scheduling state mutable under the owning
rq lock.

The primary remains Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`. The tracked tree is clean.

## Linux Hierarchy Resolution

One `sched_entity` has one parent, owning `cfs_rq`, and optional owned
`my_q`. R6 therefore cannot add a second orthogonal domain hierarchy to an
arbitrary cgroup tree.

The accepted composition is:

```text
root fair rq
  fixed R6 selector
    one sealed domain per dedicated root-child FAIR_GROUP_SCHED subtree
      ordinary descendant cgroups confined to that domain
        ordinary CFS tasks with the same task-local sealed slot binding
```

The cgroup/task-group object is only a mechanism. It is never authority.
Mixed-domain subtrees, one domain spread across multiple root subtrees,
ordinary leased root tasks, authority-changing cgroup moves, and
`SCHED_AUTOGROUP` fail closed. Group placement cannot replace the final
task-local generation/domain/slot check.

This plan covers ordinary CFS only. Non-fair classes, idle/stop/per-CPU
workers, sched_ext, core/proxy/deadline-server paths, and monitor delivery
remain unaccepted integration or exclusion obligations.

## Exact Selector and Fairness Bounds

The per-rq top selector has 64 leaves and 127 unique nodes. One leaf change
updates at most six ancestors. An exact pick has two independent phases:

```text
allowed-domain aggregate phase       <= 127 node visits
eligible earliest-deadline phase     <= 127 node visits
complete top query                   <= 254 node visits
descriptor mask reconciliation       <=  64 slot visits
one leaf-update ancestor walk        <=   6 visits
```

This is fixed `O(B_max)` work independent of task count. It is neither a
127-operation complete query nor an `O(log 64)` arbitrary-mask claim.

R6 implements equal fixed `NICE_0_LOAD` fairness among allowed runnable
domains, followed by ordinary hierarchical CFS fairness inside a domain.
Re-enabled/newly-runnable domains receive zero negative lag at the current
allowed-domain virtual time. Unauthorized time creates no catch-up credit.
The plan explicitly makes no flat-CFS equivalence claim.

## Finite Layout Boundary

R6-E2 may measure only private candidate types under these conservative
architecture-local envelopes:

```text
64 slot states at <= 1,024 bytes       65,536 bytes
127 top nodes at <= 64 bytes            8,128 bytes
one rq control at <= 1,024 bytes        1,024 bytes
computed private total                 74,688 bytes/rq
hard admission limit                   98,304 bytes/rq
maximum private alignment                  64 bytes
```

Ordinary `sched_entity`, `cfs_rq`, `rq`, and `task_struct` growth is exactly
zero. Slot 65, allocation failure, descriptor overflow, or envelope breach is
`Blocked`; there is no eviction, merge, alias, or ordinary-root fallback.

The future config is `CONFIG_SCHED_EXEC_LEASE_R6_LAYOUT_PROBE`, default `n`,
and requires `SCHED_EXEC_LEASE`, the existing layout probe, debug kernel,
SMP, cgroup/fair-group scheduling, and disabled autogroup. E2 may add private
types and object-local layout symbols only. It may add no constructor,
callsite, hook, callback, CPUHP state, allocation, static key, export,
tracepoint, ABI, monitor/policy call, or behavior.

Arm64 and x86_64 must each use an architecture-local clean-primary baseline,
preserve all 51 existing expanded-probe values, show no config-off private
symbols/relocations/strings, and preserve zero ordinary hot-object growth.

## Ordering and Lifetime

The plan freezes:

- task-local descriptor/domain/slot and domain-root checks before enqueue;
- remove-neutral-add migration with no simultaneous rq contribution;
- complete destination revalidation, with failure remaining `Blocked`;
- separate picker exclusion and current-task stop observation;
- rq-offline visibility/admission removal before sleepable draining;
- online allocation/initialization/publication before accepting;
- zero contributions/readers/refs before RCU grace and free; and
- generation saturation with no trusted wrap or reuse.

`resched_curr()` is a scheduler request, not a monitor interrupt or completion
receipt.

## Formal and Focused Validation

Canonical run `20260725T-p5a-r6-e1-domain-forest-plan-r1` produces result
SHA-256
`364c1c21b0bcb33ccda1e7dd95eb99542cf3dd4f40fcc754aee9c93b89211f62`.

The immutable evidence contains 325 files in 476 KiB. All 40 current Linux
anchors pass and all eight future R6 source patterns remain absent.

The safe TLC trace passes:

```text
states generated:       10
distinct states:        10
search depth:           10
liveness properties:     2
```

The trace mutates a selector leaf, performs both bounded query phases,
migrates through a contribution-neutral state, publishes revocation,
separately observes current stop, removes CPU visibility, drains references,
waits for RCU, and frees state.

All 50 declared safety faults produce expected invariant counterexamples.
They cover prerequisite binding, immutable/live-state separation, exact
bounds, denied selection, hierarchy/authority, admission/storage, E2 scope,
enqueue/migration/fork/exec/current/hotplug/RCU ordering, later gates, and the
claim ledger. Two separate liveness faults reproduce missing allowed-domain
selection and missing revoked-current stop.

The focused suite accepts the exact contract and rejects ten mutations.
Bash syntax checks and VM ShellCheck pass.

## Next Gate

Only the exact disposable R6-E2 layout candidate may now be drafted. Before
any build credit, its source gate must prove:

1. direct-child identity and exactly two changed files;
2. default-off config and dependency closure;
3. type/layout-probe-only source with no behavior or callsites;
4. strict style and source/object absence checks;
5. fresh arm64 and x86_64 architecture-local off/on builds;
6. unchanged 51 existing values and zero ordinary hot-object growth; and
7. exact 74,688-byte computation below the 98,304-byte hard envelope.

R6-E3 remains blocked until an independent dual-architecture E2 closure.
R6-E4 remains blocked until a separate E3 correctness/diagnostic closure.

## Claim Boundary

No R6 layout source is accepted yet. No real scheduler or cgroup attachment,
runtime denial, monitor verification, N-136 runtime charge, flat-CFS
equivalence, cross-class coverage, bare-metal validation, performance, cost,
production protection, deployment, multi-node, multi-cluster, or datacenter
readiness is claimed.
