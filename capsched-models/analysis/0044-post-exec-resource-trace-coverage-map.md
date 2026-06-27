# Analysis 0044: Post-Exec Resource Trace-Only Coverage Map

Status: Draft coverage map, no enforcement approved

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

Related model:

```text
capsched/capsched-models/analysis/0043-post-exec-resource-inheritance-classes.md
capsched/capsched-models/formal/0026-post-exec-resource-inheritance-model/PostExecResource.tla
```

## Purpose

`analysis/0043` classified post-exec resource inheritance:

```text
post-exec fd reachability is not endpoint authority.
each surviving resource class requires class-specific derivation or attenuation.
```

This note maps which parts of that rule can be observed with existing
tracepoints, raw syscall tracing, dynamic ftrace, and kprobes before any
behavior-changing exec endpoint hook is considered.

This is a coverage map, not an implementation plan.

## Core Finding

Existing tracing is useful but incomplete:

```text
raw_syscalls:
  sees syscall numbers, arguments, and returns, including fd numbers

sched exec tracepoints:
  mark the exec boundary before and after process-image replacement

io_uring tracepoints:
  expose ring creation, registration, request submission, fixed-file gets,
  async queueing, task_work, and completion

workqueue tracepoints:
  expose generic worker queue/execute lifecycle, but not caller authority

kprobes:
  can observe many internal file/socket/anon/eventfd/timerfd/epoll/io_uring
  functions in the QEMU validation build
```

The gap is semantic:

```text
trace-only observation can show that a path was reached.
it cannot prove that endpoint authority was correctly derived.
```

The goal of N-060 is therefore:

```text
determine whether future CapSched hooks would see all relevant post-exec
resource classes and identify where trace-only evidence is insufficient.
```

## Internal Redesign Boundary

The answer to "why not just redesign the internal async substrate completely?"
is:

```text
yes, the production async substrate may need deep internal redesign;
no, internal redesign alone cannot replace typed caller provenance.
```

The reason is the workqueue merge and context-loss property already recorded in
`analysis/0034` and `analysis/0041`:

```text
queue_work() returns false if the same work_struct is already pending.
worker execution enters worker->current_func(work) or work->func(work) in a
kworker/kthread context.
```

So an internal async substrate is safe only if it preserves work classes:

```text
KernelCoreWork:
  audited internal authority, no caller-attributed endpoint effect

ServiceMaintenanceWork:
  service authority only

DomainRequestWork:
  caller Domain, caller epoch, FrozenEndpointUse, BudgetTicket, service Domain,
  work generation, revoke epoch

MergedDomainBatchWork:
  explicit merge, accounting, cancellation, and settlement semantics
```

If these classes collapse into ambient worker authority, the design becomes
unprovable for hostile-Domain isolation.

## Trace Primitives

### Raw syscall tracepoints

Source:

```text
include/trace/events/syscalls.h:18 sys_enter
include/trace/events/syscalls.h:24-27 syscall id plus six args
include/trace/events/syscalls.h:44 sys_exit
include/trace/events/syscalls.h:50-53 syscall id plus return value
kernel/entry/syscall-common.c:10 trace_syscall_enter()
kernel/entry/syscall-common.c:20 trace_syscall_exit()
```

Use:

```text
observe fd-level surface operations before and after exec.
```

Limit:

```text
does not identify f_op, private_data, socket state, epoll watched endpoint,
registered io_uring resource, or CapSched authority class.
```

### Exec tracepoints

Source:

```text
fs/exec.c:1126 trace_sched_prepare_exec(current, bprm)
include/trace/events/sched.h:458 sched_prepare_exec
include/trace/events/sched.h:464-480 interp, filename, pid, comm
fs/exec.c:1748 trace_sched_process_exec(current, old_pid, bprm)
include/trace/events/sched.h:424 sched_process_exec
include/trace/events/sched.h:431-444 filename, pid, old_pid
```

Use:

```text
bracket the ProgramGeneration transition.
```

Important ordering:

```text
fs/exec.c:1126 sched_prepare_exec
fs/exec.c:1142 io_uring_task_cancel()
fs/exec.c:1145 unshare_files()
fs/exec.c:1205 do_close_on_exec()
fs/exec.c:1748 sched_process_exec
```

### io_uring tracepoints

Source:

