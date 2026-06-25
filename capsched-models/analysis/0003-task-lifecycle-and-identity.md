# Analysis 0003: Task Lifecycle and Identity

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note maps Linux task creation, exec, and exit behavior to CapSched identity
and authority. It focuses on compatibility risks around `SpawnCap`,
`DomainTag`, generation counters, `FrozenRunUse`, and worker threads.

## Existing Strengths

- Linux stages task creation carefully. `copy_process()` in `kernel/fork.c`
  initializes task state before publication.
- `sched_fork()` in `kernel/sched/core.c` around lines 4803-4872 sets
  `TASK_NEW`, which prevents accidental wakeup or enqueue before scheduler
  setup is complete.
- `sched_cgroup_fork()` around lines 4874-4902 initializes cgroup scheduling
  state before the child becomes visible.
- `wake_up_new_task()` is the explicit point where a new task becomes runnable.
- `exec` has a clear point-of-no-return in `begin_new_exec()` in `fs/exec.c`
  around lines 1110-1295.
- `do_exit()` in `kernel/exit.c` around lines 924-1035 centralizes a large part
  of task teardown.

These are good boundaries for analysis. They are not automatically safe hook
points.

## Fork and Clone Path

Evidence:

- `copy_mm()` in `kernel/fork.c` around lines 1563-1597:
  `CLONE_VM` shares the old mm, otherwise `dup_mm()` creates a new mm.
- `copy_files()` around lines 1637-1664:
  `CLONE_FILES` shares file tables, otherwise `dup_fd()` creates a copy.
- `copy_process()` starts around line 1989.
- Around lines 2100-2215, `copy_process()` handles `dup_task_struct()`,
  execution state, flags such as `PF_KTHREAD`, `PF_USER_WORKER`, `PF_IO_WORKER`,
  credentials, rlimits, and cgroup fork setup.
- Around lines 2257-2297, `copy_process()` calls `sched_fork()`,
  `security_task_alloc()`, `copy_files()`, `copy_fs()`, `copy_sighand()`,
  `copy_signal()`, `copy_mm()`, `copy_namespaces()`, and related setup.
- Around lines 2362-2408, pid/tgid setup, `cgroup_can_fork()`, and
  `sched_cgroup_fork()` happen before publication.
- `kernel_clone()` around lines 2693-2790 calls `copy_process()` and then
  `wake_up_new_task()`.

CapSched reading:

Fork is where ambient authority can accidentally multiply. Linux clone flags
let a child share or duplicate:

```text
mm
files
fs state
sighand
signal/thread group
io context
credentials, sometimes shared for threads
```

CapSched must separate:

```text
thread creation: same Domain may be allowed, but still needs SpawnCap
process creation: new task generation and explicit inherited capability set
domain creation: monitor-issued DomainToken, not normal clone inheritance
kernel worker creation: service Domain or typed system authority
io worker creation: caller provenance plus service/worker authority
```

## Clone Form Matrix

| Form | Linux evidence | CapSched authority risk |
| --- | --- | --- |
| Thread clone | `CLONE_VM`, `CLONE_THREAD`, shared credentials/files depending flags | Thread creation can amplify RunCap unless SpawnCap is explicit. |
| Process fork | duplicated mm/files/cred references | Object authority can be copied unless inherited caps are allowlisted. |
| Kernel thread | `kernel_thread()` around `kernel/fork.c` lines 2796-2809 | Kernel authority must not become a default Domain escape hatch. |
| io worker | `create_io_thread()` around `kernel/fork.c` lines 2672-2684 | Shares process resources and runs later, high provenance risk. |
| User worker | `PF_USER_WORKER` handling in `copy_process()` | Looks task-like but may be subsystem-controlled. |

## Exec Path

Evidence:

- `de_thread()` in `fs/exec.c` around lines 919-1025 changes thread-group
  structure and may move identity to the old group leader.
- `begin_new_exec()` around lines 1110-1295 handles the point-of-no-return,
  `de_thread()`, `io_uring_task_cancel()`, `unshare_files()`, `exec_mmap()`,
  namespace and signal changes, close-on-exec, task comm, `self_exec_id++`,
  and credential commit.
