# Validation 0177: SchedExecLease P5A-R 0010 Source and Targeted Build

Date: 2026-07-04

Status: passed for source/config/workload/targeted `fair.o` build only. QEMU
negative runtime validation is pending.

## Scope

This validation covers the concrete test-only `0010` harness overlay:

```text
linux_commit=9f2b3996688849eb0ddc13531f735cc4eb16b63d
linux_subject=sched/fair: Add test-only CFS exec lease denial harness
patch_queue_file=linux-patches/patches/capsched-linux-l0/0010-sched-fair-Add-test-only-CFS-exec-lease-denial-harne.patch
patch_queue_sha256=72a5d00ea28f75ea426aa7eb600dd27deae41629ee74a54db611817654fce2dd
```

It does not validate QEMU runtime denial, full `vmlinux`, protection, or
production capability semantics.

## Checks

Passed:

```text
gcc -O2 -Wall -Wextra capsched/capsched-models/validation/workloads/sched_exec_lease_negative_workload.c -o build/validation-tools/sched_exec_lease_negative_workload
bash -n capsched/capsched-models/validation/run-sched-exec-lease-qemu-boot-smoke.sh capsched/capsched-models/validation/run-sched-exec-lease-p5a-r-0010-negative-qemu.sh
git -C linux diff --check
git -C capsched diff --check
```

Targeted config/build:

```text
build_dir=build/linux-l0-sched-exec-lease-on-p5a-r-0010-targeted-x86_64
CONFIG_SCHED_EXEC_LEASE=y
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y
make -C linux O=<build_dir> -j8 kernel/sched/fair.o
fair_o_size=160304
fair_o_sha256=612ba1d25f71c87846310276e73a900cf38800a08244b33b8b805380f3abf4f2
```

Validation harness hashes:

```text
negative_workload_sha256=9739a225d7022dfed37359094d5e9247e172a16b8320a95dbcbe5e7babd4cb0b
negative_runner_sha256=5f064ee14b1629bf763cc032b068357a2372e065db1fcc88b7ba162ee7a56fc7
qemu_smoke_runner_sha256=8e6b367a9e370c2061b95f07004bfaf0fb0d8bedba7fb0984b67d4b4add5a2b3
series_sha256=32e071609a60df58acd9997650554d87a7e5a59d9b9ab5c49581b253f8b020d4
```

## Result

The `0010` overlay is buildable at the touched CFS object level and the
negative QEMU harness can be compiled and invoked.

The next validation must run:

```text
capsched/capsched-models/validation/run-sched-exec-lease-p5a-r-0010-negative-qemu.sh
```

Expected QEMU guest markers:

```text
CONFIG_SCHED_EXEC_LEASE_CFS_DENY_TEST=y
NEGATIVE_ALLOWED_NEXT > 0
NEGATIVE_DENIED_NEXT == 0
NEGATIVE_RESULT PASS
WORKLOAD_RET 0
```

## Non-Claims

This validation does not approve:

```text
accepting 0010
accepting 0009
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
