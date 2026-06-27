# Analysis 0029: Fork, Clone, Exec, and Exit Identity Propagation Map

Status: Draft source map, no implementation approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

This note maps Linux task lifecycle code into CapSched identity rules:

```text
TaskIdentity:
  task pointer plus task generation

ProcessIdentity:
  process/thread-group lineage plus process generation

DomainIdentity:
  Domain id plus Domain epoch

ExecutionAuthority:
  RunCap + SchedContext + FrozenRunUse + active RunToken
```

The goal is to prevent Linux lifecycle semantics from accidentally amplifying
authority. Fork, clone, exec, and exit must not turn ambient task state into
runnable authority.

## Fork and Clone Source Spine

The core copy path is:

```text
kernel/fork.c:1989 copy_process()
kernel/fork.c:2110 dup_task_struct(current, node)
kernel/fork.c:2148 copy_creds(p, clone_flags)
kernel/fork.c:2169 delay/accounting and task state initialization
kernel/fork.c:2170 clear PF_WQ_WORKER/PF_IDLE/PF_NO_SETAFFINITY
kernel/fork.c:2171 set PF_FORKNOEXEC
kernel/fork.c:2192-2195 io_uring_fork(p)
kernel/fork.c:2214 cgroup_fork(p)
kernel/fork.c:2258 sched_fork(clone_flags, p)
kernel/fork.c:2270 security_task_alloc(p, clone_flags)
kernel/fork.c:2276 copy_files(...)
kernel/fork.c:2288 copy_mm(...)
kernel/fork.c:2291 copy_namespaces(...)
kernel/fork.c:2294 copy_io(...)
kernel/fork.c:2297 copy_thread(p, args)
kernel/fork.c:2747 copy_process(...)
kernel/fork.c:2757 trace_sched_process_fork(current, p)
kernel/fork.c:2778 wake_up_new_task(p)
```

Scheduler-side fork initialization is:

```text
kernel/sched/core.c:4563 __sched_fork()
kernel/sched/core.c:4565 p->on_rq = 0
kernel/sched/core.c:4567-4574 reset CFS entity runtime/vruntime fields
kernel/sched/core.c:4593 init_dl_entity(&p->dl)
kernel/sched/core.c:4595-4599 initialize RT entity fields
kernel/sched/core.c:4601-4603 init_scx_entity(&p->scx)
kernel/sched/core.c:4613 p->wake_entry.u_flags = CSD_TYPE_TTWU
kernel/sched/core.c:4615 init_sched_mm(p)
kernel/sched/core.c:4803 sched_fork()
kernel/sched/core.c:4811 p->__state = TASK_NEW
kernel/sched/core.c:4816 p->prio = current->normal_prio
kernel/sched/core.c:4823-4842 reset-on-fork policy normalization
kernel/sched/core.c:4844-4845 reject deadline fork with -EAGAIN
kernel/sched/core.c:4847 scx_pre_fork(p)
kernel/sched/core.c:4849-4857 select sched_class
kernel/sched/core.c:4874 sched_cgroup_fork()
kernel/sched/core.c:4882 take p->pi_lock
kernel/sched/core.c:4883-4890 assign sched_task_group
kernel/sched/core.c:4896 __set_task_cpu(p, smp_processor_id())
kernel/sched/core.c:4897 class task_fork callback
kernel/sched/core.c:4911 sched_post_fork()
```

The first runnable transition is:

```text
kernel/sched/core.c:4941 wake_up_new_task()
kernel/sched/core.c:4947 take p->pi_lock
kernel/sched/core.c:4948 WRITE_ONCE(p->__state, TASK_RUNNING)
kernel/sched/core.c:4958 select_task_rq(... WF_FORK)
kernel/sched/core.c:4963 activate_task(... ENQUEUE_NOCLOCK | ENQUEUE_INITIAL)
kernel/sched/core.c:4964 trace_sched_wakeup_new(p)
```

## Fork/Clone CapSched Rule

Fork or clone must create a new task identity. It must not inherit a live
FrozenRunUse or active RunToken from the parent.

Required rules:

