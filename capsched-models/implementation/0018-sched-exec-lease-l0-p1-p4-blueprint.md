# Implementation 0018: SchedExecLease L0 P1-P4 Blueprint

Status: Draft implementation blueprint; P1-P4 remain no-denial preparation only

Date: 2026-07-02

## Purpose

This blueprint turns the SchedExecLease L0 design gate into an implementation
sequence that can be reviewed against current Linux source without approving
runtime enforcement.

The target is deliberately narrow:

```text
P1-P4:
  internal scheduler execution-lease plumbing
  default allow-all semantics
  no denial
  no user ABI
  no monitor ABI
  no public tracepoint ABI
  no exported symbol

P5:
  first possible test-only denial mode
  requires separate approval after validation gates below
```

## Current Source Basis

```text
linux branch: capsched-linux-l0
linux work commit: 3bb2a5821ffdcc0fa6d451cbf259ef82a9ea9a9c
linux subject: sched/exec_lease: Rename inert scheduler lease scaffold
patch queue base: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

Current Linux scaffold:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
CONFIG_SCHED_EXEC_LEASE depends on EXPERT and defaults n
```

Current behavior:

```text
no task_struct fields
no scheduler hooks
no lifecycle hooks
no runtime state
no ABI
no monitor call
```

## P1: Internal Object Skeleton

Allowed patch surface:

```text
include/linux/sched_exec_lease.h
kernel/sched/exec_lease.c
```

Allowed contents:

```text
opaque public declarations remain opaque
internal definitions live only in kernel/sched/exec_lease.c
default root-domain / allow-all helpers
pure helper return types for future placement, validation, and observation
no allocation required on hot paths
no task_struct field
no runqueue field
no externally callable symbol
```

The P1 helper vocabulary should separate authorities:

```text
sched_exec_domain_shadow:
  Linux-local domain shadow only, not authority

sched_exec_grant_shadow:
  future ExecutionGrant shadow only, not budget or spawn authority

sched_budget_ctx_shadow:
  future budget context shadow only, not grant authority

sched_exec_lease_use:
  future frozen execution use, not a reusable boolean

sched_exec_validation:
  allow/deny/retry/quarantine shape, but P1 always returns allow
```

P1 must not introduce names that imply monitor-backed protection. Any future
sealed token or MemoryView type remains an opaque placeholder until Monitor
work exists.

## P2: Task Lifecycle Identity Skeleton

Allowed patch surface:

```text
include/linux/sched.h
include/linux/sched_exec_lease.h
kernel/fork.c
fs/exec.c
kernel/exit.c
kernel/sched/exec_lease.c
```

P2 may add a tiny task-local shadow only after its lifetime rules are explicit.
The preferred first shape is a single embedded value object rather than owned
heap pointers:

```c
struct sched_exec_task {
        sched_exec_domain_id_t domain_id;
        sched_exec_epoch_t domain_epoch;
        sched_exec_generation_t task_generation;
        unsigned long flags;
};
```

This object is not authority. It records only the default root-domain shadow and
generation freshness needed by later validation.

Required lifecycle placement:

```text
dup_task_struct():
  copied task bytes are not authority; P2 must reinitialize or sanitize the
  sched_exec_task state after arch_dup_task_struct() and before publication.
  Use the existing post-raw-copy pattern such as exec_state reset; do not let
  parent pointers, frozen lease state, or generations survive the raw copy.

copy_process():
  child identity must be prepared before the task becomes visible and before
  kernel_clone() can call wake_up_new_task(). This also covers create_io_thread()
  and other inactive child-return paths that are woken by a later caller.
  Any future fallible spawn/lease allocation must happen before the no-more-
  failure-paths boundary or be replaced by a nofail default-root shadow.

sched_cgroup_fork()/sched_post_fork():
  may be observed for ordering, but cgroup membership is policy input only.

kernel_clone():
  wake_up_new_task() is too late to mint child identity.

sched_exec():
  placement only. It runs before exec credential preparation can fail or be
  check-only, so it must not mutate isolation domain or task/program generation.

begin_new_exec():
  exec may bump task-generation or exec-generation shadow after point of no
  return, but it must not change isolation domain or mint execution authority.

do_exit()/release_task()/__put_task_struct():
  exit invalidates task authority at do_exit()/PF_EXITING time. release_task(),
  Linux cleanup, trace, RCU, final put, and free_task() are not revoke receipts.
  owned storage release should be centralized so fork-error and normal final
  release paths agree.
```

P2 must preserve:

