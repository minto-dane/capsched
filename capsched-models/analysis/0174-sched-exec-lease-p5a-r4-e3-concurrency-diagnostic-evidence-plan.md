# Analysis 0174: SchedExecLease P5A-R4 E3 Concurrency and Diagnostic Evidence Plan

Date: 2026-07-17

Status: pre-source gate for one disposable, default-off, same-translation-unit
R4-E3 KUnit concurrency prototype. Passing this plan authorizes only drafting
that isolated source. It does not accept the draft, connect a scheduler hook,
or authorize runtime or production use.

## Decision

Validation/0240 closed R4-E2 on fresh arm64 and x86_64 baselines. The exact E2
candidate contains the full private bucket, notifier cursor, projection dirty
node, and per-rq irq/work owner layout without constructing any object. R4-E3
may now test the selected protocol, but only behind a new test-only option in
the same translation unit and only with synthetic scheduler inputs.

The gate deliberately separates three claims:

```text
plan passes       -> exact disposable E3 source may be drafted
source gate passes -> the exact source/build boundary is eligible for boots
diagnostic closure -> isolated concurrency evidence may unlock an E4 plan
```

None of those claims is live scheduler correctness. The primary Linux branch,
patch queue, production configuration, and Linux PR #2 remain unchanged.

## Immutable Input and Direct-Child Boundary

The future draft is an exact direct child of:

```text
parent commit:  a429fc30252ac6af94c51d96cd4ac24e72d9f83b
parent tree:    fffd419bbc05bab87ad304c1e4a3213439d62bab
parent diff:    94dedc73b731c451d52b90885cd63a350a1cd562a3b1b40f856c5984b4f6cd15
branch:         codex/p5a-r4-e3-concurrency-prototype
worktree:       build/DomainLeaseLinux.volume/worktrees/
                  p5a-r4-e3-concurrency-prototype

allowed files:
  init/Kconfig
  kernel/sched/exec_lease.c
```

Every E2 private type, field, enum value, constant, and all 58 private probe
symbols remain byte-for-byte fixed. Every existing expanded-probe value remains
unchanged. The future diff may append test-only helpers and configuration, but
may not edit a public or scheduler header, Makefile, `sched.h`, `fair.c`,
`core.c`, or `exec_lease_layout_probe.c`.

The primary remains Linux commit
`5e1ca3037e34823d1ba0cdd1dc04161fac170280`, tree
`54f685aad94f28f0027cbba18cf5e29aadce234a`. The patch queue remains commit
`16bb080da472ffabbbafd2698073eca633fb0602`, series blob
`298567f8e0bd18168222da4e64da32750b9ea818`, and tail 0014. R4-E3 is
disposable evidence and is not a promotion of the build-only E2 probe.

## Configuration and Reachability Boundary

Add exactly one configuration:

```text
CONFIG_SCHED_EXEC_LEASE_R4_KUNIT_TEST
  bool
  default n
  depends on SCHED_EXEC_LEASE_R4_LAYOUT_PROBE && KUNIT=y
```

The option is not selected by the ordinary lease option, either layout probe,
or `KUNIT_ALL_TESTS`. All new includes, fixtures, hooks, helpers, fault knobs,
workers, irq callbacks, and suite registration live inside this option in
`kernel/sched/exec_lease.c`. The exact suite name is
`sched_exec_lease_r4_concurrency`.

With the option disabled there must be zero new E3 symbols, relocations,
strings, initcalls, constructors, workqueue allocations, CPUHP registrations,
or test surfaces. The E3 code must add no export, static key, tracepoint,
debugfs/proc/sysfs entry, device, netlink family, securityfs entry, or userspace
ABI. A release config must continue to pin both R4 options to `n`.

## Synthetic Prototype Boundary

The prototype instantiates the actual E2-private bucket, projection, and rq
state types. It uses real raw spinlocks, refcounts, cpumasks, XArray entries,
RCU readers/callbacks, hard irq-work items, work structs, and a dedicated
`WQ_UNBOUND | WQ_HIGHPRI | WQ_MEM_RECLAIM` workqueue. A small test rq shell
provides a raw lock, synthetic current token, contribution counters, and
observation sequence. It is not attached to a live `struct rq`.

