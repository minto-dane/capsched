# Analysis 0008: Policy Front-Ends and Capability Issuance

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note maps LSM, Linux credentials, Linux capabilities, namespaces, cgroups,
and Landlock to CapSched capability issuance. These mechanisms are important
policy front-ends. They are not the non-forgeable root of the final security
boundary.

## Core Distinction

CapSched needs two different layers:

```text
policy decision:
  Who should be allowed to receive a capability?

authority root:
  What prevents Linux or a compromised Domain-local kernel context from forging
  that capability?
```

Existing Linux mechanisms are mostly policy decision machinery. The eventual
authority root must come from frozen kernel objects and then from HyperTag
Monitor state.

## LSM Hooks

Evidence:

- `security/security.c` around lines 777-801:
  `security_bprm_creds_for_exec()` and `security_bprm_creds_from_file()`
  prepare or modify proposed exec credentials.
- `security/security.c` around lines 2783-2802:
  `security_task_alloc()` and `security_task_free()` manage task LSM blobs.
- `security/security.c` around lines 3175-3251:
  `security_task_setnice()`, `security_task_setioprio()`, and
  `security_task_setscheduler()` mediate scheduling-related operations.
- `include/linux/lsm_hook_defs.h` around lines 52-56, 218-220, and 251-258
  defines exec, task allocation, and scheduler hooks.

CapSched interpretation:

LSM hooks can answer questions such as:

```text
May this task receive a SpawnCap?
May this task request SchedControlCap for a target task?
May exec attenuate endpoint capabilities?
May a task enter or create a Domain?
May a Domain receive a service endpoint?
```

They should not be treated as:

```text
the thing that makes RunCap unforgeable
the thing that protects Domain epoch
the thing that protects MemoryView
the thing that survives arbitrary kernel code execution
```

## Linux Credentials

Evidence:

- `kernel/cred.c` around lines 263-327 implements `copy_creds()`.
  Thread clone may share credentials. Other cases prepare a new cred object.
- `kernel/cred.c` around lines 368-430 implements `commit_creds()`, which
  RCU-replaces `real_cred` and `cred` and handles dumpability, keyrings, user
  namespace references, and notifications.
- `kernel/cred.c` around lines 559-608 implements `prepare_kernel_cred()` for
  kernel services.

CapSched interpretation:

Credentials are a policy input and compatibility state. `DomainTag` must not be
identical to `cred` because:

- fork and clone may share or copy credentials.
- exec may change credentials.
- setuid and Linux capabilities may change effective authority.
- kernel services can prepare alternative credentials.
- final threat model assumes compromised kernel context inside a Domain.

Rule candidate:

```text
cred may influence capability issuance
cred changes may attenuate or revoke endpoint caps
cred changes must not silently mint a new DomainTag
```

## Linux Capabilities

Evidence:

- `security/commoncap.c` around lines 919-980 modifies proposed exec
  credentials using file capabilities and setid behavior.
- `security/commoncap.c` around lines 1159-1195 adjusts capabilities during
  setuid changes.
- `security/commoncap.c` around lines 1301-1455 implements capability-related
  `prctl()` operations and mmap/memory capability checks.
- `security/commoncap.c` around lines 1491-1503 registers capability LSM hooks.

CapSched interpretation:

Linux capabilities such as `CAP_SYS_NICE`, `CAP_SYS_ADMIN`, `CAP_BPF`, and
`CAP_NET_ADMIN` are coarse policy gates. They are useful compatibility inputs,
but they are ambient and mutable within normal Linux authority.

Mapping:

| Linux capability use | CapSched policy object |
| --- | --- |
| `CAP_SYS_NICE` | request SchedControlCap or privileged SchedContext mutation |
| `CAP_SYS_ADMIN` | management-domain policy input, never universal authority by itself |
| `CAP_BPF` | request BPF program/map authority within a Domain/service policy |
| `CAP_NET_ADMIN` | request network endpoint or queue-management authority |
| `CAP_IPC_LOCK` | request pinned/donated memory policy for monitor-backed memory |

## Namespaces

Evidence:

- `kernel/nsproxy.c` around lines 88-169 creates and copies namespace proxies.
- `copy_namespaces()` around lines 169-211 reuses the old namespace proxy for
  common cases and requires namespace capability for new namespaces.
