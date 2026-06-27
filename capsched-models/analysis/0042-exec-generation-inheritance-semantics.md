# Analysis 0042: Exec Generation and Inherited Endpoint Semantics

Status: Draft exec boundary map with TLC-backed design filter

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

`analysis/0029` left an explicit open question:

```text
Should exec increment process_generation for scheduler RunCap validity?
```

`analysis/0041` then established that endpoint reachability is not endpoint
authority. This note resolves the exec side of that split:

```text
exec must not change CapSched Domain identity by default
exec must create a new program/process-generation authority boundary
old endpoint uses, async uses, mmap uses, and program-scoped authority must not
  survive as usable authority after successful exec
surviving fds are reachability and must be derived or attenuated for the new
  post-exec generation before endpoint effects
```

This is not an approval to patch exec code yet.

## Core Finding

Linux `execve()` preserves the task object and many fd references, but it
replaces or mutates enough identity-bearing state that CapSched must treat
successful exec as a generation boundary.

Relevant Linux facts:

```text
same task_struct continues
possibly non-leader task becomes thread-group leader and assumes the old TGID
old mm is replaced by a new mm
other threads are killed by de_thread()
io_uring task activity is canceled
file table sharing is broken by unshare_files()
CLOEXEC fds are closed by do_close_on_exec()
credentials may change through bprm hooks and commit_creds()
self_exec_id is incremented
task namespaces may change for time namespaces
rseq, mm cid, NUMA state, membarrier state, and signal handlers are reset
```

Therefore CapSched needs two distinct notions:

```text
DomainGeneration:
  Domain id and Domain epoch. Exec does not change this unless an explicit
  DomainTransitionCap and monitor-issued token are present.

ProgramGeneration:
  exec-sensitive identity for endpoint, notification, async, mmap, and
  process-image-scoped authority. Successful exec increments this generation.
```

The scheduler-visible task can continue only through an explicit
`ExecContinuation` rule:

```text
same Domain
same or explicitly revalidated SchedContext
fresh ProgramGeneration installed
old FrozenRunUse not reused as post-exec endpoint authority
selected/running state refreshed or still justified by current execution
```

This avoids both extremes:

```text
too weak:
  exec preserves all old endpoint and async authority because the task pointer
  is the same

too strong:
  exec invalidates the current running task with no current-exec continuation
  rule, making normal Linux exec impossible
```

## Source Anchors

### Exec entry and balancing

```text
fs/exec.c:1754 bprm_execve()
fs/exec.c:1758 prepare_bprm_creds()
fs/exec.c:1767 check_unsafe_exec()
fs/exec.c:1768 current->in_execve = 1
fs/exec.c:1769 sched_mm_cid_before_execve(current)
fs/exec.c:1771 sched_exec()
fs/exec.c:1774 security_bprm_creds_for_exec()
fs/exec.c:1778 exec_binprm()
fs/exec.c:1782 sched_mm_cid_after_execve(current)
fs/exec.c:1783 rseq_execve(current)
fs/exec.c:1785 current->in_execve = 0
```

`sched_exec()` is a placement opportunity:

```text
kernel/sched/core.c:5623 sched_exec()
kernel/sched/core.c:5629 p->pi_lock
kernel/sched/core.c:5630 class select_task_rq(... WF_EXEC)
kernel/sched/core.c:5634 cpu_active(dest_cpu)
kernel/sched/core.c:5639 stop_one_cpu(... migration_cpu_stop)
```

CapSched implication:

```text
sched_exec() may move the task for Linux placement reasons, but it cannot expand
FrozenRunUse.allowed_cpus or bypass PlacementEpoch checks.
```

### Point of no return

```text
fs/exec.c:1110 begin_new_exec()
fs/exec.c:1116 bprm_creds_from_file()
fs/exec.c:1126 trace_sched_prepare_exec()
fs/exec.c:1131 bprm->point_of_no_return = true
fs/exec.c:1134 de_thread(me)
```

`begin_new_exec()` is the semantic boundary. Before this point, exec may fail
and return to the old program. After this point, errors are fatal or lead to
SIGSEGV. CapSched must not increment ProgramGeneration or revoke old userspace
authority for `AT_EXECVE_CHECK` or pre-commit failures.

Once point-of-no-return is reached, the task is being transformed and old
program-scoped authority must be treated as dying.

### Thread-group identity

```text
fs/exec.c:919 de_thread()
fs/exec.c:941 sig->group_exec_task = tsk
fs/exec.c:942 zap_other_threads(tsk)
fs/exec.c:961 non-leader exec waits for leader
fs/exec.c:1006 exchange_tids(tsk, leader)
fs/exec.c:1007 transfer_pid(leader, tsk, PIDTYPE_TGID)
fs/exec.c:1014 tsk->group_leader = tsk
fs/exec.c:1039 comment: changed execution domain
```

CapSched implication:

```text
PID/TGID cannot be the root task identity.
```

A non-leader `execve()` can assume the old leader's externally visible TGID.
CapSched task identity should therefore use `task_struct` plus
`task_generation`, while process-image authority uses a separate
`program_generation` that increments on successful exec.

