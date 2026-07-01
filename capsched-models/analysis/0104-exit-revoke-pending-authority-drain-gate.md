# Analysis 0104: Exit/Revoke Pending Authority Drain Gate

Status: Draft integration model gate with TLC-backed design filter; no
implementation approved

Date: 2026-07-01

## Purpose

N-150 closes a cross-cutting gap left intentionally open by the local models:

```text
exit/revoke completion is not valid while any old authority can still be
reached through scheduler state, async carriers, endpoints, monitor admission
carriers, device queues, budget tickets, server tickets, root timers, or
derived receipts.
```

The model is intentionally broader than a task exit model. It is a global
pending-authority drain predicate:

```text
embargo new old-epoch authority
  -> enumerate pending authority with complete keys
  -> drain/reject/quarantine/settle every known carrier family
  -> revoke derived receipts and shadows
  -> release refs/locks/tickets/root execution exactly once
  -> then, and only then, mark exit/revoke complete
```

Unknown carrier classes are fail-closed. Omitting a family from the inventory
does not mean it is drained.

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

No scheduler, async, endpoint, device, budget, or monitor behavior has changed.

## Linux Source Anchors

These anchors define cleanup surfaces and race boundaries. They do not create
CapSched authority by themselves.

| Surface | Current upstream anchor | CapSched meaning |
| --- | --- | --- |
| io_uring file cancel | `kernel/exit.c:944 io_uring_files_cancel()` | early exit cleanup before PF_EXITING, not drain proof |
| PF_EXITING set | `kernel/exit.c:946 exit_signals(tsk)` | Linux sentinel, not authority invalidation receipt |
| exit task work | `kernel/exit.c:1004 exit_task_work(tsk)` | callback execution point after mm/files/fs/ns teardown |
| tasks RCU start | `kernel/exit.c:1015 exit_tasks_rcu_start()` | RCU lifetime phase, not authority |
| exit RCU finish | `kernel/exit.c:1043 exit_rcu()` | RCU cleanup phase |
| final task death | `kernel/exit.c:1047 do_task_dead()` | scheduler terminal handoff |
| signal queue flush | `kernel/exit.c:303 flush_sigqueue()` | release cleanup, not CapSched settlement |
| final RCU put | `kernel/exit.c:234 put_task_struct_rcu_user()` | deferred free through RCU |
| scheduler on-rq model | `kernel/sched/core.c:580` | queued state is a carrier family |
| on_rq values | `kernel/sched/sched.h:98` | visibility state is not authority |
| enqueue task | `kernel/sched/core.c:2172 enqueue_task()` | queued runnable publication surface |
| activate task | `kernel/sched/core.c:2219 activate_task()` | runnable activation surface |
| sleep dequeue state | `kernel/sched/sched.h:3032` | on-rq clearing surface |
| wake_q add | `kernel/sched/core.c:1091 __wake_q_add()` | wake queue holds task ref, still not authority |
| wake_q flush | `kernel/sched/core.c:1156 wake_up_q()` | remote/local wake carrier consumption |
| TTWU pending receive | `kernel/sched/core.c:3891 sched_ttwu_pending()` | remote wakelist consumption |
| TTWU wakelist enqueue | `kernel/sched/core.c:3950 __ttwu_queue_wakelist()` | remote wake carrier publication |
| TTWU wakelist path | `kernel/sched/core.c:4056 ttwu_queue_wakelist()` | remote wake path selection |
| TTWU transition | `kernel/sched/core.c:4251 try_to_wake_up()` | TASK_WAKING/RUNNING transition surface |
| final scheduler cleanup | `kernel/sched/core.c:5318 __schedule()` | TASK_DEAD handling and class cleanup |
| task dead state | `kernel/sched/core.c:7244 do_task_dead()` | terminal scheduler state |
| task_work add | `kernel/task_work.c:59 task_work_add()` | add failure is not callback completion |
| task_work cancel | `kernel/task_work.c:115 task_work_cancel_match()` | cancel race serialization |
| task_work run | `kernel/task_work.c:200 task_work_run()` | callback execution and work_exited marking |
| exit task_work helper | `include/linux/task_work.h:38 exit_task_work()` | wrapper around task_work_run |
| workqueue pending steal | `kernel/workqueue.c:2063 try_to_grab_pending()` | pending ownership transition |
| workqueue queue reject | `kernel/workqueue.c:2300 __queue_work()` | destroy/drain state is not monitor receipt |
| work pending clear | `kernel/workqueue.c:3220 process_one_work()` | pending-bit clear precedes callback |
| workqueue drain | `kernel/workqueue.c:4218 drain_workqueue()` | Linux drain primitive, not CapSched receipt |
| work cancel/flush | `kernel/workqueue.c:4382 __cancel_work_sync()` | synchronization primitive, not revoke proof |
| delayed-work caveat | `kernel/workqueue.c:6035 destroy_workqueue()` | timer-side delayed work is separate carrier |
| io_uring wrappers | `include/linux/io_uring.h:17` | exit/exec cleanup hooks |
| io_uring cancel loop | `io_uring/cancel.c:582 io_uring_cancel_generic()` | cancel loop, not authority settlement |
| tctx cleanup | `io_uring/tctx.c:238 io_uring_clean_tctx()` | io-wq exit path |
| io-wq exit | `io_uring/io-wq.c:1316 io_wq_exit_start()` | worker cleanup and cancel state |
| io_uring task_work fallback | `io_uring/tw.c:46` | fallback can enter system workqueue |
| io_uring fallback queue | `io_uring/tw.c:227` | fallback worker publication |
| timer delete/shutdown | `kernel/time/timer.c:1390` | timer callback carrier deletion surface |
| timer sync rules | `kernel/time/timer.c:1633` | sync ordering is not authority proof |
| call_rcu | `kernel/rcu/tree.c:3130 call_rcu()` | RCU callback enqueue |
| RCU callback invoke | `kernel/rcu/tree.c:2568 rcu_do_batch()` | callback execution surface |
| rcu_barrier | `kernel/rcu/tree.c:3834 rcu_barrier()` | covers ordered callbacks only |
| softirq loop | `kernel/softirq.c:586 __do_softirq()` | pending action consumption |
| softirq raise | `kernel/softirq.c:799 raise_softirq()` | softirq carrier publication |

