# Implementation 0036: SchedExecLease P5A-R 0010 Negative Harness

Date: 2026-07-04

Status: concrete test-only Linux patch drafted. Not accepted as production
policy or protection.

## Purpose

Patch `0009` added a dormant ordinary-CFS deny-and-repick candidate path. It
had no enable site for `sched_exec_cfs_candidate_key`, so runtime negative
tests could not exercise the path.

Patch `0010` adds a default-off test harness overlay so QEMU can validate the
mechanics without adding a production policy surface.

## Linux Patch

```text
linux_commit=9f2b3996688849eb0ddc13531f735cc4eb16b63d
linux_subject=sched/fair: Add test-only CFS exec lease denial harness
patch_queue_file=linux-patches/patches/capsched-linux-l0/0010-sched-fair-Add-test-only-CFS-exec-lease-denial-harne.patch
patch_queue_sha256=72a5d00ea28f75ea426aa7eb600dd27deae41629ee74a54db611817654fce2dd
series_sha256=32e071609a60df58acd9997650554d87a7e5a59d9b9ab5c49581b253f8b020d4
```

Touched Linux files:

```text
init/Kconfig
kernel/sched/fair.c
```

## Behavior

The patch adds:

```text
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST
```

Properties:

```text
depends on SCHED_EXEC_LEASE && DEBUG_KERNEL
default n
compiled out unless explicitly enabled
```

When enabled, the patch:

```text
1. enables the existing sched_exec_cfs_candidate_key at late init
2. treats task->comm prefix "seldeny" as SCHED_EXEC_VALIDATION_INELIGIBLE
```

When disabled, there is no enable site for the candidate static key and normal
`CONFIG_SCHED_EXEC_LEASE=y` behavior remains the denial-disabled `0009` shape.

## Validation Harness

Validation-side files:

```text
capsched-models/validation/workloads/sched_exec_lease_negative_workload.c
capsched-models/validation/run-sched-exec-lease-p5a-r-0010-negative-qemu.sh
capsched-models/validation/run-sched-exec-lease-qemu-boot-smoke.sh
```

Hashes:

```text
negative_workload_sha256=21e7baafcb56ec5a92d6ee1b1e49b2aa4ad246d71ab420b17851e5825d994739
negative_runner_sha256=5f064ee14b1629bf763cc032b068357a2372e065db1fcc88b7ba162ee7a56fc7
qemu_smoke_runner_sha256=8e6b367a9e370c2061b95f07004bfaf0fb0d8bedba7fb0984b67d4b4add5a2b3
```

The negative workload creates:

```text
seldenyA:
  synthetic denied ordinary-CFS child

selallowB:
  allowed ordinary-CFS sibling child
```

Both children are pinned to CPU 0 after trace reset. The workload expects:

```text
NEGATIVE_ALLOWED_NEXT > 0
NEGATIVE_DENIED_NEXT == 0
NEGATIVE_RESULT PASS
```

## Fast Evidence

Validation/0177 records the first local source/config/workload checks:

```text
workload host compile: passed
runner shell syntax: passed
linux diff --check: passed
capsched diff --check: passed
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y olddefconfig: passed
targeted fair.o build: passed
```

Targeted object:

```text
build_dir=build/linux-l0-sched-exec-lease-on-p5a-r-0010-targeted-x86_64
fair_o_size=160304
fair_o_sha256=612ba1d25f71c87846310276e73a900cf38800a08244b33b8b805380f3abf4f2
```

## Non-Claims

This patch does not approve:

```text
production execution lease policy
capability semantics
public ABI
public tracepoint ABI
debugfs/sysctl/proc control
LSM/cgroup/namespace policy hook
monitor call
persistent hot denial fields
runtime denial correctness
CFS deny-and-repick correctness
runtime coverage
protection
cost efficiency
deployment readiness
datacenter readiness
```

## Pending

Before any acceptance:

```text
QEMU negative runtime rerun after validation/0180 allowed-first release fix
security diff review
final overclaim review
claim-ledger update
decision on whether 0010 remains test-only overlay or is dropped after use
```

## Harness Fix

Validation/0178 found that the first QEMU negative attempt reached the guest
with `CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y`, but timed out after
`tracefs reset: Bad file descriptor`. The workload treated `trace_marker` as a
required reset step even though the decision only depends on clearing trace and
counting `sched_switch next_comm` after the reset.

The workload now treats `trace_marker` as optional:

```text
required:
  tracing_on=0
  trace clear
  tracing_on=1

optional:
  trace_marker DOMAINLEASE_NEGATIVE_START
```

This does not change the Linux patch or the synthetic denial predicate.

Validation/0179 then found a second workload issue. The workload released the
denied child, yielded/slept, and only then released the allowed sibling. If the
parent was not eligible after yielding, there was no allowed sibling runnable
yet, so the test could time out before measuring the intended property.

Validation/0180 found a sharper version of the same issue: even without an
explicit yield between child releases, waking the denied high-priority child
first can preempt the parent before it writes the allowed child's start pipe.

The workload now releases the allowed child first:

```text
write allowed_start
print NEGATIVE_ALLOWED_RELEASED
write denied_start
print NEGATIVE_CHILDREN_RELEASED
sched_yield()
```

This restores the intended measurement: denied and allowed ordinary-CFS
children are runnable together, and the picker must choose the allowed sibling
without running the denied one.
