# Analysis 0103: Lifecycle Identity Propagation Integration Gate

Status: Draft integration model gate with TLC-backed design filter; no
implementation approved

Date: 2026-07-01

## Purpose

N-142 through N-148 progressively fixed wake publication, final run/move
revalidation, denial retry, placement, and task lifetime. Earlier models also
covered exec generation and post-exec resource inheritance. N-149 closes the
remaining integration gap:

```text
fork/clone/exec/exit identity transitions must not break the scheduler
authority chain.
```

The required shape is:

```text
fork/clone:
  SpawnCap-derived child identity is prepared before wake publication.
  The child never inherits a live RunCap, FrozenRunUse, or RunToken.

exec:
  ordinary exec preserves Domain identity.
  successful exec requires ExecContinuation for the currently running task.
  check-only exec does not mutate generations.

exit:
  task identity is invalidated before stale queued, selected, denied, move,
  or remote pending state can be consumed.
```

Linux clone flags, PID/TGID reuse, `sched_exec()` placement, RCU task
visibility, and task release state are compatibility mechanics, not CapSched
authority.

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
| fork broad task copy | `kernel/fork.c:914 dup_task_struct()` | future task fields are copy hazards unless sanitized |
| stack ref init | `kernel/fork.c:934 refcount_set(&tsk->stack_refcount, 1)` | child object has fresh lifetime state |
| task usage init | `kernel/fork.c:973 refcount_set(&tsk->usage, 1)` | child task lifetime begins separately |
| core fork path | `kernel/fork.c:1989 copy_process()` | child identity construction path |
| fork-no-exec flag | `kernel/fork.c:2171 p->flags |= PF_FORKNOEXEC` | child program image has not execed |
| RCU task copy reset | `kernel/fork.c:2174 rcu_copy_process(p)` | raw copied RCU state must not be authority |
| alloc pid | `kernel/fork.c:2304 alloc_pid()` | PID allocation is not task authority |
| no more failure paths | `kernel/fork.c:2478` | publication boundary after rollback is no longer available |
| clone copy process | `kernel/fork.c:2747 copy_process()` | userspace clone/fork creates child before wake |
| first child wake | `kernel/fork.c:2778 wake_up_new_task(p)` | initial runnable publication edge |
| scheduler fork setup | `kernel/sched/core.c:4803 sched_fork()` | child scheduler state initialized before run |
| TASK_NEW | `kernel/sched/core.c:4811 p->__state = TASK_NEW` | child cannot run before explicit wake |
| wake new task | `kernel/sched/core.c:4941 wake_up_new_task()` | initial runnable transition |
| TASK_RUNNING publish | `kernel/sched/core.c:4948 WRITE_ONCE(p->__state, TASK_RUNNING)` | fail-capable SpawnCap checks belong before publication |
| initial enqueue | `kernel/sched/core.c:4963 activate_task()` | queued state after child identity preparation |
| exec placement | `kernel/sched/core.c:5623 sched_exec()` | placement opportunity, not authority |
| exec mm replace | `fs/exec.c:842 exec_mmap()` | old program memory authority ends |
| exec de-thread | `fs/exec.c:919 de_thread()` | PID/TGID identity can be transferred |
| non-leader PID transfer | `fs/exec.c:1006 exchange_tids()` | PID/TGID cannot be task identity root |
| TGID transfer | `fs/exec.c:1007 transfer_pid(... PIDTYPE_TGID)` | visible process id can move between task objects |
| exec commit boundary | `fs/exec.c:1110 begin_new_exec()` | successful exec authority boundary |
| point of no return | `fs/exec.c:1131 bprm->point_of_no_return = true` | after this, errors are fatal rather than old-program continuation |
| mm installed | `fs/exec.c:1167 exec_mmap(bprm)` | old mm/mmap authority revoked |
| self exec id | `fs/exec.c:1262 self_exec_id++` | Linux-visible exec generation exists but is not CapSched authority alone |
| credential commit | `fs/exec.c:1274 commit_creds()` | credential changes cannot amplify inherited endpoint authority |
| exec entry | `fs/exec.c:1754 bprm_execve()` | exec orchestration |
| exec sched opportunity | `fs/exec.c:1771 sched_exec()` | migration opportunity before commit |
| release task | `kernel/exit.c:244 release_task()` | logical release/unhash path |
| RCU task put | `kernel/exit.c:307 put_task_struct_rcu_user(p)` | RCU visibility remains after logical release |
| exit notify | `kernel/exit.c:766 exit_notify()` | zombie/dead notification boundary |
| do exit | `kernel/exit.c:924 do_exit()` | task exit path |
| process-exit trace | `kernel/exit.c:975 trace_sched_process_exit()` | observation only |
| exit mm | `kernel/exit.c:992 exit_mm()` | old memory authority ends |
| final task dead call | `kernel/exit.c:1047 do_task_dead()` | scheduler death handoff |
| dead task schedule drop | `kernel/sched/core.c:5395 prev_state == TASK_DEAD` | final scheduler handling for dead task |
| dead task RCU put | `kernel/sched/core.c:5410 put_task_struct_rcu_user(prev)` | RCU put is lifetime cleanup, not authority |
| task dead state | `kernel/sched/core.c:7244 do_task_dead()` | TASK_DEAD transition |
| TASK_DEAD set | `kernel/sched/core.c:7247 set_special_state(TASK_DEAD)` | no runnable authority after death |
| task get/put API | `include/linux/sched/task.h:114 get_task_struct()` | explicit lifetime reference |
| numeric pid warning | `include/linux/pid.h:23` | numeric PID reuse warning; PID not authority |