The prototype may not:

```text
attach private state to rq, cfs_rq, sched_entity, task_struct, or task_group
call a production enqueue, dequeue, pick, migrate, hotplug, or cgroup seam
register a real CPUHP state or publish a non-test global registry
make a capability, budget, policy, monitor, admission, or denial decision
call resched_curr() on a live rq or claim an interrupt/completion receipt
scan inner leaves, hierarchy levels, all buckets, or all rqs
export a helper or create a persistent observability/userspace surface
```

The suite exercises the control protocol in isolation. Passing it says that
the forced finite schedules agree with an independent oracle; it does not say
that the production scheduler invokes the protocol correctly.

## Independent Oracle and Receipts

The oracle uses plain immutable test records and must not reuse the prototype's
transition, refcount, mask, generation, dirty-list, notifier, migration,
hotplug, or work-owner helpers. After every forced transition it snapshots the
implementation under documented locks and compares:

```text
bucket state, generation, membership sequence, and notifier ownership
notifier target/pass generation, pass membership sequence, cursor, restart
projection desired/observed generation, state, contribution, dirty ownership
per-rq dirty depth/list uniqueness, irq pending, work pending/running/owner
queued, delayed, current, source, destination, and neutral contribution state
current request sequence and later scheduler-observation sequence
accepting, queue-enabled, offline, retiring, unpublished, and RCU-reader state
bucket/projection/contribution/dirty/notifier/callback/RCU reference classes
```

Each test case emits a machine-readable receipt containing its exact forced
schedule, fault site, oracle checkpoints, terminal reference equation, and
cleanup outcome. A failed assertion does not skip cleanup or the final oracle
and leak checks. Required cases may not be marked expected-fail or skipped.

## Capacity and Pre-Runnable Allocation

The exact active-projection cases per rq are `0, 1, 63, 64, 65`. The first
four are admitted and 65 fails closed before any queued, delayed, or current
contribution becomes visible. There is no eviction, alias, merge, mixed-tree
fallback, unbounded list, or capacity increase.

Fault injection covers every named pre-runnable allocation boundary:

```text
dedicated workqueue creation
bucket control object
bucket active-rq cpumask
private rq-state shell
bucket/rq projection object
XArray slot reservation
```

Every injected failure returns `-ENOMEM`, leaves no active bit, XArray entry,
contribution, dirty node, queued/running callback, notifier owner, recovery
owner, or leaked reference, and permits a clean retry after fault removal.
Allocation, XArray allocation, free, waiting, or RCU synchronization under an
rq or membership lock is forbidden.

## irq-work to Unbound-Work Bridge

The test kick is called only while the synthetic rq raw lock is held with local
IRQs disabled. It records latest-wins desired generation, adds a projection's
preallocated dirty node only on the `0 -> 1` edge, takes exactly one dirty
lifetime reference, and calls `irq_work_queue()` on the rq's one hard item.

Duplicate kick or `irq_work_queue()==false` may not grow dirty depth or owner
count. The hard irq callback is dispatch-only. It records entry/exit context
and unconditionally calls `queue_work()` for the one rq recovery owner. It may
not take an rq or membership lock, repair, allocate, free, wait, cancel, flush,
or execute an oracle/policy/monitor action.

`queue_work()==false` is accepted only while the same recovery owner is
provably pending or running. Durable dirty state and its lifetime reference
remain owned. A false return with neither pending nor running owner is a lost-
wakeup failure.

The recovery worker takes one rq lock, selects at most one unique dirty
projection, and takes at most that projection's membership lock in the sole
nested order `rq -> one membership lock`. It rechecks accepting, contribution,
state, and acquire-generation before publishing Fresh. A race retains or
reinserts the node. The worker releases all scheduler locks before self-
requeue. A concurrent insertion racing the final-empty check always kicks the
irq bridge.

## Publisher and Cursor Notifier