- `setup_new_exec()` around lines 1334-1356 performs arch setup and releases
  old mm state.
- `bprm_execve()` around lines 1754-1806 prepares credentials, marks
  `current->in_execve`, calls `sched_exec()`, applies LSM exec credential
  hooks, and runs the binary handler.

CapSched reading:

Linux exec changes code, mm, credentials, files, signal/thread-group shape, and
observable process identity. It should not automatically change CapSched
`DomainTag`.

Rule candidate:

```text
exec may change program identity and Linux credentials
exec may attenuate or revoke endpoint capabilities by policy
exec must not mint a new DomainTag
exec must not bypass SchedContext or monitor identity
```

Important terminology warning:

`fs/exec.c` uses the word "domain" in an existing Linux comment around thread
group behavior. This is not CapSched DomainTag and must not be conflated.

## Exit and Release Path

Evidence:

- `release_task()` in `kernel/exit.c` around lines 244-312 handles unhashing,
  cgroup release, ptrace release, pid release, and delayed RCU freeing.
- `exit_mm()` around lines 576-613 clears `current->mm` with task locking and
  membarrier ordering.
- `do_exit()` around lines 924-1035 cancels io_uring files, sets `PF_EXITING`
  through `exit_signals()`, traces sched process exit, exits mm/files/fs/ns,
  runs task work, exits cgroups, notifies parent, and reaches final scheduling.
- `exit_group()` around lines 1156-1159 exits a thread group.

CapSched reading:

Self-exit should not require RunCap. It is a current-task self operation.
External terminate/suspend/resume/inspect needs `ThreadControlCap`.

Grant and generation rule candidate:

```text
task generation invalidates runnable grants on exit
process generation may invalidate process-scoped endpoint grants on exec/exit
domain epoch invalidates all grants when monitor or root policy revokes domain
```

Compatibility hazard:

Task memory and pid identity can outlive execution through RCU and parent
notification. CapSched must distinguish "not executable anymore" from "object
still exists for wait, ptrace cleanup, audit, or RCU release".

## Credential and LSM Path

Evidence:

- `copy_creds()` in `kernel/cred.c` around lines 263-327 shares credentials for
  some threaded cases or prepares new credentials otherwise.
- `commit_creds()` around lines 368-430 RCU-replaces `real_cred` and `cred`.
- `include/linux/cred.h` around lines 130-143 contains uid/gid, capability,
  keyring, LSM security, and user namespace fields.
- LSM hooks include task allocation and scheduler policy hooks in
  `include/linux/lsm_hook_defs.h` around lines 218-220 and 251-259.

CapSched reading:

Linux credentials are policy inputs and ABI state. They are not the CapSched
authority root because the final threat model includes compromised Domain-local
kernel context. `DomainTag` must therefore be distinct from `cred`.

## Mapping to Capability Types

| Capability concept | Lifecycle mapping | Risk to avoid |
| --- | --- | --- |
| SpawnCap | Required before fork/clone creates a runnable child | Ambient multiplication of execution authority. |
| RunCap | Child must not inherit a runnable-submission right unless allowed | New task wakeup becomes an authority escalation. |
| SchedContext | May be inherited, attenuated, or freshly bound by policy | Child consumes parent/root budget unexpectedly. |
| FrozenRunUse | Must be invalid for a task generation after exit or exec-sensitive transition | Stale runqueue lease after task identity changed. |
| DomainTag | Stable across exec, explicit across domain creation | setuid or file exec must not mint a domain. |
| ThreadControlCap | Required for external kill/suspend/inspect | RunCap should not include control authority. |
| EndpointCap | May copy only by explicit inheritance rules | File/socket authority leaks through fork. |

## Preliminary Conclusion

Linux lifecycle code gives CapSched useful staging points and strong existing
compatibility semantics. The danger is not adding pointers to `task_struct`.
The danger is accidentally treating Linux inheritance as capability inheritance.
The first formal model should represent task generation, process generation,
domain epoch, and a child-authority allowlist before any fork hook is designed.
