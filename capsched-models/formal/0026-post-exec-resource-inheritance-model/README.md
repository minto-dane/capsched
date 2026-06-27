# Post-Exec Resource Inheritance Model

Status: Draft, checked with tiny finite TLC configurations

Date: 2026-06-27

Related analysis:

```text
capsched/capsched-models/analysis/0043-post-exec-resource-inheritance-classes.md
```

## Purpose

This model captures the post-exec fd/resource inheritance rule:

```text
fd reachability after exec is not endpoint authority.
Each surviving resource class must be derived or attenuated before endpoint
effects in the new ProgramGeneration.
```

## Modeled Hazards

```text
generic fd reachability used as post-exec authority
CLOEXEC resource leaking after exec
regular file operation without operation mask
socket state used without socket-specific policy
anonymous fd treated as generic path-backed file
epoll old readiness or watched endpoint used as authority
eventfd kernel-signal authority leaking across exec
timerfd old timer authority leaking across exec
io_uring ring reachability carrying registered resources or old activity
execfd handoff used without ExecfdGrant
```

## Checked Invariants

```text
NoGenericFdPostExecAuthority
NoCloseOnExecResourceLeak
NoRegularFileOpWithoutMask
NoSocketStateAmbientAuthority
NoAnonFdGenericPolicy
NoEpollOldReadinessAuthority
NoEventfdSignalLeak
NoTimerfdOldTimerAuthority
NoIoUringRegisteredResourceLeak
NoExecfdAmbientInheritance
```

## Scope Limit

This is not a full VFS, socket, epoll, eventfd, timerfd, io_uring, or binfmt
model. It abstracts post-exec endpoint effects into class-specific inheritance
hazards.

The model does not decide whether implementation should use eager exec-time
sweeps, lazy generation checks, or a hybrid. It only establishes:

```text
no endpoint effect before class-specific post-exec derivation.
```
