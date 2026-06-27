# Validation 0040: Post-Exec Resource QEMU Trace Result

Status: Executed observation-only validation

Date: 2026-06-27

Runner:

```text
capsched/capsched-models/validation/run-post-exec-resource-qemu-trace.sh
```

Workload:

```text
capsched/capsched-models/validation/workloads/post_exec_resource_workload.c
```

Related analysis:

```text
capsched/capsched-models/analysis/0044-post-exec-resource-trace-coverage-map.md
```

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
subject: sched/capsched: Add type-only authority scaffolding
```

## Result Summary

Final successful run:

```text
run directory:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/post-exec-resource-trace/20260627T100204Z

serial log:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/post-exec-resource-trace/20260627T100204Z/serial.log

counts:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/post-exec-resource-trace/20260627T100204Z/counts.tsv

classification:
  /media/nia/scsiusb/dev/linux-cap/build/qemu/post-exec-resource-trace/20260627T100204Z/classification.tsv
```

Outcome:

```text
qemu_status: 0
workload_ret: 0
kernel rebuild: no, reused existing QEMU bzImage
CONFIG_CAPSCHED: y
CONFIG_KPROBE_EVENTS: y
CONFIG_IO_URING: y
CONFIG_EVENTFD: y
CONFIG_EPOLL: y
```

An earlier run at `20260627T095741Z` was intentionally discarded after it
exposed a workload bug: the listen/accept case used AF_INET loopback, but the
minimal initramfs did not configure `lo`, causing the accept test to block. The
workload was changed to AF_UNIX listen/accept so the trace is independent of
guest network setup.

## Workload Markers

The final run reached the post-exec marker and completed every implemented
class operation:

```text
CAPSCHED_POSTEXEC_BEGIN
CAPSCHED_POSTEXEC_RESULT epoll wait ret=1 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT regular read ret=16 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT regular write ret=1 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT regular mmap ret=0 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT regular ioctl ret=0 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT opath read ret=-1 errno=9 status=expected_fail
CAPSCHED_POSTEXEC_RESULT cloexec read ret=-1 errno=9 status=expected_fail
CAPSCHED_POSTEXEC_RESULT socket recv_preexec ret=3 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT socket send_postexec ret=4 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT socket recv_postexec ret=4 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT socket accept ret=3 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT eventfd read ret=8 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT eventfd write ret=8 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT timerfd read ret=8 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT timerfd settime ret=0 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT io_uring unregister_files ret=0 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT io_uring enter ret=0 errno=0 status=ok
CAPSCHED_POSTEXEC_RESULT execfd binfmt_misc ret=-1 errno=38 status=not_observed
CAPSCHED_POSTEXEC_END
```

## Event Counts

Important tracepoint counts:

```text
raw_syscalls/sys_enter: 166
raw_syscalls/sys_exit: 166
sched/sched_prepare_exec: 2
sched/sched_process_exec: 2
io_uring/io_uring_create: 1
io_uring/io_uring_register: 2
io_uring/io_uring_file_get: 0
io_uring/io_uring_submit_req: 0
io_uring/io_uring_queue_async_work: 0
io_uring/io_uring_task_work_run: 0
io_uring/io_uring_complete: 0
workqueue/workqueue_queue_work: 1
workqueue/workqueue_execute_start: 1
workqueue/workqueue_execute_end: 0
sock/sock_send_length: 3
sock/sock_recv_length: 3
sock/sk_data_ready: 4
```

Important kprobe counts:

```text
do_close_on_exec: 2
file_close_fd_locked: 6
filp_close: 28
fd_install: 16
do_dentry_open: 10
vfs_read: 12
vfs_write: 38
do_vfs_ioctl: 3
security_mmap_file: 31
sock_alloc_file: 5
do_accept: 1
sock_recvmsg: 3
anon_inode_getfile: 1
anon_inode_getfile_fmode: 2
anon_inode_create_getfile: 1
eventfd_signal_mask: 0
eventfd_read: 1
eventfd_write: 1
timerfd_read_iter: 1
do_timerfd_settime: 2
do_epoll_ctl_file: 1
io_sqe_files_register: 1
load_misc_binary: 2
```

Kprobe limitations observed:

```text
ep_insert:
  KPROBE_ADD_FAILED, Invalid argument

ep_poll:
  KPROBE_ADD_FAILED, Invalid argument

io_file_get_fixed:
  KPROBE_ADD_FAILED; kernel reported notrace function
```

## Classifications

The generated classification is intentionally conservative:

| Class | Classification | Meaning |
| --- | --- | --- |
| CLOEXEC fd | observed | post-exec EBADF plus `do_close_on_exec` observed |
| Regular file | observed | read/write/mmap/ioctl surface plus VFS probes observed |
| O_PATH | observed | inherited O_PATH fd rejected read as expected |
| Socket | observed | socketpair send/recv and AF_UNIX listen/accept observed |
| Anonymous fd | observed | anon inode creation observed for eventfd/timerfd/epoll/io_uring classes |
| eventfd | partially_observed | read/write observed; kernel-held `eventfd_signal_mask` did not fire |
| timerfd | observed | post-exec read and settime observed |
| epoll | partially_observed | `epoll_wait` returned readiness; `ep_insert`/`ep_poll` probes were unavailable |
| io_uring | partially_observed | ring create/register/unregister/enter observed; fixed-file request consumption not observed |
| execfd | not_observed | binfmt_misc execfd workload not included |

## Validation Meaning

This validation supports only an observation claim:

```text
The QEMU trace harness can drive and observe several post-exec resource
inheritance classes without changing Linux behavior.
```

It does not prove:

```text
post-exec endpoint authority is protected.
endpoint authority is derived correctly.
eventfd kernel signal provenance is covered.
epoll watched endpoint delivery is internally correlated.
io_uring fixed-file consumption is covered.
execfd handoff is covered.
```

## Consequence

Before any behavior-changing exec endpoint hook, the remaining observation gaps
are:

```text
1. eventfd kernel-held signal provenance.
2. epoll internal delivery and watched endpoint correlation.
3. io_uring fixed-file request consumption after exec.
4. execfd handoff through binfmt_misc.
```

The next step should refine those gaps with narrower workloads, better argument
capture, or a CONFIG_CAPSCHED observation-only patch. It should not yet enforce
post-exec endpoint authority.
