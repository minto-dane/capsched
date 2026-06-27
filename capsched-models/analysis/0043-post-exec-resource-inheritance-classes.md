# Analysis 0043: Post-Exec Resource Inheritance Classes

Status: Draft inheritance-class map with TLC-backed design filter

Date: 2026-06-27

Linux source:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 7cf0b1e415bcead8a2079c8be94a9d41aad7d462
```

## Purpose

`analysis/0042` established the exec rule:

```text
successful exec preserves CapSched Domain by default, but creates a new
ProgramGeneration boundary for endpoint, async, mmap, notification, and
process-image-scoped authority.
```

This note classifies post-exec fd/resource inheritance before any exec endpoint
hook implementation.

The central question is:

```text
If a file descriptor remains reachable after exec, what endpoint authority is
allowed to remain or be re-derived?
```

The answer is not one rule. The resource class matters.

## Core Finding

Linux fd inheritance is intentionally generic:

```text
non-CLOEXEC fd remains reachable
CLOEXEC fd is removed by do_close_on_exec()
file pointer, f_op, f_mode, private_data, and subsystem state define behavior
```

CapSched cannot map all surviving fds to a single inherited `EndpointCap`.

Post-exec derivation must be class-specific:

```text
RegularFileInherit
SocketInherit
AnonFdInherit
EventfdInherit
TimerfdInherit
EpollInherit
IoUringInherit
ExecfdHandoff
```

Each class has different operation sets, state hazards, revoke rules, and
confused-deputy risks.

## Source Anchors

### Generic fd survival and close-on-exec

```text
fs/exec.c:1144-1145 unshare_files()
fs/exec.c:1200-1205 do_close_on_exec(me->files)
fs/file.c:890 do_close_on_exec()
fs/file.c:906 clears close_on_exec bits
fs/file.c:914 rcu_assign_pointer(fdt->fd[fd], NULL)
fs/file.c:917 filp_close(file, files)
```

Rule:

```text
CLOEXEC:
  no post-exec endpoint reachability and no post-exec endpoint authority

non-CLOEXEC:
  fd reachability survives, but endpoint authority must be re-derived or
  attenuated for the new ProgramGeneration
```

The generic fd table answers "can this file be found?" It does not answer
"which post-exec operations are authorized?"

## Class 1: Regular Files and Path-Backed Files

Relevant Linux shape:

```text
fs/open.c:898 O_PATH sets FMODE_PATH
fs/open.c:924 do_dentry_open() calls security_file_open()
fs/open.c:952-957 sets FMODE_CAN_READ/FM0DE_CAN_WRITE based on f_op
fs/read_write.c:554 vfs_read()
fs/read_write.c:667 vfs_write()
fs/ioctl.c:583 sys_ioctl()
mm/mmap.c:1143 security_mmap_file()
```

Post-exec derivation:

```text
RegularFileInherit:
  object identity/generation
  new ProgramGeneration
  new cred/LSM policy result
  f_mode/f_flags operation envelope
  operation class: read, write, seek, ioctl, mmap, exec-check, metadata
```

Important distinctions:

```text
O_PATH:
  path reachability only; no ordinary read/write authority

read/write:
  operation-specific FrozenEndpointUse

ioctl:
  typed command authority

mmap:
  MmapCap and MemoryView consequences
```

Rejected rule:

```text
if fd survived exec, allow every file operation that f_op exposes
```

## Class 2: Sockets

Relevant Linux shape:

```text
net/socket.c:525 sock_alloc_file()
net/socket.c:532 alloc_file_pseudo(..., &socket_file_ops)
net/socket.c:541 sock->file = file
net/socket.c:542 file->private_data = sock
net/socket.c:773 sock_sendmsg_nosec()
net/socket.c:785 __sock_sendmsg()
net/socket.c:1123 sock_recvmsg_nosec()
net/socket.c:1997 do_accept()
net/socket.c:2025 accepted socket gets a new file
net/socket.c:2029 security_socket_accept()
net/socket.c:2050 accepted socket file flags not inherited like other systems
```

Post-exec derivation:

```text
SocketInherit:
  socket object/generation
  net namespace and socket family/type/protocol
  connected/listening/bound state
  send/recv/accept/connect/bind/listen/shutdown/setopt operation class
  peer/co-tenancy policy
  rate/budget policy if relevant