Authority publication is modeled as an O(1) bucket-lock critical section. It
freezes state, release-publishes a non-wrapping generation, advances the
notifier target, sets restart when already owned, and takes at most one
notifier reference. It releases the lock before queueing notifier work. It
never walks an rq mask or projection map and never takes an rq lock.

Each notifier invocation performs at most one `cpumask_next()` projection
visit. It takes one projection reference under the membership lock, releases
that lock, then takes the target rq lock. It revalidates membership and
contribution, updates desired generation, inserts the unique dirty node if
needed, records a current-stop request if appropriate, and kicks the rq
bridge. It releases the rq before dropping the projection reference.

At pass end, target generation, membership sequence, restart, and ownership
clear are serialized with publication. A changed generation or membership
sequence restarts from the first active CPU. A publisher racing owner clear
either sets restart on the existing owner or observes clear and becomes the
new owner. A projection admitted after its CPU was passed acquires the current
generation and self-kicks, so late admission cannot be lost.

After a final publication and membership change, with `A` stable active rqs,
the oracle permits at most an old remaining pass plus one newest pass:
`notifier_projection_visits <= 2*A`. This is a logical count under forced weak
fairness, never a wall-clock or global-settlement claim.

## Current Observation, Migration, and Hotplug

A picker trust failure and a current stop receipt remain separate. The test
notifier/recovery path increments a request sequence under the rq lock. Only a
later distinct synthetic scheduler-observation transition may advance the
observed sequence after the current token changed or revalidated. Merely
setting need-resched state is not completion, monitor delivery, or immediate
revocation.

Migration is exactly remove-neutral-add. The source queued/delayed/current
contribution reaches zero before source unlock, the oracle observes an
explicit neutral state, and destination contribution begins only after its
slot/projection is prepared. Destination capacity or allocation failure leaves
the task neutral and denied; it never restores an unverified source state.

Offline is two phase:

```text
rq-locked phase:
  clear accepting, disable new dirty ownership/kicks, remove contributions,
  retain bounded residual dirty/callback references

sleepable phase outside all scheduler locks:
  irq_work_sync(), cancel_work_sync(), settle canceled ownership/dirty refs,
  verify empty list and zero callback ownership, then complete offline
```

The forced schedules cover irq pending, irq callback dispatching, ordinary
work pending, work running, and a worker requiring self-requeue. Online
initializes and resets all private state before publishing accepting. The
suite does not register a real CPUHP callback; later integration must revalidate
the already frozen CPUHP ordering against its exact source.

## Retirement, Saturation, and RCU

Retirement first publishes Retiring/Blocked, prohibits new notifier/dirty
ownership, and unpublishes the synthetic registry. It then drains task and
contribution state, notifier ownership, every sparse projection, every rq
irq/work owner, and dirty references outside scheduler locks. Cancellation is
allowed only after all racing queue sources are disabled.

No bucket or projection is freed until its active mask/XArray are empty, all
task/contribution/notifier/dirty/callback/projection refs are zero, every
pre-unpublish RCU reader exits, and a grace period completes. Reaching
`U64_MAX` blocks publication and requires quiescent replacement; generation
zero and wrap reuse are invalid.

## Exact Deterministic Case Families

The suite must implement these 36 named families without reduction:

```text
bmax_0_1_63_64_and_65_reject
allocation_fault_every_pre_runnable_site_and_retry
duplicate_irq_kick_coalesces
publication_while_irq_pending
publication_while_irq_callback_dispatches
publication_while_work_pending
publication_while_work_running
irq_callback_dispatch_only_unconditional_queue
queue_work_false_pending_owner_retained
queue_work_false_running_owner_retained
worker_final_empty_vs_insert
worker_self_requeue_newest_generation
two_buckets_one_rq_one_projection_quantum
dirty_node_unique_and_bounded
notifier_old_partial_final_republish_restart_bound
notifier_generation_change_at_owner_clear
notifier_membership_change_at_owner_clear
late_admission_after_cursor_self_kicks
member_remove_before_cursor
member_remove_after_reference_before_rq_lock
queued_delayed_current_accounting
current_request_then_changed_observation
current_request_then_revalidated_observation
migration_success_remove_neutral_add
migration_destination_capacity_failure_stays_neutral
offline_while_irq_pending
offline_while_irq_callback_dispatches
offline_while_work_pending
offline_while_work_running
offline_while_worker_self_requeues
online_initializes_before_accepting
retire_vs_publisher_and_owner_clear
retire_vs_notifier_picker_worker_and_rcu_reader
cancel_pending_running_and_requeued
generation_saturation_blocks_without_wrap
reference_equation_and_cleanup_after_each_failure
```