```text
new child gets a fresh task generation
new process gets a fresh process generation unless it is an explicitly modeled
  thread sharing a process identity
Domain id is inherited only if SpawnCap authorizes same-Domain spawn
new Domain requires monitor-issued DomainToken, not clone flags alone
SchedContext inheritance is allowlist-only and must bind child generation
RunCap is not ambiently inherited
FrozenRunUse is never inherited
active RunToken is never inherited
```

Compatibility pressure:

```text
Linux expects clone/fork failures to happen before wake_up_new_task().
wake_up_new_task() has void enqueue-style behavior after TASK_RUNNING is
written. A fail-capable CapSched SpawnCap check should therefore happen before
the child is made runnable, or be modeled as a nofail assertion after all
non-rollback state mutations.
```

## Exec Source Spine

Exec enters through:

```text
fs/exec.c:1808 do_execveat_common()
fs/exec.c:1754 bprm_execve()
fs/exec.c:1758 prepare_bprm_creds(bprm)
fs/exec.c:1767 check_unsafe_exec(bprm)
fs/exec.c:1768 current->in_execve = 1
fs/exec.c:1769 sched_mm_cid_before_execve(current)
fs/exec.c:1771 sched_exec()
fs/exec.c:1774 security_bprm_creds_for_exec(bprm)
fs/exec.c:1778 exec_binprm(bprm)
fs/exec.c:1782 sched_mm_cid_after_execve(current)
fs/exec.c:1783 rseq_execve(current)
fs/exec.c:1785 current->in_execve = 0
```

Scheduler balancing on exec is:

```text
kernel/sched/core.c:5623 sched_exec()
kernel/sched/core.c:5629 lock current->pi_lock
kernel/sched/core.c:5630 select_task_rq(... WF_EXEC)
kernel/sched/core.c:5634 cpu_active(dest_cpu) check
kernel/sched/core.c:5639 stop_one_cpu(... migration_cpu_stop)
```

The point-of-no-return exec transition includes:

```text
fs/exec.c:1110 begin_new_exec()
fs/exec.c:1116 bprm_creds_from_file(bprm)
fs/exec.c:1126 trace_sched_prepare_exec(current, bprm)
fs/exec.c:1131 bprm->point_of_no_return = true
fs/exec.c:1134 de_thread(me)
fs/exec.c:1142 io_uring_task_cancel()
fs/exec.c:1145 unshare_files()
fs/exec.c:1154 set_mm_exe_file(...)
fs/exec.c:1167 exec_mmap(bprm)
fs/exec.c:842 exec_mmap()
fs/exec.c:857 exec_mm_release(tsk, old_mm)
fs/exec.c:859 down_write_killable(&tsk->signal->exec_update_lock)
fs/exec.c:1334 setup_new_exec()
fs/exec.c:1348 up_write(&me->signal->exec_update_lock)
fs/exec.c:1351-1354 release old mm
fs/exec.c:1360 finalize_exec()
fs/exec.c:1748 trace_sched_process_exec(current, old_pid, bprm)
```

## Exec CapSched Rule

Exec changes code, user `mm`, credentials within policy, file table sharing,
thread-group shape, and many userspace-visible identities.

Exec must not change:

```text
Domain id
Domain epoch
monitor identity
active MemoryView root except through an explicit Domain/MemoryView transition
SchedContext ownership
```

Open identity question:

```text
Should exec increment process_generation for scheduler RunCap validity?
```

Current answer for design pressure:

```text
Do not decide in code yet.
```

Two candidate semantics remain:

```text
Option A:
  exec increments an endpoint/process generation used by fd/object caps, but
  not the scheduler RunCap process generation. Current execution continues,
  and future enqueue uses the same Domain/SchedContext authority.

Option B:
  exec increments a scheduler-visible process generation and therefore requires
  an explicit current-exec revalidation rule so the currently running task does
  not violate "No valid generation, no execution" mid-exec.
```

Option B is stricter but needs a model for current execution revalidation.
Option A is simpler for scheduler compatibility but may be too weak for
exec-sensitive authority attenuation. No implementation should choose between
them until the endpoint/object capability model is cross-checked.

## Exit Source Spine

Exit enters:

