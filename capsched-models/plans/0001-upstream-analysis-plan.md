# Plan 0001: Upstream Linux Analysis for CapSched L0

Status: Active

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
remote: upstream = https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Goal

Analyze current upstream Linux deeply enough to decide how CapSched L0 could be
embedded without guessing patch points. This plan is about reading, mapping, and
model extraction. It is not permission to implement.

The analysis must answer:

```text
Where does Linux decide that a task may become runnable?
Where does Linux account and consume CPU time?
Where does Linux select a next task and perform context switch?
Where do fork/exec/exit propagate task identity and scheduler state?
Where does async execution lose caller provenance?
Where do cgroup/cpuset/uclamp/core scheduling/sched_ext interact with authority?
Which invariants can be modeled before code changes?
```

## Non-Goals

- Do not decide final patch points before source notes exist.
- Do not implement CapSched hooks.
- Do not claim Linux-only isolation strength.
- Do not collapse `RunCap`, `SchedContext`, `ThreadControlCap`,
  `SchedControlCap`, and `SpawnCap` into one authority type.
- Do not treat `sched_ext` as a production security root.

## CapSched Invariants to Map

```text
EXEC-001: No RunCap, no enqueue.
EXEC-002: No SchedContext, no execution.
EXEC-003: No budget, no execution.
EXEC-004: No FrozenRunUse, no runqueue entry.
EXEC-005: No valid epoch/generation, no execution.
EXEC-006: No DomainTag activation, no cross-Domain context switch.
ASYNC-001: No async work without caller provenance and frozen authority.
BROKER-001: No caller budget, no broker/service execution on behalf of caller.
BOUNDARY-001: No raw pointer or mutable kernel object authority across Domain boundaries.
MONITOR-001: Linux-only prototypes must not claim hypervisor-grade isolation.
```

## Analysis Phases

### Phase A: Scheduler Execution Spine

Purpose: understand the exact path from wakeup/enqueue to pick/switch/tick.

Primary files:

- `include/linux/sched.h`
- `kernel/sched/sched.h`
- `kernel/sched/core.c`
- `kernel/sched/fair.c`
- `kernel/sched/rt.c`
- `kernel/sched/deadline.c`
- `kernel/sched/ext/ext.c`
- `kernel/sched/syscalls.c`

Questions:

- Which functions enqueue and dequeue tasks?
- Which paths activate a task from wakeup, fork, migration, or class-specific state?
- Where can a frozen execution lease be checked without breaking scheduler class contracts?
- Where is runtime charged today, and how does it differ by fair/RT/deadline/ext?
- What lock, RCU, preemption, and per-CPU assumptions exist around `rq`, `task_struct`,
  and scheduler class callbacks?
- Where can DomainTag switch instrumentation be observed without changing semantics?

Deliverables:

- `capsched-models/analysis/0002-scheduler-execution-spine.md`
- An invariant coverage matrix for enqueue, pick, context switch, and tick.
- A list of forbidden hook locations where lock/preemption semantics make CapSched unsafe.

### Phase B: Task Identity and Lifecycle

Purpose: understand how Linux creates, transforms, and destroys task identity.

Primary files:

- `kernel/fork.c`
- `fs/exec.c`
- `kernel/exit.c`
- `kernel/cred.c`
- `include/linux/cred.h`
- `include/linux/sched.h`

Questions:

- What does `copy_process()` initialize before and after `sched_fork()`?
- Where do `copy_creds()`, `copy_files()`, and `copy_mm()` establish inherited authority?
- Where should analysis distinguish thread creation, process creation, and kernel thread creation?
- Which exec paths change credentials or mm while keeping task identity?
- Which exit/release paths can invalidate FrozenRunUse, SchedContext bindings, and Domain membership?
- Which operations are self-authority versus external control authority?

Deliverables:

- `capsched-models/analysis/0003-task-lifecycle.md`
- A spawn/exec/exit authority table.
- A list of task lifetime generations that a formal model must represent.

### Phase C: Placement, Priority, and Existing Resource Controls

Purpose: map existing Linux controls that are policy inputs or constraints, not
the CapSched authority root.

Primary files:

- `kernel/sched/core.c`
- `kernel/sched/syscalls.c`
- `kernel/cgroup/cgroup.c`
- `kernel/cgroup/cpuset.c`
- `include/linux/cgroup*.h`
- `include/linux/cpuset.h`
- `kernel/sched/core_sched.c`
- `kernel/sched/isolation.c`

