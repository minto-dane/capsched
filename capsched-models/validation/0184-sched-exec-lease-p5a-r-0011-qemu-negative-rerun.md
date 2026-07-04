# Validation 0184: SchedExecLease P5A-R 0011 QEMU Negative Rerun

Date: 2026-07-04

Status: timed out after the allowed child started. This is negative evidence
against accepting the `0011` corrective draft as sufficient.

## Scope

Run the P5A-R negative runtime validation against corrective Linux patch
`0011`.

```text
unit=capsched-p5a-r-0011-negative-qemu-20260704T053810Z.service
log=/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0011-negative-qemu-20260704T053810Z.log
run_dir=build/qemu/sched-exec-lease-p5a-r-0011-negative/20260704T053810Z-on
linux_commit=38340eceafa88119ba3e0bcdc10f309bfff6462b
linux_subject=sched/fair: Fix exec lease denied CFS repick progress
```

## Observed

The guest booted with the intended config and test-only denial harness:

```text
CONFIG_SCHED_EXEC_LEASE=y
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y
sched_exec_lease: enabled test-only CFS denial harness
```

The workload reached:

```text
NEGATIVE_TRACE_MARKER_SKIPPED errno=9
NEGATIVE_CHILDREN_READY denied_pid=72 allowed_pid=73 tracefs=/sys/kernel/tracing
NEGATIVE_ALLOWED_STARTED
NEGATIVE_ALLOWED_RELEASED
NEGATIVE_CHILDREN_RELEASED
```

It did not reach:

```text
NEGATIVE_ALLOWED_DONE
NEGATIVE_RESULT
```

The QEMU runner timed out:

```text
qemu_status=124
qemu_timeout_seconds=240
kvm=enabled
```

Hashes:

```text
log_sha256=5c75462d6880255fbb748c6bad703e6a4c4d2cf3caab97ef3b3630d1a1f33128
serial_sha256=80278c8623dad5896591f8b80d12df383223ffa332e4dbdeeeb3474c146b817b
summary_sha256=ebdf9277bd1ebb993be21b3c1871650ef4d5ce317e31e98971311f151faca29e
counts_sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Diagnosis

`0011` fixed the first-order same-state retry/stall class, but it still lets
the scheduler settle to idle when a denied entity is the only eligible visible
candidate and an allowed sibling is runnable but temporarily ineligible.

That is unsafe for forward progress: if the CPU idles while the only allowed
runnable entity remains ineligible, CFS virtual time does not advance in a way
that makes the allowed entity naturally complete the workload.

The next corrective draft must prefer an allowed pickable runnable entity over
idling when denial has blocked the eligible candidate, even if that entity is
not currently CFS-eligible. This is a draft forced-progress rule, not a final
production policy.

## Non-Claims

This run does not prove:

```text
runtime denial correctness
CFS deny-and-repick correctness
runtime coverage
capability semantics
monitor enforcement
protection
cost efficiency
deployment readiness
datacenter readiness
```
