# Validation 0182: SchedExecLease P5A-R 0010 QEMU Negative Equal-Priority Run

Date: 2026-07-04

Status: timed out after establishing the equal-priority denied/allowed sibling
condition. This is negative evidence against the current `0009/0010` draft CFS
deny-and-repick path, not a host-environment verdict and not an accepted
denial-correctness result.

## Scope

Run the QEMU negative runtime validation after validation/0181 changed the
workload so both children use the same high priority.

```text
unit=capsched-p5a-r-0010-negative-qemu-equalprio-20260704T051528Z.service
log=/media/nia/scsiusb/dev/linux-cap/build/logs/sched-exec-lease-p5a-r-0010-negative-qemu-equalprio-20260704T051528Z.log
run_dir=build/qemu/sched-exec-lease-p5a-r-0010-negative/20260704T051528Z-on
linux_commit=9f2b3996688849eb0ddc13531f735cc4eb16b63d
linux_subject=sched/fair: Add test-only CFS exec lease denial harness
```

## Observed

The guest booted into the intended kernel/config:

```text
CONFIG_SCHED_EXEC_LEASE=y
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y
sched_exec_lease: enabled test-only CFS denial harness
```

The workload reached:

```text
NEGATIVE_TRACE_MARKER_SKIPPED errno=9
NEGATIVE_CHILDREN_READY denied_pid=71 allowed_pid=72 tracefs=/sys/kernel/tracing
NEGATIVE_ALLOWED_STARTED
NEGATIVE_ALLOWED_RELEASED
NEGATIVE_CHILDREN_RELEASED
```

It did not reach:

```text
NEGATIVE_ALLOWED_DONE
NEGATIVE_RESULT
```

The systemd/QEMU runner timed out:

```text
qemu_status=124
qemu_timeout_seconds=240
kvm=enabled
```

Hashes:

```text
log_sha256=e282c354d52715108a17bc6bcdd2c5c1457db4b7cb1f506c3ac975172d31b603
serial_sha256=31033dae53834356752077fa372e6a2e2402c1cbcd9bf8aad2b949f165d9046d
summary_sha256=2f373b3c46d57bb739f2dd2ea6e954cc93eb9fee5e655bcef8a0bac5ef403d7f
counts_sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
negative_workload_sha256=5989c84eefa1ca10600642baf015edad11e848189e517187d80b590913a00934
```

## Diagnosis

This is not first-class evidence for a slow host PC. The same QEMU environment
previously completed the denial-disabled P5A-R 0009 smoke run. Here, the
allowed child started and both children were released, but the workload never
settled.

The scheduler-source failure class is:

```text
upstream CFS assumption:
  pick_next_entity() returning NULL while queued usually means delayed dequeue;
  retrying the pick can make progress.

SchedExecLease draft change:
  denial filtering introduces a new NULL reason: a denied candidate can block
  the visible eligible choice.

broken consequence:
  __pick_task_fair() can retry/newidle-balance around the same denied/blocked
  CFS state without making progress.
```

Validation/0181 already showed the same class with an RCU stall in
`pick_eevdf()`. Validation/0182 removes the priority-skew ambiguity and still
fails to complete.

## Required Fix Class

The draft path must distinguish denied-candidate blockage from delayed dequeue
and must provide a bounded way to locate a later allowed CFS entity, or settle
without spinning when no such entity exists.

## Non-Claims

This timed-out run does not prove:

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