```

Socket state is long-lived. A post-exec program may inherit a connected socket
or listening socket. That is normal Linux behavior, but CapSched must derive
operation authority for the new ProgramGeneration.

Special hazards:

```text
nosec fast paths:
  cannot bypass CapSched frozen endpoint use

listening socket:
  accept derives a new SocketEndpointCap for the accepted socket

connected socket:
  send and recv are separate operation authorities

SCM_RIGHTS:
  receiving files through a socket remains receiver-side derivation, not sender
  ambient authority
```

## Class 3: Generic Anonymous FDs

Relevant Linux shape:

```text
fs/anon_inodes.c:198 anon_inode_getfile()
fs/anon_inodes.c:224 anon_inode_getfile_fmode()
fs/anon_inodes.c:265 anon_inode_create_getfile()
fs/anon_inodes.c:281 __anon_inode_getfd() publishes via FD_ADD()
fs/anon_inodes.c:302 anon_inode_getfd()
```

Anonymous fds do not carry ordinary path identity. Their authority is defined by
their fops and private data.

Post-exec derivation:

```text
AnonFdInherit:
  anon class name/fops
  private_data object generation
  LSM anonymous inode context if present
  operation-specific endpoint policy
```

Rejected rule:

```text
anonymous inode survived exec, so use generic file read/write policy
```

The singleton anon inode pattern means inode identity alone is not a sufficient
security object identity.

## Class 4: eventfd

Relevant Linux shape:

```text
fs/eventfd.c:30 struct eventfd_ctx
fs/eventfd.c:56 eventfd_signal_mask()
fs/eventfd.c:71-78 increments count and wakes waiters
fs/eventfd.c:214 eventfd_read()
fs/eventfd.c:247 eventfd_write()
fs/eventfd.c:348 eventfd_ctx_fdget()
fs/eventfd.c:366 eventfd_ctx_fileget()
fs/eventfd.c:370 verifies file->f_op == &eventfd_fops
```

Post-exec derivation:

```text
EventfdInherit:
  read counter
  write/signal counter
  poll/observe readiness
  kernel-signal delegation
  wake authority separation
```

eventfd is not just a file-like byte stream. Kernel subsystems can hold an
`eventfd_ctx` and signal it. If the fd survives exec, CapSched must decide
whether the new ProgramGeneration may:

```text
read old counter state
write/signal the counter
receive kernel-origin signals from pre-exec registrations
use readiness wakeups as cross-Domain notification
```

At minimum, eventfd signal/read/write authority must be re-derived. Kernel-held
eventfd contexts should be generation-checked or treated as service endpoint
relationships.

## Class 5: timerfd

Relevant Linux shape:

```text
fs/timerfd.c:31 struct timerfd_ctx
fs/timerfd.c:58 __timerfd_triggered()
fs/timerfd.c:63 ticks++
fs/timerfd.c:64 wake_up_locked_poll()
fs/timerfd.c:300 timerfd_read_iter()
fs/timerfd.c:381 timerfd_ioctl()
fs/timerfd.c:415 timerfd_fops
fs/timerfd.c:424 timerfd_create()
fs/timerfd.c:464 FD_ADD(... anon_inode_getfile_fmode("[timerfd]", ...))
fs/timerfd.c:473 do_timerfd_settime()
fs/timerfd.c:488 verifies fd_file(f)->f_op == &timerfd_fops
```

Post-exec derivation:

```text
TimerfdInherit:
  read expiration ticks
  arm/disarm/settime
  clock source and alarm privilege
  poll/observe readiness
  ioctl command class if enabled
