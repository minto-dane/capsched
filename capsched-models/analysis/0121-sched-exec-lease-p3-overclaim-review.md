# Analysis 0121: SchedExecLease P3 Overclaim Review

Status: Passed; P3 may claim placement-only no-behavior compatibility only

Date: 2026-07-02

## Purpose

Review the P3 Linux patch and validation evidence for claim discipline before
accepting P3 validation.

P3 touches scheduler hot paths, so the dangerous mistake would be to describe a
successful build or QEMU boot as runtime protection. This review prevents that
claim escalation.

## Reviewed Patch

```text
linux_commit=d5f77adb5a64f3b2545db6ab1dcdc4aa4442bab3
linux_subject=sched/exec_lease: Add placement-only scheduler touchpoints
patch_queue=linux-patches/patches/capsched-linux-l0/0006-sched-exec_lease-Add-placement-only-scheduler-touchp.patch
```

Changed files:

```text
include/linux/sched_exec_lease.h
kernel/sched/core.c
kernel/sched/sched.h
```

## Accepted Claim

P3 may claim only:

```text
P3 places no-op scheduler touchpoint markers at selected wake, new-task,
queued-move, tick, and switch-observation source edges. The patch queue
replays, full off/on builds pass, QEMU off/on no-behavior smoke passes, and no
ABI, denial path, monitor call, budget charging, or exported symbol is added.
```

## Evidence Classes

| Evidence | Result | Claim Supported |
| --- | --- | --- |
| Patch queue replay | Passed to exact P3 HEAD | Reproducibility of patch queue |
| `git diff --check` | Passed | Patch formatting sanity |
| Full build off/on | Passed | Build compatibility |
| QEMU smoke off/on | Passed | Boot/workload compatibility |
| Object/symbol note | Marker symbols absent; `core.o` size identical off/on | No out-of-line marker helper overhead observed |
| Grep review | No P3 validation/denial/ABI/monitor symbols found | No obvious overclaiming source surface |

## Forbidden Claim Review

| Forbidden Claim | Verdict | Reason |
| --- | --- | --- |
| Runtime enforcement | Rejected | P3 helpers are `void` no-ops |
| Runtime denial | Rejected | No fallible return path or denial state exists |
| Retry/quarantine | Rejected | No retry or quarantine object/path exists |
| Complete hook coverage | Rejected | QEMU function tracing still lacks `pick_next_task` and `__schedule`; markers are inline |
| Final run validation | Rejected | P3 switch marker is before `context_switch()`, not the future pre-`rq->curr` validation edge |
| Queued move validation | Rejected | P3 marks move sites but does not validate or deny movement |
| Budget enforcement | Rejected | No budget read, charge, timer, or overrun handling exists |
| Policy integration | Rejected | No LSM/cgroup/namespace/Landlock policy hook exists |
| User ABI | Rejected | No syscall, ioctl, sysfs, procfs, debugfs, or tracepoint ABI is added |
| Monitor verification | Rejected | No monitor exists and no monitor call is added |
| Hypervisor-grade isolation | Rejected | Linux-only marker patch cannot enforce MemoryView/IOMMU/domain roots |
| Production protection | Rejected | No runtime authority boundary is enforced |
| Cost efficiency | Rejected | No benchmark or density/cost comparison was run |

## Compatibility Reading

The QEMU evidence is useful because it exercises fork/exec/exit and ordinary
scheduler activity in both disabled and enabled configurations:

```text
off: qemu_status=0, WORKLOAD_RET=0
on:  qemu_status=0, WORKLOAD_RET=0, CONFIG_SCHED_EXEC_LEASE=y
```

It is not runtime coverage for the new P3 marker helpers. Since the helpers are
static inline no-ops, absence from ftrace/kprobe output is expected.

## Design Integrity

P3 preserves the P3/P4 naming boundary from analysis/0112:

```text
P3:
  prepare/note/observe marker names only.

P4 or later:
  allow-all validation result objects or fallible validation names.
```

This avoids implying that a validation contract exists before it does.

## Conclusion

P3 validation is acceptable under a narrow compatibility claim. It is not a
security boundary, not an enforcement patch, and not evidence that the future
DomainLease-Linux scheduler capability model protects anything at runtime.

Next valid implementation step is P4 allow-all final run/move revalidation
skeleton, but only after a separate scope decision and a refreshed final
run/move tuple review.