- `switch_task_namespaces()` around lines 245-265 swaps `task->nsproxy` with
  task locking and reference handling.
- `exec_task_namespaces()` around lines 292-297 can update time namespace state
  during exec.

CapSched interpretation:

Namespaces are compatibility and object-view policy inputs:

```text
mnt namespace -> filesystem view policy
net namespace -> network endpoint policy
pid namespace -> visibility and control policy
cgroup namespace -> accounting/control view policy
user namespace -> Linux capability interpretation
```

They are not a full Domain boundary. A namespace changes what Linux exposes or
names. A CapSched Domain must also bind execution authority, budget, provenance,
epoch, and eventually MemoryView.

## cgroups

Evidence:

- `kernel/cgroup/cgroup.c` around lines 6890-6930:
  `cgroup_can_fork()` prepares the child's `css_set` and lets subsystems deny
  fork before exposure.
- `cgroup_cancel_fork()` around lines 6939-6950 unwinds a failed fork after
  `cgroup_can_fork()`.
- `cgroup_post_fork()` around lines 6960-7060 attaches the child and invokes
  subsystem fork callbacks.
- `cgroup_task_exit()` around lines 7061-7070 invokes exit callbacks.

CapSched interpretation:

cgroups provide excellent administrative grouping and resource policy. They are
also a good place to observe fork admission and tenant/service grouping.

But cgroup membership is not enough for CapSched because:

- it is mutable Linux state
- it is designed for management and accounting
- it does not carry frozen per-operation authority
- it does not protect MemoryView or device ownership below Linux

Mapping:

```text
cgroup placement/policy
  -> candidate issuer or constraint for Domain and SchedContext

cgroup CPU controls
  -> policy-level quota/weight/uclamp

monitor root budget
  -> final non-forgeable CPU upper bound
```

## Landlock

Evidence:

- `security/landlock/setup.c` around lines 20-61 registers Landlock hooks and
  blob sizes for cred, file, inode, and superblock security state.
- `security/landlock/cred.c` around lines 16-58 transfers Landlock domain
  state through credential prepare/transfer/free hooks.
- `security/landlock/syscalls.c` around lines 466-526 implements
  `landlock_add_rule()` and `landlock_restrict_self()`.
- `security/landlock/syscalls.c` around lines 590-720 merges rulesets into new
  credentials and commits them.
- `security/landlock/fs.h` around lines 46-83 states that file security state
  tracks access rights available at open time.
- `security/landlock/fs.c` around lines 1751-1785 performs `hook_file_open()`
  checks and records allowed access.
- `security/landlock/fs.c` around lines 1840-2010 checks later file operations
  such as truncate, ioctl, file owner, and registers file/path hooks.

CapSched interpretation:

Landlock is especially relevant to EndpointCap because it already has:

- user-visible ruleset construction
- self-restriction semantics
- cred-attached domain-like policy
- file-open-time access capture
- later operation checks against access captured at open
- path, file, network, signal, and Unix socket scopes

Potential CapSched use:

```text
Landlock ruleset
  -> policy input for EndpointCap issuance

Landlock file-open captured access
  -> model reference for freezing object authority

Landlock task/socket scopes
  -> policy reference for cross-Domain task and IPC control
```

Limit:

Landlock is still an LSM policy layer inside Linux. It can constrain normal
Linux behavior, but cannot be the final root against Domain-local arbitrary
kernel execution.

## Capability Issuance Pipeline

Candidate pipeline for L0/L1:

```text
Linux request:
  fork, exec, sched_setattr, open, socket, ioctl, io_uring register, BPF load

Policy front-ends:
  LSM, cred, Linux capabilities, namespace, cgroup, Landlock

CapSched issuer:
  creates attenuated typed capability object

Freeze point:
  turns capability into FrozenRunUse or endpoint-specific FrozenUse

Execution or resource endpoint:
  validates frozen use cheaply on hot path
```

Candidate pipeline for Monitor-backed track:

```text
Linux policy front-end
  -> CapSched issuer
  -> Monitor seal or lease validation
  -> local frozen use
  -> endpoint or scheduler execution
```

## Preliminary Conclusion

The existing Linux security stack is a strong policy source and compatibility
surface. CapSched should integrate with it rather than compete with it. The
critical design move is to let Linux decide "should this be allowed" while
CapSched and later HyperTag Monitor decide "can this authority be forged,
reused, or expanded after the decision".