```text
fork and clone do not amplify authority
exec keeps isolation domain
PID/TGID reuse is not identity freshness
RCU visibility is not authority
task generation is monotonic per task object lifetime
program/exec generation is distinct from task object identity
```

P2 still must not deny, allocate grant objects, expose ABI, or call a monitor.

## P3: Placement-Only Scheduler Touch Points

Allowed patch surface:

```text
kernel/sched/core.c
kernel/sched/sched.h
kernel/sched/exec_lease.c
include/linux/sched_exec_lease.h
```

P3 may add static inline or local no-op calls that return allow-all and are
compiled away or trivially predictable when disabled.

The touch points must be named for the edge they represent, not for a broad
"scheduler check":

```text
sched_exec_lease_prepare_wake()
  future pre-TASK_WAKING preparation, not first fallible denial

sched_exec_lease_prepare_new_task()
  future child runnable publication preparation before wake_up_new_task enqueue

sched_exec_lease_validate_run_edge()
  future final run validation before rq->curr publication

sched_exec_lease_validate_move_edge()
  future queued move validation around move_queued_task_locked()

sched_exec_lease_observe_tick()
  future donor-aware runtime observation only

sched_exec_lease_note_switch()
  future monitor activation boundary, but P3 remains no-op
```

Candidate current anchors:

```text
kernel/sched/core.c:2546  move_queued_task(), common queued move before
  deactivate_task()/set_task_cpu()
kernel/sched/core.c:4357  TASK_WAKING publication in try_to_wake_up()
kernel/sched/core.c:4941  wake_up_new_task()
kernel/fork.c:952        post-raw-copy task field reset pattern
kernel/fork.c:2478       no more failure paths in copy_process()
kernel/fork.c:2672       create_io_thread() returns inactive copied task
kernel/fork.c:2778       kernel_clone() wakes child after trace/pid handling
fs/exec.c:1006           non-leader exec can exchange task IDs
fs/exec.c:1105           begin_new_exec() point-of-no-return region
fs/exec.c:1771           sched_exec() placement before final exec success
kernel/exit.c:946        exit_signals() sets PF_EXITING
kernel/exit.c:307        RCU-user put after release_task cleanup
kernel/fork.c:533        free_task() final storage release path
kernel/sched/sched.h:4120 move_queued_task_locked()
kernel/sched/core.c:5762  sched_tick(), donor selected before class tick
kernel/sched/core.c:6215  core-scheduling pick_next_task()
kernel/sched/core.c:6254  core cached pick fast path
kernel/sched/core.c:6447  core out_set_next
kernel/sched/core.c:6871  proxy execution owner search
kernel/sched/core.c:7149  final pick_next_task() in __schedule()
kernel/sched/core.c:7151  proxy execution donor/current adjustment
kernel/sched/core.c:7191  keep_resched join, best no-behavior final-run
  validation point before rq->curr publication
kernel/sched/core.c:7201  rq->curr publication
kernel/sched/core.c:7234  context_switch()
kernel/sched/fair.c:10839 fair detach_task(), load-balance move path that
  directly calls deactivate_task()/set_task_cpu()
kernel/sched/sched.h:3083 attach_task(), too late to be move authority
kernel/sched/rt.c:2066   RT push uses move_queued_task_locked()
kernel/sched/rt.c:2342   RT pull uses move_queued_task_locked()
kernel/sched/deadline.c:2827 deadline server pick is selected state
kernel/sched/deadline.c:3195 deadline push uses move_queued_task_locked()
kernel/sched/deadline.c:3281 deadline pull uses move_queued_task_locked()
kernel/sched/ext/ext.c:1904 sched_ext enqueue bypass for exiting or
  migration-disabled tasks
kernel/sched/ext/ext.c:2264 sched_ext remote-to-local DSQ move
kernel/sched/ext/ext.c:5484 sched_ext enable/disable and fallback path
kernel/workqueue.c:2861 worker execution loop entry
kernel/workqueue.c:3220 work->func execution in kworker context
```

P3 must not make `enqueue_task()` fail. `enqueue_task()` is void and mutates
uclamp, scheduler-class state, PSI, and core-scheduling state, so it cannot be
the first fallible authority boundary.

## P4: Allow-All Final Revalidation Skeleton

P4 may wire the no-op validation calls into the final run and move edges, but
the result must remain allow-all for every ordinary Linux task.

Preferred P4 hook classes:

```text
final run:
  __schedule() after pick_next_task(), after proxy resolution, at the
  keep_resched join, before is_switch and before rq->curr publication.

common queued move:
  move_queued_task() before deactivate_task()/set_task_cpu().

double-rq queued move:
  move_queued_task_locked() before deactivate_task()/set_task_cpu().

fair load-balance move:
  fair detach_task() before its direct deactivate_task()/set_task_cpu() pair.
```