### mm replacement and memory authority

```text
fs/exec.c:842 exec_mmap()
fs/exec.c:857 exec_mm_release(tsk, old_mm)
fs/exec.c:859 down_write_killable(&tsk->signal->exec_update_lock)
fs/exec.c:876 task_lock(tsk)
fs/exec.c:881-882 tsk->active_mm = mm; tsk->mm = mm
fs/exec.c:884 task_exec_state_replace(tsk, exec_state)
fs/exec.c:894 activate_mm(active_mm, mm)
fs/exec.c:904 bprm->old_mm = old_mm
```

Related resets:

```text
kernel/sched/membarrier.c:249 membarrier_exec_mmap()
kernel/sched/core.c:11122 sched_mm_cid_before_execve()
kernel/sched/core.c:11128 sched_mm_cid_after_execve()
include/linux/rseq.h:140 rseq_execve()
```

CapSched implication:

```text
old MmapCap and old user-memory mappings do not survive exec.
```

New executable mappings, interpreter mappings, stack, and auxiliary pages need
new post-exec MemoryView semantics. In L0 this is only a model boundary; in
CapSched-H it becomes a Monitor MemoryView and page-ownership boundary.

### io_uring and async authority

```text
fs/exec.c:1140-1142 io_uring_task_cancel()
include/linux/io_uring.h:22 io_uring_task_cancel()
kernel/task_work.c:193-200 task_work_run()
kernel/task_work.c:231-234 work->func(work)
```

Linux explicitly cancels io_uring task activity across exec. Generic task_work
does not become caller authority just because the same task survives.

CapSched implication:

```text
old program async work cannot run post-exec under old FrozenEndpointUse.
```

Any task_work, io_uring, worker, notification, or endpoint operation that
continues after exec must be generation-checked or derived for the new
ProgramGeneration. This is the same design family as `self_exec_id` checks in
existing Linux notification paths.

### file table unshare and close-on-exec

```text
fs/exec.c:1144-1145 unshare_files()
kernel/fork.c:3351 unshare_files()
fs/exec.c:1200-1205 do_close_on_exec(me->files)
fs/file.c:890 do_close_on_exec()
fs/file.c:906 clears close_on_exec bits
fs/file.c:914 removes fd from table
fs/file.c:917 filp_close(file, files)
```

Fork file inheritance is:

```text
kernel/fork.c:1637 copy_files()
kernel/fork.c:1654 CLONE_FILES shares files_struct
kernel/fork.c:1659 dup_fd(oldf, NULL)
```

CapSched implication:

```text
surviving fd != surviving authority.
```

After successful exec:

```text
CLOEXEC fd:
  must not retain EndpointBasis or FrozenEndpointUse as usable authority

non-CLOEXEC fd:
  may remain reachable, but post-exec endpoint effects require a derived or
  attenuated endpoint authority bound to the new ProgramGeneration

shared files_struct:
  is broken by unshare_files(), so post-exec endpoint metadata must not rely on
  shared pre-exec files_struct authority
```

### credentials and LSM domain transitions

```text
fs/exec.c:1375 prepare_bprm_creds()
kernel/cred.c:230 prepare_exec_creds()
fs/exec.c:1613 bprm_creds_from_file()
security/security.c:777 security_bprm_creds_for_exec()
security/security.c:801 security_bprm_creds_from_file()
security/security.c:835 security_bprm_committing_creds()
fs/exec.c:1274 commit_creds(bprm->cred)
security/security.c:851 security_bprm_committed_creds()
```

Linux capabilities and setid behavior can change credential authority:

```text
security/commoncap.c:919 cap_bprm_creds_from_file()
security/commoncap.c:950 handles id/capability gain under unsafe/no_new_privs
security/commoncap.c:966 file caps or setid clears ambient capabilities
security/commoncap.c:999 marks privilege-elevated exec secureexec
```

SELinux already treats exec credential transitions as a point to close or reset
state:

```text
security/selinux/hooks.c:2518 selinux_bprm_committing_creds()
security/selinux/hooks.c:2528 flush_unauthorized_files(bprm->cred,
  current->files)
security/selinux/hooks.c:2564 selinux_bprm_committed_creds()
```

CapSched implication:

```text
LSM domain and Linux credential changes are policy inputs for post-exec
derivation and attenuation, not automatic CapSched Domain changes.
```

If a future design wants exec to move a task to another CapSched Domain, it must
use an explicit:

```text
DomainTransitionCap
Monitor-issued DomainToken
new MemoryView
new root budget/SchedContext authorization
explicit endpoint re-derivation
```

Without that, exec leaves CapSched Domain identity stable and only changes
program-generation and endpoint authority.

### self_exec_id as existing generation evidence

```text
fs/exec.c:1262 WRITE_ONCE(me->self_exec_id, me->self_exec_id + 1)
kernel/fork.c:2448 child parent_exec_id = current->self_exec_id
kernel/signal.c:2191 compare parent_exec_id with parent->self_exec_id
ipc/mqueue.c:1360 notify_self_exec_id = current->self_exec_id
ipc/mqueue.c:816 require task->self_exec_id match before sending signal
```

