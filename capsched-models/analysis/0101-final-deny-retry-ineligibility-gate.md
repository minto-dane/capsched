# Analysis 0101: Final Deny Retry and Ineligibility Gate

Status: Draft model gate with TLC-backed design filter; no implementation
approved

Date: 2026-07-01

## Purpose

N-146 requires final ordinary Domain run commitment and queued-task movement to
consume a fresh validation tuple. N-147 answers the next semantic question:

```text
What happens if the final run validation denies the selected task?
```

The answer cannot be "just return failure" after the scheduler has already
settled class state. The answer also cannot be "retry the same candidate"
without changing its eligibility. That would either run a denied task,
livelock, or corrupt scheduler class state.

The required shape is:

```text
final validation denies candidate
  -> denial is recorded before rq->curr publication
  -> denied candidate becomes ineligible for this retry epoch
  -> scheduler class state and balance callbacks are neutralized
  -> pick is retried with progress
  -> either a fresh tuple for a different eligible candidate commits
     or the CPU fails closed because no eligible candidate remains
```

This remains a model gate only. It does not approve a Linux hook.

## Source Basis

Current Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
work commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
upstream ref: 665159e246749578d4e4bfe106ee3b74edcdab18
```

Current CapSched Linux code remains inert:

```text
include/linux/capsched.h
kernel/sched/capsched.c
```

No scheduler behavior has changed.

## Linux Source Anchors

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| final schedule loop | `kernel/sched/core.c:7061 __schedule()` | final run decision region |
| internal retry label | `kernel/sched/core.c:7147 pick_again` | existing retry concept, but not CapSched authority |
| next-task pick | `kernel/sched/core.c:7149 pick_next_task()` | candidate selection before CapSched final validation |
| proxy retry to pick_again | `kernel/sched/core.c:7160` | existing retry after proxy task discovery fails |
| picked label | `kernel/sched/core.c:7188 picked` | conceptual last common point before rq current publication |
| need-resched clear | `kernel/sched/core.c:7189 clear_tsk_need_resched()` | cannot clear and continue silently after a CapSched deny |
| rq current publication | `kernel/sched/core.c:7201 RCU_INIT_POINTER(rq->curr, next)` | deny after this point is too late |
| context switch | `kernel/sched/core.c:7234 context_switch()` | denied task must not reach switch |
| fast fair retry | `kernel/sched/core.c:6145 RETRY_TASK` | class retry concept exists before final run commit |
| active class retry | `kernel/sched/core.c:6161 RETRY_TASK` | retry is part of pick semantics, not authority |
| core retry single | `kernel/sched/core.c:6306 RETRY_TASK` | core scheduling may retry on same task set |
| core retry multi | `kernel/sched/core.c:6341 RETRY_TASK` | core scheduling cached picks require progress protection |
| core set-next | `kernel/sched/core.c:6448 put_prev_set_next_task()` | class state may already be settled for selected task |
| put/set helper | `kernel/sched/sched.h:2758 put_prev_set_next_task()` | class state transition helper |
| proxy resched idle | `kernel/sched/core.c:6747 proxy_resched_idle()` | existing pattern for clearing donor/current references |
| proxy balance callback zap | `kernel/sched/core.c:6786` | callbacks must be cleared before lock release and retry |
| proxy migrate reference drop | `kernel/sched/core.c:6827` | rq references must be neutralized before migration/retry |
| proxy chain changed retry | `kernel/sched/core.c:6906` | existing pick_again on stale proxy relation |
| core cookie steal | `kernel/sched/core.c:6455 try_steal_cookie()` | selected/moved state remains non-authority |
| sched_ext pick | `kernel/sched/ext/ext.c:3147 pick_task_scx()` | BPF scheduler selection is not authority |
| sched_ext retry | `kernel/sched/ext/ext.c:3184 RETRY_TASK` | sched_ext retry signal is not CapSched authority |

## Required Semantics

For an ordinary Domain final run denial:

```text
deny occurs before rq->curr publication
deny is recorded as a CapSched denial receipt
denied candidate is made ineligible for the retry epoch
class state is neutralized before retry or fail-closed
balance callbacks are cleared before lock release or retry
retry count advances and is bounded
the same denied candidate cannot be selected again in the same retry epoch
```

The retry edge must either:

```text
commit a different candidate with a fresh validation tuple
```

or:

```text
fail closed because no eligible candidate remains
```

Fail-closed is not allowed while another eligible ordinary Domain candidate is
available.

## Rejected Designs

The model rejects:

```text
running a denied candidate
retrying the same denied candidate without ineligibility
denying after rq->curr publication
denying without marking ineligible
retrying without progress
failing closed while an eligible candidate exists
running another candidate without a fresh tuple after retry
silently dropping a candidate without retry or fail-closed
ignoring retry budget
using scheduler class state as CapSched authority
using RETRY_TASK as CapSched authority
using idle fallback as CapSched authority
using sched_ext fallback as CapSched authority
using core cached pick as CapSched authority
behavior, monitor-verification, or protection overclaims
```

## Model

New model:

```text
formal/0079-final-deny-retry-ineligibility-gate-model/
```

Checked invariants:

```text
NoDeniedCandidateRuns
NoRunWithoutFreshTuple
NoRetryWithoutIneligibility
NoRetrySameDeniedCandidate
NoDenyAfterRqCurrCommit
NoRetryWithoutProgress
NoFailClosedWithEligibleCandidate
NoSilentDropWithoutRetryOrFailClosed
NoAuthoritySubstitution
NoNonClaimOverreach
```

## Non-Claims

This gate does not approve a Linux hook, retry implementation, task field,
task dequeue semantics, class-state rollback mechanism, public ABI, monitor ABI,
runtime coverage, behavior change, monitor verification, or production
protection.

It supports only this claim shape:

```text
Any future final run hook must make denial explicit, progress-making, bounded,
and fail-closed without treating Linux retry machinery as authority.
```