Questions:

- How do `sched_setattr()`, `sched_setscheduler()`, `sched_setaffinity()`, and
  `__set_cpus_allowed_ptr()` modify scheduling authority today?
- How do cgroup CPU controller, cpuset, and uclamp constrain tasks and task groups?
- How does core scheduling cookie management work and what can be reused as a
  co-tenancy input?
- Where do existing controls enforce policy, and where do they only annotate state?
- Which controls are subject to ambient privilege and therefore cannot be the
  root of CapSched authority?

Deliverables:

- `capsched-models/analysis/0004-existing-resource-controls.md`
- A mapping from existing Linux mechanisms to CapSched policy-input,
  enforcement-input, or non-root categories.

### Phase D: Async Execution and Provenance Loss

Purpose: identify where execution continues after the originating syscall/task
context has changed or disappeared.

Primary files:

- `kernel/workqueue.c`
- `kernel/task_work.c`
- `kernel/kthread.c`
- `kernel/softirq.c`
- `kernel/time/timer.c`
- `io_uring/io-wq.c`
- `io_uring/io_uring.c`
- `io_uring/tctx.c`
- `io_uring/register.c`
- `io_uring/rsrc.c`

Questions:

- Where is work queued, where is it executed, and what identity is carried?
- Which work items run under worker task credentials rather than caller provenance?
- Which io_uring resources are registered once and later consumed asynchronously?
- Where are kernel workers created, parked, woken, stopped, or reused?
- Which async paths require caller frozen authority versus service-domain authority?
- What is the minimum provenance data a model needs before implementation?

Deliverables:

- `capsched-models/analysis/0005-async-provenance.md`
- A confused-deputy risk matrix.
- Candidate formal model scope for `ASYNC-001`.

### Phase E: Security and Policy Front-Ends

Purpose: understand how existing Linux security mechanisms can feed policy
without being mistaken for the root enforcement boundary.

Primary files:

- `security/security.c`
- `include/linux/lsm_hook_defs.h`
- `include/linux/lsm_hooks.h`
- `include/linux/cred.h`
- `kernel/cred.c`
- `security/landlock/`
- namespace and cgroup files as needed

Questions:

- Which security hooks are naturally policy issuance points?
- Which hooks are too semantic or too late for scheduler authority?
- How do credentials change across fork/exec and what would DomainTag keep stable?
- Which Linux capabilities overlap with but do not replace CapSched authority?

Deliverables:

- `capsched-models/analysis/0006-policy-frontends.md`
- A policy-input map for LSM, cred, namespace, cgroup, cpuset, and Landlock.

### Phase F: Model Extraction

Purpose: select the first formal model based on source evidence.

Candidate models:

1. Enqueue/pick/tick budget semantics:
   `RunCap + SchedContext + FrozenRunUse + budget refill/exhaustion`.
2. Epoch/generation revocation:
   lazy runqueue invalidation, cross-CPU revoke, and generation mismatch.
3. Async provenance:
   caller frozen authority crossing workqueue/io_uring/task_work boundaries.
4. Broker budget donation:
   `BudgetTicket` and `effective = caller ∩ service`.

Selection rule:

Choose the model whose code paths are best understood after Phases A-D and whose
properties block the most dangerous implementation ambiguity.

Deliverables:

- `capsched-models/formal/0001-model-selection.md`
- First TLA+ or equivalent model skeleton only after the selection memo.

## Evidence Standard

Every analysis claim should include at least one of:

- file path and function name
- line number range from the current upstream commit
- command used to locate the path
- explicit uncertainty marker

Avoid writing "Linux does X" without evidence.

## Stop Conditions Before Implementation

No implementation branch patch should start until:

1. Scheduler execution spine note exists.
2. Task lifecycle note exists.
3. Async provenance note exists or is explicitly deferred with risk accepted.
4. First formal model target is chosen.
5. L0 security claim boundary is restated: no hypervisor-grade isolation.
6. The user explicitly accepts the first L0 slice.

## Working Method

For each phase:

1. Read source and record evidence.
2. Map findings to CapSched invariants.
3. Mark open questions.
4. Update `capsched-ai/state/events.jsonl`.
5. Commit project-control artifacts in `capsched/`.

Linux source must remain unmodified during analysis.