```

Timer state may legitimately survive exec in Linux, but old program authority
must not. CapSched should distinguish:

```text
object state survives:
  pending ticks, interval, clock id

authority does not automatically survive:
  ability to read, rearm, ioctl, or use wakeups after ProgramGeneration change
```

## Class 6: epoll

Relevant Linux shape:

```text
fs/eventpoll.c:51-57 eventpoll file owns struct eventpoll and watched entries
fs/eventpoll.c:59-60 epoll can watch epoll up to EP_MAX_NESTS
fs/eventpoll.c:1381 eventpoll_release_file()
fs/eventpoll.c:1405-1408 removes epitem when watched file is released
fs/eventpoll.c:1880 ep_insert()
fs/eventpoll.c:1890 detects watched file is epoll
fs/eventpoll.c:1917-1928 attaches poll hooks and reads current readiness
fs/eventpoll.c:2476 do_epoll_create()
fs/eventpoll.c:2496 anon_inode_getfile("[eventpoll]", ...)
fs/eventpoll.c:2621 do_epoll_ctl_file()
fs/eventpoll.c:2632 target file must support poll
fs/eventpoll.c:2677 EPOLL_CTL_ADD calls ep_insert()
```

Post-exec derivation:

```text
EpollInherit:
  epoll instance authority
  watched endpoint authority for each epitem
  observe readiness authority
  wakeup-source authority for EPOLLWAKEUP
  nested epoll topology constraints
```

epoll is a derived observation endpoint. A surviving epoll fd can contain
watched-file relationships created by the old ProgramGeneration.

CapSched must reject:

```text
old epoll ready-list event implies new program may observe/use target endpoint
```

Safe rule:

```text
post-exec epoll_wait/ctl effects require:
  epoll fd authority
  and, for each delivered or modified watched endpoint, derived watch/observe
  authority for the new ProgramGeneration
```

This may require lazy revalidation on delivery or an exec-time sweep. The model
does not choose the implementation yet.

## Class 7: io_uring

Relevant Linux shape:

```text
io_uring/io_uring.c:2708 io_uring_fops
io_uring/io_uring.c:2721 io_is_uring_fops()
io_uring/io_uring.c:2774 io_uring_install_fd() uses O_CLOEXEC by default
io_uring/io_uring.c:2790 io_uring_get_file()
io_uring/io_uring.c:2793 anon_inode_create_getfile("[io_uring]", ...)
fs/exec.c:1140-1142 io_uring_task_cancel()
io_uring/rsrc.c:616 io_sqe_files_register()
io_uring/rsrc.c:652 fget(fd) during registration
io_uring/rsrc.c:660 rejects registering io_uring instances
io_uring/rsrc.c:665 allocates IORING_RSRC_FILE node
io_uring/io_uring.c:1571 io_file_get_fixed()
io_uring/io_uring.c:1579 lookup ctx->file_table.data
io_uring/io_uring.c:1581-1584 attaches file_node to request
io_uring/register.c:786 IORING_REGISTER_FILES
io_uring/register.c:801 IORING_REGISTER_EVENTFD
```

Post-exec derivation:

```text
IoUringInherit:
  ring fd authority
  ring mmap authority
  registered file authority
  registered buffer MemoryCap authority
  eventfd completion notification authority
  request submission authority
  worker/SQPOLL authority and BudgetTicket
```

Even if a ring fd becomes reachable post-exec, old registered resources and
in-flight requests must not remain old-program authority.

Safe rule:

```text
io_uring_task_cancel() covers in-flight task activity but does not by itself
derive post-exec authority for the ring or registered resources.

After exec, any io_uring operation needs:
  ring endpoint derivation for new ProgramGeneration
  fixed file/buffer revalidation or invalidation
  request-time FrozenEndpointUse
  BudgetTicket for worker/service execution