```text
include/trace/events/io_uring.h:27 io_uring_create
include/trace/events/io_uring.h:69 io_uring_register
include/trace/events/io_uring.h:108 io_uring_file_get
include/trace/events/io_uring.h:140 io_uring_queue_async_work
include/trace/events/io_uring.h:321 io_uring_complete
include/trace/events/io_uring.h:364 io_uring_submit_req
include/trace/events/io_uring.h:601 io_uring_task_work_run
io_uring/io_uring.c:432 trace_io_uring_queue_async_work()
io_uring/io_uring.c:1594 trace_io_uring_file_get()
io_uring/io_uring.c:1899 trace_io_uring_submit_req()
io_uring/io_uring.c:3091 trace_io_uring_create()
io_uring/register.c:1042 trace_io_uring_register()
io_uring/tw.c:124 trace_io_uring_task_work_run()
```

Use:

```text
observe ring creation, resource registration, fixed file use, request
submission, async worker transition, task_work, and completion.
```

Limit:

```text
does not by itself prove registered resource authority was re-derived after
exec.
```

### workqueue tracepoints

Source:

```text
include/trace/events/workqueue.h:23 workqueue_queue_work
include/trace/events/workqueue.h:59 workqueue_activate_work
include/trace/events/workqueue.h:84 workqueue_execute_start
include/trace/events/workqueue.h:110 workqueue_execute_end
kernel/workqueue.c:2383 trace_workqueue_queue_work()
kernel/workqueue.c:3321 trace_workqueue_execute_start()
kernel/workqueue.c:3327 trace_workqueue_execute_end()
```

Use:

```text
show when generic worker execution occurs.
```

Limit:

```text
does not carry caller Domain, FrozenEndpointUse, or BudgetTicket.
```

### Socket tracepoints

Source:

```text
include/trace/events/sock.h:140 inet_sock_set_state
include/trace/events/sock.h:240 sk_data_ready
include/trace/events/sock.h:298 sock_send_length
include/trace/events/sock.h:304 sock_recv_length
net/socket.c:780 trace_sock_send_length_enabled()
net/socket.c:1130 trace_sock_recv_length_enabled()
```

Use:

```text
observe socket state transitions and send/recv effects.
```

Limit:

```text
does not identify post-exec authority derivation or accepted-socket capability.
```

## QEMU Build Eligibility Snapshot

The existing QEMU validation config has the tracing features required for this
coverage pass:

```text
CONFIG_TRACEPOINTS=y
CONFIG_HAVE_SYSCALL_TRACEPOINTS=y
CONFIG_FTRACE=y
CONFIG_FUNCTION_TRACER=y
CONFIG_DYNAMIC_FTRACE=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
```

The same config enables the relevant subsystems:

```text
CONFIG_EPOLL=y
CONFIG_EVENTFD=y
CONFIG_IO_URING=y
CONFIG_BINFMT_MISC=y
```

Representative kprobe-visible symbols in the QEMU build:

```text
do_dentry_open
vfs_read
vfs_write
do_vfs_ioctl
do_close_on_exec
file_close_fd_locked
filp_close
fd_install
do_epoll_ctl_file
anon_inode_getfile
anon_inode_getfile_fmode
anon_inode_create_getfile
__anon_inode_getfd
timerfd_read_iter
do_timerfd_settime
eventfd_signal_mask
eventfd_read
eventfd_write
security_mmap_file
io_file_get_fixed
io_sqe_files_register
sock_alloc_file
sock_recvmsg
do_accept
load_misc_binary
```

Representative gaps or config-dependent targets:

```text
sock_sendmsg_nosec:
  inline in source; use sock_send_length tracepoint and __sock_sendmsg source
  adjacency instead of assuming a stable kprobe symbol

timerfd_ioctl:
  depends on CONFIG_CHECKPOINT_RESTORE

create_elf_tables:
  source-level execfd anchor; symbol visibility is build/config dependent
```

## Phase Model

Trace-only coverage should be organized by phase:

```text
P0 pre-exec setup:
  resource creation, fd flags, registrations, epoll watches, pending readiness

P1 exec boundary:
  sched_prepare_exec, io_uring_task_cancel, unshare_files, do_close_on_exec

P2 post-exec reachability:
  first syscall/use of inherited fd or class object in the new program image

P3 post-exec endpoint effect:
  read/write/send/recv/accept/mmap/ioctl/epoll_wait/eventfd/timerfd/io_uring
  effect after sched_process_exec

P4 async effect:
  worker, task_work, eventfd signal, socket readiness, epoll delivery, or
  io_uring completion after exec
```

The important edge is:

```text
P2 reachability must not be mistaken for P3 authority.
```

## Coverage Table