## Existing Model Inputs

This gate composes earlier local models:

```text
formal/0016-task-local-run-state-model/
formal/0017-workqueue-carrier-model/
formal/0024-wider-endpoint-capability-model/
formal/0025-exec-generation-inheritance-model/
formal/0026-post-exec-resource-inheritance-model/
formal/0031-modern-nic-queue-revoke-model/
formal/0050-combined-admission-carriers-model/
formal/0058-direct-call-async-carrier-model/
formal/0060-direct-call-workqueue-adapter-refinement-model/
formal/0061-direct-call-io-uring-adapter-refinement-model/
formal/0071-monitor-root-budget-timer-model/
formal/0078-final-run-move-revalidation-hook-placement-gate-model/
formal/0079-final-deny-retry-ineligibility-gate-model/
formal/0080-task-frozen-run-lifetime-locking-gate-model/
formal/0081-lifecycle-identity-propagation-integration-gate-model/
```

The earlier models are still the detailed component evidence. N-150 adds the
integration completion rule: no old carrier family may remain pending merely
because some other family was drained.

## Required Inventory Key

A future implementation-facing inventory must be keyed by at least:

```text
task generation
process generation
domain id
domain epoch
carrier kind
authority kind
lease id
lease epoch
revoke epoch
budget ticket id
server ticket id
root timer / RunToken id
receipt id
settlement state
```

This is an integration rule, not a struct layout approval.

## Required Semantics

Exit/revoke start:

```text
new old-epoch authority is embargoed
all known pending-authority carrier families are enumerated
the inventory key set must be complete for the claim being made
```

Scheduler drain:

```text
queued, selected, denied, move, wake_q, and remote wake entries cannot consume
old authority after drain start.
```

Async drain:

```text
task_work, workqueue/kthread/delayed work, io_uring/io-wq/task_work fallback,
timer callbacks, RCU callbacks, and softirq-style carriers are drained,
rejected, quarantined, or forced to observe revoked authority before effect.
```

Endpoint and admission drain:

```text
endpoint uses, direct-call in-flight requests/responses, monitor-owned ring
slots/responses, and derived receipts/shadows are invalidated before completion.
```

Device drain:

```text
queue submit, descriptors, DMA memory, completion, IRQ/control, representor,
and service-work carriers are drained or quarantined before reassignment.
```

Budget/root settlement:

```text
caller BudgetTickets, server-borrow tickets, root timers, and RunTokens are
settled exactly once and cannot spend after drain start.
```

## Rejected Designs

The model rejects:

```text
exit complete with remote wake pending
exit complete with queued/selected/denied/move FrozenRunUse pending
release before drain settlement
PID/TGID or raw pointer reuse matching stale authority
revoke complete with typed workqueue carrier pending
cancel_work_sync() or flush_work() as drain receipt
work pending-bit clear as revoke receipt
self-requeue using old carrier authority
io_uring cancel/free as drain receipt
CQE delivery or skip as authority settlement
linked/reissued io_uring request using old authority
endpoint use after exit/revoke
futex waiter wake after endpoint revoke
direct-call revoke complete with in-flight request/response
monitor-owned ring revoke complete with pending slot/response
derived receipt or Linux shadow live after revoke complete
device queue reassignment before drain/quarantine
BudgetTicket refund before carrier terminal state
server borrow ticket surviving exit/revoke
root timer or RunToken live after terminal state
audit/trace/timeout/Linux cleanup as drain proof
unknown pending carrier treated as drained
budget reservation leak or double settlement
RCU visibility as authority
behavior, monitor-verification, or protection overclaims
```

## Model

New model:

```text
formal/0082-exit-revoke-pending-authority-drain-gate-model/
```

Checked invariant group:

```text
Safety
```

with component obligations:

```text
NoSchedulerEffectAfterDrain
NoAsyncEffectAfterDrain
NoEndpointEffectAfterDrain
NoMonitorAdmissionEffectAfterDrain
NoDeviceEffectAfterDrain
NoBudgetSpendAfterDrain
NoRootExecutionAfterDrain
NoPendingCarrierSurvivesComplete
NoUnknownCarrierDefaultDrain
NoBudgetLeakAfterComplete
NoBudgetDoubleSettle
NoLinuxCleanupAsAuthorityReceipt
NoRcuVisibilityAuthority
NoPidReuseAuthority
NoEarlyReleaseAuthority
NoNonClaimOverreach
```

## Non-Claims

This gate does not approve Linux exit hooks, scheduler hooks, async wrappers,
endpoint implementation, device implementation, budget implementation, monitor
ABI, trace ABI, runtime coverage, behavior change, monitor verification, or
production protection.
