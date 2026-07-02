# SchedExecLease P4 Final Overclaim and Security Review Validation

Date: 2026-07-02

Status: passed. P4 allow-only compatibility slice is closed.

## Scope

Validate the final P4 overclaim and security review:

```text
analysis/0128-sched-exec-lease-p4-final-overclaim-security-review.md
analysis/sched-exec-lease-p4-final-overclaim-security-review-v1.json
```

This validation is scoped to the P4 allow-only compatibility slice.

## Checks

JSON contract:

```sh
jq empty \
  capsched/capsched-models/analysis/sched-exec-lease-p4-final-overclaim-security-review-v1.json
```

Patch and source review:

```sh
git -C linux show --stat --oneline HEAD
git -C linux show --format=medium --no-ext-diff HEAD -- \
  include/linux/sched_exec_lease.h \
  kernel/sched/core.c \
  kernel/sched/exec_lease.c \
  kernel/sched/sched.h
```

Forbidden behavior review:

```sh
grep -RIn \
  "SCHED_EXEC_VALIDATION_\\(RETRY\\|INELIGIBLE\\|QUARANTINE\\)\\|sched_exec_lease_validate_.*edge\\|monitor\\|budget\\|tracepoint\\|debugfs\\|procfs\\|sysfs\\|ioctl\\|SYSCALL" \
  linux/include/linux/sched_exec_lease.h \
  linux/kernel/sched/core.c \
  linux/kernel/sched/sched.h \
  linux/kernel/sched/exec_lease.c
```

Result interpretation:

```text
non-ALLOW enum values: present only as type vocabulary.
validate helpers: present and allow-only.
validate callsites: present and result discarded.
monitor/budget/ABI terms: comments, existing unrelated scheduler text, or
private placeholder types only.
new syscall/ioctl/sysfs/procfs/debugfs/tracepoint ABI: none.
```

## Evidence Summary

Accepted evidence:

```text
patch queue replay exact: validation/0147
checkpatch clean: validation/0147
targeted scheduler build off/on: validation/0147
source/object checker: validation/0147
formal gate safe plus expected unsafe counterexamples: validation/0147
full vmlinux off/on: validation/0148
QEMU off/on boot/workload smoke: validation/0149
```

Security review result:

```text
findings_reported=0
```

## Decision

P4 allow-only compatibility slice is closed.

P5 remains blocked.

## Non-Claims

This validation does not claim runtime denial, runtime coverage, budget
enforcement, monitor call, monitor verification, production protection,
hypervisor-grade isolation, cost-efficiency, deployment readiness, or P5 denial
approval.
