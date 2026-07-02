# Implementation 0025: SchedExecLease P5 Test-Only Denial Readiness Gate

Status: Draft readiness gate; P5 implementation not approved; out of current
scope under ADR-0011 until implementation-ready design blockers are closed

Date: 2026-07-02

## Purpose

P5 is the first possible SchedExecLease slice that may change scheduler
behavior by denying, retrying, quarantining, or failing closed for a selected
candidate. It is not approved by P1-P4.

This gate defines the minimum evidence required before any P5 Linux patch can
be proposed. Its job is to prevent an allow-all preparation hook from silently
becoming an unsafe runtime security boundary.

## Current Source Basis

```text
linux_branch=capsched-linux-l0
linux_commit=a0f2676adda634391983e74f29fcba577a9c919e
linux_subject=sched/exec_lease: Add task identity shadow
```

P5 is blocked until:

```text
P2 task lifecycle shadow validation is recorded
P3 scheduler touchpoint validation is recorded
P4 allow-all revalidation skeleton validation is recorded
analysis/0100 final run/move tuple gate is refreshed against current source
analysis/0101 final deny/retry/ineligibility gate is refreshed against current source
analysis/0113 implementation-ready blockers are closed or explicitly scoped
analysis/0114 sched_ext/core/proxy coverage decisions are closed
analysis/0115 bounded retry/ineligibility source design is reflected in the
  refreshed model and validation plan
analysis/0116 negative denial validation plan is reflected in the future P5
  test harness design
analysis/0117 scheduler path classification is reflected in the future P5
  support, disable, and exclusion checks
analysis/0118 implementation claim ledger gate is reflected in the future P5
  proposal row and non-claim list
analysis/0119 implementation-reopen upstream drift gate is reflected in the
  future P5 touched-group freshness and drift row
```

## Permitted Scope If Re-Approved

The first P5 patch may only be a test-only denial mode. It must be off by
default and must not claim production security.

The initial support set is limited to:

```text
ordinary CFS final run in a non-core, non-proxy, non-sched_ext configuration
common queued move through move_queued_task() / move_queued_task_locked()
```

Allowed in principle after re-approval:

```text
internal-only test state
explicit denial receipt
bounded retry epoch
candidate ineligibility for the retry epoch
fresh tuple requirement after retry
fail-closed path only when no eligible candidate exists
negative tests proving denial happens before class settlement, or after a
  source-proved rollback, and always before rq->curr publication
```

Forbidden even in P5:

```text
user ABI
public tracepoint ABI
monitor ABI
production protection claim
hypervisor-grade claim
silent fallback to ordinary Linux scheduling after denial
unbounded retry
denying after rq->curr publication
denying after put_prev_set_next_task() or equivalent class settlement without a
rollback proof
running a denied candidate
using RETRY_TASK, idle fallback, sched_ext fallback, class state, or core cached
pick as SchedExecLease authority
```

## Mandatory Design Decisions Before P5

### Denial Subject

P5 must define exactly what is denied:

```text
final run of a selected ordinary Domain task
queued move of an ordinary Domain task
or both
```

Run denial and move denial are not interchangeable and must use different
tuples.

### Eligibility and Retry

P5 must define:

```text
retry epoch owner
candidate ineligibility representation
retry budget
progress condition
fail-closed condition
class-state neutralization
balance-callback handling
pre-settle validation shape or post-settle rollback proof
class picker ineligibility visibility
```

The same denied candidate must not be selected again in the same retry epoch.

### Scheduler Class Coverage

P5 must decide whether it covers or blocks:

```text
CFS
RT
deadline
idle
sched_ext
core scheduling
proxy execution
stopper/hotplug/migration kernel threads
```

Any uncovered class or path must be explicitly excluded from runtime coverage
claims.

For the initial P5 test-only denial mode, analysis/0117 classifies:

```text
disabled:
  sched_ext
  core scheduling
  proxy execution

excluded:
  fair direct load balance
  RT
  deadline
  idle exception
  stopper/hotplug/migration kernel threads
  generic kthreads/workqueues
  io_uring workers
```

Any future patch that touches these paths must first update the classification,
formal gate, validation plan, and claim ledger.

### sched_ext

P5 must make a concrete decision:

```text
disable sched_ext when test denial is enabled
or support sched_ext consume/fallback/bypass paths with tests
or mark sched_ext uncovered and make protection claims impossible
```

Because sched_ext can fall back to the normal scheduler, fallback must never be
treated as security-policy preservation.

### Core Scheduling and Proxy Execution

P5 must define:

```text
core cached-pick invalidation or revalidation
core sibling tuple freshness
proxy donor/current/executor authority relation
budget charge subject
what happens when donor and current differ
```

The budget subject cannot be guessed from `rq->curr` alone.

### Kernel Threads and Workqueues

P5 must define:

```text
root/internal kernel thread exception class
service-domain worker class
caller-derived async work exclusion
workqueue/io_uring provenance gap handling
```

P5 must not accidentally treat kworker identity as caller authority.

## Required Validation Before P5 Patch Review

Before even reviewing a P5 patch:

```text
P2/P3/P4 validation complete
TLC or equivalent model refreshed for final denial retry/ineligibility
negative denial tests designed
analysis/0116 negative-denial obligations mapped to concrete tests or explicit
  unsupported notes
analysis/0117 scheduler-path classification reflected in setup-time disables,
  unsupported notes, and negative tests
full vmlinux off/on build plan updated
QEMU boot/workload smoke plan updated for denial mode
fork/exec/exit denial-lifetime tests designed
move/affinity/hotplug tests designed
sched_ext/core/proxy availability or exclusion recorded
post-settle denial rollback model or explicit pre-settle-only decision recorded
claim ledger updated to forbid production protection claims
machine-readable claim ledger row present for the proposal
fresh implementation-reopen drift row present for the proposal
```

Before accepting a P5 patch:

```text
git diff --check
patch queue replay
CONFIG_SCHED_EXEC_LEASE=n full vmlinux build
CONFIG_SCHED_EXEC_LEASE=y full vmlinux build with denial disabled
test-only denial config build
QEMU boot/workload smoke with denial disabled
QEMU negative denial tests with denial enabled
trace/kprobe evidence that denied candidates do not reach rq->curr/context_switch
bounded retry evidence
fail-closed evidence or explicit unavailable note
no overclaim review
claim ledger row matches observed evidence classes and leaves unsupported
  claims false
implementation-reopen drift row matches touched groups and current upstream
```

## Non-Claims

This gate is not P5 implementation approval, production enforcement,
monitor-backed protection, monitor implementation, monitor verification,
exploit containment, hypervisor-grade isolation, production protection,
cost-efficiency evidence, or datacenter deployment readiness.
