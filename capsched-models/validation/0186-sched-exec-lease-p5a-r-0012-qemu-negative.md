# Validation 0186: SchedExecLease P5A-R 0012 QEMU Negative

Date: 2026-07-04

Status: passed for the synthetic ordinary-CFS negative runtime workload under
the default-off test-only denial harness. This is deny-and-repick mechanic
evidence for the narrow P5A-R test path only.

## Scope

Run the P5A-R negative runtime validation against corrective Linux patch
`0012`.

```text
unit=capsched-p5a-r-0012-negative-qemu-20260704T061035Z.service
log=/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0012-negative-qemu-20260704T061035Z.log
run_dir=build/qemu/sched-exec-lease-p5a-r-0012-negative/20260704T061035Z-on
linux_commit=bd71af5daeae808ac948cbd12af2663151936f22
linux_subject=sched/fair: Force exec lease pickable CFS progress
```

## Observed

The guest booted with the intended config and test-only denial harness:

```text
CONFIG_SCHED_EXEC_LEASE=y
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y
sched_exec_lease: enabled test-only CFS denial harness
```

The workload reached the required markers:

```text
NEGATIVE_ALLOWED_STARTED
NEGATIVE_ALLOWED_RELEASED
NEGATIVE_CHILDREN_RELEASED
NEGATIVE_ALLOWED_DONE
NEGATIVE_ALLOWED_STATUS exit=0
NEGATIVE_DENIED_STATUS still_present
NEGATIVE_ALLOWED_NEXT 770
NEGATIVE_DENIED_NEXT 0
NEGATIVE_RESULT PASS
WORKLOAD_RET 0
SCHED_EXEC_LEASE_QEMU_END workload_ret=0
```

Summary:

```text
qemu_status=0
qemu_timeout_seconds=240
workload_mode=negative
cfs_deny_test_enabled=1
expect_negative=1
kvm=enabled
```

Trace counts:

```text
sched_exec=1518
sched_waking=413
sched_wakeup=413
sched_switch=1590
sched_process_exit=1
```

Hashes:

```text
log_sha256=a5fb5808dabeaec35d56bca443e8fdba892e655b5b385747ebb02d4eae5e4a61
serial_sha256=45349bea54dee19802d9ad71c5c5969c37617b88f7c9c00eab013bd4025f7dcd
summary_sha256=8ab3a605742a51db74f1f3ff4547f393df24920d394de943508185999ad0a90b
counts_sha256=a7756ce233cc6cf7e883abc5dfede72aa72cfefd993230e765ce67798fe7680a
```

## Verdict

The synthetic denied task `seldenyA` did not appear as a scheduled
`next_comm`, while the allowed sibling `selallowB` did run and completed.

This closes the immediate P5A-R 0010/0011 forward-progress failures for the
current synthetic ordinary-CFS test path.

## Remaining Limits

This is not yet a production security result. The test still uses:

```text
default-off CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST
synthetic task->comm prefix denial
ordinary CFS only
non-core scheduling
non-proxy execution
non-sched_ext
no monitor
no real RunCap object
no budget enforcement
```

Function tracing was unavailable in this guest, and kprobes were disabled for
this negative run:

```text
function_tracer_enabled=0
kprobes_enabled=0
pick_next_task_count=0
__schedule_count=0
```

The event trace still counted `sched_switch`, which is sufficient for the
synthetic denied-vs-allowed `next_comm` property in this run.

## Non-Claims

This validation does not prove:

```text
production runtime denial correctness
complete CFS deny-and-repick correctness
runtime coverage across all scheduler paths
RT/deadline/idle/class-loop coverage
core scheduling coverage
proxy execution coverage
sched_ext coverage
real capability semantics
monitor enforcement
budget enforcement
protection
cost efficiency
deployment readiness
datacenter readiness
```
