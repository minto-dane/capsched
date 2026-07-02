# SchedExecLease P4 Full vmlinux Build

Date: 2026-07-02

Status: passed for `CONFIG_SCHED_EXEC_LEASE=off` and
`CONFIG_SCHED_EXEC_LEASE=on`.

## Scope

Validate that the P4 allow-only validation skeleton Linux commit builds as a
full `vmlinux` with the feature disabled and enabled.

This is build compatibility evidence only. It is not runtime coverage, runtime
denial, budget enforcement, monitor verification, production protection,
hypervisor-grade isolation, cost-efficiency, or deployment readiness evidence.

## Linux Commit

```text
commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
subject: sched/exec_lease: Add allow-only validation skeleton
```

## Command

Launched under a transient systemd user unit:

```sh
systemd-run --user \
  --unit=capsched-p4-full-build-20260702T214346Z \
  --collect \
  --working-directory=/media/nia/scsiusb/dev/linux-cap \
  /usr/bin/env BUILD_TAG=p4-a937-full JOBS=8 \
  capsched/capsched-models/validation/run-sched-exec-lease-full-build-validation.sh
```

Log:

```text
build/logs/sched-exec-lease-full-build-20260702T214346Z.log
```

## Result

```text
CONFIG_SCHED_EXEC_LEASE=off:
  config: undef
  vmlinux: present
  kernel/sched/exec_lease.o: absent
  build dir: build/linux-l0-sched-exec-lease-off-p4-a937-full-x86_64

CONFIG_SCHED_EXEC_LEASE=on:
  config: y
  vmlinux: present
  kernel/sched/exec_lease.o: present
  build dir: build/linux-l0-sched-exec-lease-on-p4-a937-full-x86_64
```

Log anchors:

```text
[2026-07-02T17:43:46-04:00] SchedExecLease full vmlinux build validation started
[2026-07-02T17:52:28-04:00] completed CONFIG_SCHED_EXEC_LEASE=off vmlinux
[2026-07-02T18:00:29-04:00] completed CONFIG_SCHED_EXEC_LEASE=on vmlinux
[2026-07-02T18:00:29-04:00] SchedExecLease full vmlinux build validation completed
```

Size evidence:

```text
text      data     bss      dec       hex
31120690  8854182  1114804  41089676  272fa8c  off vmlinux
31120798  8854182  1114804  41089784  272faf8  on vmlinux
289       32       0        321       141      on exec_lease.o
```

## Decision

The P4 allow-only validation skeleton passes full `vmlinux` build validation
with `CONFIG_SCHED_EXEC_LEASE` disabled and enabled.

P4 full acceptance remains incomplete until QEMU off/on compatibility
validation passes and the final overclaim/security review is recorded.

P5 remains blocked.

## Non-Claims

This validation does not claim runtime denial, runtime coverage, behavior
equivalence, budget enforcement, monitor call, monitor verification, production
protection, hypervisor-grade isolation, cost-efficiency, deployment readiness,
or P5 denial approval.