```text
kernel/exit.c:924 do_exit()
kernel/exit.c:944 io_uring_files_cancel()
kernel/exit.c:945 sched_mm_cid_exit(tsk)
kernel/exit.c:946 exit_signals(tsk) sets PF_EXITING
kernel/exit.c:975 trace_sched_process_exit(tsk, group_dead)
kernel/exit.c:984 perf_event_exit_task(tsk)
kernel/exit.c:992 exit_mm()
kernel/exit.c:999 exit_files(tsk)
kernel/exit.c:1000 exit_fs(tsk)
kernel/exit.c:1003 exit_nsproxy_namespaces(tsk)
kernel/exit.c:1004 exit_task_work(tsk)
kernel/exit.c:1008 cgroup_task_exit(tsk)
kernel/exit.c:1040 preempt_disable()
kernel/exit.c:1043 exit_rcu()
kernel/exit.c:1047 do_task_dead()
```

Memory teardown includes:

```text
kernel/exit.c:576 exit_mm()
kernel/exit.c:580 exit_mm_release(current, mm)
kernel/exit.c:584 exit_mm_sched_cache(mm)
kernel/exit.c:601 smp_mb__after_spinlock()
kernel/exit.c:603 current->mm = NULL
kernel/exit.c:604 membarrier_update_current_mm(NULL)
kernel/exit.c:605 enter_lazy_tlb(mm, current)
kernel/exit.c:610 mmput(mm)
```

Final scheduler death is:

```text
kernel/sched/core.c:7244 do_task_dead()
kernel/sched/core.c:7247 set_special_state(TASK_DEAD)
kernel/sched/core.c:7252 __schedule(SM_NONE)
```

## Exit CapSched Rule

Self-exit does not require RunCap. It is current-task teardown, not runnable
submission.

Required exit invalidation:

```text
clear or invalidate FrozenRunUse
clear active RunToken
release or charge remaining SchedContext reservation according to policy
invalidate task generation
close endpoint uses tied to task identity
cancel or retag async work with caller provenance
leave audit evidence before mutable state disappears
```

External terminate is different:

```text
ThreadControlCap required for suspend/resume/terminate/inspect
RunCap must not imply terminate authority
SchedControlCap must not imply terminate authority
```

## Lifecycle Invariant Matrix

| Event | Domain id | Domain epoch | task generation | process generation | RunCap | FrozenRunUse | RunToken |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `fork` new process | inherited only with SpawnCap | unchanged | fresh child | fresh child | allowlist only | no inherit | no inherit |
| `clone` thread | inherited only with SpawnCap | unchanged | fresh thread | shared or fresh by semantic choice | allowlist only | no inherit | no inherit |
| new Domain | monitor token required | new epoch root | fresh | fresh | newly issued | no inherit | no inherit |
| `exec` | unchanged | unchanged | unchanged | open question | may need revalidation | open question | current token continues only if Domain/SchedContext remain valid |
| `exit` self | unchanged until dead | unchanged | invalidated/dead | group-dependent | invalid | invalid | cleared |
| external kill | unchanged until dead | unchanged | invalidated/dead on success | group-dependent | irrelevant | invalid | cleared |

## Proof Obligations

Future lifecycle work must prove:

```text
1. SpawnCap is checked before child runnable admission or after-mutation
   failure is proven nofail/rollback-safe.
2. Child task identity cannot reuse parent FrozenRunUse or active RunToken.
3. clone thread sharing does not imply capability table sharing unless
   explicitly authorized.
4. exec cannot switch Domain or SchedContext through credentials, binfmt, LSM,
   namespace, or file table side effects.
5. exec generation semantics are decided before endpoint caps depend on them.
6. exit clears active execution authority before task storage can be reused.
7. io_uring, task_work, workqueue, and kthread aftermath preserve provenance or
   are canceled/quarantined.
```

## Immediate Design Consequence

Fork/clone/exec/exit should not be modeled as scheduler details only.

They are authority lifetime events:

```text
fork/clone:
  identity mint plus attenuated authority issuance

exec:
  code/mm/cred replacement within stable Domain authority

exit:
  authority death plus async aftermath cleanup
```

This is why a future scheduler patch must be paired with lifecycle and async
provenance work before it can claim anything stronger than L0 prototype
behavior.
