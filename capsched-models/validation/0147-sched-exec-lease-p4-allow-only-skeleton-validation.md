# SchedExecLease P4 Allow-Only Skeleton Validation

Date: 2026-07-02

Status: patch queue replay, checkpatch, source/object checker, targeted
`CONFIG_SCHED_EXEC_LEASE=off/on` scheduler build, and formal gate passed.
Full `vmlinux` validation is recorded separately in validation/0148. QEMU
compatibility validation is still pending.

## Linux Patch

```text
commit: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
subject: sched/exec_lease: Add allow-only validation skeleton
patch: linux-patches/patches/capsched-linux-l0/0007-sched-exec-lease-Add-allow-only-validation-skel.patch
```

Touched files:

```text
include/linux/sched_exec_lease.h
kernel/sched/core.c
kernel/sched/exec_lease.c
kernel/sched/sched.h
```

## Patch Queue Replay

Command:

```sh
rm -rf build/replay/p4-allow-skeleton
git clone --shared linux build/replay/p4-allow-skeleton
DOMAINLEASE_RECREATE_FETCH=0 \
  linux-patches/scripts/recreate-capsched-linux-l0.sh \
  build/replay/p4-allow-skeleton
```

Result:

```text
final HEAD: a937c67f51d1b82297c4f8b7c471f63e8f1a4fe8
```

## Checkpatch

Command:

```sh
linux/scripts/checkpatch.pl --no-tree \
  linux-patches/patches/capsched-linux-l0/0007-sched-exec-lease-Add-allow-only-validation-skel.patch
```

Result:

```text
total: 0 errors, 0 warnings, 97 lines checked
```

## Targeted Build

Command:

```sh
BUILD_TAG=p4-targeted-current \
  capsched/capsched-models/validation/run-sched-exec-lease-rename-build-validation.sh
```

Result:

```text
CONFIG_SCHED_EXEC_LEASE=off kernel/sched/built-in.a: passed
CONFIG_SCHED_EXEC_LEASE=on  kernel/sched/built-in.a: passed
log: build/logs/sched-exec-lease-rename-build-20260702T213150Z.log
```

## Source/Object Checker

Contract:

```text
implementation/sched-exec-lease-p4-allow-only-validation-skeleton-implementation-v1.json
```

Command:

```sh
DOMAINLEASE_RUN_ID=20260702T2136Z-p4-allow-only \
  capsched/capsched-models/validation/run-sched-exec-lease-p4-allow-only-skeleton-check.sh
```

Result:

```text
run_dir=build/source-check/sched-exec-lease-p4-allow-only-skeleton/20260702T2136Z-p4-allow-only
work_commit_matches=true
patch_queue_entry_present=true
checkpatch_clean=true
helper_count=3
callsite_count=3
non_allow_returns_found=false
scheduler_branches_on_validation_result=false
targeted_build_objects_present=true
validation_symbols_emitted=false
core_o_file_size_equal=true
core_o_size=347728/347728
runtime_denial=false
runtime_coverage=false
production_protection=false
```

Object size result:

```text
text   data   bss   dec     hex
73924  29289  704   103917  195ed  off core.o
73924  29289  704   103917  195ed  on core.o
289    32     0     321     141    on exec_lease.o
```

Important negative:

```text
core.o file sizes match, but byte identity is not claimed.
No sched_exec_lease_validate_* or sched_exec_allow_all_validation symbol is emitted.
```

## Formal Gate

Model:

```text
formal/0097-p4-allow-only-skeleton-gate-model/
```

Safe result:

```text
Model checking completed. No error has been found.
2 states generated, 1 distinct state found.
Depth: 1.
```

Unsafe batch:

```text
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeAcceptedWithoutFullValidation.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeAuthoritySideEffect.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeCheckpatch.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeEmittedSymbol.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeHelperNonAllow.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeMissingCallsites.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeNoReplay.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeNoSourceCheck.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeProtectionClaim.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeRuntimeDenial.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeSchedulerBranch.cfg
EXPECTED_COUNTEREXAMPLE P4AllowOnlySkeletonGateUnsafeTargetedBuild.cfg
expected_counterexamples=12 unexpected=0
```

## Decision

The P4 allow-only skeleton is recorded as an applied no-denial Linux patch and
has passed static, replay, style, targeted build, object/symbol, and formal
gate validation.

It is not yet fully accepted as P4 completion because QEMU off/on compatibility
validation remains pending.

P5 remains blocked.

## Non-Claims

This validation does not claim runtime denial, runtime coverage, budget
enforcement, monitor call, monitor verification, production protection,
hypervisor-grade isolation, cost-efficiency, deployment readiness, or P5 denial
approval.
