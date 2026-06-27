# Validation 0038: Post-Exec Resource Inheritance TLC

Status: Completed bounded model check

Date: 2026-06-27

Model:

```text
capsched/capsched-models/formal/0026-post-exec-resource-inheritance-model/PostExecResource.tla
```

Related analysis:

```text
capsched/capsched-models/analysis/0043-post-exec-resource-inheritance-classes.md
```

TLC logs:

```text
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceSafe.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeGeneric.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeCloseOnExec.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeRegular.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeSocket.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeAnon.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeEpoll.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeEventfd.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeTimerfd.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeIoUring.log
/media/nia/scsiusb/dev/linux-cap/build/tlc/post-exec-resource-20260627T093956Z/PostExecResourceUnsafeExecfd.log
```

## Result Summary

Safe configuration:

```text
config: PostExecResourceSafe.cfg
result: PASS
generated states: 17
distinct states: 17
search depth: 3
```

Unsafe configurations produced expected counterexamples:

```text
config: PostExecResourceUnsafeGeneric.cfg
target invariant: NoGenericFdPostExecAuthority
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3

config: PostExecResourceUnsafeCloseOnExec.cfg
target invariant: NoCloseOnExecResourceLeak
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3

config: PostExecResourceUnsafeRegular.cfg
target invariant: NoRegularFileOpWithoutMask
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3

config: PostExecResourceUnsafeSocket.cfg
target invariant: NoSocketStateAmbientAuthority
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3

config: PostExecResourceUnsafeAnon.cfg
target invariant: NoAnonFdGenericPolicy
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3

config: PostExecResourceUnsafeEpoll.cfg
target invariant: NoEpollOldReadinessAuthority
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3

config: PostExecResourceUnsafeEventfd.cfg
target invariant: NoEventfdSignalLeak
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3

config: PostExecResourceUnsafeTimerfd.cfg
target invariant: NoTimerfdOldTimerAuthority
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3

config: PostExecResourceUnsafeIoUring.cfg
target invariant: NoIoUringRegisteredResourceLeak
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3

config: PostExecResourceUnsafeExecfd.cfg
target invariant: NoExecfdAmbientInheritance
result: expected FAIL
generated states before violation: 18
distinct states before violation: 18
depth: 3
```

## Validated Claims

This validation supports the following local design constraints:

```text
1. Post-exec fd reachability is not endpoint authority.

2. Close-on-exec resources must not remain reachable or usable after exec.

3. Regular and path-backed files require operation-specific post-exec masks;
   O_PATH-style reachability cannot become read/write/mmap authority.

4. Inherited sockets require socket-state and operation-specific endpoint
   derivation; connected/listening state is not ambient authority.

5. Anonymous fds require fops/private_data class policy, not generic file
   policy.

6. epoll old readiness and watched endpoint relationships cannot imply new
   ProgramGeneration observe/use authority.

7. eventfd read/write/kernel-signal authority must be re-derived.

8. timerfd old timer state may exist, but read/arm/ioctl authority must be
   re-derived.

9. io_uring ring reachability cannot carry old registered file/buffer/request
   authority across exec.

10. execfd handoff requires explicit ExecfdGrant rather than ambient fd
    inheritance.
```

## Unsafe Counterexample Meaning

`PostExecResourceUnsafeGeneric.cfg` demonstrates endpoint effects authorized by
generic fd reachability after exec.

`PostExecResourceUnsafeCloseOnExec.cfg` demonstrates a close-on-exec resource
remaining usable after exec.

`PostExecResourceUnsafeRegular.cfg` demonstrates regular file operation without
operation-specific post-exec mask.

`PostExecResourceUnsafeSocket.cfg` demonstrates socket operation authorized by
surviving socket state alone.

`PostExecResourceUnsafeAnon.cfg` demonstrates anonymous fd use under generic
file policy rather than fops/private_data class policy.

`PostExecResourceUnsafeEpoll.cfg` demonstrates old epoll readiness or watched
endpoint relationship authorizing post-exec effects.

`PostExecResourceUnsafeEventfd.cfg` demonstrates eventfd kernel-signal authority
leaking across exec.

`PostExecResourceUnsafeTimerfd.cfg` demonstrates old timerfd timer authority
leaking across exec.

`PostExecResourceUnsafeIoUring.cfg` demonstrates ring reachability carrying old
registered resources or old activity across exec.

`PostExecResourceUnsafeExecfd.cfg` demonstrates execfd handoff without
ExecfdGrant.

## Evidence Limits

This validation does not prove:

```text
complete fd table sweep coverage
complete per-fops taxonomy
all socket protocol state transitions
all anonymous fd classes such as pidfd, signalfd, userfaultfd, perf, bpf, memfd
all epoll delivery races
all io_uring opcodes and registered buffer semantics
performance cost of eager versus lazy post-exec derivation
monitor-backed MemoryView or IOMMU behavior
```

Those remain separate proof obligations.

## Design Consequence

Future exec endpoint work should use class-specific inheritance functions or
equivalent lazy checks:

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

A single generic rule such as "surviving fd inherits EndpointCap" is unsafe.

The implementation choice remains open:

```text
eager exec-time sweep
lazy ProgramGeneration check on first use
hybrid high-risk eager plus common-case lazy
```

The next gate should map trace-only coverage for these classes before any
behavior-changing endpoint enforcement hook.
