# Analysis 0001: Initial Linux Source Map

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This is the first source map for CapSched analysis. It records actual upstream
files and function locations found before choosing implementation patch points.

This note is evidence inventory, not an implementation decision.

## Scheduler Files

`kernel/sched/` contains the scheduler core and classes:

- `kernel/sched/core.c`
- `kernel/sched/sched.h`
- `kernel/sched/fair.c`
- `kernel/sched/rt.c`
- `kernel/sched/deadline.c`
- `kernel/sched/idle.c`
- `kernel/sched/stop_task.c`
- `kernel/sched/syscalls.c`
- `kernel/sched/core_sched.c`
- `kernel/sched/ext/ext.c`
- `kernel/sched/ext/*.h`
- `kernel/sched/cpuacct.c`
- `kernel/sched/cputime.c`
- `kernel/sched/topology.c`
- `kernel/sched/isolation.c`

## Core Execution Spine

Initial grep evidence from `kernel/sched/core.c`:

- `finish_task_switch()` around line 5318
- `context_switch()` around line 5451
- `__pick_next_task()` around line 6124
- `pick_next_task()` around lines 6216 and 6671, depending on core scheduling config
- `__schedule()` around line 7061
- `schedule()` around line 7316
- `schedule_user()` around line 7357

Initial CapSched relevance:

- `__schedule()` / `pick_next_task()` / `context_switch()` form the likely
  observation spine for `DomainTag + SchedContext + Thread`.
- This does not yet imply a hook point.
- The analysis must preserve locking, RCU, preemption, and scheduler class
  contracts before proposing changes.

## Enqueue, Wakeup, and Tick

Initial grep evidence:

- `activate_task()` in `kernel/sched/core.c` around line 2219
- `deactivate_task()` in `kernel/sched/core.c` around line 2230
- `wake_up_process()` in `kernel/sched/core.c` around line 4545
- `sched_fork()` in `kernel/sched/core.c` around line 4803
- `sched_cgroup_fork()` in `kernel/sched/core.c` around line 4874
- `scheduler_tick()` matched in `kernel/sched/core.c`
- class-specific runtime updates appear in:
  - `update_curr()` in `kernel/sched/fair.c` around line 1985
  - `update_curr_rt()` in `kernel/sched/rt.c` around line 974
  - `update_curr_dl()` in `kernel/sched/deadline.c` around line 2128
  - `update_curr_scx()` in `kernel/sched/ext/ext.c` around line 1321

Initial CapSched relevance:

- `RunCap` maps conceptually to runnable submission, but Linux has multiple
  activation paths.
- `SchedContext` and budget accounting must be compared against class-specific
  runtime accounting rather than assuming one global fair-only path.
- Tick/preemption analysis must include RT, deadline, fair, and sched_ext.

## Data Structures

Initial grep evidence from `include/linux/sched.h`:

- `struct task_struct` starts around line 826.
- Scheduler entities appear around:
  - `struct sched_entity` around line 575
  - `struct sched_rt_entity` around line 623
  - `struct sched_dl_entity` around line 644
- `task_struct` contains scheduler-related fields around:
  - `se`, `rt`, `dl`, `scx`
  - `sched_class`
  - `core_cookie`
  - `nr_cpus_allowed`
  - `cpus_ptr`
  - `user_cpus_ptr`
- `task_struct` also contains authority-relevant state:
  - `mm`, `active_mm`
  - `real_cred`, `cred`, `ptracer_cred`
  - `files`
  - `cgroups`

Initial grep evidence from `kernel/sched/sched.h`:

- `struct task_group` around line 478
- `struct root_domain` around line 1001
- `struct rq` around line 1135
- `struct rq_flags` around line 1849
- `struct sched_class` around line 2585

Initial CapSched relevance:

- `task_struct` can carry Domain-related pointers mechanically, but the hard
  problem is propagation and semantic authority.
- `rq` and `sched_class` contracts are central for any `FrozenRunUse` or
  budget eligibility check.
- `task_group`, cgroups, and cpuset are policy inputs and constraints, not
  sufficient capability roots.

## Lifecycle Files

Initial grep evidence:

- `kernel/fork.c`
  - `copy_mm()` around line 1563
  - `copy_files()` around line 1637
  - `copy_creds()` call around line 2148
  - `sched_fork()` call around line 2258
  - `copy_files()` call around line 2276
  - `copy_mm()` call around line 2288
  - `sched_cgroup_fork()` call around line 2406
  - `kernel_clone()` around line 2693
  - `clone` syscalls around lines 2856-2872
  - `clone3()` around line 3028