Linux already uses `self_exec_id` to avoid delivering stale notifications to a
different program image. CapSched should generalize this principle:

```text
old program generation must not authorize post-exec endpoint effects.
```

### execfd handoff

```text
fs/binfmt_misc.c:231 MISC_FMT_OPEN_BINARY sets bprm->have_execfd
fs/binfmt_misc.c:263 MISC_FMT_CREDENTIALS sets bprm->execfd_creds
fs/exec.c:1293-1298 FD_ADD(0, bprm->executable) passes opened binary to
  interpreter
fs/binfmt_elf.c:285 emits AT_EXECFD
```

CapSched implication:

```text
execfd is a derived endpoint handoff.
```

It is not ordinary ambient fd inheritance. The interpreter receives a specific
opened executable file as a new fd. CapSched must derive an endpoint authority
for the new ProgramGeneration and interpreter execution context.

### AT_EXECVE_CHECK

```text
fs/exec.c:768 do_open_execat()
fs/exec.c:780 accepts AT_EXECVE_CHECK
fs/exec.c:1472-1485 check-only path stops after security_bprm_creds_for_exec()
Documentation/userspace-api/check_exec.rst:36 check only, no execution
Documentation/userspace-api/check_exec.rst:60 recommends fd-based checks to
  avoid TOCTOU
```

CapSched implication:

```text
AT_EXECVE_CHECK may validate executable policy and produce audit evidence, but
it must not increment ProgramGeneration, derive post-exec endpoint authority, or
consume an ExecContinuation.
```

It is a policy check, not an execution transition.

## Proposed Semantics

Successful exec creates:

```text
program_generation := program_generation + 1
old frozen endpoint uses := revoked
old async endpoint uses := canceled or generation-failed
old mmap uses := revoked
post-exec surviving fd bases := reachable but not yet operation authority
post-exec endpoint effects := require derived/attenuated FrozenEndpointUse
```

Successful exec preserves by default:

```text
CapSched Domain id
Domain epoch unless already revoked
monitor identity
SchedContext only if compatible with the same Domain and current task
task_generation of the continuing task_struct
```

Successful exec does not preserve:

```text
old program-generation endpoint effects
old task_work/worker authority
old mmap/page-fault authority
old credential-derived endpoint rights
old fd authority for CLOEXEC fds
old assumptions about PID/TGID as task identity
```

## Required Invariants

```text
NoExecDomainChangeWithoutToken:
  exec cannot change CapSched Domain unless an explicit DomainTransitionCap and
  monitor token are present.

NoRunAfterExecWithoutContinuation:
  the current task may continue after exec only with same-domain
  ExecContinuation, live SchedContext, and fresh ProgramGeneration.

NoOldEndpointUseAfterExec:
  old FrozenEndpointUse cannot authorize post-exec endpoint effects.

NoSurvivingFdWithoutDerivation:
  non-CLOEXEC fd reachability after exec must be derived or attenuated before
  endpoint effects.

NoCloseOnExecLeak:
  CLOEXEC endpoints must not remain usable after exec.

NoCredChangeEndpointAmplification:
  credential or LSM-domain changes cannot amplify inherited endpoints; they
  must attenuate, close, or explicitly derive them.

NoExecfdWithoutDerivation:
  execfd handoff to an interpreter requires a derived endpoint authority.

NoOldAsyncUseAfterExec:
  old program-generation async work cannot perform post-exec endpoint effects.

NoOldMmapAcrossExec:
  old mmap and page-fault authority cannot survive into the new program image.

NoCheckOnlyMutation:
  AT_EXECVE_CHECK must not mutate ProgramGeneration or derive post-exec
  authority.
```

## Design Consequences

Future implementation should not treat exec as either:

```text
ordinary continuation with all authorities intact
```

or:

```text
implicit Domain transition based on LSM label or executable path
```

The safer structure is:

```text
exec_prepare:
  check ExecCap/ExecEndpointCap for the executable and interpreter chain

exec_commit_generation:
  after point-of-no-return and before post-exec user execution, increment
  ProgramGeneration and revoke old program-scoped uses

exec_endpoint_inherit:
  for each surviving fd/resource, derive or attenuate endpoint authority for
  new ProgramGeneration using credentials, LSM policy, close-on-exec state,
  endpoint policy, and service Domain rules

exec_continuation:
  keep current task running only because same Domain, SchedContext, and
  ExecContinuation are valid

execfd_handoff:
  derive a specific endpoint authority for the interpreter-visible executable fd
```

## First Slice Implications

No Linux behavior-changing patch should be made yet. A later trace-only slice
could observe:

```text
trace_sched_prepare_exec
trace_sched_process_exec
begin_new_exec point-of-no-return
self_exec_id increment
do_close_on_exec result count
security_bprm_committing_creds/committed_creds
execfd insertion
io_uring_task_cancel
task_work still pending or generation-failed
```

For L0 type scaffolding, candidate names are:

```text
capsched_exec_continuation
capsched_program_generation
capsched_exec_endpoint_inherit
capsched_execfd_grant
capsched_exec_revoke_epoch
```

These names remain conceptual until a separate implementation gate is accepted.
