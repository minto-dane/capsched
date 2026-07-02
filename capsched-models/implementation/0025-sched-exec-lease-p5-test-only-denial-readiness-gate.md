# Implementation 0025: SchedExecLease P5 Test-Only Denial Readiness Gate

Status: Draft readiness gate; P5 implementation not approved

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
```

## Permitted Scope If Re-Approved

The first P5 patch may only be a test-only denial mode. It must be off by
default and must not claim production security.

Allowed in principle after re-approval:

```text
internal-only test state
explicit denial receipt
bounded retry epoch
candidate ineligibility for the retry epoch
fresh tuple requirement after retry
fail-closed path only when no eligible candidate exists
negative tests proving denial happens before rq->curr publication
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
full vmlinux off/on build plan updated
QEMU boot/workload smoke plan updated for denial mode
fork/exec/exit denial-lifetime tests designed
move/affinity/hotplug tests designed
sched_ext/core/proxy availability or exclusion recorded
claim ledger updated to forbid production protection claims
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
```

## Non-Claims

This gate is not P5 implementation approval, production enforcement,
monitor-backed protection, monitor implementation, monitor verification,
exploit containment, hypervisor-grade isolation, production protection,
cost-efficiency evidence, or datacenter deployment readiness.
