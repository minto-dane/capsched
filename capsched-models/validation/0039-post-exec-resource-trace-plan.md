# Validation 0039: Post-Exec Resource Trace-Only Plan

Status: Planned and implemented; first result recorded in validation 0040

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0044-post-exec-resource-trace-coverage-map.md
```

## Purpose

Plan a QEMU trace-only run for post-exec resource inheritance classes before
any behavior-changing exec endpoint enforcement hook.

This validation is intended to answer:

```text
Can existing tracepoints, raw syscall tracing, and kprobes observe the setup,
exec boundary, and post-exec effects for each resource class?
```

It must not be used to claim that protection exists.

## Required Trace Features

The QEMU validation kernel should enable:

```text
CONFIG_TRACEPOINTS=y
CONFIG_HAVE_SYSCALL_TRACEPOINTS=y
CONFIG_FTRACE=y
CONFIG_FUNCTION_TRACER=y
CONFIG_DYNAMIC_FTRACE=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_EPOLL=y
CONFIG_EVENTFD=y
CONFIG_IO_URING=y
CONFIG_BINFMT_MISC=y
```

## Event Set

Enable these tracepoint groups where available:

```text
raw_syscalls/sys_enter
raw_syscalls/sys_exit
sched/sched_prepare_exec
sched/sched_process_exec
io_uring/io_uring_create
io_uring/io_uring_register
io_uring/io_uring_file_get
io_uring/io_uring_submit_req
io_uring/io_uring_queue_async_work
io_uring/io_uring_task_work_run
io_uring/io_uring_complete
workqueue/workqueue_queue_work
workqueue/workqueue_execute_start
workqueue/workqueue_execute_end
sock/inet_sock_set_state
sock/sock_send_length
sock/sock_recv_length
sock/sk_data_ready
```

Missing events must be recorded explicitly.

## Kprobe Candidate Set

Attempt these probes where the build exposes a symbol:

```text
do_close_on_exec
file_close_fd_locked
filp_close
fd_install
do_dentry_open
vfs_read
vfs_write
do_vfs_ioctl
security_mmap_file
sock_alloc_file
do_accept
sock_recvmsg
anon_inode_getfile
anon_inode_getfile_fmode
anon_inode_create_getfile
__anon_inode_getfd
eventfd_signal_mask
eventfd_read
eventfd_write
timerfd_read_iter
do_timerfd_settime
do_epoll_ctl_file
ep_insert
ep_poll
io_sqe_files_register
io_file_get_fixed
load_misc_binary
```

Probe add failures are data, not validation failure. They should be classified
as:

```text
missing symbol
not kprobeable
config disabled
argument capture unsupported by current harness
```

## Workload Plan

The future helper should create pre-exec resources, then exec a second program
image that attempts post-exec effects:

```text
regular:
  read/write/mmap/ioctl attempts on inherited regular fd

opath:
  O_PATH inherited fd plus failed read/write/mmap attempts

socket:
  inherited socketpair or TCP socket send/recv
  inherited listening socket accept

eventfd:
  pending count before exec, post-exec read/write, optional kernel signal path

timerfd:
  armed timer before exec, post-exec read and settime

epoll:
  watched endpoint and pending readiness before exec, post-exec epoll_wait

io_uring:
  ring created and registered file before exec, ring fd kept non-CLOEXEC,
  post-exec enter/register/submit attempt

execfd:
  optional binfmt_misc OPEN_BINARY workload
```

## Expected Output Classification

For each class, the result record should classify:

```text
observed:
  setup, exec boundary, and post-exec use are visible

partially_observed:
  fd/syscall surface is visible but class identity or object relation is not

not_observed:
  workload did not reach the class

not_trace_provable:
  trace-only cannot establish the semantic relation
```

## Pass Criteria

This validation passes only as an observation run if:

```text
the runner boots the CapSched QEMU kernel,
tracefs is writable,
available/missing events are recorded,
available/missing kprobes are recorded,
the workload prints begin/end markers,
and each resource class receives an explicit classification.
```

It does not pass or fail the security design.

## Follow-up Rule

If a class is `not_trace_provable`, the next step is not enforcement. The next
step is either:

```text
1. a narrower workload or kprobe argument capture improvement, or
2. a CONFIG_CAPSCHED internal observation-only patch proposal.
```

## Prepared Artifacts

The planned runner and workload are:

```text
capsched/capsched-models/validation/run-post-exec-resource-qemu-trace.sh
capsched/capsched-models/validation/workloads/post_exec_resource_workload.c
```

The runner is intended to reuse an existing QEMU `bzImage` by default. Set
`CAPSCHED_POSTEXEC_QEMU_REBUILD=1` only when a fresh kernel build is required.

First execution result:

```text
capsched/capsched-models/validation/0040-post-exec-resource-qemu-trace-result.md
```