- `kernel/cred.c`
  - `copy_creds()` around line 263
  - `commit_creds()` around line 368
- `fs/exec.c`
  - `de_thread()` around line 919
  - `begin_new_exec()` around line 1110
  - `commit_creds()` call around line 1274
  - `setup_new_exec()` around line 1334
  - `bprm_execve()` around line 1754
  - `sched_exec()` call around line 1771
  - `do_execveat_common()` around line 1808
- `kernel/exit.c`
  - `release_task()` around line 244
  - `exit_mm()` around line 576
  - `do_exit()` around line 924
  - `exit_files()` call around line 999
  - `exit_group()` syscall around line 1156

Initial CapSched relevance:

- Fork/clone is the main ambient-authority risk for `SpawnCap`.
- Exec changes code, mm, and credentials but should not automatically change
  DomainTag in the desired model.
- Exit/release must eventually invalidate or release run grants and budget
  bindings without treating self-exit as RunCap authority.

## Placement and Existing Controls

Initial grep evidence:

- Affinity and migration in `kernel/sched/core.c`:
  - comments around `sched_setaffinity()` / `set_cpus_allowed_ptr()` near lines 589-590
  - `set_cpus_allowed_common()` around line 2774
  - `do_set_cpus_allowed()` around line 2793
  - `__set_cpus_allowed_ptr_locked()` around line 3112
  - `__set_cpus_allowed_ptr()` around line 3197
  - `set_cpus_allowed_ptr()` around line 3215
- uclamp in `kernel/sched/core.c`:
  - static key and defaults around lines 1558-1604
  - `uclamp_rq_inc()` around line 1856
  - `uclamp_rq_dec()` around line 1884
  - `uclamp_fork()` around line 2076
  - cgroup `cpu.uclamp.*` handlers around lines 9695-9772
- cgroup CPU interface in `kernel/sched/core.c`:
  - `cpu.weight` handlers around lines 10386-10427
  - `cpu.max` handlers around lines 10479-10530
- core scheduling:
  - `task_struct::core_cookie` appears in `include/linux/sched.h`
  - core scheduling helpers in `kernel/sched/core.c` and `kernel/sched/core_sched.c`
  - `sched_core_update_cookie()` in `kernel/sched/core_sched.c` around line 55

Initial CapSched relevance:

- Existing controls are valuable policy inputs, compatibility constraints, and
  prior art for placement/co-tenancy.
- They should not be treated as non-forgeable CapSched authority roots.

## Async Execution Files

Initial grep evidence:

- `kernel/workqueue.c`
  - `__queue_work()` around line 2275
  - `queue_work_on()` around line 2442
  - `create_worker()` around line 2836
  - `process_one_work()` around line 3220
  - `worker_thread()` around line 3431
- `kernel/task_work.c`
  - `task_work_add()` around line 59
  - `task_work_run()` around line 200
- `kernel/kthread.c`
  - `__kthread_create_on_node()` around line 476
  - `kthread_create_on_node()` around line 550
  - `kthread_stop()` around line 733
  - `kthread_queue_work()` around line 1199
- `io_uring/tctx.c`
  - `io_init_wq_offload()` around line 16
  - task io-wq management around lines 93, 183, 253
- `io_uring/io-wq.c`
  - `struct io_worker` around line 48
  - `struct io_wq` around line 116
  - worker creation paths around lines 147, 323, 351, 387
  - task_work-based worker creation around line 410

Initial CapSched relevance:

- Async work is the highest confused-deputy risk discovered before patching.
- Workqueue, task_work, kthread, and io_uring must be analyzed before any claim
  that Domain provenance can be preserved.

## Immediate Open Questions

1. Which activation paths bypass a naive enqueue-only check?
2. How many places can task runtime be charged, and which are class-specific?
3. What is the minimum safe meaning of `FrozenRunUse` in Linux runqueues?
4. Which fork/clone paths create threads versus new processes versus kernel workers?
5. Which async work items already carry enough context, and which carry none?
6. How does core scheduling cookie lifecycle interact with Domain co-tenancy?
7. Where should the first formal model cut the system boundary?

## Next Analysis Note

The next note should be:

```text
capsched-models/analysis/0002-scheduler-execution-spine.md
```

It should read `kernel/sched/core.c` and `kernel/sched/sched.h` deeply before
considering any implementation patch point.