Rejected hook substitutes:

```text
picked label alone:
  misses proxy path that jumps to keep_resched.

context_switch():
  too late for fail-closed denial.

set_task_cpu():
  CPU mutation is a Linux state change, not authority.

attach_task():
  too late; the task was already detached and CPU was already changed.

sched_ext dispatch queues:
  selected custody state, not authority.
```

Required semantics:

```text
validate before rq->curr publication
validate move before destination commit
run and move validation tuples are separate and not interchangeable
never deny after RCU_INIT_POINTER(rq->curr, next)
never retry indefinitely
never silently drop a wakeup
never treat selected state as authority
never treat core cached picks as already fresh
never charge budget only to current when donor differs
never treat sched_ext BPF dispatch as authority
never treat kworker execution context as caller authority
```

P4 may introduce an internal result enum if all non-allow values are unreachable
outside KUnit or build-only tests:

```c
enum sched_exec_validation_result {
        SCHED_EXEC_VALIDATION_ALLOW,
        SCHED_EXEC_VALIDATION_RETRY,
        SCHED_EXEC_VALIDATION_INELIGIBLE,
        SCHED_EXEC_VALIDATION_QUARANTINE,
};
```

The enum is a future control-flow type, not enforcement evidence.

## P5 Is Still Blocked

P5 is the first possible behavior-changing slice and remains blocked until all
of these are true:

```text
hook coverage plan maps every bypass surface
core cached-pick revalidation or invalidation is designed
sched_ext support/disable/fail-closed decision is made
proxy donor/current budget test plan exists
kthread and workqueue root/internal/service-domain classification exists
fork/exec/exit identity KUnit or trace validation exists
negative denial tests exist
bounded retry/ineligibility state is implemented
claim ledger still forbids production protection claims
```

Passing full build and QEMU smoke is necessary but not sufficient for P5.
As of validation/0130 and validation/0131, the full-build and QEMU boot-smoke
prerequisites are satisfied for no-behavior compatibility. P5 remains blocked by
the hook-coverage, sched_ext, core-scheduling, proxy, lifecycle-validation,
workqueue/kthread-classification, bounded-retry, and negative-test items above.

## Compatibility Constraints

Compatibility is part of the security design:

```text
CONFIG_SCHED_EXEC_LEASE=n must preserve current Linux behavior
CONFIG_SCHED_EXEC_LEASE=y must preserve current Linux behavior until P5
CFS, RT, deadline, idle, sched_ext, proxy execution, and core scheduling must
  not change accidentally
cpuset, affinity, CPU hotplug, cgroup, rlimit, LSM, namespace, and existing
  Linux capabilities remain Linux policy inputs, not SchedExecLease authority
kernel threads, stop tasks, idle tasks, hotplug tasks, and migration paths need
  explicit classification before denial exists
workqueue workers execute work items in kthread context; queued work is not a
  scheduler execution grant and must not inherit user authority accidentally
sched_ext may bypass some BPF callbacks and may fall back to the normal
  scheduler, so it cannot be a security-policy root
```

## Validation Required For P1-P4

Every P1-P4 patch requires at least:

```text
patch queue replay against recorded base
source-drift freshness check for touched anchors
CONFIG_SCHED_EXEC_LEASE=n full vmlinux build
CONFIG_SCHED_EXEC_LEASE=y full vmlinux build
QEMU boot smoke for off/on when scheduler/lifecycle code is touched
diff check
no old public Linux scaffold names reintroduced
```

If P2 adds task fields, the build matrix must include at least one config with:

```text
CONFIG_SCHED_CORE=y
CONFIG_SCHED_CLASS_EXT=y where available
CONFIG_SCHED_PROXY_EXEC=y where available
```

P5 readiness additionally requires separate coverage, because current Kconfig
does not necessarily allow all combinations at once:

```text
sched_ext enabled and fallback/bypass paths observed
core scheduling enabled on SMT-capable topology or explicit unavailable note
proxy execution enabled or explicit unavailable note
workqueue/kthread smoke with explicit root/internal-domain classification
```

If a config option is unavailable on the chosen upstream snapshot, the absence
must be recorded instead of silently treating it as covered.

## Non-Claims

This blueprint is not Linux implementation, runtime denial approval, user ABI
approval, public tracepoint ABI approval, monitor ABI approval, monitor
implementation, runtime coverage, exploit containment, hypervisor-grade
isolation, production protection, or cost-efficiency evidence.