Race sides use completions, atomic checkpoints, or explicit test barriers.
Timing-only sleeps are not proof. Each case has a 15-second hard timeout. Each
diagnostic boot repeats bridge, notifier, migration, hotplug, and retirement
stress at least 2,048 times using a recorded deterministic seed set.

## Build and Dual-Architecture Diagnostic Matrix

Fresh build directories are mandatory. Arm64 and x86_64 each build:

```text
exact E2 parent
E3 source with ordinary lease/layout/test options off
E3 source with R4 layout on and E3 test off
E3 source with R4 KUnit test on
```

Disabled modes contain zero E3 symbols, relocations, strings, or initcalls.
Enabled modes preserve all 51 expanded and all 58 R4-private values, maintain
zero ordinary scheduler-structure growth, and pass strict checkpatch with zero
errors, warnings, or checks.

Six fresh QEMU boots are required:

```text
arm64   standard debug + exact KUnit + lockdep + work/RCU/IRQ diagnostics
x86_64  standard debug + exact KUnit + lockdep + work/RCU/IRQ diagnostics
arm64   CPU-hotplug + failslab/fail-page-allocation stress
x86_64  CPU-hotplug + failslab/fail-page-allocation stress
arm64   generic KASAN + exact suite
x86_64  KCSAN + exact suite
```

Standard and fault boots enable `HOTPLUG_CPU`, `PROVE_LOCKING`,
`DEBUG_OBJECTS_WORK`, `PROVE_RCU`, `DEBUG_IRQFLAGS`, fault injection, and the
available IRQ-work/workqueue diagnostics. KASAN and KCSAN remain separate.
Every boot filters exactly `sched_exec_lease_r4_concurrency`, runs every
required case and stress family with zero fail/skip/timeout, and records the
compiler, full config, Image and object hashes, QEMU command, KTAP, console,
seed set, fault ledger, case receipts, and warning scan.

Any KASAN, KCSAN, lockdep, refcount, workqueue, irq-work, RCU, kmemleak,
WARNING, BUG, Oops, panic, stall, hung-task, soft-lockup, hard-lockup, or CPUHP
diagnostic rejects the source. Harness corruption, missing artifacts, reduced
matrix, absent receipt, or non-reproducible raw evidence is a harness failure,
not a pass or engineering rejection.

## Authorization and Claim Boundary

Passing N-133 authorizes only creation of the exact direct-E2-child disposable
source draft and its source gate. It does not accept source correctness or
authorize a build/boot result in advance. Only a separate exact-source and six-
boot closure may permit drafting an R4-E4 measurement plan.

```text
R4-E3 disposable two-file source draft: allowed only after this plan passes
R4-E3 source/correctness acceptance: blocked on exact source + diagnostics
R4-E4 plan/source: blocked on R4-E3 closure and a separate plan
live scheduler behavior: blocked
primary Linux and patch queue: unchanged and unapproved
```

This gate does not establish runtime task admission, denial correctness,
fairness/PELT/cgroup compatibility, current-stop latency, monitor delivery or
enforcement, cross-class coverage, production protection, performance, cost,
deployment, multi-node behavior, multi-cluster behavior, or datacenter
readiness.

## Next

Run validation/0241. Only a reproducible pass of the exact E2 hashes and
identities, source anchors, complete contract, safe formal trace, four liveness
properties, and every expected unsafe counterexample permits drafting the
disposable R4-E3 source.