| Class | Existing surface observation | Internal trace/kprobe candidates | Blind spot |
| --- | --- | --- | --- |
| CLOEXEC fd | `execve`, `fcntl`, `close_range`, post-exec fd use failure | `do_close_on_exec`, `file_close_fd_locked`, `filp_close` | per-fd close-on-exec classification may require argument capture or later observation patch |
| Regular file | `openat/openat2`, `read/write`, `ioctl`, `mmap` syscalls | `do_dentry_open`, `vfs_read`, `vfs_write`, `do_vfs_ioctl`, `security_mmap_file` | raw syscall fd does not expose `f_mode`, `f_flags`, or file generation |
| O_PATH | `openat/openat2` flags, failed read/write/mmap attempts | `do_dentry_open`, `security_mmap_file` | path-only authority must be inferred from flags unless an internal observation point records file mode |
| Socket | `socket`, `connect`, `listen`, `accept`, `send`, `recv` syscalls | `sock_alloc_file`, `do_accept`, `sock_send_length`, `sock_recv_length`, `inet_sock_set_state` | send/recv effect visibility does not prove operation-specific post-exec derivation |
| Anonymous fd | class-specific creation syscalls for known classes | `anon_inode_getfile`, `anon_inode_getfile_fmode`, `anon_inode_create_getfile`, `__anon_inode_getfd` | generic anon class identity may require fops/private_data observation |
| eventfd | `eventfd2`, `read`, `write`, `poll/epoll_wait` | `eventfd_read`, `eventfd_write`, `eventfd_signal_mask`, `eventfd_ctx_fileget` | kernel-held `eventfd_ctx` signal provenance may be outside syscall traces |
| timerfd | `timerfd_create`, `timerfd_settime`, `timerfd_gettime`, `read` | `timerfd_read_iter`, `do_timerfd_settime`, `timerfd_ioctl` if enabled | old timer state survival is visible, but authority derivation is not |
| epoll | `epoll_create`, `epoll_ctl`, `epoll_wait` | `do_epoll_ctl_file`, `ep_insert`, `ep_poll` | delivered readiness needs watched endpoint correlation, not just epoll fd observation |
| io_uring | `io_uring_setup`, `io_uring_register`, `io_uring_enter` | built-in io_uring tracepoints, `io_sqe_files_register`, `io_file_get_fixed` | post-exec ring reachability does not prove registered file/buffer invalidation or revalidation |
| execfd | `execve/execveat`, `binfmt_misc` setup, auxv effect | `load_misc_binary`, `create_elf_tables` if visible, `fd_install` near `bprm->execfd` | requires binfmt_misc workload and may need a narrow observation patch to distinguish execfd from ordinary fd install |

## Workload Coverage Requirements

The future trace workload should use a parent process that creates resources,
marks selected fds close-on-exec or non-close-on-exec, then execs a helper that
attempts class-specific post-exec effects.

Minimum workload classes:

```text
regular file:
  non-CLOEXEC read/write fd
  O_PATH fd
  mmap attempt
  ioctl attempt on a harmless target if available

socket:
  socketpair or loopback TCP connected socket
  listening socket plus post-exec accept
  post-exec send and recv

anonymous fd:
  eventfd
  timerfd
  epoll

epoll:
  watched endpoint created pre-exec
  readiness made pending before exec
  epoll_wait after exec

io_uring:
  ring created pre-exec
  fd flags changed if needed so the ring survives exec
  registered file before exec
  submit or enter after exec

execfd:
  optional binfmt_misc workload, because it requires guest setup
```

The helper must print stable markers:

```text
CAPSCHED_POSTEXEC_BEGIN
CAPSCHED_POSTEXEC_CLASS <class> <operation> <expected>
CAPSCHED_POSTEXEC_RESULT <class> <operation> <ret> <errno>
CAPSCHED_POSTEXEC_END
```

Trace analysis should classify each class as:

```text
observed:
  trace shows setup, exec boundary, and post-exec effect

partially_observed:
  syscall surface observed, but class identity or internal object relation is
  missing

not_observed:
  workload did not reach the path

not_trace_provable:
  trace-only evidence cannot establish the needed semantic relation
```

## Decisions Before Enforcement

No behavior-changing exec endpoint hook is justified until the project has:

```text
1. trace evidence for the class under a post-exec workload,
2. a source-level explanation for every blind spot,
3. a decision whether the class can use existing observation/hook points,
4. or a narrow CONFIG_CAPSCHED internal observation patch proposal.
```

Trace-only evidence is enough to choose where to inspect next. It is not enough
to claim:

```text
post-exec endpoint authority is protected.
```

## Consequence

The next implementation-facing step should still be observation-only:

```text
build a QEMU post-exec resource trace workload and runner extension.
```

If existing tracepoints and kprobes cannot distinguish a required class, the
proper next step is a small internal observation patch, not enforcement.