```

## Class 8: execfd Handoff

Relevant Linux shape:

```text
fs/binfmt_misc.c:231 MISC_FMT_OPEN_BINARY sets bprm->have_execfd
fs/binfmt_misc.c:263 MISC_FMT_CREDENTIALS sets bprm->execfd_creds
fs/exec.c:1293-1298 FD_ADD(0, bprm->executable)
fs/binfmt_elf.c:285 emits AT_EXECFD
```

Post-exec derivation:

```text
ExecfdHandoff:
  executable object identity
  interpreter ProgramGeneration
  exact fd inserted into new process
  read/exec/map policy
  credential source policy if execfd_creds is set
```

execfd is neither normal fd inheritance nor SCM_RIGHTS. It is an exec-created
endpoint handoff. CapSched must derive an explicit `ExecfdGrant` for the new
ProgramGeneration.

## Inheritance Class Table

| Class | Linux reachability after exec | Required CapSched derivation |
| --- | --- | --- |
| CLOEXEC fd | removed by `do_close_on_exec()` | none; must not be usable |
| Regular file | fd/file remains | operation mask plus new policy result |
| O_PATH | path handle remains | path/metadata only, no read/write/mmap |
| Socket | socket file remains | socket-state and op-specific endpoint cap |
| Generic anon fd | file/fops/private_data remains | class-specific anon policy |
| eventfd | eventfd_ctx remains | read/write/signal/poll policy |
| timerfd | timerfd_ctx and timer state remain | read/arm/ioctl/clock policy |
| epoll | eventpoll and epitems may remain | epoll authority plus watched endpoint derivation |
| io_uring | ring fd may remain if not closed | ring and registered resource derivation; old requests canceled |
| execfd | inserted by exec path | explicit ExecfdGrant |

## Required Invariants

```text
NoGenericFdPostExecAuthority:
  post-exec endpoint effects require class-specific derivation, not fd
  reachability alone.

NoCloseOnExecResourceLeak:
  close-on-exec resources must not remain reachable or usable.

NoRegularFileOpWithoutMask:
  regular files require operation-specific derived rights; O_PATH cannot become
  read/write/mmap authority.

NoSocketStateAmbientAuthority:
  inherited sockets require socket-state and operation-specific derivation.

NoAnonFdGenericPolicy:
  anonymous fds require fops/private_data class policy.

NoEpollOldReadinessAuthority:
  old epoll readiness or watched endpoints cannot imply new program authority.

NoEventfdSignalLeak:
  eventfd kernel-signal/read/write authority must be re-derived.

NoTimerfdOldTimerAuthority:
  old timer state may exist, but read/arm/ioctl authority must be re-derived.

NoIoUringRegisteredResourceLeak:
  ring reachability cannot carry old registered file/buffer/request authority.

NoExecfdAmbientInheritance:
  execfd handoff requires explicit ExecfdGrant.
```

## Design Consequences

Future implementation should prefer a class table over one generic hook:

```text
capsched_exec_inherit_regular_file()
capsched_exec_inherit_socket()
capsched_exec_inherit_anonfd()
capsched_exec_inherit_eventfd()
capsched_exec_inherit_timerfd()
capsched_exec_inherit_epoll()
capsched_exec_inherit_io_uring()
capsched_execfd_grant()
```

This does not require an eager exec-time sweep for every class. Some classes may
derive lazily on first post-exec use. The invariant is semantic:

```text
no endpoint effect before class-specific post-exec derivation.
```

Implementation choices still open:

```text
eager sweep:
  simple fail-closed state but potentially expensive on huge fd tables

lazy generation check:
  lower exec cost but requires every operation path to check ProgramGeneration

hybrid:
  eager close/revoke high-risk classes, lazy derive ordinary file/socket ops
```

No behavior-changing Linux patch should choose among these until trace-only
coverage proves the selected hooks see all required classes.