## Existing Model Inputs

This gate composes and narrows earlier work:

```text
analysis/0029-fork-exec-exit-identity-propagation-map.md
analysis/0042-exec-generation-inheritance-semantics.md
analysis/0043-post-exec-resource-inheritance-classes.md
formal/0025-exec-generation-inheritance-model/
formal/0026-post-exec-resource-inheritance-model/
formal/0074-f1-admission-freeze-refresh-model/
formal/0078-final-run-move-revalidation-hook-placement-gate-model/
formal/0079-final-deny-retry-ineligibility-gate-model/
formal/0080-task-frozen-run-lifetime-locking-gate-model/
```

## Required Semantics

For fork/clone:

```text
SpawnCap or equivalent spawn admission is required.
child task generation is fresh.
new process generation is fresh unless the model explicitly treats it as a
  same-process thread clone.
new Domain requires a monitor token; clone flags are not Domain authority.
SchedContext inheritance is bound to the child identity.
RunCap, FrozenRunUse, and RunToken are not ambiently copied.
child wake publication happens only after identity preparation.
```

For exec:

```text
ordinary exec does not change Domain identity.
Domain-changing exec requires an explicit transition token.
successful exec requires ExecContinuation for current execution.
check-only exec does not mutate generations or derive new authority.
old FrozenRunUse is not reused across exec.
PID/TGID transfer during non-leader exec is not task identity.
```

For exit:

```text
task exit invalidates queued, selected, denied, move, and pending authority.
task release and RCU visibility do not create authority.
PID reuse cannot preserve authority.
```

## Rejected Designs

The model rejects:

```text
child run without SpawnCap
child run without fresh task generation
process clone without fresh process generation
ambient RunCap inheritance
FrozenRunUse inheritance
RunToken inheritance
unbound child SchedContext
wake before identity preparation
new Domain clone without monitor token
clone flags as Domain authority
exec Domain change without token
post-exec run without ExecContinuation
check-only exec mutating generation
old FrozenRunUse after exec
run after exit invalidation
PID/TGID reuse as authority
release state as authority
behavior, monitor-verification, or protection overclaims
```

## Model

New model:

```text
formal/0081-lifecycle-identity-propagation-integration-gate-model/
```

Checked invariant group:

```text
Safety
```

with component obligations:

```text
NoChildRunWithoutSpawnAuthority
NoChildRunWithoutFreshTaskGeneration
NoProcessCloneWithoutProcessGeneration
NoAmbientRunAuthorityInheritance
NoUnboundSchedContextInheritance
NoWakeBeforeIdentity
NoNewDomainWithoutToken
NoCloneFlagsAsDomainAuthority
NoExecDomainChangeWithoutToken
NoRunAfterExecWithoutContinuation
NoCheckOnlyMutation
NoOldFrozenRunUseAfterExec
NoRunAfterExitInvalidation
NoPidReuseAuthority
NoReleaseAuthority
NoNonClaimOverreach
```

## Non-Claims

This gate does not approve Linux fork/clone, exec, exit, scheduler hooks,
task fields, storage layout, public ABI, monitor ABI, runtime coverage,
behavior change, monitor verification, or production protection.

It supports only this claim shape:

```text
Any future scheduler authority implementation must preserve CapSched identity
freshness across fork/clone, exec, and exit; Linux lifecycle mechanics may
constrain compatibility but cannot mint runnable authority.
```
